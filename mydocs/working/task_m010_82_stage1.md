# Task #82 Stage 1 완료 보고서

## 단계 목적

렌더링 core/native 비교 문서의 성격을 재판단하고, 상세 절차 문서의 진실 원천 위치를 정리했다. 기존 링크가 즉시 깨지지 않도록 troubleshooting 경로에는 forwarding 문서를 남겼다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/manual/render_core_native_compare_guide.md` | 기존 상세 절차 본문을 manual 문서로 이동. 233줄 |
| `mydocs/troubleshootings/render_core_native_compare.md` | 기존 경로 보호용 안내 문서로 축약. 7줄 |

## 본문 변경 정도 / 본문 무손실 여부

상세 절차 본문은 `mydocs/manual/render_core_native_compare_guide.md`로 이동했다. Stage 1에서는 내용 보강을 하지 않고 위치만 정리했다. 기존 `mydocs/troubleshootings/render_core_native_compare.md` 경로는 과거 PR, 보고서, 외부 링크 보호를 위해 삭제하지 않고 최신 manual 경로를 안내하는 forwarding 문서로 유지했다.

## 검증 결과

### 링크 검색

```bash
rg -n "render_core_native_compare" README.md CONTRIBUTING.md mydocs .github
```

결과 요약:

- 최신 안내 링크 보정 대상: `CONTRIBUTING.md`, `mydocs/manual/build_run_guide.md`
- 기존 작업 기록으로 유지할 항목: Task #65 계획서, 단계 보고서, 최종 보고서의 당시 경로 기록
- 새 forwarding 문서: `mydocs/troubleshootings/render_core_native_compare.md`

### diff check

```bash
git diff --check
```

결과: 통과.

### 상태 확인

```bash
git status --short
```

결과 요약:

```text
 M mydocs/troubleshootings/render_core_native_compare.md
?? mydocs/manual/render_core_native_compare_guide.md
```

### 라인 수 확인

```bash
wc -l mydocs/manual/render_core_native_compare_guide.md mydocs/troubleshootings/render_core_native_compare.md
```

결과:

```text
233 mydocs/manual/render_core_native_compare_guide.md
  7 mydocs/troubleshootings/render_core_native_compare.md
240 total
```

## 잔여 위험

- `CONTRIBUTING.md`와 `build_run_guide.md`는 아직 troubleshooting 경로를 직접 참조한다. Stage 2~3에서 최신 manual 경로로 보정한다.
- Task #65 문서들은 당시 산출물 기록이므로 경로를 바꾸지 않는다. 대신 forwarding 문서가 과거 링크의 도착점 역할을 한다.

## 다음 단계 영향

Stage 2에서는 `mydocs/manual/build_run_guide.md`와 새 manual 문서를 기준으로 `validate-stage3-render.sh`와 `render-debug-compare.sh`의 역할, 사용 시점, 실제 예시를 보강한다.

## 승인 요청

Stage 1 산출물 검토 후 Stage 2 진행 승인을 요청한다.
