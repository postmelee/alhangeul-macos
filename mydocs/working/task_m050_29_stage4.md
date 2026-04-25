# Issue #29 Stage 4 완료 보고서

## 단계 목적

`scripts/package-release.sh`가 package 생성 전에 Rust bridge 산출물 lock 검증을 수행하도록 연동한다.

## 변경 내용

### package 전 lock verify 연동

`scripts/package-release.sh`가 기존에는 다음 명령을 실행했다.

```bash
./scripts/build-rust-macos.sh
```

이를 다음 명령으로 변경했다.

```bash
./scripts/build-rust-macos.sh --verify-lock
```

따라서 Rust bridge 산출물과 `rhwp-core.lock`이 일치하지 않으면 `xcodegen generate`, Release app build, zip 생성으로 진행하지 않는다.

### release 산출물 경로 조정

기존 산출물 경로:

```text
build/release
```

변경 후 산출물 경로:

```text
build.noindex/release
```

이 경로는 Finder/Spotlight discovery 혼선을 줄이기 위한 repository 운영 규칙에 맞춘 것이다.

### DerivedData 경로 고정

초기 검증에서 `xcodebuild`가 기본 DerivedData 경로인 `~/Library/Developer/Xcode/DerivedData`에 쓰려다 sandbox 권한 오류로 실패했다.

이를 피하고 package build를 재현 가능하게 하기 위해 다음 경로를 명시했다.

```text
build.noindex/DerivedDataRelease
```

### app bundle 이름 정정

`project.yml`의 HostApp `PRODUCT_NAME`은 현재 `RhwpMac`이다. 따라서 package script의 app bundle 확인 대상도 다음과 같이 맞췄다.

```text
RhwpMac.app
```

기존 `알한글.app`은 현재 build product name과 맞지 않았다.

### `.gitignore` 갱신

`build.noindex/`는 재생성 가능한 package/build 산출물 경로이므로 `.gitignore`에 추가했다.

## 검증

### shell 문법 검사

```bash
bash -n scripts/package-release.sh
```

결과: 통과.

### diff whitespace 검사

```bash
git diff --check -- scripts/package-release.sh
```

결과: 통과.

### package release smoke test

```bash
./scripts/package-release.sh 0.0.0-test
```

결과: 통과.

확인된 흐름:

1. `./scripts/build-rust-macos.sh --verify-lock` 실행
2. `Verified: /private/tmp/rhwp-mac-task29/rhwp-core.lock` 출력 확인
3. `xcodegen generate` 성공
4. Release `RhwpMac.app` build 성공
5. `build.noindex/release/rhwp-mac-0.0.0-test.zip` 생성
6. zip sha256 출력

확인된 zip sha256:

```text
a68402288ad3a447d626758d80ded4d7569f41a3bc767135681ee2603ec8c1dd
```

### 산출물 확인

```bash
ls -la build.noindex/release
shasum -a 256 build.noindex/release/rhwp-mac-0.0.0-test.zip
```

주요 산출물:

- `build.noindex/release/RhwpMac.app`
- `build.noindex/release/RhwpMacPreview.appex`
- `build.noindex/release/RhwpMacThumbnail.appex`
- `build.noindex/release/rhwp-mac-0.0.0-test.zip`

## 참고 사항

검증 중 `xcodebuild`가 CoreSimulatorService 관련 경고를 출력했다. 이번 단계에서는 macOS app build와 XCFramework/package 생성이 성공했고 exit code도 성공이므로 blocker로 보지 않는다.

초기 package 검증은 기본 DerivedData 경로 권한 문제로 실패했다. `-derivedDataPath build.noindex/DerivedDataRelease`를 명시한 뒤 동일 명령이 성공했다.

## 생성된 로컬 산출물

다음 경로는 `.gitignore` 대상이며 커밋하지 않는다.

- `Frameworks/`
- `RustBridge/target/`
- `build.noindex/`

## 다음 단계

Stage 5에서 README와 manual 문서를 갱신하고 전체 검증을 수행한다.

## 승인 요청

이 Stage 4 완료 보고서 기준으로 Stage 5를 진행할지 승인 요청한다.
