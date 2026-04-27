# Issue #22 단계 3 완료 보고서

## 작업 내용

- `RhwpDocument`에 embedded preview fast path를 감싸는 Swift 호출 경로를 추가했다.
- `HwpPageImageRenderer`를 `embedded preview 우선 -> 실패 시 기존 render tree 첫 페이지 렌더 fallback` 정책으로 정리했다.
- 실제 Finder thumbnail 동작을 막던 macOS 등록 경로 문제를 함께 정리했다.

## 코드 변경

### 1. `RhwpDocument` FFI 역할 정리

- `Sources/RhwpCoreBridge/RhwpDocument.swift`에 `RhwpEmbeddedThumbnail` 구조체를 추가했다.
- `RhwpDocument.extractEmbeddedThumbnail(from:)`를 추가해 `rhwp_extract_thumbnail` / `rhwp_free_bytes` / `rhwp_free_string` 호출과 메모리 해제를 Swift bridge 내부로 숨겼다.
- 이로써 Swift 상위 계층은 raw pointer 수명 규칙을 직접 다루지 않고 `Data + width/height + format` 형태로 embedded preview를 받게 됐다.

### 2. `HwpPageImageRenderer` fallback 정책 반영

- `Sources/Shared/HwpPageImageRenderer.swift`에서 파일 데이터를 먼저 읽고 embedded preview decode를 시도하도록 바꿨다.
- embedded preview decode 성공 시 해당 이미지를 그대로 thumbnail/preview 입력으로 사용한다.
- embedded preview가 없거나 decode에 실패하면 기존 `RhwpDocument` + render tree + `CGTreeRenderer` 경로로 첫 페이지를 렌더한다.
- `fileTooLarge` 제한은 render fallback 직전에만 적용되도록 옮겨, large file에서도 embedded preview가 있으면 fast path를 우선 사용할 수 있게 했다.

### 3. 실제 Finder 동작을 위한 macOS 번들/서명 경로 정리

- `Sources/HostApp/HostApp.entitlements`에 `com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-only`를 추가했다.
- `project.yml`의 `PRODUCT_NAME`을 ASCII 경로용 값으로 분리했다.
  - `HostApp`: `RhwpMac`
  - `QLExtension`: `RhwpMacPreview`
  - `ThumbnailExtension`: `RhwpMacThumbnail`
- 각 `Info.plist`의 `CFBundleDisplayName`은 기존 한글 표시명을 유지하고, `CFBundleName`도 명시 문자열로 고정했다.
- 결과적으로 사용자 표시명은 유지하면서, 실제 `.app` / `.appex` 경로는 ASCII가 되어 LaunchServices / ExtensionKit / Finder 경로 해석 충돌을 피하게 했다.

## 실제 원인 분석

Finder에서 thumbnail이 안 뜨던 직접 원인은 두 가지였다.

1. 초기 Debug/Release 산출물은 extension이 PlugInKit/ExtensionKit에 안정적으로 수용되지 않았다.
2. 특히 한글 bundle path를 가진 `.app` / `.appex`가 LaunchServices database에서 안정적으로 해석되지 않아,
   `com.apple.quicklook.ThumbnailsAgent`가 `not found in LS database`로 launch에 실패했다.

추가로 build 산출물 경로와 설치본 경로가 같은 bundle ID로 동시에 discovery되면, Quick Look가 build path 인스턴스를 먼저 잡는 경우가 있어 실제 설치본이 아닌 경로를 launch하려는 현상도 확인했다.

이번 단계에서는:

- 설치본을 `~/Applications/RhwpMac.app`로 고정하고
- build 산출물 `.app`는 `.app.disabled`로 바꿔 자동 discovery 후보에서 제외하고
- `pluginkit -a /Users/melee/Applications/RhwpMac.app`로 설치본을 활성 인스턴스로 재등록하는 방식으로

실제 Finder/qlmanage 경로를 안정화했다.

## 검증

### 정적/빌드 검증

- `git diff --check -- Sources/RhwpCoreBridge/RhwpDocument.swift Sources/Shared/HwpPageImageRenderer.swift Sources/HostApp/HostApp.entitlements Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist project.yml`
- `./scripts/check-no-appkit.sh`
- `xcodegen generate`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build/DerivedDataReleaseSigned CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES build`

### 시스템 등록/실동작 검증

- `pluginkit -mvv -i com.postmelee.rhwpmac.ThumbnailExtension`
  - 활성 인스턴스:
    - `/Users/melee/Applications/RhwpMac.app/Contents/PlugIns/RhwpMacThumbnail.appex`
- `qlmanage -r`
- `qlmanage -r cache`
- `qlmanage -t -x -s 512 -o /tmp /Users/melee/Documents/projects/rhwp-mac/Vendor/rhwp/samples/basic/KTX.hwp`
  - 결과:
    - `produced one thumbnail`
- Finder 실제 화면 확인
  - `/tmp/rhwp-finder-check/KTX.hwp`와 `samples` 폴더의 HWP/HWPX 파일에서 기본 아이콘이 아니라 문서 썸네일이 표시되는 것을 확인했다.

### 로그 검증

- `log show`에서 `com.postmelee.rhwpmac.ThumbnailExtension` 프로세스가 `com.apple.quicklook.ThumbnailsAgent`에 의해 실제로 launch되는 것을 확인했다.
- 최종 상태에서는 `xpcservice<com.postmelee.rhwpmac.ThumbnailExtension...>` 프로세스가 실행되고 completion까지 진행되는 로그를 확인했다.

## 판단

- Stage 2에서 추가한 FFI는 Stage 3에서 Swift bridge 내부로 안전하게 흡수됐다.
- Thumbnail 경로는 이제 embedded preview fast path와 기존 render fallback을 함께 가진다.
- 실제 배포/실사용 기준으로는 FFI 구조 개선만으로 충분하지 않았고, bundle path / sandbox / LaunchServices 등록까지 함께 맞춰야 Finder thumbnail이 동작함을 확인했다.

## 다음 단계

- 4단계에서 아키텍처/배포 문서에 이번 변경을 반영한다.
- 특히 다음 항목을 문서화한다.
  - `RhwpDocument`의 fast path / render path 책임 분리
  - Finder/Quick Look 검증 시 설치본 경로와 build 산출물 경로를 함께 두지 않는 운영 규칙
  - ASCII bundle path와 한글 표시명 분리 원칙

## 승인 요청 사항

- 이 단계 완료 기준으로 4단계(문서와 provenance 정리) 진행 승인 요청
