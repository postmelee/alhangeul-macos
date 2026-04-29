# Task #95 Stage 3 완료 보고서

## 단계 목적

`rhwp v0.7.8` Stable tag 기준으로 Rust bridge 산출물과 `Rhwp.xcframework`를 재생성하고, `rhwp-core.lock`의 artifact hash/size가 현재 산출물과 일치하는지 검증한다.

## 산출물

- `Frameworks/universal/librhwp.a`
  - generated artifact, git tracked 대상 아님
  - universal static library, `x86_64 arm64`
- `Frameworks/generated_rhwp.h`
  - generated artifact, git tracked 대상 아님
  - header sha256/size는 기존과 동일
- `Frameworks/generated_rhwp_symbols.txt`
  - generated artifact, git tracked 대상 아님
  - `rhwp-ffi-symbols.txt`와 diff 없음
- `Frameworks/Rhwp.xcframework`
  - generated artifact, git tracked 대상 아님
- `rhwp-core.lock`
  - `built_at`과 artifact hash/size를 `v0.7.8` 재생성 산출물 기준으로 갱신
- `mydocs/working/task_m010_95_stage3.md`
  - Stage 3 검증 결과 기록

## 본문 변경 정도 / 본문 무손실 여부

- Rust/Swift 소스 본문은 수정하지 않았다.
- C ABI symbol snapshot `rhwp-ffi-symbols.txt`는 변경하지 않았다.
- git에 남는 변경은 `rhwp-core.lock` artifact metadata와 Stage 3 보고서다.
- generated framework/header/library는 재생성됐지만 git tracked 파일은 아니다.

## 변경 내용

`rhwp-core.lock` artifact section을 현재 산출물 기준으로 채웠다.

```text
built_at = "2026-04-29T21:32:27Z"

[[artifacts]]
path = "Frameworks/universal/librhwp.a"
sha256 = "257f3689f86f661e7cebf7f2b0debdcdfe872fe1e3b9be132917976389a9859f"
size = 104102400

[[artifacts]]
path = "Frameworks/generated_rhwp.h"
sha256 = "69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5"
size = 1349
```

`librhwp.a`는 `v0.7.8` build 결과로 hash/size가 바뀌었다. `generated_rhwp.h`는 기존 header와 같은 hash/size를 유지했다.

## 검증 결과

```bash
$ ./scripts/build-rust-macos.sh --update-lock
```

결과:

```text
[1/4] Rust staticlib (arm64 + x86_64)...
Finished `release` profile [optimized]
[2/4] Universal binary...
Architectures in the fat file: .../Frameworks/universal/librhwp.a are: x86_64 arm64
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
xcframework successfully written out to: .../Frameworks/Rhwp.xcframework
Updated: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

`xcodebuild -create-xcframework` 중 CoreSimulatorService와 cache 관련 경고가 출력됐지만 명령은 exit code 0으로 완료했다. macOS static library와 xcframework 생성 자체에는 실패가 없었다.

```bash
$ ./scripts/build-rust-macos.sh --verify-lock
```

결과:

```text
[1/4] Rust staticlib (arm64 + x86_64)...
[2/4] Universal binary...
[3/4] cbindgen header check...
[4/4] XCFramework...
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

```bash
$ diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
```

결과: 출력 없음. expected symbol snapshot과 generated symbol list가 일치한다.

```bash
$ grep -n "rhwp_render_page_tree\\|rhwp_image_data\\|width_pt\\|height_pt" Frameworks/generated_rhwp.h
```

결과:

```text
14:  double width_pt;
15:  double height_pt;
34:char *rhwp_render_page_tree(const struct RhwpHandle *handle, uint32_t page);
36:const uint8_t *rhwp_image_data(const struct RhwpHandle *handle,
```

```bash
$ git status --short
```

결과:

```text
 M rhwp-core.lock
```

보고서 작성 전 기준으로 git tracked 변경은 `rhwp-core.lock`뿐이었다.

```bash
$ git diff -- rhwp-core.lock rhwp-ffi-symbols.txt
```

결과: `rhwp-core.lock`의 `built_at`, `librhwp.a` sha256/size, `generated_rhwp.h` sha256/size만 갱신됐다. `rhwp-ffi-symbols.txt` 변경은 없었다.

## 잔여 위험

- Stage 3는 Rust bridge artifact와 ABI symbol 검증까지 수행했다. HostApp build, no-AppKit 규칙, render smoke는 Stage 4 범위로 남아 있다.
- `xcodebuild -create-xcframework`가 CoreSimulator 관련 경고를 출력했다. 명령은 성공했지만 Stage 4의 Xcode build에서도 유사한 환경 경고가 나올 수 있다.
- `v0.7.8` core로 생성한 static library는 기존보다 size가 바뀌었다. Stage 4에서 실제 Swift/macOS integration과 render smoke로 runtime 경로를 확인해야 한다.

## 다음 단계 영향

Stage 4에서 다음 검증을 수행해야 한다.

- `./scripts/check-no-appkit.sh`
- `xcodegen generate`
- HostApp Debug build
- `./scripts/validate-stage3-render.sh`
- 이미지 포함 샘플의 `bin_data_id` 기반 render smoke
- Quick Look/Thumbnail smoke 수행 여부 기록

## 승인 요청

Stage 3 완료를 승인하고 Stage 4 Swift/macOS build와 PageRenderTree render smoke 검증으로 진행할지 승인 요청한다.
