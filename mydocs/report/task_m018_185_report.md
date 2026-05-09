# Task M018 #185 최종 결과 보고서

## 작업 요약

- 이슈: [#185](https://github.com/postmelee/alhangeul-macos/issues/185) GitHub Release/Pages 업데이트 본문 템플릿과 생성 스크립트 고도화
- 마일스톤: M018 / `v0.1.1`
- 통합 대상: `devel-webview`
- 작업 브랜치: `local/task185`
- 단계: Stage 1~4 완료, Stage 4.1 Pages branch 기준 보정, Stage 5 매뉴얼 통합과 최종 dry-run 완료, Stage 6 릴리즈 배포 매뉴얼 컨텍스트 분리 완료

GitHub Release 본문, Pages 업데이트 페이지, README 최신 릴리즈 블록, `mydocs/release/` 장기 기록, 배포 매뉴얼이 같은 버전/DMG/SHA256/provenance 기준을 쓰도록 정리했다. 이후 `release_distribution_guide.md`를 entrypoint로 줄이고 주제별 하위 매뉴얼을 분리해 AI agent가 필요한 컨텍스트만 읽을 수 있게 했다. 이번 작업은 release communication과 검증 기준 마련이 범위이며, public DMG 생성, GitHub Release 게시, Sparkle appcast 게시, Homebrew tap 배포는 수행하지 않았다.

`docs/updates/v0.1.0.html`의 현재 양식과 디자인은 유지했다. `v0.1.1` Pages 후보는 같은 header, hero, action button, content section, footer 구조를 재사용하고, 운영 상세는 GitHub Release 본문과 `mydocs/release/v0.1.1.md`로 분리했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `scripts/ci/write-release-notes.sh` | GitHub Release 본문 후보 template 보강, 설치/첫 실행/업데이트/provenance/검증/known limitations 섹션 포함 |
| `scripts/ci/check-release-notes-template.sh` | release note 필수 heading 누락을 확인하는 검증 helper 추가 |
| `scripts/ci/write-release-delta-checklist.sh` | 직전 공개 릴리즈 대비 변경 파일을 영향 영역별 checklist 초안으로 분류하는 helper 추가 |
| `docs/updates/v0.1.1.html` | `v0.1.0` 양식을 유지한 `v0.1.1` Pages 후보 작성 |
| `docs/updates/index.html` | 최신 릴리즈 항목과 latest DMG 링크를 `v0.1.1` 기준으로 갱신 |
| `README.md` | 현재 작업 축, 최신 공개 릴리즈 1개, 실제 릴리즈 목록 링크, `v0.1.x` 구현 범위와 제한 사항 기준 정리 |
| `mydocs/tech/product_roadmap_notes.md` | 상세 로드맵과 README 표현 기준 분리 |
| `mydocs/release/index.md` | 릴리즈 기록 폴더의 역할, 릴리즈 목록, 정보 소유 기준 작성 |
| `mydocs/release/v0.1.0.md` | 실제 공개 `v0.1.0` release decision record와 SHA256/provenance 기록 |
| `mydocs/release/v0.1.1.md` | `v0.1.1` release candidate 기록 초안과 #188 public smoke handoff 작성 |
| `mydocs/tech/release_environment.md` | Team ID, signing identity 표시명, notary profile name, GitHub Actions 변수/secret 이름 같은 환경 식별자 분리 |
| `mydocs/manual/document_structure_guide.md` | `mydocs/release/`, release environment, troubleshooting, 릴리즈 매뉴얼 분리 기준 추가 |
| `mydocs/manual/release_distribution_guide.md` | 릴리즈 작업 entrypoint, 안전 게이트, 하위 문서 맵, 전체 flow, 최종 체크리스트로 축소 |
| `mydocs/manual/release_policy_guide.md` | 운영 기준, 배포 브랜치, public 배포 수준, artifact/provenance, 알려진 한계 분리 |
| `mydocs/manual/release_packaging_dmg_guide.md` | build 검증, 개발용 zip, public/rehearsal DMG, DMG layout, Finder smoke 분리 |
| `mydocs/manual/release_signing_notarization_guide.md` | Developer ID, notarytool, credential 기록 금지, signing/notarization 검증 분리 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | GitHub Release body, delta checklist, Pages, Sparkle appcast 분리 |
| `mydocs/manual/release_homebrew_cask_guide.md` | Homebrew Cask source, SHA256 교체, tap 반영, audit 분리 |
| `.github/workflows/release-publish.yml` | 실제 GitHub Pages source와 맞게 `ALHANGEUL_PAGES_BRANCH` fallback을 `main`으로 보정 |
| `mydocs/plans/task_m018_185.md` | 수행계획서 작성 |
| `mydocs/plans/task_m018_185_impl.md` | 5단계 구현계획서 작성과 Stage 4.1 보정 반영 |
| `mydocs/working/task_m018_185_stage1.md` | 릴리즈 communication 정보 소유 경계 보고 |
| `mydocs/working/task_m018_185_stage2.md` | GitHub Release template 보강 보고 |
| `mydocs/working/task_m018_185_stage3.md` | Pages/README 기준 정리 보고 |
| `mydocs/working/task_m018_185_stage4.md` | release 기록과 delta checklist 기준 보고 |
| `mydocs/working/task_m018_185_stage6.md` | 릴리즈 배포 매뉴얼 컨텍스트 분리 보고 |
| `mydocs/orders/20260510.md` | 오늘할일 완료 처리 |

제품 runtime source, Rust bridge, `rhwp-core.lock`, bundled `rhwp-studio` asset은 수정하지 않았다.

## 주요 결정

| 항목 | 결정 |
|------|------|
| GitHub Release | 운영 상세와 긴 provenance, SHA256, 검증 결과, delta checklist를 담는 primary release body로 둔다 |
| Pages 업데이트 페이지 | 사용자용 요약, 설치/업데이트 안내, 주요 변경, 알려진 제한 사항을 간결하게 제공한다 |
| README | 최신 공개 릴리즈 1개와 현재 구현 범위만 요약하고, 과거 릴리즈 상세는 `mydocs/release/`와 GitHub Release로 넘긴다 |
| `mydocs/release/` | 릴리즈별 decision record, 검증 기록, Pages/GitHub Release/appcast 링크를 누적한다 |
| 배포 매뉴얼 | entrypoint와 주제별 하위 매뉴얼로 나누고, 버전별 결정과 환경 식별자는 release/tech 문서로 분리한다 |
| troubleshooting | 실패 증상, 재현 조건, 원인, 예방 절차가 있는 문제 해결 문서에만 사용한다 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| release note generator syntax | OK | `bash -n scripts/ci/write-release-notes.sh` 통과 |
| release note template check syntax | OK | `bash -n scripts/ci/check-release-notes-template.sh` 통과 |
| delta checklist helper syntax | OK | `bash -n scripts/ci/write-release-delta-checklist.sh` 통과 |
| release note dry-run 생성 | OK | `scripts/ci/write-release-notes.sh 0.1.1 ... build.noindex/release/release-notes-0.1.1.md` 통과 |
| release note 필수 heading 검증 | OK | `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1.md` 통과 |
| delta checklist dry-run 생성 | OK | `scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md` 통과 |
| Pages 후보 구조 유지 | OK | Stage 3에서 `v0.1.0`/`v0.1.1`의 `updates-hero`, `updates-content`, `updates-section`, `page-action-button`, `site-footer` 구조 대조 |
| Pages 후보 브라우저 확인 | OK | Stage 3에서 로컬 정적 서버로 `docs/updates/index.html`, `docs/updates/v0.1.0.html`, `docs/updates/v0.1.1.html` 확인 |
| GitHub Pages branch 기준 | OK | GitHub Pages source가 `main`/`docs`, release environment `ALHANGEUL_PAGES_BRANCH=main`임을 확인하고 workflow fallback 보정 |
| release guide 버전 중립화 | OK | `release_distribution_guide.md`에서 `v0.1`, `0.1.0`, 특정 Team ID/signing identity/notary profile hard-code 검색 결과 없음 |
| release guide 컨텍스트 분리 | OK | entrypoint 113줄, 하위 매뉴얼 72~240줄로 분리 |
| release guide 하위 링크 | OK | `release_distribution_guide.md`와 `document_structure_guide.md`에서 하위 매뉴얼 링크 확인 |
| 하위 매뉴얼 guardrail | OK | 명시 승인, 민감 정보 기록 금지, public release guardrail 키워드 확인 |
| whitespace 검사 | OK | `git diff --check` 통과 |

Stage 5의 version/provenance 대조 명령은 release note 후보, Pages, README, `mydocs/release/`, `mydocs/tech/`, 배포 매뉴얼에서 `v0.1.1`, `alhangeul-macos-0.1.1.dmg`, `SHA256`, `Quick Look`, `Thumbnail`, `Sparkle`, `provenance` 표현을 확인했다.

## #188 release handoff

[#188](https://github.com/postmelee/alhangeul-macos/issues/188) `v0.1.1 patch release 준비와 public 배포 실행`에서 다음 값을 실제 public release 기준으로 확정한다.

| 항목 | #188 확인 기준 |
|------|----------------|
| 버전 | `CFBundleShortVersionString=0.1.1`, `CFBundleVersion=2` 이상 |
| GitHub Release | `https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.1` public release body와 asset 확인 |
| Pages index | `https://postmelee.github.io/alhangeul-macos/updates/` 최신 항목과 latest DMG link 확인 |
| Pages release note | `https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html` 공개 반영 확인 |
| Sparkle appcast | `https://postmelee.github.io/alhangeul-macos/appcast.xml` stable item, DMG URL, EdDSA signature 확인 |
| DMG asset | `alhangeul-macos-0.1.1.dmg` public DMG 생성, upload, SHA256 기록 |
| Homebrew Cask | public DMG SHA256 고정 여부와 tap 공개 여부 결정 |
| release detail | `mydocs/release/v0.1.1.md`의 TBD와 후보 표현을 실제 결과로 보정 |

반복할 public smoke:

1. signed/notarized public DMG 생성 후 `spctl`, `stapler`, checksum 검증을 기록한다.
2. DMG root 구성, 720x460 PNG background, Applications drag 안내, 첫 실행 안내를 public DMG에서 다시 확인한다.
3. `/Applications/Alhangeul.app` 설치본으로 `KTX.hwp`, `hwpx-01.hwpx` window zoom/resize smoke를 반복한다.
4. HWP/HWPX Quick Look preview와 Finder thumbnail 생성 확인을 public 설치본으로 반복한다.
5. GitHub Release 본문이 `scripts/ci/write-release-notes.sh` template의 필수 heading과 실제 SHA256/provenance를 포함하는지 확인한다.
6. `write-release-delta-checklist.sh v0.1.0 <release-candidate-ref>` 결과를 release owner가 수동 보정해 public smoke checklist로 사용한다.
7. Sparkle manual update flow는 stable appcast 공개 후 별도 설치본에서 확인한다.

## 잔여 위험

- `v0.1.1` Pages, README, release detail 문서는 public release 전 후보 상태다. 실제 public DMG SHA256, appcast EdDSA signature, Homebrew Cask SHA256은 #188에서 확정해야 한다.
- release delta helper는 path 기반 초안 생성기다. 사용자 영향, 수동 smoke 필요 여부, 누락된 의미 변경은 release owner가 보정해야 한다.
- GitHub Release와 Pages의 실제 공개 URL은 #188 release 게시와 GitHub Pages build가 끝난 뒤에만 최종 확인할 수 있다.
- Homebrew Cask는 아직 `sha256 :no_check` 초안 상태다. public DMG가 업로드되기 전에는 사용자 설치 경로로 안내하지 않는다.

## PR 게시 전 상태

- `local/task185`에는 Stage 1~6 산출물이 포함된다.
- 이번 작업은 public release 실행 권한이 필요한 작업을 수행하지 않았다.
- 최종 보고 승인 후 `publish/task185` 브랜치를 게시하고 `devel-webview` 대상으로 PR을 생성한다.

## 작업지시자 승인 요청

본 보고서 기준으로 Task #185의 구현과 검증을 완료했다. 승인 후 PR 게시 절차로 넘어간다.
