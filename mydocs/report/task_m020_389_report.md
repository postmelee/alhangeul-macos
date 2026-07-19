# Task #389 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #389 `Thumbnail Skia opt-in diagnostic path와 cache logging 추가` |
| 추적 이슈 | #387 `Preview/Thumbnail Skia readiness 후속 개선 추적` |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 작업 브랜치 | `local/task389` |
| 단계 수 | 5 |

Finder Thumbnail production default는 CoreGraphics로 유지하면서, DEBUG/internal 진단 경로에서 Skia opt-in provider path와 cache/backend/fallback 정보를 관측할 수 있게 했다.

핵심 결과:

- `HwpThumbnailPolicyResolver`를 추가해 `ALHANGEUL_THUMBNAIL_RENDER_POLICY`를 DEBUG/internal 진단 경로에서만 해석한다.
- Release build와 env missing/empty/invalid 값은 모두 `coreGraphicsOnly`로 수렴한다.
- `HwpThumbnailProvider`는 `renderedPageResult(for:)`를 사용해 cache event, requested/matched bucket, backend, fallback, render timing, pixel size를 success log에 남긴다.
- `smoke-thumbnail-skia-policy.sh`는 resolver contract와 policy별 cache signature separation을 summary/detail 산출물에 기록한다.
- 대표 5개 샘플 smoke에서 40 render rows 모두 `OK`, resolver contract `OK`, cache signature separation 5 rows 모두 `OK`였다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/Shared/HwpPageImageRenderer.swift` | `HwpPageRenderPolicy.identifier` 단일 source-of-truth 추가 |
| `Sources/ThumbnailExtension/HwpThumbnailPolicyResolver.swift` | DEBUG/internal thumbnail render policy resolver 추가 |
| `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | resolver policy 전달, `renderedPageResult(for:)` 사용, cache/backend/fallback/timing 로그 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 신규 resolver source를 target에 반영 |
| `scripts/smoke-thumbnail-skia-policy.sh` | resolver source compile list 추가, smoke binary `-DDEBUG` compile |
| `scripts/thumbnail_skia_policy_smoke.swift` | resolver contract detail, Debug/Release 기대값, cache signature separation summary/detail 추가 |
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | #389 기준 DEBUG opt-in provider diagnostic path와 대표 smoke 기준선 기록 |
| `mydocs/tech/skia_preview_renderer_baseline.md` | #389 완료 후 Thumbnail/Finder cache 판단 상태와 #392 잔여 범위 갱신 |
| `mydocs/plans/task_m020_389.md` | 수행계획서 |
| `mydocs/plans/task_m020_389_impl.md` | 단계별 구현계획서 |
| `mydocs/working/task_m020_389_stage1.md` | provider/cache/smoke 진단 경로 inventory |
| `mydocs/working/task_m020_389_stage2.md` | provider policy resolver와 cache logging 구현 보고 |
| `mydocs/working/task_m020_389_stage3.md` | smoke/helper와 resolver 검증 보강 보고 |
| `mydocs/working/task_m020_389_stage4.md` | 대표 샘플 smoke와 #392 handoff 보고 |
| `mydocs/report/task_m020_389_report.md` | 최종 보고서 |
| `mydocs/orders/20260701.md` | #389 완료 처리 |

제품 사용자-facing 설정 UI, Release default, fallback tile shape, extension badge 동작은 변경하지 않았다. `Sources/RhwpCoreBridge`도 변경하지 않았다.

## Resolver contract

`HwpThumbnailPolicyResolver`의 기준:

| 입력 | DEBUG 결과 | Release 결과 |
|------|------------|--------------|
| missing/empty/invalid | `.coreGraphicsOnly` | `.coreGraphicsOnly` |
| `coreGraphics` | `.coreGraphicsOnly` | `.coreGraphicsOnly` |
| `coreGraphicsOnly` | `.coreGraphicsOnly` | `.coreGraphicsOnly` |
| `skia` | `.skiaOptIn` | `.coreGraphicsOnly` |
| `skiaOptIn` | `.skiaOptIn` | `.coreGraphicsOnly` |

값 비교는 trim, lowercase, `-`/`_` 제거 후 수행한다. display identifier는 `coreGraphicsOnly`, `skiaOptIn`이다.

## Provider logging

Provider success log는 다음 진단 값을 포함한다.

| 필드 | 의미 |
|------|------|
| `policy` | provider가 결정한 render policy |
| `cache` | `miss`, `exactHit`, `largerBucketHit(...)` |
| `requestedBucket` | 요청 pixel bucket |
| `matchedBucket` | 실제 cache hit/reuse bucket |
| `backend` | `coreGraphics`, `skia`, `embeddedThumbnail` |
| `fallback` | fallback reason. 없으면 `-` |
| `renderMs` | renderer diagnostic total duration |
| `pixels` | 실제 rendered pixel size |
| `context` | Finder reply context size |
| `page` | page size |

오류와 fallback tile 경로에도 resolved `policy`를 남긴다. public reply/fallback behavior는 기존과 같다.

## Smoke helper 결과

### Stage 3 quick smoke

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-stage3-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

결과:

- resolver contract: `OK`
- render rows: 16개 모두 `OK`
- cache signature separation: 2개 샘플 모두 `OK`
- fallback: 모든 row `-`

### Stage 4 representative smoke

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
```

결과:

| 항목 | 결과 |
|------|------|
| resolver contract | `OK` |
| render rows | 40개 모두 `OK` |
| cache pattern | 각 파일/정책 모두 `miss -> exactHit -> largerBucketHit -> largerBucketHit` |
| cache signature separation | 5개 샘플 모두 `OK` |
| backend | `coreGraphicsOnly`는 `coreGraphics`, `skiaOptIn`은 `skia` |
| fallback | 모든 row `-` |

`복학원서.hwp` smoke 중 기존 `LAYOUT_OVERFLOW` warning 3줄이 stderr에 출력됐다. render status는 모두 `OK`였고 fallback은 발생하지 않았다.

### PR review follow-up smoke

Copilot review 반영 후 실행:

```bash
./scripts/check-no-appkit.sh
git diff --check
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask389ReviewFix CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-review-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

Release 조건은 smoke runner를 `-DDEBUG` 없이 별도 컴파일해 `samples/basic/request.hwp`로 확인했다. 두 번째 Copilot review 반영 후에는 `resolve()` 기본 인자에서 `ProcessInfo.processInfo.environment`를 제거해, Release 호출 경로가 환경변수 딕셔너리를 만들지 않도록 정리했다.

결과:

- `check-no-appkit.sh`, `git diff --check`: 성공.
- `xcodebuild ... DerivedDataTask389ReviewFix ... build`: 성공. macOS build는 `BUILD SUCCEEDED`.
- Debug smoke: resolver contract `OK`, 16 render rows 모두 `OK`.
- Release smoke: `ResolverBuild: RELEASE`, `skia`/`skiaOptIn` env case가 모두 expected/resolved `coreGraphicsOnly`.
- Release provider call: `resolve()` 기본 호출은 `nil` default를 사용하므로 `ProcessInfo.processInfo.environment`를 평가하지 않는다.

## #392 handoff

#392 `Thumbnail Skia maxDimension mapping 실험`에는 다음 기준을 넘긴다.

1. 모든 대표 샘플에서 `1024x1024` bucket cache는 policy별로 정상 분리된다.
2. 같은 bucket에서 Skia pixel size가 CoreGraphics보다 긴 축 기준 1px 큰 패턴이 반복된다.
   - portrait 계열: `725x1024` vs `725x1025`
   - `request.hwp`: `732x1024` vs `732x1025`
   - landscape 계열 `KTX.hwp`: `1024x725` vs `1025x725`
3. fallback은 발생하지 않았으므로, 우선순위는 `maximumPixelSize -> Skia maxDimension/scale/rounding` mapping 확인이다.
4. output bytes와 PNGBytes는 policy별로 차이가 크지만 #389에서는 품질/성능 판정이 아니라 진단 baseline으로만 남긴다.

## 후속 이슈 관계

| 이슈 | 관계 |
|------|------|
| #387 | #389는 Preview/Thumbnail Skia readiness 추적의 Thumbnail 관측성 보강 작업이다 |
| #392 | #389가 cache/backend/fallback 관측성을 확보했고, 1px size drift/maxDimension mapping은 #392에서 실험한다 |
| #393 | Quick Look 단일 페이지 Skia direct PNG opt-in fast path 실험이다. #389의 Thumbnail provider/cache 진단과 별도 surface다 |
| #394 | `build-rust-macos --verify-lock strict` UX/portable verify 운영성 작업이다. #389 smoke나 provider 변경과 직접 결합하지 않는다 |

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| 계획 | `77a7763` | 수행계획서 작성과 오늘할일 갱신 |
| 구현계획 | `291eb75` | 단계별 구현계획서 작성 |
| Stage 1 | `1f1eea6` | Thumbnail provider 진단 경로 inventory |
| Stage 2 | `e7a210f` | provider Skia opt-in resolver와 cache/backend/fallback logging 구현 |
| Stage 3 | `49e9b25` | thumbnail diagnostic smoke resolver/cache separation 보강 |
| Stage 4 | `183fcae` | 대표 샘플 smoke와 #392 handoff 정리 |
| Stage 5 | `6047332` | 최종 보고서와 기술 문서 기준선 정리 |
| PR review follow-up 1 | `31d26f1` | identifier 단일화와 smoke Release 기대값 반영 |
| PR review follow-up 2 | 이번 커밋 | Release `resolve()` 기본 호출의 environment 평가 제거 |

## 검증 결과

실행한 주요 검증:

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask389Stage2 CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task389-review-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

결과:

- `check-no-appkit.sh`: 성공.
- `verify-rhwp-core-build-info.sh`: 성공.
- `verify-rhwp-studio-assets.sh`: 성공.
- `xcodebuild ... ThumbnailExtension ... build`: 성공. macOS build는 `BUILD SUCCEEDED`. Xcode/CoreSimulator version warning은 출력됐지만 build 실패는 아니었다.
- quick smoke: 성공. 16 rows 모두 `OK`.
- representative smoke: 성공. 40 rows 모두 `OK`.
- PR review follow-up Debug smoke: 성공. 16 rows 모두 `OK`.
- PR review follow-up Release smoke: 성공. `skia`/`skiaOptIn` env case 모두 `coreGraphicsOnly`로 resolve.
- `git diff --check`: 각 단계에서 성공.

최종 보고서 검증:

```bash
rg -n "#389|#387|#392|#393|#394|Thumbnail|Skia|CoreGraphics|cache|fallback|provider|smoke" \
  mydocs/report/task_m020_389_report.md mydocs/orders/20260701.md
git diff --check
git status --short --branch
git log --oneline devel..local/task389
```

## 잔여 위험

| 항목 | 상태 | 처리 |
|------|------|------|
| Release env opt-in 차단 | source `#if DEBUG`, `nil` default, Release smoke로 확인 | 계속 유지 |
| forced fallback reason fixture | 없음 | 정상 샘플에서는 fallback `-`; forced failure fixture는 필요 시 별도 작업 |
| Finder/LaunchServices system cache | 범위 밖 | 이번 smoke는 extension 내부 render cache contract 검증 |
| 1px pixel size drift | 관측됨 | #392 maxDimension mapping 실험으로 이관 |
| Skia visual default 판단 | 범위 밖 | #396 visual suite, #392, #393 등 후속 입력과 함께 판단 |

## PR 게시 메모

권장 PR 제목:

```text
Task #389: Thumbnail Skia opt-in diagnostic path와 cache logging 추가
```

권장 리뷰 포인트:

- Release/production default가 계속 CoreGraphics인지
- `ALHANGEUL_THUMBNAIL_RENDER_POLICY`가 DEBUG/internal diagnostic 경로에 한정되는지
- provider success log가 cache/backend/fallback/timing을 충분히 남기는지
- smoke helper가 resolver contract와 policy별 cache signature separation을 과도한 product coupling 없이 검증하는지
- #392로 넘긴 1px pixel size drift가 #389 범위에 섞이지 않았는지

## PR review follow-up

PR #401 Copilot review의 identifier 중복, Release resolver 기대값, Release `resolve()` 기본 호출 environment 평가 피드백은 follow-up 커밋에서 반영했다.
