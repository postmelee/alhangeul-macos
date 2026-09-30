# Task #573 Stage 2 — 홈페이지 Windows / Linux 안내 링크

## 결과

홈·소식·문의·업데이트 인덱스와 버전별 업데이트 15개를 포함한 19개 페이지의 기존 정적 헤더에 `알한글 for Windows / Linux`를 추가했다. 모두 `https://postmelee.github.io/alhangeul-tauri/`로 이동한다. 공유 CSS를 유지하며 820px 이하에서는 추가 링크를 별도 줄에 표시하고 헤더 높이가 내용에 맞게 늘어난다. 모든 페이지의 stylesheet query를 갱신하여 기존 CSS cache와 새 헤더가 섞이지 않도록 했다.

## 검증

- HTML parser로 19개 페이지의 header 영역에서 새 링크가 정확히 하나 존재하고 표시 문구·절대 URL이 일치함을 확인했다.
- 브라우저에서 홈·소식·문의·업데이트 인덱스·v0.2.2를 320/360/375/520/521/700/701/768/820/821/1024/1440px로 검사했다. 나머지 버전별 페이지는 320/1440px로 검사했다. 총 19개 페이지·88개 조합에서 보이는 header anchor의 화면·헤더 경계 포함, text overflow, anchor 간 겹침과 새 링크 표시·URL을 확인했다. 실패 0개. [결과 JSON](assets/task_m020_573/header-layout.json).
- 링크를 실제 클릭해 Windows / Linux 홈페이지의 URL·제목·본문을 확인했다. [이동 기록](assets/task_m020_573/link-navigation.json).
- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-news-pages.py`: 14개 통과. `node --test scripts/ci/test-news-ui.cjs`: 9개 통과.
- `actionlint .github/workflows/pr-ci.yml .github/workflows/rhwp-upstream-sync-pr.yml`, `git diff --check`: 통과.
- README 배지도 브라우저에서 Shields 이미지의 로드·실제 표시를 확인하고 클릭하여 고정 `v0.8.6` 릴리스 페이지로 이동했다.

검증 화면: [모바일 320px](assets/task_m020_573/home-320.png), [데스크톱 1024px](assets/task_m020_573/home-1024.png), [README 배지](assets/task_m020_573/readme-badges.png). 로컬 미리보기만 수행했으며 공개 홈페이지는 배포하지 않았다. 미리보기 전용 HTML은 삭제했다.

2026-09-30 사용자 지시 범위에 따라 Stage 3 최종 검증·보고·PR 생성을 진행한다.

후속 모바일 배치는 [Stage 3.2](task_m020_573_stage3.md#stage-32--모바일-플랫폼-링크-위치-보정)에서 변경했다. 위 Stage 2의 별도 줄 헤더와 화면 기록은 당시 결과이며, 최종 모바일 화면은 한 줄 헤더와 다운로드 영역·하단 보조 링크를 사용한다.
