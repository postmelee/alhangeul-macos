# Issue #182 Stage 1 완료 보고서

## 단계명

기능 섹션 설계와 자산 처리 기준 확정

## 작업 범위

이번 단계에서는 구현 파일을 변경하지 않고, 현재 GitHub Pages 홍보 페이지의 세 번째 기능 섹션 구조와 제공 영상 자산, 레퍼런스 화면 기록을 분석해 다음 단계 구현 기준을 확정했다.

- 현재 `features-section` 구조 분석
- 레퍼런스 화면 기록에서 가져올 상호작용 원칙 정리
- 데스크톱/모바일 레이아웃 결정
- hover/focus/click, mobile snap, pagination 동작 규칙 확정
- 기능별 copy inventory 확정
- 동영상 자산 파일명, 압축 기준, poster 기준 확정
- Frontend App Builder 적용 방식과 Image Gen 생략 사유 기록

## 확인한 파일과 자산

현재 섹션:

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`

설계 보조 프레임:

- `mydocs/working/assets/task_m010_182_stage1_reference_nexters.jpg`
- `mydocs/working/assets/task_m010_182_stage1_quicklook_frame.jpg`
- `mydocs/working/assets/task_m010_182_stage1_edit_save_frame.jpg`
- `mydocs/working/assets/task_m010_182_stage1_share_frame.jpg`

제공 동영상 메타:

| 기능 | 원본 | 해상도 | 길이 | 크기 | 판단 |
|------|------|--------|------|------|------|
| Quick Look | `/Users/melee/Desktop/main_images/quicklook.mp4` | 1920x1080 | 12.25초 | 34.8MB | 압축 필요 |
| 공유 | `/Users/melee/Desktop/main_images/share.mp4` | 1920x1080 | 17.5초 | 31.3MB | 압축 필요 |
| 편집/저장 | `/Users/melee/Desktop/main_images/edit_and_save.mp4` | 1920x1080 | 7.08초 | 23.9MB | 압축 필요 |
| Finder 썸네일 | 기존 scroll animation에서 생성 | 16:9 근접 frame 목표 | 3~5초 목표 | Stage 2 산출 | 새로 생성 필요 |

## 현재 구조 분석

현재 `features-section`은 긴 sticky scroll timeline이다.

- `docs/index.html`에는 4개 `.feature-step`과 하나의 `.feature-visual`이 있다.
- `.feature-visual` 안에는 `.finder-progress` progress bar/checkpoint 박스와 `.finder-image-stage`가 있다.
- `.finder-image-stage` 안에 Finder, Quick Look, viewer, share 이미지 레이어가 모두 쌓여 있다.
- `docs/styles.css`는 `--feature-progress`, `--quicklook-*`, `--viewer-*`, `--share-*` 같은 CSS 변수를 대량으로 사용한다.
- `docs/script.js`는 `featureStages`, `getFeatureScrollState()`, `applyFeatureVisualState()`로 스크롤 위치를 active feature와 local checkpoint로 변환한다.
- desktop section 높이는 `1720vh`, 좁은 화면 override는 `940vh`라 사용자가 기능을 비교하려면 긴 스크롤을 지나야 한다.

이번 개편에서는 이 scroll-driven 구조를 제거하고 feature 선택 기반 구조로 바꾼다.

## 레퍼런스에서 가져올 점

레퍼런스 화면 기록은 왼쪽 큰 미디어와 오른쪽 항목 리스트를 보여준다. active 항목은 진하고, inactive 항목은 낮은 opacity로 물러난다. 항목에 hover하면 미디어가 바뀌는 구조가 핵심이다.

알한글 페이지에 그대로 복제하지 않을 점도 정리했다.

- 레퍼런스의 큰 영문 headline/eyebrow는 가져오지 않는다. 현재 섹션 heading을 유지한다.
- 레퍼런스의 사진형 media 대신 앱 기능 동영상을 사용한다.
- 레퍼런스보다 기능 영상의 실제 화면 가독성이 중요하므로, 동영상 영역을 더 크게 잡는다.
- 기존 Apple-style white/parchment/blue accent 톤을 유지한다.

## Frontend App Builder 적용 판단

이 작업은 frontend redesign 성격이 있으므로 `build-web-apps:frontend-app-builder` 기준을 참조했다. 다만 이번 Stage 1에서는 Image Gen을 사용하지 않는다.

생략 사유:

- 새 페이지나 새 브랜드 비주얼이 아니라 기존 `docs/` 디자인 시스템 안의 한 섹션 개편이다.
- 작업지시자가 레퍼런스 영상과 실제 기능 영상을 제공했다.
- 유지할 copy와 제거할 UI(progress bar/checkpoint)가 명확하다.
- 핵심 결정은 시각 분위기 창작보다 media placement, hover replay, mobile snap 동작에 있다.

따라서 Stage 1 산출물은 별도 생성 콘셉트 이미지가 아니라 구현 가능한 섹션 명세로 둔다. Stage 5 브라우저 검증에서는 실제 구현 screenshot과 레퍼런스/대표 프레임을 `view_image`로 비교한다.

## 확정 디자인 방향

### Desktop / 넓은 화면

기본 구조:

```text
section heading
┌──────────────────────────────┬──────────────────────┐
│ large video frame             │ feature buttons/list │
│ 16:9 media, active video only │ active title/body    │
└──────────────────────────────┴──────────────────────┘
```

결정:

- 동영상은 왼쪽에 둔다.
- 이유: 제공 영상이 16:9 화면 기록 중심이라, 좌측 큰 영역에서 먼저 실제 기능을 보여주는 쪽이 가시성이 높다.
- 기능 리스트는 오른쪽에 둔다.
- 리스트는 카드 grid가 아니라 세로 list/button 구조로 만든다.
- active 항목은 white surface, 1px hairline, blue accent line 또는 blue title로 구분한다.
- inactive 항목은 opacity를 낮추되 본문이 완전히 안 보이지 않게 한다.
- 카드 radius는 8px 기준으로 맞춰 과한 rounded card 느낌을 줄인다.
- 기존 `feature-highlight` sweep은 유지하지 않는다. hover video 전환의 주목도가 충분하고, sweep animation은 기존 scroll timeline 느낌을 남긴다.
- 섹션 자체는 긴 sticky scroll이 아니라 일반 full-width band로 바꾼다.
- 예상 desktop section padding은 `clamp(88px, 12vh, 132px) 20px`.
- media frame은 `aspect-ratio: 16 / 9`, background `#151820`, radius 18px 이하, 기존 product shadow를 사용한다.

### Mobile / 좁은 화면

기본 구조:

```text
section heading
horizontal video carousel
pagination dots
active feature title/body
```

결정:

- hover list를 억지로 축소하지 않는다.
- 동영상 carousel에 `scroll-snap-type: x mandatory`를 적용한다.
- 각 slide는 `scroll-snap-align: center`를 사용한다.
- 동영상 아래에 pagination dots를 둔다.
- dots 아래에는 현재 active feature의 제목/본문을 한 벌만 보여준다.
- dot click/tap은 해당 slide로 `scrollIntoView` 또는 `scrollTo` 이동한다.
- carousel scroll로 active index가 바뀌면 dots와 제목/본문도 동기화한다.
- 좁은 화면에서는 video frame width를 `min(100%, 620px)` 안에서 유지하고, 320px 폭에서도 텍스트와 dots가 겹치지 않게 한다.

## Feature copy inventory

섹션 heading은 유지한다.

```text
미리보기부터 뷰어까지, Mac 방식으로
Finder와 Quick Look, 앱 뷰어까지 HWP/HWPX 문서를 Mac 안에서 자연스럽게 열고 공유합니다.
```

기능 항목:

| index | key | 제목 | 본문 | 영상 |
|------:|-----|------|------|------|
| 0 | `finder` | `Finder에서 썸네일로 찾기` | `꽁꽁 숨겨진 .hwp 파일이 알한글 설치 후 첫 페이지 썸네일과 함께 드러납니다.` | `feature-finder-thumbnail.mp4` |
| 1 | `quicklook` | `스페이스바로 즉시 미리보기` | `Quick Look 확장으로 HWP/HWPX 문서를 열기 전에 빠르게 확인합니다.` | `feature-quicklook.mp4` |
| 2 | `editor` | `앱에서 한글 파일 수정하기.` | `HWP/HWPX 파일을 열고, 필요한 내용을 수정한 뒤 저장합니다.` | `feature-edit-save.mp4` |
| 3 | `share` | `문서를 Mac 방식으로 공유하기` | `PDF로 내보내고, Mac 방식으로 공유하고, 바로 인쇄합니다.` | `feature-share.mp4` |

copy는 현재 문구를 유지한다. 문장부호는 작업지시자가 별도 변경 요청하지 않았으므로 `한글 파일 수정하기.`의 마침표도 유지한다.

## Interaction spec

### Desktop

- Feature trigger는 `<button type="button">`로 구현한다.
- trigger에는 `data-feature-index`를 둔다.
- active trigger는 `aria-pressed="true"` 또는 동등한 상태를 가진다.
- trigger hover, focus, click 모두 `activateFeature(index, { restart: true })`를 호출한다.
- 같은 active trigger에 다시 hover/focus/click해도 해당 video를 처음부터 재생한다.
- inactive video는 pause한다.
- active video는 `currentTime = 0`으로 되감은 뒤 `play()`를 시도한다.
- `play()` promise rejection은 console error로 노출하지 않고 catch한다.
- 첫 진입 기본 active는 index 0이다.

### Mobile

- horizontal carousel의 active slide 판정은 `IntersectionObserver`를 우선한다.
- fallback은 throttled scroll handler로 가장 가까운 slide를 계산한다.
- active slide가 바뀌면 `activateFeature(index, { restart: true, scroll: false })`를 호출한다.
- dot click은 해당 slide로 이동하고, 이동 후 같은 feature replay가 가능해야 한다.
- mobile에서도 inactive video는 pause한다.

### Reduced motion

- `prefers-reduced-motion: reduce`일 때 hover/focus/click으로 active frame은 바꾸되 자동 replay는 하지 않는다.
- 이 경우 video poster 또는 첫 프레임이 보이는 것을 목표로 한다.
- 사용자가 click한 경우에만 재생을 허용할지는 Stage 3 구현 중 브라우저 동작을 보고 결정하되, 보고서에 명시한다.

## Asset processing spec

Stage 2에서 만들 파일명:

- `docs/assets/feature-finder-thumbnail.mp4`
- `docs/assets/feature-quicklook.mp4`
- `docs/assets/feature-edit-save.mp4`
- `docs/assets/feature-share.mp4`

poster가 필요하면:

- `docs/assets/feature-finder-thumbnail-poster.jpg`
- `docs/assets/feature-quicklook-poster.jpg`
- `docs/assets/feature-edit-save-poster.jpg`
- `docs/assets/feature-share-poster.jpg`

압축 기준:

- video codec: H.264
- audio: 제거
- frame rate: 30fps
- target display resolution: 1440x810
- 16:9 원본: 1440x810로 scale
- Finder 영상: 기존 scroll animation을 캡처하거나 이미지 레이어를 재구성해 1440x810 frame에 맞춘다.
- pixel format: `yuv420p`
- web start: `-movflags +faststart`
- 1차 CRF: 25~27 범위에서 시작
- 목표: 기능별 텍스트가 식별 가능하고, 총 video asset 크기가 원본 합계보다 크게 줄어드는 것

Finder 영상 생성 기준:

- 현재 scroll 기반 Finder 첫 기능 상태를 동영상으로 만든다.
- 원본 레퍼런스 녹화는 Nexters 사이트 참고용이므로 Finder 기능 영상으로 쓰지 않는다.
- Stage 2 우선안은 기존 `finder-before.png`, `finder-after.png`, logo asset, `.hwp 정보 잠김`/install/check 연출을 이용해 3~5초짜리 mp4를 생성하는 방식이다.
- 브라우저 캡처가 더 정확하면 로컬 페이지에서 첫 Feature 구간만 캡처해 mp4로 만든다.
- 어떤 방식을 택하든 결과 영상은 `feature-finder-thumbnail.mp4` 하나로 정리한다.

## 구현 제거 대상

Stage 3에서 제거 또는 대체할 구조:

- `docs/index.html`의 `.finder-progress`
- `progress-track`, `progress-fill`, `progress-checkpoints`, `checkpoint-*`, `install-marker` 렌더 구조
- 이미지 레이어 기반 `.finder-image-stage` 내부의 feature-specific stacked images
- `docs/script.js`의 `featureStages`, `checkpointsPerFeature`, `progressMap`, `quicklookScrollSteps`
- `getFeatureScrollState()`, `getFeaturePhase()`, `setStageLabels()`, `applyFeatureVisualState()`, `updateFeatureScroll()`, `requestFeatureScrollUpdate()`
- `window.addEventListener("scroll", requestFeatureScrollUpdate, ...)`
- `docs/styles.css`의 scroll-driven feature CSS 변수와 관련 selector

유지할 구조:

- FAQ accordion 동작
- reveal animation setup
- section heading text
- 전체 Apple-style color/token system
- header/hero/app-intro/FAQ/footer

## 접근성 기준

- trigger는 keyboard focus 가능해야 한다.
- active trigger는 visual state와 ARIA state가 함께 바뀌어야 한다.
- `:focus-visible`은 blue outline 또는 inset ring으로 명확히 보여야 한다.
- video에는 `muted`, `playsinline`, `preload="metadata"`를 둔다.
- video 자체에 필요한 `aria-label`을 둔다.
- decorative poster나 내부 frame은 screen reader에 중복 노출하지 않는다.
- 모바일 dots는 각 기능명 기반 `aria-label`을 가진 button으로 구현한다.

## 남은 의사결정

Stage 1 기준으로 작업지시자에게 추가 확인이 필요한 결정은 없다.

내 결정:

- desktop media 위치는 왼쪽으로 확정한다.
- mobile은 video carousel + dots + active text panel로 확정한다.
- 원본 MP4는 그대로 커밋하지 않고 웹용 무음 압축본을 만든다.
- Finder 영상은 Nexters 레퍼런스 녹화를 쓰지 않고, 현재 Finder scroll animation을 재구성 또는 캡처해 만든다.
- Image Gen은 이번 단계에서 생략한다.

## 검증 결과

실행한 명령:

```bash
git status --short --branch
sed -n '119,250p' docs/index.html
sed -n '400,1225p' docs/styles.css
sed -n '1,460p' docs/script.js
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of default=noprint_wrappers=1 /Users/melee/Desktop/main_images/quicklook.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of default=noprint_wrappers=1 /Users/melee/Desktop/main_images/share.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of default=noprint_wrappers=1 /Users/melee/Desktop/main_images/edit_and_save.mp4
ffmpeg -y -ss 1.2 -i "{reference mov}" -frames:v 1 -vf scale=1440:-1 -q:v 3 mydocs/working/assets/task_m010_182_stage1_reference_nexters.jpg
ffmpeg -y -ss 2.0 -i /Users/melee/Desktop/main_images/quicklook.mp4 -frames:v 1 -vf scale=1440:-1 -q:v 3 mydocs/working/assets/task_m010_182_stage1_quicklook_frame.jpg
ffmpeg -y -ss 2.0 -i /Users/melee/Desktop/main_images/edit_and_save.mp4 -frames:v 1 -vf scale=1440:-1 -q:v 3 mydocs/working/assets/task_m010_182_stage1_edit_save_frame.jpg
ffmpeg -y -ss 2.0 -i /Users/melee/Desktop/main_images/share.mp4 -frames:v 1 -vf scale=1440:-1 -q:v 3 mydocs/working/assets/task_m010_182_stage1_share_frame.jpg
ls -lh mydocs/working/assets/task_m010_182_stage1_*.jpg
```

대표 프레임은 `view_image`로 확인했다.

## 산출물

- `mydocs/working/task_m010_182_stage1.md`
- `mydocs/working/assets/task_m010_182_stage1_reference_nexters.jpg`
- `mydocs/working/assets/task_m010_182_stage1_quicklook_frame.jpg`
- `mydocs/working/assets/task_m010_182_stage1_edit_save_frame.jpg`
- `mydocs/working/assets/task_m010_182_stage1_share_frame.jpg`

## 다음 단계 승인 요청

Stage 2 `기능 동영상 자산 생성과 배치`로 진행할지 승인 요청한다. 승인 전에는 `docs/` 구현 파일과 홍보 페이지 동영상 자산을 변경하지 않는다.
