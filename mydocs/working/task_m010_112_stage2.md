# Task #112 Stage 2 완료 보고서

## 단계 목적

`.github/pull_request_template.md`를 새 PR 본문 구조로 축약 개편했다. 기존 내용을 단순 추가하지 않고, `문서` 최상위 섹션과 기본 `Closes #` placeholder, 미실행 검증 체크리스트를 제거하면서 Stage 1에서 확정한 기준을 템플릿에 반영했다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `.github/pull_request_template.md` | 질문형 요약 프롬프트, Stage 보고서 링크+커밋 링크 예시, `변경 내역` 안의 작업 문서 링크, 핵심 리뷰 포인트, 조건부 Before/After, 관련 이슈/후속 이슈/리스크 섹션 반영 |

라인 수:

- 변경 전: 73줄
- 변경 후: 77줄
- diff stat: 49 insertions, 45 deletions

## 주요 변경

### 요약

기존 설명형 주석을 질문형 프롬프트로 바꿨다.

- 대상 타스크는 무엇인가요?
- 왜 변경했나요?
- 무엇을 변경했나요?
- 리뷰어가 먼저 볼 지점은 무엇인가요?

작성 부담을 줄이기 위해 본문 기본값은 4개 bullet만 남겼다.

### 변경 내역

`문서` 최상위 섹션을 제거하고 `변경 내역` 안에 다음을 배치했다.

- Stage별 요약
- 주요 파일/영역 표
- 작업 문서 링크

Stage별 요약은 아래 형식을 템플릿에 직접 넣었다.

```md
- **[Stage 1](stage-url)** ([0cdbae0](commit-url)):
```

`Stage 1`은 단계 보고서 링크, `0cdbae0`은 해당 Stage 커밋 링크로 사용한다.

### 검증

기본 미체크 체크리스트를 제거했다. 대신 "어떻게 검증했나요?" 질문과 "실제 실행한 명령과 수동 확인만 남긴다"는 기준만 유지했다.

조건부 검증 기대치는 Stage 3에서 `pr_process_guide.md`와 `.github/copilot-instructions.md`에 남긴다.

### 스크린샷

시각적 변경사항이 있을 때만 `스크린샷` 섹션을 유지하도록 주석을 바꿨고, Before/After 표를 추가했다.

실제 이미지나 산출물 없이 형식만 채우는 방식은 주석에서 금지했다.

### 관련 이슈

`Closes #` placeholder를 제거했다. `관련 이슈`는 현재 PR의 대상 타스크가 아니라 선행, 후속, Epic, upstream, 참고 issue/PR을 적는 섹션으로 설명했다.

직접 수행 issue는 `요약`의 `대상 타스크`에 적는다.

## 검증 결과

### 새 구조 키워드 확인

```bash
rg -n "대상 타스크|왜 변경했나요|무엇을 변경했나요|핵심 리뷰 포인트|후속 이슈 제안|Before|After|head_sha|commit-url|stage-url" \
  .github/pull_request_template.md
```

결과: 통과. 질문형 프롬프트, Stage 링크 placeholder, 작업 문서 head SHA placeholder, Before/After 표, 후속 이슈 섹션이 모두 확인됐다.

### 제거 대상 확인

```bash
rg -n "## 문서|Closes #" .github/pull_request_template.md
```

결과: 출력 없음. `rg` exit code는 1이며, 이번 검증에서는 제거 대상 문자열이 없다는 의미로 기대 결과다.

### 문서 형식 확인

```bash
git diff --check -- \
  .github/pull_request_template.md \
  mydocs/working/task_m010_112_stage2.md
```

결과: 통과.

## 잔여 위험

- `핵심 리뷰 포인트`, `스크린샷`, `후속 이슈 제안`은 조건부 섹션이므로 작성자가 삭제하지 않고 빈 상태로 남길 수 있다. Stage 3에서 PR 처리 가이드와 `task-final-report`에 조건부 섹션 정리 기준을 보강한다.
- 단계 보고서 링크와 커밋 링크는 URL 종류가 다르다. Stage 3에서 `task-final-report` 검증 기준에 두 링크 유형을 분리해 넣어야 한다.
- 템플릿의 Xcode/Rust/renderer 검증 기본 체크리스트를 제거했으므로, 조건부 검증 기대치는 가이드와 review 지시에 남겨야 한다.

## 다음 단계 영향

Stage 3에서는 `pr_process_guide.md`와 `task-final-report`를 새 템플릿 구조에 맞춘다.

- `문서` 섹션 기준을 `변경 내역 > 작업 문서` 기준으로 변경
- `관련 이슈`를 맥락 이슈로 재정의
- `--body-file` 우선 사용과 Stage 보고서 링크+커밋 링크 검증 기준 반영
- 필요 시 `git_workflow_guide.md`, `.github/copilot-instructions.md` 최소 보정

## 승인 요청

이 Stage 2 결과 기준으로 Stage 3: PR 처리 가이드와 `task-final-report` 절차 보정을 진행할지 승인 요청한다.
