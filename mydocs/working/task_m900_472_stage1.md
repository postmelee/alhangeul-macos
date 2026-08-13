# Task M900 #472 Stage 1 완료보고서

## 단계 목적

`v0.1.10` public release 시작 기준을 live 상태로 다시 고정하고, 세 app target과 Release Rehearsal/Publish workflow 기본 입력을 승인된 `0.1.10 (16)`, 직전 공개 버전 `v0.1.9`, upstream `rhwp v0.8.4`로 정렬한다.

이번 단계는 source metadata 정렬까지만 수행했다. Release Rehearsal/Publish workflow 실행, 원격 branch push, PR 생성·merge, tag 생성과 GitHub Release·Pages·Sparkle·Homebrew 변경은 수행하지 않았다.

## Release context 기준선

조회 시각은 `2026-08-13 16:37 KST`다.

| 항목 | 확인 결과 |
|------|-----------|
| 최신 공개 앱 release | `v0.1.9`, draft 아님, prerelease 아님 |
| 앱 release publishedAt | `2026-07-30T16:17:53Z` |
| 앱 release URL | `https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.9` |
| 직전 public ref peeled commit | `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| 최신 upstream release | `v0.8.4`, draft 아님, prerelease 아님 |
| upstream publishedAt | `2026-08-12T01:33:52Z` |
| upstream release URL | `https://github.com/edwardkim/rhwp/releases/tag/v0.8.4` |
| `origin/main` | `26f3104469135c5e80b3a19dddb9d0baebfbfb0a` |
| `origin/devel` / Stage 1 candidate | `4abdc30746edcd25be3d11fa3d5c1e09f600c6c3` |
| merge base | `9e564ff79410bd06c36b36d3dd3cd6fa2b6e4c49` |
| `origin/main...origin/devel` | main 전용 3개 / devel 전용 68개 commit |
| `v0.1.10` tag | local과 GitHub remote matching ref 모두 없음 |
| 열린 PR | Draft #462 한 건, `main` 대상이며 Task #472 범위에서 명시 제외 |
| release-critical 열린 PR | 없음 |
| Issue #472 | Open, milestone `Release Operations` |

`origin/devel`은 Issue 등록, 수행계획과 구현계획 승인 당시 candidate인 `4abdc30746edcd25be3d11fa3d5c1e09f600c6c3`에서 이동하지 않았다. 최신 앱과 upstream release도 승인된 identity와 일치하므로 Stage 1 metadata 정렬을 계속 수행했다.

`v0.1.9..origin/devel` first-parent merge inventory는 다음과 같다.

```text
4abdc30 Merge pull request #471 from postmelee/automation/rhwp-v0.8.4-full-sync
c0fce3c Merge pull request #468 from postmelee/publish/task467
af7994b Merge pull request #465 from postmelee/publish/task375
dce0c65 Merge pull request #464 from postmelee/publish/task439
b7beb3d Merge pull request #461 from postmelee/publish/task460
98546c8 Merge pull request #458 from postmelee/publish/task455
f617e3f Merge pull request #457 from postmelee/publish/task456
b04c2ba Merge pull request #454 from postmelee/publish/task453
9e564ff Merge pull request #451 from postmelee/publish/task441
```

PR #451은 `v0.1.9` release closeout의 `devel` 반영이므로 Stage 2 신규 사용자-facing 변화에서 제외한다. PR #454, #457, #458, #461, #464, #465, #468과 #471은 Stage 2에서 PR body, 연결 Issue와 최종 보고서를 근거로 분류한다.

## main 전용 commit과 back-merge 판정

`origin/main` 전용 3개 commit은 모두 `devel -> main` merge transport다.

| main commit | PR | 역할 | tree 판정 |
|-------------|----|------|-----------|
| `1e7f5df59684713745cb9d59c0a0e9dfdaaf0272` | #446 | 최초 v0.1.9 release candidate 승격 | merge tree가 head `1b1213d...` tree와 동일 |
| `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` | #450 | PR #448 반영 후보 재승격과 final v0.1.9 tag commit | merge tree가 head `485c76c...` tree와 동일 |
| `26f3104469135c5e80b3a19dddb9d0baebfbfb0a` | #452 | v0.1.9 Homebrew·릴리즈 closeout 승격 | current main tree가 head `9e564ff...` tree와 동일 |

확인한 tree identity는 다음과 같다.

```text
PR #446 merge/head tree: c07e52d44c9321e0ab2ffca0e9d5deddae54d32e
PR #450 merge/head tree: c08f8c815f25bd079093cd75ffe96c9aac03d752
origin/main / 9e564ff tree: 8f52d69bbf99db08e4836969d31f879ce5c09308
```

따라서 `main`에만 존재하고 `devel`에서 누락된 file content는 없다. 현재 merge base도 PR #451 merge commit `9e564ff...`이며 `origin/main` tree와 그 commit tree가 정확히 같다.

판정은 다음처럼 분리한다.

- content 동기화 목적의 back-merge: 불필요
- release branch 이력 정렬 목적의 back-merge: 필요 권고

Stage 1~3 source PR merge 뒤에도 `main` 전용 release transport commit은 `devel`의 ancestor가 아니다. `devel -> main` v0.1.10 release PR이 이번 release 변화만 명확히 표시되도록 Stage 4에서 tree 변경 없는 reviewed `main -> devel` back-merge PR을 별도 승인으로 먼저 처리한다. 실행 직전 branch가 이동하면 tree와 merge 결과를 다시 계산한다.

## 산출물

- `Sources/HostApp/Info.plist`
  - `CFBundleShortVersionString`: `0.1.9` -> `0.1.10`
  - `CFBundleVersion`: `15` -> `16`
- `Sources/QLExtension/Info.plist`
  - `CFBundleShortVersionString`: `0.1.9` -> `0.1.10`
  - `CFBundleVersion`: `15` -> `16`
- `Sources/ThumbnailExtension/Info.plist`
  - `CFBundleShortVersionString`: `0.1.9` -> `0.1.10`
  - `CFBundleVersion`: `15` -> `16`
- `.github/workflows/release-rehearsal.yml`
  - `version`: `0.1.9` -> `0.1.10`
  - `previous_release_ref`: `v0.1.8` -> `v0.1.9`
  - `expected_rhwp_tag`: `v0.8.2` -> `v0.8.4`
- `.github/workflows/release-publish.yml`
  - `version`: `0.1.9` -> `0.1.10`
  - `previous_release_ref`: `v0.1.8` -> `v0.1.9`
  - `expected_rhwp_tag`: `v0.8.2` -> `v0.8.4`
  - `require_latest_rhwp=true`, `include_rhwp_in_title=true`, `draft=false`, `prerelease=false` 유지
- `mydocs/working/task_m900_472_stage1.md`
  - live release context, main-only commit 판정, 변경 경계와 검증 결과 기록
- `mydocs/orders/20260813.md`
  - #472를 `Stage 1 완료 · Stage 2 승인 대기`로 갱신

보고서와 오늘할일을 제외한 source 변경량은 5개 파일, 12줄 추가와 12줄 삭제다.

## Public surface와 dependency inventory

Stage 1 변경 전 세 target은 모두 `0.1.9 (15)`였고, 변경 후 모두 `0.1.10 (16)`다.

core와 bundled studio의 기준은 다음 값으로 일치했다.

| 원천 | tag / resolved commit |
|------|------------------------|
| `rhwp-core.lock` | `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| `RustBridge/Cargo.lock` | git tag `v0.8.4` / commit `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| `RhwpCoreBuildInfo` | `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| bundled studio manifest | `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |

bundled studio manifest의 `source_cargo_lock_sha256`은 `217783dc2ee85525ff8eaefd3ae6b44a8523d0a38daaf6031f3cc277de16b893`다. Stage 1은 manifest와 bundled asset 무결성까지만 검사했다. target upstream checkout의 실제 root `Cargo.lock` 비교는 계획대로 Stage 3 strict provenance gate에서 수행한다.

변경하지 않은 현재 public/distribution surface는 다음과 같다.

- public Pages 최신 다운로드와 release note: `v0.1.9`
- public Sparkle appcast: short version `0.1.9`, build `15`
- public Sparkle enclosure: `alhangeul-macos-0.1.9.dmg`
- repository `Casks/alhangeul.rb`: version `0.1.9`, official SHA256 `8110dc4c...`

public Pages, stable appcast와 Cask는 Stage 1에서 변경하지 않았다. release communication은 Stage 2, 실제 stable appcast/Pages 생성은 official Publish gate, Cask 갱신은 public DMG URL/SHA256 확정 뒤 별도 Homebrew 승인 gate의 소유다.

## 본문 변경 정도 / 본문 무손실 여부

세 plist는 version/build 문자열만 교체했다. bundle identifier, document type, imported UTI, analytics endpoint, extension 설정과 나머지 plist 본문은 변경하지 않았다.

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
- `origin/main...origin/devel`: `3 68`
- `v0.1.10`: local tag와 remote matching ref 없음
- 열린 PR: Draft #462 한 건이며 수행계획 제외 범위
- 최신 앱/upstream release 조회: 각각 `v0.1.9`, `v0.8.4`
- Issue #472: Open, `Release Operations`

### plist version/build

`plutil -lint` 결과:

```text
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK
```

추출한 version/build:

```text
HostApp: 0.1.10 (16)
QLExtension: 0.1.10 (16)
ThumbnailExtension: 0.1.10 (16)
```

### core와 bundled studio provenance

```text
v0.8.4
496333b27d21ddb9114ba9ae340bcb895870c9a7
OK: RhwpCoreBuildInfo.swift matches rhwp-core.lock
OK: rhwp-studio assets verified
```

`scripts/ci/read-rhwp-core-lock.sh`, `scripts/verify-rhwp-core-build-info.sh`, `scripts/verify-rhwp-studio-assets.sh --tag v0.8.4 --commit 496333b...`가 모두 exit code 0으로 통과했다.

### workflow와 diff

- Ruby `Psych.parse_file`로 두 release workflow YAML을 파싱: exit code 0
- 두 workflow default: `0.1.10`, `v0.1.9`, `v0.8.4`
- Publish boolean 보호 기본값: `true`, `true`, `false`, `false`
- identity scan: 이전 workflow 기본값 `v0.1.8`, `v0.8.2` 잔존 없음
- `git diff --check`: 통과
- source diff: 계획된 plist 3개와 workflow 2개만 존재

로컬 Ruby는 사용하지 않는 `ffi-1.13.1` native extension 미빌드 경고를 출력했지만 `Psych` YAML parse 결과와 exit code에는 영향을 주지 않았다.

## 잔여 위험

- Stage 1 candidate는 현재 `4abdc30...`지만 이후 `devel` merge로 이동할 수 있다. 이동 시 포함 PR 범위와 영향받는 검증을 자동 승계하지 않고 다시 계산해야 한다.
- `main` 전용 3개 commit은 content 누락은 없지만 이력상 `devel`의 ancestor가 아니다. Stage 4에서 별도 승인된 history-only back-merge로 정렬하기 전 release PR을 만들지 않는다.
- 로컬 v0.8.4 strict static archive hash/size 차이는 이번 단계에서 재검증하지 않았다. lock을 갱신하지 않았으며 Stage 3에서 strict/portable 결과를 분리한다.
- target upstream root `Cargo.lock` fingerprint의 실제 checkout 비교는 Stage 3 전까지 미실행이다.
- 이번 단계는 앱 build, universal slice, package, 저장·PDF·인쇄, signed/notarized DMG, 실제 Finder/Preview, Sparkle와 Intel Mac smoke를 수행하지 않았다.
- Release Rehearsal/Publish workflow를 실행하지 않았으므로 이번 검증은 workflow 구문과 입력 기본값까지만 보장한다.

## 다음 단계 영향

Stage 2는 고정된 `v0.1.9..4abdc30...` 범위에서 포함 PR을 분석하고 `v0.1.10` release communication을 작성한다.

- PR #457의 HWP/HWPX 저장과 PR #458의 native PDF·인쇄는 사용자-facing 주요 변화 후보로 검토한다.
- PR #461은 PDF·인쇄 WebKit trust boundary와 정상 경로 보존을 함께 설명한다.
- PR #468과 #471은 v0.8.4 viewer compatibility/sync 근거를 연결한다.
- PR #464와 #465는 build-info와 Cargo.lock provenance gate로 개발자·운영 세부에 분류한다.
- PR #454는 익명 실행 분석의 개인정보 경계와 실제 사용자-facing 의미를 확인한다.
- PR #451과 release transport는 신규 사용자-facing 변화에서 제외한다.
- release note, README와 Pages 문구는 PR title만으로 작성하지 않고 각 PR body, 연결 Issue와 최종 보고서 근거로 작성한다.
- Stage 2 시작 시 최신 앱/upstream release와 `origin/main`, `origin/devel`을 다시 조회한다.

## 승인 요청

Stage 1의 release context 확정, main-only back-merge 판정, source metadata 정렬과 검증 결과를 승인하고 Stage 2 `포함 PR 분석과 release communication 작성` 진입을 요청한다.
