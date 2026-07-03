# Task M020 #393 구현계획서

수행계획서: `mydocs/plans/task_m020_393.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #393 `Quick Look 단일 페이지 Skia direct PNG opt-in fast path 실험`
- 추적 이슈: #387 Preview/Thumbnail Skia readiness 후속 개선 추적
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task393`
- 목표: Quick Look 단일 페이지 `skiaOptIn` 진단 경로에서 Skia PNG bytes를 Swift `CGImage` decode와 PNG 재인코딩 없이 `QLPreviewReply`로 직접 반환할 수 있는지 실험하고, 기존 decode path와 latency/bytes/fallback을 비교한다.

## 구현 원칙

- production default는 계속 `.coreGraphicsOnly`다.
- Skia default 전환, Thumbnail direct PNG, Quick Look 다중 페이지 PDF direct path, upstream `rhwp` 변경은 하지 않는다.
- direct PNG path는 Quick Look 단일 페이지에만 한정한다.
- Skia direct render 실패 또는 invalid PNG 결과는 Quick Look text fallback으로 바로 내려가지 않고 기존 CoreGraphics PNG reply shape으로 fallback한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- `project.yml`이 Xcode project 원본이다. 새 Swift source 추가가 필요하면 `project.yml` 변경과 `xcodegen generate`를 함께 처리한다. 가능하면 기존 source 안에서 좁게 구현한다.
- smoke helper는 같은 입력 파일에서 CoreGraphics, 기존 Skia decode path, Skia direct path를 비교 가능하게 남긴다.
- visual/default 판단은 #259 readiness gate로 넘기고, 이번 작업은 direct path의 비용과 fallback contract 실험으로 제한한다.

## Stage 1. 현행 Quick Look PNG reply inventory

### 목표

현재 Quick Look 단일 페이지 경로가 `Skia PNG -> CGImage decode -> PNG encode` round-trip을 거친다는 사실을 코드와 smoke output으로 고정한다.

### 대상

- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `scripts/smoke-quicklook-skia-policy.sh`
- `scripts/quicklook_skia_policy_smoke.swift`
- `mydocs/report/task_m020_390_report.md`
- `mydocs/report/task_m020_392_report.md`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md`

### 작업

1. `HwpPreviewProvider.pngReply`가 현재 production/default에서 `.coreGraphicsOnly`만 호출하는지 확인한다.
2. `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)`가 Skia PNG bytes를 decode해서 `HwpRenderedPage`로 바꾸는 흐름을 정리한다.
3. `quicklook_skia_policy_smoke.swift`가 단일 페이지에서 기존 Skia decode path를 어떻게 측정하는지 정리한다.
4. 현재 브랜치에서 quick smoke를 실행해 #390 기준과 비교 가능한 baseline을 고정한다.
5. Stage 2에서 필요한 direct path source surface와 diagnostics field 후보를 확정한다.

### 검증

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-stage1-quicklook-baseline \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
rg -n "pngReply|renderPagePNG|decodePNGImage|encodePNG|skiaOptIn|coreGraphicsOnly|SkiaBytes|SkiaPNGBytes|Reply" \
  Sources/QLExtension/HwpPreviewProvider.swift Sources/Shared/HwpPageImageRenderer.swift \
  scripts/quicklook_skia_policy_smoke.swift build.noindex/task393-stage1-quicklook-baseline \
  mydocs/working/task_m020_393_stage1.md
git diff --check
```

### 완료 조건

- 현재 Quick Look 단일 페이지 Skia smoke가 decode/encode round-trip 경로임이 문서화되어 있다.
- quick smoke baseline에서 reply type, output bytes, PNG bytes, backend pages, fallback, elapsed seconds가 정리되어 있다.
- Stage 2 설계 입력이 충분하다.

### 커밋 메시지

```text
Task #393 Stage 1: Quick Look PNG reply baseline inventory
```

## Stage 2. direct PNG reply contract 설계

### 목표

Quick Look 단일 페이지 direct PNG fast path의 적용 조건, fallback shape, diagnostics, smoke output contract를 확정한다.

### 대상

- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `scripts/quicklook_skia_policy_smoke.swift`
- `mydocs/working/task_m020_393_stage2.md`

### 작업

1. provider opt-in 조건을 설계한다.
   - production default는 `.coreGraphicsOnly`
   - DEBUG/internal 진단 조건에서만 direct Skia path 후보 사용
   - env key를 추가할지, smoke helper 전용 direct path로 둘지 판단
2. direct render helper contract를 정한다.
   - 입력: `HwpPreviewDocumentContext`, page index 0, policy/direct option
   - 성공: PNG bytes, page size, backend `.skia`, pngBytes, renderMs, direct flag
   - 실패: fallback reason과 Skia render timing을 보존한 뒤 CoreGraphics PNG reply로 fallback
3. `HwpPageRenderDiagnostics`를 확장할지, Quick Look 전용 diagnostics 구조를 만들지 판단한다.
4. 다중 페이지 PDF에는 direct path가 적용되지 않도록 조건을 명시한다.
5. smoke summary/detail column 후보를 정한다.
   - reply mode: `coreGraphics`, `skiaDecode`, `skiaDirect`
   - direct 여부
   - output bytes
   - skia PNG bytes
   - render/decode/encode/total seconds
   - fallback reason

### 검증

```bash
rg -n "QLPreviewReply|renderPagePNG|HwpPageRenderDiagnostics|HwpPreview|quicklook|direct|skiaOptIn|fallback" \
  Sources/QLExtension/HwpPreviewProvider.swift Sources/Shared/HwpPageImageRenderer.swift \
  Sources/RhwpCoreBridge/RhwpDocument.swift scripts/quicklook_skia_policy_smoke.swift \
  mydocs/working/task_m020_393_stage2.md
git diff --check
```

### 완료 조건

- source 변경 전 direct path contract가 문서화되어 있다.
- fallback과 diagnostics의 책임 경계가 확정되어 있다.
- Stage 3 구현 범위가 source 단위로 명확하다.

### 커밋 메시지

```text
Task #393 Stage 2: Quick Look direct PNG contract 설계
```

## Stage 3. opt-in direct PNG 구현과 smoke 보강

### 목표

Quick Look 단일 페이지 Skia direct PNG path를 opt-in으로 구현하고, 기존 decode path와 직접 비교 가능한 smoke output을 만든다.

### 대상

- `Sources/QLExtension/HwpPreviewProvider.swift`
- 필요 시 `Sources/Shared/HwpPageImageRenderer.swift`
- 필요 시 `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `scripts/quicklook_skia_policy_smoke.swift`
- 필요 시 `scripts/smoke-quicklook-skia-policy.sh`
- `mydocs/working/task_m020_393_stage3.md`

### 작업

1. Quick Look 단일 페이지 direct PNG helper를 구현한다.
2. direct path 성공 시 `QLPreviewReply(dataOfContentType: .png)`가 Skia PNG bytes를 그대로 반환하도록 한다.
3. direct path 실패 시 기존 CoreGraphics PNG reply로 fallback한다.
4. production/default provider path가 계속 CoreGraphics인지 확인한다.
5. smoke helper에 direct path 측정을 추가한다.
6. quick smoke로 direct/decode/CoreGraphics path의 output bytes, PNG bytes, timing, fallback을 비교한다.

### 검증

```bash
./scripts/check-no-appkit.sh
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-stage3-quicklook-direct \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
rg -n "direct|skiaOptIn|coreGraphicsOnly|Reply|Bytes|Fallback|RenderMs|Decode|Encode|OK|FAIL" \
  build.noindex/task393-stage3-quicklook-direct Sources scripts mydocs/working/task_m020_393_stage3.md
git diff --check
```

가능하면 build 검증:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask393Stage3 CODE_SIGNING_ALLOWED=NO build
```

### 완료 조건

- 단일 페이지 opt-in direct path가 Skia PNG bytes를 decode/encode 없이 reply data로 반환한다.
- direct 실패 시 CoreGraphics fallback reply가 유지된다.
- 다중 페이지 PDF path에는 direct path가 적용되지 않는다.
- smoke 결과가 direct/decode/CoreGraphics 경로를 같은 summary에서 비교 가능하게 남긴다.

### 커밋 메시지

```text
Task #393 Stage 3: Quick Look Skia direct PNG opt-in 적용
```

## Stage 4. 대표 샘플 비교 측정

### 목표

대표 샘플에서 CoreGraphics, 기존 Skia decode path, Skia direct path의 latency/bytes/fallback 결과를 비교하고 #259로 넘길 결론을 정리한다.

### 대상

- `build.noindex/task393-stage1-quicklook-baseline/`
- `build.noindex/task393-stage3-quicklook-direct/`
- `build.noindex/task393-quicklook-policy-representative/`
- `mydocs/working/task_m020_393_stage4.md`
- 필요 시 `mydocs/tech/skia_quicklook_thumbnail_backend.md`

### 작업

1. 기본 검증 command를 실행한다.
2. 대표 샘플 smoke를 실행한다.
3. 단일 페이지 샘플에서 direct/decode/CoreGraphics latency와 bytes를 표로 정리한다.
4. 다중 페이지 샘플이 direct path 비적용 상태로 기존 PDF path를 유지하는지 확인한다.
5. `KTX.hwp` visual regression이 direct PNG 실험으로 해결된 것이 아니라는 점을 분리한다.
6. #259 readiness gate로 넘길 direct path 성능/리스크 입력을 정리한다.

### 검증

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

### 완료 조건

- 대표 샘플 결과가 존재하고 direct path 효과를 해석할 수 있다.
- 단일/다중 페이지 경계가 검증되어 있다.
- direct path의 유효성, 한계, 후속 판단이 정리되어 있다.

### 커밋 메시지

```text
Task #393 Stage 4: Quick Look direct PNG 대표 샘플 검증
```

## Stage 5. 최종 보고와 문서 반영

### 목표

#393 실험 결과를 최종 보고서와 기술 문서에 반영하고 PR 게시 준비를 완료한다.

### 대상

- `mydocs/report/task_m020_393_report.md`
- `mydocs/orders/20260703.md`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- 필요 시 `mydocs/tech/skia_preview_renderer_baseline.md`

### 작업

1. 최종 보고서에 direct PNG fast path 정책, smoke 결과, 비교 결론을 정리한다.
2. 기술 문서의 Quick Look single-page direct PNG opt-in 기준과 남은 blocker를 갱신한다.
3. 오늘할일 #393 상태를 완료 처리한다.
4. #387, #390, #392, #259와의 후속 관계를 정리한다.
5. PR body 초안에 들어갈 변경 요약과 검증 결과를 정리한다.

### 검증

```bash
rg -n "#393|#387|#390|#392|#259|Quick Look|direct PNG|Skia|CoreGraphics|fallback|smoke|readiness" \
  mydocs/report/task_m020_393_report.md mydocs/orders/20260703.md \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/tech/skia_preview_renderer_baseline.md
git diff --check
git status --short --branch
git log --oneline devel..local/task393
```

### 완료 조건

- #393 최종 결론과 잔여 risk가 문서화되어 있다.
- 오늘할일이 완료 처리되어 있다.
- PR 게시에 필요한 변경 요약과 검증 결과가 정리되어 있다.

### 커밋 메시지

```text
Task #393 Stage 5: 최종 보고서와 문서 반영
```
