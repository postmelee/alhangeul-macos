# Task #32 Stage 2 완료 보고서

## 단계 목적

release pipeline의 인터페이스, 실행 모드, credential preflight, 실패 정책을 구현 전에 확정한다. 이번 단계에서는 `scripts/release.sh`, `scripts/package-release.sh`, release guide, Cask, README 구현 변경을 하지 않는다.

현재 목표는 v0.1.0 Demo/Preview release 준비다. 따라서 Apple Developer Program credential이 없는 환경에서도 로컬 rehearsal과 missing credential 검증은 가능해야 하지만, signed/notarized public release 산출물은 만들 수 없다는 경계를 명확히 둔다.

## 설계 결정 요약

- 기존 `scripts/package-release.sh`는 개발/검증용 package script로 유지한다.
- 공개 배포용 signed/notarized pipeline은 신규 `scripts/release.sh`가 담당한다.
- 공개 배포 모드는 Developer ID Application identity와 notarytool keychain profile을 필수로 요구한다.
- credential 없는 로컬 확인은 `--skip-notarize` rehearsal 모드로만 허용한다.
- rehearsal 산출물은 public release 파일명과 다르게 만들어 실수로 Cask나 GitHub Release에 연결하지 않도록 한다.
- public release 산출물은 DMG를 기준으로 한다.
- GitHub Release 생성, Homebrew tap PR 생성, release note template 생성, Finder smoke test report 자동 첨부는 이번 issue 범위 밖의 후속 작업으로 둔다.

## Script 역할 분리

### `scripts/package-release.sh`

역할:

- Rust bridge lock verify
- `xcodegen generate`
- Xcode Release build
- app zip 생성
- sha256 출력

정책:

- 개발/검증용 package script로 남긴다.
- Developer ID signing과 notarization을 필수로 요구하지 않는다.
- Finder 통합 smoke test에 쓸 수는 있지만, public release 보증 경로로 간주하지 않는다.
- Stage 3에서는 필요한 경우 안내 문구나 signing 영향 최소화만 보정한다.

### `scripts/release.sh`

역할:

- 공개 배포용 release pipeline의 단일 진입점
- preflight
- Rust bridge lock verify
- AppKit 의존 금지 검사
- Xcode project 생성
- Release build
- Developer ID 서명 검증
- app notarization submit/wait
- app staple
- DMG 생성
- DMG 서명
- DMG notarization submit/wait
- DMG staple
- Gatekeeper 검증
- sha256 산출

정책:

- public mode는 credential 누락 시 build 전에 실패한다.
- rehearsal mode는 credential이 없어도 DMG layout과 checksum 생성까지 확인할 수 있다.
- 비밀값은 저장소와 로그에 남기지 않는다.

## CLI 인터페이스

기본 형태:

```bash
./scripts/release.sh [options] <version>
```

옵션:

```text
--skip-notarize    Apple notarization과 staple을 건너뛰는 로컬 rehearsal 모드
--output <dir>     산출물 경로 지정. 기본값은 build.noindex/release
--keep-staging     실패 후 staging directory를 보존
--help             사용법 출력
```

public release 예시:

```bash
ALHANGEUL_DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
ALHANGEUL_NOTARY_PROFILE="alhangeul-notary" \
./scripts/release.sh 0.1.0
```

credential 없는 rehearsal 예시:

```bash
./scripts/release.sh --skip-notarize 0.1.0
```

## 환경변수

repo 전용 변수명을 사용해 다른 프로젝트의 release script와 충돌하지 않게 한다.

| 변수 | 필수 여부 | 용도 |
|------|----------|------|
| `ALHANGEUL_DEVELOPER_ID_APPLICATION` | public mode 필수 | app과 embedded extension signing identity |
| `ALHANGEUL_NOTARY_PROFILE` | public mode 필수 | `xcrun notarytool` keychain profile 이름 |
| `ALHANGEUL_DEVELOPER_ID_DMG` | 선택 | DMG signing identity. 없으면 `ALHANGEUL_DEVELOPER_ID_APPLICATION` 사용 |
| `ALHANGEUL_BUILD_ROOT` | 선택 | build root override. 기본값은 `build.noindex` |

`DEVELOPMENT_TEAM`은 초기 구현의 필수 입력으로 두지 않는다. Developer ID identity와 Xcode signing 설정만으로 부족하다고 확인되면 후속 단계에서 별도 변수로 추가한다.

## 실행 모드

### Public Mode

조건:

- `--skip-notarize`를 사용하지 않는다.
- `ALHANGEUL_DEVELOPER_ID_APPLICATION`이 설정되어 있다.
- `ALHANGEUL_NOTARY_PROFILE`이 설정되어 있다.
- signing identity가 local keychain에서 조회된다.
- 작업트리가 clean 상태다.

산출물:

- `build.noindex/release/AlhangeulMac.app`
- `build.noindex/release/alhangeul-macos-<version>.dmg`
- `build.noindex/release/alhangeul-macos-<version>.dmg.sha256`

이 모드의 DMG만 GitHub Release와 Homebrew Cask 대상이 될 수 있다.

### Rehearsal Mode

조건:

- `--skip-notarize`를 사용한다.
- Apple Developer Program credential 없이도 실행 가능해야 한다.

산출물:

- `build.noindex/release/AlhangeulMac.app`
- `build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg`
- `build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg.sha256`

정책:

- notarization, staple, public Gatekeeper 검증을 수행하지 않는다.
- signing identity가 있으면 signed rehearsal을 허용할 수 있다.
- signing identity가 없으면 unsigned rehearsal로 진행한다.
- stdout/stderr에 public release가 아니라는 경고를 출력한다.
- Cask sha256이나 public release note에 사용하지 않는다.

## Preflight 순서

1. `version` 인자 형식 확인
2. output directory가 `build.noindex/` 아래인지 확인
3. public mode이면 작업트리 clean 확인
4. 필수 도구 확인
5. public mode credential 환경변수 확인
6. public mode signing identity 존재 확인
7. source version과 입력 version 일치 확인
8. `rhwp-core.lock` artifact verify
9. `./scripts/check-no-appkit.sh`
10. `xcodegen generate`

필수 도구:

- `git`
- `xcodegen`
- `xcodebuild`
- `xcrun`
- `ditto`
- `hdiutil`
- `codesign`
- `spctl`
- `shasum`
- `plutil`
- `security`

public mode 추가 도구:

- `xcrun notarytool`
- `xcrun stapler`

## Build와 Signing

public mode build는 Xcode가 app과 embedded app extension을 올바른 entitlements로 sign하도록 한다.

후보 build setting:

```text
CODE_SIGN_STYLE=Manual
CODE_SIGN_IDENTITY=<ALHANGEUL_DEVELOPER_ID_APPLICATION>
ENABLE_HARDENED_RUNTIME=YES
```

검증:

```bash
codesign --verify --deep --strict --verbose=2 AlhangeulMac.app
codesign --display --verbose=4 AlhangeulMac.app
codesign --verify --strict --verbose=2 AlhangeulMac.app/Contents/PlugIns/*.appex
```

rehearsal mode에서 signing identity가 없을 때는 다음 기준으로 build한다.

```text
CODE_SIGNING_ALLOWED=NO
```

이 경우 산출물은 public release로 취급하지 않는다.

## Notarization과 Staple

public mode 순서:

1. app bundle을 `ditto -c -k --keepParent`로 notarization submit용 zip으로 만든다.
2. `xcrun notarytool submit <app.zip> --wait --keychain-profile <profile>`을 실행한다.
3. app bundle에 `xcrun stapler staple`을 실행한다.
4. stapled app으로 DMG를 생성한다.
5. DMG에 `codesign --sign`을 실행한다.
6. `xcrun notarytool submit <dmg> --wait --keychain-profile <profile>`을 실행한다.
7. DMG에 `xcrun stapler staple`을 실행한다.

이번 issue는 GitHub Actions나 원격 release upload를 포함하지 않으므로 notarytool credential은 local keychain profile을 전제로 한다.

## DMG 생성

DMG staging 구조:

```text
AlhangeulMac.app
Applications -> /Applications
```

생성 후보:

```bash
hdiutil create \
  -volname "AlhangeulMac <version>" \
  -srcfolder <dmg-staging-dir> \
  -format UDZO \
  -ov \
  <output-dmg>
```

정책:

- DMG 안의 app filesystem name은 `AlhangeulMac.app`을 유지한다.
- 사용자 표시명은 localized `InfoPlist.strings`가 담당한다.
- 첫 구현에서는 배경 이미지나 Finder window layout 커스터마이즈를 넣지 않는다.

## Gatekeeper와 Checksum 검증

public mode 검증:

```bash
spctl --assess --type execute --verbose AlhangeulMac.app
spctl --assess --type open --context context:primary-signature --verbose alhangeul-macos-<version>.dmg
shasum -a 256 alhangeul-macos-<version>.dmg > alhangeul-macos-<version>.dmg.sha256
```

rehearsal mode 검증:

```bash
hdiutil verify alhangeul-macos-<version>-rehearsal.dmg
shasum -a 256 alhangeul-macos-<version>-rehearsal.dmg > alhangeul-macos-<version>-rehearsal.dmg.sha256
```

## Cask 정책

Stage 4에서 `Casks/alhangeul-macos.rb`는 public release 산출물 정책에 맞춰 보정한다.

결정 기준:

- public release 대상은 `alhangeul-macos-<version>.dmg`다.
- rehearsal DMG는 Cask URL이 가리키면 안 된다.
- paid Apple Developer credential로 signed/notarized DMG를 만든 뒤에는 Cask sha256을 실제 digest로 고정한다.
- 실제 release artifact가 없는 동안 `sha256 :no_check`를 유지할지, 문서에서 교체 절차만 안내할지는 Stage 4에서 현재 배포 시점에 맞춰 결정한다.

## 문서 정책

Stage 4 문서 보강 방향:

- `release_distribution_guide.md`
  - 개발용 package와 public release pipeline 분리 설명
  - Apple Developer Program credential 없을 때 가능한 검증 범위 설명
  - `scripts/release.sh` 실행 예시
  - public mode와 rehearsal mode 산출물 차이
  - Cask sha256 갱신 절차
- `README.md`
  - 공개 배포 절차 상세를 늘리지 않고 release guide로 연결
  - Demo/Preview release라는 현재 목표만 간결히 반영

## Error 정책

script는 실패 시 non-zero로 종료하고 `ERROR:` prefix를 사용한다. public release가 아닌 rehearsal 경고에는 `WARN:` prefix를 사용한다.

필수 error 예시:

```text
ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release.
ERROR: ALHANGEUL_NOTARY_PROFILE is required for public release.
WARN: Apple notarization is skipped. This rehearsal artifact is not a public release.
ERROR: input version 0.1.1 does not match CFBundleShortVersionString 0.1.0.
ERROR: output directory must be under build.noindex unless explicitly overridden by ALHANGEUL_BUILD_ROOT.
```

비밀값은 출력하지 않는다. identity 이름과 keychain profile 이름은 credential 자체가 아니므로 진단을 위해 표시할 수 있지만, notarytool 계정 정보나 password는 다루지 않는다.

## Stage 3 구현 범위

Stage 3에서 구현할 항목:

- 신규 `scripts/release.sh`
- `scripts/package-release.sh` 경계 보정이 필요한 경우 최소 변경
- `bash -n`과 `--help` 동작 확인
- public mode missing credential fail-fast 확인
- rehearsal mode가 public artifact와 다른 파일명으로 DMG/checksum을 만드는지 확인

Stage 3에서 하지 않을 항목:

- 실제 Apple notarization submit
- GitHub Release 생성
- Homebrew tap PR 생성
- release note 자동 생성
- Finder smoke test 결과 자동 첨부

## 검증 결과

Stage 2는 설계 문서 작성 단계이므로 구현 검증은 수행하지 않았다. 문서 산출 후 다음 정적 검증만 수행한다.

```text
git diff --check
rg --line-number '<직접 언급 금지 용어>' mydocs/working/task_m010_32_stage2.md mydocs/orders/20260426.md
```

## 잔여 위험

- Developer ID signing은 실제 인증서, keychain, Xcode signing 동작에 의존하므로 Stage 3 구현 후에도 credential 없는 환경에서는 public mode 전체 검증이 불가능하다.
- `xcodebuild` signing setting만으로 app extension까지 Developer ID signing이 안정적으로 처리되지 않으면 후속 보정이 필요하다.
- Hardened Runtime setting이 script 인자로 충분하지 않으면 `project.yml` 설정 보정이 필요할 수 있다.
- Cask sha256은 실제 public DMG 산출물이 있어야 최종값으로 고정할 수 있다.

## 다음 단계

Stage 3에서는 이 설계에 따라 `scripts/release.sh`를 구현하고, credential 없는 환경에서 가능한 help/missing credential/rehearsal 검증을 수행한다.

## 승인 요청

Stage 2 설계를 완료했다. 이 보고서 기준으로 Stage 3 `공개 배포용 release script 구현과 개발용 package script 경계 보정`을 진행할지 승인 요청한다.
