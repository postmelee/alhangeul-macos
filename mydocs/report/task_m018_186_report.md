# Task M018 #186 최종 보고서

## 작업 요약

- 이슈: [#186 GitHub Actions Node.js 20 deprecation warning 대응](https://github.com/postmelee/alhangeul-macos/issues/186)
- 마일스톤: M018 (`v0.1.1`)
- 기준 브랜치: `devel-webview`
- 작업 브랜치: `local/task186`
- 단계 수: Stage 1~3 구현 완료, Stage 4 최종 검증/보고

이번 작업은 GitHub Actions JavaScript action runtime deprecation warning이 PR/release 판단을 흐리지 않도록 official action major를 Node.js 24 runtime 대응 버전으로 갱신했다. Pages deployment model 전환은 #206으로 분리하고, #186에서는 branch Pages/appcast push 구조를 유지했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/pr-ci.yml` | `actions/checkout@v4`를 `actions/checkout@v6`로 갱신 |
| `.github/workflows/rhwp-upstream-check.yml` | `actions/checkout@v4`를 `actions/checkout@v6`로 갱신 |
| `.github/workflows/release-rehearsal.yml` | `actions/checkout@v6`, `actions/upload-artifact@v7`로 갱신 |
| `.github/workflows/release-publish.yml` | `actions/checkout@v6`, `actions/upload-artifact@v7`로 갱신 |
| `mydocs/manual/ci_workflow_guide.md` | JavaScript action runtime warning 대응의 일반 점검 기준 추가 |
| `mydocs/manual/document_structure_guide.md` | manual 문서 중립성 정책 추가 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | Pages 배포 모델 기준을 특정 이슈 번호 없이 일반화 |
| `mydocs/troubleshootings/github_actions_node20_deprecation.md` | Node.js 20 deprecation warning 대응 사건 기록 분리 |
| `mydocs/plans/task_m018_186.md` | 수행계획서 |
| `mydocs/plans/task_m018_186_impl.md` | 구현계획서 |
| `mydocs/working/task_m018_186_stage1.md` | Stage 1 official action/runtime 기준과 영향 분석 |
| `mydocs/working/task_m018_186_stage2.md` | Stage 2 workflow action major 갱신 보고 |
| `mydocs/working/task_m018_186_stage3.md` | Stage 3 문서화와 troubleshooting 분리 보고 |
| `mydocs/orders/20260510.md` | #186 오늘할일 완료 처리 |

## action version 변경

| action | 변경 전 | 변경 후 | 개수 |
|--------|---------|---------|------|
| `actions/checkout` | `actions/checkout@v4` | `actions/checkout@v6` | 7 |
| `actions/upload-artifact` | `actions/upload-artifact@v4` | `actions/upload-artifact@v7` | 5 |

유지한 경계:

- PR CI trigger와 job 조건 유지
- release rehearsal/publish `workflow_dispatch` 입력 유지
- release publish `environment: release` 유지
- tag 검증, GitHub Release asset upload, Sparkle appcast 생성 조건 유지
- branch Pages/appcast push 구조 유지
- 임시 runtime 우회 환경변수 미사용

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| workflow YAML parse 통과 | OK | `pr-ci.yml`, `release-rehearsal.yml`, `release-publish.yml`, `rhwp-upstream-check.yml` 모두 `Psych.parse_file` exit code 0 |
| shell helper syntax 통과 | OK | `bash -n scripts/ci/*.sh` exit code 0 |
| PR 변경 범위가 release checks로 분류됨 | OK | `scripts/ci/classify-pr-changes.sh devel-webview HEAD` 결과 `run_release_checks=true` |
| v4 action reference 제거 | OK | `.github/workflows`에서 `actions/checkout@v4`, `actions/upload-artifact@v4` 없음 |
| v6/v7 action reference 기대 개수 확인 | OK | `actions/checkout@v6` 7곳, `actions/upload-artifact@v7` 5곳 |
| manual 중립성 보정 확인 | OK | `mydocs/manual`에서 `Node.js 20`, `Node.js 24`, `node24`, `checkout@v6`, `upload-artifact@v7`, `#206` 검색 결과 없음 |
| troubleshooting 사건 기록 확인 | OK | `github_actions_node20_deprecation.md`에 Node.js 20/24, action major, #206 handoff 기록 |
| release delta checklist dry-run 통과 | OK | `scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md` exit code 0 |
| release note helper dry-run 통과 | OK | `write-release-notes.sh`와 `check-release-notes-template.sh` exit code 0 |
| Sparkle appcast helper dry-run 통과 | OK | `write-sparkle-appcast.sh ... --output build.noindex/release/appcast.xml`와 `xmllint --noout` exit code 0 |
| GitHub Actions workflow lint 통과 | OK | `actionlint` exit code 0 |
| whitespace/diff 검사 | OK | `git diff --check` exit code 0 |

YAML parse 시 로컬 Ruby 환경에서 `ffi-1.13.1` extension warning이 출력됐지만, parse 명령은 모두 exit code 0으로 완료됐다.

## 미실행 검증

- GitHub-hosted Actions 실제 PR run은 아직 실행하지 않았다. PR 생성 후 `PR CI`에서 Node.js 20 deprecation annotation이 해소됐는지 확인해야 한다.
- `xcodegen generate`와 `xcodebuild ... HostApp ... build`는 실행하지 않았다. 이번 변경 범위는 workflow/manual 중심이고 `classify-pr-changes.sh devel-webview HEAD`가 `run_macos_build=false`로 분류했다.
- `Release Rehearsal DMG`와 `Release Publish DMG` workflow 실제 실행은 수행하지 않았다. release workflow 실행은 macOS runner, signing/notarization, Sparkle key, GitHub Release 권한이 필요한 보호 영역이다.

## 잔여 위험과 후속 작업

- PR 게시 후 실제 GitHub-hosted runner에서 `PR CI` annotation을 확인해야 한다.
- #206: Pages/appcast 배포 방식을 `deploy-pages` workflow로 전환할지는 별도 작업에서 branch publishing, appcast push, permissions, Pages source 설정을 함께 검토한다.
- #188 release 실행 시에는 PR run 결과와 release workflow summary/artifact를 release report에 다시 기록해야 한다.
- future action major 갱신 시에는 `ci_workflow_guide.md`의 일반 점검 기준을 따르고, 특정 warning 사건의 세부값은 `mydocs/troubleshootings/`에 분리한다.

## PR 준비 상태

최종 로컬 검증과 보고서 작성을 완료했다. PR 게시 후 GitHub Actions 결과를 확인하고, 리뷰 후 merge 승인을 요청한다.
