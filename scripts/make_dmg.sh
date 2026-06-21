#!/bin/bash
# Build Folio.app (universal) and package a drag-to-Applications DMG.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
APP_DIR="Folio.app"
DMG="Folio-${VERSION}.dmg"

bash scripts/bundle.sh

echo "▶ Staging DMG contents…"
STAGE="$(mktemp -d)"
cp -R "$APP_DIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-to-install target

echo "▶ Creating ${DMG}…"
rm -f "$DMG"
hdiutil create \
    -volname "Folio ${VERSION}" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGE"
echo "✅ Built ${DMG}  ($(du -h "$DMG" | cut -f1))"
echo "   Share this file. On another Mac: open it, drag Folio to Applications,"
echo "   then first launch via right-click → Open (Gatekeeper, since it isn't notarized)."
