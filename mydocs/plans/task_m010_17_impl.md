# Issue #17 구현 계획서

## 구현 목표

`AGENTS.md`의 Git 워크플로우를 `devel` 대상 PR 기반 흐름으로 바꾸기 위한 실제 문서 수정 단계를 정의한다.

- 기존 `local/devel` 중심 설명을 `publish/task{N}` 기반 설명으로 대체한다.
- 원격 브랜치 명명 규칙을 `publish/task{issue번호}`로 명시한다.
- 변경에 따른 단점과 대응 전략을 문서 안에서 이해할 수 있게 정리한다.

## 단계 계획

### 1단계. 단점 대응 전략 우선 확정

- 수행 계획서에서 정리한 단점과 대응 전략을 실제 운영 규칙 수준으로 다시 점검한다.
- 어떤 대응 전략을 `AGENTS.md` 본문에 직접 넣고, 어떤 내용은 간단한 운영 원칙으로 축약할지 정한다.
- `devel` 대상 PR 전환으로 생길 운영 부담을 먼저 통제한 뒤 문안 수정 기준을 고정한다.

### 2단계. 기존 워크플로우 문구 정리

- `AGENTS.md`에서 `local/devel` 중심 흐름, `devel` 직접 push 중심 설명, 메인테이너 워크플로우 예시를 확인한다.
- 실제로 바꿔야 할 구간을 흐름도, 브랜치 표, 설명 문장, 예시 명령 단위로 식별한다.
- 필요한 경우 오늘 할 일 문서에 현재 진행 상태를 반영한다.

### 3단계. `devel` 대상 PR 기반 문안 반영

- 흐름도를 `local/task -> publish/task -> devel PR -> devel -> main PR` 구조로 바꾼다.
- 브랜치 역할 표와 Git 워크플로우 설명을 새 방식에 맞게 정리한다.
- 원격 PR 브랜치 이름 추천과 운영 규칙을 문서에 반영한다.
- 단점 완화용 운영 규칙을 `AGENTS.md`에 자연스럽게 녹인다.

### 4단계. 검증 및 완료 보고 준비

- 변경된 `AGENTS.md`, `README.md`, 오늘 할 일 문서, 계획 문서의 형식 오류 여부를 확인한다.
- 단계별 완료 보고서와 최종 보고서에 들어갈 검증 결과와 변경 요약을 정리한다.

## 단계별 검증

- 1단계 후: `git diff --check -- mydocs/plans/task_m010_17.md mydocs/plans/task_m010_17_impl.md`
- 2단계 후: `git diff --check -- mydocs/orders/20260423.md mydocs/plans/task_m010_17.md mydocs/plans/task_m010_17_impl.md`
- 3단계 후: `git diff --check -- AGENTS.md`
- 4단계 후: `git diff --check -- AGENTS.md README.md mydocs/orders/20260423.md mydocs/plans/task_m010_17.md mydocs/plans/task_m010_17_impl.md`

## 승인 요청 사항

- 이 구현 계획서 기준으로 1단계 진행 승인 요청
