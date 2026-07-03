# Task M020 #393 Stage 4 보고서

## 단계 목적

대표 샘플에서 CoreGraphics, 기존 Skia decode path, 신규 Skia direct path의 latency/bytes/fallback 결과를 비교하고, #259 Skia readiness gate로 넘길 판단 입력을 정리했다.

이번 단계는 source 변경 없이 Stage 3 구현 결과를 대표 smoke로 재측정하고 문서화했다.

## 산출물

| 파일/산출물 | 내용 |
|------|------|
| `build.noindex/task393-quicklook-policy-representative/summary.txt` | 대표 5개 샘플 Quick Look policy smoke summary |
| `build.noindex/task393-quicklook-policy-representative/resolver-contract.txt` | DEBUG resolver contract 결과 |
| `build.noindex/task393-quicklook-policy-representative/*-quicklook-skia-policy.txt` | 파일별 mode detail |
| `mydocs/working/task_m020_393_stage4.md` | Stage 4 비교 보고서 |
| `mydocs/orders/20260703.md` | #393 상태를 Stage 4 완료 후 승인 대기로 갱신 |

## 검증 명령

기본 검증:

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
```

결과:

- `check-no-appkit.sh`: 성공.
- `verify-rhwp-core-build-info.sh`: 성공.
- `verify-rhwp-studio-assets.sh`: 성공.

대표 smoke:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-quicklook-policy-representative \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
```

결과:

- resolver contract: `OK`.
- 5개 샘플 모두 load/render `OK`.
- 단일 페이지 3개 샘플 모두 `skiaDirect` backend `skia`, fallback 0.
- 다중 페이지 2개 샘플은 `skiaDirect` status `N/A`.
- `복학원서.hwp` 처리 중 기존 layout overflow warning 2줄이 stderr에 출력됐지만 render status는 모두 `OK`.

## Resolver contract

`ALHANGEUL_QUICKLOOK_PNG_REPLY_MODE` DEBUG resolver contract:

| Case | RawValue | Expected | Resolved | Status |
|------|----------|----------|----------|--------|
| missing | `<missing>` | `coreGraphics` | `coreGraphics` | OK |
| empty |  | `coreGraphics` | `coreGraphics` | OK |
| invalid | `banana` | `coreGraphics` | `coreGraphics` | OK |
| `coreGraphics` | `coreGraphics` | `coreGraphics` | `coreGraphics` | OK |
| `coreGraphicsOnly` | `coreGraphicsOnly` | `coreGraphics` | `coreGraphics` | OK |
| `skia` | `skia` | `skiaDecode` | `skiaDecode` | OK |
| `skiaDecode` | `skiaDecode` | `skiaDecode` | `skiaDecode` | OK |
| `skiaOptIn` | `skiaOptIn` | `skiaDecode` | `skiaDecode` | OK |
| `direct` | `direct` | `skiaDirect` | `skiaDirect` | OK |
| `skiaDirect` | `skiaDirect` | `skiaDirect` | `skiaDirect` | OK |

Release에서는 source `#if DEBUG` 경계로 env opt-in이 `coreGraphics`로 수렴한다. 이번 Stage 4에서는 별도 Release smoke를 추가하지 않았다.

## 대표 smoke summary

| File | Reply | Pages | CGBytes | CGSec | SkiaDecodeBytes | SkiaDecodePNGBytes | SkiaDecodeSec | SkiaDirectBytes | SkiaDirectPNGBytes | SkiaDirectSec | DirectPixel | DirectFallback |
|------|------|------:|--------:|------:|----------------:|-------------------:|---------------:|----------------:|-------------------:|--------------:|-------------|----------------|
| `request.hwp` | png | 1 | 90472 | 1.167163 | 84098 | 87027 | 0.062005 | 87027 | 87027 | 0.023481 | 567x794 | 0 |
| `KTX.hwp` | png | 1 | 543472 | 0.073884 | 181314 | 166247 | 0.055980 | 166247 | 166247 | 0.042532 | 1123x794 | 0 |
| `복학원서.hwp` | png | 1 | 223309 | 0.051353 | 196405 | 198675 | 0.063517 | 198675 | 198675 | 0.051415 | 794x1123 | 0 |
| `hwp-multi-001.hwp` | pdf | 9 | 1398731 | 0.443835 | 1102131 | 1297323 | 0.505146 | N/A | N/A | N/A | - | - |
| `hwpx-01.hwpx` | pdf | 9 | 1377385 | 0.412582 | 1093637 | 1314854 | 0.633081 | N/A | N/A | N/A | - | - |

## 단일 페이지 direct 효과

### Latency

| File | CGSec | SkiaDecodeSec | SkiaDirectSec | Direct vs Decode | Direct vs CG |
|------|------:|---------------:|---------------:|------------------|--------------|
| `request.hwp` | 1.167163 | 0.062005 | 0.023481 | 0.038524초 감소, 약 62.1% 단축 | 1.143682초 감소 |
| `KTX.hwp` | 0.073884 | 0.055980 | 0.042532 | 0.013448초 감소, 약 24.0% 단축 | 0.031352초 감소 |
| `복학원서.hwp` | 0.051353 | 0.063517 | 0.051415 | 0.012102초 감소, 약 19.1% 단축 | 거의 동일, direct가 0.000062초 느림 |

해석:

- direct path는 단일 페이지 3개 샘플 모두에서 기존 `skiaDecode`보다 빠르다.
- `request.hwp`, `KTX.hwp`에서는 CoreGraphics보다도 빠르다.
- `복학원서.hwp`는 CoreGraphics와 사실상 같은 수준이며, 로컬 단일 실행값으로 우열을 단정하기 어렵다.

### Bytes

| File | CGBytes | SkiaDecodeBytes | SkiaDirectBytes | 해석 |
|------|--------:|----------------:|----------------:|------|
| `request.hwp` | 90472 | 84098 | 87027 | direct는 Skia 원본 PNG. decode 재인코딩보다 2929 bytes 큼 |
| `KTX.hwp` | 543472 | 181314 | 166247 | direct가 decode 재인코딩보다 15067 bytes 작음 |
| `복학원서.hwp` | 223309 | 196405 | 198675 | direct가 decode 재인코딩보다 2270 bytes 큼 |

해석:

- direct path의 output bytes는 항상 `SkiaDirectPNGBytes`와 같다.
- decode path의 output bytes는 Skia 원본 PNG를 `CGImage`로 decode한 뒤 ImageIO가 다시 encode한 결과라 원본 PNG bytes와 다를 수 있다.
- bytes 차이는 성능과 품질 판단의 보조 신호일 뿐이며 visual correctness를 대체하지 않는다.

## 다중 페이지 경계

다중 페이지 샘플 2개는 `Reply=pdf`이고 `skiaDirect`가 `N/A`로 기록됐다.

| File | Pages | CGSec | SkiaDecodeSec | SkiaDirect |
|------|------:|------:|---------------:|------------|
| `hwp-multi-001.hwp` | 9 | 0.443835 | 0.505146 | N/A |
| `hwpx-01.hwpx` | 9 | 0.412582 | 0.633081 | N/A |

이 결과는 Stage 2 범위인 "direct PNG path는 Quick Look 단일 페이지에만 한정" 조건을 만족한다. 다중 PDF는 여전히 기존 bitmap PDF path이며, Skia decode path는 두 샘플 모두 CoreGraphics보다 느리다.

## #259 readiness 입력

이번 결과가 주는 긍정 신호:

1. Quick Look 단일 페이지에서 direct path가 fallback 없이 성공한다.
2. direct path는 decode/re-encode 비용을 제거해 `skiaDecode`보다 일관되게 빠르다.
3. direct path의 output bytes가 upstream Skia PNG bytes와 같아 data-copy/validation 중심의 단순 경로가 가능하다.
4. 다중 PDF와 Thumbnail surface에는 영향을 주지 않는다.

이번 결과가 해결하지 않는 문제:

1. `KTX.hwp`의 기존 Skia visual regression은 direct PNG로 해결된 것이 아니다. 같은 Skia renderer output을 더 직접 반환할 뿐이다.
2. Skia default 전환 판단은 visual suite와 release readiness gate가 필요하다.
3. direct fallback 강제 fixture는 아직 없다.
4. Release resolver 동작은 source 경계로 보장하지만 별도 Release smoke는 이번 단계에서 추가하지 않았다.

Stage 4 결론:

- `skiaDirect`는 Quick Look 단일 PNG opt-in fast path 후보로 유효하다.
- default 전환 근거로 쓰기에는 부족하다. visual correctness, 특히 `KTX.hwp` Skia regression은 #259/#396 계열 판단으로 남긴다.
- Stage 5에서는 기술 문서에 "Quick Look 단일 PNG direct path는 opt-in fast path로 가능하지만 Skia quality gate를 우회하지 않는다"는 결론을 반영한다.

## 검증 결과

구현계획서 Stage 4 검증:

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-quicklook-policy-representative \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
rg -n "OK|FAIL|coreGraphicsOnly|skiaOptIn|direct|decode|png|pdf|Fallback|Bytes|Seconds|RenderMs" \
  build.noindex/task393-quicklook-policy-representative mydocs/working/task_m020_393_stage4.md
git diff --check
```

결과:

- `check-no-appkit.sh`: 성공.
- `verify-rhwp-core-build-info.sh`: 성공.
- `verify-rhwp-studio-assets.sh`: 성공.
- representative smoke: 성공. resolver contract `OK`, 5개 샘플 모두 `OK`.
- `rg`: smoke output과 Stage 4 문서에서 mode/status/bytes/timing/fallback 항목 확인.
- `git diff --check`: 통과.

## 승인 요청

Stage 4 대표 샘플 비교 측정을 완료했다. Stage 5 `최종 보고와 문서 반영`으로 진행 승인해 달라.
