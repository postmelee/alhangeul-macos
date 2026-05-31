# Task M014 #305 Stage 2 보고서 - CoreGraphics PUA 표시 보정

## 목적

`CGTreeRenderer`가 CoreText 문자열을 만들기 전에 `복학원서.hwp`에서 확인된 PUA 두 codepoint만 표시 문자열로 보정한다.

## 변경 파일

| 파일 | 변경 |
|---|---|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | `TextRunDisplay` helper 추가, 일반/centered text run에서 display text 사용 |
| `mydocs/plans/task_m014_305_impl.md` | compile smoke 명령을 실행 파일 링크가 아닌 `swiftc -typecheck`로 보정 |
| `mydocs/working/task_m014_305_stage1.md` | core SVG의 `(인)` 분리 text node 확인 내용 보강 |
| `mydocs/working/task_m014_305_stage2.md` | Stage 2 구현/검증 결과 기록 |

## 구현 내용

`CGTreeRenderer.renderTextRun` 진입 시 `makeTextRunDisplay(_:)`로 display text와 layout용 `charPositions`를 계산한다.

보정 규칙:

| source codepoint | display text | 판단 |
|---|---|---|
| `U+F012B` | `(인)` | 복학원서 서명/날인 표시 |
| `U+F081C` | 빈 문자열 | HWP TAC filler, 사용자-facing glyph로 그리지 않음 |

display text가 빈 문자열이면 text run drawing 전체를 생략한다. `U+F012B -> (인)`처럼 source와 display text의 unicode scalar count가 달라지는 경우에는 `charPositions`를 nil로 처리해 원문 기준 위치 배열을 잘못 재사용하지 않게 했다.

보정 helper는 일반 text run과 rotation/vertical 경로인 centered text run 양쪽에서 공유한다.

## 렌더 확인

보정 전 Stage 1 native PNG:

```text
build.noindex/task305-stage1/복학원서-page1-native.png
```

- 서명란 `(Signature)` 앞에 fallback glyph/tofu가 보인다.
- 하단 안내문 앞에 `U+F081C` filler가 깨진 사각형 두 개로 보인다.

보정 후 Stage 2 native PNG:

```text
build.noindex/task305-stage2/복학원서-page1-native.png
```

- 서명란 `(Signature)` 앞이 `(인)`으로 표시된다.
- 하단 안내문 앞 filler 사각형 두 개가 노출되지 않는다.

## 검증

AppKit/UIKit 의존 확인:

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

Swift source typecheck:

```bash
swiftc -parse-as-library -typecheck \
  -module-cache-path build.noindex/task305-typecheck-cache \
  -Xcc -fmodules-cache-path=build.noindex/task305-clang-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/PageOverlayImages.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/FontResourceRegistry.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

결과: 통과.

렌더 helper:

```bash
./scripts/render-debug-compare.sh build.noindex/task305-stage2 samples/복학원서.hwp
```

결과:

```text
OK 복학원서.hwp: page=1 renderTreeJSON=... coreSVG=... nativePNG=... summary=...
```

`LAYOUT_OVERFLOW` 2건은 Stage 1 baseline과 동일한 기존 layout warning이다.

diff check:

```bash
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/plans/task_m014_305_impl.md mydocs/working/task_m014_305_stage1.md mydocs/working/task_m014_305_stage2.md
```

결과: 통과.

## 후속

Stage 3에서 QLExtension/ThumbnailExtension Debug build와 대표 샘플 smoke를 수행한다. Quick Look/Thumbnail 기본 policy가 `.coreGraphicsOnly`로 유지되는지도 함께 확인한다.

