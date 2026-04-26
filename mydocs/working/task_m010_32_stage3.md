# Task #32 Stage 3 완료 보고서

## 단계 목적

공개 배포용 release script를 구현하고, Apple Developer Program credential 없이 가능한 검증 범위를 확인한다. 이번 단계는 script 구현과 credential 없는 rehearsal 검증까지 수행하며, release guide, README, Cask 정책 문서 보정은 Stage 4로 남긴다.

## 변경 파일

- `scripts/release.sh`
- `mydocs/orders/20260426.md`
- `mydocs/working/task_m010_32_stage3.md`

## 구현 요약

신규 `scripts/release.sh`를 추가했다.

주요 기능:

- `./scripts/release.sh [options] <version>` CLI 제공
- `--skip-notarize` rehearsal mode 지원
- `--output <dir>` 산출물 경로 override 지원
- `--keep-staging` 중간 산출물 보존 지원
- version 입력 형식 검증
- source `Info.plist`의 `CFBundleShortVersionString`과 입력 version 일치 확인
- 필수 도구 preflight
- public mode credential preflight
- Developer ID signing identity keychain 확인
- public mode 작업트리 clean 확인
- `scripts/build-rust-macos.sh --verify-lock`
- `scripts/check-no-appkit.sh`
- `xcodegen generate`
- Xcode Release build
- app signing 검증
- app notarization submit/wait와 staple 경로
- DMG 생성
- DMG signing 경로
- DMG notarization submit/wait와 staple 경로
- public mode Gatekeeper 검증 경로
- rehearsal mode DMG verify와 sha256 산출

## Script 인터페이스

사용법:

```bash
./scripts/release.sh [options] <version>
```

옵션:

```text
--skip-notarize    Build a local rehearsal DMG without notarization or staple.
--output <dir>     Write artifacts to the given directory. Defaults to build.noindex/release.
--keep-staging     Keep intermediate files after the script exits.
-h, --help         Show this help.
```

public release 환경변수:

```text
ALHANGEUL_DEVELOPER_ID_APPLICATION
ALHANGEUL_NOTARY_PROFILE
ALHANGEUL_DEVELOPER_ID_DMG
ALHANGEUL_BUILD_ROOT
```

## Public Mode 정책

`--skip-notarize`를 사용하지 않으면 public release mode로 동작한다.

필수 조건:

- `ALHANGEUL_DEVELOPER_ID_APPLICATION`
- `ALHANGEUL_NOTARY_PROFILE`
- local keychain의 Developer ID signing identity
- clean worktree

예상 산출물:

- `build.noindex/release/AlhangeulMac.app`
- `build.noindex/release/alhangeul-macos-<version>.dmg`
- `build.noindex/release/alhangeul-macos-<version>.dmg.sha256`

현재 로컬에는 Apple Developer Program credential이 없으므로 public mode 전체 실행은 하지 않았다. 대신 credential 누락이 build 전에 fail-fast 되는지 확인했다.

## Rehearsal Mode 정책

`--skip-notarize`를 사용하면 rehearsal mode로 동작한다.

특징:

- Apple notarization과 staple을 건너뛴다.
- signing identity가 없으면 `CODE_SIGNING_ALLOWED=NO`로 Release build를 수행한다.
- 산출물명에 `-rehearsal` suffix를 붙인다.
- DMG verify와 sha256 산출까지만 수행한다.
- public release나 Homebrew Cask 대상이 아니라는 경고를 출력한다.

산출물:

- `build.noindex/release/AlhangeulMac.app`
- `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg`
- `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256`

검증된 sha256:

```text
88c7595f90c0560a7ac766a9d53d551a8b31bf2bc3e123870c6e3f63252e7dfa  alhangeul-macos-0.1.0-rehearsal.dmg
```

## Stage 2 설계 대비 조정

credential 누락 검증을 더 빠르게 하기 위해 public mode에서는 credential 환경변수 확인을 clean worktree 확인보다 먼저 수행한다. 이 조정으로 작업 중에도 `./scripts/release.sh 0.1.0`이 build 전에 credential 누락 원인을 바로 알려준다.

`scripts/package-release.sh`는 수정하지 않았다. 기존 script는 개발/검증용 zip package 흐름으로 그대로 두고, public release 책임은 신규 `scripts/release.sh`로 분리했다.

## 검증 결과

문법과 shell 정적 검증:

```text
$ bash -n scripts/release.sh
결과: 통과
```

```text
$ shellcheck scripts/release.sh
결과: 통과
```

사용법 출력:

```text
$ ./scripts/release.sh --help
결과: Usage와 public release 환경변수 출력 확인
```

public mode credential 누락:

```text
$ ./scripts/release.sh 0.1.0
ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release
```

rehearsal mode:

```text
$ ./scripts/release.sh --skip-notarize 0.1.0
결과: sandbox 내부에서는 hdiutil create 단계에서 실패
원인: disk image 생성 디바이스 접근 제한으로 판단
```

```text
$ ./scripts/release.sh --skip-notarize 0.1.0
조건: sandbox 밖 실행
결과: 성공
```

rehearsal mode 성공 시 확인된 단계:

- Rust bridge artifact verify 성공
- shared Swift AppKit 의존 금지 검사 성공
- `xcodegen generate` 성공
- Release build 성공
- rehearsal DMG 생성 성공
- `hdiutil verify` 성공
- sha256 파일 생성 성공

## 잔여 위험

- public mode의 Developer ID signing, app notarization, app staple, DMG signing, DMG notarization, DMG staple, Gatekeeper 검증은 실제 Apple Developer credential 없이는 아직 실행하지 못했다.
- unsigned rehearsal build는 Finder Quick Look/Thumbnail 등록 검증이나 public distribution 보증으로 사용하면 안 된다.
- `xcodebuild`에 넘긴 Developer ID signing setting이 실제 credential 환경에서 embedded app extension까지 안정적으로 처리되는지는 credential 확보 후 별도 검증이 필요하다.
- public DMG가 생성되기 전까지 Cask sha256은 최종값으로 고정할 수 없다.

## 다음 단계

Stage 4에서는 release distribution guide, README, Cask 정책을 이번 script 기준으로 보정한다. 특히 개발용 package와 public release DMG의 역할, Apple Developer credential이 없을 때 가능한 검증 범위, Cask URL/sha256 전환 기준을 문서에 반영한다.

## 승인 요청

Stage 3 구현과 credential 없는 검증을 완료했다. 이 보고서 기준으로 Stage 4 `release distribution guide, README, Cask 정책 보정`을 진행할지 승인 요청한다.
