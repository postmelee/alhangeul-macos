# Task M020 #278 구현계획서

## 전제

- 추적 이슈: #278
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task278`
- 대상 upstream: `edwardkim/rhwp` `v0.7.13`
- resolved commit: `b3e16ef212af81ef37d973ddb86d6816d3804642`

## Stage 1: v0.7.13 영향 범위 확정

목표:

- upstream `v0.7.13` release/tag/resolved commit이 stable core 기준을 만족하는지 확인한다.
- 현재 앱 lock과 bundled `rhwp-studio`가 어떤 기준에 머물러 있는지 확인한다.
- core update와 bundled `rhwp-studio` sync를 분리할 수 있는지 판단한다.

작업:

1. `git ls-remote --tags`와 `gh release view/list`로 `v0.7.13` release 상태를 확인한다.
2. `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13`로 release tag compatibility를 확인한다.
3. `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 현재 기준을 조사한다.
4. `scripts/ci/detect-rhwp-studio-impact.sh`로 `v0.7.12..v0.7.13` viewer/WASM/core 영향 범위를 계산한다.
5. Stage 2 이후 진행 순서와 #282 handoff 조건을 보고서에 기록한다.

검증:

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13
git diff --check -- mydocs/plans/task_m020_278_impl.md mydocs/working/task_m020_278_stage1.md
```

완료 조건:

- `v0.7.13` release/tag/resolved commit이 문서화되어 있다.
- core update 전에 bundled `rhwp-studio` sync 필요 여부가 판단되어 있다.
- 다음 단계에서 수정할 파일과 검증 순서가 명확하다.

## Stage 2: stable core dependency와 RustBridge 산출물 갱신

목표:

- 앱의 Rust core dependency를 `v0.7.13` release tag와 resolved commit 기준으로 갱신한다.
- Swift/Rust FFI 산출물이 새 core 기준에서 빌드되고 ABI surface가 의도치 않게 변하지 않았는지 확인한다.

작업:

1. `scripts/update-rhwp-core.sh --channel stable --tag v0.7.13`를 실행한다.
2. `scripts/build-rust-macos.sh --update-lock`로 universal static library, generated header, `rhwp-core.lock` metadata를 갱신한다.
3. `rhwp-ffi-symbols.txt` 변경 여부를 확인한다.
4. `Frameworks/generated_rhwp.h`와 Swift bridge 호출부 영향 여부를 확인한다.

검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
git diff -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock Frameworks/generated_rhwp.h rhwp-ffi-symbols.txt
git diff --check
```

완료 조건:

- `RustBridge/Cargo.toml`과 `Cargo.lock`의 `rhwp` source가 `v0.7.13` / `b3e16ef212af81ef37d973ddb86d6816d3804642`로 맞아 있다.
- `rhwp-core.lock`이 같은 release tag와 resolved commit을 기록한다.
- FFI symbol/header 변경이 없거나 변경 이유가 Stage 2 보고서에 기록되어 있다.

## Stage 3: bundled rhwp-studio sync

목표:

- WebView viewer와 visual diff reference가 core update 기준과 같은 upstream release를 가리키게 한다.

작업:

1. Stage 1 impact 결과를 근거로 `rhwp-studio` sync 포함 여부를 최종 확정한다.
2. upstream checkout에서 `pkg/`와 `rhwp-studio/dist` 준비 상태를 확인한다.
3. 필요 시 `scripts/sync-rhwp-studio.sh --tag v0.7.13 --commit b3e16ef212af81ef37d973ddb86d6816d3804642`를 실행한다.
4. local overlay인 `alhangeul-wkwebview-overrides.css`, `fonts/FONTS.md` 보존 여부를 확인한다.

검증:

```bash
./scripts/verify-rhwp-studio-assets.sh
git diff -- Sources/HostApp/Resources/rhwp-studio/manifest.json
git diff --check
```

완료 조건:

- `Sources/HostApp/Resources/rhwp-studio/manifest.json`이 `v0.7.13` / `b3e16ef212af81ef37d973ddb86d6816d3804642` 기준을 기록한다.
- bundled viewer asset entrypoint와 WASM hash가 검증된다.

## Stage 4: 앱 빌드와 Quick Look/Thumbnail smoke

목표:

- 새 core와 viewer asset 기준에서 HostApp, Quick Look preview, thumbnail 경로가 빌드 및 최소 smoke를 통과하는지 확인한다.
- #282에서 사용할 visual diff baseline을 새 release 기준으로 다시 남긴다.

작업:

1. `xcodegen generate`로 Xcode project를 재생성한다.
2. HostApp Debug build를 실행한다.
3. Skia policy smoke와 visual diff harness를 실행한다.
4. 필요 시 overlay metadata smoke를 추가 실행한다.

검증:

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task278 CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task278-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task278-visual-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/overlay-metadata-smoke.sh build.noindex/task278-overlay-metadata
git diff --check
```

완료 조건:

- Debug build가 성공한다.
- smoke 결과와 visual diff 수치가 Stage 4 보고서에 기록되어 있다.
- Quick Look/Thumbnail 개발 산출물 등록이 남아 있지 않다.

## Stage 5: handoff와 최종 보고

목표:

- #278 core update 결과를 #282, #259 후속 작업이 안전하게 이어받을 수 있게 정리한다.

작업:

1. #282 branch 재정렬 필요 사항을 기록한다.
2. `v0.7.13`에서 새로 반영된 overlay payload, resolved image payload, `displayText` 관찰값을 정리한다.
3. 잔여 제한과 후속 이슈 영향을 최종 보고서에 기록한다.
4. 오늘할일을 완료 처리하고 PR을 게시한다.

검증:

```bash
git status --short
git diff --check
```

완료 조건:

- 최종 보고서가 `mydocs/report/task_m020_278_report.md`에 작성되어 있다.
- PR 본문에 Stage별 결과, smoke 수치, #282 handoff가 포함되어 있다.
