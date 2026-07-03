# Task M020 #393 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #393 `Quick Look 단일 페이지 Skia direct PNG opt-in fast path 실험` |
| 추적 이슈 | #387 `Preview/Thumbnail Skia readiness 후속 개선 추적` |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 작업 브랜치 | `local/task393` |
| 단계 수 | 5 |

Quick Look 단일 페이지 PNG reply에서 Skia PNG bytes를 Swift `CGImage`로 decode한 뒤 다시 PNG로 encode하던 진단 경로와 별도로, DEBUG/internal opt-in `skiaDirect` reply mode를 추가했다. Production/default는 계속 CoreGraphics PNG reply다.

핵심 결과:

- `ALHANGEUL_QUICKLOOK_PNG_REPLY_MODE` DEBUG resolver를 추가했다. missing/empty/invalid 값과 Release build는 `coreGraphics`로 수렴한다.
- `skiaDirect`는 Quick Look 단일 페이지에서 `RhwpDocument.renderPagePNG(at: 0, scale: 1, maxDimension: 0)` 결과 PNG bytes를 header/IHDR 검증 후 그대로 반환한다.
- direct 실패 시 Quick Look text fallback으로 가지 않고 CoreGraphics PNG reply shape으로 fallback한다.
- 대표 5개 샘플 smoke에서 단일 페이지 3개 샘플 모두 direct fallback 0건, 다중 페이지 2개 샘플은 의도대로 `skiaDirect=N/A`였다.
- 단일 페이지 3개 샘플에서 `skiaDirect`는 기존 `skiaDecode`보다 빨랐다.
- `KTX.hwp` Skia visual regression은 해결되지 않았다. direct path는 같은 Skia output을 더 직접 반환하는 fast path일 뿐, Skia quality gate를 우회하지 않는다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/Shared/HwpPreviewPNGRenderer.swift` | Quick Look PNG reply helper, `coreGraphics`/`skiaDecode`/`skiaDirect` mode, PNG header/IHDR validation, timing diagnostics 추가 |
| `Sources/QLExtension/HwpQuickLookPNGReplyModeResolver.swift` | DEBUG/internal `ALHANGEUL_QUICKLOOK_PNG_REPLY_MODE` resolver 추가 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | 단일 페이지 PNG reply에서 resolver와 `HwpPreviewPNGRenderer` 사용. 다중 PDF path는 유지 |
| `scripts/smoke-quicklook-skia-policy.sh` | smoke compile list에 신규 helper/resolver 추가, DEBUG resolver contract 검증 |
| `scripts/quicklook_skia_policy_smoke.swift` | `coreGraphics`, `skiaDecode`, `skiaDirect` 측정과 resolver contract summary/detail 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 신규 Swift source 반영 |
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | #393 direct PNG opt-in 결과와 default blocker 반영 |
| `mydocs/tech/skia_preview_renderer_baseline.md` | #393 결과를 visual suite를 대체하지 않는 성능 입력으로 연결 |
| `mydocs/plans/task_m020_393.md` | 수행계획서 |
| `mydocs/plans/task_m020_393_impl.md` | 단계별 구현계획서 |
| `mydocs/working/task_m020_393_stage1.md` | 현행 PNG reply inventory |
| `mydocs/working/task_m020_393_stage2.md` | direct PNG reply contract 설계 |
| `mydocs/working/task_m020_393_stage3.md` | opt-in direct PNG 구현과 smoke 보강 |
| `mydocs/working/task_m020_393_stage4.md` | 대표 샘플 비교 측정 |
| `mydocs/working/task_m020_393_stage5.md` | Stage 5 완료 보고 |
| `mydocs/report/task_m020_393_report.md` | 최종 보고서 |
| `mydocs/orders/20260703.md` | #393 완료 처리 |

Thumbnail, Quick Look 다중 페이지 PDF direct path, Skia default 전환, user-facing preference, upstream `rhwp`, `Rhwp.xcframework`는 변경하지 않았다.

## 구현 계약

`HwpPreviewPNGReplyMode`:

| mode | 동작 | output |
|------|------|--------|
| `coreGraphics` | `HwpPageImageRenderer.renderPage(... .coreGraphicsOnly)` 후 PNG encode | CoreGraphics encoded PNG |
| `skiaDecode` | `HwpPageImageRenderer.renderPage(... .skiaOptIn)` 후 PNG encode | Skia PNG를 CGImage로 decode 후 재인코딩한 PNG |
| `skiaDirect` | `RhwpDocument.renderPagePNG(at: 0, scale: 1, maxDimension: 0)` 직접 호출 | upstream Skia PNG bytes |

`skiaDirect` 성공 조건:

1. Quick Look 단일 페이지 context.
2. `renderPagePNG` status가 `.ok`.
3. PNG bytes가 non-empty.
4. PNG 8-byte signature가 유효.
5. 첫 chunk가 `IHDR`, length 13, width/height가 1 이상.

ImageIO decode는 direct path 검증에 사용하지 않는다. direct path의 목적은 `CGImageSource` decode와 `CGImageDestination` PNG 재인코딩 비용을 제거하는 것이다.

Resolver contract:

| 입력 | DEBUG 결과 | Release 결과 |
|------|------------|--------------|
| missing/empty/invalid | `coreGraphics` | `coreGraphics` |
| `coreGraphics`, `coreGraphicsOnly` | `coreGraphics` | `coreGraphics` |
| `skia`, `skiaDecode`, `skiaOptIn` | `skiaDecode` | `coreGraphics` |
| `direct`, `skiaDirect` | `skiaDirect` | `coreGraphics` |

## 대표 smoke 결과

실행:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-quicklook-policy-representative \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
```

결과:

- resolver contract: `OK`
- 5개 샘플 load/render: 모두 `OK`
- 단일 페이지 3개 샘플: `skiaDirect` backend `skia`, fallback 0
- 다중 페이지 2개 샘플: `skiaDirect` status `N/A`
- `복학원서.hwp` 처리 중 기존 layout overflow warning 2줄이 stderr에 출력됐지만 render status는 모두 `OK`

| File | Reply | CGSec | SkiaDecodeSec | SkiaDirectSec | Direct vs Decode | DirectFallback |
|------|------|------:|---------------:|---------------:|------------------|----------------|
| `request.hwp` | png | 1.167163 | 0.062005 | 0.023481 | 0.038524초 감소, 약 62.1% 단축 | 0 |
| `KTX.hwp` | png | 0.073884 | 0.055980 | 0.042532 | 0.013448초 감소, 약 24.0% 단축 | 0 |
| `복학원서.hwp` | png | 0.051353 | 0.063517 | 0.051415 | 0.012102초 감소, 약 19.1% 단축 | 0 |
| `hwp-multi-001.hwp` | pdf | 0.443835 | 0.505146 | N/A | - | - |
| `hwpx-01.hwpx` | pdf | 0.412582 | 0.633081 | N/A | - | - |

Bytes:

| File | CGBytes | SkiaDecodeBytes | SkiaDecodePNGBytes | SkiaDirectBytes | DirectPixel |
|------|--------:|----------------:|-------------------:|----------------:|-------------|
| `request.hwp` | 90472 | 84098 | 87027 | 87027 | 567x794 |
| `KTX.hwp` | 543472 | 181314 | 166247 | 166247 | 1123x794 |
| `복학원서.hwp` | 223309 | 196405 | 198675 | 198675 | 794x1123 |

`skiaDirect` output bytes는 항상 upstream Skia PNG bytes와 같다. `skiaDecode` output bytes는 Skia PNG를 decode한 뒤 ImageIO가 다시 encode한 결과라 원본 PNG bytes와 다를 수 있다.

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| 계획 | `4225112` | 수행계획서 작성과 오늘할일 갱신 |
| 구현계획 | `a86ede2` | 단계별 구현계획서 작성 |
| Stage 1 | `5d88e75` | Quick Look PNG reply baseline inventory |
| Stage 2 | `ec7e43c` | Quick Look direct PNG contract 설계 |
| Stage 3 | `f8054ee` | Quick Look Skia direct PNG opt-in 적용 |
| Stage 4 | `3188adf` | Quick Look direct PNG 대표 샘플 검증 |
| Stage 5 | 이번 커밋 | 최종 보고서와 기술 문서 반영 |

## 후속 이슈 관계

| 이슈 | 관계 |
|------|------|
| #387 | #393은 Preview/Thumbnail Skia readiness 추적 중 Quick Look 단일 PNG fast path 실험이다 |
| #390 | `KTX.hwp` visual regression 때문에 Skia default 보류 결론을 유지한다. #393은 그 결론을 바꾸지 않는다 |
| #392 | Thumbnail maxDimension/underfill 판단과 별도 surface다. #393은 Thumbnail path를 변경하지 않는다 |
| #396 | visual suite가 Skia quality gate를 담당한다. #393 direct PNG 결과는 visual suite를 대체하지 않는다 |
| #259 | release/default readiness gate다. #393 결과는 단일 PNG opt-in 성능 입력으로만 넘긴다 |

## 검증 결과

실행한 주요 검증:

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-stage1-quicklook-baseline \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-stage3-quicklook-direct \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-quicklook-policy-representative \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask393Stage3 CODE_SIGNING_ALLOWED=NO build
```

결과:

- `check-no-appkit.sh`: 성공.
- `verify-rhwp-core-build-info.sh`: 성공.
- `verify-rhwp-studio-assets.sh`: 성공.
- Stage 1 baseline smoke: 성공. 5개 샘플 모두 `OK`, fallback 0건.
- Stage 3 direct smoke: 성공. resolver contract `OK`, 단일 페이지 direct fallback 0건, 다중 페이지 direct `N/A`.
- Stage 4 representative smoke: 성공. 5개 샘플 모두 `OK`.
- `xcodegen generate`: 성공.
- `xcodebuild ... QLExtension ... build`: 첫 sandbox 실행은 Sparkle package fetch DNS/network 실패, 네트워크 허용 재실행에서 `BUILD SUCCEEDED`.
- `git diff --check`: 각 단계에서 성공.

최종 보고서 검증:

```bash
rg -n "#393|#387|#390|#392|#259|Quick Look|direct PNG|Skia|CoreGraphics|fallback|smoke|readiness" \
  mydocs/report/task_m020_393_report.md mydocs/orders/20260703.md \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/tech/skia_preview_renderer_baseline.md
git diff --check
git status --short --branch
git log --oneline devel..local/task393
```

## 잔여 위험

| 항목 | 상태 | 처리 |
|------|------|------|
| `KTX.hwp` Skia visual regression | 잔여 | #396/#259 visual readiness gate에서 default blocker로 유지 |
| direct fallback 강제 fixture | 없음 | 정상 샘플 fallback 0은 확인. 실패 주입 fixture는 별도 후속 후보 |
| Release resolver smoke | source `#if DEBUG`로 env opt-in 차단 | 필요 시 review follow-up에서 별도 Release compile smoke 추가 |
| latency 절대값 | 로컬 단일 실행값 | 같은 smoke run 안의 상대 비교와 fallback 여부 중심으로 해석 |
| 다중 PDF Skia latency | 여전히 CoreGraphics보다 느림 | direct PNG 범위 밖. #259 readiness 입력으로 유지 |

## PR 게시 준비 메모

권장 PR 제목:

```text
Task #393: Quick Look Skia direct PNG opt-in fast path 실험
```

권장 PR 본문 요약:

```text
## Summary
- Add a Quick Look single-page PNG reply helper with coreGraphics, skiaDecode, and skiaDirect modes.
- Add a DEBUG-only ALHANGEUL_QUICKLOOK_PNG_REPLY_MODE resolver; Release resolves to CoreGraphics.
- Return upstream Skia PNG bytes directly for skiaDirect after PNG signature/IHDR validation, with CoreGraphics PNG fallback.
- Extend the Quick Look Skia policy smoke to compare CoreGraphics, Skia decode/re-encode, and Skia direct paths.
- Document that direct PNG is an opt-in fast path and does not bypass the Skia visual readiness gate.

## Verification
- ./scripts/check-no-appkit.sh
- ./scripts/verify-rhwp-core-build-info.sh
- ./scripts/verify-rhwp-studio-assets.sh
- ./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-quicklook-policy-representative samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
- xcodegen generate
- xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask393Stage3 CODE_SIGNING_ALLOWED=NO build
- git diff --check
```

리뷰 포인트:

- Release/default가 계속 CoreGraphics인지
- `skiaDirect`가 Quick Look 단일 페이지 PNG reply에만 적용되는지
- direct failure가 text fallback이 아니라 CoreGraphics PNG reply로 fallback하는지
- PNG validation이 ImageIO decode 없이 signature/IHDR 수준으로 제한된 것이 fast path 목적과 맞는지
- `KTX.hwp` visual regression을 default blocker로 계속 남긴 문서 판단이 적절한지

## 작업지시자 승인 요청

Task #393의 구현, 검증, 최종 보고서 작성을 완료했다. PR 게시 단계 진입 여부를 승인 요청한다.
