# Task M900 #360 Stage 2 완료보고서

## 단계 요약

`v0.1.6` release communication을 `rhwp v0.7.16` 기준으로 작성했다. 공개 요약은 upstream sync PR #359 항목과 Finder thumbnail cache consistency 보강 PR #335 항목만 사용자-facing으로 반영하고, release note 자동화 PR #358 항목과 release execution Task #360 항목은 운영/배포 항목으로 분리했다.

| 항목 | 결과 |
|------|------|
| Release version | `0.1.6` |
| Build | `12` |
| Previous release ref | `v0.1.5` |
| Expected rhwp tag | `v0.7.16` |
| Release title 후보 | `Alhangeul v0.1.6 (rhwp v0.7.16)` |

## 변경 내용

| 파일 | 변경 |
|------|------|
| `README.md` | 최신 릴리즈 요약을 `v0.1.6`, `rhwp v0.7.16`, build `12` 기준으로 갱신 |
| `docs/index.html` | 최신 DMG download link와 FAQ 문구를 `v0.1.6` 기준으로 갱신 |
| `docs/updates/index.html` | 최신 DMG download link, Homebrew 안내, v0.1.6 release note 항목 추가 |
| `docs/updates/v0.1.6.html` | 사용자용 v0.1.6 Pages release note 추가 |
| `docs/updates/v0.1.0.html` ~ `docs/updates/v0.1.5.html` | 최신 버전 안내 banner를 v0.1.6 기준으로 갱신 |
| `mydocs/release/index.md` | v0.1.6 후보 추가, v0.1.5 공개 완료 상태 반영 |
| `mydocs/release/v0.1.6.md` | release record, 포함 PR 분석, GitHub Release body 후보, 검증 기준 작성 |
| `mydocs/working/task_m900_360_stage2.md` | Stage 2 완료보고서 작성 |

`Casks/alhangeul.rb`는 public DMG SHA256 확정 전이라 수정하지 않았다.

## 포함 PR 판단

| PR | 분류 | 사용자-facing | 공개 요약 반영 | 판단 |
|----|------|---------------|----------------|------|
| #359 | upstream sync | 예 | 예 | `rhwp v0.7.16` core/studio 반영이 이번 patch release의 중심 변화 |
| #335 | 사용자-facing | 예 | 예 | Finder thumbnail cache signature가 renderer/backend/provenance 변화 뒤 stale reuse 위험을 줄임. 기본 renderer 정책은 유지 |
| #358 | 운영/배포 | 아니오 | 아니오 | release note PR/Issue 분석 자동화와 workflow helper 보강 |
| #357 | 문서-only | 아니오 | 아니오 | 이전 v0.1.5 public Pages 문구 정정 |
| #360 | 운영/배포 | 아니오 | 아니오 | release candidate source/communication 정렬 |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `scripts/ci/write-release-delta-checklist.sh v0.1.5 HEAD ...` | 통과 | `build.noindex/release/delta-checklist-0.1.6.md` 생성 |
| `scripts/ci/write-release-notes.sh 0.1.6 ...` | 통과 | `build.noindex/release/release-notes-0.1.6.md` 생성 |
| `scripts/ci/check-release-notes-template.sh` | 통과 | release body 필수 heading과 PR/Issue section 검증 |
| `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check` | 통과 | 최신 v0.1.6 안내 banner 반영 확인 |
| `scripts/validate-github-body.sh` | 통과 | release record, Pages v0.1.6, generated release notes |
| HTML parse | 통과 | `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.6.html`, `docs/updates/v0.1.5.html` |
| version/provenance 검색 | 통과 | v0.1.6 최신 경로와 v0.1.5 이전 릴리즈 항목을 구분 확인 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

## 남은 위험

- `scripts/ci/write-release-pr-analysis.sh v0.1.5^{} HEAD ...`는 현재 범위의 squash merge commit을 PR로 식별하지 못해 `merge PR 없음` 초안을 만들었다. Stage 2에서는 GitHub PR metadata와 최종 보고서를 직접 읽어 `포함 PR 분석` 표를 수동 보정했다.
- `docs/index.html`과 `docs/updates/index.html`는 publish 전 후보 DMG URL을 가리킨다. 실제 사용자-facing public surface는 official stable release와 Pages 배포 후 확인해야 한다.
- upstream `rhwp-studio`의 웹/확장 drag/drop 확인 UI는 bundled asset에 포함되지만, 알한글 macOS 앱의 Finder 열기와 앱 내부 파일 열기는 HostApp native document router 정책을 따른다는 제한을 Pages와 release record에 분리했다.
- public DMG SHA256, Sparkle EdDSA signature, notarization result, Homebrew Cask digest는 아직 확정하지 않았다.

## 다음 단계 요청

Stage 3에서는 source preflight와 rehearsal을 진행한다. Rust/core lock, bundled asset, AppKit boundary, Xcode generation, Debug build, render smoke, release helper, package/rehearsal DMG를 검증하고 결과를 `mydocs/release/v0.1.6.md`에 기록한다.

Stage 3 진행 승인을 요청한다.
