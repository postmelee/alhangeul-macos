# Task M014 #307 Stage 2 보고서 - CoreGraphics 텍스트 shade sentinel 보정

## 목적

Stage 1에서 확인한 `0xFFFFFFFF` 텍스트 shade sentinel을 CoreGraphics renderer에서 no shade로 처리해, Quick Look/Thumbnail preview의 불필요한 흰색 박스 렌더링을 제거한다.

## 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`

## 구현 내용

`CGTreeRenderer`에 `drawTextShadeIfNeeded(style:bbox:in:)` helper를 추가했다.

no shade로 처리하는 값:

```text
0
0x00FFFFFF
0xFFFFFFFF
```

기존 `0`, `0x00FFFFFF` 판정은 유지했고, `0xFFFFFFFF`만 추가했다. 실제 shade 값인 경우에는 기존과 동일하게 bbox를 `alpha: 0.3`으로 칠한다. 다만 기존의 `copy(alpha:)!` force unwrap 대신 기존 `colorRefToCGColor(_:alpha:)` helper를 사용해 같은 alpha 값을 적용한다.

적용 경로:

- `renderTextRun`
- `renderCenteredTextRun`

따라서 일반 텍스트와 회전/세로쓰기/centered 텍스트가 같은 shade sentinel 판정을 공유한다.

## 검증

```bash
./scripts/check-no-appkit.sh
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/orders/20260531.md mydocs/plans/task_m014_307_impl.md mydocs/working/task_m014_307_stage1.md
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

`git diff --check` 통과.

## 다음 단계

Stage 3에서 `BookReview.hwp`, `복학원서.hwp` render smoke를 다시 실행하고 native PNG를 확인한다. 그 다음 QLExtension, ThumbnailExtension Debug build로 extension 소비 경로 compile을 검증한다.
