#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <Alhangeul.app>" >&2
  exit 1
fi

APP_PATH="$1"
REQUIRED_ARCHS=(arm64 x86_64)

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: missing app bundle: $APP_PATH" >&2
  exit 1
fi

if ! xcrun --find lipo >/dev/null 2>&1; then
  echo "ERROR: required Xcode tool not found: lipo" >&2
  exit 1
fi

verify_binary() {
  local relative_path="$1"
  local binary="$APP_PATH/$relative_path"

  if [ ! -f "$binary" ]; then
    echo "ERROR: missing executable: $relative_path" >&2
    exit 1
  fi

  if [ ! -x "$binary" ]; then
    echo "ERROR: not executable: $relative_path" >&2
    exit 1
  fi

  if ! xcrun lipo "$binary" -verify_arch "${REQUIRED_ARCHS[@]}" >/dev/null 2>&1; then
    echo "ERROR: $relative_path must contain architectures: ${REQUIRED_ARCHS[*]}" >&2
    xcrun lipo -info "$binary" >&2 || true
    exit 1
  fi

  xcrun lipo -info "$binary"
}

verify_binary "Contents/MacOS/Alhangeul"
verify_binary "Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview"
verify_binary "Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail"
