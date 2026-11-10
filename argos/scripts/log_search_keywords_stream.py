#!/usr/bin/env python3
"""
log_search_keywords_stream.py — cursor-paginated keyword log search via argos tool.

Usage:
    python3 log_search_keywords_stream.py '<json_input>' [max_pages]

Arguments:
    json_input  - JSON string with search parameters
    max_pages   - Optional maximum pages to fetch (default: no fixed page limit)

Required JSON fields:
    psm_list  - string[] - PSM list (array, NOT single string)
    region    - string   - Bytedance cloud region (e.g. "China-North")
    keywords  - string[] - Search keywords
    start     - string   - RFC3339 start time
    end       - string   - RFC3339 end time

Optional JSON fields:
    env                 - string   - Environment override (dev|boe|cn|i18n|i18n-bd|eu-ttp|us-ttp|sandbox)
                                     Passed as -e flag; required for non-CN regions
    project             - string   - Project name (passed as --project flag)
    max_elapsed_seconds - number   - Client-side pagination budget (default: 300)
    max_logs            - int      - Check this log budget after each page (default: 1000)
    limit               - int      - First-page max logs (default: 100)
    keywords_exclude    - string[] - Keywords to exclude
    keyword_operator    - string   - "AND" (default) or "OR"
    level               - string[] - Log level filter (e.g. ["Error","Warning"])
    kv_filters          - array    - Structured filters [{key, values}]
    index_mode          - string   - auto (default), on, off, or legacy
    enable_index        - bool     - Existing explicit index switch (legacy profile)
    term_keywords       - string[] - Explicit TERM keywords (needs auto/on)
    error_log_preferred - bool     - Smart filter: try Warning+ first
    timeout_in_ms       - int      - First query timeout (default: 2000)
    deduplication       - bool     - Deduplicate logs

Example:
    python3 log_search_keywords_stream.py \\
      '{"psm_list":["my.service.api"],"region":"China-North","keywords":["error"],"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z","limit":100}'

Output:
    stdout: JSON array of collected log entries (may be partial)
    stderr: Progress information. If a safety budget is reached, includes the
            resume cursor and reports that stdout contains partial results.

Exit codes:
    0 - success
    1 - argument/parse error
    2 - tool invocation error
    3 - incomplete because a safety budget was reached or pagination stalled
"""

import json
import math
import subprocess
import sys
import time


DEFAULT_MAX_ELAPSED_SECONDS = 300
DEFAULT_MAX_LOGS = 1000


class PaginationError(RuntimeError):
    def __init__(self, message: str, logs: list, cursor: str | None):
        super().__init__(message)
        self.logs = logs
        self.cursor = cursor


def call_argos_tool(request: dict, env: str | None = None, project: str | None = None) -> dict:
    """Call argos tool log search.keywords_stream with the given request."""
    input_json = json.dumps(request)
    cmd = ["argos", "tool", "--json", "--limit", "0"]
    if env:
        cmd += ["-e", env]
    if project:
        cmd += ["--project", project]
    cmd += ["log", "search.keywords_stream"]
    process_timeout = max(
        30, math.ceil(request.get("timeout_in_ms", 2000) / 1000) + 30
    )
    try:
        result = subprocess.run(
            cmd,
            input=input_json,
            capture_output=True,
            text=True,
            timeout=process_timeout,
        )
    except subprocess.TimeoutExpired as e:
        raise RuntimeError(
            f"argos tool timed out after {process_timeout}s"
        ) from e
    if result.returncode != 0:
        raise RuntimeError(
            f"argos tool failed (exit {result.returncode}): {result.stderr.strip()}"
        )

    stdout = result.stdout.strip()
    if not stdout:
        raise RuntimeError("argos tool returned empty output; query completion is unknown")

    try:
        data = json.loads(stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"argos tool returned invalid JSON: {e}") from e

    # Unwrap MCP envelope if present: {content:[{text:'...'}]}
    if "content" in data and isinstance(data.get("content"), list):
        text = data["content"][0].get("text", "{}")
        if data.get("isError"):
            raise RuntimeError(f"MCP returned isError=true: {text}")
        try:
            data = json.loads(text)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"MCP content returned invalid JSON: {e}") from e

    return data


def run_search(
    request: dict,
    max_pages: int | None,
    max_elapsed_seconds: float,
    max_logs: int = DEFAULT_MAX_LOGS,
    call_tool=call_argos_tool,
) -> tuple[list, dict]:
    """Fetch pages serially and return logs plus terminal pagination state."""
    env = request.pop("env", None)
    project = request.pop("project", None)

    all_logs = []
    cursor = request.get("cursor") or None
    previous_cursor = cursor
    page = 0
    less_data_times = 0
    resolved_enable_index = None
    legacy_profile = request.get("index_mode") == "legacy" or (
        "enable_index" in request and "index_mode" not in request
    )
    started_at = time.monotonic()
    stop_reason = None

    while max_pages is None or page < max_pages:
        if page > 0 and time.monotonic() - started_at >= max_elapsed_seconds:
            stop_reason = "elapsed_time_budget"
            break

        page += 1
        if cursor:
            request["cursor"] = cursor
        else:
            request.pop("cursor", None)

        if page == 1 and not legacy_profile:
            request.setdefault("limit", 100)
            request.setdefault("timeout_in_ms", 2000)
            request.setdefault("index_mode", "auto")
        elif page > 1 and not legacy_profile:
            request["limit"] = 1000 if resolved_enable_index else 200
            request["timeout_in_ms"] = min(
                60000, request["timeout_in_ms"] + 1000 * less_data_times
            )

        print(f"--- Page {page} ---", file=sys.stderr)
        try:
            data = call_tool(request, env=env, project=project)
        except RuntimeError as e:
            raise PaginationError(str(e), all_logs, cursor) from e

        logs = data.get("logs", [])
        cursor = data.get("cursor") or None
        finished = data.get("finished", False)

        if not legacy_profile:
            if "enable_index" in data:
                resolved_enable_index = bool(data["enable_index"])
            elif request.get("index_mode") == "on":
                resolved_enable_index = True
            elif resolved_enable_index is None:
                # enable_index is optional and may be omitted by OG response
                # filtering. The cursor still preserves the backend query plan.
                resolved_enable_index = False
                print(
                    "Notice: response omitted optional enable_index; "
                    "continuing with non-index pagination settings.",
                    file=sys.stderr,
                )

        all_logs.extend(logs)
        print(f"  Fetched {len(logs)} logs (total: {len(all_logs)})", file=sys.stderr)
        if not legacy_profile and len(logs) < request["limit"]:
            less_data_times += 1
        elif not legacy_profile:
            less_data_times = 0

        if finished:
            print(f"--- Done (finished=true, pages={page}) ---", file=sys.stderr)
            return all_logs, {
                "complete": True,
                "cursor": None,
                "pages": page,
                "stop_reason": "finished",
            }
        if len(all_logs) >= max_logs:
            stop_reason = "log_budget"
            break
        if not cursor:
            stop_reason = "missing_cursor"
            break
        if cursor == previous_cursor:
            stop_reason = "repeated_cursor"
            break

        previous_cursor = cursor
        print(f"  Cursor: {cursor[:50]}...", file=sys.stderr)

    if stop_reason is None:
        stop_reason = "page_budget"
    return all_logs, {
        "complete": False,
        "cursor": cursor,
        "pages": page,
        "stop_reason": stop_reason,
    }


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} '<json_input>' [max_pages]", file=sys.stderr)
        sys.exit(1)

    try:
        request = json.loads(sys.argv[1])
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        max_pages = int(sys.argv[2]) if len(sys.argv) > 2 else None
        max_elapsed_seconds = float(
            request.pop("max_elapsed_seconds", DEFAULT_MAX_ELAPSED_SECONDS)
        )
        max_logs = int(request.pop("max_logs", DEFAULT_MAX_LOGS))
        if (
            (max_pages is not None and max_pages <= 0)
            or max_elapsed_seconds <= 0
            or max_logs <= 0
        ):
            raise ValueError("budgets must be positive")
    except ValueError as e:
        print(f"Error: invalid pagination budget: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        all_logs, state = run_search(
            request, max_pages, max_elapsed_seconds, max_logs=max_logs
        )
    except PaginationError as e:
        print(f"Error: {e}", file=sys.stderr)
        if e.cursor:
            print(
                "Incomplete pagination: "
                + json.dumps({"stop_reason": "tool_error", "cursor": e.cursor}),
                file=sys.stderr,
            )
        json.dump(e.logs, sys.stdout)
        sys.exit(2)

    print(
        f"--- Total: {len(all_logs)} logs across {state['pages']} page(s) ---",
        file=sys.stderr,
    )
    if not state["complete"]:
        print(
            "Incomplete pagination: "
            + json.dumps(
                {
                    "stop_reason": state["stop_reason"],
                    "pages": state["pages"],
                    "cursor": state["cursor"],
                }
            ),
            file=sys.stderr,
        )
    json.dump(all_logs, sys.stdout)
    if not state["complete"]:
        sys.exit(3)


if __name__ == "__main__":
    main()
