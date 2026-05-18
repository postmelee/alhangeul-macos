# Task M020 #254 구현 계획서

수행계획서: `mydocs/plans/task_m020_254.md`

## 작업 개요

- 이슈: #254 Skia Quick Look/Thumbnail optional backend 설계와 rollout gate 정리
- 마일스톤: `v0.2.x Skia Quick Look/Thumbnail Backend`
- 브랜치: `local/task254`
- 목표: Quick Look preview와 Finder thumbnail에 upstream `rhwp` native Skia PNG backend를 optional raster backend로 도입하기 위한 설계, fallback contract, 후속 이슈 의존 순서, 검증 gate를 확정한다.

## 구현 원칙

- 본 작업은 설계와 rollout gate 정리이며, 제품 Swift/Rust source는 변경하지 않는다.
- `RustBridge` ABI 추가, `native-skia` feature enable, Quick Look/Thumbnail 적용은 후속 이슈 #255-#258에서 수행한다.
- 현재 제품 기준선은 `PageRenderTree` JSON + Swift `CGTreeRenderer` + Quick Look/Thumbnail bitmap 경로다.
- Skia 후보는 `PageLayerTree` + upstream native Skia PNG output으로 정의한다.
- HostApp WKWebView viewer, CanvasKit browser renderer, vector PDF export는 이번 task 범위 밖으로 둔다.
- 후속 이슈가 바로 실행할 수 있도록 stage별 산출물은 장기 기술 문서와 단계 보고서에 중복 없이 정리한다.

## Stage 1. 현행 경로와 upstream Skia 적용 가능 범위 inventory

대상:

- `rhwp-core.lock`
- `RustBridge/Cargo.toml`
- `RustBridge/src/lib.rs`
- `rhwp-ffi-symbols.txt`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `mydocs/tech/project_architecture.md`
- GitHub upstream `edwardkim/rhwp` #536, 필요 시 관련 PR #599/#769/#925

작업:

1. 현재 Quick Look preview와 Finder thumbnail의 render flow를 코드 기준으로 정리한다.
2. 현재 RustBridge FFI 표면과 `rhwp v0.7.11` lock 상태를 확인한다.
3. upstream native Skia PNG API가 현재 lock에서 어디까지 포함되어 있는지 정리한다.
4. #96, #222와 #254의 책임 경계를 정리한다.
5. Stage 1 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_254_stage1.md`

검증:

```bash
rg -n "rhwp_render_page_tree|renderPageTree|HwpPageImageRenderer|HwpPreviewPDFRenderer|HwpThumbnailProvider|native-skia|render_page_png" \
  rhwp-core.lock RustBridge Sources mydocs/tech/project_architecture.md mydocs/working/task_m020_254_stage1.md
git diff --check -- mydocs/plans/task_m020_254_impl.md mydocs/working/task_m020_254_stage1.md
```

완료 조건:

- 현재 제품 경로와 Skia 후보 경로가 명확히 분리되어 있다.
- 현재 lock 기준으로 당장 활용 가능한 upstream API와 아직 release 밖인 항목이 구분되어 있다.
- #96/#222와 중복하지 않는 #254의 설계 책임이 정리되어 있다.

커밋:

```text
Task #254 Stage 1: Skia Quick Look renderer inventory 정리
```

## Stage 2. backend 선택 정책과 fallback contract 설계

대상:

- 신규: `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- `mydocs/working/task_m020_254_stage2.md`

작업:

1. `CoreGraphics only`, `Skia opt-in`, `Skia first + CoreGraphics fallback`, `Skia default` 후보를 비교한다.
2. failure taxonomy를 정의한다.
   - FFI unavailable
   - Skia render failure
   - PNG decode failure
   - invalid page size
   - file size fallback
   - memory/timeout fallback
3. Quick Look과 Thumbnail의 backend 선택 정책 차이를 정리한다.
4. 로그/진단 필드 후보를 정리한다.
5. Stage 2 완료보고서를 작성한다.

산출물:

- `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- `mydocs/working/task_m020_254_stage2.md`

검증:

```bash
rg -n "CoreGraphics|Skia|fallback|Quick Look|Thumbnail|failure|decode|memory|timeout" \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage2.md
git diff --check -- mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage2.md
```

완료 조건:

- 기본 후보와 보류 후보의 장단점이 문서화되어 있다.
- Quick Look과 Thumbnail에 같은 정책을 강제하지 않는다.
- 후속 구현에서 사용할 fallback contract 초안이 있다.

커밋:

```text
Task #254 Stage 2: Skia backend fallback contract 설계
```

## Stage 3. 후속 이슈 의존 순서와 handoff gate 정리

대상:

- `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- `mydocs/working/task_m020_254_stage3.md`
- GitHub issue #255, #256, #257, #258, #259

작업:

1. #255 RustBridge FFI, #256 Shared renderer, #257 Quick Look, #258 Thumbnail, #259 verification gate의 선후관계를 확정한다.
2. 각 후속 이슈가 시작되기 위한 입력 조건과 완료 조건을 정리한다.
3. ABI gate, Shared renderer gate, extension integration gate, release readiness gate를 분리한다.
4. 필요하면 후속 이슈 본문 업데이트 후보를 보고서에 적는다. 이 단계에서는 GitHub issue 본문을 직접 수정하지 않는다.
5. Stage 3 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_254_stage3.md`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md` 갱신

검증:

```bash
rg -n "#255|#256|#257|#258|#259|ABI gate|Shared renderer|Quick Look|Thumbnail|release readiness" \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage3.md
git diff --check -- mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage3.md
```

완료 조건:

- 후속 이슈 진행 순서와 handoff 조건이 명확하다.
- #255-#259가 서로 중복해서 같은 책임을 갖지 않는다.
- GitHub issue 본문 수정이 필요하면 별도 승인 후보로 남긴다.

커밋:

```text
Task #254 Stage 3: Skia 후속 이슈 handoff gate 정리
```

## Stage 4. visual/performance/package readiness gate 정리

대상:

- `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- `mydocs/working/task_m020_254_stage4.md`
- 관련 기존 smoke/debug script 문서

작업:

1. 대표 샘플군을 정한다.
   - 단일 페이지
   - 다중 페이지
   - 이미지 포함
   - 수식/raw SVG/form object 후보
   - text/font fallback 민감 문서
2. visual diff 기준을 정리한다.
3. extension latency/memory 측정 항목을 정리한다.
4. `native-skia` feature로 인한 staticlib/Rhwp.xcframework/package size 측정 기준을 정리한다.
5. default 전환, opt-in 유지, 보류 판단 기준을 정리한다.
6. Stage 4 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_254_stage4.md`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md` 갱신

검증:

```bash
rg -n "visual|diff|latency|memory|package|staticlib|Rhwp.xcframework|default|opt-in|보류" \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage4.md
git diff --check -- mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage4.md
```

완료 조건:

- 후속 #259가 사용할 readiness checklist가 문서화되어 있다.
- default 전환 판단이 감각이 아니라 측정 항목에 연결되어 있다.
- release note known limitation 후보가 있다.

커밋:

```text
Task #254 Stage 4: Skia readiness gate 정리
```

## Stage 5. 최종 설계 문서와 보고서 정리

대상:

- `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- `mydocs/report/task_m020_254_report.md`
- `mydocs/orders/20260518.md`

작업:

1. Stage 1-4 결론을 장기 기술 문서에 정리한다.
2. 최종 권장 rollout 순서를 확정한다.
3. 후속 이슈별 시작 조건과 잔여 리스크를 최종 보고서에 정리한다.
4. 오늘할일 상태를 완료로 갱신한다.
5. 최종 보고서를 작성한다.

산출물:

- `mydocs/report/task_m020_254_report.md`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md` 최종 갱신
- `mydocs/orders/20260518.md` 갱신

검증:

```bash
rg -n "#254|#255|#256|#257|#258|#259|Skia|Quick Look|Thumbnail|fallback|readiness" \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/report/task_m020_254_report.md mydocs/orders/20260518.md
git diff --check
```

완료 조건:

- 후속 #255-#259를 진행할 설계 기준이 장기 문서에 남아 있다.
- 최종 보고서가 완료 범위, 검증 결과, 잔여 리스크를 포함한다.
- 오늘할일이 완료 상태로 갱신되어 있다.

커밋:

```text
Task #254 Stage 5 + 최종 보고서: Skia optional backend 설계 정리
```

## 승인 요청

이 구현계획 승인 후 Stage 1 `현행 Quick Look/Thumbnail renderer와 upstream Skia 적용 가능 범위 inventory`를 진행한다.
