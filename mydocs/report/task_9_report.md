# Issue #9 최종 보고서

## 작업 요약

`README.md`를 upstream `rhwp` README의 순서와 작성 포맷을 따르도록 다시 재작성했다.

## 변경 내용

- 원본 README의 큰 순서인 `로드맵 -> 이정표 -> Features -> Quick Start (소스 빌드) -> AI 페어 프로그래밍으로 개발합니다` 흐름을 반영했다.
- macOS Quick Look, Thumbnail, HostApp viewer, RustBridge, `postmelee/rhwp` submodule 기준으로 내용을 수정했다.
- 온보딩 가이드는 추후 추가 예정임을 전제로 Quick Start 문구를 먼저 반영했다.
- "AI 페어 프로그래밍으로 개발합니다" 섹션은 upstream README의 문제의식과 문체를 최대한 보존하고 출처를 명시했다.
- Claude Code와 OpenAI Codex를 함께 사용하는 현재 개발 방식을 반영했다.
- Viewer 안정화, Editing, Agent Plugin 로드맵을 이정표에 추가했다.
- 릴리스/배포 절차는 타인용 README에서 제외했다. 해당 내용은 저장소 소유자용 `AGENTS.md` 또는 별도 릴리스 문서에서 다루는 것이 적절하다고 판단했다.

## 검증

- `git diff --check`

## 남은 사항

- 온보딩 가이드는 후속 작업에서 추가해야 한다.
- `CONTRIBUTING.md`는 후속 작업에서 추가해야 한다.
- README에 삽입할 실제 screenshot 또는 동영상은 후속 작업에서 추가할 수 있다.
