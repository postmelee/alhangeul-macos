# Task M020 #389 Stage 1 완료 보고서

## 단계 목적

현재 Thumbnail provider, cache result, smoke helper가 관측할 수 있는 값과 부족한 값을 정리하고, Stage 2에서 구현할 DEBUG/internal opt-in resolver contract를 확정한다.

## 조사 대상

| 파일 | 확인 내용 |
|------|-----------|
| `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | provider request 생성, 기본 policy, 현재 OSLog 항목 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | render request 기본값, render signature, cache event/result contract |
| `scripts/smoke-thumbnail-skia-policy.sh` | smoke runner compile list와 output 구조 |
| `scripts/thumbnail_skia_policy_smoke.swift` | policy pair 측정, cache/backend/fallback summary/detail column |
| `mydocs/report/task_m020_258_report.md` | #258 cache signature와 smoke helper handoff |
| `mydocs/report/task_m020_396_report.md` | #396 이후 Thumbnail/Finder surface handoff |
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | Thumbnail backend/fallback/logging 정책 기준 |
| `project.yml` | ThumbnailExtension source 포함 방식 |

## 현재 provider 흐름

`HwpThumbnailProvider.provideThumbnail`은 현재 다음 순서로 동작한다.

1. `QLFileThumbnailRequest`를 받는다.
2. `HwpThumbnailRenderRequest(fileURL:maximumSize:scale:)`를 생성한다.
3. `HwpThumbnailRenderCache.shared.renderedPage(for:)`를 호출한다.
4. 성공 시 aspect-fit context에 page image를 그리고 extension badge를 설정한다.
5. fallback 대상 오류는 기존 fallback tile로 수렴한다.
6. 그 외 오류는 handler에 error를 반환한다.

현재 provider는 `HwpThumbnailRenderRequest` 생성 시 `policy`를 넘기지 않는다. 따라서 `HwpThumbnailRenderRequest` initializer의 기본값인 `.coreGraphicsOnly`가 production/default provider policy다.

현재 provider 로그:

| 시점 | 현재 로그 | 부족한 값 |
|------|-----------|-----------|
| request 시작 | file basename, requested point size, scale | resolved policy |
| render enqueue | maximum pixel bucket | render signature |
| render success | context size, rendered page size | cache event, requested/matched bucket, backend used, fallback reason, render timing, pixel size |
| fallback/failure | file basename, error description | resolved policy, backend/fallback context |

## cache/result contract

`HwpThumbnailRenderRequest`는 다음 값을 가진다.

| 항목 | 현재 값/의미 |
|------|--------------|
| `policy` | 기본값 `.coreGraphicsOnly`; 명시하면 `.skiaOptIn` 가능 |
| `maximumPixelSize` | point size와 scale을 bucket화한 값. 현재 #392 maxDimension mapping과는 별개 |
| `renderSignature` | policy, renderer option version, core release/commit/features, maxDimension policy version |
| `key` | path, mtime, file size, pixel bucket, render signature |

`HwpThumbnailRenderCache.renderedPageResult(for:)`는 성공 시 `HwpThumbnailRenderResult`를 반환한다.

| 항목 | Stage 2 provider logging에 사용 가능 여부 |
|------|------------------------------------------|
| `page` | 가능. `page.diagnostics`에서 backend/fallback/timing/pixel 정보를 얻는다 |
| `cacheEvent` | 가능. `miss`, `exactHit`, `largerBucketHit(...)` |
| `requestedKey` | 가능. requested bucket과 signature 확인 |
| `matchedKey` | 가능. cache hit에서 실제 reuse bucket 확인 |

현재 cache는 이미 policy/render signature로 key와 larger bucket reuse를 분리한다. Stage 2에서 cache 자체를 변경할 필요는 없어 보인다.

## smoke helper contract

`scripts/smoke-thumbnail-skia-policy.sh`는 Swift runner를 compile해서 같은 입력 파일에 대해 `.coreGraphicsOnly`와 `.skiaOptIn`을 모두 측정한다.

현재 summary column:

```text
File, Policy, Request, Status, Cache, RequestedBucket, MatchedBucket,
Backend, Fallback, Pixel, OutputBytes, PNGBytes, RenderMs, Seconds
```

현재 detail file 항목:

```text
Request, Status, Error, CacheEvent, RequestedBucket, MatchedBucket,
Signature, Backend, Fallback, PageSize, PixelSize, PNGBytes,
OutputBytes, RenderMs, ElapsedSeconds
```

따라서 smoke helper는 이미 #389가 필요로 하는 cache event, backend used, fallback reason, timing을 대부분 갖고 있다. 부족한 부분은 provider resolver와 같은 policy identifier를 검증하거나 provider opt-in contract를 summary에 명시하는 것이다.

## #258 / #396 handoff 반영

#258에서 이미 확인된 기준:

- Finder Thumbnail provider 기본 policy는 `.coreGraphicsOnly`.
- cache key, in-flight key, larger bucket reuse guard는 render signature equality를 사용한다.
- 대표 5개 샘플 smoke에서 40 rows 모두 `OK`, fallback 0.
- 각 파일/정책 cache event는 `miss -> exactHit -> largerBucketHit -> largerBucketHit` 흐름이었다.
- helper는 extension 내부 cache contract 검증이고 Finder/LaunchServices 시스템 cache 검증은 별도다.

#396에서 이어받은 기준:

- visual baseline만으로 Thumbnail/Finder cache 판단은 완료되지 않는다.
- #389는 Finder Thumbnail cache/signature/logging 관측성을 보강하는 후속이다.
- #392는 Thumbnail maxDimension mapping과 size drift 판단을 별도 surface smoke로 이어갈 후속이다.

## project/source 포함 방식

`project.yml`의 `ThumbnailExtension` target은 `Sources/ThumbnailExtension` 디렉터리 전체를 source path로 포함한다. 따라서 Stage 2에서 `Sources/ThumbnailExtension/HwpThumbnailPolicyResolver.swift`를 새로 추가하면 Xcode target에는 source folder 경유로 포함된다.

다만 `scripts/smoke-thumbnail-skia-policy.sh`는 `swiftc` compile list를 명시적으로 나열한다. Stage 3에서 smoke runner가 새 resolver를 참조하게 되면 compile list에 `HwpThumbnailPolicyResolver.swift`를 직접 추가해야 한다.

## Stage 2 resolver contract 확정

Stage 2는 `HwpThumbnailPolicyResolver` 신규 source를 추가하는 방향으로 진행한다.

Resolver contract:

| 항목 | 결정 |
|------|------|
| env key | `ALHANGEUL_THUMBNAIL_RENDER_POLICY` |
| 허용 값 | `skia`, `skiaOptIn`, `coreGraphics`, `coreGraphicsOnly` |
| empty/missing/invalid | `.coreGraphicsOnly` |
| Release build | env 값과 무관하게 `.coreGraphicsOnly` |
| DEBUG build | 명시 env 값이 `skia`/`skiaOptIn`이면 `.skiaOptIn` |
| display identifier | `coreGraphicsOnly`, `skiaOptIn` 문자열 helper 제공 |
| user-facing preference | 추가하지 않음 |

Provider 변경 방향:

1. `HwpThumbnailPolicyResolver.resolve()`로 policy를 얻는다.
2. `HwpThumbnailRenderRequest(..., policy: resolvedPolicy)`로 전달한다.
3. `renderedPage(for:)` 대신 `renderedPageResult(for:)`를 사용한다.
4. success log에 다음 값을 포함한다.
   - `policy`
   - `cacheEvent`
   - `requestedBucket`
   - `matchedBucket`
   - `backend`
   - `fallback`
   - `renderMs`
   - `pixelSize`
5. fallback/failure log에도 `policy`를 포함한다.

Cache source 변경은 Stage 2의 기본 대상이 아니다. provider에서 필요한 formatting helper만 추가한다.

## Stage 3 smoke 보강 범위 확정

Stage 3는 다음만 보강한다.

- smoke compile list에 resolver source가 필요하면 추가한다.
- runner가 resolver default/env opt-in contract를 확인할 수 있도록 간단한 row 또는 detail 항목을 추가할지 검토한다.
- 기존 policy pair 측정과 summary column은 유지한다.

Stage 3에서 하지 않을 일:

- maxDimension policy 변경
- Finder/LaunchServices system cache 검증
- release package registration smoke 확장

## 본문 변경 정도 / 본문 무손실 여부

Stage 1은 inventory 문서 작성 단계다. 제품 Swift source, shell script, project configuration, Rust bridge, sample 문서는 변경하지 않았다.

## 검증 결과

실행 대상:

```bash
rg -n "HwpThumbnailProvider|HwpThumbnailRenderRequest|renderedPageResult|HwpThumbnailCacheEvent|backendUsed|fallbackReason|smoke-thumbnail-skia-policy" \
  Sources/ThumbnailExtension scripts mydocs/report/task_m020_258_report.md \
  mydocs/report/task_m020_396_report.md mydocs/working/task_m020_389_stage1.md
git diff --check
```

결과는 Stage 1 커밋 전 최종 확인으로 남긴다.

## 잔여 위험

- provider OSLog는 smoke summary처럼 파일로 바로 수집되지 않는다. Stage 2-3에서 log와 smoke output의 역할을 분리해야 한다.
- 정상 샘플에서는 Skia fallback reason이 `-`로 남을 가능성이 높다. forced fallback fixture는 이번 작업의 완료 조건으로 두지 않는다.
- Release build에서 env opt-in을 막는 방식은 Swift compile condition에 의존한다. Stage 2에서 `#if DEBUG` 경계가 명확해야 한다.
- 새 resolver source는 Xcode target에는 자동 포함되지만 smoke helper의 manual compile list에는 직접 추가가 필요할 수 있다.

## 다음 단계 영향

Stage 2는 `HwpThumbnailPolicyResolver` 신규 source와 `HwpThumbnailProvider` logging 변경으로 진행한다. public reply/fallback behavior는 유지하고, provider가 `renderedPageResult(for:)`를 통해 cache/backend/fallback 정보를 로그에 남기는지만 바꾼다.

## 승인 요청

Stage 1은 완료했다. Stage 2 `provider policy resolver와 cache logging 구현`으로 진행해도 되는지 승인 요청한다.
