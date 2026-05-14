# Issue #182 Stage 2 완료 보고서

## 단계명

기능 동영상 자산 생성과 배치

## 작업 범위

이번 단계에서는 홍보 페이지 세 번째 기능 섹션에서 사용할 웹용 동영상 자산을 생성하고 `docs/assets/`에 배치했다. 구현 파일은 변경하지 않았다.

- Finder 썸네일 기능용 동영상 생성
- Quick Look, 편집/저장, 공유 기능 원본 MP4를 웹용 MP4로 변환
- 각 기능별 poster JPG 추출
- Finder 영상 재생성용 HTML composition과 capture script 기록
- 동영상 코덱, 해상도, 프레임레이트, 길이, 오디오 스트림 부재 확인
- 대표 프레임 육안 확인

## 생성한 파일

동영상:

- `docs/assets/feature-finder-thumbnail.mp4`
- `docs/assets/feature-quicklook.mp4`
- `docs/assets/feature-edit-save.mp4`
- `docs/assets/feature-share.mp4`

Poster:

- `docs/assets/feature-finder-thumbnail-poster.jpg`
- `docs/assets/feature-quicklook-poster.jpg`
- `docs/assets/feature-edit-save-poster.jpg`
- `docs/assets/feature-share-poster.jpg`

Finder 영상 생성 소스:

- `mydocs/working/assets/task_m010_182_finder_video/DESIGN.md`
- `mydocs/working/assets/task_m010_182_finder_video/index.html`
- `mydocs/working/assets/task_m010_182_finder_video/capture.mjs`

## 변환 기준

공통 기준:

- video codec: H.264
- audio: 제거
- target resolution: 1440x810
- frame rate: 30fps
- pixel format: `yuv420p`
- web start: `-movflags +faststart`
- browser autoplay 대응: Stage 3에서 `muted`, `playsinline` 속성으로 연결 예정

압축 기준:

- Quick Look, 편집/저장, 공유 원본은 1920x1080/60fps 화면 기록이므로 1440x810/30fps로 축소했다.
- 화면 녹화 텍스트 가독성을 우선해 CRF 26을 적용했다.
- Finder 영상은 현재 웹페이지의 Finder 시각화 중 Finder stage만 별도 HTML composition으로 재생성했다.
- 상단 progress/checkpoint 박스는 최종 영상에서 제외하고, `.hwp 정보 잠김` badge, 중앙 install orb, 하단 `알한글 설치` 라벨은 유지했다.
- Finder 영상 생성에는 `@hyperframes` 지침의 HTML composition source-of-truth 방식을 적용했고, 현재 페이지 색상/타이포 기준은 `DESIGN.md`에 기록했다.
- Finder animation timing은 `docs/script.js`의 Finder 단계 수식(`checkpointProgress`, `progressMap`, `installProgress`, `lockOpacity`, `finderAfterOpacity`)을 composition에 옮겨 사용했다.
- 설치 진행값은 ease-out 곡선으로 변환해 ring, logo reveal, scale, check transition이 초반에 빠르게 진행되고 끝에서 감속되도록 조정했다.
- Finder 영상은 2x device scale로 2880x1620 frame을 캡처한 뒤 Lanczos downscale로 1440x810 출력해 설치 overlay의 선명도를 높였다.
- 시각 검증 의견을 반영해 `.hwp 정보 잠김` badge는 124px 높이/38px 텍스트로 키우고, scale/glow/sheen 진행 애니메이션을 적용했다.
- 중앙 install orb는 285px로, 하단 `알한글 설치` 라벨은 최종 출력 기준 45px로 키웠다.
- Finder 영상은 다른 기능 영상과 동일하게 1440x810, 16:9, 30fps, time base `1/15360`으로 맞췄고, 104 frame으로 캡처해 기존 5.20초 대비 약 1.5배 빠른 3.47초로 줄였다.

## 생성 명령

Finder 썸네일:

```bash
node mydocs/working/assets/task_m010_182_finder_video/capture.mjs /private/tmp/task182-finder-frames
ffmpeg -y -framerate 30 -i /private/tmp/task182-finder-frames/frame_%04d.png -vf scale=1440:810:flags=lanczos -r 30 -fps_mode cfr -an -c:v libx264 -preset slow -crf 24 -pix_fmt yuv420p -video_track_timescale 15360 -movflags +faststart docs/assets/feature-finder-thumbnail.mp4
```

Quick Look:

```bash
ffmpeg -y -i /Users/melee/Desktop/main_images/quicklook.mp4 -vf fps=30,scale=1440:810,setsar=1 -an -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p -movflags +faststart docs/assets/feature-quicklook.mp4
```

편집/저장:

```bash
ffmpeg -y -i /Users/melee/Desktop/main_images/edit_and_save.mp4 -vf fps=30,scale=1440:810,setsar=1 -an -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p -movflags +faststart docs/assets/feature-edit-save.mp4
```

공유:

```bash
ffmpeg -y -i /Users/melee/Desktop/main_images/share.mp4 -vf fps=30,scale=1440:810,setsar=1 -an -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p -movflags +faststart docs/assets/feature-share.mp4
```

Poster:

```bash
ffmpeg -y -ss 0.2 -i docs/assets/feature-finder-thumbnail.mp4 -frames:v 1 -q:v 3 docs/assets/feature-finder-thumbnail-poster.jpg
ffmpeg -y -ss 2.0 -i docs/assets/feature-quicklook.mp4 -frames:v 1 -q:v 3 docs/assets/feature-quicklook-poster.jpg
ffmpeg -y -ss 2.0 -i docs/assets/feature-edit-save.mp4 -frames:v 1 -q:v 3 docs/assets/feature-edit-save-poster.jpg
ffmpeg -y -ss 2.0 -i docs/assets/feature-share.mp4 -frames:v 1 -q:v 3 docs/assets/feature-share-poster.jpg
```

## 결과 메타데이터

| 기능 | 파일 | 코덱 | 해상도 | FPS | 길이 | 크기 | 오디오 |
|------|------|------|--------|-----|------|------|--------|
| Finder 썸네일 | `feature-finder-thumbnail.mp4` | H.264 | 1440x810 | 30 | 3.47초 | 231,027 bytes | 없음 |
| Quick Look | `feature-quicklook.mp4` | H.264 | 1440x810 | 30 | 12.27초 | 1,983,140 bytes | 없음 |
| 편집/저장 | `feature-edit-save.mp4` | H.264 | 1440x810 | 30 | 7.10초 | 1,160,527 bytes | 없음 |
| 공유 | `feature-share.mp4` | H.264 | 1440x810 | 30 | 17.50초 | 1,819,286 bytes | 없음 |

Poster 크기:

| 파일 | 크기 |
|------|------|
| `feature-finder-thumbnail-poster.jpg` | 58KB |
| `feature-quicklook-poster.jpg` | 154KB |
| `feature-edit-save-poster.jpg` | 131KB |
| `feature-share-poster.jpg` | 111KB |

## 대표 프레임 확인

`view_image`로 poster를 확인했다.

- Finder 썸네일: progress/checkpoint 박스 없이 16:9 Finder 화면만 보이며, `.hwp 정보 잠김` badge, 중앙 install orb, 하단 `알한글 설치` 라벨, Finder 썸네일 전환이 함께 보인다.
- Quick Look: Quick Look 미리보기 창과 Finder 목록이 함께 보여 기능 맥락이 명확하다.
- 편집/저장: 알한글 앱 뷰어와 문서 본문이 크게 보이며 텍스트 가독성이 충분하다.
- 공유: macOS print/PDF 흐름이 보이고, 공유 기능 맥락이 명확하다.

## 구현 단계 연결 사항

Stage 3에서 사용할 media mapping은 다음과 같다.

| key | video | poster |
|-----|-------|--------|
| `finder` | `assets/feature-finder-thumbnail.mp4` | `assets/feature-finder-thumbnail-poster.jpg` |
| `quicklook` | `assets/feature-quicklook.mp4` | `assets/feature-quicklook-poster.jpg` |
| `editor` | `assets/feature-edit-save.mp4` | `assets/feature-edit-save-poster.jpg` |
| `share` | `assets/feature-share.mp4` | `assets/feature-share-poster.jpg` |

Stage 3 구현 시 주의할 점:

- 같은 feature를 다시 hover/focus/click하면 `currentTime = 0` 후 재생해야 한다.
- `play()` promise rejection은 잡아야 한다.
- inactive video는 pause해야 한다.
- `prefers-reduced-motion: reduce`에서는 자동 replay를 억제하고 poster 또는 첫 프레임을 유지한다.
- Stage 2에서는 기존 이미지 자산을 삭제하지 않았다. 최종 검증 후 더 이상 참조되지 않는 자산은 별도 정리 판단 대상으로 둔다.

## 검증

실행한 검증:

```bash
ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=codec_name,width,height,avg_frame_rate,r_frame_rate,time_base,duration,nb_read_frames -show_entries format=filename,duration,size -of json docs/assets/feature-finder-thumbnail.mp4
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of json docs/assets/feature-quicklook.mp4
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of json docs/assets/feature-edit-save.mp4
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,avg_frame_rate,duration -show_entries format=filename,duration,size -of json docs/assets/feature-share.mp4
find docs/assets -maxdepth 1 -name 'feature-*' -type f -exec ls -lh {} +
node mydocs/working/assets/task_m010_182_finder_video/capture.mjs /private/tmp/task182-finder-frames
ffmpeg -y -ss 1.45 -i docs/assets/feature-finder-thumbnail.mp4 -frames:v 1 -q:v 3 /private/tmp/task182-finder-mid.jpg
ffmpeg -y -ss 3.3 -i docs/assets/feature-finder-thumbnail.mp4 -frames:v 1 -q:v 3 /private/tmp/task182-finder-end.jpg
```

결과:

- 네 동영상 모두 H.264 video stream 1개만 가진다.
- 네 동영상 모두 1440x810, 16:9, 30fps, time base `1/15360`이다.
- 오디오 스트림은 없다.
- poster 4개가 생성되어 있다.
- Finder 캡처 원본 frame은 2880x1620이며, 최종 출력은 1440x810으로 downscale했다.
- Finder 영상은 104 frame, 3.466667초로 생성되어 30fps CFR 조건을 만족한다.
- Finder 영상 시작 frame과 진행 frame에서 2배 확대된 `.hwp 정보 잠김` badge와 scale/glow/sheen 애니메이션 상태를 확인했다.
- Finder 영상 중간 frame에서 ease-out 적용 후 완료 상태의 확대된 중앙 install orb와 `알한글 설치` 라벨을 확인했다.
- Finder 영상 종료 frame에서 Finder 썸네일 상태를 확인했다.

남은 검증:

- 보고서 작성 후 `git diff --check`를 실행한다.
- Stage 3/4 구현 후 실제 브라우저에서 hover replay, mobile snap, pagination dot 동기화를 검증한다.

## 다음 단계

작업지시자 승인 후 Stage 3 `데스크톱 hover/focus 쇼케이스 구현`으로 진행한다.
