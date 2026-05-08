# AGENTS.md

본 저장소에서 작업하는 모든 코딩 에이전트(Codex, Claude Code 등)가 따르는 운영 규칙. 매 턴 시스템 프롬프트로 적재되므로 항상 필요한 정책·제약·인덱스만 둔다. 절차 상세는 매뉴얼·SKILL로 분리한다.

## 프로젝트 개요

**목표**: macOS용 HWP/HWPX 문서 미리보기 및 viewer 앱 개발

- Finder Quick Look preview / Thumbnail extension으로 `.hwp`, `.hwpx` 첫 페이지 미리보기·썸네일 제공
- macOS viewer app: MVP는 `edwardkim/rhwp` `devel-webview` 브랜치의 `rhwp-studio`를 WKWebView로 표시하고, native viewer renderer는 후순위 마일스톤에서 개선
- Rust `rhwp` core를 `edwardkim/rhwp` 기준으로 고정, `RustBridge` C ABI와 `Rhwp.xcframework`로 Swift/macOS에서 사용
- 앱, Quick Look/Thumbnail 확장, Swift bridge, 패키징·배포 정책은 본 저장소가 소유

## 하이퍼-워터폴 핵심 규칙

이 프로젝트는 **하이퍼-워터폴** 방법론을 적용한다. 에이전트의 기본 동작(빠른 실행, 자율 수정)과 충돌하므로 반드시 숙지한다. 상세: [`agent_code_hyperfall_rule_conflict.md`](mydocs/manual/agent_code_hyperfall_rule_conflict.md).

- 소스 수정 전 반드시 작업지시자 승인 요청
- 작업은 GitHub Issue 기준으로 추적
- 새 기능, 버그 수정, 구조 변경은 `이슈 -> 브랜치 -> 오늘할일 -> 계획서 -> 구현 -> 검증 -> 최종 보고서 -> PR` 순서 절대 생략 금지
- 각 단계 완료 후 승인 없이 다음 단계 진행 금지
- 범위가 불명확하거나 기존 작업과 충돌할 가능성이 있으면 먼저 확인
- 사용자나 다른 작업자가 만든 변경은 되돌리지 않음
- 이슈 close는 작업지시자 승인 후 또는 PR merge 확인 후에만 수행
- 문서 수정은 기존 내용을 먼저 읽고 필요한 부분만 수정하며, 불가피할 때만 내용을 추가
- 작업 완료 후 다음 작업에 필요하지 않은 로컬/원격 부산물은 정리
- PR merge와 이슈 close 후에는 대상 통합 브랜치로 돌아오고, 더 이상 필요 없는 `local/task{번호}` 브랜치와 임시 worktree를 정리

**승인 간주 조건**: 작업지시자가 같은 스레드에서 "계속 진행", "다음 단계 진행"처럼 명시 지시한 경우에만 해당 단계 승인으로 간주한다.

## 명명 규칙

- 마일스톤: `M{버전}` (예: M100=v1.0.0, M05x=v0.5.x). 문서 파일명은 `m{숫자}` 소문자 (예: `m100`)
- 브랜치: `local/task{이슈번호}` (작업), `publish/task{이슈번호}` (`devel-webview` 또는 `devel` 대상 PR 게시용)
- 커밋 메시지:
  - 기본형: `Task #{번호}: 내용`
  - 단계: `Task #{번호} Stage {N}: 내용`
  - 하위 단계: `Task #{번호} [Stage {N.M}]: 내용`
  - 보고서 묶음: `Task #{번호} Stage {N} + 최종 보고서: 내용`
- 문서 파일명: `task_{milestone}_{이슈번호}{_impl|_stage{N}|_report}?.md`. 신규 문서는 마일스톤 포함 형식 강제. 상세: [`document_structure_guide.md`](mydocs/manual/document_structure_guide.md)
- 모든 문서는 한국어 작성

## 핵심 강제 규칙 (변경 전 매뉴얼 확인 필수)

- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 금지 — 상세: [`swift_macos_code_rules_guide.md`](mydocs/manual/swift_macos_code_rules_guide.md)
- Rust FFI 경계의 포인터/길이/수명 규칙 준수 — 상세: 동일 매뉴얼
- `project.yml`이 Xcode project 원본. `Alhangeul.xcodeproj` 직접 수정 금지 — 상세: [`build_run_guide.md`](mydocs/manual/build_run_guide.md)
- 변경 유형별 최소 검증 필수 — 상세: 동일 매뉴얼
- `build.noindex/` 아래에 `.app`/`.appex` 산출물 배치 (Spotlight 검색 혼선 방지) — 상세: 동일 매뉴얼
- core 안정 기준은 Stable의 경우 release tag + resolved commit, Demo/Preview의 경우 resolved commit `rev` pin. branch/floating ref는 안정 기준으로 취급하지 않음 — 상세: [`core_dependency_operation_guide.md`](mydocs/manual/core_dependency_operation_guide.md)
- 릴리스/배포/서명/공증/Homebrew Cask는 작업지시자 명시 지시 시에만 — 상세: [`release_distribution_guide.md`](mydocs/manual/release_distribution_guide.md)

## 필수 참조 문서

- [`README.md`](README.md) — 프로젝트 개요, 초기 설정, 빌드
- [`rhwp-core.lock`](rhwp-core.lock) — 현재 고정된 `rhwp` core 저장소·ref kind·commit·산출물
- [`mydocs/tech/project_architecture.md`](mydocs/tech/project_architecture.md) — 코드베이스 소유 경계, bridge 구조, FFI ABI 표면
- [`mydocs/manual/document_structure_guide.md`](mydocs/manual/document_structure_guide.md) — `mydocs/` 폴더 역할, 문서 파일명, 외부 PR 폴더 정책, Skills 위치 정책
- [`mydocs/manual/task_workflow_guide.md`](mydocs/manual/task_workflow_guide.md) — 타스크 진행 15단계, 커밋 메시지 규칙, 작업 시간 규칙
- [`mydocs/manual/git_workflow_guide.md`](mydocs/manual/git_workflow_guide.md) — 브랜치 정책, Git 다이어그램, 메인테이너/컨트리뷰터 워크플로우
- [`mydocs/manual/build_run_guide.md`](mydocs/manual/build_run_guide.md) — 빌드/실행/검증
- [`mydocs/manual/core_dependency_operation_guide.md`](mydocs/manual/core_dependency_operation_guide.md) — core git dependency 운영
- [`mydocs/manual/swift_macos_code_rules_guide.md`](mydocs/manual/swift_macos_code_rules_guide.md) — Swift/macOS 코드 규칙
- [`mydocs/manual/release_distribution_guide.md`](mydocs/manual/release_distribution_guide.md) — 릴리스/배포
- [`mydocs/manual/pr_process_guide.md`](mydocs/manual/pr_process_guide.md) — 외부 기여 PR 검토
- [`mydocs/manual/agent_code_hyperfall_rule_conflict.md`](mydocs/manual/agent_code_hyperfall_rule_conflict.md) — 하이퍼-워터폴과 에이전트 기본 동작 충돌 규칙

## Agent Skills

하이퍼-워터폴 절차의 정형 시점은 SKILL로 분리해 명시 호출 시에만 트리거한다. 진실 원천은 `mydocs/skills/`이며, Codex(`.agents/skills`)와 Claude Code(`.claude/skills`)는 심볼릭 링크로 동일 본문을 인식한다. 모든 SKILL은 `allow_implicit_invocation: false`로 명시 호출만 허용한다. 상세: [`document_structure_guide.md`](mydocs/manual/document_structure_guide.md) 의 "Agent Skills 위치 정책".

## 작업 규칙

- 작업 시간의 시작과 종료는 작업지시자가 결정한다. 에이전트가 임의로 작업 종료를 제안하거나 시간을 한정하지 않는다.
