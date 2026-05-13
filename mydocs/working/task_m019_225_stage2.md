# Task M019 #225 Stage 2 완료보고서

## 단계 목적

`rhwp v0.7.11`을 v0.1.2 후보의 core/studio 기준으로 반영했다. Rust git dependency, Cargo lock, `rhwp-core.lock`, bundled `rhwp-studio` 정적 asset, provenance/라이선스 고지를 모두 `v0.7.11` release-tag와 resolved commit `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` 기준으로 맞췄다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `RustBridge/Cargo.toml` | 수정 | `rhwp` git dependency tag를 `v0.7.11`로 갱신 |
| `RustBridge/Cargo.lock` | 수정 | `rhwp` resolved source를 `v0.7.11#a9dcdee...`로 갱신 |
| `rhwp-core.lock` | 수정 | release tag, commit, build timestamp, `librhwp.a` artifact hash/size 갱신 |
| `Sources/HostApp/Resources/rhwp-studio/**` | 수정 | upstream `rhwp-studio/dist`를 `v0.7.11` build output으로 재동기화 |
| `scripts/sync-rhwp-studio.sh` | 수정 | expected tag/commit을 `v0.7.11`로 갱신하고 기본 checkout 경로를 task-specific 값에서 generic `build.noindex/rhwp-upstream`으로 정리 |
| `scripts/verify-rhwp-studio-assets.sh` | 수정 | manifest expected tag/commit 검증 기준을 `v0.7.11`로 갱신 |
| `THIRD_PARTY_LICENSES.md` | 수정 | root third-party provenance를 `v0.7.11`로 갱신 |
| `Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md` | 수정 | app bundle legal resource provenance를 `v0.7.11`로 갱신 |
| `README.md` | 수정 | 현재 구현 범위의 WKWebView viewer snapshot 표기를 `v0.7.11`로 갱신 |
| `mydocs/working/task_m019_225_stage2.md` | 신규 | Stage 2 수행과 검증 결과 기록 |

`Frameworks/universal/librhwp.a`, `Frameworks/Rhwp.xcframework`, `Frameworks/generated_rhwp.h`는 `scripts/build-rust-macos.sh`로 재생성했다. 이 경로들은 현재 git tracking 대상이 아니며, tracked source에는 `rhwp-core.lock`의 artifact metadata로 반영된다.

## Core 갱신 결과

`scripts/update-rhwp-core.sh --channel stable --tag v0.7.11`을 실행해 Cargo dependency와 lock 입력을 갱신했다.

확정된 값:

```text
rhwp_release_tag = "v0.7.11"
rhwp_commit = "a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"
RustBridge/Cargo.toml rhwp tag = "v0.7.11"
RustBridge/Cargo.lock source = git+https://github.com/edwardkim/rhwp.git?tag=v0.7.11#a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae
```

`./scripts/build-rust-macos.sh --update-lock`로 Rust bridge artifact를 재생성했다.

주요 결과:

```text
Architectures in the fat file: Frameworks/universal/librhwp.a are: x86_64 arm64
FFI symbols:
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
librhwp.a sha256 = 8a42ea0c1f39b7b3c2a1ebeda3f97584d63fef6d7bc67efbdac9becd20812251
librhwp.a size = 108417040
generated_rhwp.h sha256 = 69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5
```

`rhwp-ffi-symbols.txt`는 변경되지 않았다.

## Studio asset 갱신 결과

upstream checkout은 ignored build input인 `build.noindex/rhwp-upstream-task225`에 준비했다.

```text
git -C build.noindex/rhwp-upstream-task225 rev-parse HEAD
a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae
```

WASM package는 upstream root에서 Docker/Colima를 사용해 생성했다.

```text
docker-compose --env-file .env.docker run --rm wasm
[INFO]: :-) Your wasm pkg is ready to publish at /app/pkg.
```

`rhwp-studio`는 upstream `rhwp-studio` 디렉터리에서 다음 순서로 빌드했다.

```text
npm ci
npx tsc
npx vite build --base ./
```

Vite build output:

```text
dist/registerSW.js                     0.13 kB
dist/manifest.webmanifest              0.60 kB
dist/index.html                       55.34 kB
dist/assets/rhwp_bg-C02QlQr4.wasm  4,626.54 kB
dist/assets/index-DMFL0yRA.css        62.10 kB
dist/assets/index-CRsGAVvx.js        722.59 kB
precache 52 entries (23231.96 KiB)
```

Vite는 main JS chunk가 500 kB를 초과한다는 경고를 출력했다. 기존 upstream studio bundle 특성에 가까운 경고이며, Stage 2에서는 bundle split 정책을 변경하지 않았다.

`scripts/sync-rhwp-studio.sh build.noindex/rhwp-upstream-task225`로 bundled resource를 동기화했다.

manifest 핵심 값:

```json
{
  "source_release_tag": "v0.7.11",
  "source_resolved_commit": "a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae",
  "copied_file_count": 54,
  "copied_total_bytes": 28543821,
  "entrypoints": {
    "main_js": "assets/index-CRsGAVvx.js",
    "main_css": "assets/index-DMFL0yRA.css",
    "wasm": "assets/rhwp_bg-C02QlQr4.wasm"
  }
}
```

동기화 과정에서 기존 hashed entrypoint asset은 제거되고 새 hashed asset으로 교체됐다. `alhangeul-wkwebview-overrides.css`와 `fonts/FONTS.md` local overlay는 보존됐다.

## 검증 결과

### Rust bridge

```text
$ ./scripts/build-rust-macos.sh --verify-lock
Architectures in the fat file: Frameworks/universal/librhwp.a are: x86_64 arm64
FFI symbols:
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
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

`xcodebuild -create-xcframework` 실행 중 CoreSimulatorService 연결 경고가 출력됐지만, simulator 기능을 쓰는 단계가 아니며 xcframework 생성과 lock 검증은 성공했다.

```text
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

### Studio asset

```text
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

manifest JSON 검증:

```text
$ python3 -m json.tool Sources/HostApp/Resources/rhwp-studio/manifest.json
exit 0

$ plutil -convert json -o /private/tmp/rhwp-manifest-check.json Sources/HostApp/Resources/rhwp-studio/manifest.json
exit 0

$ plutil -p Sources/HostApp/Resources/rhwp-studio/manifest.json
source_release_tag => "v0.7.11"
source_resolved_commit => "a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"
```

계획서의 `plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json`은 이 환경의 Swift-mode `plutil`에서 raw JSON object를 plist lint 대상으로 처리해 다음처럼 실패했다.

```text
Sources/HostApp/Resources/rhwp-studio/manifest.json: (Unexpected character { at line 1)
```

따라서 Stage 2에서는 JSON parser와 `plutil -convert/-p` 기반으로 manifest parse 가능성을 확인했다.

### Diff hygiene

```text
$ git diff --check
exit 0
```

잔여 `v0.7.10` 표기 분류:

- `README.md` 최신 공개 릴리즈 섹션의 `v0.1.1` / bundled `rhwp v0.7.10` 표기는 현재 최신 공개 릴리즈의 역사 기록이다. v0.1.2 public release 단계인 Stage 4에서 최신 공개 릴리즈 요약을 갱신한다.
- `mydocs/release/v0.1.0.md`, `mydocs/release/v0.1.1.md`의 `v0.7.10` 표기는 해당 릴리즈의 역사 기록이다.
- `.github/workflows/release-publish.yml`의 default version `0.1.1`과 `expected_rhwp_tag=v0.7.10`, `.github/workflows/release-rehearsal.yml`의 default version `0.1.1`, `pr-ci.yml`의 v0.1.1 release dry-run 입력은 Stage 4 release candidate 정리 범위다.
- `mydocs/working/task_m019_225_stage1.md`, `mydocs/plans/task_m019_225_impl.md`의 `v0.7.10` 표기는 조사 당시 상태와 계획 기록이다.

## 본문 변경 정도 / 본문 무손실 여부

source/provenance 변경은 `rhwp v0.7.11` 반영에 필요한 범위로 제한했다. `rhwp-studio` resource는 upstream release-tag checkout에서 build한 `dist` output을 스크립트로 재동기화했으며, local overlay CSS와 font license 문서는 삭제하지 않았다.

사용자 문서 본문, sample 문서, release history 문서는 변경하지 않았다.

## 잔여 위험

- `Frameworks/**` generated artifact는 현재 git tracking 대상이 아니므로, clean checkout에서 release/build 전 `scripts/build-rust-macos.sh --verify-lock` 또는 release build 경로가 artifact를 재생성해야 한다.
- `rhwp-studio` main JS chunk size 경고는 남아 있다. Stage 2 범위에서는 upstream bundle 구조를 그대로 수용했다.
- `plutil -lint`는 JSON manifest 검증 명령으로 이 환경에서 부적합했다. 후속 단계에서 문서화된 검증 명령을 조정할지 검토할 수 있다.
- release workflow default와 README 최신 공개 릴리즈 섹션은 아직 `v0.1.1` 기준이다. Stage 4에서 v0.1.2 release candidate 기준으로 갱신해야 한다.

## 다음 단계 영향

Stage 3에서는 앱에 update maintenance와 About provenance 표시를 추가한다.

구현 기준:

- About 창은 `rhwp-studio/manifest.json` 또는 generated metadata에서 `rhwp v0.7.11 (a9dcdee)`를 표시한다.
- extension registration refresh는 새 build 최초 실행 때만 자동 수행하도록 build-scoped marker로 감싼다.
- recent HWP/HWPX 후보에는 `NSWorkspace.noteFileSystemChanged`를 적용해 Finder/Quick Look 재평가를 유도하되, 파일 내용/mtime/xattr은 변경하지 않는다.
- 전역 `qlmanage -r cache`, `pluginkit`, Finder 재시작은 제품 앱 자동 path에 넣지 않는다.

## 승인 요청

Stage 2 완료를 승인하면 Stage 3 `About rhwp provenance 표시와 update 후 Finder thumbnail refresh 구현`을 진행한다.
