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
  "## 지원 환경과 아키텍처"
  "## 설치 후 첫 실행과 Quick Look/Thumbnail 활성화 안내"
  "## 업데이트 확인 방법"
  "## 상세 문서"
  "## 이번 버전의 주요 변경 사항"
  "### 변경 요약"
  "### 포함된 rhwp 변화"
  "### 알한글 앱 변화"
  "## 다운로드 산출물과 SHA256"
  "## Homebrew Cask"
  "## Release metadata"
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

forbidden_texts=(
  "Release owner는"
  "release owner가 보정"
  "보정합니다"
  "초안"
  "HostApp, Quick Look, Finder thumbnail, 저장/다른 이름 저장, PDF/인쇄/공유, 설치, 업데이트, About, DMG, Homebrew, Pages/Sparkle 변경"
  "문서 전용 변경과 설치본 smoke가 필요한 변경은 release delta checklist에서 구분합니다"
  "Homebrew Cask는 public DMG URL/SHA256과 tap context 검증을 통과했습니다"
)

for forbidden_text in "${forbidden_texts[@]}"; do
  if grep -Fq "$forbidden_text" "$RELEASE_NOTES_FILE"; then
    echo "ERROR: release notes contain placeholder or unverified public wording: $forbidden_text" >&2
    exit 1
  fi
done

if ! grep -Eq '\[`mydocs/release/v[0-9]+\.[0-9]+\.[0-9]+[^`]*\.md`\]\(https://github.com/[^)]*/blob/[^)]*/mydocs/release/v[0-9]+\.[0-9]+\.[0-9]+[^)]*\.md\)' "$RELEASE_NOTES_FILE"; then
  echo "ERROR: release notes must link to the public mydocs/release/v<version>.md document" >&2
  exit 1
fi

echo "Release note template check passed: $RELEASE_NOTES_FILE"
