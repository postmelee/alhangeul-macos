# Task #104 Stage 3 완료 보고서 - Rust bridge artifact와 lock 검증 갱신

## 목적

Stage 2에서 `v0.7.9` provenance skeleton으로 전환한 뒤, Rust bridge 산출물과 `Rhwp.xcframework`를 실제 재생성하고 `rhwp-core.lock`의 artifact hash/size를 현재 산출물 기준으로 채운다.

## 변경 파일

- `rhwp-core.lock`

`Frameworks/` 아래 산출물은 재생성되었지만 git 추적 대상이 아니다. 추적 변경은 `rhwp-core.lock` artifact metadata만 남았다.

## 산출물 재생성

실행 명령:

```bash
./scripts/build-rust-macos.sh --update-lock
```

결과:

```text
[1/4] Rust staticlib (arm64 + x86_64)...
Compiling rhwp v0.7.9
Compiling rhwp_mac_bridge v0.1.0
[2/4] Universal binary...
Architectures in the fat file: Frameworks/universal/librhwp.a are: x86_64 arm64
[3/4] cbindgen header check...
[4/4] XCFramework...
xcframework successfully written out to: Frameworks/Rhwp.xcframework
Updated: rhwp-core.lock
```

`xcodebuild -create-xcframework` 과정에서 CoreSimulatorService와 cache directory 관련 경고가 출력됐지만, XCFramework 생성은 성공했다. iOS simulator build가 아니라 macOS staticlib 기반 XCFramework 생성 단계이므로 Stage 3에서는 경고로 기록하고 진행했다.

## lock 갱신 결과

`rhwp-core.lock`은 다음 artifact metadata를 기록한다.

```text
built_at = "2026-05-01T03:42:53Z"

Frameworks/universal/librhwp.a
sha256 = "4fc34a8cb7b6489d18705ee342fab13a79df5bd559893c10c163a0787c04e619"
size = 104179008

Frameworks/generated_rhwp.h
sha256 = "69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5"
size = 1349
```

`Frameworks/generated_rhwp.h`의 hash와 size는 기존 `v0.7.8` 기준과 동일하다. `Frameworks/universal/librhwp.a`는 core 변경 반영으로 hash와 size가 갱신되었다.

## lock verify

실행 명령:

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과:

```text
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

`--verify-lock`도 `xcodebuild`의 CoreSimulatorService 관련 경고를 출력했지만, 최종 lock 검증은 통과했다.

## ABI 확인

expected symbol snapshot과 generated symbol list를 비교했다.

```bash
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
```

결과: 차이 없음.

현재 symbol set:

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

generated header 핵심 entrypoint 확인:

```text
14:  double width_pt;
15:  double height_pt;
34:char *rhwp_render_page_tree(const struct RhwpHandle *handle, uint32_t page);
36:const uint8_t *rhwp_image_data(const struct RhwpHandle *handle,
```

의도하지 않은 C ABI 변경은 없다.

## 검증

실행한 명령:

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
grep -n "rhwp_render_page_tree\\|rhwp_image_data\\|width_pt\\|height_pt" Frameworks/generated_rhwp.h
sed -n '1,80p' rhwp-core.lock
git status --short
git diff -- rhwp-core.lock
git diff --check -- rhwp-core.lock rhwp-ffi-symbols.txt
```

검증 결과:

- Rust staticlib arm64/x86_64 build 성공
- universal staticlib 생성 성공
- generated C header 생성 성공
- expected/generated FFI symbol diff 없음
- `Rhwp.xcframework` 생성 성공
- `rhwp-core.lock` artifact metadata 갱신 완료
- `./scripts/build-rust-macos.sh --verify-lock` 통과
- `git diff --check` 통과

## 다음 단계

Stage 4에서는 app/extension version 방침을 최종 확인하고, `xcodegen generate`, `check-no-appkit.sh`, HostApp Debug build, `validate-stage3-render.sh`를 수행해 Swift/macOS build와 기본 render smoke를 검증한다.
