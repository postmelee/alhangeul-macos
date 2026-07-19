# Task M020 #408 Stage 3 보고서

## 단계 목적

Stage 3의 목적은 Stage 2에서 구현한 external image context C ABI를 expected symbol set과 generated header/staticlib/xcframework에 반영하고, `rhwp-core.lock` artifact metadata와 RustBridge architecture/ownership 문서를 일치시키는 것이다.

이 단계에서는 Swift wrapper나 Quick Look/Thumbnail 제품 경로를 변경하지 않는다. Swift compile/link와 embedded render regression은 Stage 4 범위다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `rhwp-ffi-symbols.txt` | 신규 symbol 세 개를 정렬된 expected set에 추가했다. 현재 15줄이다. |
| `rhwp-core.lock` | source provenance는 유지하고 staticlib/header artifact hash, size, build timestamp를 갱신했다. |
| `scripts/build-rust-macos.sh` | 숫자가 포함된 FFI symbol을 온전히 추출하도록 regex를 `[a-z0-9_]+`로 보강했다. 현재 677줄이다. |
| `RustBridge/README.md` | current core pin, external image ABI, status, 메모리·filesystem 책임 경계를 문서화했다. 현재 80줄이다. |
| `mydocs/tech/project_architecture.md` | current FFI 표면과 external context/ownership 규칙을 추가했다. 현재 265줄이다. |
| `mydocs/working/task_m020_408_stage3.md` | Stage 3 build, artifact, provenance, 문서 검증과 Stage 4 handoff를 기록한다. |
| `mydocs/orders/20260711.md` | #408을 Stage 3 완료 및 Stage 4 승인 대기 상태로 갱신한다. |

생성·검증했지만 저장소 정책에 따라 commit하지 않는 ignored 산출물:

- `Frameworks/generated_rhwp.h`
- `Frameworks/generated_rhwp_symbols.txt`
- `Frameworks/universal/librhwp.a`
- `Frameworks/Rhwp.xcframework/**`

## Expected/generated symbol 결과

`rhwp-ffi-symbols.txt`에 다음 symbol을 추가했다.

- `rhwp_external_image_refs_json`
- `rhwp_inject_external_image_by_key`
- `rhwp_set_file_name_utf8`

최종 expected/generated symbol set은 15개이며 `diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt`가 빈 결과로 통과했다.

generated header는 다음 계약을 포함한다.

- `RhwpExternalImageStatus` enum 값 0-6
- mutable `RhwpHandle *`를 받는 filename setter
- const `RhwpHandle *`를 받는 refs JSON query
- mutable `RhwpHandle *`, caller-owned key/data/display path buffer와 `uintptr_t` length를 받는 injection

universal staticlib의 global text symbol에서도 세 함수가 확인됐다.

```text
_rhwp_external_image_refs_json
_rhwp_inject_external_image_by_key
_rhwp_set_file_name_utf8
```

## Build gate 보강

첫 `./scripts/build-rust-macos.sh --update-lock` 실행은 arm64/x86_64 release build와 universal binary 생성까지 성공했지만 generated symbol 추출 단계에서 실패했다.

원인은 기존 regex가 `\brhwp_[a-z_]+`여서 숫자 `8`을 허용하지 않고 `rhwp_set_file_name_utf8`을 `rhwp_set_file_name_utf`으로 잘랐기 때문이다. 함수명이나 cbindgen 출력 오류가 아니라 build gate의 symbol parser 문제였다.

다음 최소 수정 후 같은 명령을 다시 실행했다.

```diff
-grep -oE '\brhwp_[a-z_]+'
+grep -oE '\brhwp_[a-z0-9_]+'
```

수정 후 expected/generated symbol diff, xcframework 생성, lock update와 verify가 모두 통과했다. `bash -n scripts/build-rust-macos.sh`도 통과했다.

## Artifact와 provenance

source provenance는 변경되지 않았다.

| 필드 | 값 |
|------|----|
| `rhwp_ref_kind` | `release-tag` |
| `rhwp_release_tag` | `v0.7.17` |
| `rhwp_commit` | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| `rhwp_enabled_features` | `native-skia` |

artifact 변화:

| artifact | 이전 | 현재 | 변화 |
|----------|------|------|------|
| `Frameworks/universal/librhwp.a` | 202,902,712 bytes | 202,931,144 bytes | +28,432 bytes |
| `Frameworks/generated_rhwp.h` | 2,059 bytes | 3,310 bytes | +1,251 bytes |

현재 reference metadata:

- staticlib sha256: `e454ac6b32667c84509d320ce6da7972277a5d97655f3187f19f2f5a9a8a5acd`
- header sha256: `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5`
- `built_at`: `2026-07-11T13:10:18Z`
- universal staticlib과 xcframework 표시 크기: 각각 194M
- universal architectures: `x86_64 arm64`

## ABI와 ownership 문서화

`RustBridge/README.md`와 `project_architecture.md`에 다음을 반영했다.

- 세 external image context 함수와 `RhwpExternalImageStatus`
- refs JSON의 `key`, `binDataId`, `originalPath`, `basename`, `extension`, `loaded` 계약
- filename/key/data/display path는 caller-owned이며 호출 동안 유효해야 한다는 규칙
- refs JSON은 Rust-owned string이며 `rhwp_free_string`으로 해제한다는 규칙
- injection 성공 시 upstream document가 image bytes를 복사해 소유한다는 규칙
- `rhwp_image_data` pointer는 즉시 복사하고 mutable 호출을 넘겨 보관하지 않는다는 규칙
- RustBridge가 original/display path를 filesystem lookup에 사용하지 않는다는 책임 경계
- `rhwp_image_state_json`은 pinned public API 부재로 제공하지 않는다는 판단

architecture의 기존 FFI 목록에서 빠져 있던 `rhwp_page_overlay_images`와 `rhwp_render_page_png`도 current expected symbol set에 맞춰 함께 보정했다.

## 본문 변경 정도 / 본문 무손실 여부

- RustBridge ABI 구현 source와 cbindgen 설정은 Stage 2 이후 변경하지 않았다.
- expected symbol set은 신규 세 symbol만 additive로 증가했다.
- build script는 symbol 추출 regex 한 줄만 수정했으며 build 순서, target, lock 정책은 변경하지 않았다.
- `rhwp-core.lock`은 artifact metadata와 timestamp만 변경됐고 core repo/tag/commit/features는 무손실이다.
- 두 문서는 기존 구조를 유지하며 current ABI와 ownership 규칙을 필요한 위치에 추가했다.
- generated `Frameworks/**`와 Rust target 산출물은 ignored 상태이며 commit 대상에 포함하지 않는다.
- Swift, Quick Look, Thumbnail, HostApp 제품 source는 변경하지 않았다.

## 검증 결과

### Artifact update

```bash
./scripts/build-rust-macos.sh --update-lock
```

최종 결과: 통과.

```text
[1/4] Rust staticlib (arm64 + x86_64)...
[2/4] Universal binary... x86_64 arm64
[3/4] cbindgen header check... 15 FFI symbols
[4/4] XCFramework...
xcframework successfully written out
Updated: rhwp-core.lock
```

첫 실행의 숫자 symbol 절단 실패는 build gate regex를 보정한 뒤 같은 명령으로 회복했다.

### Lock verification

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과.

```text
Verified: rhwp-core.lock
```

두 build 실행의 `xcodebuild -create-xcframework` 과정에서 sandbox가 CoreSimulatorService와 사용자 log/cache 경로에 접근하지 못한다는 경고가 출력됐다. 이 작업은 simulator runtime을 사용하지 않으며 명령 exit code는 0, xcframework 생성과 lock verification은 성공했다.

### Header와 symbol

```bash
rg -n "RhwpExternalImageStatus|rhwp_set_file_name_utf8|rhwp_external_image_refs_json|rhwp_inject_external_image_by_key" \
  Frameworks/generated_rhwp.h Frameworks/generated_rhwp_symbols.txt rhwp-ffi-symbols.txt
nm -gU Frameworks/universal/librhwp.a | \
  rg "rhwp_(set_file_name_utf8|external_image_refs_json|inject_external_image_by_key)"
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
```

결과: 모두 통과. Header declaration, expected/generated set 일치, staticlib global symbol 존재를 확인했다.

### Source provenance

```bash
rg -n "v0.7.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia" rhwp-core.lock
```

결과: 통과. release tag, commit, feature가 유지됐다.

### Script와 문서 diff

```bash
bash -n scripts/build-rust-macos.sh
LC_ALL=C sort -c rhwp-ffi-symbols.txt
git diff --check -- rhwp-ffi-symbols.txt rhwp-core.lock RustBridge/README.md \
  mydocs/tech/project_architecture.md scripts/build-rust-macos.sh \
  mydocs/working/task_m020_408_stage3.md mydocs/orders/20260710.md
git diff --check
```

결과: 통과. 구현계획서가 참조한 7월 10일 orders는 Stage 1 기록으로 유지하고, 현재 진행 상태는 7월 11일 orders에서 전체 diff check로 함께 검증했다.

## 잔여 위험

- Stage 3은 artifact 생성과 symbol/provenance 검증까지 완료했지만 Swift import/compile은 아직 실행하지 않았다. Stage 4에서 실제 generated xcframework를 HostApp과 link한다.
- exact external fixture가 없어 신규 ABI의 성공 injection visual 경로는 아직 검증하지 못했다. #409와 #412에서 확인해야 한다.
- `rhwp_image_state_json`이 없어 embedded/external/missing/decode failure 전체 상태를 단일 query로 얻을 수 없다. External loaded는 refs JSON, renderer failure는 #410이 소유한다.
- staticlib hash는 build environment 영향을 받을 수 있다. 현재 lock은 이 작업 환경의 reference metadata이며 CI는 기존 정책에 따라 staticlib hash skip을 사용할 수 있다.
- CoreSimulatorService 경고는 비치명적이었지만 Stage 4 xcodebuild에서도 sandbox 환경 경고가 반복될 수 있다. build exit code와 compile/link 결과를 기준으로 판정한다.
- build symbol parser는 이제 소문자·숫자·underscore를 지원한다. 향후 대문자 symbol을 도입하면 regex 정책을 다시 검토해야 한다.

## 다음 단계 영향

Stage 4에서는 이번 단계에서 생성한 `Rhwp.xcframework`를 사용해 다음을 검증한다.

1. `check-no-appkit.sh` 공통 계층 경계
2. `xcodegen generate`와 HostApp Debug compile/link
3. 기본 fixture의 page count/size/render tree/native bitmap smoke
4. `samples/hwp-img-001.hwp`의 기존 embedded image lookup 회귀
5. Rust unit test와 staticlib symbol 재확인
6. Swift가 import한 신규 enum/function signature 기록

## 승인 요청

Stage 3 `Header, symbol, provenance와 ABI 문서 갱신`은 완료됐다. Stage 4 `Swift compile/link와 embedded render 회귀 검증`으로 진행하려면 작업지시자 승인이 필요하다.
