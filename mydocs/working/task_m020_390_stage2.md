# Task M020 #390 Stage 2 완료보고서

## 단계 목적

current `rhwp v0.7.17` 기준으로 Quick Look과 Thumbnail의 CoreGraphics default / Skia opt-in smoke 결과를 재측정한다. 이번 단계는 renderer 정책을 변경하지 않고, fallback, latency, output bytes, Thumbnail signature/cache behavior를 기록했다.

## 산출물

| 경로 | 내용 |
|------|------|
| `build.noindex/task390-skia-policy/summary.txt` | Quick Look policy smoke 5개 샘플 요약 |
| `build.noindex/task390-skia-policy/*-quicklook-skia-policy.txt` | Quick Look 파일별 detail |
| `build.noindex/task390-thumbnail-policy/summary.txt` | Thumbnail policy smoke 3개 샘플 요약 |
| `build.noindex/task390-thumbnail-policy/*-thumbnail-skia-policy.txt` | Thumbnail 파일별 detail과 signature |
| `mydocs/working/task_m020_390_stage2.md` | Stage 2 측정 결과 보고 |
| `mydocs/orders/20260629.md` | #390 비고를 `Stage 2 완료보고서 승인 대기`로 갱신 |

`build.noindex/` 산출물은 로컬 측정 결과이며 커밋 대상이 아니다.

## Quick Look policy smoke

실행 명령:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task390-skia-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과:

| 샘플 | Load | Reply | Pages | CG backend | CG seconds | CG bytes | Skia backend | Skia seconds | Skia bytes | Skia PNG bytes | fallback |
|------|------|-------|-------|------------|------------|----------|--------------|--------------|------------|----------------|----------|
| `request.hwp` | OK | png | 1 | `skia:0,cg:1,embedded:0` | 1.188107 | 90472 | `skia:1,cg:0,embedded:0` | 0.068532 | 84098 | 87027 | 0 |
| `KTX.hwp` | OK | png | 1 | `skia:0,cg:1,embedded:0` | 0.072109 | 543472 | `skia:1,cg:0,embedded:0` | 0.059391 | 181314 | 166247 | 0 |
| `복학원서.hwp` | OK | png | 1 | `skia:0,cg:1,embedded:0` | 0.049888 | 223309 | `skia:1,cg:0,embedded:0` | 0.063096 | 196405 | 198675 | 0 |
| `hwp-multi-001.hwp` | OK | pdf | 9 | `skia:0,cg:9,embedded:0` | 0.420672 | 1398731 | `skia:9,cg:0,embedded:0` | 0.482924 | 1102131 | 1297323 | 0 |
| `hwpx-01.hwpx` | OK | pdf | 9 | `skia:0,cg:9,embedded:0` | 0.376054 | 1377385 | `skia:9,cg:0,embedded:0` | 0.514870 | 1093637 | 1314854 | 0 |

관찰:

- 5개 샘플 모두 `OK`, fallback 0이다.
- 단일 PNG 샘플 중 `request.hwp`, `KTX.hwp`는 이번 smoke에서 Skia opt-in이 CoreGraphics보다 빠르게 측정됐다.
- `복학원서.hwp`는 이번 smoke에서 CoreGraphics가 Skia opt-in보다 빠르게 측정됐다.
- 다중 PDF 샘플 2개는 여전히 Skia opt-in이 CoreGraphics보다 느리지만, #259 대비 차이는 줄었다.
- `hwp-multi-001.hwp`는 #259에서 pages 10으로 기록됐으나 이번 `v0.7.17` smoke에서는 pages 9로 기록됐다. Stage 4 판단에서 page count 변화 여부를 별도 확인 대상으로 둔다.
- smoke stderr에 `LAYOUT_OVERFLOW` diagnostic이 출력됐지만 command exit는 0이고 fallback은 발생하지 않았다.

## #259 Quick Look 기준 대비

| 샘플 | v0.7.13 reply/pages | v0.7.13 CG/Skia sec | v0.7.17 reply/pages | v0.7.17 CG/Skia sec | fallback | 해석 |
|------|---------------------|---------------------|---------------------|---------------------|----------|------|
| `request.hwp` | png / 1 | 1.073779 / 0.069324 | png / 1 | 1.188107 / 0.068532 | 0 | Skia opt-in 우위 유지. CG는 약간 느려지고 Skia는 유사 |
| `KTX.hwp` | png / 1 | 0.069717 / 0.071174 | png / 1 | 0.072109 / 0.059391 | 0 | smoke latency는 Skia가 개선되어 우위로 전환 |
| `복학원서.hwp` | png / 1 | 0.160401 / 0.065900 | png / 1 | 0.049888 / 0.063096 | 0 | CG가 크게 개선되어 이번 smoke에서는 CG 우위 |
| `hwp-multi-001.hwp` | pdf / 10 | 0.390930 / 0.666077 | pdf / 9 | 0.420672 / 0.482924 | 0 | Skia는 여전히 느리지만 격차 감소. page count 변화 확인 필요 |
| `hwpx-01.hwpx` | pdf / 9 | 0.376997 / 0.617429 | pdf / 9 | 0.376054 / 0.514870 | 0 | Skia는 여전히 느리지만 격차 감소 |

## Thumbnail policy smoke

실행 명령:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task390-thumbnail-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp
```

요약:

| 샘플 | 결과 | cache sequence |
|------|------|----------------|
| `request.hwp` | `renders=8 failed=0` | `miss`, `exactHit`, `largerBucketHit(1024x1024)`, `largerBucketHit(1024x1024)` 반복 |
| `KTX.hwp` | `renders=8 failed=0` | `miss`, `exactHit`, `largerBucketHit(1024x1024)`, `largerBucketHit(1024x1024)` 반복 |
| `복학원서.hwp` | `renders=8 failed=0` | `miss`, `exactHit`, `largerBucketHit(1024x1024)`, `largerBucketHit(1024x1024)` 반복 |

첫 render miss 기준 상세:

| 샘플 | policy | backend | fallback | pixel | output bytes | PNG bytes | render ms | seconds | signature core |
|------|--------|---------|----------|-------|--------------|-----------|-----------|---------|----------------|
| `request.hwp` | CoreGraphics | coreGraphics | - | 732x1024 | 125618 | - | 1125.330 | 1.145840 | `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` / `native-skia` |
| `request.hwp` | Skia opt-in | skia | - | 732x1025 | 117040 | 117366 | 77.710 | 0.079214 | `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` / `native-skia` |
| `KTX.hwp` | CoreGraphics | coreGraphics | - | 1024x725 | 482670 | - | 67.662 | 0.069935 | `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` / `native-skia` |
| `KTX.hwp` | Skia opt-in | skia | - | 1025x725 | 161652 | 148962 | 46.783 | 0.048759 | `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` / `native-skia` |
| `복학원서.hwp` | CoreGraphics | coreGraphics | - | 725x1024 | 193700 | - | 46.273 | 0.047897 | `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` / `native-skia` |
| `복학원서.hwp` | Skia opt-in | skia | - | 725x1025 | 170973 | 175775 | 53.810 | 0.055486 | `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` / `native-skia` |

대표 signature:

```text
coreGraphicsOnly|thumbnail-renderer-v1|v0.7.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia|skia-max-dimension-0
skiaOptIn|thumbnail-renderer-v1|v0.7.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia|skia-max-dimension-0
```

관찰:

- 세 샘플 모두 CoreGraphics와 Skia opt-in에서 첫 render는 `miss`, 반복 요청은 `exactHit`, 더 작은 bucket 요청은 `largerBucketHit(1024x1024)`로 재사용됐다.
- signature는 #388에서 정리한 current core metadata를 포함한다.
- fallback은 `-`로 기록되어 실제 fallback 경로가 실행되지 않았다.
- `request.hwp`, `KTX.hwp` thumbnail 첫 render는 Skia opt-in이 더 빠르게 측정됐다.
- `복학원서.hwp` thumbnail 첫 render는 CoreGraphics가 더 빠르게 측정됐다.
- smoke stderr에 `LAYOUT_OVERFLOW` diagnostic이 출력됐지만 command exit는 0이고 `failed=0`이다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 측정 실행, 측정 보고서 작성, 오늘할일 비고 갱신만 수행했다. 제품 Swift/Rust source와 renderer 정책은 수정하지 않았다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `./scripts/verify-rhwp-core-build-info.sh` | 통과: `RhwpCoreBuildInfo`가 `rhwp-core.lock`과 일치 |
| `./scripts/verify-rhwp-studio-assets.sh` | 통과: bundled `rhwp-studio` asset 검증 성공 |
| `./scripts/check-no-appkit.sh` | 통과: shared Swift code AppKit/UIKit 의존 없음 |
| `./scripts/smoke-quicklook-skia-policy.sh ...` | 통과: 5개 샘플 모두 `OK`, fallback 0 |
| `./scripts/smoke-thumbnail-skia-policy.sh ...` | 통과: 3개 샘플 모두 `renders=8 failed=0` |
| Stage 2 `rg` | 통과: fallback, Signature, current core metadata, `failed=0`, `OK` 확인 |
| `git diff --check` | 통과 |

대표 command 출력:

```text
OK request.hwp: reply=png pages=1 cg=skia:0,cg:1,embedded:0 skia=skia:1,cg:0,embedded:0 fallback=0
OK KTX.hwp: reply=png pages=1 cg=skia:0,cg:1,embedded:0 skia=skia:1,cg:0,embedded:0 fallback=0
OK 복학원서.hwp: reply=png pages=1 cg=skia:0,cg:1,embedded:0 skia=skia:1,cg:0,embedded:0 fallback=0
OK hwp-multi-001.hwp: reply=pdf pages=9 cg=skia:0,cg:9,embedded:0 skia=skia:9,cg:0,embedded:0 fallback=0
OK hwpx-01.hwpx: reply=pdf pages=9 cg=skia:0,cg:9,embedded:0 skia=skia:9,cg:0,embedded:0 fallback=0
request.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
KTX.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
복학원서.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
```

## 잔여 위험

- `hwp-multi-001.hwp` page count가 #259의 10에서 이번 smoke의 9로 달라졌다. Stage 4에서 readiness 판단 전에 이 변화가 core/studio 기준 변화인지 smoke harness 차이인지 확인해야 한다.
- `LAYOUT_OVERFLOW` diagnostic은 실패나 fallback으로 이어지지 않았지만 visual 품질 판단은 Stage 3 visual diff에서 별도로 확인해야 한다.
- Stage 2는 smoke latency 중심이다. `KTX.hwp`는 latency가 개선되어도 #259에서 visual regression이 컸던 샘플이므로 default 전환 판단에는 Stage 3 visual diff가 필요하다.
- `request.hwp`는 여전히 CoreGraphics 첫 render가 1초대이고 Skia opt-in이 빠르다. 이 차이가 visual diff와 함께 유지되는지 Stage 3에서 확인해야 한다.

## 다음 단계 영향

Stage 3에서는 같은 5개 샘플에 대해 CoreGraphics와 Skia opt-in visual diff harness를 실행한다. Stage 2 결과상 fallback은 모두 0이므로, Stage 3의 핵심 판단은 visual diff 방향성과 `NativeMs`, reference capture failure 여부가 된다.

## 승인 요청

Stage 2 결과에 따라 Stage 3 `visual diff harness 재측정`으로 진행해도 되는지 승인 요청한다.
