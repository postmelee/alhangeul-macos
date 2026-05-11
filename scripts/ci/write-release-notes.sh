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

## 사용자용 요약

- macOS 12 이상에서 HWP/HWPX 문서를 Finder Quick Look, Finder thumbnail, 알한글 앱으로 확인할 수 있습니다.
- 공식 DMG는 Intel Mac과 Apple Silicon Mac을 모두 지원하는 단일 universal DMG입니다.
- 이번 릴리스의 상세 변경과 검증 기록은 \`$RELEASE_DETAIL_DOC\`와 release delta checklist를 기준으로 관리합니다.
- 설치, 첫 실행, 업데이트 확인, 알려진 제한 사항을 먼저 확인한 뒤 DMG를 내려받으세요.

## 설치 방법

- DMG: [\`$DMG_NAME\`]($DMG_URL)
- macOS 12 이상을 지원합니다.
- Intel Mac과 Apple Silicon Mac 모두 같은 DMG 파일을 사용합니다.
- DMG를 열고 \`Alhangeul.app\`을 \`Applications\` 폴더로 드래그해 설치합니다.
- GitHub Release에 게시된 signed/notarized public DMG만 사용자 배포 산출물로 사용합니다.

## 지원 환경과 아키텍처

- 지원 OS: macOS 12 Monterey 이상
- 지원 Mac: Intel Mac, Apple Silicon Mac
- 배포 방식: 아키텍처별 DMG를 나누지 않고 \`$DMG_NAME\` 단일 파일을 제공합니다.
- release build는 앱 본체와 Quick Look/Thumbnail extension 실행 파일의 \`arm64 + x86_64\` slice를 검증해야 합니다.
- 실제 Intel Mac 실기기 smoke는 실행한 경우에만 성공으로 기록하고, 미실행 시에는 release detail doc에 이유를 남깁니다.

## 설치 후 첫 실행과 Quick Look/Thumbnail 활성화 안내

- 설치 후 \`Applications\` 폴더의 \`Alhangeul.app\`을 한 번 실행합니다.
- 첫 실행 후 macOS가 Quick Look preview와 Finder thumbnail extension을 발견하고 등록할 수 있습니다.
- Finder에서 \`.hwp\` 또는 \`.hwpx\` 파일을 선택한 뒤 Space로 Quick Look preview를 확인하고, icon view에서 thumbnail 갱신을 확인합니다.

## 업데이트 확인 방법

- 앱 메뉴에서 \`알한글 > 업데이트 확인...\`을 선택해 Sparkle 업데이트를 수동 확인할 수 있습니다.
- 업데이트 feed: \`$APPCAST_URL\`
- 버전별 Pages 릴리즈 노트: $PAGES_RELEASE_NOTES_URL

## 이번 버전의 주요 변경 사항

- 직전 공개 릴리즈 대비 사용자-facing 변경은 release delta checklist를 기준으로 정리합니다.
- 연결된 Issue/PR과 기여자는 \`$RELEASE_DETAIL_DOC\`의 릴리즈 상세 기록을 기준으로 확인합니다.
- 문서 전용 변경과 설치본 smoke가 필요한 변경은 release delta checklist에서 구분합니다.

## 다운로드 산출물과 SHA256

- GitHub Release: $RELEASE_URL
- DMG: \`$DMG_NAME\`
- DMG URL: $DMG_URL
- 지원 아키텍처: \`arm64 + x86_64\` universal app/extension bundle
- SHA256 file: \`$SHA256_NAME\`
- SHA256: \`$DMG_SHA256\`

## Homebrew Cask

- Homebrew Cask는 public DMG URL/SHA256과 tap context 검증이 끝난 뒤 안내합니다.
- 검증 전 공식 설치 경로는 위 GitHub Release DMG입니다.
- Homebrew Cask도 아키텍처별 URL을 나누지 않고 같은 public universal DMG URL과 SHA256을 사용합니다.
- 공개 완료 후 설치 명령은 \`brew install --cask postmelee/tap/alhangeul-macos\` 기준으로 README, Pages, GitHub Release/릴리즈 노트에 반영합니다.

## Release metadata

| 항목 | 값 |
|------|----|
| App version | \`$TAG_NAME\` |
| rhwp core release tag | \`$RHWP_TAG\` |
| rhwp core commit | \`$RHWP_COMMIT\` |
| bundled rhwp-studio release tag | \`$STUDIO_TAG\` |
| bundled rhwp-studio commit | \`$STUDIO_COMMIT\` |
| core lock | \`$CORE_LOCK\` |
| studio manifest | \`$STUDIO_MANIFEST\` |

## 검증 결과

- release publish workflow에서 서명, 공증, staple, Gatekeeper assessment, checksum 검증을 통과한 public DMG만 배포합니다.
- \`hdiutil verify\`, SHA256 대조, app bundle signing/notarization/staple 검증 결과를 최종 확인합니다.
- \`Alhangeul.app\`, \`AlhangeulPreview.appex\`, \`AlhangeulThumbnail.appex\`의 실행 파일이 \`arm64 + x86_64\` universal인지 확인합니다.
- Finder Quick Look preview, Finder thumbnail, 앱 실행, 문서 열기, 창 resize/확대, Sparkle 수동 업데이트 확인 smoke 결과는 \`$RELEASE_DETAIL_DOC\`에 기록합니다.
- 실행하지 않은 수동 확인 항목은 성공으로 쓰지 않고 #188 final smoke 또는 후속 확인으로 분리합니다.

## 릴리즈 delta 기반 추가 확인 항목

- 기준 범위는 직전 공개 release tag부터 현재 release candidate commit까지입니다.
- merged PR, 연결된 Issue, commit range, 변경 파일 목록을 수집한 뒤 영향 영역별 smoke 항목을 보정합니다.
- 영향 영역 후보: HostApp viewer, Quick Look preview, Finder thumbnail, 저장/다른 이름 저장, PDF/인쇄/공유, Sparkle/appcast/Pages, DMG/signing/notarization, Homebrew Cask, rhwp core/viewer asset provenance, 문서 전용 변경.
- 자동 생성된 checklist는 초안이며 release owner가 누락/과잉 항목을 보정합니다.

## 알려진 제한 사항과 후속 이슈

- 앱 viewer/editor 화면은 bundled \`rhwp-studio\`를 WKWebView에서 실행합니다.
- PDF 내보내기, Quick Look preview, Finder thumbnail은 Rust bridge와 Swift native renderer 계열 경로를 사용하므로 앱 화면과 표시가 다를 수 있습니다.
- 인쇄는 \`rhwp-studio\` page payload를 별도 WKWebView/PDFKit/AppKit 출력 경로로 처리합니다.
- Quick Look/Thumbnail smoke 통과는 extension 등록과 기본 렌더 성공 확인이며, 모든 문서가 앱 화면과 같은 시각 결과로 보인다는 보장은 아닙니다.
- 손상·대용량·미지원 문서 fallback은 복구가 아니라 앱과 extension이 raw error, hang, crash로 끝나지 않게 하는 안전장치입니다.
- native renderer의 style, image effect/fill, text layout, RawSvg/OLE 등 parity 개선은 v0.5 이후 Swift native viewer 범위에서 계속 다룹니다.
- 후속 이슈는 \`$RELEASE_DETAIL_DOC\`와 GitHub Issue 상태를 기준으로 관리합니다.

## Third Party notices

- \`$THIRD_PARTY_NOTICES\`
- \`$FONT_NOTICES\`
EOF
