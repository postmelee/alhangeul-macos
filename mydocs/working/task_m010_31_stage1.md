# Task #31 Stage 1 완료 보고서

## 단계 목적

README, architecture, build/run 문서의 현재 구조와 실제 target/source 구성을 조사해 Stage 2 이후 문서 재정렬 범위를 확정한다. 이번 단계에서는 README, architecture, build/run guide 본문은 수정하지 않는다.

## 조사 대상

- `README.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/build_run_guide.md`
- `project.yml`
- `Sources/`
- `RustBridge/`
- `Frameworks/`

## 실제 target/source 구조

`project.yml` 기준 target 구성:

| target | type | sources | 주요 dependency |
|------|------|------|------|
| `HostApp` | application | `Sources/HostApp`, `Sources/Shared`, `Sources/RhwpCoreBridge` | `QLExtension`, `ThumbnailExtension`, `Frameworks/Rhwp.xcframework` |
| `QLExtension` | app-extension | `Sources/QLExtension`, `Sources/Shared`, `Sources/RhwpCoreBridge` | `Frameworks/Rhwp.xcframework` |
| `ThumbnailExtension` | app-extension | `Sources/ThumbnailExtension`, `Sources/Shared`, `Sources/RhwpCoreBridge` | `Frameworks/Rhwp.xcframework` |

실제 source 폴더:

- `Sources/HostApp`: app entrypoint, document open services, extension status model, viewer store, SwiftUI/AppKit view, localized resources, entitlements
- `Sources/QLExtension`: Quick Look preview provider, Info.plist, entitlements, localized resources
- `Sources/ThumbnailExtension`: thumbnail provider, render cache, Info.plist, entitlements, localized resources
- `Sources/Shared`: `HwpPageImageRenderer` 공통 첫 페이지 bitmap helper
- `Sources/RhwpCoreBridge`: `RhwpDocument`, render tree model, CoreGraphics/CoreText renderer, font fallback
- `RustBridge`: Rust C ABI staticlib crate, `Cargo.toml`, `Cargo.lock`, `cbindgen.toml`, `src/lib.rs`
- `Frameworks`: generated `Rhwp.xcframework`, generated header, modulemap, universal staticlib 산출물

`Sources/README.md`와 `RustBridge/README.md`는 현재 없다.

## README 현재 상태

장점:

- Features는 Finder integration, native viewer, rendering, core bridge, development workflow로 기능을 잘 나눈다.
- Quick Start는 Rust bridge build, Xcode project, native build, run, render smoke, shared bridge check, core update 순서를 포함한다.
- Project Structure는 `Sources`, `RustBridge`, `mydocs`, `scripts`를 보여준다.
- `project.yml`이 Xcode project 원본이라는 규칙과 `AlhangeulMac.xcodeproj` 직접 수정 금지 규칙이 있다.
- Demo/Preview commit pin과 Stable release tag 기준이 이미 일부 반영되어 있다.

보강 지점:

- Quick Start 첫 문단이 “온보딩 가이드(추후 추가 예정)”를 가리키지만 현재 해당 문서는 없다.
- Project Structure가 제품 target boundary보다 저장소 tree 나열에 가깝다. `HostApp`, `QLExtension`, `ThumbnailExtension`을 먼저 독립 제품 타깃으로 설명하고, 그 아래 `Shared`, `RhwpCoreBridge`, `RustBridge`, `Frameworks`, `scripts`, `mydocs` 순서로 재배열하는 편이 낫다.
- 현재 Project Structure에는 `Frameworks/`, `project.yml`, `rhwp-core.lock`, `samples/`의 역할이 충분히 보이지 않는다.
- README의 core release 표현 중 “최신 release `v0.7.3`에는 필요한 bridge API가 없어 즉시 전환할 수 없음”은 #30 이후 문맥에서는 “Stable release tag 승격이 blocked”로 더 정확히 쓰는 편이 좋다.
- 외부 참고 구현에서 의도적으로 도입하지 않는 제외 비교 표현은 아직 없다.

## Architecture 현재 상태

장점:

- `project_architecture.md`는 소유 경계, RustBridge 경계, Swift bridge 경계, macOS UI 경계, project 설정 경계를 이미 분리한다.
- Demo/Preview와 Stable 기준, `v0.7.3` Stable blocked 상태가 명시되어 있다.
- `Sources/RhwpCoreBridge`의 AppKit/UIKit 직접 의존 금지와 `Sources/Shared`의 macOS helper 역할이 분리되어 있다.
- HostApp viewer 경로와 Quick Look/Thumbnail 경로가 runtime flow로 정리되어 있다.

보강 지점:

- 상위 구조가 짧은 bullet list라 신규 진입자가 `project.yml`의 실제 target 구성과 source 포함 관계를 바로 알기 어렵다.
- 소유 경계 섹션이 core 경계부터 시작한다. Issue #31 목표에는 제품 타깃 중심 재정렬이 더 적합하므로 `HostApp`/extension/공통 계층을 먼저 설명하고 core/RustBridge/provenance를 뒤에 배치하는 편이 좋다.
- `Frameworks`가 generated artifact이며 commit 대상이 아니라는 설명은 RustBridge 경계에 있지만, 상위 구조에서는 별도 계층으로 보이지 않는다.
- 외부 참고 구현 비교에서 유지하지 않는 render 구조는 아직 architecture 문서에 없다.

## Build/Run Guide 현재 상태

장점:

- 초기 설정, core dependency 모드, Rust bridge build, Xcode project, HostApp build, render smoke, Finder 통합 확인이 순서대로 있다.
- Demo/Preview와 Stable dependency/lock 기준 표가 있다.
- `project.yml` 원본 규칙과 `build.noindex/` 사용 규칙이 있다.

보강 지점:

- 신규 진입자가 “무엇부터 읽고 실행할지”를 보여주는 짧은 권장 순서가 없다.
- 문서 초반이 core dependency 설명으로 바로 들어가므로, 제품 타깃 구조를 이해한 뒤 빌드 단계로 넘어가게 연결하면 좋다.
- 현재 v0.1.0 Demo/Preview release 목표와 Stable blocked 상태는 build guide의 core dependency 표 이후 문맥으로만 드러난다. release channel 설명을 더 명확히 할 수 있다.

## 검색 결과와 분류

실행:

```bash
rg --line-number --glob '!RustBridge/target/**' '<실제 비교 대상 프로젝트명>|<제외 비교 표현>|Demo/Preview|Stable|release tag|resolved commit|Vendor/rhwp|git submodule|submodule|RhwpMac.xcodeproj|xcodeproj.*원본|project.yml' README.md mydocs/tech mydocs/manual Sources RustBridge
```

확인 결과:

- 실제 비교 대상 프로젝트명과 제외 비교 표현은 active README/manual/architecture에 아직 없다.
- `Demo/Preview`, `Stable`, `release tag`, `resolved commit` 표현은 README, architecture, build guide, core compatibility/core dependency guide에 존재한다.
- `Vendor/rhwp`는 active 사용자 문서에서는 대부분 제거되어 있고, `mydocs/tech/task_m010_28_sample_provenance.md`의 샘플 출처 증빙 기록에 남아 있다.
- `core_submodule_operation_guide.md` 파일명 링크는 호환 유지 목적의 이름이다.
- `RhwpMac.xcodeproj`가 원본처럼 설명되는 active 문맥은 확인되지 않았다.

주의:

- `RustBridge/target/**`에는 이전 빌드 산출물의 `.d` 파일이 있어 `Vendor/rhwp` path가 대량 검출된다. 생성물/ignored 경로이므로 Issue #31 검색 gate에서는 `--glob '!RustBridge/target/**'`를 사용해야 한다.

## Stage 2 제안 범위

Stage 2에서는 README만 수정 대상으로 삼는다.

권장 변경:

- README의 Project Structure를 제품 타깃 중심으로 재작성
- `Frameworks/`, `project.yml`, `rhwp-core.lock`, `samples/` 역할을 구조 설명에 포함
- Quick Start의 “온보딩 가이드(추후 추가 예정)” 문구를 현재 존재하는 문서 경로와 읽기 순서로 대체
- core release 문구를 “현재 Demo/Preview 목표, Stable release tag 승격 blocked”로 명확히 보정
- 외부 참고 구현에서 유지하지 않는 방향은 README에서는 짧게만 언급하고, 상세 비교는 architecture 또는 Stage 5에서 처리

## 검증 결과

```text
$ git status --short
결과: 조사 전 작업트리 clean
```

```text
$ find Sources RustBridge -maxdepth 2 -name README.md -print
결과: 출력 없음
```

```text
$ rg --line-number --glob '!RustBridge/target/**' '<실제 비교 대상 프로젝트명>|<제외 비교 표현>|Demo/Preview|Stable|release tag|resolved commit|Vendor/rhwp|git submodule|submodule|RhwpMac.xcodeproj|xcodeproj.*원본|project.yml' README.md mydocs/tech mydocs/manual Sources RustBridge
결과: 위 검색 결과와 분류 참고
```

## 잔여 위험

- README를 너무 상세한 운영 문서로 만들면 첫 진입자가 제품 구조를 빠르게 읽기 어려워진다.
- `Shared`와 `RhwpCoreBridge`를 모두 “공통 코드”로만 설명하면 AppKit/UIKit 의존 경계가 흐려질 수 있다.
- Demo/Preview commit pin을 Stable release처럼 보이게 하면 #30 결과와 충돌한다.
- `RustBridge/target` 생성물 노이즈를 검색 gate에 포함하면 문서 문제와 무관한 과거 path가 잡힌다.

## 다음 단계

Stage 2에서는 README를 제품 타깃 중심으로 재정렬한다. 코드, Xcode target, `project.yml`, build script는 수정하지 않는다.

## 승인 요청

Stage 1 조사를 완료했다. 이 보고서 기준으로 Stage 2 `README 구조 섹션과 신규 진입자용 설명 재정렬`을 진행할지 승인 요청한다.
