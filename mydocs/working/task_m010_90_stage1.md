# Task #90 Stage 1 완료 보고서 - 기준 산출물 재생성과 overflow 재현

## 단계 목적

`samples/복학원서.hwp` 1페이지 기준 render debug 산출물을 재생성하고, Task #84/#85에서 관찰된 page bbox 밖 layout overflow diagnostic이 현재 `local/task90`에서도 재현되는지 확인한다.

## 산출물

저장소 source code 변경은 없다. Stage 1 산출물은 `/tmp/rhwp-task90-bokhak-stage1`에 생성했다.

| 산출물 | 크기 | 비고 |
|--------|------|------|
| `복학원서-page1-render-tree.json` | 189402 bytes | 필수 산출물, render tree JSON |
| `복학원서-page1-core.svg` | 341594 bytes | 필수 산출물, `rhwp_render_page_svg` 결과 |
| `복학원서-page1-native.png` | 408418 bytes | 필수 산출물, Swift native renderer 결과 |
| `복학원서-page1-summary.txt` | 894 bytes | 필수 산출물, summary |
| `복학원서-page1-core.svg.qlmanage.log` | 95 bytes | 선택 산출물 실패 로그 |

macOS 파일명 정규화 때문에 일부 명령 출력에는 decomposed Hangul 형태의 파일명이 표시된다. 같은 `/tmp/rhwp-task90-bokhak-stage1` 산출물이다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. Stage 1은 조사 산출물 생성과 단계 보고서 작성만 수행했고 제품 source, manual, plan 본문은 변경하지 않았다.

## 검증 결과

작업 브랜치와 working tree:

```text
## local/task90
```

샘플 hash:

```text
da81b4010331bcac290f900c7cf224c97ee8355399614725ce46c197ff1a22a4  samples/복학원서.hwp
```

필수 bridge 산출물:

```text
Frameworks/modulemap/module.modulemap 45B
Frameworks/universal/librhwp.a 98M
samples/복학원서.hwp 112K
```

render debug 명령:

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-task90-bokhak-stage1 --page 1 samples/복학원서.hwp
```

결과:

```text
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Table, y=1130.6, bottom=1084.7, overflow=45.9px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1094.3, bottom=1084.7, overflow=9.6px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1094.3, bottom=1084.7, overflow=9.6px
```

위 세 diagnostic은 명령 실행 중 2회 반복 출력됐다. 필수 산출물 생성은 성공했다.

summary 핵심값:

```text
PageCount: 1
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 189402
CoreSVGBytes: 341594
NativePNGSize: 794x1123
NativeNonWhitePixels: 163193
TextRuns: 102
HangulRuns: 25
HangulScalars: 143
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-core.svg.qlmanage.log
```

`qlmanage` rasterize 실패 로그:

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

이 실패는 선택 산출물인 core raster PNG와 diff PNG 생성 실패이며, render tree JSON, core SVG, native PNG, summary 생성 성공 여부와는 별개다.

`git diff --check` 결과:

```text
통과
```

## 잔여 위험

- Stage 1은 산출물 재현 단계라 overflow node의 정확한 parent chain과 clip 정보는 아직 분석하지 않았다.
- `qlmanage` sandbox 실패로 pixel diff는 생성되지 않았다. Stage 2-3에서는 필수 산출물과 render tree geometry 분석을 기준으로 책임 경계를 먼저 판단한다.
- diagnostic이 2회 반복 출력되는 이유는 script가 core SVG/render tree/native export 과정에서 문서를 여는 경로가 반복되기 때문으로 보이며, overflow 자체의 중복 원인 분석은 Stage 2에서 다룬다.

## 다음 단계 영향

Stage 2는 `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-render-tree.json`을 기준으로 page bbox 밖 node를 구조적으로 추려야 한다. 특히 `page=0, col=0, para=16` 주변의 table, partial paragraph, shape bbox와 `Body.clip_rect`, `TableCell.clip` 정보를 함께 확인한다.

## 승인 요청

Stage 1 완료를 승인 요청한다. 승인 후 Stage 2 `overflow node와 page geometry 분석`으로 진행한다.
