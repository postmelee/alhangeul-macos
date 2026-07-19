# Task M020 #389 Stage 3 완료 보고서

## 단계 목적

smoke helper가 Stage 2에서 추가한 provider policy resolver contract와 cache/backend/fallback diagnostic output을 함께 검증할 수 있게 보강한다.

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `scripts/smoke-thumbnail-skia-policy.sh` | smoke compile list에 `HwpThumbnailPolicyResolver.swift` 추가, resolver opt-in 검증을 위해 `-DDEBUG`로 compile |
| `scripts/thumbnail_skia_policy_smoke.swift` | resolver contract summary/detail, cache signature separation summary/detail 추가 |
| `mydocs/orders/20260701.md` | Stage 3 완료보고서 승인 대기 상태로 갱신 |

## smoke helper 보강 내용

### Resolver contract

runner가 `HwpThumbnailPolicyResolver.resolve(environment:)`를 직접 호출해 다음 case를 기록한다.

| case | 기대값 |
|------|--------|
| missing | `coreGraphicsOnly` |
| empty | `coreGraphicsOnly` |
| invalid | `coreGraphicsOnly` |
| `coreGraphics` | `coreGraphicsOnly` |
| `coreGraphicsOnly` | `coreGraphicsOnly` |
| `skia` | `skiaOptIn` |
| `skiaOptIn` | `skiaOptIn` |

이 검증은 provider의 DEBUG/internal opt-in path를 확인하기 위한 것이므로 smoke binary는 `-DDEBUG`로 compile한다. Release에서 env opt-in을 무시하는 동작은 Stage 2 source의 `#if DEBUG` 경계로 유지한다.

산출물:

- `summary.txt`: `ResolverBuild`, `ResolverEnvKey`, `ResolverContract`, resolver contract table 추가
- `resolver-contract.txt`: resolver contract 전용 detail 추가

### Cache signature separation

각 파일에 대해 첫 CoreGraphics request와 첫 Skia opt-in request를 비교한다.

확인 기준:

- CoreGraphics 첫 request cache event가 `miss`
- Skia opt-in 첫 request cache event가 `miss`
- 두 request의 render signature가 서로 다름

이 기준이 충족되면 `Cache Signature Separation` status를 `OK`로 기록한다. 이는 cache key가 policy/render signature별로 분리되는지 smoke summary에서 바로 확인하기 위한 진단이다.

산출물:

- `summary.txt`: `## Cache Signature Separation` table 추가
- 각 per-file detail: `[CacheSignatureSeparation]` block 추가

기존 render measurement row는 유지했다.

## 실행 결과

실행:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-stage3-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

콘솔 요약:

```text
resolver: OK
request.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
KTX.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
```

주요 산출물:

| 파일 | 결과 |
|------|------|
| `build.noindex/task389-stage3-thumbnail-policy/summary.txt` | resolver contract `OK`, render 16 rows 모두 `OK`, cache signature separation 2 rows 모두 `OK` |
| `build.noindex/task389-stage3-thumbnail-policy/resolver-contract.txt` | 7개 resolver case 모두 `OK` |
| `build.noindex/task389-stage3-thumbnail-policy/request-thumbnail-skia-policy.txt` | `CoreFirstCache: miss`, `SkiaFirstCache: miss`, signature 분리 `OK` |
| `build.noindex/task389-stage3-thumbnail-policy/KTX-thumbnail-skia-policy.txt` | `CoreFirstCache: miss`, `SkiaFirstCache: miss`, signature 분리 `OK` |

정상 샘플에서는 `Fallback: -`로 남았다. 이는 fallback이 발생하지 않았다는 의미이며, fallback column은 summary/detail에 유지된다.

## 검증 결과

실행:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-stage3-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
rg -n "coreGraphicsOnly|skiaOptIn|Cache|Backend|Fallback|miss|exactHit|largerBucketHit|ALHANGEUL_THUMBNAIL_RENDER_POLICY" \
  build.noindex/task389-stage3-thumbnail-policy scripts Sources/ThumbnailExtension \
  mydocs/working/task_m020_389_stage3.md
git diff --check
```

결과:

- smoke: 성공.
- `rg`: resolver env key, policy names, cache/backend/fallback column, `miss/exactHit/largerBucketHit` 산출물 확인.
- `git diff --check`: 성공.

## 잔여 위험

- smoke helper는 DEBUG resolver opt-in path를 검증한다. Release binary에서 env opt-in이 막히는지는 source `#if DEBUG` 경계로 보장하고, Release build smoke는 이번 단계 범위가 아니다.
- 정상 샘플만 사용했기 때문에 forced fallback reason fixture는 검증하지 않았다.
- Finder/LaunchServices system cache 검증은 여전히 별도 영역이며, 이번 helper는 extension 내부 render cache contract를 확인한다.

## 완료 조건 확인

- smoke helper가 새 resolver source와 함께 compile/run 된다.
- CoreGraphics/Skia opt-in policy pair가 기존처럼 측정된다.
- cache event/backend/fallback column이 summary/detail에 유지된다.
- resolver contract와 policy signature separation 결과가 후속 보고에 충분히 남는다.

## 승인 요청

Stage 3은 완료했다. Stage 4 `대표 샘플 smoke와 #392 handoff 정리`로 진행해도 되는지 승인 요청한다.
