# Task M016 #167 Stage 2 보고서

## 단계 목적

Stage 1에서 확인한 `rhwp v0.7.10` stable tag와 resolved commit을 기준으로 RustBridge dependency, Cargo lock, 앱 저장소 lock을 실제 갱신한다. 이어서 Rust bridge universal staticlib/header를 재생성하고 `rhwp-core.lock` artifact hash/size와 FFI symbol snapshot 정합성을 검증한다.

## 산출물

| 파일 | 라인 수 | 내용 |
|------|---------|------|
| `RustBridge/Cargo.toml` | 12 | `rhwp` dependency tag를 `v0.7.10`으로 갱신 |
| `RustBridge/Cargo.lock` | 1183 | `rhwp v0.7.10` resolved commit과 transitive dependency 갱신 |
| `rhwp-core.lock` | 17 | `v0.7.10` release tag, resolved commit, artifact hash/size 기록 |
| `mydocs/working/task_m016_167_stage2.md` | 224 | Stage 2 갱신/검증 결과 |
| `mydocs/orders/20260506.md` | 17 | #167 상태를 Stage 3 승인 대기로 갱신 |

`rhwp-ffi-symbols.txt`는 변경하지 않았다. build 과정에서 생성된 `Frameworks/`와 Stage 1 조사용 `build.noindex/`는 `.gitignore` 대상이며 commit하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

제품 Swift 코드와 bundled `rhwp-studio` asset은 변경하지 않았다. 이번 단계의 추적 변경은 RustBridge dependency/lock, 앱 core lock, 단계 보고서, 오늘할일 상태 갱신으로 제한된다.

## 검증 결과

### 브랜치 상태

```text
$ git status --short --branch
## local/task167...origin/devel-webview [ahead 3]
```

### core dependency 갱신

실행:

```text
$ ./scripts/update-rhwp-core.sh --channel stable --tag v0.7.10
From https://github.com/edwardkim/rhwp
 * [new tag]         v0.7.10    -> v0.7.10
    Updating git repository `https://github.com/edwardkim/rhwp.git`
    Updating crates.io index
     Locking 131 packages to latest compatible versions
Checked rhwp core target:
  channel: stable
  tag:     v0.7.10
  commit:  62a458aa317e962cd3d0eec6096728c172d57110
Updated: /private/tmp/rhwp-mac-task167/RustBridge/Cargo.toml
Updated: /private/tmp/rhwp-mac-task167/RustBridge/Cargo.lock
Updated: /private/tmp/rhwp-mac-task167/rhwp-core.lock
Next: ./scripts/build-rust-macos.sh --update-lock && ./scripts/check-no-appkit.sh
```

주요 변경:

- `RustBridge/Cargo.toml`: `rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.10" }`
- `RustBridge/Cargo.lock`: `rhwp v0.7.10`, source `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.10#62a458aa317e962cd3d0eec6096728c172d57110`
- `rhwp-core.lock`: `rhwp_release_tag = "v0.7.10"`, `rhwp_commit = "62a458aa317e962cd3d0eec6096728c172d57110"`

Cargo.lock의 transitive dependency 변화:

| package | 변화 |
|---------|------|
| `pcx` | `0.2.5` 신규 추가. `rhwp v0.7.10` dependency에 포함 |
| `quick-xml` | `0.39.2` -> `0.39.3` |
| `siphasher` | `1.0.2` -> `1.0.3` |

### Rust bridge artifact update

실행:

```text
$ ./scripts/build-rust-macos.sh --update-lock
[1/4] Rust staticlib (arm64 + x86_64)...
   Compiling rhwp v0.7.10 (https://github.com/edwardkim/rhwp.git?tag=v0.7.10#62a458aa)
   Compiling rhwp_mac_bridge v0.1.0 (/private/tmp/rhwp-mac-task167/RustBridge)
    Finished `release` profile [optimized] target(s) in 48.55s
   Compiling rhwp v0.7.10 (https://github.com/edwardkim/rhwp.git?tag=v0.7.10#62a458aa)
   Compiling rhwp_mac_bridge v0.1.0 (/private/tmp/rhwp-mac-task167/RustBridge)
    Finished `release` profile [optimized] target(s) in 37.76s
[2/4] Universal binary...
Architectures in the fat file: /private/tmp/rhwp-mac-task167/Frameworks/universal/librhwp.a are: x86_64 arm64
[3/4] cbindgen header check...
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
[4/4] XCFramework...
xcframework successfully written out to: /private/tmp/rhwp-mac-task167/Frameworks/Rhwp.xcframework
Done: /private/tmp/rhwp-mac-task167/Frameworks/Rhwp.xcframework
102M	/private/tmp/rhwp-mac-task167/Frameworks/universal/librhwp.a
102M	/private/tmp/rhwp-mac-task167/Frameworks/Rhwp.xcframework
Updated: /private/tmp/rhwp-mac-task167/rhwp-core.lock
```

갱신된 `rhwp-core.lock` artifact:

| path | sha256 | size |
|------|--------|------|
| `Frameworks/universal/librhwp.a` | `fefa08d741cfdd6645081ca838601f677f6da064d95308555e29629f7609f7a2` | 107120120 |
| `Frameworks/generated_rhwp.h` | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` | 1349 |

추가 확인:

```text
$ xcrun lipo -info Frameworks/universal/librhwp.a
Architectures in the fat file: Frameworks/universal/librhwp.a are: x86_64 arm64

$ shasum -a 256 Frameworks/universal/librhwp.a Frameworks/generated_rhwp.h
fefa08d741cfdd6645081ca838601f677f6da064d95308555e29629f7609f7a2  Frameworks/universal/librhwp.a
69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5  Frameworks/generated_rhwp.h

$ stat -f '%N %z' Frameworks/universal/librhwp.a Frameworks/generated_rhwp.h
Frameworks/universal/librhwp.a 107120120
Frameworks/generated_rhwp.h 1349
```

### lock verification

실행:

```text
$ ./scripts/build-rust-macos.sh --verify-lock
[1/4] Rust staticlib (arm64 + x86_64)...
    Finished `release` profile [optimized] target(s) in 0.08s
    Finished `release` profile [optimized] target(s) in 0.07s
[2/4] Universal binary...
Architectures in the fat file: /private/tmp/rhwp-mac-task167/Frameworks/universal/librhwp.a are: x86_64 arm64
[3/4] cbindgen header check...
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
[4/4] XCFramework...
xcframework successfully written out to: /private/tmp/rhwp-mac-task167/Frameworks/Rhwp.xcframework
Done: /private/tmp/rhwp-mac-task167/Frameworks/Rhwp.xcframework
102M	/private/tmp/rhwp-mac-task167/Frameworks/universal/librhwp.a
102M	/private/tmp/rhwp-mac-task167/Frameworks/Rhwp.xcframework
Verified: /private/tmp/rhwp-mac-task167/rhwp-core.lock
```

결과: 통과. `Cargo.lock`의 `rhwp` source commit과 `rhwp-core.lock`의 `rhwp_commit`이 일치하고, artifact hash/size도 lock과 일치한다.

### FFI symbol snapshot

`cbindgen` 결과와 `rhwp-ffi-symbols.txt` 비교:

```text
$ diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
출력 없음
```

생성된 symbol set:

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

결론: FFI symbol snapshot 변화 없음. `rhwp-ffi-symbols.txt` 갱신은 필요하지 않다.

### provenance 검색

```text
$ rg -n "v0\\.7\\.9|v0\\.7\\.10|rhwp_release_tag|rhwp_commit|source =" RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
RustBridge/Cargo.toml:11:rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.10" }
rhwp-core.lock:4:rhwp_release_tag = "v0.7.10"
rhwp-core.lock:5:rhwp_commit = "62a458aa317e962cd3d0eec6096728c172d57110"
RustBridge/Cargo.lock:595:source = "git+https://github.com/edwardkim/rhwp.git?tag=v0.7.10#62a458aa317e962cd3d0eec6096728c172d57110"
```

검색 대상인 core dependency 파일 안에는 `v0.7.9`가 더 이상 남지 않는다.

### ignored build artifacts

```text
$ git status --ignored --short Frameworks build.noindex
!! Frameworks/
!! build.noindex/
```

`Frameworks/`는 local generated artifact이며 commit 대상이 아니다. release 기준 hash/size는 `rhwp-core.lock`에만 기록했다.

## 잔여 위험

- Stage 2는 Rust bridge artifact와 FFI boundary까지만 확인했다. Swift/Xcode build, render smoke, Quick Look/Thumbnail smoke는 Stage 4와 #151 범위에서 이어서 확인해야 한다.
- bundled `rhwp-studio` manifest/resource는 아직 `v0.7.9` 기준이다. Stage 3에서 `scripts/sync-rhwp-studio.sh`, `scripts/verify-rhwp-studio-assets.sh`, bundled asset/manifest를 `v0.7.10` 기준으로 맞춰야 한다.
- `librhwp.a` size가 104,179,008 bytes에서 107,120,120 bytes로 증가했다. 현재 빌드와 verify-lock은 통과했지만, packaged app size 영향은 Stage 4/package 검증에서 함께 본다.

## 다음 단계 영향

Stage 3은 bundled `rhwp-studio` 기준 정합화다. 현재 core lock은 `v0.7.10`으로 올라갔지만 viewer asset manifest는 아직 `v0.7.9`라 release artifact provenance는 Stage 3 완료 전까지 불완전하다.

Stage 3에서 해야 할 일:

- `scripts/sync-rhwp-studio.sh`의 expected commit/tag 기준을 `v0.7.10`으로 갱신
- `scripts/verify-rhwp-studio-assets.sh`의 expected manifest commit을 `62a458aa317e962cd3d0eec6096728c172d57110`으로 갱신
- upstream `rhwp-studio` v0.7.10 dist/WASM을 빌드 또는 동기화
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`과 bundled assets를 재검증

## 승인 요청

Stage 2 완료를 보고한다. 승인 후 Stage 3 `bundled rhwp-studio asset/manifest 기준 정합화`로 진행한다.
