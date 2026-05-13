# Task M019 #230 Stage 2 완료보고서

## 단계 목적

같은 commit에서 `universal`, `arm64-only`, `x86_64-only` Release app bundle을 만들고, 앱/extension 실행 파일과 bundle breakdown을 같은 기준으로 측정했다.

이 단계는 local-only unsigned Release build 측정이다. public release DMG, signing, notarization, Sparkle appcast, Pages, Homebrew Cask는 변경하거나 실행하지 않았다.

## 산출물

- `mydocs/working/task_m019_230_stage2.md`
  - Stage 2 build/measurement 결과를 기록한 신규 단계 보고서
- local-only 측정 산출물
  - `build.noindex/task230/DerivedData-universal/Build/Products/Release/Alhangeul.app`
  - `build.noindex/task230/DerivedData-arm64/Build/Products/Release/Alhangeul.app`
  - `build.noindex/task230/DerivedData-x86_64/Build/Products/Release/Alhangeul.app`
- generated bridge/project 산출물
  - `Frameworks/Rhwp.xcframework`
  - `Frameworks/universal/librhwp.a`
  - `Alhangeul.xcodeproj`

## 본문 변경 정도 / 본문 무손실 여부

- 신규 단계 보고서 1건만 추가했다.
- 제품 source, release script, policy 문서, workflow는 수정하지 않았다.
- `xcodegen generate`는 실행했지만 `Alhangeul.xcodeproj`의 tracked diff는 없었다.
- `build.noindex/`와 `Frameworks/` 아래 산출물은 측정 입력이며 commit 대상이 아니다.

## Build 결과

### Rust bridge

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과:

- arm64/x86_64 Rust staticlib build 통과
- `Frameworks/universal/librhwp.a` 생성
- `Frameworks/Rhwp.xcframework` 생성
- `rhwp-core.lock` 검증 통과
- 생성 후 크기: `Frameworks/universal/librhwp.a` 약 `102M`, `Frameworks/Rhwp.xcframework` 약 `102M`

`xcodebuild -create-xcframework` 단계에서 CoreSimulatorService 관련 경고가 출력됐지만 macOS XCFramework 생성과 lock 검증은 성공했다.

### Xcode project

```bash
xcodegen generate
```

결과:

- `Alhangeul.xcodeproj` 재생성 성공
- tracked diff 없음

### Release app bundles

| variant | command 핵심 | 결과 |
|---------|--------------|------|
| universal | `ARCHS="arm64 x86_64"` | `** BUILD SUCCEEDED ** [30.393 sec]` |
| arm64-only | `ARCHS="arm64"` | `** BUILD SUCCEEDED ** [23.895 sec]` |
| x86_64-only | `ARCHS="x86_64"` | `** BUILD SUCCEEDED ** [23.135 sec]` |

각 variant는 별도 `DerivedData-*` 경로를 사용했다. Sparkle Swift Package는 각 DerivedData에서 working copy를 만들기 때문에, sandbox network 제한 상태의 첫 시도는 dependency clone에서 실패했다. 같은 `xcodebuild` 명령을 승인된 네트워크 접근으로 재실행해 build를 완료했다.

## 측정 결과

### App bundle breakdown

| variant | arch | app KiB | DMG bytes | Host exe bytes | Preview exe bytes | Thumbnail exe bytes | Resources KiB | Frameworks KiB | PlugIns KiB | 비고 |
|---------|------|---------|-----------|----------------|-------------------|---------------------|---------------|----------------|-------------|------|
| universal | `x86_64 + arm64` | `192300` | Stage 3 | `53366456` | `51450544` | `51519344` | `36784` | `2804` | `100584` | 현재 public release 구조와 같은 slice 구성 |
| arm64-only | `arm64` | `113660` | Stage 3 | `25890312` | `24941152` | `24977184` | `36784` | `2804` | `48776` | Apple Silicon 전용 후보 |
| x86_64-only | `x86_64` | `118240` | Stage 3 | `27455984` | `26501320` | `26536816` | `36784` | `2804` | `51824` | Intel Mac 전용 후보 |

### Universal 대비 절감량

| 항목 | arm64-only 절감 | arm64-only 절감률 | x86_64-only 절감 | x86_64-only 절감률 |
|------|-----------------|-------------------|------------------|--------------------|
| app bundle | `78640 KiB` | `40.9%` | `74060 KiB` | `38.5%` |
| Host executable | `27476144 bytes` | `51.5%` | `25910472 bytes` | `48.6%` |
| Preview executable | `26509392 bytes` | `51.5%` | `24949224 bytes` | `48.5%` |
| Thumbnail executable | `26542160 bytes` | `51.5%` | `24982528 bytes` | `48.5%` |
| PlugIns directory | `51808 KiB` | `51.5%` | `48760 KiB` | `48.5%` |

### 관찰

- `Resources`는 세 variant 모두 `36784 KiB`로 같다. bundled `rhwp-studio`, fonts, legal resources는 arch split으로 줄지 않는다.
- `Frameworks`는 세 variant 모두 `2804 KiB`로 같다. 이번 측정에서 Sparkle framework 추출 결과는 app bundle 내 size 차이의 주요 원인이 아니다.
- size 차이는 대부분 HostApp/Preview/Thumbnail 실행 파일과 `Contents/PlugIns`에 집중된다.
- universal Host executable은 `arm64-only + x86_64-only`보다 약간 더 크다.
  - `25890312 + 27455984 = 53346296`
  - universal Host executable `53366456`
  - lipo wrapper/align overhead 후보: `20160 bytes`
- 세 실행 파일의 arch별 절감률이 모두 약 `48.5-51.5%`로 비슷하다. 이는 Rust staticlib와 Swift/native code가 각 target executable에 architecture slice별로 들어간다는 Stage 1 가설과 맞다.
- 현 브랜치 universal app bundle `192300 KiB`는 이슈 #230의 mounted `v0.1.1` 기준선 `192680 KiB`와 거의 같은 수준이다. 조건이 완전히 같지는 않지만, 이슈의 용량 증가 진단이 현재 release build에서도 재현된다.

## Slice 및 dependency 확인

### lipo

```bash
xcrun lipo -info build.noindex/task230/DerivedData-universal/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
xcrun lipo -info build.noindex/task230/DerivedData-arm64/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
xcrun lipo -info build.noindex/task230/DerivedData-x86_64/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
```

결과:

```text
Architectures in the fat file: build.noindex/task230/DerivedData-universal/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul are: x86_64 arm64
Non-fat file: build.noindex/task230/DerivedData-arm64/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul is architecture: arm64
Non-fat file: build.noindex/task230/DerivedData-x86_64/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul is architecture: x86_64
```

측정 명령에서는 Preview/Thumbnail appex 실행 파일도 같은 방식으로 확인했다.

### otool 요약

Host executable은 `@rpath/Sparkle.framework/Versions/B/Sparkle`과 system frameworks에 동적으로 의존한다. Preview/Thumbnail extension executable은 Sparkle에 의존하지 않고 Foundation/CoreGraphics/CoreText/ImageIO 등 system frameworks 중심이다.

세 variant 모두 Rust bridge는 별도 dynamic dependency로 보이지 않는다. 현재 `Rhwp.xcframework`가 staticlib 기반으로 링크되기 때문이다.

## 검증 결과

구현계획서 Stage 2의 검증 명령을 실행했다.

```bash
./scripts/build-rust-macos.sh --verify-lock
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build.noindex/task230/DerivedData-universal \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build.noindex/task230/DerivedData-arm64 \
  ARCHS="arm64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build.noindex/task230/DerivedData-x86_64 \
  ARCHS="x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
xcrun lipo -info build.noindex/task230/DerivedData-universal/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
xcrun lipo -info build.noindex/task230/DerivedData-arm64/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
xcrun lipo -info build.noindex/task230/DerivedData-x86_64/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
git diff --check -- mydocs/working/task_m019_230_stage2.md
```

결과:

- Rust bridge verify: 통과
- Xcode project generation: 통과
- universal Release build: 통과
- arm64-only Release build: 통과
- x86_64-only Release build: 통과
- lipo slice 확인: 통과
- 보고서 `git diff --check`: 통과

## 잔여 위험

- 이번 build는 `CODE_SIGNING_ALLOWED=NO` local-only unsigned Release build다. public signed/notarized DMG와 code signature/staple 결과가 다를 수 있다.
- 각 DerivedData 경로가 Sparkle package working copy를 별도로 만들기 때문에 최초 sandbox 실행은 네트워크 제한으로 실패했고, 승인된 네트워크 접근으로 재실행했다.
- Stage 2는 app bundle과 executable 중심 측정이다. DMG 압축 후 download size 차이는 Stage 3에서 별도 측정해야 한다.
- Intel Mac 실기기에서 x86_64-only app을 실행한 smoke는 이 단계 범위가 아니다.
- arch별 build는 policy 변경 후보 검토용이며, 현재 release policy상 public artifact로 사용할 수 없다.

## 다음 단계 영향

Stage 3에서는 이 단계의 app bundle 산출물을 입력으로 DMG download size 후보를 비교한다.

우선순위:

1. 현재 plist version으로 universal `--skip-notarize` rehearsal DMG를 생성한다.
2. arm64/x86_64 app bundle을 이용해 local-only DMG 시뮬레이션을 만든다.
3. GitHub Release, Pages, Sparkle, Homebrew Cask에서 arch별 DMG를 운영할 때 바뀌는 표면을 정리한다.

## 승인 요청

Stage 2 결과를 승인하면 Stage 3 `DMG 후보와 배포 운영 영향 비교`로 진행한다.
