# AGENTS.md

This file provides guidance to OpenAI Codex when working with code in this repository.

## 프로젝트 개요

**목표**: macOS용 HWP/HWPX 문서 미리보기 및 viewer 앱 개발

- Finder Quick Look preview extension으로 `.hwp`, `.hwpx` 문서 첫 페이지를 미리보기로 표시
- Finder thumbnail extension으로 문서 첫 페이지 기반 썸네일 생성
- macOS viewer app에서 HWP/HWPX 파일 열기, 다중 페이지 스크롤, 확대/축소 제공
- Rust `rhwp` core를 `Vendor/rhwp` git submodule로 고정하고, `RustBridge` C ABI와 `Rhwp.xcframework`를 통해 Swift/macOS 앱에서 사용
- 앱, Quick Look/Thumbnail 확장, Swift bridge, 패키징과 배포 정책은 이 저장소가 소유

## Codex 사용 시 주의사항

이 프로젝트는 작업 추적과 문서화를 중시한다. Codex의 기본 동작인 빠른 자율 수정과 충돌하지 않도록 아래 원칙을 우선한다.

**핵심 규칙 요약**:

- 작업은 GitHub Issue 기준으로 추적한다.
- 새 기능, 버그 수정, 구조 변경은 `이슈 -> 브랜치 -> 계획서 -> 구현 -> 검증 -> 최종 보고서 -> PR` 순서로 진행한다.
- 사용자가 "진행해줘", "작성해줘", "구현해줘"처럼 명확히 지시한 범위는 해당 단계 진행 승인으로 간주한다.
- 범위가 불명확하거나 기존 작업과 충돌할 가능성이 있으면 먼저 확인한다.
- 사용자나 다른 작업자가 만든 변경은 되돌리지 않는다.
- 이슈 close는 작업지시자 승인 또는 PR merge 후에만 수행한다.

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

- `README.md` - 프로젝트 개요, 초기 설정, 빌드, 릴리스 패키징
- `docs/ARCHITECTURE.md` - 소유 경계, Swift bridge 정책, submodule 정책, FFI ABI 정책
- `docs/RHWP_CORE_BRIDGE_PLAN.md` - Rust core bridge와 장기 운영 계획
- `rhwp-core.lock` - 현재 고정된 `rhwp` core 저장소, 브랜치, commit, 생성 산출물

### 문서 파일명 규칙

기본 형식은 GitHub Issue 번호를 기준으로 한다.

- 수행 계획서: `task_{이슈번호}.md` (예: `task_7.md`)
- 구현 계획서: `task_{이슈번호}_impl.md` (예: `task_7_impl.md`)
- 단계별 완료 보고서: `task_{이슈번호}_stage{N}.md` (예: `task_7_stage1.md`)
- 최종 보고서: `task_{이슈번호}_report.md` (예: `task_7_report.md`)

릴리스 마일스톤을 명시해야 하는 큰 작업은 `task_{milestone}_{이슈번호}.md` 형식을 사용할 수 있다. 예: `task_m100_7.md`.

### PR 처리 규칙 (`pr/`)

외부 기여자 PR 검토는 내부 타스크 구현과 분리한다.

- 검토 문서: `pr_{번호}_review.md`
- 구현 계획서: `pr_{번호}_review_impl.md` (필요 시)
- 최종 보고서: `pr_{번호}_report.md`

PR 검토 절차:

1. PR 정보 확인: 연결 이슈, base/head, mergeable 상태, CI 상태
2. `pr_{번호}_review.md` 작성
3. 필요 시 `pr_{번호}_review_impl.md` 작성
4. 빌드/테스트/코드 검토 후 `pr_{번호}_report.md` 작성

처리 완료 PR 문서는 `pr/archives/`로 이동한다.

## 빌드 및 실행

### 초기 설정

```bash
git submodule update --init --recursive
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo install cbindgen
brew install xcodegen
```

### Rust bridge 및 XCFramework 빌드

```bash
./scripts/build-rust-macos.sh
```

이 스크립트는 다음을 수행한다.

- `RustBridge` staticlib를 `aarch64-apple-darwin`, `x86_64-apple-darwin`으로 빌드
- `xcrun lipo`로 universal static library 생성
- `cbindgen`으로 C header 생성
- `rhwp-ffi-symbols.txt`와 생성된 `rhwp_` 심볼 목록 비교
- `Frameworks/Rhwp.xcframework` 생성

### Xcode 프로젝트 생성 및 빌드

```bash
xcodegen generate
xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

`project.yml`이 Xcode project의 원본이다. `RhwpMac.xcodeproj`를 직접 수정하지 말고 `project.yml`을 수정한 뒤 `xcodegen generate`를 실행한다.

### 렌더링 검증

```bash
./scripts/validate-stage3-render.sh
```

기본 샘플:

- `Vendor/rhwp/samples/basic/KTX.hwp`
- `Vendor/rhwp/samples/basic/request.hwp`
- `Vendor/rhwp/samples/exam_kor.hwp`

렌더링 변경은 최소한 이 스크립트로 text run과 non-white pixel 결과를 확인한다.

### 공유 Swift 코드 플랫폼 의존성 검사

```bash
./scripts/check-no-appkit.sh
```

`Sources/RhwpCoreBridge`는 HostApp, Quick Look, Thumbnail에서 함께 쓰는 bridge 계층이다. 이 계층에는 AppKit/UIKit 타입을 직접 넣지 않는다. 플랫폼 UI 타입이 필요하면 `Sources/Shared`, `Sources/HostApp`, `Sources/QLExtension`, `Sources/ThumbnailExtension` 경계에서 처리한다.

### 릴리스 패키징

```bash
./scripts/package-release.sh 0.1.0
```

산출물은 `build/release/rhwp-mac-<version>.zip`에 생성된다. Homebrew Cask(`Casks/rhwp-mac.rb`)를 갱신할 때는 버전, URL, SHA256을 함께 검토한다.

## rhwp Core Submodule 운영

### 소유 경계

- `Vendor/rhwp`: Rust HWP/HWPX parser/renderer core. 개인 fork `postmelee/rhwp`의 `devel`을 기준으로 추적한다.
- `RustBridge`: 이 저장소가 소유하는 macOS용 C ABI bridge.
- `Sources/RhwpCoreBridge`: Swift FFI wrapper와 CoreGraphics render bridge.
- `Sources/HostApp`: macOS viewer app.
- `Sources/QLExtension`: Quick Look preview extension.
- `Sources/ThumbnailExtension`: Finder thumbnail extension.
- `Sources/Shared`: HostApp/extension 공통 macOS helper.

### Core 최신화 기준

`rhwp` core 최신화 기준은 다음 순서로 판단한다.

1. `postmelee/rhwp`의 `devel`: 이 저장소가 실제로 사용하는 core 기준
2. `edwardkim/rhwp`의 `devel`: upstream core 최신 변경 참고 기준
3. `edwardkim/rhwp`의 `ios/devel`: native viewer 관련 변경 참고 기준

앱 저장소에서 core 변경이 필요하면 `Vendor/rhwp` 안에서 임시 수정만 남기지 않는다. 먼저 `postmelee/rhwp`의 `devel`에 core 변경을 커밋/푸시한 뒤, 이 저장소에서는 submodule pointer와 `rhwp-core.lock`만 갱신한다.

### Core 업데이트 절차

```bash
./scripts/update-rhwp-core.sh
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
```

업데이트 후 확인 항목:

- `Vendor/rhwp` submodule commit과 `rhwp-core.lock`의 `rhwp_commit`이 일치하는가
- `rhwp-ffi-symbols.txt` 변경이 의도된 ABI 변경인가
- Swift `RenderTree` 모델과 core JSON 직렬화 구조가 호환되는가
- Finder Quick Look/Thumbnail extension smoke test가 필요한 변경인가

## Swift 및 macOS 코드 규칙

- iOS에서 가져온 Swift 코드는 초기 이식 자산으로만 본다. 분리 이후에는 이 저장소가 macOS용 bridge와 UI 코드를 독립적으로 소유한다.
- 플랫폼 중립 이름을 사용한다. 예: `mapHWPFontToApple`, `resolveAppleFont`.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존성을 넣지 않는다.
- Quick Look/Thumbnail extension에서 사용할 코드는 extension sandbox와 메모리 사용량을 고려한다.
- HostApp 전용 UI 상태는 `Sources/HostApp`에 둔다.
- HostApp/extension 공통 렌더링 helper는 `Sources/Shared`에 둔다.
- Rust FFI 경계에서는 null pointer, length, ownership 해제를 명확히 처리한다.
- `RhwpDocument`가 소유한 native handle 수명과 `rhwp_free_*` 호출 경계를 변경할 때는 crash/leak 가능성을 함께 검토한다.

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
Issue #7: Add Codex agent guidelines
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

변경 유형별 기본 검증은 다음과 같다.

- 문서만 변경: `git diff --check`
- Swift UI/bridge 변경: `xcodegen generate`, `xcodebuild ... HostApp ...`
- Rust bridge 변경: `./scripts/build-rust-macos.sh`, `./scripts/check-no-appkit.sh`
- 렌더링 변경: `./scripts/validate-stage3-render.sh`
- core submodule 변경: `Vendor/rhwp` commit과 `rhwp-core.lock` 대조, Rust bridge 재빌드, HostApp 빌드
- 릴리스 변경: `./scripts/package-release.sh <version>`, Cask checksum 확인

검증을 실행하지 못한 경우 최종 보고서와 PR 본문에 이유를 명시한다.

## 작업 규칙

- 작업 시간의 시작과 종료는 작업지시자가 결정한다.
- Codex가 임의로 작업 범위를 확장하지 않는다.
- unrelated refactor, formatter churn, 생성물 재생성은 요청 범위에 필요할 때만 수행한다.
- `Vendor/rhwp` 내부 변경은 core 작업으로 분리한다.
- destructive git 명령은 작업지시자의 명시적 요청 없이 실행하지 않는다.
