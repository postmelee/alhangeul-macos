# Task M020 #388 Stage 2 완료보고서

## 단계 목적

`HwpThumbnailRenderSignature`가 stale hardcoded core metadata 대신 current `rhwp-core.lock` 기준 build info를 참조하도록 수정한다.

Stage 1 결론에 따라 build info source는 `Sources/RhwpCoreBridge`에 두고, Thumbnail signature와 관련 smoke/check script source list를 보정했다.

## 산출물

- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`
  - `rhwp-core.lock`의 current core metadata를 Swift constant로 노출한다.
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
  - `HwpThumbnailRenderSignature`의 core release tag, commit, enabled features 기본값을 `RhwpCoreBuildInfo` 참조로 변경했다.
- `scripts/check-no-appkit.sh`
  - 새 `RhwpCoreBuildInfo.swift`를 AppKit/UIKit 금지 검사 목록에 포함했다.
- `scripts/smoke-thumbnail-skia-policy.sh`
  - 수동 `swiftc` compile list에 `RhwpCoreBuildInfo.swift`를 추가했다.
- `mydocs/working/task_m020_388_stage2.md`
  - Stage 2 결과와 검증을 기록했다.
- `mydocs/orders/20260629.md`
  - #388 비고를 `Stage 2 완료보고서 승인 대기`로 갱신했다.

## 변경 내용

### RhwpCoreBuildInfo 추가

`Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`를 추가했다.

현재 값:

```swift
enum RhwpCoreBuildInfo {
    static let releaseTag = "v0.7.17"
    static let commit = "03351190ec35436e58cbfee0aa9278a8fdc04a59"
    static let enabledFeatures = "native-skia"
}
```

이 파일은 AppKit/UIKit 또는 Foundation 의존이 없고, `RhwpCoreBridge` target source에 포함된다.

### Thumbnail signature refactor

`HwpThumbnailRenderSignature`의 기존 하드코딩을 다음 참조로 변경했다.

```swift
private static let coreReleaseTag = RhwpCoreBuildInfo.releaseTag
private static let coreCommit = RhwpCoreBuildInfo.commit
private static let coreEnabledFeatures = RhwpCoreBuildInfo.enabledFeatures
```

`identifier` 필드 순서와 cache key 구조는 바꾸지 않았다. 따라서 backend policy, renderer option version, core metadata, maxDimension policy version을 함께 분리하는 기존 cache 의미가 유지된다.

### smoke/check script 보정

`scripts/smoke-thumbnail-skia-policy.sh`는 `swiftc` 파일 목록을 직접 나열하므로 `RhwpCoreBuildInfo.swift`를 추가했다. 그렇지 않으면 Xcode target build는 통과하더라도 smoke helper compile에서 `RhwpCoreBuildInfo` symbol을 찾지 못할 수 있다.

`scripts/check-no-appkit.sh`도 hardcoded 검사 파일 목록을 사용하므로 새 bridge source를 검사 대상에 넣었다.

## 본문 변경 정도 / 본문 무손실 여부

기존 제품 동작의 render policy나 cache key 필드 구성은 바꾸지 않았다.

변경된 의미는 `HwpThumbnailRenderSignature`의 기본 core metadata source가 stale literal에서 `RhwpCoreBuildInfo`로 바뀐 것이다. 이로 인해 현재 default signature는 `v0.7.17`, `03351190ec35436e58cbfee0aa9278a8fdc04a59`, `native-skia` 기준을 사용한다.

## 검증 결과

### stale metadata 검색

```text
rg -n "v0\.7\.13|b3e16ef" Sources
결과: 매치 없음
```

### build info 참조 확인

```text
Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift:1:enum RhwpCoreBuildInfo {
Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:51:    private static let coreReleaseTag = RhwpCoreBuildInfo.releaseTag
Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:52:    private static let coreCommit = RhwpCoreBuildInfo.commit
Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:53:    private static let coreEnabledFeatures = RhwpCoreBuildInfo.enabledFeatures
scripts/check-no-appkit.sh:7:  "$ROOT/Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift"
scripts/smoke-thumbnail-skia-policy.sh:86:  "$ROOT/Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift" \
```

### AppKit/UIKit boundary

```text
scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

### Thumbnail smoke compile/run

```text
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task388-stage2-smoke samples/basic/KTX.hwp
KTX.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
```

명령 중 `DVTFilePathFSEvents`와 `DARWIN_USER_CACHE_DIR` 관련 xcodebuild 경고가 출력됐지만, smoke helper는 exit 0으로 완료됐다.

### diff 검증

```text
git diff --check
결과: 통과
```

## 잔여 위험

- `RhwpCoreBuildInfo.swift` 값은 아직 사람이 갱신해야 하는 constant다. Stage 3에서 `rhwp-core.lock`과 이 파일의 정합성 검증을 추가해야 core pin 변경 시 누락을 잡을 수 있다.
- 다른 수동 `swiftc` script가 후속 단계에서 `HwpThumbnailRenderCache.swift` 또는 `RhwpCoreBuildInfo`를 함께 쓰게 되면 compile list 보정이 추가로 필요할 수 있다.
- `RhwpCoreBuildInfo`가 source of truth가 아니라 lock mirror라는 점을 문서/검증에서 명확히 유지해야 한다.

## 다음 단계 영향

Stage 3에서는 lock/build info 정합성 검증 script를 추가한다.

권장 방향:

1. `scripts/ci/read-rhwp-core-lock.sh`로 `rhwp_release_tag`, `rhwp_commit`, `rhwp_enabled_features`를 읽는다.
2. `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`에서 대응하는 literal 값을 확인한다.
3. mismatch 시 lock key, Swift field, 기대값, 실제값을 출력하고 실패한다.
4. 현재 Stage 2 상태에서는 검증이 통과해야 한다.

## 승인 요청

Stage 2 결과에 따라 Stage 3로 진행해도 되는지 승인 요청한다.

Stage 3에서는 `rhwp-core.lock`과 `RhwpCoreBuildInfo.swift`의 정합성 검증 경로를 추가한다.
