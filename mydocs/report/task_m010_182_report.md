# Issue #182 최종 결과 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| GitHub Issue | [#182 홍보 페이지 기능 섹션을 호버 재생 비디오 쇼케이스로 개편](https://github.com/postmelee/alhangeul-macos/issues/182) |
| Milestone | v0.1 |
| 문서 prefix | `task_m010_182` |
| 작업 브랜치 | `local/task182` |
| Pages 반영 대상 | `main` 브랜치의 `/docs` |
| 완료 단계 | Stage 1, Stage 2, Stage 3 |

GitHub Pages 홍보 페이지의 기능 설명 섹션을 기존 긴 scroll-driven 이미지 timeline에서 feature button 기반 동영상 쇼케이스로 교체했다. 기능별 MP4/poster 자산을 생성하고, hover/focus/click 시 active 영상이 처음부터 재생되도록 `docs/script.js`를 단순화했다. 작업지시자의 시각 검증 피드백에 따라 Finder 영상 overlay, section spacing, heading 문구, 배경색, footer 중간 폭 겹침도 함께 보정했다.

GitHub Pages 설정은 `main` 브랜치의 `/docs`를 배포한다. 따라서 실제 Pages 반영 PR은 현재 `local/task182`를 그대로 `main`에 올리지 않고, `origin/main`에서 `publish/task182`를 만들어 `docs/` 홍보 페이지 변경과 Task #182 문서만 선별 반영하는 방식으로 정리한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `docs/index.html` | 기능 섹션 markup을 기존 progress/checkpoint 이미지 stack에서 4개 feature video와 feature button list 구조로 교체했다. 상단 문구를 현재 기능 범위에 맞춰 `미리보기부터 공유까지, Mac 방식으로`로 갱신했다. |
| `docs/styles.css` | 기능 동영상 layout, active/inactive feature button, highlight underline animation, section 배경 리듬, app intro heading 통일, FAQ/footer 여백과 중간 폭 footer 겹침 보정을 반영했다. |
| `docs/script.js` | scroll timeline 계산을 제거하고 hover/focus/click 기반 active video 전환, replay, inactive pause, reduced-motion 처리를 구현했다. |
| `docs/assets/feature-finder-thumbnail.mp4`, `docs/assets/feature-finder-thumbnail-poster.jpg` | Finder 썸네일 기능을 1440x810, 30fps, 무음 MP4와 poster로 생성했다. |
| `docs/assets/feature-quicklook.mp4`, `docs/assets/feature-quicklook-poster.jpg` | Quick Look 제공 영상을 웹용 1440x810, 30fps, 무음 MP4와 poster로 변환했다. |
| `docs/assets/feature-edit-save.mp4`, `docs/assets/feature-edit-save-poster.jpg` | 편집/저장 제공 영상을 웹용 1440x810, 30fps, 무음 MP4와 poster로 변환했다. |
| `docs/assets/feature-share.mp4`, `docs/assets/feature-share-poster.jpg` | 공유 제공 영상을 웹용 1440x810, 30fps, 무음 MP4와 poster로 변환했다. |
| `mydocs/plans/task_m010_182.md` | 수행 계획서와 범위, 검증 계획을 기록했다. |
| `mydocs/plans/task_m010_182_impl.md` | 구현 단계와 수용 기준을 기록했다. |
| `mydocs/working/task_m010_182_stage1.md` | 기능 섹션 설계와 자산 기준 확정 보고서를 작성했다. |
| `mydocs/working/task_m010_182_stage2.md` | 동영상 생성, 압축, poster 추출, ffprobe 검증 결과를 기록했다. |
| `mydocs/working/task_m010_182_stage3.md` | 데스크톱 hover/focus 쇼케이스 구현과 후속 시각 보정 내용을 기록했다. |
| `mydocs/working/assets/task_m010_182_*` | 레퍼런스/대표 프레임과 Finder 영상 재생성용 HTML composition source를 보존했다. |
| `mydocs/orders/20260509.md` | #182 오늘할일 상태를 완료로 갱신했다. |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 기능 섹션 전환 방식 | scroll position 기반 image timeline | hover/focus/click 기반 active video showcase |
| 기능 media | stacked image layer와 progress checkpoint | 4개 MP4 + 4개 poster |
| feature video 규격 | 없음 | 4개 모두 H.264, 1440x810, 30fps, audio 없음 |
| feature video 총 크기 | 없음 | MP4 합계 5,193,980 bytes |
| poster 총 크기 | 없음 | JPG 합계 465,273 bytes |
| 현재 구현 파일 라인 수 | `docs/index.html`, `docs/styles.css`, `docs/script.js` | 252 + 1276 + 149 lines |
| `origin/devel-webview..HEAD` Task #182 주요 diff | 없음 | docs/문서 기준 16 files, 1382 insertions, 1319 deletions |
| 기존 progress UI | `.finder-progress`, `.progress-checkpoints` 렌더 | 제거 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `docs/script.js` 문법 검사 | OK | `node --check docs/script.js` 통과 |
| whitespace/diff 검사 | OK | `git diff --check -- docs mydocs` 통과 |
| feature video mapping | OK | `rg`로 `feature-*.mp4`, `data-feature-step`, `data-feature-video`, `currentTime`, `play()`, `pause()` 확인 |
| 기존 scroll timeline 제거 | OK | `finder-progress`, `progress-checkpoints`, `featureStages`, `getFeatureScrollState`, `applyFeatureVisualState` 검색 결과 없음 |
| 동영상 규격 | OK | `ffprobe`로 4개 MP4 모두 H.264, 1440x810, 30fps, audio 없음 확인 |
| desktop active 전환 | OK | headless Chrome에서 feature 1 click 후 active button/video index `1` 확인 |
| 같은 feature replay | OK | 같은 feature 재클릭 후 active video `currentTime`이 다시 초기 구간으로 돌아가는 것 확인 |
| Browser console | OK | in-app browser/headless Chrome 검증 중 관련 error/warn 없음 |
| footer 중간 폭 겹침 | OK | 1135px/390px viewport에서 footer 설명문/nav bounding box overlap 없음 |
| GitHub Pages source 확인 | OK | GitHub Pages API 결과 `source.branch=main`, `source.path=/docs` 확인 |

## 잔여 위험과 후속 작업

| 항목 | 내용 |
|------|------|
| PR base | Pages 반영은 `main:/docs`가 맞다. 단, `local/task182`는 `devel-webview` 계열이므로 `main` 대상 PR은 main 기반 `publish/task182`에서 필요한 파일만 선별 반영해야 한다. |
| 모바일 pagination dots | 최초 구현 계획의 Stage 4로 남겨 둔 horizontal scroll snap/pagination dots는 현재 PR 범위에 포함하지 않았다. 현재 좁은 화면은 stacked responsive layout으로 깨짐 없이 동작하며, dots carousel이 여전히 필요하면 후속 이슈로 분리한다. |
| 기존 자산 정리 | 이전 이미지 기반 기능 섹션 자산은 즉시 삭제하지 않았다. 참조 제거는 완료했지만 저장소 용량 정리는 별도 판단이 필요하다. |
| 배포 확인 | PR merge 후 GitHub Pages build 완료와 `https://postmelee.github.io/alhangeul-macos/` 실제 반영 상태를 확인해야 한다. |

## 작업지시자 승인 요청

Task #182의 현재 승인된 홍보 페이지 개편 범위를 기준으로 최종 정리를 완료했다. 다음 단계는 `origin/main` 기반 `publish/task182` 브랜치를 push하고, `main` 대상 PR을 생성하는 것이다. PR 생성 후 작업지시자 리뷰와 merge 승인을 요청한다.
