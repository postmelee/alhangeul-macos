# Task #154 Stage 1 완료 보고서: Alhangeul rename 대상과 경계 조사

## 단계 목적

`AlhangeulMac`/`alhangeulmac`으로 남아 있는 제품 identity 사용처를 전체 목록화하고, `Alhangeul`로 변경할 대상과 유지할 `alhangeul-macos` 배포 채널명을 분리했다. 실제 rename 구현은 하지 않고 Stage 2 이후 변경 경계를 확정했다.

## 산출물

Stage 1은 조사 단계라 기존 소스와 문서 본문은 변경하지 않았다. 본 단계 산출물은 이 완료 보고서다.

점검한 주요 파일:

| 파일 | 라인 수 | 분류 |
|------|--------:|------|
| `project.yml` | 76 | 변경 필수 |
| `Sources/HostApp/Info.plist` | 176 | 변경 필수 |
| `Sources/QLExtension/Info.plist` | 51 | 변경 필수 |
| `Sources/ThumbnailExtension/Info.plist` | 47 | 변경 필수 |
| `Sources/HostApp/Services/ExtensionStatusModel.swift` | 233 | 변경 필수 |
| `Sources/HostApp/Services/DocumentOpenPanel.swift` | 35 | 변경 필수 |
| `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift` | 100 | 변경 필수 |
| `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift` | 113 | 변경 필수 |
| `Sources/HostApp/Services/DocumentFileActions.swift` | 76 | 변경 필수 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | 154 | 변경 필수 |
| `scripts/package-release.sh` | 58 | 변경 필수 |
| `scripts/release.sh` | 422 | 변경 필수 |
| `Casks/alhangeul-macos.rb` | 15 | `app` stanza 변경, token 유지 |
| `README.md` | 454 | 문서 갱신 |
| `mydocs/manual/build_run_guide.md` | 306 | 문서 갱신 |
| `mydocs/manual/release_distribution_guide.md` | 399 | 문서 갱신 |
| `mydocs/tech/project_architecture.md` | 241 | 정책 갱신 |
| `mydocs/tech/core_release_compatibility.md` | 426 | 예시 갱신 |
| `.github/copilot-instructions.md` | 26 | reviewer 기준 갱신 |

## 본문 변경 정도 / 본문 무손실 여부

- 기존 제품 소스, script, Cask, 운영 문서 본문은 변경하지 않았다.
- 조사 결과만 신규 단계 보고서에 추가했다.
- 구현계획서의 Stage 1 범위와 검증 명령은 유지했다.

## 조사 결과

### 변경 필수: Xcode identity

`project.yml`에는 project/product/executable/bundle id가 모두 `AlhangeulMac`/`alhangeulmac` 기준으로 남아 있다.

```text
project.yml:1:name: AlhangeulMac
project.yml:32:PRODUCT_NAME: AlhangeulMac
project.yml:33:EXECUTABLE_NAME: AlhangeulMacHost
project.yml:34:PRODUCT_BUNDLE_IDENTIFIER: com.postmelee.alhangeulmac
project.yml:52:PRODUCT_NAME: AlhangeulMacPreview
project.yml:54:PRODUCT_BUNDLE_IDENTIFIER: com.postmelee.alhangeulmac.QLExtension
project.yml:71:PRODUCT_NAME: AlhangeulMacThumbnail
project.yml:73:PRODUCT_BUNDLE_IDENTIFIER: com.postmelee.alhangeulmac.ThumbnailExtension
```

Stage 2에서는 다음 값으로 옮기는 것이 맞다.

- project: `Alhangeul`
- app product/executable: `Alhangeul`
- app bundle id: `com.postmelee.alhangeul`
- Quick Look product/executable: `AlhangeulPreview`
- Quick Look bundle id: `com.postmelee.alhangeul.QLExtension`
- Thumbnail product/executable: `AlhangeulThumbnail`
- Thumbnail bundle id: `com.postmelee.alhangeul.ThumbnailExtension`

`HostApp`, `QLExtension`, `ThumbnailExtension` target/scheme 이름은 역할 기반 이름이며 `AlhangeulMac` 문자열이 없으므로 유지 대상으로 둔다.

### 변경 필수: Info.plist와 localized strings

`Sources/**/Info.plist`에는 기본 bundle display/name과 app-owned UTI가 남아 있다.

```text
Sources/HostApp/Info.plist:8:AlhangeulMac
Sources/HostApp/Info.plist:40:com.postmelee.alhangeulmac.hwp
Sources/HostApp/Info.plist:76:com.postmelee.alhangeulmac.hwpx
Sources/QLExtension/Info.plist:8:AlhangeulMacPreview
Sources/QLExtension/Info.plist:35:com.postmelee.alhangeulmac.hwp
Sources/ThumbnailExtension/Info.plist:8:AlhangeulMacThumbnail
Sources/ThumbnailExtension/Info.plist:33:com.postmelee.alhangeulmac.hwp
```

영어 localized strings도 사용자 표시명 변경 대상이다.

```text
Sources/HostApp/Resources/en.lproj/InfoPlist.strings: AlhangeulMac
Sources/QLExtension/Resources/en.lproj/InfoPlist.strings: AlhangeulMac Preview
Sources/ThumbnailExtension/Resources/en.lproj/InfoPlist.strings: AlhangeulMac Thumbnail
```

한국어 localized strings는 이미 `알한글`, `알한글 미리보기`, `알한글 썸네일` 계열이므로 유지 대상으로 본다.

### 변경 필수: UTI와 internal domain 문자열

UTI identifier는 app-owned type이므로 bundle id와 함께 `com.postmelee.alhangeul.hwp`/`com.postmelee.alhangeul.hwpx`로 이동하는 것이 일관된다. HostApp exported/document type, Quick Look supported type, Thumbnail supported type, `DocumentOpenPanel` allowed type이 모두 함께 움직여야 한다.

유지 대상:

- `com.hancom.hwp`
- `com.hancom.hwpx`
- `com.haansoft.hancomofficeviewer.mac.hwp`
- `com.haansoft.hancomofficeviewer.mac.hwpx`

Swift 코드의 error domain, dispatch queue label, share directory도 변경 대상이다.

```text
ExtensionStatusModel.swift: com.postmelee.alhangeulmac.QLExtension
ExtensionStatusModel.swift: AlhangeulMacPreview.appex
DocumentOpenPanel.swift: com.postmelee.alhangeulmac.hwp
RhwpStudioDocumentSchemeHandler.swift: com.postmelee.alhangeulmac.rhwp-studio.document-scheme
RhwpStudioResourceSchemeHandler.swift: com.postmelee.alhangeulmac.rhwp-studio.resource-scheme
DocumentFileActions.swift: AlhangeulMacShare
HwpThumbnailRenderCache.swift: com.postmelee.alhangeulmac.thumbnail-cache
```

### 변경 필수: scripts와 Cask

배포 script는 Xcode project와 app bundle 이름을 직접 참조한다.

```text
scripts/package-release.sh: PROJECT_NAME="AlhangeulMac"
scripts/package-release.sh: BUILD_APP_NAME="AlhangeulMac.app"
scripts/package-release.sh: APP_NAME="AlhangeulMac.app"
scripts/release.sh: PROJECT_NAME="AlhangeulMac"
scripts/release.sh: BUILD_APP_NAME="AlhangeulMac.app"
scripts/release.sh: APP_NAME="AlhangeulMac.app"
scripts/release.sh: -volname "AlhangeulMac $VERSION"
```

Stage 3에서는 `Alhangeul.xcodeproj`, `Alhangeul.app`, DMG volume `Alhangeul <version>` 기준으로 바꿔야 한다. 다만 public DMG filename `alhangeul-macos-<version>.dmg`는 유지한다.

Cask는 token과 URL은 유지하고 app stanza만 변경한다.

```ruby
cask "alhangeul-macos" do
  app "AlhangeulMac.app"
end
```

예상 변경:

```ruby
app "Alhangeul.app"
```

### 변경 필수: tracked Xcode project

다음 generated project 파일이 git에 tracked 되어 있다.

```text
AlhangeulMac.xcodeproj/project.pbxproj
AlhangeulMac.xcodeproj/project.xcworkspace/contents.xcworkspacedata
```

`project.yml`이 원본이라는 정책은 유지하되, 현재 저장소가 generated `.xcodeproj`를 commit하고 있으므로 Stage 2에서 `xcodegen generate` 후 다음 처리가 필요하다.

- 새 `Alhangeul.xcodeproj` 생성 확인
- 기존 tracked `AlhangeulMac.xcodeproj` 제거 또는 rename 반영
- `AlhangeulMac.xcodeproj` 직접 수동 편집 금지

### 문서 갱신 대상

다음 문서는 build/run/release/Finder smoke 기준을 `Alhangeul`로 갱신해야 한다.

- `README.md`
- `.github/copilot-instructions.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/tech/core_release_compatibility.md`

Stage 4에서는 새 기준을 다음처럼 통일한다.

- project path: `Alhangeul.xcodeproj`
- debug app path: `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app`
- release app path: `build.noindex/release/Alhangeul.app`
- installed smoke path: `$HOME/Applications/Alhangeul.app`
- process check: `pgrep -x Alhangeul`
- pluginkit grep: `com.postmelee.alhangeul`

### 유지 대상

다음 값은 제품 identity rename과 분리해 유지한다.

- GitHub repository: `postmelee/alhangeul-macos`
- local repository directory name examples: `alhangeul-macos`
- Homebrew Cask token: `alhangeul-macos`
- Cask URL path and public DMG filename: `alhangeul-macos-<version>.dmg`
- zip filename: `alhangeul-macos-<version>.zip`
- `rhwp-studio` 관련 resource path
- Hancom compatibility UTI identifiers

## 검증 결과

구현계획서 Stage 1 검증을 실행했다.

```bash
rg --line-number 'AlhangeulMac|alhangeulmac|AlhangeulMacHost|AlhangeulMacPreview|AlhangeulMacThumbnail|com\.postmelee\.alhangeulmac' \
  project.yml README.md Casks scripts Sources mydocs/manual mydocs/tech .github
```

결과: `project.yml`, `Sources`, scripts, Cask, README, manual, tech 문서, `.github/copilot-instructions.md`에서 rename 대상 확인.

```bash
git ls-files | rg 'AlhangeulMac\.xcodeproj|Alhangeul\.xcodeproj'
```

결과:

```text
AlhangeulMac.xcodeproj/project.pbxproj
AlhangeulMac.xcodeproj/project.xcworkspace/contents.xcworkspacedata
```

추가 확인:

```bash
rg --files | rg 'AlhangeulMac|alhangeulmac|Alhangeul\.xcodeproj'
rg --line-number 'alhangeul-macos|alhangeul_macos|alhangeul-mac' README.md Casks scripts Sources mydocs/manual mydocs/tech .github
git diff --check
```

결과:

- 파일명 기준 `AlhangeulMac.xcodeproj`가 확인됐다.
- `alhangeul-macos`는 저장소명, GitHub URL, Cask token, DMG/zip filename 문맥으로 유지 대상임을 확인했다.
- `git diff --check` 통과.

## 잔여 위험

- `Alhangeul.xcodeproj` 생성과 기존 `AlhangeulMac.xcodeproj` 제거는 tracked generated project 처리라 Stage 2에서 변경량이 커질 수 있다.
- App Store Connect에서 `com.postmelee.alhangeul` bundle id 사용 가능 여부는 아직 확인하지 않았다.
- UTI 변경 후 LaunchServices가 기존 `com.postmelee.alhangeulmac.*`와 새 `com.postmelee.alhangeul.*`를 동시에 기억할 수 있으므로 smoke test에서 stale 등록을 주의해야 한다.
- 기존 설치본 삭제가 필요하면 작업지시자 승인 후에만 수행해야 한다.
- Task #148과 같은 release guide를 수정하므로 merge 순서에 따라 문서 conflict 가능성이 있다.

## 다음 단계 영향

Stage 2에서는 `project.yml`, Info.plist, 영어 localized strings, tracked Xcode project를 `Alhangeul` identity로 정합화한다. 이 단계 후 `project.yml`과 `Sources`에는 non-legacy `AlhangeulMac`/`alhangeulmac` 문자열이 남지 않아야 한다.

Stage 3에서는 Swift 코드, scripts, Cask를 새 identity에 맞춘다. Stage 4에서는 문서와 smoke test 기준을 새 이름으로 갱신한다.

## 승인 요청

Stage 1을 완료했다. 이 보고서 기준으로 Stage 2 `Xcode project identity와 bundle/UTI 정합화`를 진행할지 승인 요청한다.
