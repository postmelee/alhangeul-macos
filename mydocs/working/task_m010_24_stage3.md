# Issue #24 단계 3 완료 보고서

## 작업 내용

- `gh pr create`에서 PR 템플릿을 재사용하는 운영 규칙을 문서화했다.
- `--template`과 `--body-file`의 사용 기준을 구분했다.
- `AGENTS.md`와 `README.md`의 PR 생성 예시를 새 템플릿 규칙에 맞게 최소 보정했다.

## 변경 파일

- `mydocs/manual/pr_process_guide.md`
- `AGENTS.md`
- `README.md`
- `mydocs/orders/20260423.md`

## 정리한 운영 기준

### 1. `--template` 사용 기준

초안 PR을 빠르게 만들 때는 아래 형식을 사용한다.

```bash
gh pr create \
  --base devel \
  --head publish/task24 \
  --draft \
  --title "Task #24: PR 템플릿과 PR 생성 규격 표준화" \
  --template .github/pull_request_template.md
```

이 방식은 `.github/pull_request_template.md`를 시작 본문으로 사용한다.

### 2. `--body-file` 사용 기준

최종 보고서와 단계 보고서를 바탕으로 PR 본문을 미리 완성한 경우에는 아래 형식을 사용한다.

```bash
gh pr create \
  --base devel \
  --head publish/task24 \
  --draft \
  --title "Task #24: PR 템플릿과 PR 생성 규격 표준화" \
  --body-file /tmp/task24-pr-body.md
```

### 3. 기본적으로 피할 방식

- `--fill`: 커밋 메시지만으로 본문을 만들기 때문에 이 저장소의 stage/보고서 흐름을 반영하기 어렵다.
- 긴 `--body`: 재사용과 검토가 어렵다.

## AGENTS/README 보정

- `AGENTS.md`의 메인테이너 워크플로우 예시에서 `gh pr create` 명령에 `--template .github/pull_request_template.md`를 추가했다.
- `README.md`의 타스크 진행 절차에 draft PR 생성 시 `.github/pull_request_template.md` 기준으로 작성한다는 문구를 추가했다.

## 검증

- `gh pr create --help`
- `git diff --check -- .github/pull_request_template.md mydocs/manual/pr_process_guide.md AGENTS.md README.md mydocs/orders/20260423.md mydocs/working/task_m010_24_stage3.md`

## 다음 단계

- 4단계에서 전체 문서 형식과 템플릿 경로를 검증한다.
- 최종 보고서 작성 전 미정리 항목이 없는지 확인한다.

## 승인 요청 사항

- 이 단계 완료 기준으로 4단계 진행 승인 요청
