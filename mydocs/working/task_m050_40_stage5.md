# Issue #40 Stage 5 완료 보고서

## 타스크

- GitHub Issue: #40
- 마일스톤: M050
- 제목: Dock/Spotlight 표시명 한영 현지화
- 작업 브랜치: `local/task40`

## 목적

Stage 1-4에서 localized `InfoPlist.strings`를 추가했지만 실제 Spotlight에서는 `AlhangeulMac`으로만 검색되는 문제가 남았다. Apple bundle 표시명 규칙과 카카오톡 설치본 구조를 비교해, 기본 `Info.plist` 표시명과 filesystem bundle name의 불일치를 보정한다.

## 원인 분석

카카오톡 설치본은 다음 구조를 사용한다.

- 실제 app path: `KakaoTalk.app`
- 기본 `Info.plist`: `CFBundleDisplayName = KakaoTalk`, `CFBundleName = KakaoTalk`, `LSHasLocalizedDisplayName = true`
- `ko.lproj/InfoPlist.strings`: `CFBundleDisplayName = 카카오톡`, `CFBundleName = 카카오톡`

반면 Stage 1-4 상태의 알한글은 실제 app path가 `AlhangeulMac.app`인데 기본 `Info.plist` 값이 `알한글`이었다. 이 상태는 기본 표시명과 실제 filesystem name이 불일치하므로 Finder/Spotlight가 localized 표시명을 신뢰하지 않고 filesystem name 쪽으로 fallback할 수 있다.

참조:

- Apple `Core Foundation Keys`의 `CFBundleDisplayName` 설명: localized bundle name을 지원할 때 `Info.plist`와 언어별 `InfoPlist.strings`에 키를 포함해야 하며, macOS Finder는 localized name 표시 전에 기본 표시명과 실제 filesystem name을 비교한다.
- Apple `Display Names` 문서: localized display name을 지원하는 앱은 `LSHasLocalizedDisplayName`을 포함하는 것이 권장된다.

## 변경 내용

### HostApp

- `Sources/HostApp/Info.plist`
  - `CFBundleDisplayName`: `알한글` -> `AlhangeulMac`
  - `CFBundleName`: `알한글` -> `AlhangeulMac`
  - `LSHasLocalizedDisplayName = true` 추가
- `ko.lproj/InfoPlist.strings`의 `알한글`은 유지
- `en.lproj/InfoPlist.strings`의 `AlhangeulMac`은 유지

### Quick Look extension

- `Sources/QLExtension/Info.plist`
  - `CFBundleDisplayName`: `알한글 미리보기` -> `AlhangeulMacPreview`
  - `CFBundleName`: `알한글 미리보기` -> `AlhangeulMacPreview`
  - `LSHasLocalizedDisplayName = true` 추가
- `ko.lproj/InfoPlist.strings`의 `알한글 미리보기`는 유지

### Thumbnail extension

- `Sources/ThumbnailExtension/Info.plist`
  - `CFBundleDisplayName`: `알한글 썸네일` -> `AlhangeulMacThumbnail`
  - `CFBundleName`: `알한글 썸네일` -> `AlhangeulMacThumbnail`
  - `LSHasLocalizedDisplayName = true` 추가
- `ko.lproj/InfoPlist.strings`의 `알한글 썸네일`은 유지

## 문서 갱신

- `AGENTS.md`: 표시명 현지화 기준을 강제 규칙에 추가
- `README.md`: 기본 plist와 localized resource 역할 분리 설명 추가
- `mydocs/manual/build_run_guide.md`: Finder/Spotlight 표시명 검증 기준 추가
- `mydocs/manual/release_distribution_guide.md`: 배포 전 표시명 확인 기준 추가
- `mydocs/tech/project_architecture.md`: 프로젝트 설정 경계에 기본 plist name 정책 추가
- `mydocs/troubleshootings/task_m050_40_quicklook_thumbnail_registration_validation.md`: 재발 방지 원인 분석과 증상별 판단표 갱신

## 검증

### 정적 검증

```bash
plutil -lint Sources/HostApp/Info.plist \
  Sources/QLExtension/Info.plist \
  Sources/ThumbnailExtension/Info.plist \
  Sources/HostApp/Resources/ko.lproj/InfoPlist.strings \
  Sources/HostApp/Resources/en.lproj/InfoPlist.strings \
  Sources/QLExtension/Resources/ko.lproj/InfoPlist.strings \
  Sources/QLExtension/Resources/en.lproj/InfoPlist.strings \
  Sources/ThumbnailExtension/Resources/ko.lproj/InfoPlist.strings \
  Sources/ThumbnailExtension/Resources/en.lproj/InfoPlist.strings
plutil -lint AlhangeulMac.xcodeproj/project.pbxproj
git diff --check
```

결과:

- 모두 성공

### Release package

```bash
xcodegen generate
./scripts/package-release.sh 0.1.0
```

결과:

- 성공
- release zip SHA256:
  - `3b26f59e5c2adc581d143b1573dda3263a3e38bd498e607589a177d6f66558e5  alhangeul-macos-0.1.0.zip`

### 설치본 표시명

설치본:

- `/Users/melee/Applications/AlhangeulMac.app`

확인 결과:

- `Info.plist`
  - `CFBundleDisplayName = AlhangeulMac`
  - `CFBundleName = AlhangeulMac`
  - `LSHasLocalizedDisplayName = true`
- `ko.lproj/InfoPlist.strings`
  - `CFBundleDisplayName = 알한글`
  - `CFBundleName = 알한글`
- `mdls`
  - `kMDItemDisplayName = 알한글.app`
  - `kMDItemFSName = AlhangeulMac.app`
  - `kMDItemCFBundleIdentifier = com.postmelee.alhangeulmac`

### Spotlight 검색

```bash
mdfind -onlyin /Users/melee/Applications 알한글
mdfind -onlyin /Users/melee/Applications AlhangeulMac
mdfind 'kMDItemDisplayName == "*알한글*"cd'
mdfind 'kMDItemFSName == "AlhangeulMac.app"'
```

결과:

- `알한글` 검색에서 `/Users/melee/Applications/AlhangeulMac.app` 확인
- `AlhangeulMac` 검색에서 `/Users/melee/Applications/AlhangeulMac.app` 확인
- display name predicate에서 `/Users/melee/Applications/AlhangeulMac.app` 확인
- filesystem name predicate에서 `/Users/melee/Applications/AlhangeulMac.app` 확인

### PlugInKit

```bash
pluginkit -mAvvv -i com.postmelee.alhangeulmac.QLExtension
pluginkit -mAvvv -i com.postmelee.alhangeulmac.ThumbnailExtension
```

결과:

- 두 extension 모두 `/Users/melee/Applications/AlhangeulMac.app` parent bundle로 등록됨
- PlugInKit parent name은 `알한글`로 표시됨

### Quick Look thumbnail smoke

요청한 테스트 경로 `/Users/melee/Documents/projects/rhwp-mac/samples`에는 현재 `.DS_Store` 외 HWP/HWPX 파일이 없었다. 해당 경로의 `/samples/basic/KTX.hwp`는 존재하지 않아 thumbnail 생성이 불가능했다.

보조 확인으로 기존 Vendor sample을 사용했다.

```bash
qlmanage -t -x -s 512 -o /tmp/rhwp-task40-stage5-ql-vendor \
  /Users/melee/Documents/projects/rhwp-mac/Vendor/rhwp/samples/basic/KTX.hwp
```

결과:

- `/tmp/rhwp-task40-stage5-ql-vendor/KTX.hwp.png` 생성 확인

## 결론

기본 bundle name과 localized display name의 역할을 카카오톡과 같은 구조로 맞췄다. 설치본 기준으로 Spotlight metadata가 `알한글.app` display name과 `AlhangeulMac.app` filesystem name을 모두 보유하며, `알한글`과 `AlhangeulMac` 검색 모두 설치본을 찾는 것을 확인했다.

## 승인 요청

Stage 5 완료 보고 승인을 요청한다.
