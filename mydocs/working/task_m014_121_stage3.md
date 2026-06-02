# Task M014 #121 Stage 3 완료보고서

## 개요

Stage 3에서는 Swift native renderer가 upstream render tree의 `RawSvg`와 `Placeholder` node를 `.unknown`으로 흡수하지 않도록 모델을 확장하고, CoreGraphics 경계 안에서 렌더링 가능한 최소 정책을 구현했다.

Stage 2에서는 upstream `Placeholder` 구현을 #121 범위 밖으로 두는 정책을 세웠지만, 작업 중 제공받은 `/Users/melee/Downloads/143E433F503322BD33.hwp`가 실제 OLE Placeholder 양성 fixture로 확인되어 범위를 조정했다. 이 fixture는 RawSvg는 아니지만 #121의 OLE 리소스 fallback 품질을 직접 검증할 수 있으므로, 사용자 승인 후 `Placeholder` 렌더링까지 포함했다.

## 기준

| 항목 | 값 |
|------|----|
| 이슈 | #121 Swift native renderer RawSvg/OLE·차트 리소스 렌더링 보강 |
| 브랜치 | `local/task121` |
| 기준 브랜치 | `origin/devel` `1b767bd` |
| core/studio 기준 | `edwardkim/rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| Stage 1 보고서 | `mydocs/working/task_m014_121_stage1.md` |
| Stage 2 보고서 | `mydocs/working/task_m014_121_stage2.md` |
| 구현계획서 | `mydocs/plans/task_m014_121_impl.md` |

## 구현 내용

### RenderTree 모델

`Sources/RhwpCoreBridge/RenderTree.swift`에 다음 node type을 추가했다.

| NodeType | Swift 모델 | JSON shape |
|----------|------------|------------|
| `RawSvg` | `RawSvgNode { svg: String }` | `{"RawSvg":{"svg":"..."}}` |
| `Placeholder` | `PlaceholderNode { fillColor, strokeColor, label }` | `{"Placeholder":{"fill_color":...,"stroke_color":...,"label":"..."}}` |

decode 순서는 기존 known variant 이후 `.unknown` 전에 배치했다. 따라서 upstream JSON에 해당 variant가 들어오면 native renderer가 명시적으로 처리할 수 있다.

### RawSvg 렌더링

`Sources/RhwpCoreBridge/CGTreeRenderer.swift`에 `.rawSvg` case와 전용 renderer를 추가했다.

지원 범위:

| payload | 처리 |
|---------|------|
| 단일 self-closing `<image ... xlink:href="data:image/...;base64,..."/>` | base64 data URL을 디코드하고 기존 `decodeImage`/`drawImage` 경로로 bbox에 draw |
| 단일 self-closing `<image ... href="data:image/...;base64,..."/>` | `xlink:href`가 없을 때만 `href` 사용 |
| PNG/JPEG/GIF/PCX 등 기존 image decoder가 처리 가능한 data image | 기존 decoder에 위임 |

fallback 범위:

| payload | 처리 |
|---------|------|
| OOXML chart 복합 SVG fragment | `SVG` label이 있는 회색 점선 placeholder |
| EMF preview 복합 SVG fragment | `SVG` label이 있는 회색 점선 placeholder |
| full `<svg>...</svg>` 문서 | fallback |
| 외부 `file:`, `http:`, `https:` href | fallback |
| 비-base64 data URL, malformed XML, 복수 element | fallback |
| 비정상 bbox 또는 guard 초과 | fallback 또는 draw 생략 |

guard:

| 항목 | 정책 |
|------|------|
| RawSvg string size | 4 MiB 초과 시 fallback |
| bbox | finite, width/height > 0 |
| raster pixel estimate | 67,108,864 초과 시 fallback |
| XML parser | `XMLParser`, external entity resolve 비활성화 |
| data URL | `data:image/*;base64,...`만 허용, nested `image/svg+xml` 제외 |

복합 SVG를 직접 파싱하거나 WebKit/AppKit 래스터라이저를 붙이지 않았다. `RhwpCoreBridge`의 AppKit/UIKit 금지 경계를 유지하기 위해서다.

### Placeholder 렌더링

`Placeholder`는 upstream core SVG와 같은 의미의 OLE fallback 박스로 렌더링한다.

| 요소 | 처리 |
|------|------|
| fill | `fill_color` |
| stroke | `stroke_color`, dashed `[6, 3]` |
| label | `label`을 중앙 배치 |
| clip | 기존 parent clip과 bbox clip을 모두 존중 |
| 부분 clipping | 실제 visible clip bounds 안에 label을 재배치 |

제공 fixture처럼 OLE bbox가 body clip 밖으로 내려가는 경우 전체 bbox 중앙의 label이 잘릴 수 있었다. 그래서 label은 현재 clip path와 bbox의 교집합 안에서 배치하도록 보정했다.

## Fixture 확인

### Repository samples

현재 repository samples는 RawSvg/Placeholder 양성 fixture가 아니다.

명령:

```bash
find samples -type f \( -name '*.hwp' -o -name '*.hwpx' \) -exec build.noindex/task121-rawsvg-scan/rawsvg_scan {} +
```

결과:

| 항목 | 값 |
|------|---:|
| DocumentsOpened | `174` |
| PagesScanned | `1390` |
| Failures | `0` |
| DirectHits | `164` |
| ImageOrEquationPages | `338` |
| RawSvg positive page | `0` |
| Placeholder positive page | `0` |

`DirectHits`는 문서 본문에 `OLE`/`chart` 문자열이 있는 페이지다. 해당 hit 전체에서 `RawSvg=0`, `rawSvg=0`, `Placeholder=0`이었다.

### 제공받은 fixture

파일:

```text
/Users/melee/Downloads/143E433F503322BD33.hwp
```

분석 결과:

| NodeType | Count |
|----------|------:|
| `RawSvg` | `0` |
| `Placeholder` | `1` |
| `Image` | `1` |

Placeholder node:

| 항목 | 값 |
|------|----|
| id | `265` |
| bbox | `x=77.48`, `y=904.1866666666666`, `width=302.36`, `height=302.36` |
| fill_color | `4293980400` (`0xFFF0F0F0`) |
| stroke_color | `4285558896` (`0xFF707070`) |
| label | `OLE 개체 (BinData #2)` |

이 파일은 RawSvg fixture는 아니지만, OLE object가 image decode에 실패하거나 정적 preview 없이 내려올 때 upstream이 표시하는 Placeholder fixture로 유효하다.

## 검증 결과

### Synthetic RawSvg smoke

실제 RawSvg HWP/HWPX fixture가 없으므로 synthetic RenderTree JSON으로 decode/render smoke를 수행했다.

검증 대상:

| case | 기대 |
|------|------|
| `{"RawSvg":{"svg":"<image ... data:image/png;base64,.../>"}}` | 빨간 PNG data image draw |
| `{"RawSvg":{"svg":"<g class=\"hwp-ooxml-chart\">...</g>"}}` | `SVG` fallback placeholder |
| `{"Placeholder":...}` | OLE placeholder draw |

결과:

| 항목 | 값 |
|------|---:|
| SyntheticNonWhitePixels | `6200` |
| SyntheticRedPixels | `1600` |
| SyntheticGrayPixels | `4600` |
| 산출물 | `build.noindex/task121-rawsvg-synthetic/rawsvg-synthetic.png` |

### Render debug

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task121-stage3-download-v2 --page 1 /Users/melee/Downloads/143E433F503322BD33.hwp
./scripts/render-debug-compare.sh build.noindex/task121-stage3-target-v2 --page 1 samples/draw-group.hwp samples/eq-01.hwp
```

결과:

| 파일 | RenderTreeJSONBytes | CoreSVGBytes | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|--------------------:|-------------:|---------------|---------------------:|---------:|-----------:|--------------------:|
| `143E433F503322BD33.hwp` | `307461` | `628489` | `794x1123` | `136906` | `186` | `98` | `0` |
| `draw-group.hwp` | `13998` | `19539` | `794x1123` | `7324` | `2` | `1` | `0` |
| `eq-01.hwp` | `233539` | `262660` | `794x1123` | `45708` | `71` | `37` | `0` |

`143E433F503322BD33.hwp`의 Stage 3 이전 native non-white 기준은 `105571`이었고, Placeholder 렌더링 후 `136906`으로 증가했다. 생성 PNG에서도 좌하단 OLE placeholder 박스와 `OLE 개체 (BinData #2)` label을 확인했다.

세 render-debug 결과 모두 optional core SVG raster diff는 생성되지 않았다.

```text
DiffReason: qlmanage rasterize failed
```

이는 Stage 1과 동일한 local `qlmanage` rasterize 실패이며 native PNG 생성 자체는 성공했다.

### Build / policy checks

| 명령 | 결과 |
|------|------|
| `git diff --check` | 통과 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData-task121 CODE_SIGNING_ALLOWED=NO build` | 통과, `** BUILD SUCCEEDED **` |
| `./scripts/check-no-appkit.sh` | 통과, `RhwpCoreBridge` AppKit/UIKit 의존 없음 |
| `./scripts/check-extension-registration-hygiene.sh --check-only` | 통과, Issues 없음 |

비고:

- 최초 `xcodebuild` sandbox 실행은 Sparkle fetch network 제한과 SwiftPM cache write 제한으로 실패했다.
- 같은 명령을 승인된 escalated 실행으로 재시도해 빌드 성공을 확인했다.
- extension hygiene는 `build.noindex/DerivedData-task121/.../Alhangeul.app` 개발 산출물이 존재한다는 warning만 냈고, 등록된 개발 provider는 없었다.

## RawSvg fixture를 찾을 때의 특징

RawSvg positive fixture는 “그림으로 삽입된 일반 이미지”가 아니라, upstream core가 OLE/차트 리소스를 inline SVG fragment로 내보내는 문서여야 한다.

가능성이 높은 파일:

| 유형 | 기대 RawSvg payload |
|------|--------------------|
| HWP/HWPX 안에 삽입된 OOXML chart | `<g class="hwp-ooxml-chart">...` 복합 SVG |
| OLE container 내부 OOXML chart | `<g class="hwp-ooxml-chart">...` 복합 SVG |
| OLE object의 EMF preview | `<g transform="matrix(...)">...` 복합 SVG |
| OLE native image object | 단일 `<image ... xlink:href="data:image/png;base64,..."/>` |

가능성이 낮은 파일:

| 유형 | 이유 |
|------|------|
| 일반 “그림 넣기” 이미지 | 보통 `Image` node로 내려온다 |
| 수식 | `Equation` node로 내려온다 |
| 양식 컨트롤 | `FormObject` 계열이다 |
| 문서 본문에 `OLE`/`chart`라는 글자가 있는 문서 | 텍스트 hit일 뿐 RawSvg가 아니다 |
| 이번 제공 fixture 같은 Placeholder-only OLE | OLE fallback 검증에는 유효하지만 RawSvg positive는 아니다 |

찾아볼 때는 한컴오피스에서 “개체 삽입”으로 들어간 Excel/PowerPoint/차트/OLE 개체가 실제 문서 안에 보이는 HWP/HWPX가 좋다. 단순 스크린샷이나 이미지로 붙인 차트는 RawSvg가 아니라 `Image`가 될 가능성이 높다.

## 다음 단계 제안

Stage 4는 다음 순서가 적절하다.

1. 이번 Stage 3 변경을 기준으로 visual diff harness를 다시 시도한다.
2. readiness timeout이 재현되면 harness 안정화만 별도 범위로 분리한다.
3. 사용자가 RawSvg positive fixture를 확보하면 Stage 4 검증 입력에 추가한다.
4. 실제 복합 SVG chart/EMF fixture가 생기면 fallback 유지 여부와 별도 raster backend 도입 필요성을 판단한다.
