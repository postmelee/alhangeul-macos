# Issue #33 Stage 1 완료 보고서

## 타스크

- GitHub Issue: #33
- 마일스톤: M050
- 제목: Quick Look thumbnail smoke test 실패 원인 분석
- 단계: Stage 1. 기준 상태 동기화와 재현 조건 고정

## 요약

- `devel`을 최신화한 뒤 `local/task33` worktree를 `22aa57f` 기준으로 맞췄다.
- 조사 worktree는 `/tmp/rhwp-mac-task33`이며, 테스트 파일은 작업지시자 지정 경로인 `/Users/melee/Documents/projects/rhwp-mac/samples`를 사용했다.
- signed Debug app을 `/Users/melee/Applications/알한글.app`에 설치하고 LaunchServices/PlugInKit 등록을 재확인했다.
- 대표 샘플 3개 모두 `qlmanage -t`에서 `No thumbnail created`로 실패했다.
- unified log 기준 실패 지점은 provider 내부 렌더링 전이며, ExtensionKit launch 단계에서 thumbnail appex URL을 LaunchServices DB에서 찾지 못한다.

## 기준 상태

- 기준 commit: `22aa57f Merge pull request #38 from postmelee/publish/task37`
- worktree: `/tmp/rhwp-mac-task33`
- branch: `local/task33`
- 설치본: `/Users/melee/Applications/알한글.app`
- 테스트 샘플:
  - `/Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp`
  - `/Users/melee/Documents/projects/rhwp-mac/samples/group-drawing-02.hwp`
  - `/Users/melee/Documents/projects/rhwp-mac/samples/pic-in-head-02.hwp`

## 수행 내용

1. `devel` 최신화 후 `local/task33`을 fast-forward 기준으로 맞췄다.
2. `xcodegen generate`를 실행해 project를 재생성했다.
3. `git submodule update --init --recursive`로 `Vendor/rhwp`를 lockfile 기준 commit에 맞췄다.
4. `./scripts/build-rust-macos.sh`로 `Frameworks/Rhwp.xcframework`를 생성했다.
5. `xcodebuild` Debug build를 `CODE_SIGNING_ALLOWED=NO`와 local signing 양쪽으로 확인했다.
6. local signing 산출물을 `/Users/melee/Applications/알한글.app`에 설치했다.
7. `lsregister -f -R -trusted /Users/melee/Applications/알한글.app` 후 `pluginkit -a`로 등록했다.
8. `pluginkit -mAvvv`와 `qlmanage` smoke test, unified log를 확인했다.

## 확인 결과

### 정적 설정

- Host app bundle id는 `com.postmelee.rhwpmac`로 확장 bundle id의 parent와 일치한다.
- Thumbnail extension bundle id는 `com.postmelee.rhwpmac.ThumbnailExtension`이다.
- Thumbnail extension principal class는 산출물 기준 `RhwpMacThumbnail.HwpThumbnailProvider`로 확장됐다.
- `QLSupportedContentTypes`에는 `com.haansoft.hancomofficeviewer.mac.hwp`가 포함돼 있다.
- `samples/basic/KTX.hwp`의 UTI는 `com.haansoft.hancomofficeviewer.mac.hwp`로 확인됐다.

### 등록 계층

- `pluginkit -a`만 실행했을 때는 extension match가 나오지 않았다.
- 명시적 LaunchServices 등록 후 `pluginkit -a`를 다시 실행하면 다음 항목이 확인됐다.
  - `com.postmelee.rhwpmac.QLExtension`
  - `com.postmelee.rhwpmac.ThumbnailExtension`
- `pluginkit -e use`는 두 extension 모두 오류 없이 완료됐다.
- `qlmanage -m plugins`에는 여전히 system `.qlgenerator`만 표시되고 `rhwp`, `hwp`, `알한글`, `postmelee` 관련 항목은 표시되지 않았다.

### thumbnail smoke test

다음 명령으로 대표 샘플 3개를 확인했다.

```bash
qlmanage -t -x -s 512 -o /tmp/rhwp-task33-ql-samples \
  /Users/melee/Documents/projects/rhwp-mac/samples/group-drawing-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/pic-in-head-02.hwp \
  /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

결과:

- `group-drawing-02.hwp`: `No thumbnail created`
- `pic-in-head-02.hwp`: `No thumbnail created`
- `basic/KTX.hwp`: `No thumbnail created`

### unified log

`qlmanage` 실행 시 `com.apple.quicklook.ThumbnailsAgent`가 thumbnail extension을 선택하려고 시도한 뒤 ExtensionKit launch에서 실패했다.

핵심 메시지:

```text
Launch failed with error: Error Domain=com.apple.extensionKit.errorDomain Code=5
Extension `com.postmelee.rhwpmac.ThumbnailExtension`, URL `file:///Users/melee/Applications/.../RhwpMacThumbnail.appex/` not found in LS database
```

이 메시지 때문에 `HwpThumbnailProvider` 내부 렌더링 실패로 보기 어렵다. 현재 실패는 provider 실행 전의 LaunchServices/ExtensionKit 등록 불일치로 좁혀졌다.

## 판단

- #33의 최초 증상인 `qlmanage -t` 실패는 현재 `devel` 최신 기준에서도 재현된다.
- `pluginkit` 등록은 보이지만, ExtensionKit이 실제 process launch를 할 때 같은 appex URL을 LaunchServices DB에서 찾지 못한다.
- 다음 단계는 stale extension 등록, appex path/name 불일치, LaunchServices DB 등록 범위, BackgroundTaskManagement 잔존 항목을 분리해 확인하는 것이 우선이다.
- 아직 source code의 thumbnail render path를 수정할 근거는 없다.

## 다음 단계

Stage 2에서 다음 항목을 확인한다.

- LaunchServices DB 내 현재 app/appex 등록 경로와 stale 등록 항목 분리
- `pluginkit`에 표시되는 path와 ExtensionKit launch 시 사용하는 URL 대조
- 기존 `RhwpMac.app`, `알한글 Preview.appex`, `알한글 Thumbnail.appex` 잔존 등록 여부 확인
- 등록 절차만으로 해결되는지, `project.yml`/Info.plist 설정 수정이 필요한지 판단

## 승인 요청

Stage 1 기준 상태 동기화와 재현 조건 고정을 완료했다. Stage 2 진행 승인을 요청한다.
