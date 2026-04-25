# Issue #29 Stage 5 완료 보고서

## 단계 목적

`rhwp-core.lock` v2 산출물 provenance 검증 사용법을 문서화하고 전체 검증을 수행한다.

## 변경 내용

### README 갱신

`README.md`에 다음 내용을 반영했다.

- `./scripts/build-rust-macos.sh --update-lock`
- `./scripts/build-rust-macos.sh --verify-lock`
- 일반 build는 lock을 수정하지 않는다는 정책
- 검증 대상 artifact
  - `Frameworks/universal/librhwp.a`
  - `Frameworks/generated_rhwp.h`
- `rhwp-core.lock`이 core commit과 Rust bridge 산출물 provenance를 기록한다는 설명
- Debug app 경로를 현재 product name인 `RhwpMac.app`으로 정정

### 빌드/실행 가이드 갱신

`mydocs/manual/build_run_guide.md`에 lock update/verify 사용법과 검증 대상을 추가했다.

### 릴리스/배포 가이드 갱신

`mydocs/manual/release_distribution_guide.md`에 다음 내용을 반영했다.

- package 전 `./scripts/build-rust-macos.sh --verify-lock` 필수화
- package 산출물 경로를 `build.noindex/release`로 정정
- package 대상 app bundle을 `RhwpMac.app`으로 정정
- lock 검증 실패 시 app build와 zip 생성을 시작하지 않는다는 정책
- 릴리스 체크리스트에 lock verify 항목 추가

### core submodule 운영 가이드 갱신

`mydocs/manual/core_submodule_operation_guide.md`에 core 갱신 후 다음 흐름을 반영했다.

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
```

### Homebrew Cask 초안 갱신

package zip 안의 app bundle 이름이 `RhwpMac.app`이므로 `Casks/rhwp-mac.rb`의 `app` stanza도 `RhwpMac.app`으로 정정했다.

### lock 최종 갱신

최종 검증 과정에서 `./scripts/build-rust-macos.sh --update-lock`을 실행해 `built_at`을 갱신했다.

현재 기록:

- `built_at`: `2026-04-25T00:30:08Z`
- `Frameworks/universal/librhwp.a`
  - sha256: `725b65ad445660292bb1a5f2a0f9107ff810e65a699ade78e0a3b26dd901dd50`
  - size: `102627384`
- `Frameworks/generated_rhwp.h`
  - sha256: `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5`
  - size: `1349`

## 전체 검증

### Rust bridge lock update

```bash
./scripts/build-rust-macos.sh --update-lock
```

결과: 통과.

### Rust bridge lock verify

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과.

확인된 출력:

```text
Verified: /private/tmp/rhwp-mac-task29/rhwp-core.lock
```

### Rust bridge 기본 build

```bash
./scripts/build-rust-macos.sh
```

결과: 통과.

### Shared Swift bridge 검사

```bash
./scripts/check-no-appkit.sh
```

결과: 통과.

확인된 출력:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### Xcode project 생성

```bash
xcodegen generate
```

결과: 통과.

### HostApp Debug build

```bash
xcodebuild -project RhwpMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: 통과.

확인된 출력:

```text
** BUILD SUCCEEDED **
```

### package release smoke test

```bash
./scripts/package-release.sh 0.0.0-test
```

결과: 통과.

확인된 흐름:

- package 전 `--verify-lock` 실행
- `RhwpMac.app` Release build 성공
- `build.noindex/release/rhwp-mac-0.0.0-test.zip` 생성

확인된 zip sha256:

```text
384ba0a87e1e49c3d95020481eb94a9289b29816ca4a2441df25f8ef33e7c0fb
```

### 직접 hash 확인

```bash
shasum -a 256 build.noindex/release/rhwp-mac-0.0.0-test.zip Frameworks/universal/librhwp.a Frameworks/generated_rhwp.h
```

결과: lock과 산출물 hash 일치.

## 참고 사항

검증 중 `xcodebuild`가 CoreSimulatorService 관련 경고를 반복 출력했다. macOS app build와 XCFramework/package 생성은 모두 exit code 0으로 성공했으므로 이번 작업의 blocker로 보지 않는다.

## 생성된 로컬 산출물

다음 경로는 `.gitignore` 대상이며 커밋하지 않는다.

- `Frameworks/`
- `RustBridge/target/`
- `build/`
- `build.noindex/`

## 다음 단계

최종 결과 보고서 기준으로 작업지시자 승인 후 PR 생성 절차로 진행한다.
