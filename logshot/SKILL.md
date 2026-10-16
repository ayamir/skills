---
name: logshot
description: "Snapshot a Herdr pane's terminal output as an image (SVG or high-DPI PNG) with correct CJK/Chinese + Nerd Font glyphs. Works on macOS and on a headless Linux box — no display server needed. Use when the user wants a screenshot or visual evidence of logs, terminal output, test results, or a running process ('截图', 'screenshot the logs'). Reads Herdr panes; for browser/Web UI screenshots use chromium headless instead."
---

# Logshot

Renders a Herdr pane's ANSI output to an image with no display server, no X, no
Xvfb — on macOS or on a headless Linux box. Rose-pine dawn light backdrop so
every pane comes out on the same clean off-white; Maple Mono NF CN so CJK and
Nerd Font icons render correctly.

## Setup (once per machine)

```bash
bash ~/.agents/skills/logshot/install.sh
```

Installs `logshot` into `~/.local/bin` and every dependency below. Use
`TERMSHOT=0` to skip the optional alt renderer, `CHROMIUM=1` to also install
chromium, `FONT=0` to skip the font.

| Dependency | Why | macOS | Debian/Ubuntu |
|---|---|---|---|
| `rsvg-convert` (librsvg) | SVG → high-DPI PNG (the only rasterizer) | `brew install librsvg` | `apt install librsvg2-bin` |
| Maple Mono NF CN | CJK + Nerd Font glyphs (else tofu) | `brew install --cask font-maple-mono-nf-cn` | release zip → `~/.local/share/fonts` |
| `go` | builds `freeze-cjk` from `freeze-cjk.patch` | `brew install go` | `apt install golang` |
| `jq` | pane geometry (`herdr pane layout`) → canvas width | `brew install jq` | `apt install jq` |
| `herdr` | reads the pane (`herdr pane read`) | `brew install herdr` | — |
| `chromium` (optional) | last-resort rasterizer, Web UI shots | `brew install --cask chromium` | `apt install chromium` |

If the image shows blank boxes instead of Chinese, the font family did not
resolve: check `fc-scan --format '%{family}' ~/Library/Fonts/Maple*Regular.ttf`
and pass `FONT_FAMILY=...` — the release ttf is `Maple Mono Normal NF CN`, the
Homebrew cask is `Maple Mono NF CN`.

## First-pass evidence workflow

1. Locate the pane and set its final geometry before producing evidence:
   ```bash
   herdr pane list                       # add --workspace "$HERDR_WORKSPACE_ID" inside Herdr
   ```
   Make the pane wide enough for the command and key output. Resizing after the
   output was printed does not reliably repair its old soft wraps; rerun the
   evidence command after the final geometry is set.
2. Produce first-hand evidence in that pane. Print a start marker containing the
   case ID and environment, run the exact command, then print a unique completion
   marker. The captured region must show the command, key input/environment, and
   actual service output or assertion. Do not substitute a prose summary.
3. Wait for completion, then inspect exactly what will be rendered:
   ```bash
   herdr pane wait-output <pane-id> --match "<completion-marker>" --timeout 30000
   herdr pane read <pane-id> --source recent --lines 120
   ```
   Do not shoot until the command, input/environment, output/assertion, and
   completion marker are all visible without horizontal truncation.
4. Capture while preserving the pane's rendered soft wraps:
   ```bash
   logshot <pane-id> --png        # when the deliverable requires PNG
   logshot <pane-id>              # otherwise, SVG
   ```
   Keep the default `SOURCE=recent` and omit `--width`: the launcher derives the
   canvas width from the live Herdr pane columns. Never guess a fixed pixel width.
5. Check the resulting image before reporting it. Verify that its right edge is
   not clipped and that the command, environment/input, and first-hand result are
   readable. Report the path printed on stdout; mention clipboard delivery only
   when `--clipboard` was requested.

If the image is clipped or wrapped poorly, widen the pane, rerun the evidence
command, wait for its completion marker, and capture again without `--width`.
Increase `LINES` only when vertical history is missing; it cannot fix horizontal
geometry.

## Options

- default → **SVG path on stdout**; vector, so text stays crisp at any zoom.
- `--clipboard` → also puts the PNG on the clipboard: on macOS via `osascript`
  (local clipboard, no terminal support needed); elsewhere via OSC 5522 through
  the terminal. stdout still carries only the SVG path.
- `--png` → high-DPI PNG instead of SVG.
- `SOURCE=visible` → the rendered viewport instead of recent scrollback.
- `LINES=40` → fewer lines.
- `--renderer termshot` → dark macOS-window frame (termshot-cjk).
- `--width <px>` → pins the canvas width. Width is otherwise derived from the
  live pane columns and current font metrics, so leave it unset.

Launcher source: `logshot.sh`. Install, dependencies, and the herdr OSC 5522
patch: [`MAINTENANCE.md`](MAINTENANCE.md).

The rationale behind each layer and the non-obvious bugs that shaped it:
[`README.md`](README.md).

## Web UI instead of a terminal

`logshot` renders terminal/ANSI text. A dashboard or Web UI on the remote box is
a headless chromium job:

```bash
chromium --headless=new --disable-gpu --window-size=1600,1200 \
  --screenshot=/tmp/ui.png "http://127.0.0.1:9090/"
```

On macOS the cask binary is not on PATH:
`/Applications/Chromium.app/Contents/MacOS/Chromium`.
