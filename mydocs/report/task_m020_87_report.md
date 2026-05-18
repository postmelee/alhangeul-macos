# Task M020 #87 최종 결과보고서

## 작업 요약

- 이슈: #87 PDFKit 기반 Quick Look lazy PDF preview 가능성 검증
- 마일스톤: M020 / v0.2
- 브랜치: `local/task87`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task87`
- 단계 수: 5단계
- 결론: `QLPreviewReply(forPDFWithPageSize:documentCreationBlock:)`와 custom `PDFDocument`/`PDFPage` 조합은 이번 관측 범위에서 visible page 중심 lazy rendering으로 동작하지 않았다. 제품 Quick Look 기본 경로는 기존 data reply를 유지하고, lazy preview가 계속 필요하면 #88의 view-based Quick Look 경로를 검토한다.

## 최종 판단

PDFKit document reply 경로는 Task #87의 목표인 "보이는 page 중심 lazy preview" 후보로 채택하지 않는다.

근거는 두 가지다.

1. standalone PDFKit probe에서 `PDFDocument.dataRepresentation()`은 custom page 5개를 모두 `draw(with:to:)`로 materialize했다.
2. 실제 Quick Look runtime에서도 최초 preview load 중 `dataRepresentation`이 호출됐고, 10페이지 샘플의 page 1-10 전체가 요청 및 draw됐다.

따라서 `QLPreviewReply(forPDFWithPageSize:)`에 custom `PDFDocument`를 반환하더라도 Quick Look이 PDFDocument를 page view처럼 lazily 소비한다고 보기 어렵다. 현재 확인한 동작은 data-based PDF reply와 유사하게 최초 load 시 전체 PDF bytes를 준비하는 흐름에 가깝다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
| --- | --- |
| `scripts/quicklook-pdfkit-lazy-probe.swift` | standalone PDFKit draw hook 관측 helper 추가 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | Stage 3/4의 debug-only PDFKit probe 분기를 Stage 5에서 제거하고 기존 PNG/PDF data reply 흐름으로 복귀 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate` 결과로 제거된 probe source 참조 반영 |
| `mydocs/plans/task_m020_87.md` | 수행계획서 |
| `mydocs/plans/task_m020_87_impl.md` | 구현계획서 |
| `mydocs/working/task_m020_87_stage1.md` | 현행 Quick Look PDF reply와 PDFKit 후보 inventory |
| `mydocs/working/task_m020_87_stage2.md` | standalone PDFKit lazy probe 결과 |
| `mydocs/working/task_m020_87_stage3.md` | Quick Look extension gated probe 추가와 Debug build 검증 |
| `mydocs/working/task_m020_87_stage4.md` | 실제 Quick Look smoke와 page draw 관측 |
| `mydocs/report/task_m020_87_report.md` | 최종 결론과 handoff 정리 |
| `mydocs/orders/20260518.md` | #87 오늘할일 완료 처리 |

Stage 3/4에서 제품 소스에 추가했던 `Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift`는 최종 제품 코드에 남기지 않고 제거했다. 관측 재현에는 `scripts/quicklook-pdfkit-lazy-probe.swift`와 단계 보고서를 사용한다.

## 단계별 결과

| Stage | 결과 | 산출물 |
| --- | --- | --- |
| Stage 1 | 현행 단일 페이지 PNG reply, 다중 페이지 PDF data reply, PDFKit reply 후보 구조를 정리 | `mydocs/working/task_m020_87_stage1.md` |
| Stage 2 | custom `PDFPage.draw(with:to:)` 기록 helper 작성. standalone `dataRepresentation()`이 전체 page draw를 호출함을 확인 | `scripts/quicklook-pdfkit-lazy-probe.swift`, `mydocs/working/task_m020_87_stage2.md` |
| Stage 3 | 기본 경로는 유지하고 opt-in flag로만 Quick Look PDFKit probe를 선택하는 debug-only extension probe 추가 | `Sources/QLExtension/HwpPDFKitLazyPreviewProbe.swift`, `mydocs/working/task_m020_87_stage3.md` |
| Stage 4 | `qlmanage -p` runtime에서 최초 load만으로 10페이지 전체 `page(at:)`/`draw`가 발생함을 관측 | `mydocs/working/task_m020_87_stage4.md` |
| Stage 5 | 제품 probe 제거, 최종 결론과 #88 handoff 정리, 오늘할일 완료 처리 | `mydocs/report/task_m020_87_report.md`, `mydocs/orders/20260518.md` |

## 핵심 관측 근거

Stage 2 standalone helper:

```text
PagesRequested: 5
DocumentPageCount: 5
DataRepresentationDrawEvents: 5
DirectDrawEvents: 5
TotalDrawEvents: 10
```

의미:

- page 삽입 자체는 draw를 호출하지 않았다.
- `PDFDocument.dataRepresentation()` 단계에서 custom page 5개 전체가 draw됐다.
- 직접 draw hook은 page별 기록 수단으로 정상 동작했다.

Stage 4 Quick Look runtime:

```text
Filename: hwp-multi-001.hwp
PageCount: 10
EventCount: 34
```

event sequence 요약:

```text
3  dataRepresentation begin
4  pageRequest page=1
...
13 pageRequest page=10
15 draw page=1
17 draw page=2
...
33 draw page=10
34 dataRepresentation end bytes=8030
```

의미:

- 실제 Quick Look preview 최초 load에서 `PDFDocument.dataRepresentation()`이 호출됐다.
- scroll/page 이동 전에도 page 1-10 전체가 요청되고 draw됐다.
- visible page 중심 lazy rendering으로 볼 근거가 없다.

## #88 / #254 handoff

#88은 PDFKit document reply가 아니라 view-based Quick Look lazy rendering 가능성을 검토하는 방향이 맞다. lazy가 목표라면 PDF bytes 전체 생성 시점을 늦추는 것보다, Quick Look이 실제로 표시할 view 또는 page surface를 언제 요청하는지 검증해야 한다.

#254 Skia backend 설계와는 충돌하지 않는다. #254는 renderer backend 품질과 성능 선택지이고, #87/#88은 Quick Look preview container가 page를 언제 materialize하는지에 대한 문제다. Skia가 빠른 renderer가 되더라도 Quick Look container가 최초 load에서 전체 document를 요구하면 lazy preview 문제는 별도로 남는다.

## 제품 코드 정리

최종 제품 경로는 Stage 3 이전의 정책으로 돌아갔다.

- 단일 페이지 문서는 PNG reply를 유지한다.
- 다중 페이지 문서는 기존 PDF data reply를 유지한다.
- PDFKit lazy probe gate와 extension-side recorder는 제거했다.
- `Sources/RhwpCoreBridge`에는 AppKit/PDFKit/QuickLookUI 의존을 추가하지 않았다.

## 검증 결과

실행한 검증:

```bash
xcrun swift scripts/quicklook-pdfkit-lazy-probe.swift --pages 5 --output /private/tmp/rhwp-task87-pdfkit-probe
env ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 scripts/package-release.sh 0.2.0
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
qlmanage -p samples/hwp-multi-001.hwp
scripts/check-extension-registration-hygiene.sh --check-only
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
git diff --check
```

결과:

- standalone helper 실행과 summary 생성 성공.
- Release package 생성 성공. `rhwp-core.lock`의 staticlib byte hash와 로컬 산출물 hash mismatch는 lock 수정 없이 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`로 우회했다.
- Finder integration smoke 성공.
- Quick Look runtime probe summary 생성 성공.
- Stage 4 종료 후 probe gate flag 제거 확인.
- extension registration hygiene check 결과 issue 없음. 다만 PlugInKit provider path 미보고 warning은 관측됐다.
- `xcodegen generate`로 probe source 제거 상태를 project file에 반영했다.
- Debug build 성공. sandbox 안에서는 SwiftPM/clang module cache 쓰기 권한 문제로 실패했고, 권한 상승 재실행에서 `** BUILD SUCCEEDED **`를 확인했다.
- 최종 `git diff --check` 통과.

## 잔여 위험

- 실제 Quick Look runtime 관측은 `qlmanage -p`와 `samples/hwp-multi-001.hwp` 10페이지 샘플 기준이다. 다만 최초 load에서 이미 전체 page draw가 끝났으므로 lazy 가능성 판단에는 충분한 반례로 본다.
- `/Applications/Alhangeul.app`와 `/Users/melee/Applications/Alhangeul.app`가 동시에 있으면 provider routing이 흔들릴 수 있다. Stage 4에서는 기존 `/Applications` 등록을 임시 해제했다가 복원했다.
- `scripts/check-extension-registration-hygiene.sh`는 등록 issue 없음으로 보고했지만, PlugInKit path warning이 있어 Quick Look smoke 시 provider path를 별도로 확인하는 습관은 유지해야 한다.
- `PDFDocument`가 아닌 완전히 다른 Quick Look view 기반 API에서는 다른 결과가 나올 수 있다. 이 범위는 #88에서 별도 검증한다.

## 승인 요청 사항

본 최종 결과 보고서 기준으로 `publish/task87` 원격 게시와 `devel` 대상 draft PR 리뷰 및 merge 승인 여부를 확인한다. Merge 후에는 #87 close와 `publish/task87`, `local/task87`, 임시 worktree 정리를 별도 cleanup 절차로 진행한다.
