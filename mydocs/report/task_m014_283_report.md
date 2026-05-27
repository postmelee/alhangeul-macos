# Task M014 #283 최종 결과보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#283](https://github.com/postmelee/alhangeul-macos/issues/283) |
| 마일스톤 | M014 — v0.1.4 Native Preview/Viewer Parity |
| 작업명 | rhwp-studio 문서 열기 normalization·external image parity 영향 조사 |
| 단계 수 | 4단계 |
| 최종 PR base 판단 | `devel` |

이번 작업은 `rhwp-studio` reference path와 Quick Look/Thumbnail/HostApp native preview path의 문서 open contract 차이가 v0.1.4 preview parity의 blocker인지 분리한 조사 작업이다.

production Swift source, Rust bridge, bundled `rhwp-studio` asset, renderer/compositor 구현은 수정하지 않았다. 결과적으로 `convertToEditable`, stable id, validation/reflow는 M014 즉시 blocker로 보지 않고, `filename`과 external linked image는 renderer보다 앞선 open contract 후속 범위로 분리하는 것이 맞다고 판단했다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| task-start | `c4d55f5` | #283 수행계획서와 오늘할일을 작성했다. |
| 구현계획 | `c1ed7f3` | Stage 1-4 구현계획서를 작성했다. |
| Stage 1 | `cfade5b` | HostApp Studio, Quick Look, Thumbnail, Shared native renderer의 open pipeline inventory를 정리했다. |
| Stage 2 | `81c46db` | `convertToEditable`, stable id, validation/reflow, filename setter 차이를 분류했다. |
| Stage 3 | `520f8cc` | filename/base directory/external image 영향과 native image render sanity를 조사했다. |
| Stage 4 | 최종 커밋 | 최종 결론, 후속 handoff, 보고서, 오늘할일 갱신을 수행했다. |

## 최종 판정

| 항목 | 최종 판정 | M014 처리 |
|------|-----------|-----------|
| 입력 bytes 전달 | 영향 낮음 | 양쪽 모두 원본 bytes를 읽어 core에 넘긴다. |
| `convertToEditable()` | 즉시 blocker 아님 | 배포용/읽기전용 sample이 생기면 별도 검증한다. |
| stable paragraph id | 영향 낮음 | editor navigation/selection 안정화 성격으로 보이며 preview output blocker 근거 없음. |
| validation warning / `reflowLinesegs()` | 기본 open path 영향 낮음 | 사용자 선택 후 auto-fix 경로로 보이며 자동 render 변경 경로로 보지 않는다. |
| filename field context | 후속 open contract 필요 | native `filename` 인자가 core document state에 전달되지 않는다. |
| base directory | 현재 app/extension 공통 미지원 | source directory는 HostApp/Quick Look/Thumbnail 모두 core에 전달하지 않는다. |
| external linked image | 후속 resource contract 필요 | Studio/WASM에는 basename 조회/inject API가 있지만 native C ABI와 Swift open pipeline에는 없다. |
| embedded image | 기존 native path로 처리 가능 | `rhwp_image_data`와 render tree image node로 후보 샘플 PNG 생성 확인. |
| PageLayerTree 전환 | external image 직접 해결책 아님 | document state에 bytes가 없으면 PageLayerTree도 같은 누락을 가진다. |

## M014 blocker 판단

이번 조사 기준으로 `convertToEditable`, stable id, validation/reflow 차이는 #281, #282, #116, #122, #121, #110 진행을 막는 blocker로 보지 않는다.

반면 `filename`과 external linked image는 정확도에 영향을 줄 수 있지만, v0.1.4의 현재 목표가 bundled `rhwp-studio` 기본 렌더와 Swift/native fallback parity를 줄이는 것이라면 별도 open/resource contract 후속으로 분리하는 편이 낫다. 이유는 다음과 같다.

- 현재 M014의 주요 후속은 overlay, compositor, watermark, fill/tile, RawSvg/OLE/chart, Placeholder/FormObject 같은 renderer/compositor parity다.
- filename/external linked image는 renderer 구현이 아니라 document open 시점의 state 주입 문제다.
- external linked image를 release acceptance에 포함하면 source directory 보존, sandbox 권한, C ABI, Swift bridge, cache invalidation까지 같이 설계해야 하므로 M014의 렌더러 parity 범위를 넘는다.

따라서 #283의 결론은 다음과 같다.

- M014 후속 renderer 작업은 진행 가능하다.
- external linked image parity는 M014 release blocker로 즉시 포함하지 않는다.
- filename field context와 external resource contract는 별도 후속 이슈 또는 upstream contract 개선 경로로 분리한다.

## smoke 측정 결과

### Studio/native visual diff harness

Stage 2와 Stage 3에서 #280 harness를 재사용했지만, Studio readiness polling 오류로 visual diff metric을 얻지 못했다.

| 실행 | sample | 결과 | 관찰 |
|------|--------|------|------|
| Stage 2 normalization smoke | `samples/basic/request.hwp` | FAIL | `rhwp-studio page 1 readiness timed out`, `WKErrorDomain Code=5`, JavaScript result unsupported type |
| Stage 2 normalization smoke | `samples/hwpx/hwpx-01.hwpx` | FAIL | 동일 |
| Stage 3 external image smoke | `samples/tac-img-02.hwp` | FAIL | 동일 |
| Stage 3 external image smoke | `samples/tac-img-02.hwpx` | FAIL | 동일 |
| Stage 3 external image smoke | `samples/hwp-img-001.hwp` | FAIL | 동일 |
| Stage 3 external image smoke | `samples/img-start-001.hwp` | FAIL | 동일 |

이번 작업에서 `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`는 생성되지 않았다. 이 실패는 open pipeline parity 결론을 무효화하지 않지만, #281 이후 PR별 수치 회귀 검증을 하려면 #280 harness readiness 문제를 먼저 안정화해야 한다.

### native render-debug sanity

Studio reference 비교가 실패했기 때문에 Stage 3에서는 native 경로가 image-heavy 후보를 최소한 render tree/PNG로 처리하는지만 보조 확인했다.

| sample | pageCount | renderTree bytes | native PNG | native non-white pixels | textRuns | image nodes | 결론 |
|--------|----------:|-----------------:|------------|------------------------:|---------:|------------:|------|
| `tac-img-02.hwp` | 66 | 36,221 | `794x1123` | 38,551 | 19 | 1 | native render OK |
| `tac-img-02.hwpx` | 69 | 38,894 | `794x1123` | 32,799 | 21 | 1 | native render OK, `LAYOUT_OVERFLOW` 2.4px warning |
| `hwp-img-001.hwp` | 1 | 121,964 | `794x1123` | 57,797 | 67 | 4 | native render OK |
| `img-start-001.hwp` | 3 | 209,463 | `794x1123` | 108,951 | 131 | 0 | native render OK |

이 표는 Studio/native parity 수치가 아니라 native render sanity check다. `render-debug-compare`의 core SVG raster diff는 `qlmanage rasterize failed`로 생성되지 않았다.

## 얻은 교훈

1. `rhwp-studio` reference와 native preview의 차이를 renderer output 차이로 바로 해석하면 안 된다. open contract, document context, resource population을 먼저 분리해야 한다.
2. filename은 단순 표시용 문자열이 아니라 머리말/꼬리말 필드 치환에 쓰이는 document context다.
3. external linked image는 PageLayerTree나 Skia 전환만으로 해결되지 않는다. renderer 입력 전에 document state에 image bytes가 들어와야 한다.
4. app-bundled `rhwp-studio`의 `/samples/<basename>` fetch는 public app의 source directory resolution으로 보기 어렵다. 개발 서버 편의 경로와 제품 open policy를 분리해야 한다.
5. #280 harness는 v0.1.4 품질 판단의 핵심 도구지만, 현재 readiness failure를 별도 안정화하지 않으면 정량 비교 자료를 반복 생산하기 어렵다.

## 후속 handoff

| 대상 | 상태 | handoff |
|------|------|---------|
| [#280](https://github.com/postmelee/alhangeul-macos/issues/280) | CLOSED | harness 자체는 구축됐지만 readiness polling 실패가 반복됐다. 이후 PR 수치 검증 전에 JS result unsupported type 원인과 settle 조건을 재점검해야 한다. |
| [#281](https://github.com/postmelee/alhangeul-macos/issues/281) | OPEN | PageLayerTree overlay metadata 연결은 진행 가능하다. external linked image bytes 누락은 #281 범위로 끌어오지 않는다. |
| [#282](https://github.com/postmelee/alhangeul-macos/issues/282) | OPEN | flow/behind/front compositor 보강은 진행 가능하다. base directory/resource injection과 별개로 overlay z-order를 다룬다. |
| [#116](https://github.com/postmelee/alhangeul-macos/issues/116) | OPEN | watermark 효과/투명키는 embedded/resolved image와 compositor 위에서 다룬다. external linked image open contract와 분리한다. |
| [#122](https://github.com/postmelee/alhangeul-macos/issues/122) | OPEN | fill mode, tile, placement parity는 renderer geometry 범위다. 외부 이미지 resource discovery/injection과 분리한다. |
| [#121](https://github.com/postmelee/alhangeul-macos/issues/121) | OPEN | RawSvg/OLE/chart 리소스 렌더링 보강은 현재 open pipeline 조사 결과와 직접 충돌 없음. |
| [#110](https://github.com/postmelee/alhangeul-macos/issues/110) | OPEN | Placeholder/FormObject 정적 프리뷰 보강은 현재 open pipeline 조사 결과와 직접 충돌 없음. |

## upstream 연계

이번 조사에서 확인된 filename/external image 문제는 downstream renderer 구현만으로 닫기보다 upstream `rhwp`의 멀티 렌더러 contract와 맞춰 가는 것이 적절하다.

이를 위해 별도 upstream 이슈를 생성했다.

| upstream issue | 역할 |
|----------------|------|
| [edwardkim/rhwp#1141](https://github.com/edwardkim/rhwp/issues/1141) | Skia/CanvasKit direct replay 문서 컨텍스트·외부 리소스 정합 상위 이슈 |
| [edwardkim/rhwp#1144](https://github.com/edwardkim/rhwp/issues/1144) | filename field context 멀티 렌더러 경로 일관화 |
| [edwardkim/rhwp#1142](https://github.com/edwardkim/rhwp/issues/1142) | external image reference discovery contract |
| [edwardkim/rhwp#1143](https://github.com/edwardkim/rhwp/issues/1143) | external image bytes injection/resource resolver contract |

GitHub native Sub-issues 연결은 maintainer 권한이 필요해 현재 계정으로는 실패했다. #1141 본문에는 하위 이슈 체크리스트와 실행 순서를 남겨 두었다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m014_283.md` | 수행계획서 |
| `mydocs/plans/task_m014_283_impl.md` | 구현계획서 |
| `mydocs/working/task_m014_283_stage1.md` | open pipeline inventory 보고서 |
| `mydocs/working/task_m014_283_stage2.md` | normalization 영향 조사 보고서 |
| `mydocs/working/task_m014_283_stage3.md` | filename/base directory/external image 영향 조사 보고서 |
| `mydocs/report/task_m014_283_report.md` | 최종 결과보고서 |
| `mydocs/orders/20260527.md` | #283 오늘할일 상태 갱신 |

제품 source, renderer, bridge, bundled resource는 변경하지 않았다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `./scripts/verify-rhwp-studio-assets.sh` | OK | Stage 2에서 통과 |
| #280 visual diff harness | FAIL | Stage 2/3 모두 readiness 오류. 비교 수치 없음 |
| native render-debug PNG 생성 | OK | Stage 3 후보 4개 sample 모두 native PNG 생성 |
| `git diff --check` | OK | Stage 1-3 및 Stage 4 최종 문서 검증에서 통과 |

Stage 4에서는 새 production 검증을 추가하지 않았다. 이번 단계의 검증은 보고서와 오늘할일 문서가 Stage 1-3 결론을 빠짐없이 참조하는지 확인하는 문서 검증이다.

## 잔여 위험

| 항목 | 위험 | 처리 |
|------|------|------|
| visual diff metric 부재 | 정량 parity 판단을 못 했다. | #280 readiness 안정화 후 #281 이후 PR에서 다시 수치화한다. |
| external linked image sample 부족 | 현재 repo sample만으로 실제 sibling external image 요구를 확정하지 못했다. | upstream/resource contract 후속 또는 별도 fixture 확보 시 재검증한다. |
| filename field sample 부족 | 파일명 필드 치환이 실제 output diff로 이어지는 sample을 이번 단계에서 확보하지 못했다. | filename field fixture 확보 후 upstream #1144 또는 downstream bridge 이슈에서 검증한다. |
| app-bundled Studio `/samples` fetch | 실제 warning/runtime timing을 직접 캡처하지 못했다. | harness 안정화 뒤 console/log capture로 재확인한다. |
| external image async timing | `populateExternalImagesFromDevServer()`가 `await`되지 않는다. | reference capture settle 조건에 image injection 완료 여부가 포함되는지 별도 확인한다. |

## PR 게시 준비

| 항목 | 값 |
|------|----|
| 작업 브랜치 | `local/task283` |
| 게시 브랜치 | `publish/task283` |
| PR base | `devel` |
| PR 제목 후보 | `Document rhwp-studio open pipeline parity findings` |

PR 본문에는 source 변경이 없는 조사 PR임을 명시하고, visual diff metric 미생성 원인, native sanity 측정값, #281/#282/#116/#122/#121/#110 handoff, upstream #1141-#1144 연결을 포함하면 된다.

## 작업지시자 승인 요청

최종 결과보고서 작성과 오늘할일 상태 갱신을 마쳤다. 이 보고서 기준으로 `publish/task283` 원격 브랜치 push와 `devel` 대상 Open PR 생성을 진행하려면 작업지시자 승인이 필요하다.
