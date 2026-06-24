# Task M900 #378 Stage 4 gate 준비 보고서

## 단계 요약

`v0.1.7` public release를 위한 `main` 반영, tag 생성, pre-public signed/notarized DMG smoke, official stable publish gate를 준비했다. 현재 후보 commit은 아직 로컬 `local/task378`에만 있으므로, 실제 tag나 publish workflow는 실행하지 않았다.

| 항목 | 값 |
|------|----|
| latest public app release | `v0.1.6`, `Alhangeul v0.1.6 (rhwp v0.7.16)` |
| latest upstream `rhwp` release | `v0.7.17` |
| current local candidate | `d9ee08fcd0a3f1f1d4b2871ec006b2caf7ee3bc2` |
| `origin/devel` | `0d3bb4f8b0b0e4acb958ce42239e490f73f7bbd5` |
| `origin/main` | `eb10d27ad802835ebd9354f47462d6ca457f3c9c` |
| `v0.1.7` tag | 없음 |
| `v0.1.7` GitHub Release | 없음 |

## Gate 판단

현재 `d9ee08fcd0a3f1f1d4b2871ec006b2caf7ee3bc2`는 `local/task378`의 pre-merge candidate다. runbook 기준 public release tag는 `main`에 반영된 최종 candidate commit에만 생성해야 한다. 따라서 다음 순서를 먼저 승인받아야 한다.

1. `publish/task378 -> devel` PR 생성과 merge
2. `devel -> main` release PR 생성과 merge
3. `main`의 최종 release candidate commit에 `v0.1.7` tag 생성과 push
4. `Release Publish DMG` `draft=true`, `prerelease=false` 실행
5. maintainer 설치 smoke 결과 확인
6. `Release Publish DMG` `draft=false`, `prerelease=false` official stable 실행

## Stage 4에서 확인한 값

| 항목 | 값 |
|------|----|
| `version` | `0.1.7` |
| `build` | `13` |
| `previous_release_ref` | `v0.1.6` |
| `expected_rhwp_tag` | `v0.7.17` |
| `require_latest_rhwp` | `true` |
| `include_rhwp_in_title` | `true` |
| pre-public publish mode | `draft=true`, `prerelease=false` |
| official stable publish mode | `draft=false`, `prerelease=false` |
| release title 후보 | `Alhangeul v0.1.7 (rhwp v0.7.17)` |

## 생성/검증한 보조 산출물

| 산출물 | 결과 |
|--------|------|
| `build.noindex/release/pr-analysis-0.1.7.md` | `scripts/ci/write-release-pr-analysis.sh v0.1.6 HEAD ...` 통과 |
| `build.noindex/release/delta-checklist-0.1.7.md` | `scripts/ci/write-release-delta-checklist.sh v0.1.6 HEAD ...` 통과 |
| `build.noindex/release/release-notes-0.1.7.md` | `scripts/ci/write-release-notes.sh 0.1.7 <placeholder-sha256> ...` 통과 |
| release note template | `scripts/ci/check-release-notes-template.sh ...` 통과 |
| GitHub body validator | `scripts/validate-github-body.sh ...` 통과 |

`release-notes-0.1.7.md`는 아직 public DMG SHA256이 없으므로 placeholder SHA256으로 형식만 검증했다. 실제 GitHub Release body는 official public DMG SHA256 확정 후 다시 생성해야 한다.

## 실행하지 않은 항목

| 항목 | 사유 |
|------|------|
| `publish/task378` push/PR 생성 | 별도 승인 gate 필요 |
| `publish/task378 -> devel` merge | 별도 승인 gate 필요 |
| `devel -> main` release PR 생성/merge | `devel`에 #378이 아직 반영되지 않음 |
| `v0.1.7` tag 생성/push | 최종 `main` candidate commit 미확정 |
| `Release Publish DMG` `draft=true` workflow | tag가 아직 없고 별도 승인 필요 |
| signed/notarized DMG 설치 smoke | pre-public workflow 산출물이 아직 없음 |
| `Release Publish DMG` `draft=false` official stable workflow | draft smoke 전이므로 실행 금지 |
| Pages/Sparkle public 확인 | official stable publish 전이므로 실행 불가 |
| Homebrew Cask 갱신 | public DMG SHA256 확정 전이므로 실행 금지 |

## 다음 승인 요청

다음 gate는 `publish/task378` 브랜치를 원격에 push하고 `devel` 대상 PR을 만드는 것이다. 이 PR이 merge된 뒤에야 `devel -> main` release PR, `v0.1.7` tag, pre-public signed/notarized DMG workflow를 순서대로 진행할 수 있다.

다음 단계 진행 승인을 요청한다.
