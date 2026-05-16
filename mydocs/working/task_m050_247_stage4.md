# Task M050 #247 Stage 4 보고서

## 목적

Stage 2와 Stage 3에서 `origin/devel` 제품 라인을 merge/통합한 뒤 generated project, script helper, RustBridge/core, macOS app build가 현재 `native-viewer-editor` 라인에서 다시 일관되는지 확인한다.

이번 단계는 기능 포팅 단계가 아니라 검증 단계이므로 source 변경은 만들지 않았다.

## 검증 범위 판단

`scripts/ci/classify-pr-changes.sh origin/native-viewer-editor HEAD` 결과는 다음과 같다.

| flag | 값 |
|------|----|
| `docs_only` | `false` |
| `run_macos_build` | `true` |
| `run_rust_verify` | `true` |
| `run_render_smoke` | `true` |
| `run_release_checks` | `true` |

`project.yml`, generated Xcode project, `RustBridge`, `rhwp-core.lock`, release/CI helper, HostApp source가 모두 forward-port 범위에 포함되어 있으므로 Stage 4에서는 XcodeGen, shell helper, RustBridge lock 검증, HostApp Debug build, native renderer smoke를 실행했다.

## 결과 요약

| 항목 | 결과 |
|------|------|
| XcodeGen project 재생성 | 통과. `xcodegen generate` 후 tracked diff 없음 |
| script syntax | 통과. `scripts/*.sh`, `scripts/ci/*.sh` 전체 `bash -n` 통과 |
| helper interface | 통과. PR CI helper `--help` 및 release helper `--help` 확인 |
| RustBridge/core 검증 | 통과. universal staticlib와 `Rhwp.xcframework` 생성, `rhwp-core.lock` 검증 |
| Xcode project 목록 | 통과. `HostApp`, `QLExtension`, `ThumbnailExtension` scheme 확인 |
| HostApp Debug build | 통과. `** BUILD SUCCEEDED **` |
| Native renderer smoke | 통과. 기본 3개 sample의 PNG 생성과 non-blank 판정 성공 |
| tracked 변경 | 없음. generated/build output은 작업 트리에 남지 않음 |

## 상세 검증

### XcodeGen

```bash
xcodegen generate
```

결과:

- `Alhangeul.xcodeproj`가 정상 생성됐다.
- 생성 후 `git status --short --branch`는 `## local/task247`만 출력했다.
- 따라서 Stage 2에서 채택한 `project.yml`과 generated project가 동기화된 상태다.

### script syntax와 helper interface

```bash
for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/check-rhwp-upstream-release.sh --help
bash scripts/ci/prepare-pages-artifact.sh --help
bash scripts/ci/write-sparkle-appcast.sh --help
./scripts/release.sh --help
```

결과:

- 전체 shell syntax 검증이 통과했다.
- PR CI helper와 release helper의 help interface가 통과했다.
- `scripts/ci/check-rhwp-upstream-release.sh`는 실행 비트가 없어서 직접 실행하면 permission denied가 나지만, workflow와 매뉴얼의 호출 방식은 `bash scripts/ci/check-rhwp-upstream-release.sh ...`이므로 Stage 4에서는 결함으로 분류하지 않았다.
- 직접 호출되는 `scripts/ci/prepare-pages-artifact.sh`, `scripts/ci/write-sparkle-appcast.sh`, `scripts/release.sh`는 실행 비트가 유지되어 있다.

### RustBridge/core

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock
```

결과:

- arm64와 x86_64 staticlib build가 완료됐다.
- universal binary는 `x86_64 arm64` slice를 포함한다.
- `Frameworks/Rhwp.xcframework`가 생성됐다.
- `rhwp-core.lock` 검증이 통과했다.
- FFI symbol 표면은 다음 symbol을 포함한다.

```text
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_size
rhwp_render_page_svg
rhwp_render_page_tree
```

`ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`을 사용했으므로 `Frameworks/universal/librhwp.a`의 byte-for-byte hash 검증은 이번 단계에서 생략됐다. Stage 4 목적은 forward-port 후 local build/lock/symbol 표면이 깨지지 않는지 확인하는 것이며, release 수준의 archive hash 재현성 검증은 최종 release 경로에서 다시 다룬다.

### Xcode project와 HostApp build

```bash
xcodebuild -list \
  -project Alhangeul.xcodeproj \
  -clonedSourcePackagesDirPath build.noindex/SourcePackages

xcodebuild \
  -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  -clonedSourcePackagesDirPath build.noindex/SourcePackages \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

- `xcodebuild -list`가 통과했고 scheme 목록은 `HostApp`, `QLExtension`, `ThumbnailExtension`이다.
- Sparkle package는 `2.9.1`로 resolve됐다.
- `HostApp` Debug build가 통과했고 `Alhangeul.app` 안에 `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex`가 포함됐다.
- CoreSimulator service 관련 warning은 출력됐지만 macOS HostApp build를 막지 않았다.

### Native renderer smoke

```bash
./scripts/validate-stage3-render.sh
```

결과:

- `samples/basic/KTX.hwp`: `OK`, page 1 PNG 생성, `nonWhitePixels=455004`.
- `samples/basic/request.hwp`: `OK`, page 1 PNG 생성, `nonWhitePixels=69375`.
- `samples/basic/exam_kor.hwp`: `OK`, page 1 PNG 생성, `nonWhitePixels=174843`.
- `KTX.hwp` 처리 중 layout overflow 진단이 출력됐지만 smoke script exit code는 0이고 non-blank bitmap 판정은 통과했다. 이 smoke는 기본 render pipeline 회귀 확인이며 시각 정합성 전체를 보장하지는 않는다.
- 생성 output은 `output/stage3-render/` 아래에 남았고 git ignored 상태다.

## 작업 트리 확인

```bash
git diff --check
git status --short --branch
git diff --name-status
```

결과:

- `git diff --check` 통과.
- tracked 변경 없음.

## 다음 단계

Stage 5에서는 `origin/devel..origin/devel-webview`에 남은 #243 저장 확인 변경을 검토한다. WebView fallback 전용 bridge 구현과 native editor에도 필요한 dirty-state/termination 개념을 분리하고, 안전하게 재사용 가능한 범위만 `native-viewer-editor`에 포팅한다.
