# Task M016 #149 Stage 1 보고서

## 단계 목적

현행 HostApp, Quick Look preview, Finder thumbnail의 문서 opening/fallback 경로를 코드 변경 없이 inventory했다. 목표는 Stage 2에서 확정할 error taxonomy, 사용자 fallback 문구, helper 위치, target별 구현 범위를 구체화하는 것이다.

## 산출물

- `mydocs/working/task_m016_149_stage1.md`: Stage 1 조사 보고서
- 소스 코드 변경 없음
- 매뉴얼/README 변경 없음

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 조사와 보고서 작성만 수행했다. 제품 소스, 기존 계획서, 매뉴얼 본문은 변경하지 않았으므로 기존 동작에는 영향이 없다.

## 조사 결과

### HostApp opening 경로

| 입력/실패 | 현재 경로 | 현재 사용자 결과 | Stage 2 입력 |
|-----------|-----------|------------------|--------------|
| 파일 선택 후 읽기 실패 | `DocumentViewerStore.loadDocument(from:)`에서 `Data(contentsOf:)` 실패 catch | `문서를 열 수 없습니다: ...` error state | 파일 접근/읽기 실패 문구를 별도 taxonomy로 분리 |
| 빈 파일 | `loadDocument(data:)`가 `DocumentViewerStoreError.emptyDocument` throw | 파일 선택은 error state, drop은 banner 메시지 | 빈 파일은 HostApp 조기 validation으로 유지하되 문구 통일 필요 |
| non-empty corrupt/signature mismatch | Swift store는 bytes만 payload로 보관하고 WebView에 전달 | Swift 쪽 조기 차단 없음 | HWP/HWPX signature preflight를 Swift에 둘지 Stage 2에서 결정 |
| `rhwp-studio` URL parameter load 실패 | bundled JS `oo()`/`Qa()`/`X.loadDocument()` 실패를 `so(error)`가 처리 | WebView 내부 status/toast에 `파일 로드 실패: ...`; Swift `webViewFailure`로 올라오지 않음 | parse failure를 host bridge로 전달하는 최소 injection 필요 여부 검토 |
| JS unhandled runtime failure | `runtimeErrorSource`가 `runtime-error` message post | `RhwpStudioWebViewFailure.runtime` fatal fallback | #150 runtime fallback 유지. 다만 handled document load failure는 별도 포착 필요 |
| drag/drop 파일 읽기 실패 | host bridge `postDroppedDocument` catch가 `type: "error"` post | `webViewErrorMessage` banner | 파일 읽기 실패와 문서 파싱 실패를 구분해야 함 |

핵심 관찰:

- `DocumentViewerStore`는 파일 bytes 읽기와 empty data만 검증한다. 문서 signature나 parser-level validity는 HostApp Swift 계층에서 확인하지 않는다.
- `RhwpStudioWebView`는 navigation/process/timeout/runtime failure를 fatal fallback으로 연결하지만, upstream app이 catch해서 `so(error)`로 처리한 document load failure는 native callback이 없다.
- bundled `rhwp-studio`에는 HWP CFB magic과 HWPX ZIP magic을 보는 signature check가 있으며, mismatch면 `실제 HWP/HWPX 파일이 아닙니다...` 오류를 만든다. 이 오류는 현재 WebView 내부 status/toast에 머무른다.
- HostApp에는 50 MB hard block이 없다. 현재 문서와 코드 기준으로는 50 MB 제한이 Quick Look/Thumbnail preview fallback 정책이다.

### Quick Look preview 경로

| 입력/실패 | 현재 경로 | 현재 사용자 결과 | Stage 2 입력 |
|-----------|-----------|------------------|--------------|
| 50 MB 초과 | `HwpPreviewPDFRenderer.inspect`가 file size 확인 후 `HwpRenderError.fileTooLarge` throw | `HwpPreviewProvider`가 plain text `The file is larger than 50 MB.` 반환 | 기존 fallback 유지, 문구 정합성 검토 |
| 빈 파일 | `RhwpDocument.init`에서 `RhwpError.invalidData` throw | `HwpPreviewProvider`가 rethrow | plain text fallback mapping 후보 |
| corrupt/signature/parser 실패 | `RhwpDocument.init`에서 `RhwpError.parseFailure` throw | `HwpPreviewProvider`가 rethrow | plain text fallback mapping 필요 |
| page count 0 | `HwpPreviewPDFRenderer.inspect`가 `HwpRenderError.emptyDocument` throw | rethrow | plain text fallback mapping 후보 |
| invalid page size | `HwpPreviewPDFRenderer.inspect`가 `HwpRenderError.invalidPageSize` throw | rethrow | plain text fallback mapping 후보 |
| PNG/PDF data block render 실패 | `pngReply`/`pdfReply` data creation block 내부에서 throw | provider 생성 이후 failure로 전파 | inspect 단계와 data creation block 양쪽 error mapping 검토 필요 |

핵심 관찰:

- Quick Look은 50 MB 초과만 fallback reply로 바꾼다.
- `RhwpError.parseFailure`, `RhwpError.invalidData`, `HwpRenderError.emptyDocument`, `HwpRenderError.invalidPageSize`, `renderTreeUnavailable`, encoding failure는 현재 raw error 전파 경로다.
- 다중 페이지 PDF render 단계는 `inspect` 후 다시 `RhwpDocument`를 열고 모든 페이지를 순회한다. data block 내부 실패 처리까지 Stage 4 설계에 포함해야 한다.

### Finder thumbnail 경로

| 입력/실패 | 현재 경로 | 현재 사용자 결과 | Stage 2 입력 |
|-----------|-----------|------------------|--------------|
| 50 MB 초과 | `HwpPageImageRenderer.renderFirstPage`가 `HwpRenderError.fileTooLarge` throw | `HwpThumbnailProvider`가 fallback tile 반환 | 기존 fallback tile 유지 |
| resource values 실패 | `HwpThumbnailRenderRequest.init` throw | `handler(nil, error)` | fallback tile 후보 여부 검토 |
| 빈 파일 | `RhwpDocument.init`에서 `RhwpError.invalidData` throw | `handler(nil, error)` | fallback tile mapping 필요 |
| corrupt/parser 실패 | `RhwpDocument.init`에서 `RhwpError.parseFailure` throw | `handler(nil, error)` | fallback tile mapping 필요 |
| render tree/page size/bitmap 실패 | `HwpRenderError` throw | `handler(nil, error)` | fallback tile mapping 필요 |

핵심 관찰:

- Thumbnail provider는 `HwpRenderError.fileTooLarge`만 fallback tile로 처리한다.
- `HwpThumbnailRenderCache`는 성공한 page만 cache에 저장하고 실패는 저장하지 않는다. 실패 fan-out은 callback으로 그대로 전파된다.
- `HwpPageImageRenderer.renderFirstPage`는 file size 확인 전에 `Data(contentsOf:)`로 전체 파일을 읽고 embedded thumbnail decode를 먼저 시도한다. 대용량 파일 memory pressure를 완화하려면 Stage 2에서 "size check before full read"를 별도 구현 후보로 검토해야 한다.

### 문서/운영 기준

- README는 `50 MB 초과 preview fallback`을 완료 항목으로 표시하고, `corrupt file fallback`은 미완료 항목으로 남겨 두었다.
- `build_run_guide.md`에는 #150의 WKWebView asset negative smoke가 있으나 손상/대용량 문서 opening negative smoke는 아직 없다.
- `release_distribution_guide.md`는 자동화 환경에서 `qlmanage -t -x` headless thumbnail 기준을 사용한다고 정리되어 있다.

## Stage 2 설계 입력

Stage 2에서는 다음 결정을 먼저 내려야 한다.

- HostApp 조기 validation:
  - 파일 읽기 실패, 빈 파일, signature mismatch를 Swift store 단계에서 잡을지 결정한다.
  - 50 MB는 우선 Quick Look/Thumbnail preview 제한으로 유지하고 HostApp hard block은 도입하지 않는 방향을 명시한다.
- WKWebView parse failure bridge:
  - upstream `so(error)`가 처리하는 `파일 로드 실패`를 native로 전달할 최소 injection 지점을 찾는다.
  - native fatal fallback으로 보낼지, document-specific banner/status로 둘지 결정한다.
- Quick Look fallback reply:
  - `RhwpError`와 사용자 문서성 `HwpRenderError`를 plain text fallback으로 mapping한다.
  - provider 생성 전 `inspect` 실패와 data creation block 실패를 따로 검토한다.
- Thumbnail fallback tile:
  - `fileTooLarge` 외 parse/render failure를 기존 tile로 mapping한다.
  - cache에는 실패를 저장하지 않는 현 구조를 유지한다.
- Shared helper:
  - `Sources/Shared`에 AppKit/WebKit 없는 classification helper를 둘지, target별 provider에서 최소 mapping할지 결정한다.

## 검증 결과

구현계획서 Stage 1 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과: `## local/task149`

```bash
rg -n "errorMessage|webViewErrorMessage|webViewFailure|loadDocument|loadDroppedDocument|runtime-error|type: \\\"error\\\"|loadFromUrlParam|파일 로드 실패" \
  Sources/HostApp/Stores/DocumentViewerStore.swift \
  Sources/HostApp/Views/DocumentViewerView.swift \
  Sources/HostApp/Views/RhwpStudioWebView.swift \
  Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
```

결과: 성공. `DocumentViewerStore`, `DocumentViewerView`, `RhwpStudioWebView`, host bridge script, bundled asset의 document load/status/error 경로 match를 확인했다. bundled asset은 minified single-line 파일이라 출력이 길어졌지만 `loadFromUrlParam`, `파일 로드 실패`, `type: "error"`, `runtime-error` 경로가 모두 match되었다.

```bash
rg -n "hwpQuickLookMaxFileSize|fileTooLarge|RhwpError|HwpRenderError|renderFirstPage|providePreview|provideThumbnail|renderedPage" \
  Sources/Shared Sources/QLExtension Sources/ThumbnailExtension Sources/RhwpCoreBridge
```

결과: 성공. `hwpQuickLookMaxFileSize`, `HwpRenderError.fileTooLarge`, `RhwpError.parseFailure`, Quick Look/Thumbnail provider와 cache 경로 match를 확인했다.

```bash
rg -n "50 MB|corrupt file fallback|fallback|preview" README.md mydocs/manual/build_run_guide.md mydocs/manual/release_distribution_guide.md
```

결과: 성공. README의 50 MB preview fallback 완료 항목과 corrupt file fallback 미완료 항목, build/run guide의 #150 asset fallback smoke, release guide의 headless thumbnail 기준을 확인했다.

추가로 코드 위치 확인을 위해 `nl -ba`와 minified asset context extraction을 사용했다. 이는 보고서 작성을 위한 보조 조사이며 제품 파일을 변경하지 않았다.

## 잔여 위험

- WebView 내부 document load failure는 upstream bundle의 handled error라서 `window.onerror`/`unhandledrejection`만으로는 native에 전달되지 않을 가능성이 높다.
- Quick Look data creation block 내부 실패는 `providePreview`의 `createPreview` catch와 다른 시점에 발생한다. Stage 4에서 실제 API 제약을 확인해야 한다.
- Thumbnail 대용량 경로는 현재 full data read 후 file size fallback으로 이동한다. 실제 memory pressure 위험이 있으면 Stage 2에서 범위 조정이 필요하다.
- synthetic corrupt 파일은 signature mismatch와 parser failure를 대표하지만 실제 손상 corpus의 모든 failure mode를 대표하지 않는다.

## 다음 단계 영향

Stage 2는 코드 작성 전에 taxonomy와 구현 기준을 확정한다. 특히 HostApp 50 MB hard block은 기본적으로 도입하지 않는 방향을 유지하되, Thumbnail의 size-check-before-full-read와 Quick Look/Thumbnail parse failure fallback mapping은 구현 후보로 올린다.

## 승인 요청

Stage 1 inventory 완료를 승인해 주시면 Stage 2 fallback taxonomy와 구현 기준 확정 단계로 진행하겠다.
