# Task M020 #259 Stage 3 보고서 - Skia release policy 판정

## 단계 개요

- 이슈: #259 Skia backend visual/performance/package regression gate 정리
- 단계: Stage 3. release policy 판정과 최소 보정
- 기준 브랜치: `local/task259`
- 목표: Stage 1-2 입력을 바탕으로 Quick Look 기본 backend 정책을 확정하고, 필요한 source 보정을 수행한다.

## 정책 결정

결론: `Quick Look 기본 CoreGraphics/native path 복귀 + Skia opt-in/diagnostic 경로 유지`

이 결정은 Skia 기능을 제거하는 것이 아니다. `HwpPageImageRenderer`의 `.skiaOptIn`, fallback contract, diagnostics, smoke helper는 유지한다. 다만 release 기본 경로에서는 Quick Look preview가 안정적인 CoreGraphics/native renderer를 먼저 사용하도록 되돌린다.

## 판정 근거

| Gate | Stage 2 결과 | 판정 |
|---|---|---|
| Visual diff | `복학원서.hwp`는 Skia가 크게 개선됐지만 `KTX.hwp`는 changed pixel 31.1362%에서 47.1389%로 악화 | 문서별 방향이 갈려 default 근거 부족 |
| Latency | Quick Look smoke에서 단일 PNG 일부는 Skia가 빠르지만, 다중 PDF 2개는 Skia가 느림 | 다중 preview default로 부담 |
| First/render cost | `request.hwp` visual diff harness에서 Skia native render가 5,460.6ms | release default로 위험 |
| Fallback | 측정 샘플 fallback 0 | 실패 안정성은 좋지만 품질/성능 판단을 대체하지 못함 |
| Package size | `librhwp.a`는 #255 이전 대비 +95,019,768 bytes | 기본 경로 개선 근거가 부족한 상태에서는 비용이 큼 |
| Surface 일관성 | Quick Look은 Skia 우선, Thumbnail은 CoreGraphics 기본이던 상태 | CoreGraphics 기본으로 맞추는 편이 release 설명이 단순함 |

Stage 2 수치만으로는 Skia를 기본 경로로 유지할 만큼 일관된 품질/성능 개선이 확인되지 않았다. 따라서 Stage 3에서는 Quick Look provider의 기본 정책만 CoreGraphics로 보정한다.

## Source 변경

변경 파일:

| 파일 | 변경 |
|---|---|
| `Sources/QLExtension/HwpPreviewProvider.swift` | 단일 PNG reply의 `HwpPageImageRenderer.renderPage(... policy:)`를 `.skiaOptIn`에서 `.coreGraphicsOnly`로 변경 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | 다중 PDF reply의 `HwpPreviewPDFRenderer.render(... policy:)`를 `.skiaOptIn`에서 `.coreGraphicsOnly`로 변경 |

변경하지 않은 것:

| 범위 | 유지 이유 |
|---|---|
| `HwpPageRenderPolicy.skiaOptIn` | 후속 diagnostic/smoke와 opt-in 실험 경로로 필요 |
| Skia fallback/diagnostics | `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs` contract 유지 |
| `HwpPreviewPDFRenderer` public API | 기본값이 이미 `.coreGraphicsOnly`이고 opt-in 호출을 계속 지원 |
| Thumbnail extension | 현재도 CoreGraphics 기본이므로 Stage 3에서 추가 변경 없음 |
| `smoke-quicklook-skia-policy.sh` | CoreGraphics/Skia 비교 gate로 계속 필요 |

## 변경 후 backend 정책

| Surface | 변경 후 정책 | 의미 |
|---|---|---|
| Quick Look 단일 PNG | `.coreGraphicsOnly` | release 기본 preview는 CoreGraphics/native renderer 사용 |
| Quick Look 다중 PDF | `.coreGraphicsOnly` | PDF page bitmap도 CoreGraphics/native renderer 사용 |
| Finder Thumbnail | `.coreGraphicsOnly` 기본값 유지 | `renderFirstPage` 기본 정책 그대로 사용 |
| Shared renderer | `.coreGraphicsOnly`, `.skiaOptIn` 모두 유지 | Skia는 명시 opt-in일 때만 사용 |

## #258 진행 조건

이번 결정으로 #258은 release 전 필수 작업에서 제외하는 쪽이 맞다.

정리:

1. Quick Look 기본이 CoreGraphics로 복귀했으므로, release surface의 기본 preview/thumbnail backend는 다시 일관된다.
2. #258을 지금 진행해 Thumbnail까지 Skia를 확장하면 Stage 2에서 확인한 visual/latency 리스크를 더 넓히게 된다.
3. #258은 "Finder thumbnail Skia default 적용"보다는 후속 "Skia opt-in thumbnail diagnostic/cache 설계"로 재범위화하는 것이 안전하다.
4. 나중에 #258을 진행한다면 cache key에는 backend 정책, pixel bucket, `maximumPixelSize`/`maxDimension` 변환 signature가 반드시 포함되어야 한다.
5. Skia를 release default로 다시 검토하려면 KTX류 악화 사례와 `request.hwp` first/render cost를 먼저 줄여야 한다.

## 검증 결과

### Source/policy 검색

```bash
rg -n "skiaOptIn|coreGraphicsOnly|HwpPageRenderPolicy|Preview selected|Preview rendering" \
  Sources/QLExtension Sources/Shared Sources/ThumbnailExtension --glob '!**/Resources/**'
```

결과:

- `Sources/QLExtension/HwpPreviewProvider.swift`의 단일 PNG와 다중 PDF 호출부가 `.coreGraphicsOnly`를 명시한다.
- Shared renderer와 smoke 관련 Skia opt-in 경로는 남아 있다.
- Thumbnail은 여전히 `renderFirstPage` 기본값을 사용한다.

### Build

실행:

```bash
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
```

결과:

| 명령 | 결과 | 비고 |
|---|---|---|
| `./scripts/check-no-appkit.sh` | 통과 | `OK: shared Swift code has no AppKit/UIKit dependencies` |
| `xcodebuild ... QLExtension ... build` | 통과 | sandbox 안에서는 Sparkle clone network 제한으로 실패 후 sandbox 밖 재실행 통과, `** BUILD SUCCEEDED ** [12.360 sec]` |
| `xcodebuild ... HostApp ... build` | 통과 | sandbox 안에서는 SwiftPM/clang cache 쓰기 제한으로 실패 후 sandbox 밖 재실행 통과, `** BUILD SUCCEEDED ** [1.368 sec]` |
| `xcodebuild ... ThumbnailExtension ... build` | 통과 | sandbox 밖 실행, `** BUILD SUCCEEDED ** [0.590 sec]` |

### Policy smoke

실행:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task259-after-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

결과:

| File | Reply | Pages | CG backend | CG sec | Skia backend | Skia sec | Fallback |
|---|---|---:|---|---:|---|---:|---:|
| `request.hwp` | png | 1 | `skia:0,cg:1,embedded:0` | 1.079998 | `skia:1,cg:0,embedded:0` | 0.069319 | 0 |
| `hwpx-01.hwpx` | pdf | 9 | `skia:0,cg:9,embedded:0` | 0.372840 | `skia:9,cg:0,embedded:0` | 0.615025 | 0 |

이 smoke는 helper가 CoreGraphics와 Skia opt-in 정책을 직접 비교하는 검증이다. Stage 3 source 변경 후에도 opt-in Skia 경로와 fallback 관측이 유지됨을 확인했다.

### Hygiene

```bash
git diff --check
```

결과: 통과.

## 남은 작업

Stage 4에서 다음을 최종 보고서로 정리한다.

- release readiness checklist
- release note/known limitation 초안
- #258 handoff 문구
- 오늘할일 완료 처리

## 다음 단계 승인 요청

Stage 4에서는 #259 최종 보고서를 작성하고, Quick Look 기본 CoreGraphics 복귀와 Skia opt-in 유지 결론을 release note 후보까지 정리한다.
