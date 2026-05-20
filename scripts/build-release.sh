#!/usr/bin/env bash
# Build a release .dmg of No More Turtle.
#
# Usage:   ./scripts/build-release.sh [VERSION]
# Example: ./scripts/build-release.sh 0.1.0

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP_NAME="NoMoreTurtle"
SCHEME="NoMoreTurtle"
BUILD_ROOT="build"
DERIVED="$BUILD_ROOT/DerivedData"
STAGING="$BUILD_ROOT/dmg-staging"
DMG_PATH="$BUILD_ROOT/${APP_NAME}-${VERSION}.dmg"

command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found. Install with: brew install xcodegen"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild not found. Install Xcode."; exit 1; }

mkdir -p "$BUILD_ROOT"

echo "▶︎ Generating Xcode project…"
xcodegen generate > /dev/null

echo "▶︎ Release build…"
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    clean build > "$BUILD_ROOT/build.log" 2>&1

APP_PATH="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Build failed — see $BUILD_ROOT/build.log"
    tail -40 "$BUILD_ROOT/build.log"
    exit 1
fi

echo "▶︎ Staging DMG contents…"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "▶︎ Creating ${DMG_PATH}…"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" > /dev/null

SIZE_HUMAN="$(du -h "$DMG_PATH" | cut -f1)"
SHA_SHORT="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}' | cut -c1-12)"

echo ""
echo "✅ Built ${DMG_PATH} (${SIZE_HUMAN}, sha256 ${SHA_SHORT}…)"
echo ""
echo "Test locally:"
echo "  open \"$DMG_PATH\""
echo ""
echo "Publish to GitHub Releases:"
echo "  gh release create v${VERSION} \"$DMG_PATH\" --title \"v${VERSION}\" --notes-file <(echo 'release notes')"
