# Task #92 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 구현한 Viewer page tree cache eviction 정책이 HostApp 빌드와 기존 render pipeline을 깨지 않았는지 확인했다. 실제 Viewer 스크롤 체감 검증은 자동화가 어려우므로, 자동 검증 결과와 작업지시자 수동 확인 필요 항목을 분리해 기록한다.

## 검증 결과

### 정적 검증

```bash
git diff --check
```

결과: 통과

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage3 CODE_SIGNING_ALLOWED=NO build
```

결과: 통과

비고:

- Xcode가 CoreSimulatorService, provisioning profile 관련 경고를 출력했지만 macOS HostApp build는 성공했다.
- 빌드 산출물: `build.noindex/DerivedDataStage3/Build/Products/Debug/AlhangeulMac.app`

### Stage 3 기본 render smoke

```bash
./scripts/validate-stage3-render.sh /tmp/rhwp-task92-render
```

결과: 통과

확인된 샘플:

| 파일 | page | image size | textRuns | hangulRuns | hangulScalars | nonWhitePixels |
|------|------|------------|----------|------------|---------------|----------------|
| `KTX.hwp` | 1 | 1123x794 | 435 | 76 | 209 | 449097 |
| `request.hwp` | 1 | 567x794 | 104 | 36 | 309 | 53220 |
| `exam_kor.hwp` | 1 | 1123x1588 | 108 | 71 | 1203 | 159757 |

### 대표 다중 페이지 문서 render compare

최초 sandbox 실행에서는 `qlmanage` SVG rasterize가 sandbox 초기화 오류로 diff PNG를 만들지 못했다. render tree, core SVG, native PNG 생성은 성공했지만 비교 산출물 완성을 위해 권한 상승으로 동일 명령을 재실행했다.

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-task92-cache-smoke --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp samples/aift.hwp
```

결과: 통과, diff 산출물 생성

| 파일 | PageCount | NativeNonWhitePixels | TextRuns | MissingHangulGlyphs | Diff |
|------|-----------|----------------------|----------|---------------------|------|
| `hwp-multi-001.hwp` | 10 | 143197 | 277 | 0 | generated |
| `20250130-hongbo.hwp` | 4 | 83133 | 60 | 0 | generated |
| `aift.hwp` | 77 | 132970 | 25 | 0 | generated |

### `table-vpos-01.hwp` page 1/2 render compare

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-task92-table-vpos-page1 --page 1 /Users/melee/Documents/samples/table-vpos-01.hwp
./scripts/render-debug-compare.sh /tmp/rhwp-task92-table-vpos-page2 --page 2 /Users/melee/Documents/samples/table-vpos-01.hwp
```

결과: 통과, diff 산출물 생성

| 파일 | page | PageCount | NativeNonWhitePixels | TextRuns | MissingHangulGlyphs | Diff |
|------|------|-----------|----------------------|----------|---------------------|------|
| `table-vpos-01.hwp` | 1 | 5 | 89219 | 90 | 0 | generated |
| `table-vpos-01.hwp` | 2 | 5 | 86237 | 67 | 0 | generated |

## 확인된 범위

- Stage 2의 `DocumentViewerStore`/`DocumentViewerView` 변경은 HostApp 컴파일을 깨지 않는다.
- 대표 다중 페이지 문서의 page 1 render tree/native PNG가 계속 생성된다.
- 사용자가 첫 페이지/두 번째 페이지 초기 로드 문제를 관측했던 `table-vpos-01.hwp`의 page 1/2 render data가 정상 생성된다.
- `20250130-hongbo.hwp`, `aift.hwp` 등 문서 전환 이미지 cache 이슈와 관련된 샘플도 render data 생성과 diff 산출물 생성이 가능하다.

## 남은 수동 확인

자동 render smoke는 실제 SwiftUI `LazyVStack` 스크롤 lifecycle과 cache eviction 체감 동작을 직접 검증하지 않는다. 다음 항목은 작업지시자가 빌드 산출물을 열어 확인해야 한다.

- `aift.hwp`처럼 긴 문서를 상단, 중간, 하단으로 스크롤한 뒤 상단으로 돌아왔을 때 첫 페이지가 `ProgressView`에 머물지 않는지
- `/Users/melee/Documents/samples/table-vpos-01.hwp`를 열었을 때 page 1/2가 초기 화면에서 지연 표시되지 않는지
- `복학원서.hwp`에서 `20250130-hongbo.hwp`로 문서 전환 후 이전 문서 이미지가 새 문서에 섞여 나오지 않는지

수동 확인 대상 앱:

```text
/tmp/rhwp-mac-task92/build.noindex/DerivedDataStage3/Build/Products/Debug/AlhangeulMac.app
```

## 잔여 리스크

- page tree cache eviction 자체의 메모리 절감 효과는 Instruments 또는 별도 runtime 계측으로 아직 수치화하지 않았다.
- `visiblePages`는 SwiftUI lifecycle 기반 soft signal이므로 viewport 중심 page와 완전히 같지는 않다.
- 이번 단계는 render data와 build 안정성 검증이며, UI 스크롤 interaction의 최종 판정은 수동 확인에 의존한다.

## 다음 단계

작업지시자 수동 확인 결과가 문제없으면 Stage 4에서 최종 보고서 작성, 오늘할일 완료 처리, PR 게시 준비로 진행한다.

## 승인 요청

Stage 3 결과를 승인하면 Stage 4(최종 보고와 작업 상태 정리)로 진행한다.
