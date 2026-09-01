#!/usr/bin/env bash
# install.sh — install the `logshot` snapshot tool and its dependencies.
#
# Installs (to ~/.local/bin unless BINDIR overrides):
#   - system deps: rsvg-convert (librsvg2-bin), chromium, fonttools/py
#   - Maple Mono NF CN font: /usr/share/fonts/maple-mono/MapleMonoNormal-NF-CN-Regular.ttf
#   - freeze-cjk: patched Freeze (CJK + Nerd Font) built from this dir's patch
#   - termshot-cjk: OPTIONAL patched termshot (dark macOS-window alt renderer)
#   - logshot: the launcher script (this dir's logshot.sh -> ~/.local/bin/logshot)
#
# Usage:
#   sh install.sh            # full install
#   TERMSHOT=0 sh install.sh # skip the optional termshot-cjk
#   BINDIR=/tmp sh install.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BINDIR="${BINDIR:-$HOME/.local/bin}"
mkdir -p "$BINDIR"

echo "==> Installing logshot to $BINDIR"

# ---------------------------------------------------------------------------
# 1. System packages (apt): librsvg2-bin for rsvg-convert, chromium
# ---------------------------------------------------------------------------
if ! command -v rsvg-convert >/dev/null || ! command -v chromium >/dev/null; then
  echo "==> apt install rsvg-convert + chromium..."
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq 2>/dev/null || apt-get update -qq 2>/dev/null
  sudo apt-get install -y -qq librsvg2-bin chromium \
    2>/dev/null || apt-get install -y -qq librsvg2-bin chromium
fi

# ---------------------------------------------------------------------------
# 2. Python fonttools (used to verify/convert fonts; optional but handy)
# ---------------------------------------------------------------------------
if ! python3 -c "import fontTools" 2>/dev/null; then
  echo "==> installing fonttools..."
  python3 -m pip install --quiet --break-system-packages fonttools 2>/dev/null \
    || python3 -m pip install --quiet --user fonttools 2>/dev/null
fi

# ---------------------------------------------------------------------------
# 3. Maple Mono NF CN font (CJK + Nerd Font glyphs). If missing, fetch it.
# ---------------------------------------------------------------------------
FONT_PATH="/usr/share/fonts/maple-mono/MapleMonoNormal-NF-CN-Regular.ttf"
if [[ ! -f "$FONT_PATH" ]]; then
  echo "==> fetching Maple Mono NF CN (hinted, woff2 zip) + converting to ttf..."
  tmp="$(mktemp -d)"
  curl -sSL -o "$tmp/maple.zip" \
    "https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMonoNormal-NF-CN-unhinted.zip"
  ( cd "$tmp" && unzip -oq maple.zip )
  # The NF-CN zip ships .ttf (unhinted). We rely on the system-hinted variant if
  # present; otherwise install this ttf and let fontconfig use it.
  sudo mkdir -p /usr/share/fonts/maple-mono 2>/dev/null
  sudo cp "$tmp/MapleMonoNormal-NF-CN-Regular.ttf" "$FONT_PATH" 2>/dev/null \
    || cp "$tmp/MapleMonoNormal-NF-CN-Regular.ttf" ~/.local/share/fonts/
  fc-cache -f >/dev/null 2>&1
  rm -rf "$tmp"
fi

# ---------------------------------------------------------------------------
# 4. freeze-cjk (patched Freeze). Build from this dir's script + patch.
# ---------------------------------------------------------------------------
if ! command -v freeze-cjk >/dev/null; then
  echo "==> building freeze-cjk (needs go)..."
  FREEZE_PATCH="$HERE/freeze-cjk.patch" BINDIR="$BINDIR" bash "$HERE/freeze-cjk.sh"
fi

# ---------------------------------------------------------------------------
# 5. termshot-cjk (optional alt renderer). Skip with TERMSHOT=0.
# ---------------------------------------------------------------------------
if [[ "${TERMSHOT:-1}" == "1" ]] && ! command -v termshot-cjk >/dev/null; then
  echo "==> building termshot-cjk (optional)..."
  TERMSHOT_PATCH="$HERE/termshot-cjk.patch" BINDIR="$BINDIR" bash "$HERE/termshot-cjk.sh"
fi

# ---------------------------------------------------------------------------
# 6. logshot launcher — from this dir's logshot.sh, or embed the inline source.
# ---------------------------------------------------------------------------
if [[ -f "$HERE/logshot.sh" ]]; then
  chmod +x "$HERE/logshot.sh"
  cp "$HERE/logshot.sh" "$BINDIR/logshot"
else
  echo "==> logshot.sh not found alongside install.sh; expecting it to be provided."
  echo "    (The full source is embedded in SKILL.md.)"
fi
chmod +x "$BINDIR/logshot" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Verify
# ---------------------------------------------------------------------------
echo
echo "==> Verify:"
for t in logshot freeze-cjk rsvg-convert chromium; do
  printf '%-16s %s\n' "$t" "$(command -v $t || echo MISSING)"
done
echo "font: $([ -f "$FONT_PATH" ] && echo "$FONT_PATH" || echo MISSING)"
echo
echo "Done. Usage: logshot <pane-id>  |  logshot <pane-id> --clipboard"
