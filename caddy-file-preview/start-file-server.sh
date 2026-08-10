#!/usr/bin/env bash
set -euo pipefail

: "${CADDY_FILE_PREVIEW_ROOT:?must point to the directory to serve}"
: "${CADDY_FILE_PREVIEW_PORT:=9080}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${CADDY_FILE_PREVIEW_STATE_DIR:-${CADDY_FILE_PREVIEW_ROOT}/.caddy-state}"
PID_FILE="$STATE_DIR/caddy.pid"
LOG_FILE="$STATE_DIR/caddy.log"
mkdir -p "$STATE_DIR"

if [[ ! -d "$CADDY_FILE_PREVIEW_ROOT" ]]; then
  echo "CADDY_FILE_PREVIEW_ROOT does not exist: $CADDY_FILE_PREVIEW_ROOT" >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Caddy file server already running with pid $(cat "$PID_FILE")"
  echo "URL: http://127.0.0.1:${CADDY_FILE_PREVIEW_PORT}/"
  exit 0
fi

export FILE_SERVER_ROOT="$CADDY_FILE_PREVIEW_ROOT"
export CADDY_TEMPLATE_ROOT="$SCRIPT_DIR/templates"
export CADDY_LISTEN_ADDR=":${CADDY_FILE_PREVIEW_PORT}"

nohup caddy run --config "$SCRIPT_DIR/Caddyfile" --adapter caddyfile >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

for _ in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:${CADDY_FILE_PREVIEW_PORT}/" >/dev/null 2>&1; then
    echo "Caddy file server started"
    echo "Root: $CADDY_FILE_PREVIEW_ROOT"
    echo "URL: http://127.0.0.1:${CADDY_FILE_PREVIEW_PORT}/"
    echo "PID: $(cat "$PID_FILE")"
    echo "Log: $LOG_FILE"
    exit 0
  fi
  sleep 0.25
done

echo "Caddy file server failed to start; see $LOG_FILE" >&2
exit 1
