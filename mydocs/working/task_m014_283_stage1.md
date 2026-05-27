# Task M014 #283 Stage 1 보고서 - open pipeline inventory 정리

## 단계 개요

- 이슈: #283 rhwp-studio 문서 열기 normalization·external image parity 영향 조사
- 단계: Stage 1. open pipeline inventory와 조사 기준 확정
- 목표: HostApp `rhwp-studio`, Quick Look, Thumbnail, Shared native renderer의 문서 open path를 파일/함수 단위로 정리하고 Stage 2-3 조사 기준을 고정한다.

이번 단계는 조사와 문서화만 수행했다. production renderer, bridge, bundled `rhwp-studio` asset은 수정하지 않았다.

## 현재 open pipeline inventory

| 영역 | 파일/함수 | 입력 전달 | base directory 전달 | 관찰 |
|---|---|---|---|---|
| HostApp store | `Sources/HostApp/Stores/DocumentViewerStore.swift` `loadDocument(from:)` | security scoped `URL`에서 `Data(contentsOf:)`, `url.lastPathComponent` | 없음 | `RecentDocumentItem`은 reveal/save용 source로 저장되지만 Studio payload에는 포함되지 않는다. |
| HostApp payload | `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift` | `data`, `filename`, `revision` | 없음 | payload type 자체가 bytes, filename, revision만 가진다. |
| Studio entry URL | `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` `loadURL(for:)` | `url=alhangeul-document://current?revision=...`, `filename=...` query | 없음 | Web/WASM open path에는 current document scheme URL과 filename만 전달된다. |
| Studio document bytes | `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift` | current revision payload bytes | 없음 | `application/octet-stream`, `Cache-Control: no-store`, CORS header로 bytes를 응답한다. |
| Studio WebView | `Sources/HostApp/Views/RhwpStudioWebView.swift` coordinator `update(...)` | documentProvider에 payload 설정 후 `RhwpStudioResourceLocator.loadURL(for:)` 로드 | 없음 | `sourceDocument`는 Swift side save/reveal/share 흐름에 남고 JS query로 전달되지 않는다. |
| Shared PDF preview | `Sources/Shared/HwpPreviewPDFRenderer.swift` `load(fileURL:)`, `inspect(fileURL:)` | `Data(contentsOf: fileURL, options: [.mappedIfSafe])`, `fileURL.lastPathComponent` | 없음 | `RhwpDocument(data:filename:)`를 직접 만든 뒤 page count와 page size를 확인한다. |
| Shared page image | `Sources/Shared/HwpPageImageRenderer.swift` `renderFirstPage(fileURL:...)` | `Data(contentsOf: fileURL, options: [.mappedIfSafe])`, `fileURL.lastPathComponent` | 없음 | Thumbnail 경로의 첫 페이지 render도 같은 `RhwpDocument(data:filename:)` 생성 경로다. |
| Quick Look | `Sources/QLExtension/HwpPreviewProvider.swift` `providePreview` | request `fileURL`을 Shared PDF renderer에 전달 | 없음 | 단일 페이지는 loaded document context로 PNG, 다중 페이지는 PDF로 렌더한다. |
| Thumbnail | `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`, `HwpThumbnailRenderCache.swift` | request `fileURL`을 render request로 넘긴 뒤 Shared page image renderer 호출 | 없음 | cache worker에서 `HwpPageImageRenderer.renderFirstPage(...)`를 호출한다. |

핵심 결론은 HostApp Studio 진입 경로와 Quick Look/Thumbnail native 진입 경로가 모두 Swift layer에서는 bytes + filename만 core에 넘긴다는 점이다. 따라서 base directory 미전달은 둘 중 한쪽만의 차이가 아니라 현재 앱 전체 open contract의 공통 제약이다.

## bundled rhwp-studio open 흐름

번들된 `Sources/HostApp/Resources/rhwp-studio/assets/index-*.js`는 minified asset이지만 다음 흐름을 확인했다.

| 단계 | 확인된 호출 | 의미 |
|---|---|---|
| URL query parse | `Ul()`이 `url`과 `filename` query를 읽음 | HostApp이 만든 `alhangeul-document://current?...`와 filename을 Studio에 전달하는 지점 |
| bytes fetch | `fetch(url)` 후 signature 확인 | HostApp document scheme handler가 제공한 bytes를 읽음 |
| document open | `Pl(bytes, filename, null)` | file handle 없이 bytes와 filename으로 문서 open |
| WASM load | `X.loadDocument(bytes, filename)` | `new HwpDocument(bytes)` 뒤 editor용 초기화 수행 |
| editable 변환 | `doc.convertToEditable()` | native preview에는 대응 호출이 없다. Stage 2 핵심 조사 대상이다. |
| stable id 보정 | `ensureParagraphStableIds()` | editor interaction용 id 보정으로 보이며 render 영향은 Stage 2에서 판단한다. |
| filename 설정 | `doc.setFileName(filename)` | native `RhwpDocument(data:filename:)`의 filename 전달과 성격이 유사한지 Stage 2에서 확인한다. |
| external image population | `populateExternalImagesFromDevServer()` | `getExternalImageBasenames()` 후 `/samples/<basename>` fetch, `injectExternalImage(...)` 호출을 시도한다. Stage 3 핵심 조사 대상이다. |
| canvas/editor init | `Ml(...)`에서 font load, `Q?.loadDocument()`, toolbar init, input handler activate | 실제 Studio reference capture 전에 일어나는 초기화다. validation warning이 있으면 사용자 선택에 따라 `reflowLinesegs()`가 호출될 수 있다. |

`rhwp.d.ts`에서는 `convertToEditable`, `setFileName`, `getValidationWarnings`, `reflowLinesegs` 선언을 확인했다. 반면 이번 grep 기준으로 external image basename/inject API 선언은 `rhwp.d.ts`에서 확인되지 않았고, minified JS bundle 내부 호출로만 확인됐다. Stage 3에서는 generated header와 bridge 노출 여부를 별도로 확인해야 한다.

## Studio와 native preview의 차이 후보

| 후보 | 현재 판정 | 다음 조사 |
|---|---|---|
| bytes 전달 | 차이 낮음 | 양쪽 모두 파일 bytes를 직접 읽어 core에 넘긴다. |
| filename 전달 | 차이 낮음, 단 API 형태는 다름 | Studio는 open 후 `setFileName`, native는 constructor `filename` 인자다. Stage 2에서 영향 확인. |
| base directory | 공통 미지원 | HostApp과 extension 모두 전달하지 않는다. external linked image에는 영향 가능성이 있으므로 Stage 3에서 확인. |
| `convertToEditable()` | 차이 있음 | Studio만 호출한다. render tree/page layout 영향이 있으면 M014 blocker가 될 수 있어 Stage 2에서 조사. |
| `ensureParagraphStableIds()` | 차이 있음 | editor interaction용으로 보이나 page render 영향 여부를 Stage 2에서 확인. |
| validation/reflow | 조건부 차이 | Studio는 validation warning 후 사용자 선택 시 reflow 가능하다. 자동 기본 경로인지 Stage 2에서 확인. |
| external image dev-server population | 차이 있음 | Studio bundle은 `/samples/<basename>` fetch를 시도한다. public app HostApp URL에서는 source directory와 무관하므로 Stage 3에서 실제 영향과 sample/dev 전용 여부를 분리. |
| font loading/editor init | 차이 있음 | Studio capture reference에는 web font load와 canvas init timing이 포함된다. Stage 2에서 normalization과 분리해 기록. |

## Stage 2 조사 기준

Stage 2는 normalization/editor initialization 영향만 본다.

확인 대상:

- `convertToEditable()` 호출이 page layout, render tree, text visibility, PUA 표시 경로에 영향을 주는지
- `ensureParagraphStableIds()`가 render output에 관여하는지
- `setFileName(filename)`이 native constructor filename과 같은 의미인지
- `getValidationWarnings()`와 `reflowLinesegs()`가 기본 open path에서 자동으로 render를 바꾸는지, 아니면 사용자 선택 후에만 바뀌는지
- `Ml(...)`의 `Q?.loadDocument()`와 font load가 #280 Studio capture settle 조건에 어떤 영향을 주는지

Stage 2 완료 판정은 각 항목을 `M014 blocker`, `후속 이슈 필요`, `현재 영향 낮음`, `sample/dev 전용으로 제외` 중 하나로 분류하는 것이다.

## Stage 3 조사 기준

Stage 3는 filename/base directory/external image 영향을 본다.

sample 후보:

- `samples/tac-img-02.hwp`
- `samples/tac-img-02.hwpx`
- `samples/hwp-img-001.hwp`
- `samples/img-start-001.hwp`
- 필요 시 `samples/images/*`

확인 대상:

- `getExternalImageBasenames` / `injectExternalImage` 계열 API가 native bridge나 generated header에 노출되어 있는지
- bundled Studio의 `/samples/<basename>` fetch가 #280 harness reference capture에서 실제로 성공하는지
- public HostApp open path에서 source document directory를 기준으로 external image를 resolve할 수 있는지
- external image 미해결 diff가 #116/#122/#281/#282 범위인지, 별도 base-dir-aware open/bridge 이슈인지

## Stage 1 검증

실행:

```bash
rg -n "loadDocument|RhwpStudioDocumentPayload|RhwpStudioResourceLocator|RhwpStudioDocumentSchemeHandler|HwpPreviewPDFRenderer|HwpPageImageRenderer|providePreview|provideThumbnail" \
  Sources/HostApp Sources/Shared Sources/QLExtension Sources/ThumbnailExtension
rg -n "loadFromUrlParam|loadDocument|convertToEditable|getExternalImageBasenames|external|image|filename|url" \
  Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
git diff --check
```

결과:

- HostApp open path는 `DocumentViewerStore` -> `RhwpStudioDocumentPayload` -> `RhwpStudioResourceLocator` -> `RhwpStudioDocumentSchemeHandler` -> `RhwpStudioWebView` 흐름으로 확인했다.
- Quick Look/Thumbnail open path는 provider -> Shared renderer -> `RhwpDocument(data:filename:)` 흐름으로 확인했다.
- bundled Studio JS에서 `loadFromUrlParam`, `X.loadDocument`, `convertToEditable`, `ensureParagraphStableIds`, `populateExternalImagesFromDevServer`, `Pl`, `Ml` 흐름을 확인했다.
- minified JS는 한 줄 또는 긴 줄에 여러 symbol이 함께 있어 line reference의 가독성은 낮다. 보고서에는 symbol과 파일 단위 근거로 기록했다.
- `git diff --check` 결과 whitespace 오류는 없었다.

## 리스크와 보류 판단

- 이번 단계는 static inventory라서 실제 render diff 수치는 만들지 않았다. 수치 관찰은 Stage 2/3에서 #280 harness를 사용해 진행한다.
- bundled JS의 external image population은 async이며 `loadDocument()`에서 await하지 않는다. #280 harness capture가 이 비동기 inject 이후를 관찰하는지는 Stage 3에서 별도 확인해야 한다.
- HostApp과 extension 모두 source directory를 넘기지 않으므로 base-dir-aware open을 추가하려면 앱, extension, bridge contract를 함께 설계해야 한다. 이번 단계에서는 구현하지 않았다.
- external image API가 `rhwp.d.ts`와 generated header에 완전히 정리되어 있는지는 Stage 3에서 다시 확인한다.

## 다음 단계

Stage 2에서는 source를 수정하지 않고 normalization/editor initialization 차이를 조사한다. 특히 `convertToEditable()`와 validation/reflow가 preview parity의 blocker인지 먼저 결론 내린다. Stage 2 진행은 작업지시자 승인 후 시작한다.
