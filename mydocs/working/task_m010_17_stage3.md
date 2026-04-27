# Issue #17 단계 3 완료 보고서

## 작업 내용

- `AGENTS.md`의 브랜치 관리 표에서 `local/devel` 항목을 제거하고 `publish/task{num}` 원격 브랜치를 추가했다.
- Git 워크플로우 흐름도를 `local/task -> publish/task push -> devel 대상 PR -> devel 누적 -> main PR` 구조로 수정했다.
- 핵심 설명 문장을 `devel` 대상 draft PR, merge 전략, 원격 게시 브랜치 규칙 기준으로 다시 정리했다.
- 메인테이너 워크플로우 예시를 `publish/task{N}` push 및 `devel` 대상 PR 생성 흐름으로 교체했다.
- 컨트리뷰터 예시와 이슈 생성 예시도 현재 저장소 기준으로 정리했다.

## 변경 결과

- `AGENTS.md`가 더 이상 `local/devel` 중심 로컬 merge 워크플로우를 기본으로 두지 않게 됐다.
- 메인테이너와 컨트리뷰터 모두 `devel` 대상 PR을 거친다는 상위 원칙으로 정렬됐다.
- `publish/task{issue번호}` 명명 규칙과 draft PR 기본값, merge 전략 고정 원칙을 명시했다.

## 검증

- `git diff --check -- AGENTS.md`

## 다음 단계

- 전체 문서 변경 범위 검증을 실행하고 단계별 완료 보고 및 최종 보고 준비를 진행한다.
