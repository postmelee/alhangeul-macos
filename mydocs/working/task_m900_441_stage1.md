# Task M900 #441 Stage 1 완료보고서

## 단계 목적

`v0.1.9` public release 시작 기준을 live 상태로 다시 고정하고, 세 app target과 Release Rehearsal/Publish workflow 기본 입력을 승인된 `0.1.9 (15)`, 직전 공개 버전 `v0.1.8`, upstream `rhwp v0.8.2`로 정렬한다.

이번 단계는 source metadata 정렬까지만 수행한다. Release Rehearsal/Publish workflow 실행, 원격 branch push, PR 생성·merge, tag 생성과 GitHub Release·Pages·Sparkle·Homebrew 변경은 수행하지 않는다.

## Release context 기준선

조회 시각은 `2026-07-28 21:55 KST`다.

| 항목 | 확인 결과 |
|------|-----------|
| 최신 공개 앱 release | `v0.1.8`, draft 아님, prerelease 아님 |
| 앱 release publishedAt | `2026-07-19T03:42:35Z` |
| 앱 release URL | `https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.8` |
| 직전 public ref peeled commit | `542a35f2179e5499996b2ab7d2b1a94774b544a2` |
| 최신 upstream release | `v0.8.2`, draft 아님, prerelease 아님 |
| upstream publishedAt | `2026-07-26T15:57:18Z` |
| upstream release URL | `https://github.com/edwardkim/rhwp/releases/tag/v0.8.2` |
| `origin/main` | `32c1129477dfd3c812f1eac758654f1e591b1888` |
| `origin/devel` / Stage 1 candidate | `76c86fc76a9e2b7291f80e57b8b85c7c1e1ff525` |
| merge base | `b6ddc23f4bd4d2147144e3fea3b3fb473004994e` |
| `origin/main...origin/devel` | main 전용 3개 / devel 전용 38개 commit |
| `v0.1.9` tag | local과 GitHub remote matching ref 모두 없음 |
| 열린 `devel` 대상 PR | 없음 |
| 열린 `main` 대상 PR | 없음 |
| Issue #441 | Open |

`origin/devel`은 Issue 등록과 구현계획 승인 당시 candidate인 `76c86fc76a9e2b7291f80e57b8b85c7c1e1ff525`에서 이동하지 않았다. 따라서 승인된 Stage 1 metadata 정렬을 계속 수행했다.

`v0.1.8..origin/devel` first-parent merge inventory는 다음과 같다.

```text
76c86fc Merge pull request #440 from postmelee/publish/task438
5689462 Merge pull request #436 from postmelee/automation/rhwp-v0.8.2-full-sync
c968c1a Merge pull request #437 from postmelee/publish/task409
0995341 Merge pull request #434 from postmelee/publish/task433
f908a38 Merge pull request #431 from postmelee/publish/task430
dcef80c Merge pull request #428 from postmelee/publish/task424
```

`main`에는 PR #432 전용 변경이 있고 `devel`에는 위 release 이후 변경이 있다. 이 inventory는 Stage 2 포함 PR 분석의 입력이며, 사용자-facing 포함 여부와 변경 설명은 Stage 2에서 PR body, 연결 Issue와 최종 보고서를 읽은 뒤 확정한다.

## 산출물

- `Sources/HostApp/Info.plist`
  - `CFBundleShortVersionString`: `0.1.8` -> `0.1.9`
  - `CFBundleVersion`: `14` -> `15`
- `Sources/QLExtension/Info.plist`
  - `CFBundleShortVersionString`: `0.1.8` -> `0.1.9`
  - `CFBundleVersion`: `14` -> `15`
- `Sources/ThumbnailExtension/Info.plist`
  - `CFBundleShortVersionString`: `0.1.8` -> `0.1.9`
  - `CFBundleVersion`: `14` -> `15`
- `.github/workflows/release-rehearsal.yml`
  - `version`: `0.1.8` -> `0.1.9`
  - `previous_release_ref`: `v0.1.7` -> `v0.1.8`
  - `expected_rhwp_tag`: `v0.7.18` -> `v0.8.2`
- `.github/workflows/release-publish.yml`
  - `version`: `0.1.8` -> `0.1.9`
  - `previous_release_ref`: `v0.1.7` -> `v0.1.8`
  - `expected_rhwp_tag`: `v0.7.18` -> `v0.8.2`
  - `require_latest_rhwp=true`, `include_rhwp_in_title=true`, `draft=false`, `prerelease=false` 유지
- `mydocs/working/task_m900_441_stage1.md`
  - live release context, 변경 경계, 검증 결과와 다음 승인 gate 기록
- `mydocs/orders/20260728.md`
  - #441을 `Stage 1 완료 · Stage 2 승인 대기`로 갱신

보고서와 오늘할일을 제외한 source 변경량은 5개 파일, 12줄 추가와 12줄 삭제다.

## Public surface와 dependency inventory

Stage 1 변경 전 세 target은 모두 `0.1.8 (14)`였고, 변경 후 모두 `0.1.9 (15)`다.

core와 bundled studio의 기준은 다음 값으로 일치했다.

| 원천 | tag / resolved commit |
|------|------------------------|
| `rhwp-core.lock` | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| `RustBridge/Cargo.lock` | git tag `v0.8.2` / commit `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| `RhwpCoreBuildInfo` | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| bundled studio manifest | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |

변경하지 않은 현재 public/distribution surface는 다음과 같다.

- public Pages 최신 다운로드와 release note: `v0.1.8`
- public Sparkle appcast: short version `0.1.8`, build `14`
- repository `Casks/alhangeul.rb`: `0.1.7`
- repository `docs/appcast.xml`: source tree의 기존 placeholder 상태 유지

public Pages, stable appcast와 Cask는 Stage 1에서 변경하지 않았다. release communication은 Stage 2, 실제 stable appcast/Pages 생성은 official Publish gate, Cask 갱신은 public DMG URL/SHA256 확정 뒤 별도 Homebrew 승인 gate의 소유다.

## 본문 변경 정도 / 본문 무손실 여부

세 plist는 version/build 문자열만 교체했다. bundle identifier, document type, imported UTI, extension 설정과 나머지 plist 본문은 변경하지 않았다.

두 workflow는 `workflow_dispatch.inputs`의 release identity 기본값 세 항목만 교체했다. job, permission, concurrency, signing/notary secret 경계, tag 검증, upstream latest guard, GitHub Release, Sparkle와 Pages 동작은 변경하지 않았다.

Publish workflow의 보호 기본값은 다음과 같이 유지했다.

```text
require_latest_rhwp: true
include_rhwp_in_title: true
draft: false
prerelease: false
```

## 검증 결과

### GitHub와 branch 기준선

- `git fetch origin --prune`: 통과
- `origin/devel`: 승인 당시 candidate와 동일
- `origin/main...origin/devel`: `3 38`
- `v0.1.9`: local tag와 remote matching ref 없음
- GitHub App open PR 조회: `base:devel` 0건, `base:main` 0건
- 최신 앱/upstream release 조회: 각각 `v0.1.8`, `v0.8.2`

### plist version/build

`plutil -lint` 결과:

```text
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK
```

추출한 version/build:

```text
HostApp: 0.1.9 (15)
QLExtension: 0.1.9 (15)
ThumbnailExtension: 0.1.9 (15)
```

### core와 bundled studio provenance

```text
v0.8.2
9b16aa9e23f476e2b335d7c029fc9f24a199d63c
OK: RhwpCoreBuildInfo matches rhwp-core.lock
OK: rhwp-studio assets verified
```

`scripts/ci/read-rhwp-core-lock.sh`, `scripts/verify-rhwp-core-build-info.sh`, `scripts/verify-rhwp-studio-assets.sh --tag v0.8.2 --commit 9b16aa9e...`가 모두 exit code 0으로 통과했다.

### workflow와 diff

- Ruby `Psych.parse_file`로 두 release workflow YAML을 파싱: exit code 0
- 두 workflow default: `0.1.9`, `v0.1.8`, `v0.8.2`
- Publish boolean 보호 기본값: `true`, `true`, `false`, `false`
- `rg` identity scan: 이전 workflow 기본값 `v0.1.7`, `v0.7.18` 잔존 없음
- `git diff --check`: 통과
- source diff: 계획된 plist 3개와 workflow 2개만 존재

로컬 Ruby는 사용하지 않는 `ffi-1.13.1` native extension 미빌드 경고를 출력했지만 `Psych` YAML parse 결과와 exit code에는 영향을 주지 않았다.

## 잔여 위험

- Stage 1 candidate는 현재 `76c86fc...`지만 이후 `devel` merge로 이동할 수 있다. 이동 시 포함 PR 범위와 영향받는 검증을 자동 승계하지 않고 다시 계산해야 한다.
- `main` 전용 PR #432 변경이 존재한다. Stage 4 release PR 전 reviewed `main -> devel` back-merge 필요 여부와 merge tree를 다시 확인해야 한다.
- repository Cask는 `0.1.7`로 public 앱 `v0.1.8`보다 뒤에 있다. 이번 단계에서 임의 보정하지 않았으며 `v0.1.9` official public DMG URL과 SHA256 확정 뒤 별도 Homebrew 승인 gate에서 처리한다.
- 이번 단계는 앱 build, static archive strict/portable 판정, universal slice, package, signed/notarized DMG, 실제 Finder/Preview, Sparkle와 Intel Mac smoke를 수행하지 않았다.
- Release Rehearsal/Publish workflow를 실행하지 않았으므로 이번 검증은 workflow 구문과 입력 기본값까지만 보장한다.

## 다음 단계 영향

Stage 2는 고정된 `v0.1.8..76c86fc...` 초기 범위에서 포함 PR을 분석하고 `v0.1.9` release communication을 작성한다.

- PR #436의 upstream `rhwp v0.8.2` full sync와 PR #440의 통합 검증을 중심으로 사용자 영향을 확인한다.
- PR #437, #434, #431, #428은 실제 public `v0.1.8` 포함 여부, merge 시점과 release closeout 경계를 확인한 뒤 직접 반영/운영 기록/중복으로 분류한다.
- release note, README와 Pages 문구는 PR title만으로 작성하지 않고 각 PR body, 연결 Issue와 최종 보고서 근거로 작성한다.
- Stage 2 시작 시 최신 앱/upstream release와 `origin/main`, `origin/devel`을 다시 조회한다.

## 승인 요청

Stage 1의 release context 확정, source metadata 정렬과 검증 결과를 승인하고 Stage 2 `포함 PR 분석과 release communication 작성` 진입을 요청한다.
