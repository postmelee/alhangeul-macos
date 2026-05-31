# Task M020 #88 Stage 2 완료보고서

## 단계 개요

- 단계: Stage 2. `PDFView + PDFThumbnailView` view-based lazy 가능성 검증
- 수행 범위: 현재 PDF preview와 유사한 main page + right thumbnail rail 구성을 `NSViewController, QLPreviewingController` 기반으로 prototype 구현하고, `PDFView`가 lazy draw 관측 대상이 될 수 있는지 확인
- 결론: source/build 수준에서 `PDFView + PDFThumbnailView` prototype은 가능하다. 그러나 현재 Quick Look 시스템 PDF preview UI를 그대로 유지하는 경로는 아니며, runtime smoke에서 Debug provider가 안정적으로 선택되지 않아 lazy 판정 증거도 충분하지 않았다. 따라서 사용자 지시 기준으로 `PDFView` 제품화는 채택하지 않고, 다음 단계는 현재 data-based PDF UI 유지 + PDF 생성 최적화로 전환한다.

## 구현 내용

### 신규 view-based prototype

`Sources/QLExtension/HwpPreviewPDFViewController.swift`를 추가했다.

- `NSViewController, QLPreviewingController` 조합으로 `preparePreviewOfFile(at:completionHandler:)`를 구현했다.
- root view 내부에 `PDFView`와 `PDFThumbnailView`를 배치해 현재 Quick Look PDF preview와 유사한 큰 page 영역 + 오른쪽 thumbnail rail 구조를 구성했다.
- request `generation`과 `DispatchWorkItem`을 둬 빠른 파일 전환 시 이전 metadata 결과가 새 preview에 반영되지 않도록 했다.
- metadata load 실패 시 기존 `HwpDocumentFallbackClassifier` 메시지를 status label로 표시하도록 했다.

### Lazy draw probe

`Sources/QLExtension/HwpPDFViewLazyProbe.swift`를 추가했다.

- `HwpPreviewPDFRenderer.inspect(fileURL:)`로 실제 HWP/HWPX page count와 첫 page size를 읽는다.
- 각 page마다 custom `PDFPage`를 만들고 `draw(with:to:)`에서 `page-init`, `draw-begin`, `draw-end` 이벤트를 `Logger.notice`로 기록한다.
- prototype은 실제 문서 내용을 그리지 않고, lazy 여부 관측을 위한 synthetic page marker만 그린다.

### Quick Look 설정

Stage 2 probe 범위에서 `Sources/QLExtension/Info.plist`를 view-based principal class로 바꿨다.

| 항목 | Stage 1 값 | Stage 2 probe 값 |
|---|---|---|
| `NSExtensionPrincipalClass` | `$(PRODUCT_MODULE_NAME).HwpPreviewProvider` | `$(PRODUCT_MODULE_NAME).HwpPreviewPDFViewController` |
| `QLIsDataBasedPreview` | `true` | 제거 |

`project.yml`에는 QLExtension target 의존성으로 `PDFKit.framework`를 추가했다. 이후 `xcodegen generate`로 `Alhangeul.xcodeproj`를 재생성했다.

기존 `Sources/QLExtension/HwpPreviewProvider.swift`는 삭제하지 않았다. data-based PDF/PNG reply 구현은 다음 단계의 fallback 및 최적화 대상이다.

## 검증 결과

실행한 명령:

```bash
xcodegen generate
./scripts/check-no-appkit.sh
git diff --check
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  build
qlmanage -r cache
qlmanage -r
perl -e 'alarm 8; exec @ARGV' qlmanage -p samples/hwp-multi-001.hwp
/usr/bin/log show --style compact --last 1m \
  --predicate 'subsystem == "com.postmelee.alhangeul.QLExtension" OR process CONTAINS "AlhangeulPreview"'
pluginkit -m -A -v -i com.postmelee.alhangeul.QLExtension
```

결과:

- `xcodegen generate` 성공.
- `./scripts/check-no-appkit.sh` 성공: `OK: shared Swift code has no AppKit/UIKit dependencies`.
- `git diff --check` 성공.
- 최초 sandbox build는 SwiftPM/Xcode cache 경로 쓰기 제한으로 실패했다. 권한 승격 후 같은 QLExtension Debug build는 성공했다.
- 권한 승격 build 결과: `** BUILD SUCCEEDED ** [4.200 sec]`.
- build 중 QLExtension, ThumbnailExtension, HostApp이 함께 build/sign/register 됐다.
- `pluginkit -m -A -v -i com.postmelee.alhangeul.QLExtension` 결과는 Debug build path를 가리켰다.
- 그러나 `qlmanage -p samples/hwp-multi-001.hwp` 후 unified log는 실제 실행된 extension path를 `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`로 기록했다.
- probe가 기록해야 하는 `PDFView probe prepare`, `PDFView probe installed`, `PDFView lazy probe` 이벤트는 runtime log에 나타나지 않았다.

## 판단

`PDFView + PDFThumbnailView`는 source/build 수준에서 view-based Quick Look controller로 붙일 수 있다. 다만 이번 사용자 지시의 핵심은 스크린샷처럼 macOS Quick Look이 PDF data reply에 제공하는 현재 PDF preview UI를 유지하는 것이다.

Stage 2 prototype은 다음 두 이유로 제품화 경로로 채택하지 않는다.

1. 현재 시스템 PDF preview UI를 그대로 쓰는 것이 아니라, extension 내부에 `PDFView`와 `PDFThumbnailView`를 직접 배치하는 방식이다. page/thumbnail 배치는 비슷하게 만들 수 있지만 Quick Look의 기존 PDF preview UI와 완전히 같은 경로는 아니다.
2. Debug provider 등록과 실제 Quick Look provider 실행 경로가 엇갈려, `PDFView`가 Quick Look view-based 환경에서 visible page 중심으로 lazy draw를 요청한다는 runtime 증거를 확보하지 못했다.

따라서 Stage 3 결정은 `PDFView` lazy 제품화가 아니라 현재 data-based PDF reply 경로 유지로 잡는다. Stage 4에서는 `HwpPreviewProvider`/`HwpPreviewPDFRenderer`의 중복 document open과 PDF 생성 비용을 줄이는 방향으로 진행한다.

## 다음 단계

- `Info.plist`를 현행 data-based provider 설정으로 복원한다.
- Stage 2 probe source와 `PDFKit.framework` 의존성은 제품 경로에서 제거한다.
- 현재 Quick Look PDF UI는 `QLPreviewReply(dataOfContentType: .pdf)`를 유지해 보존한다.
- `HwpPreviewPDFRenderer.inspect` 후 `render(previewInfo:)`에서 `RhwpDocument`를 다시 여는 중복 비용을 줄이는 최적화를 우선 구현한다.
