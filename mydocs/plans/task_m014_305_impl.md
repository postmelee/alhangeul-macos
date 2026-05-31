# Task M014 #305 구현계획서

## 작업 기준

- 이슈: #305 CoreGraphics preview에서 복학원서.hwp PUA 표시 최소 보정
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 작업 브랜치: `local/task305`
- 기준 브랜치: `devel`
- 수행계획서: `mydocs/plans/task_m014_305.md`

## 구현 목표

Quick Look preview와 Finder thumbnail이 공유하는 CoreGraphics renderer에서 `samples/복학원서.hwp`의 확인된 PUA 문자가 깨진 glyph로 표시되지 않게 한다. 이번 작업은 release-blocking 최소 보정이므로 `CGTreeRenderer`의 텍스트 렌더링 직전 표시 문자열만 제한적으로 보정하고, Quick Look/Thumbnail backend 정책은 변경하지 않는다.

최종 산출물은 다음 조건을 만족해야 한다.

- `U+F012B`는 CoreGraphics output에서 `(인)`으로 표시된다.
- `U+F081C`는 CoreGraphics output에서 그려지지 않는다.
- 보정 문자열과 원문 문자열의 scalar count가 다르면 `charPositions`를 사용하지 않는다.
- `HwpPreviewProvider`와 `HwpThumbnailRenderCache`의 기본 `.coreGraphicsOnly` 경로는 유지된다.
- `Sources/RhwpCoreBridge`에 AppKit 의존을 추가하지 않는다.

## Stage 1. 현행 PUA 재현과 렌더링 입력 inventory

### 목적

`samples/복학원서.hwp`의 render tree와 현재 CoreGraphics/native output을 기준으로 보정 대상 codepoint, bbox, style, layout 입력을 확정한다.

### 작업

- `render-debug-compare.sh`로 render tree JSON, core SVG, native PNG, summary를 생성한다.
- render tree에서 Private Use 영역 codepoint를 포함한 `TextRun`을 추출한다.
- core SVG가 같은 위치에서 어떤 표시 문자열을 내보내는지 확인한다.
- `CGTreeRenderer`의 현재 text run 소비 지점을 확인한다.
- Stage 2 구현 위치와 charPositions 처리 원칙을 확정한다.

### 산출물

- `build.noindex/task305-stage1/`
- `mydocs/working/task_m014_305_stage1.md`

### 검증

```bash
./scripts/render-debug-compare.sh build.noindex/task305-stage1 samples/복학원서.hwp
jq -r '...' build.noindex/task305-stage1/*render-tree.json
rg -n "NSAttributedString\\(string: run.text|makeTextRunLayoutPlan|charPositions" \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift
git diff --check -- mydocs/plans/task_m014_305_impl.md mydocs/working/task_m014_305_stage1.md
```

### 커밋

```text
Task #305 Stage 1: 복학원서 PUA 입력 경로 확인
```

## Stage 2. CoreGraphics 최소 PUA 보정 구현

### 목적

`CGTreeRenderer`에서 CoreText 문자열을 생성하기 전에 확인된 PUA만 표시 문자열로 변환한다.

### 작업

- `CGTreeRenderer`에 private helper를 추가해 `TextRunNode`의 display text와 layout용 `charPositions`를 계산한다.
- `U+F012B`는 `(인)`으로 대체한다.
- `U+F081C`는 빈 문자열로 제거한다.
- display text가 빈 문자열이면 text run drawing을 생략한다.
- 원문과 display text의 unicode scalar count가 다르면 `charPositions`를 nil로 둔다.
- 일반/centered text run 양쪽에서 같은 helper를 사용한다.
- shadow, emphasis dot, underline/strikethrough가 display text 기준으로 동작하는지 확인한다.

### 산출물

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/working/task_m014_305_stage2.md`

### 검증

```bash
./scripts/check-no-appkit.sh
swiftc -parse-as-library \
  -typecheck \
  -module-cache-path build.noindex/task305-compile-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/PageOverlayImages.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/FontResourceRegistry.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift
git diff --check
```

### 커밋

```text
Task #305 Stage 2: CoreGraphics PUA 표시 보정
```

## Stage 3. Renderer smoke와 regression 확인

### 목적

보정 후 `samples/복학원서.hwp`의 native/CoreGraphics output에서 PUA 깨짐이 사라졌는지 확인하고, 대표 샘플에서 renderer가 실패하지 않는지 확인한다.

### 작업

- `render-debug-compare.sh`를 보정 후 다시 실행한다.
- 보정 후 native PNG 또는 OCR/시각 확인으로 서명란 위치의 tofu 제거를 확인한다.
- core SVG의 기존 `인` 출력과 native output의 표시가 같은 의도임을 기록한다.
- `request.hwp`, `KTX.hwp`, `hwpx-01.hwpx` 중 가능한 대표 샘플을 추가 smoke한다.
- Quick Look/Thumbnail 기본 정책이 `.coreGraphicsOnly`로 유지되는지 source 검색으로 확인한다.
- QLExtension과 ThumbnailExtension Debug build를 수행한다.

### 산출물

- `build.noindex/task305-stage3/`
- `mydocs/working/task_m014_305_stage3.md`

### 검증

```bash
./scripts/render-debug-compare.sh build.noindex/task305-stage3 samples/복학원서.hwp
rg -n "policy: \\.coreGraphicsOnly|skiaOptIn|renderFirstPage" Sources/QLExtension Sources/ThumbnailExtension Sources/Shared
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask305 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask305 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

### 커밋

```text
Task #305 Stage 3: PUA 보정 smoke 검증
```

## Stage 4. 최종 보고와 release handoff

### 목적

최소 보정 범위와 검증 결과를 정리하고, #301 release 작업이 이어받아야 할 조건을 남긴다.

### 작업

- 최종 보고서 작성
- 오늘할일 상태 완료 처리
- 장기 PageLayerTree/Skia 전환은 #258/#259 흐름으로 유지한다는 결론 재기록
- #301 release handoff: #305 merge 후 v0.1.4 draft release artifact를 다시 생성해야 하는지 판단 근거 작성

### 산출물

- `mydocs/report/task_m014_305_report.md`
- `mydocs/orders/20260531.md`

### 검증

```bash
git diff --check
git status --short --branch
git log --oneline -5
```

### 커밋

```text
Task #305 Stage 4 + 최종 보고서: PUA 보정 결과 정리
```
