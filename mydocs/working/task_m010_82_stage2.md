# Task #82 Stage 2 완료 보고서

## 단계 목적

`validate-stage3-render.sh`와 `render-debug-compare.sh`의 역할 차이, 사용 시점, 산출물 해석을 build/run guide와 렌더 비교 매뉴얼에 보강했다. `table-in-tbox.hwp` core/native 비교 사례를 짧은 실제 활용 예시로 추가했다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/manual/build_run_guide.md` | `validate-stage3-render.sh`의 자동 검사 항목, 출력 위치, custom sample 사용법, smoke test 한계, `render-debug-compare.sh` 사용 시점 추가 |
| `mydocs/manual/render_core_native_compare_guide.md` | 도구 역할 요약, `table-in-tbox` 실제 활용 예시, 최신 summary 수치, smoke test와 debug compare 관계 보강 |

## 본문 변경 정도 / 본문 무손실 여부

기존 절차를 삭제하지 않고 설명을 보강했다. Stage 1에서 이동한 renderer 비교 manual의 기존 본문은 유지했고, 도구 역할 표와 실제 활용 예시를 추가했다. `table-in-tbox` 재현 수치는 현재 `output/render-debug/table-in-tbox-page1-summary.txt` 기준으로 갱신했다.

## 검증 결과

### Stage 2 검색 검증

```bash
rg -n "validate-stage3-render|render-debug-compare|TextRuns|MissingHangulGlyphs|table-in-tbox|core/native" \
  mydocs/manual mydocs/troubleshootings
```

결과 요약:

- `build_run_guide.md`에 render smoke 역할과 core/native 비교 사용 시점이 노출됨.
- `render_core_native_compare_guide.md`에 `TextRuns`, `MissingHangulGlyphs`, `table-in-tbox`, `core/native` 판단 흐름이 노출됨.
- `swift_macos_code_rules_guide.md`의 renderer 변경 규칙 보강은 Stage 3 범위로 남김.

### diff check

```bash
git diff --check
```

결과: 통과.

### 상태 확인

```bash
git status --short --branch
```

결과에는 Stage 2 산출물 외에 #84 관련 미커밋 변경도 함께 보였다.

```text
## local/task82
 M mydocs/manual/build_run_guide.md
 M mydocs/manual/render_core_native_compare_guide.md
 M mydocs/orders/20260429.md
?? mydocs/plans/task_m010_84.md
```

`mydocs/orders/20260429.md`의 #84 행과 `mydocs/plans/task_m010_84.md`는 Task #82 Stage 2 범위가 아니므로 커밋 대상에서 제외한다.

## 잔여 위험

- README/CONTRIBUTING/PR 템플릿은 아직 최신 manual 경로와 새 설명으로 보정되지 않았다. Stage 3에서 처리한다.
- `validate-stage3-render.sh` 자체의 `--help`는 아직 없다. Stage 4에서 script usage 보강으로 처리한다.

## 다음 단계 영향

Stage 3에서는 README, CONTRIBUTING, Swift/macOS 코드 규칙, PR 템플릿, 필요 시 architecture 문서를 보정한다. 특히 외부 기여자 안내와 PR 검증 기록에서 `render-debug-compare.sh` 산출물을 어떻게 남기는지 연결한다.

## 승인 요청

Stage 2 산출물 검토 후 Stage 3 진행 승인을 요청한다.
