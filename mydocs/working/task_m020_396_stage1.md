# Task M020 #396 Stage 1 완료보고서

## 단계 목적

업스트림 `rhwp` renderer baseline 체계와 현재 macOS preview visual diff harness를 비교해, #396에서 이식할 요소와 macOS Quick Look/Thumbnail surface에 맞게 새로 필요한 adapter 범위를 고정한다.

이번 단계는 inventory와 설계 입력 정리만 수행했다. 제품 Swift/Rust renderer source와 기존 script는 수정하지 않았다.

## 기준 upstream 상태

| 항목 | 값 |
|------|----|
| upstream repo | `https://github.com/edwardkim/rhwp.git` |
| remote `main` HEAD | `10f5c51e65e0e8e9260cf1498972db14ea04c29e` |
| local inspect clone | `/private/tmp/rhwp-upstream-inspect` |
| inspect 방식 | working tree가 LFS checkout 실패 흔적으로 dirty라서 `git show HEAD:...`로 파일 내용을 확인 |

참조 파일:

- https://github.com/edwardkim/rhwp/blob/main/.github/workflows/render-diff.yml
- https://github.com/edwardkim/rhwp/blob/main/.github/workflows/full-renderer-sweep.yml
- https://github.com/edwardkim/rhwp/blob/main/scripts/renderer_baseline.py
- https://github.com/edwardkim/rhwp/blob/main/scripts/renderer_baseline_manifest.json
- https://github.com/edwardkim/rhwp/blob/main/tests/svg_snapshot.rs

## upstream baseline 요소 분해

| 요소 | upstream 구현 | #396에서 이식할 부분 | 그대로 이식하지 않을 부분 |
|------|---------------|---------------------|---------------------------|
| workflow tier | `render-diff.yml`은 PR/수동 빠른 canvas visual diff, `full-renderer-sweep.yml`은 수동 full renderer sweep | quick smoke와 extended sweep 분리 | Linux CI, WASM build, browser CanvasKit setup 자체 |
| manifest | `renderer_baseline_manifest.json`에 `id`, `file`, `category`, `page`, `notes`, sample별 threshold 기록 | 대표 sample manifest와 category/known risk/threshold field | upstream의 `file`은 `samples/` 상대, `page`는 0-based라 로컬 adapter 필요 |
| capture | `renderer_baseline.py`가 `legacy-svg`, `layer-svg`, `native-skia`, `canvas2d`, `canvaskit-*` 산출물을 profile별 capture | 다중 backend artifact matrix와 summary 구조 | macOS Quick Look/Thumbnail에서 CanvasKit surface 비교를 직접 gate로 삼지는 않음 |
| diff metric | browser render diff는 channel tolerance와 max diff ratio를 사용. baseline parity는 `ignoreChannelDelta=8`, `maxDiffRatio=0.005` 중심 | tolerant diff ratio, max channel delta, mean channel delta 개념 | upstream threshold를 macOS CoreGraphics/Skia에 수치 그대로 적용하지 않음 |
| artifact | PNG/SVG, `results.json`, `summary.md`, worst comparison, category/profile summary | summary markdown + machine-readable report + artifact path | upstream output tree 이름과 profile matrix 전체 |
| regression lock | `svg_snapshot.rs`가 golden SVG를 byte-for-byte 비교하고 determinism test 포함 | `KTX.hwp`, `복학원서.hwp` 같은 sentinel sample을 manifest에 명시 | SVG golden 자체는 upstream core 회귀용이며 macOS Quick Look visual parity gate는 아님 |

## upstream workflow inventory

### `render-diff.yml`

- PR path filter는 renderer, WASM API, rhwp-studio, workflow 파일 중심이다.
- 기본 fixture는 browser canvas path의 소수 sample이다.
- 수동 실행에서 fixture list, max pages, full suite, image artifact 여부를 조정한다.
- output은 `rhwp-studio/e2e/screenshots/render-diff/`, `output/e2e/`, Vite log artifact를 남긴다.
- pass 기준은 same size와 diff ratio threshold이며, 실패 또는 `write-images` 옵션에서 PNG artifact를 쓴다.

### `full-renderer-sweep.yml`

- 수동 workflow만 제공한다.
- `cargo test --features native-skia skia`, WASM release build, studio build, browser render diff full suite, renderer baseline multi-profile capture를 묶는다.
- `screen`, `print`, `high-quality`, `fast-preview` profile과 CanvasKit surface 변형을 다룬다.
- output은 layer/svg/skia/e2e/renderer-baseline artifact를 업로드한다.

### `renderer_baseline.py` / `renderer-baseline*.mjs`

- manifest를 읽어 sample id/category/page를 정규화한다.
- native side는 `legacy-svg`, `layer-svg`, `native-skia`를 capture한다.
- browser side는 `canvas2d`, `canvaskit-compat`, `canvaskit-default`를 capture한다.
- `native-skia`와 `canvaskit-default` parity는 1px 이하 size drift를 crop해서 비교하고, `ignoreChannelDelta=8`, `maxDiffRatio=0.005` 기준을 쓴다.
- report는 sample matrix, browser timing, backend parity, native Skia parity, worst comparisons, category/profile summary를 포함한다.

## local harness inventory

현재 macOS harness는 다음 구조다.

| 항목 | 현재 구현 |
|------|-----------|
| entry point | `scripts/preview-visual-diff-harness.sh <out-dir> [--page N] [--policy coreGraphicsOnly|skiaOptIn] ... <files...>` |
| compile target | `scripts/preview_visual_diff_harness.swift`를 AppKit/WebKit 포함 standalone binary로 compile |
| reference capture | bundled `Sources/HostApp/Resources/rhwp-studio`에서 `StudioReferenceRenderer`로 PNG capture |
| native capture | `HwpPageImageRenderer` policy에 따라 CoreGraphics 또는 Skia opt-in PNG 생성 |
| output dirs | `studio/`, `native/`, `diff/`, `summary.md` |
| page convention | CLI `--page`는 1-based |
| policy convention | 한 번의 실행은 `coreGraphicsOnly` 또는 `skiaOptIn` 단일 policy |
| diff pixel | RGB channel max delta가 `12`보다 크면 changed pixel |
| summary fields | `File`, `Status`, `Phase`, `StudioSize`, `NativeSize`, `CompareSize`, `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`, `MaxRGBDelta`, `DiffBounds`, `StudioCapture`, `NativeBackend`, `NativeMs`, artifact path |
| failure phase | navigation/readiness/snapshot/native render/diff 계열 phase로 분류 |

현재 harness의 장점:

- 이미 `CoreGraphics`와 `Skia opt-in` 양쪽을 같은 reference에 대해 측정할 수 있다.
- `ChangedPercent`, `MeanRGBDelta`, `NativeMs`, `StudioCapture`, `NativeBackend`, fallback suffix를 남긴다.
- `studio`, `native`, `diff` PNG artifact가 sample별로 남는다.
- sandbox/WebKit failure를 renderer failure와 구분할 phase field가 있다.

현재 harness의 gap:

- manifest가 없어서 sample category, known risk, threshold, suite tier가 실행 명령 밖에 흩어진다.
- 한 번의 실행은 한 policy만 다루므로 CoreGraphics/Skia pair summary가 자동으로 합쳐지지 않는다.
- `summary.md`는 사람 읽기용 table 중심이고 machine-readable JSON 결과가 없다.
- upstream처럼 category/profile/worst comparison summary가 없다.
- Thumbnail smoke와 visual diff가 한 report에서 연결되지 않는다.
- `복학원서.hwp` 같은 reference capture contamination을 known-risk로 표시할 위치가 없다.
- quick smoke와 extended sweep을 분리하는 표준 CLI가 없다.

## #390 결과를 baseline 요구사항으로 변환

| #390 관찰 | baseline 요구사항 |
|-----------|-------------------|
| `KTX.hwp` Skia changed percent가 CG보다 +15.4874pp 악화 | `KTX.hwp`를 regression sentinel로 manifest에 포함하고, CoreGraphics/Skia delta를 summary에 직접 노출한다 |
| `복학원서.hwp` reference에 `로컬 글꼴 감지` overlay가 섞여 CG/Skia 모두 99%대 diff | known-risk/capture-contamination field를 두고 renderer regression과 분리한다 |
| 다중 PDF 샘플은 page 1 visual만 있고 Skia latency는 CG보다 느림 | manifest에 `pages`와 `surface`를 분리하고, quick smoke는 page 1, extended는 manifest pages를 따른다 |
| Thumbnail Skia output이 CG와 1px dimension 차이 | size mismatch field와 `maxAllowedSizeDriftPx` 후보를 manifest/report에 둔다 |
| sandbox 내부 WebKit readiness timeout | `environmentFailure` 또는 `phase=readiness`를 renderer hard fail과 분리한다 |
| package size는 #259와 같은 `194M` | #396 visual suite 자체의 blocker는 아니며 최종 readiness report에서만 연결한다 |

## macOS adapter 결정

| adapter | 결정 |
|---------|------|
| sample path | upstream `file`과 달리 local manifest는 repo root 상대 `path`를 사용한다 |
| page index | local harness CLI가 1-based라 manifest `pages`도 1-based로 둔다. upstream 0-based page는 참고만 한다 |
| policy pair | Stage 3 helper가 `coreGraphicsOnly`와 `skiaOptIn`을 같은 run 아래에서 실행한다 |
| suite tier | `suite: quick|extended`를 sample 단위 또는 entry 단위로 둔다 |
| known risk | `knownRisk` 배열에 `regression-sentinel`, `capture-contamination`, `size-drift-watch` 같은 문자열을 둔다 |
| threshold | hard fail threshold가 아니라 triage metadata로 둔다. 예: `maxChangedPercentWarn`, `maxSkiaMinusCGChangedPercentWarn`, `maxAllowedSizeDriftPx` |
| output tree | `<out>/coreGraphics/`, `<out>/skia/`, `<out>/summary.md`, 필요 시 `<out>/results.json` 구조로 둔다 |
| failure handling | individual harness failure는 phase/status를 보존한다. quick suite에서는 실패를 명확히 exit nonzero로 반환하되 report는 남긴다 |
| Thumbnail 연결 | Stage 3 helper의 1차 범위는 visual diff orchestration이고, Thumbnail cache/logging 연결은 #389/#392 결과를 받는 확장 지점으로 둔다 |

## Stage 2 manifest schema 초안

Stage 2에서 JSON으로 고정할 schema 후보:

```json
{
  "label": "quicklook-thumbnail-skia-baseline",
  "version": 1,
  "pageIndexBase": 1,
  "suites": {
    "quick": { "description": "fast regression smoke" },
    "extended": { "description": "manual readiness sweep" }
  },
  "samples": [
    {
      "id": "ktx-regression-sentinel",
      "path": "samples/basic/KTX.hwp",
      "category": "single-page-basic",
      "suite": ["quick", "extended"],
      "pages": [1],
      "surfaces": ["quicklook", "thumbnail", "visual"],
      "knownRisk": ["regression-sentinel"],
      "threshold": {
        "maxAllowedSizeDriftPx": 1,
        "maxSkiaMinusCGChangedPercentWarn": 10.0
      },
      "notes": "Skia visual regression persisted in #390."
    }
  ]
}
```

필수 필드 후보:

- `id`
- `path`
- `category`
- `suite`
- `pages`
- `surfaces`
- `knownRisk`
- `threshold`
- `notes`

## Stage 3 helper 방향

Stage 3 helper는 새 renderer를 만들지 않고 orchestration/report만 담당한다.

예상 CLI:

```bash
./scripts/preview-renderer-baseline.sh <out-dir> \
  --suite quick \
  --manifest scripts/preview_renderer_baseline_manifest.json \
  --page-mode first \
  --policy-pair coreGraphicsOnly,skiaOptIn
```

예상 동작:

1. manifest를 검증한다.
2. suite와 page-mode에 맞는 sample/page list를 만든다.
3. `scripts/preview-visual-diff-harness.sh`를 CoreGraphics와 Skia opt-in으로 각각 실행한다.
4. 각 `summary.md`를 집계해 pair summary를 만든다.
5. `KTX.hwp` 같은 regression sentinel은 CoreGraphics/Skia delta를 표에 노출한다.
6. `복학원서.hwp` 같은 known-risk sample은 failure가 아니라 별도 risk column에 표시한다.
7. machine-readable `results.json`은 Stage 3에서 구현 가능하면 추가하고, 어렵다면 Stage 4 이전에 최소 summary markdown부터 고정한다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 upstream/local inventory 보고서 작성과 오늘할일 비고 갱신만 수행했다. 제품 Swift/Rust source와 기존 script는 수정하지 않았다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| upstream remote HEAD 확인 | 통과: `10f5c51e65e0e8e9260cf1498972db14ea04c29e` |
| upstream 파일 확인 | 통과: `git show HEAD:...`로 workflow, manifest, baseline script, SVG snapshot 확인 |
| Stage 1 keyword `rg` | 통과: upstream workflow/manifest/diff 관련 keyword 확인 |
| local harness keyword `rg` | 통과: local harness metric, #390 sentinel, fallback/dimension keyword 확인 |
| `git diff --check` | 통과 |

## 잔여 위험

- upstream clone working tree는 LFS checkout 실패 흔적으로 dirty지만, Stage 1 근거는 `git show HEAD:...`와 원격 HEAD 확인으로 확보했다.
- upstream threshold는 browser/CanvasKit parity 기준이므로 macOS CoreGraphics/Skia threshold로 그대로 쓰면 안 된다.
- Stage 2 manifest가 너무 커지면 #396이 전수 비교 작업으로 변질될 수 있다. quick suite는 반드시 작게 유지한다.
- local harness는 WebKit/AppKit 실행 환경의 영향을 받으므로 Stage 3-4에서 sandbox 밖 재실행 기준을 계속 분리해야 한다.

## 다음 단계 영향

Stage 2에서는 이 보고서의 schema 초안을 바탕으로 `scripts/preview_renderer_baseline_manifest.json`과 `mydocs/tech/skia_preview_renderer_baseline.md`를 작성한다. 특히 `KTX.hwp`는 regression sentinel, `복학원서.hwp`는 capture contamination sentinel로 분리한다.

## 승인 요청

Stage 1 결과에 따라 Stage 2 `대표 샘플 manifest와 threshold/triage policy 설계`로 진행해도 되는지 승인 요청한다.
