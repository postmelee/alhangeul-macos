# Task #30 Stage 4 완료 보고서

## 단계 목적

git dependency 기준으로 Rust bridge와 XCFramework를 실제 빌드하고, `rhwp-core.lock`의 artifact hash/size를 현재 산출물 기준으로 갱신한 뒤 FFI symbol과 lock 검증을 수행한다.

## 산출물

- `rhwp-core.lock`
  - `built_at = "2026-04-25T23:54:56Z"`
  - `Frameworks/universal/librhwp.a`
    - `sha256 = "4548f87fdf93eef196a85d6f553869c78478075df4c6e4496f66e20ebb125ed5"`
    - `size = 102635296`
  - `Frameworks/generated_rhwp.h`
    - `sha256 = "69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5"`
    - `size = 1349`
- `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h`, `Frameworks/Rhwp.xcframework`
  - 생성 산출물이며 `.gitignore` 대상이라 커밋하지 않는다.
- `mydocs/orders/20260426.md`
  - #30 비고를 Stage 5 승인 대기 상태로 갱신
- `mydocs/working/task_m010_30_stage4.md`
  - Stage 4 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

이번 단계의 tracked 변경은 `rhwp-core.lock` artifact metadata와 단계 보고서/오늘할일뿐이다. Rust source, Swift source, FFI symbol 고정 파일, build script 본문은 변경하지 않았다.

## 검증 결과

build와 lock update:

```text
$ ./scripts/build-rust-macos.sh --update-lock
[1/4] Rust staticlib (arm64 + x86_64)...
   Compiling rhwp v0.7.3 (https://github.com/edwardkim/rhwp.git?rev=1e9d78a1d40c71779d81c6ec6870cd301d912626#1e9d78a1)
   Compiling rhwp_mac_bridge v0.1.0 (/Users/melee/Documents/projects/rhwp-mac/RustBridge)
    Finished `release` profile [optimized] target(s) in 13.77s
   Compiling rhwp v0.7.3 (https://github.com/edwardkim/rhwp.git?rev=1e9d78a1d40c71779d81c6ec6870cd301d912626#1e9d78a1)
   Compiling rhwp_mac_bridge v0.1.0 (/Users/melee/Documents/projects/rhwp-mac/RustBridge)
    Finished `release` profile [optimized] target(s) in 13.15s
[2/4] Universal binary...
Architectures in the fat file: /Users/melee/Documents/projects/rhwp-mac/Frameworks/universal/librhwp.a are: x86_64 arm64
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
xcframework successfully written out to: /Users/melee/Documents/projects/rhwp-mac/Frameworks/Rhwp.xcframework
Done: /Users/melee/Documents/projects/rhwp-mac/Frameworks/Rhwp.xcframework
Updated: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

lock verify:

```text
$ ./scripts/build-rust-macos.sh --verify-lock
[1/4] Rust staticlib (arm64 + x86_64)...
    Finished `release` profile [optimized] target(s) in 0.09s
    Finished `release` profile [optimized] target(s) in 0.07s
[2/4] Universal binary...
Architectures in the fat file: /Users/melee/Documents/projects/rhwp-mac/Frameworks/universal/librhwp.a are: x86_64 arm64
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
xcframework successfully written out to: /Users/melee/Documents/projects/rhwp-mac/Frameworks/Rhwp.xcframework
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

`xcodebuild -create-xcframework` 중 CoreSimulatorService 관련 sandbox 로그가 출력됐지만, XCFramework 생성과 lock 검증은 모두 성공했다.

FFI symbol diff:

```text
$ diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
결과: 차이 없음
```

generated header field:

```text
$ grep -n "width_pt\\|height_pt" Frameworks/generated_rhwp.h
14:  double width_pt;
15:  double height_pt;
```

script 문법과 shellcheck:

```text
$ bash -n scripts/build-rust-macos.sh
결과: 통과

$ shellcheck scripts/build-rust-macos.sh
결과: 통과
```

diff check:

```text
$ git diff --check
결과: 통과
```

## 잔여 위험

- `Frameworks/` 산출물은 ignored generated output이라 커밋하지 않는다. fresh checkout에서는 `./scripts/build-rust-macos.sh`로 다시 생성해야 한다.
- Stage 5 전까지 README와 매뉴얼에는 아직 submodule 기준 안내가 남아 있다.
- Stage 6에서 HostApp build와 render smoke까지 통합 검증해야 한다.

## 다음 단계 영향

Stage 5에서는 README, architecture, core 운영, build/run, release 문서의 active submodule 안내를 git dependency 기준으로 보정한다. Stage 4에서 artifact lock이 채워졌으므로 Stage 5 문서에는 `Cargo.lock`/`rhwp-core.lock` 정합성과 `--verify-lock` 기준을 실제 완료 상태로 설명할 수 있다.

## 승인 요청

Stage 4 `build script, artifact lock, FFI symbol 검증 보강`을 완료했다. 이 보고서 기준으로 Stage 5 `사용자 문서와 운영 매뉴얼을 git dependency 기준으로 보정`을 진행할지 승인 요청한다.
