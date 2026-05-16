#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --version <version> --build <build> --dmg-url <url> --length <bytes> \\
  --ed-signature <signature> --release-notes-url <url> --pub-date <rfc-2822-date> \\
  --output <file> [--minimum-system-version <version>]

Writes the stable Sparkle appcast XML for Alhangeul.

Required inputs:
  --version              CFBundleShortVersionString, for example 0.1.0.
  --build                CFBundleVersion used by Sparkle for update comparison.
  --dmg-url              Tag-fixed GitHub Release DMG URL.
  --length               DMG byte length.
  --ed-signature         Sparkle EdDSA signature for the DMG.
  --release-notes-url    Public release notes URL.
  --pub-date             RFC 2822 pubDate, for example Fri, 08 May 2026 09:00:00 +0000.
  --output               Output appcast XML path.

Optional inputs:
  --minimum-system-version  Defaults to 12.0.
  -h, --help                Show this help.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s' "$value"
}

require_https_url() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^https://[^[:space:]]+$ ]]; then
    fail "$name must be an https URL without whitespace"
  fi
}

VERSION=""
BUILD=""
DMG_URL=""
LENGTH=""
ED_SIGNATURE=""
RELEASE_NOTES_URL=""
PUB_DATE=""
OUTPUT_FILE=""
MINIMUM_SYSTEM_VERSION="12.0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      shift
      [ "$#" -gt 0 ] || fail "--version requires a value"
      VERSION="$1"
      ;;
    --build)
      shift
      [ "$#" -gt 0 ] || fail "--build requires a value"
      BUILD="$1"
      ;;
    --dmg-url)
      shift
      [ "$#" -gt 0 ] || fail "--dmg-url requires a value"
      DMG_URL="$1"
      ;;
    --length)
      shift
      [ "$#" -gt 0 ] || fail "--length requires a value"
      LENGTH="$1"
      ;;
    --ed-signature)
      shift
      [ "$#" -gt 0 ] || fail "--ed-signature requires a value"
      ED_SIGNATURE="$1"
      ;;
    --release-notes-url)
      shift
      [ "$#" -gt 0 ] || fail "--release-notes-url requires a value"
      RELEASE_NOTES_URL="$1"
      ;;
    --pub-date)
      shift
      [ "$#" -gt 0 ] || fail "--pub-date requires a value"
      PUB_DATE="$1"
      ;;
    --output)
      shift
      [ "$#" -gt 0 ] || fail "--output requires a value"
      OUTPUT_FILE="$1"
      ;;
    --minimum-system-version)
      shift
      [ "$#" -gt 0 ] || fail "--minimum-system-version requires a value"
      MINIMUM_SYSTEM_VERSION="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

[ -n "$VERSION" ] || fail "--version is required"
[ -n "$BUILD" ] || fail "--build is required"
[ -n "$DMG_URL" ] || fail "--dmg-url is required"
[ -n "$LENGTH" ] || fail "--length is required"
[ -n "$ED_SIGNATURE" ] || fail "--ed-signature is required"
[ -n "$RELEASE_NOTES_URL" ] || fail "--release-notes-url is required"
[ -n "$PUB_DATE" ] || fail "--pub-date is required"
[ -n "$OUTPUT_FILE" ] || fail "--output is required"

if ! [[ "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  fail "version must look like semantic version, got: $VERSION"
fi

if [[ "$BUILD" =~ [[:space:]] ]]; then
  fail "build must not contain whitespace"
fi

if ! [[ "$LENGTH" =~ ^[1-9][0-9]*$ ]]; then
  fail "length must be a positive integer byte count"
fi

if [[ "$ED_SIGNATURE" =~ [[:space:]] ]]; then
  fail "ed-signature must not contain whitespace"
fi

if [[ "$MINIMUM_SYSTEM_VERSION" =~ [[:space:]] ]]; then
  fail "minimum-system-version must not contain whitespace"
fi

require_https_url "--dmg-url" "$DMG_URL"
require_https_url "--release-notes-url" "$RELEASE_NOTES_URL"

OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"
TMP_OUTPUT="$OUTPUT_FILE.tmp.$$"

CHANNEL_TITLE="$(xml_escape "알한글 업데이트")"
CHANNEL_LINK="$(xml_escape "https://postmelee.github.io/alhangeul-macos/updates/")"
CHANNEL_DESCRIPTION="$(xml_escape "알한글 macOS 앱 업데이트 feed")"
ITEM_TITLE="$(xml_escape "Alhangeul v$VERSION")"
ITEM_LINK="$(xml_escape "$RELEASE_NOTES_URL")"
VERSION_ESCAPED="$(xml_escape "$VERSION")"
BUILD_ESCAPED="$(xml_escape "$BUILD")"
DMG_URL_ESCAPED="$(xml_escape "$DMG_URL")"
LENGTH_ESCAPED="$(xml_escape "$LENGTH")"
ED_SIGNATURE_ESCAPED="$(xml_escape "$ED_SIGNATURE")"
RELEASE_NOTES_URL_ESCAPED="$(xml_escape "$RELEASE_NOTES_URL")"
PUB_DATE_ESCAPED="$(xml_escape "$PUB_DATE")"
MINIMUM_SYSTEM_VERSION_ESCAPED="$(xml_escape "$MINIMUM_SYSTEM_VERSION")"

cat > "$TMP_OUTPUT" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$CHANNEL_TITLE</title>
    <link>$CHANNEL_LINK</link>
    <description>$CHANNEL_DESCRIPTION</description>
    <language>ko</language>
    <item>
      <title>$ITEM_TITLE</title>
      <link>$ITEM_LINK</link>
      <sparkle:version>$BUILD_ESCAPED</sparkle:version>
      <sparkle:shortVersionString>$VERSION_ESCAPED</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>$RELEASE_NOTES_URL_ESCAPED</sparkle:releaseNotesLink>
      <pubDate>$PUB_DATE_ESCAPED</pubDate>
      <enclosure url="$DMG_URL_ESCAPED" length="$LENGTH_ESCAPED" type="application/octet-stream" sparkle:edSignature="$ED_SIGNATURE_ESCAPED" />
      <sparkle:minimumSystemVersion>$MINIMUM_SYSTEM_VERSION_ESCAPED</sparkle:minimumSystemVersion>
    </item>
  </channel>
</rss>
EOF

mv "$TMP_OUTPUT" "$OUTPUT_FILE"
