# Task M015 #119 Stage 3 완료 보고서

## 단계 목적

HWP 문서에서 자주 등장하는 proprietary font family를 `rhwp-studio/fonts`의 오픈 라이선스 WOFF2와 macOS 시스템 폰트로 일관되게 매핑한다. Swift native renderer는 DOM/CSS 구조를 복제하지 않고 CoreText 후보 체인으로 재해석한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/FontFallback.swift` | HWP font family 정규화, bundled/system 후보 체인, bold/italic face 선택 정책 추가 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | TextRun/footnote marker가 공통 `resolveAppleFont(..., size:)` 경로를 사용하도록 변경 |
| `mydocs/tech/font_fallback_strategy.md` | native renderer font fallback 정책 문서화 |
| `mydocs/working/task_m015_119_stage3.md` | Stage 3 구현/검증 결과 |
| `mydocs/orders/20260503.md` | #119 상태를 Stage 3 완료 승인 대기로 갱신 |

## 구현 내용

### 1. HWP font family normalization

`FontFallback.swift`에 HWP font family 정규화와 alias 정책을 모았다.

- 앞뒤 공백 제거
- 영문 대소문자 통일
- 공백, `-`, `_` 제거 후 alias matching
- 알 수 없는 font family는 원래 이름을 먼저 CoreText 후보로 보고 실패하면 시스템 fallback으로 전환

### 2. bundled font 우선 후보 체인

`rhwp-studio/fonts/FONTS.md`와 Stage 1에서 확인한 CoreText PostScript name을 기준으로 후보 체인을 구성했다.

- `함초롬바탕`, `한컴바탕`, `바탕`: Noto Serif KR -> Nanum Myeongjo -> Gowun Batang -> AppleMyungjo
- `HY명조`, `휴먼명조`: Nanum Myeongjo -> Noto Serif KR -> AppleMyungjo
- `궁서`: Gowun Batang -> Nanum Myeongjo -> Noto Serif KR
- `함초롬돋움`, `맑은 고딕`, `Calibri`, `Tahoma`, `Verdana`: Pretendard -> Apple SD Gothic Neo
- `한컴돋움`, `돋움`, `굴림`: Noto Sans KR -> Pretendard -> Nanum Gothic -> Apple SD Gothic Neo
- `HY고딕`, `HY그래픽`, `HY헤드라인M`: Pretendard -> Gowun Dodum -> Noto Sans KR -> Apple SD Gothic Neo
- `돋움체`, `굴림체`, `바탕체`, `Courier New`, `Consolas`: D2Coding -> Nanum Gothic Coding -> Courier New -> Apple SD Gothic Neo

Noto 계열은 파일명이 아니라 Stage 1에서 확인한 PostScript name을 사용했다.

```text
NotoSansKR-Regular.woff2 -> NotoSansKRThin-Regular
NotoSansKR-Bold.woff2 -> NotoSansKRThin-Bold
NotoSerifKR-Regular.woff2 -> NotoSerifKRExtraLight-Regular
NotoSerifKR-Bold.woff2 -> NotoSerifKRExtraLight-Bold
```

### 3. CoreText 선택 정책

기존 코드는 `mapHWPFontToApple` 결과 문자열을 renderer에서 다시 `CTFontCreateWithName`에 넘기고 trait를 붙였다. 이번 단계에서는 `resolveAppleFont(..., size:)`가 다음을 한 번에 수행한다.

- bundled WOFF2 process-local registration 보장
- 후보 font가 실제 CoreText에서 match되는지 `CTFontDescriptorCreateMatchingFontDescriptors`로 확인
- bold face가 있으면 명시 PostScript name 우선 선택
- italic face가 없으면 CoreText synthetic trait 적용을 시도
- 모든 후보가 실패하면 Apple SD Gothic Neo/Helvetica Neue fallback

`CGTreeRenderer`의 TextRun과 footnote marker는 이 공통 경로를 사용하도록 바꿨다. Equation SVG text의 `equationFontName` 경로는 이번 단계에서 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 변환 작업이 아니므로 본문 무손실 검증 대상은 없다.

이번 단계는 renderer의 font 선택 정책만 바꾸며, `rhwp` core 입력 JSON이나 TextRun 문자열은 변경하지 않는다.

## 검증 결과

### Stage 3 계획 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/FontFallback.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task119-stage3-hongbo samples/20250130-hongbo.hwp
test -s /private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-summary.txt
sed -n '1,180p' /private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-summary.txt
git diff --check
```

결과:

- `./scripts/check-no-appkit.sh`: 성공

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

- `render-debug-compare.sh`: 성공

```text
OK 20250130-hongbo.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-render-tree.json coreSVG=/private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-core.svg nativePNG=/private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-native.png summary=/private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-summary.txt
```

summary 핵심값:

```text
PageCount: 4
NativePNGSize: 794x1123
NativeNonWhitePixels: 91412
TextRuns: 60
HangulRuns: 35
HangulScalars: 535
MissingHangulGlyphs: 0
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-core.svg.qlmanage.log
```

- `git diff --check`: 성공

추가로 `validate-stage3-render.sh` compile/smoke 경로도 홍보 샘플로 확인했다.

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task119-stage3-smoke samples/20250130-hongbo.hwp
```

결과:

```text
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=91412 png=/private/tmp/rhwp-task119-stage3-smoke/20250130-hongbo-page1.png
```

### sample font family 확인

홍보 샘플 1쪽의 TextRun font family는 다음과 같았다.

```text
   6 돋움체
  46 바탕
   2 함초롬돋움
   6 함초롬바탕
```

이번 Stage 3 mapping으로 해당 font family들은 각각 D2Coding, Noto Serif KR, Pretendard, Noto Serif KR 후보 체인을 타게 된다.

## Equation / marker 경로 회귀 확인

- footnote marker는 기존 `mapHWPFontToApple` 문자열 직접 생성 대신 공통 `resolveAppleFont(..., size:)` 경로를 사용한다.
- Equation SVG text의 `equationFontName(for:familyList:)`는 Stage 3 범위 밖이라 변경하지 않았다. 따라서 #118의 수식 font fallback 경로는 이번 변경으로 직접 영향받지 않는다.

## 잔여 위험

- CoreText synthetic italic은 font family에 따라 실패할 수 있다. 이 경우 regular/bold face를 유지한다.
- 실제 Quick Look/Thumbnail extension process에서 parent app resource lookup이 성공하는지는 Stage 4에서 app/extension smoke로 다시 확인해야 한다.
- Noto 계열 WOFF2의 PostScript name이 파일명과 다르므로, future font 교체 시 Stage 1과 같은 PostScript name 검증을 다시 해야 한다.
- `qlmanage` SVG rasterize 실패로 core SVG diff PNG는 생성되지 않았다. native PNG와 summary는 생성됐으므로 Stage 3의 compile/render 검증은 충족한다.

## 다음 단계 영향

Stage 4에서는 Quick Look/Thumbnail 중심 render smoke를 수행해 Stage 2의 parent app font resource lookup과 Stage 3의 fallback policy가 extension 공통 bitmap 경로에서 실제로 적용되는지 확인한다.

## 승인 요청

Stage 4. Quick Look/Thumbnail 중심 렌더 검증과 회귀 확인 진행 승인을 요청한다.
