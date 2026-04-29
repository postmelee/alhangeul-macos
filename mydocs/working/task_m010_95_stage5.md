# Task #95 Stage 5 완료 보고서

## 단계 목적

`rhwp v0.7.8` Stable tag 승격 결과를 현재 기준 문서에 반영하고, 전체 검증 결과와 잔여 리스크를 최종 보고서로 정리한다.

## 산출물

- `mydocs/tech/project_architecture.md`
  - core 기준 요약을 `v0.7.8` Stable release tag pin 상태로 갱신
- `mydocs/manual/core_dependency_operation_guide.md`
  - 운영 가이드의 현재 core 기준을 `v0.7.8`과 resolved commit 기준으로 갱신
- `mydocs/tech/core_release_compatibility.md`
  - current release 상태, current dependency 형식, use case 검증 결과를 `v0.7.8` 기준으로 갱신
- `mydocs/orders/20260430.md`
  - #95 상태를 완료로 갱신
- `mydocs/working/task_m010_95_stage5.md`
  - Stage 5 결과 기록
- `mydocs/report/task_m010_95_report.md`
  - Task #95 최종 결과 보고서

## 본문 변경 정도 / 본문 무손실 여부

- Rust, Swift, Xcode project, generated framework 산출물은 수정하지 않았다.
- 현재 상태를 설명하는 기준 문서만 갱신했다.
- 과거 단계 보고서와 수행/구현 계획서에 남아 있는 `v0.7.7`, `e91ecea`, `demo-commit-pin`, Stable blocked 표현은 당시 시점 기록으로 유지했다.
- Demo/Preview gate 설명에 남아 있는 `demo-commit-pin`은 일반 운영 규칙이므로 stale current status로 보지 않는다.

## 변경 내용

`mydocs/tech/project_architecture.md`와 `mydocs/manual/core_dependency_operation_guide.md`의 현재 lock 설명을 다음 기준으로 보정했다.

```text
rhwp release tag: v0.7.8
resolved commit: 42cf91b6ba7b50fa1c853c01158a52ef68b45442
dependency form: tag = "v0.7.8"
```

`mydocs/tech/core_release_compatibility.md`에는 다음 현재 상태를 반영했다.

- `v0.7.8`은 required API gate를 통과한다.
- 현재 `RustBridge/Cargo.lock` source는 `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.8#42cf91b6ba7b50fa1c853c01158a52ef68b45442`다.
- `v0.7.8`에는 PageRenderTree API와 PageLayerTree API가 모두 포함된다.
- 이번 작업은 기존 PageRenderTree 기반 C ABI와 Swift renderer를 유지하며, PageLayerTree 기반 renderer 전환은 후속 작업으로 분리한다.
- 작업지시자 수동 smoke 결과로 HostApp, Quick Look Preview, Finder Thumbnail 체크리스트 통과를 기록했다.

## 검증 결과

```bash
$ git diff --check
```

결과: 통과.

```bash
$ ./scripts/build-rust-macos.sh --verify-lock
```

결과:

```text
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

명령 중 CoreSimulator/cache 관련 경고가 출력됐지만 exit code 0으로 완료했다.

```bash
$ ./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

```bash
$ xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [5.709 sec]
```

CoreSimulatorService, provisioning profile, Xcode plist detector 관련 경고가 출력됐지만 macOS Debug build는 성공했다.

```bash
$ ./scripts/validate-stage3-render.sh
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=434 hangulRuns=75 hangulScalars=205 nonWhitePixels=410503
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53220
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=131 hangulRuns=84 hangulScalars=1336 nonWhitePixels=171049
```

```bash
$ rg -n "v0\\.7\\.7|v0\\.7\\.8|e91ecea3174a0da0ad7a1ea495cacc4f8772c31d|demo-commit-pin|Stable 전환|Stable.*blocked|latest release" README.md rhwp-core.lock RustBridge mydocs/tech mydocs/manual mydocs/plans/task_m010_76.md mydocs/plans/task_m010_95.md mydocs/plans/task_m010_95_impl.md
```

결과 분류:

- 현재 기준 문서 `project_architecture.md`, `core_dependency_operation_guide.md`, `core_release_compatibility.md`는 `v0.7.8` Stable release tag pin 상태를 설명한다.
- `task_m010_76.md`, `task_m010_95.md`, `task_m010_95_impl.md`의 `v0.7.7`/Stable blocked 표현은 과거 계획 또는 이번 작업 전 조사 기준 기록이다.
- `core_release_compatibility.md`의 `demo-commit-pin`은 Demo/Preview 채널 운영 규칙과 gate 설명에 남아 있는 일반 규칙이다.

```bash
$ git status --short
```

결과: Stage 5 문서 변경과 최종 보고서만 남아 있음을 확인했다.

## 잔여 위험

- `v0.7.8`에 PageLayerTree API가 포함되어 있지만, 앱은 이번 작업에서 PageRenderTree 기반 C ABI와 Swift renderer를 유지한다. PageLayerTree 전환은 별도 설계와 ABI 작업이 필요하다.
- Quick Look Preview와 Finder Thumbnail은 작업지시자 수동 smoke로 통과했다. 배포 전 release rehearsal에서는 설치/등록 상태에서 다시 확인해야 한다.
- 문서 검색 결과의 과거 계획/보고서 stale 표현은 히스토리 보존을 위해 수정하지 않았다. 현재 상태 문서는 `v0.7.8` 기준으로 정리되어 있다.

## 다음 단계 영향

Task #95의 구현/검증/문서 정리는 완료됐다. 작업지시자 승인 후 `publish/task95` 원격 push와 devel 대상 draft PR 생성 단계로 진행할 수 있다.

## 승인 요청

Stage 5 완료와 최종 보고서 검토 후 PR 게시 단계 진행 여부 승인을 요청한다.
