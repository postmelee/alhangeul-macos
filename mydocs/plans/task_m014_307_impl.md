# Task M014 #307 구현 계획 - CoreGraphics 텍스트 shade sentinel 보정

## 목적

Quick Look/Thumbnail CoreGraphics preview에서 `samples/basic/BookReview.hwp`, `samples/복학원서.hwp` 텍스트 뒤에 불투명한 흰색 박스가 그려지는 문제를 최소 범위로 보정한다.

## Stage 1. 원인 inventory

완료 기준:

- 문제 샘플의 render tree에서 `TextRun.style.shade_color` 분포를 확인한다.
- core SVG와 native PNG를 비교해 박스가 CoreGraphics renderer에서만 생기는지 확인한다.
- 수정 위치를 `CGTreeRenderer` 내부 shade drawing 조건으로 확정한다.

검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task307-stage1 samples/basic/BookReview.hwp samples/복학원서.hwp
jq -r '[.. | objects | select(.node_type.TextRun? != null) | .node_type.TextRun.style.shade_color] as $shades | input_filename + "\n" + (($shades | sort | group_by(.)[] | "  count=\(length) shade=\(.[0])"))' build.noindex/task307-stage1/*page1-render-tree.json
rg -n "fill=\"#fff|fill=\"white|opacity|rgba|rect" build.noindex/task307-stage1/*core.svg
```

## Stage 2. CoreGraphics shade 조건 보정

구현:

- `CGTreeRenderer`에 텍스트 shade helper를 추가한다.
- `0`, `0x00FFFFFF`, `0xFFFFFFFF`는 no shade로 처리한다.
- 기존 실제 shade 값은 `colorRefToCGColor(...).copy(alpha: 0.3)` 흐름을 유지한다.
- 일반 text run과 centered/rotated/vertical text run 양쪽에서 같은 helper를 사용한다.

완료 기준:

- 문제 샘플의 기본 텍스트 박스가 사라진다.
- 실제 shade 값 처리 경로를 삭제하지 않는다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 의존을 추가하지 않는다.

검증:

```bash
./scripts/check-no-appkit.sh
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/plans/task_m014_307_impl.md mydocs/working/task_m014_307_stage1.md
```

## Stage 3. renderer smoke와 extension build

검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task307-stage3 samples/basic/BookReview.hwp samples/복학원서.hwp
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask307 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask307 CODE_SIGNING_ALLOWED=NO build
```

완료 기준:

- `BookReview.hwp` native PNG의 제목/표지 텍스트 뒤 흰색 박스가 사라진다.
- `복학원서.hwp` native PNG에서 #305 PUA 보정이 유지되고 텍스트 뒤 박스가 사라진다.
- Quick Look/Thumbnail extension Debug build가 통과한다.

## Stage 4. 최종 보고와 PR

정리:

- 최종 보고서에 원인, 변경 범위, 검증 산출물, 잔여 리스크를 기록한다.
- #301 릴리즈 작업에 반영해야 할 후속 조치로 PR merge 후 `devel` 재기준화가 필요함을 남긴다.
- `publish/task307` 브랜치로 `devel` 대상 PR을 게시한다.

## 리스크

- `0xFFFFFFFF`가 특정 문서에서 실제 흰색 shade를 의미할 가능성이 이론적으로 남는다. 다만 현재 core SVG는 해당 shade rect를 출력하지 않고, `0x00FFFFFF`도 기존부터 no shade로 처리하고 있어 `0xFFFFFFFF`는 기본값/sentinel로 보는 것이 더 일관적이다.
- 이번 작업은 CoreGraphics renderer 최소 보정이다. 장기적으로 Quick Look/Thumbnail을 PageLayerTree 소비 경로로 전환하는 문제는 별도 이슈/코멘트에서 계속 추적한다.
