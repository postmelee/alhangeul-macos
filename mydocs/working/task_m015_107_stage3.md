# Task M015 #107 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 task-scoped tech 문서로 분리한 M015 필수 샘플 smoke/diff 기준이 실제 명령으로 재현되는지 확인했다.

또한 `render-debug-compare.sh --help`가 사용법을 출력하면서도 exit code 1로 종료되는 문제를 확인해, help 호출은 bridge 산출물 없이도 exit code 0으로 끝나도록 보강했다.

## 산출물

변경 파일:

| 파일 | 요약 |
|------|------|
| `scripts/render-debug-compare.sh` | `--help`/`-h`를 인자 개수 검사보다 먼저 처리해 usage 확인이 exit code 0으로 끝나도록 보강 |
| `mydocs/working/task_m015_107_stage3.md` | Stage 3 완료 보고서 |

검증 산출물:

| 샘플 | 출력 위치 |
|------|----------|
| `samples/basic/BookReview.hwp` native smoke | `/private/tmp/rhwp-task107-smoke/BookReview-page1.png` |
| `samples/복학원서.hwp` native smoke | `/private/tmp/rhwp-task107-smoke/복학원서-page1.png` |
| `samples/basic/BookReview.hwp` core/native compare | `/private/tmp/rhwp-task107-bookreview/` |
| `samples/복학원서.hwp` core/native compare | `/private/tmp/rhwp-task107-bokhak/` |

분리 worktree에는 `Frameworks/` 산출물이 없어 Stage 3 검증 전에 `./scripts/build-rust-macos.sh`를 실행했다. 생성된 `Frameworks/`, `RustBridge/target/`, `/private/tmp` 산출물은 generated/ignored 또는 임시 산출물로 취급하며 tracked 변경에 포함하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

Swift/Rust source와 renderer 구현은 변경하지 않았다.

shell script 변경은 `render-debug-compare.sh`의 help 조기 처리 5줄 추가로 제한했다. 기존 일반 실행 경로와 diff 생성 경로는 변경하지 않았다.

## 검증 결과

작업 브랜치:

```text
## local/task107
```

### help 출력

```bash
./scripts/validate-stage3-render.sh --help
```

핵심 출력:

```text
Usage: ./scripts/validate-stage3-render.sh [output-dir] [hwp-or-hwpx ...]
Builds and runs a native renderer smoke check for the first page of each input.
```

```bash
./scripts/render-debug-compare.sh --help
```

보강 후 exit code 0으로 종료했다.

핵심 출력:

```text
Usage: ./scripts/render-debug-compare.sh <output-dir> [--page N] <hwp-or-hwpx> [...]
Creates render tree JSON, rhwp core SVG, native renderer PNG, summary files,
and optional core raster PNG / pixel diff files when local SVG rasterization works.
```

### Rust bridge 산출물 생성

```bash
./scripts/build-rust-macos.sh
```

결과:

```text
Architectures in the fat file: /private/tmp/rhwp-mac-task107/Frameworks/universal/librhwp.a are: x86_64 arm64
xcframework successfully written out to: /private/tmp/rhwp-mac-task107/Frameworks/Rhwp.xcframework
Done: /private/tmp/rhwp-mac-task107/Frameworks/Rhwp.xcframework
99M /private/tmp/rhwp-mac-task107/Frameworks/universal/librhwp.a
99M /private/tmp/rhwp-mac-task107/Frameworks/Rhwp.xcframework
```

Xcode가 CoreSimulatorService, user cache, fs event stream 관련 경고를 출력했지만 XCFramework 생성은 성공했다.

### 필수 샘플 native smoke

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task107-smoke samples/basic/BookReview.hwp samples/복학원서.hwp
```

결과:

```text
OK BookReview.hwp: page=1 size=794x1123 textRuns=66 hangulRuns=28 hangulScalars=209 nonWhitePixels=390859 png=/private/tmp/rhwp-task107-smoke/BookReview-page1.png
OK 복학원서.hwp: page=1 size=794x1123 textRuns=102 hangulRuns=25 hangulScalars=143 nonWhitePixels=154266 png=/private/tmp/rhwp-task107-smoke/복학원서-page1.png
```

`복학원서.hwp` 실행 중 다음 diagnostic이 출력됐지만 command exit code는 0이었다.

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=16 line=1 y=1326.6 col_bottom=1084.7 overflow=241.9px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1336.2, bottom=1084.7, overflow=251.5px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1336.2, bottom=1084.7, overflow=251.5px
```

### BookReview core/native compare

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bookreview samples/basic/BookReview.hwp
test -s /private/tmp/rhwp-task107-bookreview/BookReview-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task107-bookreview/BookReview-page1-summary.txt
```

결과:

```text
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
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task107-bookreview/BookReview-page1-core.svg.qlmanage.log
```

### 복학원서 core/native compare

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bokhak samples/복학원서.hwp
test -s /private/tmp/rhwp-task107-bokhak/복학원서-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task107-bokhak/복학원서-page1-summary.txt
```

결과:

```text
PageCount: 1
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 189498
CoreSVGBytes: 380803
NativePNGSize: 794x1123
NativeNonWhitePixels: 154266
TextRuns: 102
HangulRuns: 25
HangulScalars: 143
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task107-bokhak/복학원서-page1-core.svg.qlmanage.log
```

macOS 파일명 정규화 때문에 일부 출력에는 decomposed Hangul 파일명이 표시됐지만, 계획서의 composed Hangul 경로 `복학원서-page1-summary.txt` 기준 `test -s`도 통과했다.

### script syntax와 diff check

```bash
bash -n scripts/validate-stage3-render.sh scripts/render-debug-compare.sh
git diff --check
```

결과: 출력 없이 통과.

## 잔여 위험

- `qlmanage` sandbox 오류로 core raster PNG와 diff PNG는 생성되지 않았다. 필수 산출물인 render tree JSON, core SVG, native PNG, summary는 두 샘플 모두 생성됐다.
- `복학원서.hwp`는 layout overflow diagnostic이 계속 출력된다. Stage 2 문서 기준대로 책임 경계 분리 샘플로 다루고, Swift renderer 단독 회귀로 단정하지 않는다.
- 이번 Stage 3는 필수 샘플 재현 검증이다. 기능 범주별 후보 샘플 전체 full diff는 수행하지 않았다.

## 다음 단계 영향

Stage 4에서는 다음을 정리한다.

- 문서와 script 변경의 최종 일관성 검색
- `bash -n`과 `check-no-appkit.sh`
- 최종 보고서 작성
- 오늘할일 완료 처리

## 승인 요청

Stage 3 smoke/diff 실행 안내와 필수 샘플 검증 결과를 승인 요청한다.

승인 후 Stage 4 `통합 검증과 최종 보고`로 진행한다.
