# Issue #84 Stage 4 완료 보고서

## 단계 목적

Stage 1의 즉시 unload 제거와 Stage 3의 `DocumentPageNSView` redraw 보강 이후, HostApp build와 렌더 회귀 검증을 다시 수행한다. 작업지시자가 재현한 `/Users/melee/Documents/samples/table-vpos-01.hwp`의 page 1/2도 검증 범위에 포함한다.

## 검증 명령과 결과

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 통과 (`** BUILD SUCCEEDED **`)

비고: CoreSimulator 연결 및 provisioning profile 경고가 출력됐지만 macOS HostApp build는 성공했다.

```bash
./scripts/validate-stage3-render.sh /tmp/rhwp-stage4-render-task84
```

결과: 통과

| Sample | Page | Native size | TextRuns | HangulRuns | NonWhitePixels |
|--------|------|-------------|----------|------------|----------------|
| KTX.hwp | 1 | 1123x794 | 435 | 76 | 450455 |
| request.hwp | 1 | 567x794 | 104 | 36 | 54724 |
| exam_kor.hwp | 1 | 1123x1588 | 69 | 51 | 96464 |

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-stage4-first-page-task84 --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp
```

결과: 통과

| Sample | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|--------|-----------|---------------------|----------------------|----------|------------|---------------------|
| hwp-multi-001.hwp | 9 | 468702 | 142561 | 277 | 113 | 0 |
| 20250130-hongbo.hwp | 4 | 92327 | 77596 | 58 | 33 | 0 |

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-table-vpos-page1-task84 --page 1 /Users/melee/Documents/samples/table-vpos-01.hwp
./scripts/render-debug-compare.sh /tmp/rhwp-table-vpos-page2-task84 --page 2 /Users/melee/Documents/samples/table-vpos-01.hwp
```

결과: 통과

| Sample | Page | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|--------|------|-----------|---------------------|----------------------|----------|------------|---------------------|
| table-vpos-01.hwp | 1 | 5 | 143246 | 89133 | 90 | 45 | 0 |
| table-vpos-01.hwp | 2 | 5 | 92899 | 86141 | 67 | 38 | 0 |

## 확인 사항

- 사용자 재현 파일의 page 1/2는 render tree, core SVG, native PNG가 모두 생성됐다.
- page 1/2 모두 native PNG에 non-white pixel이 충분히 존재하고, 한글 glyph 누락은 0개다.
- `qlmanage` 기반 SVG raster diff는 로컬 환경에서 실패해 optional diff PNG는 생성되지 않았다. 이 실패는 render tree/native PNG 생성 성공 여부와 별개이며, 스크립트는 정상 종료했다.
- 검증 결과는 첫 페이지 누락의 원인이 render data 부재나 thumbnail cache 재사용이 아니라 Viewer 초기 drawing lifecycle 쪽이라는 Stage 3 판단과 일치한다.

## 잔여 리스크

자동 검증은 Viewer App의 실제 초기 화면 표시를 픽셀 단위로 캡처하지 않는다. 최종 확인에는 작업지시자가 동일 파일을 HostApp에서 다시 열어 page 1/2가 첫 화면에서 표시되는지 확인하는 수동 검증이 필요하다.

## 다음 단계

Stage 5에서 최종 보고서 작성, 오늘할일 상태 갱신, 작업 범위 요약을 수행한다.
