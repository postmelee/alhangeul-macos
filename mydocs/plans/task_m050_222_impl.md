# Task M050 #222 구현 계획서

수행계획서: `mydocs/plans/task_m050_222.md`

## 작업 개요

- 이슈: #222 rhwp v0.7.11 기준 Swift native renderer parity gap 정리와 따라잡기
- 마일스톤: `v0.5`
- 브랜치: `local/task222`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 목표: `samples/복학원서.hwp`의 `BehindText` 워터마크가 Quick Look/native preview에서 본문 위가 아니라 본문 아래 레이어에 그려지도록 Swift native renderer의 이미지 z-order 처리를 보강한다.

## 구현 원칙

- 흑백/GrayScale 효과 미지원은 본 작업에서 수정하지 않는다.
- Swift native renderer의 현재 `PageRenderTree` 기반 경로를 유지하고, PageLayerTree 전면 전환은 하지 않는다.
- `ImageNode.textWrap` 디코딩은 문자열 원본을 보존하되 renderer 판단 helper로 의미를 좁힌다.
- `BehindText` draw order 보정은 page-level과 body/column 내부 렌더 패스에서 처리하고, 개별 이미지 drawing, crop, effect, fill mode 구현은 기존 경로를 재사용한다.
- `CGImageSource`가 직접 지원하지 않는 PCX 계열 bin data는 Swift native renderer 안에서 최소 fallback decoder로 처리한다.
- 기존 top-level 순서에서 `PageBackground`는 가장 먼저, `BehindText` 이미지는 그 다음, body/header/footer/일반 foreground 노드는 기존 순서를 최대한 유지한다.
- stage별로 검증 가능한 산출물을 남기고, 다음 stage로 넘어가기 전 단계 보고서를 작성한다.

## Stage 1. `text_wrap`와 draw order 책임 범위 확정

대상:

- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `scripts/render-debug-compare.sh`
- 기존 `/private/tmp/rhwp-bokhak-watermark-analysis` 분석 산출물

작업:

1. `ImageNode`가 현재 디코딩하는 필드와 누락된 `text_wrap` 필드를 확인한다.
2. `CGTreeRenderer`의 현재 page/body/image 순회 순서를 코드 기준으로 정리한다.
3. `samples/복학원서.hwp` render tree에서 중앙 워터마크와 좌상단 로고의 `text_wrap` 값을 확인한다.
4. Stage 2에서 구현할 최소 보정 위치와 제외 범위를 확정한다.
5. Stage 1 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m050_222_stage1.md`

검증:

```bash
git diff --check -- mydocs/plans/task_m050_222_impl.md mydocs/working/task_m050_222_stage1.md
```

완료 조건:

- `text_wrap` 누락 위치와 render order 문제 원인이 파일/라인 기준으로 설명되어 있다.
- Stage 2 구현 단위가 `RenderTree.swift`와 `CGTreeRenderer.swift` 중심으로 좁혀져 있다.
- 제품 코드 변경 없이 완료된다.

커밋:

```text
Task #222 Stage 1: BehindText draw order 책임 범위 확정
```

## Stage 2. `BehindText` 이미지 렌더 패스 구현

대상:

- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`

작업:

1. `ImageNode`에 `textWrap` 디코딩 필드를 추가한다.
2. `BehindText` 판단 helper를 추가한다.
3. page-level 렌더링에서 `PageBackground`를 먼저 그리고, top-level `BehindText` 이미지를 body/foreground 전에 그리는 pass를 추가한다.
4. 일반 pass에서는 이미 선행 pass로 그린 `BehindText` top-level 이미지를 중복 렌더하지 않는다.
5. 기존 이미지 drawing 함수와 crop/effect/fill mode 경로를 그대로 사용한다.
6. Stage 2 완료보고서를 작성한다.

산출물:

- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/working/task_m050_222_stage2.md`

검증:

```bash
git diff --check -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/working/task_m050_222_stage2.md
swift test
```

완료 조건:

- `text_wrap: "BehindText"`가 Swift 모델에 보존된다.
- `BehindText` top-level 이미지는 page background 이후, body/header/footer/foreground 이전에 한 번만 그려진다.
- 기존 render tree decode와 renderer compile 검증이 통과한다.

커밋:

```text
Task #222 Stage 2: BehindText 이미지 렌더 패스 추가
```

## Stage 3. `복학원서.hwp` visual/debug smoke 검증

대상:

- `scripts/render-debug-compare.sh`
- `samples/복학원서.hwp`
- 이미지가 포함된 기존 대표 샘플 1개 이상

작업:

1. `samples/복학원서.hwp` 1페이지 render debug compare를 실행한다.
2. 생성된 native PNG에서 중앙 워터마크가 본문 아래에 렌더되는지 확인한다.
3. 좌상단 로고와 하단 접수 도장이 의도치 않게 사라지거나 중복되지 않는지 확인한다.
4. 이미지 포함 대표 샘플 1개 이상으로 smoke를 실행한다.
5. Stage 3 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m050_222_stage3.md`
- `/private/tmp/rhwp-bokhak-watermark-task222` 검증 산출물

검증:

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-bokhak-watermark-task222 --page 1 samples/복학원서.hwp
git diff --check -- mydocs/working/task_m050_222_stage3.md
```

완료 조건:

- `복학원서.hwp` native PNG에서 워터마크가 텍스트와 표 위를 가리지 않는다.
- 흑백/GrayScale 미반영은 별도 제한 사항으로 남기고, z-order 문제만 해결 여부를 판단한다.
- smoke 실행 결과와 남은 리스크가 문서화되어 있다.

커밋:

```text
Task #222 Stage 3: 복학원서 BehindText smoke 검증
```

## Stage 4. nested `BehindText` 로고와 PCX fallback 보정

대상:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `samples/복학원서.hwp`

작업:

1. `Body > Column` 내부에 있는 좌상단 로고의 render tree 위치와 `text_wrap` 값을 확인한다.
2. 로고 `bin_data_id=1`이 PCX이고 `CGImageSource` 직접 decode 대상이 아님을 확인한다.
3. ImageIO decode 실패 시 PCX fallback decoder를 적용해 기존 `renderImage` 경로에 연결한다.
4. nested `BehindText` 이미지는 같은 column 안에서 foreground보다 먼저 그리도록 순서를 보정한다.
5. `복학원서.hwp` native PNG에서 좌상단 로고가 보이는지 확인한다.
6. Stage 4 완료보고서를 작성한다.

산출물:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/working/task_m050_222_stage4.md`

검증:

```bash
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/working/task_m050_222_stage4.md
./scripts/render-debug-compare.sh /private/tmp/rhwp-bokhak-watermark-task222-stage4 --page 1 samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task222-image-smoke-stage4 --page 1 samples/hwp-img-001.hwp
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

완료 조건:

- 중앙 page-level 워터마크 pass는 유지된다.
- 좌상단 nested `BehindText` 로고가 native PNG에 보인다.
- 기존 JPEG/PNG 등 ImageIO 경로는 유지되고, PCX는 fallback으로만 처리된다.
- preview와 thumbnail 공통 renderer 경로에 같은 보정이 적용된다.

커밋:

```text
Task #222 Stage 4: nested BehindText 로고 렌더 보정
```

## Stage 5. 최종 정리와 보고

대상:

- `mydocs/report/task_m050_222_report.md`
- `mydocs/orders/20260516.md`

작업:

1. Stage 1~4 결과를 최종 보고서로 요약한다.
2. 검증 명령과 산출물 위치를 기록한다.
3. 남은 parity gap, 특히 GrayScale/upstream 갱신 필요성을 분리해 기록한다.
4. 오늘할일 상태를 완료로 갱신한다.

산출물:

- `mydocs/report/task_m050_222_report.md`
- `mydocs/orders/20260516.md`

검증:

```bash
git diff --check
git status --short
```

완료 조건:

- 작업 결과, 검증, 잔여 리스크가 최종 보고서에 정리되어 있다.
- PR 생성 전 커밋되지 않은 변경이 없다.

커밋:

```text
Task #222 Stage 5 + 최종 보고서: BehindText 렌더 순서 정리
```
