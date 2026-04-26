# Issue #31 최종 결과 보고서

## 작업 요약

- GitHub Issue: #31
- 마일스톤: M010
- 작업 브랜치: `local/task31`
- 작업명: README와 아키텍처 문서를 타깃별 제품 경계 중심으로 재정렬
- 단계 수: 5개 단계 + 최종 보고

README, architecture, build/run guide를 신규 진입자가 제품 타깃과 공통 계층 경계를 먼저 이해할 수 있는 순서로 재정렬했다. 현재 v0.1.0 목표가 Demo/Preview release이며 Stable release tag 승격은 별도 경로라는 점을 README, architecture, build/run, RustBridge 보조 문서에서 같은 용어로 맞췄다.

## 최종 변경 요약

- `README.md`의 Project Structure를 `Sources/`를 한 번만 상단에 두는 구조로 정리했다.
- README에서 직접 비교 명칭과 비교 구현 세부 표현을 제거했다.
- `mydocs/tech/project_architecture.md`를 제품 타깃 -> 공통 Swift 계층 -> Rust bridge -> generated artifact -> 프로젝트 설정 순서로 재정렬했다.
- Quick Look preview와 Thumbnail runtime flow를 분리해 설명했다.
- `mydocs/manual/build_run_guide.md`에 신규 진입자 읽기 순서와 새 checkout/worktree 기본 실행 순서를 추가했다.
- `Sources/README.md`를 추가해 `HostApp`, `QLExtension`, `ThumbnailExtension`, `Shared`, `RhwpCoreBridge`의 역할과 포함 target을 정리했다.
- `RustBridge/README.md`를 추가해 Rust FFI crate, generated `Rhwp.xcframework`, `Cargo.lock`, `rhwp-core.lock` 관계를 정리했다.
- 현재 Task #31 계획서와 단계 보고서의 검색 예시에서도 직접 비교 문자열을 쓰지 않도록 보정했다.

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | README, architecture, build/run guide와 실제 target/source 경계 조사 |
| Stage 2 | README 구조와 신규 진입자용 설명을 제품 타깃 중심으로 재정렬 |
| Stage 3 | architecture 문서를 제품 타깃, 공통 Swift 계층, Rust bridge, generated artifact 순서로 재정렬 |
| Stage 4 | build/run guide 보강, `Sources/README.md`, `RustBridge/README.md` 추가 |
| Stage 5 | 직접 비교 명칭 제거 여부, Demo/Preview vs Stable 표현, active 문서 검색 gate 검증 |

## 변경 파일과 영향 범위

사용자-facing 문서:

- `README.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/build_run_guide.md`
- `Sources/README.md`
- `RustBridge/README.md`

하이퍼-워터폴 작업 문서:

- `mydocs/plans/task_m010_31.md`
- `mydocs/working/task_m010_31_stage1.md`
- `mydocs/working/task_m010_31_stage2.md`
- `mydocs/working/task_m010_31_stage3.md`
- `mydocs/working/task_m010_31_stage4.md`
- `mydocs/working/task_m010_31_stage5.md`
- `mydocs/report/task_m010_31_report.md`
- `mydocs/orders/20260426.md`

source, `project.yml`, build script, lock 파일, generated framework 산출물은 변경하지 않았다.

## 변경 전·후 정량 비교

Stage 1-5 누적 변경 기준:

```text
12 files changed, 917 insertions(+), 58 deletions(-)
```

변경 유형:

- 사용자-facing 문서 5개 보정 또는 추가
- 단계 보고서 5개 작성
- 수행 계획서 1개 작성 및 보정
- 오늘할일 1개 갱신

## 검증 결과

Whitespace:

```bash
git diff --check
```

결과: 통과

직접 비교 명칭과 제외 비교 표현:

```bash
rg --line-number "<실제 비교 대상 프로젝트명>|<제외 비교 표현>" README.md mydocs/tech mydocs/manual Sources RustBridge mydocs/plans/task_m010_31.md mydocs/working/task_m010_31_stage1.md mydocs/working/task_m010_31_stage2.md mydocs/working/task_m010_31_stage3.md mydocs/working/task_m010_31_stage4.md mydocs/working/task_m010_31_stage5.md --glob '!RustBridge/target/**'
```

결과: 출력 없음

Demo/Preview와 Stable 표현:

```bash
rg --line-number "Demo/Preview|Stable|release tag|resolved commit|git dependency|rev|tag|branch/floating|prerelease" README.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md Sources/README.md RustBridge/README.md mydocs/plans/task_m010_31.md
```

결과: Demo/Preview commit pin, Stable release tag 기준, branch/floating ref 금지 표현 확인

단계 보고서 존재:

```bash
test -f mydocs/working/task_m010_31_stage1.md
test -f mydocs/working/task_m010_31_stage2.md
test -f mydocs/working/task_m010_31_stage3.md
test -f mydocs/working/task_m010_31_stage4.md
test -f mydocs/working/task_m010_31_stage5.md
```

결과: 통과

## 수용 기준 충족 여부

| 기준 | 결과 |
|------|------|
| README Project Structure를 제품 타깃 중심으로 재정렬 | OK |
| README에서 직접 비교 명칭 제거 | OK |
| architecture 문서를 제품 타깃 중심으로 재정렬 | OK |
| build/run guide에 신규 진입자 실행 순서 보강 | OK |
| `Sources/README.md`, `RustBridge/README.md` 필요성 판단 및 추가 | OK |
| Demo/Preview와 Stable release tag 기준 분리 | OK |
| source/project/build script 변경 없음 | OK |

## 잔여 위험과 후속 작업

- 이번 작업은 문서 정렬 작업이라 build를 실행하지 않았다.
- 현재 v0.1.0은 Demo/Preview release 목표다. Stable release tag 승격은 upstream release tag가 필요한 bridge API를 포함할 때 별도 작업으로 진행해야 한다.
- 과거 완료된 task 문서에는 당시의 조사 기록이 남아 있을 수 있다. 이번 gate는 현재 사용자-facing 문서와 현재 Task #31 문서를 기준으로 수행했다.

## 완료 판단

Issue #31의 목표인 README와 architecture 문서의 타깃별 제품 경계 재정렬, Demo/Preview와 Stable release 표현 분리, 직접 비교 명칭 제거, 신규 진입자용 build/run 흐름 보강을 완료했다.

## 승인 요청

이 최종 결과 보고서 기준으로 draft PR 리뷰와 merge 승인을 요청한다.
