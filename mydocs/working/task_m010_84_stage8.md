# Issue #84 Stage 8 완료 보고서

## 단계 목적

Viewer에서 `복학원서.hwp`를 연 뒤 `20250130-hongbo.hwp`를 열었을 때 이전 문서 이미지가 새 문서의 이미지 위치에 재사용되는 회귀를 수정한다.

## 재현 분석

작업지시자가 첨부한 2026-04-29 09:31 스크린샷에서 `20250130-hongbo.hwp`의 상단 이미지 위치에 `복학원서.hwp`의 학교 마크 이미지가 표시됐다.

관련 구조:

- Viewer page view는 SwiftUI/AppKit bridge 과정에서 `DocumentPageNSView`를 재사용할 수 있다.
- `DocumentPageNSView`는 내부에 `CGTreeRenderer` 인스턴스를 보유한다.
- `DocumentViewerStore.pageTrees.removeAll()`은 문서 전환 시 render tree만 비우며, 재사용된 page view 내부 renderer의 `imageCache`까지 직접 비우지는 않는다.
- `CGTreeRenderer.imageCache`는 `UInt16 binDataId`만 key로 사용한다.

HWP의 `binDataId`는 문서 내부 식별자이므로 서로 다른 문서가 같은 `binDataId`를 쓸 수 있다. 따라서 같은 renderer가 문서 A의 이미지를 캐시한 뒤 문서 B를 렌더링하면, 문서 B의 같은 `binDataId` 이미지 위치에 문서 A의 이미지가 재사용될 수 있다.

## 변경 내용

`Sources/RhwpCoreBridge/CGTreeRenderer.swift`를 보정했다.

- `render(tree:in:pageHeight:document:)` 진입 시 이전 렌더 대상 `RhwpDocument`와 현재 `document`가 같은 객체인지 확인한다.
- 문서 identity가 바뀌면 `clearCache()`로 `imageCache`를 비운다.
- `imageCache` 자체는 유지해 같은 문서 안에서 반복되는 이미지 decode 비용은 줄인다.
- `DocumentPageView`와 `DocumentPageNSView`의 SwiftUI/AppKit lifecycle 흐름은 변경하지 않았다.

계획 문서도 Stage 8을 image cache 문서 전환 보정 단계로 갱신하고, 최종 보고 단계는 Stage 9로 미뤘다.

## 검증 명령과 결과

```bash
git diff --check
```

결과: 통과

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 통과 (`** BUILD SUCCEEDED **`)

비고: CoreSimulator 연결 및 provisioning profile 경고가 출력됐지만 macOS HostApp build는 성공했다.

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-stage8-image-cache-task84 --page 1 samples/복학원서.hwp samples/20250130-hongbo.hwp samples/aift.hwp
```

결과: 통과

| Sample | Page | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|--------|------|-----------|---------------------|----------------------|----------|------------|---------------------|
| 복학원서.hwp | 1 | 1 | 189402 | 163193 | 102 | 25 | 0 |
| 20250130-hongbo.hwp | 1 | 4 | 92327 | 77596 | 58 | 33 | 0 |
| aift.hwp | 1 | 74 | 40170 | 132970 | 25 | 15 | 0 |

```bash
/tmp/rhwp-stage8-renderer-reuse-check samples/복학원서.hwp samples/20250130-hongbo.hwp samples/aift.hwp
```

결과: 통과

이 임시 검증은 같은 `CGTreeRenderer` 인스턴스를 세 문서에 순차 재사용했을 때의 bitmap 결과가 문서별 fresh renderer 결과와 같은지 비교한다.

| Sample | Page | Native size | Reused renderer nonWhitePixels |
|--------|------|-------------|--------------------------------|
| 복학원서.hwp | 1 | 794x1123 | 168558 |
| 20250130-hongbo.hwp | 1 | 794x1123 | 80097 |
| aift.hwp | 1 | 794x1123 | 133003 |

## 잔여 리스크

자동 검증은 renderer 재사용 시 pixel 결과가 fresh renderer와 동일한지 확인했지만, 실제 Viewer 창에서 파일 열기 UI를 통해 같은 순서로 문서를 여는 동작은 작업지시자 환경에서 재확인이 필요하다.

대용량 문서의 render tree 메모리 정책은 이번 correctness 수정과 분리한다. 즉시 unload 제거와 초기 page 0/1 선로딩은 유지하되, LRU 또는 주변 page window 기반 eviction은 별도 후속 이슈로 다루는 것이 적절하다.

## 다음 단계

작업지시자의 실제 UI 재검증 결과를 확인한 뒤 Stage 9 최종 보고서와 오늘할일 상태 갱신을 진행한다.
