# Task #392 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #392 `Thumbnail Skia maxDimension mapping 실험` |
| 추적 이슈 | #387 `Preview/Thumbnail Skia readiness 후속 개선 추적` |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 작업 브랜치 | `local/task392` |
| 단계 수 | 5 |

Finder Thumbnail production default는 `coreGraphicsOnly`로 유지하면서, DEBUG/internal `skiaOptIn` 진단 경로에서 `maximumPixelSize`를 upstream Skia PNG export의 `maxDimension`으로 매핑하는 실험을 완료했다.

핵심 결과:

- Thumbnail Skia opt-in path에서 `maximumPixelSize`의 긴 변을 `PngExportOptions.max_dimension`으로 전달한다.
- `maxDimension > 0`일 때는 upstream 자동 scale 계산을 사용하도록 `scale: 0`으로 호출한다.
- Thumbnail render signature suffix를 `skia-max-dimension-thumbnail-v1`로 갱신해 기존 scale-only cache와 분리했다.
- 대표 5개 샘플 smoke에서 40 render rows 모두 `OK`, resolver contract `OK`, fallback 0건이었다.
- #389에서 관찰한 1px 초과 drift는 5개 중 4개 샘플에서 해소됐다.
- `request.hwp`는 Skia output이 `567x794`로 낮아지는 underfill risk가 확인되어, maxDimension 단독 정책은 아직 default 전환 근거로 부족하다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/Shared/HwpPageImageRenderer.swift` | Skia render attempt에 `maxDimension` 전달, `maxDimension > 0`이면 Rust bridge 호출 시 `scale: 0` 사용, 안전한 `skiaMaxDimension(from:)` helper 추가 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | `maxDimensionPolicyVersion`을 `skia-max-dimension-thumbnail-v1`로 갱신 |
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | #392 maxDimension 대표 smoke 결과와 underfill risk 반영 |
| `mydocs/tech/skia_preview_renderer_baseline.md` | Thumbnail/Finder 판단 상태를 #392 결과 기준으로 갱신 |
| `mydocs/plans/task_m020_392.md` | 수행계획서 |
| `mydocs/plans/task_m020_392_impl.md` | 단계별 구현계획서 |
| `mydocs/working/task_m020_392_stage1.md` | scale-only baseline inventory |
| `mydocs/working/task_m020_392_stage2.md` | maxDimension mapping 설계 |
| `mydocs/working/task_m020_392_stage3.md` | opt-in 구현과 quick smoke 결과 |
| `mydocs/working/task_m020_392_stage4.md` | 대표 샘플 smoke와 drift 분류 |
| `mydocs/report/task_m020_392_report.md` | 최종 보고서 |
| `mydocs/orders/20260703.md` | #392 완료 처리 |

Quick Look direct PNG path, Release default, 사용자-facing 설정 UI, upstream `rhwp` 코드는 변경하지 않았다.

## 구현 계약

Stage 2에서 확인한 upstream/bridge 계약은 다음과 같다.

- RustBridge `rhwp_render_page_png`는 `scale == 0`을 `None`, `max_dimension == 0`을 `None`으로 변환한다.
- upstream `PngExportOptions`는 명시 `scale`을 `max_dimension` 자동 scale보다 우선한다.
- Skia raster renderer는 최종 scaled dimension이 `max_dimension`을 넘으면 error를 낼 수 있다.

따라서 이번 구현은 `maxDimension > 0`인 Thumbnail 요청에서 explicit scale을 함께 넘기지 않는다.

적용 계약:

| 조건 | Skia 호출 |
|------|-----------|
| `maximumPixelSize`가 nil/invalid/0 이하 | `scale: Double(scale)`, `maxDimension: 0` |
| `maximumPixelSize`의 긴 변이 유효 | `scale: 0`, `maxDimension: ceil(longestEdge)` |

`skiaMaxDimension(from:)` helper는 non-finite 값과 0 이하 값을 `0`으로 처리하고, 유효한 값은 `Int32.max`로 상한 처리한다.

## Smoke 결과

### Stage 1 scale-only baseline

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage1-scale-only \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

| sample | policy | pixel | signature suffix |
|------|------|------|------|
| `request.hwp` | `coreGraphicsOnly` | `732x1024` | `skia-max-dimension-0` |
| `request.hwp` | `skiaOptIn` | `732x1025` | `skia-max-dimension-0` |
| `KTX.hwp` | `coreGraphicsOnly` | `1024x725` | `skia-max-dimension-0` |
| `KTX.hwp` | `skiaOptIn` | `1025x725` | `skia-max-dimension-0` |

### Stage 3 quick smoke

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage3-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

결과:

- resolver contract: `OK`
- render rows: 16건 모두 `OK`
- fallback: 0건
- cache pattern: 각 정책에서 `miss -> exactHit -> largerBucketHit(1024x1024) -> largerBucketHit(1024x1024)`
- signature suffix: `skia-max-dimension-thumbnail-v1`

| sample | policy | Stage 1 Pixel | Stage 3 Pixel | 해석 |
|------|------|------|------|------|
| `request.hwp` | `skiaOptIn` | `732x1025` | `567x794` | 1024px 초과는 사라졌지만 underfill risk 발생 |
| `KTX.hwp` | `skiaOptIn` | `1025x725` | `1024x725` | 1px 초과 해소 |

### Stage 4 representative smoke

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
```

결과:

| 항목 | 결과 |
|------|------|
| resolver contract | `OK` |
| render rows | 40건 모두 `OK` |
| cache pattern | 각 파일/정책 모두 `miss -> exactHit -> largerBucketHit -> largerBucketHit` |
| cache signature separation | 5개 샘플 모두 `OK` |
| backend | `coreGraphicsOnly`는 `coreGraphics`, `skiaOptIn`은 `skia` |
| fallback | 모든 row `-` |

`복학원서.hwp` 처리 중 기존 `LAYOUT_OVERFLOW` warning 3줄이 stderr에 출력됐지만 render status는 모두 `OK`였고 fallback은 발생하지 않았다.

## Drift 분류

비교 기준은 #389 Stage 4 scale-only 대표 smoke다.

| File | #389 Skia scale-only Pixel | #392 Skia maxDimension Pixel | 분류 |
|------|------|------|------|
| `복학원서.hwp` | `725x1025` | `725x1024` | 해소 |
| `KTX.hwp` | `1025x725` | `1024x725` | 해소 |
| `request.hwp` | `732x1025` | `567x794` | 변형 |
| `hwpx-01.hwpx` | `725x1025` | `725x1024` | 해소 |
| `hwp-multi-001.hwp` | `725x1025` | `725x1024` | 해소 |

정리하면 maxDimension 매핑은 1px 초과 drift를 통제하는 데 효과가 있다. 하지만 `request.hwp`처럼 upstream Skia가 자연 해상도 이상 확대하지 않는 문서가 있어, maxDimension 정책을 그대로 Skia default 전환 근거로 삼기는 어렵다.

## 후속 이슈 관계

| 이슈 | 관계 |
|------|------|
| #387 | #392는 Preview/Thumbnail Skia readiness 추적 중 Thumbnail size drift 실험이다 |
| #389 | #389가 provider diagnostic path와 cache signature separation을 확보했고, #392는 그 결과로 드러난 1px drift를 실험했다 |
| #393 | Quick Look 단일 페이지 Skia direct PNG opt-in fast path 실험이다. #392의 Thumbnail maxDimension underfill risk와 별도 surface로 판단한다 |
| #259 | Skia default/release readiness gate다. #392 결과는 1px drift 해소 신호와 `request.hwp` underfill risk를 함께 입력으로 넘긴다 |

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| 계획 | `b7b2d83` | 수행계획서 작성과 오늘할일 갱신 |
| 구현계획 | `3be144d` | 단계별 구현계획서 작성 |
| Stage 1 | `7b83628` | scale-only baseline inventory |
| Stage 2 | `2546390` | maxDimension mapping 설계 |
| Stage 3 | `e775299` | Thumbnail Skia maxDimension opt-in 적용 |
| Stage 4 | `6a845ef` | 대표 샘플 smoke와 drift 분류 |
| Stage 5 | 이번 커밋 | 최종 보고서와 기술 문서 반영 |

## 검증 결과

실행한 주요 검증:

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage1-scale-only \
  samples/basic/request.hwp samples/basic/KTX.hwp
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage3-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask392Stage3 CODE_SIGNING_ALLOWED=NO build
```

결과:

- `check-no-appkit.sh`: 성공.
- `verify-rhwp-core-build-info.sh`: 성공.
- `verify-rhwp-studio-assets.sh`: 성공.
- Stage 1 quick smoke: 성공. 16 rows 모두 `OK`.
- Stage 3 quick smoke: 성공. 16 rows 모두 `OK`.
- Stage 4 representative smoke: 성공. 40 rows 모두 `OK`.
- `xcodebuild ... ThumbnailExtension ... build`: 성공. macOS build는 `BUILD SUCCEEDED`. Xcode/CoreSimulator version warning은 출력됐지만 build 실패는 아니었다.
- `git diff --check`: 각 단계에서 성공.

최종 보고서 검증:

```bash
rg -n "#392|#387|#389|#393|#259|maxDimension|maximumPixelSize|Thumbnail|Skia|CoreGraphics|cache|signature|smoke" \
  mydocs/report/task_m020_392_report.md mydocs/orders/20260703.md \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/tech/skia_preview_renderer_baseline.md
git diff --check
git status --short --branch
git log --oneline devel..local/task392
```

## 잔여 위험

| 항목 | 상태 | 처리 |
|------|------|------|
| `request.hwp` underfill | maxDimension path에서 `567x794`로 낮아짐 | #259 visual/thumbnail readiness에서 default 전환 blocker 후보로 유지 |
| latency 절대값 | 단일 로컬 실행값이라 변동 가능 | 대표 smoke의 상대 신호로만 해석 |
| CoreGraphics cache invalidation | signature suffix가 공통 필드라 CoreGraphics thumbnail cache도 함께 갱신 | stale cache 방지 우선. 필요 시 per-policy option signature 분리 |
| visual 품질 | 이번 작업은 pixel/cache smoke 중심 | #396 visual suite와 #259 readiness gate에서 종합 |

## PR 게시 메모

권장 PR 제목:

```text
Task #392: Thumbnail Skia maxDimension mapping 실험
```

권장 리뷰 포인트:

- Release/production default가 계속 `coreGraphicsOnly`인지
- `maxDimension > 0`일 때 explicit `scale`을 넘기지 않는 계약이 upstream 우선순위와 맞는지
- `skia-max-dimension-thumbnail-v1` signature 갱신이 기존 cache 혼입을 막는지
- 대표 샘플 5개 중 4개에서 1px drift가 해소된 점과 `request.hwp` underfill risk를 균형 있게 해석했는지
- #259 default readiness로 넘길 blocker 후보가 문서화되어 있는지
