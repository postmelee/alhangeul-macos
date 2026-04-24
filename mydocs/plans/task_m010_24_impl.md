# Issue #24 구현 계획서

## 구현 목표

PR 템플릿과 PR 생성 규격을 저장소 표준으로 정리한다.

- `.github/pull_request_template.md`를 추가한다.
- `mydocs/manual/pr_process_guide.md`에 PR 본문 작성 규칙을 추가한다.
- 실제 `gh pr create` 운영 규칙까지 문서로 연결한다.

## 단계 계획

### 1단계. PR 템플릿 구조 확정 및 추가

- `edwardkim/rhwp` 템플릿을 바탕으로 이 저장소용 섹션을 확정한다.
- `.github/pull_request_template.md`를 추가한다.
- 하이퍼-워터폴 산출물과 연결되는 기본 섹션을 반영한다.

### 2단계. PR 가이드 문서 보강

- `mydocs/manual/pr_process_guide.md`에 내부 task PR 작성 규칙을 추가한다.
- 필수 섹션과 선택 섹션, `Closes #번호` 규칙, 실제 검증만 적는 원칙을 명시한다.
- stage 문서/최종 보고서와 PR 본문 관계를 정리한다.

### 3단계. PR 생성 운영 규칙 정리

- `gh pr create` 시 템플릿 재사용 방법을 문서화한다.
- 가능하면 `--body-file` 사용 예시를 추가해 수동 작성 편차를 줄인다.
- 필요 시 `AGENTS.md` 또는 README의 PR 생성 예시를 최소 범위에서 보정한다.

### 4단계. 검증 및 보고 준비

- 문서 형식과 템플릿 경로를 검증한다.
- 단계별 완료 보고서와 최종 보고서에 반영할 내용을 정리한다.

## 단계별 검증

- 1단계 후:
  - `git diff --check -- .github/pull_request_template.md`

- 2단계 후:
  - `git diff --check -- .github/pull_request_template.md mydocs/manual/pr_process_guide.md`

- 3단계 후:
  - `git diff --check`
  - `gh pr create --help`

- 4단계 후:
  - `git diff --check`

## 보류 기준

다음 조건 중 하나가 발생하면 즉시 다음 단계로 넘어가지 않고 보고 후 승인 대기한다.

1. 템플릿이 지나치게 무거워 작은 PR 작성 비용이 커지는 경우
2. guide 규칙과 현재 `AGENTS.md` 워크플로우가 충돌하는 경우
3. 단일 템플릿으로 task PR과 release PR을 동시에 커버하기 어려운 경우

## 승인 요청 사항

- 이 구현 계획서 기준으로 1단계 구현 진행 승인 요청
