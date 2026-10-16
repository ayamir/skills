# Logshot maintenance

Install, dependencies, and the herdr patch that makes `--clipboard` work over a
remote terminal.

For the design rationale and the bugs behind each layer, see
[`README.md`](README.md).

## Install

```bash
bash ~/.agents/skills/logshot/install.sh              # full install (macOS or Debian/Ubuntu)
TERMSHOT=0 bash ~/.agents/skills/logshot/install.sh   # skip the optional termshot-cjk
CHROMIUM=1 bash ~/.agents/skills/logshot/install.sh   # also install chromium (optional)
FONT=0 bash ~/.agents/skills/logshot/install.sh       # skip the font install
```

Installs `logshot` + `jq` + `rsvg-convert` (brew on macOS, apt on Debian/Ubuntu),
Maple Mono NF CN, and builds `freeze-cjk` (+ optional `termshot-cjk`) into
`~/.local/bin`.

## Dependencies

| Component | Why | macOS | Debian/Ubuntu |
|---|---|---|---|
| `logshot` | the launcher | `install.sh` copies `logshot.sh` | same |
| `freeze-cjk` | ANSI→SVG with CJK | Go build of patched freeze (`brew install go`) | `apt install golang` |
| `rsvg-convert` | SVG→high-DPI PNG (2×) | `brew install librsvg` | `apt install librsvg2-bin` |
| `jq` | reads pane geometry for the canvas width | `brew install jq` | `apt install jq` |
| Maple Mono NF CN | CJK + Nerd Font glyphs (else tofu) | `brew install --cask font-maple-mono-nf-cn` → `~/Library/Fonts/MapleMono-NF-CN-Regular.ttf` | release zip → `~/.local/share/fonts/` or `/usr/share/fonts/maple-mono/` |
| `fonttools` (optional) | font conversion/verify | `pip3 install --user fonttools` | same |
| `chromium` (optional) | fallback rasterizer, Web UI shots | `brew install --cask chromium` (binary in `/Applications`, not on PATH) | `apt install chromium` |
| `herdr` | reads pane output (`herdr pane read`, `herdr pane layout`) | `brew install herdr` | — |

`logshot.sh` finds the font by walking the same candidate list `install.sh`
uses (`FONT_FILE` overrides) and takes the family name from
`fc-scan` — the release ttf is `Maple Mono Normal NF CN`, the Homebrew cask is
`Maple Mono NF CN`. Pin it with `FONT_FAMILY` if `fc-scan` is unavailable.

## Files

```
skills/logshot/
  SKILL.md            # the skill
  MAINTENANCE.md      # this file
  install.sh          # one-shot install of logshot + dependencies (macOS/Linux)
  logshot.sh          # the launcher (authoritative source)
  freeze-cjk.sh       # builds patched Freeze (CJK) -> freeze-cjk
  freeze-cjk.patch
  termshot-cjk.sh     # optional: patched termshot -> termshot-cjk
  termshot-cjk.patch
  tty7-clip.py        # image -> OSC 5522 frames (used by --clipboard)
  herdr-osc5522.patch # herdr: forward OSC 5522 to the local terminal
```

## Clipboard path

**macOS (local).** `--clipboard` rasterizes the SVG and sets the clipboard with
`osascript -e 'set the clipboard to (read (POSIX file "…") as «class PNGf»)'`.
The clipboard is local, so no escape sequence, no terminal support, and no herdr
patch is involved. `LOGSHOT_CLIPBOARD=osc` forces the protocol path below.

**Linux / remote (OSC 5522).** `--clipboard` ships the image over **OSC 5522**,
Kitty's streaming, acknowledged, image-aware clipboard protocol (carries
`image/png` in chunks). tty7 supports it natively — no tty7 patch. Terminals
without OSC 5522 fall back to OSC 52 (text/base64 only).

herdr **does** need `herdr-osc5522.patch` for that path: its ghostty core drops
unknown OSC sequences, so herdr must strip the frames out of the PTY stream in
`process_pty_bytes` and forward them to the foreground client. Two details that
caused real bugs:

- Frames are ~5.5 KB, PTY reads ~4 KB, so **every frame straddles a chunk
  boundary**. Unterminated tails (partial frame, or partial `ESC]5522;` header)
  live in `pending_osc5522` and get re-scanned with the next chunk.
- After a frame's `ESC \` terminator the scan index must advance past **both**
  bytes. Consuming only the `ESC` re-emits `\` as visible text — symptom is runs
  of `\\\\\\` in the pane.

Rebuild with `cargo build --release` in the herdr checkout, then swap without
losing the session:

```bash
herdr live-handoff /path/to/new/herdr
```
