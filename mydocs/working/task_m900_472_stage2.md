# Task M900 #472 Stage 2 완료보고서

## 단계 목적

`v0.1.9..candidate`에 새로 포함되는 merge PR을 PR body, 연결 Issue, 최종 보고서와 upstream release note로 직접 분류하고, `v0.1.10 (16)` / `rhwp v0.8.4` 기준의 release record, README와 Pages communication을 작성한다.

이번 단계는 release communication source 작성까지만 수행했다. Source preflight, Release Rehearsal/Publish workflow, 원격 branch push, PR 생성·merge, tag, GitHub Release, Pages deploy, stable appcast와 Homebrew mutation은 수행하지 않았다.

## Stage 시작 기준선

조회 시각은 `2026-08-13 16:51 KST`다.

| 항목 | 확인 결과 |
|------|-----------|
| Stage 2 분석 HEAD | `58424de31051007c2f185410f47ef090680c4ad9` |
| previous release ref / commit | `v0.1.9` / `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| `origin/main` | `26f3104469135c5e80b3a19dddb9d0baebfbfb0a` |
| `origin/devel` | `4abdc30746edcd25be3d11fa3d5c1e09f600c6c3` |
| `origin/main...origin/devel` | main 전용 3 / devel 전용 68 |
| latest public app | `v0.1.9`, non-draft / non-prerelease |
| latest upstream | `rhwp v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| 열린 PR | Draft #462 한 건, Task #472 명시 제외 범위 |
| release-critical 열린 PR | 없음 |

Stage 1 이후 `origin/devel`, 최신 public app과 upstream release는 이동하지 않았다. 따라서 승인된 `v0.1.9..58424de...` 범위와 release identity를 유지했다.

## 분석 자료

다음 helper 초안을 `build.noindex/task472-stage2/`에 생성했다.

- `pr-analysis-v0.1.10.md`
  - 9개 first-parent merge PR
  - PR title/body의 closing/related Issue
  - 변경 path와 최종 보고서 후보
- `delta-checklist-v0.1.10.md`
  - HostApp viewer
  - Quick Look/Thumbnail
  - 저장/PDF/인쇄/공유
  - Sparkle/Pages와 release workflow
  - core/studio provenance
  - 문서·수동 분류 대상
- `release-notes-v0.1.10.md`
  - GitHub Release body 구조
  - 구조 검증용 64자리 0 checksum

helper 출력은 분류 초안으로만 사용했다. PR #454, #457, #458, #461, #464, #465, #468과 #471의 실제 body/files, 관련 Issue 상태, 대응 최종 보고서를 확인했다. upstream `rhwp v0.8.3`과 `v0.8.4` release body도 직접 읽어 알한글에 포함되는 누적 변화와 v0.8.4 배포 채널 정책 보정을 분리했다.

## 포함 PR owner 판정

| PR | 최종 분류 | 사용자-facing | 공개 요약 | 근거 |
|----|-----------|---------------|-----------|------|
| #471 | upstream sync | 예 | 반영 | v0.8.4 core/studio same-commit sync, upstream v0.8.3·v0.8.4 note |
| #468 | 사용자-facing 호환·검증 | 예 | 반영 | v0.8.4 `dirty` 제거 시 native render tree nil 재현·보정 |
| #465 | 개발자-facing provenance | 아니오 | 주요 요약 제외 | target checkout root `Cargo.lock` actual fingerprint gate |
| #464 | 개발자-facing sync/release gate | 아니오 | 주요 요약 제외 | canonical build-info writer/verifier와 release block |
| #461 | 사용자-facing 보안·안정성 | 예 | 반영 | PDF·인쇄 script/resource/navigation 차단과 정상 출력 보존 |
| #458 | 사용자-facing 기능 | 예 | 반영 | current page SVG 기반 전체 페이지 PDF·인쇄 |
| #457 | 사용자-facing 기능 | 예 | 반영 | HWP/HWPX 형식별 저장, 후속 저장과 재열기 |
| #454 | 사용자-facing 개인정보·운영 | 예 | 반영 | 영구 식별자 없는 payload, nonblocking outbox와 opt-out |
| #451 | 이전 release closeout | 아니오 | 제외 | v0.1.9 official/Homebrew 종료 기록 |

### 해결된 Issue

다음 Issue는 PR merge 뒤 Closed 상태임을 live 조회로 확인했다.

- #453 익명 실행·버전 전환 event
- #456 HWP/HWPX native 저장
- #455 page SVG native PDF
- #460 PDF·인쇄 WebKit hardening
- #439 generated build-info sync/release gate
- #375 upstream root Cargo.lock fingerprint gate
- #467 v0.8.4 Swift decoder compatibility

### 참고/연관 Issue

다음 Issue는 Open 상태이며 이번 release가 완료했다고 서술하지 않는다.

- #459 PDF·인쇄 lifecycle 중복/stale callback
- #469 producer-backed render-tree golden
- #470 known payload decode 진단과 unknown variant 구분

helper가 후보로 제시한 #142와 #388은 이전 작업에서 이미 완료된 선행 Issue이므로 public `참고/연관 Issue`에서 다시 나열하지 않았다.

## 공개 문구 결정

### 변경 요약

1. HWP/HWPX 형식별 저장과 같은 형식 재열기
2. 현재 편집 상태의 전체 페이지 searchable PDF와 native 인쇄
3. PDF·인쇄 문서 SVG의 script, 외부 resource와 navigation 차단
4. `rhwp v0.8.4` 암호 문서·중첩 표·특수 글리프·대형 문서 보강
5. 영구 사용자·기기 식별자 없는 익명 실행 추이와 개인정보 opt-out

### 기술 세부로 분리한 항목

- `RhwpCoreBuildInfo` deterministic writer와 canonical verifier
- target upstream root `Cargo.lock` actual fingerprint 비교
- decoder current/legacy envelope와 TextRun fixture
- workflow change classification과 sync body gate
- Stage 1 version/build와 workflow default 변경
- strict/portable static archive 판정 절차

이 항목들은 사용자 기능으로 과장하지 않고 release 안정성·provenance 근거에만 기록했다.

### rhwp 변화 범위

upstream v0.8.3의 누적 문서 변화 중 알한글 core/studio에 직접 관련된 다음 항목만 public summary에 반영했다.

- HWP5 EncryptVersion 4, HWP3와 암호화 HWPX 열기·저장·재열기
- 중첩 표 page split, cell flow, bottom border
- 표 내부 selection/copy/format/resize
- PUA 사각 번호와 작은 오른쪽 삼각형 glyph
- deflate 상한과 대형 표 처리 보강

MCP/에이전트 schema, 공식 CLI archive, package registry 등 알한글 앱과 직접 무관한 upstream 배포 항목은 사용자 요약에서 제외했다. v0.8.4는 v0.8.3에서 의도치 않게 켜진 일부 배포 채널을 철회한 patch임을 기술해, 앱 문서 기능 변경과 upstream distribution policy를 혼동하지 않게 했다.

## 변경 파일과 의도

### 최신 release surface

- `README.md`
  - 최신 release를 `v0.1.10`으로 갱신
  - HWP/HWPX 저장, PDF·인쇄와 renderer 경로의 stale 설명 보정
  - bundled studio를 `v0.8.4`로 정렬
- `docs/index.html`
  - download URL을 `v0.1.10` DMG로 갱신
  - HWPX 저장 제한 안내를 형식별 저장과 fidelity 경계로 교체
- `docs/updates/index.html`
  - `v0.1.10` download와 release entry 추가
  - Homebrew는 public DMG digest 확정 전 별도 gate로 표시
- `docs/updates/v0.1.10.html`
  - 사용자용 변경 요약, rhwp/app 변화, 한계와 설치 안내 작성
- `mydocs/release/index.md`
  - `v0.1.10`을 `후보 · Stage 2 완료`로 추가
- `mydocs/release/v0.1.10.md`
  - release identity, owner 판정, GitHub body 후보, gate와 limitations 기록

### 이전 release notice

`scripts/ci/update-release-version-notices.sh`로 `v0.1.0`부터 `v0.1.9` page까지 최신 `v0.1.10` 안내를 정렬했다. 이전 page 본문이나 당시 release 설명은 수정하지 않았다.

### Release note helper 보정

`scripts/ci/write-release-notes.sh`의 고정 `알려진 제한 사항`이 현재 구현과 달랐다.

- 변경 전: PDF를 Quick Look/Thumbnail과 같은 Rust/Swift native renderer로 설명하고 인쇄를 별도 경로로 설명
- 변경 후: PDF와 인쇄가 editor page SVG + script-disabled WKWebView/PDFKit/AppKit 경로를 공유하고, Quick Look/Thumbnail은 별도 native renderer임을 설명
- 추가: HWP/HWPX 저장 fidelity 경계와 전체 page SVG memory/progress/deadline 제한

release generator가 v0.1.9 이전 renderer 구조를 public note에 재게시하지 않도록 Stage 2 communication 범위에서 필요한 최소 보정을 적용했다.

## 검증 결과

### Release helper

- `write-release-pr-analysis.sh v0.1.9 HEAD`: 9개 merge PR 초안 생성
- `write-release-delta-checklist.sh v0.1.9 HEAD`: 영향 영역 초안 생성
- `write-release-notes.sh 0.1.10 <zero-checksum>`: GitHub Release body 생성
- `check-release-notes-template.sh`: v0.1.10 body 통과
- `validate-github-body.sh`: PR 분석과 v0.1.10 body 통과
- CI 고정 fixture `0.1.5` release note 재생성·template·body 검증 통과
- `bash -n scripts/ci/write-release-notes.sh`: 통과

64자리 0 checksum은 Stage 2 template 구조 검증용이다. draft/public DMG SHA256으로 기록하거나 외부에 게시하지 않는다.

### Version notice와 identity

- `update-release-version-notices.sh --check`: latest `v0.1.10` 기준 통과
- README, Pages, release index/record의 version: `0.1.10`
- app/extension build: `16`
- previous release: `v0.1.9`
- core/studio: `v0.8.4` / `496333b...`
- GitHub Release title 후보: `Alhangeul v0.1.10 (rhwp v0.8.4)`

### Diff 품질

- 이전 release page는 latest notice block만 기계적으로 변경
- 새 v0.1.10 page는 기존 update page의 header/footer/section 구조를 유지
- `git diff --check`: 통과
- workflow, app source, core lock, bundled studio asset과 Cask 변경 없음

로컬의 legacy `xmllint`/`tidy`는 기존 page에도 사용하는 HTML5 semantic element(`header`, `nav`, `main`, `section`)를 인식하지 않아 validation gate로 사용하지 않았다. 새 page는 repository의 기존 v0.1.9 page 구조, version notice helper와 source diff 검토를 기준으로 확인했다.

## 잔여 위험

- Stage 2 공개 문구는 기존 PR 검증과 upstream release note 근거다. exact v0.1.10 candidate source preflight와 signed draft 수동 smoke가 실패하면 성공 문구를 보정해야 한다.
- upstream 암호 문서·중첩 표 누적 변화 전체를 알한글에서 직접 재실행하지 않았다. Stage 3/4 대표 smoke와 미실행 범위를 구분한다.
- public DMG URL, SHA256, size, signing/notarization, appcast와 Homebrew 값은 아직 없다.
- `v0.1.10` tag와 GitHub Release가 아직 없어 candidate URL은 source communication용 future URL이다.
- HWP/HWPX 저장은 모든 요소의 완전 무손실을 보장하지 않는다.
- PDF는 전체 page SVG memory 비용과 document 전체 progress/deadline/cancel UI 제한이 남는다.
- 실제 mixed-orientation fixture, deployment target macOS 12 장비와 Intel Mac 실기기 검증은 미실행이다.
- 익명 event는 전체 설치·고유 사용자 수가 아니며, offline retention 밖의 실행은 관측하지 않는다.

## 다음 단계 영향

Stage 3에서 다음을 exact candidate 기준으로 검증한다.

1. core/studio/build-info와 target upstream root `Cargo.lock` provenance
2. strict static archive와 portable source/header/FFI 결과 분리
3. Rust tests, decoder fixture, HostAppTests와 ExternalImageTests
4. 세 app target Release build와 representative renderer
5. HWP/HWPX 저장, PDF·인쇄 controller와 WebKit trust boundary 자동 회귀
6. local universal package, release note helper, Legal resource와 registration hygiene
7. 위 preflight 통과 뒤 별도 승인된 Rehearsal workflow

Stage 3에서 candidate SHA가 이동하거나 차단 실패가 확인되면 Stage 2 communication을 자동 승계하지 않고 영향 문구를 다시 검토한다.

## 승인 요청

Stage 2의 포함 PR owner 판정, `v0.1.10` release communication, release-note helper 보정과 검증 결과를 승인하고 Stage 3 `Source preflight와 rehearsal` 진입을 요청한다.
