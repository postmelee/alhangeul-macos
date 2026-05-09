#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 <previous-release-ref> <candidate-ref> <output-file>

Writes a release delta checklist draft by classifying changed file paths.
The output is a review aid only; release owner must correct false positives
and missing manual smoke checks before publishing.
EOF
}

if [ "$#" -ne 3 ]; then
  usage
  exit 1
fi

PREVIOUS_REF="$1"
CANDIDATE_REF="$2"
OUTPUT_FILE="$3"

git rev-parse --verify "$PREVIOUS_REF^{commit}" >/dev/null
git rev-parse --verify "$CANDIDATE_REF^{commit}" >/dev/null

mkdir -p "$(dirname "$OUTPUT_FILE")"

changed_files="$(git diff --name-only "$PREVIOUS_REF..$CANDIDATE_REF")"
commit_log="$(git log --oneline "$PREVIOUS_REF..$CANDIDATE_REF")"
previous_commit="$(git rev-parse "$PREVIOUS_REF^{commit}")"
candidate_commit="$(git rev-parse "$CANDIDATE_REF^{commit}")"

path_matches_category() {
  local category="$1"
  local path="$2"

  case "$category:$path" in
    "HostApp viewer:"Sources/HostApp/*|"HostApp viewer:"Sources/HostApp/Resources/rhwp-studio/*)
      return 0
      ;;
    "Quick Look preview:"Sources/QLExtension/*|"Quick Look preview:"Sources/Shared/HwpPreviewPDFRenderer.swift|"Quick Look preview:"Sources/Shared/HwpPageImageRenderer.swift|"Quick Look preview:"Sources/RhwpCoreBridge/CGTreeRenderer.swift)
      return 0
      ;;
    "Finder thumbnail:"Sources/ThumbnailExtension/*|"Finder thumbnail:"Sources/Shared/HwpPageImageRenderer.swift|"Finder thumbnail:"Sources/RhwpCoreBridge/CGTreeRenderer.swift)
      return 0
      ;;
    "저장/다른 이름 저장/PDF/인쇄/공유:"Sources/HostApp/*Save*|"저장/다른 이름 저장/PDF/인쇄/공유:"Sources/HostApp/*Export*|"저장/다른 이름 저장/PDF/인쇄/공유:"Sources/HostApp/*Print*|"저장/다른 이름 저장/PDF/인쇄/공유:"Sources/HostApp/*Share*|"저장/다른 이름 저장/PDF/인쇄/공유:"Sources/HostApp/Services/*|"저장/다른 이름 저장/PDF/인쇄/공유:"Sources/HostApp/Commands/*)
      return 0
      ;;
    "Sparkle/appcast/Pages:"docs/appcast.xml|"Sparkle/appcast/Pages:"docs/updates/*|"Sparkle/appcast/Pages:"docs/index.html|"Sparkle/appcast/Pages:".github/workflows/release-publish.yml|"Sparkle/appcast/Pages:"scripts/ci/write-sparkle-appcast.sh|"Sparkle/appcast/Pages:"scripts/ci/write-release-notes.sh|"Sparkle/appcast/Pages:"scripts/ci/check-release-notes-template.sh)
      return 0
      ;;
    "DMG/signing/notarization:"scripts/release.sh|"DMG/signing/notarization:"scripts/package-release.sh|"DMG/signing/notarization:"scripts/create-dmg-background.swift|"DMG/signing/notarization:"scripts/ci/import-developer-id-certificate.sh)
      return 0
      ;;
    "Homebrew Cask:"Casks/*|"Homebrew Cask:"scripts/update-cask-sha256.sh)
      return 0
      ;;
    "rhwp core/viewer provenance:"rhwp-core.lock|"rhwp core/viewer provenance:"RustBridge/*|"rhwp core/viewer provenance:"Frameworks/*|"rhwp core/viewer provenance:"Sources/HostApp/Resources/rhwp-studio/*|"rhwp core/viewer provenance:"scripts/sync-rhwp-studio.sh|"rhwp core/viewer provenance:"scripts/verify-rhwp-studio-assets.sh|"rhwp core/viewer provenance:"scripts/build-rust-macos.sh)
      return 0
      ;;
    "문서 전용 변경:"README.md|"문서 전용 변경:"mydocs/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

path_has_known_category() {
  local path="$1"
  local category

  for category in \
    "HostApp viewer" \
    "Quick Look preview" \
    "Finder thumbnail" \
    "저장/다른 이름 저장/PDF/인쇄/공유" \
    "Sparkle/appcast/Pages" \
    "DMG/signing/notarization" \
    "Homebrew Cask" \
    "rhwp core/viewer provenance" \
    "문서 전용 변경"; do
    if path_matches_category "$category" "$path"; then
      return 0
    fi
  done

  return 1
}

category_matches() {
  local category="$1"
  local matched=0

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ "$category" = "수동 분류 필요" ]; then
      if path_has_known_category "$path"; then
        continue
      fi
      printf -- '- `%s`\n' "$path"
      matched=1
      continue
    fi
    if path_matches_category "$category" "$path"; then
      printf -- '- `%s`\n' "$path"
      matched=1
    fi
  done <<< "$changed_files"

  if [ "$matched" -eq 0 ]; then
    printf -- '- 변경 없음\n'
  fi
}

cat > "$OUTPUT_FILE" <<EOF
# Release delta checklist draft

## 범위

- previous release ref: \`$PREVIOUS_REF\`
- previous release commit: \`$previous_commit\`
- candidate ref: \`$CANDIDATE_REF\`
- candidate commit: \`$candidate_commit\`

이 문서는 변경 파일 path 기반 자동 분류 초안이다. release owner가 누락, 과잉, 실제 사용자 영향, 수동 smoke 필요 여부를 반드시 보정한다.

## Commit delta

\`\`\`text
$commit_log
\`\`\`

## 변경 파일 전체 목록

\`\`\`text
$changed_files
\`\`\`

## 영향 영역별 초안

### HostApp viewer

$(category_matches "HostApp viewer")

### Quick Look preview

$(category_matches "Quick Look preview")

### Finder thumbnail

$(category_matches "Finder thumbnail")

### 저장/다른 이름 저장/PDF/인쇄/공유

$(category_matches "저장/다른 이름 저장/PDF/인쇄/공유")

### Sparkle/appcast/Pages

$(category_matches "Sparkle/appcast/Pages")

### DMG/signing/notarization

$(category_matches "DMG/signing/notarization")

### Homebrew Cask

$(category_matches "Homebrew Cask")

### rhwp core/viewer provenance

$(category_matches "rhwp core/viewer provenance")

### 문서 전용 변경

$(category_matches "문서 전용 변경")

### 수동 분류 필요

$(category_matches "수동 분류 필요")

## release owner 보정 항목

- 각 영향 영역의 실제 사용자-facing 변화 여부를 확인한다.
- 변경 파일이 여러 영역에 걸치는 경우 checklist를 수동으로 중복 반영한다.
- 실행하지 않은 smoke는 성공으로 쓰지 않는다.
- public DMG signing, notarization, appcast, Homebrew Cask는 release 실행 시점 산출물로 다시 검증한다.
EOF
