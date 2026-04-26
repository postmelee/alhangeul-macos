# Task M020 #65 Stage 4 완료보고서

## 단계 목표

Stage 2~3에서 만든 core/native 렌더 비교 도구의 사용 절차, 산출물 해석, 문제 분리 기준을 문서화한다.

## 변경 내용

### 1. troubleshooting 문서 추가

`mydocs/troubleshootings/render_core_native_compare.md`를 추가했다.

문서에 포함한 내용:

- 이 절차의 목적과 한컴 viewer 비교와의 경계
- core SVG, native PNG, render tree JSON 기준 경로
- `./scripts/render-debug-compare.sh` 기본 사용법
- 페이지 지정 방법
- 필수/선택 산출물 파일명 규칙
- summary 주요 필드 해석
- renderer 차이 판단 흐름
- `qlmanage` 실패 시 fallback 해석
- 기존 `validate-stage3-render.sh` smoke test와의 관계
- `table-in-tbox.hwp` 기준 재현 기록 예시

### 2. README 디버깅 진입점 보강

`README.md`의 Render Smoke Test 섹션에 특정 파일 비교 명령을 추가했다.

```bash
./scripts/render-debug-compare.sh output/render-debug path/to/sample.hwp
```

README의 디버깅 프로토콜에도 `render-debug-compare.sh`를 추가해 render tree JSON, core SVG, native PNG, pixel diff 산출 경로를 찾을 수 있게 했다.

### 3. build/run guide 연결

`mydocs/manual/build_run_guide.md`에 `core/native 렌더 비교 디버깅` 섹션을 추가했다.

이 섹션은 명령과 산출물 종류만 짧게 안내하고, 상세 절차는 troubleshooting 문서로 연결한다.

## 검증

### 키워드 검색

```bash
rg -n "render-debug-compare|render tree JSON|core SVG|native PNG|pixel diff|table-in-tbox" \
  README.md \
  mydocs/manual/build_run_guide.md \
  mydocs/troubleshootings/render_core_native_compare.md
```

결과:

- README Render Smoke Test 섹션에서 `render-debug-compare.sh` 명령 확인
- README 디버깅 프로토콜에서 `render-debug-compare.sh` 확인
- build/run guide에서 core/native 렌더 비교 디버깅 섹션 확인
- troubleshooting 문서에서 산출물, 판단 흐름, `table-in-tbox.hwp` 재현 기록 확인

### 문서 diff 검사

```bash
git diff --check -- \
  README.md \
  mydocs/manual/build_run_guide.md \
  mydocs/troubleshootings/render_core_native_compare.md
```

결과: 통과.

## 판단

- 새 디버깅 절차를 문서만 보고 재현할 수 있게 정리했다.
- 상세 내용은 troubleshooting 문서에 두고 README와 build/run guide는 진입점 역할로 제한했다.
- core SVG가 제품 fallback이 아니라 진단 산출물이라는 경계를 명시했다.
- 한컴 viewer 비교는 이번 자동화 범위 밖이며, 우선 rhwp core와 native renderer 정합성을 맞추는 기준을 명확히 했다.

## 변경 파일

- `README.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/troubleshootings/render_core_native_compare.md`
- `mydocs/working/task_m020_65_stage4.md`

## 승인 요청

Stage 4 완료를 승인하면 Stage 5 통합 검증과 회귀 확인으로 진행한다.
