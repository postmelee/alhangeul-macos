# Issue #17 단계 2 완료 보고서

## 작업 내용

- `AGENTS.md`에서 `devel` 대상 PR 기반 워크플로우로 바꿔야 할 구간을 식별했다.
- 교체 대상 구간을 브랜치 표, 흐름도, 설명 문장, 메인테이너 예시 명령, 컨트리뷰터 예시와 구분해 정리했다.
- 다음 단계에서 실제 문안 반영 시 어디를 어떻게 바꿔야 하는지 기준을 확정했다.

## 식별한 교체 대상

### 1. 브랜치 관리 표

현재 문제 구간:

- `local/devel` 항목이 로컬 통합 브랜치로 정의되어 있다.

변경 방향:

- `local/devel` 항목은 제거하거나 축소한다.
- 대신 `publish/task{num}`를 PR 생성용 원격 브랜치로 추가한다.

### 2. Git 워크플로우 흐름도

현재 문제 구간:

- `local/task -> local/devel merge -> devel merge (로컬) + push -> main PR` 흐름으로 되어 있다.

변경 방향:

- `local/task -> publish/task push -> devel 대상 PR -> devel 누적 -> main PR` 흐름으로 바꾼다.

### 3. 핵심 설명 문장

현재 문제 구간:

- `local/devel 작업`
- `원격 push: devel만 push`

변경 방향:

- `local/task`는 로컬 작업 브랜치, `publish/task`는 원격 게시 브랜치로 역할을 분리한다.
- 원격에는 PR 생성용 `publish/task{N}` 브랜치를 push하고, `devel` 반영은 PR merge로 이뤄지도록 문장을 바꾼다.
- 문서 전용 작업과 1인 운영 상황을 고려해 draft PR 기본값을 운영 원칙으로 넣는다.

### 4. 메인테이너 워크플로우 예시

현재 문제 구간:

- `local/devel -> devel` 로컬 merge + push 예시

변경 방향:

- `publish/task{N}` push
- `devel` 대상 draft PR 생성
- 리뷰 후 merge
- 릴리즈 시 `devel -> main` PR 생성

즉, 메인테이너 예시는 작업 단위 PR 생성 흐름과 릴리즈 PR 흐름을 분리해서 다시 써야 한다.

### 5. 컨트리뷰터 워크플로우와의 관계

현재 상태:

- 컨트리뷰터 워크플로우는 fork 기반 `devel` 대상 PR 흐름이라 새 방향과 크게 충돌하지 않는다.

변경 방향:

- 메인테이너 로컬 작업도 `devel` 대상 PR을 만든다는 점만 추가로 정렬하면 된다.
- 즉, 메인테이너/컨트리뷰터가 모두 `devel` 대상 PR을 거친다는 상위 원칙으로 맞출 수 있다.

## 반영 기준

- `AGENTS.md`에는 장황한 배경 설명 대신, 실제 운영에 필요한 문구만 넣는다.
- 다음 단계에서 직접 반영할 핵심 항목은 아래와 같다.
  - `publish/task{N}` 브랜치 추가
  - `local/devel` 흐름 제거
  - `devel` 대상 PR 생성 규칙 명시
  - draft PR 기본값 명시
  - merge 전략 고정 원칙 명시

## 검증

- `git diff --check -- mydocs/orders/20260423.md mydocs/plans/task_m010_17.md mydocs/plans/task_m010_17_impl.md mydocs/working/task_m010_17_stage1.md mydocs/working/task_m010_17_stage2.md`

## 다음 단계

- 식별한 구간을 기준으로 `AGENTS.md`의 실제 문안을 `devel` 대상 PR 기반 워크플로우로 수정한다.
