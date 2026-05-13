# Task M019 #205 Stage 1 완료 보고서

## 단계 목적

앱 버전과 bundled `rhwp` provenance 표기 정책을 구현하기 전에 현재 문서, 스크립트, workflow, README, Pages가 어떤 기준으로 앱 버전과 `rhwp` 정보를 노출하는지 조사했다.

이번 단계에서는 정책/스크립트/Pages 본문을 수정하지 않고, 변경 대상과 제외 대상을 확정하는 inventory만 수행했다.

## 현재 provenance 기준

| 항목 | 값 |
|------|----|
| `rhwp` repository | `https://github.com/edwardkim/rhwp.git` |
| `rhwp` ref kind | `release-tag` |
| `rhwp` release tag | `v0.7.10` |
| `rhwp` commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| bundled `rhwp-studio` release tag | `v0.7.10` |
| bundled `rhwp-studio` commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| core lock | `rhwp-core.lock` |
| studio manifest | `Sources/HostApp/Resources/rhwp-studio/manifest.json` |

`rhwp-core.lock`과 studio manifest의 tag/commit은 일치한다. Stage 2에서 `v0.1.1` Pages에 추가할 사용자용 provenance 문구는 `rhwp v0.7.10` 기준으로 둔다.

## 현황 조사 결과

### Release policy

`mydocs/manual/release_policy_guide.md`에는 이미 artifact 계층, checksum 공개 기준, provenance 진실 원천이 정리되어 있다.

확인된 현재 기준:

- public DMG filename, Pages latest 다운로드, Sparkle enclosure, Homebrew Cask URL은 단일 universal DMG 기준이다.
- `rhwp` core tag/commit의 진실 원천은 `rhwp-core.lock`이다.
- bundled `rhwp-studio` asset의 진실 원천은 `Sources/HostApp/Resources/rhwp-studio/manifest.json`이다.
- release note에는 core/studio tag와 commit을 표시해야 한다.
- 버전 갱신 확인 대상에는 Git tag, app plist version, Cask, GitHub Release 제목과 파일명이 포함된다.

부족한 점:

- 앱 release identity를 `Alhangeul v<app-version>` 하나로 유지한다는 정책이 독립 섹션으로 정리되어 있지 않다.
- Git tag, bundle version, DMG filename, Sparkle appcast version, Homebrew Cask version에 `rhwp` 버전을 넣지 않는다는 기준이 명시적으로 모여 있지 않다.
- GitHub Release title 기본형과 `(rhwp vX.Y.Z)` 병기 허용 조건이 없다.
- GitHub Release body와 내부 release record의 표준 `Release metadata` 표가 아직 정책으로 고정되어 있지 않다.
- #204 upstream sync PR body와 release handoff가 따라야 할 짧은 표준 문구가 없다.

### GitHub Release, Pages, Sparkle guide

`mydocs/manual/release_github_pages_sparkle_guide.md`는 release body 포함 항목, Pages 사용자용 문서 기준, Sparkle appcast 배포 기준을 갖고 있다.

확인된 현재 기준:

- GitHub Release 생성 전 `rhwp-core.lock` commit과 `rhwp-studio` manifest tag/commit 기록 여부를 확인한다.
- release note 본문에는 포함된 `edwardkim/rhwp` core commit과 `rhwp-studio` asset manifest/commit을 넣는다.
- Pages는 사용자용 안내 표면이며 GitHub Release body의 긴 provenance, delta checklist, PR별 검증 기록을 그대로 복제하지 않는다.
- Sparkle appcast version과 enclosure URL은 앱 버전과 tag 고정 DMG URL을 기준으로 한다.

부족한 점:

- GitHub Release body의 표준 metadata 블록 이름과 필수 항목이 아직 guide에 없다.
- Pages 릴리즈 문서에 bundled `rhwp` 버전을 어느 정도까지 짧게 노출할지 기준이 없다.
- Sparkle appcast는 앱 버전만 사용하고 `rhwp` 버전은 release note metadata로만 연결한다는 경계가 명시되어 있지 않다.

### Release note generator

`scripts/ci/write-release-notes.sh`는 현재 `rhwp-core.lock`과 studio manifest를 읽어 다음 section을 생성한다.

```md
## 포함된 rhwp core와 viewer asset provenance
```

현재 dry-run 결과에는 다음 값이 들어간다.

- `rhwp core release tag`: `v0.7.10`
- `rhwp core commit`: `62a458aa317e962cd3d0eec6096728c172d57110`
- `rhwp-studio release tag`: `v0.7.10`
- `rhwp-studio commit`: `62a458aa317e962cd3d0eec6096728c172d57110`
- manifest path
- release detail doc path

부족한 점:

- heading이 정책에서 요구하는 표준 `Release metadata` 구조가 아니다.
- app version 항목이 provenance section 안에 함께 표시되지 않는다.
- `rhwp-core.lock` path가 metadata로 직접 표시되지 않는다.
- table 형태가 아니라 bullet list이므로 GitHub Release body와 내부 release record의 대조 기준으로 쓰기에는 약하다.
- `scripts/ci/check-release-notes-template.sh`도 현재 heading `## 포함된 rhwp core와 viewer asset provenance`를 필수 section으로 검사한다. Stage 3에서 heading을 바꾸면 checker도 함께 바꿔야 한다.

참고:

- `plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json`은 이 환경에서 JSON 파일을 plist lint 대상으로 처리하지 못해 실패했다.
- `jq empty Sources/HostApp/Resources/rhwp-studio/manifest.json`은 통과했다.
- `write-release-notes.sh`의 현재 `plutil -extract ... manifest.json` 경로는 dry-run에서 정상 동작했다.
- 따라서 manifest JSON 검증 명령은 Stage 2/3 문서와 최종 검증에서 `jq empty`를 우선 사용하는 편이 맞다.

### Release publish workflow

`.github/workflows/release-publish.yml`은 `expected_rhwp_tag`와 `require_latest_rhwp` guard를 갖고 있다. `rhwp-core.lock` tag가 workflow input과 일치하는지 확인하고, 필요 시 upstream latest release와도 비교한다.

현재 GitHub Release title 생성 방식:

```bash
--title "Alhangeul $tag_name"
```

이 title은 release create와 release edit 모두에 고정되어 있다.

부족한 점:

- 기본 release title은 정책 방향과 일치한다.
- 다만 upstream `rhwp` 반영 중심 release에서만 `(rhwp vX.Y.Z)`를 병기하는 예외 경로가 없다.
- 예외 경로를 추가한다면 기본값은 기존 `Alhangeul v<version>`을 유지해야 한다.
- GitHub Release 게시와 asset upload는 작업지시자 명시 승인 대상이라는 권한 원칙은 그대로 유지해야 한다.

### README

README의 최신 공개 릴리즈 섹션은 현재 `v0.1.0`을 최신 공개 릴리즈로 요약하고, `v0.1.1`은 patch release 후보로 설명한다.

확인된 현재 기준:

- README는 최신 공개 릴리즈 1개만 요약한다고 명시한다.
- core/version provenance는 `rhwp-core.lock`과 studio manifest에 기록한다고 안내한다.
- WKWebView viewer 섹션에는 `edwardkim/rhwp v0.7.10` snapshot의 `rhwp-studio` viewer 통합이 적혀 있다.

부족한 점:

- 최신 공개 릴리즈 요약에 bundled `rhwp-studio v<version>`을 어느 정도로 표시할지 기준이 없다.
- `v0.1.1`이 public release로 확정된 상태인지 여부는 README에서 아직 후보로 남아 있다. Stage 2에서 README를 고칠 때는 release 상태를 새로 확정한 것처럼 쓰지 않고, 기존 최신 공개 릴리즈 정책에 맞춰 짧은 provenance 기준만 반영해야 한다.

### Pages `v0.1.1`

`docs/updates/v0.1.1.html`은 사용자용 release note 구조를 갖고 있다.

확인된 현재 기준:

- hero, 주요 변경, 알려진 한계, 설치와 업데이트 section으로 구성되어 있다.
- download action은 `releases/latest/download/alhangeul-macos-0.1.1.dmg`를 가리킨다.
- 알려진 한계에서 앱 화면은 WKWebView 기반 `rhwp-studio` 경로를 사용한다고 설명한다.

부족한 점:

- 이 릴리즈가 bundled `rhwp v0.7.10`을 사용한다는 문구가 없다.
- upstream `edwardkim/rhwp` `v0.7.10` release 링크가 없다.
- 알한글 `v0.1.1` GitHub Release tag 링크가 보조 링크로 노출되어 있지 않다.
- Stage 2에서는 GitHub Release body 수준의 긴 metadata 표를 넣지 않고, 사용자용으로 짧은 provenance section 또는 문단을 추가하는 편이 맞다.

### Release record `v0.1.1`

`mydocs/release/v0.1.1.md`에는 이미 Provenance 표가 있고, `rhwp v0.7.10` core/studio tag와 commit을 기록한다.

부족한 점:

- 표준 `Release metadata`라는 이름과 app version/core/studio/lock/manifest 필수 항목의 공통 구조가 정책으로 연결되어 있지는 않다.
- Stage 2에서 policy와 맞추되, release record 초안의 후보 상태는 그대로 존중해야 한다.

## 변경 대상 확정

Stage 2 변경 대상:

- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `README.md`
- `docs/updates/v0.1.1.html`
- `mydocs/release/v0.1.1.md`
- `mydocs/working/task_m019_205_stage2.md`

Stage 3 변경 대상:

- `scripts/ci/write-release-notes.sh`
- `scripts/ci/check-release-notes-template.sh`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m019_205_stage3.md`

변경 제외:

- `rhwp-core.lock`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- `Frameworks/*`
- `RustBridge/*`
- `Alhangeul.xcodeproj`
- public release 실행, GitHub Release 게시, Pages deployment, Sparkle appcast 갱신

## 검증 결과

실행한 명령:

```bash
git status --short --branch
sed -n '1,120p' rhwp-core.lock
plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json
jq empty Sources/HostApp/Resources/rhwp-studio/manifest.json
jq -r '[.source_release_tag,.source_resolved_commit] | @tsv' Sources/HostApp/Resources/rhwp-studio/manifest.json
rg -n "Alhangeul v|rhwp core|rhwp-studio|Release metadata|GitHub Release|Pages|appcast|expected_rhwp_tag|--title" \
  README.md docs/updates/v0.1.1.html mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh .github/workflows/release-publish.yml
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
bash scripts/ci/write-release-notes.sh 0.1.2 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/stage1-current-release-notes-0.1.2.md
git check-ignore -v build.noindex/release/stage1-current-release-notes-0.1.2.md
```

결과:

- `git status --short --branch`: `local/task205...origin/devel-webview [ahead 2]`
- `rhwp-core.lock`: `rhwp_release_tag = "v0.7.10"`, `rhwp_commit = "62a458aa317e962cd3d0eec6096728c172d57110"`
- `plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json`: 실패. JSON manifest lint 용도로는 부적합.
- `jq empty Sources/HostApp/Resources/rhwp-studio/manifest.json`: 통과.
- studio manifest 값: `v0.7.10`, `62a458aa317e962cd3d0eec6096728c172d57110`
- `bash -n` 두 스크립트: 통과.
- release note dry-run: 통과. 생성물은 `build.noindex/` 아래이고 `.gitignore` 대상이다.

## 다음 단계 제안

Stage 2에서는 정책 문서와 사용자-facing 문서를 먼저 보강한다. 특히 `docs/updates/v0.1.1.html`에는 `rhwp v0.7.10`과 `https://github.com/edwardkim/rhwp/releases/tag/v0.7.10` 링크를 추가하되, GitHub Release body 수준의 긴 metadata 표는 넣지 않는다.

Stage 3에서는 generated release note의 provenance section을 `Release metadata` 표로 바꾸고, checker와 release publish title 생성 경로를 함께 맞춘다.
