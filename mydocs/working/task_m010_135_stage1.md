# Issue #135 Stage 1 완료 보고서

## 단계명

랜딩페이지 디자인 콘셉트 확정

## 작업 범위

이번 단계에서는 구현 파일을 만들지 않고, GitHub Pages 랜딩페이지의 정보 구조와 디자인 기준만 확정했다.

- 레퍼런스 `https://openscreen.vercel.app/` 구조 분석
- README 기반 제품 메시지 추출
- 랜딩페이지 섹션 순서 확정
- 첫 화면 허용 문구와 CTA 정책 확정
- 디자인 콘셉트 이미지 생성
- 구현 토큰과 섹션별 설계 기준 정리

## 레퍼런스 분석

Open Screen 레퍼런스에서 가져올 구조:

- 상단 중앙에 얇은 floating header를 둔다.
- Header 왼쪽은 로고와 제품명, 오른쪽은 GitHub 링크로 구성한다.
- Hero는 중앙 정렬 대형 headline과 짧은 supporting copy, 다운로드 CTA를 둔다.
- 첫 viewport 하단에 바로 다음 media preview가 보이게 하여 제품 시연으로 자연스럽게 이어지게 한다.
- Media preview 다음에 Feature를 시각 자료 중심으로 설명한다.
- FAQ는 단순한 accordion 형태로 배치한다.
- Footer는 로고, 짧은 설명, GitHub, 라이선스 정도만 남긴다.

알한글에 맞춰 바꾸는 점:

- 레퍼런스의 녹색/어두운 배경은 사용하지 않는다.
- 전체 배경은 true white를 유지하고, 텍스트는 black/near-black 중심으로 둔다.
- 하이라이트는 앱 로고에서 가져온 blue 계열만 사용한다.
- hero badge, fake metric, testimonial, pricing, app store badge는 넣지 않는다.
- 기능 설명은 README의 구현 상태와 로드맵 범위를 넘지 않는다.

## 확정 정보 구조

1. Header
   - 로고
   - `Alhangeul`
   - GitHub 링크
2. Hero
   - `Mac에서 한글 파일은 더 이상 이방인이 아닙니다.`
   - `스페이스바로 미리보고, Finder에서 썸네일로 찾고, HWP파일을 보고 편집하세요.`
   - `Mac 다운로드`
3. Demo media
   - `thumbnail2.mov`를 video frame으로 사용
   - 영상이 없거나 재생되지 않는 경우 fallback 텍스트 제공
4. Features
   - `Group 1_4x.png` 기반 이미지 주도 섹션
   - Quick Look preview
   - Finder thumbnail
   - WKWebView viewer
   - 로컬 처리 / 오픈소스
5. FAQ
   - 무료 여부
   - 지원 파일 형식
   - 설치/다운로드 상태
   - 개인정보와 로컬 처리
   - 편집 기능 범위
   - macOS 손상 경고 대응
   - 업데이트 계획
6. Footer
   - 로고와 제품명
   - 짧은 설명
   - GitHub
   - MIT License

## 카피 인벤토리

Above-the-fold 허용 문구:

- Header 제품명: `Alhangeul`
- Header 링크: `GitHub`
- H1: `Mac에서 한글 파일은 더 이상 이방인이 아닙니다.`
- Supporting copy: `스페이스바로 미리보고, Finder에서 썸네일로 찾고, HWP파일을 보고 편집하세요.`
- Primary CTA: `Mac 다운로드`

Feature 후보 문구:

- `스페이스바 미리보기`
- `Quick Look 확장으로 HWP/HWPX 문서를 바로 확인합니다.`
- `Finder 썸네일`
- `Finder에서 문서 첫 페이지를 썸네일로 확인합니다.`
- `HWP/HWPX 뷰어`
- `WKWebView 기반 viewer로 문서를 열고 탐색합니다.`
- `로컬 처리`
- `파일을 업로드하지 않고 Mac 안에서 처리합니다.`

FAQ 후보 문구:

- `무료로 사용할 수 있나요?`
- `어떤 파일 형식을 지원하나요?`
- `Mac 다운로드는 어디로 연결되나요?`
- `개인정보와 문서는 안전한가요?`
- `편집 기능은 어디까지 지원되나요?`
- `macOS에서 앱이 손상되었다고 나오면 어떻게 하나요?`
- `업데이트는 계속 제공되나요?`

## 디자인 콘셉트

- 생성 방식: built-in ImageGen
- 저장 경로: `mydocs/working/assets/task_m010_135_concept.png`
- 원본 생성 경로: `/Users/melee/.codex/generated_images/019deadb-c96f-7f13-acff-7faab6a621f0/ig_0e320a3359f49eec0169f6850bacd88191ab59891b1c5fb821.png`
- 이미지 크기: 1536 x 1024

콘셉트는 구현 기준의 시각 방향만 제공한다. 최종 페이지의 텍스트, 버튼, FAQ, 링크는 모두 HTML/CSS/JS 코드-native로 구현한다. 콘셉트 이미지 안의 미세한 문구 오류나 비현실적인 가상 앱 화면은 그대로 옮기지 않는다.

## 디자인 토큰

색상:

- Background: `#ffffff`
- Text primary: `#050505`
- Text secondary: `#4b5563`
- Text muted: `#7a7f87`
- Border: `#d9dde3`
- Border subtle: `#eef0f3`
- Surface: `#ffffff`
- Surface raised: `rgba(255, 255, 255, 0.86)`
- Accent blue: `#5ea8ff`
- Accent blue strong: `#2f8cff`
- Accent blue dark text: `#0f5fb8`
- Black media frame: `#050505`

Typography:

- Font stack: `Inter`, `Pretendard`, `Apple SD Gothic Neo`, `SF Pro Display`, `system-ui`, `sans-serif`
- Hero: 72-96px desktop, 44-52px tablet, 36-42px mobile
- Section heading: 36-52px desktop, 30-36px mobile
- Body: 17-19px desktop, 16px mobile
- Small UI text: 13-15px
- Font weight: 800-900 for hero, 700 for headings, 500-600 for UI, 400-500 for body
- Letter spacing: 0

Layout:

- Page max width: 1120-1180px
- Header width: min(920px, calc(100% - 32px))
- Header height: 56px desktop, 52px mobile
- Hero top padding: 96-120px desktop, 84px mobile
- Section vertical spacing: 96-128px desktop, 64-80px mobile
- Media aspect ratio: 16 / 9
- Radius: 18px for media frame, 14px for buttons, 12px for FAQ rows, 999px for header/button pills only when appropriate

Interaction:

- Header와 CTA는 hover/focus-visible 상태를 명확히 둔다.
- FAQ는 `details/summary` 기본 접근성을 우선하고, 필요 시 한 번에 하나만 열리는 JS를 추가한다.
- 영상은 `autoplay muted loop playsinline controls`를 기본으로 검토한다.
- `prefers-reduced-motion`에서는 부드러운 hover/scroll animation을 줄인다.

## 다운로드 버튼 정책

현재 실제 release artifact URL이 확정되어 있지 않으므로 Stage 3 구현에서 `Mac 다운로드`는 다음 URL로 연결한다.

```text
https://github.com/postmelee/alhangeul-macos/releases/latest
```

GitHub Pages 설정 변경, release 생성, DMG/zip 산출물 생성은 이번 타스크 범위가 아니다.

## 검증 결과

실행한 명령:

```bash
git status --short
rg -n "Mac에서 한글 파일은 더 이상 이방인이 아닙니다|스페이스바로 미리보고|Finder|WKWebView|Quick Look" README.md mydocs/plans/task_m010_135.md
file mydocs/working/assets/task_m010_135_concept.png
git diff --check -- mydocs/working/task_m010_135_stage1.md
```

결과:

- README와 수행계획서에서 필수 hero 문구와 제품 기능 기준을 확인했다.
- 디자인 콘셉트 이미지를 생성해 `mydocs/working/assets/task_m010_135_concept.png`에 저장했다.
- Stage 1 보고서 diff check는 통과했다.

## 리스크와 후속 조치

- `thumbnail2.mov`와 `Group 1_4x.png`는 아직 분리 worktree에 없으므로 Stage 2에서 메인 worktree의 사용자 제공 파일을 복사해야 한다.
- `Group 1_4x.png`는 원본 크기가 크므로 Stage 2에서 웹용 축소 사본 생성 여부를 판단한다.
- 콘셉트 이미지는 최종 구현의 레이아웃/톤 기준으로만 사용하고, 제품 기능 설명은 README 기준으로 다시 작성한다.
- `local/task135`는 현재 `origin/devel-webview` 대비 ahead 2, behind 1 상태다. 구현 단계에서 충돌 여부를 확인하되, 임의 rebase/merge는 진행하지 않는다.

## 승인 요청 사항

Stage 1 산출물 기준으로 Stage 2 `GitHub Pages 정적 사이트 골격과 자산 배치`를 진행할지 승인 요청한다. 승인 전에는 `docs/` 구현 파일과 랜딩페이지 자산을 생성하지 않는다.
