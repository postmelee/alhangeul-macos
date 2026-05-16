# Task M050 #247 Stage 3 보고서

## 목적

Stage 2에서 native 쪽으로 보존해 둔 `Sources/RhwpCoreBridge` 충돌 파일을 `origin/devel`의 최신 제품 라인 변경과 수동 통합한다.

이번 단계의 목표는 native renderer 구현을 새로 바꾸는 것이 아니라, `native-viewer-editor`가 최신 제품 라인의 Quick Look/Thumbnail 안정성 보강과 font resource 목록을 따라가게 하는 것이다.

## 변경 요약

| 파일 | 변경 |
|------|------|
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | bundled font allowlist에 `SourceHanSerifK-OldHangul-subset.woff2` 추가 |
| `Sources/RhwpCoreBridge/FontFallback.swift` | #140의 Quick Look/Thumbnail layout 안정성 우선 fallback 순서 반영 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | page/open-arrow 흰색 fill을 `CGColor(gray:)` 생성 대신 `setFillColor(red:green:blue:alpha:)` 호출로 정리 |

작업 후 위 세 파일은 작업 트리 기준으로 `origin/devel`과 동일하다.

## 판단 기록

### Font resource registry

`origin/devel`은 #167 이후 `rhwp-studio` font bundle에 `SourceHanSerifK-OldHangul-subset.woff2`를 포함한다. Stage 2에서 font asset과 `FONTS.md`, `font_fallback_strategy.md`는 이미 `origin/devel` 버전을 채택했으므로, registry allowlist도 같은 목록을 따라가야 한다.

따라서 `HwpBundledFontRegistry.bundledFontFileNames`에 Source Han Serif K old Hangul subset을 추가했다.

### Font fallback order

`origin/devel`의 #140은 릴리즈 전 Quick Look/Thumbnail 회귀 보정으로 주요 한글 serif/sans 계열에서 시스템 기본 font를 먼저 선택하도록 바꿨다. #140 보고서의 판단은 다음과 같다.

- Quick Look/Thumbnail은 정확한 font family보다 문서 구조와 레이아웃 안정성을 우선한다.
- bundled Korean font 우선 순서가 문서 metric을 흔들 수 있으므로 기본 시스템 font를 먼저 둔다.

`native-viewer-editor`에는 #119의 bundled open-license font 우선 정책이 남아 있었지만, 이번 #247은 최신 제품 라인에 가깝게 forward-port하는 작업이다. 따라서 #140의 안정성 보정 순서를 반영했다.

### CGTreeRenderer fill color

`origin/devel`의 변경은 의미 변경이 아니라 Core Graphics API 호출 형태 정리다. 흰색 fill 색상은 동일하게 유지된다.

## 검증

| 명령 | 결과 |
|------|------|
| `git diff origin/devel -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/FontFallback.swift Sources/RhwpCoreBridge/FontResourceRegistry.swift` | 빈 출력. 세 파일이 `origin/devel`과 동일 |
| `git diff --check` | 통과 |
| `./scripts/check-no-appkit.sh` | 통과. `OK: shared Swift code has no AppKit/UIKit dependencies` |

## 다음 단계

Stage 4에서는 XcodeGen project를 재생성하고, scripts syntax, helper interface, RustBridge/Core 영향 범위, HostApp Debug build를 검증한다.
