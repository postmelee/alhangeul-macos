# Issue #40 Stage 3 완료 보고서

## 타스크

- GitHub Issue: #40
- 마일스톤: M050
- 제목: Dock/Spotlight 표시명 한영 현지화
- 작업 브랜치: `local/task40`
- Stage: 3. 빌드 산출물과 등록 상태 검증

## 목표

Debug build와 설치본 기준으로 localized `InfoPlist.strings` 포함 여부를 확인하고, LaunchServices/PlugInKit 등록 안정성이 유지되는지 검증한다.

## 진행 내용

새 worktree에는 ignored 생성 산출물인 `Frameworks/Rhwp.xcframework`와 submodule checkout이 없었으므로 다음 준비 작업을 먼저 수행했다.

- `git submodule update --init --recursive`
- `./scripts/build-rust-macos.sh`

그 뒤 Debug build와 Release package 경로를 모두 확인했다.

## 검증

### Rust bridge 산출물 생성

```bash
./scripts/build-rust-macos.sh
```

결과:

- 성공
- `Frameworks/Rhwp.xcframework` 생성
- FFI symbol check 통과
- 생성 symbol:
  - `rhwp_close`
  - `rhwp_extract_thumbnail`
  - `rhwp_free_bytes`
  - `rhwp_free_string`
  - `rhwp_image_data`
  - `rhwp_open`
  - `rhwp_page_count`
  - `rhwp_page_size`
  - `rhwp_render_page_svg`
  - `rhwp_render_page_tree`

### Debug build

첫 시도:

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

- 실패
- 원인: 새 worktree에 `Frameworks/Rhwp.xcframework`가 없었음

재시도:

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build/DerivedDataStage3 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

- 성공
- 산출물: `build/DerivedDataStage3/Build/Products/Debug/AlhangeulMac.app`

### Debug bundle 리소스 포함 확인

```bash
find build/DerivedDataStage3/Build/Products/Debug/AlhangeulMac.app \
  -path '*InfoPlist.strings' -print | sort
```

결과:

- HostApp `ko.lproj/InfoPlist.strings`
- HostApp `en.lproj/InfoPlist.strings`
- QLExtension `ko.lproj/InfoPlist.strings`
- QLExtension `en.lproj/InfoPlist.strings`
- ThumbnailExtension `ko.lproj/InfoPlist.strings`
- ThumbnailExtension `en.lproj/InfoPlist.strings`

값 확인:

- HostApp `ko`: `알한글`
- HostApp `en`: `AlhangeulMac`
- QLExtension `ko`: `알한글 미리보기`
- QLExtension `en`: `AlhangeulMac Preview`
- ThumbnailExtension `ko`: `알한글 썸네일`
- ThumbnailExtension `en`: `AlhangeulMac Thumbnail`

### Debug 설치본 등록 확인

Debug build 산출물을 `/Users/melee/Applications/AlhangeulMac.app`에 설치하고 LaunchServices/PlugInKit 등록을 시도했다.

결과:

- 설치본의 localized 리소스 포함은 확인
- `mdls`:
  - `kMDItemCFBundleIdentifier = "com.postmelee.alhangeulmac"`
  - `kMDItemDisplayName = "AlhangeulMac.app"`
  - `kMDItemFSName = "AlhangeulMac.app"`
- PlugInKit 목록에는 Quick Look/Thumbnail extension이 노출되지 않음

추가 확인:

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 `Info.plist=not bound`, `Sealed Resources=none`인 linker-signed 상태였다.
- `codesign --force --deep --sign -`로 설치본을 ad-hoc sign해도 PlugInKit 목록에는 노출되지 않았다.
- 따라서 PlugInKit 등록 검증은 Release package 경로로 진행했다.

### Release package

```bash
./scripts/package-release.sh 0.1.0
```

결과:

- 성공
- SHA256:
  - `f248f77092e43c4f81a509e21cfd911586315b66501631f66b0dc21d09e1350b  alhangeul-macos-0.1.0.zip`
- 산출물: `build/release/AlhangeulMac.app`
- Release 산출물은 `Sign to Run Locally` 경로로 ad-hoc signing과 sealed resources가 정상 적용됨

### Release bundle 리소스 포함 확인

```bash
find build/release/AlhangeulMac.app -path '*InfoPlist.strings' -print | sort
```

결과:

- HostApp/QLExtension/ThumbnailExtension에 각각 `ko.lproj`, `en.lproj` `InfoPlist.strings` 포함

### Release 설치본 PlugInKit 등록 확인

Release 산출물을 `/Users/melee/Applications/AlhangeulMac.app`에 설치한 뒤 등록했다.

```bash
pluginkit -mAvvv | rg -i 'rhwpmac|alhangeul|알한글|postmelee'
```

결과:

- `com.postmelee.alhangeulmac.ThumbnailExtension`
  - path: `/Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex`
  - display name: `AlhangeulMac Thumbnail`
  - parent bundle: `/Users/melee/Applications/AlhangeulMac.app`
- `com.postmelee.alhangeulmac.QLExtension`
  - path: `/Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex`
  - display name: `AlhangeulMac Preview`
  - parent bundle: `/Users/melee/Applications/AlhangeulMac.app`

현재 사용자 환경에서는 영어 localization이 선택되어 PlugInKit 표시명이 영어로 노출됐다.

### 언어 선택 확인

```bash
swift -module-cache-path build/SwiftModuleCache -e '
import Foundation
let localizations = ["en", "ko"]
print(Bundle.preferredLocalizations(from: localizations, forPreferences: ["ko-KR", "en-KR"]))
print(Bundle.preferredLocalizations(from: localizations, forPreferences: ["en-KR", "ko-KR"]))
'
```

결과:

- `["ko"]`
- `["en"]`

즉, bundle이 제공하는 localization set 기준으로는 한국어 선호 환경에서 `ko`, 영어 선호 환경에서 `en`이 선택된다.

### Spotlight metadata 확인

```bash
mdls -name kMDItemDisplayName \
  -name kMDItemFSName \
  -name kMDItemCFBundleIdentifier \
  /Users/melee/Applications/AlhangeulMac.app
```

결과:

- `kMDItemCFBundleIdentifier = "com.postmelee.alhangeulmac"`
- `kMDItemDisplayName = "AlhangeulMac.app"`
- `kMDItemFSName = "AlhangeulMac.app"`

Spotlight metadata는 현재 사용자 환경과 캐시 상태 기준으로 filesystem app name을 표시했다.

### Quick Look thumbnail smoke

사용자 지정 sample 경로를 사용했다.

```bash
qlmanage -t -x -s 512 -o /tmp/rhwp-task40-stage3-ql \
  /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

결과:

- `KTX.hwp` thumbnail 1개 생성
- 생성 파일: `/tmp/rhwp-task40-stage3-ql/KTX.hwp.png`

## 결론

- localized `InfoPlist.strings`는 Debug/Release 산출물 모두에 포함됐다.
- Release 설치본 기준으로 LaunchServices/PlugInKit 등록은 유지됐다.
- 현재 사용자 환경에서는 영어 표시명이 선택되어 PlugInKit과 Spotlight metadata가 `AlhangeulMac` 계열을 보여준다.
- 한국어 환경에서 `ko` localization이 선택될 리소스 구조는 갖춰졌다.
- 실제 Dock/Finder/Spotlight의 즉시 표시명 갱신은 LaunchServices/Spotlight 캐시 영향을 받으므로 Stage 4 문서와 최종 보고서에 운영 메모로 남긴다.

## 다음 단계

Stage 4에서 README 또는 운영 문서에 다음 정책을 정리한다.

- filesystem bundle name은 `AlhangeulMac.app` 유지
- 사용자 표시명은 `InfoPlist.strings`로 `ko`/`en` 분리
- Debug `CODE_SIGNING_ALLOWED=NO` 산출물은 PlugInKit 등록 검증에 부적합하므로 Release package 또는 signing 적용 산출물을 사용
- Spotlight/Dock/Finder 표시명은 현재 사용자 언어와 캐시 상태의 영향을 받음

## 승인 요청

Stage 3 완료를 보고하며, Stage 4 진행 승인을 요청한다.
