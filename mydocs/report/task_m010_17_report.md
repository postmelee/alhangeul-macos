# Issue #17 최종 보고서

## 개요

Issue #17은 `AGENTS.md`의 Git 워크플로우를 `devel` 대상 PR 기반으로 개편하고, 그에 따라 `README.md`의 워크플로우 요약도 정합화하는 작업이다.

- 기존 `local/task -> local/devel -> devel` 흐름을 `local/task -> publish/task -> devel PR -> devel` 흐름으로 변경했다.
- PR 생성용 원격 브랜치 규칙을 `publish/task{issue번호}`로 정리했다.
- draft PR 기본값과 merge 전략 원칙을 `AGENTS.md`에 반영했다.
- 커밋 메시지 규칙을 `기본형 + Stage형`으로 명시했다.
- `README.md`의 요약 워크플로우와 절차 설명도 새 규칙에 맞췄다.

## 주요 변경

### 1. `AGENTS.md` 워크플로우 개편

- 브랜치 관리 표에서 `local/devel` 항목을 제거했다.
- `publish/task{num}`를 `devel` 대상 PR 생성용 원격 게시 브랜치로 추가했다.
- Git 워크플로우 흐름도를 `local/task -> publish/task push -> devel 대상 PR -> devel 누적 -> main PR` 구조로 수정했다.
- 메인테이너 워크플로우 예시를 `publish/task{N}` push 및 `devel` 대상 draft PR 생성 흐름으로 교체했다.
- `devel` 대상 PR의 draft 기본값, merge commit 유지/`--no-ff` 중심 merge 전략을 명시했다.
- 커밋 메시지 규칙에 `Task #{issue번호}: 내용`, `Task #{issue번호} Stage {N}: 내용`, `Task #{issue번호} [Stage {N.M}]: 내용` 형식을 추가했다.

### 2. 단점 대응 전략 반영

- 브랜치 수 증가 대응:
  - `local/task{N}` / `publish/task{N}` 두 패턴으로 고정
  - PR merge 후 `publish/task{N}` 삭제
- 소규모 작업 속도 저하 대응:
  - 예외 처리 대상은 경량 절차 허용
  - 문서 전용 작업은 draft PR 기본값 유지
- 관리 포인트 증가 대응:
  - 절차를 `Issue -> local/task -> publish/task -> devel PR -> merge`로 단순화
- 1인 저장소 운영 부담 대응:
  - PR 본문을 self-review 기록으로 활용
- `devel` 히스토리 복잡화 대응:
  - squash merge를 기본값으로 두지 않음

### 3. `README.md` 정합화

- Git 워크플로우 요약에 `publish/task{N}` push와 `devel draft PR + merge`를 반영했다.
- 브랜치 표에 `publish/task{N}`를 추가했다.
- 타스크 관리 항목에 PR 생성용 원격 브랜치명을 추가했다.
- 커밋 메시지 예시를 `기본형 + Stage형` 기준으로 정리했다.
- 타스크 진행 절차에 `publish/task` push 및 `devel` 대상 draft PR 생성 단계를 반영했다.

## 산출물

- `AGENTS.md`
- `README.md`
- `mydocs/orders/20260423.md`
- `mydocs/plans/task_m010_17.md`
- `mydocs/plans/task_m010_17_impl.md`
- `mydocs/working/task_m010_17_stage1.md`
- `mydocs/working/task_m010_17_stage2.md`
- `mydocs/working/task_m010_17_stage3.md`
- `mydocs/working/task_m010_17_stage4.md`
- `mydocs/report/task_m010_17_report.md`

## 검증 결과

- 아래 명령으로 전체 문서 형식 검증을 실행했다.

`git diff --check -- AGENTS.md README.md mydocs/orders/20260423.md mydocs/plans/task_m010_17.md mydocs/plans/task_m010_17_impl.md mydocs/working/task_m010_17_stage1.md mydocs/working/task_m010_17_stage2.md mydocs/working/task_m010_17_stage3.md mydocs/working/task_m010_17_stage4.md mydocs/report/task_m010_17_report.md`

- 형식 오류는 확인되지 않았다.

## 미실시 항목

- 실제 `publish/task` 브랜치 운영을 저장소 전반에 적용하는 후속 작업은 수행하지 않았다.
- 코드, 빌드, 배포 설정 변경은 이번 타스크 범위에 포함하지 않았다.

## 결론

- `AGENTS.md`와 `README.md`가 같은 Git 워크플로우를 설명하도록 정렬됐다.
- 이후 작업부터는 `devel` 대상 PR 기반 운영 규칙을 기준으로 문서와 절차를 적용할 수 있는 상태가 됐다.
