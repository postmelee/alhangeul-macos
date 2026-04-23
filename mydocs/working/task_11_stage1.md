# Issue #11 단계 1 완료 보고서

## 수행 내용

- `mydocs/manual/release_distribution_guide.md`를 추가했다.
- `AGENTS.md`의 릴리스 패키징 상세 설명을 제거하고, manual 문서 필수 참조 규칙만 남겼다.
- 검증 기준의 릴리스/배포 항목도 manual 참조 방식으로 변경했다.

## 판단

릴리스/배포는 저장소 소유자 권한, 서명, 공증, GitHub Release, Homebrew Cask 정책이 필요한 작업이다. 공개 README에는 포함하지 않고, Codex/Claude가 필요할 때만 읽는 manual 문서로 분리하는 것이 적절하다.

## 결과

`AGENTS.md`의 전체 크기를 늘리지 않으면서 릴리스/배포 작업 전 반드시 참조할 문서 경로를 명시했다.
