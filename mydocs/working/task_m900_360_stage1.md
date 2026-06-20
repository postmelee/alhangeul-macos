# Task M900 #360 Stage 1 완료보고서

## 단계 요약

`v0.1.6` public release candidate의 source metadata를 확정 후보값에 맞춰 정렬했다.

| 항목 | 결과 |
|------|------|
| App version | `0.1.6` |
| Build | `12` |
| Previous release ref | `v0.1.5` |
| Expected rhwp tag | `v0.7.16` |
| rhwp commit | `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb` |

## 변경 내용

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Info.plist` | `CFBundleShortVersionString=0.1.6`, `CFBundleVersion=12` |
| `Sources/QLExtension/Info.plist` | `CFBundleShortVersionString=0.1.6`, `CFBundleVersion=12` |
| `Sources/ThumbnailExtension/Info.plist` | `CFBundleShortVersionString=0.1.6`, `CFBundleVersion=12` |
| `.github/workflows/release-rehearsal.yml` | default `version=0.1.6`, `previous_release_ref=v0.1.5`, `expected_rhwp_tag=v0.7.16` |
| `.github/workflows/release-publish.yml` | default `version=0.1.6`, `previous_release_ref=v0.1.5`, `expected_rhwp_tag=v0.7.16` |

`rhwp-core.lock`과 bundled `rhwp-studio` manifest는 이미 `v0.7.16` / `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb` 기준이라 수정하지 않았다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| HostApp version/build 추출 | 통과 | `0.1.6`, `12` |
| Quick Look extension version/build 추출 | 통과 | `0.1.6`, `12` |
| Thumbnail extension version/build 추출 | 통과 | `0.1.6`, `12` |
| `bash scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag` | 통과 | `v0.7.16` |
| `bash scripts/ci/read-rhwp-core-lock.sh rhwp_commit` | 통과 | `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb` |
| `scripts/verify-rhwp-studio-assets.sh` | 통과 | bundled asset entrypoint hash 검증 |
| `plutil -lint` | 통과 | HostApp, Quick Look, Thumbnail plist 모두 OK |
| workflow YAML parse | 통과 | `release-rehearsal.yml`, `release-publish.yml` parse 성공 |
| stale release defaults 검색 | 통과 | 변경 대상 파일에서 `v0.1.4`, `v0.7.15`, plist `0.1.5` 잔존 없음. `v0.1.5`는 의도된 `previous_release_ref`로만 남음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

## 남은 위험

- `include_rhwp_in_title` 기본값은 이번 단계에서 바꾸지 않았다. `rhwp v0.7.16` 반영을 release title에 병기하는 결정은 이미 release identity에 `include_rhwp_in_title=true`로 기록했으며, 실제 `Release Publish DMG` 실행 시 명시 입력으로 다시 확인해야 한다.
- Stage 1은 metadata 정렬 단계다. Debug/Release build, Rust bridge strict verify, render smoke, rehearsal DMG는 Stage 3에서 실행한다.
- public publish, GitHub Release, Pages/Sparkle, Homebrew는 아직 실행하지 않았다.

## 다음 단계 요청

Stage 2에서는 `mydocs/release/v0.1.6.md`, Pages release note, updates index, README 최신 요약 등 release communication을 작성하고, `v0.1.5` 대비 포함 PR 분석과 public wording을 정리한다.

Stage 2 진행 승인을 요청한다.
