# Task M015 #118 Stage 4 완료보고서

## 단계 목적

`samples/exam_math_no.hwp`와 `samples/eq-01.hwp`에서 Stage 3 구현 결과를 검증하고, 추가 bbox/font/line/path 보정이 필요한지 판단했다.

두 기준 샘플 모두 native PNG에서 수식이 표시되어 Stage 4에서는 추가 소스 보정 없이 검증 결과를 기록했다.

## 산출물

- Stage 4 render debug 산출물: `/private/tmp/rhwp-task118-stage4-exam/`
- Stage 4 render debug 산출물: `/private/tmp/rhwp-task118-stage4-eq/`
- 단계 보고서: `mydocs/working/task_m015_118_stage4.md`

기준 산출물:

- `/private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-render-tree.json`
- `/private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-core.svg`
- `/private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-native.png`
- `/private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-summary.txt`
- `/private/tmp/rhwp-task118-stage4-eq/eq-01-page1-render-tree.json`
- `/private/tmp/rhwp-task118-stage4-eq/eq-01-page1-core.svg`
- `/private/tmp/rhwp-task118-stage4-eq/eq-01-page1-native.png`
- `/private/tmp/rhwp-task118-stage4-eq/eq-01-page1-summary.txt`

## 본문 변경 정도 / 본문 무손실 여부

소스 코드와 샘플 문서 본문은 변경하지 않았다. Stage 4 변경은 이 단계 보고서 추가뿐이다.

렌더 debug 실행을 위해 worktree에 `Frameworks` symlink를 임시로 만들었으나, 검증 후 제거했다. git 추적 대상에는 포함하지 않았다.

## 검증 결과

작업 브랜치:

```text
## local/task118...origin/devel [ahead 5, behind 9]
```

`origin/devel`은 작업 시작 뒤 앞서갔지만, Stage 4는 현재 task branch 기준의 샘플 검증 단계이므로 중간 merge/rebase 없이 검증했다.

구현계획서 Stage 4 검증 명령:

```bash
git status --short --branch
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-stage4-exam samples/exam_math_no.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-stage4-eq samples/eq-01.hwp
test -s /private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-summary.txt
test -s /private/tmp/rhwp-task118-stage4-eq/eq-01-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task118-stage4-eq/eq-01-page1-summary.txt
git diff --check
```

`exam_math_no.hwp` Stage 4 summary:

```text
RenderTreeJSONBytes: 217884
CoreSVGBytes: 67323
NativePNGSize: 1028x1490
NativeNonWhitePixels: 28151
TextRuns: 108
HangulRuns: 32
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-core.svg.qlmanage.log
```

`eq-01.hwp` Stage 4 summary:

```text
RenderTreeJSONBytes: 228819
CoreSVGBytes: 158088
NativePNGSize: 794x1123
NativeNonWhitePixels: 45341
TextRuns: 71
HangulRuns: 37
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task118-stage4-eq/eq-01-page1-core.svg.qlmanage.log
```

Stage 1 대비 변화:

```text
exam_math_no.hwp NativeNonWhitePixels: 24091 -> 28151 (+4060)
eq-01.hwp       NativeNonWhitePixels: 34514 -> 45341 (+10827)
```

Equation 노드 수:

```text
exam_math_no.hwp: 29
eq-01.hwp: 3
```

PNG 확인:

- `/private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-native.png`
  - 1번 문항의 세제곱근/분수 지수, 2번 문항의 함수/극한/분수식, 3번과 4번 문항의 수식이 표시된다.
- `/private/tmp/rhwp-task118-stage4-eq/eq-01-page1-native.png`
  - 두 사각형 안의 긴 평가식, 분수선, 괄호 path, `2x` 항이 표시된다.

검증 상태:

- 두 샘플 모두 `render-debug-compare.sh` 성공
- 두 샘플 모두 summary 파일 존재 확인 통과
- 두 샘플 모두 native PNG에서 수식 표시 확인
- `git diff --check` 통과
- `qlmanage` 기반 core raster/diff는 sandbox 문제로 생성되지 않았지만 Stage 4 필수 실패로 보지 않는다.

## 잔여 위험

- 수식이 표시되지만 CoreText font fallback 차이로 core SVG 또는 한컴 viewer와 글자 폭, baseline, 괄호 곡선 모양이 완전히 같지는 않을 수 있다.
- `path`는 `M/L/H/V/Q/Z` subset 중심이다. cubic curve, arc, SVG transform 등이 포함된 수식은 후속 보강이 필요할 수 있다.
- `qlmanage` rasterize 실패로 pixel diff는 확보하지 못했다. 최종 단계에서도 native PNG와 smoke/build 검증 중심으로 판단한다.
- `origin/devel`이 현재 branch보다 앞서 있어 PR 전 또는 최종 단계에서 최신 `devel`과의 차이를 확인해야 한다.

## 다음 단계 영향

Stage 5에서는 통합 검증과 최종 보고를 진행한다.

- `./scripts/check-no-appkit.sh`
- `./scripts/validate-stage3-render.sh`
- HostApp Debug build
- `exam_math_no.hwp` 최종 render debug 확인
- 최종 보고서 작성과 오늘할일 완료 갱신

## 승인 요청

Stage 4 완료를 승인해 달라. 승인 후 Stage 5 `통합 검증과 최종 보고`로 진행한다.
