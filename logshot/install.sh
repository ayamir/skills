#!/usr/bin/env bash
# install.sh — install the `logshot` snapshot tool and its dependencies.
#
# macOS (Homebrew) and Debian/Ubuntu (apt) are supported.
#
# Installs (to ~/.local/bin unless BINDIR overrides):
#   - system deps: rsvg-convert (librsvg) to rasterize the SVG to a crisp PNG
#   - Maple Mono NF CN font (CJK + Nerd Font glyphs; tofu without it)
#   - freeze-cjk: patched Freeze (CJK + Nerd Font) built from this dir's patch
#   - termshot-cjk: OPTIONAL patched termshot (dark macOS-window alt renderer)
#   - logshot: the launcher script (this dir's logshot.sh -> BINDIR/logshot)
#   - tty7-clip.py: OSC 5522 clipboard frames (used by --clipboard off macOS)
#
# Usage:
#   bash install.sh                      # full install
#   TERMSHOT=0 bash install.sh           # skip the optional termshot-cjk
#   CHROMIUM=1 bash install.sh           # also install chromium (Web UI shots)
#   FONT=0 bash install.sh               # skip the font install
#   BINDIR=/tmp bash install.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BINDIR="${BINDIR:-$HOME/.local/bin}"
OS="$(uname -s)"
mkdir -p "$BINDIR"

# Font candidates, first hit wins. Keep in sync with logshot.sh.
FONT_CANDIDATES=(
  "$HOME/Library/Fonts/MapleMonoNormal-NF-CN-Regular.ttf"      # macOS, release ttf
  "$HOME/Library/Fonts/MapleMono-NF-CN-Regular.ttf"            # macOS, brew cask
  "$HOME/.local/share/fonts/MapleMonoNormal-NF-CN-Regular.ttf" # Linux, user
  "$HOME/.local/share/fonts/MapleMono-NF-CN-Regular.ttf"
  /usr/share/fonts/maple-mono/MapleMonoNormal-NF-CN-Regular.ttf
  /usr/local/share/fonts/maple-mono/MapleMonoNormal-NF-CN-Regular.ttf
)
find_font() { local f; for f in "${FONT_CANDIDATES[@]}"; do [[ -f "$f" ]] && { printf '%s' "$f"; return 0; }; done; return 1; }

echo "==> Installing logshot to $BINDIR ($OS)"

# ---------------------------------------------------------------------------
# 1. rsvg-convert (librsvg) — the SVG -> high-DPI PNG rasterizer
# ---------------------------------------------------------------------------
if ! command -v rsvg-convert >/dev/null; then
  if [[ "$OS" == "Darwin" ]]; then
    echo "==> brew install librsvg (provides rsvg-convert)"
    brew install librsvg
  else
    echo "==> apt install librsvg2-bin (provides rsvg-convert)"
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -qq 2>/dev/null || apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq librsvg2-bin 2>/dev/null || apt-get install -y -qq librsvg2-bin
  fi
fi

# ---------------------------------------------------------------------------
# 2. jq — reads the pane geometry (herdr pane layout) to size the canvas
# ---------------------------------------------------------------------------
if ! command -v jq >/dev/null; then
  if [[ "$OS" == "Darwin" ]]; then
    echo "==> brew install jq"
    brew install jq
  else
    sudo apt-get install -y -qq jq 2>/dev/null || apt-get install -y -qq jq
  fi
fi

# ---------------------------------------------------------------------------
# 3. chromium — OPTIONAL: last-resort rasterizer + headless Web UI screenshots
# ---------------------------------------------------------------------------
if [[ "${CHROMIUM:-0}" == "1" ]] && ! command -v chromium >/dev/null \
   && [[ ! -x "/Applications/Chromium.app/Contents/MacOS/Chromium" ]]; then
  if [[ "$OS" == "Darwin" ]]; then
    echo "==> brew install --cask chromium"
    brew install --cask chromium
  else
    echo "==> apt install chromium"
    sudo apt-get install -y -qq chromium 2>/dev/null || apt-get install -y -qq chromium
  fi
fi

# ---------------------------------------------------------------------------
# 4. Python fonttools — optional convenience for font inspection
# ---------------------------------------------------------------------------
if ! python3 -c "import fontTools" 2>/dev/null; then
  echo "==> installing fonttools (optional)..."
  python3 -m pip install --quiet --break-system-packages fonttools 2>/dev/null \
    || python3 -m pip install --quiet --user fonttools 2>/dev/null \
    || echo "    (skipped: pip unavailable; not needed by logshot itself)"
fi

# ---------------------------------------------------------------------------
# 5. Maple Mono NF CN — CJK + Nerd Font glyphs
# ---------------------------------------------------------------------------
if [[ "${FONT:-1}" == "1" ]] && ! find_font >/dev/null; then
  if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null \
     && brew install --cask font-maple-mono-nf-cn; then
    : # brew installs ~/Library/Fonts/MapleMono-NF-CN-Regular.ttf
  else
    # Release zip (unhinted family). macOS installs into ~/Library/Fonts (no
    # sudo); Linux tries the system font dir, else the user font dir.
    if [[ "$OS" == "Darwin" ]]; then
      FONT_DIR="$HOME/Library/Fonts"
      FONT_PATH="$FONT_DIR/MapleMonoNormal-NF-CN-Regular.ttf"
    elif [[ -w /usr/share/fonts || "$(id -u)" == "0" ]]; then
      FONT_DIR="/usr/share/fonts/maple-mono"
      FONT_PATH="$FONT_DIR/MapleMonoNormal-NF-CN-Regular.ttf"
    else
      FONT_DIR="$HOME/.local/share/fonts"
      FONT_PATH="$FONT_DIR/MapleMonoNormal-NF-CN-Regular.ttf"
    fi
    echo "==> fetching Maple Mono NF CN -> $FONT_DIR"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/maple.zip" \
      "https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMonoNormal-NF-CN-unhinted.zip"
    unzip -oq "$tmp/maple.zip" -d "$tmp"
    mkdir -p "$FONT_DIR"
    cp "$tmp/MapleMonoNormal-NF-CN-Regular.ttf" "$FONT_PATH"
    rm -rf "$tmp"
    # Tell fontconfig to rescan so rsvg-convert resolves the family right away.
    command -v fc-cache >/dev/null && fc-cache -f >/dev/null 2>&1 || true
  fi
fi

# ---------------------------------------------------------------------------
# 6. freeze-cjk (patched Freeze). Build from this dir's script + patch.
# ---------------------------------------------------------------------------
if ! command -v freeze-cjk >/dev/null; then
  command -v go >/dev/null || {
    echo "error: go is required to build freeze-cjk (brew install go / apt install golang)" >&2
    exit 1
  }
  echo "==> building freeze-cjk..."
  FREEZE_PATCH="$HERE/freeze-cjk.patch" BINDIR="$BINDIR" bash "$HERE/freeze-cjk.sh"
fi

# ---------------------------------------------------------------------------
# 7. termshot-cjk (optional alt renderer). Skip with TERMSHOT=0.
# ---------------------------------------------------------------------------
if [[ "${TERMSHOT:-1}" == "1" ]] && ! command -v termshot-cjk >/dev/null; then
  echo "==> building termshot-cjk (optional)..."
  TERMSHOT_PATCH="$HERE/termshot-cjk.patch" BINDIR="$BINDIR" bash "$HERE/termshot-cjk.sh"
fi

# ---------------------------------------------------------------------------
# 8. logshot launcher — from this dir's logshot.sh.
# ---------------------------------------------------------------------------
if [[ -f "$HERE/logshot.sh" ]]; then
  chmod +x "$HERE/logshot.sh"
  cp "$HERE/logshot.sh" "$BINDIR/logshot"
else
  echo "==> logshot.sh not found alongside install.sh; expecting it to be provided."
  echo "    (The full source is embedded in SKILL.md.)"
fi
chmod +x "$BINDIR/logshot" 2>/dev/null || true

# tty7-clip.py: the OSC 5522 emitter used by --clipboard on Linux/remote. It
# must be on PATH next to logshot (the launcher calls it by name).
if [[ -f "$HERE/tty7-clip.py" ]]; then
  install -m 0755 "$HERE/tty7-clip.py" "$BINDIR/tty7-clip.py"
fi

# ---------------------------------------------------------------------------
# 9. Verify
# ---------------------------------------------------------------------------
FONT_PATH="$(find_font || true)"
FONT_FAMILY="$(fc-scan --format '%{family[0]}' "$FONT_PATH" 2>/dev/null || true)"
echo
echo "==> Verify:"
for t in logshot freeze-cjk rsvg-convert chromium; do
  printf '%-16s %s\n' "$t" "$(command -v $t || echo 'not installed (optional)')"
done
echo "font            ${FONT_PATH:-MISSING (run with FONT=1)}"
echo "font family     ${FONT_FAMILY:-unknown}"
echo
echo "Done. Usage: logshot <pane-id>  |  logshot <pane-id> --png  |  logshot <pane-id> --clipboard"
