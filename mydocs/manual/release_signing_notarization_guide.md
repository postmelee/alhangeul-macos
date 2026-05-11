# 릴리즈 서명과 공증 가이드

## 목적

이 문서는 public DMG release에 필요한 Developer ID signing, notarization, Gatekeeper 검증 기준을 정리한다. package/DMG 생성 절차는 [`release_packaging_dmg_guide.md`](release_packaging_dmg_guide.md)를 따른다.

## 권한 원칙

- Developer ID 서명, notarization submit/wait, GitHub Actions secret/variable 변경은 작업지시자의 명시 지시가 있을 때만 수행한다.
- 인증서 private key, Apple Developer 계정, notarization credential, GitHub token은 작업지시자가 직접 관리한다.
- password, app-specific password, App Store Connect API private key, exported signing identity, Sparkle EdDSA private key, GitHub token은 저장소에 기록하지 않는다.

## Apple Developer Program 준비 상태

Apple Developer Program과 public release에 필요한 credential은 release owner가 관리한다. 비밀이 아닌 운영 식별자와 GitHub Actions 변수/secret 이름은 [`release_environment.md`](../tech/release_environment.md)에 기록한다.

매 릴리스 전에는 다음을 확인한다.

- Developer ID Application signing identity가 현재 release machine 또는 workflow keychain에서 조회되는가
- `notarytool` keychain profile 또는 workflow credential이 인증 오류 없이 동작하는가
- GitHub Actions `release` environment variable과 secret이 현재 release workflow 요구사항과 일치하는가

저장소에 기록하지 않는 값은 다음과 같다.

- Apple ID password
- app-specific password
- App Store Connect API private key(`.p8`)
- exported signing identity(`.p12`)와 password
- Keychain에 저장된 notarytool credential payload
- Sparkle EdDSA private key
- GitHub token

## Public release credential 확인

```bash
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile "$ALHANGEUL_NOTARY_PROFILE"
```

확인 기준:

- `security find-identity` 출력에 현재 `ALHANGEUL_DEVELOPER_ID_APPLICATION` 값과 일치하는 identity가 있어야 한다.
- `notarytool history`가 인증 오류 없이 실행되어야 한다.
- 제출 이력이 없으면 `No submission history.`가 나올 수 있으며 credential 검증 실패가 아니다.

## Public DMG 실행 시 환경변수

```bash
ALHANGEUL_DEVELOPER_ID_APPLICATION="<Developer ID Application signing identity>" \
ALHANGEUL_NOTARY_PROFILE="<notarytool keychain profile>" \
./scripts/release.sh <version>
```

선택 환경변수:

```text
ALHANGEUL_DEVELOPER_ID_DMG
ALHANGEUL_BUILD_ROOT
```

`ALHANGEUL_DEVELOPER_ID_DMG`를 지정하지 않으면 `ALHANGEUL_DEVELOPER_ID_APPLICATION`과 같은 identity로 DMG를 서명한다.

## 서명과 공증 검증 항목

public mode에서 확인할 항목:

- HostApp, QLExtension, ThumbnailExtension이 모두 올바르게 서명되는가
- extension bundle이 app bundle 안에 올바르게 embed되는가
- sandbox entitlement가 preview/thumbnail 동작과 충돌하지 않는가
- notarization 후 Gatekeeper에서 실행 가능한가
- stapled app과 stapled DMG가 모두 검증되는가

대표 확인 명령:

```bash
codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/alhangeul-macos-<version>.dmg
spctl --assess --type execute --verbose build.noindex/release/Alhangeul.app
spctl --assess --type open --context context:primary-signature --verbose build.noindex/release/alhangeul-macos-<version>.dmg
```

위 검증은 `scripts/release.sh` public mode가 이미 수행하는 항목을 수동으로 재확인할 때 사용한다.

## 실패 시 분리 기준

- credential 조회 실패는 `release_environment.md`의 환경 식별자와 실제 Keychain/workflow 환경을 먼저 대조한다.
- app/DMG staple 실패, Gatekeeper 차단, notarization rejection은 release report에 실제 command, 대상 파일, 오류 요약을 기록한다.
- Sparkle nested component signing, app extension entitlement, notary log 부족이 의심되면 [`release_v0_1_1_workflow_failures.md`](../troubleshootings/release_v0_1_1_workflow_failures.md)의 `v0.1.1` release workflow 실패 사례를 함께 확인한다.
- 반복 가능한 실패 증상, 재현 조건, 원인, 재발 방지 절차가 정리되면 `mydocs/troubleshootings/`에 별도 문서로 승격한다.
