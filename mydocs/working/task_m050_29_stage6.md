# Issue #29 Stage 6 완료 보고서

## 단계 목적

최신 `devel` 기준으로 `local/task29`를 갱신하고, PR #41의 이름 변경(`AlhangeulMac`/`알한글`)과 #29 작업 결과가 충돌하지 않는지 점검한다.

## 수행 내용

- `origin/devel`을 fetch한 뒤 `local/task29`에 병합했다.
- 병합 충돌을 해결하면서 최신 저장소 기준의 이름을 우선 적용했다.
- #29에서 추가한 lock 검증 흐름은 유지했다.
- #29 작업 문서에 남아 있던 이전 `RhwpMac` 기준의 현재 경로 설명을 `AlhangeulMac`/`alhangeul-macos` 기준으로 정정했다.

## 충돌 해결 결과

다음 파일에서 충돌을 해결했다.

| 파일 | 해결 기준 |
|------|-----------|
| `Casks/alhangeul-macos.rb` | app stanza를 `AlhangeulMac.app`으로 유지 |
| `README.md` | Debug app 경로를 `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app`으로 유지 |
| `mydocs/manual/build_run_guide.md` | 최신 `build.noindex`와 `AlhangeulMac.app` 기준 유지 |
| `mydocs/manual/release_distribution_guide.md` | package zip `alhangeul-macos-<version>.zip`, app `AlhangeulMac.app`, bundle id `com.postmelee.alhangeulmac` 기준 유지 |
| `mydocs/orders/20260425.md` | 최신 `devel`의 완료 작업 행을 유지하고 #29 상태를 보정 |
| `scripts/package-release.sh` | `AlhangeulMac` package 구조를 유지하면서 package 전 `--verify-lock` 호출을 유지 |

## 이름 기준 점검

현재 운용 파일 기준으로 다음 이름을 사용한다.

- Xcode project: `AlhangeulMac.xcodeproj`
- app bundle: `AlhangeulMac.app`
- Quick Look extension: `AlhangeulMacPreview.appex`
- Thumbnail extension: `AlhangeulMacThumbnail.appex`
- package zip: `alhangeul-macos-<version>.zip`
- Homebrew Cask: `Casks/alhangeul-macos.rb`
- bundle id prefix: `com.postmelee.alhangeulmac`
- 사용자 표시명: localized `InfoPlist.strings`의 `알한글`

`RhwpMac.app`과 `알한글.app`은 현재 설치본 이름이 아니라 이전 이름 설치본이 discovery 충돌을 일으킬 수 있는 경우의 정리 대상으로만 문서에 남겼다.

## 검증 결과

통과:

```bash
rg -n "<<<<<<<|=======|>>>>>>>" -g '!Vendor/**'
git diff --cached --check
git diff --check
bash -n scripts/build-rust-macos.sh
bash -n scripts/package-release.sh
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
plutil -lint Sources/*/Resources/*/InfoPlist.strings
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/package-release.sh 0.0.0-test
```

최신 package smoke test 산출물:

- `build.noindex/release/alhangeul-macos-0.0.0-test.zip`
- sha256: `0ff5b4b3963f09106655de8bd62f7ceba07f00e1ffc2bc825b981bac03a89143`

lock artifact hash:

| path | sha256 |
|------|--------|
| `Frameworks/universal/librhwp.a` | `725b65ad445660292bb1a5f2a0f9107ff810e65a699ade78e0a3b26dd901dd50` |
| `Frameworks/generated_rhwp.h` | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` |

## 참고 사항

`xcodebuild`와 `xcodebuild -create-xcframework`에서 CoreSimulatorService 관련 경고가 출력되었다. macOS 대상 빌드와 package 생성은 모두 exit code 0으로 성공했으며, 이번 작업 범위에서는 산출물 생성 실패나 lock 검증 실패로 이어지지 않았다.

## 완료 판단

최신 `devel` 기준 이름 변경과 #29 lock 검증 변경 사이의 직접 충돌은 해소했다. 현재 운용 파일은 `AlhangeulMac`/`alhangeul-macos` 기준으로 정렬되어 있다.
