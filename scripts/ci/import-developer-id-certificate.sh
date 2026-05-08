#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0

Imports the Developer ID Application .p12 from environment variables into a
temporary keychain and prints the keychain path.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

for required in \
  DEVELOPER_ID_APPLICATION_P12_BASE64 \
  DEVELOPER_ID_APPLICATION_P12_PASSWORD \
  RELEASE_KEYCHAIN_PASSWORD
do
  if [ -z "${!required:-}" ]; then
    echo "ERROR: $required is required to import Developer ID certificate" >&2
    exit 1
  fi
done

if [ -z "${RUNNER_TEMP:-}" ]; then
  RUNNER_TEMP="${TMPDIR:-/tmp}"
fi

KEYCHAIN_PATH="$RUNNER_TEMP/alhangeul-release.keychain-db"
P12_PATH="$RUNNER_TEMP/alhangeul-developer-id-application.p12"

decode_base64() {
  if base64 --decode </dev/null >/dev/null 2>&1; then
    base64 --decode
  else
    base64 -D
  fi
}

rm -f "$P12_PATH"
printf '%s' "$DEVELOPER_ID_APPLICATION_P12_BASE64" | decode_base64 > "$P12_PATH"

if [ -f "$KEYCHAIN_PATH" ]; then
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null
fi

security create-keychain -p "$RELEASE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH" >/dev/null
security unlock-keychain -p "$RELEASE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security import "$P12_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$DEVELOPER_ID_APPLICATION_P12_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  >/dev/null
security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$RELEASE_KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH" \
  >/dev/null
security list-keychains -d user -s "$KEYCHAIN_PATH" >/dev/null
security default-keychain -d user -s "$KEYCHAIN_PATH" >/dev/null
security unlock-keychain -p "$RELEASE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null

rm -f "$P12_PATH"
printf '%s\n' "$KEYCHAIN_PATH"
