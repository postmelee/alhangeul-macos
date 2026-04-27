# Issue #33 Stage 3 완료 보고서

## 타스크

- GitHub Issue: #33
- 마일스톤: M050
- 제목: Quick Look thumbnail smoke test 실패 원인 분석
- 단계: Stage 3. Thumbnail provider 실행 여부 확인과 최소 수정

## 요약

- Stage 2에서 확인한 원인에 맞춰 filesystem app bundle name을 ASCII `RhwpMac.app`으로 고정했다.
- 사용자 표시명은 기존처럼 `Info.plist`의 `알한글`, `알한글 미리보기`, `알한글 썸네일`을 유지했다.
- release package zip 내부 앱도 `RhwpMac.app`으로 생성되도록 수정했다.
- 수정된 `RhwpMac.app` 설치본에서 사용자 지정 samples 3개 모두 Finder thumbnail smoke test에 성공했다.

## 변경 파일

- `scripts/package-release.sh`
  - release zip 내부 app bundle name을 `알한글.app`에서 `RhwpMac.app`으로 변경했다.
  - `xcodebuild`가 사용자 Library의 기본 DerivedData를 사용하지 않도록 `-derivedDataPath build/release/DerivedData`를 지정했다.
  - package 종료 후 release 전용 DerivedData를 정리하도록 했다.
  - non-ASCII `.app` path가 ExtensionKit lookup을 깨뜨릴 수 있으므로 filesystem bundle name은 ASCII로 유지한다는 주석을 추가했다.
- `Casks/rhwp-mac.rb`
  - 설치 app stanza를 `app "RhwpMac.app"`으로 변경했다.
  - Cask의 사용자 표시 name은 `알한글`로 유지했다.
- `mydocs/manual/build_run_guide.md`
  - Finder 통합 smoke test 설치 경로를 `~/Applications/RhwpMac.app`으로 변경했다.
  - 사용자 표시명은 한글로 유지하되 filesystem bundle path는 ASCII로 유지해야 한다는 설명을 추가했다.
- `mydocs/manual/release_distribution_guide.md`
  - release zip/Cask 기준 app bundle name을 `RhwpMac.app`으로 갱신했다.
  - 한글 표시명과 ASCII filesystem path의 역할을 분리해 정리했다.
- `mydocs/tech/project_architecture.md`
  - 사용자 표시명과 filesystem app bundle name의 소유 경계를 최신 기준으로 갱신했다.

## 검증

### 1. 스크립트 문법

```bash
bash -n scripts/package-release.sh
```

결과: 성공

### 2. Info.plist lint

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

### 4. Release package

```bash
./scripts/package-release.sh 0.1.0
```

결과:

- 성공
- SHA256:
  - `8da1fee3ee70e1e5b1facfbfab6e9908fed041c9e804dcfa058eead7bf732322  rhwp-mac-0.1.0.zip`
- zip 내부 최상위 app bundle:
  - `RhwpMac.app/`
- staging 산출물:
  - `build/release/RhwpMac.app`
  - `build/release/rhwp-mac-0.1.0.zip`

첫 실행에서는 `xcodebuild`가 기본 DerivedData인 `~/Library/Developer/Xcode/DerivedData`에 로그와 workspace arena를 만들려다 sandbox 권한 오류로 실패했다. 이를 `scripts/package-release.sh`에서 release 전용 `build/release/DerivedData`를 사용하도록 수정한 뒤 package가 성공했다.

### 5. Package 산출물 표시명 확인

`build/release/RhwpMac.app/Contents/Info.plist`:

- `CFBundleDisplayName`: `알한글`
- `CFBundleName`: `알한글`
- `CFBundleIdentifier`: `com.postmelee.rhwpmac`

`build/release/RhwpMac.app/Contents/PlugIns/RhwpMacThumbnail.appex/Contents/Info.plist`:

- `CFBundleDisplayName`: `알한글 썸네일`
- `CFBundleName`: `알한글 썸네일`
- `CFBundleIdentifier`: `com.postmelee.rhwpmac.ThumbnailExtension`
- `NSExtensionPrincipalClass`: `RhwpMacThumbnail.HwpThumbnailProvider`

### 6. Finder thumbnail smoke test

설치/등록:

```bash
ditto build/release/RhwpMac.app /Users/melee/Applications/RhwpMac.app
lsregister -f -R -trusted /Users/melee/Applications/RhwpMac.app
pluginkit -a /Users/melee/Applications/RhwpMac.app
pluginkit -e use -i com.postmelee.rhwpmac.ThumbnailExtension
qlmanage -r
qlmanage -r cache
```

등록 확인:

```text
Path = /Users/melee/Applications/RhwpMac.app/Contents/PlugIns/RhwpMacThumbnail.appex
Display Name = 알한글 썸네일
Parent Bundle = /Users/melee/Applications/RhwpMac.app
```

사용자 지정 samples smoke test:

```bash
mkdir -p /tmp/rhwp-task33-stage3-ql
qlmanage -t -x -s 512 -o /tmp/rhwp-task33-stage3-ql \
  /Users/melee/Documents/projects/rhwp-mac/samples/group-drawing-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/pic-in-head-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

결과:

- `group-drawing-02.hwp`: thumbnail 1개 생성
- `pic-in-head-02.hwp`: thumbnail 1개 생성
- `basic/KTX.hwp`: thumbnail 1개 생성

생성 파일:

- `/tmp/rhwp-task33-stage3-ql/group-drawing-02.hwp.png`
- `/tmp/rhwp-task33-stage3-ql/pic-in-head-02.hwp.png`
- `/tmp/rhwp-task33-stage3-ql/KTX.hwp.png`

unified log에서는 `not found in LS database`가 더 이상 나오지 않았고, ExtensionKit이 `/Users/melee/Applications/RhwpMac.app/Contents/PlugIns/RhwpMacThumbnail.appex` 경로로 extension process를 생성했다.

## 현재 환경 상태

- `/Users/melee/Applications/RhwpMac.app`는 수정된 release staging 산출물 기준으로 설치/등록돼 있다.
- Stage 2 비교용 `/Users/melee/Applications/RhwpMac-task33-ascii.app`는 PlugInKit/LaunchServices 등록을 해제하고 파일도 제거했다.
- `/Users/melee/Applications/알한글.app` 파일은 삭제하지 않았지만, Stage 2에서 LaunchServices unregister 상태로 두었다.

## 판단

- 최소 수정은 code path가 아니라 package/install path 정책 정정이다.
- `HwpThumbnailProvider`는 `RhwpMac.app` ASCII path 설치본에서 정상 로드/실행된다.
- Quick Look thumbnail smoke test 실패 원인은 `알한글.app` filesystem path 및 중복/stale registration이 ExtensionKit의 LS lookup과 충돌한 것이다.
- 사용자에게 보이는 한글 앱 이름은 `CFBundleDisplayName`/`CFBundleName`으로 유지하고, 실제 `.app` 경로는 `RhwpMac.app`로 유지하는 것이 현재 macOS Quick Look extension 동작 기준에서 안정적이다.

## 다음 단계

Stage 4에서 다음을 진행한다.

- 최종 검증 묶음 재실행
- 최종 보고서 작성
- 오늘할일 갱신
- PR 준비 전 커밋 상태 확인

## 승인 요청

Stage 3 최소 수정과 검증을 완료했다. Stage 4 진행 승인을 요청한다.
