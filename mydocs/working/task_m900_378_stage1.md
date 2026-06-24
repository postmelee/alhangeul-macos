# Task M900 #378 Stage 1 완료보고서

## 단계 요약

`v0.1.7` public release candidate의 source metadata를 확정 후보값에 맞춰 정렬했다.

| 항목 | 결과 |
|------|------|
| App version | `0.1.7` |
| Build | `13` |
| Previous release ref | `v0.1.6` |
| Expected rhwp tag | `v0.7.17` |
| rhwp commit | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |

## 변경 내용

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Info.plist` | `CFBundleShortVersionString=0.1.7`, `CFBundleVersion=13` |
| `Sources/QLExtension/Info.plist` | `CFBundleShortVersionString=0.1.7`, `CFBundleVersion=13` |
| `Sources/ThumbnailExtension/Info.plist` | `CFBundleShortVersionString=0.1.7`, `CFBundleVersion=13` |
| `.github/workflows/release-rehearsal.yml` | default `version=0.1.7`, `previous_release_ref=v0.1.6`, `expected_rhwp_tag=v0.7.17` |
| `.github/workflows/release-publish.yml` | default `version=0.1.7`, `previous_release_ref=v0.1.6`, `expected_rhwp_tag=v0.7.17`, `include_rhwp_in_title=true` |

`rhwp-core.lock`과 bundled `rhwp-studio` manifest는 이미 `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` 기준이라 수정하지 않았다.

## Release Context 확인

| 항목 | 결과 |
|------|------|
| 최신 공개 앱 release | `v0.1.6`, `Alhangeul v0.1.6 (rhwp v0.7.16)` |
| 최신 upstream `rhwp` release | `v0.7.17` |
| 현재 candidate branch | `local/task378` |
| 기준 통합 브랜치 | `devel` |

`include_rhwp_in_title` 기본값은 이번 release가 upstream `rhwp v0.7.17` 반영 중심 patch release이므로 `true`로 조정했다. public publish 단계에서도 workflow input을 실행 직전에 다시 확인한다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| HostApp version/build 추출 | 통과 | `0.1.7`, `13` |
| Quick Look extension version/build 추출 | 통과 | `0.1.7`, `13` |
| Thumbnail extension version/build 추출 | 통과 | `0.1.7`, `13` |
| `bash scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag` | 통과 | `v0.7.17` |
| `bash scripts/ci/read-rhwp-core-lock.sh rhwp_commit` | 통과 | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| `scripts/verify-rhwp-studio-assets.sh` | 통과 | bundled asset entrypoint hash 검증 |
| `plutil -lint` | 통과 | HostApp, Quick Look, Thumbnail plist 모두 OK |
| workflow YAML parse | 통과 | `release-rehearsal.yml`, `release-publish.yml` parse 성공. 로컬 `ffi` gem 경고만 발생 |
| release default 검색 | 통과 | workflow default가 `0.1.7`, `v0.1.6`, `v0.7.17` 기준임을 확인 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

## 남은 위험

- Stage 1은 metadata 정렬 단계다. Debug/Release build, Rust bridge strict verify, render smoke, rehearsal DMG는 Stage 3에서 실행한다.
- public publish, GitHub Release, Pages/Sparkle, Homebrew는 아직 실행하지 않았다.
- `include_rhwp_in_title=true`는 workflow 기본값을 보정한 것이며, Stage 4에서 실제 `Release Publish DMG` 실행 전 release owner 승인과 입력값 재확인이 필요하다.

## 다음 단계 요청

Stage 2에서는 `mydocs/release/v0.1.7.md`, Pages release note, updates index, README 최신 요약 등 release communication을 작성하고, `v0.1.6` 대비 포함 PR 분석과 public wording을 정리한다.

Stage 2 진행 승인을 요청한다.
