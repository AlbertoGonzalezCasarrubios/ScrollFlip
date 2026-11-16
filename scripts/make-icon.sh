#!/bin/bash
# Regenerates Resources/AppIcon.icns from scripts/make-icon.swift.
# Only needed if you change the icon design; the .icns is committed.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

swiftc scripts/make-icon.swift -o "$TMP/make-icon"
"$TMP/make-icon" "$TMP/icon_1024.png"

ICONSET="$TMP/AppIcon.iconset"
mkdir "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
cp "$TMP/icon_1024.png" Resources/AppIcon.png
echo "✔ Resources/AppIcon.icns"
