# Task M020 #388 구현계획서

수행계획서: `mydocs/plans/task_m020_388.md`

## 작업 개요

- 이슈: #388 Thumbnail render signature를 `rhwp-core.lock` 기준으로 생성/검증
- 추적 이슈: #387 Preview/Thumbnail Skia readiness 후속 개선 추적
- 마일스톤: `v0.2.x Skia Quick Look/Thumbnail Backend`
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task388`
- 목표: `HwpThumbnailRenderSignature`의 core metadata가 `rhwp-core.lock`과 일치하도록 만들고, 이후 core pin 변경 시 불일치를 검증으로 잡는다.

## 구현 원칙

- `rhwp-core.lock`을 source of truth로 둔다.
- release-critical Swift 코드에 core release tag와 commit을 직접 중복 하드코딩하지 않는다.
- Thumbnail cache key의 기존 분리 의도는 유지한다.
  - backend policy
  - renderer option version
  - core release tag
  - core commit
  - core enabled features
  - maxDimension policy version
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 넣지 않는다.
- Xcode project 원본은 `project.yml`이며, `Alhangeul.xcodeproj`는 직접 수정하지 않는다.
- generated file을 추가하는 경우 생성 명령, 검증 명령, target 포함 범위를 함께 정리한다.

## Stage 1. build info 위치와 lock parser 재사용 경로 조사

목표:

- `RhwpCoreBuildInfo` 성격의 Swift source를 어디에 둘지 결정한다.
- 기존 script와 XcodeGen source inclusion 구조에서 lock parser를 재사용할 수 있는지 확인한다.
- 검증 흐름을 build script에 넣을지 standalone script로 둘지 판단한다.

대상:

- `project.yml`
- `rhwp-core.lock`
- `scripts/build-rust-macos.sh`
- `scripts/ci/read-rhwp-core-lock.sh`
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `Sources/Shared`
- `Sources/RhwpCoreBridge`

작업:

1. `project.yml`의 `ThumbnailExtension`, `QLExtension`, `HostApp` source inclusion 구조를 확인한다.
2. `scripts/build-rust-macos.sh`의 lock parsing과 verify flow를 조사한다.
3. `scripts/ci/read-rhwp-core-lock.sh`를 local 검증 script에서 재사용할 수 있는지 확인한다.
4. build info source 위치 후보를 비교한다.
   - `Sources/RhwpCoreBridge`
   - `Sources/Shared`
   - `Sources/ThumbnailExtension`
5. Stage 1 완료보고서에 선택안과 Stage 2 구현 방향을 기록한다.

검증:

```bash
rg -n "sources:|Sources/Shared|Sources/RhwpCoreBridge|ThumbnailExtension|QLExtension|HostApp" project.yml
rg -n "rhwp_release_tag|rhwp_commit|rhwp_enabled_features|read-rhwp-core-lock|verify-lock|LOCK_FILE" \
  rhwp-core.lock scripts/build-rust-macos.sh scripts/ci/read-rhwp-core-lock.sh
rg -n "HwpThumbnailRenderSignature|coreReleaseTag|coreCommit|coreEnabledFeatures" \
  Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift
git diff --check -- mydocs/plans/task_m020_388_impl.md mydocs/working/task_m020_388_stage1.md
```

완료 조건:

- build info 파일 위치와 생성/검증 책임이 문서화되어 있다.
- Stage 2에서 수정할 파일 목록이 확정되어 있다.
- AppKit/UIKit 금지 경계와 XcodeGen 원본 경계에 어긋나지 않는다.

커밋:

```text
Task #388 Stage 1: Thumbnail core build info 경로 조사
```

## Stage 2. RhwpCoreBuildInfo와 Thumbnail signature refactor

목표:

- `HwpThumbnailRenderSignature`가 stale hardcoded core metadata 대신 current build info를 참조하도록 수정한다.
- `v0.7.13` / `b3e16ef` 하드코딩을 release-critical Swift 코드에서 제거한다.

대상:

- Stage 1에서 확정한 build info Swift source
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- 필요 시 `project.yml`
- `mydocs/working/task_m020_388_stage2.md`

작업:

1. `RhwpCoreBuildInfo` 또는 동등한 타입을 추가한다.
2. current lock 기준 값을 build info에 반영한다.
   - `releaseTag = "v0.7.17"`
   - `commit = "03351190ec35436e58cbfee0aa9278a8fdc04a59"`
   - `enabledFeatures = "native-skia"`
3. `HwpThumbnailRenderSignature`의 default core metadata를 build info 참조로 바꾼다.
4. `identifier`가 기존 필드 순서와 cache 분리 의미를 유지하는지 확인한다.
5. Stage 2 완료보고서에 변경 구조와 cache key 영향 범위를 기록한다.

검증:

```bash
rg -n "v0\\.7\\.13|b3e16ef" Sources
rg -n "RhwpCoreBuildInfo|coreReleaseTag|coreCommit|coreEnabledFeatures|identifier" \
  Sources mydocs/working/task_m020_388_stage2.md
git diff --check
```

완료 조건:

- `Sources` 아래 release-critical 코드에 stale core metadata가 남아 있지 않다.
- `HwpThumbnailRenderSignature`가 current build info 값을 참조한다.
- cache key 구조와 larger bucket reuse 조건은 기존 의도대로 유지된다.

커밋:

```text
Task #388 Stage 2: Thumbnail render signature core metadata 정합화
```

## Stage 3. rhwp-core.lock과 build info 정합성 검증 추가

목표:

- `rhwp-core.lock`과 Swift build info가 다르면 명시적으로 실패하는 검증 경로를 추가한다.
- core pin 변경 후 build info 갱신 누락을 조기에 발견한다.

대상:

- `scripts/` 하위 신규 또는 기존 검증 script
- 필요 시 `scripts/build-rust-macos.sh`
- 필요 시 `scripts/ci/read-rhwp-core-lock.sh`
- `mydocs/working/task_m020_388_stage3.md`

작업:

1. Stage 1 결론에 따라 standalone verification command 또는 build script hook을 구현한다.
2. 검증 대상 값을 lock에서 읽는다.
   - `rhwp_release_tag`
   - `rhwp_commit`
   - `rhwp_enabled_features`
3. Swift build info source에서 같은 값을 확인한다.
4. mismatch 발생 시 어떤 파일을 갱신해야 하는지 에러 메시지에 남긴다.
5. Stage 3 완료보고서에 실행 명령과 failure mode를 기록한다.

검증:

```bash
신규 또는 갱신된 lock/build info 검증 명령
./scripts/build-rust-macos.sh --verify-lock
git diff --check
```

완료 조건:

- 검증 명령이 현재 `rhwp-core.lock`과 build info의 일치 상태에서 통과한다.
- mismatch를 만들지 않고도 검증 대상과 failure mode가 코드/문서에서 확인 가능하다.
- 기존 `build-rust-macos.sh --verify-lock` 의미와 충돌하지 않는다.

커밋:

```text
Task #388 Stage 3: core lock build info 검증 추가
```

## Stage 4. build, smoke, 최종 정리

목표:

- ThumbnailExtension compile과 thumbnail signature smoke를 통해 변경이 실제 target에서 동작하는지 확인한다.
- #390 readiness 재측정으로 넘길 기준 상태를 정리한다.

대상:

- `mydocs/working/task_m020_388_stage4.md`
- `mydocs/report/task_m020_388_report.md`
- `mydocs/orders/20260629.md`

작업:

1. AppKit/UIKit boundary 검사를 실행한다.
2. 필요 시 Xcode project를 재생성한다.
3. `ThumbnailExtension` Debug build를 실행한다.
4. thumbnail policy smoke를 실행하고 signature 값이 current lock 기준을 포함하는지 확인한다.
5. 오래된 core metadata 검색 결과를 기록한다.
6. 최종 보고서와 오늘할일 완료 처리를 준비한다.

검증:

```bash
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task388 CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task388-thumbnail-signature \
  samples/basic/KTX.hwp samples/basic/request.hwp
rg -n "v0\\.7\\.13|b3e16ef" Sources scripts mydocs
git diff --check
git status --short
```

완료 조건:

- `ThumbnailExtension` Debug build가 성공한다.
- smoke output 또는 보고서에 current lock 기준 signature가 기록된다.
- stale core metadata 검색 결과가 release-critical source에 남아 있지 않음으로 정리된다.
- 최종 보고서가 #390 readiness 재측정의 입력 상태를 명확히 남긴다.

커밋:

```text
Task #388 Stage 4: Thumbnail signature 검증과 최종 보고서 정리
```
