# Task M018 #198 최종 보고서

## 작업 요약

- 이슈: [#198 PR 생성 CI와 릴리즈 검증 CI 보강](https://github.com/postmelee/alhangeul-macos/issues/198)
- 마일스톤: M018 (`v0.1.1`)
- 기준 브랜치: `devel-webview`
- 작업 브랜치: `local/task198`
- 단계 수: Stage 1~4 구현 완료, Stage 5 최종 검증/보고

이번 작업은 PR 생성/갱신 시 실행되는 기본 CI gate를 추가하고, release rehearsal/publish workflow에 release delta checklist 생성 경로를 연결했다. release publish는 기존처럼 보호된 수동 실행, tag 검증, `environment: release`, signing/notarization 경계를 유지한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/pr-ci.yml` | `pull_request` 기반 PR CI 추가. 변경 범위 분류, script checks, 조건부 macOS validation, 조건부 release helper checks를 분리 |
| `.github/workflows/release-rehearsal.yml` | `previous_release_ref` input, release delta checklist summary/artifact 생성 추가 |
| `.github/workflows/release-publish.yml` | `previous_release_ref` input, tag validation 이후 release delta checklist summary/artifact 생성 추가. 기존 `environment: release`와 publish 경로 유지 |
| `scripts/ci/classify-pr-changes.sh` | PR 변경 파일을 `docs_only`, `run_macos_build`, `run_rust_verify`, `run_render_smoke`, `run_release_checks`로 분류하는 helper 추가 |
| `scripts/ci/write-release-delta-checklist.sh` | release workflow path가 delta checklist에서 release 영향 영역에 분류되도록 보강 |
| `mydocs/manual/ci_workflow_guide.md` | PR CI, release rehearsal/publish, rhwp upstream check의 trigger, 권한, 로컬 재현 명령 문서화 |
| `mydocs/manual/release_distribution_guide.md` | CI guide 연결, release workflow 자산, `previous_release_ref`/delta artifact 확인 기준 추가 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | workflow에서 생성되는 delta checklist input, candidate ref, artifact 이름, summary 위치 추가 |
| `mydocs/manual/release_packaging_dmg_guide.md` | `Release Rehearsal DMG` workflow 입력과 DMG/checksum/delta artifact 기준 추가 |
| `mydocs/manual/document_structure_guide.md` | 릴리즈 매뉴얼 분리 정책에 CI workflow guide 추가 |
| `README.md` | 개발자 Checks 섹션에 CI workflow guide 링크 추가 |
| `mydocs/plans/task_m018_198.md` | 수행계획서 |
| `mydocs/plans/task_m018_198_impl.md` | 구현계획서 |
| `mydocs/working/task_m018_198_stage1.md` | Stage 1 CI 경계와 변경 범위 기준 보고 |
| `mydocs/working/task_m018_198_stage2.md` | Stage 2 PR CI workflow/helper 구현 보고 |
| `mydocs/working/task_m018_198_stage3.md` | Stage 3 release workflow delta checklist 연결 보고 |
| `mydocs/working/task_m018_198_stage4.md` | Stage 4 CI 역할 문서화 보고 |
| `mydocs/orders/20260510.md` | #198 오늘할일 완료 처리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| PR CI workflow | 없음 | `PR CI` 1개 추가 |
| PR 변경 범위 분류 helper | 없음 | `scripts/ci/classify-pr-changes.sh` 추가 |
| PR CI flag | 없음 | `docs_only`, `run_macos_build`, `run_rust_verify`, `run_render_smoke`, `run_release_checks` |
| release delta checklist workflow 연결 | 로컬 helper 중심 | rehearsal/publish workflow summary와 artifact로 연결 |
| release publish 보호 조건 | `workflow_dispatch`, `environment: release`, tag 검증 | 유지 |
| CI 운영 문서 | release guide에 분산 | `ci_workflow_guide.md`로 분리하고 release guide에서 링크 |
| Stage 1~4 산출물 diff | 기준 없음 | 18 files, 1704 insertions, 10 deletions |
| 단계 커밋 | 0개 | 계획/구현/Stage 1~4 총 6개 커밋 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 새/수정 workflow YAML parse 통과 | OK | `pr-ci.yml`, `release-rehearsal.yml`, `release-publish.yml`, `rhwp-upstream-check.yml` 모두 `Psych.parse_file` exit code 0 |
| shell helper syntax 통과 | OK | `bash -n scripts/ci/*.sh` exit code 0 |
| PR CI helper interface와 분류 결과 확인 | OK | `scripts/ci/classify-pr-changes.sh --help`, `scripts/ci/classify-pr-changes.sh devel-webview HEAD` 통과 |
| 현재 PR 변경 범위가 release checks로 분류됨 | OK | `run_release_checks=true`, `run_macos_build=false`, `run_rust_verify=false`, `run_render_smoke=false` |
| release note template dry-run 통과 | OK | `write-release-notes.sh` + `check-release-notes-template.sh` 통과 |
| release delta checklist 생성 통과 | OK | `write-release-delta-checklist.sh v0.1.0 HEAD ...` 통과, 영향 영역 heading 검색 확인 |
| Sparkle appcast helper dry-run 통과 | OK | `write-sparkle-appcast.sh ...` + `xmllint --noout` 통과 |
| shared Swift boundary 확인 | OK | `./scripts/check-no-appkit.sh` 통과 |
| workflow/helper/manual 연결 검색 | OK | `rg`로 `pull_request`, `classify-pr-changes`, `previous_release_ref`, `environment: release` 등 확인 |
| whitespace/diff 검사 | OK | `git diff --check` 통과 |

## 미실행 검증

- GitHub-hosted Actions 실제 PR run은 아직 실행하지 않았다. PR 생성 후 `PR CI`에서 실제 runner 기준으로 확인해야 한다.
- `xcodegen generate`와 `xcodebuild ... HostApp ... build`는 이번 변경 범위가 workflow/script/manual 중심이고 `classify-pr-changes.sh devel-webview HEAD`가 `run_macos_build=false`로 분류해 로컬에서 실행하지 않았다.
- `Release Rehearsal DMG`와 `Release Publish DMG` workflow 실제 실행은 수행하지 않았다. rehearsal은 macOS runner DMG build가 필요하고, publish는 `environment: release`, Developer ID, notarization, Sparkle private key, GitHub Release 권한이 필요한 보호 영역이다.

## 잔여 위험과 후속 작업

- GitHub Actions expression, runner image, `actions/upload-artifact`, macOS runner toolchain 동작은 PR 게시 후 실제 Actions 결과로 최종 확인해야 한다.
- `actionlint`가 로컬에 설치되어 있지 않아 전용 GitHub Actions lint는 수행하지 못했다. YAML parse와 helper dry-run으로 대체했다.
- 변경 범위 분류는 path 기반이므로 새 source/layout/script path가 추가될 때 `classify-pr-changes.sh`와 `ci_workflow_guide.md`를 함께 갱신해야 한다.
- release delta checklist는 자동 승인 장치가 아니다. #188 release 실행 시 release owner가 workflow artifact 또는 로컬 helper 출력의 누락/과잉을 보정해야 한다.
- #188 handoff: `previous_release_ref`, workflow summary, delta checklist artifact, public DMG SHA256, Pages/appcast 상태를 release report에 다시 기록해야 한다.

## 작업지시자 승인 요청

최종 검증과 보고서 작성을 완료했다. PR 게시 후 GitHub Actions 결과를 확인하고, 리뷰 후 merge 승인을 요청한다.
