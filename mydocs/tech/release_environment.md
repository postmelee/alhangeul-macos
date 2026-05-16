# 릴리즈 환경 스냅샷

## 목적

이 문서는 알한글 public release에 필요한 비밀이 아닌 운영 환경 식별자를 기록한다. 배포 절차 자체는 [`../manual/release_distribution_guide.md`](../manual/release_distribution_guide.md)를 따른다.

인증서 private key, password, app-specific password, App Store Connect API private key, exported signing identity, Sparkle EdDSA private key, GitHub token은 이 문서와 저장소에 기록하지 않는다.

## 현재 운영 식별자

2026-04-29 기준으로 확인된 값이다. 값이 바뀌면 이 문서와 GitHub Actions release environment variable을 함께 점검한다.

| 항목 | 값 |
|------|----|
| Apple Team ID | `XH6JHKYXV8` |
| Developer ID Application signing identity | `Developer ID Application: Taegyu Lee (XH6JHKYXV8)` |
| notarytool keychain profile | `alhangeul-notary` |
| GitHub repository | `postmelee/alhangeul-macos` |
| Release environment | `release` |
| GitHub Pages source | `main` / `docs` |
| Pages branch variable | `ALHANGEUL_PAGES_BRANCH` |
| Pages branch current value | `main` |
| Pages branch workflow fallback | `main` |

## GitHub Actions 변수와 secret

`Release Publish DMG` workflow는 다음 값을 사용한다.

비밀이 아닌 repository/environment variable 후보:

- `ALHANGEUL_DEVELOPER_ID_APPLICATION`
- `ALHANGEUL_DEVELOPER_ID_DMG`
- `ALHANGEUL_NOTARY_PROFILE`
- `APPLE_TEAM_ID`
- `ALHANGEUL_PAGES_BRANCH`

secret:

- `DEVELOPER_ID_APPLICATION_P12_BASE64`
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
- `NOTARY_APPLE_ID`
- `NOTARY_APP_SPECIFIC_PASSWORD`
- `RELEASE_KEYCHAIN_PASSWORD`
- `SPARKLE_ED_PRIVATE_KEY`
- `APPLE_TEAM_ID`은 secret으로도 제공될 수 있지만, Team ID 자체는 비밀로 취급하지 않는다.

## 로컬 확인 기록

2026-04-29 기준 다음이 확인되었다.

- Developer ID Application 인증서를 `로그인` Keychain에 설치했다.
- `security find-identity -v -p codesigning`에서 Developer ID Application signing identity를 확인했다.
- `xcrun notarytool store-credentials "alhangeul-notary" --apple-id <Apple ID> --team-id "XH6JHKYXV8"`로 credential을 Keychain에 저장했다.
- `xcrun notarytool history --keychain-profile "alhangeul-notary"`가 credential validation을 통과했고, 당시 notarization submission history는 없었다.

2026-05-10 기준 다음이 확인되었다.

- GitHub Pages source는 `main` branch의 `/docs` 경로다.
- `release` environment variable `ALHANGEUL_PAGES_BRANCH` 값은 `main`이다.

## 기록 금지 항목

- Apple ID password
- app-specific password
- App Store Connect API private key (`.p8`)
- exported signing identity (`.p12`)와 password
- Keychain에 저장된 notarytool credential payload
- Sparkle EdDSA private key
- GitHub token

## 갱신 기준

- signing identity 표시명, Team ID, notary profile name이 바뀌면 이 문서를 갱신한다.
- GitHub Actions 변수 이름이나 release environment가 바뀌면 이 문서를 갱신한다.
- credential 자체가 교체되어도 비밀 값은 기록하지 않고, 검증 명령의 통과 여부만 release report에 기록한다.
