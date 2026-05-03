# Task M015 #120 Stage 4 완료보고서

## 단계 목적

Stage 3 cluster drawing 적용 후 기준 샘플 4개를 다시 검증하고, Swift-only 위치 재계산만으로 충분한지 또는 render tree 계약 확장이 필요한지 판단했다.

결론은 다음이다.

- 현재 Swift fallback은 기준 샘플 4개에서 회귀 없이 동작한다.
- rhwp-studio와 동등한 시각 결과를 안정적으로 보장하려면 core가 계산한 글자별 x 위치를 render tree `TextRun`에 optional field로 전달해야 한다.
- 이번 단계에서는 기존 JSON 호환을 유지하면서 Swift 쪽 optional decoder와 renderer 우선 사용 경로를 열어두었다.

## 산출물

- 변경 파일: `Sources/RhwpCoreBridge/RenderTree.swift`
- 변경 파일: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 단계 보고서: `mydocs/working/task_m015_120_stage4.md`
- 기준 산출물: `/private/tmp/rhwp-task120-stage4-hongbo`
- 기준 산출물: `/private/tmp/rhwp-task120-stage4-center`
- 기준 산출물: `/private/tmp/rhwp-task120-stage4-right`
- 기준 산출물: `/private/tmp/rhwp-task120-stage4-justify`
- 추가 smoke 산출물: `/private/tmp/rhwp-task120-stage4-smoke`

## 구현 내용

### optional `char_positions` 수용

`TextRunNode`에 optional field를 추가했다.

```text
char_positions -> TextRunNode.charPositions: [Double]?
```

현재 render tree JSON에는 이 필드가 없으므로 기존 문서 decode와 렌더 결과는 유지된다. Swift의 synthesized `Decodable`은 optional field 누락을 `nil`로 처리하므로 기존 JSON 호환을 깨지 않는다.

### renderer 우선순위

`CGTreeRenderer`의 cluster plan 생성 순서를 다음으로 조정했다.

1. `TextRun.charPositions`가 있고 cluster span과 길이가 맞으면 이를 최우선 사용한다.
2. explicit positions가 있으면 bbox 기반 position scale을 적용하지 않는다.
3. explicit positions가 없으면 Stage 3의 Swift fallback advance 계산을 사용한다.
4. fallback 계산 경로에서는 bbox 폭과 raw advance 차이를 glyph outline scale이 아니라 cluster x position scale로 보정한다.

Swift cluster는 `String` extended grapheme cluster 단위로 drawing하지만, `char_positions`는 core/Rust `char` 기준 배열일 가능성이 높다. 이를 위해 각 Swift cluster의 Unicode scalar 시작/끝 index를 계산하고, external position 배열에서 해당 경계를 매핑한다.

## 계약 판단

### 현재 한계

Stage 3 fallback은 rhwp-studio의 방향과 같지만 완전한 reference implementation은 아니다.

- rhwp-studio/core는 `compute_char_positions(text, style)`를 한 번 계산하고, 같은 배열을 SVG/Canvas/text layout query에서 사용한다.
- Swift renderer는 같은 core metric table에 직접 접근하지 못하고 CoreText 측정값과 HWP-style heuristic을 섞어 재계산한다.
- font fallback, 반각 구두점, 라틴/기호 폭, 옛한글 jamo cluster에서 core와 Swift 계산이 달라질 수 있다.

따라서 “같은 `rhwp` core 입력에 대해 macOS native renderer가 rhwp-studio와 동등한 시각 결과와 fallback 정책을 갖는다”는 구현 기준을 안정적으로 만족하려면, render tree가 이미 layout에서 확정한 run-local char x 배열을 제공해야 한다.

### 권장 render tree field

권장 필드:

```text
TextRun.char_positions: Vec<f64>
```

의미:

- run-local x boundary 배열
- 길이: Rust `text.chars().count() + 1`
- 값: `compute_char_positions(text, style)`의 full precision 결과
- 좌표: `TextRun.bbox.x + char_positions[i]`가 page 좌표의 glyph/cluster 시작 x
- 마지막 값: text run의 reference advance

기존 `get_page_text_layout_native`의 `charX`는 편집/query 용도로 이미 존재하지만 소수 1자리 문자열로 포맷된다. renderer reference input으로는 full precision `char_positions`가 더 적합하다.

### Swift 호환 전략

- Swift는 `char_positions`가 있으면 그 값을 직접 사용한다.
- 필드가 없거나 길이/단조성 검증에 실패하면 Stage 3 Swift fallback을 사용한다.
- 따라서 core upstream이 field를 추가하기 전후 모두 같은 앱 binary가 동작한다.

## 검증 결과

### 상태

```text
git status --short --branch
## local/task120...origin/devel [ahead 5]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
 M Sources/RhwpCoreBridge/RenderTree.swift
?? mydocs/working/task_m015_120_stage4.md
```

### render-debug

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage4-hongbo samples/20250130-hongbo.hwp
OK 20250130-hongbo.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage4-hongbo/20250130-hongbo-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage4-hongbo/20250130-hongbo-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage4-hongbo/20250130-hongbo-page1-native.png summary=/private/tmp/rhwp-task120-stage4-hongbo/20250130-hongbo-page1-summary.txt
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage4-center samples/re-align-center-hancom.hwp
OK re-align-center-hancom.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage4-center/re-align-center-hancom-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage4-center/re-align-center-hancom-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage4-center/re-align-center-hancom-page1-native.png summary=/private/tmp/rhwp-task120-stage4-center/re-align-center-hancom-page1-summary.txt
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage4-right samples/re-align-right-hancom.hwp
OK re-align-right-hancom.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage4-right/re-align-right-hancom-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage4-right/re-align-right-hancom-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage4-right/re-align-right-hancom-page1-native.png summary=/private/tmp/rhwp-task120-stage4-right/re-align-right-hancom-page1-summary.txt
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage4-justify samples/re-align-justify-hancom.hwp
OK re-align-justify-hancom.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage4-justify/re-align-justify-hancom-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage4-justify/re-align-justify-hancom-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage4-justify/re-align-justify-hancom-page1-native.png summary=/private/tmp/rhwp-task120-stage4-justify/re-align-justify-hancom-page1-summary.txt
```

### summary 핵심값

| 샘플 | RenderTreeJSONBytes | CoreSVGBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs | Diff |
|------|---------------------|--------------|----------------------|----------|------------|---------------------|------|
| `20250130-hongbo.hwp` | 99137 | 235786 | 84306 | 60 | 35 | 0 | qlmanage rasterize failed |
| `re-align-center-hancom.hwp` | 6696 | 29578 | 6666 | 3 | 3 | 0 | qlmanage rasterize failed |
| `re-align-right-hancom.hwp` | 6698 | 29581 | 6615 | 3 | 3 | 0 | qlmanage rasterize failed |
| `re-align-justify-hancom.hwp` | 6674 | 29602 | 6652 | 3 | 3 | 0 | qlmanage rasterize failed |

Stage 4 source 변경은 현재 JSON에서 `char_positions`가 없으므로 Stage 3과 같은 bitmap smoke 수치를 유지했다.

### 문제 run 확인

`20250130-hongbo.hwp`의 핵심 run bbox는 이전 단계와 같다.

| id | text | bbox x | bbox width |
|----|------|--------|------------|
| 39 | `2026. 1. 30.(` | 588.3533 | 87.0 |
| 40 | `금)` | 675.3533 | 20.0 |
| 50 | `혹한기 봉화댐 건설 현장점검 ‘안전 온도 높인다’` | 84.88 | 624.0 |

core SVG는 이 run들을 이미 개별 `<text x="...">`로 출력한다. 예를 들어 날짜 run은 `(`가 x `668.3533`, `금`이 x `675.3533`에 온다. Swift native renderer는 현재 fallback 계산으로 이 간격을 근사하고, future `char_positions`가 들어오면 같은 배열을 직접 사용할 수 있다.

### 추가 smoke

```text
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task120-stage4-smoke samples/20250130-hongbo.hwp samples/re-align-center-hancom.hwp samples/re-align-right-hancom.hwp samples/re-align-justify-hancom.hwp
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=84306 png=/private/tmp/rhwp-task120-stage4-smoke/20250130-hongbo-page1.png
OK re-align-center-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6666 png=/private/tmp/rhwp-task120-stage4-smoke/re-align-center-hancom-page1.png
OK re-align-right-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6615 png=/private/tmp/rhwp-task120-stage4-smoke/re-align-right-hancom-page1.png
OK re-align-justify-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6652 png=/private/tmp/rhwp-task120-stage4-smoke/re-align-justify-hancom-page1.png
```

### 의존성 경계와 whitespace

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
git diff --check
```

통과했다.

## 잔여 위험

- core render tree가 아직 `char_positions`를 내보내지 않으므로 현재 문서에서는 Stage 3 Swift fallback이 계속 쓰인다.
- `char_positions`를 core에 추가할 때 field name과 precision을 확정해야 한다. renderer input으로는 `charX`의 1자리 반올림 형식보다 full precision `char_positions`가 필요하다.
- optional field가 들어온 뒤에도 vertical text, char overlap, text effects까지 같은 정책으로 확장하려면 별도 검증 샘플이 필요하다.
- `qlmanage` rasterize 실패로 diff PNG는 생성되지 않았다. 이번 단계도 summary와 native PNG 중심으로 판단했다.

## 다음 단계 영향

Stage 5에서는 HostApp/Quick Look/Thumbnail 공유 renderer 변경으로서 통합 검증과 최종 보고를 수행한다.

core upstream 작업이 별도 이슈로 이어진다면, `TextRun.char_positions` full precision 배열을 render tree에 추가하고 Swift fallback과 비교 검증하는 흐름이 적절하다.

## 승인 요청

Stage 4 정렬 샘플 검증과 render tree 계약 판단을 완료했다. Stage 5 `통합 검증과 최종 보고`에 진입해도 되는지 승인 요청한다.
