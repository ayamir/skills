#!/usr/bin/env bash
# termshot-cjk — build a patched termshot that renders CJK + Nerd Font glyphs.
#
# Upstream termshot hardcodes the embedded Hack font (no CJK), and its CLI has no
# way to supply an external font. This applies a small patch (adds a `--font-file`
# flag that loads a TTF/OTF via freetype/truetype with Full hinting) so Chinese
# and Nerd Font glyphs render crisply.
#
# Works on a headless box (no X/Wayland): it renders directly to a PNG from ANSI
# input via `--raw-read`, no virtual display needed.
#
# Usage:
#   termshot-cjk.sh                        # install to ~/.local/bin/termshot-cjk
#   SRCDIR=/path BINDIR=/path sh termshot-cjk.sh
set -euo pipefail

BINDIR="${BINDIR:-$HOME/.local/bin}"
SRCDIR="${SRCDIR:-$HOME/.cache/termshot-cjk-src}"
PATCH="${TERMSHOT_PATCH:-$(cd "$(dirname "$0")" && pwd)/termshot-cjk.patch}"

if [[ ! -d "$SRCDIR/.git" ]]; then
  rm -rf "$SRCDIR"
  git clone --depth 1 https://github.com/homeport/termshot.git "$SRCDIR"
fi
cd "$SRCDIR"

if [[ ! -f "$PATCH" ]]; then
  echo "error: patch not found at $PATCH" >&2
  exit 1
fi

# Apply idempotently: only if the new flag isn't already present.
if ! grep -q '"font-file"' internal/cmd/root.go; then
  git apply "$PATCH"
fi

go build -o "$BINDIR/termshot-cjk" ./cmd/termshot
echo "built: $BINDIR/termshot-cjk"
echo "usage: cat log.ansi | $BINDIR/termshot-cjk --font-file <cjk.ttf> --raw-read - --filename out.png"
