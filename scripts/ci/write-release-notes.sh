#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <version> <dmg-sha256> <output-file>

Writes a GitHub Release note candidate for the public DMG.
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
SHA256_NAME="$DMG_NAME.sha256"
REPOSITORY="postmelee/alhangeul-macos"
RELEASE_URL="https://github.com/$REPOSITORY/releases/tag/$TAG_NAME"
DMG_URL="https://github.com/$REPOSITORY/releases/download/$TAG_NAME/$DMG_NAME"
PAGES_RELEASE_NOTES_URL="https://postmelee.github.io/alhangeul-macos/updates/$TAG_NAME.html"
APPCAST_URL="https://postmelee.github.io/alhangeul-macos/appcast.xml"
RELEASE_DETAIL_DOC="mydocs/release/$TAG_NAME.md"
RELEASE_INDEX_DOC="mydocs/release/index.md"
SOURCE_DOC_BASE_URL="https://github.com/$REPOSITORY/blob/main"
RELEASE_DETAIL_DOC_URL="$SOURCE_DOC_BASE_URL/$RELEASE_DETAIL_DOC"
RELEASE_INDEX_DOC_URL="$SOURCE_DOC_BASE_URL/$RELEASE_INDEX_DOC"
CORE_LOCK="rhwp-core.lock"

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
RHWP_RELEASE_URL="https://github.com/edwardkim/rhwp/releases/tag/$RHWP_TAG"
STUDIO_MANIFEST="Sources/HostApp/Resources/rhwp-studio/manifest.json"
THIRD_PARTY_NOTICES="THIRD_PARTY_LICENSES.md"
FONT_NOTICES="Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md"

for required_file in "$ROOT/$RELEASE_DETAIL_DOC" "$ROOT/$STUDIO_MANIFEST" "$ROOT/$THIRD_PARTY_NOTICES" "$ROOT/$FONT_NOTICES"; do
  if [ ! -f "$required_file" ]; then
    echo "ERROR: required release provenance file is missing: ${required_file#$ROOT/}" >&2
    exit 1
  fi
done

if ! grep -Fxq "## 포함 PR 분석" "$ROOT/$RELEASE_DETAIL_DOC"; then
  echo "ERROR: $RELEASE_DETAIL_DOC must contain '## 포함 PR 분석' before generating public release notes" >&2
  exit 1
fi

extract_release_subsection() {
  local heading="$1"

  awk -v heading="$heading" '
    /^## GitHub Release 본문 구조 후보$/ { in_release_body = 1; next }
    in_release_body && /^## / { exit }
    in_release_body && $0 == heading { in_target = 1; print; next }
    in_target && /^### / { exit }
    in_target { print }
  ' "$ROOT/$RELEASE_DETAIL_DOC" | sed '/./,$!d'
}

CHANGE_SUMMARY_SECTION="$(extract_release_subsection "### 변경 요약")"
RHWP_CHANGES_SECTION="$(extract_release_subsection "### 포함된 rhwp 변화")"
APP_CHANGES_SECTION="$(extract_release_subsection "### 알한글 앱 변화")"
DIRECT_PRS_SECTION="$(extract_release_subsection "### 릴리즈 요약에 반영된 PR")"
RESOLVED_ISSUES_SECTION="$(extract_release_subsection "### 해결된 Issue")"
RELATED_ISSUES_SECTION="$(extract_release_subsection "### 참고/연관 Issue")"

for required_release_section in \
  "CHANGE_SUMMARY_SECTION:### 변경 요약" \
  "RHWP_CHANGES_SECTION:### 포함된 rhwp 변화" \
  "APP_CHANGES_SECTION:### 알한글 앱 변화" \
  "DIRECT_PRS_SECTION:### 릴리즈 요약에 반영된 PR" \
  "RESOLVED_ISSUES_SECTION:### 해결된 Issue" \
  "RELATED_ISSUES_SECTION:### 참고/연관 Issue"; do
  section_var="${required_release_section%%:*}"
  section_heading="${required_release_section#*:}"
  if [ -z "${!section_var}" ]; then
    echo "ERROR: $RELEASE_DETAIL_DOC must contain $section_heading under '## GitHub Release 본문 구조 후보'" >&2
    exit 1
  fi
done

RELEASE_CHANGE_SECTIONS="$(printf '%s\n\n%s\n\n%s\n' "$CHANGE_SUMMARY_SECTION" "$RHWP_CHANGES_SECTION" "$APP_CHANGES_SECTION")"
RELEASE_PR_ISSUE_SECTIONS="$(printf '%s\n\n%s\n\n%s\n' "$DIRECT_PRS_SECTION" "$RESOLVED_ISSUES_SECTION" "$RELATED_ISSUES_SECTION")"

STUDIO_TAG="$(plutil -extract source_release_tag raw -o - "$ROOT/$STUDIO_MANIFEST")"
STUDIO_COMMIT="$(plutil -extract source_resolved_commit raw -o - "$ROOT/$STUDIO_MANIFEST")"
STUDIO_RELEASE_URL="https://github.com/edwardkim/rhwp/releases/tag/$STUDIO_TAG"

mkdir -p "$(dirname "$OUTPUT_FILE")"
cat > "$OUTPUT_FILE" <<EOF
# Alhangeul $TAG_NAME

## 이번 버전의 주요 변경 사항

$RELEASE_CHANGE_SECTIONS

## 다운로드 및 설치

### 다운로드

- DMG: [\`$DMG_NAME\`]($DMG_URL)
- SHA256: \`$DMG_SHA256\`
- SHA256 file: \`$SHA256_NAME\`

### 지원 환경

- macOS 12 이상을 지원합니다.
- Intel Mac과 Apple Silicon Mac 모두 같은 DMG 파일을 사용합니다.

### 설치 후 첫 실행

- DMG를 열고 \`Alhangeul.app\`을 \`Applications\` 폴더로 드래그해 설치합니다.
- GitHub Release에 게시된 signed/notarized public DMG만 사용자 배포 산출물로 사용합니다.
- 설치 후 \`Applications\` 폴더의 \`Alhangeul.app\`을 한 번 실행합니다.
- 첫 실행 후 macOS가 Quick Look preview와 Finder thumbnail extension을 발견하고 등록할 수 있습니다.
- Finder에서 \`.hwp\` 또는 \`.hwpx\` 파일을 선택한 뒤 Space로 Quick Look preview를 확인하고, icon view에서 thumbnail 갱신을 확인합니다.

### 업데이트 확인

- 앱 메뉴에서 \`알한글 > 업데이트 확인...\`을 선택해 Sparkle 업데이트를 수동 확인할 수 있습니다.
- 업데이트 feed: \`$APPCAST_URL\`
- 버전별 Pages 릴리즈 노트: $PAGES_RELEASE_NOTES_URL

### Homebrew

- Homebrew Cask 반영 전에는 위 GitHub Release DMG를 직접 내려받아 설치하세요.

## 알려진 제한 사항

- 앱 viewer/editor 화면은 bundled \`rhwp-studio\`를 WKWebView에서 실행합니다.
- PDF 내보내기와 인쇄는 현재 editor의 page SVG를 별도 script-disabled WKWebView/PDFKit/AppKit 출력 경로로 처리하므로 앱 화면과 표시가 다를 수 있습니다.
- Quick Look preview와 Finder thumbnail은 Rust bridge와 Swift native renderer 경로를 사용하므로 앱 viewer/editor·PDF/인쇄와 표시가 다를 수 있습니다.
- HWP/HWPX 저장은 형식별 container와 대표 문서 재열기를 확인하지만, 모든 문서 요소의 의미론적 완전 무손실을 보장하지 않습니다.
- PDF 내보내기는 전체 page SVG를 memory에 보유하며 document 전체 progress, deadline과 수집 중 취소 UI는 아직 없습니다.
- Quick Look/Thumbnail smoke 통과는 extension 등록과 기본 렌더 성공 확인이며, 모든 문서가 앱 화면과 같은 시각 결과로 보인다는 보장은 아닙니다.
- 손상·대용량·미지원 문서 fallback은 복구가 아니라 앱과 extension이 raw error, hang, crash로 끝나지 않게 하는 안전장치입니다.
- native renderer의 style, image effect/fill, text layout, RawSvg/OLE 등 parity 개선은 v0.5 이후 Swift native viewer 범위에서 계속 다룹니다.

## 이번 릴리즈 관련 PR과 Issue

$RELEASE_PR_ISSUE_SECTIONS

## 상세 기록

- 릴리즈 상세 기록: [\`$RELEASE_DETAIL_DOC\`]($RELEASE_DETAIL_DOC_URL)
- 릴리즈 기록 index: [\`$RELEASE_INDEX_DOC\`]($RELEASE_INDEX_DOC_URL)
- 사용자용 Pages 릴리즈 노트: $PAGES_RELEASE_NOTES_URL
- GitHub Release: $RELEASE_URL
- Third Party notices: \`$THIRD_PARTY_NOTICES\`
- Font notices: \`$FONT_NOTICES\`

### Release metadata

| 항목 | 값 |
|------|----|
| App version | \`$TAG_NAME\` |
| rhwp core release tag | \`$RHWP_TAG\` |
| rhwp core commit | \`$RHWP_COMMIT\` |
| bundled rhwp-studio release tag | \`$STUDIO_TAG\` |
| bundled rhwp-studio commit | \`$STUDIO_COMMIT\` |
| core lock | \`$CORE_LOCK\` |
| studio manifest | \`$STUDIO_MANIFEST\` |
EOF
