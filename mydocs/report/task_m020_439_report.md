# Task #439 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#439 rhwp Upstream Sync PR에 RhwpCoreBuildInfo 갱신과 검증 gate 추가](https://github.com/postmelee/alhangeul-macos/issues/439) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 기준 통합 브랜치 | `devel` |
| 작업 브랜치 | `local/task439` |
| 게시 브랜치 | `publish/task439` |
| 단계 | Stage 1~4 |
| current core identity | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` / `native-skia` |

Upstream full sync에서 `rhwp-core.lock`만 새 release로 바뀌고 `RhwpCoreBuildInfo.swift`가 이전 값에 남는 재발 경로를 제거했다. Complete lock을 단일 진실 원천으로 삼아 deterministic writer와 verifier를 분리하고, sync candidate만 source를 갱신하며 PR CI와 release workflow는 drift를 자동 수정하지 않고 차단하도록 구성했다.

핵심 결과:

- Stable/Demo lock을 지원하는 deterministic Swift build-info writer와 isolated fixture test를 추가했다.
- Upstream sync가 complete lock 직후 writer/verifier를 실행하고 generated Swift source를 명시 stage한다.
- PR CI와 release rehearsal/publish가 tracked build-info drift를 blocking failure로 처리한다.
- Helper/Swift source 변경이 macOS·Rust/core·필요한 render/release gate를 건너뛰지 않게 path classification을 보강했다.
- Core dependency, CI와 release 운영 문서를 같은 writer/verifier 책임 계약으로 정렬했다.
- 현재 production lock/build info는 no-diff이며 Issue #375, PR #463, public release 상태는 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | Complete lock 뒤 writer/verifier 실행, verification summary/body 전달, `RhwpCoreBuildInfo.swift` explicit stage |
| `.github/workflows/pr-ci.yml` | Helper fixture와 interface 검사, macOS tracked build-info verifier gate |
| `.github/workflows/release-rehearsal.yml` | Rust/core lock verify 뒤 build-info verifier를 rehearsal DMG 전 blocking gate로 실행 |
| `.github/workflows/release-publish.yml` | Rust/core lock verify 뒤 build-info verifier를 signing/notarization 전 blocking gate로 실행 |
| `scripts/update-rhwp-core-build-info.sh` | Complete Stable/Demo lock에서 고정 형식 Swift source를 안전하게 생성하는 신규 writer |
| `scripts/verify-rhwp-core-build-info.sh` | Stable/Demo mapping, 명시 fixture 경로와 입력 validation을 지원하는 verifier |
| `scripts/ci/read-rhwp-core-lock.sh` | 기존 `<key>` 호출을 유지하며 `--lock-file` fixture 경로와 누락 key 오류를 지원 |
| `scripts/ci/test-rhwp-core-build-info.sh` | 정상, stale, malformed, no-diff, production 파일 무손실 isolated fixture |
| `scripts/ci/classify-pr-changes.sh` | Build-info source/helper/reader/test 변경에 macOS와 Rust/core gate 활성화 |
| `scripts/ci/write-rhwp-full-sync-pr-body.sh` | Generated build-info scope와 maintainer 정합성 checklist 추가 |
| `scripts/update-rhwp-core.sh` | Complete lock 이후 writer→verifier→shared boundary 순서 안내 |
| `mydocs/manual/core_dependency_operation_guide.md` | Stable/Demo mapping, 표준 update 순서, sync/PR/release 책임과 current v0.8.2 pin 기록 |
| `mydocs/manual/ci_workflow_guide.md` | Fixture, classification, sync mutation, PR/release blocking gate와 로컬 재현 기록 |
| `mydocs/manual/release_distribution_guide.md` | 자동 gate와 maintainer 확인 경계, public release checklist 갱신 |
| `mydocs/plans/task_m020_439.md` | 목적, 범위, 설계 방향, 위험과 후속 순서 |
| `mydocs/plans/task_m020_439_impl.md` | 4단계 구현 계획, 판정 규칙과 단계별 검증 명령 |
| `mydocs/working/task_m020_439_stage1.md` | 호출 graph, helper interface와 Stable/Demo 경계 조사 결과 |
| `mydocs/working/task_m020_439_stage2.md` | Writer/verifier/reader와 fixture 구현·검증 결과 |
| `mydocs/working/task_m020_439_stage3.md` | Sync·PR CI·release workflow 연결과 generated body 검증 결과 |
| `mydocs/working/task_m020_439_stage4.md` | 운영 문서, 전체 회귀와 #375/#463 handoff |
| `mydocs/report/task_m020_439_report.md` | Stage 1~4 최종 결과와 PR 리뷰·후속 작업 경계 |
| `mydocs/orders/20260813.md` | #439 작업 등록, 단계 진행과 완료 시각 |

제품 renderer, Thumbnail cache 구조, `project.yml`, `rhwp-core.lock`, `RhwpCoreBuildInfo.swift`, Rust dependency와 bundled studio asset은 Task #439에서 변경하지 않았다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행 계획 | `ac273ff` | 이슈 범위, branch, 오늘할일과 4단계 검증 경계 등록 |
| 구현 계획 | `b67f8d7` | Writer/verifier/test 계약, sync/PR/release 책임과 판정 규칙 확정 |
| Stage 1 | `1fcd8b8` | Lock 완성 시점, Stable/Demo mapping과 exact helper interface 확정 |
| Stage 2 | `ec06000` | Deterministic writer, verifier/reader 확장과 isolated fixture 구현 |
| Stage 3 | `f5ac6f9` | Sync mutation, PR CI/release blocking gate, classification과 generated body 연결 |
| Stage 4 | `2bbd197` | 운영 문서 정렬, 전체 회귀와 #375/#463 handoff 확정 |
| 최종 보고 | 이번 커밋 | 최종 수용 결과, 잔여 위험과 PR 리뷰 요청 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| Build-info writer | 없음 | 전용 writer 1개, 161줄 |
| Isolated helper test | 없음 | fixture test 1개, 224줄 |
| Verifier | Stable release tag 직접 비교, repository 기본 경로만 지원, 83줄 | Stable/Demo baseline, 명시 fixture 경로와 입력 검증 지원, 172줄 |
| Lock reader | repository lock `<key>`만 지원, 59줄 | 기존 호출 호환 + `--lock-file`, 명시 누락 key 오류, 86줄 |
| Fixture lock case | 없음 | 정상 Stable/Demo 2종, stale 3종, invalid lock 9종, interface 오류 3종 |
| Workflow build-info gate | 없음 | Sync writer/verifier 1곳, PR CI fixture/verifier, release verifier 2곳 |
| Explicit classification path | 없음 | Swift source, writer, verifier, reader, fixture test 5개 |
| Workflow YAML parse | 기존 workflow | 전체 6개 workflow 통과 |
| 단계 보고서 | 없음 | Stage 1~4 보고서 4개 |
| Stage 4 commit 기준 diff | 없음 | 21 files, `+1,918 / -41`, 제품 source diff 0 |
| 최종 PR 파일 범위 | 없음 | 최종 보고서 포함 22 files, `+2,093 / -41` |

## 핵심 동작 계약

### Writer

1. `scripts/update-rhwp-core.sh`가 Cargo dependency와 lock skeleton을 갱신한다.
2. `scripts/build-rust-macos.sh --update-lock`가 enabled features와 artifact metadata를 기록해 lock을 완성한다.
3. `scripts/update-rhwp-core-build-info.sh`가 고정된 5줄 Swift source를 같은 directory의 임시 파일에 생성한다.
4. 임시 source가 verifier를 통과하고 기존 output과 다를 때만 원자적으로 교체한다.
5. 같은 input에서는 `already up to date`로 종료해 tracked source를 다시 쓰지 않는다.

Stable은 `rhwp_release_tag`, 실제 commit/features를 기록한다. Demo/Preview는 `rhwp_latest_checked_release_tag`를 Stable baseline label로 사용하되 실제 demo commit/features를 기록한다. Incomplete/malformed lock은 output을 변경하지 않고 실패한다.

### Workflow 책임

| 경로 | Writer | Verifier | 실패 의미 |
|------|--------|----------|-----------|
| Upstream sync candidate | 실행 | 실행 | 잘못된 candidate 생성을 중단 |
| PR CI script-checks | 실행하지 않음 | isolated fixture | Helper contract 회귀를 중단 |
| PR CI macOS validation | 실행하지 않음 | tracked source | PR source drift를 중단 |
| Release rehearsal | 실행하지 않음 | tracked source | Rehearsal DMG 전에 중단 |
| Release publish | 실행하지 않음 | tracked source | Signing/notarization/public artifact 전에 중단 |

## 검증 결과

| 수용 기준 | 결과 | 확인 내용 |
|----------|------|-----------|
| Helper shell syntax | OK | Update/writer/verifier/test/classifier/PR body helper `bash -n` 통과 |
| Stable writer | OK | Expected Swift source 생성, verifier 통과와 반복 실행 no-diff |
| Demo writer | OK | Latest checked Stable baseline + 실제 commit/features mapping 통과 |
| Stale build info | OK | Tag, commit, features 각각 verifier 실패 후 writer로 수렴 |
| Incomplete/malformed lock | OK | 필수 key 누락·형식 오류에서 기존 output hash 유지 |
| Fixture 무손실 | OK | Test 전후 production lock/build-info SHA-256 동일 |
| Production writer | OK | `RhwpCoreBuildInfo.swift`를 다시 쓰지 않고 `already up to date` |
| Production verifier | OK | `RhwpCoreBuildInfo matches rhwp-core.lock` |
| Source/lock no-diff | OK | `git diff --exit-code -- RhwpCoreBuildInfo.swift rhwp-core.lock` 통과 |
| Path classification | OK | Helper diff는 macOS/Rust/release, Swift diff는 macOS/Rust/render gate 활성화 |
| Workflow YAML | OK | `.github/workflows/*.yml` 6개 Psych parse 통과 |
| Embedded workflow bash | OK | 수정된 4개 workflow `run` block syntax 통과 |
| Generated PR body | OK | GitHub body validator와 build-info scope/verification/checklist 확인 |
| Writer mutation 경계 | OK | 옵션 없는 writer는 upstream sync candidate 경로 1곳에만 존재 |
| 운영 문서 정합성 | OK | Core·CI·release 가이드가 같은 책임 계약 설명 |
| Diff 품질 | OK | `git diff --check` 통과 |
| 통합 브랜치 관계 | OK | 최종 보고서 작성 전 `origin/devel` 대비 behind 0, ahead 6 확인 |

최종 통합 검증 결과:

```text
OK: RhwpCoreBuildInfo writer and verifier fixtures passed
OK: RhwpCoreBuildInfo is already up to date: .../RhwpCoreBuildInfo.swift
OK: RhwpCoreBuildInfo matches rhwp-core.lock
Task #439 integrated validation: OK
```

## 잔여 위험과 후속 작업

### Task #439 PR

- Local static/integration gate는 통과했지만 GitHub-hosted macOS/Rust/render job은 PR 생성 후 확인해야 한다.
- PR CI가 모두 통과한 뒤에만 `devel` merge를 승인한다.
- Merge 후 Issue close와 branch/worktree cleanup은 `pr-merge-cleanup` 절차로 별도 수행한다.

### Issue #375

[#375 source_cargo_lock_sha256 upstream Cargo.lock 자동 비교 검증 추가](https://github.com/postmelee/alhangeul-macos/issues/375)는 open 상태다. Task #439 merge 뒤 최신 `devel`에서 별도 task로 시작한다. `scripts/verify-rhwp-studio-assets.sh`의 현재 sha256 형식 검증을 실제 target upstream root `Cargo.lock` hash 비교로 확장하되 build-info writer/verifier 계약과 섞지 않는다.

예상 겹침 파일은 `rhwp-upstream-sync-pr.yml`, full sync PR body helper와 core/CI 운영 문서다. 오래된 `devel` 또는 Task #439 branch에서 병렬 구현하지 않는다.

### PR #463

현재 [PR #463 Sync rhwp upstream v0.8.4](https://github.com/postmelee/alhangeul-macos/pull/463)은 기존 PR CI가 green이어도 Task #439/#375 gate 이전 candidate다. Lock은 v0.8.4인데 build info가 v0.8.2인 상태이므로 merge하지 않는다.

후속 순서:

1. Task #439 PR merge
2. 최신 `devel`에서 #375 구현·PR merge
3. 별도 승인 후 #463 close와 `automation/rhwp-v0.8.4-full-sync` branch cleanup
4. Upstream sync workflow 재실행
5. 새 candidate의 build info와 Cargo.lock fingerprint gate 확인 후 merge

### Public release

Task #439는 signing/notarization, GitHub Release, Pages/Sparkle와 Homebrew 작업을 실행하지 않았다. 새 v0.8.4 sync PR merge 뒤 별도 release 승인과 runbook을 따른다.

## 작업지시자 승인 요청

Task #439 PR의 변경 범위와 검증 결과를 리뷰하고 `devel` merge 여부를 승인해 달라.

특히 다음을 확인 요청한다.

1. Upstream sync만 writer를 실행하고 PR CI/release는 verifier로 차단하는 책임 분리
2. Stable/Demo release baseline mapping과 deterministic writer interface
3. #375를 Task #439 merge 뒤 최신 `devel`에서 시작하는 순서
4. 기존 PR #463을 merge하지 않고 #375 완료 뒤 cleanup·재생성하는 경계
