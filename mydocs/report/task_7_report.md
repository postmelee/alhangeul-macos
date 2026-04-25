# Issue #7 최종 보고서

## 작업 요약

`alhangeul-macos` 저장소에서 OpenAI Codex가 사용할 프로젝트 규칙 파일 `AGENTS.md`를 추가했다.

## 변경 내용

- upstream `edwardkim/rhwp`의 `CLAUDE.md` 구조를 참고하되, macOS 앱 저장소에 맞게 내용을 재작성했다.
- 프로젝트 개요를 Quick Look preview, Finder thumbnail, HostApp viewer, RustBridge/XCFramework 구조로 정리했다.
- Codex 진행 규칙, 문서 생성 규칙, GitHub Issue/branch/PR 흐름을 이 저장소 기준으로 명시했다.
- `edwardkim/rhwp` core submodule 운영과 `rhwp-core.lock` 관리 기준을 추가했다.
- Swift/macOS 코드 경계, FFI ABI, 렌더링 검증, 릴리스 패키징 검증 기준을 정리했다.

## 검증

- `git diff --check`

## 남은 사항

- 저장소를 독립 디렉토리로 이동한 뒤 새 세션에서 이 `AGENTS.md`가 정상 적용되는지 확인한다.
