# Task #282 Stage 2 보고서

## 단계 목적

Quick Look/Thumbnail native CoreGraphics 렌더러가 rhwp-studio의 flow/overlay 구조로 갈 수 있도록 기존 단일 pass 렌더 경로를 background, behind overlay, flow, front overlay pass로 분리했다.

이번 단계는 실제 compact overlay image bytes를 별도 주입해 그리는 완성 단계가 아니라, pass 경계와 순서 보존을 먼저 만든 준비 단계다.

## 산출물

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
  - `CGTreeOverlayLayer`, `CGTreeRenderMode`를 추가했다.
  - `complete`, `pageBackground`, `flowExcludingPageOverlays`, `pageOverlay` 모드로 같은 render tree를 여러 pass에서 재사용할 수 있게 했다.
  - `BehindText`, `InFrontOfText` textWrap 정규화를 `-`, `_`, 대소문자 차이에 견디도록 처리했다.
- `Sources/Shared/HwpNativePageCompositor.swift`
  - native page compositor를 새로 추가했다.
  - render tree의 image textWrap과 #281 overlay metadata를 함께 보고 필요한 overlay pass를 결정한다.
  - overlay metadata가 비어 있어도 render tree에 overlay textWrap이 있으면 기존 layer 순서를 잃지 않도록 했다.
- `Sources/Shared/HwpPageImageRenderer.swift`
  - CoreGraphics fallback 렌더 경로에서 render tree decode 후 `pageOverlayImages` metadata를 조회하고 compositor로 위임하도록 변경했다.
- `scripts/preview-visual-diff-harness.sh`, `scripts/smoke-quicklook-skia-policy.sh`, `scripts/compare-quicklook-pdf-renderers.sh`
  - standalone Swift compile 대상에 `PageOverlayImages.swift`, `HwpNativePageCompositor.swift`를 추가했다.
- `Alhangeul.xcodeproj/project.pbxproj`
  - `xcodegen generate`로 `HwpNativePageCompositor.swift`를 HostApp, QLExtension, ThumbnailExtension source phase에 반영했다.

## 본문 변경 / 무손실

문서 파싱 결과나 문서 본문 데이터는 변경하지 않았다. 변경 범위는 native CoreGraphics 렌더링 순서와 빌드/검증 스크립트 compile list에 한정된다.

현재 샘플의 visual diff 수치는 Stage 1 baseline과 동일하게 유지됐다. 즉, overlay 양성 fixture가 없는 현 샘플군에서는 pass 분리가 기존 출력 픽셀을 바꾸지 않았다.

## 검증 결과

`./scripts/check-no-appkit.sh`

- 결과: OK
- 공유 Swift 코드에 AppKit/UIKit 직접 의존 없음.

`./scripts/verify-rhwp-studio-assets.sh`

- 결과: OK
- bundled rhwp-studio asset 경로: `Sources/HostApp/Resources/rhwp-studio`

`./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage2-basic --page 1 samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx`

| File | Status | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | NativeBackend | NativeMs |
| --- | --- | ---: | ---: | ---: | ---: | --- | ---: |
| `request.hwp` | OK | 325488/1798071 | 18.1021% | 11.5796 | 255 | coreGraphics | 1063.2 |
| `hwpx-01.hwpx` | OK | 540973/3562815 | 15.1839% | 15.6722 | 255 | coreGraphics | 35.0 |

Stage 1 baseline과 비교하면 `ChangedPercent`는 두 샘플 모두 동일하다. `NativeMs`는 `request.hwp`가 1010.4ms에서 1063.2ms로, `hwpx-01.hwpx`가 42.5ms에서 35.0ms로 관찰됐다. 단일 smoke 측정이라 성능 판단 근거로 보지는 않고, pass 분리가 현재 샘플 출력 픽셀을 바꾸지 않았다는 확인 용도로만 사용한다.

실행 중 `request.hwp`에서 기존 layout overflow 경고가 반복 관찰됐다.

- `Table` overflow 4.0px
- Stage 2 변경으로 새로 생긴 실패는 아니며, visual diff 결과는 OK다.

`./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage2-overlay-metadata`

| File | Status | PageCount | UpstreamImages | Overlay | Behind | Front | TreeImages | TreeEmbeddedAvailable | Wraps |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| `request.hwp` | OK | 1 | 1 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `hwpx-01.hwpx` | OK | 9 | 2 | 0 | 0 | 0 | 2 | 2/2 | TopAndBottom:2 |
| `tac-img-02.hwp` | OK | 66 | 1 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `tac-img-02.hwpx` | OK | 69 | 1 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `hwp-img-001.hwp` | OK | 1 | 4 | 0 | 0 | 0 | 4 | 4/4 | Square:1, TopAndBottom:3 |
| `img-start-001.hwp` | OK | 3 | 0 | 0 | 0 | 0 | 0 | 0/0 | - |

현 기본 샘플에는 `BehindText`/`InFrontOfText` 양성 overlay가 없다. 따라서 이번 단계에서 검증한 것은 pass 분리 후 기존 샘플 출력 보존과 metadata 조회 경로 정상 동작이다.

`xcodegen generate`

- 결과: OK
- `project.yml` 원본 기준으로 Xcode project를 재생성했다.

`xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData-task282-stage2 CODE_SIGNING_ALLOWED=NO build`

- 결과: `** BUILD SUCCEEDED ** [3.343 sec]`
- `HwpNativePageCompositor.swift`가 QLExtension, ThumbnailExtension, HostApp에서 컴파일되는 것을 확인했다.

`./scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations`

- 최초 결과: FAIL
- 원인: Debug app 자체의 provider 등록은 `/Applications/Alhangeul.app`만 보였지만, Stage 2 빌드 산출물 내부 Sparkle `Updater.app` 경로가 LaunchServices dump에 남아 `Alhangeul.app` 개발 등록으로 추출됐다.
- 조치: 현재 작업 산출물의 nested `Updater.app`만 `lsregister -u`로 해제했다.
- 재확인: `./scripts/check-extension-registration-hygiene.sh --check-only` OK
- 남은 warning: `build.noindex/DerivedData-task282-stage2/.../Alhangeul.app` 번들은 파일시스템에 남아 있다. 등록은 남아 있지 않다.

`git diff --check`

- 결과: OK

## 결론

Stage 2는 native CoreGraphics fallback을 rhwp-studio와 유사한 pass 구조로 나눌 수 있는 최소 구조를 만들었다. 현재 샘플군에서는 기존 visual diff 수치를 유지했고, HostApp/Quick Look/Thumbnail target 빌드도 통과했다.

이번 단계에서 얻은 중요한 관찰은 overlay pass 활성화 조건을 #281 metadata에만 의존하면 안 된다는 점이다. metadata가 비어 있어도 render tree의 `textWrap`에 overlay layer가 있으면 기존 순서 보존을 위해 pass를 켜야 한다. 그래서 compositor는 metadata와 render tree를 모두 사용하도록 구현했다.

## 한계

- 기본 smoke 샘플에는 `BehindText`/`InFrontOfText` 양성 fixture가 없어 실제 overlay pass의 픽셀 개선을 아직 수치로 증명하지 못했다.
- compact overlay image bytes를 직접 그리는 경로는 아직 없다. Stage 3에서 #281 metadata의 renderable image bytes를 실제 pass에 주입해야 한다.
- Quick Look PNG/PDF 경로에서 Skia가 성공하면 CoreGraphics compositor는 fallback으로만 사용된다. Thumbnail은 기본적으로 CoreGraphics 경로를 타므로 이번 변경 영향이 더 직접적이다.
- `check-extension-registration-hygiene.sh --cleanup-dev-registrations`는 nested Sparkle `Updater.app` 등록까지 직접 해제하지는 않았다. 이번 단계에서는 수동 unregister로 정리했지만, 필요하면 별도 hygiene 개선 이슈로 분리하는 것이 좋다.

## 다음 단계

Stage 3에서는 `RhwpPageOverlayImageSet`의 behind/front renderable image bytes를 compositor pass에 실제로 주입하는 경로를 구현한다. 그 뒤 overlay 양성 fixture가 없다는 한계가 계속 남으면 synthetic 또는 신규 샘플 확보 여부를 판단해야 한다.

## 승인 요청

Stage 2 구현과 검증을 완료했다. 작업지시자가 승인하면 Stage 3로 진행한다.
