# Task M020 #88 최종 결과보고서

## 작업 개요

- 이슈: #88 View-based Quick Look preview visible-page lazy rendering 전환
- 브랜치: `local/task88`
- 최종 선택: 현재 Quick Look PDF UI 유지 + data-based PDF 생성 최적화
- 핵심 변경: Quick Look preview와 HostApp PDF export에서 중복 `RhwpDocument` open 제거

## 최종 결론

`PDFView + PDFThumbnailView` view-based lazy 경로는 제품화하지 않았다.

이유:

- 작업지시자가 스크린샷처럼 현재 macOS Quick Look PDF preview UI 유지를 우선 요구했다.
- `PDFView + PDFThumbnailView` prototype은 compile 가능했지만, 시스템 PDF preview UI를 그대로 쓰는 경로가 아니라 extension 내부에서 PDFKit UI를 직접 구성하는 방식이다.
- 이 머신의 Quick Look runtime에서는 Debug/installed provider routing이 흔들려 `PDFView` lazy draw를 확정할 runtime 증거를 확보하지 못했다.

따라서 현행 `QLPreviewReply(dataOfContentType: .pdf)` 경로를 유지해 현재 PDF UI를 보존하고, 생성 비용 중 확실히 줄일 수 있는 중복 document open을 제거했다.

## 구현 요약

### 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/Shared/HwpPreviewPDFRenderer.swift` | `HwpPreviewDocumentContext`, `load(fileURL:)`, `render(context:)`를 추가해 열린 `RhwpDocument`를 재사용하도록 변경 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | Quick Look preview가 `load(fileURL:)` context를 사용해 PNG/PDF reply를 생성하도록 변경 |
| `Sources/HostApp/Services/RhwpStudioPDFExportController.swift` | HostApp PDF export에서 이미 연 `RhwpDocument`를 PDF renderer에 직접 전달하도록 변경 |
| `Sources/QLExtension/Info.plist`, `project.yml` | Stage 2 probe 후 data-based provider 설정과 dependency를 원상 경로로 확정 |
| `mydocs/plans`, `mydocs/working`, `mydocs/report`, `mydocs/orders` | 수행계획, 구현계획, 단계 보고서, 최종 보고서, 오늘할일 상태 정리 |

### 유지한 동작

- `Sources/QLExtension/Info.plist`
  - `QLIsDataBasedPreview=true` 유지
  - `NSExtensionPrincipalClass=AlhangeulPreview.HwpPreviewProvider` 유지
- 다중 page HWP/HWPX는 `.pdf` data reply로 Quick Look에 전달한다.
- 단일 page는 기존처럼 `.png` data reply를 사용한다.
- Thumbnail extension 경로는 변경하지 않았다.
- #256 Skia optional backend는 이번 작업에서 기본값으로 켜지지 않았다.

### 변경한 동작

- `Sources/Shared/HwpPreviewPDFRenderer.swift`
  - `HwpPreviewDocumentContext` 추가
  - `load(fileURL:)` 추가: file data, filename, page count, first page size, 열린 `RhwpDocument`를 한 번에 반환
  - `render(context:)` 추가
  - `render(document:pageCount:contentSize:)`를 내부 재사용 가능 API로 노출
- `Sources/QLExtension/HwpPreviewProvider.swift`
  - 기존 `inspect(fileURL:)` 후 재-open 방식에서 `load(fileURL:)` context 재사용 방식으로 변경
- `Sources/HostApp/Services/RhwpStudioPDFExportController.swift`
  - 이미 연 `RhwpDocument`를 PDF renderer에 직접 넘겨 PDF export 중복 open 제거
- 문서
  - `mydocs/plans/task_m020_88.md`
  - `mydocs/tech/project_architecture.md`
  - `mydocs/working/task_m020_88_stage1.md` ~ `stage5.md`

## 성능 개선 범위

중복 open 제거:

| 경로 | 변경 전 | 변경 후 |
|------|---------|---------|
| Quick Look 단일 page PNG preview | `RhwpDocument` open 2회 | `RhwpDocument` open 1회 |
| Quick Look 다중 page PDF preview | `RhwpDocument` open 2회 | `RhwpDocument` open 1회 |
| HostApp PDF export | `RhwpDocument` open 2회 | `RhwpDocument` open 1회 |

전체 page bitmap rendering과 PDF page 작성은 기존과 같은 구조다. 따라서 true visible-page lazy rendering은 이번 최종 경로에서 제공하지 않는다.

## 검증 결과

### Build/정적 검증

성공:

```bash
./scripts/check-no-appkit.sh
git diff --check
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  build
./scripts/validate-stage3-render.sh \
  output/task88-stage4-render \
  samples/basic/KTX.hwp \
  samples/hwp-multi-001.hwp
```

주요 결과:

- QLExtension Debug build 성공: `** BUILD SUCCEEDED ** [6.272 sec]`
- HostApp Debug build 성공: `** BUILD SUCCEEDED ** [0.595 sec]`
- render smoke 성공:
  - `OK KTX.hwp`
  - `OK hwp-multi-001.hwp`

### Release Finder smoke

성공:

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  scripts/smoke-finder-integration.sh \
  --version 0.2.0 \
  --output-dir /private/tmp/rhwp-task88-finder-smoke
```

결과:

```text
OK: Finder integration smoke passed
Installed app: /Users/melee/Applications/Alhangeul.app
Output: /private/tmp/rhwp-task88-finder-smoke/task151-20260520-234427
Diagnostics: /private/tmp/rhwp-task88-finder-smoke/task151-20260520-234427/diagnostics
```

HWP/HWPX thumbnail smoke 산출물도 생성됐다.

### Registration hygiene

부분 실패:

- PlugInKit active provider:
  - `/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`
  - `/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex`
- `scripts/check-extension-registration-hygiene.sh --check-only`는 LaunchServices stale development registration 때문에 실패했다.
- generated app bundle 파일을 제거하고 `lsregister -gc`를 실행했지만 LaunchServices dump에는 stale path가 남았다.
- global LaunchServices database delete/reset은 재부팅과 사용자 환경 영향이 커서 수행하지 않았다.

### Manual preview

`qlmanage -p samples/hwp-multi-001.hwp`는 preview session을 열었지만 unified log의 extension launch path는 `/Applications/Alhangeul.app`로 기록됐다. 이 로컬 머신에는 `/Applications/Alhangeul.app` 설치본과 `/Users/melee/Applications/Alhangeul.app` smoke 설치본이 동시에 존재해 manual preview path가 흔들린다.

따라서 이번 환경에서 새 bundle의 preview latency 수치 측정은 완료하지 못했다.

## 단계별 산출물

- Stage 1: `mydocs/working/task_m020_88_stage1.md`
- Stage 2: `mydocs/working/task_m020_88_stage2.md`
- Stage 3: `mydocs/working/task_m020_88_stage3.md`
- Stage 4: `mydocs/working/task_m020_88_stage4.md`
- Stage 5: `mydocs/working/task_m020_88_stage5.md`

## 잔여 리스크

- data-based PDF reply 구조를 유지하므로 true visible-page lazy rendering은 해결되지 않았다.
- 다중 page 문서 총 생성 시간은 여전히 전체 page render 비용에 좌우된다.
- 이 머신에서는 `/Applications/Alhangeul.app`와 LaunchServices stale registration 때문에 manual preview path가 흔들린다.
- 정확한 preview latency 측정은 `/Applications/Alhangeul.app`를 임시 unregister/교체한 격리 환경에서 다시 수행해야 한다.

## 후속 제안

- 별도 task에서 Release smoke 환경을 더 격리해 `/Applications` 설치본 충돌 없이 `qlmanage -p` path와 latency를 측정한다.
- true lazy preview가 다시 필요하면 시스템 PDF UI 포기를 전제로 `NSScrollView` 직접 page stack 또는 별도 native viewer UX를 새 task로 다룬다.

## 작업지시자 승인 요청

현재 결과 기준으로 PR 게시 승인을 요청한다. PR에는 `PDFView` lazy 미채택 사유, 현재 PDF UI 유지 경로, 중복 `RhwpDocument` open 제거, LaunchServices stale registration 잔여 리스크를 명확히 포함한다.
