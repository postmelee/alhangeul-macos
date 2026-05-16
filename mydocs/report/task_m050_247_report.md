# Task M050 #247 최종 보고서

## 개요

| 항목 | 값 |
|------|----|
| 이슈 | [#247 native-viewer-editor를 최신 제품 라인 기준으로 forward-port](https://github.com/postmelee/alhangeul-macos/issues/247) |
| 마일스톤 | M050 `v0.5.0 Viewer 안정화` |
| 작업 브랜치 | `local/task247` |
| 대상 브랜치 | `native-viewer-editor` |
| 기준 제품 라인 | `origin/devel` |
| legacy alias 검토 | `origin/devel-webview`의 #243 변경 선별 포팅 |

## 최종 결과

`native-viewer-editor` 장기 라인을 최신 제품 `devel` 라인에 가깝게 forward-port했다. 기존 native renderer/editor 장기 작업을 없애는 방식이 아니라, `origin/devel`의 프로젝트 구조, build/release/CI 운영, HostApp/WebView fallback, Quick Look/Thumbnail 안정화, RustBridge/core lock 변경을 통합한 뒤 native renderer 충돌 파일을 수동 정리했다.

`origin/devel..origin/devel-webview`에 남아 있던 #243 저장 확인 변경은 source만 선별 포팅했다. `devel-webview` 전환기 문서와 branch 안내 변경은 현재 `devel` 기본 브랜치 정책과 충돌할 수 있어 제외했다.

## 변경 요약

| 영역 | 내용 |
|------|------|
| 프로젝트 구조 | `Alhangeul.xcodeproj`/`project.yml` 제품 라인 구조 채택, 구 `AlhangeulMac.xcodeproj` 제거 |
| HostApp/WebView fallback | 최신 `devel` HostApp, rhwp-studio bundled resource, save/share/print/export/recent document 계열 변경 반영 |
| RustBridge/core | `rhwp-core.lock`, `RustBridge` lock/manifest, universal staticlib build helper와 FFI symbol 표면 최신화 |
| Quick Look/Thumbnail | `origin/devel`의 input validation, preview/PDF/image rendering, thumbnail cache/provider 변경 반영 |
| Native renderer bridge | `CGTreeRenderer`, `FontFallback`, `FontResourceRegistry` 충돌 수동 해결 및 `origin/devel`과 일치 확인 |
| #243 저장 확인 | dirty-state, document close confirmation, app termination confirmation, save completion callback 선별 포팅 |
| 운영 문서/CI/release | README/CONTRIBUTING/AGENTS/manual/workflow/release helper의 최신 제품 라인 정책 반영 |
| 기록 문서 | Stage 1-5 보고서, 구현 계획서, 오늘할일, 최종 보고서 작성 |

## 단계별 요약

| 단계 | 보고서 | 요약 |
|------|--------|------|
| Stage 1 | [`task_m050_247_stage1.md`](../working/task_m050_247_stage1.md) | 기준 commit, merge-tree 충돌 inventory, #243 전용 변경 범위 고정 |
| Stage 2 | [`task_m050_247_stage2.md`](../working/task_m050_247_stage2.md) | `origin/devel` merge, project/CI/release/docs 충돌 해결 |
| Stage 3 | [`task_m050_247_stage3.md`](../working/task_m050_247_stage3.md) | `RhwpCoreBridge` renderer/font fallback 충돌 수동 통합 |
| Stage 4 | [`task_m050_247_stage4.md`](../working/task_m050_247_stage4.md) | XcodeGen, script/helper, RustBridge, HostApp build, renderer smoke 검증 |
| Stage 5 | [`task_m050_247_stage5.md`](../working/task_m050_247_stage5.md) | #243 dirty-state/close/terminate 저장 확인 source 변경 선별 포팅 |
| Stage 6 | 본 보고서 | 최종 검증, 최종 보고서, 오늘할일 완료 처리 |

## 주요 판단

### `devel` merge를 기준으로 선택

`origin/devel`에는 제품 기여 기본 브랜치 전환 이후의 프로젝트 구조와 배포/CI 정책이 누적되어 있다. commit 단위 cherry-pick보다 `origin/devel` merge 후 충돌을 수동 해결하는 편이 `native-viewer-editor`를 최신 개발 기반에 가깝게 맞추는 데 안전했다.

### native renderer 충돌 처리

`Sources/RhwpCoreBridge` 충돌 파일은 Stage 2에서 native 쪽을 보존한 뒤 Stage 3에서 `origin/devel`의 최신 안정성 보강을 수동 반영했다. 최종적으로 `CGTreeRenderer.swift`, `FontFallback.swift`, `FontResourceRegistry.swift`는 `origin/devel`과 동일한 상태로 정리했다.

### #243 포팅 범위

#243의 `DocumentCloseConfirmationController`와 `DocumentTerminationCoordinator`는 WebView 자체가 아니라 window/app lifecycle에 붙는 공통 정책이므로 native 라인에 반영했다. dirty-state 입력은 현재 남아 있는 `RhwpStudioWebView` fallback에 연결했고, 후속 native editor 구현에서는 같은 store API를 native editing surface에서 호출하도록 확장하면 된다.

문서/branch 안내 변경은 `devel-webview` legacy alias 방향으로 되돌아갈 수 있어 제외했다.

## 최종 검증

| 명령 | 결과 |
|------|------|
| `scripts/ci/classify-pr-changes.sh origin/native-viewer-editor HEAD` | `docs_only=false`, `run_macos_build=true`, `run_rust_verify=true`, `run_render_smoke=true`, `run_release_checks=true` |
| `xcodegen generate` | 통과. generated project 재생성 후 tracked diff 없음 |
| `git diff --check` | 통과 |
| `./scripts/check-no-appkit.sh` | 통과. `OK: shared Swift code has no AppKit/UIKit dependencies` |
| `for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done` | 통과 |
| `bash scripts/ci/classify-pr-changes.sh --help` | 통과 |
| `bash scripts/ci/check-rhwp-upstream-release.sh --help` | 통과 |
| `bash scripts/ci/prepare-pages-artifact.sh --help` | 통과 |
| `bash scripts/ci/write-sparkle-appcast.sh --help` | 통과 |
| `./scripts/release.sh --help` | 통과 |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock` | 통과. source provenance, Cargo lock, generated header, FFI symbols, `rhwp-core.lock` 검증 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData -clonedSourcePackagesDirPath build.noindex/SourcePackages CODE_SIGNING_ALLOWED=NO build` | 통과. `** BUILD SUCCEEDED **` |
| `./scripts/validate-stage3-render.sh` | 통과. `KTX.hwp`, `request.hwp`, `exam_kor.hwp` non-blank PNG 생성 |

`validate-stage3-render.sh`는 `KTX.hwp`에서 기존 layout overflow diagnostic을 출력했지만 exit code는 0이고 세 샘플 모두 non-blank bitmap 판정에 성공했다.

`xcodebuild`와 Rust XCFramework 생성 중 CoreSimulator service warning이 출력됐지만 macOS HostApp build와 XCFramework 생성은 실패하지 않았다.

## 미수행 범위와 잔여 리스크

- `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`을 사용했으므로 `Frameworks/universal/librhwp.a`의 byte-for-byte hash/size 검증은 생략했다. source provenance, Cargo lock, generated header, FFI symbol, `rhwp-core.lock` 검증은 통과했다.
- Debug `CODE_SIGNING_ALLOWED=NO` build 검증만 수행했다. Release packaging, signing, notarization, Finder integration smoke, Gatekeeper 검증은 이번 작업 범위가 아니다.
- close/termination confirmation의 수동 UI smoke는 수행하지 않았다. compile/link와 WebView fallback save bridge 연결은 HostApp build로 검증했다.
- `devel-webview`의 branch 안내/문서 변경은 의도적으로 제외했다.

## 다음 절차

`publish/task247`를 원격에 push하고, `native-viewer-editor` 대상 PR을 생성한다. PR 본문에는 `Closes #247`을 포함한다.
