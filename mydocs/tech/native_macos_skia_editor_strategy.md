# Native macOS Skia editor 전략

작성일: 2026-05-18

## 목적

이 문서는 `native-viewer-editor` 장기 라인의 제품/기술 방향을 재정의한다. 기존 “Swift native viewer/editor” 표현은 Swift가 HWP/HWPX renderer와 editor engine을 직접 재구현하는 것처럼 읽힐 수 있으므로, 앞으로의 기준은 다음 구조로 둔다.

```text
Swift native macOS app shell
+ Rust/rhwp Skia renderer
+ Swift editing UI overlays
+ WKWebView fallback
```

핵심 판단은 Swift가 문서 의미, 조판, 저장 구조를 직접 소유하지 않는 것이다. Swift/macOS 계층은 Mac 앱 경험과 입력/오버레이를 맡고, 문서 모델과 렌더링의 진실 원천은 `rhwp` core와 그 bridge contract에 둔다.

## 범위

이 문서는 다음을 정의한다.

- `devel`과 `native-viewer-editor`의 장기 역할 경계
- `rhwp` core, RustBridge, Swift/macOS shell, Swift overlay, WKWebView fallback의 책임
- Skia renderer가 viewer/editor 전환에서 갖는 위치
- CoreGraphics/CoreText renderer를 현행 fallback/diagnostic 경로로 유지하는 기준
- editor 기능을 열기 전에 필요한 core/bridge gate

이 문서는 구현 계획서가 아니다. 실제 ABI, renderer, editor UI, 저장 기능은 별도 GitHub Issue와 하이퍼-워터폴 단계로 진행한다.

## 비범위

- HostApp Skia renderer 구현
- Quick Look/Thumbnail Skia backend 구현
- RustBridge ABI 추가 또는 `Rhwp.xcframework` 재빌드
- editor hit-test, selection, IME, dirty region, undo/redo, save/round-trip 구현
- `native-viewer-editor` 브랜치 삭제, rename, 원격 branch 조작
- upstream `rhwp` source 수정
- release, packaging, signing, notarization 정책 변경

## 브랜치 역할

`native-viewer-editor`는 유지한다. 다만 의미는 “Swift renderer 재구현 브랜치”가 아니라 native macOS shell/editor integration 브랜치로 바꾼다.

| 브랜치 | 역할 |
|------|------|
| `devel` | 일반 제품 개발과 release 후보 통합. WKWebView viewer/editor, Finder Quick Look/Thumbnail, PDF/공유/저장, Mac 통합, 변환, 배포, 문서, RustBridge Skia ABI, Shared renderer backend, bundled `rhwp-studio`/core provenance를 받는다. |
| `native-viewer-editor` | HostApp native macOS viewer/editor shell, Skia 기반 page/tile viewport, native zoom/cache/sidebar/search/copy, Swift caret/selection/IME/ruler/object overlay, native editor command routing 실험을 받는다. |
| `main` | release/tag 기준 브랜치다. 일반 작업 PR 대상이 아니다. |

Skia 공통 기반은 `devel`에 둔다. HostApp native viewer/editor shell에서 그 기반을 사용하는 실험과 사용자 상호작용 계층은 `native-viewer-editor`에서 검증한다.

## 소유 경계

### `rhwp` core

`rhwp` core는 문서 의미와 layout/render의 진실 원천이다.

- HWP/HWPX parsing
- document model과 structural mutation
- page layout
- Skia 기반 page/layer rendering
- hit-test와 selection anchor 계산 후보
- dirty page/dirty rect 계산 후보
- save/export와 round-trip 안정성

core API 변경은 먼저 upstream `edwardkim/rhwp`에서 설계하고, 앱 저장소는 release tag 또는 resolved commit, RustBridge adapter, Swift wrapper만 소유한다.

### RustBridge

RustBridge는 macOS 앱이 core를 호출하는 C ABI gate다.

- Swift가 직접 Rust type이나 `DocumentCore` 내부 구조를 알지 않게 한다.
- ABI symbol 추가/삭제/변경은 `rhwp-ffi-symbols.txt`, generated header, `rhwp-core.lock`, Swift wrapper 검토를 동반한다.
- Skia renderer를 앱에 노출할 때는 Rust-owned byte/string 수명과 `rhwp_free_*` 규칙을 유지한다.
- editor 관련 API는 실험용이라도 null handle, page/range out of bounds, invalid document state를 안전하게 실패시켜야 한다.

### Swift/macOS shell

Swift/macOS shell은 문서 엔진이 아니라 앱 경험 계층이다.

- document window, toolbar, sidebar, inspector, menu command
- sandbox와 security-scoped bookmark
- open/save/share/print/PDF/export flow
- zoom, scroll, page navigation, cache orchestration
- accessibility와 macOS interaction
- fallback 선택과 오류 표시
- WKWebView viewer/editor와 native shell 사이 전환 UI

Swift shell은 core가 제공하지 않는 HWP layout 의미를 추측해서 저장 가능한 상태로 만들지 않는다.

### Swift editing UI overlays

Swift overlay는 사용자 입력을 core command로 번역하고, core가 계산한 위치 정보를 표시한다.

- caret, selection, composition underline
- IME preedit 표시와 commit timing
- ruler, margin, table/object handles
- context menu와 command routing
- dirty state 표시
- undo/redo UI integration

overlay는 시각적 표시와 입력 routing을 맡되, 문단 구조, table model, text shaping, line breaking, 저장 가능한 mutation의 진실 원천이 되지 않는다.

### WKWebView fallback

WKWebView `rhwp-studio` 경로는 native shell이 충분히 안정화될 때까지 유지한다.

- v0.1.x 사용자-facing viewer/editor 기본 경로
- 저장/공유/인쇄/export fallback
- native shell regression 비교 기준
- unsupported document와 editor 기능의 escape hatch

native shell이 도입되어도 WKWebView fallback 제거는 별도 release readiness gate가 필요하다.

## 렌더링 경로 기준

현재 제품 경로는 다음처럼 나뉜다.

| 표면 | 현재 기준 | 장기 방향 |
|------|-----------|-----------|
| HostApp viewer/editor | `rhwp-studio` Web/WASM in WKWebView | native macOS shell에서 `rhwp` Skia renderer를 사용하고 WKWebView fallback 유지 |
| Quick Look preview | Swift `PageRenderTree` + CoreGraphics/CoreText bitmap/PDF | #255-#259 gate 후 Skia optional/first 여부 판단, CoreGraphics fallback 유지 |
| Finder thumbnail | Swift `PageRenderTree` + CoreGraphics/CoreText bitmap/cache | #255-#259 gate 후 Skia optional/first 여부 판단, CoreGraphics fallback 유지 |
| PDF export | 현재 render tree 기반 bitmap PDF | vector/export 품질 개선은 별도 범위, HostApp Skia viewer 전환과 자동 결합하지 않음 |
| Debug compare | core SVG, render tree JSON, native PNG, diff | CoreGraphics fallback과 Skia 결과를 함께 비교할 수 있게 확장 후보 |

CoreGraphics/CoreText renderer는 즉시 제거하지 않는다. 현재 Quick Look/Thumbnail/PDF export의 동작 기준이고, Skia 도입 후에도 fallback, diagnostic, visual comparison 기준으로 남긴다.

## Editor gate

native editor 기능은 renderer만으로 열지 않는다. 최소한 다음 gate가 필요하다.

| Gate | 필요 조건 |
|------|-----------|
| render gate | Skia renderer가 page/tile 단위로 안정적으로 표시되고 fallback이 동작한다. |
| hit-test gate | point to document position, object/table hit-test, selection anchor가 core API로 제공된다. |
| selection gate | selection range, rects, caret rect, IME composition rect를 core 기준으로 얻을 수 있다. |
| mutation gate | insert/delete/format/table/object command가 transaction 단위로 성공/실패를 보고한다. |
| dirty gate | mutation 후 affected page/rect, document dirty state, undo grouping 정보를 얻을 수 있다. |
| save gate | HWP/HWPX 저장 또는 export가 round-trip test와 compatibility warning 정책을 통과한다. |
| fallback gate | unsupported edit command나 render failure가 WKWebView fallback 또는 read-only mode로 안전하게 떨어진다. |

이 gate가 없으면 Swift overlay는 read-only viewer interaction 또는 제한된 UI 실험으로만 둔다.

## Rollout 원칙

1. Quick Look/Thumbnail Skia backend는 #255-#259 gate를 따른다.
2. HostApp native shell은 `native-viewer-editor`에서 별도 viewer shell gate로 검증한다.
3. editor overlay는 read-only selection/caret visualization부터 시작하고, 저장 가능한 mutation은 가장 늦게 연다.
4. Swift가 HWP 구조를 임의로 수정해서 저장하는 경로는 만들지 않는다.
5. WKWebView fallback은 native shell의 품질이 충분해질 때까지 제품에서 유지한다.
6. release 기본 경로 전환은 visual, performance, package size, memory, fallback, accessibility 결과를 모아 별도 승인으로 결정한다.

## 후속 이슈 후보

- HostApp native Skia viewer shell architecture 설계
- Skia page/tile viewport와 cache contract 설계
- Native shell과 WKWebView fallback 전환 UX 설계
- Core hit-test/selection C ABI 후보 조사
- Swift caret/selection/IME overlay prototype
- Native editor command routing과 undo/redo 정책 설계
- HWP/HWPX save/round-trip gate 정의

각 이슈는 구현 범위를 좁게 잡고, core 변경이 필요한 경우 upstream `rhwp` 작업과 앱 저장소 bridge 작업을 분리한다.

## 문서 반영 기준

다른 문서에서는 이 문서를 기준으로 다음 표현을 사용한다.

- “Swift native viewer/editor” 단독 표현보다 “native macOS viewer/editor shell”을 우선한다.
- renderer 장기 방향은 “Rust/rhwp Skia renderer”로 표현한다.
- Swift 책임은 “Mac shell, interaction, overlay, command routing”으로 제한한다.
- CoreGraphics/CoreText renderer는 현행 render tree backend, fallback, diagnostic 경로로 설명한다.
- `native-viewer-editor`는 삭제 대상이 아니라 장기 native shell/editor integration 브랜치로 설명한다.
