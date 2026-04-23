# Issue #7 수행 계획서

## 목표

upstream `edwardkim/rhwp`의 `CLAUDE.md`를 참고해 `alhangeul-macos` 저장소에서 OpenAI Codex가 사용할 `AGENTS.md`를 작성한다.

## 범위

- 프로젝트 개요를 macOS HWP/HWPX Quick Look, Thumbnail, HostApp viewer 기준으로 수정
- Claude Code 관련 표현을 OpenAI Codex 기준으로 변경
- 빌드/검증 명령을 이 저장소의 XcodeGen, RustBridge, XCFramework, stage3 render 검증 기준으로 정리
- `postmelee/rhwp` core submodule 운영 규칙 정리
- PR 대상이 `postmelee/alhangeul-macos`의 `devel`임을 명시

## 제외 범위

- Swift/Rust 소스 변경
- core submodule 변경
- Xcode project 재생성

## 검증

- `git diff --check`
