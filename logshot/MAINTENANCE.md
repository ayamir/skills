# Logshot maintenance

Install, dependencies, and the herdr patch that makes `--clipboard` work.

## Install

```bash
bash ~/.agents/skills/logshot/install.sh              # full install
TERMSHOT=0 bash ~/.agents/skills/logshot/install.sh   # skip optional termshot-cjk
```

Installs `rsvg-convert` + `chromium` (apt), `fonttools` (pip), Maple Mono NF CN,
builds `freeze-cjk` (+ optional `termshot-cjk`), and puts `logshot` in `~/.local/bin`.

## Dependencies

| Component | Why | Install |
|---|---|---|
| `logshot` | the launcher | `install.sh` copies `logshot.sh` |
| `freeze-cjk` | ANSI→SVG with CJK | Go build of patched freeze |
| `rsvg-convert` | SVG→high-DPI PNG (2x) | `librsvg2-bin` (apt) |
| `chromium` | fallback rasterizer | apt |
| Maple Mono NF CN | CJK + Nerd Font glyphs | `/usr/share/fonts/maple-mono/...ttf` |
| `fonttools` (optional) | font conversion/verify | pip |
| `herdr` | reads pane output | herdr env (`HERDR_ENV=1`) |

## Files

```
skills/logshot/
  SKILL.md            # the skill
  MAINTENANCE.md      # this file
  install.sh          # one-shot install of logshot + dependencies
  logshot.sh          # the launcher (authoritative source)
  freeze-cjk.sh       # builds patched Freeze (CJK) -> freeze-cjk
  freeze-cjk.patch
  termshot-cjk.sh     # optional: patched termshot -> termshot-cjk
  termshot-cjk.patch
  tty7-clip.py        # image -> OSC 5522 frames (used by --clipboard)
  herdr-osc5522.patch # herdr: forward OSC 5522 to the local terminal
```

## Clipboard path (OSC 5522)

`--clipboard` ships the image over **OSC 5522**, Kitty's streaming, acknowledged,
image-aware clipboard protocol (carries `image/png` in chunks). tty7 supports it
natively — no tty7 patch. Terminals without OSC 5522 fall back to OSC 52
(text/base64 only, and herdr may swallow it).

herdr **does** need `herdr-osc5522.patch`: its ghostty core drops unknown OSC
sequences, so herdr must strip the frames out of the PTY stream in
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
