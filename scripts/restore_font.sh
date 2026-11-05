#!/usr/bin/env bash
set -euo pipefail

FONT_SOURCE="assets/fonts/ArefRuqaa-Regular.ttf.base64"
FONT_TARGET="assets/fonts/ArefRuqaa-Regular.ttf"

mkdir -p assets/fonts
base64 --decode "$FONT_SOURCE" > "$FONT_TARGET"
test -s "$FONT_TARGET"
echo "Aref Ruqaa offline font restored: $FONT_TARGET"
