# Task M900 #523 Stage 2 완료보고서

## 승인과 변경

2026-09-13 작업지시자의 “승인할게 다음을 진행해줘.”에 따라 Stage 2를 수행했다. 작업 브랜치는 `local/task523`, 직전 단계 commit은 `b76a42c`다.

- 업데이트 홈의 Homebrew 안내를 “처음 설치”와 “Homebrew로 설치한 앱 업데이트”로 나누고 각각 코드 블록과 복사 버튼을 추가했다.
- 기존 `.code-panel`을 재사용하고 키보드로 가로 스크롤할 수 있도록 포커스 가능한 코드 블록에 접근 가능한 이름을 연결했다. 버튼은 44px 높이를 확보하고 포커스 테두리를 표시한다.
- `docs/updates.js`에서 화면의 `code.textContent`를 그대로 복사한다. 명령어 문자열을 JavaScript에 중복 저장하지 않는다. 버튼·제목·shell prompt는 복사값에 들어가지 않는다.
- 성공 시 “복사됨”과 `role="status"` 안내를 제공한다. 1.8초 후 기본 상태로 돌아오고, 재복사 시 기존 타이머를 해제한다. 복사 처리 중에는 중복 요청을 막고 포커스를 유지한다.
- clipboard 거부·미지원 시 수동 선택·복사 안내를 유지한다. JavaScript가 실행되지 않으면 복사 버튼은 숨겨지고 명령어는 계속 표시된다.
- v0.1.11·v0.2.0 상세 노트의 앱 메뉴 안내를 간결하게 바꾸고, Homebrew 명령과 현재 제공 버전은 업데이트 홈의 `#homebrew`로 연결했다. 과거 노트에서 현재 tap이 해당 과거 버전을 설치한다고 오해할 문구를 제거했다.

## 실제 복사값 검증

Codex 내장 브라우저에서 로컬 8523 서버의 실제 페이지 버튼을 실행한 후, 별도 로컬 검증 입력란에 `Meta+V`로 붙여넣어 전체 문자열을 비교했다. 브라우저 도구의 `clipboard.readText()`가 빈 값을 반환하는 문제가 있어, 버튼 성공 표시만으로 통과 처리하지 않고 실제 붙여넣기를 사용했다.

| 명령 | 마우스 | Enter | Space | 포커스 |
|------|--------|-------|-------|--------|
| 설치 | 정확히 일치 | 정확히 일치 | 정확히 일치 | 실행한 버튼 유지 |
| 업데이트 | 정확히 일치 | 정확히 일치 | 정확히 일치 | 실행한 버튼 유지 |

설치값은 마지막 개행 없이 `brew install --cask postmelee/tap/alhangeul`이다. 업데이트값은 아래 두 줄 사이 LF 하나만 포함하고 마지막 개행은 없다.

```sh
brew update
brew upgrade --cask postmelee/tap/alhangeul
```

6건 모두 상태 영역에 복사 완료 안내가 표시됐다. 명령을 터미널에 실행하거나 앱을 설치하지 않았다. 결과 원본은 `build.noindex/task523/stage2-copy.json`에 보관했다.

## 예외·키보드·화면 검증

| 검사 | 결과 |
|------|------|
| clipboard 권한 거부 모의 | 수동 복사 안내, 성공 표시 없음, 버튼 포커스 유지 |
| clipboard API 미지원 모의 | 같은 수동 복사 안내, 코드 원문 표시 유지 |
| 스크립트 로드 없음 | 두 버튼 숨김, 두 명령어 표시 유지 |
| 비동기 복사 지연 중 더블클릭 | API 호출 1회, 복사 중 상태·aria-disabled 표시, 종료 후 기본 상태 복원 |
| Tab 순서 | 설치 복사 → 설치 코드 → 업데이트 복사 → 업데이트 코드, 네 요소 모두 포커스 테두리 표시 |
| 320px에서 코드 키보드 스크롤 | ArrowRight 후 scrollLeft 0 → 80, 페이지 너비 320px 유지 |
| 마우스 수동 선택 | 설치 코드 전체 문자열 선택 가능 |
| 데스크톱 1440px | 코드 블록 내부 너비·내용 너비 878px, 페이지 넘침 없음 |
| 모바일 390px·320px | 페이지 넘침 없음, 긴 코드는 블록 내부 스크롤, 버튼과 제목 겹침 없음 |
| 상세 노트 두 페이지의 Homebrew 링크 | 실제 클릭 후 `/updates/#homebrew` 도착 |
| 브라우저 경고·오류 | 조회 결과 없음 |

예외 상태는 `build.noindex/task523/clipboard-fixtures/` 아래에 현재 HTML·CSS·JavaScript를 복사하고, 테스트용 clipboard 거부·미지원·1.2초 지연을 설정한 별도 페이지에서 확인했다. 모의 결과를 실제 OS 권한 설정 시험으로 간주하지 않는다. 배포용 소스에는 테스트 분기를 추가하지 않았다. 예외·Tab 결과는 `build.noindex/task523/stage2-fixtures.json`에 보관했다.

상세 노트 검증 중 브라우저에 이전 HTML이 캐시되어 신규 링크가 조회되지 않았다. 각 페이지를 새로고침한 뒤 두 링크 모두 실제 클릭 검증을 통과했다.

- `node --check docs/updates.js`: PASS.
- `git diff --check`: PASS.
- `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check`: PASS. 기존 helper의 v0.2.0 기준 준비 배너 정책을 유지했다.

## 로컬 미리보기와 화면

사용자 확인용 서버는 계속 127.0.0.1:8523에서 이 worktree의 `docs`만 제공한다. 별도 8524 검증 서버는 검증 후 종료한다. 브라우저의 임시 viewport 설정은 복원한다.

- [Homebrew 설치·업데이트 미리보기](http://127.0.0.1:8523/updates/#homebrew)
- [데스크톱 화면](../report/assets/task_m900_523/stage2-homebrew-desktop.jpg)
- [모바일 화면](../report/assets/task_m900_523/stage2-homebrew-mobile.jpg)

## 다음 단계와 공개 조건

Stage 3에서는 Pages 작성 매뉴얼, 전체 링크·화면 회귀, 공개 appcast 보존 artifact 조립, 최종 전후 화면을 준비한다. v0.2.0 공개 승격·Pages 배포 후 실제 공개 문구와 앱 feed·Homebrew 버전의 최종 정렬 조건은 그대로 남아 있다. 이번 단계에서는 버전 배지를 재확정하거나 공개 배포·앱 빌드·릴리스 실행을 하지 않았다.

소스·화면·단계 기록을 `Task #523 Stage 2: Homebrew 설치와 업데이트 명령 복사 제공`으로 함께 커밋하고 Stage 3 진행 승인을 요청한다.
