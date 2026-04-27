# Task #31 Stage 4 완료 보고서

## 단계 목적

`mydocs/manual/build_run_guide.md`를 신규 진입자가 읽고 실행할 순서 중심으로 보강하고, 실제 디렉터리 안에서도 제품 타깃과 Rust bridge 경계를 확인할 수 있도록 보조 README를 추가한다.

## 변경 파일

- `mydocs/manual/build_run_guide.md`
- `Sources/README.md`
- `RustBridge/README.md`
- `mydocs/working/task_m010_31_stage4.md`
- `mydocs/orders/20260426.md`

## 변경 내용

Build/Run Guide:

- 문서 초반에 `먼저 읽을 문서` 절을 추가했다.
- 신규 진입자 읽기 순서를 `README.md` Project Structure -> `project_architecture.md` -> `Sources/README.md` -> `RustBridge/README.md` -> build/run 명령으로 정리했다.
- `기본 실행 순서` 절을 추가해 새 checkout/worktree의 준비 순서를 도구 준비 -> Rust bridge 산출물 생성 -> Xcode project 생성 -> HostApp build -> boundary/render smoke -> Finder 통합 확인 순서로 정리했다.
- 현재 v0.1.0 목표가 Demo/Preview release이며 기본 core update 경로가 `--channel demo --rev`임을 Core dependency 모드에 명시했다.

Sources README:

- `Sources/` 아래 제품 타깃과 공통 Swift 계층을 한 번의 tree로 정리했다.
- `HostApp`, `QLExtension`, `ThumbnailExtension`, `Shared`, `RhwpCoreBridge`의 역할과 포함 target을 표로 정리했다.
- `RhwpCoreBridge`의 AppKit/UIKit 직접 의존 금지, HostApp/AppKit drawing 소유, extension entrypoint 소유, `project.yml` 원본 규칙을 짧게 명시했다.

RustBridge README:

- `RustBridge/`가 `edwardkim/rhwp`를 C ABI로 노출하는 이 저장소 소유 crate임을 정리했다.
- `Cargo.toml`, `Cargo.lock`, `src/lib.rs`, `cbindgen.toml` 역할을 표로 정리했다.
- generated `Frameworks/Rhwp.xcframework`, header, modulemap, universal staticlib과 `rhwp-core.lock`의 관계를 정리했다.
- Demo/Preview와 Stable dependency/lock 기준을 build guide와 같은 용어로 맞췄다.
- 기본 build/verify/update 명령과 FFI 변경 시 확인할 경계 규칙을 추가했다.

## 본문 변경 정도 / 본문 무손실 여부

기존 build/run 명령, render smoke, `check-no-appkit`, Finder 통합 검증 절차는 유지했다. Stage 4 변경은 문서 초반의 읽기/실행 순서와 폴더별 보조 설명 추가에 한정했다.

source, `project.yml`, build script, lock 파일, generated framework 산출물은 변경하지 않았다.

## 검증 결과

diff whitespace:

```text
$ git diff --check
결과: 통과
```

직접 비교 명칭과 제외 표현:

```text
$ rg --line-number '<실제 비교 대상 프로젝트명>|<제외 비교 표현>' README.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md Sources/README.md RustBridge/README.md
결과: 출력 없음
```

신규 문서 연결:

```text
$ rg --line-number 'Sources/README.md|RustBridge/README.md|Project Structure|project_architecture.md' mydocs/manual/build_run_guide.md
결과: build/run guide의 먼저 읽을 문서 절에서 연결 확인
```

제품 타깃/bridge 경계:

```text
$ rg --line-number 'HostApp|QLExtension|ThumbnailExtension|Shared|RhwpCoreBridge|AppKit/UIKit|project.yml' Sources/README.md
결과: Sources README에서 주요 경계 확인
```

Demo/Preview와 Stable 표현:

```text
$ rg --line-number 'Demo/Preview|Stable|rev|release tag|resolved commit|branch/floating' mydocs/manual/build_run_guide.md RustBridge/README.md
결과: build/run guide와 RustBridge README에서 Demo/Preview commit pin과 Stable release tag 기준 확인
```

## 잔여 위험

- Stage 4는 문서 보강만 수행했다. 실제 build는 source/project 설정을 바꾸지 않았으므로 실행하지 않았다.
- active 문서 전체의 직접 비교 명칭 제거와 Demo/Preview/Stable 표현 검색 gate는 Stage 5에서 한 번 더 묶어서 검증해야 한다.

## 다음 단계

Stage 5에서는 직접 비교 명칭 제거 여부, Demo/Preview vs Stable 표현, active 문서 검색 gate를 전체 범위로 검증한다.

## 승인 요청

Stage 4 build/run guide와 보조 README 보강을 완료했다. 이 보고서 기준으로 Stage 5 `직접 비교 명칭 제거 여부, Demo/Preview vs Stable 표현, 검색 gate 검증`을 진행할지 승인 요청한다.
