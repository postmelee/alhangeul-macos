# Task M020 #259 Stage 2 보고서 - Skia visual/performance/package gate 측정

## 단계 개요

- 이슈: #259 Skia backend visual/performance/package regression gate 정리
- 단계: Stage 2. visual/performance/package gate 측정
- 기준 브랜치: `local/task259`
- 기준 core: `rhwp v0.7.13`, resolved commit `b3e16ef212af81ef37d973ddb86d6816d3804642`
- 목표: 현재 최신 코드 기준 Quick Look Skia/CoreGraphics 결과를 재측정하고 Stage 3 release policy 판정 입력을 확보한다.

Stage 2에서는 Swift source를 변경하지 않았다. 측정 산출물은 `build.noindex/task259-*` 아래에 생성했다.

## 기준 산출물 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| Rust lock 검증 | 통과 | `./scripts/build-rust-macos.sh --verify-lock` |
| FFI symbol set | 통과 | `rhwp_render_page_png`, `rhwp_page_overlay_images` 포함 12 symbols |
| `rhwp-core.lock` | 통과 | `release-tag`, `v0.7.13`, commit `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| bundled `rhwp-studio` | 통과 | `./scripts/verify-rhwp-studio-assets.sh` |
| Shared AppKit/UIKit 금지 | 통과 | `./scripts/check-no-appkit.sh` |

`build-rust-macos.sh --verify-lock`는 sandbox 안에서 실행했기 때문에 `xcodebuild -create-xcframework` 중 CoreSimulator 관련 warning이 출력됐다. 그러나 xcframework 생성, symbol 출력, lock verification은 성공했다.

## Package size

| 항목 | 현재 값 |
|---|---:|
| `Frameworks/universal/librhwp.a` exact size | 203,436,808 bytes |
| `Frameworks/generated_rhwp.h` exact size | 2,059 bytes |
| `du -sh Frameworks/universal/librhwp.a` | `194M` |
| `du -sh Frameworks/Rhwp.xcframework` | `194M` |
| `du -sk Sources/HostApp/Resources/rhwp-studio` | `35736` KB |
| `rhwp-studio` copied file count | 57 |
| `rhwp-studio` copied total bytes | 36,462,802 bytes |

비교 기준:

| 기준 | `librhwp.a` size | 변화 |
|---|---:|---:|
| #255 이전 | 108,417,040 bytes | - |
| #255 native-skia 반영 | 190,410,384 bytes | +81,993,344 bytes |
| #278 v0.7.13 반영 후 현재 | 203,436,808 bytes | #255 대비 +13,026,424 bytes, #255 이전 대비 +95,019,768 bytes |

판단 입력: Skia backend capability를 포함하면서 staticlib는 #255 이전 대비 약 95 MB 커졌다. Quick Look 기본 backend를 Skia로 유지하려면 visual/latency 개선이 이 비용을 정당화해야 한다.

## Quick Look policy smoke

실행:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task259-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp \
  samples/basic/KTX.hwp samples/hwp-multi-001.hwp
```

결과:

| File | Reply | Pages | CG backend | CG sec | Skia backend | Skia sec | Delta sec | Fallback |
|---|---|---:|---|---:|---|---:|---:|---:|
| `request.hwp` | png | 1 | `skia:0,cg:1,embedded:0` | 1.073779 | `skia:1,cg:0,embedded:0` | 0.069324 | -1.004455 | 0 |
| `hwpx-01.hwpx` | pdf | 9 | `skia:0,cg:9,embedded:0` | 0.376997 | `skia:9,cg:0,embedded:0` | 0.617429 | +0.240432 | 0 |
| `복학원서.hwp` | png | 1 | `skia:0,cg:1,embedded:0` | 0.160401 | `skia:1,cg:0,embedded:0` | 0.065900 | -0.094501 | 0 |
| `KTX.hwp` | png | 1 | `skia:0,cg:1,embedded:0` | 0.069717 | `skia:1,cg:0,embedded:0` | 0.071174 | +0.001457 | 0 |
| `hwp-multi-001.hwp` | pdf | 10 | `skia:0,cg:10,embedded:0` | 0.390930 | `skia:10,cg:0,embedded:0` | 0.666077 | +0.275147 | 0 |

해석:

- 5개 샘플 모두 Skia fallback은 0이었다.
- 단일 PNG 샘플 중 `request.hwp`, `복학원서.hwp`는 Skia가 빨랐다.
- `KTX.hwp` 단일 PNG는 거의 동률이었다.
- 다중 PDF 샘플 2개는 Skia가 CoreGraphics보다 느렸다.
- #278에서 관측한 `request.hwp` Quick Look Skia 12.158348s는 이번 policy smoke에서는 재현되지 않았다. 다만 아래 visual diff harness의 native render time에서는 `request.hwp` Skia가 여전히 5초대로 측정됐다.

## Visual diff

처음 sandbox 내부에서 `preview-visual-diff-harness.sh`를 실행했을 때 WKWebView/rhwp-studio readiness 단계가 실패했다.

```text
rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
Could not create a 'com.apple.gputools.service' sandbox extension
Could not create a 'com.apple.coreservices.launchservicesd' sandbox extension
```

같은 명령을 sandbox 밖 권한으로 재실행해 완료했다.

실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task259-visual-cg --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp \
  samples/basic/KTX.hwp samples/hwp-multi-001.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task259-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp \
  samples/basic/KTX.hwp samples/hwp-multi-001.hwp
```

공통 조건:

| 항목 | 값 |
|---|---|
| Reference | bundled `rhwp-studio` |
| Studio release | `v0.7.13` |
| Studio commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| Page | 1 |
| Viewport | `1400x1800` |
| Settle | 120 ms |
| Diff pixel threshold | 12 |

결과:

| File | CG changed | Skia changed | Delta pp | CG mean RGB | Skia mean RGB | Mean delta | CG native ms | Skia native ms | Ms delta |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `request.hwp` | 17.8542% | 12.8683% | -4.9859 | 11.0716 | 10.1453 | -0.9263 | 1016.7 | 5460.6 | +4443.9 |
| `hwpx-01.hwpx` | 15.0285% | 14.6452% | -0.3833 | 15.2088 | 16.0791 | +0.8703 | 33.8 | 69.2 | +35.4 |
| `복학원서.hwp` | 32.0188% | 6.4738% | -25.5450 | 18.2116 | 7.2558 | -10.9558 | 157.6 | 61.1 | -96.5 |
| `KTX.hwp` | 31.1362% | 47.1389% | +16.0027 | 13.6308 | 22.5798 | +8.9490 | 52.3 | 65.3 | +13.0 |
| `hwp-multi-001.hwp` | 14.8327% | 14.3340% | -0.4987 | 14.8651 | 15.7946 | +0.9295 | 29.2 | 66.3 | +37.1 |

해석:

- Skia는 `복학원서.hwp`에서 visual diff를 크게 줄였다.
- `request.hwp`도 changed pixel과 mean RGB가 개선됐지만, native render ms가 5초대로 매우 느리다.
- `hwpx-01.hwpx`, `hwp-multi-001.hwp`는 changed pixel 개선 폭이 0.5pp 안팎이고 mean RGB는 오히려 나빠졌다.
- `KTX.hwp`는 Skia가 changed pixel과 mean RGB 모두 크게 악화됐다.
- visual 평균만 보면 Skia가 일부 개선되지만, 문서별 방향이 크게 갈려 release default의 안정 근거로 쓰기 어렵다.

## Stage 3 판정 입력

Stage 2 수치만 기준으로 보면 Stage 3에서 검토할 기본 방향은 `Quick Look 기본 CoreGraphics 복귀 + Skia opt-in/diagnostic 유지` 쪽이 더 강하다.

근거:

1. 다중 PDF Quick Look smoke에서 Skia가 계속 느리다.
2. visual diff가 문서별로 갈린다. `복학원서.hwp`는 크게 개선되지만 `KTX.hwp`는 크게 악화된다.
3. `request.hwp`는 Quick Look smoke에서 12초 지연이 재현되지는 않았지만 visual diff harness의 Skia native ms가 5초대로 남아 있다.
4. staticlib size는 #255 이전 대비 약 95 MB 증가했다. 현재 개선 폭은 이 package cost를 기본 경로 전환 근거로 삼기 어렵다.
5. Finder Thumbnail은 아직 CoreGraphics 기본이다. Quick Look만 Skia 기본으로 두면 release 설명과 회귀 대응 범위가 복잡하다.

다만 Stage 2는 측정 단계이므로 source policy 변경은 하지 않았다. 최종 default 유지/복귀 결정과 필요 시 `HwpPreviewProvider` 보정은 Stage 3에서 수행한다.

## Stage 2 검증

실행한 검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task259-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp \
  samples/basic/KTX.hwp samples/hwp-multi-001.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task259-visual-cg --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp \
  samples/basic/KTX.hwp samples/hwp-multi-001.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task259-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp \
  samples/basic/KTX.hwp samples/hwp-multi-001.hwp
du -sh Frameworks/universal/librhwp.a Frameworks/Rhwp.xcframework
git diff --check
```

결과:

| 검증 | 결과 |
|---|---|
| Rust/core lock 검증 | 통과 |
| `rhwp-studio` asset 검증 | 통과 |
| Shared AppKit/UIKit 금지 | 통과 |
| Quick Look policy smoke | 통과, fallback 0 |
| Visual diff CoreGraphics | sandbox 밖 재실행 통과 |
| Visual diff Skia | sandbox 밖 재실행 통과 |
| Package size 확인 | 통과 |
| `git diff --check` | 통과 |

## 다음 단계 승인 요청

Stage 3에서는 이 측정값을 기준으로 Quick Look 기본 backend 정책을 확정한다. CoreGraphics default 복귀가 필요하다고 판단하면 `Sources/QLExtension/HwpPreviewProvider.swift`의 단일 PNG와 다중 PDF policy를 최소 수정하고, Skia opt-in smoke/helper와 Shared renderer contract는 유지한다.
