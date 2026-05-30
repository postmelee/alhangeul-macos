# Task M020 #259 구현계획서

수행계획서: `mydocs/plans/task_m020_259.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #259 Skia backend visual/performance/package regression gate 정리
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 브랜치: `local/task259`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 선행 상태: #255/#256/#257/#278은 완료됐고, #258 Finder thumbnail Skia 적용은 아직 열려 있다.
- 목표: 현재 Quick Look Skia 기본 적용이 release 후보로 충분한지 판단하고, 필요하면 Quick Look 기본 backend를 CoreGraphics/native path로 되돌린 뒤 Skia를 opt-in/diagnostic 경로로 유지하는 결론을 남긴다.

## 구현 원칙

- #259는 구현 확장보다 release gate 판정 작업이다.
- #258 미완료 상태를 명시적으로 인정하고, thumbnail 적용 확장은 이 작업에서 수행하지 않는다.
- 판단 근거는 기존 보고서 수치, 현재 코드 정책, 추가 smoke 결과를 함께 사용한다.
- Skia 기본 유지 여부는 visual diff만이 아니라 latency, fallback 관측성, staticlib/package size, Quick Look/Thumbnail 정책 일관성까지 함께 본다.
- Skia 기본 유지 근거가 부족하면 Quick Look provider의 기본 정책을 CoreGraphics/native path로 되돌리는 최소 보정까지 수행한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- public release 실행, tag 생성, signing/notarization, Homebrew 반영은 하지 않는다.

## 판정 기준

| 항목 | Skia 기본 유지 쪽 근거 | CoreGraphics 기본 복귀 쪽 근거 |
|---|---|---|
| Visual diff | 대표 샘플 다수에서 rhwp-studio/reference 대비 의미 있게 개선 | 개선 폭이 작거나 문서별로 방향이 갈림 |
| Latency | 단일/다중 Quick Look path에서 CoreGraphics와 동등하거나 빠름 | first-call 또는 대표 문서에서 큰 지연 발생 |
| Fallback | 실패 시 CoreGraphics fallback이 관측 가능하고 안정적 | fallback 원인/횟수/성능을 release에서 해석하기 어려움 |
| Package size | native-skia 크기 증가가 release 가치에 비례 | staticlib/package 증가 대비 사용자-facing 개선 근거 부족 |
| Surface 일관성 | Quick Look과 Thumbnail 모두 같은 정책으로 갈 준비가 됨 | Quick Look은 Skia, Thumbnail은 CoreGraphics로 갈라져 release 설명이 복잡함 |
| Known limitations | 제한이 명확하고 사용자 영향이 작음 | 알려진 시각/성능 이슈를 기본 경로로 배포하기 부담스러움 |

최종 결론은 `default 유지`, `default 복귀 + opt-in 유지`, `#258 선행 필요`, `추가 upstream 대기` 중 하나로 고정한다.

## Stage 1. 입력 산출물과 현재 backend 정책 inventory

### 목표

#255/#256/#257/#278 산출물과 현재 코드 정책을 수집해 #259가 #258보다 먼저 진행되는 이유와 판단 입력을 고정한다.

### 작업

1. #255 보고서에서 native-skia ABI, staticlib size 증가, symbol/header 변경을 추출한다.
2. #256 보고서에서 `HwpPageImageRenderer` policy, fallback taxonomy, diagnostics contract를 추출한다.
3. #257 보고서에서 Quick Look 단일/다중 page Skia smoke와 known limitations를 추출한다.
4. #278 보고서에서 `rhwp v0.7.13` 기준 Quick Look policy smoke, visual diff, Skia latency 결과를 추출한다.
5. 현재 `Sources/QLExtension/HwpPreviewProvider.swift`, `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`, `Sources/Shared/HwpPageImageRenderer.swift`의 backend policy를 확인한다.
6. #258 미완료 상태에서 #259를 먼저 진행하는 판단 근거를 Stage 1 보고서에 기록한다.

### 산출물

- `mydocs/plans/task_m020_259_impl.md`
- `mydocs/working/task_m020_259_stage1.md`

### 검증

```bash
rg -n "#255|#256|#257|#258|#259|#278|skiaOptIn|coreGraphicsOnly|backendUsed|fallbackReason|staticlib|visual diff" \
  mydocs/plans/task_m020_259_impl.md mydocs/working/task_m020_259_stage1.md \
  mydocs/report/task_m020_255_report.md mydocs/report/task_m020_256_report.md \
  mydocs/report/task_m020_257_report.md mydocs/report/task_m020_278_report.md
rg -n "skiaOptIn|coreGraphicsOnly|HwpPageRenderPolicy|renderFirstPage|renderPage" \
  Sources/QLExtension Sources/ThumbnailExtension Sources/Shared --glob '!**/Resources/**'
git diff --check
```

### 완료 기준

- 현재 Quick Look은 Skia 우선, Finder thumbnail은 CoreGraphics 기본이라는 정책 차이가 문서화된다.
- Stage 2 측정 대상과 Stage 3 판정 기준이 확정된다.
- Swift source는 아직 변경하지 않는다.

### 커밋 메시지

```text
Task #259 Stage 1: Skia readiness 입력과 정책 inventory 정리
```

## Stage 2. visual/performance/package gate 측정

### 목표

`rhwp v0.7.13` 기준으로 Skia/CoreGraphics Quick Look 결과를 재측정하고 release 판단에 필요한 visual, latency, package size 입력을 확보한다.

### 작업

1. Rust lock과 bundled `rhwp-studio` provenance를 검증한다.
2. 대표 샘플을 최소 3개 이상 사용한다.
   - `samples/basic/request.hwp`
   - `samples/hwpx/hwpx-01.hwpx`
   - `samples/복학원서.hwp`
   - 필요 시 `samples/basic/KTX.hwp`, `samples/hwp-multi-001.hwp`
3. `smoke-quicklook-skia-policy.sh`로 CoreGraphics/Skia reply shape, backend, fallback, latency를 비교한다.
4. `preview-visual-diff-harness.sh`로 reference 대비 CoreGraphics/Skia visual diff를 비교한다.
5. staticlib/Rhwp.xcframework size와 #255/#278 기록 대비 변화를 정리한다.
6. Stage 2 보고서에 수치와 해석을 기록한다.

### 산출물

- `mydocs/working/task_m020_259_stage2.md`
- `build.noindex/task259-*` 측정 산출물

### 검증

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task259-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task259-visual-cg --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task259-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp
du -sh Frameworks/universal/librhwp.a Frameworks/Rhwp.xcframework
git diff --check
```

### 완료 기준

- 대표 샘플별 Skia/CoreGraphics backend, fallback, latency, visual diff 수치가 보고서에 있다.
- size/package 영향이 release gate 판단 입력으로 정리되어 있다.
- Stage 3에서 default 유지/복귀를 판단할 수 있다.

### 커밋 메시지

```text
Task #259 Stage 2: Skia visual/performance gate 측정
```

## Stage 3. release policy 판정과 필요 시 최소 보정

### 목표

Stage 1-2 입력을 바탕으로 Quick Look 기본 backend 정책을 확정하고, 필요 시 최소 source 보정을 수행한다.

### 작업

1. 판정 기준표에 따라 `Skia default 유지` 또는 `CoreGraphics default 복귀 + Skia opt-in 유지`를 결정한다.
2. CoreGraphics default 복귀가 필요하면 `HwpPreviewProvider`의 단일 PNG와 다중 PDF policy를 `coreGraphicsOnly`로 조정한다.
3. Skia opt-in smoke helper와 Shared renderer contract는 유지한다.
4. QLExtension/HostApp/ThumbnailExtension build 영향 범위를 확인한다.
5. #258 진행 조건을 정리한다.
   - default 복귀 시 #258은 release 전 필수에서 제외하거나 diagnostic/cache 설계 이슈로 재범위화한다.
   - default 유지 시 #258에서 cache key/backend signature/memory smoke를 release 전 필수로 둔다.
6. Stage 3 보고서에 정책 결정과 근거를 기록한다.

### 산출물

- 필요 시 `Sources/QLExtension/HwpPreviewProvider.swift`
- 필요 시 `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `mydocs/working/task_m020_259_stage3.md`

### 검증

```bash
./scripts/check-no-appkit.sh
rg -n "skiaOptIn|coreGraphicsOnly|HwpPageRenderPolicy|Preview selected|Preview rendering" \
  Sources/QLExtension Sources/Shared Sources/ThumbnailExtension --glob '!**/Resources/**'
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task259-after-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
git diff --check
```

### 완료 기준

- Quick Look 기본 backend 정책이 source 또는 명시적 보고서 결론으로 고정된다.
- 필요한 source 보정이 있었다면 build와 smoke가 통과한다.
- #258 진행/보류/재범위화 조건이 명확하다.

### 커밋 메시지

```text
Task #259 Stage 3: Skia release policy 판정
```

## Stage 4. readiness checklist와 release note 초안 정리

### 목표

Skia optional backend의 release readiness checklist, known limitations, release note 초안, #258 handoff를 최종 산출물로 정리한다.

### 작업

1. Stage 1-3 결과를 종합해 readiness checklist를 작성한다.
2. release note/known limitations 후보 문구를 작성한다.
3. #258에 넘길 조건을 정리한다.
4. #259 최종 보고서를 작성한다.
5. 오늘할일을 완료 처리한다.
6. PR 본문에 포함할 summary와 검증 결과를 정리한다.

### 산출물

- `mydocs/report/task_m020_259_report.md`
- `mydocs/orders/20260530.md`
- 필요 시 `mydocs/working/task_m020_259_stage4.md`

### 검증

```bash
rg -n "#259|#258|Skia|CoreGraphics|Quick Look|Thumbnail|release note|known limitation|readiness|default" \
  mydocs/report/task_m020_259_report.md mydocs/orders/20260530.md
git diff --check
git status --short --branch
```

### 완료 기준

- Skia backend release readiness 판단이 근거와 함께 최종 보고서에 남아 있다.
- release note/known limitations 초안이 있다.
- #258을 계속할지, 보류할지, 범위를 바꿀지 명확히 남아 있다.
- PR 게시 준비가 가능하다.

### 커밋 메시지

```text
Task #259 Stage 4 + 최종 보고서: Skia readiness gate 정리
```
