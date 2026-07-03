# Task M020 #392 구현계획서

수행계획서: `mydocs/plans/task_m020_392.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #392 `Thumbnail Skia maxDimension mapping 실험`
- 추적 이슈: #387 Preview/Thumbnail Skia readiness 후속 개선 추적
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task392`
- 목표: Thumbnail Skia opt-in 경로에서 `maximumPixelSize`를 upstream PNG export `maxDimension`으로 매핑해 1px size drift와 cache/signature 영향을 측정한다.

## 구현 원칙

- production default는 계속 `.coreGraphicsOnly`다.
- Skia default 전환, Quick Look direct PNG, upstream `rhwp` 변경은 하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- `project.yml`이 Xcode project 원본이다. 이번 작업은 새 Swift source 추가 없이 기존 target source만 변경하는 것을 우선한다.
- maxDimension 정책 변경이 cache output을 바꿀 수 있으므로 `HwpThumbnailRenderSignature`의 policy version을 반드시 검토한다.
- scale-only baseline과 maxDimension 적용 후 결과를 같은 request sequence로 비교한다.

## Stage 1. 현행 scale-only baseline inventory

### 목표

현재 Thumbnail Skia path가 `maxDimension: 0`으로 동작하는 계약과 baseline output을 고정한다.

### 대상

- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `scripts/smoke-thumbnail-skia-policy.sh`
- `scripts/thumbnail_skia_policy_smoke.swift`
- `mydocs/report/task_m020_389_report.md`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- `mydocs/tech/skia_preview_renderer_baseline.md`

### 작업

1. `HwpPageImageRenderer.renderPage`가 `maximumPixelSize`로 scale을 계산하고, Skia 호출에는 `maxDimension: 0`을 넘기는 현재 흐름을 정리한다.
2. `HwpThumbnailRenderRequest`의 pixel bucket 계산과 `HwpThumbnailRenderSignature.maxDimensionPolicyVersion == skia-max-dimension-0` 의미를 정리한다.
3. smoke helper가 이미 기록하는 `RequestedBucket`, `MatchedBucket`, `Signature`, `Pixel`, `OutputBytes`, `PNGBytes`, `RenderMs`를 확인한다.
4. 현재 브랜치에서 quick smoke를 실행해 #389 baseline과 같은 1px drift가 재현되는지 확인한다.
5. Stage 2에서 변경할 source surface와 signature version 후보를 확정한다.

### 검증

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage1-scale-only \
  samples/basic/request.hwp samples/basic/KTX.hwp
rg -n "maxDimension|maximumPixelSize|skia-max-dimension-0|1024x1025|1025x725|Signature|Pixel" \
  Sources/Shared/HwpPageImageRenderer.swift Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift \
  build.noindex/task392-stage1-scale-only mydocs/working/task_m020_392_stage1.md
git diff --check
```

### 완료 조건

- 현재 scale-only Skia path와 thumbnail cache signature 의미가 문서화되어 있다.
- quick smoke baseline에서 request bucket, Skia pixel size, cache pattern, signature가 정리되어 있다.
- Stage 2 설계 입력이 충분하다.

### 커밋 메시지

```text
Task #392 Stage 1: Thumbnail maxDimension baseline inventory
```

## Stage 2. maxDimension mapping 설계와 signature 정책 확정

### 목표

Shared renderer와 Thumbnail cache 사이에서 `maximumPixelSize -> maxDimension`을 어떻게 연결할지 확정한다.

### 대상

- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `scripts/thumbnail_skia_policy_smoke.swift`
- `mydocs/working/task_m020_392_stage2.md`

### 작업

1. `renderSkiaPage`가 `maximumPixelSize` 또는 계산된 `maxDimension`을 받을 수 있게 하는 최소 API 변경안을 정한다.
2. `maxDimension` 계산 규칙을 정한다.
   - `maximumPixelSize == nil`이면 `0`
   - finite이고 양수인 긴 변만 사용
   - `Int(UInt32.max)` 초과 방어는 `RhwpDocument.renderPagePNG` guard와 중복되지 않게 처리
3. Thumbnail에서만 maxDimension mapping을 적용하고 Quick Look path 영향이 없는지 확인한다.
4. `HwpThumbnailRenderSignature.maxDimensionPolicyVersion` 새 값을 정한다.
   - 후보: `skia-max-dimension-thumbnail-v1`
   - 기존 `skia-max-dimension-0` cache와 분리되는지 확인
5. smoke summary/detail에서 signature version 변화와 pixel drift를 확인할 수 있는지 검토한다.

### 검증

```bash
rg -n "renderSkiaPage|renderPagePNG|maxDimensionPolicyVersion|HwpThumbnailRenderSignature|maximumPixelSize" \
  Sources/Shared/HwpPageImageRenderer.swift Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift \
  scripts/thumbnail_skia_policy_smoke.swift mydocs/working/task_m020_392_stage2.md
git diff --check
```

### 완료 조건

- source 변경 전 적용할 maxDimension mapping contract가 문서화되어 있다.
- cache signature version 변경 여부와 값이 확정되어 있다.
- Stage 3 구현 범위가 source 단위로 명확하다.

### 커밋 메시지

```text
Task #392 Stage 2: Thumbnail maxDimension mapping 설계
```

## Stage 3. opt-in 실험 구현과 smoke 보강

### 목표

Thumbnail Skia opt-in path에 maxDimension mapping을 적용하고, smoke 결과가 정책 변경을 추적할 수 있게 한다.

### 대상

- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- 필요 시 `scripts/thumbnail_skia_policy_smoke.swift`
- `mydocs/working/task_m020_392_stage3.md`

### 작업

1. `HwpPageImageRenderer.renderPage`에서 Skia attempt 호출 시 `maximumPixelSize` 기반 maxDimension을 전달한다.
2. CoreGraphics path와 embedded thumbnail decode path는 기존 scale/bucket 정책을 유지한다.
3. `HwpThumbnailRenderSignature`의 maxDimension policy version을 새 값으로 갱신한다.
4. smoke helper가 기존 `Signature`, `Pixel`, `RequestedBucket`, `MatchedBucket` column으로 충분한지 확인하고, 부족하면 최소 column만 보강한다.
5. quick smoke로 cache miss/hit/reuse와 backend/fallback이 유지되는지 확인한다.

### 검증

```bash
./scripts/check-no-appkit.sh
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage3-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
rg -n "skia-max-dimension|coreGraphicsOnly|skiaOptIn|Pixel|Signature|miss|exactHit|largerBucketHit|Fallback" \
  build.noindex/task392-stage3-thumbnail-policy Sources scripts mydocs/working/task_m020_392_stage3.md
git diff --check
```

가능하면 build 검증:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask392Stage3 CODE_SIGNING_ALLOWED=NO build
```

### 완료 조건

- Thumbnail Skia opt-in path에서 `maxDimension`이 요청 bucket 긴 변으로 전달된다.
- cache signature가 기존 scale-only 정책과 분리된다.
- quick smoke가 성공하고 fallback이 새로 발생하지 않는다.

### 커밋 메시지

```text
Task #392 Stage 3: Thumbnail Skia maxDimension opt-in 적용
```

## Stage 4. 대표 샘플 비교 측정

### 목표

대표 샘플에서 maxDimension 정책 적용 후 pixel size, latency, bytes, cache pattern을 측정하고 #389 baseline과 비교한다.

### 대상

- `build.noindex/task392-stage1-scale-only/`
- `build.noindex/task392-stage3-thumbnail-policy/`
- `build.noindex/task392-thumbnail-policy-representative/`
- `mydocs/working/task_m020_392_stage4.md`
- 필요 시 `mydocs/tech/skia_preview_renderer_baseline.md`

### 작업

1. 기본 검증 command를 실행한다.
2. 대표 샘플 smoke를 실행한다.
3. `request.hwp`, `KTX.hwp`, `복학원서.hwp`, `hwpx-01.hwpx`, `hwp-multi-001.hwp`의 CoreGraphics/Skia pixel size를 비교한다.
4. 1px drift가 해소/유지/다른 형태로 변했는지 표로 정리한다.
5. `RenderMs`, `OutputBytes`, `PNGBytes`, cache pattern, signature를 함께 정리한다.
6. #393 또는 #259로 넘길 판단 근거와 잔여 risk를 분리한다.

### 검증

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
rg -n "OK|FAIL|coreGraphicsOnly|skiaOptIn|Pixel|OutputBytes|PNGBytes|RenderMs|Signature|skia-max-dimension|largerBucketHit" \
  build.noindex/task392-thumbnail-policy-representative mydocs/working/task_m020_392_stage4.md
git diff --check
```

### 완료 조건

- 대표 샘플 결과가 존재하고 summary/detail을 근거로 해석 가능하다.
- 1px drift에 대한 결론이 sample별로 정리되어 있다.
- latency/bytes/cache signature risk가 보고서 입력으로 정리되어 있다.

### 커밋 메시지

```text
Task #392 Stage 4: Thumbnail maxDimension 대표 샘플 검증
```

## Stage 5. 최종 보고와 문서 반영

### 목표

#392 실험 결과를 최종 보고서와 기술 문서에 반영하고 PR 게시 준비를 완료한다.

### 대상

- `mydocs/report/task_m020_392_report.md`
- `mydocs/orders/20260703.md`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- 필요 시 `mydocs/tech/skia_preview_renderer_baseline.md`

### 작업

1. 최종 보고서에 maxDimension mapping 정책, signature version, smoke 결과, 비교 결론을 정리한다.
2. 기술 문서의 Thumbnail maxDimension 기준과 잔여 판단을 갱신한다.
3. 오늘할일 #392 상태를 완료 처리한다.
4. #387, #389, #393, #259와의 후속 관계를 정리한다.
5. PR body 초안에 들어갈 변경 요약과 검증 결과를 정리한다.

### 검증

```bash
rg -n "#392|#387|#389|#393|#259|maxDimension|maximumPixelSize|Thumbnail|Skia|CoreGraphics|cache|signature|smoke" \
  mydocs/report/task_m020_392_report.md mydocs/orders/20260703.md \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/tech/skia_preview_renderer_baseline.md
git diff --check
git status --short --branch
git log --oneline devel..local/task392
```

### 완료 조건

- #392 최종 결론과 잔여 risk가 문서화되어 있다.
- 오늘할일이 완료 처리되어 있다.
- PR 게시에 필요한 변경 요약과 검증 결과가 정리되어 있다.

### 커밋 메시지

```text
Task #392 Stage 5 + 최종 보고서: Thumbnail maxDimension 실험 정리
```

## 승인 요청 사항

- 이 구현계획서 승인 후 Stage 1 `현행 scale-only baseline inventory`를 시작한다.
- Stage 1에서는 source 변경 없이 baseline 조사와 재측정만 수행한다.
- Stage 3 전까지 production 동작을 바꾸는 코드는 작성하지 않는다.
