# Issue #40 Quick Look/Thumbnail 등록 검증 시행착오 분석

## 목적

Issue #33과 Issue #40에서 Quick Look/Thumbnail 검증 중 반복된 삭제, 재설치, 재등록 시행착오의 원인을 정리하고 재발 방지 기준을 고정한다.

## 결론

반복 시행착오의 직접 원인은 Quick Look/Thumbnail 검증에 서로 다른 목적의 산출물을 섞어 사용한 것이다.

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 compile/link 확인용이다.
- LaunchServices/PlugInKit 등록 검증은 signed/sealed된 app bundle이 필요하다.
- 실제 Finder/Quick Look 실행 확인은 단일 설치 경로의 Release package 산출물로 해야 한다.
- Spotlight/Dock/Finder 표시명은 extension 등록 실패와 별개의 LaunchServices/Spotlight metadata 및 사용자 언어/캐시 문제다.

## 원인 분석

### 1. 새 worktree에는 generated framework가 없다

`Frameworks/Rhwp.xcframework`는 git에 commit하지 않는 생성 산출물이다. 새 worktree에서 곧바로 `xcodebuild`를 실행하면 다음 오류가 날 수 있다.

```text
There is no XCFramework found at '.../Frameworks/Rhwp.xcframework'
```

이것은 코드 회귀가 아니라 준비 단계 누락이다.

표준 준비:

```bash
git submodule update --init --recursive
./scripts/build-rust-macos.sh
```

첫 실패 후 같은 DerivedData 경로를 재사용하면 stale build description이 남을 수 있으므로, 산출물 생성 후에는 새 `-derivedDataPath`를 쓰는 편이 명확하다.

### 2. Debug `CODE_SIGNING_ALLOWED=NO` 산출물은 PlugInKit 검증에 부적합하다

`CODE_SIGNING_ALLOWED=NO` Debug app은 실행 파일 자체는 linker-signed 될 수 있지만 bundle 관점에서는 다음 상태가 될 수 있다.

```text
Info.plist=not bound
Sealed Resources=none
```

이 산출물은 `find ... InfoPlist.strings`, `plutil`, 앱 실행 확인에는 충분할 수 있다. 그러나 PlugInKit registration smoke test의 기준 산출물로 쓰면 extension이 목록에 나타나지 않아 문제를 잘못 추적하게 된다.

### 3. Release package 산출물은 registration smoke test 기준에 더 가깝다

`./scripts/package-release.sh <version>`은 다음을 수행한다.

- Rust bridge와 `Rhwp.xcframework` 재생성
- XcodeGen project 재생성
- Release configuration build
- `AlhangeulMac.app` staging
- local signing과 sealed resources 적용
- zip 생성과 SHA256 출력

따라서 LaunchServices/PlugInKit 등록 확인과 `qlmanage -t` smoke test에는 `build/release/AlhangeulMac.app`을 기준으로 사용한다.

### 4. app bundle filesystem name과 사용자 표시명은 분리한다

Issue #33에서 non-ASCII filesystem path인 `알한글.app`은 ExtensionKit lookup에서 `not found in LS database` 문제를 유발할 수 있음을 확인했다.

표준:

- filesystem path: `/Users/melee/Applications/AlhangeulMac.app`
- 기본 `Info.plist` 표시명: 실제 bundle filesystem name과 일치하는 `AlhangeulMac`
- 한국어 사용자 표시명: `ko.lproj/InfoPlist.strings`의 `알한글`
- 영어 사용자 표시명: `en.lproj/InfoPlist.strings`의 `AlhangeulMac`
- localized 표시명 사용 선언: `LSHasLocalizedDisplayName = true`

사용자에게 한글 이름을 보여주기 위해 `.app` 디렉터리 자체를 `알한글.app`으로 바꾸지 않는다.

Apple의 `Core Foundation Keys` 문서에서 `CFBundleDisplayName`은 localized bundle name을 지원할 때 `Info.plist`와 언어별 `InfoPlist.strings`에 함께 넣어야 하는 키로 설명된다. 같은 문서는 macOS Finder가 localized name을 표시하기 전에 기본 표시명과 실제 filesystem name을 비교한다고 설명한다. 따라서 기본 plist 값을 한글로 직접 두면 `AlhangeulMac.app`과 불일치해 Spotlight/Finder가 `AlhangeulMac`만 신뢰하는 상태가 될 수 있다. 카카오톡도 같은 이유로 기본 plist는 `KakaoTalk`, `ko.lproj/InfoPlist.strings`는 `카카오톡` 구조를 사용한다.

Apple의 `Display Names` 문서는 localized display name을 지원하는 앱에 `LSHasLocalizedDisplayName`을 포함하는 것을 권장한다.

extension도 같은 원칙을 적용한다.

| Bundle | 기본 `Info.plist` 표시명 | 한국어 `InfoPlist.strings` |
|--------|--------------------------|-----------------------------|
| `AlhangeulMac.app` | `AlhangeulMac` | `알한글` |
| `AlhangeulMacPreview.appex` | `AlhangeulMacPreview` | `알한글 미리보기` |
| `AlhangeulMacThumbnail.appex` | `AlhangeulMacThumbnail` | `알한글 썸네일` |

### 5. `qlmanage -m plugins`는 판정 기준이 아니다

app extension 기반 Quick Look/Thumbnail은 `qlmanage -m plugins`에 기대한 방식으로 나타나지 않을 수 있다. 이 출력이 비어 있어도 extension 실행이 반드시 실패했다는 뜻은 아니다.

판정 기준:

- 등록 후보: `pluginkit -mAvvv | grep com.postmelee.alhangeulmac`
- 파일 UTI: `mdls -name kMDItemContentType <sample>`
- 실제 thumbnail 생성: `qlmanage -t -x -s 512 -o <out-dir> <sample>`
- GUI preview: 작업지시자 확인이 가능한 경우 `qlmanage -p <sample>`

## 표준 검증 절차

### 1. 준비

```bash
git submodule update --init --recursive
./scripts/build-rust-macos.sh
xcodegen generate
```

### 2. compile/link 확인

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build/DerivedDataDebug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

이 단계에서는 `pluginkit` 등록 성공 여부를 판단하지 않는다.

### 3. registration smoke 기준 산출물 생성

```bash
./scripts/package-release.sh 0.1.0
```

### 4. 단일 설치 경로로 교체

```bash
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
mkdir -p /Users/melee/Applications
"$LSREGISTER" -u /Users/melee/Applications/AlhangeulMac.app >/dev/null 2>&1 || true
rm -rf /Users/melee/Applications/AlhangeulMac.app
ditto build/release/AlhangeulMac.app /Users/melee/Applications/AlhangeulMac.app
"$LSREGISTER" -f -R -trusted /Users/melee/Applications/AlhangeulMac.app
pluginkit -a /Users/melee/Applications/AlhangeulMac.app
```

주의:

- 이 절차에서 제거하는 경로는 표준 설치 경로인 `/Users/melee/Applications/AlhangeulMac.app` 하나뿐이다.
- `RhwpMac.app`, `알한글.app` 등 이전 이름의 설치본은 충돌이 의심될 때만 작업지시자 승인 후 제거한다.

### 5. 등록 확인

```bash
pluginkit -mAvvv | grep com.postmelee.alhangeulmac
```

기대:

- `com.postmelee.alhangeulmac.QLExtension`
- `com.postmelee.alhangeulmac.ThumbnailExtension`
- parent bundle이 `/Users/melee/Applications/AlhangeulMac.app`

### 6. 실제 thumbnail smoke

```bash
mkdir -p /tmp/alhangeul-ql
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

사용자 요청이 있으면 `/Users/melee/Documents/projects/rhwp-mac/samples` 아래 파일을 우선 사용한다.

## 증상별 판단표

| 증상 | 우선 판단 | 다음 확인 |
|------|-----------|-----------|
| `Rhwp.xcframework` 없음 | 생성 산출물 누락 | `git submodule update --init --recursive`, `./scripts/build-rust-macos.sh` |
| Debug app이 `pluginkit`에 안 보임 | Debug 산출물 특성일 가능성 높음 | Release package 산출물로 재검증 |
| `pluginkit` parent bundle이 이전 경로 | stale install/discovery 후보 | 표준 경로 재등록, 이전 설치본은 승인 후 제거 |
| `qlmanage -m plugins`에 안 보임 | 판정 기준 아님 | `pluginkit -mAvvv`, `qlmanage -t -x` 확인 |
| Spotlight/Dock이 `AlhangeulMac`만 검색/표시 | 기본 plist와 bundle name 불일치 또는 캐시 문제 | `CFBundleDisplayName`, `CFBundleName`, `LSHasLocalizedDisplayName`, `InfoPlist.strings`, `mdfind` 확인 |
| thumbnail 생성 실패 | registration 또는 renderer 문제 | `pluginkit`, `mdls kMDItemContentType`, `qlmanage -t -x`, unified log 순서로 확인 |

## 금지할 습관

- Debug `CODE_SIGNING_ALLOWED=NO` 산출물로 extension 등록 성공/실패를 결론 내리지 않는다.
- 문제가 보인다고 이전 앱 후보들을 무작정 삭제하지 않는다.
- `qlmanage -m plugins` 미노출만으로 실패를 확정하지 않는다.
- filesystem bundle name을 한글로 바꾸어 표시명 문제를 해결하려 하지 않는다.
- 기본 `Info.plist` 표시명을 실제 bundle filesystem name과 다르게 두지 않는다.
- 설치본 교체, LaunchServices 등록, PlugInKit 등록, Quick Look cache reset을 순서 없이 반복하지 않는다.

## 문서 반영

이 기준은 다음 문서에도 반영했다.

- `AGENTS.md`
- `README.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/tech/project_architecture.md`
