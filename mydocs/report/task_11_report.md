# Issue #11 최종 보고서

## 작업 요약

릴리스/배포 상세 절차를 `mydocs/manual/release_distribution_guide.md`로 분리하고, `AGENTS.md`에는 필수 참조 규칙만 남겼다.

## 변경 내용

- `mydocs/manual/release_distribution_guide.md` 추가
- `AGENTS.md`의 릴리스 패키징 상세 설명 제거
- `AGENTS.md`에 릴리스/배포 작업 전 manual 문서 필수 참조 규칙 추가
- Issue #11 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서 추가
- 오늘 할일 문서에 Issue #11 항목 추가

## 검증

- `git diff --check`

## 남은 사항

- 실제 릴리스 전 cask token, zip 파일명, GitHub Release URL, SHA256, 서명/notarization 정책을 확정해야 한다.
