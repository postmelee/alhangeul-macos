# Task #258 Stage 3 완료 보고서

## 단계 목적

Finder Thumbnail provider 기본 동작을 바꾸지 않고, helper에서만 CoreGraphics와 Skia opt-in thumbnail 렌더 결과를 같은 파일/요청 bucket 기준으로 비교 측정한다. Smoke output에는 backend, fallback, latency, bucket, CacheMiss/CacheHit 성격의 cache event가 남아야 한다.

## 산출물

| 파일 | 내용 |
|---|---|
| `scripts/smoke-thumbnail-skia-policy.sh` | thumbnail smoke Swift runner 빌드/실행 wrapper |
| `scripts/thumbnail_skia_policy_smoke.swift` | CoreGraphics/Skia opt-in thumbnail policy, request bucket, cache event 측정 runner |
| `mydocs/working/task_m020_258_stage3.md` | Stage 3 변경과 smoke 결과 기록 |
| `mydocs/orders/20260603.md` | #258 상태를 Stage 3 완료 보고서 승인 대기로 갱신 |

## 구현 내용

### Smoke wrapper

`scripts/smoke-thumbnail-skia-policy.sh`를 추가했다. 기존 Quick Look smoke wrapper와 같은 구조로 `Frameworks/universal/librhwp.a`, `Frameworks/modulemap`, RhwpCoreBridge, Shared renderer, `HwpThumbnailRenderCache`를 Swift runner와 함께 compile한다.

기본 사용법:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

선택적으로 `--request NAME:WIDTHxHEIGHT@SCALE`을 여러 번 넘겨 request preset을 직접 지정할 수 있다.

### Swift runner

`scripts/thumbnail_skia_policy_smoke.swift`는 각 입력 파일에서 다음 policy를 순서대로 측정한다.

- `.coreGraphicsOnly`
- `.skiaOptIn`

기본 request preset은 다음 순서다.

| Request | maximumSize | scale | 의도 |
|---|---:|---:|---|
| `large` | `512x512` | `2` | 첫 render CacheMiss |
| `large-repeat` | `512x512` | `2` | 같은 key exact CacheHit |
| `medium-after-large` | `256x256` | `2` | 큰 bucket 재사용 CacheHit |
| `small-after-large` | `128x128` | `1` | 큰 bucket 재사용 CacheHit |

Runner는 `HwpThumbnailRenderCache.renderedPageResult(for:)`를 호출해 다음 값을 summary/detail 파일에 기록한다.

- policy
- request size/scale
- requested bucket
- matched bucket
- render signature
- cache event (`miss`, `exactHit`, `largerBucketHit`)
- backend
- fallback
- pixel size
- output PNG bytes
- Skia PNG bytes
- renderMs
- elapsed seconds

## Smoke 결과

명령:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

결과:

| File | Policy | large miss | exact hit | larger bucket hit | Backend | Fallback |
|---|---|---:|---:|---:|---|---|
| `request.hwp` | `coreGraphicsOnly` | 1 | 1 | 2 | `coreGraphics` | 0 |
| `request.hwp` | `skiaOptIn` | 1 | 1 | 2 | `skia` | 0 |
| `KTX.hwp` | `coreGraphicsOnly` | 1 | 1 | 2 | `coreGraphics` | 0 |
| `KTX.hwp` | `skiaOptIn` | 1 | 1 | 2 | `skia` | 0 |

대표 수치:

| File | Policy | First render ms | First elapsed sec | Output bytes | Skia PNG bytes |
|---|---|---:|---:|---:|---:|
| `request.hwp` | `coreGraphicsOnly` | 1180.819 | 1.191673 | 126597 | - |
| `request.hwp` | `skiaOptIn` | 95.295 | 0.096691 | 120977 | 121702 |
| `KTX.hwp` | `coreGraphicsOnly` | 64.779 | 0.069169 | 484340 | - |
| `KTX.hwp` | `skiaOptIn` | 62.633 | 0.064418 | 164259 | 151997 |

Smoke runner stdout에는 `LAYOUT_OVERFLOW` 로그가 출력됐지만 helper 실패는 없었다. `summary.txt` 기준 모든 row의 status는 `OK`이고 fallback은 `-`이다.

## 본문 변경 정도 / 본문 무손실 여부

제품 provider인 `HwpThumbnailProvider`는 변경하지 않았다. `HwpThumbnailRenderCache`는 Stage 2에서 추가된 `renderedPageResult(for:)`를 helper가 사용하게 했고, 기존 `renderedPage(for:)` API는 유지된다. Finder Thumbnail default는 계속 CoreGraphics다.

## 검증 결과

| 검증 | 결과 |
|---|---|
| `./scripts/check-no-appkit.sh` | 통과 |
| `./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy samples/basic/request.hwp samples/basic/KTX.hwp` | 통과, 2 files x 2 policies x 4 requests, 실패 0 |
| `rg -n "Thumbnail Skia\|CacheHit\|CacheMiss\|coreGraphicsOnly\|skiaOptIn\|fallback\|latency\|bucket" scripts mydocs/working/task_m020_258_stage3.md` | 통과 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask258 CODE_SIGNING_ALLOWED=NO build` | 통과: sandbox 밖 재실행에서 `** BUILD SUCCEEDED **` |
| `git diff --check` | 통과 |

Sandbox 제약:

- `xcodebuild`는 sandbox 내부에서 Swift/clang cache 쓰기 제한으로 실패했다.
- 같은 명령을 권한 허용 상태로 재실행했고 build가 통과했다.

## 잔여 위험

| 항목 | 내용 |
|---|---|
| forced fallback fixture | 이번 helper는 Skia fallback을 강제로 유발하는 fixture를 만들지 않았다. Stage 4에서는 대표 샘플 smoke 결과로 fallback 0 또는 발생 원인을 기록한다. |
| cache event granularity | `inFlightJoin`은 별도 event로 분리하지 않았다. 현재 helper는 miss, exactHit, largerBucketHit를 측정한다. |
| output size interpretation | cache hit row의 `renderMs`는 원 render diagnostics 값이고, hit latency는 `elapsedSeconds`로 봐야 한다. |
| Finder system cache | helper는 extension 내부 cache contract 검증이다. Finder 시스템 cache와 LaunchServices 등록은 이번 scope 밖이다. |

## 다음 단계 영향

Stage 4에서는 이 helper를 대표 샘플 5개로 확장 실행하고, 최소 3개 bucket의 latency/fallback/cache hit-miss를 기록한다. 또한 `mydocs/tech/skia_quicklook_thumbnail_backend.md`에 반복 적용 가능한 Thumbnail gate와 Quick Look/Thumbnail gate 분리 기준을 반영한다.

## 승인 요청

Stage 3 helper 추가와 smoke 결과를 승인하면 Stage 4 `대표 샘플 smoke와 장기 gate 정리`로 진행한다.
