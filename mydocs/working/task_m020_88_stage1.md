# Task M020 #88 Stage 1 완료보고서

## 단계 개요

- 단계: Stage 1. View-based Quick Look API와 현행 구조 inventory
- 수행 범위: 제품 source 변경 없이 Quick Look SDK contract, 현행 data-based preview 구조, view-based 전환 방향, container 후보를 정리
- 결론: SDK/API inventory상 view-based 전환은 가능하다. 다만 작업지시자가 현재 Quick Look PDF preview UI 유지를 우선 요구했으므로, Stage 2는 `NSScrollView` 직접 page stack 전환이 아니라 `PDFView + PDFThumbnailView` view-based lazy 가능성 검증으로 보정한다.

## 현행 Quick Look preview 구조

현재 `Sources/QLExtension/HwpPreviewProvider.swift`는 `QLPreviewProvider, QLPreviewingController`를 구현하고, `providePreview(for:) async throws -> QLPreviewReply`에서 data reply를 생성한다.

흐름은 다음과 같다.

1. `HwpPreviewPDFRenderer.inspect(fileURL:)`가 파일 크기, 문서 open, page count, 첫 페이지 크기를 확인한다.
2. 단일 페이지는 `HwpPageImageRenderer.renderPage(document:pageIndex:)`로 첫 페이지를 렌더링한 뒤 `.png` `QLPreviewReply`를 반환한다.
3. 다중 페이지는 `HwpPreviewPDFRenderer.render(previewInfo:)`가 전체 page를 순회해 PDF data를 만든 뒤 `.pdf` `QLPreviewReply`를 반환한다.
4. known error는 `HwpDocumentFallbackClassifier.quickLookMessage(for:)`로 `.plainText` data reply를 반환한다.

`Sources/QLExtension/Info.plist`는 현재 다음 data-based 설정을 가진다.

| 항목 | 현재 값 | 판단 |
|---|---|---|
| `NSExtensionPointIdentifier` | `com.apple.quicklook.preview` | 유지 |
| `NSExtensionPrincipalClass` | `$(PRODUCT_MODULE_NAME).HwpPreviewProvider` | Stage 2에서 신규 view controller로 변경 |
| `QLIsDataBasedPreview` | `true` | Stage 2에서 제거 |
| `QLSupportedContentTypes` | HWP/HWPX UTI 6개 | 유지 |
| `QLSupportsSearchableItems` | `false` | 유지 |

`project.yml`의 `QLExtension` target은 `Sources/QLExtension`, `Sources/Shared`, `Sources/RhwpCoreBridge`를 source로 포함하고, `Frameworks/Rhwp.xcframework`와 CoreGraphics/ImageIO 등 기존 framework를 링크한다. 현재 source가 이미 `QuickLookUI`를 import하고 있으므로 Stage 2에서 신규 view controller source 추가 자체는 `project.yml` source path 변경이 필요 없다. 다만 build 결과가 autolink만으로 부족하면 Stage 2에서 `AppKit.framework` 또는 `QuickLookUI.framework` 명시 의존을 추가한다.

## SDK contract 확인

macOS SDK: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk`

`QuickLookUI.framework/Headers/QLPreviewingController.h` 기준 핵심 차이는 다음과 같다.

| 방식 | SDK 설명 | 구현 entrypoint |
|---|---|---|
| view-based preview | `QLPreviewingController`를 구현하는 view controller가 main preview를 표시 | `preparePreviewOfFile(at:completionHandler:)` |
| data-based preview | `QLPreviewProvider` subclass가 `QLPreviewReply`를 제공 | `providePreview(for:completionHandler:)` |

헤더 주석의 중요한 제약:

- file preview용 view-based controller는 `preparePreviewOfFileAtURL:completionHandler:`를 구현해야 한다.
- OS가 preview controller를 표시하기 전 main thread에서 한 번 호출한다.
- 장시간 작업은 main thread에서 수행하지 않는다.
- completion handler는 preview 사용 가능 시점을 OS에 알리며, OS는 그 전까지 loading spinner를 표시한다.
- preview duration 동안 file descriptor를 계속 열어두지 않는 편이 좋다.

Swift compile probe 결과:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/rhwp-task88-clang-cache \
  xcrun swift -e 'import QuickLookUI; import AppKit; final class Probe: NSViewController, QLPreviewingController { func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) { handler(nil) } } ; print(Probe.self)'
```

결과:

```text
Probe
```

의미:

- `NSViewController, QLPreviewingController` 조합은 현재 SDK/Swift 환경에서 compile 가능하다.
- Swift signature는 `func preparePreviewOfFile(at: URL, completionHandler: @escaping (Error?) -> Void)` 형태로 구현할 수 있다.
- sandbox 기본 clang module cache는 쓰기 권한 문제가 있어 probe에서는 `CLANG_MODULE_CACHE_PATH=/private/tmp/rhwp-task88-clang-cache`를 사용했다.

## Container 후보 비교

### 후보 A: `NSScrollView` + 직접 page stack

장점:

- visible rect를 직접 읽어 page index set을 계산할 수 있다.
- page placeholder, render task, cache entry, stale result discard를 page 단위로 제어할 수 있다.
- PDF data나 `PDFDocument`를 만들지 않으므로 #87에서 확인한 전체 materialization 위험을 피한다.
- `HwpPageImageRenderer.renderPage` 결과인 `CGImage`를 그대로 `CALayer.contents` 또는 custom `NSView.draw(_:)`에 연결할 수 있다.
- cache 상한과 adjacent prefetch 범위를 extension 메모리 정책에 맞게 좁게 잡을 수 있다.

단점:

- page layout, resize, placeholder, scroll observation을 직접 구현해야 한다.
- zoom이나 accessibility 같은 고급 preview 기능은 이번 범위에서 최소 구현으로 제한된다.

### 후보 B: `PDFView`

장점:

- page layout과 scroll UI를 PDFKit이 제공한다.
- 다중 페이지 navigation UI를 적은 코드로 얻을 수 있다.

단점:

- 결국 `PDFDocument`/`PDFPage` 구조를 요구하므로 #87에서 관측한 전체 page materialization 경로로 돌아갈 위험이 있다.
- visible page 중심 render scheduling과 cancellation을 제품 코드가 직접 제어하기 어렵다.
- `PDFView`가 내부 preload/cache를 수행하면 render event와 사용자 visible page의 대응이 불명확해진다.

### 선택 보정

순수 lazy scheduling control만 보면 `NSScrollView` + 직접 page stack이 가장 강하다. 그러나 이 방식은 현재 Quick Look PDF preview가 제공하는 main page, right thumbnail rail, PDF-like scroll/zoom 경험을 직접 다시 구현해야 한다.

작업지시자는 현재 스크린샷과 같은 PDF preview UI 유지를 우선 요구했다. 따라서 Stage 2 이후 기본 방향은 다음처럼 보정한다.

1. 먼저 `PDFView + PDFThumbnailView` view-based 경로가 lazy하게 동작하는지 검증한다.
2. 가능하면 현재 PDF UI와 유사한 사용자 경험을 유지하면서 성능을 개선한다.
3. 불가능하면 `NSScrollView` 직접 page stack으로 전환하지 않고, 현행 data-based PDF preview UI를 유지한 채 PDF 생성 성능 최적화를 진행한다.

## 재사용 경계

재사용:

- `RhwpDocument`: request별 document open, page count, page size, page render tree access
- `HwpPageImageRenderer.renderPage`: page 단위 image render
- `HwpPageImageRenderer.encodePNG`: view-based path에서는 기본 필요 없음. debug/export가 필요할 때만 사용
- `HwpDocumentFallbackClassifier`: known error를 view-based 오류 view message로 매핑
- `hwpQuickLookMaxFileSize`: view-based path에서도 같은 50 MB 제한 유지

부분 재사용 또는 분리:

- `HwpPreviewPDFRenderer.inspect(fileURL:)`: metadata load에 필요한 data read, `RhwpDocument` open, first page size 확인은 재사용 가능하다. 다만 이름이 PDF 전용이므로 Stage 3에서 view-based metadata helper를 `QLExtension` 또는 `Shared`로 분리하는 편이 낫다.
- `HwpPreviewPDFRenderer.render(previewInfo:)`: view-based 기본 path에서는 사용하지 않는다. PR 최종 전 unused data-based path가 남으면 삭제 또는 legacy fallback 유지 이유를 최종 보고서에 기록한다.
- `HwpPreviewProvider`: Stage 2에서는 비교/porting reference로 유지할 수 있지만 principal class에서는 제외한다. Stage 6에서 최종 유지/삭제를 결정한다.

이번 보정 후 기본 구현 후보에서 제외:

- `NSScrollView` 직접 page stack 제품화
- 직접 구현한 thumbnail rail/zoom UI

검증 후 제외 가능:

- `QLPreviewReply(forPDFWithPageSize:documentCreationBlock:)`는 #87에서 전체 materialization으로 확인되어 기본 후보가 아니다.
- `PDFView` 기반 lazy 구현은 Stage 2에서 별도 검증 후 채택 또는 제외한다.

## Stage 2 source 변경 범위 보정

확정 변경:

- 신규 `Sources/QLExtension/HwpPreviewPDFViewController.swift`
  - `NSViewController, QLPreviewingController`
  - `preparePreviewOfFile(at:completionHandler:)`
  - request generation token
  - task cancellation skeleton
  - `PDFView + PDFThumbnailView` probe UI
  - custom `PDFDocument`/`PDFPage` draw 관측 hook
- `Sources/QLExtension/Info.plist`
  - Stage 2 probe 범위에서 `QLIsDataBasedPreview` 제거 또는 복원 가능성을 기록
  - `NSExtensionPrincipalClass`를 probe view controller로 변경한 경우 Stage 2 결과에 따라 유지/복원
  - `QLSupportedContentTypes`, `QLSupportsSearchableItems`, extension point는 유지

조건부 변경:

- `project.yml`
  - 신규 source는 기존 `Sources/QLExtension` path에 자동 포함되므로 기본적으로 변경 불필요
  - build에서 autolink가 부족하다고 확인될 때만 `AppKit.framework`, `QuickLookUI.framework`, `PDFKit.framework` 명시 추가
- `Sources/QLExtension/HwpPreviewProvider.swift`
  - Stage 2에서는 삭제하지 않고 fallback/reference로 유지
  - `PDFView` lazy가 불가능하다고 판단되면 현행 data-based PDF preview 최적화 대상이 된다.

Stage 2에서는 제품 전환을 확정하지 않고, `PDFView + PDFThumbnailView`가 현재 PDF UI 유지와 lazy render를 동시에 만족할 수 있는지 관측하는 것을 목표로 한다.

## 검증 결과

실행한 명령:

```bash
rg -n "QLPreviewProvider|QLPreviewingController|providePreview|preparePreview|QLIsDataBasedPreview|NSExtensionPrincipalClass|QLSupportedContentTypes" \
  Sources/QLExtension project.yml
sed -n '1,130p' /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk/System/Library/Frameworks/QuickLookUI.framework/Versions/A/Headers/QLPreviewingController.h
env CLANG_MODULE_CACHE_PATH=/private/tmp/rhwp-task88-clang-cache \
  xcrun swift -e 'import QuickLookUI; import AppKit; final class Probe: NSViewController, QLPreviewingController { func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) { handler(nil) } } ; print(Probe.self)'
env CLANG_MODULE_CACHE_PATH=/private/tmp/rhwp-task88-clang-cache \
  xcrun swift -e 'import PDFKit; import AppKit; final class Probe: PDFView {} ; print(Probe.self)'
env CLANG_MODULE_CACHE_PATH=/private/tmp/rhwp-task88-clang-cache \
  xcrun swift -e 'import AppKit; final class ProbeScroll: NSScrollView {} ; print(ProbeScroll.self)'
find Sources/QLExtension -maxdepth 3 -type f -print
```

결과:

- `rg` 결과에서 data-based marker는 `Sources/QLExtension/Info.plist`의 `QLIsDataBasedPreview`, principal class는 `HwpPreviewProvider`, source entrypoint는 `providePreview(for:)`로 확인됐다.
- SDK header에서 view-based와 data-based preview의 entrypoint 차이를 확인했다.
- `NSViewController, QLPreviewingController` compile probe가 `Probe`를 출력했다.
- `PDFView`와 `NSScrollView` compile probe도 각각 성공했다. 최초 inventory 기준 scheduling control은 `NSScrollView`가 강했지만, 작업지시자 피드백에 따라 현재 PDF UI 유지를 우선해 `PDFView + PDFThumbnailView`를 먼저 검증하는 방향으로 보정했다.
- `Sources/QLExtension`에는 현재 provider, plist, entitlements, localized InfoPlist strings만 있다. Stage 2 신규 source 추가가 기존 파일 구조와 충돌하지 않는다.

## 잔여 리스크

- `QLIsDataBasedPreview` 제거 후 실제 LaunchServices/PlugInKit runtime이 view-based principal class를 정상 선택하는지는 Stage 5 Release package smoke에서 확인해야 한다.
- `preparePreviewOfFile(at:)` completion handler 호출 시점을 너무 늦추면 Quick Look spinner가 길어지고, 너무 빠르면 빈 placeholder가 먼저 보일 수 있다. Stage 2-3에서 loading view와 첫 page readiness 균형을 조정한다.
- `HwpPreviewPDFRenderer.inspect` 이름이 PDF 전용이라 view-based path에 그대로 쓰면 구조 의도가 흐려진다. Stage 3에서 metadata helper 분리를 우선 검토한다.
- `PDFView + PDFThumbnailView`가 view-based 환경에서도 전체 materialization을 유도하면 lazy 성능 개선은 어려울 수 있다. 이 경우 커스텀 UI로 전환하지 않고 현행 PDF UI를 유지하며 PDF 생성 성능 최적화로 진행한다.

## 승인 요청 사항

Stage 1 보정 결과 기준으로 Stage 2 `PDFView + PDFThumbnailView view-based lazy 가능성 검증` 진행 승인을 요청한다. Stage 2에서는 현재 PDF preview UI 유지 가능성과 `PDFView` lazy draw 여부를 검증하고, 불가능하면 현행 data-based PDF preview 생성 최적화로 전환한다.
