# Task M020 #87 구현 계획서

수행계획서: `mydocs/plans/task_m020_87.md`

## 작업 개요

- 이슈: #87 PDFKit 기반 Quick Look lazy PDF preview 가능성 검증
- 마일스톤: `v0.2`
- 브랜치: `local/task87`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task87`
- 목표: `QLPreviewReply(forPDFWithPageSize:documentCreationBlock:)`와 custom `PDFDocument`/`PDFPage` 조합이 Quick Look 안에서 visible page 중심 lazy rendering으로 동작하는지 검증하고, #88 view-based 전환 필요성을 판단한다.

## 구현 원칙

- 본 작업은 Quick Look API 동작 검증 spike이며 제품 기본 preview 경로를 바로 전환하지 않는다.
- 현재 data-based PDF preview 경로(`HwpPreviewPDFRenderer` + `HwpPageImageRenderer`)는 기준선으로 유지한다.
- `Sources/RhwpCoreBridge`에는 AppKit/PDFKit/QuickLookUI 의존을 추가하지 않는다.
- PDFKit probe는 Quick Look extension 경계 또는 standalone script에 둔다.
- 제품 코드에 probe가 들어가야 할 경우 명확한 opt-in gate를 둔다. gate가 꺼진 기본 동작은 기존 `.pdf` data reply와 같아야 한다.
- Stage별 산출물에는 실행 명령, 샘플, 관측 로그 위치, 한계와 다음 판단을 함께 남긴다.

## Stage 1. 현행 Quick Look PDF reply와 PDFKit 후보 inventory

대상:

- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- `mydocs/report/task_m010_85_report.md`
- `mydocs/report/task_m020_221_report.md`
- `mydocs/working/task_m010_85_stage1.md`
- `mydocs/working/task_m010_85_stage5.md`

작업:

1. 현재 단일 페이지 PNG reply와 다중 페이지 PDF data reply 흐름을 코드 기준으로 정리한다.
2. #85 Stage 5 결론과 #221 SVG PDF spike 결론을 #87 판단 범위에 맞게 재정리한다.
3. `QLPreviewReply(forPDFWithPageSize:documentCreationBlock:)`, `PDFDocument`, `PDFPage` subclass의 compile 가능성을 확인한다.
4. `PDFDocument` subclass/page 삽입 방식 중 실제 probe에 쓸 수 있는 최소 구조를 고른다.
5. Stage 1 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_87_stage1.md`

검증:

```bash
rg -n "QLPreviewReply|forPDFWithPageSize|PDFDocument|PDFPage|HwpPreviewProvider|HwpPreviewPDFRenderer" \
  Sources mydocs/report/task_m010_85_report.md mydocs/report/task_m020_221_report.md mydocs/working/task_m010_85_stage1.md mydocs/working/task_m010_85_stage5.md
xcrun swift -e 'import Foundation; import QuickLookUI; import PDFKit; let _ = QLPreviewReply(forPDFWithPageSize: .zero) { reply in PDFDocument() }'
git diff --check -- mydocs/plans/task_m020_87_impl.md mydocs/working/task_m020_87_stage1.md
```

완료 조건:

- 현재 data-based PDF reply가 true lazy pagination을 제공하지 못하는 이유가 코드 흐름으로 설명되어 있다.
- PDFKit reply API와 custom page hook의 compile 가능 여부가 기록되어 있다.
- Stage 2에서 만들 probe의 위치와 최소 객체 구조가 정해져 있다.

커밋:

```text
Task #87 Stage 1: Quick Look PDFKit lazy 후보 inventory
```

## Stage 2. standalone PDFKit lazy probe helper 작성

대상:

- 신규 후보: `scripts/quicklook-pdfkit-lazy-probe.swift`
- `mydocs/working/task_m020_87_stage2.md`

작업:

1. custom `PDFPage` subclass가 `draw(with:to:)` 호출을 기록하도록 만든다.
2. custom `PDFDocument` 또는 inserted page 구조로 여러 page를 구성한다.
3. helper가 page count, page bounds, 직접 draw 호출 로그를 summary로 남기게 한다.
4. Quick Look extension에 넣기 전 PDFKit 객체 구조가 standalone 환경에서 동작하는지 확인한다.
5. Stage 2 완료보고서를 작성한다.

산출물:

- `scripts/quicklook-pdfkit-lazy-probe.swift`
- `mydocs/working/task_m020_87_stage2.md`

검증:

```bash
xcrun swift scripts/quicklook-pdfkit-lazy-probe.swift --pages 5 --output /private/tmp/rhwp-task87-pdfkit-probe
test -s /private/tmp/rhwp-task87-pdfkit-probe/summary.txt
git diff --check -- scripts/quicklook-pdfkit-lazy-probe.swift mydocs/working/task_m020_87_stage2.md
```

완료 조건:

- custom `PDFPage.draw(with:to:)` 호출을 page index별로 기록할 수 있다.
- helper가 실패할 경우 실패 지점이 PDFDocument 구성, page bounds, draw hook 중 어디인지 구분된다.
- 제품 preview 경로는 변경하지 않는다.

커밋:

```text
Task #87 Stage 2: PDFKit lazy probe helper 추가
```

## Stage 3. Quick Look extension gated PDFKit reply probe 추가

대상:

- `Sources/QLExtension/HwpPreviewProvider.swift`
- 신규 후보: `Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift`
- 필요 시 `project.yml`
- `mydocs/working/task_m020_87_stage3.md`

작업:

1. 기본 경로는 기존 PNG/PDF data reply를 유지한다.
2. 환경변수 또는 명확한 debug flag로만 PDFKit probe reply를 선택하게 한다.
3. probe reply는 `QLPreviewReply(forPDFWithPageSize:documentCreationBlock:)`로 custom `PDFDocument`를 반환한다.
4. custom page draw 호출, document 생성, page request, fallback 여부를 `OSLog`와 `/private/tmp` summary 중 하나 이상에 기록한다.
5. Debug build에서 compile/link를 확인한다.
6. Stage 3 완료보고서를 작성한다.

산출물:

- `Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift`
- `Sources/QLExtension/HwpPreviewProvider.swift`
- 필요 시 `project.yml`
- `mydocs/working/task_m020_87_stage3.md`

검증:

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check -- Sources/QLExtension/HwpPreviewProvider.swift Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift project.yml mydocs/working/task_m020_87_stage3.md
```

완료 조건:

- gate가 꺼진 기본 Quick Look preview 코드 흐름은 기존과 동일하다.
- gate가 켜진 경우에만 PDFKit reply probe가 선택된다.
- QLExtension이 Debug configuration에서 빌드된다.

커밋:

```text
Task #87 Stage 3: Quick Look PDFKit reply probe 추가
```

## Stage 4. Quick Look smoke와 page draw 관측

대상:

- Stage 3 probe
- 다중 페이지 HWP/HWPX 샘플
- `mydocs/working/task_m020_87_stage4.md`

작업:

1. `build_run_guide.md`의 Quick Look/Thumbnail smoke 원칙을 확인하고 오염 정리 절차를 먼저 기록한다.
2. 다중 페이지 샘플에서 기존 data reply 기준 first preview latency와 probe reply 기준 관측 로그를 비교한다.
3. 최초 표시, scroll/page 이동, 빠른 Finder selection 전환에서 `PDFPage.draw(with:to:)` 호출 순서를 기록한다.
4. Quick Look이 전체 page를 선행 materialize하는지, visible page 중심으로 요청하는지 결론을 낸다.
5. 개발 산출물 등록이나 임시 로그 파일 정리 결과를 기록한다.
6. Stage 4 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_87_stage4.md`
- 필요 시 ignored `output/task87-*` 또는 `/private/tmp/rhwp-task87-*` 측정 산출물

검증:

```bash
git diff --check -- mydocs/working/task_m020_87_stage4.md
```

Quick Look smoke 명령은 Stage 3 산출물과 실제 provider 등록 방식이 확정된 뒤 Stage 4 보고서에 실행형으로 기록한다.

완료 조건:

- 최소 1개 다중 페이지 HWP/HWPX 샘플에서 Quick Look 안의 page draw 호출 양상이 기록되어 있다.
- 가능/부분 가능/불가능 판단에 필요한 evidence가 있다.
- smoke 이후 개발용 Quick Look/Thumbnail provider 등록 잔존 여부가 확인되어 있다.

커밋:

```text
Task #87 Stage 4: Quick Look PDFKit lazy 동작 관측
```

## Stage 5. 결론, probe 정리, #88 handoff

대상:

- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift`
- `scripts/quicklook-pdfkit-lazy-probe.swift`
- `mydocs/report/task_m020_87_report.md`
- `mydocs/orders/20260518.md`

작업:

1. PDFKit reply probe를 제품 코드에 남길지 제거할지 판단한다.
2. 남긴다면 기본 disabled/debug-only 상태와 이유를 문서화한다.
3. 제거한다면 관측용 script/report만 보존하고 제품 코드 diff를 정리한다.
4. 가능/부분 가능/불가능 최종 결론과 #88 진행 조건을 정리한다.
5. #254 Skia backend 설계와 충돌하지 않는 handoff 문구를 남긴다.
6. 오늘할일을 완료로 갱신하고 최종 보고서를 작성한다.

산출물:

- `mydocs/report/task_m020_87_report.md`
- `mydocs/orders/20260518.md`
- 유지 또는 제거 결정에 따른 probe 관련 파일

검증:

```bash
git diff --check
```

제품 코드에 probe가 남는 경우:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

완료 조건:

- PDFKit lazy preview 채택 가능성이 결론으로 정리되어 있다.
- #88을 바로 진행할지, #254 이후로 미룰지, 또는 data-based 경로를 유지할지 판단 근거가 있다.
- 최종 보고서와 오늘할일 갱신이 완료되어 있다.

커밋:

```text
Task #87 Stage 5 + 최종 보고서: PDFKit lazy preview 검증 결과 정리
```
