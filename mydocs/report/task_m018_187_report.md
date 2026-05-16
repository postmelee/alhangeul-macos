# Task M018 #187 최종 보고서

## 작업 요약

- 이슈: [#187 Homebrew tap 배포 경로 확정과 Cask 검증 절차 정리](https://github.com/postmelee/alhangeul-macos/issues/187)
- 마일스톤: M018 (`v0.1.1`)
- 기준 브랜치: `devel-webview`
- 작업 브랜치: `local/task187`
- 단계 수: Stage 1~3 완료, 최종 보고

이번 작업은 v0.1.1에서 Homebrew 설치 경로를 공개하기 전에 tap 운영 경로와 검증 기준을 확정했다. 초기 공개 배포는 maintainer 소유 tap인 `postmelee/homebrew-tap` 기준으로 분리하고, #187은 정책과 검증 절차 확정, #209는 실제 tap 생성/동기화와 public Cask 배포 실행으로 역할을 나눴다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `README.md` | Homebrew Cask 안내를 tap 검증 완료 후 공개하는 기준으로 보정 |
| `mydocs/manual/release_homebrew_cask_guide.md` | `postmelee/homebrew-tap` 기준, Cask SHA 고정, tap 반영 절차, maintainer tap gate와 official cask 제출 기준 분리 |
| `mydocs/manual/release_distribution_guide.md` | 전체 release flow와 checklist에서 Homebrew 공개 배포를 #209 후속 단계로 분리 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | GitHub Release/Pages Homebrew 안내 기준 추가 |
| `mydocs/release/v0.1.1.md` | #187/#209 handoff, Homebrew Cask 검증 기준, v0.1.1 checklist 갱신 |
| `mydocs/release/index.md` | 릴리즈 기록 역할에 #188/#209 handoff 반영 |
| `scripts/ci/write-release-notes.sh` | release note 후보에 `Homebrew Cask` 섹션 추가 |
| `scripts/ci/check-release-notes-template.sh` | `Homebrew Cask` heading을 필수 release note 섹션으로 추가 |
| `mydocs/plans/task_m018_187.md` | 수행계획서 작성 |
| `mydocs/working/task_m018_187_stage1.md` | 현황 조사, 후보 tap 비교, `postmelee/homebrew-tap` 결정안 기록 |
| `mydocs/working/task_m018_187_stage2.md` | 문서와 release template 반영 결과 기록 |
| `mydocs/working/task_m018_187_stage3.md` | Homebrew tap context 검증 결과 기록 |
| `mydocs/orders/20260510.md` | #187 진행/완료 상태 갱신 |

## 변경 전·후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| Homebrew tap 대상 | 후보 상태: `postmelee/homebrew-alhangeul`, `postmelee/homebrew-tap`, 장기 후보 `Homebrew/homebrew-cask` | 초기 공개 기준을 `postmelee/homebrew-tap`으로 확정 |
| Homebrew 안내 공개 시점 | #188에서 공개 여부와 Cask SHA 상태를 함께 결정 | #188은 public DMG/SHA/appcast, #209는 tap 공개 배포와 Cask 검증 담당 |
| 검증 기준 | raw path audit 가능성이 문서상 혼재 | tap context 기준 `brew style`, 일반 `brew audit`, install/uninstall smoke로 정리 |
| `brew audit --cask --new` 의미 | maintainer tap 검증과 구분 약함 | official `Homebrew/homebrew-cask` 제출 참고 검증으로 분리 |
| release note template | Homebrew 전용 섹션 없음 | `Homebrew Cask` 섹션 추가 |
| 전체 diff | 없음 | 13 files, 420 insertions, 14 deletions |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| Cask 문법 검사 | OK | `ruby -c Casks/alhangeul-macos.rb` 통과 |
| public checksum dry-run | OK | `./scripts/update-cask-sha256.sh --dry-run 0.1.1 /private/tmp/alhangeul-macos-0.1.1.dmg.sha256` 통과 |
| rehearsal checksum guard | OK | `./scripts/update-cask-sha256.sh --dry-run 0.1.1 /private/tmp/alhangeul-macos-0.1.1-rehearsal.dmg.sha256`가 rehearsal checksum을 의도대로 거부 |
| release note helper syntax | OK | `bash -n scripts/ci/write-release-notes.sh` 통과 |
| release note check syntax | OK | `bash -n scripts/ci/check-release-notes-template.sh` 통과 |
| release note dry-run | OK | `scripts/ci/write-release-notes.sh 0.1.1 <sample-sha> /private/tmp/alhangeul-release-notes-final-0.1.1.md` 통과 |
| release note heading check | OK | `scripts/ci/check-release-notes-template.sh /private/tmp/alhangeul-release-notes-final-0.1.1.md` 통과 |
| Homebrew 섹션 생성 확인 | OK | generated note에서 `## Homebrew Cask`, `postmelee/tap`, GitHub Release DMG 우선 안내 확인 |
| stale 문구 제거 확인 | OK | 활성 문서에서 `Homebrew tap 공개 여부`, `Cask SHA256은 #188`, `tap 공개 여부 결정` 등 이전 책임 경계 문구 없음 |
| Homebrew CLI 확인 | OK | `brew --version` 결과 `Homebrew 5.1.10-52-g1c3a79e` |
| tap context style | OK | Stage 3 임시 tap에서 `brew style --cask alhangeul-macos` 통과 |
| tap context audit | OK | Stage 3 임시 tap에서 `brew audit --cask alhangeul-macos` 통과 |
| official cask 제출 참고 audit | MISS, expected | `brew audit --cask --new alhangeul-macos`는 token platform 포함과 repository notability 기준으로 실패. maintainer tap 공개 blocker가 아니라 official cask 제출 후속 기준으로 분리 |
| 임시 tap 정리 | OK | `brew untap postmelee/tap` 후 `brew tap` 목록 비어 있음 |
| whitespace/diff 검사 | OK | `git diff --check` 통과 |

## 미실행 검증

- `brew install --cask postmelee/tap/alhangeul-macos`는 실행하지 않았다. 현재 Cask source가 `version "0.1.0"`과 `sha256 :no_check` 상태라 지금 실행하면 v0.1.0 public DMG를 내려받아 사용자 시스템에 설치를 시도한다.
- 실제 `postmelee/homebrew-tap` repository 생성, Cask push, v0.1.1 install/uninstall smoke는 #209에서 수행한다.
- v0.1.1 public DMG URL/SHA256 확정은 #188 범위다.

## 잔여 위험과 후속 작업

- #209에서 public DMG SHA256이 확정되면 `scripts/update-cask-sha256.sh 0.1.1`로 `Casks/alhangeul-macos.rb`를 갱신해야 한다.
- #209에서 `postmelee/homebrew-tap`에 Cask를 반영하고 `brew style`, 일반 `brew audit`, install/uninstall smoke를 반복해야 한다.
- `brew audit --cask --new` 실패 사유는 official `Homebrew/homebrew-cask` 제출 후속 이슈에서 다룬다.
- #208의 단일 universal DMG 정책이 바뀌면 Homebrew 안내와 Cask URL/SHA 기준도 다시 확인해야 한다.

## PR 준비 상태

최종 로컬 검증과 보고서 작성을 완료했다. PR 게시 후 GitHub Actions 결과를 확인하고, 리뷰 후 merge 승인을 요청한다.
