# Task M015 #120 Stage 5 완료보고서

## 단계 목적

HostApp, Quick Look, Thumbnail이 공유하는 Swift native renderer 변경에 대해 최종 smoke/build 검증을 수행하고, 최종 보고서와 오늘할일을 정리했다.

이번 단계에서는 추가 소스 코드를 변경하지 않았다. Stage 2-4에서 구현한 텍스트 advance/cluster drawing 보강과 optional `char_positions` 수용 경로를 통합 검증했다.

## 산출물

- 최종 smoke 산출물: `/private/tmp/rhwp-task120-final-smoke/`
- 최종 render debug 산출물: `/private/tmp/rhwp-task120-final/`
- 단계 보고서: `mydocs/working/task_m015_120_stage5.md`
- 최종 보고서: `mydocs/report/task_m015_120_report.md`
- 오늘할일 갱신: `mydocs/orders/20260502.md`

기준 산출물:

- `/private/tmp/rhwp-task120-final/20250130-hongbo-page1-render-tree.json`
- `/private/tmp/rhwp-task120-final/20250130-hongbo-page1-core.svg`
- `/private/tmp/rhwp-task120-final/20250130-hongbo-page1-native.png`
- `/private/tmp/rhwp-task120-final/20250130-hongbo-page1-summary.txt`

## 본문 변경 정도 / 본문 무손실 여부

샘플 문서와 HWP 본문 데이터는 변경하지 않았다.

이번 단계의 파일 변경은 단계 보고서, 최종 보고서, 오늘할일 문서에 한정된다.

## 검증 결과

작업 브랜치:

```text
## local/task120...origin/devel [ahead 6]
```

구현계획서 Stage 5 검증 명령:

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task120-final-smoke samples/20250130-hongbo.hwp samples/re-align-center-hancom.hwp samples/re-align-right-hancom.hwp samples/re-align-justify-hancom.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-final samples/20250130-hongbo.hwp
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
git diff --check
```

검증 상태:

- `./scripts/check-no-appkit.sh` 통과
- 기본 `./scripts/validate-stage3-render.sh` 통과
- #120 기준 샘플 4개 smoke 통과
- `./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-final samples/20250130-hongbo.hwp` 성공
- `xcodegen generate` 성공
- HostApp Debug build 성공
- `git diff --check` 통과

`check-no-appkit` 결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

기본 smoke 결과:

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=28 line=0 y=768.5 col_bottom=755.9 overflow=12.5px
LAYOUT_OVERFLOW: page=0, col=0, para=28, type=PartialParagraph, y=776.5, bottom=755.9, overflow=20.5px
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452397
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67765
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=176233
```

`exam_kor.hwp` 처리 중 layout overflow 진단 로그가 출력됐지만 명령은 exit code 0으로 통과했다. 이 로그는 이번 텍스트 advance 변경의 build 실패나 smoke 실패가 아니라 기존 layout smoke 진단이다.

#120 기준 샘플 smoke 결과:

```text
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=84306
OK re-align-center-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6666
OK re-align-right-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6615
OK re-align-justify-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6652
```

`20250130-hongbo.hwp` 최종 summary:

```text
RenderTreeJSONBytes: 99137
CoreSVGBytes: 235786
NativePNGSize: 794x1123
NativeNonWhitePixels: 84306
TextRuns: 60
HangulRuns: 35
HangulScalars: 535
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task120-final/20250130-hongbo-page1-core.svg.qlmanage.log
```

`xcodegen generate` 결과:

```text
Created project at /tmp/rhwp-mac-task120/AlhangeulMac.xcodeproj
```

HostApp Debug build:

```text
** BUILD SUCCEEDED ** [12.389 sec]
```

build 산출물:

```text
build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app
build.noindex/DerivedData/Build/Products/Debug/AlhangeulMacPreview.appex
build.noindex/DerivedData/Build/Products/Debug/AlhangeulMacThumbnail.appex
```

Xcode가 CoreSimulatorService 관련 경고를 출력했지만 macOS HostApp build는 성공했다.

## 잔여 위험

- 현재 core render tree는 아직 `char_positions`를 내보내지 않으므로 실제 문서에서는 Stage 3 Swift fallback이 계속 사용된다.
- rhwp-studio와 동등한 위치 재현을 안정화하려면 core/rhwp-studio가 쓰는 full precision 글자 위치 배열을 `TextRun.char_positions`로 넘기는 후속 core 작업이 필요하다.
- core SVG rasterize는 로컬 `qlmanage` sandbox 오류로 실패해 pixel diff를 생성하지 못했다.
- CoreText font fallback과 core SVG/font metric 차이 때문에 일부 라틴/기호/옛한글 cluster의 폭은 후속 샘플에서 추가 보정이 필요할 수 있다.

## 다음 단계 영향

Task #120 구현과 통합 검증은 완료됐다.

다음 단계는 작업지시자 승인 후 최종 PR 게시 절차로 진행한다.
