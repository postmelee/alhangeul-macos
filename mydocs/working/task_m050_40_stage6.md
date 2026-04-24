# Issue #40 Stage 6 완료 보고서

## 타스크

- GitHub Issue: #40
- 마일스톤: M050
- 제목: Dock/Spotlight 표시명 한영 현지화
- 작업 브랜치: `local/task40`

## 목적

사용자 Spotlight 화면에서 `AlhangeulMac`과 `알한글` 검색 결과가 서로 다른 앱 후보로 보이는 문제를 추가 분석하고, 개발 build 산출물이 Spotlight 앱 검색 후보를 오염하지 않도록 빌드 경로와 문서를 정리한다.

## 원인 분석

설치본 `/Users/melee/Applications/AlhangeulMac.app`의 구조는 카카오톡과 같은 형태였다.

- `kMDItemDisplayName = 알한글.app`
- `kMDItemFSName = AlhangeulMac.app`
- `kMDItemAlternateNames = AlhangeulMac.app`
- `kMDItemCFBundleIdentifier = com.postmelee.alhangeulmac`

하지만 Spotlight 전체 검색에는 설치본 외에도 개발 산출물이 앱 후보로 섞일 수 있었다.

- `/Users/melee/Documents/projects/rhwp-mac/build/DerivedData/Build/Products/Debug/AlhangeulMac.app`
- `/Users/melee/Library/Developer/Xcode/DerivedData/RhwpMac-*/Build/Products/Debug/알한글.app`

특히 repo의 `build/DerivedData`는 일반 디렉터리라 Spotlight가 색인할 수 있고, 오래된 Debug app은 Stage 5 이전 plist 구조를 가진 상태로 남아 검색 결과에서 표준 설치본과 경쟁할 수 있었다. 따라서 앱 표시명 구조만 맞추는 것으로는 충분하지 않고, 개발 산출물 위치도 Spotlight 색인 대상에서 제외해야 한다.

## 변경 내용

### 빌드 산출물 경로

- `.gitignore`
  - `/build.noindex/` 추가
- `scripts/package-release.sh`
  - 기본 build root를 `build.noindex`로 변경
  - Release staging 경로를 `build.noindex/release`로 변경
  - build root에 `.metadata_never_index`를 생성

### 문서 갱신

- `AGENTS.md`
  - 생성 `.app`/`.appex` 산출물은 `build.noindex/` 아래에 둔다는 강제 규칙 추가
- `README.md`
  - Debug build, Debug app 실행, Release install 경로를 `build.noindex` 기준으로 수정
  - 사용자가 확인할 기준 앱은 `~/Applications/AlhangeulMac.app`이라고 명시
- `mydocs/manual/build_run_guide.md`
  - Debug/Release DerivedData와 release install 경로를 `build.noindex` 기준으로 수정
  - `build/DerivedData` 앱 산출물이 Spotlight 검색 후보를 오염할 수 있음을 기록
- `mydocs/manual/release_distribution_guide.md`
  - 배포 build, install, zip 경로를 `build.noindex/release` 기준으로 수정
- `mydocs/manual/core_submodule_operation_guide.md`
  - submodule 검증용 Debug build 경로를 `build.noindex/DerivedData`로 수정
- `mydocs/manual/pr_process_guide.md`
  - PR 검증 예시 Debug build 경로를 `build.noindex/DerivedData`로 수정
- `mydocs/troubleshootings/task_m050_40_quicklook_thumbnail_registration_validation.md`
  - 개발 산출물 Spotlight 오염 증상과 재발 방지 기준 추가

## 산출물 정리

다음 generated build 산출물을 제한적으로 제거했다.

- `/Users/melee/Documents/projects/rhwp-mac/build/DerivedData`
- `/Users/melee/Library/Developer/Xcode/DerivedData/RhwpMac-djdcolzyygqkukbokntcdmiefnwo`
- `/Users/melee/Library/Developer/Xcode/DerivedData/RhwpMac-cpyvbxnxabrtukapskxpqcwseeel`

정리 후 확인:

- `/Users/melee/Documents/projects/rhwp-mac/build` 아래 `.app`/`.appex` 후보 없음
- `/Users/melee/Library/Developer/Xcode/DerivedData` 아래 `RhwpMac`/`AlhangeulMac`/`알한글` 앱 후보 없음
- `/Users/melee/Applications`의 관련 설치본은 `/Users/melee/Applications/AlhangeulMac.app` 하나만 존재

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
bash -n scripts/package-release.sh
git diff --check
```

결과:

- 모두 성공

### Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

- 성공
- Debug app 경로: `/tmp/rhwp-mac-task40/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app`

### Release package

```bash
./scripts/package-release.sh 0.1.0
```

결과:

- 성공
- release app: `/tmp/rhwp-mac-task40/build.noindex/release/AlhangeulMac.app`
- release zip SHA256:
  - `fae970ef947b91adecd29179ad3d2618ba9ebb7f60a2a2ee48612e4eb476a1f9  alhangeul-macos-0.1.0.zip`

### 설치본과 Spotlight

설치본:

- `/Users/melee/Applications/AlhangeulMac.app`

확인 결과:

- `mdls`
  - `kMDItemDisplayName = 알한글.app`
  - `kMDItemFSName = AlhangeulMac.app`
  - `kMDItemAlternateNames = AlhangeulMac.app`
  - `kMDItemCFBundleIdentifier = com.postmelee.alhangeulmac`
- `mdfind -onlyin /Users/melee/Applications 알한글`
  - `/Users/melee/Applications/AlhangeulMac.app`
- `mdfind -onlyin /Users/melee/Applications AlhangeulMac`
  - `/Users/melee/Applications/AlhangeulMac.app`
- app bundle predicate 검색
  - `/Users/melee/Applications/AlhangeulMac.app` 하나만 확인

참고:

- Codex sandbox 내부에서는 Spotlight server가 disabled로 보여 `mdfind`/`mdls`가 실패할 수 있었다.
- sandbox 밖 권한으로 확인하면 `/`와 `/System/Volumes/Data` indexing은 enabled였고, 설치본 metadata와 검색 결과가 정상 확인됐다.

### Quick Look/Thumbnail

```bash
pluginkit -m -A -D -i com.postmelee.alhangeulmac.QLExtension
pluginkit -m -A -D -i com.postmelee.alhangeulmac.ThumbnailExtension
qlmanage -t -x -s 256 -o /tmp/alhangeul-ql-stage6 \
  /Users/melee/Documents/projects/rhwp-mac/Vendor/rhwp/samples/basic/KTX.hwp
codesign --verify --deep --strict --verbose=2 \
  /Users/melee/Applications/AlhangeulMac.app
```

결과:

- `com.postmelee.alhangeulmac.QLExtension(0.1.0)` 등록 확인
- `com.postmelee.alhangeulmac.ThumbnailExtension(0.1.0)` 등록 확인
- `/tmp/alhangeul-ql-stage6/KTX.hwp.png` 생성 확인
- PNG 크기: `256 x 182`
- 설치본 codesign verify 성공

요청한 테스트 경로 `/Users/melee/Documents/projects/rhwp-mac/samples`에는 현재 `.DS_Store` 외 HWP/HWPX 파일이 없어, 보조로 `Vendor/rhwp/samples/basic/KTX.hwp`를 사용했다.

## 결론

사용자 화면에서 `AlhangeulMac`과 `알한글` 검색 결과가 다르게 보인 핵심 원인은 설치본 표시명 구조가 아니라, 오래된 개발 build 앱 산출물이 Spotlight 앱 후보로 남아 표준 설치본과 경쟁한 것이다. 표준 설치본은 카카오톡과 같은 metadata 구조를 갖고 있으며, 정리 후 `알한글`과 `AlhangeulMac` 검색 모두 같은 `/Users/melee/Applications/AlhangeulMac.app`으로 수렴했다.

이후 Debug/Release/package 산출물은 `build.noindex/` 아래에 두는 것을 표준으로 고정한다.

## 승인 요청

Stage 6 완료 보고 승인을 요청한다.
