# AGENTS.md

This file provides guidance to Claude / Codex when working with code in this repository.

## 프로젝트 개요

**목표**: macOS용 HWP/HWPX 문서 미리보기 및 viewer 앱 개발

- Finder Quick Look preview extension으로 `.hwp`, `.hwpx` 문서 첫 페이지를 미리보기로 표시
- Finder thumbnail extension으로 문서 첫 페이지 기반 썸네일 생성
- macOS viewer app에서 HWP/HWPX 파일 열기, 다중 페이지 스크롤, 확대/축소 제공
- Rust `rhwp` core를 `Vendor/rhwp` git submodule로 고정하고, `RustBridge` C ABI와 `Rhwp.xcframework`를 통해 Swift/macOS 앱에서 사용
- 앱, Quick Look/Thumbnail 확장, Swift bridge, 패키징과 배포 정책은 이 저장소가 소유

## Claude / Codex 사용 시 주의사항

이 프로젝트는 **하이퍼-워터폴** 방법론을 적용한다. Claude / Codex의 기본 동작(빠른 실행, 자율 수정)과 충돌이 발생할 수 있으므로 반드시 숙지한다.

상세 내용: [`mydocs/manual/agent_code_hyperfall_rule_conflict.md`](mydocs/manual/agent_code_hyperfall_rule_conflict.md)

**핵심 규칙 요약**:

- 소스 수정 전 반드시 작업지시자 승인 요청
- 작업은 GitHub Issue 기준으로 추적
- 새 기능, 버그 수정, 구조 변경은 `이슈 -> 브랜치 -> 오늘할일 -> 계획서 -> 구현 -> 검증 -> 최종 보고서 -> PR` 순서 절대 생략 금지
- 각 단계 완료 후 승인 없이 다음 단계 진행 금지
- 범위가 불명확하거나 기존 작업과 충돌할 가능성이 있으면 먼저 확인
- 사용자나 다른 작업자가 만든 변경은 되돌리지 않음
- 이슈 close는 작업지시자 승인 후 또는 PR merge 확인 후에만 수행

승인 간주 조건:

- 작업지시자가 같은 스레드에서 "계속 진행", "다음 단계 진행"처럼 명시 지시한 경우에만 해당 단계 승인으로 간주한다.

## 문서 생성 규칙

모든 문서는 한국어로 작성한다.

문서 폴더 구조 (`mydocs/` 하위):

- `orders/` - 오늘 할일 문서 (`yyyymmdd.md`)
- `plans/` - 수행 계획서, 구현 계획서
- `plans/archives/` - 완료된 계획서 보관
- `working/` - 단계별 완료 보고서
- `report/` - 최종 보고서와 장기 보관 보고서
- `feedback/` - 작업지시자 피드백, 코드 리뷰 의견
- `tech/` - 기술 조사, 구조 분석, 스펙 정리
- `manual/` - 개발자/사용자 매뉴얼
- `troubleshootings/` - 트러블슈팅과 재발 방지 기록
- `pr/` - 외부 PR 검토 기록
- `pr/archives/` - 처리 완료 PR 검토 기록 보관

### 필수 참조 문서

- `README.md` - 프로젝트 개요, 초기 설정, 빌드
- `docs/ARCHITECTURE.md` - 소유 경계, Swift bridge 정책, submodule 정책, FFI ABI 정책
- `docs/RHWP_CORE_BRIDGE_PLAN.md` - Rust core bridge와 장기 운영 계획
- `rhwp-core.lock` - 현재 고정된 `rhwp` core 저장소, 브랜치, commit, 생성 산출물
- `mydocs/manual/pr_process_guide.md` - PR 처리 상세 절차
- `mydocs/manual/build_run_guide.md` - 빌드/실행/검증 상세 절차
- `mydocs/manual/core_submodule_operation_guide.md` - core submodule 운영 상세 절차
- `mydocs/manual/swift_macos_code_rules_guide.md` - Swift/macOS 코드 규칙 상세
- `mydocs/manual/release_distribution_guide.md` - 릴리스/배포 상세 절차
- `mydocs/manual/agent_code_hyperfall_rule_conflict.md` - 하이퍼-워터폴과 에이전트 기본 동작 충돌 규칙

### 문서 파일명 규칙

신규 문서의 표준 형식은 GitHub Issue 번호와 마일스톤을 함께 사용한다.

- 수행 계획서: `task_{milestone}_{이슈번호}.md` (예: `task_m100_7.md`)
- 구현 계획서: `task_{milestone}_{이슈번호}_impl.md` (예: `task_m100_7_impl.md`)
- 단계별 완료 보고서: `task_{milestone}_{이슈번호}_stage{N}.md` (예: `task_m100_7_stage1.md`)
- 최종 보고서: `task_{milestone}_{이슈번호}_report.md` (예: `task_m100_7_report.md`)

강제 규칙:

- 신규 작성 문서는 반드시 `task_{milestone}_{이슈번호}` 형식을 사용한다.
- 마일스톤은 항상 `m{숫자}` 형식으로 적는다. 예: `m100`, `m200`
- 마일스톤 없이 `task_{이슈번호}` 형식으로 신규 문서를 만들지 않는다.
- 기존 레거시 문서명은 유지할 수 있으나, 신규 이슈부터는 마일스톤 포함 형식을 고정한다.

### 폴더 역할 (엄격 준수)

| 폴더 | 용도 | 비고 |
|------|------|------|
| `orders/` | 오늘 할일 | `yyyymmdd.md`만 허용. 상세 조사/분석은 `tech/` 또는 `troubleshootings/`에 기록 |
| `plans/` | 수행/구현 계획서 | `_stage{N}`, `_report` 파일은 두지 않는다 |
| `plans/archives/` | 완료된 계획서 보관 | merge 후 정리 시 사용 |
| `working/` | 단계별 완료 보고서 (`_stage{N}.md`) | 최종 보고서는 두지 않는다 |
| `report/` | 최종 결과보고서 (`_report.md`) + 장기 보관 보고서 | 최종 보고서는 반드시 이 폴더 |
| `feedback/` | 작업지시자 피드백, 코드 리뷰 의견 | |
| `tech/` | 기술 조사, 구조/스펙 분석 | |
| `manual/` | 매뉴얼, 가이드 | 사용자/개발자 문서 |
| `troubleshootings/` | 트러블슈팅, 재발 방지 기록 | |
| `pr/` | 외부 기여자 PR 검토 기록 | 내부 타스크와 분리 |
| `pr/archives/` | 처리 완료된 PR 검토 기록 보관 | |

### 외부 기여자 PR 처리 (`mydocs/pr/`)

외부 기여 PR 검토 상세 절차는 `mydocs/manual/pr_process_guide.md`를 따른다.

강제 규칙:

- 외부 기여자 PR은 내부 타스크와 다른 본질을 가지므로 별도 절차와 폴더를 사용한다.
- 이 목차는 외부 기여 PR 검토에만 적용한다.
- 외부 PR 검토 기록은 `mydocs/pr/`에 남긴다.
- 파일명은 `pr_{번호}_review.md`, `pr_{번호}_review_impl.md`(필요 시), `pr_{번호}_report.md`를 사용한다.
- 처리 완료 문서는 `mydocs/pr/archives/`로 이동한다.

즉시 처리 절차:

1. PR 정보 확인: 이슈 연결, base/head, mergeable, CI 상태 확인
2. `pr_{번호}_review.md` 작성 후 승인 요청
3. 필요 시 `pr_{번호}_review_impl.md` 작성 후 승인 요청
4. 검증과 판단 후 `pr_{번호}_report.md` 작성

내부 타스크의 `수행 -> 구현 -> 단계별 보고 -> 최종 보고` 절차는 외부 기여 PR 검토에 그대로 적용하지 않는다.

## 빌드 및 실행

상세 절차는 `mydocs/manual/build_run_guide.md`를 따른다.

강제 규칙:

- `project.yml`이 Xcode project의 원본이며 `RhwpMac.xcodeproj`를 직접 수정하지 않는다.
- 변경 유형별 최소 검증은 반드시 수행한다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존을 넣지 않는다.

### 릴리스/배포

릴리스, 배포, Homebrew Cask, 서명, 공증, GitHub Release 작업은 저장소 소유자 명시 지시가 있을 때만 진행한다. 시작 전 반드시 `mydocs/manual/release_distribution_guide.md`를 읽고 따른다.

## rhwp Core Submodule 운영

상세 절차는 `mydocs/manual/core_submodule_operation_guide.md`를 따른다.

강제 규칙:

- core 최신화 기준은 `postmelee/rhwp` `devel`이다.
- 앱 저장소에 `Vendor/rhwp` 임시 수정을 남기지 않는다.
- core 변경은 먼저 core 저장소에 반영한 뒤 앱 저장소에서 submodule pointer + `rhwp-core.lock`을 함께 갱신한다.

## Swift 및 macOS 코드 규칙

상세 규칙은 `mydocs/manual/swift_macos_code_rules_guide.md`를 따른다.

강제 규칙:

- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 넣지 않는다.
- Rust FFI 경계의 포인터/길이/수명 규칙을 깨지 않는다.
- HostApp 전용 UI 상태와 공통 렌더링 helper의 소유 경계를 유지한다.
- 렌더링/FFI 변경 후 필수 검증을 수행한다.

## Git 워크플로우

### 브랜치 관리

| 브랜치 | 용도 |
|--------|------|
| `main` | 최종 릴리스. 태그로 안정 버전 보존 |
| `devel` | 개발 통합 브랜치 |
| `local/task{issue}` | GitHub Issue 단위 작업 브랜치 |

### 기준 브랜치 동기화

새 작업 시작 전에는 반드시 `origin/devel`을 기준으로 작업 브랜치를 만든다.

```bash
git switch devel
git fetch origin
git pull --ff-only origin devel
git switch -c local/task{issue}
```

이미 존재하는 작업 브랜치를 최신 `devel` 기준으로 갱신할 때는 변경 범위를 확인한 뒤 병합한다.

```bash
git switch devel
git fetch origin
git pull --ff-only origin devel
git switch local/task{issue}
git merge devel
```

`edwardkim/rhwp` upstream에는 이 저장소의 앱 작업 PR을 생성하지 않는다. 이 저장소의 모든 앱/bridge/문서 변경 PR은 `postmelee/alhangeul-macos`의 `devel`로 생성한다.

### PR 생성

최종 보고서 작성 후 PR을 생성한다. PR 본문은 최종 보고서를 기반으로 상세히 작성한다.

```bash
git push -u origin local/task{issue}
gh pr create --repo postmelee/alhangeul-macos --base devel --head local/task{issue} --draft --title "Issue #{issue}: 제목"
```

PR 본문에는 다음을 포함한다.

- `Closes #{issue}`
- 작업 배경과 변경 요약
- core submodule 변경 여부와 commit SHA
- FFI ABI 변경 여부
- 실행한 검증 명령과 결과
- 남은 수동 검증 항목

### 커밋 메시지

```text
Issue #{issue}: 변경 요약
```

예:

```text
Issue #7: Add agent guidelines
```

## 타스크 진행 절차

1. GitHub Issue에 타스크 등록
2. `origin/devel` 기준으로 `local/task{issue}` 브랜치 생성
3. 수행 계획서 작성
4. 구현 계획서 작성
5. 단계별 진행
6. 단계 완료 시 단계별 완료 보고서 작성
7. 단계 소스 변경과 단계 보고서를 함께 커밋
8. 모든 단계 완료 시 최종 보고서 작성
9. 오늘 할일 문서 갱신
10. `git status`로 미커밋 파일 확인
11. 최종 보고서 기반 PR 생성
12. PR merge 후 이슈 close 확인

작업지시자가 단순 문서 수정, 명확한 한 줄 수정, 조사만 요청한 경우에는 절차를 필요한 수준으로 축소할 수 있다. 다만 GitHub Issue가 이미 생성된 작업은 최종 보고서와 PR 본문에 작업 결과를 남긴다.

## 검증 기준

변경 유형별 상세 검증 명령은 `mydocs/manual/build_run_guide.md`를 따른다.

최소 기준은 다음과 같다.

- 문서만 변경: `git diff --check`
- Swift UI/bridge 변경: `xcodegen generate`, `xcodebuild ... HostApp ...`
- Rust bridge 변경: `./scripts/build-rust-macos.sh`, `./scripts/check-no-appkit.sh`
- 렌더링 변경: `./scripts/validate-stage3-render.sh`
- core submodule 변경: `Vendor/rhwp` commit과 `rhwp-core.lock` 대조, Rust bridge 재빌드, HostApp 빌드
- 릴리스/배포 변경: `mydocs/manual/release_distribution_guide.md` 확인 후 수행

검증을 실행하지 못한 경우 최종 보고서와 PR 본문에 이유를 명시한다.

## 작업 규칙

- 작업 시간의 시작과 종료는 작업지시자가 결정한다.
- Claude와 Codex가 임의로 작업 범위를 확장하지 않는다.
- unrelated refactor, formatter churn, 생성물 재생성은 요청 범위에 필요할 때만 수행한다.
- `Vendor/rhwp` 내부 변경은 core 작업으로 분리한다.
- destructive git 명령은 작업지시자의 명시적 요청 없이 실행하지 않는다.
