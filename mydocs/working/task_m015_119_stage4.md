# Task M015 #119 Stage 4 완료 보고서

## 단계 목적

Stage 2-3의 bundled WOFF2 등록과 HWP font fallback 정책이 Quick Look/Thumbnail 공통 bitmap 경로에서 동작하는지 대표 샘플로 검증한다. 검증 중 발견된 font-sensitive fallback gap은 Stage 4 범위 안에서 보수적으로 보정한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/FontFallback.swift` | BookReview 샘플에서 확인된 장식 계열 proprietary font alias 보강 |
| `mydocs/tech/font_fallback_strategy.md` | 장식 계열 fallback 체인 문서화 |
| `mydocs/working/task_m015_119_stage4.md` | Stage 4 검증 결과 |
| `mydocs/orders/20260503.md` | #119 상태를 Stage 4 완료 승인 대기로 갱신 |

## 구현 보정

`BookReview.hwp` page 1 debug summary에서 다음 font family가 확인됐다.

```text
   1 HY바다L
   7 한컴 소망 B
   2 한컴 쿨재즈 B
  55 함초롬돋움
   1 함초롬바탕
```

`함초롬돋움`과 `함초롬바탕`은 Stage 3에서 이미 각각 Pretendard/Noto Serif KR 체인으로 연결됐다. 반면 `HY바다L`, `한컴 소망 B`, `한컴 쿨재즈 B`는 unknown fallback으로 내려가고 있었다. Glyph는 표시되지만 #119의 오픈 라이선스 font fallback 취지상 장식 계열 bundled font 후보로 연결하는 편이 맞아 다음 체인을 추가했다.

- `HY바다L`: Cafe24Ssurround -> Happiness Sans -> Pretendard -> Apple SD Gothic Neo
- `한컴 소망 B`: Cafe24Supermagic -> Happiness Sans -> Pretendard -> Apple SD Gothic Neo
- `한컴 쿨재즈 B`: Cafe24Ssurround -> Cafe24Supermagic -> Happiness Sans -> Pretendard -> Apple SD Gothic Neo

이 보정은 proprietary font 파일을 추가하지 않고, 이미 `rhwp-studio/fonts`에 포함된 오픈/무료 배포 WOFF2만 후보로 사용한다.

## 렌더 smoke 결과

### 대표 샘플 3개

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task119-stage4-smoke-after \
  samples/basic/BookReview.hwp \
  samples/복학원서.hwp \
  samples/20250130-hongbo.hwp
```

결과:

```text
OK BookReview.hwp: page=1 size=794x1123 textRuns=66 hangulRuns=28 hangulScalars=209 nonWhitePixels=386919 png=/private/tmp/rhwp-task119-stage4-smoke-after/BookReview-page1.png
OK 복학원서.hwp: page=1 size=794x1123 textRuns=102 hangulRuns=25 hangulScalars=143 nonWhitePixels=261878 png=/private/tmp/rhwp-task119-stage4-smoke-after/복학원서-page1.png
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=91412 png=/private/tmp/rhwp-task119-stage4-smoke-after/20250130-hongbo-page1.png
```

`BookReview.hwp`에서는 기존 layout overflow diagnostic이 출력됐지만 smoke 실패로 이어지지 않았다.

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=16 line=1 y=1326.6 col_bottom=1084.7 overflow=241.9px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1336.2, bottom=1084.7, overflow=251.5px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1336.2, bottom=1084.7, overflow=251.5px
```

### render-debug 산출물

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-task119-stage4-hongbo samples/20250130-hongbo.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task119-stage4-book-after samples/basic/BookReview.hwp
```

홍보 샘플 summary:

```text
PageCount: 4
NativePNGSize: 794x1123
NativeNonWhitePixels: 91412
TextRuns: 60
HangulRuns: 35
HangulScalars: 535
MissingHangulGlyphs: 0
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task119-stage4-hongbo/20250130-hongbo-page1-core.svg.qlmanage.log
```

BookReview summary:

```text
PageCount: 2
NativePNGSize: 794x1123
NativeNonWhitePixels: 386919
TextRuns: 66
HangulRuns: 28
HangulScalars: 209
MissingHangulGlyphs: 0
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task119-stage4-book-after/BookReview-page1-core.svg.qlmanage.log
```

core SVG raster diff는 `qlmanage`의 SVG rasterize 실패로 생성되지 않았다. render tree JSON, core SVG, native PNG, summary는 생성됐으므로 필수 debug 산출물은 충족한다.

## Finder / Quick Look 통합 smoke

`build_run_guide.md`의 Finder 통합 확인 기준에 맞춰 Debug 산출물이 아니라 Release package 산출물을 사용했다.

```bash
ALHANGEUL_BUILD_ROOT=/private/tmp/rhwp-mac-task119/build.noindex \
  ./scripts/package-release.sh 0.1.0-task119-stage4
```

결과:

```text
** BUILD SUCCEEDED ** [19.416 sec]
ec912bcb4773c213b7fbea9a64c3ef9f9e24dd9ecf1ea027a7a63991b3bc8d52  alhangeul-macos-0.1.0-task119-stage4.zip
```

산출물:

```text
build.noindex/release/AlhangeulMac.app
build.noindex/release/alhangeul-macos-0.1.0-task119-stage4.zip
```

Release app을 `~/Applications/AlhangeulMac.app`으로 교체하고 LaunchServices/PlugInKit에 등록했다.

```bash
pluginkit -mAvvv | rg "com\\.postmelee\\.alhangeulmac|AlhangeulMac"
```

결과:

```text
+    com.postmelee.alhangeulmac.QLExtension(0.1.0)
            Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
       Parent Bundle = /Users/melee/Applications/AlhangeulMac.app
+    com.postmelee.alhangeulmac.ThumbnailExtension(0.1.0)
            Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
       Parent Bundle = /Users/melee/Applications/AlhangeulMac.app
```

서명 검증:

```bash
codesign --verify --deep --strict --verbose=2 "$HOME/Applications/AlhangeulMac.app"
```

결과:

```text
/Users/melee/Applications/AlhangeulMac.app: valid on disk
/Users/melee/Applications/AlhangeulMac.app: satisfies its Designated Requirement
```

Thumbnail smoke:

```bash
qlmanage -r
qlmanage -r cache
mkdir -p /tmp/alhangeul-task119-thumbnail
qlmanage -t -x -s 512 -o /tmp/alhangeul-task119-thumbnail samples/20250130-hongbo.hwp
```

결과:

```text
Testing Quick Look thumbnails with files using server:
    samples/20250130-hongbo.hwp
* /private/tmp/rhwp-mac-task119/samples/20250130-hongbo.hwp produced one thumbnail
Done producing thumbnails
```

생성 PNG:

```text
/tmp/alhangeul-task119-thumbnail/20250130-hongbo.hwp.png
pixelWidth: 363
pixelHeight: 512
```

자동화 환경에서는 GUI preview 창을 띄우는 `qlmanage -p`를 실행하지 않았다. Preview extension은 PlugInKit 등록으로 확인했고, 실제 headless 렌더링은 Thumbnail extension의 `qlmanage -t -x`로 확인했다.

## Resource 배치 확인

설치된 app 기준 HostApp resource에는 WOFF2 34개가 포함되어 있다.

```text
/Users/melee/Applications/AlhangeulMac.app/Contents/Resources/rhwp-studio/fonts/*.woff2 = 34
```

QLExtension/ThumbnailExtension 내부에는 `rhwp-studio/fonts`가 중복 포함되어 있지 않다. 따라서 Stage 2의 parent app resource reuse 전략이 bundle 배치상 유지된다.

## 검증 결과 요약

- `./scripts/check-no-appkit.sh`: 성공
- `git diff --check`: 성공
- 대표 샘플 3개 render smoke: 성공
- 홍보/BookReview render-debug 산출물 생성: 성공
- Release package build: 성공
- 설치본 codesign 검증: 성공
- PlugInKit Preview/Thumbnail extension 등록 확인: 성공
- `qlmanage -t -x` thumbnail 생성: 성공

## 잔여 위험

- `qlmanage -p` GUI preview smoke는 자동화 환경 정책상 실행하지 않았다.
- core SVG raster diff PNG는 `qlmanage` SVG rasterize 실패로 생성되지 않았다. 이 문제는 render debug guide에서 선택 산출물 실패로 분리하는 항목이다.
- Stage 4는 page 1 중심 smoke다. 장식체 fallback의 정성적 시각 평가는 PR 전 비교 이미지 또는 수동 Finder 확인으로 보강할 수 있다.

## 다음 단계 영향

Stage 5에서는 font resource provenance와 fallback 정책 문서를 최종 정리하고, 최종 보고서와 PR 준비 상태를 만든다.

## 승인 요청

Stage 5. 라이선스 문서화와 최종 정리 진행 승인을 요청한다.
