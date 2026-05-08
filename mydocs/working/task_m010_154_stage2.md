# Task #154 Stage 2 완료 보고서: Xcode identity와 bundle/UTI 정합화

## 단계 목적

`AlhangeulMac` 계열로 남아 있던 Xcode project, product, executable, bundle identifier, app-owned UTI, 사용자 표시명을 `Alhangeul` 계열로 정합화했다. `project.yml`을 원본으로 수정한 뒤 `xcodegen generate`로 새 `Alhangeul.xcodeproj`를 생성하고, 기존 tracked 생성물인 `AlhangeulMac.xcodeproj`는 제거 대상으로 전환했다.

## 변경 파일

### Xcode project 원본

- `project.yml`
  - project name: `Alhangeul`
  - app product/executable: `Alhangeul`
  - app bundle id: `com.postmelee.alhangeul`
  - Quick Look product/executable: `AlhangeulPreview`
  - Quick Look bundle id: `com.postmelee.alhangeul.QLExtension`
  - Thumbnail product/executable: `AlhangeulThumbnail`
  - Thumbnail bundle id: `com.postmelee.alhangeul.ThumbnailExtension`

### 생성 Xcode project

- 추가: `Alhangeul.xcodeproj/project.pbxproj`
- 추가: `Alhangeul.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- 제거: `AlhangeulMac.xcodeproj/project.pbxproj`
- 제거: `AlhangeulMac.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

`AlhangeulMac.xcodeproj`를 직접 수정하지 않고 `project.yml` 변경 후 `xcodegen generate`를 실행했다.

### bundle metadata와 UTI

- `Sources/HostApp/Info.plist`
  - 기본 표시명/이름: `Alhangeul`
  - exported UTI: `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx`
  - document type content type도 새 app-owned UTI로 변경
- `Sources/QLExtension/Info.plist`
  - 기본 표시명/이름: `AlhangeulPreview`
  - supported content type을 새 app-owned UTI로 변경
- `Sources/ThumbnailExtension/Info.plist`
  - 기본 표시명/이름: `AlhangeulThumbnail`
  - supported content type을 새 app-owned UTI로 변경
- `Sources/**/Resources/en.lproj/InfoPlist.strings`
  - 영어 사용자 표시명: `Alhangeul`, `Alhangeul Preview`, `Alhangeul Thumbnail`

Hancom 호환 UTI는 유지했다.

- `com.hancom.hwp`
- `com.hancom.hwpx`
- `com.haansoft.hancomofficeviewer.mac.hwp`
- `com.haansoft.hancomofficeviewer.mac.hwpx`

### Swift runtime identity 상수

구현계획서에서는 일부 Swift 상수를 Stage 3에 두었지만, Stage 2에서 bundle id와 UTI를 변경한 뒤 Swift runtime 상수가 old id를 가리키면 중간 상태가 불일치한다. 따라서 `Sources` 내부 identity 상수는 Stage 2에서 함께 정리했다.

- `Sources/HostApp/Services/DocumentOpenPanel.swift`
  - allowed UTI를 `com.postmelee.alhangeul.hwp/.hwpx`로 변경
- `Sources/HostApp/Services/ExtensionStatusModel.swift`
  - extension bundle id와 appex bundle name을 새 product 기준으로 변경
- `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift`
  - error domain을 `com.postmelee.alhangeul` 계열로 변경
- `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift`
  - error domain을 `com.postmelee.alhangeul` 계열로 변경
- `Sources/HostApp/Services/DocumentFileActions.swift`
  - share temp directory를 `AlhangeulShare`로 변경
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
  - dispatch queue label을 `com.postmelee.alhangeul` 계열로 변경

## 산출물 확인

`xcodebuild` 결과 Debug 산출물이 새 이름으로 생성됐다.

- app: `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app`
- Quick Look appex: `Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`
- Thumbnail appex: `Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex`

빌드된 app Info.plist에서 다음 값을 확인했다.

- `CFBundleDisplayName`: `Alhangeul`
- `CFBundleExecutable`: `Alhangeul`
- `CFBundleIdentifier`: `com.postmelee.alhangeul`
- app-owned UTI: `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx`

빌드된 extension Info.plist에서 다음 값을 확인했다.

- Quick Look bundle id: `com.postmelee.alhangeul.QLExtension`
- Quick Look principal class: `AlhangeulPreview.HwpPreviewProvider`
- Thumbnail bundle id: `com.postmelee.alhangeul.ThumbnailExtension`
- Thumbnail principal class: `AlhangeulThumbnail.HwpThumbnailProvider`

## 검증 결과

실행한 명령:

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
rg --line-number 'AlhangeulMac|alhangeulmac|AlhangeulMacHost|AlhangeulMacPreview|AlhangeulMacThumbnail|com\.postmelee\.alhangeulmac' \
  project.yml Sources Alhangeul.xcodeproj
git diff --check
```

결과:

- `plutil -lint` 통과
- `xcodegen generate` 통과
- `xcodebuild ... build` 통과
- `project.yml`, `Sources`, `Alhangeul.xcodeproj` 범위에서 old identity 문자열 없음
- `git diff --check` 통과

## 검증 환경 메모

처음 `xcodebuild`는 `Frameworks/Rhwp.xcframework`가 없는 새 worktree 상태라 실패했다. 같은 저장소 주 작업트리에 이미 생성된 gitignore 대상 `Frameworks/`를 검증용으로 복사한 뒤 다시 실행했다. sandbox 내부에서는 존재하는 `Rhwp.xcframework`를 Xcode가 찾지 못해 동일 명령을 샌드박스 밖에서 실행했고, 그 결과 빌드는 성공했다.

`Frameworks/`와 `build.noindex/`는 `.gitignore` 대상이며 커밋하지 않는다.

## 잔여 범위

Stage 3에서는 script와 Cask의 배포 산출물 이름을 정리한다.

- `scripts/package-release.sh`
- `scripts/release.sh`
- `Casks/alhangeul-macos.rb`

Stage 4에서는 README, build/run guide, release guide, architecture 문서의 경로와 smoke test 기준을 새 이름으로 갱신한다. GitHub 저장소명, Homebrew Cask token, public DMG/zip filename의 `alhangeul-macos`는 유지 대상이다.

## 승인 요청

Stage 2를 완료했다. 이 보고서 기준으로 Stage 3 `script/Cask 배포 이름 반영`을 진행할지 승인 요청한다.
