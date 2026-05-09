# Task M018 #208 최종 결과 보고서

## 작업 요약

- 이슈: [#208](https://github.com/postmelee/alhangeul-macos/issues/208) `v0.1.1 Intel Mac 지원과 단일 universal DMG 안내 보강`
- 마일스톤: M018 / `v0.1.1`
- 통합 대상: `devel-webview`
- 작업 브랜치: `local/task208`
- 단계: 계획 수립, Stage 1 현황 재검증, Stage 2 universal build gate 구현, Stage 3 Pages direct download 안내 보강, Stage 3.1 main Pages 기준 보정, Stage 4 release 문서/template 보강, Stage 5 통합 검증 완료

`v0.1.1` public release 전에 앱 본체와 Quick Look/Thumbnail extension 실행 파일이 `arm64 + x86_64` universal 기준을 만족하도록 release/package build gate를 추가했다. 배포 정책은 Intel Mac용 DMG와 Apple Silicon용 DMG를 나누지 않고, 단일 `alhangeul-macos-<version>.dmg`를 유지하는 방향으로 확정했다.

GitHub Pages는 아키텍처 선택 UI를 만들지 않고 기존 direct DMG 다운로드 버튼을 유지한다. 대신 홈 FAQ, 업데이트 index, `v0.1.1` 릴리즈 페이지, README, GitHub Release note template, release 기록, 배포 매뉴얼에 “Intel Mac과 Apple Silicon Mac이 같은 universal DMG를 사용한다”는 기준을 반영했다.

이번 작업은 public release 실행 전 준비 작업이다. signed/notarized public DMG 생성, GitHub Release 게시, Sparkle stable appcast 게시, Homebrew tap 공개 배포는 각각 #188/#209 범위로 남겼다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `scripts/ci/verify-universal-macos-app.sh` | `Alhangeul.app`, `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex` 실행 파일이 `arm64 + x86_64` slice를 모두 포함하는지 검증하는 공통 helper 추가 |
| `scripts/package-release.sh` | Release build에 `generic/platform=macOS`, `ARCHS="arm64 x86_64"`, `ONLY_ACTIVE_ARCH=NO`를 적용하고 package staging app에 universal 검증 gate 연결 |
| `scripts/release.sh` | public/rehearsal release build 양쪽에 universal build setting과 검증 gate 연결 |
| `docs/index.html` | 다운로드 버튼을 `v0.1.1` latest DMG로 갱신하고 FAQ에 단일 universal DMG 안내 추가 |
| `docs/updates/index.html` | 업데이트 페이지의 최신 다운로드와 설명을 `v0.1.1` 단일 DMG 기준으로 갱신 |
| `docs/updates/v0.1.1.html` | v0.1.1 릴리즈 페이지에 universal app/extension 검증과 단일 DMG 설치 안내 추가 |
| `docs/updates/v0.1.0.html` | 과거 릴리즈 다운로드 링크를 `v0.1.0` tag 고정 URL로 정리 |
| `docs/appcast.xml`, `docs/assets/**`, `docs/script.js`, `docs/styles.css` | GitHub Pages live source인 `main/docs` 기준으로 보정해 현재 사이트 구조와 feature 영상 자산 유지 |
| `README.md` | v0.1.1 후보 설명과 Release / Install 섹션에 Intel Mac/Apple Silicon 단일 universal DMG 기준 추가 |
| `scripts/ci/write-release-notes.sh` | GitHub Release body 후보에 지원 환경/아키텍처, 단일 DMG, Homebrew/Sparkle 전제, Intel smoke 기록 기준 추가 |
| `scripts/ci/check-release-notes-template.sh` | `## 지원 환경과 아키텍처` 필수 heading 검증 추가 |
| `mydocs/release/v0.1.1.md` | #208 변경점, universal 검증, #188 public smoke handoff, #209 Homebrew handoff 반영 |
| `mydocs/manual/release_policy_guide.md` | public DMG를 단일 universal DMG로 운영하고 Pages/Sparkle/Homebrew가 같은 URL을 쓰는 정책 추가 |
| `mydocs/manual/release_packaging_dmg_guide.md` | release/package/public/rehearsal 경로에서 app/extension `arm64 + x86_64` 검증 기준 추가 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | Pages direct download, Sparkle enclosure, Homebrew Cask 안내가 단일 universal DMG 기준임을 명시 |
| `mydocs/manual/release_distribution_guide.md` | release flow와 최종 checklist에 universal slice 검증과 Intel smoke 기록 기준 추가 |
| `mydocs/manual/ci_workflow_guide.md` | release checks 재현과 rehearsal/publish workflow 설명에 universal 검증 기준 추가 |
| `mydocs/manual/release_homebrew_cask_guide.md` | Cask가 `on_arm`/`on_intel` 분기 없이 같은 public universal DMG URL/SHA256을 사용한다는 기준 추가 |
| `mydocs/plans/task_m018_208.md` | 수행계획서 작성과 Stage 3 범위 조정 반영 |
| `mydocs/plans/task_m018_187.md` | Homebrew Cask 전제를 단일 universal DMG URL 기준으로 정정 |
| `mydocs/working/task_m018_208_stage1.md` ~ `task_m018_208_stage5.md` | 단계별 조사, 구현, 문서 보정, 통합 검증 보고 |
| `mydocs/orders/20260510.md` | #208 오늘할일 완료 처리 |

제품 runtime Swift source, Rust FFI ABI, `rhwp-core.lock`, bundled `rhwp-studio` asset은 수정하지 않았다.

## 주요 결정

| 항목 | 결정 |
|------|------|
| 배포 asset | `alhangeul-macos-<version>.dmg` 단일 파일 유지 |
| 지원 architecture | app 본체와 Quick Look/Thumbnail extension 실행 파일이 `arm64 + x86_64` slice를 포함해야 함 |
| Pages UX | Intel/Apple Silicon 선택 UI를 만들지 않고 direct DMG 다운로드 유지 |
| Sparkle | appcast enclosure는 tag 고정 단일 universal DMG URL 사용 |
| Homebrew | Cask는 `on_arm`/`on_intel` 분기 없이 같은 public DMG URL/SHA256 사용 |
| Intel 실기기 smoke | 실행한 경우에만 성공으로 기록하고, 미실행 시 #188 handoff에 사유 기록 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 기존 문제 재현 | OK | Stage 1에서 기존 release app/extension 실행 파일이 arm64-only임을 확인 |
| generic macOS Release build | OK | Stage 1/2에서 `-destination generic/platform=macOS` build가 세 실행 파일 모두 `x86_64 arm64` 생성 확인 |
| universal helper 정상/실패 판정 | OK | universal app은 통과, 기존 arm64-only app은 예상 실패 |
| package script gate | OK | Stage 2에서 `ALHANGEUL_BUILD_ROOT=/private/tmp/alhangeul-task208-package scripts/package-release.sh 0.1.0` 통과 |
| 현 HEAD package 검증 | OK | Stage 5에서 `ALHANGEUL_BUILD_ROOT=/private/tmp/alhangeul-task208-stage5-package scripts/package-release.sh 0.1.1` 통과 |
| 현 HEAD app/extension architecture | OK | `Alhangeul`, `AlhangeulPreview`, `AlhangeulThumbnail` 모두 `x86_64 arm64` |
| release script syntax | OK | `bash -n scripts/package-release.sh scripts/release.sh scripts/ci/*.sh` 통과 |
| `project.yml` parse | OK | `ruby -e 'require "psych"; Psych.parse_file("project.yml")'` 통과. 로컬 Ruby의 `ffi-1.13.1` extension 경고는 있었지만 parse는 성공 |
| release note dry-run | OK | `scripts/ci/write-release-notes.sh 0.1.1 <dummy-sha> build.noindex/release/release-notes-0.1.1-stage5.md` 통과 |
| release note heading check | OK | `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1-stage5.md` 통과 |
| Sparkle appcast dry-run | OK | `scripts/ci/write-sparkle-appcast.sh ... --output build.noindex/release/appcast-stage5.xml`와 `xmllint --noout` 통과 |
| Pages 정적 확인 | OK | 로컬 서버 `http://127.0.0.1:8765/`에서 v0.1.1 direct DMG 링크, 단일 DMG 안내, main 기준 feature 자산 확인 |
| obsolete 선택 UI 요구 제거 | OK | 검색 결과 남은 항목은 “선택 UI 없이 단일 DMG” 정책 문구 또는 과거 v0.1.0 고정 링크로 확인 |
| whitespace check | OK | `git diff --check` 통과 |

현 HEAD package 산출물:

```text
/private/tmp/alhangeul-task208-stage5-package/release/Alhangeul.app
/private/tmp/alhangeul-task208-stage5-package/release/alhangeul-macos-0.1.1.zip
SHA256: cddb79e149463e17c6e642ad562ca62392b69af28779b1af57412cdca805649f
```

참고로 `build.noindex/release/Alhangeul.app`는 #208 수정 전 생성된 stale arm64-only 산출물이라 universal helper가 실패했다. 현재 검증 기준은 Stage 5에서 새로 생성한 `/private/tmp/alhangeul-task208-stage5-package/release/Alhangeul.app`다.

## GitHub 작업

- #208 제목과 본문을 단일 universal DMG 정책으로 갱신했다.
- M018 `v0.1.1` milestone 설명의 실행 순서, 순서 원칙, 완료 기준을 direct DMG + universal 안내 기준으로 갱신했다.
- GitHub Pages source가 `main/docs`임을 확인하고, 로컬 `docs/`를 `origin/main/docs` 기준으로 보정한 뒤 #208 변경분만 재적용했다.

## #188 release handoff

[#188](https://github.com/postmelee/alhangeul-macos/issues/188) `v0.1.1 patch release 준비와 public 배포 실행`에서 다음을 반복해야 한다.

1. `scripts/release.sh 0.1.1` 또는 `Release Publish DMG` workflow로 signed/notarized public DMG를 생성한다.
2. public DMG 내부 `Alhangeul.app`, `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex` 실행 파일이 `arm64 + x86_64`인지 다시 확인한다.
3. public DMG SHA256을 기록한다.
4. signed/notarized public DMG의 `stapler`, `spctl`, checksum 검증을 기록한다.
5. Finder Quick Look/Thumbnail 설치본 smoke를 public DMG 설치본으로 반복한다.
6. 실제 Intel Mac 실기기 smoke를 실행했는지, 실행하지 못했으면 왜 못 했는지 release report에 남긴다.
7. Pages latest download, Sparkle appcast enclosure, GitHub Release asset URL이 같은 public DMG 기준인지 확인한다.

## #209 Homebrew handoff

[#209](https://github.com/postmelee/alhangeul-macos/issues/209) Homebrew 공개 배포에서는 다음을 지킨다.

1. #188에서 확정된 public universal DMG URL과 SHA256만 Cask에 사용한다.
2. `on_arm`/`on_intel`로 서로 다른 DMG URL을 나누지 않는다.
3. `postmelee/homebrew-tap` tap context에서 `brew style --cask`, `brew audit --cask`, install/uninstall smoke를 수행한다.
4. tap 검증 완료 전에는 README, Pages, GitHub Release/릴리즈 노트에 Homebrew 설치 명령을 확정 설치 경로로 안내하지 않는다.

## 잔여 위험

- 이번 작업은 binary slice 존재와 release/package gate를 검증했다. 실제 Intel Mac 실기기 실행은 현재 환경에서 수행하지 않았고 #188 public smoke로 넘긴다.
- signed/notarized public DMG와 Gatekeeper 검증은 #188에서만 최종 확인할 수 있다.
- Sparkle EdDSA signature, public DMG SHA256, Homebrew Cask SHA256은 실제 public release asset이 생성된 뒤에 확정된다.
- GitHub Pages는 `main/docs` branch publishing 기준이다. release publish 시 Pages/appcast 반영 후 실제 공개 URL을 다시 확인해야 한다.

## PR 게시 전 상태

- `local/task208`에는 계획서, Stage 1~5 보고서, 최종 보고서, 구현/문서 변경이 포함된다.
- public release 실행, GitHub Release 게시, Sparkle stable appcast 게시, Homebrew tap 공개는 수행하지 않았다.
- 최종 보고 승인 후 `publish/task208` 브랜치를 게시하고 `devel-webview` 대상으로 PR을 생성한다.

## 작업지시자 승인 요청

본 보고서 기준으로 Task #208의 구현과 검증을 완료했다. 승인 후 PR 게시 절차로 넘어간다.
