# Task M013 #263 Stage 2 보고서

## 단계 목적

Stage 2의 목적은 Stage 1 inventory 결과를 바탕으로 `native-viewer-editor`의 새 장기 방향을 한 문서에 고정하는 것이다. 이번 단계에서는 전략 문서만 추가하고, README/로드맵/브랜치 안내 문서의 본문 갱신은 Stage 3 이후로 남겼다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/tech/native_macos_skia_editor_strategy.md` | native macOS shell, rhwp Skia renderer, Swift overlay, WKWebView fallback 책임 경계와 branch 역할 정의 |
| `mydocs/working/task_m013_263_stage2.md` | Stage 2 보고서 |
| `mydocs/orders/20260518.md` | #263 상태를 Stage 2 완료, Stage 3 승인 대기로 갱신 |

## 전략 문서 핵심 결정

### 브랜치 유지

`native-viewer-editor`는 삭제하지 않는다. 다만 의미를 “Swift renderer 재구현 브랜치”가 아니라 다음 장기 라인으로 재정의한다.

```text
Swift native macOS app shell
+ Rust/rhwp Skia renderer
+ Swift editing UI overlays
+ WKWebView fallback
```

### 브랜치 역할

| 브랜치 | Stage 2 기준 역할 |
|------|-------------------|
| `devel` | 제품 공통 기반과 release 후보 통합. Skia FFI, Shared renderer backend, Quick Look/Thumbnail, WKWebView viewer/editor, bundled studio/core provenance, 배포/문서 작업을 받는다. |
| `native-viewer-editor` | HostApp native macOS viewer/editor shell, Skia page/tile viewport, native zoom/cache/sidebar/search/copy, Swift caret/selection/IME/ruler/object overlay, native editor command routing 실험을 받는다. |
| `main` | release/tag 기준 브랜치다. 일반 작업 PR 대상이 아니다. |

### 소유 경계

| 계층 | 소유 |
|------|------|
| `rhwp` core | 문서 model, parsing, layout, Skia rendering, edit transaction, hit-test/selection anchor, dirty page/rect, save/export 안정성 |
| RustBridge | C ABI gate, Swift wrapper contract, symbol/header/lock/provenance 정합성 |
| Swift/macOS shell | window, toolbar, sidebar, inspector, menu, sandbox, open/save/share/print/PDF/export flow, fallback 선택 |
| Swift overlay | caret, selection, IME composition, ruler, margin, table/object handles, command routing UI |
| WKWebView fallback | v0.1.x 기본 viewer/editor, 저장/공유/인쇄/export fallback, native shell 비교 기준 |

### 렌더링 기준

CoreGraphics/CoreText renderer는 즉시 제거하지 않는다. 현재 Quick Look/Thumbnail/PDF export의 기준 경로이며, Skia 도입 이후에도 fallback, diagnostic, visual comparison 기준으로 남긴다.

HostApp viewer/editor 장기 방향은 Skia renderer를 native macOS shell에 붙이는 것이지만, `mydocs/tech/skia_quicklook_thumbnail_backend.md`의 Quick Look/Thumbnail optional backend 범위와 섞지 않는다.

### Editor gate

native editor 기능은 renderer만으로 열지 않는다. 전략 문서에는 다음 gate를 분리했다.

- render gate
- hit-test gate
- selection gate
- mutation gate
- dirty gate
- save gate
- fallback gate

이 gate가 준비되지 않으면 Swift overlay는 read-only viewer interaction 또는 제한된 UI 실험으로 둔다.

## 이번 단계에서 수정하지 않은 문서

Stage 2는 기준 문서 추가까지만 수행했다. 다음 문서는 Stage 3/4에서 새 전략 문서를 참조하도록 갱신한다.

| Stage | 후보 파일 |
|------|-----------|
| Stage 3 | `README.md`, `mydocs/tech/product_roadmap_notes.md`, `mydocs/tech/project_architecture.md`, `mydocs/tech/skia_quicklook_thumbnail_backend.md` |
| Stage 4 | `mydocs/tech/branch_strategy_webview_native.md`, `mydocs/manual/git_workflow_guide.md`, `mydocs/manual/pr_process_guide.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md`, `.github/copilot-instructions.md`, release/CI 문서 |

## 검증

예정 검증은 Stage 2 문서 작성 후 다음 명령으로 수행한다.

```bash
git diff --check
rg -n "native_macos_skia_editor_strategy|Swift native viewer|Swift native editor|native-viewer-editor|Skia|CoreGraphics|CoreText" \
  mydocs/tech/native_macos_skia_editor_strategy.md mydocs/working/task_m013_263_stage2.md
```

코드, RustBridge, workflow를 변경하지 않았으므로 Xcode build, render smoke, YAML 검증은 이번 단계의 필수 검증에서 제외한다.

## 리스크

- 새 전략 문서만 추가된 상태라 기존 README/로드맵/브랜치 문서는 아직 오래된 표현을 포함한다. Stage 3/4에서 반드시 연결해야 한다.
- `devel`에 들어갈 Skia 공통 기반과 `native-viewer-editor`에 들어갈 HostApp native shell 실험의 경계가 문서마다 다르면 다시 PR base 혼란이 생길 수 있다.
- editor gate를 문서화했지만 실제 core/bridge API는 아직 없다. Stage 3 이후 사용자-facing 표현은 구현 완료처럼 읽히지 않게 해야 한다.

## 다음 단계 제안

Stage 3에서는 전략 문서를 기준으로 사용자/아키텍처 문서를 먼저 갱신한다.

1. `README.md`의 장기 방향, 이정표, 렌더링 경로, 브랜치 요약을 새 표현으로 조정한다.
2. `product_roadmap_notes.md`의 제품 흐름과 v0.5/v0.6 구현 메모를 native macOS shell + rhwp/Skia renderer + Swift overlay 기준으로 정리한다.
3. `project_architecture.md`에 장기 native path와 책임 경계 링크를 추가한다.
4. `skia_quicklook_thumbnail_backend.md`에는 HostApp/editor 전환이 별도 전략 문서에 있다는 연결만 추가하고 비범위는 유지한다.

## 승인 요청

Stage 2 전략 문서 작성을 완료했다. 이 보고서 기준으로 Stage 3 README/로드맵/아키텍처 문서 갱신을 진행하려면 작업지시자 승인이 필요하다.
