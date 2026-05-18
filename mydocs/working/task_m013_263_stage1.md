# Task M013 #263 Stage 1 보고서

## 단계 목적

Stage 1의 목적은 `native-viewer-editor`를 Skia 기반 native macOS 셸 전환 라인으로 재정의하기 전에, 현재 저장소 문서와 workflow에 남아 있는 `Swift native viewer/editor`, `native renderer`, `CoreGraphics/CoreText`, `Skia`, PR base 관련 참조를 inventory하고 실제 변경 범위를 확정하는 것이다.

이번 단계에서는 코드, RustBridge ABI, workflow 실행 조건, 원격 브랜치를 변경하지 않았다.

## 현재 상태 요약

현재 문서의 장기 방향은 대체로 다음 표현을 기준으로 한다.

- 제품 `devel`: WKWebView-backed viewer/editor, Finder/Quick Look, PDF/공유/저장, Mac 통합, 배포, 문서 작업
- `native-viewer-editor`: Swift native viewer/editor와 장기 native 전환 작업
- native renderer: `PageRenderTree` JSON을 Swift `CGTreeRenderer`가 CoreGraphics/CoreText로 그리는 경로
- Skia: Quick Look/Thumbnail optional backend 설계 문서에서만 명시적으로 정리된 후보 backend

이번 #263의 방향과 맞지 않는 지점은 “Swift native viewer/editor”가 Swift renderer 자체 완성을 목표로 읽힐 수 있다는 점이다. 앞으로의 문서 기준은 `Swift native macOS 앱 셸 + Rust/rhwp Skia renderer + Swift 편집 UI/오버레이` 구조로 바꿔야 한다.

## 참조 inventory

`rg`로 다음 키워드를 확인했다.

```bash
rg -n "Swift native viewer|Swift native editor|native-viewer-editor|CoreGraphics|CoreText|Skia|skia|PR base|통합 브랜치" \
  README.md CONTRIBUTING.md .github mydocs/tech mydocs/manual
```

주요 변경 대상은 다음과 같다.

| 영역 | 파일 | 현재 문제 | Stage 2 이후 조치 |
|------|------|-----------|-------------------|
| 사용자 로드맵 | `README.md` | 장기 방향과 v0.5+가 `Swift native viewer/editor`로 표현되어 있다. | `Native macOS viewer/editor shell`, rhwp/Skia renderer, Swift overlay/fallback 경계로 갱신한다. |
| 제품 로드맵 | `mydocs/tech/product_roadmap_notes.md` | 흐름이 `Swift native viewer -> Swift native editor 기반`이고, v0.5/v0.6 설명이 CoreGraphics/CoreText renderer와 Swift editor foundation 중심이다. | 장기 기본 경로를 native macOS shell + rhwp/Skia renderer + Swift overlay로 재정의한다. |
| 브랜치 전략 | `mydocs/tech/branch_strategy_webview_native.md` | `native-viewer-editor`가 Swift native viewer/editor 장기 라인으로 설명되어 있다. | 브랜치 이름은 유지하되 Skia 기반 native macOS shell/editor integration 라인으로 역할을 갱신한다. |
| 아키텍처 | `mydocs/tech/project_architecture.md` | `RhwpCoreBridge`의 장기 전환 설명이 Swift render tree renderer 중심이다. | 현재 경로와 장기 경로를 분리하고, Skia renderer와 Swift overlay 책임 경계를 추가한다. |
| 기여자 문서 | `CONTRIBUTING.md` | `native-viewer-editor` 대상이 native viewer renderer, CoreGraphics/CoreText rendering으로 좁게 안내된다. | Skia 공통 기반은 `devel`, HostApp native shell/overlay는 `native-viewer-editor`로 분리 안내한다. |
| PR 안내 | `.github/pull_request_template.md`, `.github/copilot-instructions.md` | native 작업 PR base가 `Swift native viewer/editor`로만 설명된다. | 새 역할 표현과 base branch 기준을 반영한다. |
| 운영 매뉴얼 | `mydocs/manual/git_workflow_guide.md`, `mydocs/manual/pr_process_guide.md`, `mydocs/manual/ci_workflow_guide.md` | 통합 브랜치 설명이 기존 Swift native viewer/editor 기준이다. | branch 선택 예시를 새 정책으로 갱신한다. |
| 릴리스 문서 | `mydocs/manual/release_policy_guide.md`, `mydocs/manual/release_distribution_guide.md` | release-critical 변경을 native 라인에 cherry-pick한다는 설명은 유효하지만 native 라인 설명이 오래됐다. | `native-viewer-editor`가 release 기준 브랜치가 아니라는 설명을 유지하고 역할 표현만 갱신한다. |

## 보존하거나 조심해서 수정할 문서

다음 문서는 현재 구현 또는 진단 절차를 설명하므로 무리하게 새 방향으로 덮어쓰면 안 된다.

| 파일 | 판단 |
|------|------|
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | Quick Look/Thumbnail optional backend 범위를 정확히 제한하고 있다. HostApp viewer/editor 전환은 비범위로 남겨야 하며, #263에서는 관련성만 연결한다. |
| `mydocs/tech/font_fallback_strategy.md` | 현재 Swift CoreText fallback 정책 설명이다. Skia 장기 방향과 별개로 현행 Quick Look/Thumbnail fallback 설명이므로 본문 유지가 필요하다. |
| `mydocs/manual/render_core_native_compare_guide.md` | Swift `CGTreeRenderer` 디버깅 절차다. 장기 전략 문서가 아니므로 현재 경로 설명을 보존한다. 필요하면 “CoreGraphics fallback/diagnostic 경로”라는 맥락만 보강한다. |
| `mydocs/manual/swift_macos_code_rules_guide.md` | `Sources/RhwpCoreBridge`의 AppKit/UIKit 금지와 CoreGraphics renderer 규칙을 다룬다. 현재 코드 규칙이므로 유지한다. |
| `mydocs/manual/build_run_guide.md` | native renderer smoke와 debug compare 절차를 설명한다. 현행 검증 절차로 보존한다. |

## workflow 확인

`.github/workflows/pr-ci.yml`은 이미 다음 PR target을 갖고 있다.

```yaml
branches:
  - main
  - devel
  - native-viewer-editor
```

`native-viewer-editor`를 유지하는 정책이면 Stage 2 이후 workflow branch filter를 바꿀 필요는 없다. `rhwp-upstream-sync-pr.yml`의 `BASE_BRANCH=devel`도 Skia 공통 기반과 bundled `rhwp-studio` sync가 제품 라인으로 들어가는 현재 정책과 맞다.

따라서 이번 #263에서 workflow 파일은 원칙적으로 수정하지 않는 것이 좋다. 단, PR template이나 Copilot instructions처럼 workflow 주변 문서성 파일은 변경 대상이다.

## 변경 범위 판단

Stage 2 이후 문서 변경은 두 묶음으로 나누는 것이 적절하다.

1. 전략/아키텍처 묶음
   - 새 전략 문서 또는 기존 문서 섹션으로 native macOS shell / rhwp Skia renderer / Swift overlay / WKWebView fallback 책임 경계를 먼저 고정한다.
   - README, product roadmap, project architecture, Skia backend 문서는 이 기준을 참조하게 한다.

2. 브랜치/기여 안내 묶음
   - `native-viewer-editor`는 삭제하지 않는다.
   - `devel`은 Skia FFI, Shared renderer backend, Quick Look/Thumbnail, bundled studio/core sync, 제품/배포/문서 작업을 받는다.
   - `native-viewer-editor`는 HostApp native viewer/editor shell, Skia page/tile viewport, Swift caret/selection/IME/ruler/object overlay, native editor command routing 실험을 받는다.
   - `main`은 release/tag 기준이고 `devel-webview`는 계속 퇴역 상태로 둔다.

## 제외 범위 재확인

이번 작업에서는 다음을 하지 않는다.

- RustBridge ABI 추가/변경
- Skia HostApp renderer 구현
- Quick Look/Thumbnail Skia backend 구현
- editor hit-test, selection, IME, dirty region, save/round-trip 구현
- `.github/workflows` branch trigger 변경
- `native-viewer-editor` 원격 브랜치 삭제 또는 rename
- release/package/signing 정책 변경

## Stage 1 판단

- `native-viewer-editor`는 제거하지 않고 역할을 재정의하는 방향이 현재 문서와 workflow에 가장 적합하다.
- workflow branch filter는 현재 정책과 충돌하지 않는다.
- 핵심 수정 대상은 README, 제품 로드맵, 브랜치 전략, 아키텍처, 기여자/PR 안내 문서다.
- 현재 CoreGraphics/CoreText renderer 관련 문서는 현행 fallback/diagnostic/Quick Look path 설명으로 보존해야 한다.
- Stage 2에서는 새 전략 문서를 추가하는 편이 좋다. 기존 문서 여러 곳에 같은 내용을 흩뿌리기보다 `mydocs/tech/native_macos_skia_editor_strategy.md` 같은 기준 문서를 만들고 다른 문서가 요약/링크하는 구조가 더 안전하다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `git status --short --branch` | `local/task263`에서 시작, 기존 미커밋 변경 없음 |
| 문서/workflow `rg` inventory | 완료 |
| `.github/workflows` branch filter 확인 | `main`, `devel`, `native-viewer-editor` 유지 확인 |
| `git diff --stat HEAD` | Stage 1 보고서 작성 전 변경 없음 |

## 다음 단계 제안

Stage 2에서는 다음 산출물을 작성한다.

- `mydocs/tech/native_macos_skia_editor_strategy.md` 신규 전략 문서
- 전략 문서에 포함할 최소 기준:
  - `devel`과 `native-viewer-editor`의 새 책임 경계
  - `rhwp` core, RustBridge, Swift/macOS shell, Swift overlay, WKWebView fallback의 소유권
  - CoreGraphics/CoreText renderer의 현행/장기 위치
  - editor 관련 ABI가 구현 범위가 아니라 후속 gate임을 명시

## 승인 요청

Stage 1 inventory를 완료했다. 이 보고서 기준으로 Stage 2 전략 문서 작성과 책임 경계 정리로 진행하려면 작업지시자 승인이 필요하다.
