# Issue #11 최종 보고서

## 작업 요약

`AGENTS.md`의 장문 운영 규칙을 manual 문서로 분리하고, `AGENTS.md`에는 강제 가드레일 + 필수 참조만 남기는 구조로 정리했다.

## 변경 내용

- `mydocs/manual/release_distribution_guide.md` 추가
- `mydocs/manual/pr_process_guide.md` 추가
- `mydocs/manual/build_run_guide.md` 추가
- `mydocs/manual/core_submodule_operation_guide.md` 추가
- `mydocs/manual/swift_macos_code_rules_guide.md` 추가
- `AGENTS.md`의 `PR 처리 규칙`, `빌드 및 실행`, `rhwp Core Submodule 운영`, `Swift 및 macOS 코드 규칙`을 강제 규칙 중심으로 축소
- `AGENTS.md`에 각 항목 manual 필수 참조 경로 추가
- `Git 워크플로우`는 `AGENTS.md`에 유지
- `AGENTS.md`의 PR 관련 목차를 `외부 기여자 PR 처리`로 명확화하고, 외부 PR 검토 최소 규칙만 유지
- `mydocs/manual/pr_process_guide.md`를 외부 기여 PR 검토 절차 중심으로 재정리
- Issue #11 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서 추가
- 오늘 할일 문서에 Issue #11 항목 추가

## 검증

- `git diff --check`

## 남은 사항

- 실제 릴리스 전 cask token, zip 파일명, GitHub Release URL, SHA256, 서명/notarization 정책을 확정해야 한다.
