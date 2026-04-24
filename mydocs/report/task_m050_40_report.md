# Issue #40 최종 결과 보고서

## 타스크

- GitHub Issue: #40
- 마일스톤: M050
- 제목: Dock/Spotlight 표시명 한영 현지화
- 작업 브랜치: `local/task40`
- 기준 브랜치: `origin/devel` `05cc8ac`

## 결론

실제 app bundle filesystem name은 `AlhangeulMac.app`으로 유지하면서, 사용자 표시명은 `InfoPlist.strings`로 한국어와 영어를 분리했다. 추가로 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`을 실제 bundle filesystem name과 맞추고 `LSHasLocalizedDisplayName`을 명시해 Finder/Spotlight가 localized 표시명을 선택할 수 있게 보정했다.

- 한국어 환경: `알한글`, `알한글 미리보기`, `알한글 썸네일`
- 영어 환경: `AlhangeulMac`, `AlhangeulMac Preview`, `AlhangeulMac Thumbnail`

또한 Quick Look/Thumbnail 검증 시행착오의 원인을 분석해 운영 문서에 재발 방지 기준을 추가했다.

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 registration smoke test에 쓰지 않는다.
- LaunchServices/PlugInKit/Quick Look 검증은 signed/sealed Release package 산출물 기준으로 수행한다.
- 단일 설치 경로는 `AlhangeulMac.app`으로 유지한다.
- 기본 plist name은 filesystem bundle name과 맞추고, 한글 표시명은 `ko.lproj/InfoPlist.strings`에서 제공한다.
- `qlmanage -m plugins`는 app extension 등록 판정 기준으로 쓰지 않는다.
- 개발 build와 package staging 산출물은 Spotlight 앱 검색 후보에 섞이지 않도록 `build.noindex/` 아래에 둔다.

## 단계별 결과

### Stage 1. 현지화 리소스 구조 추가

추가 파일:

- `Sources/HostApp/Resources/ko.lproj/InfoPlist.strings`
- `Sources/HostApp/Resources/en.lproj/InfoPlist.strings`
- `Sources/QLExtension/Resources/ko.lproj/InfoPlist.strings`
- `Sources/QLExtension/Resources/en.lproj/InfoPlist.strings`
- `Sources/ThumbnailExtension/Resources/ko.lproj/InfoPlist.strings`
- `Sources/ThumbnailExtension/Resources/en.lproj/InfoPlist.strings`

검증:

- 6개 `InfoPlist.strings` `plutil -lint` 통과
- `plutil -p`로 표시명 값 확인

### Stage 2. XcodeGen 리소스 포함 및 프로젝트 재생성

변경:

- `xcodegen generate`로 `AlhangeulMac.xcodeproj` 재생성
- target별 `PBXVariantGroup` 3개 추가
- target별 Copy Bundle Resources에 `InfoPlist.strings` 포함
- `knownRegions`에 `ko` 포함

검증:

- `xcodegen generate` 성공
- `plutil -lint AlhangeulMac.xcodeproj/project.pbxproj` 성공
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -derivedDataPath build.noindex/DerivedDataList -list` 종료 코드 0

### Stage 3. 빌드 산출물과 등록 상태 검증

검증:

- `git submodule update --init --recursive`
- `./scripts/build-rust-macos.sh`
- Debug build 성공
- Debug/Release bundle 내부 localized `InfoPlist.strings` 포함 확인
- `./scripts/package-release.sh 0.1.0` 성공
- Release 설치본 `/Users/melee/Applications/AlhangeulMac.app` 기준 PlugInKit 등록 확인
- `/Users/melee/Documents/projects/rhwp-mac/Vendor/rhwp/samples/basic/KTX.hwp` thumbnail smoke test 성공

중요 관찰:

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 PlugInKit 등록 검증에 부적합했다.
- Release package 산출물은 local signing과 sealed resources가 적용되어 PlugInKit 등록이 정상 확인됐다.
- 현재 사용자 환경에서는 영어 localization이 선택되어 PlugInKit/Spotlight metadata가 `AlhangeulMac` 계열을 표시했다.

### Stage 4. 문서와 최종 보고

변경 문서:

- `AGENTS.md`
- `README.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/troubleshootings/task_m050_40_quicklook_thumbnail_registration_validation.md`

핵심 반영:

- Debug build와 Finder integration smoke test의 목적 분리
- Release package 산출물을 registration smoke test 기준으로 고정
- 단일 ASCII 설치 경로 유지
- 이전 설치본 삭제는 승인 후 제한적으로만 수행
- 증상별 판단표와 금지할 습관 기록

### Stage 5. Spotlight/Finder 표시명 기준 보정

변경:

- HostApp 기본 `Info.plist` 표시명을 `AlhangeulMac`으로 보정
- QLExtension 기본 `Info.plist` 표시명을 `AlhangeulMacPreview`로 보정
- ThumbnailExtension 기본 `Info.plist` 표시명을 `AlhangeulMacThumbnail`으로 보정
- 세 target 모두 `LSHasLocalizedDisplayName = true` 추가
- 한국어/영어 `InfoPlist.strings`는 사용자 표시명 소스로 유지

검증:

- 설치본 `mdls` 결과:
  - `kMDItemDisplayName = 알한글.app`
  - `kMDItemFSName = AlhangeulMac.app`
  - `kMDItemCFBundleIdentifier = com.postmelee.alhangeulmac`
- `mdfind -onlyin /Users/melee/Applications 알한글`에서 `/Users/melee/Applications/AlhangeulMac.app` 확인
- `mdfind -onlyin /Users/melee/Applications AlhangeulMac`에서 `/Users/melee/Applications/AlhangeulMac.app` 확인
- PlugInKit의 parent name이 `알한글`로 표시됨

### Stage 6. 개발 산출물 Spotlight 오염 방지

변경:

- `.gitignore`에 `/build.noindex/` 추가
- `scripts/package-release.sh` 기본 build root를 `build.noindex`로 변경
- `scripts/package-release.sh`가 build root에 `.metadata_never_index`를 생성하도록 변경
- README, AGENTS, build 실행, release 배포, core submodule, PR manual의 Debug/Release/package 경로를 `build.noindex` 기준으로 갱신
- Spotlight 오염 원인과 재발 방지 기준을 troubleshooting 문서에 추가

원인 확인:

- 설치본 `/Users/melee/Applications/AlhangeulMac.app`은 `알한글.app` display name과 `AlhangeulMac.app` filesystem name을 모두 가진 정상 구조였다.
- 별도 검색 후보로 보인 원인은 repo `build/DerivedData`와 Xcode 기본 DerivedData에 남은 오래된 개발 `.app` 산출물이었다.

검증:

- `build.noindex/DerivedData` Debug build 성공
- `build.noindex/release/AlhangeulMac.app` Release package 성공
- 이전 generated DerivedData 앱 후보 제거 후 app bundle predicate 검색에서 `/Users/melee/Applications/AlhangeulMac.app` 하나만 확인
- `알한글`과 `AlhangeulMac` 검색 모두 `/Users/melee/Applications/AlhangeulMac.app` 확인

## 최종 검증 요약

### 정적 검증

```bash
plutil -lint Sources/HostApp/Resources/ko.lproj/InfoPlist.strings \
  Sources/HostApp/Resources/en.lproj/InfoPlist.strings \
  Sources/QLExtension/Resources/ko.lproj/InfoPlist.strings \
  Sources/QLExtension/Resources/en.lproj/InfoPlist.strings \
  Sources/ThumbnailExtension/Resources/ko.lproj/InfoPlist.strings \
  Sources/ThumbnailExtension/Resources/en.lproj/InfoPlist.strings
plutil -lint Sources/HostApp/Info.plist \
  Sources/QLExtension/Info.plist \
  Sources/ThumbnailExtension/Info.plist
plutil -lint AlhangeulMac.xcodeproj/project.pbxproj
git diff --check
```

결과:

- 모두 성공

### Build/package 검증

```bash
./scripts/build-rust-macos.sh
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/package-release.sh 0.1.0
```

결과:

- 모두 성공
- release zip SHA256:
  - `fae970ef947b91adecd29179ad3d2618ba9ebb7f60a2a2ee48612e4eb476a1f9  alhangeul-macos-0.1.0.zip`

### 설치본 검증

설치본:

- `/Users/melee/Applications/AlhangeulMac.app`

확인:

- HostApp/QLExtension/ThumbnailExtension에 `ko.lproj`, `en.lproj` `InfoPlist.strings` 포함
- HostApp/QLExtension/ThumbnailExtension에 `LSHasLocalizedDisplayName = true` 포함
- Spotlight metadata에서 `알한글.app` display name과 `AlhangeulMac.app` filesystem name 확인
- Spotlight metadata에서 `AlhangeulMac.app` alternate name 확인
- Spotlight 검색에서 `알한글`, `AlhangeulMac` 모두 설치본 확인
- 이전 generated DerivedData 앱 후보 제거 후 관련 설치 후보가 `/Users/melee/Applications/AlhangeulMac.app` 하나로 수렴함 확인
- `com.postmelee.alhangeulmac.QLExtension` PlugInKit 등록 확인
- `com.postmelee.alhangeulmac.ThumbnailExtension` PlugInKit 등록 확인
- `qlmanage -t -x` thumbnail 생성 확인

## 남은 리스크와 운영 메모

- Dock/Finder/Spotlight 표시명은 LaunchServices/Spotlight cache 영향을 받을 수 있으나, 현재 설치본 metadata와 Spotlight 검색 후보는 `알한글`과 `AlhangeulMac` 모두 확인됐다.
- Codex sandbox 내부에서는 Spotlight server가 disabled로 보여 `mdfind`/`mdls`가 실패할 수 있다. Spotlight 검증은 sandbox 밖 권한에서 수행해야 하며, 이번 검증에서는 `/`와 `/System/Volumes/Data` indexing enabled를 확인했다.
- 요청한 테스트 경로 `/Users/melee/Documents/projects/rhwp-mac/samples`에는 현재 `.DS_Store` 외 HWP/HWPX 파일이 없어 해당 경로로 thumbnail smoke를 수행할 수 없었다. 보조로 `/Users/melee/Documents/projects/rhwp-mac/Vendor/rhwp/samples/basic/KTX.hwp`를 사용해 thumbnail 생성은 확인했다.
- 공개 배포용 서명/공증은 이번 작업 범위가 아니며 별도 release task에서 결정한다.

## PR 준비 상태

- 수행 계획서: 작성 완료
- 구현 계획서: 작성 완료
- Stage 1-6 보고서: 작성 완료
- 최종 보고서: 작성 완료
- 오늘할일: 완료 처리
- PR 생성은 작업지시자 최종 승인 후 `publish/task40` 원격 브랜치로 push하고 `devel` 대상 draft PR로 진행한다.

## 승인 요청

Issue #40 최종 결과 보고를 승인 요청한다.
