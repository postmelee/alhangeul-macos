# Issue #40 Stage 1 완료 보고서

## 타스크

- GitHub Issue: #40
- 마일스톤: M050
- 제목: Dock/Spotlight 표시명 한영 현지화
- 작업 브랜치: `local/task40`
- Stage: 1. 현지화 리소스 구조 추가

## 목표

실제 filesystem app bundle name은 `AlhangeulMac.app`으로 유지하면서, macOS가 언어 환경에 따라 표시명을 선택할 수 있도록 target별 localized `InfoPlist.strings`를 추가한다.

## 변경 내용

HostApp:

- `Sources/HostApp/Resources/ko.lproj/InfoPlist.strings`
  - `CFBundleDisplayName`: `알한글`
  - `CFBundleName`: `알한글`
- `Sources/HostApp/Resources/en.lproj/InfoPlist.strings`
  - `CFBundleDisplayName`: `AlhangeulMac`
  - `CFBundleName`: `AlhangeulMac`

Quick Look preview extension:

- `Sources/QLExtension/Resources/ko.lproj/InfoPlist.strings`
  - `CFBundleDisplayName`: `알한글 미리보기`
  - `CFBundleName`: `알한글 미리보기`
- `Sources/QLExtension/Resources/en.lproj/InfoPlist.strings`
  - `CFBundleDisplayName`: `AlhangeulMac Preview`
  - `CFBundleName`: `AlhangeulMac Preview`

Thumbnail extension:

- `Sources/ThumbnailExtension/Resources/ko.lproj/InfoPlist.strings`
  - `CFBundleDisplayName`: `알한글 썸네일`
  - `CFBundleName`: `알한글 썸네일`
- `Sources/ThumbnailExtension/Resources/en.lproj/InfoPlist.strings`
  - `CFBundleDisplayName`: `AlhangeulMac Thumbnail`
  - `CFBundleName`: `AlhangeulMac Thumbnail`

## 검증

### plist strings lint

```bash
plutil -lint \
  Sources/HostApp/Resources/ko.lproj/InfoPlist.strings \
  Sources/HostApp/Resources/en.lproj/InfoPlist.strings \
  Sources/QLExtension/Resources/ko.lproj/InfoPlist.strings \
  Sources/QLExtension/Resources/en.lproj/InfoPlist.strings \
  Sources/ThumbnailExtension/Resources/ko.lproj/InfoPlist.strings \
  Sources/ThumbnailExtension/Resources/en.lproj/InfoPlist.strings
```

결과:

- 6개 파일 모두 `OK`

### 값 확인

```bash
plutil -p <각 InfoPlist.strings>
```

결과:

- HostApp `ko`: `알한글`
- HostApp `en`: `AlhangeulMac`
- QLExtension `ko`: `알한글 미리보기`
- QLExtension `en`: `AlhangeulMac Preview`
- ThumbnailExtension `ko`: `알한글 썸네일`
- ThumbnailExtension `en`: `AlhangeulMac Thumbnail`

## 미진행 항목

- `project.yml` 리소스 포함 보정과 `AlhangeulMac.xcodeproj` 재생성은 Stage 2 범위로 남겼다.
- Debug build, 설치본 등록, Dock/Finder/Spotlight 표시 확인은 Stage 3 범위로 남겼다.

## 다음 단계

Stage 2에서 XcodeGen 리소스 포함 여부를 확인하고, 필요 시 `project.yml`을 보정한 뒤 `AlhangeulMac.xcodeproj`를 재생성한다.

## 승인 요청

Stage 1 완료를 보고하며, Stage 2 진행 승인을 요청한다.
