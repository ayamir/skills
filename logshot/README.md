# Logshot — design rationale & how it was built

This is the "why" behind logshot: the problem it solves, the alternatives
rejected, and the non-obvious bugs that shaped each layer. For how to *use* it
see [`SKILL.md`](SKILL.md); for install/deps/patches see
[`MAINTENANCE.md`](MAINTENANCE.md).

## The problem

A headless remote dev box has no display server and no clipboard. An agent needs
to turn a Herdr pane's terminal/log output into an image — as evidence for a
ticket, a chat message, a review. Naively "screenshot" is impossible (no X, no
Xvfb), and the image must eventually land on the *user's local machine* clipboard
(here a Mac running the `tty7` terminal, connected over SSH).

So the real requirements, each of which turned out to be a distinct problem:

1. Render ANSI terminal text to an image with **no display**.
2. Render **Chinese/emoji** correctly (the default toolchain renders tofu).
3. Look like a **real terminal screenshot**, not a flat black block.
4. Push the image to the **local clipboard** through a terminal multiplexer.
5. Produce a **correct-size, clean** result — no trash characters, no hang.

## Alternatives that were considered, and why not

| Tool | Verdict |
|---|---|
| `scrot`/`import`/`xwd` | Need an X display — N/A on a headless box. |
| ImageMagick `convert` | Rasterizes text but CJK via fontconfig is unreliable; `@file` reads are blocked by policy. |
| `cairosvg` | Ignores embedded SVG `@font-face`, drops CJK glyphs. |
| `chromium --headless` | Best for Web UI, not for ANSI terminal text. |
| `asciinema`/`svg-term` | Animations/asciicast, not still-frame log evidence. |
| `termframe` / `termshot` | Nice window chrome, but both hardcode fonts with **no CJK** and no way to inject one (termshot embeds `font.Hack`; termframe ships only JetBrains/Cascadia/Symbols). |

**Freeze (charmbracelet)** was chosen: it renders ANSI → SVG (vector), supports
24-bit color, and its PNG path is rasterized by resvg. The catch: it can't render
CJK out of the box.

## Layer 1 — CJK: patching Freeze

Freeze's ANSI→PNG path builds an SVG, then resvg rasterizes it. `fontOptions`
embeds `--font.file` into the SVG, **but** `resvgConvert` only calls
`fontdb.LoadFontData(font.JetBrainsMonoTTF/NL)` — the *embedded* JetBrains Mono.
The user's `--font.file` is never loaded into resvg's font database, so CJK glyphs
fall back to JetBrains Mono → tofu.

**Fix** (in `freeze-cjk.patch`): in `resvgConvert`, also
`fontdb.LoadFontData(os.ReadFile(config.Font.File))` and treat `.ttc` as a
`TRUETYPE` format. This let a real CJK font actually render.

## Layer 2 — the right font

`Maple Mono NF CN` was picked: monospace with **both** CJK *and* Nerd Font icons.
The critical gotcha: its real family name is **`Maple Mono Normal NF CN`**, not
`Maple Mono NF CN`. Passing the wrong name makes rsvg/fontconfig fall back to
DejaVu Sans (thin, non-monospace). Always use the name `fc-match` returns.

## Layer 3 — uniform, attractive output

rose-pine dawn (`#faf4ed` base) + `rose-pine-dawn` theme gives every pane the
same clean off-white backdrop, so a shot of pane A and pane B look consistent
instead of inheriting whatever ANSI colors each pane emits.

## Layer 4 — SVG stays crisp; PNG needs high DPI

SVG is vector (crisp at any zoom), so the default output is SVG. When a PNG is
needed it is rasterized with **rsvg-convert at 2×** — a lossless vector upscale,
not a blurry pixel resize. A real bug here: the launcher wrote
`w=${w%%%.*}` (three `%`) instead of `w=${w%%.*}` (two `%`), so the width stayed
`1200.00`, `$((w*2))` hit "invalid arithmetic", and every PNG silently fell back
to Freeze's default **1000×386**.

## Layer 5 — getting the image to the local clipboard

The remote box has no clipboard, so the image must travel over the SSH stream as
an escape sequence that the *local terminal* interprets and places in its
clipboard.

**OSC 52** is the "standard" clipboard escape, but it is text/base64 only and, in
this environment, **herdr intercepts it** (herdr treats OSC 52 as a clipboard
write it owns). **OSC 5522** is Kitty's streaming, acknowledged, image-aware
clipboard protocol — it carries `image/png` in chunks, and crucially **herdr does
not recognize it**, so it passes straight through to the outer terminal. tty7
supports OSC 5522 natively (its `remote_clipboard_write` setting), so **no tty7
patch is needed**.

## Layer 6 — herdr swallows unknown OSC sequences

herdr runs a ghostty terminal core to model each pane. ghostty, seeing an OSC it
doesn't know (`5522`), **silently drops it** — so the frames never reach tty7.
`logshot --clipboard` appeared to do nothing.

**Fix** (in `herdr-osc5522.patch`): in `process_pty_bytes`, strip `ESC ] 5522 …`
sequences out of the byte stream *before* feeding ghostty, collect them as
`osc5522_writes`, and forward each as a new `ServerMessage::Osc5522` to the
foreground client, which writes the raw bytes to stdout → the outer tty7.

## Layer 7 — cross-chunk state machine

Two sibling bugs that only showed up under real traffic:

- PTY reads arrive in ~4 KB slices, but each OSC 5522 frame is ~5.5 KB, so
  **every frame straddles a chunk boundary**. The first strip logic only scanned
  for the terminator at the *tail* of the pending buffer, so a frame whose
  `ESC \` landed mid-chunk was never closed → the remainder leaked as visible
  text and `in_frame` got stuck.
- After a frame closes, the scan index must advance past **both** bytes of
  `ESC \`. Consuming only `ESC` re-emits the `\` — the symptom is runs of
  `\\\\\`.

The final state machine scans the **whole** pending buffer for `ESC \` / `BEL`,
drains the closed frame, keeps any remainder, and correctly resets `in_frame`. It
handles multiple frames per chunk and text immediately after a frame.

## Layer 8 — a clean, uncorrupted frame stream

The last "makes the image wrong" bug was noise: the launcher sent the SVG's
`WROTE` log and an `echo` note on **stderr**, interleaved with the OSC 5522
frames. tty7's frame parser, seeing a non-frame character between frames,
reconstructed the image from a subset → **1000×386** instead of 2400×4164.

Fix: make Freeze silent (`>/dev/null`), drop the `echo` notes, and make
`tty7-clip.py` silent on stderr. **stdout carries nothing but the SVG path;
stderr carries nothing but frames.** Any other text between frames corrupts the
reconstruction.

## The finished pipeline

```
herdr pane read
  → freeze-cjk  (Maple Mono Normal NF CN + rose-pine dawn)  → SVG (vector)
  → rsvg-convert 2×                                          → high-DPI PNG
  → tty7-clip.py (OSC 5522, clean frames, image/png chunks)  → stderr
  → herdr strips + forwards OSC 5522                          → foreground client
  → tty7                                                      → local clipboard
```

## What the agent actually calls

```
logshot <pane-id>          # → SVG path on stdout
logshot <pane-id> --clipboard   # → also write the image to the local clipboard
```

Everything else — font family, theme, SVG→PNG, OSC 5522 framing, herdr
stripping, dimensions — is hidden behind those two commands.
