#!/bin/bash
# Assemble Folio.app from the SwiftPM release build — no Xcode required.
set -euo pipefail

cd "$(dirname "$0")/.."

DISPLAY_NAME="Folio"          # user-facing name (Finder, menu bar, window)
EXEC_NAME="Folio"             # SwiftPM product / binary name
BUNDLE_ID="com.tonyfadel.folio"
MIN_OS="13.0"
APP_DIR="${DISPLAY_NAME}.app"
ICON_SRC="Resources/AppIcon.icns"
VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"  # single source of truth

# Build a universal binary by compiling each arch separately and fusing with lipo.
# (Single `swift build --arch a --arch b` needs full Xcode's xcbuild, absent with CLT.)
echo "▶ Building release binary (arm64)…"
swift build -c release --arch arm64
echo "▶ Building release binary (x86_64)…"
swift build -c release --arch x86_64

ARM_BIN="$(swift build -c release --arch arm64 --show-bin-path)/${EXEC_NAME}"
X86_BIN="$(swift build -c release --arch x86_64 --show-bin-path)/${EXEC_NAME}"
if [[ ! -f "$ARM_BIN" || ! -f "$X86_BIN" ]]; then
    echo "✗ Expected binaries not found ($ARM_BIN / $X86_BIN)" >&2
    exit 1
fi

# Regenerate the icon if it is missing.
if [[ ! -f "$ICON_SRC" ]]; then
    echo "▶ Icon missing — generating…"
    bash scripts/make_iconset.sh || echo "  (icon generation failed; continuing without icon)"
fi

echo "▶ Assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

lipo -create "$ARM_BIN" "$X86_BIN" -output "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"

ICON_PLIST=""
if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "${APP_DIR}/Contents/Resources/AppIcon.icns"
    ICON_PLIST="    <key>CFBundleIconFile</key>       <string>AppIcon</string>
    <key>CFBundleIconName</key>       <string>AppIcon</string>"
fi

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>      <string>${EXEC_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>         <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>${MIN_OS}</string>
    <key>LSApplicationCategoryType</key> <string>public.app-category.utilities</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSHumanReadableCopyright</key> <string>© 2026 Tony Fadel. MIT Licensed.</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>   <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>   <string>Viewer</string>
            <key>LSHandlerRank</key>      <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array><string>net.daringfireball.markdown</string></array>
            <key>CFBundleTypeExtensions</key>
            <array><string>md</string><string>markdown</string><string>mdown</string><string>mkd</string></array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>   <string>HTML Document</string>
            <key>CFBundleTypeRole</key>   <string>Viewer</string>
            <key>LSHandlerRank</key>      <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array><string>public.html</string></array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>   <string>Text Document</string>
            <key>CFBundleTypeRole</key>   <string>Viewer</string>
            <key>LSHandlerRank</key>      <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.plain-text</string>
                <string>public.source-code</string>
                <string>public.json</string>
                <string>public.xml</string>
                <string>public.comma-separated-values-text</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>   <string>Image</string>
            <key>CFBundleTypeRole</key>   <string>Viewer</string>
            <key>LSHandlerRank</key>      <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array><string>public.image</string><string>public.svg-image</string></array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>   <string>PDF Document</string>
            <key>CFBundleTypeRole</key>   <string>Viewer</string>
            <key>LSHandlerRank</key>      <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array><string>com.adobe.pdf</string></array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>   <string>Folder</string>
            <key>CFBundleTypeRole</key>   <string>Viewer</string>
            <key>LSHandlerRank</key>      <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array><string>public.folder</string></array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>   <string>net.daringfireball.markdown</string>
            <key>UTTypeDescription</key>  <string>Markdown Document</string>
            <key>UTTypeConformsTo</key>
            <array><string>public.plain-text</string></array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array><string>md</string><string>markdown</string><string>mdown</string><string>mkd</string></array>
                <key>public.mime-type</key>
                <array><string>text/markdown</string></array>
            </dict>
        </dict>
    </array>
${ICON_PLIST}
</dict>
</plist>
PLIST

echo "▶ Ad-hoc code-signing…"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "  (codesign skipped — app still runs locally)"

echo "✅ Built ${APP_DIR} (v${VERSION}, universal: $(lipo -archs "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"))"
