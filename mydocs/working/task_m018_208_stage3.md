# Task M018 #208 Stage 3 보고서

## 단계 목적

단일 universal DMG 정책에 맞춰 GitHub Pages 다운로드 진입점과 작업 추적 문구를 정정한다. Stage 2 이후 작업지시자 판단에 따라 Intel Mac / Apple Silicon 선택 UI는 만들지 않고, 기존 direct DMG 다운로드 방식을 유지하면서 지원 아키텍처 안내를 보강하는 범위로 조정했다.

## 변경 요약

| 파일/대상 | 변경 내용 |
|-----------|-----------|
| GitHub Issue #208 | 제목과 본문을 `단일 universal DMG 안내 보강` 기준으로 갱신 |
| Milestone #18 `v0.1.1` | 실행 순서, 순서 원칙, 완료 기준에서 선택 UI 기준을 direct DMG + universal 안내 기준으로 갱신 |
| `mydocs/plans/task_m018_208.md` | 수행계획서의 Stage 3 범위를 Pages 선택 UI 구현에서 direct download 안내 보강으로 수정 |
| `docs/index.html` | 홈 다운로드 버튼을 v0.1.1 DMG direct link로 갱신하고 FAQ에 단일 universal DMG 안내 추가 |
| `docs/updates/index.html` | 업데이트 페이지 설명에 Intel Mac + Apple Silicon 지원 단일 DMG 안내 추가 |
| `docs/updates/v0.1.1.html` | v0.1.1 릴리즈 노트에 universal app/extension 검증과 단일 DMG 설치 안내 추가 |
| `docs/updates/v0.1.0.html` | 과거 릴리즈 다운로드 링크를 `latest/download`가 아니라 `v0.1.0` tag 고정 URL로 변경 |
| `mydocs/orders/20260510.md` | #208 타스크명을 새 범위에 맞게 수정 |
| `mydocs/release/v0.1.1.md`, `mydocs/plans/task_m018_187.md`, Stage 1/2 보고서 | 선택 UI 전제 문구를 단일 universal DMG 안내 기준으로 정정 |

## 정책 결정

- v0.1.1 기본 배포 산출물은 `alhangeul-macos-0.1.1.dmg` 단일 파일이다.
- 이 DMG 안의 app bundle이 `arm64 + x86_64` universal이면 Intel Mac과 Apple Silicon Mac이 같은 설치 파일을 사용한다.
- GitHub Pages에는 Intel Mac / Apple Silicon 선택 UI를 만들지 않는다.
- Pages 다운로드 버튼은 현재처럼 DMG direct link를 유지한다.
- 사용자 혼선을 줄이기 위해 FAQ, 업데이트 index, v0.1.1 릴리즈 페이지에 단일 universal DMG 문구를 추가한다.

## GitHub 업데이트

- #208 제목: `v0.1.1 Intel Mac 지원과 단일 universal DMG 안내 보강`
- #208 본문:
  - direct DMG 다운로드 유지
  - 선택 UI 제외
  - 단일 universal DMG 기준 문서 영향 범위
  - Sparkle/Homebrew가 단일 public DMG URL을 유지한다는 전제
- v0.1.1 milestone:
  - #208 실행 순서명을 새 제목으로 갱신
  - 완료 기준을 “Pages 다운로드 버튼은 단일 v0.1.1 universal DMG를 바로 내려받고, 안내 문구는 같은 DMG가 Intel Mac과 Apple Silicon Mac을 모두 지원한다고 설명”으로 갱신

## 검증 결과

| 검증 | 결과 |
|------|------|
| `git diff --check` | 통과 |
| `rg -n "alhangeul-macos-0.1.0.dmg\|alhangeul-macos-0.1.1.dmg\|universal DMG\|Intel Mac\|Apple Silicon" docs/...` | 현재 Pages 링크와 universal 안내 위치 확인 |
| `rg -n "다운로드 선택 UI 추가\|다운로드 선택 UI 구현\|선택 UI 추가\|선택 UI 구현\|선택 UI 기준\|선택 UI를 거치\|latest/download/alhangeul-macos-0.1.0.dmg" mydocs docs README.md scripts .github` | 현재 작업 범위에서 obsolete 선택 UI 요구 없음. 과거 완료 task 기록의 v0.1.0 링크 기록은 역사 기록이라 유지 |
| `gh issue view 208 --repo postmelee/alhangeul-macos --json title,body` | 제목과 본문 갱신 확인 |
| `gh api repos/postmelee/alhangeul-macos/milestones/18 -X PATCH ...` | milestone 설명 갱신 완료 |

## main 기준 보정

작업지시자 시각 검증 중 로컬 `docs/`가 GitHub Pages live source인 `main/docs`보다 이전 화면 기준이라는 점을 확인했다. `docs/`를 `origin/main` 기준으로 다시 맞춘 뒤, #208 범위의 v0.1.1 direct DMG 링크와 단일 universal DMG 안내만 재적용했다. 따라서 로컬 서버는 main Pages 화면 구조와 영상/스타일 자산을 유지하면서 #208 변경분만 포함한다.

## 남은 작업

Stage 4에서는 README, GitHub Release body template, v0.1.1 release record, release manuals에 Intel Mac + Apple Silicon 지원과 단일 universal DMG 검증 기준을 반영한다. 이번 Stage 3에서는 Pages direct download 구조와 GitHub issue/milestone 범위 정정을 우선 완료했다.

## Stage 4 승인 요청

Stage 4에서 `README.md`, `scripts/ci/write-release-notes.sh`, `mydocs/release/v0.1.1.md`, release 관련 매뉴얼을 단일 universal DMG/Intel Mac 지원 기준으로 보강한다.
