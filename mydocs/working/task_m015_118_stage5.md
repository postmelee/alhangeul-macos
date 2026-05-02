# Task M015 #118 Stage 5 완료보고서

## 단계 목적

HostApp, Quick Look, Thumbnail이 공유하는 Swift native renderer 변경에 대해 최종 smoke/build 검증을 수행하고, 최종 보고서와 오늘할일을 정리했다.

이번 단계에서는 추가 소스 코드를 변경하지 않았다. Stage 2-4에서 구현한 `Equation.svg_content` 파서와 CoreGraphics/CoreText drawing 결과를 통합 검증했다.

## 산출물

- 최종 render debug 산출물: `/private/tmp/rhwp-task118-final/`
- 단계 보고서: `mydocs/working/task_m015_118_stage5.md`
- 최종 보고서: `mydocs/report/task_m015_118_report.md`
- 오늘할일 갱신: `mydocs/orders/20260502.md`

기준 산출물:

- `/private/tmp/rhwp-task118-final/exam_math_no-page1-render-tree.json`
- `/private/tmp/rhwp-task118-final/exam_math_no-page1-core.svg`
- `/private/tmp/rhwp-task118-final/exam_math_no-page1-native.png`
- `/private/tmp/rhwp-task118-final/exam_math_no-page1-summary.txt`

## 본문 변경 정도 / 본문 무손실 여부

샘플 문서와 HWP 본문 데이터는 변경하지 않았다.

렌더 debug와 Xcode build 실행을 위해 worktree에 `Frameworks` symlink를 임시로 만들었고, 검증 후 제거했다. git 추적 대상에는 포함하지 않았다.

## 검증 결과

작업 브랜치:

```text
## local/task118...origin/devel [ahead 6, behind 9]
```

`origin/devel`은 작업 시작 뒤 앞서갔지만, Stage 5는 현재 task branch 기준의 최종 검증 단계이므로 중간 merge/rebase 없이 검증했다. PR 게시 전 최신 `devel` 반영 여부를 별도로 확인해야 한다.

구현계획서 Stage 5 검증 명령:

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-final samples/exam_math_no.hwp
git diff --check
```

검증 상태:

- `./scripts/check-no-appkit.sh` 통과
- `xcodegen generate` 성공
- `./scripts/validate-stage3-render.sh` 통과
- HostApp Debug build 성공
- `./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-final samples/exam_math_no.hwp` 성공
- `git diff --check` 통과

`validate-stage3-render.sh` 결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452058
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67872
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=176579
```

HostApp Debug build:

```text
** BUILD SUCCEEDED ** [12.417 sec]
```

Xcode가 CoreSimulatorService 관련 경고를 출력했지만 macOS HostApp build는 성공했다.

`exam_math_no.hwp` 최종 summary:

```text
RenderTreeJSONBytes: 217884
CoreSVGBytes: 67323
NativePNGSize: 1028x1490
NativeNonWhitePixels: 28151
TextRuns: 108
HangulRuns: 32
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task118-final/exam_math_no-page1-core.svg.qlmanage.log
```

Stage 1 대비 변화:

```text
exam_math_no.hwp NativeNonWhitePixels: 24091 -> 28151 (+4060)
eq-01.hwp       NativeNonWhitePixels: 34514 -> 45341 (+10827)
```

## 잔여 위험

- core SVG rasterize는 로컬 `qlmanage` sandbox 오류로 실패해 pixel diff를 생성하지 못했다.
- 수식 표시 자체는 회복됐지만 font fallback 차이로 글자 폭, baseline, 괄호 곡선 모양이 core SVG 또는 한컴 viewer와 완전히 같지 않을 수 있다.
- SVG path 지원은 `M/L/H/V/Q/Z` subset이다. cubic curve, arc, transform 같은 SVG 기능이 포함된 수식은 후속 보강이 필요하다.
- `origin/devel`이 현재 branch보다 9 commit 앞서 있으므로 PR 게시 전 최신 `devel`과의 통합 상태를 확인해야 한다.

## 다음 단계 영향

Task #118 구현과 검증은 완료됐다. 다음 단계는 작업지시자 승인 후 최종 PR 게시 절차로 진행한다.
