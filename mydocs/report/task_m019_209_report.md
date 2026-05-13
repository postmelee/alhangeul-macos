# Task M019 #209 최종 보고서

## 개요

| 항목 | 값 |
|------|----|
| 이슈 | [#209 v0.1.2 Homebrew tap 초기 공개 배포](https://github.com/postmelee/alhangeul-macos/issues/209) |
| 마일스톤 | M019 `v0.1.2` |
| 작업 브랜치 | `local/task209` |
| 대상 브랜치 | `main` |
| Homebrew tap | https://github.com/postmelee/homebrew-tap |
| tap commit | `4df9f12 Add alhangeul cask` |
| Cask token | `alhangeul` |
| 설치 명령 | `brew install --cask postmelee/tap/alhangeul` |

## 결과

`v0.1.2` public DMG URL과 SHA256 기준으로 Homebrew Cask를 공개했다. Cask token은 앱 이름 기준 `alhangeul`로 확정했고, release DMG 파일명과 저장소명은 기존 `alhangeul-macos`를 유지했다.

사용자-facing 안내는 README, GitHub Pages, GitHub Release body, release note template에 같은 설치 명령으로 반영했다.

## 변경 요약

- `postmelee/homebrew-tap`
  - `Casks/alhangeul.rb` 추가
  - `version "0.1.2"`
  - `sha256 "37a27321f03a84b8b28749b5f839ea5c5833975d20f2479e3b79ebd665811ead"`
  - public DMG URL: `https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.2/alhangeul-macos-0.1.2.dmg`
- 본 저장소
  - Cask source를 `Casks/alhangeul.rb`로 정리
  - `scripts/update-cask-sha256.sh` Cask path 갱신
  - `scripts/ci/write-release-notes.sh` Homebrew Cask 안내 갱신
  - README와 Pages 업데이트 문서에 Homebrew 설치 명령 반영
  - `mydocs/release/v0.1.2.md`, `mydocs/release/index.md`, Homebrew Cask 배포 가이드 갱신
- GitHub
  - #209 이슈 본문을 실제 Cask token과 검증 명령 기준으로 갱신
  - `v0.1.2` GitHub Release body를 Homebrew Cask 검증 완료 안내로 갱신

## 검증

| 명령 | 결과 |
|------|------|
| `ruby -c Casks/alhangeul.rb` | 통과 |
| `./scripts/update-cask-sha256.sh --dry-run 0.1.2 /private/tmp/alhangeul-macos-0.1.2.dmg.sha256` | 통과 |
| `bash -n scripts/ci/write-release-notes.sh scripts/update-cask-sha256.sh` | 통과 |
| `scripts/ci/check-release-notes-template.sh /private/tmp/alhangeul-release-notes-0.1.2-homebrew.md` | 통과 |
| `git diff --check` | 통과 |
| `brew style --cask alhangeul` | 통과 |
| `brew audit --cask alhangeul` | 통과 |
| `brew audit --cask --new alhangeul` | `GitHub repository not notable enough`로 실패. 공식 `Homebrew/homebrew-cask` 신규 제출 기준이므로 maintainer tap 공개 gate에서는 비차단 |
| `brew install --cask --appdir=/private/tmp/alhangeul-cask-appdir postmelee/tap/alhangeul` | 통과 |
| `/private/tmp/alhangeul-cask-appdir/Alhangeul.app` bundle version/build 확인 | `0.1.2 (8)` |
| `brew uninstall --cask alhangeul` | 통과 |

## 특이 사항

- 기본 appdir 설치 smoke는 `/Applications/Alhangeul.app`이 이미 존재해 Homebrew가 overwrite를 거부했다. 기존 앱은 `0.1.2 (8)`로 확인했고 삭제하지 않았다.
- 설치 smoke는 기존 사용자 앱을 건드리지 않기 위해 임시 appdir로 수행했다.
- `Homebrew/homebrew-cask` 공식 저장소 제출은 repository notability 기준을 충족한 뒤 별도 작업으로 다룬다.

## 후속

- PR merge 후 #209를 close한다.
- PR merge 후 `publish/task209`와 `local/task209` 부산물을 정리한다.
