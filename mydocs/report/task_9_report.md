# Issue #9 최종 보고서

## 작업 요약

`README.md`를 `alhangeul-macos`의 현재 구현 상태와 장기 로드맵 기준으로 상세 재작성했다.

## 변경 내용

- 프로젝트 소개를 macOS Quick Look, Thumbnail, HostApp viewer 중심으로 재작성했다.
- 현재 구현된 기능과 아직 남은 안정화 항목을 분리해 정리했다.
- 지원 UTI, 프로젝트 구조, Mermaid 아키텍처, Quick Start, Finder 통합 확인 절차를 추가했다.
- `postmelee/rhwp` core submodule 운영 원칙과 `rhwp-core.lock` 관리 기준을 추가했다.
- 릴리스 패키징과 Homebrew Cask 초안의 확인 필요 사항을 명시했다.
- Claude Code와 OpenAI Codex를 함께 사용하는 개발 방식을 설명했다.
- M0부터 M4까지 Viewer 안정화, Editing, Agent Plugin 로드맵을 추가했다.
- npm package, WASM browser viewer/editor, browser extension은 이 저장소 범위가 아님을 명시했다.

## 검증

- `git diff --check`

## 남은 사항

- 첫 공개 릴리스 전 cask token, zip 파일명, GitHub release URL, SHA256, 서명/notarization 정책을 확정해야 한다.
- README에 삽입할 실제 screenshot 또는 동영상은 후속 작업에서 추가할 수 있다.
