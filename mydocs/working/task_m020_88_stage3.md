# Task M020 #88 Stage 3 완료보고서

## 단계 개요

- 단계: Stage 3. 결정 게이트와 구현 경로 확정
- 수행 범위: Stage 2 probe 결과와 작업지시자의 UI 유지 요구를 기준으로 제품화 경로를 결정하고, source 상태를 결정 경로에 맞게 정리
- 결론: `PDFView + PDFThumbnailView` view-based 경로는 제품화하지 않는다. 현재 macOS Quick Look PDF preview UI를 유지하기 위해 data-based `.pdf` `QLPreviewReply` 경로를 유지하고, 다음 단계에서 PDF 생성 비용 최적화를 진행한다.

## 결정 근거

Stage 2에서 확인한 사실:

- `NSViewController, QLPreviewingController`와 `PDFView + PDFThumbnailView` prototype은 compile 가능했다.
- 그러나 이 방식은 Quick Look이 PDF data reply에 제공하는 기존 시스템 PDF preview UI를 그대로 쓰는 것이 아니라, extension이 `PDFView`와 thumbnail rail을 직접 구성하는 방식이다.
- PluginKit registry는 Debug build path를 가리켰지만, `qlmanage -p samples/hwp-multi-001.hwp` runtime log는 `/Applications/Alhangeul.app` 안의 기존 extension을 실행한 것으로 기록했다.
- 따라서 Quick Look view-based 환경에서 `PDFView`가 visible page 중심 lazy draw를 보장한다는 runtime 증거를 확보하지 못했다.

작업지시자는 스크린샷처럼 현재 PDF preview UI 유지를 우선 요구했다. 이 기준에서는 lazy 가능성이 불확실한 `PDFView` 제품화보다 현행 data-based PDF preview UI를 유지하는 편이 안전하다.

## source 정리

Stage 2 probe를 제품 경로에서 제거했다.

- `Sources/QLExtension/Info.plist`
  - `NSExtensionPrincipalClass`를 `$(PRODUCT_MODULE_NAME).HwpPreviewProvider`로 복원했다.
  - `QLIsDataBasedPreview=true`를 복원했다.
- `project.yml`
  - QLExtension의 `PDFKit.framework` 의존성을 제거했다.
- `Sources/QLExtension/HwpPDFViewLazyProbe.swift`
  - probe source를 제거했다.
- `Sources/QLExtension/HwpPreviewPDFViewController.swift`
  - probe view controller source를 제거했다.
- `xcodegen generate`
  - `Alhangeul.xcodeproj`를 `project.yml` 기준으로 재생성했다.

## 확정 경로

Stage 4는 다음 범위로 진행한다.

- 현재 Quick Look PDF UI는 유지한다.
- `HwpPreviewProvider`의 `.pdf` data reply와 `.png` 단일 page reply 구조는 유지한다.
- `HwpPreviewPDFRenderer.inspect(fileURL:)` 후 `render(previewInfo:)` 또는 `pngReply(_:)`에서 같은 file data를 다시 `RhwpDocument`로 여는 중복 비용을 줄인다.
- renderer backend 기본값은 기존처럼 `coreGraphicsOnly`로 유지한다. #256의 Skia opt-in 기본 전환은 이번 단계에서 다루지 않는다.
- fallback message와 Thumbnail extension 경로는 변경하지 않는다.

## 검증

실행한 명령:

```bash
xcodegen generate
rg -n "PDFKit|HwpPreviewPDFViewController|HwpPDFViewLazyProbe|QLIsDataBasedPreview|NSExtensionPrincipalClass" \
  project.yml Sources/QLExtension Alhangeul.xcodeproj/project.pbxproj
git diff --check
```

예상 상태:

- `QLIsDataBasedPreview`는 `Sources/QLExtension/Info.plist`에 존재한다.
- `NSExtensionPrincipalClass`는 `HwpPreviewProvider`를 가리킨다.
- `PDFKit`, `HwpPreviewPDFViewController`, `HwpPDFViewLazyProbe`는 제품 source/project에서 사라진다.

build 검증은 Stage 4 최적화 변경 후 함께 수행한다.

## 다음 단계

Stage 4에서 current PDF UI 유지 경로의 실제 성능 개선을 구현한다. 우선순위는 중복 document open 제거다.
