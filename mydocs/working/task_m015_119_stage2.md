# Task M015 #119 Stage 2 완료 보고서

## 단계 목적

HostApp, Quick Look, Thumbnail이 같은 process-local font registration 정책을 쓰도록 공통 helper를 추가하고, Stage 1에서 확정한 `rhwp-studio` WOFF2 직접 재사용 전략을 코드에 반영한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | bundled WOFF2 allowlist, font directory 탐색, CoreText process-local registration helper 추가 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | page render 시작 시 bundled font registration 보장 |
| `Sources/RhwpCoreBridge/FontFallback.swift` | `resolveAppleFont` 호출 시 bundled font registration 보장 |
| `AlhangeulMac.xcodeproj/project.pbxproj` | XcodeGen 산출물에 `FontResourceRegistry.swift` 포함 |
| `scripts/check-no-appkit.sh` | 새 shared Swift 파일을 AppKit/UIKit 금지 검증 대상에 포함 |
| `scripts/validate-stage3-render.sh` | smoke compile 파일 목록에 `FontResourceRegistry.swift` 포함 |
| `scripts/render-debug-compare.sh` | debug compare compile 파일 목록에 `FontResourceRegistry.swift` 포함 |
| `mydocs/working/task_m015_119_stage2.md` | Stage 2 구현/검증 결과 |
| `mydocs/orders/20260503.md` | #119 상태를 Stage 2 완료 승인 대기로 갱신 |

라인 수:

```text
187 Sources/RhwpCoreBridge/FontResourceRegistry.swift
 87 Sources/RhwpCoreBridge/FontFallback.swift
1966 Sources/RhwpCoreBridge/CGTreeRenderer.swift
 28 scripts/check-no-appkit.sh
182 scripts/render-debug-compare.sh
 85 scripts/validate-stage3-render.sh
910 AlhangeulMac.xcodeproj/project.pbxproj
```

## 구현 내용

### 1. WOFF2 allowlist 기반 등록 helper

`HwpBundledFontRegistry`를 추가했다.

- `rhwp-studio/fonts`에 포함된 오픈 라이선스 WOFF2 34개를 allowlist로 관리한다.
- `CTFontManagerRegisterFontsForURL(..., .process, ...)`로 process-local 등록한다.
- 동일 process에서 중복 등록하지 않도록 `NSLock`과 cached status를 둔다.
- `kCTFontManagerErrorAlreadyRegistered`는 성공과 동일하게 취급한다.
- 등록 실패, resource 누락, font directory 미발견은 crash가 아니라 `registeredCount == 0` 상태로 남기고 기존 fallback이 계속 동작하게 한다.

Stage 1에서 proprietary font 파일은 Git에 포함하지 않는 정책을 확인했으므로, directory 전체 scan 대신 allowlist 등록을 택했다. 로컬에 별도로 proprietary WOFF2를 넣은 상태에서도 이번 native renderer가 그 파일을 자동 등록하지 않게 하기 위한 선택이다.

### 2. HostApp/extension resource lookup

font directory 후보는 다음 순서로 찾는다.

1. `Bundle.main.resourceURL/rhwp-studio/fonts`
2. bundle/resource URL의 ancestor 중 `Contents` 아래 `Resources/rhwp-studio/fonts`
3. 개발/스크립트 실행용 current working directory의 `Sources/HostApp/Resources/rhwp-studio/fonts`

이 구조는 HostApp process에서는 app resource를 직접 찾고, Quick Look/Thumbnail extension process에서는 `AlhangeulMac.app/Contents/PlugIns/*.appex`에서 parent app의 `Contents/Resources/rhwp-studio/fonts`를 찾도록 설계했다.

### 3. renderer 진입점 연결

`CGTreeRenderer.render(...)` 시작 시 `HwpBundledFontRegistry.ensureRegistered()`를 호출한다. Quick Look/Thumbnail/HostApp native bitmap render가 모두 이 경로를 공유하므로 실제 page rendering 전에 한 번 등록된다.

기존 standalone font helper인 `resolveAppleFont(...)`에서도 같은 registration을 보장했다.

### 4. 검증 스크립트 갱신

`validate-stage3-render.sh`와 `render-debug-compare.sh`는 Swift source list를 수동으로 넘긴다. 새 registry 파일을 추가하지 않으면 smoke/debug compile이 실패하므로 두 스크립트에 `FontResourceRegistry.swift`를 포함했다.

`check-no-appkit.sh`도 새 shared Swift 파일을 검사하도록 갱신했다.

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 변환 작업이 아니므로 본문 무손실 검증 대상은 없다.

이번 단계의 제품 코드 변경은 font registration 준비와 검증 스크립트 compile list 갱신에 한정했다. HWP font alias mapping 자체는 Stage 3에서 변경한다.

## 검증 결과

### Stage 2 계획 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge Sources/Shared project.yml
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

결과:

- `./scripts/check-no-appkit.sh`: 성공

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

- `xcodegen generate`: 성공

```text
Created project at /tmp/rhwp-mac-task119/AlhangeulMac.xcodeproj
```

- `xcodebuild ... build`: 성공

```text
** BUILD SUCCEEDED ** [1.379 sec]
```

- `git diff --check`: 성공

### 추가 검증

새 registry 파일이 render smoke script compile path에 들어가는지 확인하기 위해 KTX 샘플 smoke를 추가 실행했다.

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task119-stage2-smoke samples/basic/KTX.hwp
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452386 png=/private/tmp/rhwp-task119-stage2-smoke/KTX-page1.png
```

빌드 산출물의 resource 배치도 확인했다.

```bash
test -d build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/fonts
find build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/fonts -name '*.woff2' -type f | wc -l
test ! -d build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex/Contents/Resources/rhwp-studio/fonts
test ! -d build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex/Contents/Resources/rhwp-studio/fonts
```

결과:

- HostApp resource에 WOFF2 34개 포함 확인
- QLExtension/ThumbnailExtension 내부에는 중복 font resource가 없음 확인

### 검증 중 확인한 환경 이슈

분리 worktree에는 generated `Frameworks/Rhwp.xcframework`가 없어서 첫 `xcodebuild`는 framework missing으로 실패했다. 메인 worktree의 generated `Frameworks`를 `/private/tmp/rhwp-mac-task119/Frameworks`로 복사해 검증 환경을 맞췄다. `Frameworks`와 `build.noindex`는 생성 산출물이며 커밋 대상이 아니다.

sandbox 안의 `xcodebuild`는 Xcode log/DerivedData 접근과 XCFramework 처리에서 실패했으므로, 동일 명령을 승인된 sandbox 외부 실행으로 검증했다.

## 잔여 위험

- parent app resource lookup은 코드로 구현됐지만, 실제 PlugInKit/Quick Look runtime에서 parent app resource 접근이 항상 허용되는지는 Stage 4 Quick Look/Thumbnail smoke에서 다시 확인해야 한다.
- Stage 2는 font registration 준비만 수행했다. 실제 HWP font family를 bundled font PostScript name으로 매핑하는 작업은 Stage 3에 남아 있다.
- Noto 계열 PostScript name은 파일명과 다르다. Stage 3에서 mapping을 파일명 기반으로 하면 안 된다.
- `HwpFontRegistrationStatus`는 현재 내부 진단용 구조이며 UI 노출이나 logging은 하지 않는다. 필요하면 후속 단계에서 debug summary에 연결한다.

## 다음 단계 영향

Stage 3에서는 `FontFallback.swift`의 HWP font alias mapping을 bundled font 우선 fallback chain으로 바꾼다. Stage 2에서 WOFF2 등록이 render 시작 전에 보장되므로, Stage 3은 PostScript name과 fallback 순서에 집중하면 된다.

## 승인 요청

Stage 3. HWP font alias 매핑과 CoreText 선택 정책 보강 진행 승인을 요청한다.
