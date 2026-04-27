# Issue #7 단계 1 완료 보고서

## 수행 내용

- upstream `edwardkim/rhwp`의 `CLAUDE.md`를 확인했다.
- `README.md`, `docs/ARCHITECTURE.md`(현재는 `mydocs/tech/project_architecture.md`로 이전), `project.yml`, `scripts/`를 확인해 `alhangeul-macos`의 실제 빌드와 운영 방식을 반영했다.
- `AGENTS.md`를 OpenAI Codex용 규칙 파일로 작성했다.

## 주요 반영 사항

- 프로젝트 목표를 macOS Quick Look, Thumbnail, HostApp viewer, RustBridge/XCFramework 구조로 수정했다.
- `Vendor/rhwp` submodule 기준을 `edwardkim/rhwp`의 `devel`로 명시했다.
- 앱 저장소 작업 PR은 `postmelee/alhangeul-macos`의 `devel`로 생성하도록 명시했다.
- Swift bridge, FFI ABI, 렌더링 검증, 릴리스 패키징 규칙을 추가했다.

## 검증

- `git diff --check`
