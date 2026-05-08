# Issue #178 최종 결과 보고서

## 작업 요약

- 이슈: [#178](https://github.com/postmelee/alhangeul-macos/issues/178)
- 마일스톤: M010 / v0.1
- 통합 대상: `devel-webview`
- 작업 브랜치: `local/task178`
- 단계 수: Stage 1 구현, Stage 2 브라우저 검증/추가 피드백, Stage 3 최종 보고와 PR 준비

GitHub Pages 홍보 페이지의 두 번째 섹션을 재정렬하고, 스크린샷을 더 크게 보이게 하며, 리드 문구와 footer 설명의 위계를 정리했다. 작업 중 철학 설명은 섹션 2에서 제거하고 footer 설명으로 이동했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `docs/index.html` | 두 번째 섹션 철학 설명 블록 제거, footer 설명을 최신 제품 철학 문구로 교체 |
| `docs/styles.css` | 두 번째 섹션 높이/간격/이미지 크기/radius 조정, footer 높이 축소와 3열 중앙 정렬 적용 |
| `mydocs/plans/task_m010_178.md` | 수행 계획서 작성 |
| `mydocs/plans/task_m010_178_impl.md` | 구현 계획서 작성 |
| `mydocs/working/task_m010_178_stage1.md` | Stage 1 구현 완료 보고 |
| `mydocs/working/task_m010_178_stage2.md` | Browser/IAB 검증과 추가 피드백 반영 기록 |
| `mydocs/orders/20260508.md` | #178 완료 처리 |
| `mydocs/report/task_m010_178_report.md` | 최종 결과 보고 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 섹션 2 높이 모델 | 콘텐츠 중심 정렬 | 첫 hero와 같은 `calc(100svh - var(--header-height))` 모델 |
| 섹션 2 내부 gap | `clamp(12px, 1.4vh, 18px)` | `clamp(30px, 3.2vh, 38px)` |
| 리드 문구 색상 | 본문색 | `var(--muted)` |
| 스크린샷 최대 높이 | `min(58svh, 660px)` | `min(61svh, 700px)` |
| 스크린샷 radius | 데스크톱 18px / 모바일 14px | 데스크톱 10px / 모바일 6px |
| footer 상단 여백 | `80px` | `56px` |
| footer padding | `48px ...` | `30px ...` |
| footer 설명 폭 | `max-width: 560px` | FAQ와 같은 중앙 760px grid 칼럼 |
| 검증 통과 | 미확인 | `node --check`, `git diff --check`, Browser/IAB, `curl -I` 통과 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 리드 문구 유지 | OK | `HWP/HWPX 문서를 Mac에서 빠르게 확인하고, 편집하고, 공유하세요.` 유지 |
| 철학 설명 정리 | OK | 섹션 2에서는 제거하고 footer 설명으로 이동 |
| 스크린샷 확대와 radius 보정 | OK | `max-height: min(61svh, 700px)`, radius 10px/6px 적용 |
| 첫 hero와 같은 viewport 높이 모델 | OK | `.app-intro-section`에 `height: calc(100svh - var(--header-height))` 적용 |
| footer 높이 축소와 중앙 정렬 | OK | 3열 grid, 중앙 760px 칼럼, 브랜드 nowrap 적용 |
| 기존 script 문법 | OK | `node --check docs/script.js` 통과 |
| 정적 HTML/CSS diff 공백 검사 | OK | `git diff --check -- docs mydocs` 통과 |
| 로컬 서버 응답 | OK | `curl -I http://127.0.0.1:8080/`에서 `HTTP/1.0 200 OK` |
| Browser/IAB smoke | OK | page identity, footer DOM, console error/warn 없음 확인 |

## 실행한 검증 명령

```bash
node --check docs/script.js
rg -n "app-intro|og-main|site-footer|문서 접근은 특정 프로그램|grid-template-columns: minmax\\(140px" docs/index.html docs/styles.css docs/script.js
git diff --check -- docs mydocs
curl -I http://127.0.0.1:8080/
git log --oneline origin/devel-webview..HEAD
git diff --stat origin/devel-webview..HEAD
```

## 잔여 위험과 후속 작업

- Browser/IAB 환경에서 viewport resize API를 쓰지 못해 실제 390px 모바일 캡처는 자동화하지 못했다.
- footer는 최신 `origin/devel-webview`의 업데이트 링크를 유지한 상태에서 정렬을 보정했다. 실제 배포 페이지에서 업데이트 링크 포함 폭을 한 번 더 육안 확인하는 것이 좋다.
- 홍보 페이지의 나머지 섹션은 이번 작업의 직접 수정 대상이 아니며, 전체 랜딩페이지 재설계는 별도 이슈로 분리하는 것이 적절하다.

## 작업지시자 승인 요청

본 보고서 기준으로 Task #178의 구현과 검증을 완료했다. `publish/task178` 브랜치를 `devel-webview` 대상으로 게시하고 PR을 생성한다.
