# Issue #33 Stage 4 완료 보고서

## 타스크

- GitHub Issue: #33
- 마일스톤: M050
- 제목: Quick Look thumbnail smoke test 실패 원인 분석
- 단계: Stage 4. `AlhangeulMac` 이름 정합화

## 요약

- 작업지시자 의견에 따라 사용자 표시명은 `알한글`로 유지하고, `RhwpMac`/`rhwpmac` 계열 내부 이름을 `alhangeul-macos` 저장소명과 맞는 ASCII 이름으로 정리했다.
- Xcode project/product/executable/module 계열은 `AlhangeulMac`으로 변경했다.
- bundle identifier와 app-owned UTI는 `com.postmelee.alhangeulmac` 계열로 변경했다.
- release zip과 Homebrew Cask token/file은 `alhangeul-macos` 기준으로 변경했다.
- 새 설치본 `/Users/melee/Applications/AlhangeulMac.app` 기준으로 사용자 지정 samples 3개 모두 Finder thumbnail smoke test에 성공했다.

## 변경 파일

- `project.yml`
  - project name을 `AlhangeulMac`으로 변경했다.
  - HostApp product/executable을 `AlhangeulMac.app`/`AlhangeulMacHost`로 변경했다.
  - Quick Look/Thumbnail extension product/executable을 `AlhangeulMacPreview`, `AlhangeulMacThumbnail`로 변경했다.
  - bundle identifier를 `com.postmelee.alhangeulmac` 계열로 변경했다.
- `RhwpMac.xcodeproj` -> `AlhangeulMac.xcodeproj`
  - `project.yml` 기준으로 XcodeGen 재생성했다.
- `Sources/HostApp/Info.plist`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist`
  - app-owned UTI를 `com.postmelee.alhangeulmac.hwp`/`com.postmelee.alhangeulmac.hwpx`로 변경했다.
  - 사용자 표시명 `알한글`, `알한글 미리보기`, `알한글 썸네일`은 유지했다.
- `Sources/HostApp/Services/DocumentOpenPanel.swift`
  - 열기 패널의 app-owned UTI를 새 식별자로 변경했다.
- `Sources/HostApp/Services/ExtensionStatusModel.swift`
  - extension 상태 확인 bundle id를 새 식별자로 변경했다.
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
  - 내부 dispatch queue label을 새 bundle id 계열로 변경했다.
- `scripts/package-release.sh`
  - project/app/zip 이름을 `AlhangeulMac`/`alhangeul-macos` 기준으로 변경했다.
- `Casks/rhwp-mac.rb` -> `Casks/alhangeul-macos.rb`
  - Cask token, release asset URL, app stanza를 새 이름 기준으로 변경했다.
- `README.md`, `.github/pull_request_template.md`, `mydocs/manual/*`, `mydocs/tech/project_architecture.md`
  - 빌드, 검증, 릴리스, PR 문서의 project/app/bundle id/cask 기준을 갱신했다.
- `mydocs/plans/task_m050_33.md`, `mydocs/plans/task_m050_33_impl.md`
  - 추가 Stage 4를 반영하고 최종 보고 단계를 Stage 5로 조정했다.

## 검증

### 1. Xcode project 재생성

```bash
xcodegen generate
```

결과:

- 성공
- 생성물: `AlhangeulMac.xcodeproj`
- scheme: `HostApp`, `QLExtension`, `ThumbnailExtension`

### 2. plist lint

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
```

결과:

- `Sources/HostApp/Info.plist: OK`
- `Sources/QLExtension/Info.plist: OK`
- `Sources/ThumbnailExtension/Info.plist: OK`

### 3. Bridge 계층 규칙

```bash
./scripts/check-no-appkit.sh
```

결과:

- `OK: shared Swift code has no AppKit/UIKit dependencies`

### 4. Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

- 성공
- 산출물: `build/DerivedData/Build/Products/Debug/AlhangeulMac.app`
- embedded appex:
  - `AlhangeulMacPreview.appex`
  - `AlhangeulMacThumbnail.appex`

### 5. Release package

```bash
./scripts/package-release.sh 0.1.0
```

결과:

- 성공
- SHA256:
  - `8c6d20752417124cd479d1690fe82d8c97eab29ff59849b7c16ed482682ab1b0  alhangeul-macos-0.1.0.zip`
- zip 내부 최상위 app bundle:
  - `AlhangeulMac.app/`
- staging 산출물:
  - `build/release/AlhangeulMac.app`
  - `build/release/alhangeul-macos-0.1.0.zip`

### 6. Package 산출물 표시명과 principal class 확인

`build/release/AlhangeulMac.app/Contents/Info.plist`:

- `CFBundleDisplayName`: `알한글`
- `CFBundleName`: `알한글`
- `CFBundleExecutable`: `AlhangeulMacHost`
- `CFBundleIdentifier`: `com.postmelee.alhangeulmac`

`build/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex/Contents/Info.plist`:

- `CFBundleDisplayName`: `알한글 썸네일`
- `CFBundleName`: `알한글 썸네일`
- `CFBundleExecutable`: `AlhangeulMacThumbnail`
- `CFBundleIdentifier`: `com.postmelee.alhangeulmac.ThumbnailExtension`
- `NSExtensionPrincipalClass`: `AlhangeulMacThumbnail.HwpThumbnailProvider`

### 7. Finder thumbnail smoke test

설치/등록:

```bash
ditto build/release/AlhangeulMac.app /Users/melee/Applications/AlhangeulMac.app
lsregister -u /Users/melee/Applications/RhwpMac.app
lsregister -u /Users/melee/Applications/알한글.app
lsregister -f -R -trusted /Users/melee/Applications/AlhangeulMac.app
pluginkit -a /Users/melee/Applications/AlhangeulMac.app
pluginkit -e use -i com.postmelee.alhangeulmac.QLExtension
pluginkit -e use -i com.postmelee.alhangeulmac.ThumbnailExtension
qlmanage -r
qlmanage -r cache
```

등록 확인:

```text
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
Display Name = 알한글 썸네일
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app
```

사용자 지정 samples smoke test:

```bash
mkdir -p /tmp/rhwp-task33-stage4-ql
qlmanage -t -x -s 512 -o /tmp/rhwp-task33-stage4-ql \
  /Users/melee/Documents/projects/rhwp-mac/samples/group-drawing-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/pic-in-head-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

결과:

- `group-drawing-02.hwp`: thumbnail 1개 생성
- `pic-in-head-02.hwp`: thumbnail 1개 생성
- `basic/KTX.hwp`: thumbnail 1개 생성

생성 파일:

- `/tmp/rhwp-task33-stage4-ql/group-drawing-02.hwp.png`
- `/tmp/rhwp-task33-stage4-ql/pic-in-head-02.hwp.png`
- `/tmp/rhwp-task33-stage4-ql/KTX.hwp.png`

## 검증 중 특이사항

- sandbox 안에서 `pluginkit -mAvvv` 조회는 `Connection invalid`를 반환했지만, 권한 밖 조회에서는 새 extension 등록이 정상 확인됐다.
- sandbox 안에서 `qlmanage -t`는 `sandbox initialization failed: invalid data type of path filter`로 실패했지만, 권한 밖 실행에서는 thumbnail 생성이 정상 완료됐다.
- `mdls -name kMDItemContentType /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp`는 파일이 실제 존재함에도 `could not find`를 반환했다. Stage 4 판단은 `qlmanage -t`의 실제 thumbnail 생성 결과와 PlugInKit 등록 상태를 기준으로 했다.

## 현재 환경 상태

- `/Users/melee/Applications/AlhangeulMac.app`는 Stage 4 release staging 산출물 기준으로 설치/등록돼 있다.
- `/Users/melee/Applications/RhwpMac.app`와 `/Users/melee/Applications/알한글.app` 파일은 삭제하지 않았다.
- LaunchServices 등록은 새 `/Users/melee/Applications/AlhangeulMac.app` 기준으로 갱신했고, 기존 두 경로는 unregister를 시도했다.

## 판단

- `AlhangeulMac.app` ASCII path에서도 Stage 3에서 확인한 Quick Look/Thumbnail 안정성은 유지된다.
- 사용자 표시명 `알한글`은 유지하면서 repository/build/distribution-facing 이름을 `alhangeul-macos` 계열로 맞추는 방향이 가능하다.
- 이번 변경은 bundle identifier와 app-owned UTI까지 바꾸므로, 기존 로컬 LaunchServices/PlugInKit 캐시가 남은 환경에서는 unregister/cache reset 절차가 필요하다.

## 다음 단계

Stage 5에서 다음을 진행한다.

- 최종 검증 묶음 재확인
- 최종 결과 보고서 작성
- 오늘할일 갱신
- PR 준비 전 커밋 상태 확인

## 승인 요청

Stage 4 이름 정합화와 smoke test 검증을 완료했다. Stage 5 진행 승인을 요청한다.
