---
name: caddy-file-preview
description: >
  Use this skill when the user wants to preview local files in a browser with
  Caddy: generated diagrams, reports, docs, or any static directory. Use when
  they ask to start Caddy, stop Caddy, serve a directory, or open a local
  browser preview.
license: MIT
metadata:
  author: trae-cli
  version: "1.0"
---

# Caddy File Preview

Serve a local directory through the bundled Caddy helper scripts and verify the
browser URL actually works.

**Failure pattern:** A helper may print "started" while no usable server is left
on the port. Caddy may also exit if its state directory is not writable.
**Verified by:** The bundled Caddyfile validated, and the proven runtime check is
`curl -I` returning `HTTP/1.1 200 OK` for the requested file.

## Procedure

- [ ] 1. Pick the smallest directory that contains the artifact to preview.

- [ ] 2. Start with the bundled script from this skill directory:

```bash
CADDY_FILE_PREVIEW_ROOT=/path/to/served-dir CADDY_FILE_PREVIEW_PORT=9080 CADDY_FILE_PREVIEW_STATE_DIR=/path/to/served-dir/.caddy-state XDG_CONFIG_HOME=/path/to/served-dir/.caddy-state/config XDG_DATA_HOME=/path/to/served-dir/.caddy-state/data ./start-file-server.sh
```

- [ ] 3. Verify the exact file URL, not just script output:

```bash
curl -I http://127.0.0.1:9080/path/to/file.svg
```

Completion means the requested file returns `HTTP/1.1 200 OK`.

- [ ] 4. Report the browser URL and served root.

- [ ] 5. Stop with the bundled script when the user asks:

```bash
CADDY_FILE_PREVIEW_ROOT=/path/to/served-dir CADDY_FILE_PREVIEW_STATE_DIR=/path/to/served-dir/.caddy-state ./stop-file-server.sh
```

## Gotchas

- The start script uses `nohup caddy run ... &`; always verify with `curl -I`.
- If Caddy logs read-only filesystem errors for autosave or storage, set
  `XDG_CONFIG_HOME` and `XDG_DATA_HOME` to writable directories.
- A stale pid file is not proof of a running server. Confirm with `curl -I`.
- If port `9080` is occupied, choose another port and verify that URL.

## Bundled Files

- `start-file-server.sh`
- `stop-file-server.sh`
- `Caddyfile`
- `templates/markdown.html`

## What Didn't Work

- Trusting a helper's "started" output without `curl -I`.
- Letting Caddy use default home-backed state in restricted environments.
