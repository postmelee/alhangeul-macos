# Task M019 #225 Stage 4 완료보고서

## 단계 목적

`v0.1.2` release candidate의 source metadata와 사용자 문서를 정리했다. 앱/Quick Look/Thumbnail extension version을 `0.1.2 (5)`로 올리고, release workflow와 CI helper dry-run 기본값을 직전 public release `v0.1.1`과 `rhwp v0.7.11` 기준으로 맞췄다.

public DMG, GitHub Release, stable Sparkle appcast, Homebrew Cask는 아직 확정 산출물이 없으므로 Stage 4에서 고정하지 않았다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `Sources/HostApp/Info.plist` | 수정 | `CFBundleShortVersionString=0.1.2`, `CFBundleVersion=5` |
| `Sources/QLExtension/Info.plist` | 수정 | extension version/build를 `0.1.2 (5)`로 갱신 |
| `Sources/ThumbnailExtension/Info.plist` | 수정 | extension version/build를 `0.1.2 (5)`로 갱신 |
| `.github/workflows/release-rehearsal.yml` | 수정 | default version `0.1.2`, `previous_release_ref=v0.1.1`, `expected_rhwp_tag=v0.7.11` |
| `.github/workflows/release-publish.yml` | 수정 | public publish default version/ref/rhwp tag를 `v0.1.2` 후보 기준으로 갱신 |
| `.github/workflows/pr-ci.yml` | 수정 | release note, delta checklist, appcast helper dry-run 입력을 `0.1.2`/build `5`로 갱신 |
| `scripts/release.sh` | 수정 | usage example을 `0.1.2`로 갱신 |
| `scripts/smoke-finder-integration.sh` | 수정 | package-release 기본 version을 `0.1.2`로 갱신 |
| `scripts/smoke-clean-quicklook-install.sh` | 수정 | local visual smoke 기본 version을 `0.1.2`로 갱신 |
| `README.md` | 수정 | 최신 공개 릴리즈 요약을 release candidate `v0.1.2` 기준으로 전환하고 현재 public latest `v0.1.1 (4)`를 명시 |
| `docs/index.html` | 수정 | Pages 다운로드 링크와 FAQ를 v0.1.2 후보 기준으로 갱신 |
| `docs/updates/index.html` | 수정 | v0.1.2 릴리즈 노트 항목과 최신 DMG 링크 추가 |
| `docs/updates/v0.1.2.html` | 신규 | 사용자용 v0.1.2 릴리즈 노트 추가 |
| `mydocs/release/index.md` | 수정 | release index에 v0.1.2 후보와 v0.1.1 공개 완료 상태 반영 |
| `mydocs/release/v0.1.2.md` | 신규 | 내부 v0.1.2 release candidate 기록 추가 |
| `mydocs/working/task_m019_225_stage4.md` | 신규 | Stage 4 수행과 검증 결과 기록 |

## Version/build 기준

직전 public release는 `v0.1.1` build `4`다. Sparkle build number는 증가해야 하므로 `v0.1.2` 후보의 build는 `5`로 정했다.

| 항목 | 값 |
|------|----|
| Short version | `0.1.2` |
| Build | `5` |
| Previous release ref | `v0.1.1` |
| Expected rhwp tag | `v0.7.11` |
| Expected rhwp commit | `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` |
| Expected DMG name | `alhangeul-macos-0.1.2.dmg` |

## Public 배포 gate

Stage 4는 release source와 문서 후보 정리까지만 수행했다. public 배포는 다음 조건이 충족된 뒤 별도 승인으로 진행한다.

- `devel-webview` 대상 PR merge
- `devel-webview` 검증 commit을 `main`에 반영하는 release PR merge
- `main`의 최종 release commit에 `v0.1.2` tag 생성
- signed/notarized Release package 생성과 설치본 smoke 통과
- public DMG SHA256, Sparkle EdDSA signature, GitHub Release latest 상태 확정
- Pages/appcast public URL 확인

`docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.2.html`의 download link는 public release 이후 활성화될 URL을 가리킨다. public GitHub Release asset이 올라가기 전에 Pages가 먼저 배포되면 해당 DMG 링크는 아직 유효하지 않을 수 있다.

## 의도적으로 미갱신한 항목

| 항목 | 이유 |
|------|------|
| `docs/appcast.xml` | stable Sparkle appcast는 public DMG length와 EdDSA signature가 있어야 확정 가능 |
| `Casks/alhangeul-macos.rb` | Homebrew Cask는 public DMG SHA256 확정 후 고정해야 함 |
| GitHub Release body | `Release Publish DMG` workflow와 public asset 확정 후 생성해야 함 |

## 검증 결과

### Plist

```text
$ plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK
```

### Workflow YAML

```text
$ ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
exit 0

$ ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
exit 0
```

Ruby가 `Ignoring ffi-1.13.1 because its extensions are not built` 경고를 출력했지만 YAML parse는 exit `0`으로 완료됐다.

### Shell syntax

```text
$ bash -n scripts/ci/write-release-notes.sh
exit 0

$ bash -n scripts/ci/check-release-notes-template.sh
exit 0

$ bash -n scripts/ci/write-release-delta-checklist.sh
exit 0

$ bash -n scripts/ci/write-sparkle-appcast.sh
exit 0

$ bash -n scripts/release.sh
exit 0

$ bash -n scripts/smoke-finder-integration.sh
exit 0

$ bash -n scripts/smoke-clean-quicklook-install.sh
exit 0
```

### Release notes dry-run

초기 실행에서 checksum placeholder를 40자 0으로 넣어 helper가 의도대로 실패했다.

```text
$ scripts/ci/write-release-notes.sh 0.1.2 0000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.2.md
ERROR: dmg sha256 must be a 64-character hex digest
```

64자 SHA256 placeholder로 재실행해 release note template을 검증했다.

```text
$ scripts/ci/write-release-notes.sh 0.1.2 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.2.md
exit 0

$ scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md
Release note template check passed: build.noindex/release/release-notes-0.1.2.md
```

생성된 release note의 metadata는 다음 값을 포함했다.

```text
App version = v0.1.2
rhwp core release tag = v0.7.11
rhwp core commit = a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae
bundled rhwp-studio release tag = v0.7.11
bundled rhwp-studio commit = a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae
```

### Studio provenance

```text
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

### Version/provenance scan

```text
$ rg -n "0\\.1\\.1|0\\.1\\.2|v0\\.7\\.10|v0\\.7\\.11|a9dcdee|expected_rhwp_tag|previous_release_ref|latest/download" Sources .github/workflows scripts README.md docs mydocs/release/v0.1.2.md
exit 0
```

주요 분류:

- `0.1.2`, build `5`, `v0.7.11`, `a9dcdee...`는 Stage 4 후보 metadata와 release note에 의도적으로 포함된다.
- `v0.1.1`은 직전 public release, `previous_release_ref`, README의 현재 public latest 표기, 기존 v0.1.1 릴리즈 노트의 역사 기록으로 남긴다.
- `v0.7.10`은 `docs/updates/v0.1.0.html`, `docs/updates/v0.1.1.html`의 역사 기록으로 남긴다.
- `latest/download/alhangeul-macos-0.1.2.dmg`는 public release 이후 활성화될 Pages download link다.

추가로 `Casks/alhangeul-macos.rb`에는 `version "0.1.1"`이 남아 있다. 이는 public DMG SHA256이 아직 없어서 Stage 4에서 의도적으로 유지한 값이다.

### Diff hygiene

```text
$ git diff --check
exit 0
```

## 본문 변경 정도 / 본문 무손실 여부

source version, release workflow, release helper default, 사용자용 release page, 내부 release record만 변경했다. 문서 sample, renderer, bridge, bundled studio asset 본문은 Stage 4에서 변경하지 않았다.

## 잔여 위험

- `docs/updates/v0.1.2.html`과 Pages download links는 public GitHub Release asset이 올라가기 전에는 후보 URL이다.
- stable appcast와 Cask는 public DMG SHA256/signature 확정 전까지 v0.1.2로 고정할 수 없다.
- signed/notarized package smoke는 Stage 5에서 별도 수행해야 한다.
- Stage 3에서 구현한 launch maintenance는 source-level compile/link까지 확인됐고, 실제 업데이트 후 Finder thumbnail refresh 효과는 signed/sealed 설치본에서 확인해야 한다.

## 다음 단계 영향

Stage 5에서는 Release build/package smoke를 진행한다.

필수 확인:

- Release app/extension version이 모두 `0.1.2 (5)`인지 확인
- app/preview/thumbnail 실행 파일이 `arm64 + x86_64` universal인지 확인
- signed/sealed package 기준 앱 실행, About `rhwp v0.7.11 (a9dcdee)` 표시 확인
- Quick Look/Thumbnail provider 등록과 Finder thumbnail/preview smoke 확인
- launch maintenance marker와 최근 문서 thumbnail refresh log/동작 확인

## 승인 요청

Stage 4 완료를 승인하면 Stage 5 `Release build/package smoke와 GUI/extension 검증`을 진행한다.
