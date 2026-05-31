# Task M014 #283 Stage 3 보고서 - external image open 영향 조사

## 단계 개요

- 이슈: #283 rhwp-studio 문서 열기 normalization·external image parity 영향 조사
- 단계: Stage 3. filename/base directory/external image 영향 조사
- 목표: filename/base directory/external linked image 차이가 `rhwp-studio` reference와 native preview output 차이의 원인이 되는지 판단한다.

이번 단계는 조사와 문서화만 수행했다. production Swift source, Rust bridge, bundled `rhwp-studio` asset은 수정하지 않았다.

## sample 후보와 파일 관찰

Stage 3 후보 파일은 모두 repository에 존재했다.

| 후보 | 관찰 |
|---|---|
| `samples/tac-img-02.hwp` | HWP 5.x, native render tree에서 page 1 image node 1개 확인 |
| `samples/tac-img-02.hwpx` | HWPX zip, `BinData/image*.JPG/BMP/PNG` embedded image 파일 다수 확인, native render tree에서 page 1 image node 1개 확인 |
| `samples/hwp-img-001.hwp` | HWP 5.x, native render tree에서 page 1 image node 4개 확인 |
| `samples/img-start-001.hwp` | HWP 5.x, page 1 native render는 가능하나 image node는 0개 확인 |
| `samples/images/*` | `tiger01.jpg`, `san-serif.jpg`, `splatoon01.jpg`, `younghi.jpg`, `moogung.jpg` 존재 |

`tac-img-02.hwpx`는 zip 목록 기준 외부 sibling image가 아니라 package 내부 `BinData` 이미지가 들어 있다. HWP binary sample은 `strings`만으로 명확한 sibling file basename을 확인하지 못했다. 따라서 이번 단계의 샘플은 “image-heavy/native image 경로 후보”로는 유효하지만, external linked image가 실제로 필요한 문서라고 단정할 수는 없다.

## Studio/WASM external image 경로

bundled Studio open path는 `loadDocument(bytes, filename)`에서 다음 순서로 동작한다.

| 항목 | 현재 동작 | 의미 |
|---|---|---|
| document 생성 | `new HwpDocument(bytes)` | bytes만으로 WASM document 생성 |
| editor normalization | `convertToEditable()`, `ensureParagraphStableIds()` | Stage 2에서 별도 판단 |
| filename 설정 | `doc.setFileName(this._fileName)` | 머리말/꼬리말 필드 치환용 파일명 설정 |
| external image population | `this.populateExternalImagesFromDevServer()` | `await`하지 않고 비동기로 실행 |

`rhwp.js` wrapper에는 다음 API가 있다.

| API | 확인 내용 |
|---|---|
| `getExternalImageBasenames()` | HWP3 file path 그림의 basename 목록을 JSON 배열로 반환한다고 주석에 명시 |
| `injectExternalImage(basename, data, display_path)` | JS가 fetch한 외부 image bytes를 document에 inject |
| `setFileName(name)` | 파일 이름을 core document에 설정 |

minified bundle의 `populateExternalImagesFromDevServer()`는 basename마다 `/samples/<basename>`를 fetch하고, 성공하면 `injectExternalImage(...)`를 호출한다. 실패하면 warning만 남기고 계속 진행한다.

## HostApp resource scheme 영향

현재 HostApp resource scheme은 `rhwp-studio` bundled resource directory 아래 파일만 제공한다.

- `RhwpStudioResourceLocator.resourceDirectoryURL(...)`는 app bundle의 `rhwp-studio` directory를 기준으로 한다.
- `RhwpStudioResourceSchemeHandler.resolveResource(for:)`는 request path를 이 directory 아래 relative path로 해석한다.
- `RhwpStudioResourceLocator.isBundledResourceURL(...)`로 directory 밖 접근을 차단한다.
- `Sources/HostApp/Resources/rhwp-studio` 아래에는 `/samples/` resource가 없다.

따라서 app-bundled Studio에서 `/samples/<basename>` fetch는 원본 문서의 sibling directory가 아니라 `rhwp-studio/samples/<basename>`를 찾는 동작이다. 현재 bundle에는 해당 resource가 없으므로 public app 기본 경로에서 dev-server style external image population이 성공한다고 볼 근거가 없다.

## native bridge 노출 상태

현재 native C ABI와 Swift bridge는 external image population과 filename setter를 노출하지 않는다.

| 항목 | Studio/WASM | native Swift/C bridge |
|---|---|---|
| open | `new HwpDocument(bytes)` | `rhwp_open(data, len)` |
| filename | `doc.setFileName(filename)` | `RhwpDocument(data:filename:)`의 `filename`은 parse error에만 사용 |
| external basename 조회 | `getExternalImageBasenames()` | 없음 |
| external image inject | `injectExternalImage(...)` | 없음 |
| embedded image lookup | Studio 내부 API | `rhwp_image_data(handle, bin_data_id, len)` |
| render | Studio canvas/page layer | `rhwp_render_page_tree`, `rhwp_render_page_png` |

이 차이는 renderer 선택과 별개의 open contract 차이다. `pagelayertree` 방식으로 전환해도 document handle에 external image bytes가 inject되지 않으면 같은 external image 누락이 남는다.

## #280 harness smoke 결과

실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task283-external-image --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp samples/img-start-001.hwp
```

결과:

| sample | 결과 | 원인 |
|---|---|---|
| `samples/tac-img-02.hwp` | FAIL | `rhwp-studio page 1 readiness timed out`, `WKErrorDomain Code=5`, JavaScript result unsupported type |
| `samples/tac-img-02.hwpx` | FAIL | 동일 |
| `samples/hwp-img-001.hwp` | FAIL | 동일 |
| `samples/img-start-001.hwp` | FAIL | 동일 |

산출물:

- `build.noindex/task283-external-image/summary.md`

이번 smoke에서는 `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta` 같은 Studio/native 비교 수치를 얻지 못했다. 실패 원인은 Stage 2와 같은 harness readiness polling 문제이며, external image 또는 native renderer의 실제 visual diff로 해석하지 않는다.

## native render-debug 보조 관찰

Studio reference 비교가 실패했기 때문에 native 경로가 후보 샘플을 최소한 render tree/PNG로 처리하는지만 보조 확인했다.

실행:

```bash
./scripts/render-debug-compare.sh build.noindex/task283-native-image-debug --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp samples/img-start-001.hwp
./scripts/render-debug-compare.sh build.noindex/task283-native-image-debug-hwp --page 1 samples/tac-img-02.hwp
./scripts/render-debug-compare.sh build.noindex/task283-native-image-debug-hwpx --page 1 samples/tac-img-02.hwpx
```

첫 명령은 `tac-img-02.hwp`와 `tac-img-02.hwpx`가 같은 basename을 사용해 출력 파일이 덮어써졌다. 그래서 두 `tac-img-02` sample은 분리 output으로 다시 실행했다.

| sample | pageCount | renderTree bytes | native PNG | native non-white pixels | textRuns | image nodes | 비고 |
|---|---:|---:|---|---:|---:|---:|---|
| `tac-img-02.hwp` | 66 | 36,221 | `794x1123` | 38,551 | 19 | 1 | native render OK |
| `tac-img-02.hwpx` | 69 | 38,894 | `794x1123` | 32,799 | 21 | 1 | native render OK, `LAYOUT_OVERFLOW` 2.4px warning |
| `hwp-img-001.hwp` | 1 | 121,964 | `794x1123` | 57,797 | 67 | 4 | native render OK |
| `img-start-001.hwp` | 3 | 209,463 | `794x1123` | 108,951 | 131 | 0 | native render OK |

`render-debug-compare`의 core SVG raster diff는 `qlmanage rasterize failed`로 생성되지 않았다. 위 표는 native render sanity check일 뿐 Studio/native parity 수치가 아니다.

## 항목별 판단

| 항목 | Stage 3 판단 | 근거 | 후속 |
|---|---|---|---|
| filename | 후속 bridge/open option 필요 | Studio는 `setFileName(filename)`로 core document 상태를 바꾸지만 native `filename` 인자는 `rhwp_open`에 전달되지 않는다. | 파일명 필드, 머리말/꼬리말 필드 치환 sample이 있으면 `rhwp_set_file_name` 또는 open option ABI 필요성을 확인. |
| base directory | 현재 app/extension 공통 미지원 | HostApp payload와 Quick Look/Thumbnail path 모두 bytes + filename만 보존한다. source directory는 core에 전달되지 않는다. | linked external image를 제품 요구로 포함하려면 source directory 보존, sandbox 권한, bridge API를 함께 설계. |
| external linked image | 새 rhwp release 반영만으로는 충분하다고 보기 어렵다 | Studio JS에는 basename 조회/inject API가 있지만 native C ABI에는 없다. app-bundled Studio의 `/samples/<basename>` fetch도 source directory 기반이 아니다. | 별도 base-dir-aware open 또는 external image injection bridge가 필요. |
| embedded image | native path는 기존 ABI로 처리 가능 | `rhwp_image_data`와 render tree image node로 `tac-img-02`, `hwp-img-001` native render가 가능했다. | image effect/fill/tile/clip 차이는 #116/#122/#281/#282 renderer 범위로 분리. |
| pagelayertree 전환 | external image 해결책으로는 부족 | external image bytes가 document state에 들어오지 않으면 page layer tree도 동일하게 누락된다. | 전환 여부와 별개로 open contract를 먼저 맞춰야 한다. |

## preview parity 관점의 결론

Stage 3 기준으로 filename과 external linked image는 renderer 구현보다 앞선 open contract 문제다. `rhwp` 새 release를 반영하면 core render tree 또는 Skia PNG 내부 수정은 Quick Look/Thumbnail에도 따라올 수 있지만, Studio JS wrapper에만 있는 `setFileName`, `getExternalImageBasenames`, `injectExternalImage` 경로는 native C ABI와 Swift open pipeline이 사용하지 않는 한 자동으로 반영되지 않는다.

따라서 external linked image parity가 M014 release acceptance에 포함된다면 별도 blocker 또는 follow-up 이슈로 잡아야 한다. 반대로 M014의 v0.1.4 목표를 embedded image, layout, text, PUA/render output parity로 한정한다면 external linked image는 명시적 한계로 두고 다음 마일스톤으로 넘길 수 있다.

`pagelayertree` 전환은 external image/base directory 문제를 직접 해결하지 않는다. 먼저 document open 시점에 filename과 external image bytes를 core document state에 반영할 API가 필요하고, 그 뒤에 render tree/Skia/page layer 중 어느 출력 경로를 쓸지 판단해야 한다.

## Stage 3 검증

실행:

```bash
find samples -maxdepth 3 -type f | rg -i "(tac-img|hwp-img|img-start|images|\\.hwp$|\\.hwpx$)"
rg -n "ExternalImage|externalImage|external_image|getExternalImageBasenames|populate|imageBasename|baseDir|base directory" \
  Sources Frameworks/generated_rhwp.h Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
./scripts/preview-visual-diff-harness.sh build.noindex/task283-external-image --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp samples/img-start-001.hwp
sed -n '1,120p' build.noindex/task283-external-image/summary.md
./scripts/render-debug-compare.sh build.noindex/task283-native-image-debug --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp samples/img-start-001.hwp
./scripts/render-debug-compare.sh build.noindex/task283-native-image-debug-hwp --page 1 samples/tac-img-02.hwp
./scripts/render-debug-compare.sh build.noindex/task283-native-image-debug-hwpx --page 1 samples/tac-img-02.hwpx
```

결과:

- sample 후보와 `samples/images/*` 존재를 확인했다.
- Studio/WASM wrapper의 `getExternalImageBasenames`, `injectExternalImage`, `setFileName` 경로를 확인했다.
- native generated header와 Swift bridge에는 external basename 조회, external image inject, filename setter ABI가 없음을 확인했다.
- #280 harness는 네 샘플 모두 readiness 오류로 실패했다. 비교 수치는 생성하지 못했다.
- native render-debug는 네 샘플 모두 render tree와 native PNG 생성에 성공했다.

## 리스크와 보류 판단

- HWP binary sample의 external linked image 여부를 현재 앱 repo의 native ABI만으로 직접 조회할 수 없다. Studio/WASM에는 basename 조회 API가 있지만 native bridge에는 없어, 이번 단계에서는 static evidence와 harness 실패 결과만 남긴다.
- app-bundled Studio의 `/samples/<basename>` fetch가 실제 런타임에서 어떤 warning을 남기는지는 #280 harness readiness 실패 때문에 직접 관찰하지 못했다.
- external image population은 `loadDocument()`에서 `await`하지 않는다. harness가 안정화되더라도 capture settle 조건이 inject 완료 후인지 별도 확인이 필요하다.
- `img-start-001.hwp`는 이름상 image 후보지만 page 1 render tree에서는 image node가 확인되지 않았다. 다른 page나 layout 흐름에서 image가 나올 가능성은 이번 단계에서 보지 않았다.

## 다음 단계

Stage 4에서는 Stage 1-3 결론을 종합해 최종 보고서를 작성한다. 특히 M014 기준에서 external linked image를 release blocker로 볼지, 별도 follow-up으로 분리할지 결정하고 #281/#282/#116/#122/#280에 전달할 handoff를 정리한다. Stage 4 진행은 작업지시자 승인 후 시작한다.
