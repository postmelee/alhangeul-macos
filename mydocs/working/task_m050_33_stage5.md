# Issue #33 Stage 5 완료 보고서

## 타스크

- GitHub Issue: #33
- 마일스톤: M050
- 제목: Quick Look thumbnail smoke test 실패 원인 분석
- 단계: Stage 5. 검증과 보고서

## 요약

- `AlhangeulMac.xcodeproj` 기준으로 최종 검증 묶음을 재실행했다.
- release package는 `alhangeul-macos-0.1.0.zip`으로 생성됐고, zip 내부 최상위 app bundle은 `AlhangeulMac.app/`이다.
- 사용자 표시명은 `알한글`, `알한글 미리보기`, `알한글 썸네일`로 유지됐다.
- `/Users/melee/Documents/projects/rhwp-mac/samples`의 지정 샘플 3개 모두 thumbnail 생성에 성공했다.
- 최종 결과 보고서 `mydocs/report/task_m050_33_report.md`를 작성했다.

## 최종 검증 결과

### 1. Xcode project 재생성

```bash
xcodegen generate
```

결과: 성공

### 2. plist lint

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

### 4. package script 문법

```bash
bash -n scripts/package-release.sh
```

결과: 성공

### 5. 현재 운영 문서 이름 검색

```bash
rg -n "RhwpMac|rhwpmac|rhwp-mac|알한글\\.app" README.md .github AGENTS.md mydocs/manual mydocs/tech project.yml Sources scripts Casks
```

결과:

- 현재 운영 문서와 소스에는 기존 `RhwpMac`/`rhwpmac`/`알한글.app` 기준이 남아 있지 않다.
- 검색 결과로 남는 `rhwp-macos 기준 완전 이관`은 GitHub milestone 이름이다.

### 6. Debug build

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

### 7. Release package

```bash
./scripts/package-release.sh 0.1.0
```

결과:

- 성공
- SHA256:
  - `9a09ae057ad0cfc4e5a3cc76e4f1557350133069f8c4361da41045848d613cf4  alhangeul-macos-0.1.0.zip`
- zip 내부 최상위 app bundle:
  - `AlhangeulMac.app/`
- staging 산출물:
  - `build/release/AlhangeulMac.app`
  - `build/release/alhangeul-macos-0.1.0.zip`

### 8. 산출물 Info.plist 확인

`build/release/AlhangeulMac.app/Contents/Info.plist`:

- `CFBundleDisplayName`: `알한글`
- `CFBundleName`: `알한글`
- `CFBundleExecutable`: `AlhangeulMacHost`
- `CFBundleIdentifier`: `com.postmelee.alhangeulmac`

`build/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex/Contents/Info.plist`:

- `CFBundleDisplayName`: `알한글 썸네일`
- `CFBundleName`: `알한글 썸네일`
- `CFBundleExecutable`: `AlhangeulMacThumbnail`
- `CFBundleIdentifier`: `com.postmelee.alhangeulmac.ThumbnailExtension`
- `NSExtensionPrincipalClass`: `AlhangeulMacThumbnail.HwpThumbnailProvider`

### 9. 설치본 등록 확인

설치/등록:

```bash
ditto build/release/AlhangeulMac.app /Users/melee/Applications/AlhangeulMac.app
lsregister -u /Users/melee/Applications/RhwpMac.app
lsregister -u /Users/melee/Applications/알한글.app
lsregister -f -R -trusted /Users/melee/Applications/AlhangeulMac.app
pluginkit -a /Users/melee/Applications/AlhangeulMac.app
pluginkit -e use -i com.postmelee.alhangeulmac.QLExtension
pluginkit -e use -i com.postmelee.alhangeulmac.ThumbnailExtension
qlmanage -r
qlmanage -r cache
```

등록 확인:

- `com.postmelee.alhangeulmac.QLExtension`
  - path: `/Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex`
  - display name: `알한글 미리보기`
- `com.postmelee.alhangeulmac.ThumbnailExtension`
  - path: `/Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex`
  - display name: `알한글 썸네일`

샘플 UTI:

```bash
mdls -name kMDItemContentType /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

결과:

- `kMDItemContentType = "com.haansoft.hancomofficeviewer.mac.hwp"`

`qlmanage -m plugins` 검색:

- `alhangeul`, `postmelee`, `hwp`, `hwpx`, `한글` 검색 결과 없음
- Stage 2에서 확인한 대로 app extension 등록/실행과 `qlmanage -m plugins` 출력은 별도 계층으로 판단한다.

### 10. Finder thumbnail smoke test

```bash
mkdir -p /tmp/rhwp-task33-stage5-ql
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

## 현재 환경 상태

- `/Users/melee/Applications/AlhangeulMac.app`는 최종 release staging 산출물 기준으로 설치/등록돼 있다.
- `/Users/melee/Applications/RhwpMac.app`와 `/Users/melee/Applications/알한글.app` 파일은 삭제하지 않았다.
- 기존 두 경로는 LaunchServices unregister를 시도했고, 최종 PlugInKit 확인은 `AlhangeulMac.app` 기준이다.

## 판단

- Issue #33의 원인은 Thumbnail provider 코드 문제가 아니라 non-ASCII `.app` path 및 stale/duplicate registration이 ExtensionKit lookup과 충돌한 것이다.
- 안정화 방향은 사용자 표시명 `알한글`을 유지하면서 filesystem/project/distribution 이름을 ASCII `AlhangeulMac`/`alhangeul-macos` 계열로 유지하는 것이다.
- 최종 검증 기준에서 thumbnail smoke test는 성공했다.

## 다음 단계

- 작업지시자 최종 보고서 승인 후 `publish/task33` 원격 브랜치로 push하고 `devel` 대상 draft PR을 생성한다.

## 승인 요청

Stage 5 최종 검증과 보고서 작성을 완료했다. 최종 보고서 승인 및 PR 준비 단계 진행 승인을 요청한다.
