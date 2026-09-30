# Task #573 최종 결과보고 — 포함 rhwp 배지와 제품 간 홈페이지 링크

- 이슈: [#573](https://github.com/postmelee/alhangeul-macos/issues/573), M020 / GitHub `v0.2`
- 작업: `local/task573` → `publish/task573`, PR 대상 `devel`
- 기준: `origin/devel` `0fa65fa`, 작업일: 2026-09-30 (Asia/Seoul)
- 승인: 최초 요청은 이슈·계획·구현·검증·보고·PR 생성까지였다. 후속 `병합하고 배포해줘` 지시로 PR 병합과 이번 변경의 main 반영·Pages 배포가 추가 승인되었다.
- PR: [#574](https://github.com/postmelee/alhangeul-macos/pull/574). 2026-09-30 사용자 후속 지시로 CI 실패 fixture와 모바일 플랫폼 링크 배치를 보정해 갱신한다.

## 사용자에게 보이는 결과

README 상단의 기존 가운데 정렬 배지에 **bundled rhwp v0.8.6**을 추가했다. 클릭하면 [rhwp v0.8.6 릴리스](https://github.com/edwardkim/rhwp/releases/tag/v0.8.6)로 이동한다. 실제 Shields 이미지 로드·표시와 링크 이동을 브라우저로 확인했다. upstream 최신 버전을 조회하는 배지가 아니라 checkout의 포함 버전이며 기존 공개 릴리스 안내는 유지했다.

native core와 bundled Studio 모두 `v0.8.6`, resolved commit `f1f9c6ae58344ee9368996d3543f76b9345cf227`이다. `rhwp-core.lock`, RustBridge Cargo.toml·Cargo.lock, Studio manifest와 운영 매뉴얼을 대조했다. 버전 자체를 바꾸지 않았다.

홈·소식·문의·업데이트 인덱스·모든 버전별 업데이트 페이지의 총 19개 페이지에서 [Windows / Linux 홈페이지](https://postmelee.github.io/alhangeul-tauri/)로 이동할 수 있다. 데스크톱 헤더에는 **알한글 for Windows / Linux**를 유지한다. 820px 이하에서는 헤더 플랫폼 링크를 숨겨 기존 한 줄·52px 높이를 유지하고, 홈페이지 다운로드 버튼 아래에 **Windows / Linux 버전 보기 →**를 표시한다. 하위 페이지는 기존 푸터, 푸터가 없는 소식 페이지는 하단 외부 콘텐츠 안내 뒤에 같은 보조 링크를 둔다. 화면별로 플랫폼 링크 하나만 보이며, 홈페이지와 하위 페이지의 모바일 링크를 실제 클릭해 URL·제목·내용을 확인했다. 모든 HTML의 CSS cache query를 갱신했고 기존 제품 안내·다운로드 URL은 보존했다.

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
| 19개 페이지의 플랫폼 링크·문구·cache query 및 기존 HTML 내용 보존 | 통과 |
| 브라우저 헤더·플랫폼 링크 위치·문구·URL·문서와 푸터 가로 넘침 | 19개 페이지·88개 조합, 한 줄·52px 헤더와 화면별 링크 하나, 실패 0 |
| 현재 릴리스 버전 안내 gate | v0.2.2 일치 |
| 변경한 두 workflow의 actionlint / 새 Python helper·fixture 문법 | 통과 |
| main/devel 콘텐츠 gate | 통과, main-only 3개 모두 transport-only |
| pin·제품 소스·framework·project.yml 무변경 / diff 공백 검사 | 통과 |

대표 5개 페이지는 320/360/375/520/521/700/701/768/820/821/1024/1440px, 나머지 버전별 페이지는 320/1440px로 확인했다. 데스크톱과 모바일 브라우저 viewport 검증이며 실제 모든 기기·브라우저를 검증한 결과로 확대하지 않는다.

증거: [최종 레이아웃 결과](../working/assets/task_m020_573/mobile-layout.json), [모바일 링크 이동](../working/assets/task_m020_573/mobile-link-navigation.json), [모바일 홈페이지 320px](../working/assets/task_m020_573/home-mobile-320.png), [데스크톱 헤더 1024px](../working/assets/task_m020_573/home-desktop-1024.png), [하위 페이지 푸터 320px](../working/assets/task_m020_573/subpage-footer-320.png), [배지 화면](../working/assets/task_m020_573/readme-badges.png). 단계별 기록: [Stage 1](../working/task_m020_573_stage1.md), [Stage 2](../working/task_m020_573_stage2.md), [Stage 3](../working/task_m020_573_stage3.md). Stage 2의 별도 줄 모바일 헤더 증거는 당시 기록으로 보존하며 최종 배치는 Stage 3.2 결과를 따른다.

## PR CI 실패 보정

첫 head `c895dbdb61648012cb41fcc713dd1f1a66b69378`의 [실패 job 로그](https://github.com/postmelee/alhangeul-macos/actions/runs/36726004622/job/109923088685)를 조회했다. 새 배지·Pages 검증은 성공했으며 기존 Spotlight 재설치 fixture가 `reinstall did not create a new installation object`로 실패했다. Linux에서 birthtime 없이 설치 객체를 비교할 때 삭제 직후 inode가 재사용될 수 있는 테스트 전제를 제거했다. synthetic importer의 이전 inode를 fd로 유지하여 새 copy와 구분하고 cleanup에서 fd를 닫는다. 운영 smoke의 동일 객체 거부 gate는 그대로 두었고 launch 전 실패 경계 검증을 추가했다.

후속 로컬 검증: Spotlight 44개, birthtime 없는 설치 객체 조건의 전체 44개·경계 반복 40개, 동일 CI step의 bundle 5개·release install 25개·release promotion 16개, 배지 10개와 현재 pin 배지·문법·diff 검사 통과. 실제 Linux 로컬 실행은 Docker daemon 부재로 수행하지 않았다. 이후 조회에서 Stage 3.1 head `505a4811d95443170e68a200df5263f2e8dd08d8`의 [PR CI run](https://github.com/postmelee/alhangeul-macos/actions/runs/36727831280)이 성공했고 Linux `Script syntax checks`와 `Release helper checks` 모두 성공한 것을 확인했다. [Stage 3.1·3.2 기록](../working/task_m020_573_stage3.md)에 원인·검증과 최종 모바일 배치를 기록했다. Stage 3.2 push 후 정확한 최종 head의 CI run 링크를 전달하고 완료를 기다리지 않는다.

## 보존과 공개 반영

원래 checkout의 `local/task567` / `7a60448`과 다른 작업자의 변경을 보존했다. rhwp pin, native·Studio 제품 소스, 기능, 릴리즈·설치본, Sparkle·Homebrew·서명·공증 산출물은 변경하지 않았다. 임시 미리보기 HTML·bytecode는 제거했으며 타스크 worktree와 branch는 PR 검토·merge 후 정리에 필요하므로 유지한다.

사용자의 추가 승인에 따라 PR #574의 정확한 head CI 성공 후 merge하고, 이번 타스크 변경만 `main` 기준 별도 PR으로 반영한다. `devel`의 다른 앱 기능 변경을 포함하지 않는다. `main`의 `docs/**` merge로 실행되는 `Docs-only Pages Deploy`가 기존 public appcast를 보존하며 홈페이지를 배포한다. merge·배포 결과와 공개 확인은 최종 응답으로 전달한다.

## Stage 3.3 — 승인된 병합과 문서 배포 준비

공개 `main` 기준 `0cd5e7964c4802ba37fa42caa8088187ea041610`에서 타스크의 5개 커밋만 `cherry-pick -x`로 선별했다. README·홈페이지·배지 유지관리·CI fixture·타스크 기록만 반영하며 source·pin·framework·project.yml·Xcode project는 기존 main과 일치한다. main/source 콘텐츠 gate 통과, 배지 fixture 10개·Pages 14개·소식 UI 9개·현재 릴리스 안내 v0.2.2·README 배지·diff 검증 통과.

배포 전 public appcast를 받아 XML 검증을 완료했다. SHA256은 `8b0face06819d65f60cc6e3675244eaa1cccead997927c1f27c131d523313140`이다. 문서 배포 후 같은 피드의 보존 여부와 공개 홈페이지의 최종 모바일 배치를 확인한다. 앱 버전 태그·GitHub Release·DMG 생성은 이번 홈페이지 배포 범위에 포함하지 않는다.
