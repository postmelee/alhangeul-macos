# Task M900 #441 Stage 2 완료보고서

## 단계 목적

직전 public release `v0.1.8`부터 Stage 2 candidate까지 새로 포함된 PR을 실제 사용자 영향 기준으로 분류하고, `v0.1.9 (15)` / `rhwp v0.8.2` release communication을 README, Pages와 내부 release record에 일관되게 반영한다.

이번 단계는 공개 문구와 release record 작성까지만 수행한다. source preflight, Release Rehearsal/Publish workflow 실행, 원격 branch push, PR 생성·merge, tag 생성과 GitHub Release·Pages·Sparkle·Homebrew mutation은 수행하지 않는다.

## 산출물

### 사용자-facing 문서

- `README.md`
  - 최신 릴리즈 요약, GitHub Release/Pages 후보 링크, bundled `rhwp`와 Sparkle version/build 기준을 `v0.1.9`, `v0.8.2`, `0.1.9 (15)`로 갱신
- `docs/index.html`
  - Pages 홈 다운로드와 FAQ의 최신 DMG 후보 경로를 `v0.1.9`로 갱신
- `docs/updates/index.html`
  - header/본문 다운로드 CTA, Homebrew 안내와 첫 릴리즈 항목을 `v0.1.9`로 갱신
- `docs/updates/v0.1.9.html`
  - 사용자용 변경 요약, upstream `rhwp` 변화, 알한글 앱 변화, 알려진 한계와 설치 안내를 131줄로 추가
- `docs/updates/v0.1.0.html` ~ `docs/updates/v0.1.8.html`
  - 표준 helper로 최신 릴리즈 안내를 `v0.1.9`로 갱신

### 내부 release record

- `mydocs/release/index.md`
  - `v0.1.9`을 `후보 · Stage 2 완료` 상태로 추가
- `mydocs/release/v0.1.9.md`
  - release identity, 포함 PR 분석, GitHub Release 본문 구조 후보, 검증·배포 gate와 known limitations를 219줄로 기록
- `mydocs/working/task_m900_441_stage2.md`
  - Stage 2 변경 경계, 검증 결과, 잔여 위험과 다음 승인 gate 기록
- `mydocs/orders/20260728.md`
  - Issue #441 이슈를 `Stage 2 완료 · Stage 3 승인 대기`로 갱신

보고서와 오늘할일을 제외한 release communication 변경은 15개 파일이다.

### 검증 전용 ignored 산출물

- `build.noindex/task441-stage2/pr-analysis-v0.1.9.md`: 238줄
- `build.noindex/task441-stage2/delta-checklist-v0.1.9.md`: 309줄
- `build.noindex/task441-stage2/release-notes-v0.1.9.md`: 108줄

위 `build.noindex/` 파일은 commit하지 않는다. generated release note의 64자리 0 checksum은 template 구조 검증용이며 public release body나 release record의 실제 digest로 사용하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 앱, extension, RustBridge, core/studio asset, renderer와 release workflow source는 Stage 2에서 변경하지 않았다.
- README는 기존 최신 릴리즈 블록의 version, 사용자 요약과 링크만 교체했다. 나머지 프로젝트 소개, 빌드와 workflow 문서는 보존했다.
- Pages 홈과 updates index는 최신 다운로드/릴리즈 경로와 요약만 교체하고 기존 section, style과 script 구조를 보존했다.
- `v0.1.0`~`v0.1.7` page는 기존 notice의 최신 version과 링크만 helper 결과대로 교체했다. `v0.1.8` page에는 같은 표준 notice를 추가했고 기존 릴리즈 본문은 변경하지 않았다.
- `v0.1.9` page는 기존 update page의 header, action, section과 footer 구조를 재사용했다. 40자 provenance commit은 `<wbr>`로 안전하게 나눠 390px viewport에서도 page overflow가 발생하지 않게 했다.
- 공개 주요 변화는 PR #436 upstream sync, PR #434 HOP Quick Look 충돌 안내, PR #437 external image fallback으로 제한했다. PR #440 변경은 release readiness 검증 근거로만 반영했다.
- PR #431 Pages 문구와 PR #428 직전 release closeout은 `v0.1.9` 앱의 신규 사용자 변화에서 제외했다.
- PR #437 body의 Issue #412 이슈 참조는 자동 분석 결과와 달리 해결 관계가 아니며 현재 OPEN임을 확인했다. release record에서는 해결된 Issue가 아니라 후속 참고 Issue로 보정했다.

## 검증 결과

### Candidate와 포함 PR 기준

Stage 2 live 기준은 다음과 같다.

| 항목 | 결과 |
|------|------|
| Stage 2 분석 HEAD | `2e0529f770ce74aaefefc05fe474c01018e62eba` |
| `origin/devel` | `76c86fc76a9e2b7291f80e57b8b85c7c1e1ff525` |
| `origin/main` | `32c1129477dfd3c812f1eac758654f1e591b1888` |
| `origin/main...origin/devel` | main 전용 3개 / devel 전용 38개 commit |
| 최신 공개 앱 release | `v0.1.8` |
| 최신 upstream release | `rhwp v0.8.2` |
| `v0.1.9` tag | 없음 |
| 열린 `main`/`devel` 대상 PR | 없음 |

`v0.1.8..origin/devel` first-parent merge inventory:

```text
76c86fc Merge pull request #440 from postmelee/publish/task438
5689462 Merge pull request #436 from postmelee/automation/rhwp-v0.8.2-full-sync
c968c1a Merge pull request #437 from postmelee/publish/task409
0995341 Merge pull request #434 from postmelee/publish/task433
f908a38 Merge pull request #431 from postmelee/publish/task430
dcef80c Merge pull request #428 from postmelee/publish/task424
```

각 PR의 title/body, 연결 Issue 상태와 다음 최종 보고서를 직접 대조했다.

- `mydocs/report/task_m020_438_report.md`
- `mydocs/report/task_m020_409_report.md`
- `mydocs/report/task_m040_433_report.md`
- `mydocs/report/task_m010_430_report.md`
- `mydocs/report/task_m900_424_report.md`

release owner 판정:

| PR | 분류 | 사용자-facing | 공개 요약 | 판단 |
|----|------|---------------|-----------|------|
| `#436` | upstream sync | 예 | 반영 | `rhwp v0.7.19`~`v0.8.2` core/studio 누적 개선 |
| `#437` | 사용자-facing | 예 | 반영 | Quick Look external image resolver와 permission fallback |
| `#434` | 사용자-facing | 예 | 반영 | HOP 충돌 가능성 안내와 시스템 설정 경로 |
| `#440` | 개발자-facing | 아니오 | 검증 근거 | 최신 `devel` 결합의 provenance·ABI·app/package 검증 |
| `#431` | 문서-only | 예 | 앱 요약 제외 | Pages 철학/OG 문구 변경 |
| `#428` | 운영/배포 | 아니오 | 제외 | 직전 `v0.1.8` publish closeout |

### Release helper

다음 명령이 exit code 0으로 통과했다.

```text
scripts/ci/write-release-pr-analysis.sh v0.1.8 HEAD ...
scripts/ci/write-release-delta-checklist.sh v0.1.8 HEAD ...
scripts/ci/write-release-notes.sh 0.1.9 <placeholder-sha256> ...
scripts/ci/check-release-notes-template.sh ...
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
scripts/validate-github-body.sh <PR-analysis> <release-notes> mydocs/release/v0.1.9.md
```

핵심 결과:

```text
Release note template check passed: build.noindex/task441-stage2/release-notes-v0.1.9.md
Release version notices are up to date for latest v0.1.9.
```

generated GitHub Release body의 첫 top-level section은 `이번 버전의 주요 변경 사항`이며 다음 필수 구성을 모두 포함한다.

- `변경 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`
- 다운로드, 지원 환경, 첫 실행, 업데이트와 Homebrew 안내
- 알려진 제한 사항
- 릴리즈 요약에 반영된 PR, 해결된 Issue, 참고/연관 Issue
- 상세 기록과 release metadata

### Pages browser QA

로컬 정적 서버에서 `v0.1.9.html`, `/updates/`와 Pages 홈을 확인했다.

| viewport/페이지 | 결과 |
|-----------------|------|
| 1440x900 `v0.1.9` | `scrollWidth=clientWidth=1440`, page overflow element 0, H2 5개와 v0.1.9 링크 3개 확인 |
| 390x844 `v0.1.9` | `scrollWidth=clientWidth=390`, page overflow element 0, H2 5개와 navigation 표시 확인 |
| 390x844 updates index | 첫 릴리즈 항목과 DMG CTA가 v0.1.9, document 폭 390px 유지 |
| 390x844 Pages home | download CTA가 v0.1.9, `scrollWidth=clientWidth=390` |

세 페이지 모두 browser console error/warning이 없었다. updates index의 `pre.code-panel`은 기존 의도대로 요소 내부에서 가로 스크롤할 수 있지만 document 자체 overflow는 발생하지 않았다.

### 정적 diff

- release identity 검색: README, Pages와 release record의 `v0.1.9`, build `15`, `rhwp v0.8.2`, commit `9b16aa9e...` 확인
- 포함 PR 구조 검색: `포함 PR 분석`, 사용자-facing, 공개 요약, 해결/참고 Issue 구분 확인
- 이전 update page의 latest notice가 모두 `v0.1.9`을 가리킴
- `git diff --check`: 통과

## 잔여 위험

- Stage 2 문서의 GitHub Release, Pages와 DMG URL은 예정된 public 경로다. official stable publish 전에는 실제 public asset을 뜻하지 않으며 source도 release PR/Publish gate 전에는 public Pages에 반영되지 않는다.
- 자동 분석 candidate는 Stage 2 시작 HEAD `2e0529f...`다. Stage 2 commit 이후 Task #441 source PR, 필요한 back-merge와 final `devel -> main` candidate에서는 PR 분석과 delta checklist를 다시 생성해야 한다.
- generated release body의 SHA256은 64자리 0 placeholder다. 실제 digest는 Stage 4 draft와 Stage 5 official artifact에서 별도로 기록한다.
- `main` 전용 PR #432 변경이 있다. Stage 4 release PR 전에 tree를 다시 비교하고 필요하면 reviewed `main -> devel` back-merge로 보존해야 한다.
- strict local `librhwp.a` byte hash/size mismatch는 아직 판정되지 않았다. Stage 3에서 strict 결과와 portable source/Cargo/header/FFI 결과를 분리해 release owner 판단을 받아야 한다.
- 실제 Finder/Preview, external sibling permission, 장문서 repaint, 인쇄/PDF, universal package, signed/notarized DMG, Sparkle update와 Intel Mac 실기기 검증은 아직 성공으로 기록하지 않았다.
- repository Cask는 기존 버전 상태를 유지한다. official public DMG URL/SHA256 확정 전에는 갱신하지 않는다.
- upstream `v0.8.2`의 page-local repaint Issue #3412 이슈와 PDF 안내 modal Issue #3450 이슈가 알한글에 미치는 영향은 signed candidate editor smoke 전까지 미확정이다.

## 다음 단계 영향

Stage 3은 이번 release communication을 입력으로 source preflight를 수행한다.

1. core/studio provenance, strict archive와 portable source/header/FFI 경계를 다시 검증한다.
2. Rust/Swift boundary와 테스트, generated Xcode project 정합성, 세 app target Release build를 확인한다.
3. representative renderer, Quick Look/Thumbnail policy와 external sibling fixture를 검증한다.
4. local unsigned universal package의 version/build, architecture와 legal resource를 확인한다.
5. release helper를 Stage 2 commit이 포함된 HEAD에서 다시 생성한다.
6. Rehearsal workflow 실행은 source preflight 결과와 exact candidate SHA를 제시한 뒤 별도 승인을 받는다.

## 승인 요청

Stage 2 포함 PR 분석, release communication과 검증 결과를 승인하고 Stage 3 `Source preflight와 rehearsal` 가운데 source preflight 진입을 요청한다. Rehearsal workflow 실행, 원격 branch push와 그 밖의 외부 mutation은 Stage 3 source preflight 결과 보고 후 별도 승인을 받는다.
