# Issue #182 Stage 3 완료 보고서

## 단계명

데스크톱 hover/focus 동영상 쇼케이스 구현

## 작업 범위

이번 단계에서는 홍보 페이지 세 번째 기능 섹션을 기존 scroll-driven 이미지 timeline에서 데스크톱 hover/focus/click 기반 동영상 쇼케이스로 교체했다. 모바일 좌우 snap, pagination dots, 실제 브라우저 시각 검증은 다음 단계 범위로 남겼다.

- `docs/index.html` 기능 섹션 markup 교체
- `docs/styles.css` 기능 섹션 desktop/tablet/small-width 스타일 교체
- `docs/script.js` scroll timeline 제거 및 feature video activation 구현
- progress/checkpoint 박스와 다중 이미지 레이어 제거
- Stage 2에서 생성한 MP4/poster 자산 연결

## 변경 파일

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- `mydocs/working/task_m010_182_stage3.md`

## 구현 내용

### 추가 레이아웃 보정

작업지시자 시각 검증 의견을 반영해 Stage 3 범위 안에서 데스크톱 가독성을 추가 보정했다.

- 동영상 frame과 첫 기능 button의 위쪽 시작선을 맞추기 위해 `.feature-showcase`를 start alignment로 변경
- active 기능이 더 분명히 보이도록 inactive 기능 button의 border, background, opacity를 낮춤
- 이전 기능 섹션의 `feature-highlight` sweep 밑줄 효과를 새 button 구조에 맞게 복구
- 같은 기능 button에 다시 hover/focus/click해도 highlight animation이 재시작되도록 `is-highlight-animating` class를 JS에서 갱신
- 데스크톱 큰 화면에서 heading 위 여백이 FAQ보다 과하게 보이지 않도록 기능 section 상단 padding을 낮춤
- 기능 section 설명문 font-size를 app intro lead 문구와 같은 값으로 맞춤
- 데스크톱 큰 화면에서 기능 section 설명문이 한 줄로 보이도록 기능 heading 최대 폭을 넓힘
- 기능 section 제목과 설명문 사이 간격을 줄이기 위해 설명문 top margin을 낮춤
- section 1/2/3/FAQ가 번갈아 읽히도록 app intro와 FAQ를 회색 배경으로, 기능 동영상 section을 흰 배경으로 전환
- app intro 상단 padding과 하단 기능 설명 font-size를 키워 section 경계와 기능 설명 가독성을 보강
- 기능 동영상 section이 흰 배경으로 바뀌어도 button card가 묻히지 않도록 inactive card 배경과 border 대비를 보강
- app intro 이미지 최대 높이를 낮추고 하단 기능 설명 font-size를 한 번 더 키워 시각적 비중을 조정
- FAQ와 footer 사이에서 body 흰 배경이 노출되지 않도록 기본 footer margin을 제거하고 updates page에만 기존 margin을 유지
- FAQ와 footer가 같은 회색으로 붙어 보이지 않도록 footer 배경을 흰색으로 바꾸고 얇은 top border를 추가
- app intro와 FAQ의 회색 배경을 더 밝게 조정하고 FAQ 하단 padding을 추가해 footer와 붙어 보이지 않도록 보정
- 기능 section heading 문구를 현재 기능 범위에 맞춰 `뷰어` 중심 표현에서 `편집과 공유` 중심 표현으로 갱신
- 가장 작은 화면의 heading font-size와 상단 여백은 유지하면서 기능 section 문구를 `미리보기부터 공유까지` 표현으로 재갱신
- 가장 작은 화면에서 기능 section 설명문이 이전 화면처럼 제목보다 한 단계 작게 보이도록 모바일 font-size 15px와 line-height 1.42를 적용
- section 배경 리듬을 재조정해 app intro/FAQ는 흰색으로 되돌리고, 기능 설명 section과 footer만 밝은 회색 배경을 사용하도록 변경
- app intro `알한글` h2를 기능 section heading과 같은 selector로 묶어 font-size와 font-weight를 동일하게 조정
- 중간 화면 폭에서 footer nav가 설명문을 침범하지 않도록 nav 열 폭을 보장하고 1180px 이하에서는 nav를 설명문 아래 행으로 분리
- 모바일 snap/pagination은 Stage 4 범위로 유지

### Finder 동영상 가독성 보정

작업지시자 시각 검증 의견을 반영해 `Finder에서 썸네일로 찾기` 영상의 핵심 overlay를 다시 키웠다.

- `.hwp 정보 잠김` badge를 124px 높이/38px 텍스트로 2배 추가 확대
- `.hwp 정보 잠김` badge 애니메이션을 이전 방식인 scale/glow/sheen 진행 애니메이션으로 복구
- 중앙 install orb를 285px로 확대
- `알한글 설치` 라벨을 45px 텍스트로 확대
- Finder video/poster URL에 cache-busting query를 붙여 로컬 검증과 배포 후 새 자산을 바로 보도록 조정
- 기존 1440x810, 30fps, 104 frame, 3.466667초 조건은 유지

### HTML

기존 구조를 제거했다.

- `.features-copy`
- `.finder-progress`
- `.progress-checkpoints`
- `.finder-image-stage`
- Quick Look, viewer, share 이미지 overlay stack
- Finder lock/install overlay DOM

새 구조는 다음 기준으로 구성했다.

- 왼쪽: 16:9 `.feature-video-shell`
- 오른쪽: 4개 `.feature-step` button
- 각 button은 `aria-pressed`와 `aria-controls`로 active video와 연결
- 각 video는 `muted`, `playsinline`, `preload="metadata"`, `poster`를 지정

동영상 mapping:

| 기능 | video | poster |
|------|-------|--------|
| Finder 썸네일 | `docs/assets/feature-finder-thumbnail.mp4` | `docs/assets/feature-finder-thumbnail-poster.jpg` |
| Quick Look | `docs/assets/feature-quicklook.mp4` | `docs/assets/feature-quicklook-poster.jpg` |
| 편집/저장 | `docs/assets/feature-edit-save.mp4` | `docs/assets/feature-edit-save-poster.jpg` |
| 공유 | `docs/assets/feature-share.mp4` | `docs/assets/feature-share-poster.jpg` |

### CSS

기능 섹션을 긴 sticky scroll band에서 일반 section으로 전환했다.

- `min-height: 1720vh` 기반 scroll timeline 제거
- progress/checkpoint 관련 selector 제거
- video frame을 큰 좌측 영역에 배치
- feature list는 오른쪽 세로 button list로 배치
- active 항목은 white surface, blue accent line, hairline border로 표시
- inactive 항목은 opacity를 낮추되 본문 가독성을 유지
- 좁은 화면에서는 Stage 4 전까지 깨지지 않도록 단순 stacked/grid layout으로 보정

### JavaScript

기존 scroll timeline 계산을 제거했다.

- `featureStages`
- `checkpointsPerFeature`
- `progressMap`
- `quicklookScrollSteps`
- `getFeatureScrollState()`
- `getFeaturePhase()`
- `setStageLabels()`
- `applyFeatureVisualState()`
- `updateFeatureScroll()`
- `requestFeatureScrollUpdate()`
- feature용 `scroll`/`resize` listener

새 동작:

- hover, focus, click 시 `activateFeature(index)` 실행
- 같은 active feature를 다시 hover/focus/click해도 `currentTime = 0`으로 되돌린 뒤 재생
- inactive video는 `pause()`
- active video만 `.is-active`와 `aria-hidden="false"` 유지
- `play()` promise rejection은 catch
- `prefers-reduced-motion: reduce`에서는 active frame만 전환하고 자동 재생은 하지 않으며, 현재 재생 중인 video도 pause

## 검증

실행한 검증:

```bash
node --check docs/script.js
rg -n "feature-finder-thumbnail|feature-quicklook|feature-edit-save|feature-share|data-feature|currentTime|play\\(|pause\\(" docs/index.html docs/styles.css docs/script.js
rg -n "finder-progress|progress-checkpoints|featureStages|getFeatureScrollState|applyFeatureVisualState|requestFeatureScrollUpdate|featureScrollSpan|progressMap|quicklookScrollSteps|features-copy|finder-image-stage" docs/index.html docs/styles.css docs/script.js
git diff --check -- docs/index.html docs/styles.css docs/script.js
```

결과:

- `docs/script.js` 문법 검사 통과
- 네 feature video와 poster mapping이 `docs/index.html`에 연결되어 있음
- `currentTime`, `play()`, `pause()` 기반 replay/pause 코드 확인
- 기존 progress/checkpoint 및 scroll timeline 핵심 식별자는 `docs/` 구현 파일에서 더 이상 검색되지 않음
- `git diff --check` 통과
- 추가 레이아웃 보정 후 `docs/styles.css`, `mydocs/working/task_m010_182_stage3.md` 대상 `git diff --check` 재실행 통과
- 기능 button highlight sweep 복구 후 `node --check docs/script.js`, `git diff --check`, CSS selector 검색으로 적용 확인
- 데스크톱 heading 상단 여백 보정 후 `git diff --check`, headless Chrome spacing 계측으로 1440px/1920px 데스크톱 상단 padding 감소와 모바일 72px 유지 확인
- 기능 section 설명문 font-size 보정 후 headless Chrome computed style 계측으로 app intro lead와 기능 설명문의 font-size 일치 확인
- 기능 section heading 폭 보정 후 headless Chrome layout 계측으로 1440px 데스크톱에서 설명문 한 줄 표시 확인
- 기능 section 제목/설명 간격 보정 후 headless Chrome spacing 계측으로 데스크톱 title-to-copy gap 감소 확인
- app intro/feature/FAQ 배경 리듬과 app intro 기능 설명 font-size 보정 후 headless Chrome computed style과 desktop/mobile screenshot으로 확인
- app intro 이미지 축소와 기능 설명 확대 후 headless Chrome computed style로 desktop 이미지 높이 감소와 기능 설명 font-size 증가 확인
- FAQ/footer 경계 보정 후 headless Chrome으로 homepage footer margin 제거와 updates page margin 유지 확인
- Footer 흰 배경 전환 후 headless Chrome으로 homepage footer background와 top border 적용 확인
- FAQ 하단 여백과 밝은 회색 배경 보정 후 headless Chrome으로 app intro/FAQ background, FAQ padding-bottom, footer gap 확인
- 기능 section heading 문구 갱신 후 `rg`로 이전 `앱 뷰어까지` 표현 제거와 새 `편집과 공유` 표현 적용 확인
- 기능 section 문구 재갱신 후 headless Chrome 390px viewport로 heading font-size 32px, section top padding 72px 유지 확인
- 기능 section 모바일 설명문 크기 보정 후 headless Chrome 390px viewport로 설명문 font-size 15px, line-height 21.3px 적용 확인
- section 배경 재조정 후 headless Chrome computed style로 app intro/FAQ `rgb(255, 255, 255)`, 기능 section/footer `rgb(247, 247, 249)` 적용 확인
- app intro `알한글` h2와 기능 section heading의 computed font-size/font-weight가 desktop/mobile 모두 일치하는지 headless Chrome으로 확인
- footer overlap 보정 후 1135px/390px viewport에서 footer 설명문과 nav bounding box가 겹치지 않고 중간 폭 nav가 아래 행으로 분리되는지 headless Chrome으로 확인
- Finder 영상 overlay 보정 후 `ffprobe`로 1440x810, 30fps, 104 frame, 3.466667초 유지 확인
- `/private/tmp/task182-finder-lock-motion-restored.jpg`, `/private/tmp/task182-finder-install-motion-15x.jpg` 대표 프레임으로 badge scale/glow/sheen 복구와 1.5배 install overlay 상태 확인

## 남은 범위

Stage 4에서 진행할 항목:

- 모바일/좁은 화면 video carousel
- pagination dots
- horizontal scroll snap
- active dot과 active copy 동기화

Stage 5에서 진행할 항목:

- 로컬 브라우저 실행
- desktop hover replay 확인
- focus/click 접근성 확인
- mobile snap/pagination 확인
- 필요 시 시각 보정

## 다음 단계

작업지시자 승인 후 Stage 4 `모바일 snap carousel과 pagination dots 구현`으로 진행한다.
