# Task M018 #187 Stage 2 보고서

## 단계 목적

Stage 1에서 확정한 Homebrew tap 운영 기준을 release manual, v0.1.1 release record, release note template, README에 반영한다. 실제 tap repository 생성, tap push, public install 명령 공개는 수행하지 않는다.

## 반영한 결정

### tap 운영 기준

초기 public Homebrew 배포는 `postmelee/homebrew-tap`을 기준으로 한다.

- 사용자 tap 명령: `brew tap postmelee/tap`
- 사용자 설치 명령: `brew install --cask postmelee/tap/alhangeul-macos`
- 실제 GitHub repository: `postmelee/homebrew-tap`

`Homebrew/homebrew-cask` 제출은 장기 후보로 유지하되, v0.1.1 patch release의 초기 배포 경로에서는 제외한다.

### 이슈 역할 분리

- #187: Homebrew tap 경로와 Cask 검증 절차 확정
- #188: v0.1.1 public DMG, SHA256, GitHub Release, Pages/appcast 게시
- #209: public DMG URL/SHA256 확정 후 `postmelee/homebrew-tap` 생성/동기화, Cask SHA 고정, tap context 검증, 사용자-facing Homebrew 안내 공개

따라서 #187 문서 변경에서는 Homebrew 설치 명령을 public 안내로 확정하지 않고, #209 검증 이후 공개하는 조건으로 남겼다.

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `mydocs/manual/release_homebrew_cask_guide.md` | #187/#209 역할 분리, `postmelee/homebrew-tap` 기준, tap 반영 절차, `brew style`/`brew audit`/install smoke 명령 정리 |
| `mydocs/manual/release_distribution_guide.md` | 전체 release flow와 checklist에서 Homebrew 공개 배포를 #209 후속 단계로 분리 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | GitHub Release/Pages에서 Homebrew 설치 명령을 #209 검증 전 확정 안내로 쓰지 않는 기준 추가 |
| `mydocs/release/v0.1.1.md` | #209 handoff, Homebrew Cask 검증 기준, v0.1.1 checklist 갱신 |
| `mydocs/release/index.md` | release record 역할에 #188/#209 handoff 반영 |
| `scripts/ci/write-release-notes.sh` | release note 후보에 `Homebrew Cask` 섹션 추가 |
| `scripts/ci/check-release-notes-template.sh` | `Homebrew Cask` heading을 필수 섹션에 추가 |
| `README.md` | Homebrew Cask를 tap 검증 완료 후 안내하는 기준으로 보정 |

## #209 handoff

#209에서 이어서 수행할 항목:

1. #188에서 생성된 public DMG `.sha256`을 기준으로 `scripts/update-cask-sha256.sh 0.1.1` 실행
2. `postmelee/homebrew-tap`에 `Casks/alhangeul-macos.rb` 반영
3. tap context에서 `brew style --cask alhangeul-macos` 실행
4. tap context에서 `brew audit --cask alhangeul-macos` 실행
5. 필요 시 `brew audit --cask --new alhangeul-macos` 실행
6. `brew install --cask postmelee/tap/alhangeul-macos` 및 `brew uninstall --cask alhangeul-macos` smoke 실행
7. 검증 통과 후 README, Pages, GitHub Release/릴리즈 노트에 Homebrew 설치 안내 공개

## 검증 결과

| 명령 | 결과 |
|------|------|
| `bash -n scripts/ci/write-release-notes.sh` | 통과 |
| `bash -n scripts/ci/check-release-notes-template.sh` | 통과 |
| `scripts/ci/write-release-notes.sh 0.1.1 <sample-sha> /private/tmp/alhangeul-release-notes-0.1.1.md` | 통과 |
| `scripts/ci/check-release-notes-template.sh /private/tmp/alhangeul-release-notes-0.1.1.md` | 통과 |
| `rg -n "^## Homebrew Cask\|postmelee/tap\|GitHub Release DMG" /private/tmp/alhangeul-release-notes-0.1.1.md` | `Homebrew Cask` heading과 #209 이후 공개할 설치 명령 확인 |
| `rg -n "Homebrew tap 공개 여부\|Cask SHA256은 #188\|Homebrew Cask SHA256 고정 여부\|tap 공개 여부 결정\|Homebrew.*#188" README.md mydocs/manual mydocs/release scripts/ci` | 활성 문서에서 stale 문구 없음 |
| `ruby -c Casks/alhangeul-macos.rb` | 통과 |
| `git diff --check` | 통과 |

실제 `brew style`, `brew audit`, `brew install --cask`는 public DMG URL/SHA256과 `postmelee/homebrew-tap`이 필요한 #209 범위로 남겼다.
