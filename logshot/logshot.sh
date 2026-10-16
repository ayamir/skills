#!/usr/bin/env bash
# logshot — snapshot a Herdr pane's terminal output (no GUI needed).
#
# Works on macOS and on headless Linux. Rendering needs no display: freeze-cjk
# renders ANSI to SVG, rsvg-convert rasterizes the SVG to a high-DPI PNG.
# Install the dependencies with install.sh (see MAINTENANCE.md).
#
# Default output is SVG (vector): text is real <text>, rendered with the embedded
# CJK font, so Chinese/emoji never go blurry and can be scaled losslessly. A clean
# rose-pine dawn light background (#faf4ed) makes every pane render identically.
#
# Usage:
#   logshot <pane-id>                     # -> /tmp/herdr-log-<ts>.svg (default)
#   logshot <pane-id> -o out.svg --width 1200  # explicit width overrides pane size
#   logshot <pane-id> --clipboard        # also put a PNG on the clipboard (macOS: osascript; else OSC 5522)
#   logshot <pane-id> --png              # write a .png instead of .svg
#   logshot <pane-id> --renderer termshot  # use the (dark macOS-window) termshot-cjk instead
#   BG=#ffffff THEME=github-light FONT_FILE=/path.ttf LINES=200 logshot <pane-id>
#
# Web / non-terminal UI? Use a headless browser (chromium --headless --screenshot),
# not this. This only renders terminal/ANSI logs.
set -euo pipefail

command -v herdr >/dev/null || { echo "logshot: herdr CLI not found in PATH (it reads the pane)" >&2; exit 1; }

pane=${1:?usage: logshot <pane-id> [out.svg] [-o out.svg] [--clipboard] [--png] [--renderer termshot] [flags...]}; shift

out=""
clipboard=0
fmt="svg"
renderer="freeze"
render_flags=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    --clipboard) clipboard=1; shift ;;
    --png) fmt="png"; shift ;;
    --svg) fmt="svg"; shift ;;
    --renderer) renderer=$2; shift 2 ;;
    *)  render_flags+=("$1"); shift ;;
  esac
done

source=${SOURCE:-recent}
lines=${LINES:-120}
out=${out:-/tmp/herdr-log-$(date +%Y%m%d-%H%M%S)-$$}   # base name (PID avoids same-second collisions), extension added below

# CJK font: first hit in the same list install.sh uses. FONT_FILE overrides.
cjk_font=${FONT_FILE:-}
if [[ -z "$cjk_font" ]]; then
  for f in \
    "$HOME/Library/Fonts/MapleMonoNormal-NF-CN-Regular.ttf" \
    "$HOME/Library/Fonts/MapleMono-NF-CN-Regular.ttf" \
    "$HOME/.local/share/fonts/MapleMonoNormal-NF-CN-Regular.ttf" \
    "$HOME/.local/share/fonts/MapleMono-NF-CN-Regular.ttf" \
    /usr/share/fonts/maple-mono/MapleMonoNormal-NF-CN-Regular.ttf \
    /usr/local/share/fonts/maple-mono/MapleMonoNormal-NF-CN-Regular.ttf
  do [[ -f "$f" ]] && { cjk_font=$f; break; }; done
fi
[[ -f "$cjk_font" ]] || {
  echo "logshot: no CJK font found; run skills/logshot/install.sh or set FONT_FILE" >&2; exit 1; }
# The SVG <text> must name the font's REAL family so fontconfig/rsvg resolve it:
# the release ttf is `Maple Mono Normal NF CN`, the Homebrew cask is
# `Maple Mono NF CN`. The wrong name silently falls back to DejaVu (no CJK).
cjk_family=${FONT_FAMILY:-$(fc-scan --format '%{family[0]}' "$cjk_font" 2>/dev/null || true)}
if [[ -z "$cjk_family" ]]; then
  # No fontconfig: the two Maple variants report different family names.
  case "$(basename "$cjk_font")" in
    MapleMonoNormal-*) cjk_family="Maple Mono Normal NF CN" ;;
    *)                 cjk_family="Maple Mono NF CN" ;;
  esac
fi

tmp=$(mktemp /tmp/logshot-ansi.XXXXXX)
herdr pane read "$pane" --source "$source" --lines "$lines" --format ansi > "$tmp"

if [[ "$renderer" == "term" || "$renderer" == "termshot" ]]; then
  # termshot-cjk: patched termshot with --font-file (macOS window, dark). PNG only.
  tsbin=${TERMSHOT:-termshot-cjk}
  "$tsbin" --font-file "$cjk_font" --raw-read "$tmp" --filename "$out" "${render_flags[@]}"
else
  # freeze-cjk: always render to SVG (vector). If --png or --clipboard, we later
  # rasterize via chromium at high DPI for a crisp PNG.
  width_px=""
  _prev=""
  for a in "${render_flags[@]}"; do
    case "$a" in
      --width) width_px="" ;;  # next arg is width
      --width=*) width_px="${a#--width=}" ;;
      *) if [[ -z "$width_px" && "$_prev" == "--width" && "$a" =~ ^[0-9]+$ ]]; then width_px="$a"; fi ;;
    esac
    _prev="$a"
  done
  if [[ -z "$width_px" ]]; then
    pane_columns=$(herdr pane layout --pane "$pane" | jq -r --arg pane "$pane" '.result.layout.panes[] | select(.pane_id == $pane) | .rect.width')
    [[ "$pane_columns" =~ ^[0-9]+$ ]] || { echo "logshot: cannot determine pane width for $pane" >&2; exit 1; }
    # Maple Mono NF CN at the default 14px font occupies 8.4px per terminal column;
    # 40px supplies the two 20px horizontal margins used by freeze-cjk.
    width_px=$(awk -v columns="$pane_columns" 'BEGIN { print int(40 + columns * 8.4 + 0.999999) }')
  fi
  bg=${BG:-#faf4ed}            # rose-pine dawn base (warm off-white)
  theme=${THEME:-rose-pine-dawn}
  freeze_bin=${FREEZE:-freeze-cjk}
  # Always render to SVG; extensions are handled below so `--png`/`--clipboard`
  # get a crisp rasterized PNG and default gets a clean `.svg`.
  base="${out%.*}"                    # strip any extension the user passed
  svg_out="$base.svg"
  "$freeze_bin" --font.file "$cjk_font" --font.family "$cjk_family" \
    --background "$bg" --theme "$theme" --width "$width_px" \
    -o "$svg_out" "${render_flags[@]}" < "$tmp" >/dev/null 2>&1
  out="$svg_out"
fi

rm -f "$tmp"

# Locate a chromium/Chrome binary: not on PATH after a macOS `brew install
# --cask chromium` (the app lives in /Applications).
chromium_bin() {
  local c
  for c in chromium chromium-browser google-chrome \
           /Applications/Chromium.app/Contents/MacOS/Chromium \
           "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
    if [[ "$c" == /* ]]; then [[ -x "$c" ]] && { printf '%s' "$c"; return 0; }
    else command -v "$c" >/dev/null && { printf '%s' "$c"; return 0; }; fi
  done
  return 1
}

# Convert an SVG to a PNG at high DPI. rsvg-convert is the preferred rasterizer:
# it's fast, stable on large SVG, and -w scales from the vector (lossless, not
# blurry). Chromium is the fallback, ImageMagick last.
svg_to_png() {
  local svg="$1" out="$2"
  local w h
  if command -v rsvg-convert >/dev/null; then
    # Avoid `head` SIGPIPE under set -euo pipefail (which aborts the function):
    # read the width line first, then parse integer.
    w=$(grep -oE 'width="[0-9.]+' "$svg" | grep -oE '[0-9.]+' || true)
    w=${w%%.*}; w=${w:-1200}; w=$(printf '%d' "${w:-0}" 2>/dev/null || echo 1200)
    scale=${SCALE:-2}
    rsvg-convert -w "$((w*scale))" "$svg" -o "$out" >/dev/null 2>&1 && [[ -s "$out" ]] && return 0
  fi
  local chrome
  if chrome=$(chromium_bin); then
    w=$(grep -oE 'width="[0-9.]+' "$svg" | grep -oE '[0-9.]+' || true)
    h=$(grep -oE 'height="[0-9.]+' "$svg" | grep -oE '[0-9.]+' || true)
    w=${w%%.*}; h=${h%%.*}   # drop decimal: window-size needs integers
    w=${w:-1200}; h=${h:-200}
    scale=${SCALE:-2}
    "$chrome" --headless=new --disable-gpu --no-sandbox \
      --screenshot="$out" --window-size="$w,$h" \
      --force-device-scale-factor="$scale" \
      --default-background-color=00000000 "file://$svg" >/dev/null 2>&1 || true
    [[ -s "$out" ]] && return 0
  fi
  convert -background white "$svg" "$out"
}

# If --png was requested and we produced an SVG, rasterize it to a crisp PNG via
# chromium at high DPI (not a blurry upscale — the SVG is vector).
if [[ "$fmt" == "png" && "$out" == *.svg ]]; then
  png="${out%.svg}.png"
  svg_to_png "$out" "$png"
  out="$png"
fi

# Push a PNG to the clipboard.
#
# macOS: `--clipboard` writes the image with osascript — the clipboard is local,
# no escape sequence and no terminal support needed.
#
# Linux/remote: OSC 5522 (Kitty's streaming, multi-type, acknowledged clipboard
# protocol) via tty7-clip.py. It carries the image as image/png and — critically
# — herdr only intercepts standard OSC 52, so OSC 5522 passes straight through
# herdr to the local tty7 terminal. Standard OSC 52 (text-only) is the fallback.
# LOGSHOT_CLIPBOARD=native|osc forces one method (default: native on macOS).
#
# LOGSHOT_DEBUG=1 adds per-step diagnostics (each emits one line to stderr).
if [[ "$clipboard" == 1 ]]; then
  dbg() { [[ "${LOGSHOT_DEBUG:-0}" == "1" ]] && echo "  [logshot-debug] $*" >&2; return 0; }
  dbg "clipboard start"
  src="$out"
  if [[ "$out" == *.svg ]]; then
    cb="${out%.svg}-clip.png"
    dbg "rasterize SVG -> $cb"
    svg_to_png "$out" "$cb"
    if [[ -s "$cb" ]]; then
      dbg "svg_to_png OK: $(wc -c <"$cb" | tr -d ' ') bytes"
    else
      dbg "svg_to_png FAILED: no file"
    fi
    src="$cb"
  fi
  method=${LOGSHOT_CLIPBOARD:-$([[ "$(uname -s)" == Darwin ]] && echo native || echo osc)}
  if [[ "$method" == native ]] && command -v osascript >/dev/null; then
    if [[ "$src" != *.png ]]; then
      echo "logshot: --clipboard needs a PNG; no rasterizer (rsvg-convert) available" >&2
    else
      dbg "osascript: set clipboard from $src"
      osascript -e "set the clipboard to (read (POSIX file \"$src\") as «class PNGf»)" \
        && dbg "macOS clipboard set" || echo "logshot: clipboard write failed" >&2
    fi
  elif command -v tty7-clip.py >/dev/null; then
    dbg "emit OSC 5522 via tty7-clip.py for $src"
    # The OSC 5522 frames go to logshot's stderr (via >&2, so stdout stays a
    # clean path). Do NOT let a write hiccup abort the whole script under
    # set -e -u -o pipefail; the path must always be printed below.
    # Only the OSC 5522 frames should reach the pane stderr/PTY. Any other text
    # (freeze WROTE, echo notes) mixed between frames confuses tty7's frame
    # parser and makes it reconstruct the image from a subset -> wrong size.
    python3 "$(command -v tty7-clip.py)" "$src" >&2 || true
    dbg "OSC 5522 emitted"
  else
    dbg "tty7-clip.py MISSING -> fallback OSC 52"
    # `base64 -w0` is GNU-only; strip the newlines instead (BSD/macOS base64).
    printf '\033]52;c;%s\a' "$(base64 < "$src" | tr -d '\n')" >&2
    echo "logshot: PNG pushed via OSC 52 to client clipboard (${src})..." >&2
  fi
fi

# Agent-friendly: stdout carries ONLY the clean path, so `$(logshot ...)` stays clean.
printf '%s\n' "$out"
