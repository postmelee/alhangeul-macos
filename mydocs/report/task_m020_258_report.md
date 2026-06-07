# Task M020 #258 최종 결과 보고서

## 작업 요약

| 항목 | 내용 |
| --- | --- |
| 이슈 | [#258 Thumbnail renderer signature/cache diagnostic 설계와 Skia opt-in smoke](https://github.com/postmelee/alhangeul-macos/issues/258) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task258` |
| 대상 surface | Finder Thumbnail extension |
| core provenance | `rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642`, `native-skia` |
| 단계 수 | 5단계 |

목표는 Finder Thumbnail 기본 renderer를 CoreGraphics로 유지하면서, backend/render option 변경 뒤 stale thumbnail을 재사용하지 않도록 cache signature를 도입하고, Skia opt-in thumbnail smoke에서 backend/fallback/latency/cache event를 반복 측정할 수 있게 하는 것이었다.

결론:

- `HwpThumbnailRenderCache` key와 in-flight/reuse 조건에 render signature를 반영했다.
- Finder Thumbnail provider 기본 policy는 `.coreGraphicsOnly` 그대로 유지했다.
- 같은 signature 안에서는 큰 pixel bucket 재사용을 유지하고, signature가 다르면 cache exact hit, in-flight join, larger bucket reuse가 분리된다.
- Thumbnail 전용 smoke helper를 추가해 `.coreGraphicsOnly`와 `.skiaOptIn`을 같은 파일/요청 bucket에서 비교 측정할 수 있게 했다.
- 대표 5개 샘플 smoke에서 40 rows 모두 `OK`, fallback 0, 각 파일/정책 cache event가 `miss -> exactHit -> largerBucketHit -> largerBucketHit`로 확인됐다.
- Quick Look 단일 PNG, Quick Look 다중 PDF, Finder Thumbnail rollout gate는 분리해서 판단하는 기준으로 정리했다.
- `PageLayerTree displayText`는 Swift/CoreGraphics mapping을 계속 늘리는 방식보다 PageLayerTree/Skia 소비 경로로 검증하는 것이 장기 방향이라고 문서화했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
| --- | --- |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | `HwpThumbnailRenderSignature`, signature-aware cache key/reuse, cache event/result diagnostics 추가 |
| `scripts/smoke-thumbnail-skia-policy.sh` | Thumbnail Skia policy smoke wrapper 추가 |
| `scripts/thumbnail_skia_policy_smoke.swift` | CoreGraphics/Skia opt-in thumbnail 정책, request bucket, cache event 측정 runner 추가 |
| `mydocs/plans/task_m020_258.md` | 수행계획서 추가 |
| `mydocs/plans/task_m020_258_impl.md` | 단계별 구현계획서 추가 |
| `mydocs/working/task_m020_258_stage1.md` | cache/provider/renderer contract inventory 보고 |
| `mydocs/working/task_m020_258_stage2.md` | source 변경과 cache signature contract 보고 |
| `mydocs/working/task_m020_258_stage3.md` | smoke helper 추가와 2개 샘플 smoke 보고 |
| `mydocs/working/task_m020_258_stage4.md` | 대표 5개 샘플 smoke와 장기 gate 보고 |
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | #258 반복 smoke gate와 `PageLayerTree displayText` 장기 판단 추가 |
| `mydocs/orders/20260603.md` | 오늘할일 등록과 완료 처리 |

전체 diff 규모:

| 항목 | 값 |
| --- | ---: |
| 변경 파일 | 11 |
| insertions | 1,588 |
| deletions | 13 |

## Source contract

`HwpThumbnailRenderSignature`는 다음 입력을 포함한다.

| 항목 | 값 |
| --- | --- |
| backend policy | `coreGraphicsOnly` 또는 `skiaOptIn` |
| renderer option version | `thumbnail-renderer-v1` |
| core release tag | `v0.7.13` |
| core commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| core enabled features | `native-skia` |
| max-dimension policy version | `skia-max-dimension-0` |

적용 위치:

- memory cache key
- in-flight render coalescing key
- render 성공 후 store key
- larger bucket reuse guard

Provider가 만드는 `HwpThumbnailRenderRequest`는 여전히 기본 `.coreGraphicsOnly`다. Skia는 smoke/helper 또는 명시 opt-in request에서만 선택된다.

## Smoke 결과

Stage 3 기본 smoke:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

결과:

| File | Policy | large miss | exact hit | larger bucket hit | Backend | Fallback |
| --- | --- | ---: | ---: | ---: | --- | ---: |
| `request.hwp` | `coreGraphicsOnly` | 1 | 1 | 2 | `coreGraphics` | 0 |
| `request.hwp` | `skiaOptIn` | 1 | 1 | 2 | `skia` | 0 |
| `KTX.hwp` | `coreGraphicsOnly` | 1 | 1 | 2 | `coreGraphics` | 0 |
| `KTX.hwp` | `skiaOptIn` | 1 | 1 | 2 | `skia` | 0 |

Stage 4 대표 smoke:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
```

전체 결과:

| 항목 | 결과 |
| --- | --- |
| row 수 | 5 files x 2 policies x 4 requests = 40 |
| 실패 row | 0 |
| fallback | 0 |
| cache event 패턴 | 각 파일/정책에서 `miss -> exactHit -> largerBucketHit(1024x1024) -> largerBucketHit(1024x1024)` |
| Skia opt-in backend | 모든 opt-in row `skia` |
| CoreGraphics backend | 모든 CoreGraphics row `coreGraphics` |

대표 수치:

| File | CoreGraphics first render ms | CoreGraphics output bytes | Skia first render ms | Skia output bytes | Skia PNG bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| `복학원서.hwp` | 1117.887 | 193700 | 57.548 | 155048 | 150336 |
| `KTX.hwp` | 55.776 | 484340 | 57.876 | 164259 | 151997 |
| `request.hwp` | 26.741 | 126597 | 61.184 | 120977 | 121702 |
| `hwpx-01.hwpx` | 32.436 | 198454 | 60.173 | 171054 | 187773 |
| `hwp-multi-001.hwp` | 28.042 | 196066 | 57.656 | 165485 | 178958 |

Smoke stdout에는 일부 `LAYOUT_OVERFLOW` 진단 로그가 있었지만 helper 실패는 없었다. 이 로그는 Stage 4 cache/signature 실패로 보지 않고, visual parity 판단은 #259 readiness 범위로 둔다.

## 단계별 결과

| Stage | 커밋 | 결과 |
| --- | --- | --- |
| 계획 | `0223a6e`, `0392ae1` | 수행계획서, 구현계획서, 오늘할일 등록 |
| Stage 1 | `a754400` | Thumbnail cache/provider와 Shared renderer contract 조사 |
| Stage 2 | `bf88b87` | render signature와 signature-aware cache reuse source 반영 |
| Stage 3 | `913c699` | Thumbnail Skia opt-in smoke helper 추가 |
| Stage 4 | `ffd6a02` | 대표 샘플 smoke와 장기 gate 정리 |
| Stage 5 | 현재 | 최종 보고서와 오늘할일 완료 처리, PR 준비 |

## 검증 결과

최종 단계에서 재실행한 검증:

| 검증 | 결과 |
| --- | --- |
| `./scripts/check-no-appkit.sh` | 통과 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask258 CODE_SIGNING_ALLOWED=NO build` | 통과: sandbox 밖 재실행에서 `** BUILD SUCCEEDED **` |
| `./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-final-thumbnail-policy samples/복학원서.hwp samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx` | 통과, 3 files x 2 policies x 4 requests = 24 rows 모두 `OK`, fallback 0 |
| `rg -n "#258\|Thumbnail\|CoreGraphics\|skiaOptIn\|cache\|signature\|fallback\|latency\|hit\|miss\|PageLayerTree" mydocs/report/task_m020_258_report.md mydocs/orders/20260603.md Sources/ThumbnailExtension scripts` | 통과 |
| `git diff --check` | 통과 |
| `git status --short --branch` | 통과, 최종 보고서와 오늘할일 완료 처리 변경만 확인 |

Sandbox 제약:

- `xcodebuild`는 sandbox 내부에서 Swift/clang module cache와 SwiftPM diagnostics 파일 쓰기 제한으로 실패했다.
- 같은 명령을 권한 허용 상태로 재실행했고 build가 통과했다.

Stage 2-4에서 실행한 주요 검증:

```bash
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask258 CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy \
  samples/basic/request.hwp samples/basic/KTX.hwp
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
git diff --check
```

## 수용 기준 대응

| 수용 기준 | 결과 | 근거 |
| --- | --- | --- |
| Finder Thumbnail 기본 경로 CoreGraphics 유지 | OK | Provider request 기본값과 `HwpThumbnailRenderRequest` 기본 policy가 `.coreGraphicsOnly` |
| cache key가 render signature 반영 | OK | `HwpThumbnailCacheKey.renderSignature` 추가 |
| backend/render option 변경 시 stale thumbnail 재사용 방지 | OK | exact key, in-flight key, larger bucket reuse 모두 signature equality 사용 |
| 같은 signature 안의 큰 bucket 재사용 유지 | OK | `largerBucketHit(1024x1024)` smoke로 확인 |
| Skia opt-in backend/fallback/latency/cache event 측정 | OK | `thumbnail_skia_policy_smoke.swift` summary/detail 기록 |
| 대표 샘플 smoke 결과 기록 | OK | Stage 4 대표 5개 샘플, 40 rows OK, fallback 0 |
| Quick Look/Thumbnail gate 분리 판단 기록 | OK | 기술 문서와 Stage 4 보고서에 분리 기준 추가 |
| `PageLayerTree displayText` 장기 판단 기록 | OK | 기술 문서와 Stage 4 보고서에 Swift mapping 확장보다 PageLayerTree 소비가 장기 방향임을 기록 |

## 잔여 위험과 후속 작업

| 항목 | 내용 |
| --- | --- |
| `Skia first` 전환 | 이번 작업은 default 전환 근거가 아니라 opt-in diagnostic 기반이다. 기본 전환 여부는 #259 visual/performance/package readiness에서 판단한다. |
| visual parity | Thumbnail smoke는 render 성공과 cache event 검증이다. Skia/CoreGraphics/reference visual diff와 page 구조 누락 여부는 #259 범위다. |
| forced fallback fixture | 대표 smoke에서는 Skia fallback이 발생하지 않았다. fallback 강제 fixture 또는 오류 주입은 별도 follow-up 후보다. |
| provenance constant drift | signature source constant가 `rhwp-core.lock`과 어긋날 수 있다. core update 시 signature constant 갱신 또는 generated provenance constant 후속이 필요하다. |
| Finder system cache | helper는 extension 내부 cache contract 검증이다. Finder/LaunchServices 시스템 cache와 설치본 smoke는 이번 task 범위 밖이다. |
| pixel rounding | Skia opt-in 결과에서 긴 변이 CoreGraphics보다 1px 큰 row가 있다. Stage 4 cache 실패는 아니지만 #259 visual gate 입력으로 남긴다. |

## Handoff

- #259는 이 결과를 Thumbnail surface의 opt-in diagnostic 입력으로 사용한다.
- PR 리뷰에서는 `HwpThumbnailRenderCache`의 signature-aware key/reuse 조건과 smoke helper output 해석을 우선 확인하면 된다.
- Stage 4 대표 smoke 산출물은 `build.noindex/task258-thumbnail-policy-representative/summary.txt`에 있다.
- 최종 smoke 산출물은 `build.noindex/task258-final-thumbnail-policy/summary.txt`에 남긴다.

## 작업지시자 승인 요청

최종 보고서 작성과 오늘할일 완료 처리를 승인하면 `publish/task258` 원격 브랜치를 만들고 `devel` 대상 Open PR 게시 단계로 진행한다. PR merge 후에는 `pr-merge-cleanup` 절차로 이슈 close와 브랜치/worktree 정리를 진행한다.
