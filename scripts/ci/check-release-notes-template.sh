#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 <release-notes-file>

Checks that a generated GitHub Release note contains all required sections.
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

RELEASE_NOTES_FILE="$1"

if [ ! -f "$RELEASE_NOTES_FILE" ]; then
  echo "ERROR: release notes file does not exist: $RELEASE_NOTES_FILE" >&2
  exit 1
fi

required_headings=(
  "## 사용자용 요약"
  "## 설치 방법"
  "## 설치 후 첫 실행과 Quick Look/Thumbnail 활성화 안내"
  "## 업데이트 확인 방법"
  "## 이번 버전의 주요 변경 사항"
  "## 다운로드 산출물과 SHA256"
  "## Homebrew Cask"
  "## 포함된 rhwp core와 viewer asset provenance"
  "## 검증 결과"
  "## 릴리즈 delta 기반 추가 확인 항목"
  "## 알려진 제한 사항과 후속 이슈"
  "## Third Party notices"
)

missing_count=0
for heading in "${required_headings[@]}"; do
  if ! grep -Fxq "$heading" "$RELEASE_NOTES_FILE"; then
    echo "ERROR: missing required release note section: $heading" >&2
    missing_count=$((missing_count + 1))
  fi
done

if [ "$missing_count" -ne 0 ]; then
  exit 1
fi

echo "Release note template check passed: $RELEASE_NOTES_FILE"
