#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build/release"
XCODE_BUILD_DIR="$BUILD_DIR/xcodebuild"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
BUILD_APP_NAME="RhwpMac.app"
APP_NAME="RhwpMac.app"
ZIP_NAME="rhwp-mac-$VERSION.zip"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

mkdir -p "$BUILD_DIR"
rm -rf "$XCODE_BUILD_DIR"
rm -rf "$DERIVED_DATA_DIR"
rm -rf "$BUILD_DIR/$BUILD_APP_NAME" "$BUILD_DIR/$BUILD_APP_NAME.dSYM"
rm -rf "$BUILD_DIR"/RhwpMac*.appex "$BUILD_DIR"/RhwpMac*.appex.dSYM "$BUILD_DIR"/RhwpMac*.swiftmodule
rm -rf "$BUILD_DIR/include" "$BUILD_DIR/librhwp.a"

"$ROOT/scripts/build-rust-macos.sh"

cd "$ROOT"
xcodegen generate
xcodebuild -project RhwpMac.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CONFIGURATION_BUILD_DIR="$XCODE_BUILD_DIR" \
  build

if [ ! -d "$XCODE_BUILD_DIR/$BUILD_APP_NAME" ]; then
  echo "ERROR: missing app bundle: $XCODE_BUILD_DIR/$BUILD_APP_NAME" >&2
  exit 1
fi

rm -rf "$BUILD_DIR/$APP_NAME"
# Keep the filesystem bundle name ASCII. Localized user-facing names are provided
# by Info.plist; a non-ASCII .app path can break ExtensionKit lookup.
ditto "$XCODE_BUILD_DIR/$BUILD_APP_NAME" "$BUILD_DIR/$APP_NAME"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$XCODE_BUILD_DIR/$BUILD_APP_NAME" >/dev/null 2>&1 || true
fi
rm -rf "$XCODE_BUILD_DIR"
rm -rf "$DERIVED_DATA_DIR"
rm -f "$BUILD_DIR/$ZIP_NAME"
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME" "$ZIP_NAME"
shasum -a 256 "$ZIP_NAME"
