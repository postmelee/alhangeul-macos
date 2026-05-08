# Task M015 #120 Stage 1 완료보고서

## 단계 목적

문제 샘플의 core SVG, render tree, native PNG 기준 산출물을 생성하고, 텍스트 위치 차이가 Swift native renderer의 run 내부 advance 처리에서 발생하는지 확인했다.

이번 단계는 source code 변경 없이 기준 조사와 Stage 2 구현 범위 확정만 수행했다.

## 산출물

- 기준 산출물: `/private/tmp/rhwp-task120-stage1-hongbo`
- 기준 산출물: `/private/tmp/rhwp-task120-stage1-center`
- 기준 산출물: `/private/tmp/rhwp-task120-stage1-right`
- 기준 산출물: `/private/tmp/rhwp-task120-stage1-justify`
- 단계 보고서: `mydocs/working/task_m015_120_stage1.md`

각 산출물 디렉터리는 page 1 기준 render tree JSON, core SVG, native PNG, summary를 포함한다. `qlmanage` rasterize는 4개 샘플 모두 실패해 core raster PNG와 diff PNG는 생성되지 않았다. 이는 `render-debug-compare.sh`의 선택 산출물 실패이며, Stage 1의 필수 산출물인 render tree JSON/core SVG/native PNG/summary 생성은 성공했다.

## 본문 변경 정도 / 본문 무손실 여부

소스, 스크립트, 매뉴얼 본문은 변경하지 않았다. 새로 추가한 파일은 Stage 1 완료보고서뿐이다.

## 조사 결과

### 샘플 hash

```text
4062580dbe01654a903c88a33ac2443ba1682b9d00aeb324b749f9a902f47257  samples/20250130-hongbo.hwp
3c2382348e74412a662ede17e12c36449206d33b3eb335d05778bcec40fa5513  samples/re-align-center-hancom.hwp
bd427cbae70ffb6f82792e5dbe7e2b3b46fe10cfc29d69b30b773d4db2f2ae3a  samples/re-align-right-hancom.hwp
dc7e3d702e6df44ede782485e470f85aa0ab49b83a9d06645ee84a46b0e7a9ef  samples/re-align-justify-hancom.hwp
```

### summary 핵심값

| 샘플 | RenderTreeJSONBytes | CoreSVGBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs | Diff |
|------|---------------------|--------------|----------------------|----------|------------|---------------------|------|
| `20250130-hongbo.hwp` | 99137 | 235786 | 84406 | 60 | 35 | 0 | qlmanage rasterize failed |
| `re-align-center-hancom.hwp` | 6696 | 29578 | 6559 | 3 | 3 | 0 | qlmanage rasterize failed |
| `re-align-right-hancom.hwp` | 6698 | 29581 | 6500 | 3 | 3 | 0 | qlmanage rasterize failed |
| `re-align-justify-hancom.hwp` | 6674 | 29602 | 6582 | 3 | 3 | 0 | qlmanage rasterize failed |

### 문제 run 측정

`20250130-hongbo.hwp`의 핵심 run:

| id | text | bbox x | bbox width | font | letterSpacing | extraCharSpacing | availableWidth | lineXOffset | CoreText width |
|----|------|--------|------------|------|---------------|------------------|----------------|-------------|----------------|
| 39 | `2026. 1. 30.(` | 588.3533 | 87.0 | 돋움체 13.333 bold | 0.0 | 0.0 | 138.9333 | 15.9667 | 72.5333 |
| 40 | `금)` | 675.3533 | 20.0 | 돋움체 13.333 bold | 0.0 | 0.0 | 138.9333 | 102.9667 | 16.08 |
| 50 | `혹한기 봉화댐 건설 현장점검 ‘안전 온도 높인다’` | 84.88 | 624.0 | 함초롬돋움 32 bold | -3.52 | 0.5536 | 623.9467 | 0.0 | 496.8640 |

core SVG는 run 내부 문자를 개별 x 좌표로 출력한다.

- 날짜 run은 `2026. 1. 30.(`가 x `588.3533`에서 시작하고, `(`가 x `668.3533`, 다음 run `금`이 x `675.3533`에 온다.
- native renderer는 id 39 전체를 CoreText 폭 `72.5333pt`로 그리므로 id 39의 실제 끝이 약 x `660.8867`에 머문다. 다음 run id 40은 bbox x `675.3533`에서 시작해 `(금)` 사이가 벌어진다.
- 제목 run은 bbox 폭 `624.0pt`와 거의 같은 core SVG glyph x span을 가진다. 하지만 native renderer는 CoreText 폭 `496.8640pt`로 그려 bbox 오른쪽 약 `127pt`를 비워 두며, 결과적으로 제목이 왼쪽으로 치우쳐 보인다.

정렬 샘플 3종의 render tree:

| 샘플 | 주요 run bbox x | bbox width | availableWidth | lineXOffset | extraCharSpacing |
|------|-----------------|------------|----------------|-------------|------------------|
| center 1-2행 | 118.8533 | 556.0 | 566.9333 | 5.4667 | 0.0 |
| center 3행 | 306.3533 | 181.0 | 566.9333 | 192.9667 | 0.0 |
| right 1-2행 | 124.32 | 556.0 | 566.9333 | 10.9333 | 0.0 |
| right 3행 | 499.32 | 181.0 | 566.9333 | 385.9333 | 0.0 |
| justify 1-2행 | 113.3867 | 567.0 | 566.9333 | 0.0 | 0.2543 |
| justify 3행 | 113.3867 | 181.0 | 566.9333 | 0.0 | 0.0 |

정렬 샘플에서 `lineXOffset`은 이미 `TextRun` bbox x에 반영되어 있다. 따라서 Stage 2에서 `lineXOffset`을 다시 더하면 이중 적용이 된다. 반면 `extraCharSpacing`, `extraWordSpacing`, run bbox width와 CoreText width 차이는 현재 drawing에 반영되지 않는다.

### 현재 renderer 동작

`Sources/RhwpCoreBridge/CGTreeRenderer.swift`의 `renderTextRun`은 다음 흐름이다.

- bbox x/y로 이동하고 bbox 내부 좌표계에서 CoreText를 그린다.
- font fallback, bold/italic, ratio, `letterSpacing`만 적용한다.
- `NSAttributedString` 하나와 `CTLineDraw` 한 번으로 run 전체를 그린다.
- `extraCharSpacing`, `extraWordSpacing`, `availableWidth`, `lineXOffset`, `tabStops`, `inlineTabs`는 drawing 계산에 직접 사용하지 않는다.

`Sources/RhwpCoreBridge/RenderTree.swift`는 `availableWidth`, `lineXOffset`, `tabStops`, `inlineTabs`, `extraWordSpacing`, `extraCharSpacing`를 이미 디코딩한다. 즉 Stage 2는 우선 Swift renderer 내부 계산 보강으로 시작할 수 있다.

## 검증 결과

구현계획서 Stage 1 검증 명령을 실행했다.

```text
git status --short --branch
## local/task120...origin/devel [ahead 2]
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage1-hongbo samples/20250130-hongbo.hwp
OK 20250130-hongbo.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage1-hongbo/20250130-hongbo-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage1-hongbo/20250130-hongbo-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage1-hongbo/20250130-hongbo-page1-native.png summary=/private/tmp/rhwp-task120-stage1-hongbo/20250130-hongbo-page1-summary.txt
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage1-center samples/re-align-center-hancom.hwp
OK re-align-center-hancom.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage1-center/re-align-center-hancom-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage1-center/re-align-center-hancom-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage1-center/re-align-center-hancom-page1-native.png summary=/private/tmp/rhwp-task120-stage1-center/re-align-center-hancom-page1-summary.txt
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage1-right samples/re-align-right-hancom.hwp
OK re-align-right-hancom.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage1-right/re-align-right-hancom-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage1-right/re-align-right-hancom-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage1-right/re-align-right-hancom-page1-native.png summary=/private/tmp/rhwp-task120-stage1-right/re-align-right-hancom-page1-summary.txt
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage1-justify samples/re-align-justify-hancom.hwp
OK re-align-justify-hancom.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage1-justify/re-align-justify-hancom-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage1-justify/re-align-justify-hancom-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage1-justify/re-align-justify-hancom-page1-native.png summary=/private/tmp/rhwp-task120-stage1-justify/re-align-justify-hancom-page1-summary.txt
```

```text
test -s /private/tmp/rhwp-task120-stage1-hongbo/20250130-hongbo-page1-render-tree.json
test -s /private/tmp/rhwp-task120-stage1-hongbo/20250130-hongbo-page1-summary.txt
```

두 파일 모두 존재하고 비어 있지 않다.

```text
rg -n "lineXOffset|extraWordSpacing|extraCharSpacing|tabStops|availableWidth|renderTextRun" Sources/RhwpCoreBridge scripts
Sources/RhwpCoreBridge/RenderTree.swift:397:    let tabStops: [TabStopInfo]
Sources/RhwpCoreBridge/RenderTree.swift:399:    let availableWidth: Double
Sources/RhwpCoreBridge/RenderTree.swift:400:    let lineXOffset: Double
Sources/RhwpCoreBridge/RenderTree.swift:403:    let extraWordSpacing: Double
Sources/RhwpCoreBridge/RenderTree.swift:404:    let extraCharSpacing: Double
Sources/RhwpCoreBridge/CGTreeRenderer.swift:735:    private func renderTextRun(_ run: TextRunNode, bbox: BBox, in ctx: CGContext) {
```

추가 준비 명령:

```text
./scripts/build-rust-macos.sh
Done: /private/tmp/rhwp-mac-task120/Frameworks/Rhwp.xcframework
```

새 worktree에 Rust bridge 산출물이 없어 최초 render debug 실행이 실패했으므로, 매뉴얼에 따라 `build-rust-macos.sh`를 실행했다. XCFramework는 정상 생성됐다. 실행 중 CoreSimulator 관련 xcodebuild 경고가 출력됐지만 산출물 생성 실패로 이어지지는 않았다.

추가 측정:

```text
CoreText width:
혹한기 봉화댐 건설 현장점검 ‘안전 온도 높인다’ = 496.8640
2026. 1. 30.( = 72.5333
금) = 16.08
```

## 잔여 위험

- core SVG처럼 완전한 글자별 x 배열은 현재 Swift render tree JSON에 없다. 기존 style 값과 bbox만으로 상당 부분 보정할 수 있지만, 문서별 복잡한 shaping은 한계가 있을 수 있다.
- `lineXOffset`은 bbox x에 이미 반영되어 있으므로, Stage 2에서 style 값을 직접 더하는 방식은 회귀를 만든다.
- CoreText cluster 분리 방식이 부정확하면 조합문자, 라틴 ligature, 특수기호가 깨질 수 있다.
- `qlmanage` rasterize 실패로 자동 diff PNG는 없다. Stage 2 이후에도 native PNG와 summary, 필요 시 수동 확인 중심으로 판단해야 한다.

## 다음 단계 영향

Stage 2 구현 범위는 다음으로 확정한다.

- `renderTextRun`에 CoreText measured width와 bbox width 차이를 계산하는 helper를 추가한다.
- `lineXOffset`은 추가 적용하지 않고, bbox x/y를 render tree의 확정 위치로 취급한다.
- `extraCharSpacing`, `extraWordSpacing`, `letterSpacing`, `ratio`, bbox width를 이용해 run 내부 advance를 보정한다.
- 날짜처럼 run이 나뉜 경우 다음 run bbox와 이어지도록 현재 run의 target advance를 bbox width에 맞춘다.
- 제목처럼 CoreText 폭이 bbox보다 크게 짧은 경우 cluster 단위 배치가 필요하므로 Stage 3에서 실제 drawing 경로로 확장할 수 있게 Stage 2 helper 경계를 둔다.
- tab/inlineTabs는 기준 샘플에서 직접 문제가 확인되지 않았으므로 Stage 2에서는 helper 입력과 fallback만 열어 두고, 실제 tab stop drawing은 Stage 3-4 검증 결과에 따라 좁게 다룬다.

## 승인 요청

Stage 1 기준 조사와 계약 한계 정리를 완료했다. Stage 2 `TextRun` 배치 계산 보강에 진입해도 되는지 승인 요청한다.
