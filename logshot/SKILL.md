---
name: logshot
description: "Snapshot a Herdr pane's terminal output as an image on a headless/no-GUI box, with correct CJK/Chinese + Nerd Font glyphs. Use when the user wants a screenshot or visual evidence of logs, terminal output, or a running process ('截图', 'screenshot the logs'). Requires HERDR_ENV=1. For browser/Web UI screenshots use chromium headless instead."
---

# Logshot

Renders a Herdr pane's ANSI output to an image with no display server, no X, no
Xvfb. Rose-pine dawn light backdrop so every pane comes out on the same clean
off-white; Maple Mono NF CN so CJK and Nerd Font icons render correctly.

## Steps

1. Locate the pane:
   ```bash
   herdr pane list --workspace "$HERDR_WORKSPACE_ID"
   ```
2. Confirm the pane already holds what the shot must show:
   ```bash
   herdr pane read <pane-id> --source recent --lines 120
   herdr pane wait-output <pane-id> --match "<expected text>" --timeout 30000
   ```
   Done when the target text is visible in the pane.
3. Shoot:
   ```bash
   logshot <pane-id> --clipboard        # or just: logshot <pane-id>
   ```
4. Report the log text, the path `logshot` printed on stdout, and whether it
   reached the clipboard.

## Options

- default → **SVG path on stdout**; vector, so text stays crisp at any zoom.
- `--clipboard` → also writes the PNG to the user's local clipboard (OSC 5522).
  stdout still carries only the SVG path; the payload goes to stderr.
- `--png` → high-DPI PNG instead of SVG.
- `SOURCE=visible` → the rendered viewport instead of recent scrollback.
- `LINES=40` → fewer lines.
- `--renderer termshot` → dark macOS-window frame (termshot-cjk).
- `--width <px>` → pins the canvas width. Width is otherwise derived from the
  live pane columns and current font metrics, so leave it unset.

Launcher source: `logshot.sh`. Install, dependencies, and the herdr OSC 5522
patch: [`MAINTENANCE.md`](MAINTENANCE.md).

## Web UI instead of a terminal

`logshot` renders terminal/ANSI text. A dashboard or Web UI on the remote box is
a headless chromium job:

```bash
chromium --headless=new --disable-gpu --window-size=1600,1200 \
  --screenshot=/tmp/ui.png "http://127.0.0.1:9090/"
```
