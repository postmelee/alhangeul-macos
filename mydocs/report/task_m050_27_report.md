# Issue #27 최종 보고서

## 개요

Issue #27은 사용자에게 보이는 앱 이름을 `알한글` 기준으로 정리하고, Finder 통합 검증 절차를 현재 설정과 맞추는 작업이다.

이번 작업의 기준은 다음과 같이 정리했다.

- 사용자 표시명과 배포 앱 번들명은 `알한글`을 사용한다.
- 내부 Xcode product/executable/module 이름은 `RhwpMac` 계열을 유지한다.
- Finder 통합 검증은 단일 설치본 기준으로 수행한다.
- build 산출물 제외 같은 우회 절차는 troubleshooting으로 분리한다.

## 주요 변경

### 1. 사용자 표시명 정리

- HostApp 표시명은 기존 `알한글`을 유지했다.
- Quick Look extension 표시명을 `알한글 미리보기`로 변경했다.
- Thumbnail extension 표시명을 `알한글 썸네일`로 변경했다.

### 2. 패키징 산출물 정합화

- `scripts/package-release.sh`는 내부 build 산출물 `RhwpMac.app`을 확인한다.
- zip 생성 전 `build/release/알한글.app`으로 복사한 뒤 `알한글.app`을 압축한다.
- Xcode release build 중간 산출물은 `build/release/xcodebuild`에 격리하고, 복사 후 임시 `RhwpMac.app` LaunchServices 등록을 해제한다.
- 기존 `build/release` 루트의 `RhwpMac` 계열 중간 산출물은 패키징 시작 시 정리한다.
- `Casks/rhwp-mac.rb`의 release URL, homepage, 표시 이름을 현재 저장소와 `알한글` 기준으로 맞췄다.

### 3. 문서 보정

- README의 개발 build 산출물 경로를 `RhwpMac.app` 기준으로 수정했다.
- `mydocs/manual/build_run_guide.md`에서 앱 실행 확인과 Finder 통합 확인을 분리했다.
- `mydocs/manual/release_distribution_guide.md`에서 내부 산출물 `RhwpMac.app`과 배포 산출물 `알한글.app`의 관계를 반영했다.
- `mydocs/tech/project_architecture.md`에 사용자 표시명과 내부 식별자 경계를 명시했다.

## 산출물

- 코드/설정
  - `Sources/QLExtension/Info.plist`
  - `Sources/ThumbnailExtension/Info.plist`
  - `scripts/package-release.sh`
  - `Casks/rhwp-mac.rb`
- 문서
  - `README.md`
  - `mydocs/manual/build_run_guide.md`
  - `mydocs/manual/release_distribution_guide.md`
  - `mydocs/tech/project_architecture.md`
  - `mydocs/orders/20260425.md`
  - `mydocs/plans/task_m050_27.md`
  - `mydocs/plans/task_m050_27_impl.md`
  - `mydocs/working/task_m050_27_stage1.md`
  - `mydocs/working/task_m050_27_stage2.md`
  - `mydocs/working/task_m050_27_stage3.md`
  - `mydocs/working/task_m050_27_stage4.md`
  - `mydocs/report/task_m050_27_report.md`

## 검증 결과

### 1. 설정/문서 형식 검증

- `xcodegen generate`
- `plutil -lint Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist`
- `bash -n scripts/package-release.sh`
- `git diff --check`

### 2. build setting 확인

- `xcodebuild -showBuildSettings -project RhwpMac.xcodeproj -scheme HostApp`
  - `PRODUCT_NAME = RhwpMac`
  - `WRAPPER_NAME = RhwpMac.app`
  - `FULL_PRODUCT_NAME = RhwpMac.app`

### 3. Debug build

- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
  - 결과: `BUILD SUCCEEDED`

### 4. Release package

- `./scripts/package-release.sh 0.1.0`
  - Rust bridge 재생성 성공
  - `Rhwp.xcframework` 재생성 성공
  - Release build 성공
  - `build/release/알한글.app` 생성 확인
  - `build/release/rhwp-mac-0.1.0.zip` 생성 확인
  - `build/release` 루트에 `RhwpMac.app`과 extension 중간 산출물이 남지 않음 확인
  - SHA256: `69ba2c5c0c21340b1dfddf006d0a50e9c3925f3cdd0b3c538034ae396b36053e`

### 5. 표시명 확인

- `build/release/알한글.app/Contents/Info.plist`
  - `CFBundleName`: `알한글`
  - `CFBundleDisplayName`: `알한글`
- `build/release/알한글.app/Contents/PlugIns/RhwpMacPreview.appex/Contents/Info.plist`
  - `CFBundleName`: `알한글 미리보기`
- `build/release/알한글.app/Contents/PlugIns/RhwpMacThumbnail.appex/Contents/Info.plist`
  - `CFBundleName`: `알한글 썸네일`

### 6. 오래된 설명 제거 확인

- 다음 표현이 남아 있지 않음을 확인했다.
  - `build/DerivedData/Build/Products/.../알한글.app`
  - 이전 저장소명
  - `알한글 Preview`
  - `알한글 Thumbnail`

### 7. Finder/Quick Look smoke test

- `/Users/melee/Applications/알한글.app` 설치 후 LaunchServices와 PlugInKit에 등록했다.
- smoke test 격리를 위해 기존 `/Users/melee/Applications/RhwpMac.app`는 `/Users/melee/Applications/RhwpMac.app.stage27-smoke-disabled`로 임시 비활성화했다.
- `pluginkit -mAvvv`
  - `com.postmelee.rhwpmac.QLExtension`: 한글 앱 경로 등록 확인
  - `com.postmelee.rhwpmac.ThumbnailExtension`: 한글 앱 경로 등록 확인
  - 표시명: `알한글 미리보기`, `알한글 썸네일`
- `mdls -name kMDItemContentType /Users/melee/Documents/projects/rhwp-mac/Vendor/rhwp/samples/basic/KTX.hwp`
  - 결과: `com.haansoft.hancomofficeviewer.mac.hwp`
  - extension의 `QLSupportedContentTypes`에 포함됨 확인
- `qlmanage -r`
  - 결과: 통과
- `qlmanage -r cache`
  - 결과: 통과
- `pluginkit -e use -i com.postmelee.rhwpmac.QLExtension`
  - 결과: 통과
- `pluginkit -e use -i com.postmelee.rhwpmac.ThumbnailExtension`
  - 결과: 통과
- `qlmanage -m plugins | rg -i 'rhwp|hwp|알한글|postmelee'`
  - 결과: 매칭 없음
- `qlmanage -t -x -s 512 -o /tmp /Users/melee/Documents/projects/rhwp-mac/Vendor/rhwp/samples/basic/KTX.hwp`
  - 결과: `No thumbnail created`

## 최종 판단

- 사용자에게 전달되는 release package는 `알한글.app` 기준으로 생성된다.
- 사용자 노출 가능성이 있는 extension 표시명도 한글 기준으로 정리됐다.
- 내부 build 산출물과 Swift module/executable 계열은 `RhwpMac`으로 유지되어 기존 Quick Look principal class와 Xcode 설정 안정성을 보존한다.
- Finder 통합 절차는 단일 설치본 기준으로 문서화했고, build 산출물 제외 같은 우회 절차는 표준 절차에서 분리했다.
- Finder/Quick Look smoke test에서 PlugInKit 등록과 UTI 매칭은 확인됐지만, `qlmanage` thumbnail 생성은 실패했다.

## 남은 리스크와 후속 권장 사항

### 1. Finder 실동작 smoke test

이번 작업에서 smoke test를 실행했고, 등록 계층과 실제 thumbnail 생성 계층이 갈라지는 상태를 확인했다.

표시명/패키징/문서 정합화는 완료됐지만, 실제 Finder thumbnail 생성은 별도 후속 타스크에서 Quick Look discovery와 `HwpThumbnailProvider` 실행 여부를 좁혀야 한다.

### 2. Cask token

이번 작업은 사용자 표시명과 현재 저장소 URL을 맞췄고, Cask token `rhwp-mac`은 유지했다.

첫 공개 릴리스 전 token을 `rhwp-mac`으로 유지할지 `alhangeul-macos`로 바꿀지는 별도 릴리스 판단으로 남긴다.

### 3. smoke test 중 임시 비활성화한 설치본

기존 `/Users/melee/Applications/RhwpMac.app`는 단일 설치본 검증을 위해 `/Users/melee/Applications/RhwpMac.app.stage27-smoke-disabled`로 옮겼다.

이후 Issue #37 정리 과정에서 smoke test 설치본과 임시 비활성화 설치본은 모두 삭제했다.

## 결론

- 사용자에게 보이는 앱 이름은 `알한글` 기준으로 정리됐다.
- 내부 ASCII 식별자와 사용자 표시명의 경계가 문서화됐다.
- 패키징과 문서가 현재 Xcode 설정과 같은 기준을 사용하게 됐다.
- Finder/Quick Look smoke test는 아직 통과하지 못했으므로 후속 원인 분석이 필요하다.
