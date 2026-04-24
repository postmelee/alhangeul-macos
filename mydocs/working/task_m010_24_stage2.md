# Issue #24 단계 2 완료 보고서

## 작업 내용

- `mydocs/manual/pr_process_guide.md`에 내부 task PR 작성 규칙을 추가했다.
- 기존 외부 기여자 PR 검토 절차와 내부 task PR 생성 규칙을 분리했다.
- `.github/pull_request_template.md`의 섹션과 같은 용어를 사용하도록 가이드 문서를 맞췄다.

## 변경 파일

- `mydocs/manual/pr_process_guide.md`
- `mydocs/orders/20260423.md`

## 추가한 규칙

### 1. 내부 task PR 필수 섹션

내부 task PR에는 다음 섹션을 두도록 명시했다.

- `요약`
- `변경 내역`
- `검증`
- `문서`
- `관련 이슈`
- `남은 리스크`

`스크린샷`은 UI, Finder, Quick Look, Thumbnail처럼 시각 확인이 필요한 변경에서만 유지하도록 했다.

### 2. 섹션별 작성 기준

각 섹션에 다음 기준을 추가했다.

- `요약`: 최종 결과 보고서의 결론을 2~5개 bullet로 압축
- `변경 내역`: stage 기반 작업은 stage 기준으로 작성
- `검증`: 실제 실행한 명령만 체크
- `문서`: 계획서, 단계 보고서, 최종 보고서, troubleshooting 문서 참조
- `관련 이슈`: `Closes`, `Related`, `Refs` 사용 기준 구분
- `남은 리스크`: 검증 한계와 후속 task 후보 기록

### 3. 최종 보고서와 PR 본문 관계

최종 보고서는 장기 보관 문서이고, PR 본문은 리뷰 화면에서 빠르게 읽는 요약본이라는 기준을 추가했다.

즉, PR 본문은 새로 쓰는 별도 보고서가 아니라 최종 결과 보고서의 압축본으로 작성한다.

### 4. 작성 예시

`task #22` 유형의 stage 기반 PR을 예시로 넣어 다음 항목을 보여줬다.

- stage별 변경 내역
- 검증 체크리스트
- 문서 참조
- `Closes #번호`
- 남은 리스크 기록 방식

## 검증

- `git diff --check -- .github/pull_request_template.md mydocs/manual/pr_process_guide.md mydocs/orders/20260423.md mydocs/working/task_m010_24_stage2.md`

## 다음 단계

- 3단계에서 `gh pr create` 시 템플릿 재사용 방법과 body-file 기반 운영 규칙을 정리한다.
- 필요하면 `AGENTS.md` 또는 README의 PR 생성 예시를 최소 범위에서 보정한다.

## 승인 요청 사항

- 이 단계 완료 기준으로 3단계 진행 승인 요청
