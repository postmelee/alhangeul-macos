# Task M900 #523 최종 결과보고서

## 결과와 승인 범위

업데이트 페이지의 소개·공개일·버전 위계를 정리하고, Homebrew 설치와 업데이트 명령을 탭으로 전환하도록 개선했다. Homebrew 영역 높이는 데스크톱·모바일에서 약 29% 줄었으며 선택한 명령을 복사할 수 있다. 구현과 로컬 검증을 완료했고, 최종 보고 승인 후 v0.2.0 공개 상태까지 정렬해 리뷰 PR 게시를 진행한다. 공개 배포 완료 보고는 아니다.

2026-09-13 작업지시자의 “진행해줘.”를 Stage 3 승인 및 최종 보고서 작성 지시로 반영했다. 이번 보고에는 이미 수행한 단계별 검증 결과를 종합했다. 최초 보고서 작성 과정에서는 제품 소스를 추가 변경하지 않았다. 이후 같은 날 PR 게시 승인에 따라 공개 상태를 재조회하고 수행계획에 남겨둔 공개 후 문구 정렬을 완료했다.

- 이슈: [#523](https://github.com/postmelee/alhangeul-macos/issues/523), Release Operations / M900.
- 작업 브랜치: `local/task523`, 기준 `devel` commit `feab2c6724673a122adfecd9caee6268ee146595`.
- Stage 3 검증 commit: `9d21276`. PR 게시 전 최신 `devel`의 `a89a0ce`를 `3479190`으로 통합하고 공개 버전 정렬을 추가했다.
- 격리 경로: `/Users/melee/.codex/worktrees/4ce9/rhwp-mac`. 원본 checkout과 설치 앱은 변경하지 않았다.
- 계획: [수행계획](../plans/task_m900_523.md), [구현계획](../plans/task_m900_523_impl.md).

## 최종 변경

| 대상 | 결과 |
|------|------|
| 업데이트 홈 | 소개 한 문단, 실제 제공 버전을 나타내는 작은 앱·Homebrew 배지, 간결한 앱 메뉴 안내 |
| v0.1.11 상세 | 공개일을 14px 중앙 정렬 보조 정보로 표시하고 공유 설명의 남은 후보 표현 제거 |
| v0.2.0 상세 | GitHub 공개 시각의 한국 날짜인 2026년 9월 13일을 표시하고 공식 다운로드로 정렬 |
| Homebrew | 기본 “처음 설치”, “업데이트” 탭과 공통 복사 버튼, 두 줄 코드 높이 유지 |
| 접근성과 예외 처리 | 방향키·Home/End 전환, Tab 접근, 복사 상태 안내, 늦은 응답 무시, JavaScript 미실행 시 두 명령 표시 |
| Pages 작성 규칙 | 소개·보조 정보·배지 출처·탭·복사 규칙 및 공개 appcast 보존 검증 절차 기록 |

복사값은 표시된 코드 원문이다. 설치는 `brew install --cask postmelee/tap/alhangeul`, 업데이트는 다음 두 줄이며 두 명령 모두 마지막 개행이 없다.

```sh
brew update
brew upgrade --cask postmelee/tap/alhangeul
```

Stage 2.1에서 Homebrew 영역은 1440px·390px에서 417.57px → 298.57px, 320px에서 421.57px → 298.57px로 줄었다. 두 탭의 높이가 같아 전환해도 아래 콘텐츠가 움직이지 않는다. 긴 코드는 코드 블록 내부에서 가로 스크롤한다. 공개 후에는 앱·Homebrew 제공 버전 차이 안내 한 문장이 추가되어 영역 높이가 1440px에서 338.62px, 390/320px에서 366.66px이며 탭 전환 높이는 동일하다.

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

Stage 3의 appcast 입력과 산출물은 각각 1,167바이트이며 SHA-256은 `f880f5047ffea8f41f5675900a3fbb5261b9c5d1015a29f007fdbd3be604f234`다. XML을 재생성하거나 저장소의 stale feed로 대체하지 않았다. 검증 원본을 향후 배포 입력으로 재사용하지 않는다.

브라우저 도구의 clipboard 읽기가 빈 값을 반환해 별도 로컬 입력란에 실제 붙여넣는 방식으로 검증했다. 캐시와 이전 입력값의 영향을 제거한 최종 재검증 결과를 사용했다. 오류·지연 검증은 별도 fixture에서 수행했다. 상세 근거는 단계 보고서에 기록했다.

| 단계 | commit | 상세 근거 |
|------|--------|-----------|
| Stage 1 | `b76a42c` | [소개·공개 정보 위계](../working/task_m900_523_stage1.md) |
| Stage 2 | `4a9e59d` | [명령 복사](../working/task_m900_523_stage2.md) |
| Stage 2.1 | `163db4b` | [탭 전환·높이·복사 회귀](../working/task_m900_523_stage2.md#stage-21--명령어-탭-전환-보완) |
| Stage 3 | `9d21276` | [작성 규칙·전체 회귀·appcast](../working/task_m900_523_stage3.md) |

## 전후 화면과 로컬 확인

같은 브라우저와 1440×1000·390×844 viewport로 촬영했다. 변경 전은 기준 devel 소스, 변경 후는 v0.2.0 공개 정렬까지 적용한 PR 게시 소스다.

| 페이지 | 변경 전 | 변경 후 |
|--------|---------|---------|
| 업데이트 홈 · 데스크톱 | [화면](assets/task_m900_523/before-updates-desktop.jpg) | [화면](assets/task_m900_523/published-updates-desktop.jpg) |
| 업데이트 홈 · 모바일 | [화면](assets/task_m900_523/before-updates-mobile.jpg) | [화면](assets/task_m900_523/published-updates-mobile.jpg) |
| v0.1.11 · 데스크톱 | [화면](assets/task_m900_523/before-v0.1.11-desktop.jpg) | [화면](assets/task_m900_523/published-v0.1.11-desktop.jpg) |
| v0.1.11 · 모바일 | [화면](assets/task_m900_523/before-v0.1.11-mobile.jpg) | [화면](assets/task_m900_523/published-v0.1.11-mobile.jpg) |
| v0.2.0 · 데스크톱 | [화면](assets/task_m900_523/before-v0.2.0-desktop.jpg) | [화면](assets/task_m900_523/published-v0.2.0-desktop.jpg) |
| v0.2.0 · 모바일 | [화면](assets/task_m900_523/before-v0.2.0-mobile.jpg) | [화면](assets/task_m900_523/published-v0.2.0-mobile.jpg) |

[로컬 Homebrew 미리보기](http://127.0.0.1:8523/updates/#homebrew)에서 두 탭을 전환할 수 있다. 사용자 확인용 8523 서버를 유지하고 검증 전용 8524·8525 서버는 종료했다.

## PR 게시 전 공개 상태 정렬

2026-09-13 02:50~02:58 KST 전후 재조회에서 v0.2.0의 [공개 배포 실행](https://github.com/postmelee/alhangeul-macos/actions/runs/34709043904)이 성공한 것을 확인했다. Stage 3 당시 미공개였던 상태가 바뀌어 수행계획에 남겨둔 정렬을 적용했다.

- 최신 `devel`: `a89a0cedd14ee64b5922833bda0a97b4d4bf02b9`, `main`: `c942230b0625bc30eff894373fc3af5e205e8d8b`. 최신 devel 통합 시 오늘할일 add/add 충돌만 있었으며 #520/#525 기록과 #523 기록을 모두 보존했다. main/source content gate는 통합 직후 통과했다.
- GitHub 최신 Release: v0.2.0, draft=false, prerelease=false, 공개 시각 `2026-09-12T17:43:58Z`(한국 시각 9월 13일 02:43:58).
- 실제 public appcast: v0.2.0 / build 18. 실제 Homebrew tap은 v0.1.11로, 앱·Homebrew 배지를 각각 표시하고 최신 DMG·앱 업데이트 경로를 안내했다. tap은 수정하지 않았다.
- 업데이트 홈과 변경 대상 상세 헤더의 최신 다운로드를 v0.2.0으로 변경했다. v0.2.0 공개 준비 표시는 제거하고 공개일을 표시했다. v0.1.11의 고정 다운로드와 공개일은 유지했다. 기존 v0.2.0 안내 배너가 실제 공개 상태와 일치한다.
- v0.2.0 고정·latest DMG 링크는 모두 HTTP 200. 변경한 세 페이지를 1440/390/320px에서 다시 확인해 9개 조합 모두 가로 넘침이 없고 공개일은 14px를 유지했다. 최종 화면 6장을 다시 확보했다.
- 설치·업데이트 실제 복사를 다시 확인했다. 빠른 연속 자동화 첫 설치 붙여넣기에서 이전 명령이 관측되어, 새로고침·복사 완료·빈 입력란 확인을 분리해 재검증한 두 명령은 정확히 일치했다. 원본 결과와 재검증 결과를 `build.noindex/task523/pr-copy.json`에 함께 보관했다. CSS·JavaScript bytes는 Stage 3와 같다.
- 새 공개 appcast로 artifact 조립·XML·`cmp`를 다시 통과했다. 입력·산출물은 각각 1,161바이트, SHA-256 `e2ae654de6acd5e56db769e4e5415fa30beed2756f588b3d9a0aa1947d0ae48b`로 같다. 릴리스가 feed를 갱신했으므로 Stage 3의 v0.1.11 hash와 비교해 보존 실패로 판정하지 않는다.
- 원본·artifact 각각 내부 링크 194건, 배너 helper, JavaScript 구문 및 diff 검사를 다시 통과했다. PR CI 결과는 게시 후 PR 본문에 실제 head 기준으로 기록한다.

## 남은 작업

1. 승인된 `publish/task523` 게시와 `devel` 대상 Open PR 생성·CI 확인을 수행한다. 이번 승인은 리뷰 PR 게시 범위이며 merge는 별도다.
2. main의 docs 반영은 자동 Pages 배포를 유발하므로 별도 공개 승인을 받는다. 배포 직전에 Release·feed·tap을 재조회하고 필요한 정적 배지·문구를 정렬한다.
3. 배포 직전 새 public appcast 원본을 검증·보존하고 배포 후 bytes/hash 및 공개 화면·다운로드·복사를 확인한다. 동시 릴리스가 있으면 완료 후 비교 기준을 다시 잡는다.
4. 이번 UI 변경의 공개 후 검증이 남아 있으므로 #523 이슈와 오늘할일은 진행중으로 유지한다.

이 작업의 제품 변경은 Pages HTML·CSS·JavaScript다. 최신 devel 통합으로 들어온 #520 변경은 해당 타스크 소유이며, 이 작업에서 앱 빌드·설치, Release 자산·tag, Cask·tap, workflow·helper 구현을 추가 변경하지 않았다. 사용자 확인용 8523 서버를 유지하고 복사 재검증용 8525 서버는 종료한다.
