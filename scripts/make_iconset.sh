#!/bin/bash
# Generate Resources/AppIcon.icns from scratch: draw master PNG -> iconset -> .icns.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p Resources
MASTER="$(mktemp -t folio_master).png"
ICONSET="$(mktemp -d -t Folio_iconset)/Folio.iconset"
mkdir -p "$ICONSET"

echo "▶ Rendering master PNG…"
swift scripts/make_icon.swift "$MASTER"

echo "▶ Building iconset…"
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
            "128:128x128" "256:128x128@2x" "256:256x256" \
            "512:256x256@2x" "512:512x512" "1024:512x512@2x"; do
    px="${spec%%:*}"; name="${spec##*:}"
    sips -z "$px" "$px" "$MASTER" --out "$ICONSET/icon_${name}.png" >/dev/null
done

echo "▶ Creating .icns…"
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "✅ Wrote Resources/AppIcon.icns"
