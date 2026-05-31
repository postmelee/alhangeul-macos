# Task M014 #307 최종 보고서 - CoreGraphics preview 텍스트 박스 제거

## 요약

Quick Look/Thumbnail CoreGraphics renderer가 `TextStyle.shadeColor = 0xFFFFFFFF`를 실제 텍스트 shade로 오인해 bbox 전체를 30% 흰색으로 칠하던 문제를 수정했다.

변경 후 `samples/basic/BookReview.hwp`, `samples/복학원서.hwp` native PNG에서 텍스트 뒤 흰색 박스가 제거됐고, QLExtension/ThumbnailExtension Debug build가 통과했다.

## 이슈

- GitHub Issue: #307
- Milestone: M014
- 대상 증상:
  - `BookReview.hwp` 표지 제목/큰 글자 뒤 흰색 반투명 박스
  - `복학원서.hwp` 본문/표/서명란 주변 텍스트 뒤 흰색 반투명 박스

## 원인

문제 샘플 첫 페이지의 모든 `TextRun`이 `shade_color = 4294967295`를 가진다. 이 값은 `0xFFFFFFFF`다.

기존 `CGTreeRenderer`는 `shadeColor`가 `0` 또는 `0x00FFFFFF`가 아니면 실제 음영으로 보고 bbox 전체를 `alpha: 0.3`으로 채웠다. 따라서 기본값/sentinel 성격의 `0xFFFFFFFF`가 흰색 shade로 렌더링됐다.

core SVG에는 같은 위치의 텍스트 shade rect가 없어, Swift/CoreGraphics 소비 경로의 sentinel 해석 문제로 판단했다.

## 변경 내용

변경 파일:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`

주요 변경:

- `drawTextShadeIfNeeded(style:bbox:in:)` helper 추가
- no shade 값에 `0xFFFFFFFF` 추가
- 일반 `renderTextRun`과 `renderCenteredTextRun`이 같은 shade 판정을 사용하도록 정리
- 실제 shade 값의 `alpha: 0.3` 렌더링 정책은 유지

no shade 처리 값:

```text
0
0x00FFFFFF
0xFFFFFFFF
```

## 문서 산출물

- `mydocs/plans/task_m014_307.md`
- `mydocs/plans/task_m014_307_impl.md`
- `mydocs/working/task_m014_307_stage1.md`
- `mydocs/working/task_m014_307_stage2.md`
- `mydocs/working/task_m014_307_stage3.md`
- `mydocs/report/task_m014_307_report.md`
- `mydocs/orders/20260531.md`

## 검증

Stage 1 원인 확인:

```bash
./scripts/render-debug-compare.sh build.noindex/task307-stage1 samples/basic/BookReview.hwp samples/복학원서.hwp
jq -r '[.. | objects | select(.node_type.TextRun? != null) | .node_type.TextRun.style.shade_color] as $shades | input_filename + "\n" + (($shades | sort | group_by(.)[] | "  count=\(length) shade=\(.[0])"))' build.noindex/task307-stage1/*page1-render-tree.json
```

결과:

```text
BookReview-page1-render-tree.json: count=66 shade=4294967295
복학원서-page1-render-tree.json: count=102 shade=4294967295
```

Stage 2 코드 경계 검증:

```bash
./scripts/check-no-appkit.sh
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/orders/20260531.md mydocs/working/task_m014_307_stage2.md
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

Stage 3 smoke/build 검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task307-stage3 samples/basic/BookReview.hwp samples/복학원서.hwp
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask307 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask307 CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
OK BookReview.hwp
OK 복학원서.hwp
** BUILD SUCCEEDED ** [13.655 sec]
** BUILD SUCCEEDED ** [2.100 sec]
```

시각 확인:

- `BookReview.hwp`: 표지 제목/큰 글자 뒤 흰색 박스 제거
- `복학원서.hwp`: 본문/표/서명란 주변 가로 흰색 텍스트 박스 제거
- #305 PUA `(인)` 표시 유지

`qlmanage` 기반 core SVG rasterize는 로컬 환경에서 실패해 pixel diff는 생성되지 않았다. native PNG 생성, summary 작성, extension build는 모두 성공했다.

## 잔여 리스크

- `0xFFFFFFFF`가 실제 흰색 텍스트 shade를 의미하는 문서가 있을 가능성은 이론적으로 남는다. 다만 기존 renderer가 이미 `0x00FFFFFF`를 no shade로 취급했고, core SVG도 문제 샘플에서 shade rect를 출력하지 않아 이번 보정은 sentinel 해석으로 보는 것이 일관적이다.
- `복학원서.hwp` 중앙 워터마크가 앱 viewer보다 진하게 보이는 기존 CoreGraphics overlay 표현 차이는 이번 변경 전후 동일하게 남아 있다. 이는 #307의 텍스트 shade 문제와 별개이며, 장기적인 PageLayerTree 전환/renderer parity 작업에서 다루는 것이 적절하다.

## 릴리즈 작업 연결

#301 v0.1.4 릴리즈 작업은 이 PR이 `devel`에 merge된 뒤 `devel`을 다시 받아 release worktree/branch를 재기준화한 다음 이어가야 한다. release artifact는 이번 CoreGraphics 보정 포함 commit 이후에 다시 생성하는 것이 맞다.
