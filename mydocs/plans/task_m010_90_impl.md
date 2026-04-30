# Task #90 구현 계획서

본 문서는 [`task_m010_90.md`](task_m010_90.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/Users/melee/Documents/projects/rhwp-mac`
- **Branch**: `local/task90`
- **Issue**: #90
- **Milestone**: M010 (`v0.1`)
- **주 대상**: `samples/복학원서.hwp`, render debug 산출물, `Sources/RhwpCoreBridge`
- **보존 대상**: HostApp/Quick Look/Thumbnail의 render tree 기반 native renderer 기준 경로, `Sources/RhwpCoreBridge`의 AppKit/UIKit 비의존 경계

## 구현 원칙

- 이 작업의 1차 목적은 렌더 품질 원인 분리다. 원인이 분리되기 전에는 표시 보정 또는 layout 보정 코드를 넣지 않는다.
- 제품 기준 경로는 `rhwp_render_page_tree` + `RenderNode` + `CGTreeRenderer` native renderer로 유지한다.
- `rhwp_render_page_svg` 산출물은 core/native 책임 경계를 판단하기 위한 진단 기준으로만 사용한다.
- core 직접 수정은 하지 않는다. upstream 문제가 결론이면 최소 재현 자료와 보고 내용을 정리한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다.
- `project.yml`이 Xcode project 원본이므로 `AlhangeulMac.xcodeproj`는 직접 수정하지 않는다.
- 단계별 산출물은 재현 명령, output 경로, sample hash, summary 핵심값을 보고서에 남긴다.

## Stage 1. 기준 산출물 재생성과 overflow 재현 확인

### 목표

- `복학원서.hwp` 1페이지에서 현재 브랜치의 render debug 산출물을 재생성한다.
- #84/#85에서 관찰된 `LAYOUT_OVERFLOW` 계열 현상이 현재 `local/task90`에서도 재현되는지 확인한다.
- 이후 단계 분석에 사용할 산출물 위치와 핵심 summary 값을 고정한다.

### 작업

- `samples/복학원서.hwp` 파일 존재 여부와 SHA-256 hash를 확인한다.
- `render-debug-compare.sh`로 page 1 render tree JSON, core SVG, native PNG, summary를 생성한다.
- 명령 stderr/stdout에서 `LAYOUT_OVERFLOW`, `LAYOUT_OVERFLOW_DRAW` diagnostic 발생 여부를 기록한다.
- summary에서 page size, render tree JSON 크기, core SVG 크기, native PNG 크기, text run 통계, diff 생성 여부를 추출한다.
- 생성 산출물 중 필수 산출물 4종이 비어 있지 않은지 확인한다.
- Stage 1 보고서에 산출물 경로와 재현 결과를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m010_90_stage1.md`

### 완료 기준

- `복학원서.hwp` page 1의 render tree JSON, core SVG, native PNG, summary가 생성된다.
- diagnostic 발생 여부와 summary 핵심값이 단계 보고서에 기록된다.
- source code 변경은 없다.

### 검증

```bash
git status --short --branch
shasum -a 256 samples/복학원서.hwp
./scripts/render-debug-compare.sh /tmp/rhwp-task90-bokhak-stage1 --page 1 samples/복학원서.hwp
ls -lh /tmp/rhwp-task90-bokhak-stage1
sed -n '1,120p' /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-summary.txt
git diff --check
```

### 커밋 메시지

```text
Task #90 Stage 1: 기준 산출물 재생성과 overflow 재현
```

## Stage 2. overflow node와 page geometry 분석

### 목표

- render tree JSON에서 page bbox 밖으로 나가는 node를 구조적으로 식별한다.
- overflow node의 type, bbox, text run, parent chain, clip 관련 정보를 정리한다.
- diagnostic이 가리키는 overflow와 render tree geometry가 같은 현상인지 확인한다.

### 작업

- render tree JSON의 root/page bbox와 `RhwpDocument.pageSize(at:)` 값의 관계를 확인한다.
- 모든 node bbox를 page rect와 비교해 오른쪽/아래 경계를 넘는 후보를 추린다.
- 후보 node의 type, bbox, text, font size, baseline, parent node type, cell/body clip 정보를 기록한다.
- `Body.clip_rect`, `TableCell.clip`, node bbox 등 Swift 모델이 디코딩하는 clip 관련 필드가 overflow node 주변에 존재하는지 확인한다.
- 기존 `CGTreeRenderer`가 해당 clip 필드를 실제로 적용하는 위치를 확인한다.
- 반복 가능한 분석이 필요하면 stage 내부에서 임시 분석 스크립트를 `/tmp`에 두고, 저장소 도구 보강이 필요하다고 판단될 때만 구현계획 보정 승인을 요청한다.

### 예상 변경 파일

- `mydocs/working/task_m010_90_stage2.md`

### 완료 기준

- page bbox 밖으로 나가는 대표 node 목록과 parent 구조가 단계 보고서에 정리된다.
- Swift renderer가 활용 가능한 clip/container 정보가 render tree에 있는지 1차 판단한다.
- source code 변경은 없다. 도구 보강이 필요하면 다음 단계 전 작업지시자에게 범위 보정을 요청한다.

### 검증

```bash
git status --short --branch
sed -n '1,220p' Sources/RhwpCoreBridge/RenderTree.swift
sed -n '1,140p' Sources/RhwpCoreBridge/CGTreeRenderer.swift
rg -n "\"clip_rect\"|\"clip\"|\"TextRun\"|\"bbox\"" /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-render-tree.json
git diff --check
```

### 커밋 메시지

```text
Task #90 Stage 2: overflow node와 page geometry 분석
```

## Stage 3. Swift renderer와 core layout 책임 경계 판단

### 목표

- overflow가 core SVG와 native PNG에 공통으로 나타나는지, native renderer에서만 나타나는지 판정한다.
- 앱 저장소에서 수정 가능한 Swift renderer 문제인지, render tree/layout 산출 또는 upstream core 문제인지 결론낸다.
- 앱 저장소 수정이 필요하면 수정 범위, 검증 샘플, 위험도를 다음 승인 지점에 올린다.

### 작업

- core SVG와 native PNG를 나란히 비교해 overflow text의 위치와 잘림 여부를 확인한다.
- 필요하면 core SVG를 rasterize해 core PNG와 native PNG diff를 비교한다. `qlmanage` 실패는 필수 산출물 실패로 보지 않고 summary의 `DiffReason`으로 기록한다.
- render tree에는 clip 정보가 있으나 native renderer가 적용하지 않는 경우, `CGTreeRenderer` 수정 후보와 영향을 받는 node type을 정리한다.
- render tree 자체의 bbox/text position이 page 밖이면 upstream core layout 또는 render tree export 문제로 분리한다.
- HostApp Viewer의 page bounds clipping, Quick Look/Thumbnail bitmap context clipping이 layout 문제를 숨기는 표시 계층 보정인지 확인한다.
- 결론이 앱 저장소 코드 수정이면 구현계획서 개정 또는 후속 단계 추가 승인 요청으로 전환한다.
- 결론이 upstream 보고이면 최소 재현 자료, sample hash, 산출물, 관찰값, 기대/실제 차이를 정리한다.

### 예상 변경 파일

- `mydocs/working/task_m010_90_stage3.md`
- 필요 시 `mydocs/feedback/` 또는 `mydocs/troubleshootings/`의 조사 메모

### 완료 기준

- `Swift renderer 문제`, `render tree export 문제`, `upstream layout 문제`, `표시 계층 clipping 문제` 중 어디에 가까운지 결론이 단계 보고서에 기록된다.
- 앱 저장소 수정 여부와 다음 조치가 명확해진다.
- 승인 없이 source code 수정은 하지 않는다.

### 검증

```bash
git status --short --branch
sed -n '1,220p' /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-core.svg
sips -g pixelWidth -g pixelHeight /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-native.png
sed -n '1,160p' /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-summary.txt
git diff --check
```

### 커밋 메시지

```text
Task #90 Stage 3: Swift renderer와 core layout 책임 경계 판단
```

## Stage 4. 검증과 후속 조치 자료 정리

### 목표

- 조사 결론을 최종 보고서로 정리한다.
- Quick Look, Thumbnail, HostApp Viewer에 대한 영향 범위와 잔여 리스크를 문서화한다.
- upstream 보고 또는 앱 저장소 후속 수정이 필요하면 바로 사용할 수 있는 자료를 남긴다.

### 작업

- Stage 1-3의 산출물, summary 핵심값, overflow node 분석, 책임 경계 판단을 최종 보고서로 통합한다.
- `samples/복학원서.hwp` sample hash와 재현 명령을 최종 보고서에 기록한다.
- upstream 이슈가 필요하면 제목, 환경, 재현 절차, 첨부 산출물 목록, 기대/실제 결과 초안을 작성한다.
- 앱 저장소 후속 수정이 필요하면 수정 후보 파일, 예상 검증 샘플, 별도 이슈 필요 여부를 정리한다.
- 오늘할일 `#90` 행을 완료 상태로 갱신한다.

### 예상 변경 파일

- `mydocs/report/task_m010_90_report.md`
- `mydocs/orders/20260429.md`
- `mydocs/working/task_m010_90_stage4.md`
- 필요 시 `mydocs/troubleshootings/`의 렌더 품질 재현 기록

### 완료 기준

- 최종 보고서가 조사 결론, 재현 명령, 산출물 위치, 영향 범위, 후속 조치를 포함한다.
- 오늘할일이 완료 상태로 갱신된다.
- 작업트리가 clean 상태가 된다.

### 검증

```bash
git status --short --branch
git diff --check
./scripts/validate-stage3-render.sh
```

source code 수정이 포함된 방향으로 계획이 보정된 경우 추가 검증:

```bash
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 커밋 메시지

```text
Task #90 Stage 4 + 최종 보고서: overflow 조사 결론과 후속 조치 정리
```

## 승인 요청 사항

1. 위 4단계 구현계획으로 Stage 1 조사에 착수해도 되는지 승인 요청한다.
2. Stage 1-3은 source code 변경 없이 조사와 단계 보고서 작성으로 진행한다.
3. 조사 중 앱 저장소 코드 수정 필요성이 확인되면 즉시 멈추고 구현계획 보정 승인을 요청한다.
