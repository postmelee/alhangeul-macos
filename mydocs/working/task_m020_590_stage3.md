# Task M020 #590 Stage 3 — 회귀·최종 보고·PR 초안

## 1. 승인과 결과

2026-10-15 작업지시자가 **“#590 Stage 2 결과를 수용하고 Stage 3의 회귀 검사·최종 보고·PR 초안 준비를 진행해줘.”**라고 승인했다. [구현계획 Stage 3](../plans/task_m020_590_impl.md)에 따라 필요한 기존 회귀와 최종 보존 검사를 수행했다. **모든 검사 PASS, 추가 제품 소스 수정 없음**이다. 제품 소스는 `a626a6de`, 수용한 전체 화면·키보드 결과는 `1d99a8aa`다.

## 2. 검증

[검증 요약](../report/assets/task_m020_590/stage3/validation.json)과 원본 로그·[checksum](../report/assets/task_m020_590/stage3/SHA256SUMS)을 보관했다.

| 검사 | 결과 |
|------|------|
| `node --test scripts/ci/test-news-ui.cjs` | 9 PASS, 실패/skip 0 |
| `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-news-pages.py` | 14 PASS. 외부 API·실제 배포 없이 fixture 조립/계약 검사 |
| `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check` | 최신 v0.2.3 안내 일치 |
| 전체 21개 헤더/본문·16개 릴리즈 노트 보존 | PASS. 원본 manifest 대조, 글꼴의 승인한 문구 한 줄 제거/헤더 다운로드만 예외 |
| 로컬 HTML 링크·자산·fragment 295곳 | 파일/대상 ID 누락 0 |
| 이전 Stage 1/1.1/2 증거 checksum 18개·JPEG | 모두 일치, 기존 증거 미수정 |
| 범위·`git diff --check` | 대상 HTML/CSS와 #590 문서/증거만 변경. 앱·core/Studio·버전·workflow·appcast·Cask 미변경 |

Python suite에서 기존 Ruby `ffi-1.13.1` native extensions 미빌드 경고 3줄이 나왔지만 suite 전체는 OK였다. 환경 패키지를 재설치하거나 경고를 숨기지 않았다. 원본 [Pages 로그](../report/assets/task_m020_590/stage3/news-pages.log)에 남겼다.

## 3. 보고와 게시 준비

[최종 보고](../report/task_m020_590_report.md)에 사용자 변화·화면·검증·제한과 공개 반영 경계를 취합했다. [오늘할일](../orders/20261015.md)은 최종 로컬 준비 완료·공개 게시 승인 대기로 기록하고, 이슈/PR 완료로 표시하지 않았다.

PR 초안 `mydocs/working/task_m020_590_pr_draft.md`은 `devel` 대상 Open PR용이다. 보고서 커밋 SHA로 문서 링크를 고정하고 본문 검사를 통과한 뒤 초안도 로컬 커밋한다. `Closes #590`은 향후 실제 PR 병합 시 종료를 연결하는 초안 문자열이며 현재 이슈를 닫는 동작이 아니다.

실제 외부 CI·push/Open PR·merge·이슈 close·main/Pages 배포는 실행하지 않았다. 소형 정적 검증만 사용했고 앱/Rust 재빌드·새 DMG·사이트 전체 복사본·의존성 설치는 없었다. 기존 로컬 미리보기 서버와 증거를 후속 리뷰용으로 유지한다.

## 4. 다음 승인

최종 보고 수용과 최종 clean head의 `publish/task590` push·`devel` 대상 Open PR 게시 승인을 요청한다. PR 게시 후 CI 확인·리뷰를 진행하며, 병합·main/Pages 공개 반영은 별도 승인 대상이다. 공개 main 반영 직전 실제 appcast 보존 입력과 동시 배포 상태를 다시 확인해야 한다.
