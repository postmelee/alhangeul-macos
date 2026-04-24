# Issue #33 Stage 2 완료 보고서

## 타스크

- GitHub Issue: #33
- 마일스톤: M050
- 제목: Quick Look thumbnail smoke test 실패 원인 분석
- 단계: Stage 2. LaunchServices, PlugInKit, Quick Look discovery 분리

## 요약

- Stage 1에서 확인한 ExtensionKit launch 실패를 LaunchServices/PlugInKit 계층으로 더 좁혔다.
- `/Users/melee/Applications/알한글.app` 경로의 plugin record는 LaunchServices dump에 존재하지만, ExtensionKit launch 시에는 같은 appex URL을 `not found in LS database`로 판단했다.
- 같은 빌드 산출물을 ASCII 경로 `/Users/melee/Applications/RhwpMac-task33-ascii.app`에 설치하고 한글 경로 등록을 제거한 뒤 단독 등록하면 thumbnail smoke test가 성공했다.
- 따라서 현재 실패의 직접 원인은 `HwpThumbnailProvider` 렌더링 로직이 아니라 한글 app path와 중복/stale registration이 결합된 LaunchServices/ExtensionKit discovery 불일치다.

## 수행 내용

### 1. 설치본과 appex 정적 상태 확인

- `/Users/melee/Applications/알한글.app/Contents/PlugIns`에는 다음 appex가 존재했다.
  - `RhwpMacPreview.appex`
  - `RhwpMacThumbnail.appex`
- `RhwpMacThumbnail.appex` Info.plist 주요 값:
  - `CFBundleIdentifier`: `com.postmelee.rhwpmac.ThumbnailExtension`
  - `CFBundleExecutable`: `RhwpMacThumbnail`
  - `NSExtensionPointIdentifier`: `com.apple.quicklook.thumbnail`
  - `NSExtensionPrincipalClass`: `RhwpMacThumbnail.HwpThumbnailProvider`
  - `QLSupportedContentTypes`: `com.haansoft.hancomofficeviewer.mac.hwp` 포함
- codesign은 ad-hoc local signing 상태로 확인됐다.

### 2. 한글 경로 설치본의 LaunchServices dump 확인

`lsregister -dump`에서 host app과 plugin record가 모두 확인됐다.

- Host app:
  - path: `/Users/melee/Applications/알한글.app`
  - identifier: `com.postmelee.rhwpmac`
  - plugin identifiers: `com.postmelee.rhwpmac.QLExtension`, `com.postmelee.rhwpmac.ThumbnailExtension`
- Thumbnail plugin:
  - path: `/Users/melee/Applications/알한글.app/Contents/PlugIns/RhwpMacThumbnail.appex`
  - identifier: `com.postmelee.rhwpmac.ThumbnailExtension`
  - parent: `알한글`

하지만 `qlmanage -t` 실행 시 unified log는 다음 오류를 반복했다.

```text
Extension `com.postmelee.rhwpmac.ThumbnailExtension`,
URL `file:///Users/melee/Applications/.../RhwpMacThumbnail.appex/`
not found in LS database
```

즉 `pluginkit`/`lsregister -dump` 기준 등록과 ExtensionKit launch 기준 lookup이 일치하지 않았다.

### 3. appex 명시 등록 비교

다음처럼 appex 자체를 명시 등록했다.

```bash
lsregister -f -R -trusted /Users/melee/Applications/알한글.app/Contents/PlugIns/RhwpMacThumbnail.appex
lsregister -f -R -trusted /Users/melee/Applications/알한글.app/Contents/PlugIns/RhwpMacPreview.appex
```

결과:

- `qlmanage -t` 실패는 유지됐다.
- unified log의 실패 메시지도 동일하게 `not found in LS database`였다.

따라서 단순히 appex 경로를 추가 등록하는 절차만으로는 해결되지 않았다.

### 4. ASCII path 설치본 비교

같은 signed Debug app을 ASCII 경로에 복사했다.

```bash
ditto build/DerivedDataTask33Signed/Build/Products/Debug/RhwpMac.app \
  /Users/melee/Applications/RhwpMac-task33-ascii.app
```

처음에는 한글 경로 설치본과 같은 bundle id가 중복되어 `pkd`가 다음 상태를 기록했다.

- 같은 modification date의 다른 plugin 감지
- 기존 한글 경로 plugin이 precedent로 유지됨
- ASCII 경로 plugin은 실제 `qlmanage`에서 사용되지 않음

이후 한글 경로 parent app을 LaunchServices에서 unregister하고 ASCII 경로 설치본만 등록했다.

```bash
lsregister -u /Users/melee/Applications/알한글.app
lsregister -f -R -trusted /Users/melee/Applications/RhwpMac-task33-ascii.app
pluginkit -a /Users/melee/Applications/RhwpMac-task33-ascii.app
pluginkit -e use -i com.postmelee.rhwpmac.ThumbnailExtension
```

`pluginkit -mAvvv -i com.postmelee.rhwpmac.ThumbnailExtension` 결과는 ASCII path 단독 후보로 바뀌었다.

```text
Path = /Users/melee/Applications/RhwpMac-task33-ascii.app/Contents/PlugIns/RhwpMacThumbnail.appex
Parent Bundle = /Users/melee/Applications/RhwpMac-task33-ascii.app
```

### 5. samples smoke test 결과

ASCII path 단독 등록 상태에서 사용자 지정 samples 파일 3개를 확인했다.

```bash
qlmanage -t -x -s 512 -o /tmp/rhwp-task33-ql-samples \
  /Users/melee/Documents/projects/rhwp-mac/samples/group-drawing-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/pic-in-head-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

결과:

- `group-drawing-02.hwp`: thumbnail 1개 생성
- `pic-in-head-02.hwp`: thumbnail 1개 생성
- `basic/KTX.hwp`: thumbnail 1개 생성

생성 파일:

- `/tmp/rhwp-task33-ql-samples/group-drawing-02.hwp.png`
- `/tmp/rhwp-task33-ql-samples/pic-in-head-02.hwp.png`
- `/tmp/rhwp-task33-ql-samples/KTX.hwp.png`

성공 로그에서는 ExtensionKit이 실제 extension process를 생성했다.

```text
Created new process ExtensionProcess:
bundleID: com.postmelee.rhwpmac.ThumbnailExtension
pid: ...
```

## 판단

- 같은 빌드, 같은 bundle id, 같은 provider, 같은 표시명 조건에서 설치 경로만 ASCII 단독 상태로 바꾸면 성공한다.
- `알한글`이라는 사용자 표시명 자체가 문제라고 볼 근거는 없다. ASCII 설치본의 extension display name은 계속 `알한글 썸네일`이었다.
- 실패 조건은 한글 `.app` filesystem path와 중복/stale registration이 결합될 때 재현된다.
- `qlmanage -m plugins` 미노출은 이번 실패의 직접 원인으로 보기 어렵다. app extension 기반 Quick Look thumbnail은 legacy `.qlgenerator` 목록에 나타나지 않아도 ASCII 단독 등록 상태에서는 정상 생성됐다.
- Stage 3에서는 배포/설치 산출물의 bundle filesystem name을 ASCII로 유지하고, 사용자 표시명만 `알한글`로 유지하는 방향을 우선 검토한다.

## 현재 환경 상태

- `/Users/melee/Applications/알한글.app` 파일은 삭제하지 않았다.
- 비교를 위해 한글 경로 parent app은 LaunchServices에서 unregister했다.
- 현재 PlugInKit thumbnail 후보는 `/Users/melee/Applications/RhwpMac-task33-ascii.app` 기준이다.
- 임시 ASCII 설치본 `/Users/melee/Applications/RhwpMac-task33-ascii.app`은 Stage 3 검증에 재사용할 수 있다.

## 다음 단계

Stage 3에서 다음을 진행한다.

- package/install 절차가 한글 filesystem path를 만들지 않도록 하는 최소 수정 범위 확인
- source/project 설정 수정이 필요한지, manual/build-run guide 정리만으로 충분한지 판단
- 변경이 필요하면 `project.yml`, packaging script, build/run guide 중 실제 원인과 맞는 최소 범위만 수정
- 수정 후 `/Users/melee/Documents/projects/rhwp-mac/samples` 기준 smoke test를 재실행

## 승인 요청

Stage 2 LaunchServices, PlugInKit, Quick Look discovery 분리를 완료했다. Stage 3 진행 승인을 요청한다.
