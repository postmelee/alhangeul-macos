# Task M900 #523 최종 결과보고서

## 결과와 승인 범위

업데이트 페이지의 소개·공개일·버전 위계를 정리하고, Homebrew 설치와 업데이트 명령을 탭으로 전환하도록 개선했다. Homebrew 영역 높이는 데스크톱·모바일에서 약 29% 줄었으며 선택한 명령을 복사할 수 있다. 구현과 로컬 검증을 완료했고 리뷰 PR 게시 승인을 기다린다. 공개 배포 완료 보고는 아니다.

2026-09-13 작업지시자의 “진행해줘.”를 Stage 3 승인 및 최종 보고서 작성 지시로 반영했다. 이번 보고에는 이미 수행한 단계별 검증 결과를 종합했다. 보고서 작성 과정에서 제품 소스를 추가 변경하지 않았다.

- 이슈: [#523](https://github.com/postmelee/alhangeul-macos/issues/523), Release Operations / M900.
- 작업 브랜치: `local/task523`, 기준 `devel` commit `feab2c6724673a122adfecd9caee6268ee146595`.
- 검증된 구현 최종 commit: `9d21276`.
- 격리 경로: `/Users/melee/.codex/worktrees/4ce9/rhwp-mac`. 원본 checkout과 설치 앱은 변경하지 않았다.
- 계획: [수행계획](../plans/task_m900_523.md), [구현계획](../plans/task_m900_523_impl.md).

## 최종 변경

| 대상 | 결과 |
|------|------|
| 업데이트 홈 | 소개 한 문단, 실제 제공 버전을 나타내는 작은 앱·Homebrew 배지, 간결한 앱 메뉴 안내 |
| v0.1.11 상세 | 공개일을 14px 중앙 정렬 보조 정보로 표시하고 공유 설명의 남은 후보 표현 제거 |
| v0.2.0 상세 | 확인되지 않은 공개일을 만들지 않고 공개 준비·공개 후 다운로드 의미 표시 |
| Homebrew | 기본 “처음 설치”, “업데이트” 탭과 공통 복사 버튼, 두 줄 코드 높이 유지 |
| 접근성과 예외 처리 | 방향키·Home/End 전환, Tab 접근, 복사 상태 안내, 늦은 응답 무시, JavaScript 미실행 시 두 명령 표시 |
| Pages 작성 규칙 | 소개·보조 정보·배지 출처·탭·복사 규칙 및 공개 appcast 보존 검증 절차 기록 |

복사값은 표시된 코드 원문이다. 설치는 `brew install --cask postmelee/tap/alhangeul`, 업데이트는 다음 두 줄이며 두 명령 모두 마지막 개행이 없다.

```sh
brew update
brew upgrade --cask postmelee/tap/alhangeul
```

Homebrew 영역은 1440px·390px에서 417.57px → 298.57px, 320px에서 421.57px → 298.57px로 줄었다. 두 탭의 높이가 같아 전환해도 아래 콘텐츠가 움직이지 않는다. 긴 코드는 코드 블록 내부에서 가로 스크롤한다.

## 검증 결과

| 검증 | 실제 결과 |
|------|-----------|
| 최종 화면 회귀 | 업데이트 홈·v0.1.11·v0.2.0·v0.1.10 × 1440/390/320px 12개 조합 모두 가로 넘침 없음. 사이트 홈 390px도 확인 |
| 탭과 복사 | 최종 탭 구현에서 설치·업데이트 각각 마우스·Enter·Space로 복사한 6건을 실제 붙여넣기 문자열과 대조해 일치 |
| 키보드 | 좌우 방향키 순환, Home/End 전환, 활성 탭·복사 버튼 접근 및 포커스 유지 확인 |
| 예외 모의 | 권한 거부·API 미지원·JavaScript 미실행·지연 성공/실패 중 탭 전환 확인. 실제 OS 권한 변경 시험과 구분 |
| 내부 링크 | 원본과 Pages artifact 각각 HTML 16개, 내부 리소스·링크·fragment 194건에 누락·중복 ID 없음 |
| Pages helper | 이전 버전 배너 `--check`와 `prepare-pages-artifact.sh` 통과 |
| artifact 복사 | 별도 artifact 서버에서 두 탭의 명령을 Enter로 복사하고 실제 붙여넣어 개행까지 일치 |
| appcast 보존 | 새로 받은 공개 XML과 조립 산출물의 XML 검사·`cmp`·bytes·SHA-256 일치 |
| 기본 검사 | `node --check docs/updates.js`, `git diff --check` 통과. 실제 페이지 브라우저 경고·오류 없음 |

appcast 입력과 산출물은 각각 1,167바이트이며 SHA-256은 `f880f5047ffea8f41f5675900a3fbb5261b9c5d1015a29f007fdbd3be604f234`다. XML을 재생성하거나 저장소의 stale feed로 대체하지 않았다. 검증 원본을 향후 배포 입력으로 재사용하지 않는다.

브라우저 도구의 clipboard 읽기가 빈 값을 반환해 별도 로컬 입력란에 실제 붙여넣는 방식으로 검증했다. 캐시와 이전 입력값의 영향을 제거한 최종 재검증 결과를 사용했다. 오류·지연 검증은 별도 fixture에서 수행했다. 상세 근거는 단계 보고서에 기록했다.

| 단계 | commit | 상세 근거 |
|------|--------|-----------|
| Stage 1 | `b76a42c` | [소개·공개 정보 위계](../working/task_m900_523_stage1.md) |
| Stage 2 | `4a9e59d` | [명령 복사](../working/task_m900_523_stage2.md) |
| Stage 2.1 | `163db4b` | [탭 전환·높이·복사 회귀](../working/task_m900_523_stage2.md#stage-21--명령어-탭-전환-보완) |
| Stage 3 | `9d21276` | [작성 규칙·전체 회귀·appcast](../working/task_m900_523_stage3.md) |

## 전후 화면과 로컬 확인

같은 브라우저와 1440×1000·390×844 viewport로 촬영했다. 변경 전은 기준 devel 소스, 변경 후는 Stage 3 최종 소스다.

| 페이지 | 변경 전 | 변경 후 |
|--------|---------|---------|
| 업데이트 홈 · 데스크톱 | [화면](assets/task_m900_523/before-updates-desktop.jpg) | [화면](assets/task_m900_523/after-updates-desktop.jpg) |
| 업데이트 홈 · 모바일 | [화면](assets/task_m900_523/before-updates-mobile.jpg) | [화면](assets/task_m900_523/after-updates-mobile.jpg) |
| v0.1.11 · 데스크톱 | [화면](assets/task_m900_523/before-v0.1.11-desktop.jpg) | [화면](assets/task_m900_523/after-v0.1.11-desktop.jpg) |
| v0.1.11 · 모바일 | [화면](assets/task_m900_523/before-v0.1.11-mobile.jpg) | [화면](assets/task_m900_523/after-v0.1.11-mobile.jpg) |
| v0.2.0 · 데스크톱 | [화면](assets/task_m900_523/before-v0.2.0-desktop.jpg) | [화면](assets/task_m900_523/after-v0.2.0-desktop.jpg) |
| v0.2.0 · 모바일 | [화면](assets/task_m900_523/before-v0.2.0-mobile.jpg) | [화면](assets/task_m900_523/after-v0.2.0-mobile.jpg) |

[로컬 Homebrew 미리보기](http://127.0.0.1:8523/updates/#homebrew)에서 두 탭을 전환할 수 있다. 사용자 확인용 8523 서버를 유지하고 검증 전용 8524·8525 서버는 종료했다.

## 공개 상태와 남은 작업

Stage 3의 2026-09-13 01:49~01:52 KST 전후 조회 기준으로 최신 공개 Release·앱 feed·Homebrew는 v0.1.11이었다. v0.1.11 DMG와 Release 링크는 정상 응답했다. v0.2.0 DMG와 Release API는 404였으며 tag 웹 경로의 200 응답만으로 공개 완료를 판정하지 않았다. 이는 당시 검증 기록이며 공개 직전에 다시 조회해야 한다.

기준 소스에 있던 사이트 홈의 v0.2.0 안내와 이전 노트의 v0.2.0 배너는 #520 공개 후를 가정한 준비 상태다. 배너 helper의 최고 문서 버전 정책은 유지했으며 검사 통과를 실제 공개 상태 일치로 취급하지 않는다.

1. 최종 보고 승인 후 `publish/task523` 원격 브랜치로 게시하고 `devel` 대상 리뷰 PR을 생성한다. PR CI는 게시 후 실제 결과를 기록한다.
2. #520의 v0.2.0 공개 승격·Pages 배포 완료 후 최신 main/devel, Release·DMG·feed·tap을 다시 확인한다. 다운로드·배지·준비 표시·공개일·헤더·배너를 실제 공개 상태와 정렬하고 변경 diff 및 관련 회귀 결과를 제시한다.
3. main의 docs 반영은 자동 Pages 배포를 유발하므로 별도 공개 승인을 받는다. 배포 직전 새 public appcast 원본을 검증·보존하고 배포 후 bytes/hash 및 공개 화면·다운로드·복사를 확인한다. 동시 릴리스가 있으면 완료 후 비교 기준을 다시 잡는다.
4. 공개 후 검증이 남아 있으므로 #523 이슈와 오늘할일은 진행중으로 유지한다. PR merge·배포와 이슈 종료는 이번 최종 보고 작성 범위에 포함하지 않는다.

앱 소스·빌드·설치, core pin, Release 자산·tag, Cask·tap, workflow·helper 구현은 변경하지 않았다. #520/#513/#337의 릴리스 소유 범위를 유지했다.
