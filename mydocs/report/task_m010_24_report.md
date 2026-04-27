# Issue #24 최종 보고서

## 개요

Issue #24는 `edwardkim/rhwp`의 PR 템플릿과 실제 PR 본문 사례를 참고해, 이 저장소의 PR 본문 형식을 규격화하는 작업이다.

이번 작업은 템플릿 파일만 가져오는 방식이 아니라, 이 저장소의 하이퍼-워터폴 산출물과 연결되는 PR 작성 규칙까지 함께 정리하는 방향으로 진행했다.

## 주요 변경

### 1. PR 템플릿 추가

- `.github/pull_request_template.md`를 추가했다.
- 기본 섹션은 다음과 같다.
  - `요약`
  - `변경 내역`
  - `검증`
  - `문서`
  - `관련 이슈`
  - `남은 리스크`
  - `스크린샷`

템플릿은 `edwardkim/rhwp`의 단순한 기본 구조를 참고하되, 이 저장소의 stage 문서와 최종 보고서 흐름을 반영하도록 확장했다.

### 2. PR 처리 가이드 보강

- `mydocs/manual/pr_process_guide.md`를 `PR 처리 가이드`로 보강했다.
- 내부 task PR 생성 규칙과 외부 기여 PR 검토 절차를 같은 문서 안에서 분리해 설명했다.
- 내부 task PR 본문은 `.github/pull_request_template.md`를 따르도록 명시했다.
- PR 본문은 최종 결과 보고서의 압축본으로 작성한다는 원칙을 추가했다.

### 3. 섹션별 작성 기준 정리

가이드에 다음 기준을 추가했다.

- `요약`: 최종 결과 보고서의 결론을 2~5개 bullet로 압축
- `변경 내역`: stage 기반 작업은 stage 기준으로 작성
- `검증`: 실제 실행한 명령만 체크
- `문서`: 계획서, 단계 보고서, 최종 보고서, troubleshooting 문서 참조
- `관련 이슈`: `Closes`, `Related`, `Refs` 사용 기준 구분
- `남은 리스크`: 검증 한계와 후속 task 후보 기록

### 4. PR 생성 명령 운영 규칙 추가

`gh pr create` 사용 기준을 문서화했다.

- 초안 PR을 빠르게 만들 때:
  - `--template .github/pull_request_template.md`
- 최종 보고서 기반으로 본문을 확정했을 때:
  - `--body-file <작성한 PR 본문 파일>`
- 기본적으로 피할 방식:
  - `--fill`
  - 긴 `--body`

### 5. AGENTS/README 예시 보정

- `AGENTS.md`의 메인테이너 워크플로우 예시에서 `gh pr create` 명령에 `--template .github/pull_request_template.md`를 추가했다.
- `README.md`의 타스크 진행 절차에 draft PR 생성 시 `.github/pull_request_template.md` 기준으로 작성한다는 문구를 추가했다.

## 산출물

- `.github/pull_request_template.md`
- `mydocs/manual/pr_process_guide.md`
- `AGENTS.md`
- `README.md`
- `mydocs/orders/20260423.md`
- `mydocs/plans/task_m010_24.md`
- `mydocs/plans/task_m010_24_impl.md`
- `mydocs/working/task_m010_24_stage1.md`
- `mydocs/working/task_m010_24_stage2.md`
- `mydocs/working/task_m010_24_stage3.md`
- `mydocs/working/task_m010_24_stage4.md`
- `mydocs/report/task_m010_24_report.md`

## 검증 결과

### 1. 문서 형식 검증

- `git diff --check`
  - 결과: 형식 오류 없음

### 2. `gh pr create` 옵션 확인

- `gh pr create --help`
  - `--template file`
  - `--body-file file`
  - `--draft`
  - `--base`
  - `--head`
  - `--title`

문서화한 PR 생성 방식과 실제 GitHub CLI 옵션이 일치함을 확인했다.

## 최종 판단

이번 작업으로 다음 task부터 PR 본문을 일관된 형식으로 작성할 수 있게 됐다.

1. GitHub UI에서는 `.github/pull_request_template.md`가 기본 본문으로 노출된다.
2. CLI에서는 `gh pr create --template .github/pull_request_template.md`로 같은 템플릿을 사용할 수 있다.
3. 최종 보고서 기반으로 본문을 미리 완성한 경우에는 `--body-file`을 사용할 수 있다.
4. PR 본문은 최종 결과 보고서의 압축본이라는 기준이 문서화됐다.

## 남은 리스크와 후속 권장 사항

### 1. 단일 템플릿 한계

현재는 task PR 기준 단일 템플릿만 추가했다.

release PR이나 hotfix PR의 요구사항이 커지면 `.github/PULL_REQUEST_TEMPLATE/` 아래에 다중 템플릿을 추가하는 후속 작업이 필요할 수 있다.

### 2. 자동 생성 스크립트는 미도입

이번 작업에서는 `scripts/make-pr-body.sh` 같은 자동 생성 스크립트는 만들지 않았다.

몇 개 task에서 새 규칙을 실제로 사용해 본 뒤, 반복 패턴이 안정되면 최종 보고서와 stage 문서를 읽어 PR 본문 초안을 만드는 스크립트를 별도 task로 도입하는 것이 적절하다.

## 결론

- `rhwp`의 템플릿을 그대로 복사하지 않고, 이 저장소의 하이퍼-워터폴 절차에 맞는 PR 템플릿과 작성 규칙으로 확장했다.
- 내부 task PR 본문 작성, 검증 기록, 문서 참조, issue 연결 방식이 표준화됐다.
- 다음 작업부터는 PR 생성 시 새 템플릿과 가이드 기준을 적용할 수 있다.
