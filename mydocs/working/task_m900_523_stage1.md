# Task M900 #523 Stage 1 완료보고서

## 승인과 결과

2026-09-12 작업지시자의 구현계획 진행 및 로컬 서버 제공 지시에 따라 Stage 1을 구현·검증했다. `local/task523`의 기준은 `feab2c6724673a122adfecd9caee6268ee146595`다. 다음 Homebrew 코드 블록·복사 기능은 Stage 2 승인 후 진행한다.

- 업데이트 홈의 소개를 한 문단으로 줄이고 중복 최신 버전 설명을 제거했다.
- 앱 업데이트와 Homebrew 제목에 각각 13px 텍스트 버전 배지를 추가했다. 앱 메뉴 안내를 한 문장으로 줄이고 모바일에서 단어가 잘리지 않게 했다.
- v0.1.11의 공개일을 의미 있는 `time` 요소와 14px 중앙 정렬 보조 문구로 표시했다. v0.2.0은 공개일을 추정하지 않고 같은 위계의 준비 상태를 표시했다.
- 실제 공개 버전에 맞춰 업데이트 홈과 변경 대상 상세 페이지의 최신 다운로드를 v0.1.11로 정렬했다. v0.2.0 문서 링크와 다운로드는 공개 준비·공개 후 의미를 명시했다.
- CSS는 업데이트 영역에 한정하고 수정한 세 HTML의 stylesheet 버전 키를 갱신했다. 기존 배너 helper와 workflow는 변경하지 않았다.

## 공개 버전 확인

2026-09-12 23:50 KST 전후 읽기 전용 조회 결과다.

| 경로 | 결과 | 근거 |
|------|------|------|
| GitHub 최신 공개 Release | v0.1.11, draft=false, prerelease=false | `gh api repos/postmelee/alhangeul-macos/releases/latest` |
| 앱 업데이트 feed | 0.1.11 / build 17 | 공개 `appcast.xml` 다운로드 및 `xmllint --noout` 통과 |
| Homebrew | 0.1.11 | `postmelee/homebrew-tap`의 `Casks/alhangeul.rb` 조회 |

공개 appcast SHA-256: `f880f5047ffea8f41f5675900a3fbb5261b9c5d1015a29f007fdbd3be604f234`. 조사 원본은 `build.noindex/task523/public-appcast-stage1.xml`이며 배포용으로 재사용하지 않는다. 브라우저 방문 때 외부 API를 호출하지 않으며 각 배지는 확인된 정적 값이다.

## 검증

Codex 내장 브라우저에서 이 worktree의 로컬 서버를 사용했다. 아래 다섯 페이지를 1440×1000, 390×844, 320×844에서 검사했다.

| 페이지 | 가로 넘침 | 소개 크기: 데스크톱 / 모바일 | 보조 정보 | 배너 |
|--------|-----------|----------------------------|-----------|------|
| 업데이트 홈 | 세 너비 모두 없음 | 21px / 18px | 버전 배지 13px | 없음 |
| v0.1.11 | 세 너비 모두 없음 | 21px / 18px | 공개일 14px, 중앙 정렬 | 기존 구조 유지 |
| v0.2.0 | 세 너비 모두 없음 | 21px / 18px | 준비 상태 14px, 중앙 정렬 | 없음 |
| 사이트 홈 | 세 너비 모두 없음 | 이번 수정 대상 아님 | 신규 CSS 적용 대상 없음 | 기존 구조 유지 |
| v0.1.10 | 세 너비 모두 없음 | 21px / 18px | 신규 보조 문구 없음 | 기존 구조 유지 |

- 측정 시 각 페이지의 `documentElement.scrollWidth`가 viewport 너비와 일치했다. 조사 JSON은 `build.noindex/task523/stage1-layout.json`에 보관했다.
- 모바일 시각 확인 중 앱 메뉴 안내의 마지막 음절만 다음 줄로 떨어지는 현상을 발견해 해당 문장에 `word-break: keep-all`을 적용했다. 보정 후 세 너비의 업데이트 홈을 다시 확인하고 이미지를 갱신했다.
- 공개일은 모바일의 기존 `.updates-hero p` 규칙에 덮어써지지 않고 14px를 유지했다. 제목 옆 배지와 다운로드 버튼, 상세 공개일을 직접 시각 확인했다.
- `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check`: PASS. helper의 판단 기준은 저장소 최고 버전 v0.2.0이며 실제 공개 상태 검증과는 구분한다.
- `git diff --check`: PASS. 브라우저 경고·오류 로그 조회: 없음.
- 실제 clipboard 검사, 최종 링크 전수 검사, appcast 보존 artifact 조립은 Stage 2·3에 남아 있다. 앱 빌드·설치·공개 배포는 실행하지 않았다.

## 화면과 로컬 확인

로컬 서버는 `python3 -m http.server 8523 --bind 127.0.0.1 --directory docs`로 실행했다. 사용자 확인 요청에 따라 유지하며 원본 worktree나 설치 앱은 변경하지 않았다. 이 서버는 현재 worktree의 `docs`만 제공한다.

- [업데이트 홈](http://127.0.0.1:8523/updates/)
- [v0.1.11 상세](http://127.0.0.1:8523/updates/v0.1.11.html)
- [v0.2.0 준비 문서](http://127.0.0.1:8523/updates/v0.2.0.html)

변경 전 화면은 기준 commit의 소스로 2026-09-12 23:51 KST 무렵 확보했다. Stage 1 화면은 같은 브라우저와 viewport로 확보했으며 이미지 전체 높이는 페이지 내용에 따라 달라진다. 브라우저가 반환한 JPEG bytes를 변환하지 않고 `.jpg`로 저장했다.

| 페이지 | 변경 전 | Stage 1 |
|--------|---------|---------|
| 업데이트 홈 · 데스크톱 | [화면](../report/assets/task_m900_523/before-updates-desktop.jpg) | [화면](../report/assets/task_m900_523/stage1-updates-desktop.jpg) |
| 업데이트 홈 · 모바일 | [화면](../report/assets/task_m900_523/before-updates-mobile.jpg) | [화면](../report/assets/task_m900_523/stage1-updates-mobile.jpg) |
| v0.1.11 · 데스크톱 | [화면](../report/assets/task_m900_523/before-v0.1.11-desktop.jpg) | [화면](../report/assets/task_m900_523/stage1-v0.1.11-desktop.jpg) |
| v0.1.11 · 모바일 | [화면](../report/assets/task_m900_523/before-v0.1.11-mobile.jpg) | [화면](../report/assets/task_m900_523/stage1-v0.1.11-mobile.jpg) |
| v0.2.0 · 데스크톱 | [화면](../report/assets/task_m900_523/before-v0.2.0-desktop.jpg) | [화면](../report/assets/task_m900_523/stage1-v0.2.0-desktop.jpg) |
| v0.2.0 · 모바일 | [화면](../report/assets/task_m900_523/before-v0.2.0-mobile.jpg) | [화면](../report/assets/task_m900_523/stage1-v0.2.0-mobile.jpg) |

## 공개 반영 전 남은 조건

현재 로컬 화면은 공개용 최종본이 아니다. 기준 소스에는 사이트 홈의 v0.2.0 공개 안내와, v0.1.11 등 과거 노트에서 v0.2.0을 최신으로 안내하는 기존 배너가 남아 있다. 이는 #520의 공개 후를 가정한 준비 상태다. 해당 배너를 helper 정책과 다르게 수동 수정하거나 지금 배포하지 않았다.

#520의 v0.2.0 공개 승격 및 Pages 배포 완료 후 최신 main의 문구·공개일·최신 DMG, feed와 Homebrew를 재확인한다. 홈 다운로드·배지·준비 표시·상세 헤더를 당시 상태로 정렬하고 Stage 3 검증을 수행한다. v0.2.0 후보 자산은 성공한 공개 다운로드로 보고하지 않는다.

Stage 1 소스·계획·화면·보고서를 `Task #523 Stage 1: 업데이트 소개와 공개 정보 위계 정리`로 함께 커밋한다. Stage 2 진행은 작업지시자 승인 대기다.
