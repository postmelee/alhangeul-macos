# Task M014 #307 Stage 3 보고서 - renderer smoke와 extension build 검증

## 목적

Stage 2의 `0xFFFFFFFF` shade sentinel 보정이 문제 샘플에서 실제로 텍스트 박스를 제거하는지 확인하고, Quick Look/Thumbnail extension build가 통과하는지 검증한다.

## 실행 명령

```bash
./scripts/render-debug-compare.sh build.noindex/task307-stage3 samples/basic/BookReview.hwp samples/복학원서.hwp
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask307 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask307 CODE_SIGNING_ALLOWED=NO build
```

## render smoke 결과

`render-debug-compare.sh`는 두 샘플 모두 OK로 완료됐다.

```text
OK BookReview.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-mac-task307/build.noindex/task307-stage3/BookReview-page1-render-tree.json coreSVG=/private/tmp/rhwp-mac-task307/build.noindex/task307-stage3/BookReview-page1-core.svg nativePNG=/private/tmp/rhwp-mac-task307/build.noindex/task307-stage3/BookReview-page1-native.png summary=/private/tmp/rhwp-mac-task307/build.noindex/task307-stage3/BookReview-page1-summary.txt
OK 복학원서.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-mac-task307/build.noindex/task307-stage3/복학원서-page1-render-tree.json coreSVG=/private/tmp/rhwp-mac-task307/build.noindex/task307-stage3/복학원서-page1-core.svg nativePNG=/private/tmp/rhwp-mac-task307/build.noindex/task307-stage3/복학원서-page1-native.png summary=/private/tmp/rhwp-mac-task307/build.noindex/task307-stage3/복학원서-page1-summary.txt
```

`BookReview.hwp`에서는 Stage 1 native PNG에 보이던 표지 제목과 큰 글자 뒤의 흰색 반투명 박스가 사라졌다.

`복학원서.hwp`에서는 Stage 1 native PNG에 보이던 본문/표/서명란 주변 가로 흰색 텍스트 박스가 사라졌다. #305에서 보정한 PUA `(인)` 표시는 유지됐다.

Stage 1과 Stage 3 양쪽에서 중앙 워터마크가 앱 viewer보다 진하게 보이는 기존 CoreGraphics overlay 표현 차이는 남아 있다. 이번 이슈의 변경 전후 동일하게 존재하므로 #307 범위 밖의 잔여 렌더링 parity 이슈로 본다.

## summary 주요 값

`BookReview.hwp`:

```text
PageCount: 2
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 104282
CoreSVGBytes: 126245
NativePNGSize: 794x1123
NativeNonWhitePixels: 389185
TextRuns: 66
HangulRuns: 28
HangulScalars: 209
MissingHangulGlyphs: 0
```

`복학원서.hwp`:

```text
PageCount: 1
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 196151
CoreSVGBytes: 791753
NativePNGSize: 794x1123
NativeNonWhitePixels: 277216
TextRuns: 102
HangulRuns: 25
HangulScalars: 143
MissingHangulGlyphs: 0
```

`qlmanage` 기반 core SVG rasterize는 두 샘플 모두 실패해 pixel diff는 생성되지 않았다. native PNG 생성과 summary는 성공했고, 이번 검증 목적은 CoreGraphics native 렌더 결과의 텍스트 박스 제거 확인이므로 blocker로 보지 않는다.

## build 결과

QLExtension scheme:

```text
** BUILD SUCCEEDED ** [13.655 sec]
```

ThumbnailExtension scheme:

```text
** BUILD SUCCEEDED ** [2.100 sec]
```

QLExtension scheme 빌드 중 Swift Package `Sparkle 2.9.1` resolved package 준비가 실행됐다. 같은 `DerivedDataTask307`를 재사용한 ThumbnailExtension scheme 빌드는 증분 빌드로 통과했다.

## 검증 판단

- CoreGraphics renderer compile 통과.
- Quick Look/Thumbnail extension build 통과.
- `BookReview.hwp`, `복학원서.hwp`의 `0xFFFFFFFF` shade sentinel 오인으로 생기던 텍스트 박스 제거 확인.
- #305 PUA 보정 유지 확인.

## 다음 단계

최종 보고서를 작성하고, #301 릴리즈 작업에 이 PR merge 후 `devel` 재기준화가 필요함을 명시한다.
