# Task M016 #146 구현계획서

수행계획서: `mydocs/plans/task_m016_146.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #146 Viewer와 Quick Look/Thumbnail 렌더 경로 한계 문서화
- 마일스톤: M016 (`v0.1 출시 전 보강`)
- 브랜치: `local/task146`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 주 대상: README, 아키텍처 문서, 릴리스/배포 가이드, release note skeleton의 렌더링 경로와 known limitations 문구
- 목표: v0.1 사용자가 HostApp viewer와 Finder/Quick Look 통합의 renderer 차이, smoke gate와 시각 품질 검증의 차이, native renderer의 후속 개선 범위를 오해하지 않도록 문서화한다.

## 구현 원칙

- 이번 작업은 문서와 release note skeleton 정합화만 수행한다. Swift/Rust renderer, extension, `rhwp-studio` asset, Xcode project는 수정하지 않는다.
- HostApp viewer/editor 화면은 WKWebView `rhwp-studio` 경로로 설명한다.
- HostApp PDF 내보내기, 인쇄, Quick Look preview, Finder thumbnail은 실제 코드 기준으로 각각 다른 경로를 구분해 설명한다.
- Quick Look/Thumbnail smoke 통과를 renderer visual parity 보장으로 표현하지 않는다.
- 손상·대용량·미지원 입력 fallback은 복구나 완전 호환이 아니라 crash/hang/raw error 방지로 표현한다.
- known limitations는 사용자 문구와 개발자 근거를 분리한다. README는 요약, release note skeleton은 배포 시점 제한 사항, 최종 보고서는 상세 근거를 맡는다.
- M016에서 이미 완료된 #145/#147/#148/#149/#150/#151/#167 결과를 되돌리거나 중복하지 않는다.
- 기존 renderer 이슈의 milestone 이동, close, 재분류는 수행하지 않는다.
- 모든 문서는 한국어로 작성한다.

## Stage 1. 현재 렌더 경로와 handoff inventory

### 목표

- HostApp viewer, PDF export, print, Quick Look, Thumbnail의 실제 코드 경로와 기존 문서 표현을 변경 없이 대조한다.
- #149/#150/#151/#167 최종 보고서에서 #146에 넘긴 known limitation 후보를 수집한다.

### 작업

- HostApp viewer 경로를 확인한다.
  - `DocumentViewerStore`
  - `RhwpStudioWebView`
  - `RhwpStudioResourceLocator`
  - `RhwpStudioResourceSchemeHandler`
  - `RhwpStudioDocumentSchemeHandler`
- PDF export 경로를 확인한다.
  - `RhwpStudioHostBridgeScript`의 export payload
  - `RhwpStudioPDFExportController`
  - `HwpPreviewPDFRenderer`
- print 경로를 확인한다.
  - `RhwpStudioHostBridgeScript`의 page payload
  - `RhwpStudioPrintController`
  - PDFKit/AppKit print operation
- Quick Look/Thumbnail 경로를 확인한다.
  - `HwpPreviewProvider`
  - `HwpThumbnailProvider`
  - `HwpPageImageRenderer`
  - `HwpPreviewPDFRenderer`
  - `CGTreeRenderer`
- 현재 README, `project_architecture.md`, `release_distribution_guide.md`, `write-release-notes.sh`의 관련 표현을 대조한다.
- #149/#150/#151/#167 보고서의 #146 handoff 항목을 수집한다.
- Stage 1 보고서에 "제품 표면별 실제 renderer", "현재 문서 표현", "수정 필요 여부"를 표로 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_146_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "rhwp-studio|WKWebView|exportPDF|PDF|print|page SVG|HwpPreviewPDFRenderer|HwpPageImageRenderer|CGTreeRenderer|Quick Look|Thumbnail" \
  Sources/HostApp Sources/Shared Sources/QLExtension Sources/ThumbnailExtension
rg -n "Rendering Paths|렌더링 경로|WKWebView|Quick Look|Thumbnail|PDF|인쇄|known limitation|한계|native parity|v0\\.5" \
  README.md mydocs/tech/project_architecture.md mydocs/manual/release_distribution_guide.md scripts/ci/write-release-notes.sh
rg -n "#146|known limitation|한계|native renderer|WKWebView|Quick Look|Thumbnail" \
  mydocs/report/task_m016_149_report.md \
  mydocs/report/task_m016_150_report.md \
  mydocs/report/task_m016_151_report.md \
  mydocs/report/task_m016_167_report.md
git diff --check
```

### 완료 기준

- 제품 표면별 실제 renderer 경로가 Stage 1 보고서에 정리된다.
- 기존 문서의 모호하거나 코드와 어긋난 표현 후보가 분리된다.
- Stage 2에서 설계할 known limitations 입력이 확정된다.

### 커밋 메시지

```text
Task #146 Stage 1: 렌더 경로 inventory 정리
```

## Stage 2. known limitations와 milestone 분리 기준 설계

### 목표

- 사용자에게 공개할 known limitations 문구와 개발자용 근거를 분리해 설계한다.
- v0.1, v0.2, v0.5, v0.6/v1.0의 책임 경계를 문서별로 확정한다.

### 작업

- known limitations 범주를 확정한다.
  - 렌더 경로 차이: WKWebView viewer와 native Quick Look/Thumbnail이 다를 수 있음
  - native renderer parity: style, image effect/fill mode, text layout, body overflow, RawSvg/OLE 등
  - fallback 한계: 손상/대용량/미지원 파일 처리의 목적과 비보장 범위
  - 검증 한계: 설치본 thumbnail smoke와 preview 수동 확인, visual parity 미보장
  - release 한계: v0.1 public artifact와 후속 public release gate의 분리
- README에 넣을 요약 문구를 설계한다.
- `release_distribution_guide.md`에 넣을 release note/known limitations 운영 기준을 설계한다.
- `scripts/ci/write-release-notes.sh`의 skeleton에 넣을 섹션 구조를 설계한다.
- `project_architecture.md`에서 코드 경로 설명이 현재와 맞지 않거나 빠진 부분을 설계한다.
- Stage 2 보고서에 변경 대상별 문구 초안과 제외할 과한 상세를 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_146_stage2.md`

### 검증

```bash
git status --short --branch
rg -n "렌더 경로|known limitations|한계|v0\\.1|v0\\.2|v0\\.5|v0\\.6|v1\\.0|Quick Look|Thumbnail|WKWebView|fallback|smoke" \
  mydocs/working/task_m016_146_stage2.md
git diff --check
```

### 완료 기준

- README, release guide, release note skeleton, architecture 문서의 소유 범위가 확정된다.
- 사용자-facing 문구와 개발자 근거가 분리된다.
- Stage 3-4에서 실제로 수정할 파일과 문구 방향이 확정된다.

### 커밋 메시지

```text
Task #146 Stage 2: known limitations 문구 설계
```

## Stage 3. README와 운영 문서 보정

### 목표

- Stage 2 설계를 README, 아키텍처 문서, 릴리스/배포 가이드에 반영한다.
- v0.1 viewer와 Finder/Quick Look 경로의 차이가 public 문서에서 일관되게 드러나도록 한다.

### 작업

- `README.md`를 보정한다.
  - 소개 문구에서 "앱 viewer"와 "Finder/Quick Look" 경로 차이를 짧게 드러낸다.
  - Rendering Paths 표 또는 섹션을 실제 코드 경로 기준으로 정리한다.
  - Release/Install 또는 Features 근처에 v0.1 known limitations 요약을 추가한다.
  - 완전 호환으로 읽힐 수 있는 문구를 줄인다.
- `mydocs/tech/project_architecture.md`를 보정한다.
  - HostApp viewer, PDF export, print, Quick Look, Thumbnail 경로 설명을 현재 코드와 맞춘다.
  - native render tree 경로의 소유 범위를 Quick Look/Thumbnail/PDF export와 장기 native viewer 전환으로 분리한다.
- `mydocs/manual/release_distribution_guide.md`를 보정한다.
  - public release note에 known limitations와 smoke 결과를 포함해야 한다는 기준을 추가한다.
  - #151 smoke gate와 #146 known limitations의 관계를 정리한다.
- 필요 시 `mydocs/tech/product_roadmap_notes.md`에만 짧은 연결 문구를 추가한다.
- Stage 3 보고서에 변경 파일과 사용자 영향 문구를 정리한다.

### 예상 변경 파일

- `README.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/tech/product_roadmap_notes.md` (필요 시)
- `mydocs/working/task_m016_146_stage3.md`

### 검증

```bash
git status --short --branch
rg -n "Rendering Paths|렌더링 경로|Known Limitations|알려진 제한|WKWebView|rhwp-studio|Quick Look|Thumbnail|PDF 내보내기|인쇄|native renderer|v0\\.5|smoke" \
  README.md \
  mydocs/tech/project_architecture.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/tech/product_roadmap_notes.md
rg -n "완전 호환|완벽|100%|동일" README.md mydocs/tech/project_architecture.md mydocs/manual/release_distribution_guide.md
git diff --check
```

### 완료 기준

- README에서 v0.1 렌더 경로와 known limitations가 public 사용자 기준으로 확인된다.
- architecture 문서가 현재 HostApp/PDF/print/Quick Look/Thumbnail 경로와 충돌하지 않는다.
- release guide가 release note의 known limitations 포함 기준을 가진다.

### 커밋 메시지

```text
Task #146 Stage 3: 렌더 경로 문서 보정
```

## Stage 4. release note skeleton과 검증 정리

### 목표

- public release note skeleton에 렌더 경로와 known limitations 섹션이 빠지지 않도록 보강한다.
- dummy release note output을 생성해 사용자-facing 문구와 provenance/limitation 위치를 검증한다.

### 작업

- `scripts/ci/write-release-notes.sh`를 보강한다.
  - `렌더링 경로` 또는 `알려진 제한 사항` 섹션을 추가한다.
  - HostApp viewer, Quick Look/Thumbnail, PDF export/print의 경로 차이를 짧게 설명한다.
  - smoke 결과와 최종 보고서 연결 문구를 추가한다.
  - third-party/provenance 섹션과 중복되지 않게 배치한다.
- script가 release note output을 쓸 때 필요한 파일 존재 검증은 기존 provenance 검증과 충돌하지 않게 유지한다.
- dummy checksum으로 release note를 생성하고 output을 점검한다.
- Stage 4 보고서에 release note 예시 경로, 주요 문구, 검증 결과를 기록한다.

### 예상 변경 파일

- `scripts/ci/write-release-notes.sh`
- `mydocs/working/task_m016_146_stage4.md`

### 검증

```bash
git status --short --branch
bash -n scripts/ci/write-release-notes.sh
scripts/ci/write-release-notes.sh 0.1.0 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef /tmp/alhangeul-task146-release-note.md
rg -n "렌더|Quick Look|Thumbnail|WKWebView|rhwp-studio|PDF|인쇄|한계|제한|smoke|최종 보고서|rhwp core|Third Party" \
  /tmp/alhangeul-task146-release-note.md
git diff --check
```

### 완료 기준

- release note skeleton이 syntax check를 통과한다.
- dummy output에 provenance, 설치 안내, 렌더 경로, known limitations가 함께 존재한다.
- release note 문구가 README와 release guide의 책임 경계와 충돌하지 않는다.

### 커밋 메시지

```text
Task #146 Stage 4: release note 한계 문구 보강
```

## Stage 5. 최종 보고와 PR 준비

### 목표

- #146 문서화 결과, 검증 결과, 남은 renderer parity 후속 범위를 최종 보고서로 정리한다.
- 오늘할일을 완료 상태로 갱신하고 PR 전 미커밋 변경을 정리한다.

### 작업

- 최종 결과보고서에 변경 파일과 사용자 영향 범위를 표로 정리한다.
- HostApp viewer/PDF/print/Quick Look/Thumbnail 경로별 최종 문구를 요약한다.
- known limitations와 후속 milestone 연결을 정리한다.
  - v0.2: 문서 정보/본문 추출, Spotlight/mdimporter 등 Mac 통합
  - v0.5: Swift native viewer와 renderer parity
  - v0.6/v1.0: native editor/editor safety
- 실행한 검증과 미실행한 Xcode/Rust/Finder smoke 범위를 명시한다.
- `mydocs/orders/20260508.md`의 #146 상태를 완료로 갱신한다.

### 예상 변경 파일

- `mydocs/report/task_m016_146_report.md`
- `mydocs/orders/20260508.md`

### 검증

```bash
git status --short --branch
rg -n "#146|렌더 경로|WKWebView|Quick Look|Thumbnail|PDF|인쇄|known limitations|알려진 제한|v0\\.2|v0\\.5|v0\\.6|v1\\.0|완료" \
  mydocs/report/task_m016_146_report.md mydocs/orders/20260508.md
git diff --check
```

### 완료 기준

- 최종 보고서가 문서화 범위, 검증 결과, 잔여 한계와 후속 milestone을 포함한다.
- 오늘할일 #146 행이 완료 상태와 완료 시각을 가진다.
- PR 생성 전 `git status --short`가 비어 있다.

### 커밋 메시지

```text
Task #146 Stage 5: 렌더 경로 한계 문서화 완료
```

## 전체 수용 기준

- README에서 HostApp viewer와 Quick Look/Thumbnail의 렌더 경로가 모순 없이 설명된다.
- PDF export와 print가 viewer 화면 경로와 같은 renderer라고 오해되지 않는다.
- release note skeleton에 v0.1 known limitations 또는 renderer 경로 한계 섹션이 포함된다.
- Quick Look/Thumbnail smoke gate 통과와 native renderer 시각 품질 parity가 별도 문제로 설명된다.
- 손상·대용량·미지원 입력 fallback이 완전 복구나 완전 호환으로 표현되지 않는다.
- native renderer parity 개선은 v0.5 이후 후속 범위로 남는다.
- renderer 구현, milestone 이동, release 실행 작업은 이번 PR에 포함되지 않는다.

## 승인 요청 사항

1. 위 5단계 구현계획 승인
2. Stage 3에서 README, `project_architecture.md`, `release_distribution_guide.md`를 함께 보정하는 방향 승인
3. Stage 4에서 `scripts/ci/write-release-notes.sh`에 렌더 경로와 known limitations 섹션을 추가하는 방향 승인
4. 다음 단계: 승인 후 Stage 1 `현재 렌더 경로와 handoff inventory` 진행
