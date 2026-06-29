# Task M020 #388 Stage 1 완료보고서

## 단계 목적

`HwpThumbnailRenderSignature`의 core metadata를 `rhwp-core.lock` 기준으로 정합화하기 전에, build info source 위치와 lock parser 재사용 경로를 결정한다.

이번 단계는 코드 변경 없이 다음 항목을 조사했다.

- `project.yml`의 target source inclusion 구조
- `scripts/build-rust-macos.sh`와 `scripts/ci/read-rhwp-core-lock.sh`의 lock parsing/verify 흐름
- `HwpThumbnailRenderSignature`의 stale metadata 위치
- smoke script의 수동 `swiftc` source list 영향

## 산출물

- `mydocs/working/task_m020_388_stage1.md`
  - Stage 1 조사 결과와 Stage 2 구현 방향을 기록했다.
- `mydocs/orders/20260629.md`
  - #388 비고를 `Stage 1 완료보고서 승인 대기`로 갱신했다.

제품 Swift/Rust source는 수정하지 않았다.

## 조사 결과

### target source inclusion

`project.yml` 기준으로 `HostApp`, `QLExtension`, `ThumbnailExtension` 모두 `Sources/Shared`와 `Sources/RhwpCoreBridge`를 포함한다.

- `HostApp`: `Sources/HostApp`, `Sources/Shared`, `Sources/RhwpCoreBridge`
- `QLExtension`: `Sources/QLExtension`, `Sources/Shared`, `Sources/RhwpCoreBridge`
- `ThumbnailExtension`: `Sources/ThumbnailExtension`, `Sources/Shared`, `Sources/RhwpCoreBridge`

따라서 build info source는 `Sources/RhwpCoreBridge` 또는 `Sources/Shared`에 두면 Xcode target에는 자동 포함된다. `Sources/ThumbnailExtension`에 두면 이번 문제는 가장 좁게 해결되지만, 후속 Quick Look/Shared 진단에서 같은 core metadata를 재사용하기 어렵다.

### build info 위치 후보

선택안:

- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`

이유:

- core provenance는 RustBridge와 Swift FFI wrapper의 경계 정보라 `RhwpCoreBridge` 책임에 가깝다.
- `HostApp`, `QLExtension`, `ThumbnailExtension`이 모두 `Sources/RhwpCoreBridge`를 포함한다.
- 파일 내용은 `Foundation`조차 필요 없는 constant enum으로 둘 수 있어 AppKit/UIKit 금지 규칙과 충돌하지 않는다.
- 후속 P1/P2/P3 작업에서 Quick Look/Shared 진단에도 같은 값을 재사용할 수 있다.

대안과 보류 이유:

- `Sources/Shared`: Quick Look/Thumbnail helper와 가깝지만, core provenance 책임은 Shared helper보다 bridge 경계에 더 가깝다.
- `Sources/ThumbnailExtension`: 변경 범위는 가장 작지만, 같은 metadata를 다른 surface가 재사용하기 어렵고 후속 중복 하드코딩 가능성이 남는다.

### lock parser 재사용

`scripts/build-rust-macos.sh`는 내부 `lock_scalar` 함수로 `rhwp-core.lock`을 읽고, `--verify-lock`에서 repo, ref kind, release tag, commit, enabled features, artifact metadata를 검증한다. 다만 이 함수는 스크립트 내부 함수라 별도 script가 직접 source해서 쓰기에는 적합하지 않다.

`scripts/ci/read-rhwp-core-lock.sh`는 top-level scalar 하나를 안정적으로 읽는 작은 helper이며, 현재 task에 필요한 세 값을 모두 읽을 수 있다.

- `rhwp_release_tag`
- `rhwp_commit`
- `rhwp_enabled_features`

Stage 3에서는 이 helper를 재사용하는 standalone 검증 script를 두는 편이 적절하다. `build-rust-macos.sh --verify-lock`에 바로 끼우면 Rust bridge build/lock 검증과 Swift build info 검증의 책임이 섞인다. 후속으로 필요하면 build script에서 standalone script를 호출하는 hook을 별도 검토할 수 있다.

### 현재 stale metadata 위치

`Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`의 `HwpThumbnailRenderSignature`에 다음 값이 직접 하드코딩되어 있다.

- `coreReleaseTag = "v0.7.13"`
- `coreCommit = "b3e16ef212af81ef37d973ddb86d6816d3804642"`
- `coreEnabledFeatures = "native-skia"`

현재 `rhwp-core.lock`은 다음 값이다.

- `rhwp_release_tag = "v0.7.17"`
- `rhwp_commit = "03351190ec35436e58cbfee0aa9278a8fdc04a59"`
- `rhwp_enabled_features = "native-skia"`

Stage 2에서는 `RhwpCoreBuildInfo`를 추가하고 `HwpThumbnailRenderSignature`의 default 값을 이 타입으로 교체한다.

### smoke script 영향

XcodeGen target은 폴더 단위 inclusion을 쓰지만, 일부 smoke script는 `swiftc` 입력 파일을 직접 나열한다. `RhwpCoreBuildInfo.swift`를 `Sources/RhwpCoreBridge`에 추가하면 적어도 다음 script는 compile list 보정이 필요하다.

- `scripts/smoke-thumbnail-skia-policy.sh`

Thumbnail signature가 새 build info 타입을 직접 참조하기 때문이다.

Quick Look/preview smoke script는 현재 `HwpThumbnailRenderCache.swift`를 컴파일하지 않으므로 Stage 2 변경만으로는 직접 영향이 없다. 다만 `RhwpCoreBuildInfo`를 후속 Quick Look 진단에서 재사용하면 해당 script들도 같은 방식으로 compile list 보정이 필요하다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 신규 조사 보고서 작성과 오늘할일 비고 갱신만 수행했다.

## 검증 결과

### target source inclusion 확인

```text
project.yml:28:      - path: Sources/Shared
project.yml:29:      - path: Sources/RhwpCoreBridge
project.yml:69:      - path: Sources/Shared
project.yml:70:      - path: Sources/RhwpCoreBridge
project.yml:102:      - path: Sources/ThumbnailExtension
project.yml:103:      - path: Sources/Shared
project.yml:104:      - path: Sources/RhwpCoreBridge
```

### lock parser와 current lock 확인

```text
scripts/ci/read-rhwp-core-lock.sh:6:LOCK_FILE="$ROOT/rhwp-core.lock"
scripts/build-rust-macos.sh:11:LOCK_FILE="$ROOT/rhwp-core.lock"
scripts/build-rust-macos.sh:518:    expected_release_tag="$(lock_scalar rhwp_release_tag)"
scripts/build-rust-macos.sh:530:  expected_commit="$(lock_scalar rhwp_commit)"
scripts/build-rust-macos.sh:546:  expected_enabled_features="$(lock_scalar rhwp_enabled_features)"
rhwp-core.lock:4:rhwp_release_tag = "v0.7.17"
rhwp-core.lock:5:rhwp_commit = "03351190ec35436e58cbfee0aa9278a8fdc04a59"
rhwp-core.lock:6:rhwp_enabled_features = "native-skia"
```

### stale metadata 확인

```text
Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:51:    private static let coreReleaseTag = "v0.7.13"
Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:52:    private static let coreCommit = "b3e16ef212af81ef37d973ddb86d6816d3804642"
Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:53:    private static let coreEnabledFeatures = "native-skia"
```

### diff 검증

```text
git diff --check: 통과
```

## 잔여 위험

- `RhwpCoreBuildInfo.swift`를 `Sources/RhwpCoreBridge`에 추가하면 `scripts/check-no-appkit.sh`의 hardcoded 검사 파일 목록에도 포함할지 Stage 2에서 판단해야 한다.
- `scripts/smoke-thumbnail-skia-policy.sh`는 `swiftc` 파일 목록을 직접 관리하므로 Stage 2에서 새 source를 누락하면 Xcode build는 통과해도 smoke compile은 실패할 수 있다.
- lock/build info 검증 script가 Swift source를 단순 문자열 검색으로 검사하면 형식 변화에 취약할 수 있다. Stage 3에서는 에러 메시지와 검사 범위를 좁혀 유지보수 비용을 줄여야 한다.

## 다음 단계 영향

Stage 2 구현 방향:

1. `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`를 추가한다.
2. `HwpThumbnailRenderSignature`의 `coreReleaseTag`, `coreCommit`, `coreEnabledFeatures` 기본값을 `RhwpCoreBuildInfo` 참조로 바꾼다.
3. `scripts/smoke-thumbnail-skia-policy.sh`의 `swiftc` source list에 `RhwpCoreBuildInfo.swift`를 추가한다.
4. 필요하면 `scripts/check-no-appkit.sh` 검사 목록에도 새 파일을 추가한다.

Stage 3 구현 방향:

1. `scripts/ci/read-rhwp-core-lock.sh`를 호출하는 standalone 검증 script를 추가한다.
2. Swift build info source와 lock 값의 일치 여부를 검사한다.
3. mismatch 시 build info 갱신 대상 파일과 lock key를 명확히 출력한다.

## 승인 요청

Stage 1 결과에 따라 Stage 2로 진행해도 되는지 승인 요청한다.

Stage 2에서는 `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift` 추가, `HwpThumbnailRenderSignature` 참조 변경, 관련 smoke/check script source list 보정을 수행한다.
