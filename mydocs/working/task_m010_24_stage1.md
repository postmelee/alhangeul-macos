# Issue #24 단계 1 완료 보고서

## 작업 내용

- GitHub 기본 PR 템플릿 파일을 추가했다.
- `edwardkim/rhwp`의 얇은 기본 템플릿을 참고하되, 이 저장소의 하이퍼-워터폴 산출물과 연결되도록 필수 섹션을 확장했다.

## 추가 파일

- `.github/pull_request_template.md`

## 템플릿 구성

추가한 PR 템플릿은 다음 섹션으로 구성된다.

- `요약`
- `변경 내역`
- `검증`
- `문서`
- `관련 이슈`
- `남은 리스크`
- `스크린샷`

## 설계 판단

단순히 `rhwp` 저장소의 템플릿을 그대로 복사하지 않고, 현재 저장소의 작업 흐름에 맞춰 다음 원칙을 반영했다.

1. PR 본문은 최종 보고서의 압축본으로 작성한다.
2. stage 기반 작업은 `변경 내역`을 stage 기준으로 적을 수 있게 한다.
3. 검증 항목은 실제 실행 여부를 체크리스트로 남긴다.
4. 계획서, 단계 보고서, 최종 보고서, troubleshooting 문서를 PR 본문에서 직접 참조할 수 있게 한다.
5. issue 자동 종료 여부를 `Closes #번호`, `Related #번호`, `Refs #번호` 중 선택하도록 안내한다.

## 검증

- `git diff --check -- .github/pull_request_template.md mydocs/orders/20260423.md mydocs/working/task_m010_24_stage1.md`

## 다음 단계

- 2단계에서 `mydocs/manual/pr_process_guide.md`에 내부 task PR 작성 규칙을 추가한다.
- 필수 섹션과 선택 섹션, 최종 보고서와 PR 본문 관계, `Closes #번호` 사용 규칙을 문서화한다.

## 승인 요청 사항

- 이 단계 완료 기준으로 2단계 진행 승인 요청
