# Task M015 #108 Stage 3 완료 보고서

## 단계 목적

Stage 2의 `CGTreeRenderer` 도형 children 순회 보강 후 `samples/basic/BookReview.hwp` 첫 페이지 native renderer 출력에서 텍스트가 실제로 표시되는지 검증했다.

## 산출물

변경 후 렌더 산출물 위치:

- `/private/tmp/rhwp-task108-stage3/BookReview-page1-render-tree.json`
- `/private/tmp/rhwp-task108-stage3/BookReview-page1-core.svg`
- `/private/tmp/rhwp-task108-stage3/BookReview-page1-native.png`
- `/private/tmp/rhwp-task108-stage3/BookReview-page1-summary.txt`
- `/private/tmp/rhwp-task108-stage3/BookReview-page1-core.svg.qlmanage.log`

산출물 크기:

| 파일 | 크기 |
|------|------|
| render tree JSON | 100,010 bytes |
| core SVG | 70,430 bytes |
| native PNG | 98,905 bytes, 794x1123 |
| summary | 812 bytes |

## 본문 변경 정도 / 본문 무손실 여부

Stage 3에서는 source code를 추가로 변경하지 않았다.

이번 단계의 저장소 변경 대상은 이 단계 보고서뿐이다.

## 검증 결과

검증 명령:

```bash
git status --short --branch
./scripts/render-debug-compare.sh /private/tmp/rhwp-task108-stage3 samples/basic/BookReview.hwp
test -s /private/tmp/rhwp-task108-stage3/BookReview-page1-render-tree.json
test -s /private/tmp/rhwp-task108-stage3/BookReview-page1-core.svg
test -s /private/tmp/rhwp-task108-stage3/BookReview-page1-native.png
test -s /private/tmp/rhwp-task108-stage3/BookReview-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task108-stage3/BookReview-page1-summary.txt
git diff --check -- mydocs/working/task_m015_108_stage3.md
```

핵심 출력:

```text
OK BookReview.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task108-stage3/BookReview-page1-render-tree.json coreSVG=/private/tmp/rhwp-task108-stage3/BookReview-page1-core.svg nativePNG=/private/tmp/rhwp-task108-stage3/BookReview-page1-native.png summary=/private/tmp/rhwp-task108-stage3/BookReview-page1-summary.txt

PageCount: 2
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 100010
CoreSVGBytes: 70430
NativePNGSize: 794x1123
NativeNonWhitePixels: 390859
TextRuns: 66
HangulRuns: 28
HangulScalars: 209
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task108-stage3/BookReview-page1-core.svg.qlmanage.log
```

`qlmanage` rasterize 실패 로그:

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

`git diff --check`는 오류 없이 통과했다.

## 전후 비교

| 항목 | Stage 1 변경 전 | Stage 3 변경 후 |
|------|------------------|------------------|
| render tree JSON bytes | 100,010 | 100,010 |
| core SVG bytes | 70,430 | 70,430 |
| native PNG bytes | 21,816 | 98,905 |
| native PNG size | 794x1123 | 794x1123 |
| NativeNonWhitePixels | 377,463 | 390,859 |
| TextRuns | 66 | 66 |
| HangulRuns | 28 | 28 |
| MissingHangulGlyphs | 0 | 0 |
| Diff | not generated | not generated |

Stage 3 native PNG를 시각 확인한 결과 다음 텍스트가 표시된다.

- 상단: `단순 하면서도 강력한 연령대별 재테크 전략 61`
- 중간: `월급쟁이, 부자로 은퇴하기`
- 본문 목차: `프롤로그_부자로 은퇴하려면...`, `1장_...`, `2장_...` 등
- 우하단: `강우신 지음`, `원앤원북스 / 2006년 8월 / 305쪽`

Stage 1에서 보이지 않던 `Rectangle` children 아래의 `TextLine`/`TextRun`이 Stage 2 변경 후 native renderer 출력에 반영됐다.

## 잔여 위험

- `qlmanage` rasterize 실패로 core SVG raster PNG와 pixel diff는 생성하지 못했다. 이는 Stage 1과 동일한 환경 문제이며 native PNG 필수 산출물 검증은 통과했다.
- 이번 변경은 도형 내부 clipping 일반화를 포함하지 않는다. 도형 bbox 밖 children을 가진 다른 문서에서는 core SVG와 차이가 남을 수 있다.
- `Line`, `Ellipse`, `Path`, `Image` children 순회는 `BookReview.hwp`에서 직접 exercise되지 않는다. Stage 4에서 기본 build와 추가 smoke를 통해 회귀 위험을 한 번 더 확인한다.

## 다음 단계 영향

Stage 4에서는 통합 검증으로 다음을 수행한다.

- `./scripts/check-no-appkit.sh`
- HostApp Debug build
- `BookReview.hwp` 최종 render smoke

최종 보고서에는 Stage 1-3 전후 비교와 남은 제한 사항을 정리한다.

## 승인 요청

Stage 3 검증 결과, `BookReview.hwp` native PNG에서 텍스트 표시가 회복됐음을 확인했다.

Stage 4 통합 검증과 최종 보고로 진행할지 승인 요청한다.
