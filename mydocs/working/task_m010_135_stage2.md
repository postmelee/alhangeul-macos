# Issue #135 Stage 2 완료 보고서

## 단계명

GitHub Pages 정적 사이트 골격과 자산 배치

## 작업 범위

이번 단계에서는 `docs/` 하위에 GitHub Pages에서 바로 서빙할 수 있는 정적 사이트 골격과 필수 자산을 배치했다. Stage 3에서 진행할 최종 섹션 스타일링과 세부 시각 보정은 아직 수행하지 않았다.

## 변경 파일

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- `docs/assets/logo-256@2x.png`
- `docs/assets/thumbnail2.mov`
- `docs/assets/group-1-4x.png`
- `mydocs/orders/20260503.md`
- `mydocs/working/task_m010_135_stage2.md`

## 자산 배치

복사한 자산:

- `assets/logo-256@2x.png` → `docs/assets/logo-256@2x.png`
- `/Users/melee/Documents/projects/rhwp-mac/thumbnail2.mov` → `docs/assets/thumbnail2.mov`
- `/Users/melee/Documents/projects/rhwp-mac/Group 1_4x.png` → `docs/assets/group-1-4x.png`

파일명 정책:

- GitHub Pages URL에서 안전하게 참조할 수 있도록 `Group 1_4x.png`는 `group-1-4x.png`로 정규화했다.
- `thumbnail2.mov`는 사용자가 지정한 이름을 유지했다.
- 로고는 기존 파일명 `logo-256@2x.png`를 유지했다.

확인된 파일 형식:

```text
docs/assets/logo-256@2x.png: PNG image data, 512 x 512, 16-bit/color RGBA, non-interlaced
docs/assets/thumbnail2.mov:  ISO Media, Apple QuickTime movie, Apple QuickTime (.MOV/QT)
docs/assets/group-1-4x.png:  PNG image data, 6144 x 4132, 8-bit/color RGBA, non-interlaced
```

## 정적 사이트 골격

`docs/index.html`에는 다음 골격을 추가했다.

- 기본 SEO meta
- Open Graph title/description/image
- favicon/apple-touch-icon
- Header: 로고, `Alhangeul`, GitHub 링크
- Hero: 지정 H1, 지정 supporting copy, `Mac 다운로드` 버튼
- Demo media: `thumbnail2.mov` video frame
- Feature section: `group-1-4x.png` 이미지와 기능 문구 초안
- FAQ section: `details/summary` 기반 항목
- Footer: 로고, 설명, GitHub, MIT License
- `noscript` fallback

`docs/styles.css`에는 Stage 1 디자인 토큰을 반영한 기본 변수와 skeleton layout을 추가했다.

- true white background
- black/near-black text
- blue accent
- floating header 기본 스타일
- hero, media frame, feature layout, FAQ, footer 기본 배치
- `focus-visible`
- 모바일 기본 breakpoints
- `prefers-reduced-motion`

`docs/script.js`에는 FAQ가 한 번에 하나만 열리도록 하는 최소 동작을 추가했다. `details/summary` 기본 동작을 사용하므로 JavaScript가 없어도 FAQ 내용은 접근 가능하다.

## Stage 3로 남긴 작업

- 레퍼런스와 Stage 1 콘셉트에 맞춘 첫 viewport 밀도와 media preview 위치 보정
- Header/GitHub/download button icon treatment 정교화
- 영상 frame, Feature image, FAQ section 최종 시각 디테일 구현
- FAQ 문구 확정과 제품 상태 과장 여부 재검토
- 모바일 줄바꿈과 overflow 상세 검증
- 필요 시 `group-1-4x.png` 웹용 축소 사본 생성

## 검증 결과

실행한 명령:

```bash
find docs -maxdepth 3 -type f | sort
file docs/assets/logo-256@2x.png docs/assets/thumbnail2.mov docs/assets/group-1-4x.png
rg -n "thumbnail2|group-1-4x|logo-256|Alhangeul|GitHub" docs
git diff --check -- docs mydocs/working/task_m010_135_stage2.md
```

결과:

- `docs/` 하위 6개 파일이 생성되었다.
- 로고, 영상, Feature 이미지의 파일 형식을 확인했다.
- `docs/index.html`이 모든 필수 자산을 상대 경로로 참조하는 것을 확인했다.
- `git diff --check`는 통과했다.

## 리스크와 후속 조치

- 현재 `group-1-4x.png`는 원본 크기 6144 x 4132를 그대로 사용한다. Stage 3 또는 Stage 4에서 실제 브라우저 로딩과 표시 품질을 보고 축소 사본 필요 여부를 결정한다.
- `thumbnail2.mov`의 autoplay 여부는 브라우저 정책에 영향을 받는다. Stage 4에서 실제 브라우저에서 frame 표시와 control 동작을 확인한다.
- `local/task135`는 `origin/devel-webview` 대비 ahead 3, behind 1 상태로 시작했으며, 이번 Stage 2에서도 임의 merge/rebase는 하지 않았다. 뒤처진 원격 커밋은 Task #134 Stage 6 관련 파일이므로 이번 `docs/` 추가와 직접 충돌하지 않는다.

## 승인 요청 사항

Stage 2 산출물 기준으로 Stage 3 `랜딩페이지 주요 섹션 구현`을 진행할지 승인 요청한다.
