# Task M020 #258 구현계획서

수행계획서: `mydocs/plans/task_m020_258.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #258 Thumbnail renderer signature/cache diagnostic 설계와 Skia opt-in smoke
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 브랜치: `local/task258`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 선행 상태: #255/#256/#257/#278/#259/#305는 완료됐고, #259 결론에 따라 Quick Look/Thumbnail 기본 정책은 CoreGraphics 유지, Skia는 opt-in diagnostic backend로 정리됐다.
- 목표: Finder Thumbnail 기본 CoreGraphics 정책을 유지하면서 cache key/reuse 조건에 render signature를 반영하고, Skia opt-in thumbnail smoke에서 backend/fallback/latency/cache hit-miss를 반복 측정할 수 있게 한다.

## 구현 원칙

- Finder Thumbnail 제품 기본 경로는 `.coreGraphicsOnly`를 유지한다.
- Skia는 helper 또는 명시 opt-in 경로에서만 선택하고, 기본 provider 동작을 Skia-first로 바꾸지 않는다.
- cache key는 기존 file metadata invalidation과 pixel bucket을 유지하되, backend/render signature가 다르면 cache를 재사용하지 않는다.
- 같은 render signature 안에서는 큰 pixel bucket 결과를 작은 요청에 재사용하는 기존 최적화를 유지한다.
- Skia 실패는 Shared renderer의 CoreGraphics fallback을 먼저 사용하고, CoreGraphics까지 실패한 경우에만 기존 fallback tile 정책으로 간다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- `project.yml`을 원본으로 유지하고 `Alhangeul.xcodeproj`를 직접 수정하지 않는다.
- public release, signing/notarization, Finder provider 등록 smoke 전체 재정리는 수행하지 않는다.

## Thumbnail Cache/Signature Contract

| 항목 | 정책 |
|---|---|
| 기본 backend | Finder Thumbnail provider는 `.coreGraphicsOnly` |
| opt-in backend | smoke/helper에서 `.skiaOptIn` 명시 |
| file invalidation | path, modification time, file size 유지 |
| pixel bucket | `maximumSize * scale`을 16부터 2048까지 power-of-two bucket으로 반올림하는 기존 정책 유지 |
| render signature | backend policy, renderer option version, core commit, `native-skia` feature, thumbnail max-dimension policy version 포함 후보 |
| reuse 조건 | file identity, render signature가 같고 candidate pixel bucket이 요청 bucket 이상일 때만 재사용 |
| fallback 순서 | Skia opt-in 실패 시 CoreGraphics fallback, 이후 provider fallback tile |
| diagnostics | backend, fallback reason, latency, pixel size, png bytes, cache hit/miss, matched bucket |

Stage 1에서 source와 lock/provenance 구조를 확인한 뒤, Stage 2에서 실제 signature 필드와 version 문자열을 확정한다.

## Stage 1. Thumbnail cache/provider와 renderer contract inventory

### 목표

현재 Finder Thumbnail cache key, provider fallback, Shared renderer diagnostics, core provenance 입력을 조사해 Stage 2-3의 source 변경 범위를 고정한다.

### 작업

1. `HwpThumbnailRenderCache`의 request key, in-flight key, 큰 bucket 재사용 조건을 정리한다.
2. `HwpThumbnailProvider`의 기본 render request, success log, provider fallback tile 순서를 정리한다.
3. `HwpPageImageRenderer`의 `.coreGraphicsOnly`/`.skiaOptIn`, diagnostics, fallback reason mapping을 정리한다.
4. `rhwp-core.lock`와 Rust bridge 산출물에서 render signature에 사용할 수 있는 core commit/feature provenance를 확인한다.
5. 기존 Quick Look Skia smoke helper 구조를 확인하고 thumbnail 전용 helper로 재사용할 수 있는 compile input을 고정한다.
6. Quick Look 단일 PNG, 다중 PDF, Finder Thumbnail gate 분리 기준을 Stage 1 보고서에 초안으로 남긴다.

### 산출물

- `mydocs/plans/task_m020_258_impl.md`
- `mydocs/working/task_m020_258_stage1.md`

### 검증

```bash
rg -n "HwpThumbnailRenderCache|HwpThumbnailProvider|HwpThumbnailCacheKey|maximumPixelSize|pixelBucket|cachedPage|fallbackReply" \
  Sources/ThumbnailExtension
rg -n "coreGraphicsOnly|skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs|renderFirstPage|renderPage" \
  Sources/Shared Sources/QLExtension scripts --glob '!**/Resources/**'
rg -n "rhwp_commit|rhwp_enabled_features|native-skia" rhwp-core.lock scripts Sources
rg -n "#258|Stage 1|Thumbnail|cache|signature|Skia|CoreGraphics" \
  mydocs/plans/task_m020_258_impl.md mydocs/working/task_m020_258_stage1.md
git diff --check
```

### 완료 기준

- cache key와 재사용 조건의 현재 한계가 문서화된다.
- Stage 2에서 추가할 render signature 필드와 source 변경 파일이 확정된다.
- Stage 3에서 만들거나 보강할 thumbnail smoke helper의 입력/출력 형식이 확정된다.
- Swift source는 아직 변경하지 않는다.

### 커밋 메시지

```text
Task #258 Stage 1: Thumbnail cache signature 입력 조사
```

## Stage 2. Render signature와 cache reuse source 반영

### 목표

Thumbnail cache key와 in-flight/reuse 조건에 render signature를 추가해 backend 또는 render option 변경 후 stale thumbnail을 재사용하지 않게 한다.

### 작업

1. `HwpThumbnailRenderSignature` 또는 동등한 값 타입을 추가한다.
2. signature에 backend policy, renderer option version, core provenance, `native-skia` feature, thumbnail max-dimension policy version을 반영한다.
3. `HwpThumbnailRenderRequest`가 기본 `.coreGraphicsOnly` policy와 signature를 갖도록 한다.
4. `HwpThumbnailCacheKey`에 signature를 추가한다.
5. `cachedPage(for:)`의 큰 bucket 재사용 guard에 signature equality를 추가한다.
6. `renderFirstPage` 호출에 request policy를 전달하되 provider 기본은 `.coreGraphicsOnly`로 유지한다.
7. cache hit/miss와 matched bucket을 확인할 수 있는 내부 diagnostics 반환 구조가 필요한지 구현한다.
8. Stage 2 보고서에 source 변경과 cache contract를 기록한다.

### 산출물

- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- 필요 시 `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- `mydocs/working/task_m020_258_stage2.md`

### 검증

```bash
./scripts/check-no-appkit.sh
rg -n "HwpThumbnailRenderSignature|HwpThumbnailCacheKey|renderSignature|coreGraphicsOnly|skiaOptIn|cachedPage|matchedKey|maximumPixelSize" \
  Sources/ThumbnailExtension Sources/Shared
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask258 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

### 완료 기준

- Finder Thumbnail 기본 요청은 `.coreGraphicsOnly` signature를 사용한다.
- cache exact hit, in-flight key, 큰 bucket 재사용 모두 signature를 구분한다.
- 같은 signature 안의 큰 bucket 재사용은 유지된다.
- AppKit/UIKit guard와 ThumbnailExtension build가 통과한다.

### 커밋 메시지

```text
Task #258 Stage 2: Thumbnail render signature cache key 반영
```

## Stage 3. Thumbnail Skia opt-in diagnostic smoke helper

### 목표

제품 provider 기본 정책을 바꾸지 않고, 대표 문서와 요청 크기별로 CoreGraphics/Skia opt-in thumbnail 렌더 결과를 비교 측정하는 helper를 만든다.

### 작업

1. thumbnail 전용 Swift smoke helper를 추가하거나 Quick Look smoke helper를 분리 재사용한다.
2. helper는 입력 파일과 요청 size/scale bucket을 받아 `.coreGraphicsOnly`와 `.skiaOptIn`을 각각 측정한다.
3. output에는 backend, fallback reason, latency, pixel size, png bytes, cache hit/miss, matched bucket, output bytes를 기록한다.
4. Skia opt-in 실패 시 CoreGraphics fallback이 사용됐는지 diagnostics로 확인한다.
5. CoreGraphics fallback도 실패하는 오류에서는 provider fallback tile 순서가 유지되는지 source/보고서로 확인한다.
6. helper compile script를 추가하고 `build.noindex/task258-*` 아래에 산출물이 생기게 한다.
7. Stage 3 보고서에 helper 사용법과 샘플 1-2개 smoke 결과를 기록한다.

### 산출물

- 신규 `scripts/smoke-thumbnail-skia-policy.sh`
- 신규 `scripts/thumbnail_skia_policy_smoke.swift`
- 필요 시 `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- 필요 시 `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- `mydocs/working/task_m020_258_stage3.md`

### 검증

```bash
./scripts/check-no-appkit.sh
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
rg -n "Thumbnail Skia|CacheHit|CacheMiss|coreGraphicsOnly|skiaOptIn|fallback|latency|bucket" \
  scripts mydocs/working/task_m020_258_stage3.md
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask258 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

### 완료 기준

- helper가 CoreGraphics와 Skia opt-in thumbnail 결과를 같은 입력/size bucket에서 측정한다.
- smoke output에 backend, fallback, latency, cache hit/miss가 남는다.
- Finder Thumbnail provider 기본 정책은 CoreGraphics로 유지된다.

### 커밋 메시지

```text
Task #258 Stage 3: Thumbnail Skia opt-in smoke helper 추가
```

## Stage 4. 대표 샘플 smoke와 장기 gate 정리

### 목표

대표 문서와 size bucket에서 Thumbnail CoreGraphics/Skia opt-in 결과를 기록하고, PageLayerTree/Skia 장기 전환 gate를 문서화한다.

### 작업

1. 대표 문서 smoke를 실행한다.
   - `samples/복학원서.hwp`
   - `samples/basic/KTX.hwp`
   - `samples/basic/request.hwp`
   - `samples/hwpx/hwpx-01.hwpx`
   - `samples/hwp-multi-001.hwp`
2. 최소 3개 size/scale bucket을 측정한다.
   - 작은 Finder thumbnail 후보
   - 보통 Finder thumbnail 후보
   - 큰 Retina thumbnail 후보
3. latency, fallback, cache hit/miss, memory/hang 관측 결과를 Stage 4 보고서에 기록한다.
4. Quick Look 단일 PNG, Quick Look 다중 PDF, Finder Thumbnail을 독립 gate로 둘지 판단을 정리한다.
5. PageLayerTree `displayText`가 `U+F012B -> (인)`, `U+F081C -> 숨김` 같은 계약을 Swift/CoreGraphics 복제 없이 처리할 수 있는지 장기 판단을 정리한다.
6. `mydocs/tech/skia_quicklook_thumbnail_backend.md`에 반복 적용 가능한 gate 기준만 갱신한다.

### 산출물

- `mydocs/working/task_m020_258_stage4.md`
- 필요 시 `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- `build.noindex/task258-thumbnail-policy-*` smoke 산출물

### 검증

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
rg -n "#258|Thumbnail|cache signature|render signature|PageLayerTree|displayText|Quick Look|Finder Thumbnail|skiaOptIn|CoreGraphics" \
  mydocs/working/task_m020_258_stage4.md mydocs/tech/skia_quicklook_thumbnail_backend.md
git diff --check
git status --short --branch
```

### 완료 기준

- 대표 샘플과 size bucket별 smoke 결과가 기록된다.
- Thumbnail cache signature와 Skia opt-in gate 기준이 장기 기술 문서에 반영된다.
- Quick Look/Thumbnail gate 분리 여부와 PageLayerTree `displayText` 장기 전환 판단이 문서화된다.

### 커밋 메시지

```text
Task #258 Stage 4: Thumbnail Skia smoke와 장기 gate 정리
```

## Stage 5. 최종 보고서와 PR 준비

### 목표

#258 완료 기준을 최종 보고서에 대응시키고 오늘할일 완료 처리와 PR 게시 준비 상태를 만든다.

### 작업

1. Stage 1-4 산출물과 검증 결과를 최종 보고서에 정리한다.
2. Thumbnail default가 CoreGraphics로 유지됐다는 점을 source와 문서 기준으로 확인한다.
3. cache key/reuse 조건이 backend/render signature를 반영한다는 점을 정리한다.
4. Skia opt-in smoke 결과의 backend, fallback, latency, cache hit/miss를 요약한다.
5. 남은 PageLayerTree/Skia 장기 전환 후속 여부를 정리한다.
6. 오늘할일을 완료로 갱신한다.
7. PR 본문에 포함할 summary와 검증 결과를 준비한다.

### 산출물

- `mydocs/report/task_m020_258_report.md`
- `mydocs/orders/20260603.md`

### 검증

```bash
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask258 CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-final-thumbnail-policy \
  samples/복학원서.hwp samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
rg -n "#258|Thumbnail|CoreGraphics|skiaOptIn|cache|signature|fallback|latency|hit|miss|PageLayerTree" \
  mydocs/report/task_m020_258_report.md mydocs/orders/20260603.md Sources/ThumbnailExtension scripts
git diff --check
git status --short --branch
```

### 완료 기준

- #258 완료 기준이 최종 보고서에서 모두 대응된다.
- 작업 브랜치에 미커밋 변경이 없다.
- PR 생성 전 publish 준비 상태다.

### 커밋 메시지

```text
Task #258 Stage 5 + 최종 보고서: Thumbnail cache diagnostic 결과 정리
```
