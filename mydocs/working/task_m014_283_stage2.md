# Task M014 #283 Stage 2 보고서 - normalization 영향 조사

## 단계 개요

- 이슈: #283 rhwp-studio 문서 열기 normalization·external image parity 영향 조사
- 단계: Stage 2. normalization/editor initialization 영향 조사
- 목표: `rhwp-studio`의 editable/editor initialization 관련 처리가 Quick Look/Thumbnail native preview render output에 영향을 주는지 판단한다.

이번 단계는 조사와 문서화만 수행했다. production Swift source, Rust bridge, bundled `rhwp-studio` asset은 수정하지 않았다.

## 확인한 현재 구조

### rhwp-studio open 후 처리

bundled `rhwp-studio`의 minified JS 기준 HostApp URL open은 `Ul()` -> `Pl(bytes, filename, null)` -> `X.loadDocument(bytes, filename)` -> `Ml(info, statusText)` 흐름이다.

`X.loadDocument(bytes, filename)`에서 확인된 핵심 호출은 다음과 같다.

| 호출 | 확인 위치 | 의미 |
|---|---|---|
| `new HwpDocument(bytes)` | `assets/index-*.js` | WASM 문서 생성 |
| `doc.convertToEditable()` | `assets/index-*.js`, `rhwp.d.ts` | 배포용/읽기전용 문서를 편집 가능한 일반 문서로 변환 |
| `ensureParagraphStableIds()` | `assets/index-*.js` | editor navigation/selection에 필요한 stable id 보정 |
| `doc.setFileName(filename)` | `assets/index-*.js`, `rhwp.d.ts` | 머리말/꼬리말 필드 치환용 파일명 설정 |
| `populateExternalImagesFromDevServer()` | `assets/index-*.js` | 외부 이미지 basename을 `/samples/<basename>`로 fetch 시도. Stage 3 범위 |

`Ml(...)`에서는 web font 로드 후 `Q?.loadDocument()`로 canvas view를 로드하고, toolbar와 input handler를 활성화한다. 그 뒤 `getValidationWarnings()`를 확인하고 warning이 있으면 사용자 선택 UI를 띄운다. `reflowLinesegs()`는 사용자가 `auto-fix`를 선택한 경우에만 호출된다.

### native preview open/render 경로

Swift native preview는 `RhwpDocument(data:filename:)`를 생성하지만, 현재 C bridge 호출은 `rhwp_open(data, len)`뿐이다. `filename`은 parse error message에만 쓰이고 core handle에는 전달되지 않는다.

현재 `Frameworks/generated_rhwp.h`가 제공하는 native render 관련 ABI는 다음 범위다.

| ABI | 역할 |
|---|---|
| `rhwp_open(data, len)` | 문서 open |
| `rhwp_page_count` / `rhwp_page_size` | page metadata |
| `rhwp_render_page_tree` | Swift `CGTreeRenderer`용 render tree JSON |
| `rhwp_render_page_png` | Skia PNG render |
| `rhwp_image_data` | render tree 이미지 bin data 조회 |

native bridge에는 `convertToEditable`, `setFileName`, `getValidationWarnings`, `reflowLinesegs`, `ensureParagraphStableIds` 대응 ABI가 없다.

## 항목별 판단

| 항목 | Stage 2 판단 | 근거 | 후속 |
|---|---|---|---|
| `convertToEditable()` | M014 즉시 blocker로 보지는 않는다. 다만 배포용/읽기전용 문서 sample 검증은 필요하다. | `rhwp.d.ts` 설명은 읽기전용 문서를 편집 가능하게 변환하는 API다. 현재 확인 범위에서는 render API 호출 전에 항상 실행되지만, page layout을 직접 바꾸는 호출이라는 근거는 없다. | 배포용/읽기전용 sample이 생기면 Studio/native render tree 또는 visual diff로 별도 확인. |
| `ensureParagraphStableIds()` | 현재 영향 낮음 | bundle에서 function 존재 여부를 확인하고 있으면 호출, 실패하면 warning만 남긴다. editor navigation/selection 안정화 용도로 보이며 native render tree ABI에는 대응 상태가 없다. | render output 차이가 관찰될 때만 후속 확인. |
| `setFileName(filename)` | 후속 이슈 또는 Stage 3 handoff 필요 | Studio는 core에 파일명을 명시 설정한다. native Swift의 `filename` 인자는 core로 전달되지 않는다. 파일명 필드, 머리말/꼬리말 필드 치환 문서는 Studio와 native preview가 달라질 수 있다. | Stage 3에서 filename/base directory 항목으로 분리해 영향 sample과 bridge 필요성을 판단. |
| validation warning / `reflowLinesegs()` | 기본 open path 기준 영향 낮음 | `reflowLinesegs()`는 `getValidationWarnings()` 이후 사용자 선택이 `auto-fix`일 때만 호출된다. 자동 기본 open에서 즉시 render를 바꾸는 경로로 보이지 않는다. | lineseg warning sample은 #116/#122 계열 renderer/layout 이슈와 분리해 필요 시 별도 검증. |
| `Ml(...)` editor/canvas init | native open normalization blocker는 아님 | font load와 `Q?.loadDocument()`는 Studio canvas capture readiness/timing 문제다. native core 문서 상태를 바꾸는 ABI 차이는 아니다. | #280 harness settle/readiness 안정화 쪽으로 handoff. |
| PUA 표시 문자열/렌더 경로 | Swift layer가 막는 구조는 보이지 않는다. 단 current core tag에서는 #982 반영 여부를 검증하지 않는다. | native CoreGraphics 경로는 `rhwp_render_page_tree`가 반환한 `TextRunNode.text`를 그대로 `NSAttributedString`으로 그린다. Swift code에 PUA/display string 별도 변환은 없다. Skia 경로는 `rhwp_render_page_png` 결과를 그대로 decode한다. | #982가 포함된 새 rhwp release로 갱신된 뒤 `render_page_tree`/`render_page_png` output에 fix가 들어오는지 확인하면 된다. |

## preview parity 관점의 결론

Stage 2 범위에서 `convertToEditable()`와 stable id 보정만을 이유로 Quick Look/Thumbnail renderer를 `pagelayertree` 방식으로 즉시 전환해야 한다는 근거는 확인하지 못했다.

반대로 실제 차이 후보는 `filename`이다. HostApp Studio는 `setFileName(filename)`을 호출하지만 native preview는 core에 filename을 전달하지 않는다. 따라서 파일명 필드 또는 머리말/꼬리말 필드 치환이 있는 문서는 preview parity 차이가 생길 수 있다. 이 항목은 Stage 3의 filename/base directory 조사에서 sample 기반으로 확인해야 한다.

PUA/#982 계열 변경은 Swift native renderer가 자체 문자열 normalization을 하지 않기 때문에, core의 render tree 또는 Skia PNG 경로에 반영되면 native preview도 따라갈 가능성이 높다. 다만 현재 lock은 `rhwp-core.lock` 기준 `v0.7.12` / `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`이므로 #982 포함 release 검증은 이번 작업 범위에서 제외한다.

## smoke 관찰

일반 sample baseline을 보려고 #280 harness를 한 번 실행했다.

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task283-normalization --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

결과는 두 샘플 모두 실패했다.

| sample | 결과 | 원인 |
|---|---|---|
| `samples/basic/request.hwp` | FAIL | `rhwp-studio page 1 readiness timed out`, `WKErrorDomain Code=5`, JavaScript result unsupported type |
| `samples/hwpx/hwpx-01.hwpx` | FAIL | 동일 |

산출물은 `build.noindex/task283-normalization/summary.md`에 남았다. 이 실패는 Studio/native 렌더 차이가 아니라 harness readiness polling의 JavaScript evaluation 문제다. 따라서 Stage 2에서는 수치 비교값을 만들지 못했고, 이 결과를 normalization 판단 근거로 사용하지 않는다.

## Stage 2 검증

실행:

```bash
rg -n "convertToEditable|validation|reflow|stable|paragraph|loadDocument|initDoc|document-changed|canvasView" \
  Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
./scripts/verify-rhwp-studio-assets.sh
rg -n "rhwp_.*convert|rhwp_.*reflow|rhwp_.*validation|rhwp_.*set_file|rhwp_render_page|rhwp_open|rhwp_page" \
  Frameworks/generated_rhwp.h Sources/RhwpCoreBridge
git diff --check
```

결과:

- bundled Studio open path에서 `convertToEditable`, `ensureParagraphStableIds`, `setFileName`, validation/reflow 흐름을 확인했다.
- `./scripts/verify-rhwp-studio-assets.sh`는 `OK`로 통과했다.
- native C bridge에는 editor normalization 계열 ABI가 없고 render/page/image ABI만 있음을 확인했다.
- `git diff --check` 결과 whitespace 오류는 없었다.

## 리스크와 보류 판단

- `convertToEditable()`의 내부 구현은 현재 앱 repo에 없어서 static call graph만으로 render 영향이 0이라고 단정할 수 없다. 배포용/읽기전용 sample이 필요하다.
- `setFileName(filename)` 차이는 실제 render 차이 가능성이 있으나, 이번 단계에서는 sample 수치가 없다. Stage 3에서 filename/base directory와 함께 확인한다.
- #280 harness smoke는 readiness 오류로 실패했다. #283 결론을 막는 문제는 아니지만, 이후 Stage 3 수치 관찰 전에는 harness 오류 재현 여부를 다시 확인해야 한다.
- #982/PUA 반영 여부는 현재 core lock으로 판단하지 않는다. 새 rhwp release 반영 후 같은 경로에서 재확인해야 한다.

## 다음 단계

Stage 3에서는 filename/base directory/external image 영향을 확인한다. 특히 `setFileName` 차이와 external image population이 실제 sample diff로 이어지는지, 그리고 bridge/open option 후속 이슈가 필요한지 판단한다. Stage 3 진행은 작업지시자 승인 후 시작한다.
