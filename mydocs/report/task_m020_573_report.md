# Task #573 최종 결과보고 — 포함 rhwp 배지와 제품 간 홈페이지 링크

- 이슈: [#573](https://github.com/postmelee/alhangeul-macos/issues/573), M020 / GitHub `v0.2`
- 작업: `local/task573` → `publish/task573`, PR 대상 `devel`
- 기준: `origin/devel` `0fa65fa`, 작업일: 2026-09-30 (Asia/Seoul)
- 승인: 사용자 요청에 포함된 이슈·계획·구현·검증·보고·PR 생성. merge·공개 배포 제외.
- PR: [#574](https://github.com/postmelee/alhangeul-macos/pull/574). 2026-09-30 사용자 후속 지시로 CI 실패 fixture를 보정해 갱신한다.

## 사용자에게 보이는 결과

README 상단의 기존 가운데 정렬 배지에 **bundled rhwp v0.8.6**을 추가했다. 클릭하면 [rhwp v0.8.6 릴리스](https://github.com/edwardkim/rhwp/releases/tag/v0.8.6)로 이동한다. 실제 Shields 이미지 로드·표시와 링크 이동을 브라우저로 확인했다. upstream 최신 버전을 조회하는 배지가 아니라 checkout의 포함 버전이며 기존 공개 릴리스 안내는 유지했다.

native core와 bundled Studio 모두 `v0.8.6`, resolved commit `f1f9c6ae58344ee9368996d3543f76b9345cf227`이다. `rhwp-core.lock`, RustBridge Cargo.toml·Cargo.lock, Studio manifest와 운영 매뉴얼을 대조했다. 버전 자체를 바꾸지 않았다.

홈·소식·문의·업데이트 인덱스·모든 버전별 업데이트 페이지의 총 19개 헤더에 **알한글 for Windows / Linux**를 표시한다. 링크는 [Windows / Linux 홈페이지](https://postmelee.github.io/alhangeul-tauri/)로 연결하며 실제 클릭 후 URL·제목·내용을 확인했다. 기존 정적 HTML과 공통 CSS 구조를 유지했고, 820px 이하에서는 추가 링크를 별도 줄로 표시한다. 모든 HTML의 CSS cache query도 갱신했다.

## 다음 동기화 유지관리

`python3 scripts/ci/update-rhwp-readme-badge.py`가 core lock과 Studio manifest에서 배지를 생성한다. 같은 provenance이면 하나, 다르면 native/Studio 표시와 링크를 따로 만든다. commit pin은 짧은 SHA와 전체 commit 링크를 사용한다. PR CI의 `--check`는 오래된 표시·링크를 실패시킨다.

기존 upstream full sync는 core·Studio 갱신·검증 뒤 helper를 실행하고 README를 sync PR에 명시적으로 stage한다. 운영 문서에도 수동 pin 변경 시 갱신 방법을 추가했다. 가상 다음 버전 `v9.8.7`로 표시·릴리스 링크의 동시 갱신을 확인했다. 실제 upstream full sync 빌드·pin 변경은 실행하지 않았다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| 새 배지 CLI·다음 pin·provenance 분리·commit pin·stale·workflow 실행 순서/stage fixture | 10개 통과 |
| 현재 core lock·Cargo dependency/resolved lock·Studio tag/commit 정합성 | 통과 |
| core build info, bundled Studio assets gate | 통과 |
| 기존 Pages 통합 검증 / 소식 UI 검증 | 14개 / 9개 통과 |
| 19개 페이지의 실제 header 문구·링크 정적 검사 | 통과 |
| 브라우저 헤더 잘림·text overflow·겹침·표시·URL | 19개 페이지·88개 조합, 실패 0 |
| 변경한 두 workflow의 actionlint / 새 Python helper·fixture 문법 | 통과 |
| main/devel 콘텐츠 gate | 통과, main-only 3개 모두 transport-only |
| pin·제품 소스·framework·project.yml 무변경 / diff 공백 검사 | 통과 |

대표 5개 페이지는 320/360/375/520/521/700/701/768/820/821/1024/1440px, 나머지 버전별 페이지는 320/1440px로 확인했다. 데스크톱과 모바일 브라우저 viewport 검증이며 실제 모든 기기·브라우저를 검증한 결과로 확대하지 않는다.

증거: [레이아웃 결과](../working/assets/task_m020_573/header-layout.json), [실제 링크 이동](../working/assets/task_m020_573/link-navigation.json), [320px 화면](../working/assets/task_m020_573/home-320.png), [1024px 화면](../working/assets/task_m020_573/home-1024.png), [배지 화면](../working/assets/task_m020_573/readme-badges.png). 단계별 기록: [Stage 1](../working/task_m020_573_stage1.md), [Stage 2](../working/task_m020_573_stage2.md), [Stage 3](../working/task_m020_573_stage3.md).

## PR CI 실패 보정

첫 head `c895dbdb61648012cb41fcc713dd1f1a66b69378`의 [실패 job 로그](https://github.com/postmelee/alhangeul-macos/actions/runs/36726004622/job/109923088685)를 조회했다. 새 배지·Pages 검증은 성공했으며 기존 Spotlight 재설치 fixture가 `reinstall did not create a new installation object`로 실패했다. Linux에서 birthtime 없이 설치 객체를 비교할 때 삭제 직후 inode가 재사용될 수 있는 테스트 전제를 제거했다. synthetic importer의 이전 inode를 fd로 유지하여 새 copy와 구분하고 cleanup에서 fd를 닫는다. 운영 smoke의 동일 객체 거부 gate는 그대로 두었고 launch 전 실패 경계 검증을 추가했다.

후속 로컬 검증: Spotlight 44개, birthtime 없는 설치 객체 조건의 전체 44개·경계 반복 40개, 동일 CI step의 bundle 5개·release install 25개·release promotion 16개, 배지 10개와 현재 pin 배지·문법·diff 검사 통과. 실제 Linux 로컬 실행은 Docker daemon 부재로 수행하지 않았으며 Linux CI 완료 여부로 일반화하지 않는다. [Stage 3.1 기록](../working/task_m020_573_stage3.md)에 원인·범위·검증을 기록했다. push 후 정확한 새 head의 CI run 링크를 최종 응답으로 전달하고 완료를 기다리지 않는다.

모바일 헤더 링크의 소개 영역·공통 푸터 이동 제안은 아직 구현되지 않았다. 이번 후속 보정은 CI fixture에 한정한다.

## 보존과 공개 반영

원래 checkout의 `local/task567` / `7a60448`과 다른 작업자의 변경을 보존했다. rhwp pin, native·Studio 제품 소스, 기능, 릴리즈·설치본, Sparkle·Homebrew·서명·공증 산출물은 변경하지 않았다. 임시 미리보기 HTML·bytecode는 제거했으며 타스크 worktree와 branch는 PR 검토·merge 후 정리에 필요하므로 유지한다.

`devel` 대상 Open PR 검토·merge가 남아 있다. 공개 README와 홈페이지 반영은 별도 승인된 main 반영·Pages 문서 배포가 필요하다. 이 타스크에서 merge·이슈 close·공개 배포는 수행하지 않는다. PR CI의 run 링크는 생성 후 최종 응답으로 전달하고 Actions 완료는 기다리지 않는다.
