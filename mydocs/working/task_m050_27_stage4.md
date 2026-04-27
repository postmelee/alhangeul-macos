# Issue #27 단계 4 완료 보고서

## 작업 내용

- Debug build와 release packaging을 검증했다.
- 패키징 산출물의 앱/extension 표시명을 확인했다.
- 전체 diff 형식 검사를 수행했다.

## 검증

### 1. 정적 검증

- `git diff --check`
  - 결과: 통과
- 오래된 경로/표현 검색
  - 대상:
    - `build/DerivedData/Build/Products/.../알한글.app`
    - 이전 저장소명
    - `알한글 Preview`
    - `알한글 Thumbnail`
  - 결과: 매칭 없음

### 2. Debug build

- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
  - 결과: `BUILD SUCCEEDED`
  - 확인: `build/DerivedData/Build/Products/Debug/RhwpMac.app`

### 3. Release package

- `./scripts/package-release.sh 0.1.0`
  - Rust bridge 재생성 성공
  - `Rhwp.xcframework` 재생성 성공
  - Release build 성공
  - `build/release/알한글.app` 생성 확인
  - `build/release/rhwp-mac-0.1.0.zip` 생성 확인
  - `build/release` 루트에 `RhwpMac.app`과 extension 중간 산출물이 남지 않음 확인
  - SHA256: `69ba2c5c0c21340b1dfddf006d0a50e9c3925f3cdd0b3c538034ae396b36053e`

### 4. 표시명 확인

- `build/release/알한글.app/Contents/Info.plist`
  - `CFBundleName`: `알한글`
  - `CFBundleDisplayName`: `알한글`
- `build/release/알한글.app/Contents/PlugIns/RhwpMacPreview.appex/Contents/Info.plist`
  - `CFBundleName`: `알한글 미리보기`
- `build/release/알한글.app/Contents/PlugIns/RhwpMacThumbnail.appex/Contents/Info.plist`
  - `CFBundleName`: `알한글 썸네일`

### 5. Finder/Quick Look smoke test

- 설치/등록 대상:
  - `/Users/melee/Applications/알한글.app`
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

## 판단

- 내부 Xcode 산출물명은 `RhwpMac.app`로 유지된다.
- 사용자에게 전달되는 release package 산출물은 `알한글.app` 기준으로 생성된다.
- 사용자 노출 가능성이 있는 extension 표시명도 한글 기준으로 정리됐다.
- Finder 통합 실동작 smoke test에서 PlugInKit 등록과 UTI 매칭은 확인됐지만, `qlmanage` thumbnail 생성은 실패했다.
- 현재 결과만으로는 표시명/패키징 변경의 회귀라기보다 Quick Look discovery 또는 Thumbnail extension 실행 경로 문제로 분리해 보는 것이 맞다.

## 다음 단계

- 최종 결과 보고서에 smoke test 실패 결과와 후속 작업안을 반영하고 승인 요청한다.

## 승인 요청 사항

- 이 단계 완료 기준으로 최종 결과 보고서 작성 진행 승인 요청
