# Task M014 #280 Stage 4 보고서 - preview diff sample set 문서화

## 단계 개요

- 이슈: #280 rhwp-studio 기준 preview visual diff harness 구축
- 단계: Stage 4. sample set과 사용 문서 정리
- 목표: v0.1.4 렌더 개선 이슈들이 공통으로 재사용할 sample set, 실행 명령, 수치 해석 기준, 한계, 후속 이슈 handoff를 문서화한다.

이번 단계에서는 harness code를 변경하지 않았다.

## 변경 파일

### `mydocs/tech/v014_preview_visual_diff_harness.md`

새 기술 문서를 추가했다.

포함 내용:

- 기본 실행 명령과 `--policy`, `--page`, `--viewport`, `--settle-ms`, `--resource-dir` 옵션
- `studio`, `native`, `diff`, `summary.md` 산출물 구조
- `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`, `DiffBounds`, `NativeBackend`, `NativeMs` 해석 기준
- editor chrome 제외와 canvas 내부 margin guide residual 기준
- `canvasDataURL`, `overlayIncluded=false` 한계
- v0.1.4 기본 sample set 6개와 확장 sample set
- #282, #116, #122, #121, #110 handoff
- 후속 PR/보고서 기록 기준

## 기본 sample set

문서화한 기본 sample set:

| 목적 | 샘플 |
|---|---|
| 일반 HWP smoke | `samples/basic/request.hwp` |
| watermark/effect | `samples/복학원서.hwp` |
| image crop/fill | `samples/pic-crop-01.hwp` |
| form/placeholder HWP | `samples/form-01.hwp` |
| form/placeholder HWPX | `samples/hwpx/form-002.hwpx` |
| HWPX smoke | `samples/hwpx/hwpx-01.hwpx` |

확장 sample set:

- `samples/tac-img-02.hwp`
- `samples/tac-img-02.hwpx`
- `samples/eq-01.hwp`
- `samples/draw-group.hwp`
- `samples/table-vpos-01.hwp`

## Stage 4 smoke 결과

실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage4 --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/form-01.hwp samples/hwpx/form-002.hwpx samples/hwpx/hwpx-01.hwpx
```

결과:

- 6개 기본 샘플 모두 OK
- `studio`, `native`, `diff`, `summary.md` 생성 확인
- `request.hwp`와 `pic-crop-01.hwp`에서 기존 renderer의 `LAYOUT_OVERFLOW` stderr 관찰
- Stage 4 smoke는 WKWebView 실행이 필요하므로 sandbox 밖 실행 승인을 받아 수행했다.

요약 수치:

| 파일 | ChangedPercent | MeanRGBDelta | NativeBackend | NativeMs |
|---|---:|---:|---|---:|
| `request.hwp` | `18.1021%` | `11.5796` | `coreGraphics` | `1049.1ms` |
| `복학원서.hwp` | `32.3726%` | `42.9398` | `coreGraphics` | `415.3ms` |
| `pic-crop-01.hwp` | `2.0423%` | `0.8092` | `coreGraphics` | `6.7ms` |
| `form-01.hwp` | `0.8066%` | `0.4845` | `coreGraphics` | `2.2ms` |
| `form-002.hwpx` | `16.8925%` | `17.6456` | `coreGraphics` | `35.5ms` |
| `hwpx-01.hwpx` | `15.1839%` | `15.6722` | `coreGraphics` | `29.0ms` |

산출물 위치:

```text
build.noindex/task280-stage4/
```

## 해석 기준 확정

- `ChangedPercent`는 hard gate가 아니라 관찰 지표다.
- Stage 4 기준 reference는 `captureMode=canvasDataURL`이며 `overlayIncluded=false`다.
- DOM overlay는 PNG에 포함하지 않고 `studio/*.json`의 `overlayCount`로 기록한다.
- canvas 내부 margin guide와 crop mark는 남을 수 있으므로 diff 해석에서 editor chrome residual로 분리한다.
- native output과 Studio reference scale이 다르므로 diff는 native output을 Studio reference 크기로 확대해 계산한다.

## 검증

실행:

```bash
rg -n "#116|#122|#121|#110|#282|rhwp-studio|editor chrome|margin guide|changedPixels" \
  mydocs/tech/v014_preview_visual_diff_harness.md build.noindex/task280-stage4/summary.md
git diff --check
```

결과:

- 기술 문서에 후속 이슈 handoff와 수치 해석 기준이 포함됐다.
- whitespace 검증 통과.

## 다음 단계 승인 요청

Stage 5에서는 전체 harness 최종 smoke를 실행하고, 최종 보고서에 smoke 측정 결과, 관찰, 수치 비교자료, 한계, 후속 handoff를 정리한다.
