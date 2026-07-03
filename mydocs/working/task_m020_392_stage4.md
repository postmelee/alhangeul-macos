# Task #392 Stage 4 보고서: Thumbnail maxDimension 대표 샘플 검증

## 단계 목적

- 대표 샘플에서 Thumbnail Skia maxDimension 정책 적용 후 pixel size, latency, bytes, cache pattern, signature를 측정한다.
- #389 Stage 4 scale-only 대표 smoke와 비교해 1px drift가 해소/유지/변형되는지 분류한다.
- Stage 5 최종 보고서에 넘길 판단 근거와 잔여 risk를 정리한다.

## 실행 명령

기본 검증:

```sh
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
```

대표 샘플 smoke:

```sh
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
```

결과:

- `check-no-appkit`: 성공
- `verify-rhwp-core-build-info`: 성공
- `verify-rhwp-studio-assets`: 성공
- representative smoke: 성공
- resolver contract: `OK`
- render rows: 40건 모두 `OK`
- fallback: 0건
- `복학원서.hwp` 처리 중 기존 `LAYOUT_OVERFLOW` warning 3줄이 stderr에 출력됐지만 render status는 모두 `OK`였다.

## 대표 샘플 결과

아래 표는 각 샘플의 첫 요청인 `large:512x512@2` 기준이다. 요청 bucket은 모두 `1024x1024`이고, 이후 반복 요청은 각 정책별로 `exactHit`, `largerBucketHit(1024x1024)`, `largerBucketHit(1024x1024)` 패턴을 유지했다.

| File | Policy | Backend | Pixel | OutputBytes | PNGBytes | RenderMs |
| --- | --- | --- | --- | ---: | ---: | ---: |
| `복학원서.hwp` | `coreGraphicsOnly` | `coreGraphics` | `725x1024` | 193700 | - | 1628.596 |
| `복학원서.hwp` | `skiaOptIn` | `skia` | `725x1024` | 171213 | 175952 | 168.842 |
| `KTX.hwp` | `coreGraphicsOnly` | `coreGraphics` | `1024x725` | 482670 | - | 58.054 |
| `KTX.hwp` | `skiaOptIn` | `skia` | `1024x725` | 161545 | 148988 | 70.815 |
| `request.hwp` | `coreGraphicsOnly` | `coreGraphics` | `732x1024` | 125618 | - | 38.439 |
| `request.hwp` | `skiaOptIn` | `skia` | `567x794` | 84098 | 87027 | 66.309 |
| `hwpx-01.hwpx` | `coreGraphicsOnly` | `coreGraphics` | `725x1024` | 198763 | - | 40.292 |
| `hwpx-01.hwpx` | `skiaOptIn` | `skia` | `725x1024` | 170807 | 187583 | 47.671 |
| `hwp-multi-001.hwp` | `coreGraphicsOnly` | `coreGraphics` | `725x1024` | 195545 | - | 36.335 |
| `hwp-multi-001.hwp` | `skiaOptIn` | `skia` | `725x1024` | 166500 | 180476 | 44.396 |

## #389 scale-only baseline 대비 drift 분류

비교 기준은 `mydocs/working/task_m020_389_stage4.md`의 대표 smoke 표다.

| File | #389 Skia scale-only Pixel | #392 Skia maxDimension Pixel | 분류 | 해석 |
| --- | --- | --- | --- | --- |
| `복학원서.hwp` | `725x1025` | `725x1024` | 해소 | portrait 계열 1px 초과가 사라지고 CoreGraphics와 같은 긴 변이 됐다. |
| `KTX.hwp` | `1025x725` | `1024x725` | 해소 | landscape 계열 1px 초과가 사라지고 CoreGraphics와 같은 긴 변이 됐다. |
| `request.hwp` | `732x1025` | `567x794` | 변형 | 1024px 초과는 없어졌지만, Skia가 자연 해상도 이상으로 확대하지 않아 CoreGraphics보다 작은 bitmap이 됐다. |
| `hwpx-01.hwpx` | `725x1025` | `725x1024` | 해소 | HWPX path에서도 1px 초과가 사라졌다. |
| `hwp-multi-001.hwp` | `725x1025` | `725x1024` | 해소 | 다중 페이지 HWP 첫 페이지 thumbnail에서도 1px 초과가 사라졌다. |

정리하면 대표 샘플 5개 중 4개는 maxDimension 정책으로 1px drift가 해소됐다. `request.hwp`는 drift가 단순 해소된 것이 아니라 Skia output 자체가 `567x794`로 낮아지는 다른 형태의 변화가 발생했다.

## cache와 signature

- 모든 샘플에서 policy별 첫 요청은 `miss`였고, 같은 policy 안의 반복/작은 요청은 `exactHit` 또는 `largerBucketHit(1024x1024)`로 재사용됐다.
- `coreGraphicsOnly`와 `skiaOptIn`의 첫 요청이 서로 cache hit로 섞이지 않았다.
- signature suffix는 두 policy 모두 `skia-max-dimension-thumbnail-v1`을 포함하고, backend policy가 `coreGraphicsOnly`/`skiaOptIn`으로 분리된다.

## 해석

- maxDimension 매핑은 기존 1px 초과 drift를 통제하는 데 효과가 있다. `복학원서.hwp`, `KTX.hwp`, `hwpx-01.hwpx`, `hwp-multi-001.hwp`에서는 Skia 긴 변이 1024를 넘지 않고 CoreGraphics와 같은 pixel size가 됐다.
- `request.hwp`는 maxDimension 경로에서 upstream Skia가 확대를 수행하지 않는 것으로 보인다. 이 샘플은 `scale-only -> 732x1025`, `maxDimension -> 567x794`로 바뀌므로, maxDimension 정책을 그대로 제품 기본으로 올리면 일부 문서 thumbnail이 기대보다 작아질 수 있다.
- OutputBytes와 PNGBytes는 `request.hwp`에서 크게 줄었다. 이는 압축 효율 개선이라기보다 pixel count 감소의 영향으로 보는 편이 타당하다.
- RenderMs는 단일 로컬 실행값이므로 절대값으로 회귀를 판단하지 않는다. 다만 `복학원서.hwp` Skia RenderMs가 #389의 73.027ms에서 168.842ms로 증가했으므로 Stage 5에서는 성능 결론을 보수적으로 기록해야 한다.

## Stage 5 입력

- 적용 결과: maxDimension 정책은 1px drift 방지에는 유효하다.
- 보류 판단: `request.hwp`처럼 Skia가 자연 해상도 이상 확대하지 않는 문서가 있어, default 전환 근거로는 아직 부족하다.
- 후속 후보: #393/#259 쪽에서는 maxDimension 단독 정책 대신 `maxDimension + explicit upscale 필요성`, 또는 sample별 visual readiness gate를 함께 판단해야 한다.
- 문서 반영: `skia_quicklook_thumbnail_backend.md`에는 Thumbnail Skia opt-in이 maxDimension을 사용하지만 일부 샘플에서 underfill risk가 있다는 점을 명시해야 한다.

## 승인 요청

Stage 5에서는 최종 보고서와 기술 문서에 이번 결과를 반영하고, 오늘할일 완료 처리와 PR 게시 준비로 넘어간다.
