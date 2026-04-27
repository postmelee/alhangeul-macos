# Task M020 #65 Stage 1 완료보고서

## 단계 목표

현행 native 렌더링 smoke 경로와 rhwp core SVG 진단 경로를 확인하고, 이후 스크립트가 생성할 표준 산출물 규격을 확정한다.

## 조사 내용

### 1. native smoke renderer 경로

현재 `scripts/validate-stage3-render.sh`는 다음 Swift 파일과 `Frameworks/universal/librhwp.a`를 함께 컴파일해 `stage3_render_check` 실행 파일을 만든다.

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/FontFallback.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `scripts/stage3_render_check.swift`

`scripts/stage3_render_check.swift`의 현재 동작은 다음과 같다.

- 입력 문서의 1페이지를 대상으로 한다.
- `RhwpDocument.renderPageTree(at: 0)`로 render tree를 디코딩한다.
- `CGTreeRenderer`가 scale `1.0`의 bitmap context에 렌더링한다.
- 출력 파일명은 `{basename}-page1.png` 형식이다.
- text run 수, Hangul run 수, Hangul scalar 수, non-white pixel 수를 smoke 기준으로 출력한다.

즉, 현재 native smoke PNG는 HostApp/Quick Look/Thumbnail이 공유하는 `RenderNode` + `CGTreeRenderer` 해석 경로를 재사용한다.

### 2. rhwp core SVG 진단 경로

`RhwpDocument.renderPageSVG(at:)`는 `rhwp_render_page_svg`를 호출한다. RustBridge의 해당 C ABI는 core의 `render_page_svg_native` 결과를 반환한다.

이 경로는 제품 표시 fallback이 아니라 core 기준 렌더링을 확인하기 위한 진단 산출물로 사용해야 한다.

### 3. render tree raw JSON 범위

현재 `RhwpDocument.renderPageTree(at:)`는 `rhwp_render_page_tree`가 반환한 JSON 문자열을 즉시 `RenderNode`로 디코딩하고, raw JSON 문자열은 외부로 노출하지 않는다.

따라서 Stage 2에서는 `RhwpDocument`에 raw render tree JSON을 반환하는 좁은 API를 추가하는 것이 필요하다. 이 API는 기존 디코딩 경로를 대체하지 않고, 디버깅 스크립트가 JSON dump를 저장하기 위한 보조 표면으로 둔다.

## 산출물 규격

필수 산출물:

| 산출물 | 파일명 | 의미 |
|------|--------|------|
| render tree JSON | `{basename}-page{N}-render-tree.json` | core가 native renderer에 넘긴 render tree 원문 |
| core SVG | `{basename}-page{N}-core.svg` | `render_page_svg_native` 기준 SVG |
| native PNG | `{basename}-page{N}-native.png` | `RenderNode` + `CGTreeRenderer` 기준 PNG |
| summary | `{basename}-page{N}-summary.txt` | page size, text stats, non-white pixel, 산출물 상태 |

선택 산출물:

| 산출물 | 파일명 | 의미 |
|------|--------|------|
| core raster PNG | `{basename}-page{N}-core.png` | core SVG를 rasterize한 PNG |
| diff PNG | `{basename}-page{N}-diff.png` | native PNG와 core raster PNG의 차이 표시 |
| diff summary | summary 파일 내 `Diff` 섹션 | 비교 크기, 다른 픽셀 수, 비율, max channel delta |

선택 산출물은 SVG rasterizer 사용 가능 여부에 따라 생성하지 못할 수 있다. 이 경우에도 필수 산출물 생성은 성공으로 취급한다.

## 검증

### 산출물 준비

분리 worktree에는 생성 산출물인 `Frameworks/universal/librhwp.a`가 없어 최초 smoke 검증이 다음 오류로 중단됐다.

```text
ERROR: missing /private/tmp/rhwp-mac-task65/Frameworks/universal/librhwp.a
Run: /private/tmp/rhwp-mac-task65/scripts/build-rust-macos.sh
```

이후 다음 명령으로 로컬 산출물을 생성했다.

```bash
./scripts/build-rust-macos.sh
```

결과:

- `Frameworks/universal/librhwp.a` 생성
- `Frameworks/Rhwp.xcframework` 생성
- FFI symbol set 확인 성공
- `xcodebuild`가 CoreSimulator 관련 경고를 출력했지만 `xcframework successfully written out`으로 종료

생성된 `Frameworks/`, `RustBridge/target/`, `output/`은 git ignored 산출물이다.

### native renderer smoke

```bash
./scripts/validate-stage3-render.sh output/task65-stage1 /Users/melee/Documents/samples/table-in-tbox.hwp
```

결과:

```text
OK table-in-tbox.hwp: page=1 size=794x1123 textRuns=472 hangulRuns=187 hangulScalars=779 nonWhitePixels=11845 png=/private/tmp/rhwp-mac-task65/output/task65-stage1/table-in-tbox-page1.png
```

생성 PNG:

```text
PNG image data, 794 x 1123, 8-bit/color RGBA, non-interlaced
```

### core SVG 추출 확인

커밋하지 않는 `/tmp/rhwp_export_svg.swift` 임시 helper를 사용해 같은 worktree의 `RhwpDocument.renderPageSVG(at:)` 경로를 확인했다.

결과:

```text
SVG table-in-tbox.hwp: page=1 bytes=434334 path=output/task65-stage1/table-in-tbox-rhwp-core-page1.svg
```

SVG 첫 줄:

```text
<svg xmlns="http://www.w3.org/2000/svg" width="793.7066666666667" height="1122.5066666666667" viewBox="0 0 793.7066666666667 1122.5066666666667">
```

native PNG는 `794x1123`이고 core SVG의 logical size는 `793.7066666666667x1122.5066666666667`이므로, Stage 3 diff 구현에서는 rasterize/비교 전 반올림으로 인한 1px 내외 크기 차이를 고려해야 한다.

## Stage 2 변경 범위

Stage 2에서 필요한 변경은 다음으로 확정한다.

- `RhwpDocument`에 raw render tree JSON 반환 API 추가
- 새 Swift helper에서 core SVG, render tree JSON, native PNG, summary 생성
- 새 shell wrapper에서 기존 `validate-stage3-render.sh`와 같은 방식으로 Swift helper 빌드
- output file naming은 이번 단계의 산출물 규격을 따른다.

Stage 2에서는 아직 SVG rasterize와 pixel diff를 필수로 구현하지 않는다. 해당 작업은 Stage 3에서 선택 산출물로 분리한다.

## 변경 파일

- `mydocs/working/task_m020_65_stage1.md`

## 승인 요청

Stage 1 완료를 승인하면 Stage 2 core/native 산출물 생성 helper 구현으로 진행한다.
