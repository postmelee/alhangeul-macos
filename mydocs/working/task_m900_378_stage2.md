# Task M900 #378 Stage 2 완료보고서

## 단계 요약

`v0.1.7` public release candidate의 사용자-facing release communication과 내부 release record를 작성했다. 공개 요약은 직전 public release `v0.1.6` 이후 포함된 PR 중 사용자에게 직접 보이는 변화만 반영했다.

| 항목 | 결과 |
|------|------|
| App version | `0.1.7` |
| Build | `13` |
| Previous release ref | `v0.1.6` |
| Included rhwp | `v0.7.17` |
| rhwp commit | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| Pages note | `docs/updates/v0.1.7.html` |
| Release record | `mydocs/release/v0.1.7.md` |

## 포함 PR 분석 결과

| PR | 분류 | 공개 요약 반영 | 판단 |
|----|------|----------------|------|
| `#368` | 사용자-facing | 예 | LibreOffice HWP UTI 환경의 HostApp, Quick Look, Thumbnail 라우팅 보강 |
| `#369` | upstream sync | 예 | `rhwp v0.7.17` core/studio 반영으로 차트, HWPX 도형 주석, bundled editor 보강 노출 |
| `#374` | 운영/검증 | 아니오 | Cargo.lock provenance와 locked build 검증 보강으로 사용자 요약에는 직접 반영하지 않음 |
| `#373` | 사용자-facing | 예 | HWP 3.0 signature 문서가 앱 열기 전에 차단되지 않도록 보강 |
| `#377` | 운영/자동화 | 아니오 | upstream sync workflow 기준 보강으로 사용자 요약에는 직접 반영하지 않음 |
| `#378` | 릴리즈 실행 | 아니오 | release metadata, release record, Pages/README 정렬 작업 |

## 변경 내용

| 파일 | 변경 |
|------|------|
| `mydocs/release/v0.1.7.md` | release record, PR 분석, GitHub Release body 후보, 검증 기준, execution gate 작성 |
| `mydocs/release/index.md` | `v0.1.7` 후보 추가, `v0.1.6` 공개 완료 상태 반영 |
| `docs/updates/v0.1.7.html` | 사용자용 Pages 릴리즈 노트 추가 |
| `docs/updates/index.html` | 최신 DMG 링크와 릴리즈 노트 목록을 `v0.1.7` 기준으로 갱신 |
| `docs/index.html` | 홈 페이지 최신 다운로드 링크와 FAQ version을 `v0.1.7` 기준으로 갱신 |
| `docs/updates/v0.1.0.html` ~ `docs/updates/v0.1.6.html` | 이전 릴리즈 안내 배너를 최신 `v0.1.7` 기준으로 갱신 |
| `README.md` | 최신 공개 릴리즈 요약을 `v0.1.7` 후보 기준으로 갱신 |
| `scripts/ci/write-release-delta-checklist.sh` | heredoc 안 Markdown backtick escape 누락을 보정해 checklist 생성 중 command-not-found가 발생하지 않게 수정 |
| `mydocs/orders/20260625.md` | Stage 2 완료보고서 작성 후 승인 대기 상태 반영 |

## GitHub Release 본문 후보

`mydocs/release/v0.1.7.md`에 다음 섹션을 public release body 후보로 정리했다.

- `변경 요약`
- `포함된 rhwp 변화`
- `알한글 앱 변화`
- `릴리즈 요약에 반영된 PR`
- `해결된 Issue`
- `참고/연관 Issue`

`scripts/ci/write-release-notes.sh`는 이 섹션을 읽어 public GitHub Release body 후보를 만들도록 되어 있으므로, Stage 2에서는 실제 DMG SHA256 대신 placeholder digest로 template과 body 형식만 검증했다. 실제 SHA256은 official public publish 후 다시 생성하고 release record에 기록한다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `bash -n scripts/ci/write-release-delta-checklist.sh` | 통과 | shell syntax 확인 |
| `scripts/ci/write-release-delta-checklist.sh v0.1.6 HEAD build.noindex/release/delta-checklist-0.1.7.md` | 통과 | command-not-found 없이 delta checklist 생성 |
| `scripts/ci/write-release-notes.sh 0.1.7 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.7.md` | 통과 | placeholder SHA256으로 template 생성 |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.7.md` | 통과 | GitHub Release body template 필수 섹션 확인 |
| `scripts/validate-github-body.sh build.noindex/release/release-notes-0.1.7.md` | 통과 | GitHub body 형식 확인 |
| `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check` | 통과 | 이전 릴리즈 안내 배너 최신 version 일치 |
| release keyword 검색 | 통과 | `0.1.7`, `v0.1.7`, `v0.7.17`, DMG filename, 주요 요약 문구 확인 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

## 남은 위험

- Stage 2는 문서와 release communication 정렬 단계다. Debug build, Rust bridge locked build 검증, native render smoke, release package 검증은 Stage 3에서 실행한다.
- `docs/`와 README의 `v0.1.7` 링크는 release candidate source에 반영한 예정 URL이다. public GitHub Release와 DMG asset은 아직 생성하지 않았다.
- public DMG SHA256, Sparkle EdDSA signature, notarization result, Homebrew Cask digest는 Stage 4~5의 별도 승인 gate 이후에만 확정한다.
- `scripts/ci/write-release-delta-checklist.sh`의 backtick escape 보정은 Stage 2 validation 중 발견된 release helper 오류를 고친 것이다. 기능 source나 publish workflow 동작은 변경하지 않았다.

## 다음 단계 요청

Stage 3에서는 source preflight와 rehearsal 검증을 진행한다. `rhwp` lock/provenance, bundled asset, no-AppKit, Debug build, render smoke, package/release helper dry-run을 실행하고, 별도 승인 후 rehearsal DMG를 생성한다.

Stage 3 진행 승인을 요청한다.
