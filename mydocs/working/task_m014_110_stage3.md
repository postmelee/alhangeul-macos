# Task M014 #110 Stage 3 완료 보고서

## 단계 목적

Stage 3은 승인된 Stage 2 정책에 따라 Swift/CoreGraphics renderer에 `FormObject` 정적 preview를 구현하는 단계다. `RenderTree.swift`의 payload 모델을 확장하고, `CGTreeRenderer`의 `.formObject` no-op을 type별 renderer로 교체했다.

## 산출물

| 파일 | 요약 |
|------|------|
| `Sources/RhwpCoreBridge/RenderTree.swift` | `FormObjectNode`에 `foreColor`, `backColor`, `value`, `enabled`, `name` optional field 추가 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | `FormObject` dispatch, PushButton/CheckBox/RadioButton/ComboBox/Edit/static fallback 렌더링 추가 |
| `build.noindex/task110-stage3-render-debug/` | target sample render-debug 산출물. 재생성 가능하므로 커밋 제외 |
| `build.noindex/DerivedData-task110/` | HostApp Debug build 산출물. 재생성 가능하므로 커밋 제외 |

변경 규모:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift | 392 +++++++++++++++++++++++++++-
Sources/RhwpCoreBridge/RenderTree.swift     |   8 +
2 files changed, 396 insertions(+), 4 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 변경은 없고 Swift 소스만 변경했다. 기존 `Placeholder`, `RawSvg`, `Image`, `Equation`, 일반 text rendering 경로는 의도적으로 건드리지 않았다.

## 구현 내용

`RenderTree.swift`:

- `FormObjectNode`에 실제 payload에 존재하는 optional field를 추가했다.
- 추가 field는 모두 optional이라 기존 payload decode 실패를 만들지 않는다.

`CGTreeRenderer.swift`:

- `.formObject(let formObject)` 분기에서 `shouldRenderFlowContent` gate를 적용하고 `renderFormObject`를 호출한다.
- `form_type`은 alnum/lowercase normalized key로 dispatch한다.
- known type:
  - `PushButton`: gray rect + centered caption
  - `CheckBox`: square + `value != 0` check mark + left label
  - `RadioButton`: circle + selected inner dot + left label
  - `ComboBox`: input rect + right button + down arrow + text label
  - `Edit`: empty input rect. text/caption이 없으면 `name`/type fallback을 표시하지 않음
- unsupported type:
  - solid fallback box + type/name label
  - `Placeholder` fallback과 구분하기 위해 dashed stroke를 쓰지 않음
- `#RRGGBB` color string parser와 RGB helper를 추가했다.
- label helper는 CoreText와 `Apple SD Gothic Neo` fallback을 사용하고 AppKit/UIKit/WebKit 의존을 추가하지 않았다.

Stage 3 중 visual inspection 결과:

- `form-01.hwp` native PNG에서 버튼, 체크박스, 콤보박스, 라디오, 입력칸이 표시된다.
- 최초 구현 직후 empty `Edit` object가 `name` fallback으로 `Edit` label을 표시했으나, Stage 2 정책과 core SVG reference에 맞게 empty rect만 표시하도록 보정했다.
- `form-002.hwpx` native PNG에서 checkbox square/check/label이 표시된다.

## 검증 결과

### render-debug-compare

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task110-stage3-render-debug --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx
```

결과:

```text
OK form-01.hwp: page=1 renderTreeJSON=.../form-01-page1-render-tree.json coreSVG=.../form-01-page1-core.svg nativePNG=.../form-01-page1-native.png summary=.../form-01-page1-summary.txt
OK form-002.hwpx: page=1 renderTreeJSON=.../form-002-page1-render-tree.json coreSVG=.../form-002-page1-core.svg nativePNG=.../form-002-page1-native.png summary=.../form-002-page1-summary.txt
```

Native summary:

| 샘플 | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|---------------|---------------------:|---------:|-----------:|--------------------:|
| `form-01.hwp` | `794x1123` | 4760 | 15 | 1 | 0 |
| `form-002.hwpx` | `794x1123` | 189203 | 135 | 62 | 0 |

Stage 1 baseline 대비 native non-white 변화:

| 샘플 | Stage 1 | Stage 3 | 변화 |
|------|--------:|--------:|-----:|
| `form-01.hwp` | 352 | 4760 | +4408 |
| `form-002.hwpx` | 173421 | 189203 | +15782 |

`render-debug-compare`의 optional core SVG raster diff는 Stage 1과 같이 `qlmanage` sandbox initialization 실패로 생성되지 않았다. 스크립트 exit code는 0이었다.

### xcodebuild

명령:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task110 CODE_SIGNING_ALLOWED=NO build
```

sandbox 안 첫 실행은 Sparkle package fetch에서 DNS 제한으로 실패했다.

```text
Failed to clone repository https://github.com/sparkle-project/Sparkle
fatal: unable to access 'https://github.com/sparkle-project/Sparkle/': Could not resolve host: github.com
```

동일 명령을 승인 경로로 재실행해 성공했다.

```text
Resolved source packages:
  Sparkle: https://github.com/sparkle-project/Sparkle @ 2.9.1
** BUILD SUCCEEDED ** [13.301 sec]
```

### policy / hygiene

명령:

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
./scripts/check-no-appkit.sh
git diff --check
```

결과:

```text
Issues:
  - (none)
Warnings:
  - development/test Alhangeul.app bundles exist under build.noindex or DerivedData; this is only a problem if they are registered.
  - Quick Look preview provider path was not reported by PlugInKit.
  - Thumbnail provider path was not reported by PlugInKit.
```

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

`git diff --check`도 통과했다.

## 잔여 위험

- Stage 3는 target sample render-debug와 HostApp build smoke까지만 수행했다. rhwp-studio visual diff 재측정과 M014 regression sample 확인은 Stage 4 범위다.
- `form-002.hwpx` checkbox label은 width fitting 때문에 long label에서 core SVG보다 작게 보일 수 있다. Stage 4 visual diff에서 수치와 시각 결과를 같이 판단한다.
- disabled control fixture가 없어 `enabled=false` tone은 build-level smoke만 통과했다.
- HTML/XML entity unescape는 Stage 2 정책대로 적용하지 않았다. `R&amp;&amp;D` 표시는 bundled rhwp-studio v0.7.13 parity 기준으로 유지된다.
- `cell_location`은 모델에 추가하지 않았으므로 cell-aware diagnostics는 이번 구현에서 제공하지 않는다.

## 다음 단계 영향

Stage 4에서는 같은 target sample을 visual diff harness로 재측정하고, M014 공통 regression sample set에서 #116/#122/#121 관련 회귀가 없는지 확인해야 한다. 특히 `form-01.hwp`는 FormObject가 추가되며 pixel diff bounds와 non-white count가 크게 바뀌므로, rhwp-studio reference와 가까워지는지를 기준으로 판단한다.

## 승인 요청

Stage 3 구현과 smoke 검증을 완료했다. Stage 4에서 visual diff, render-debug 재측정, shared path 회귀 검증을 진행해도 되는지 승인 요청한다.
