# Task M020 #278 Stage 4 완료 보고서

## 단계 목적

`rhwp` core와 bundled `rhwp-studio`를 모두 `v0.7.13` / `b3e16ef212af81ef37d973ddb86d6816d3804642` 기준으로 맞춘 뒤, 앱과 Quick Look/Thumbnail extension bundle이 빌드되는지 확인하고 새 release 기준 preview visual diff baseline을 남겼다.

## 빌드 결과

실행한 빌드 전 검증:

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh
xcodegen generate
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
OK: rhwp-studio assets verified at .../Sources/HostApp/Resources/rhwp-studio
Created project at .../Alhangeul.xcodeproj
```

HostApp Debug build:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task278 CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [11.768 sec]
```

Debug 산출물에는 두 extension bundle이 모두 포함됐다.

| 항목 | 값 |
| --- | --- |
| Preview bundle id | `com.postmelee.alhangeul.QLExtension` |
| Thumbnail bundle id | `com.postmelee.alhangeul.ThumbnailExtension` |
| Preview executable | `AlhangeulPreview`, `AlhangeulPreview.debug.dylib` |
| Thumbnail executable | `AlhangeulThumbnail`, `AlhangeulThumbnail.debug.dylib` |

## Quick Look Skia policy smoke

실행 명령:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task278-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

결과:

```text
OK request.hwp: reply=png pages=1 cg=skia:0,cg:1,embedded:0 skia=skia:1,cg:0,embedded:0 fallback=0
OK hwpx-01.hwpx: reply=pdf pages=9 cg=skia:0,cg:9,embedded:0 skia=skia:9,cg:0,embedded:0 fallback=0
```

요약 수치:

| File | Reply | Pages | CG backend | CG bytes | CG sec | Skia backend | Skia bytes | Skia PNG bytes | Skia sec | Fallback |
| --- | --- | ---: | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| `request.hwp` | `png` | 1 | `skia:0,cg:1,embedded:0` | 82,130 | 0.990051 | `skia:1,cg:0,embedded:0` | 85,865 | 88,535 | 12.158348 | 0 |
| `hwpx-01.hwpx` | `pdf` | 9 | `skia:0,cg:9,embedded:0` | 1,488,882 | 0.358134 | `skia:9,cg:0,embedded:0` | 1,093,817 | 1,315,352 | 0.617731 | 0 |

관찰:

- `coreGraphicsOnly` 정책은 두 문서 모두 CG 경로만 사용했다.
- `skiaOptIn` 정책은 두 문서 모두 Skia 경로만 사용했고 fallback은 발생하지 않았다.
- `request.hwp`의 Skia smoke 시간은 `12.158348s`로 CG `0.990051s`보다 크게 느렸다. 첫 렌더 또는 Skia 초기화 비용이 섞였을 가능성이 있으므로 단일 실행 성능 수치로 확정하지 않고 후속 반복 측정 대상으로 남긴다.

## Visual diff baseline

CoreGraphics native renderer 기준:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task278-visual-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

Skia opt-in native renderer 기준:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task278-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

두 visual diff 모두 reference renderer가 bundled `rhwp-studio` `v0.7.13` / `b3e16ef212af81ef37d973ddb86d6816d3804642`임을 확인했다.

| File | Native policy | Changed pixels | Changed percent | Mean RGB delta | Max RGB delta | Native backend | Native ms |
| --- | --- | ---: | ---: | ---: | ---: | --- | ---: |
| `request.hwp` | CoreGraphics | 321,031 / 1,798,071 | 17.8542% | 11.0716 | 255 | `coreGraphics` | 961.7 |
| `request.hwp` | Skia | 231,382 / 1,798,071 | 12.8683% | 10.1453 | 255 | `skia` | 6240.1 |
| `hwpx-01.hwpx` | CoreGraphics | 535,436 / 3,562,815 | 15.0285% | 15.2088 | 255 | `coreGraphics` | 29.8 |
| `hwpx-01.hwpx` | Skia | 521,783 / 3,562,815 | 14.6452% | 16.0791 | 255 | `skia` | 64.4 |

CoreGraphics 대비 Skia 변화:

| File | Changed percent delta | Mean RGB delta 변화 | Native ms 변화 | 해석 |
| --- | ---: | ---: | ---: | --- |
| `request.hwp` | -4.9859 pp | -0.9263 | +5,278.4 ms | pixel diff 비율과 평균 RGB 차이는 개선됐지만 첫 렌더 비용이 매우 큼 |
| `hwpx-01.hwpx` | -0.3833 pp | +0.8703 | +34.6 ms | changed percent는 소폭 개선됐지만 평균 RGB 차이는 소폭 악화 |

결론:

- `v0.7.13` Skia 경로는 두 샘플에서 `rhwp-studio` reference 대비 changed pixel 비율을 낮췄다.
- 그러나 diff가 여전히 `12.8683%`, `14.6452%` 수준이라 preview parity에 도달했다고 볼 수 없다.
- 특히 `request.hwp` Skia 측정은 smoke와 visual diff 양쪽에서 느리게 관찰됐다. 이후 Skia를 기본 preview 경로로 전환하기 전 반복 측정과 초기화 비용 분리가 필요하다.
- #282의 Swift compositor 작업은 여전히 의미가 있다. Skia가 개선됐더라도 overlay/image positioning, PageLayerTree payload 소비, fallback 정책은 앱 preview 품질과 안정성을 위해 계속 보강해야 한다.

## Overlay metadata smoke

실행 명령:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task278-overlay-metadata
```

결과:

```text
OK request.hwp: page=1 upstreamImages=1 overlay=0 behind=0 front=0 treeImages=1 treeEmbeddedAvailable=1/1
OK hwpx-01.hwpx: page=1 upstreamImages=2 overlay=0 behind=0 front=0 treeImages=2 treeEmbeddedAvailable=2/2
OK tac-img-02.hwp: page=1 upstreamImages=1 overlay=0 behind=0 front=0 treeImages=1 treeEmbeddedAvailable=1/1
OK tac-img-02.hwpx: page=1 upstreamImages=1 overlay=0 behind=0 front=0 treeImages=1 treeEmbeddedAvailable=1/1
OK hwp-img-001.hwp: page=1 upstreamImages=4 overlay=0 behind=0 front=0 treeImages=4 treeEmbeddedAvailable=4/4
OK img-start-001.hwp: page=1 upstreamImages=0 overlay=0 behind=0 front=0 treeImages=0 treeEmbeddedAvailable=0/0
```

요약:

| File | Pages | Upstream images | Overlay | Behind | Front | Tree images | Embedded availability | Wrap styles |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| `request.hwp` | 1 | 1 | 0 | 0 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `hwpx-01.hwpx` | 9 | 2 | 0 | 0 | 0 | 2 | 2/2 | `TopAndBottom:2` |
| `tac-img-02.hwp` | 66 | 1 | 0 | 0 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `tac-img-02.hwpx` | 66 | 1 | 0 | 0 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `hwp-img-001.hwp` | 1 | 4 | 0 | 0 | 0 | 4 | 4/4 | `Square:1, TopAndBottom:3` |
| `img-start-001.hwp` | 3 | 0 | 0 | 0 | 0 | 0 | 0/0 | `-` |

관찰:

- 기본 sample set에서는 `v0.7.13` 기준으로도 behind/front overlay positive case가 나오지 않았다.
- PageLayerTree image node의 embedded availability는 관찰된 이미지에서 모두 채워졌다.
- #282에서는 compact overlay metadata만 기다리지 말고 PageLayerTree image node의 wrap state, resolved payload, embedded bytes availability를 같이 쓰는 방향이 맞다.

## 등록 hygiene

빌드 후 개발용 Debug app이 LaunchServices에 등록되어 있었기 때문에 먼저 hygiene check가 실패했다.

```text
Issues:
  - development/test Alhangeul.app registrations remain in LaunchServices.
```

`--cleanup-dev-registrations`는 `Alhangeul.app`과 extension bundle unregister 및 Quick Look cache reset을 실행했지만, Sparkle의 중첩 `Updater.app` 등록이 부모 `Alhangeul.app` 경로로 계속 감지됐다. 따라서 이번 smoke 산출물의 중첩 앱만 수동으로 해제했다.

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u /Users/melee/Documents/projects/rhwp-mac-task278/build.noindex/DerivedData-task278/Build/Products/Debug/Alhangeul.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app
```

최종 hygiene check:

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
```

결과:

```text
Issues:
  - (none)
Warnings:
  - development/test Alhangeul.app bundles exist under build.noindex or DerivedData; this is only a problem if they are registered.
  - Quick Look preview provider path was not reported by PlugInKit.
  - Thumbnail provider path was not reported by PlugInKit.
```

해석:

- 개발 산출물 파일은 `build.noindex/DerivedData-task278`에 남아 있지만 LaunchServices/PlugInKit provider 등록은 남아 있지 않다.
- 이번 Stage 4는 Debug build smoke이므로 설치본 provider 등록을 의도적으로 유지하지 않았다. 따라서 provider path 미보고 warning은 실패가 아니다.

## 산출물 위치

검증 산출물:

- `build.noindex/task278-skia-policy`
- `build.noindex/task278-visual-basic`
- `build.noindex/task278-visual-skia`
- `build.noindex/task278-overlay-metadata`
- `/private/tmp/alhangeul-extension-registration-hygiene/20260528-101946`

## 한계

- 이번 단계는 `CODE_SIGNING_ALLOWED=NO` Debug build 검증이다. 실제 Finder integration, signed Release package, notarized artifact 검증은 아니다.
- system `qlmanage -t` thumbnail 설치본 smoke는 실행하지 않았다. Debug build와 registration hygiene, extension bundle 포함 여부까지만 확인했다.
- visual diff는 WebView canvas capture와 native bitmap을 scale 기준으로 비교한다. changed percent는 회귀 탐지 지표로 유효하지만, 사람 눈 기준의 문서 fidelity를 완전히 대체하지 않는다.
- `request.hwp` Skia 시간은 단일 실행에서 크게 느리게 나왔다. Skia 초기화, cache warm-up, sample 특성 분리가 필요하다.
- Stage 3에서 기록한 것처럼 bundled `rhwp-studio` asset은 host `wasm-pack` fallback으로 생성됐다. hash와 asset manifest는 검증했지만 Docker 표준 빌드와 byte-identical 여부는 확인하지 못했다.

## 다음 단계 영향

- #282 branch는 #278 merge 후 최신 `devel`에 재정렬해야 한다.
- #282의 overlay/image compositor는 `v0.7.13` 기준 PageLayerTree image node의 resolved payload와 embedded bytes availability를 함께 고려해야 한다.
- Skia preview 전환은 가능성을 보였지만 아직 기본 경로 전환 근거로는 부족하다. #282/#259에서는 Swift renderer 보강과 Skia opt-in 비교를 병행하는 편이 안전하다.
- Stage 5에서는 이번 수치와 한계를 최종 보고서와 PR 본문에 요약하고, 후속 작업 handoff를 명확히 남긴다.

## 검증 결과

실행한 명령:

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task278 CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task278-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task278-visual-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task278-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/overlay-metadata-smoke.sh build.noindex/task278-overlay-metadata
./scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u /Users/melee/Documents/projects/rhwp-mac-task278/build.noindex/DerivedData-task278/Build/Products/Debug/Alhangeul.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app
./scripts/check-extension-registration-hygiene.sh --check-only
```

결과:

- no-AppKit check 통과
- bundled `rhwp-studio` asset verification 통과
- Xcode project 재생성 성공
- HostApp Debug build 성공
- Quick Look Skia policy smoke 통과
- CoreGraphics visual diff baseline 생성 성공
- Skia visual diff baseline 생성 성공
- overlay metadata smoke 통과
- 개발 산출물 LaunchServices/PlugInKit 등록 hygiene 최종 통과

## 승인 요청

Stage 5로 진행하려면 최종 보고서 작성, 오늘할일 완료 처리, PR 게시 준비를 진행한다.
