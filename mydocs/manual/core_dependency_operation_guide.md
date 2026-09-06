# rhwp Core Dependency 운영 가이드

## 목적

이 문서는 `edwardkim/rhwp` core를 앱 저장소에서 고정하고 갱신하는 절차를 정리한다. 현재 기준은 `RustBridge`의 git dependency와 lock provenance다.

## 소유 경계

- `edwardkim/rhwp`: Rust HWP/HWPX parser/renderer core
- upstream root `Cargo.lock`: upstream release checkout의 CLI/WASM/studio dependency graph fingerprint
- `RustBridge`: 이 저장소가 소유하는 macOS C ABI bridge
- `RustBridge/Cargo.toml`: core dependency 선언
- `RustBridge/Cargo.lock`: Cargo가 해석한 core source와 resolved commit
- `rhwp-core.lock`: 앱 저장소 관점의 core provenance와 Rust bridge reference artifact metadata
- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`: `rhwp-core.lock`에서 생성하는 Swift core identity mirror
- `Sources/RhwpCoreBridge`: Swift FFI wrapper/renderer
- `Sources/HostApp`: viewer app
- `Sources/QLExtension`: Quick Look preview extension
- `Sources/ThumbnailExtension`: Finder thumbnail extension
- `Sources/Shared`: 공통 helper

## core 기준

- Stable 안정 기준은 release tag + resolved commit. Demo/Preview는 필요한 API가 포함된 resolved commit을 `rev`로 고정.
- 현재 `rhwp-core.lock`은 `v0.8.2` Stable release tag pin 상태다. `RustBridge/Cargo.toml`은 `tag = "v0.8.2"`를 사용하고, `RustBridge/Cargo.lock`과 `rhwp-core.lock`은 resolved commit `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`를 기록한다.
- `v0.8.2`에는 현재 bridge가 요구하는 page/render/image API와 `set_file_name`, `get_external_image_references`, `inject_external_image_by_key` external image context API가 포함되어 있다.
- `main`, `devel` 같은 branch는 필요한 API가 포함된 과도기 commit을 찾는 참고 출처일 뿐, 안정 기준으로 사용하지 않는다.
- 채널별 dependency/lock 필드와 compatibility gate 상세는 [`core_release_compatibility.md`](../tech/core_release_compatibility.md)를 따른다.

## 운영 원칙

- core API 변경은 먼저 `edwardkim/rhwp`에 반영한다.
- 앱 저장소에서는 `RustBridge` dependency, `RustBridge/Cargo.lock`, `rhwp-core.lock`, Swift/Rust bridge 적응만 커밋한다.
- upstream root `Cargo.lock`은 downstream `RustBridge/Cargo.lock`을 대체하지 않는다. upstream release checkout의 dependency graph fingerprint로만 기록하고, native bridge build gate는 계속 `RustBridge/Cargo.lock`과 `rhwp-core.lock`을 기준으로 한다.
- core를 로컬에서 실험해야 하면 별도 clone 또는 임시 Cargo patch/local override를 사용하고, local path 변경은 커밋하지 않는다.
- ABI 변경은 `rhwp-ffi-symbols.txt`와 Swift bridge 영향 검토를 동반한다.
- Demo/Preview 배포를 Stable release처럼 표시하지 않는다.
- branch나 floating ref를 배포 기준으로 사용하지 않는다.

## Artifact 검증 정책

`rhwp-core.lock`의 source provenance 필드(`rhwp_repo`, `rhwp_ref_kind`, `rhwp_release_tag`, `rhwp_commit`)는 Stable/Demo 기준을 고정하는 핵심 gate다. `Frameworks/generated_rhwp.h` hash/size와 `rhwp-ffi-symbols.txt`는 Swift/Rust ABI 표면 검증에 직접 연결되므로 CI와 release workflow에서 계속 검증한다.

`Frameworks/universal/librhwp.a` hash/size는 reference artifact metadata로 유지한다. 이 값은 기준 환경에서 생성한 Rust bridge static archive 식별자로 유용하지만, Rust compiler, Xcode, macOS runner image, archive tool, build path 차이에 따라 source와 ABI가 같아도 byte-for-byte 값이 달라질 수 있다.

로컬·CI·release workflow의 일반 검증은 `--verify-portable`을 사용한다. staticlib byte hash/size 비교만 제외하고 source provenance, Cargo.lock, header, FFI symbol과 reference metadata 검증은 유지한다. 기준 환경 byte 검증은 명시 `--verify-strict`를 사용한다. 환경 차이를 이유로 lock을 자동 갱신하지 않는다. legacy 옵션 호환과 실패 분류는 [build_run_guide.md](build_run_guide.md)를 따른다.

### Producer 기반 render tree golden

`RhwpCoreBuildInfo`와 별도로 `scripts/ci/fixtures/render-tree/request-page0.json`에 실제 core 출력과 provenance를 보존한다. 입력은 저장소 request sample의 page 0이며 전체 tree를 저장한다. canonical 처리는 key 정렬과 공백으로 제한하고 필드·배열 순서·큰 unsigned 정수를 제거하거나 반올림하지 않는다. 모든 node 또는 pixel parity를 보증하는 fixture는 아니다.

도구에는 Python 3.11+, Rust toolchain, Swift compiler가 필요하다. native arm64/x86_64 producer는 `cargo run --release --locked --target <host> --example render_tree_golden`을 사용하므로 stale Frameworks를 읽지 않고 현재 Cargo pin으로 빌드한다. core repo/ref/tag/commit/features와 Cargo 계약, sample SHA256/page/recipe/tree hash, 실제 출력 byte와 Swift decode를 검사한다.

`scripts/verify-render-tree-golden.sh --check-environment`는 Python 3.11+ 존재/버전만 확인하고 Rust/Swift를 빌드하지 않는다. 로컬 release/package는 출력 초기화와 cleanup trap보다 먼저 이 검사를 수행한다. PATH의 python3가 해당 버전이어야 한다.

현재 Cargo feature 배열 순서는 lock writer/source verifier와 golden provenance에 공통으로 보존된다. 의미가 같은 feature라도 순서를 임의 재배열하면 검증이 실패한다. 순서 정규화가 필요하면 세 경로를 함께 변경해야 한다. tree_sha256은 편집/손상 원인의 조기 분류를 위한 값이고 최종 producer 파일 byte 검사를 대체하지 않는다.

Swift consumer는 TextRun/Table/TextLine 존재만 확인하는 것이 아니라 전체 tree를 decode한다. 현재 request 0쪽에는 Image·Header·Footer를 포함한 15종이 있고, Path/Equation/FootnoteMarker처럼 없는 variant의 변화는 이 golden의 byte 비교로도 검출하지 못한다. 단일 sample은 #469의 의도된 범위이며 전체 decoder corpus 확장은 별도 범위로 결정한다. #259의 Skia visual/performance/package 검증과 자동으로 동일시하지 않는다.

```bash
# 일반 PR / release source preflight: drift는 실패하며 tracked 파일을 수정하지 않는다.
scripts/verify-render-tree-golden.sh

# 승인된 core update/full sync: complete core build 뒤 명시 갱신한다.
scripts/update-render-tree-golden.sh
scripts/verify-render-tree-golden.sh
```

Writer는 producer·Swift decode 성공 후 metadata와 tree를 한 파일로 atomic 교체한다. 실패하면 이전 golden을 보존한다. full sync workflow는 core build 다음 writer/검증을 실행하고 fixture를 candidate에 stage한다. 일반 PR/release workflow와 로컬 package/release helper는 verifier만 실행한다. core 또는 sample 변경 시 stale failure를 무시하지 말고 원인을 검토한 뒤 명시 writer 결과를 같은 PR에서 리뷰한다.

수동 minimal decoder fixture는 빠른 current/legacy/known-error gate로 유지하고, producer golden은 실제 core/Swift 통합 계약 gate로 사용한다. 격리 helper 검증은 `python3 scripts/ci/test-render-tree-golden.py`로 실행한다.

### Swift build info mirror

`Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`는 별도 진실 원천이 아니다. 완성된 `rhwp-core.lock`에서 `scripts/update-rhwp-core-build-info.sh`로 생성하고 `scripts/verify-rhwp-core-build-info.sh`로 일치를 확인한다.

| lock ref kind | `RhwpCoreBuildInfo.releaseTag` | `commit` | `enabledFeatures` |
|---------------|--------------------------------|----------|-------------------|
| `release-tag` | `rhwp_release_tag` | 실제 `rhwp_commit` | 실제 `rhwp_enabled_features` |
| `commit` | `rhwp_latest_checked_release_tag` | 실제 `rhwp_commit` | 실제 `rhwp_enabled_features` |

Demo/Preview commit pin에서 `releaseTag`는 해당 commit에 release tag가 붙었다는 뜻이 아니라 마지막으로 호환성을 확인한 Stable baseline label이다. 실제 provenance와 thumbnail cache invalidation은 `commit`이 담당한다. Demo lock에 `rhwp_latest_checked_release_tag`가 없거나 lock version/ref kind/commit/features 형식이 유효하지 않으면 writer와 verifier는 실패해야 한다. `rhwp_enabled_features = ""`는 Cargo dependency에 명시 feature가 없는 유효한 값이며 key 누락과 구분한다.

writer는 `scripts/build-rust-macos.sh --update-lock`가 enabled features와 artifact metadata를 기록해 lock을 완성한 뒤에만 실행한다. 누락 key나 malformed lock을 이전 값으로 보정하지 않는다. Writer와 verifier는 공통 mapping·validation·canonical renderer를 사용하며, verifier는 일부 상수만 찾지 않고 generated header를 포함한 Swift source 전체가 canonical output과 byte 단위로 같은지 확인한다. PR CI와 release workflow는 writer를 실행해 drift를 고치지 않고 verifier 실패로 차단한다.

## 업데이트 절차

Demo/Preview commit pin:

```bash
./scripts/update-rhwp-core.sh --channel demo --rev <commit-sha>
./scripts/build-rust-macos.sh --update-lock
./scripts/update-rhwp-core-build-info.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/build-rust-macos.sh --verify-portable
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
```

Stable release tag:

```bash
./scripts/update-rhwp-core.sh --channel stable --tag <release-tag>
./scripts/build-rust-macos.sh --update-lock
./scripts/update-rhwp-core-build-info.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/build-rust-macos.sh --verify-portable
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
```

조회/검증만 수행하고 파일을 바꾸지 않을 때:

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag <release-tag>
```

`validate-stage3-render.sh`의 기본 샘플은 앱 저장소 루트의 `samples/`를 사용한다. core 저장소 내부 샘플 경로는 기본 검증 경로로 사용하지 않는다.

## upstream release 감지와 full sync

`rhwp-core.lock`은 Rust bridge가 링크하는 core 기준이고, `Sources/HostApp/Resources/rhwp-studio/manifest.json`은 WKWebView viewer asset의 source release와 resolved commit 기준이다. 두 provenance는 release note와 검증에서 함께 확인하지만, 자동 sync PR은 public release 결정을 대신하지 않는다.

- `.github/workflows/rhwp-upstream-check.yml`은 read-only 감시 workflow로 upstream latest release와 `rhwp-core.lock`을 비교한다.
- `.github/workflows/rhwp-upstream-sync-pr.yml`은 upstream target release를 `devel` 대상 `automation/rhwp-<tag>-full-sync` branch에 반영하는 full sync 후보 PR을 만든다. current 판정은 `devel` content의 core lock과 bundled studio manifest 기준으로 수행한다.
- sync workflow는 같은 target의 open PR 또는 PR 없는 branch-only 상태를 중복 생성 blocker로 취급한다. merge 완료 PR의 head branch가 남아 있으면 blocker가 아니라 cleanup 후보로 표시하며, 실제 원격 branch 삭제는 별도 승인 또는 merge 후 cleanup 절차에서 수행한다.
- sync workflow는 `scripts/update-rhwp-core.sh --check --channel stable --tag <tag>`로 target release compatibility를 먼저 조회하고, 실제 PR 생성 단계에서는 `scripts/update-rhwp-core.sh --channel stable --tag <tag>`와 `scripts/build-rust-macos.sh --update-lock`로 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`을 갱신한다. complete lock 직후 build info writer와 verifier를 실행하고 `RhwpCoreBuildInfo.swift`를 후보 PR에 명시적으로 stage한다.
- sync workflow는 같은 target commit에서 upstream WASM/studio asset을 빌드하고 `scripts/sync-rhwp-studio.sh`로 bundled `rhwp-studio` manifest와 asset을 갱신한다. 이때 upstream root `Cargo.lock`의 sha256을 manifest의 `source_cargo_lock_sha256`에 기록하고, target checkout을 넘긴 verifier가 checkout HEAD와 expected commit을 결합한 뒤 기록값과 실제 파일을 자동 비교한다.
- full sync 변경 PR은 후보 생성 단계에서 `scripts/verify-rhwp-studio-assets.sh --upstream-dir <target-checkout>` strict gate를 통과해야 한다. 일반 PR CI는 upstream checkout이 없으므로 resource-only verifier와 별도 fixture로 strict 비교의 정상·stale checkout·non-Git directory·누락·malformed·mismatch 경계를 검증한다. HostApp build, Rust/core provenance verify, release helper dry-run도 함께 확인하며 PR CI와 release rehearsal/publish는 build info를 자동 수정하지 않는다.
- signed/notarized DMG, GitHub Release, Sparkle appcast, Homebrew Cask 반영은 별도 release 승인과 보호 workflow가 필요하다.

## 업데이트 후 확인 항목

- `RustBridge/Cargo.toml`의 dependency repo/ref와 의도한 채널 일치
- `RustBridge/Cargo.lock`의 `rhwp` source repo/ref/resolved commit
- `rhwp-core.lock`의 `rhwp_repo`, `rhwp_ref_kind`, `rhwp_commit` 일치
- Stable이면 `rhwp_release_tag`와 resolved commit 일치
- Demo/Preview이면 `rhwp_release_transition_status = "demo-commit-pin"` 유지
- `RhwpCoreBuildInfo.releaseTag`가 Stable의 `rhwp_release_tag` 또는 Demo/Preview의 `rhwp_latest_checked_release_tag`와 일치
- `RhwpCoreBuildInfo.commit`, `enabledFeatures`가 실제 lock의 `rhwp_commit`, `rhwp_enabled_features`와 일치하고 `./scripts/verify-rhwp-core-build-info.sh` 통과
- `rhwp-core.lock`의 `Frameworks/universal/librhwp.a` reference metadata와 `Frameworks/generated_rhwp.h` sha256/size 기록 갱신 여부
- `scripts/verify-rhwp-studio-assets.sh --upstream-dir <target-checkout> --tag <tag> --commit <commit>`가 checkout HEAD/expected commit과 bundled `rhwp-studio` manifest/target root `Cargo.lock` hash 일치를 함께 확인하는지 여부
- `rhwp-ffi-symbols.txt` 변경 여부와 의도성
- Swift `RenderTree` 모델과 core JSON 구조 호환성
- Quick Look/Thumbnail smoke test 필요 여부
- Demo/Preview 배포인지 Stable 배포인지와 해당 core 기준

## 금지 사항

- branch dependency 또는 floating ref를 배포 기준으로 사용
- Cargo local path override를 커밋
- `RustBridge/Cargo.lock`과 `rhwp-core.lock`의 resolved commit 불일치 방치
- `rhwp-core.lock`과 `RhwpCoreBuildInfo.swift` 불일치 방치 또는 PR CI/release workflow에서 writer로 자동 보정
- upstream root `Cargo.lock`을 `RustBridge/Cargo.lock` 대체물로 취급
- ABI 영향 검토 없이 FFI 변경 반영
- core 저장소 PR과 앱 저장소 PR을 혼합 진행
- Demo/Preview 배포를 Stable release처럼 표시
