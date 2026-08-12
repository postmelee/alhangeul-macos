# Task M020 #439 Stage 1 완료보고서

## 단계 목적

`rhwp-core.lock`이 완성되는 시점과 `RhwpCoreBuildInfo`의 소비 경로를 확인하고, deterministic writer/verifier/test의 인터페이스와 stable/demo 지원 경계를 확정한다. 또한 upstream sync, PR CI, release workflow가 각각 갱신과 검증 중 어떤 책임을 가져야 하는지 고정한다.

이번 단계는 제품 source, helper, workflow를 변경하지 않고 다음 항목을 조사했다.

- `update-rhwp-core.sh`와 `build-rust-macos.sh`의 lock 생성·완성 순서
- lock reader와 기존 build info verifier의 production contract
- `RhwpCoreBuildInfo`의 소비 지점과 thumbnail cache 식별자 영향
- upstream sync, PR CI, release rehearsal/publish의 호출 graph
- path classification과 generated PR body의 build info 누락 범위
- stable release tag와 demo commit pin을 같은 Swift schema로 표현하는 방법

## 산출물

- `mydocs/working/task_m020_439_stage1.md`
  - 조사 결과와 Stage 2 구현 계약을 기록했다.
- `mydocs/orders/20260813.md`
  - #439 비고를 `Stage 1 완료 및 Stage 2 승인 대기`로 갱신했다.

제품 source, helper, workflow tracked file은 수정하지 않았다.

## 조사 결과

### lock 완성 시점과 writer 호출 위치

`scripts/update-rhwp-core.sh`는 Cargo dependency를 변경한 뒤 artifact metadata가 비어 있는 lock skeleton을 만든다. stable은 `rhwp_ref_kind = "release-tag"`, release tag와 resolved commit을 기록하고, demo는 `rhwp_ref_kind = "commit"`, 실제 commit과 확인 가능한 최신 stable release 정보를 기록한다. 이 시점에는 `rhwp_enabled_features`와 완성된 artifact metadata가 없다.

`scripts/build-rust-macos.sh --update-lock`가 Cargo.toml의 enabled features와 빌드 산출물의 hash/size를 기록해 lock을 완성한다. 따라서 build info writer를 `update-rhwp-core.sh` 직후에 호출하면 incomplete lock을 읽게 된다.

확정 순서:

1. `scripts/update-rhwp-core.sh`
2. `scripts/build-rust-macos.sh --update-lock`
3. `scripts/update-rhwp-core-build-info.sh`
4. `scripts/verify-rhwp-core-build-info.sh`
5. bundled studio sync/verify
6. generated candidate 명시 stage

writer는 `build-rust-macos.sh` 내부에서 암묵적으로 실행하지 않는다. build helper가 tracked Swift source를 예상 밖으로 변경하지 않게 하고, source 생성은 upstream sync와 maintainer의 명시 호출에서만 수행한다.

### `RhwpCoreBuildInfo` 소비와 cache 영향

현재 build info의 직접 소비 지점은 `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`이다. `releaseTag`, `commit`, `enabledFeatures`가 thumbnail render signature에 함께 포함된다.

따라서 demo에서 stable 기준 tag를 보조 label로 사용해도 실제 demo commit이 별도 필드로 signature에 포함되므로 서로 다른 commit 사이의 cache 재사용은 일어나지 않는다. 이 점을 근거로 demo commit pin도 기존 Swift schema를 변경하지 않고 지원할 수 있다.

### stable/demo 값 매핑

writer와 verifier는 두 ref kind를 모두 지원한다.

| `rhwp_ref_kind` | `RhwpCoreBuildInfo.releaseTag` | `commit` | `enabledFeatures` |
|------|------|------|------|
| `release-tag` | `rhwp_release_tag` | 실제 `rhwp_commit` | 실제 `rhwp_enabled_features` |
| `commit` | `rhwp_latest_checked_release_tag` | 실제 `rhwp_commit` | 실제 `rhwp_enabled_features` |

demo의 `releaseTag`는 해당 commit에 tag가 붙었다는 의미가 아니라 호환성을 마지막으로 확인한 stable baseline label이다. 실제 provenance와 cache invalidation 기준은 `commit`이 담당한다. 이 의미는 Stage 4 운영 문서에 명시한다.

다음 입력은 source를 변경하지 않고 실패해야 한다.

- `rhwp_lock_version != 2`
- `rhwp_ref_kind`가 `release-tag` 또는 `commit`이 아님
- stable의 `rhwp_release_tag` 누락
- demo의 `rhwp_latest_checked_release_tag` 누락
- 40자리 소문자 hex가 아닌 commit
- 누락되거나 허용 형식이 아닌 enabled features
- Swift 문자열 literal에 안전하게 넣을 수 없는 tag

demo path를 stable 전용 gate에서 제외하거나 skip하지 않는다. verifier가 두 ref kind를 같은 규칙으로 검증하므로 PR CI와 release source preflight도 조건 없이 실행할 수 있다.

### helper exact interface

기존 production 호출의 no-argument contract를 보존한다.

| helper | 확정 interface | 책임 |
|------|------|------|
| lock reader | `read-rhwp-core-lock.sh [--lock-file FILE] <key>` | 기본값은 repository root lock, fixture에서만 명시 경로 허용 |
| writer | `update-rhwp-core-build-info.sh [--lock-file FILE] [--output FILE]` | lock 검증, 고정 형식 Swift 생성, 안전한 교체 |
| verifier | `verify-rhwp-core-build-info.sh [--lock-file FILE] [--build-info FILE]` | lock과 Swift 상수의 일치 여부만 검증 |
| isolated test | `test-rhwp-core-build-info.sh` | 임시 fixture에서 writer/verifier 계약과 production 파일 무손실 검증 |

production 기본 경로는 환경 변수로 치환하지 않는다. fixture 경로는 명시 옵션으로만 전달한다. 기존 `read-rhwp-core-lock.sh <key>`와 `verify-rhwp-core-build-info.sh` 호출은 그대로 동작해야 한다.

writer는 다음 고정 형식의 Swift source를 생성한다.

```swift
enum RhwpCoreBuildInfo {
    static let releaseTag = "<tag>"
    static let commit = "<commit>"
    static let enabledFeatures = "<features>"
}
```

생성 파일을 output과 같은 디렉터리의 임시 파일에 쓴 뒤, 입력과 생성 결과를 검증하고 `cmp`로 동일 여부를 확인한다. 동일하면 교체하지 않고, 다를 때만 원자적으로 교체해 같은 입력에서 byte-identical 결과와 no-diff를 보장한다.

### isolated fixture 범위

Stage 2 test는 임시 디렉터리의 lock/build info만 사용하고 다음 case를 고정한다.

- stable 정상 생성과 verifier 통과
- demo 정상 생성과 baseline tag/실제 commit 매핑 확인
- stale tag, commit, features 각각 verifier 실패 후 writer로 수렴
- 필수 key 누락, 잘못된 ref kind, malformed tag/commit/features 거부
- demo latest checked release tag 누락 거부
- writer 재실행 시 byte-identical/no-diff
- test 전후 tracked `rhwp-core.lock`과 `RhwpCoreBuildInfo.swift` hash 동일

### workflow별 책임

| 경로 | writer | verifier/test | 확정 위치 |
|------|------|------|------|
| upstream full sync | 실행 | writer 직후 verifier | complete lock 생성 직후, studio sync 전 |
| PR CI | 실행하지 않음 | fixture test + tracked source verifier | helper interface와 macOS validation gate |
| release rehearsal | 실행하지 않음 | tracked source verifier | source preflight의 lock 검증 직후 |
| release publish | 실행하지 않음 | tracked source verifier | source preflight의 lock 검증 직후 |

CI와 release가 writer로 drift를 자동 수정하면 검증 대상 working tree와 게시 source가 달라질 수 있으므로 반드시 실패만 시킨다.

### 현재 누락 범위

- upstream sync workflow는 lock과 bundled studio를 갱신하지만 build info를 생성·검증·stage하지 않는다.
- generated verification summary와 PR body checklist에 build info 항목이 없다.
- PR CI와 release rehearsal/publish는 `build-rust-macos.sh --verify-lock`를 호출하지만 standalone build info verifier를 호출하지 않는다.
- `scripts/ci/classify-pr-changes.sh`는 build info writer/verifier와 Swift build info 변경을 core/Rust gate 대상으로 명시하지 않는다.

이 항목들은 Stage 3에서 수정한다. Stage 2에서는 workflow와 classification을 변경하지 않는다.

### Stage 2 변경 표면 확정

Stage 2는 다음 네 파일로 제한한다.

- 신규 `scripts/update-rhwp-core-build-info.sh`
- `scripts/verify-rhwp-core-build-info.sh`
- `scripts/ci/read-rhwp-core-lock.sh`
- 신규 `scripts/ci/test-rhwp-core-build-info.sh`

현재 production lock과 build info가 이미 일치하므로 `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`는 writer no-diff 검증 대상이며 의도된 diff에는 포함하지 않는다. `update-rhwp-core.sh`, workflow, classification, PR body helper는 Stage 3에서 다룬다. Cargo.lock fingerprint를 다루는 #375 범위도 변경하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 신규 조사 보고서 작성과 오늘할일 비고 갱신만 수행했다. 조사 대상 source/helper/workflow의 본문은 변경하지 않았다.

## 검증 결과

계획서에 명시한 Stage 1 검증 명령을 실행했다.

```text
./scripts/verify-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo matches rhwp-core.lock

bash scripts/update-rhwp-core.sh --help
bash scripts/build-rust-macos.sh --help
bash scripts/ci/read-rhwp-core-lock.sh --help
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/write-rhwp-full-sync-pr-body.sh --help
결과: 모두 usage 출력 후 정상 종료

rg -n "RhwpCoreBuildInfo|verify-rhwp-core-build-info|rhwp_enabled_features|update-lock" Sources scripts .github/workflows
결과: build info 소비, lock feature 기록, sync workflow update-lock 위치와 verifier 미연결 상태 확인

git diff --check
결과: 통과
```

검증 직후 `git status --short --branch`는 변경 전 `## local/task439`로 깨끗했다.

## 잔여 위험

- demo의 `releaseTag`가 release provenance로 오해될 수 있으므로 Stage 4 문서에서 stable baseline label 의미를 명확히 설명해야 한다.
- shell에서 Swift 문자열을 생성하므로 tag/features 문자 검증을 느슨하게 두면 source injection 또는 비결정적 출력 위험이 있다. Stage 2에서 허용 문자를 제한하고 실패 case를 fixture로 고정한다.
- writer의 output 경로 옵션은 fixture에 필요하지만 임의 tracked 파일을 덮어쓸 수 있다. 생성 전 입력 검증, output directory 임시 파일, 동일 파일 no-op, 명확한 에러를 구현한다.
- path classification과 workflow stage 목록이 Stage 3에서 함께 갱신되지 않으면 helper 자체는 정상이어도 upstream PR에 Swift 파일이 포함되지 않을 수 있다.
- #375의 Cargo.lock fingerprint 변경과 PR #463 갱신/재생성은 계속 범위 밖이다.

## 다음 단계 영향

Stage 2에서는 확정한 네 helper/test 파일만 변경한다.

1. lock reader에 기존 호출과 호환되는 `--lock-file` 옵션을 추가한다.
2. stable/demo lock을 검증하고 고정 형식 Swift source를 안전하게 생성하는 writer를 추가한다.
3. verifier에 명시적 fixture 경로 옵션과 stable/demo 매핑을 반영한다.
4. isolated fixture test로 정상, stale, malformed, convergence, production 파일 무손실을 검증한다.
5. current production input에서 writer가 no-diff이고 verifier가 통과하는지 확인한다.

workflow 연결과 운영 문서 변경은 각각 Stage 3과 Stage 4까지 보류한다.

## 승인 요청

Stage 1 결과에 따라 Stage 2로 진행해도 되는지 승인 요청한다.

Stage 2에서는 `scripts/update-rhwp-core-build-info.sh`, `scripts/verify-rhwp-core-build-info.sh`, `scripts/ci/read-rhwp-core-lock.sh`, `scripts/ci/test-rhwp-core-build-info.sh`만 변경하고, 완료 시 source와 Stage 2 보고서를 함께 검증·커밋한 뒤 Stage 3 승인 대기에서 멈춘다.
