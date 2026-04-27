# Issue #24 단계 4 완료 보고서

## 작업 내용

- PR 템플릿과 PR 생성 규격 변경 전체를 검증했다.
- `gh pr create` 옵션과 문서화한 운영 규칙이 일치하는지 확인했다.
- 최종 보고서 작성에 필요한 변경 요약과 검증 결과를 정리했다.

## 검증 결과

### 1. 전체 패치 형식 검증

실행 명령:

- `git diff --check`

결과:

- 형식 오류 없음

### 2. 템플릿/문서 경로 확인

확인한 산출물:

- `.github/pull_request_template.md`
- `mydocs/plans/task_m010_24.md`
- `mydocs/plans/task_m010_24_impl.md`
- `mydocs/working/task_m010_24_stage1.md`
- `mydocs/working/task_m010_24_stage2.md`
- `mydocs/working/task_m010_24_stage3.md`

### 3. `gh pr create` 옵션 확인

실행 명령:

- `gh pr create --help`

확인한 옵션:

- `--template file`: PR 본문 시작 템플릿 지정
- `--body-file file`: 완성된 PR 본문 파일 지정
- `--draft`: draft PR 생성
- `--base`, `--head`, `--title`: 기존 workflow와 동일하게 사용

문서화한 운영 기준과 실제 CLI 옵션이 일치함을 확인했다.

## 최종 보고서에 반영할 요약

이번 task는 `edwardkim/rhwp`의 PR 템플릿과 실제 PR 본문 사례를 참고하되, 그대로 복사하지 않고 이 저장소의 하이퍼-워터폴 흐름에 맞게 확장했다.

주요 변경은 다음과 같다.

1. `.github/pull_request_template.md` 추가
2. `mydocs/manual/pr_process_guide.md`에 내부 task PR 작성 규칙 추가
3. `gh pr create --template` / `--body-file` 운영 기준 문서화
4. `AGENTS.md`와 `README.md`의 PR 생성 예시 보정

## 판단

- PR 템플릿은 다음 task부터 GitHub UI와 `gh pr create --template`에서 재사용할 수 있다.
- 최종 보고서 기반으로 본문을 확정한 경우에는 `--body-file`을 사용할 수 있다.
- 외부 기여 PR 검토 절차와 내부 task PR 생성 규칙은 같은 문서 안에서 분리되어 설명된다.

## 다음 단계

- `mydocs/report/task_m010_24_report.md` 최종 결과 보고서 작성

## 승인 요청 사항

- 이 단계 완료 기준으로 최종 결과 보고서 작성 진행 승인 요청
