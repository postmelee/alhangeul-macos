# Issue #33 최종 결과 보고서

## 타스크

- GitHub Issue: #33
- 마일스톤: M050
- 제목: Quick Look thumbnail smoke test 실패 원인 분석
- 작업 브랜치: `local/task33`
- 기준 브랜치: `devel` `22aa57f`

## 결론

Quick Look thumbnail smoke test 실패의 직접 원인은 Thumbnail provider 코드가 아니라 설치 app bundle filesystem path와 LaunchServices/PlugInKit 등록 상태였다.

`/Users/melee/Applications/알한글.app`처럼 non-ASCII `.app` 경로를 사용하는 상태에서는 PlugInKit 등록 항목이 보여도 ExtensionKit 실행 시 `not found in LS database`가 발생할 수 있었다. 같은 산출물을 ASCII 경로로 단독 등록하면 `HwpThumbnailProvider`가 정상 로드되고 thumbnail이 생성됐다.

최종 수정은 다음 기준으로 정리했다.

- 사용자 표시명: `알한글`, `알한글 미리보기`, `알한글 썸네일` 유지
- Xcode project/product/executable/module 이름: `AlhangeulMac` 계열
- filesystem app bundle name: `AlhangeulMac.app`
- bundle identifier와 app-owned UTI: `com.postmelee.alhangeulmac` 계열
- release zip과 Cask token/file: `alhangeul-macos` 계열

## 단계별 요약

### Stage 1. 기준 상태와 재현 조건

- `devel` 최신 기준을 반영한 `/tmp/rhwp-mac-task33` worktree에서 `local/task33`을 진행했다.
- 사용자 지정 테스트 파일은 `/Users/melee/Documents/projects/rhwp-mac/samples` 아래 파일만 사용했다.
- signed Debug app을 `/Users/melee/Applications/알한글.app`에 설치했을 때 PlugInKit 등록은 보였지만 `qlmanage -t`는 `No thumbnail created`로 실패했다.
- unified log에서 `com.postmelee.rhwpmac.ThumbnailExtension`이 `not found in LS database`로 확인됐다.

### Stage 2. 등록 계층과 discovery 분리

- LaunchServices dump와 PlugInKit 등록을 분리해 확인했다.
- `/Users/melee/Applications/알한글.app`에는 app/plugin record가 있었지만 ExtensionKit launch에서는 같은 appex URL을 LS database에서 찾지 못했다.
- 같은 build 산출물을 ASCII 경로로 단독 등록하면 사용자 지정 samples 3개 모두 thumbnail 생성에 성공했다.
- `qlmanage -m plugins` 미노출은 app extension 실행 실패의 직접 원인이 아니라고 분리했다.

### Stage 3. 최소 수정

- package/install path 정책을 ASCII filesystem bundle name으로 보정했다.
- 당시 최소 수정 기준으로 `RhwpMac.app` release package를 만들고 smoke test를 통과시켰다.
- `xcodebuild`가 기본 DerivedData를 사용자 Library에 쓰지 않도록 `scripts/package-release.sh`에 release 전용 `build/release/DerivedData`를 지정했다.

### Stage 4. 이름 정합화

- 작업지시자 의견에 따라 `RhwpMac`/`rhwpmac` 계열 이름을 `alhangeul-macos` 저장소명과 맞게 정리했다.
- `AlhangeulMac.xcodeproj`, `AlhangeulMac.app`, `AlhangeulMacPreview.appex`, `AlhangeulMacThumbnail.appex` 기준으로 XcodeGen 산출물을 재생성했다.
- bundle identifier와 app-owned UTI를 `com.postmelee.alhangeulmac` 계열로 변경했다.
- `Casks/alhangeul-macos.rb`, `alhangeul-macos-<version>.zip` 기준으로 배포 이름을 맞췄다.
- README, AGENTS, build/run guide, release guide, architecture 문서 등 현재 운영 문서를 새 이름 기준으로 갱신했다.

### Stage 5. 최종 검증

- 최종 검증 묶음을 재실행했고 모두 통과했다.
- `/Users/melee/Applications/AlhangeulMac.app` 기준으로 Quick Look preview/thumbnail extension 등록을 확인했다.
- 사용자 지정 samples 3개 모두 thumbnail 생성에 성공했다.

## 변경 파일 요약

- `project.yml`
  - project/product/executable/bundle id를 `AlhangeulMac`/`com.postmelee.alhangeulmac` 계열로 변경
- `AlhangeulMac.xcodeproj`
  - `project.yml` 기준 재생성
- `Sources/HostApp/Info.plist`
  - app-owned UTI를 `com.postmelee.alhangeulmac.hwp`/`com.postmelee.alhangeulmac.hwpx`로 변경
- `Sources/QLExtension/Info.plist`
  - supported content type의 app-owned UTI 갱신
- `Sources/ThumbnailExtension/Info.plist`
  - supported content type의 app-owned UTI 갱신
- `Sources/HostApp/Services/DocumentOpenPanel.swift`
  - 열기 패널의 app-owned UTI 갱신
- `Sources/HostApp/Services/ExtensionStatusModel.swift`
  - extension 상태 확인 bundle id 갱신
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
  - dispatch queue label 갱신
- `scripts/package-release.sh`
  - release build project/app/zip 이름을 `AlhangeulMac`/`alhangeul-macos` 기준으로 변경
  - release 전용 DerivedData 사용
- `Casks/alhangeul-macos.rb`
  - 기존 `Casks/rhwp-mac.rb`에서 rename
  - release asset URL과 app stanza 갱신
- `README.md`, `AGENTS.md`, `.github/pull_request_template.md`, `mydocs/manual/*`, `mydocs/tech/project_architecture.md`
  - 현재 운영 문서의 project/app/bundle id/cask 기준 갱신
- `mydocs/plans/task_m050_33.md`, `mydocs/plans/task_m050_33_impl.md`
  - 추가 Stage 4/5 반영
- `mydocs/working/task_m050_33_stage*.md`
  - 단계별 조사, 검증, 완료 기록
- `mydocs/orders/20260425.md`
  - 오늘할일 상태 갱신

## 최종 검증 결과

### 정적 검증

```bash
xcodegen generate
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
./scripts/check-no-appkit.sh
bash -n scripts/package-release.sh
```

결과:

- 모두 성공
- `Sources/RhwpCoreBridge` AppKit/UIKit 직접 의존 없음

### 운영 문서 이름 검색

```bash
rg -n "RhwpMac|rhwpmac|rhwp-mac|알한글\\.app" README.md .github AGENTS.md mydocs/manual mydocs/tech project.yml Sources scripts Casks
```

결과:

- 현재 운영 문서와 소스에는 기존 이름 기준이 남아 있지 않다.
- `rhwp-macos 기준 완전 이관`은 milestone 이름으로 남아 있다.

### Debug build

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

### Release package

```bash
./scripts/package-release.sh 0.1.0
```

결과:

- 성공
- SHA256:
  - `9a09ae057ad0cfc4e5a3cc76e4f1557350133069f8c4361da41045848d613cf4  alhangeul-macos-0.1.0.zip`
- zip 내부 최상위 app bundle:
  - `AlhangeulMac.app/`

### Info.plist 확인

Host app:

- `CFBundleDisplayName`: `알한글`
- `CFBundleName`: `알한글`
- `CFBundleExecutable`: `AlhangeulMacHost`
- `CFBundleIdentifier`: `com.postmelee.alhangeulmac`

Thumbnail extension:

- `CFBundleDisplayName`: `알한글 썸네일`
- `CFBundleName`: `알한글 썸네일`
- `CFBundleExecutable`: `AlhangeulMacThumbnail`
- `CFBundleIdentifier`: `com.postmelee.alhangeulmac.ThumbnailExtension`
- `NSExtensionPrincipalClass`: `AlhangeulMacThumbnail.HwpThumbnailProvider`

### 설치본 등록 확인

설치본:

- `/Users/melee/Applications/AlhangeulMac.app`

PlugInKit:

- `com.postmelee.alhangeulmac.QLExtension`
  - `/Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex`
  - 표시명: `알한글 미리보기`
- `com.postmelee.alhangeulmac.ThumbnailExtension`
  - `/Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex`
  - 표시명: `알한글 썸네일`

샘플 UTI:

- `/Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp`
- `kMDItemContentType = "com.haansoft.hancomofficeviewer.mac.hwp"`

### Finder thumbnail smoke test

```bash
qlmanage -t -x -s 512 -o /tmp/rhwp-task33-stage5-ql \
  /Users/melee/Documents/projects/rhwp-mac/samples/group-drawing-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/pic-in-head-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

결과:

- `group-drawing-02.hwp`: thumbnail 1개 생성
- `pic-in-head-02.hwp`: thumbnail 1개 생성
- `basic/KTX.hwp`: thumbnail 1개 생성

생성 파일:

- `/tmp/rhwp-task33-stage5-ql/group-drawing-02.hwp.png`
- `/tmp/rhwp-task33-stage5-ql/pic-in-head-02.hwp.png`
- `/tmp/rhwp-task33-stage5-ql/KTX.hwp.png`

## 남은 리스크와 운영 메모

- 사용자 환경에 예전 `/Users/melee/Applications/RhwpMac.app` 또는 `/Users/melee/Applications/알한글.app` 파일과 캐시가 남아 있으면 LaunchServices/PlugInKit discovery에 영향을 줄 수 있다.
- 이번 검증에서는 기존 두 경로를 삭제하지 않고 LaunchServices unregister를 시도한 뒤 `AlhangeulMac.app` 단일 후보 기준으로 등록을 확인했다.
- `qlmanage -m plugins`는 app extension 등록 상태를 직접 반영하지 않으므로, Finder 통합 검증은 `pluginkit -mAvvv`, `mdls`, `qlmanage -t` 결과를 함께 본다.
- 공개 배포 전 Developer ID 서명, notarization, Homebrew Cask SHA 고정은 별도 릴리스 작업에서 결정해야 한다.

## PR 준비 상태

- 최종 검증: 완료
- 최종 보고서: 작성 완료
- 오늘할일: 완료 처리
- PR 생성은 작업지시자 최종 승인 후 `publish/task33` 원격 브랜치로 push하고 `devel` 대상 draft PR로 진행한다.

## 승인 요청

Issue #33 최종 결과 보고를 승인 요청한다.
