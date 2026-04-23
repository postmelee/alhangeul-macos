# Issue #9 수행 계획서

## 목표

`alhangeul-macos`의 현재 구현 상태와 장기 방향을 반영해 `README.md`를 상세 재작성한다.

## 범위

- 현재 코드와 문서를 확인해 구현된 기능을 파악한다.
- upstream `rhwp` README 구조를 참고하되 npm, WASM browser, browser extension 등 이 저장소에 필요 없는 내용은 제외한다.
- macOS Quick Look, Thumbnail, HostApp viewer, RustBridge, `rhwp` submodule, 배포/개발 환경을 중심으로 README를 작성한다.
- Claude Code와 OpenAI Codex를 함께 사용하는 개발 방식을 반영한다.
- Viewer 안정화, Editing, Agent Plugin 단계까지 로드맵을 명시한다.

## 제외 범위

- Swift/Rust 소스 변경
- core submodule 변경
- Xcode project 재생성
- 배포용 서명 또는 notarization 구성

## 검증

- `git diff --check`
