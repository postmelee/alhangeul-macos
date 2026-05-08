# Task #154 Stage 3 완료 보고서: 배포 스크립트와 Cask rename 반영

## 단계 목적

Stage 2에서 생성된 `Alhangeul.xcodeproj`와 `Alhangeul.app` 산출물 이름에 맞춰 배포 스크립트와 Homebrew Cask의 app stanza를 갱신했다. GitHub 저장소명, Cask token, public DMG/zip 파일명인 `alhangeul-macos`는 유지했다.

## 변경 파일

### `scripts/package-release.sh`

- `PROJECT_NAME`: `Alhangeul`
- `BUILD_APP_NAME`: `Alhangeul.app`
- `APP_NAME`: `Alhangeul.app`
- release build directory에 남는 appex/swiftmodule cleanup glob을 `Alhangeul*.appex`, `Alhangeul*.swiftmodule` 기준으로 변경

zip 파일명은 기존 정책대로 유지했다.

- `alhangeul-macos-<version>.zip`

### `scripts/release.sh`

- `PROJECT_NAME`: `Alhangeul`
- `BUILD_APP_NAME`: `Alhangeul.app`
- `APP_NAME`: `Alhangeul.app`
- DMG volume name: `Alhangeul <version>`

public DMG 파일명은 기존 정책대로 유지했다.

- public release: `alhangeul-macos-<version>.dmg`
- rehearsal: `alhangeul-macos-<version>-rehearsal.dmg`

### `Casks/alhangeul-macos.rb`

- Cask token은 `alhangeul-macos` 유지
- URL도 GitHub release 파일명 정책에 맞춰 유지
- app stanza만 `app "Alhangeul.app"`로 변경

## 검증 결과

실행한 명령:

```bash
bash -n scripts/package-release.sh scripts/release.sh
./scripts/release.sh --help
ruby -c Casks/alhangeul-macos.rb
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
rg --line-number 'AlhangeulMac|alhangeulmac|AlhangeulMacHost|AlhangeulMacPreview|AlhangeulMacThumbnail|com\.postmelee\.alhangeulmac' \
  scripts Casks project.yml Sources Alhangeul.xcodeproj
git diff --check
```

결과:

- script 문법 검사 통과
- release script help 출력 정상
- Cask Ruby syntax 검사 통과
- Debug build 성공
- `scripts`, `Casks`, `project.yml`, `Sources`, `Alhangeul.xcodeproj` 범위에서 old identity 문자열 없음
- `git diff --check` 통과

## 수행하지 않은 작업

- 실제 public release, notarization submission, GitHub Release upload는 수행하지 않았다.
- `./scripts/release.sh --skip-notarize 0.1.0` rehearsal은 최종 검증 단계에서 수행할 수 있다.
- Homebrew tap 반영은 이 task의 소스 변경 범위 밖이며, Task #148의 배포 절차와 이어진다.

## 잔여 범위

Stage 4에서는 README와 manual/tech 문서의 build/run/release/smoke test 기준을 `Alhangeul.xcodeproj`, `Alhangeul.app`, `com.postmelee.alhangeul` 기준으로 갱신한다. legacy cleanup 문맥을 제외하면 문서에서도 `AlhangeulMac` 계열 문자열을 제거한다.

## 승인 요청

Stage 3을 완료했다. 이 보고서 기준으로 Stage 4 `문서와 smoke test 기준 갱신`을 진행할지 승인 요청한다.
