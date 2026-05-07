#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <version> <dmg-sha256> <output-file>

Writes a GitHub Release note skeleton for the public DMG.
EOF
}

if [ "$#" -ne 3 ]; then
  usage
  exit 1
fi

VERSION="$1"
DMG_SHA256="$2"
OUTPUT_FILE="$3"
TAG_NAME="v$VERSION"
DMG_NAME="alhangeul-macos-$VERSION.dmg"

if ! [[ "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "ERROR: version must look like semantic version, got: $VERSION" >&2
  exit 1
fi

if ! [[ "$DMG_SHA256" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "ERROR: dmg sha256 must be a 64-character hex digest" >&2
  exit 1
fi

RHWP_TAG="$(bash "$ROOT/scripts/ci/read-rhwp-core-lock.sh" rhwp_release_tag)"
RHWP_COMMIT="$(bash "$ROOT/scripts/ci/read-rhwp-core-lock.sh" rhwp_commit)"
STUDIO_MANIFEST="Sources/HostApp/Resources/rhwp-studio/manifest.json"
THIRD_PARTY_NOTICES="THIRD_PARTY_LICENSES.md"
FONT_NOTICES="Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md"

for required_file in "$ROOT/$STUDIO_MANIFEST" "$ROOT/$THIRD_PARTY_NOTICES" "$ROOT/$FONT_NOTICES"; do
  if [ ! -f "$required_file" ]; then
    echo "ERROR: required release provenance file is missing: ${required_file#$ROOT/}" >&2
    exit 1
  fi
done

STUDIO_TAG="$(plutil -extract source_release_tag raw -o - "$ROOT/$STUDIO_MANIFEST")"
STUDIO_COMMIT="$(plutil -extract source_resolved_commit raw -o - "$ROOT/$STUDIO_MANIFEST")"

mkdir -p "$(dirname "$OUTPUT_FILE")"
cat > "$OUTPUT_FILE" <<EOF
# Alhangeul $TAG_NAME

## 설치

- macOS 12 이상을 지원합니다.
- 아래 DMG를 내려받아 \`Alhangeul.app\`을 Applications 폴더로 옮겨 설치합니다.

## 산출물

- DMG: \`$DMG_NAME\`
- SHA256: \`$DMG_SHA256\`

## 포함된 rhwp core

- release tag: \`$RHWP_TAG\`
- commit: \`$RHWP_COMMIT\`

## 포함된 viewer asset provenance

- rhwp-studio release tag: \`$STUDIO_TAG\`
- rhwp-studio commit: \`$STUDIO_COMMIT\`
- manifest: \`$STUDIO_MANIFEST\`

## Third Party notices

- \`$THIRD_PARTY_NOTICES\`
- \`$FONT_NOTICES\`

## 검증

- 이 DMG는 release publish workflow에서 서명, 공증, staple, Gatekeeper assessment, checksum 검증을 통과한 산출물입니다.
- 상세 smoke test 결과와 알려진 제한 사항은 해당 릴리스의 최종 보고서를 기준으로 확인합니다.
EOF
