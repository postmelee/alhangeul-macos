# Task M020 #389 구현계획서

수행계획서: `mydocs/plans/task_m020_389.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #389 `Thumbnail Skia opt-in diagnostic path와 cache logging 추가`
- 추적 이슈: #387 Preview/Thumbnail Skia readiness 후속 개선 추적
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task389`
- 목표: Finder Thumbnail production default는 CoreGraphics로 유지하면서 DEBUG/internal 진단 경로에서 Skia opt-in provider path와 cache/backend/fallback 로그를 관측할 수 있게 한다.

## 구현 원칙

- Skia default 전환은 하지 않는다.
- Release/production provider 기본값은 `.coreGraphicsOnly`로 유지한다.
- opt-in은 DEBUG 또는 명시 internal diagnostic 입력에서만 허용한다.
- #392의 `maxDimension` mapping 정책 변경은 이 작업에 섞지 않는다.
- provider의 public reply shape, fallback tile, extension badge 동작은 유지한다.
- `project.yml`이 Xcode project 원본이다. 새 Swift 파일이 필요하면 source folder 자동 포함 여부를 확인하고, 직접 `Alhangeul.xcodeproj`를 수정하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit를 추가하지 않는다.

## Stage 1. provider/cache/smoke 진단 경로 inventory

### 목표

현재 Thumbnail provider, cache result, smoke helper가 관측할 수 있는 값과 부족한 값을 정리하고, DEBUG/internal opt-in resolver contract를 확정한다.

### 대상

- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `scripts/smoke-thumbnail-skia-policy.sh`
- `scripts/thumbnail_skia_policy_smoke.swift`
- `mydocs/report/task_m020_258_report.md`
- `mydocs/report/task_m020_396_report.md`
- `mydocs/working/task_m020_389_stage1.md`

### 작업

1. provider가 현재 `HwpThumbnailRenderRequest`를 만드는 위치와 기본 policy 흐름을 확인한다.
2. `HwpThumbnailRenderCache.renderedPageResult(for:)`가 제공하는 cache event, requested/matched key, diagnostics 항목을 정리한다.
3. smoke helper가 이미 남기는 summary/detail column을 provider logging 요구사항과 비교한다.
4. opt-in resolver 입력을 확정한다.
   - 후보: `ALHANGEUL_THUMBNAIL_RENDER_POLICY=skiaOptIn`
   - 허용 alias 후보: `skia`, `skiaOptIn`, `coreGraphics`, `coreGraphicsOnly`
   - invalid/empty value는 `.coreGraphicsOnly`
   - Release build에서는 환경변수 값과 무관하게 `.coreGraphicsOnly`
5. Stage 2 source 변경 범위와 Stage 3 smoke 보강 범위를 확정한다.

### 검증

```bash
rg -n "HwpThumbnailProvider|HwpThumbnailRenderRequest|renderedPageResult|HwpThumbnailCacheEvent|backendUsed|fallbackReason|smoke-thumbnail-skia-policy" \
  Sources/ThumbnailExtension scripts mydocs/report/task_m020_258_report.md \
  mydocs/report/task_m020_396_report.md mydocs/working/task_m020_389_stage1.md
git diff --check
```

### 완료 조건

- provider default가 `.coreGraphicsOnly`인 현재 흐름이 문서화되어 있다.
- cache/backend/fallback 중 현재 provider log에 없는 항목이 구분되어 있다.
- DEBUG/internal resolver contract가 Stage 2 구현 입력으로 확정되어 있다.

### 커밋 메시지

```text
Task #389 Stage 1: Thumbnail provider 진단 경로 inventory
```

## Stage 2. provider policy resolver와 cache logging 구현

### 목표

Thumbnail provider에 DEBUG/internal opt-in policy resolver를 추가하고, provider 성공 로그가 cache/backend/fallback 정보를 포함하게 한다.

### 대상

- `Sources/ThumbnailExtension/HwpThumbnailPolicyResolver.swift` 신규 후보
- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- 필요 시 `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `mydocs/working/task_m020_389_stage2.md`

### 작업

1. `HwpThumbnailPolicyResolver`를 추가한다.
   - `ProcessInfo.processInfo.environment`를 입력으로 받는 resolver
   - Release build 기본값 `.coreGraphicsOnly`
   - DEBUG build에서만 명시 env opt-in 허용
   - policy display identifier helper 제공
2. `HwpThumbnailProvider`가 resolver 결과를 `HwpThumbnailRenderRequest(policy:)`에 전달하게 한다.
3. provider가 `renderedPageResult(for:)`를 사용해 성공 result를 받게 한다.
4. 성공 로그에 다음 항목을 추가한다.
   - resolved policy
   - cache event
   - requested bucket / matched bucket
   - backend used
   - fallback reason
   - render duration / pixel size
5. 실패와 fallback tile 처리 경로는 기존 public behavior를 유지한다.
6. 새 source가 Xcode target과 smoke compile list에 들어가야 하는지 확인한다.

### 검증

```bash
./scripts/check-no-appkit.sh
rg -n "HwpThumbnailPolicyResolver|ALHANGEUL_THUMBNAIL_RENDER_POLICY|renderedPageResult|cache|backend|fallback|coreGraphicsOnly|skiaOptIn" \
  Sources/ThumbnailExtension mydocs/working/task_m020_389_stage2.md
git diff --check
```

가능하면 build 검증:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask389Stage2 CODE_SIGNING_ALLOWED=NO build
```

### 완료 조건

- provider 기본 policy가 CoreGraphics로 유지된다.
- DEBUG/internal env opt-in path가 source상 명확하다.
- provider success log에 cache/backend/fallback 진단 값이 들어간다.
- public reply/fallback 동작 변경이 없다.

### 커밋 메시지

```text
Task #389 Stage 2: Thumbnail provider Skia opt-in 진단 추가
```

## Stage 3. smoke/helper와 resolver 검증 보강

### 목표

smoke helper가 provider resolver contract와 diagnostic output을 검증할 수 있게 보강한다.

### 대상

- `scripts/smoke-thumbnail-skia-policy.sh`
- `scripts/thumbnail_skia_policy_smoke.swift`
- 필요 시 `Sources/ThumbnailExtension/HwpThumbnailPolicyResolver.swift`
- `mydocs/working/task_m020_389_stage3.md`

### 작업

1. smoke helper compile list에 새 resolver source가 필요하면 추가한다.
2. runner가 resolver default와 env opt-in 결과를 확인할 수 있는 진단 값을 summary/detail에 남긴다.
3. 기존 CoreGraphics/Skia policy pair 측정은 유지한다.
4. cache key가 policy/render signature별로 분리되는지 대표 request sequence로 확인한다.
5. fallback reason이 정상 smoke에서는 `-`로 남더라도 column이 유지되는지 확인한다.

### 검증

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-stage3-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
rg -n "coreGraphicsOnly|skiaOptIn|Cache|Backend|Fallback|miss|exactHit|largerBucketHit|ALHANGEUL_THUMBNAIL_RENDER_POLICY" \
  build.noindex/task389-stage3-thumbnail-policy scripts Sources/ThumbnailExtension \
  mydocs/working/task_m020_389_stage3.md
git diff --check
```

### 완료 조건

- smoke helper가 새 resolver source와 함께 compile/run 된다.
- CoreGraphics/Skia opt-in policy pair가 기존처럼 측정된다.
- cache event/backend/fallback column이 후속 보고에 충분히 남는다.

### 커밋 메시지

```text
Task #389 Stage 3: Thumbnail diagnostic smoke 보강
```

## Stage 4. 대표 샘플 smoke와 #392 handoff 정리

### 목표

대표 샘플로 Thumbnail diagnostic smoke를 실행하고, #392 maxDimension mapping 실험에 넘길 baseline 입력을 정리한다.

### 대상

- `build.noindex/task389-thumbnail-policy/`
- `build.noindex/task389-thumbnail-policy-representative/`
- `mydocs/working/task_m020_389_stage4.md`
- 필요 시 `mydocs/tech/skia_quicklook_thumbnail_backend.md`

### 작업

1. 기본 검증 command를 실행한다.
2. 2개 샘플 quick smoke를 실행한다.
3. 대표 샘플 smoke를 실행한다.
4. cache event pattern, backend used, fallback reason, render timing, output bytes를 정리한다.
5. provider default CoreGraphics 유지와 DEBUG/internal Skia opt-in 경로가 문서화되어 있는지 확인한다.
6. #392에 넘길 maxDimension 관련 baseline을 분리한다.

### 검증

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
rg -n "OK|FAIL|coreGraphicsOnly|skiaOptIn|Cache|Backend|Fallback|miss|exactHit|largerBucketHit|RenderMs|OutputBytes" \
  build.noindex/task389-thumbnail-policy build.noindex/task389-thumbnail-policy-representative \
  mydocs/working/task_m020_389_stage4.md
git diff --check
```

### 완료 조건

- 대표 샘플 smoke 결과가 존재한다.
- default provider는 CoreGraphics 유지로 확인된다.
- Skia opt-in diagnostic path가 backend/cache/fallback 정보를 남긴다.
- #392 maxDimension 실험에 필요한 baseline 입력이 정리되어 있다.

### 커밋 메시지

```text
Task #389 Stage 4: Thumbnail diagnostic smoke 검증
```

## Stage 5. 최종 보고와 PR 준비

### 목표

#389 결과를 최종 보고서로 정리하고 PR 게시 준비를 완료한다.

### 대상

- `mydocs/report/task_m020_389_report.md`
- `mydocs/orders/20260701.md`
- 필요 시 `mydocs/working/task_m020_389_stage5.md`

### 작업

1. 최종 보고서에 provider resolver, cache logging, smoke 결과, 후속 관계를 정리한다.
2. 오늘할일 #389 상태를 완료 처리한다.
3. #387, #392, #393, #394와의 관계를 정리한다.
4. PR body 초안을 준비할 수 있도록 stage별 요약과 검증 결과를 정리한다.

### 검증

```bash
rg -n "#389|#387|#392|#393|#394|Thumbnail|Skia|CoreGraphics|cache|fallback|provider|smoke" \
  mydocs/report/task_m020_389_report.md mydocs/orders/20260701.md
git diff --check
git status --short --branch
git log --oneline devel..local/task389
```

### 완료 조건

- 최종 보고서가 존재하고 #389의 diagnostic path와 검증 결과를 설명한다.
- 오늘할일 #389가 완료 상태다.
- PR 게시 준비가 가능하다.

### 커밋 메시지

```text
Task #389 Stage 5 + 최종 보고서: Thumbnail diagnostic path 정리
```
