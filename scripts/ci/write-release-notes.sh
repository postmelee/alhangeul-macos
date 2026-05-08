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

## 렌더링 경로와 알려진 제한 사항

- 앱 viewer/editor 화면은 bundled \`rhwp-studio\`를 WKWebView에서 실행합니다.
- PDF 내보내기, Quick Look preview, Finder thumbnail은 Rust bridge와 Swift native renderer 계열 경로를 사용하므로 앱 화면과 표시가 다를 수 있습니다.
- 인쇄는 \`rhwp-studio\` page payload를 별도 WKWebView/PDFKit/AppKit 출력 경로로 처리합니다.
- Quick Look/Thumbnail smoke 통과는 extension 등록과 기본 렌더 성공 확인이며, 모든 문서가 앱 화면과 같은 시각 결과로 보인다는 보장은 아닙니다.
- 손상·대용량·미지원 문서 fallback은 복구가 아니라 앱과 extension이 raw error, hang, crash로 끝나지 않게 하는 안전장치입니다.
- native renderer의 style, image effect/fill, text layout, RawSvg/OLE 등 parity 개선은 v0.5 이후 Swift native viewer 범위에서 계속 다룹니다.

## 검증

- 이 DMG는 release publish workflow에서 서명, 공증, staple, Gatekeeper assessment, checksum 검증을 통과한 산출물입니다.
- 상세 smoke test 결과, preview 수동 확인 여부, 알려진 제한 사항은 해당 릴리스의 최종 보고서를 기준으로 확인합니다.
EOF
