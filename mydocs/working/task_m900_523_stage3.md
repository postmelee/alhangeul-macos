# Task M900 #523 Stage 3 완료보고서

## 승인과 완료 범위

2026-09-13 작업지시자의 “진행해줘.”에 따라 Stage 3의 작성 규칙·전체 로컬 회귀를 수행했다. 기준 브랜치는 `local/task523`, 직전 단계 commit은 `163db4b`다.

이 단계의 완료는 현재 공개 v0.1.11과 v0.2.0 준비 문서를 기준으로 한 구현·로컬 검증 완료를 뜻한다. v0.2.0 공개 후 문구 재정렬, 공개 배포, 배포 전후 공개 appcast 비교는 아직 실행하지 않았다.

## 변경

- `release_github_pages_sparkle_guide.md`에 소개 한 문단, 작은 공개일·버전 배지, 실제 feed/tap 확인, Homebrew 탭·복사·키보드·비동기 처리 규칙을 반영했다.
- 최신 다운로드와 상세 노트의 해당 버전 고정 다운로드를 구분하고, 준비 문서의 최고 버전과 실제 공개 버전이 다를 수 있음을 명시했다.
- Docs-only 공개 appcast 보존 경로에 bytes/hash 비교와 릴리스 완료 후 문구 정렬 절차를 추가했다. workflow와 helper 구현은 변경하지 않았다.
- v0.1.11의 공유용 `og:description`에 남아 있던 “릴리즈 후보”를 “릴리즈”로 보정했다. 본문의 공개일과 과거 변경 사실은 유지했다.
- 업데이트 홈·v0.1.11·v0.2.0의 최종 데스크톱·모바일 화면 6장을 확보했다.

## 공개 상태와 다운로드

2026-09-13 01:49~01:52 KST 전후 조회 결과다.

- `main`: `aa986e5ae59732a2423324eb3b415a06c67c8a68` (#522 병합).
- `devel`: `feab2c6724673a122adfecd9caee6268ee146595` (#521 병합).
- 최신 공개 Release: v0.1.11, draft=false, prerelease=false, DMG asset uploaded.
- 실제 앱 feed: 0.1.11 / build 17. Homebrew tap: 0.1.11.

변경 대상 세 페이지에서 Release·DMG 관련 URL을 추출해 HTTP HEAD로 검사했다. DMG 파일을 다운로드하거나 설치하지 않았다.

| 링크 | 응답 | 판단 |
|------|------|------|
| v0.1.11 고정 DMG | 200 | 현재 공개 다운로드 정상 |
| latest의 v0.1.11 DMG | 200 | 현재 최신 다운로드 정상 |
| GitHub latest | 200 | 정상 |
| v0.1.11 Release | 200 | 정상 |
| v0.2.0 DMG | 404 | 미공개 후보의 남은 배포 조건 |
| v0.2.0 tag 경로의 웹 페이지 | 200 | 공개 Release 존재의 증거로 쓰지 않음 |

추가 `releases/tags/v0.2.0` API 조회는 404였다. 따라서 tag 경로의 웹 페이지가 200이어도 공개 DMG가 준비됐다고 판정하지 않았다. v0.2.0 링크는 기존 계획대로 공개 준비·공개 후 의미를 유지한다. 상세 결과는 `build.noindex/task523/stage3-public-links.json`에 보관했다.

## appcast 보존과 내부 링크

공개 `https://postmelee.github.io/alhangeul-macos/appcast.xml`을 새로 받은 뒤 다음 순서로 검증했다.

1. `test -s`와 `xmllint --noout`으로 공개 원본 검증: PASS.
2. `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check`: PASS.
3. `scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast build.noindex/task523/public-appcast-stage3.xml --output-dir build.noindex/task523/pages-artifact`: PASS.
4. 산출물 XML 검사와 `cmp`: PASS.
5. 입력·산출물 크기와 SHA-256 비교: 모두 동일.

| 항목 | 입력 원본 | 산출물 |
|------|-----------|--------|
| bytes | 1,167 | 1,167 |
| SHA-256 | `f880f5047ffea8f41f5675900a3fbb5261b9c5d1015a29f007fdbd3be604f234` | 동일 |

공개 appcast를 재생성·재직렬화하거나 저장소 feed로 대체하지 않았다. 이 검증 원본은 실제 배포 때 재사용하지 않는다.

원본 `docs`와 조립 artifact 각각 HTML 16개의 내부 리소스·링크·fragment 194건을 검사했고 누락과 중복 ID가 없었다. 변경 대상 HTML 3개와 CSS·JavaScript는 원본과 artifact의 bytes가 정확히 일치했다. 결과는 `build.noindex/task523/stage3-local-links.json`에 기록했다.

## 화면과 복사 회귀

- 업데이트 홈·v0.1.11·v0.2.0·v0.1.10을 1440×1000, 390×844, 320×844에서 검사했다. 12개 조합 모두 페이지 가로 넘침이 없었다. 보조 공개 정보는 모두 14px 중앙 정렬을 유지했다.
- 기존 배너 구조를 유지하고 helper 정규화 검사를 통과했다. v0.1.11과 v0.1.10의 v0.2.0 안내는 공개 후를 가정한 준비 상태로, 현재 공개 가능하다는 뜻이 아니다.
- 사이트 홈의 390px 너비에서 공유 CSS 적용 후 가로 넘침이 없었다. 업데이트 홈과 artifact의 v0.1.11 상세 화면도 직접 시각 확인했다.
- Stage 2.1의 최종 JavaScript bytes를 그대로 유지했다. 탭·키보드·6건 실제 복사·실패·지연 응답 검증은 [Stage 2 보고서](task_m900_523_stage2.md)의 결과를 이어받는다.
- 별도 8524 서버로 실제 Pages artifact를 열어 설치·업데이트 탭을 전환하고 Enter로 복사했다. 별도 로컬 입력란에 실제 붙여넣은 두 명령이 개행까지 정확히 일치했다. 결과는 `build.noindex/task523/stage3-artifact-copy.json`에 기록했다.
- 앱 v0.2.0 / Homebrew v0.1.11로 배지가 다른 경우의 안내를 별도 fixture에서 390px로 확인했다. 두 배지와 Homebrew 제공 버전 안내가 구분되고 가로 넘침이 없었다. 이는 미래 상태의 표시 모의 검사이며 실제 공개 버전을 변경한 것이 아니다.
- `node --check docs/updates.js`, `git diff --check`: PASS. 실제 페이지 브라우저 경고·오류 로그 조회: 없음.

## 최종 전후 화면

변경 전은 Stage 1에서 원격 devel 기준 소스로 확보한 이미지다. 변경 후는 이번 단계의 최종 소스이며 같은 브라우저·viewport로 전체 페이지를 촬영했다.

| 페이지 | 변경 전 | 변경 후 |
|--------|---------|---------|
| 업데이트 홈 · 데스크톱 | [화면](../report/assets/task_m900_523/before-updates-desktop.jpg) | [화면](../report/assets/task_m900_523/after-updates-desktop.jpg) |
| 업데이트 홈 · 모바일 | [화면](../report/assets/task_m900_523/before-updates-mobile.jpg) | [화면](../report/assets/task_m900_523/after-updates-mobile.jpg) |
| v0.1.11 · 데스크톱 | [화면](../report/assets/task_m900_523/before-v0.1.11-desktop.jpg) | [화면](../report/assets/task_m900_523/after-v0.1.11-desktop.jpg) |
| v0.1.11 · 모바일 | [화면](../report/assets/task_m900_523/before-v0.1.11-mobile.jpg) | [화면](../report/assets/task_m900_523/after-v0.1.11-mobile.jpg) |
| v0.2.0 · 데스크톱 | [화면](../report/assets/task_m900_523/before-v0.2.0-desktop.jpg) | [화면](../report/assets/task_m900_523/after-v0.2.0-desktop.jpg) |
| v0.2.0 · 모바일 | [화면](../report/assets/task_m900_523/before-v0.2.0-mobile.jpg) | [화면](../report/assets/task_m900_523/after-v0.2.0-mobile.jpg) |

사용자 확인용 [8523 로컬 미리보기](http://127.0.0.1:8523/updates/)는 유지한다. 검증 전용 8524·8525 서버는 종료한다. 임시 viewport 설정은 복원한다.

## 남은 공개 조건과 인계

1. #520의 v0.2.0 공개 승격·Pages 배포 완료 후 최신 main/devel과 실제 Release·feed·tap을 다시 확인한다.
2. 최신 다운로드, 배지, 준비 표시, 공개일, 전역 헤더와 배너를 실제 공개 상태로 정렬한다. 그 시점의 변경 diff와 관련 회귀 결과를 다시 제시한다.
3. `main`의 docs 반영은 자동 배포를 유발하므로 별도 공개 승인 후 진행한다. 지금은 PR 게시·merge·배포를 실행하지 않았다.
4. 배포 직전에 public appcast를 새로 받아 원본 bytes/hash를 확보하고 기존 Docs-only 경로로 보존한다. 배포 후 공개 feed의 bytes/hash와 공개 화면·다운로드·복사를 검증한다. 동시 릴리스 배포가 있으면 종료 후 기준을 다시 잡는다.
5. Stage 3 승인 후 최종 보고서를 작성하고, 최종 보고 승인 후 `publish/task523`과 `devel` 대상 리뷰 PR로 이어간다. PR CI는 게시 후 실제 실행 결과를 기록한다. v0.2.0 공개 정렬이 남아 있으면 PR에도 명시한다.

앱 빌드·설치·tag·Release 자산·tap·workflow 변경은 없으며 #520/#513/#337의 소유 범위를 유지했다. 공개 조건이 남아 있으므로 #523 이슈와 오늘할일 전체를 완료 처리하지 않는다.
