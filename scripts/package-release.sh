#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build.noindex/release"
DERIVED_DATA_DIR="$ROOT/build.noindex/DerivedDataRelease"
APP_NAME="RhwpMac.app"
ZIP_NAME="rhwp-mac-$VERSION.zip"

mkdir -p "$BUILD_DIR"

"$ROOT/scripts/build-rust-macos.sh" --verify-lock

cd "$ROOT"
xcodegen generate
xcodebuild -project RhwpMac.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  build

if [ ! -d "$BUILD_DIR/$APP_NAME" ]; then
  echo "ERROR: missing app bundle: $BUILD_DIR/$APP_NAME" >&2
  exit 1
fi

rm -f "$BUILD_DIR/$ZIP_NAME"
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME" "$ZIP_NAME"
shasum -a 256 "$ZIP_NAME"
