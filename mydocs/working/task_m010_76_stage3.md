# Task #76 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 갱신한 upstream merge commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d` 기준 Rust bridge 산출물이 `rhwp-core.lock`과 일치하는지 확인하고, C ABI symbol set과 Swift bridge boundary 규칙이 유지되는지 검증한다.

## 산출물

- `mydocs/working/task_m010_76_stage3.md`
  - RustBridge lock verify, FFI symbol diff, generated header, no-AppKit, script 문법 검증 결과를 기록했다.
- `Frameworks/` generated artifacts
  - `./scripts/build-rust-macos.sh --verify-lock` 실행 중 재생성되었다.
  - `.gitignore` 대상이므로 tracked 변경에는 포함하지 않았다.

이번 단계는 검증 단계이므로 tracked source, lock, 문서 본문은 단계 보고서 외 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

본문 변경은 단계 보고서 추가뿐이다. 기존 core pin, Cargo lock, provenance lock은 Stage 2 커밋 상태를 유지한다.

## 검증 결과

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과.

```text
[1/4] Rust staticlib (arm64 + x86_64)...
    Finished `release` profile [optimized] target(s) in 0.23s
    Finished `release` profile [optimized] target(s) in 0.08s
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
 99M	/Users/melee/Documents/projects/rhwp-mac/Frameworks/universal/librhwp.a
 99M	/Users/melee/Documents/projects/rhwp-mac/Frameworks/Rhwp.xcframework
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

`xcodebuild -create-xcframework` 과정에서 CoreSimulator 관련 경고가 출력되었지만, XCFramework 생성과 lock verification은 exit code 0으로 완료했다. 경고는 simulator runtime 조회/로그 접근 문제이며 이번 macOS staticlib/XCFramework 검증 실패로 보지 않는다.

```bash
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
```

결과: 출력 없음. expected symbol set과 generated symbol set이 일치한다.

```bash
grep -n "width_pt\\|height_pt" Frameworks/generated_rhwp.h
```

결과:

```text
14:  double width_pt;
15:  double height_pt;
```

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

```bash
bash -n scripts/update-rhwp-core.sh
bash -n scripts/build-rust-macos.sh
git diff --check
```

결과: 모두 출력 없이 통과.

```bash
git status --short --ignored Frameworks
```

결과:

```text
!! Frameworks/
```

`Frameworks/`는 generated artifact이며 ignore 대상이다.

```bash
git status --short --branch
```

결과:

```text
## local/task76
```

Stage 3 보고서 작성 전 tracked working tree는 clean 상태였다.

## 잔여 위험

- Stage 3는 Rust bridge artifact와 ABI boundary 검증까지만 수행했다. HostApp build, render tree decode, image data smoke는 Stage 4에서 확인해야 한다.
- CoreSimulator 관련 경고는 `xcodebuild -create-xcframework` 단계에서 반복될 수 있다. exit code와 최종 산출물 생성 여부를 기준으로 판단한다.
- `Frameworks/`는 ignored generated artifact이므로 fresh checkout에서는 Stage 2/3 절차 또는 build script 실행으로 다시 생성되어야 한다.

## 다음 단계 영향

Stage 4는 현 산출물과 pin 기준으로 `xcodegen generate`, HostApp Debug build, `validate-stage3-render.sh` render smoke, 이미지 `bin_data_id` 조회 경로 검증을 수행한다.

## 승인 요청

Stage 3 결과를 승인하고 Stage 4: HostApp, render smoke, image data use case 검증으로 진행할지 승인 요청한다.
