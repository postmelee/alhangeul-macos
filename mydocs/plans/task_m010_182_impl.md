# Issue #182 구현 계획서

## 작업명

홍보 페이지 기능 섹션을 호버 재생 비디오 쇼케이스로 개편

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_182.md`를 기준으로 진행한다.
- 작업 브랜치는 `local/task182`, 통합 대상은 `devel-webview`로 둔다.
- 변경 범위는 GitHub Pages 정적 홍보 페이지의 세 번째 기능 설명 섹션으로 제한한다.
- 섹션 상단 문구는 유지한다.
  - `미리보기부터 뷰어까지, Mac 방식으로`
  - `Finder와 Quick Look, 앱 뷰어까지 HWP/HWPX 문서를 Mac 안에서 자연스럽게 열고 공유합니다.`
- 기존 progress bar/checkpoint 박스와 스크롤 기반 feature timeline은 제거 대상이다.
- hover만으로 동작이 막히지 않도록 keyboard focus와 click에서도 같은 active 전환을 제공한다.
- 자동 재생은 브라우저 정책에 맞춰 `muted`, `playsinline`, active media만 재생하는 구조로 구현한다.
- 모바일과 좁은 화면은 hover 대체 흐름으로 horizontal scroll snap과 pagination dots를 사용한다.
- 제공 동영상은 GitHub Pages 로딩 성능을 고려해 웹용 무음 압축본을 우선 검토한다.
- HostApp, Quick Look, Thumbnail extension, Xcode project, 배포 설정은 변경하지 않는다.
- 각 단계 완료 후 단계별 완료보고서를 작성하고 작업지시자 승인 전 다음 단계로 진행하지 않는다.

## 사전 조사 요약

현행 세 번째 섹션 구조는 `docs/index.html`의 `features-section`이다.

- `docs/index.html`: `.feature-step` 4개와 `.feature-visual` 안의 `.finder-progress`, `.finder-image-stage`가 기능 섹션을 구성한다.
- `docs/styles.css`: `.features-section`에 많은 CSS 변수가 있고, `.finder-progress`, `.quicklook-*`, `.viewer-*`, `.mac-share-*` 이미지 레이어 opacity를 제어한다.
- `docs/script.js`: `featureStages`, `getFeatureScrollState()`, `applyFeatureVisualState()`가 scroll position을 feature timeline으로 변환한다.
- 현재 구조는 `min-height: 1720vh` desktop, `940vh` 좁은 화면 override로 긴 sticky scroll 구간을 만든다.
- #178 merge 이후 `devel-webview` 기준 두 번째 섹션 보강이 이미 반영되어 있으므로 이번 작업은 최신 `docs/` 구조 위에서 진행한다.

제공 영상 자산:

- Finder 썸네일용 화면 기록: H.264, 2032x1162, 약 3.79초, 약 5.1MB
- `quicklook.mp4`: H.264, 1920x1080, 60fps, 약 12.25초, 약 34.8MB
- `share.mp4`: H.264, 1920x1080, 60fps, 약 17.5초, 약 31.3MB
- `edit_and_save.mp4`: H.264, 1920x1080, 60fps, 약 7.08초, 약 23.9MB

현재 `docs/assets/`에는 기존 이미지 기반 animation 자산과 `thumbnail2.mov`, `zoom-and-copy.mov`가 있다. 이번 작업에서 기존 자산을 즉시 삭제하지 않고, 기능 섹션에서 더 이상 참조하지 않는 자산은 최종 단계에서 잔여 참조 여부를 확인한 뒤 정리 여부를 결정한다.

## Stage 1: 기능 섹션 설계와 자산 처리 기준 확정

대상:

- `mydocs/working/task_m010_182_stage1.md`
- 필요 시 `mydocs/working/assets/task_m010_182_stage1_*.png`

작업:

- 레퍼런스 화면 기록과 현재 `features-section`의 정보 구조를 비교한다.
- desktop 레이아웃을 확정한다.
  - 기본안: 왼쪽 큰 영상, 오른쪽 기능 리스트
  - 기능 리스트는 hover/focus/click target 역할을 한다.
  - active 항목은 충분한 contrast, blue accent, 명확한 focus-visible 상태를 가진다.
- mobile 레이아웃을 확정한다.
  - 동영상 카드 horizontal scroll snap
  - 동영상 아래 pagination dots
  - dot click과 scroll 위치 동기화
- Feature별 copy inventory를 확정한다.
  - `Finder에서 썸네일로 찾기`
  - `스페이스바로 즉시 미리보기`
  - `앱에서 한글 파일 수정하기.`
  - `문서를 Mac 방식으로 공유하기`
- 자산 처리 기준을 확정한다.
  - 원본 파일명에서 URL 안전한 `feature-*.mp4` 파일명으로 변환
  - 무음 압축본 목표 크기와 해상도 후보
  - poster 이미지 필요 여부
- Frontend App Builder 기준으로 섹션 단위 디자인/상호작용 명세를 만든다. 기존 디자인 시스템과 사용자 제공 레퍼런스만으로 충분히 명확하면 Image Gen은 생략 사유를 보고서에 기록하고, 시각 판단이 애매하면 섹션 concept 이미지를 생성해 승인 대상으로 둔다.

검증:

```bash
rg -n "Feature|Finder|Quick Look|scroll snap|pagination|동영상|hover|focus" mydocs/working/task_m010_182_stage1.md
git diff --check -- mydocs/working/task_m010_182_stage1.md
```

완료 조건:

- desktop/mobile 레이아웃과 interaction rule이 단계 보고서에 확정되어 있다.
- 영상 파일명, 압축 기준, poster 필요 여부가 확정되어 있다.
- 구현 단계에서 임의로 판단할 UI 결정이 남아 있지 않다.

예상 커밋:

```text
Task #182 Stage 1: 기능 섹션 설계와 자산 기준 확정
```

## Stage 2: 기능 동영상 자산 생성과 배치

대상:

- `docs/assets/feature-finder-thumbnail.mp4`
- `docs/assets/feature-quicklook.mp4`
- `docs/assets/feature-edit-save.mp4`
- `docs/assets/feature-share.mp4`
- 필요 시 `docs/assets/feature-*.jpg` 또는 `docs/assets/feature-*.png`
- `mydocs/working/task_m010_182_stage2.md`

작업:

- Finder 썸네일용 화면 기록을 `feature-finder-thumbnail.mp4`로 변환한다.
- 제공된 세 MP4를 `docs/assets/feature-quicklook.mp4`, `feature-edit-save.mp4`, `feature-share.mp4`로 배치한다.
- 원본에 오디오가 있으면 웹용 자산에서는 제거한다.
- 16:9 영상과 Finder 2032x1162 영상이 같은 프레임 안에서 어색하지 않도록 object-fit 기준을 확정한다.
- 파일 크기와 가독성을 비교해 압축 조건을 조정한다.
- poster 이미지가 필요하면 각 영상의 대표 프레임을 추출한다.
- 기존 자산 삭제는 하지 않는다. 참조 제거와 정리는 구현/검증 후에 결정한다.

검증:

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of default=noprint_wrappers=1 docs/assets/feature-finder-thumbnail.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of default=noprint_wrappers=1 docs/assets/feature-quicklook.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of default=noprint_wrappers=1 docs/assets/feature-edit-save.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of default=noprint_wrappers=1 docs/assets/feature-share.mp4
find docs/assets -maxdepth 1 -type f | sort | rg "feature-"
git diff --check -- docs/assets mydocs/working/task_m010_182_stage2.md
```

완료 조건:

- 기능별 video asset 4개가 `docs/assets/`에 존재한다.
- 영상에 불필요한 audio stream이 없다.
- 각 영상 크기, duration, 해상도, 압축 판단이 단계 보고서에 기록되어 있다.

예상 커밋:

```text
Task #182 Stage 2: 기능 동영상 자산 배치
```

## Stage 3: 데스크톱 hover/focus 쇼케이스 구현

대상:

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- `mydocs/working/task_m010_182_stage3.md`

작업:

- 기존 `.finder-progress` progress bar/checkpoint markup을 제거한다.
- 기존 이미지 레이어 기반 `.finder-image-stage` 구조를 기능별 video showcase 구조로 교체한다.
- 기능 항목을 semantic button 또는 button 역할이 명확한 control로 구성한다.
- desktop에서 왼쪽 큰 video frame, 오른쪽 feature list 레이아웃을 구현한다.
- `docs/script.js`의 scroll-driven feature timeline 로직을 제거하거나 새 feature controller로 대체한다.
- active feature 전환 시 다음 동작을 보장한다.
  - 이전 active video pause
  - 새 active video `currentTime = 0`
  - 새 active video muted autoplay 시도
  - play promise rejection 안전 처리
- 같은 feature에 다시 hover/focus/click해도 영상이 처음부터 재생된다.
- `prefers-reduced-motion: reduce`에서는 자동 재생을 억제하거나 최소화한다.
- reveal animation과 FAQ accordion은 유지한다.

검증:

```bash
node --check docs/script.js
rg -n "feature-finder-thumbnail|feature-quicklook|feature-edit-save|feature-share|data-feature|currentTime|play\\(|pause\\(" docs/index.html docs/styles.css docs/script.js
rg -n "finder-progress|progress-checkpoints|featureStages|getFeatureScrollState|applyFeatureVisualState" docs/index.html docs/styles.css docs/script.js
git diff --check -- docs mydocs/working/task_m010_182_stage3.md
```

완료 조건:

- desktop markup/CSS/JS가 hover/focus/click 기반 feature video 전환 구조로 바뀌어 있다.
- 기존 progress bar/checkpoint UI가 더 이상 렌더되지 않는다.
- scroll-driven feature timeline 함수가 제거되었거나 사용되지 않는다.
- 문법 검증을 통과한다.

예상 커밋:

```text
Task #182 Stage 3: 데스크톱 기능 동영상 쇼케이스 구현
```

## Stage 4: 모바일 scroll snap과 pagination dots 구현

대상:

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- `mydocs/working/task_m010_182_stage4.md`

작업:

- 좁은 화면에서 기능 리스트/영상 구조를 horizontal carousel로 전환한다.
- 각 기능 card는 `scroll-snap-align`을 가진다.
- video 아래 pagination dots를 배치한다.
- carousel scroll 위치와 active dot을 동기화한다.
- dot click/tap으로 해당 card로 이동한다.
- IntersectionObserver 또는 scroll event를 최소 범위로 사용해 active mobile card의 영상만 재생한다.
- 320px 폭에서도 heading, body, video, dots가 겹치지 않도록 type scale과 frame sizing을 조정한다.
- desktop hover 동작과 mobile snap 동작이 서로 충돌하지 않도록 breakpoint별 controller 책임을 분리한다.

검증:

```bash
node --check docs/script.js
rg -n "scroll-snap|feature-pagination|feature-dot|scrollIntoView|IntersectionObserver|matchMedia" docs/index.html docs/styles.css docs/script.js
git diff --check -- docs mydocs/working/task_m010_182_stage4.md
```

완료 조건:

- mobile/narrow 화면에서 좌우 scroll snap 전환이 가능한 구조다.
- pagination dots가 현재 card와 동기화된다.
- dot click/tap으로 card 이동이 가능하다.
- text overflow와 media overlap 방지 CSS가 반영되어 있다.

예상 커밋:

```text
Task #182 Stage 4: 모바일 기능 영상 캐러셀 구현
```

## Stage 5: 브라우저 시각 검증과 반응형 보정

대상:

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- 필요 시 `docs/assets/*`
- `mydocs/working/task_m010_182_stage5.md`
- 필요 시 `mydocs/working/assets/task_m010_182_stage5_*.png`

작업:

- 로컬 정적 서버로 `docs/` 페이지를 실행한다.
- Browser/IAB를 우선 사용해 desktop과 mobile viewport를 확인한다.
- desktop에서 기능 hover/focus/click 및 같은 feature 재진입 replay를 확인한다.
- mobile에서 scroll snap, dot click, active 영상 재생/정지를 확인한다.
- Browser console error를 확인한다.
- 미디어 frame, section spacing, heading/copy 유지 여부, #178 두 번째 섹션과의 연결감을 확인한다.
- Frontend App Builder 기준으로 최신 구현 screenshot과 기준 concept/reference를 `view_image`로 확인하고 mismatch ledger를 단계 보고서에 기록한다.
- 필요한 CSS/JS 보정을 같은 단계 안에서 수행한다.

검증:

```bash
python3 -m http.server 8080 --directory docs
node --check docs/script.js
rg -n "feature-.*\\.mp4|data-feature|feature-pagination|scroll-snap|currentTime|playsinline|muted" docs
git diff --check -- docs mydocs/working/task_m010_182_stage5.md
```

브라우저 수동 검증 항목:

- desktop first feature visible frame
- desktop hover/focus/click active 전환
- desktop same-feature replay
- mobile horizontal snap
- mobile pagination dots 동기화
- Browser console error 없음
- 320px 이상 폭에서 text/media overlap 없음

완료 조건:

- desktop과 mobile에서 핵심 상호작용이 동작한다.
- 영상이 정상 표시되고 active media만 재생된다.
- 남은 중대 시각 drift가 없다.
- 검증 결과와 잔여 위험이 단계 보고서에 기록되어 있다.

예상 커밋:

```text
Task #182 Stage 5: 기능 영상 쇼케이스 브라우저 검증과 보정
```

## Stage 6: 최종 보고와 PR 준비

대상:

- `mydocs/report/task_m010_182_report.md`
- `mydocs/orders/20260509.md`
- 필요 시 최종 검증 결과 문서 보강

작업:

- 최종 결과보고서를 작성한다.
- 오늘할일 #182 상태를 완료로 갱신하고 완료 시각을 기록한다.
- 최종 검증 명령을 재실행한다.
- 사용하지 않게 된 기존 feature animation 자산의 참조 여부를 확인하고, 삭제가 범위에 맞는지 판단한다.
- `task-final-report` 절차 진입 전 작업 브랜치의 미커밋 변경이 없도록 정리한다.

검증:

```bash
rg -n "Issue #182|호버 재생|동영상 쇼케이스|검증 결과|잔여 위험" mydocs/report/task_m010_182_report.md
rg -n "#182 .*완료" mydocs/orders/20260509.md
node --check docs/script.js
git diff --check -- docs mydocs
git status --short
```

완료 조건:

- 최종 보고서가 작성되어 있다.
- 오늘할일 #182가 완료 처리되어 있다.
- 작업 브랜치의 변경이 모두 커밋되어 PR 게시 가능한 상태다.

예상 커밋:

```text
Task #182 Stage 6 + 최종 보고서: 기능 영상 쇼케이스 개편 완료
```

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1 `기능 섹션 설계와 자산 처리 기준 확정`을 진행할지 승인 요청한다. 승인 전에는 `docs/` 구현 파일과 홍보 페이지 동영상 자산 변경을 진행하지 않는다.
