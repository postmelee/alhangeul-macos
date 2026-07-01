# Task M020 #389 Stage 4 완료 보고서

## 단계 목적

대표 샘플로 Thumbnail diagnostic smoke를 실행하고, cache/backend/fallback baseline과 #392 maxDimension mapping 실험에 넘길 입력을 정리한다.

## 실행한 검증

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
```

기본 검증 결과:

| 명령 | 결과 |
|------|------|
| `check-no-appkit.sh` | 성공. shared Swift code에 AppKit/UIKit 의존 없음 |
| `verify-rhwp-core-build-info.sh` | 성공. `RhwpCoreBuildInfo`와 `rhwp-core.lock` 일치 |
| `verify-rhwp-studio-assets.sh` | 성공. bundled `rhwp-studio` asset 검증 통과 |

## quick smoke 결과

산출물:

- `build.noindex/task389-thumbnail-policy/summary.txt`
- `build.noindex/task389-thumbnail-policy/request-thumbnail-skia-policy.txt`
- `build.noindex/task389-thumbnail-policy/KTX-thumbnail-skia-policy.txt`
- `build.noindex/task389-thumbnail-policy/resolver-contract.txt`

콘솔 요약:

```text
resolver: OK
request.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
KTX.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
```

결과:

- resolver contract: `OK`
- render rows: 16개 모두 `OK`
- cache signature separation: 2개 샘플 모두 `OK`
- backend: `coreGraphicsOnly`는 `coreGraphics`, `skiaOptIn`은 `skia`
- fallback: 모든 row에서 `-`

## 대표 샘플 smoke 결과

산출물:

- `build.noindex/task389-thumbnail-policy-representative/summary.txt`
- `build.noindex/task389-thumbnail-policy-representative/resolver-contract.txt`
- `build.noindex/task389-thumbnail-policy-representative/*-thumbnail-skia-policy.txt`

콘솔 요약:

```text
resolver: OK
복학원서.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
KTX.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
request.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
hwpx-01.hwpx: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
hwp-multi-001.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
```

대표 smoke 결과:

| 항목 | 결과 |
|------|------|
| resolver contract | `OK` |
| render rows | 40개 모두 `OK` |
| cache pattern | 각 파일/정책 모두 `miss -> exactHit -> largerBucketHit -> largerBucketHit` |
| cache signature separation | 5개 샘플 모두 `OK` |
| backend | `coreGraphicsOnly`는 `coreGraphics`, `skiaOptIn`은 `skia` |
| fallback | 모든 row에서 `-` |

`복학원서.hwp` 처리 중 기존 layout overflow 진단 3줄이 stderr에 출력되었다. smoke render status는 모두 `OK`였고 fallback도 발생하지 않았다.

## 대표 large request baseline

아래 값은 대표 smoke의 첫 요청 `large:512x512@2` 기준이다. 요청 bucket은 모두 `1024x1024`다.

| File | Policy | Backend | Fallback | Pixel | OutputBytes | PNGBytes | RenderMs |
|------|--------|---------|----------|-------|-------------|----------|----------|
| `복학원서.hwp` | `coreGraphicsOnly` | `coreGraphics` | `-` | `725x1024` | `193700` | `-` | `1218.344` |
| `복학원서.hwp` | `skiaOptIn` | `skia` | `-` | `725x1025` | `170973` | `175775` | `73.027` |
| `KTX.hwp` | `coreGraphicsOnly` | `coreGraphics` | `-` | `1024x725` | `482670` | `-` | `89.693` |
| `KTX.hwp` | `skiaOptIn` | `skia` | `-` | `1025x725` | `161652` | `148962` | `66.359` |
| `request.hwp` | `coreGraphicsOnly` | `coreGraphics` | `-` | `732x1024` | `125618` | `-` | `30.996` |
| `request.hwp` | `skiaOptIn` | `skia` | `-` | `732x1025` | `117040` | `117366` | `61.484` |
| `hwpx-01.hwpx` | `coreGraphicsOnly` | `coreGraphics` | `-` | `725x1024` | `198763` | `-` | `33.656` |
| `hwpx-01.hwpx` | `skiaOptIn` | `skia` | `-` | `725x1025` | `171059` | `187595` | `56.863` |
| `hwp-multi-001.hwp` | `coreGraphicsOnly` | `coreGraphics` | `-` | `725x1024` | `195545` | `-` | `31.347` |
| `hwp-multi-001.hwp` | `skiaOptIn` | `skia` | `-` | `725x1025` | `166327` | `180447` | `47.418` |

## provider default 확인

default provider는 CoreGraphics 유지다.

- `HwpThumbnailPolicyResolver.resolve()`는 env missing/empty/invalid를 `.coreGraphicsOnly`로 반환한다.
- Release build에서는 env 값과 무관하게 `.coreGraphicsOnly`로 반환한다.
- Stage 4 smoke의 DEBUG resolver contract에서도 missing case가 `coreGraphicsOnly`로 확인되었다.
- Skia path는 `ALHANGEUL_THUMBNAIL_RENDER_POLICY=skia` 또는 `skiaOptIn`에 해당하는 DEBUG/internal diagnostic path다.

## #392 handoff

#392에는 다음 baseline을 넘긴다.

1. 모든 대표 샘플에서 `1024x1024` bucket cache는 정상적으로 policy별 분리된다.
2. 동일 bucket에서 Skia pixel size가 CoreGraphics보다 긴 축 기준 1px 큰 패턴이 반복된다.
   - portrait 계열: `725x1024` vs `725x1025`
   - `request.hwp`: `732x1024` vs `732x1025`
   - landscape 계열 `KTX.hwp`: `1024x725` vs `1025x725`
3. fallback은 발생하지 않았으므로 #392는 fallback 원인보다 `maximumPixelSize -> Skia maxDimension/scale/rounding` mapping을 우선 검토하면 된다.
4. output bytes와 PNGBytes는 policy별로 차이가 크지만, #389 범위에서는 성능/정확도 판정이 아니라 진단 baseline으로만 남긴다.

## 검증 결과

실행:

```bash
rg -n "OK|FAIL|coreGraphicsOnly|skiaOptIn|Cache|Backend|Fallback|miss|exactHit|largerBucketHit|RenderMs|OutputBytes" \
  build.noindex/task389-thumbnail-policy build.noindex/task389-thumbnail-policy-representative \
  mydocs/working/task_m020_389_stage4.md
git diff --check
```

결과:

- `rg`: quick/representative 산출물과 Stage 4 보고서에서 resolver, cache, backend, fallback, render timing, output bytes 항목 확인.
- `git diff --check`: 성공.

## 완료 조건 확인

- 대표 샘플 smoke 결과가 존재한다.
- default provider는 CoreGraphics 유지로 확인된다.
- Skia opt-in diagnostic path가 backend/cache/fallback 정보를 남긴다.
- #392 maxDimension 실험에 필요한 baseline 입력을 분리했다.

## 승인 요청

Stage 4는 완료했다. Stage 5 `최종 보고와 PR 준비`로 진행해도 되는지 승인 요청한다.
