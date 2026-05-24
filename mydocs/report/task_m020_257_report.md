# Task M020 #257 최종 보고서

## 작업 개요

- 이슈: #257 Quick Look preview에서 Skia PNG backend 적용과 다중 페이지 PDF fallback 검증
- 마일스톤: M020 `v0.2.x Skia Quick Look/Thumbnail Backend`
- 브랜치: `local/task257`
- 목표: Quick Look preview의 단일 페이지 PNG reply와 다중 페이지 bitmap PDF preview에서 #256 Shared renderer의 `skiaOptIn` backend를 적용하고, 실패 시 CoreGraphics fallback과 기존 text fallback 정책이 유지되는지 검증한다.

## 완료 범위

- 단일 페이지 Quick Look PNG reply가 `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)`을 사용하도록 변경했다.
- PNG reply에 render diagnostics 로그를 추가했다.
- 다중 페이지 Quick Look PDF renderer가 `HwpPageRenderPolicy`를 받을 수 있게 했다.
- Quick Look PDF path에서 `policy: .skiaOptIn`을 명시하도록 변경했다.
- PDF page별 `HwpPageRenderDiagnostics`는 Quick Look/smoke path에서만 `collectDiagnostics: true`로 수집한다.
- PDF reply에 backend별 page count, fallback count, Skia PNG bytes, render duration summary 로그를 추가했다.
- Quick Look policy smoke helper를 추가해 `.coreGraphicsOnly`와 `.skiaOptIn` 결과를 같은 입력 문서에서 비교할 수 있게 했다.
- 대표 단일/다중 샘플에서 Skia opt-in 성공과 fallback count를 기록했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|---|---|
| `Sources/QLExtension/HwpPreviewProvider.swift` | 단일 PNG와 다중 PDF Quick Look reply에서 `skiaOptIn` policy 명시, PNG/PDF diagnostics logging 추가 |
| `Sources/Shared/HwpPreviewPDFRenderer.swift` | PDF render API에 `policy`와 `collectDiagnostics` 기본 인자 추가, page별 diagnostics opt-in 수집 |
| `scripts/smoke-quicklook-skia-policy.sh` | Quick Look policy smoke wrapper 추가 |
| `scripts/quicklook_skia_policy_smoke.swift` | CoreGraphics/Skia opt-in reply shape, backend, fallback, latency, byte count 측정 helper 추가 |
| `mydocs/plans/task_m020_257_impl.md` | 구현계획서 |
| `mydocs/working/task_m020_257_stage1.md` | Quick Look 호출부 inventory |
| `mydocs/working/task_m020_257_stage2.md` | 단일 PNG Skia opt-in 적용 보고 |
| `mydocs/working/task_m020_257_stage3.md` | 다중 PDF Skia opt-in 연결 보고 |
| `mydocs/working/task_m020_257_stage4.md` | smoke 결과와 known limitation 정리 |
| `mydocs/orders/20260521.md`, `mydocs/orders/20260522.md` | 작업 상태 기록과 완료 처리 |

## 단계별 결과

| 단계 | 커밋 | 요약 |
|---|---|---|
| 시작 | `0d18560` | 수행계획서와 2026-05-21 오늘할일 작성 |
| Stage 1 | `e104c74` | Quick Look 단일 PNG, 다중 PDF, fallback 흐름 inventory와 구현계획서 작성 |
| Stage 2 | `5df3e1f` | 단일 페이지 PNG reply에 `skiaOptIn` 적용, diagnostics logging 추가 |
| Stage 3 | `b044ed6` | 다중 페이지 PDF renderer에 policy 인자와 page diagnostics 추가, Quick Look PDF path에 `skiaOptIn` 적용 |
| Stage 4 | `49a0ad3` | Quick Look policy smoke helper 추가, 단일/다중 대표 샘플 smoke 기록 |
| Stage 5 | 최종 보고서 커밋 | 최종 보고서와 오늘할일 완료 처리 |

## 최종 동작

### 단일 페이지 PNG

Quick Look 단일 페이지 문서는 PNG reply를 유지한다. 내부 page image 생성은 `skiaOptIn` policy를 사용한다.

1. Skia PNG render 시도
2. PNG decode 성공 시 `.skia` backend image 반환
3. Skia 실패, 빈 PNG, PNG decode 실패 시 CoreGraphics fallback
4. CoreGraphics fallback까지 실패한 경우에만 기존 `HwpDocumentFallbackClassifier` text reply 흐름 사용

### 다중 페이지 PDF

Quick Look 다중 페이지 문서는 기존처럼 bitmap PDF container를 유지한다. 각 page image 생성만 `skiaOptIn` policy를 사용한다.

- 모든 page는 `HwpPreviewPDFRenderer.render(..., policy: .skiaOptIn, collectDiagnostics: true)` 내부에서 `HwpPageImageRenderer.renderPage`를 통해 생성된다.
- Quick Look PDF path의 page별 backend/fallback 결과는 `HwpRenderedPreviewPDF.pageDiagnostics`에 남는다.
- Quick Look provider는 PDF 전체 summary 로그를 남긴다.

## Smoke 결과

Stage 4 helper smoke 결과:

| 샘플 | Reply | Pages | CG backend | Skia backend | Skia fallback | CG bytes | Skia bytes | Skia PNG bytes | CG seconds | Skia seconds |
|---|---|---:|---|---|---:|---:|---:|---:|---:|---:|
| `request.hwp` | png | 1 | cg:1 | skia:1 | 0 | 82129 | 85981 | 88793 | 1.081279 | 0.095356 |
| `KTX.hwp` | png | 1 | cg:1 | skia:1 | 0 | 555392 | 181146 | 165799 | 0.067094 | 0.073160 |
| `복학원서.hwp` | png | 1 | cg:1 | skia:1 | 0 | 233831 | 225105 | 240643 | 0.412763 | 0.062871 |
| `hwp-multi-001.hwp` | pdf | 10 | cg:10 | skia:10 | 0 | 1522638 | 1119989 | 1309516 | 0.404578 | 0.677783 |
| `hwpx-01.hwpx` | pdf | 9 | cg:9 | skia:9 | 0 | 1489442 | 1094246 | 1316036 | 0.353663 | 0.623360 |

결론:

- 단일 페이지 PNG 샘플 3개 모두 Skia backend로 성공했고 fallback은 없었다.
- 다중 페이지 PDF 샘플 2개 모두 모든 page가 Skia backend로 성공했고 fallback은 없었다.
- 다중 페이지 PDF Skia path는 대표 샘플에서 CoreGraphics baseline보다 느렸다. default 전환 판단은 #259에서 별도로 해야 한다.

산출물:

- `output/task257-stage4/`
- `output/task257-skia-policy/`
- `output/task257-quicklook-pdf/`

`output/`은 commit 대상이 아니다.

## 최종 검증

Stage 4 및 Stage 5에서 다음 검증을 수행했다.

```bash
./scripts/check-no-appkit.sh
rg -n "#257|skiaOptIn|backendUsed|fallbackReason|Quick Look|#258|#259|#278" \
  mydocs/report/task_m020_257_report.md mydocs/orders/20260522.md Sources/QLExtension Sources/Shared
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
git diff --check
git status --short --branch
```

결과:

| 명령 | 결과 |
|---|---|
| `./scripts/check-no-appkit.sh` | 통과 |
| `rg -n "#257\|skiaOptIn\|backendUsed\|fallbackReason\|Quick Look\|#258\|#259\|#278" ...` | 통과 |
| `xcodebuild ... QLExtension ... build` | 통과 |
| `xcodebuild ... HostApp ... build` | 통과 |
| `git diff --check` | 통과 |
| `git status --short --branch` | 최종 커밋 후 작업 트리 clean 확인 |

Stage 2/3의 sandbox 내부 xcodebuild는 사용자 Swift/clang cache 쓰기 제한으로 실패한 뒤 sandbox 밖 재실행에서 통과했다. Stage 4/5 build는 같은 cache 제한을 피하기 위해 sandbox 밖에서 실행했다.

## Known limitations

- 이번 작업은 Debug/helper smoke 기준이다. 설치본 Quick Look UI smoke와 LaunchServices/PlugInKit 등록 검증은 release/package smoke에서 별도로 해석해야 한다.
- Skia fallback을 강제로 유발하는 fixture는 이번 작업에서 만들지 않았다. fallback 동작은 #256 Shared renderer contract, code path, smoke의 fallback count 0 결과로 확인했다.
- 단일 페이지 PNG reply는 Skia PNG를 `CGImage`로 decode한 뒤 다시 PNG로 encode한다. direct PNG reply 최적화는 별도 후속 후보다.
- 다중 페이지 PDF Skia path는 모든 page에서 성공했지만 CoreGraphics보다 느린 대표 샘플이 있어, default 전환은 #259 readiness gate에서 판단해야 한다.
- 현재 core pin은 새 upstream rhwp release를 반영하지 않는다. #947/#976/#982/#1018 포함 release tag 반영과 회귀 확인은 #278에서 처리한다.

## Handoff

### #258 Finder thumbnail

- #257의 `HwpPageImageRenderer` diagnostics logging 방식과 policy smoke helper 결과를 참고할 수 있다.
- Thumbnail에서는 cache key에 backend/render signature를 포함해야 하므로 #257의 PDF diagnostics와 별개로 cache 정책을 고정해야 한다.
- Thumbnail은 요청 크기 기반 `max_dimension` 또는 scale mapping이 핵심이다.

### #259 Readiness gate

- Quick Look 단일 PNG는 대표 샘플에서 Skia fallback 없이 성공했다.
- Quick Look 다중 PDF도 대표 샘플에서 모든 page가 Skia backend로 성공했다.
- 다중 PDF Skia path latency가 CoreGraphics보다 느린 샘플이 있으므로 default 전환 판단에는 성능 gate가 필요하다.
- 설치본 smoke와 package/memory 측정은 #259 입력으로 남긴다.

### #278 새 rhwp release 반영

- 이번 작업은 현재 pin 기준으로 Quick Look Skia path를 연결했다.
- upstream #947/#976/#982/#1018 반영 확인은 새 rhwp release tag가 나온 뒤 #278에서 수행한다.
- Swift CoreGraphics renderer에 PUA/image/watermark 보정 로직은 포팅하지 않았다.

## 결론

#257은 Quick Look preview surface에서 Skia PNG backend를 opt-in 경로로 연결했다. 단일 페이지 PNG와 다중 페이지 PDF 모두 `skiaOptIn` policy를 사용하며, 실패 시 #256 Shared renderer의 CoreGraphics fallback contract를 따른다. 대표 샘플 smoke에서는 단일/다중 모두 Skia backend가 fallback 없이 성공했다.

다만 다중 페이지 PDF의 Skia path는 일부 샘플에서 CoreGraphics baseline보다 느리므로, release default 전환은 #259 readiness gate의 visual/performance/package 결과를 보고 별도로 판단해야 한다.
