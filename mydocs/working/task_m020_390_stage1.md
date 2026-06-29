# Task M020 #390 Stage 1 완료보고서

## 단계 목적

`rhwp v0.7.17` 기준 Skia readiness gate 재측정을 시작하기 전에, current core/studio provenance와 #259 기준 측정값, #388 handoff 조건, Stage 2-3 측정 명령을 하나의 inventory로 고정한다.

이번 단계는 제품 코드와 renderer 정책을 수정하지 않고, 다음 단계의 측정 기준만 확정했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m020_390_stage1.md` | Stage 1 inventory, 기준값, 측정 명령, 산출물 경로 |
| `mydocs/orders/20260629.md` | #390 비고를 `Stage 1 완료보고서 승인 대기`로 갱신 |

## 현재 provenance

| 항목 | 값 |
|------|----|
| core release tag | `v0.7.17` |
| core resolved commit | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| enabled features | `native-skia` |
| Swift build info | `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift` |
| studio manifest | `Sources/HostApp/Resources/rhwp-studio/manifest.json` |
| studio copied files | `60` |
| studio copied bytes | `38,608,918` |

확인 결과 `rhwp-core.lock`, `RhwpCoreBuildInfo.swift`, `rhwp-studio` manifest가 같은 release tag와 resolved commit을 가리킨다. 따라서 Stage 2-3 측정은 current bundled core/studio 기준으로 진행할 수 있다.

## #388 handoff 조건

#388에서 Thumbnail render signature가 current lock metadata를 포함하도록 정합화되었다.

| 조건 | 기준 |
|------|------|
| Thumbnail signature core release | `v0.7.17` |
| Thumbnail signature core commit | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| Thumbnail signature features | `native-skia` |
| Stage 4 thumbnail smoke | `KTX.hwp`, `request.hwp` 모두 `renders=8 failed=0` |

따라서 #390 Stage 2의 Thumbnail smoke는 stale signature로 인한 cache 재사용 문제를 전제하지 않는다. `--verify-lock` strict static archive byte hash mismatch UX는 #394로 분리되어 있으며, 이번 readiness 재측정의 blocker로 보지 않는다.

## #259 기준값

### Quick Look policy smoke 기준

| 샘플 | reply | pages | CoreGraphics seconds | Skia seconds | fallback |
|------|-------|-------|----------------------|--------------|----------|
| `samples/basic/request.hwp` | `png` | 1 | 1.073779 | 0.069324 | 0 |
| `samples/basic/KTX.hwp` | `png` | 1 | 0.069717 | 0.071174 | 0 |
| `samples/복학원서.hwp` | `png` | 1 | 0.160401 | 0.065900 | 0 |
| `samples/hwp-multi-001.hwp` | `pdf` | 10 | 0.390930 | 0.666077 | 0 |
| `samples/hwpx/hwpx-01.hwpx` | `pdf` | 9 | 0.376997 | 0.617429 | 0 |

#259에서는 fallback count가 모두 0으로 안정적이었지만, 다중 PDF 경로에서 Skia가 CoreGraphics보다 느렸다. Stage 2는 같은 샘플 세트로 `v0.7.17`에서 이 방향성이 유지되는지 확인한다.

### Visual diff 기준

| 샘플 | CG changed | Skia changed | changed delta | CG MeanRGBDelta | Skia MeanRGBDelta | CG NativeMs | Skia NativeMs | #259 해석 |
|------|------------|--------------|---------------|-----------------|-------------------|-------------|---------------|----------|
| `samples/basic/request.hwp` | 17.8542% | 12.8683% | -4.9859 | 11.0716 | 10.1453 | 1016.7 | 5460.6 | visual은 개선됐지만 Skia latency가 큼 |
| `samples/basic/KTX.hwp` | 31.1362% | 47.1389% | +16.0027 | 13.6308 | 22.5798 | 52.3 | 65.3 | Skia visual regression |
| `samples/복학원서.hwp` | 32.0188% | 6.4738% | -25.5450 | 18.2116 | 7.2558 | 157.6 | 61.1 | Skia visual 개선 |
| `samples/hwp-multi-001.hwp` | 14.8327% | 14.3340% | -0.4987 | 14.8651 | 15.7946 | 29.2 | 66.3 | visual 유사, Skia 느림 |
| `samples/hwpx/hwpx-01.hwpx` | 15.0285% | 14.6452% | -0.3833 | 15.2088 | 16.0791 | 33.8 | 69.2 | visual 유사, Skia 느림 |

#259 최종 판단은 Quick Look default Skia 전환 보류였다. Stage 3는 숫자 하나가 아니라 `ChangedPercent`, `MeanRGBDelta`, `NativeMs`, failure phase를 함께 기록한다.

## 샘플 세트

| 샘플 | 크기 | 분류 | Stage 2 용도 | Stage 3 용도 |
|------|------|------|--------------|--------------|
| `samples/basic/request.hwp` | 64K | 단일 page HWP | Quick Look, Thumbnail | visual diff |
| `samples/basic/KTX.hwp` | 65K | 단일 page HWP | Quick Look, Thumbnail | visual diff |
| `samples/복학원서.hwp` | 112K | 단일 page HWP, watermark 계열 | Quick Look, Thumbnail | visual diff |
| `samples/hwp-multi-001.hwp` | 481K | 다중 page HWP | Quick Look PDF 경로 | visual diff page 1 |
| `samples/hwpx/hwpx-01.hwpx` | 473K | 다중 page HWPX | Quick Look PDF 경로 | visual diff page 1 |

## 측정 script inventory

| script | 입력 | 주요 산출물 | Stage |
|--------|------|-------------|-------|
| `scripts/smoke-quicklook-skia-policy.sh` | output dir, HWP/HWPX 파일 목록 | `summary.txt`, 파일별 detail | Stage 2 |
| `scripts/smoke-thumbnail-skia-policy.sh` | output dir, 선택 request bucket, HWP 파일 목록 | `summary.txt`, 파일별 cache/signature detail | Stage 2 |
| `scripts/preview-visual-diff-harness.sh` | output dir, page, policy, viewport, HWP/HWPX 파일 목록 | `summary.md`, `studio/`, `native/`, `diff/`, metadata | Stage 3 |

Stage 2 산출물 경로:

```text
build.noindex/task390-skia-policy/summary.txt
build.noindex/task390-thumbnail-policy/summary.txt
```

Stage 3 산출물 경로:

```text
build.noindex/task390-visual-cg/summary.md
build.noindex/task390-visual-skia/summary.md
build.noindex/task390-visual-cg/studio/
build.noindex/task390-visual-cg/native/
build.noindex/task390-visual-cg/diff/
build.noindex/task390-visual-skia/studio/
build.noindex/task390-visual-skia/native/
build.noindex/task390-visual-skia/diff/
```

## Stage 2 고정 명령

```bash
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task390-skia-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task390-thumbnail-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp
rg -n "fallback|Fallback|Signature|v0\\.7\\.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia|failed=0|OK" \
  build.noindex/task390-skia-policy build.noindex/task390-thumbnail-policy \
  mydocs/working/task_m020_390_stage2.md
git diff --check
```

## Stage 3 고정 명령

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task390-visual-cg --page 1 \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task390-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
rg -n "FAIL|OK|ChangedPercent|MeanRGBDelta|NativeBackend|NativeMs|fallback|readiness timed out|WKErrorDomain" \
  build.noindex/task390-visual-cg build.noindex/task390-visual-skia \
  mydocs/working/task_m020_390_stage3.md
git diff --check
```

## 비교표 template

### Stage 2 Quick Look

| 샘플 | v0.7.13 reply/pages | v0.7.13 CG/Skia seconds | v0.7.17 reply/pages | v0.7.17 CG/Skia seconds | fallback | 해석 |
|------|---------------------|-------------------------|---------------------|-------------------------|----------|------|
| `request.hwp` |  |  |  |  |  |  |
| `KTX.hwp` |  |  |  |  |  |  |
| `복학원서.hwp` |  |  |  |  |  |  |
| `hwp-multi-001.hwp` |  |  |  |  |  |  |
| `hwpx-01.hwpx` |  |  |  |  |  |  |

### Stage 2 Thumbnail

| 샘플 | policy | cache event | backend | fallback | render ms | signature core | 해석 |
|------|--------|-------------|---------|----------|-----------|----------------|------|
| `request.hwp` | CoreGraphics |  |  |  |  |  |  |
| `request.hwp` | Skia opt-in |  |  |  |  |  |  |
| `KTX.hwp` | CoreGraphics |  |  |  |  |  |  |
| `KTX.hwp` | Skia opt-in |  |  |  |  |  |  |
| `복학원서.hwp` | CoreGraphics |  |  |  |  |  |  |
| `복학원서.hwp` | Skia opt-in |  |  |  |  |  |  |

### Stage 3 Visual diff

| 샘플 | policy | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | NativeBackend | NativeMs | failure phase | 해석 |
|------|--------|----------------|--------------|-------------|------------|---------------|----------|---------------|------|
| `request.hwp` | CoreGraphics |  |  |  |  |  |  |  |  |
| `request.hwp` | Skia opt-in |  |  |  |  |  |  |  |  |
| `KTX.hwp` | CoreGraphics |  |  |  |  |  |  |  |  |
| `KTX.hwp` | Skia opt-in |  |  |  |  |  |  |  |  |
| `복학원서.hwp` | CoreGraphics |  |  |  |  |  |  |  |  |
| `복학원서.hwp` | Skia opt-in |  |  |  |  |  |  |  |  |
| `hwp-multi-001.hwp` | CoreGraphics |  |  |  |  |  |  |  |  |
| `hwp-multi-001.hwp` | Skia opt-in |  |  |  |  |  |  |  |  |
| `hwpx-01.hwpx` | CoreGraphics |  |  |  |  |  |  |  |  |
| `hwpx-01.hwpx` | Skia opt-in |  |  |  |  |  |  |  |  |

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 측정 inventory 보고서 작성과 오늘할일 비고 갱신만 수행했다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `./scripts/verify-rhwp-core-build-info.sh` | 통과: `RhwpCoreBuildInfo`가 `rhwp-core.lock`과 일치 |
| `./scripts/verify-rhwp-studio-assets.sh` | 통과: bundled `rhwp-studio` asset 검증 성공 |
| current provenance `rg` | 통과: lock, Swift build info, studio manifest에서 `v0.7.17`, `03351190ec35436e58cbfee0aa9278a8fdc04a59`, `native-skia` 확인 |
| #259/#388/Stage 1 기준 `rg` | 통과: sample, fallback, `NativeMs`, package 관련 기준 확인 |
| sample file existence `test -f` | 통과: 기본 샘플 5개 존재 |
| `git diff --check` | 통과 |

대표 provenance 확인:

```text
Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift:2:    static let releaseTag = "v0.7.17"
Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift:3:    static let commit = "03351190ec35436e58cbfee0aa9278a8fdc04a59"
Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift:4:    static let enabledFeatures = "native-skia"
rhwp-core.lock:4:rhwp_release_tag = "v0.7.17"
rhwp-core.lock:5:rhwp_commit = "03351190ec35436e58cbfee0aa9278a8fdc04a59"
rhwp-core.lock:6:rhwp_enabled_features = "native-skia"
Sources/HostApp/Resources/rhwp-studio/manifest.json:5:  "source_release_tag": "v0.7.17",
Sources/HostApp/Resources/rhwp-studio/manifest.json:6:  "source_resolved_commit": "03351190ec35436e58cbfee0aa9278a8fdc04a59",
```

## 잔여 위험

- Stage 2-3 smoke와 visual diff는 실제 렌더링을 수행하므로 WebKit readiness, sandbox, local cache 상태의 영향을 받을 수 있다. 실패 시 `renderer failure`, `reference capture failure`, `environment failure`를 분리해 기록한다.
- #259와 #390은 core/studio 버전이 다르므로 absolute 숫자보다 방향성과 surface별 실패 여부가 중요하다.
- `request.hwp`처럼 visual 개선과 latency 악화가 동시에 나타날 수 있으므로 default 전환 판단은 Stage 4에서 surface별로 분리한다.

## 다음 단계 영향

Stage 2에서는 Quick Look 기본 샘플 5개와 Thumbnail 기본 샘플 3개의 CoreGraphics/Skia opt-in smoke를 재측정한다. Stage 2에서 제품 정책은 변경하지 않고, fallback, latency, output shape, Thumbnail signature/cache behavior만 보고한다.

## 승인 요청

Stage 1 inventory와 측정 설계를 기준으로 Stage 2 `Quick Look/Thumbnail policy smoke 재측정`으로 진행해도 되는지 승인 요청한다.
