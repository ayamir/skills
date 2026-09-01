#!/usr/bin/env bash
# freeze-cjk — build a patched Freeze that renders CJK + Nerd Font glyphs.
#
# Freeze v0.2.x ignores --font.file on its ANSI terminal render path: the custom
# font it embeds into the SVG is never loaded into resvg's font database, so CJK
# / Nerd Font glyphs fall back to the embedded JetBrains Mono and render as tofu.
# This applies a tiny patch (font.go supports .ttc; png.go loads the custom font
# into resvg's fontdb) and builds a `freeze-cjk` binary.
#
# Usage:
#   freeze-cjk.sh                        # install to ~/.local/bin/freeze-cjk
#   FREEZE_DIR=/path FREEZE_PATCH=... sh freeze-cjk.sh
set -euo pipefail

BINDIR="${BINDIR:-$HOME/.local/bin}"
FREEZE_DIR="${FREEZE_DIR:-$HOME/.cache/freeze-cjk-src}"
PATCH="${FREEZE_PATCH:-${FREEZE_DIR}.patch}"

if [[ ! -d "$FREEZE_DIR/.git" ]]; then
  rm -rf "$FREEZE_DIR"
  git clone --depth 1 https://github.com/charmbracelet/freeze.git "$FREEZE_DIR"
fi
cd "$FREEZE_DIR"

# Re-generate the patch from this script location if not supplied.
if [[ "$PATCH" == "${FREEZE_DIR}.patch" ]]; then
  PATCH="$(cd "$(dirname "$0")" && pwd)/freeze-cjk.patch"
fi
if [[ ! -f "$PATCH" ]]; then
  echo "error: patch not found at $PATCH" >&2
  echo "run: git -C $FREEZE_DIR diff > $PATCH  (after making the edits)" >&2
  exit 1
fi

# Apply patch idempotently: only if not already applied.
if ! grep -q "config.Font.File != \"\"" png.go; then
  git apply "$PATCH"
fi

go build -o "$BINDIR/freeze-cjk" .
echo "built: $BINDIR/freeze-cjk"
