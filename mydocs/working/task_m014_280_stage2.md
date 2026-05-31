# Task M014 #280 Stage 2 보고서 - rhwp-studio reference capture 추가

## 단계 개요

- 이슈: #280 rhwp-studio 기준 preview visual diff harness 구축
- 단계: Stage 2. rhwp-studio reference capture 구현
- 목표: bundled `rhwp-studio`가 실제로 문서를 열어 렌더한 page content를 PNG와 metadata JSON으로 저장한다.

이번 단계에서는 native preview render와 pixel diff는 구현하지 않았다. 해당 범위는 Stage 3로 남겼다.

## 변경 파일

### `scripts/preview-visual-diff-harness.sh`

새 shell wrapper를 추가했다.

- `scripts/verify-rhwp-studio-assets.sh`로 bundled Studio asset 구조를 먼저 검증한다.
- Swift helper를 `build.noindex/<output>/preview_visual_diff_harness`로 compile한다.
- 기본 CLI:

```bash
./scripts/preview-visual-diff-harness.sh <output-dir> \
  [--page N] [--viewport WIDTHxHEIGHT] [--settle-ms N] [--resource-dir DIR] \
  <hwp-or-hwpx> [...]
```

기본값:

| 옵션 | 기본값 |
|---|---|
| `--page` | `1` |
| `--viewport` | `1400x1800` |
| `--settle-ms` | `120` |
| `--resource-dir` | `Sources/HostApp/Resources/rhwp-studio` |

### `scripts/preview_visual_diff_harness.swift`

새 Swift/WebKit helper를 추가했다.

- `alhangeul-studio://app/...` script-local resource scheme handler를 구현했다.
- `alhangeul-document://current?revision=...` script-local document scheme handler를 구현했다.
- `rhwp-studio` load URL은 HostApp과 같은 형태로 만든다.
- `#scroll-content canvas`를 page selector로 사용한다.
- `requestAnimationFrame` 두 번과 `--settle-ms`만큼의 추가 settle 시간을 둔다.
- menu, toolbar, status bar, ruler chrome을 CSS로 숨긴다.
- page canvas, overlay count, viewport, devicePixelRatio, Studio provenance, capture mode를 metadata JSON에 기록한다.

산출물 구조:

```text
<output-dir>/
  studio/
    {file}-page{N}-studio.png
    {file}-page{N}-studio.json
  summary.md
```

## 구현 중 관찰과 결정

초기 설계는 `WKWebView.takeSnapshot`으로 page rect를 직접 캡처하는 방식이었다. 실제 smoke에서 `takeSnapshot`은 page canvas 영역의 배경은 캡처하지만 canvas backing store의 문서 내용은 빈 화면처럼 잡는 현상이 있었다.

동시에 JavaScript로 canvas backing store를 샘플링하면 non-white pixel이 확인되어, `rhwp-studio` 렌더 자체는 완료된 상태임을 확인했다. 따라서 Stage 2 helper는 다음 방식으로 고정했다.

1. WebKit에서 Studio를 실제로 로드하고 문서를 렌더한다.
2. page canvas readiness와 canvas backing store non-white sample을 확인한다.
3. reference PNG는 canvas `toDataURL('image/png')` 결과를 흰 배경 임시 canvas에 합성해 저장한다.
4. DOM overlay는 `overlayCount`로 기록하되, 현재 PNG에는 포함하지 않는다.

metadata에는 이 결정을 다음 필드로 남긴다.

| 필드 | 의미 |
|---|---|
| `captureMode` | 현재 `canvasDataURL` |
| `overlayIncluded` | 현재 `false` |
| `overlayCount` | page canvas와 교차하는 DOM overlay 후보 수 |
| `canvasSampleNonWhitePixels` / `canvasSamplePixels` | canvas backing store가 실제 내용을 갖는지 확인하는 샘플 |
| `snapshotSampleNonWhitePixels` / `snapshotSamplePixels` | `takeSnapshot` 결과 관찰값 |

이 결정은 Stage 3 diff를 진행하기 위한 실용적인 기준이다. 단, DOM overlay까지 포함한 완전한 Studio visual snapshot은 아직 해결되지 않았다.

## Smoke 결과

실행:

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage2 --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp
find build.noindex/task280-stage2 -maxdepth 2 -type f | sort
sed -n '1,80p' build.noindex/task280-stage2/summary.md
sips -g pixelWidth -g pixelHeight \
  build.noindex/task280-stage2/studio/request-page1-studio.png \
  build.noindex/task280-stage2/studio/복학원서-page1-studio.png
```

결과:

- `verify-rhwp-studio-assets.sh`: OK
- `request.hwp`: OK
- `복학원서.hwp`: OK

| 파일 | PNG 크기 | CanvasSampleNonWhite | CaptureMode | CaptureMs | PNG bytes |
|---|---:|---:|---|---:|---:|
| `request.hwp` | `1133x1587` | `4535/36774` | `canvasDataURL` | `7504.2ms` | `211754` |
| `복학원서.hwp` | `1587x2245` | `1901/44250` | `canvasDataURL` | `2277.7ms` | `328133` |

시각 확인:

- `request.hwp` reference PNG는 문서 본문, 표, 색상, 이미지 로고가 보이는 상태로 생성됐다.
- `복학원서.hwp` reference PNG는 한글/영문 텍스트, 표, 붉은 도장 요소가 보이는 상태로 생성됐다.

## Sandbox 관찰

Codex sandbox 안에서 WKWebView helper를 실행하면 WebKit이 다음 계열의 sandbox extension을 만들지 못해 page readiness까지 진행하지 못했다.

- `com.apple.gputools.service`
- `com.apple.coreservices.launchservicesd`
- `com.apple.webinspector`
- `~/Library/WebKit/...`
- `~/Library/Caches/...`

따라서 Stage 2 smoke는 sandbox 밖 실행 승인을 받아 검증했다. 일반 로컬 터미널 실행에서는 이 제약이 없을 것으로 판단한다.

## 한계와 Stage 3 반영점

- 현재 reference PNG는 `canvasDataURL` 기반이라 DOM overlay를 포함하지 않는다.
- `overlayCount`와 `overlayIncluded=false`를 metadata에 기록하므로 Stage 3 summary에서 이 한계를 노출해야 한다.
- `WKWebView.takeSnapshot` 결과는 관찰값으로만 보존한다. 이후 DOM overlay까지 포함해야 하면 별도 overlay rasterization 또는 WebKit snapshot 대체 경로가 필요하다.
- Stage 3에서는 native render와 diff를 구현하되, 먼저 canvas reference와 native output의 크기 정렬 및 diff 산출을 완성하는 것이 우선이다.

## 검증

실행:

```bash
git diff --check -- scripts/preview-visual-diff-harness.sh scripts/preview_visual_diff_harness.swift
rg -n "preview-visual-diff-harness|preview_visual_diff_harness|canvasDataURL|captureMode|overlayIncluded|canvasSample|snapshotSample|WKWebView|alhangeul-studio|alhangeul-document" \
  scripts/preview-visual-diff-harness.sh scripts/preview_visual_diff_harness.swift
git status --short --branch
```

결과:

- whitespace 문제 없음.
- 새 wrapper와 Swift helper의 핵심 경로를 확인했다.
- Stage 2에서는 `Sources/` 코드를 변경하지 않았다.

## 다음 단계 승인 요청

Stage 3에서는 같은 입력 문서와 page에 대해 `HwpPageImageRenderer` 기반 native PNG를 생성하고, Stage 2 reference PNG와 pixel diff 및 `summary.md`를 생성한다.
