# Task M020 #255 최종 보고서

## 작업 요약

- 이슈: #255 RustBridge native-skia PNG FFI와 build/provenance gate 추가
- 마일스톤: M020 `v0.2.x Skia Quick Look/Thumbnail Backend`
- 브랜치: `local/task255`
- 단계 수: 계획/구현계획 + Stage 1-4 + 최종 보고

이번 작업은 `rhwp v0.7.11`의 `native-skia` PNG renderer를 RustBridge staticlib에 포함하고, 후속 #256에서 Swift wrapper가 호출할 수 있는 C ABI와 artifact/provenance 검증 기준을 추가했다. Quick Look/Thumbnail 제품 동작은 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|---|---|
| `RustBridge/Cargo.toml` | `rhwp` dependency에 `features = ["native-skia"]` 추가. |
| `RustBridge/Cargo.lock` | `skia-safe`, `skia-bindings` 등 native-skia dependency graph 반영. |
| `RustBridge/src/lib.rs` | `RhwpRenderStatus` enum과 `rhwp_render_page_png` FFI 추가. |
| `RustBridge/cbindgen.toml` | `RhwpRenderStatus`를 generated header export 대상에 포함. |
| `project.yml` | `Rhwp.xcframework`를 링크하는 HostApp/QLExtension/ThumbnailExtension에 Skia native framework/library dependency 명시. |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 `project.yml`의 link dependency 반영. |
| `rhwp-ffi-symbols.txt` | expected FFI symbol set에 `rhwp_render_page_png` 추가. |
| `scripts/build-rust-macos.sh` | `rhwp_enabled_features` 기록/검증 gate 추가. |
| `rhwp-core.lock` | `native-skia` feature provenance와 새 artifact hash/size 기록. |
| `mydocs/plans/task_m020_255.md` | 수행계획서 작성. |
| `mydocs/plans/task_m020_255_impl.md` | ABI, stage, 검증 계획을 포함한 구현계획서 작성. |
| `mydocs/working/task_m020_255_stage1.md` | upstream API, RustBridge ABI, provenance gate inventory 기록. |
| `mydocs/working/task_m020_255_stage2.md` | RustBridge source-level PNG FFI 구현 결과 기록. |
| `mydocs/working/task_m020_255_stage3.md` | generated artifact와 lock/provenance 갱신 결과 기록. |
| `mydocs/working/task_m020_255_stage4.md` | C smoke 기반 정상/실패 ABI 검증 결과 기록. |
| `mydocs/orders/20260518.md` | #255 상태를 완료로 갱신. |

## 변경 전후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|---|---:|---:|
| FFI expected symbol 수 | 10 | 11 |
| 새 PNG ABI | 없음 | `rhwp_render_page_png` |
| render status taxonomy | 없음 | `RhwpRenderStatus` 6개 값 |
| `rhwp_enabled_features` lock field | 없음 | `native-skia` |
| `Frameworks/universal/librhwp.a` size | 108,417,040 bytes | 190,410,384 bytes |
| `Frameworks/generated_rhwp.h` size | 1,349 bytes | 1,978 bytes |
| `du -sh` staticlib / xcframework | 기존 수치 없음 | `182M` / `182M` |
| 초기 Stage 1-5 변경량 | 0 | 14 files, 1464 insertions, 6 deletions |
| PR review 보완 변경량 | 0 | 5 files, 189 insertions, 8 deletions |

staticlib 크기는 81,993,344 bytes 증가했다. 이 증가는 `native-skia`와 Skia dependency 포함에 따른 것으로, #259 release readiness gate에서 package size와 배포 영향 확인이 필요하다.

## ABI 결과

새 C ABI:

```c
enum RhwpRenderStatus rhwp_render_page_png(const struct RhwpHandle *handle,
                                           uint32_t page,
                                           double scale,
                                           uint32_t max_dimension,
                                           uint8_t **out_data,
                                           uintptr_t *out_len);
```

Status taxonomy:

| ABI status | 의미 | #256 Swift fallback reason 후보 |
|---|---|---|
| `RHWP_RENDER_OK` | PNG bytes 반환 성공 | 없음 |
| `RHWP_RENDER_INVALID_HANDLE` | null document handle | `invalidDocumentHandle` 또는 `ffiUnavailable` |
| `RHWP_RENDER_INVALID_OUTPUT` | output pointer 누락 | `ffiUnavailable` |
| `RHWP_RENDER_INVALID_PAGE_INDEX` | page index 범위 초과 | `invalidPageIndex` |
| `RHWP_RENDER_INVALID_OPTIONS` | scale/max_dimension option 오류 | `invalidPageSize` 또는 `invalidRenderOptions` |
| `RHWP_RENDER_FAILURE` | upstream render error, empty bytes, panic guard 실패 | `skiaRenderFailure` |

Option sentinel:

- `scale == 0.0`: upstream default scale
- `scale > 0.0`: explicit scale
- `scale < 0.0`, NaN, infinite: invalid options
- `max_dimension == 0`: upstream default max dimension
- `max_dimension > 0`: explicit max dimension

성공한 PNG bytes는 기존 `rhwp_free_bytes(ptr, len)`로 해제한다.

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|---|---|---|
| `native-skia` feature로 RustBridge build 가능 | OK | `cargo check --manifest-path RustBridge/Cargo.toml` 통과. |
| generated header와 symbol lock에 새 ABI 반영 | OK | `rhwp_render_page_png`, `RhwpRenderStatus` 확인. |
| build/provenance gate가 feature 활성화 상태 검증 | OK | `rhwp_enabled_features = "native-skia"` lock 기록과 `--verify-lock` 비교 추가. |
| source provenance 유지 | OK | `rhwp v0.7.11`, commit `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` 유지. |
| universal staticlib에 새 symbol 포함 | OK | `_rhwp_render_page_png` symbol 확인. |
| 정상 PNG render smoke | OK | `KTX.hwp` 62,065 bytes, `request.hwp` 50,986 bytes PNG signature 통과. |
| 실패 status smoke | OK | null handle, null output, page out-of-range, invalid scale 확인. |
| invalid output stale 값 방지 | OK | 한쪽 output pointer가 null이어도 null이 아닌 쪽을 null/0으로 초기화하도록 보완하고 C smoke로 확인. |
| Xcode target link dependency | OK | HostApp/QLExtension/ThumbnailExtension에 Skia system framework/library dependency를 추가하고 HostApp Debug build 통과. |
| lock verification | OK | `./scripts/build-rust-macos.sh --verify-lock` 통과. |
| whitespace 검증 | OK | `git diff --check` 통과. |

최종 통합 검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과. `xcodebuild -create-xcframework` 과정에서 CoreSimulator 관련 warning이 출력됐지만, xcframework 생성과 lock verification은 성공했다.

```text
FFI symbols:
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_size
rhwp_render_page_png
rhwp_render_page_svg
rhwp_render_page_tree
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

추가 검증:

```bash
nm -gU Frameworks/universal/librhwp.a | rg "rhwp_render_page_png|rhwp_free_bytes|rhwp_open|rhwp_close"
C smoke: 한쪽 output pointer null 조합에서 stale pointer/length가 남지 않음 확인
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask255Review -clonedSourcePackagesDirPath build.noindex/SourcePackages CODE_SIGNING_ALLOWED=NO build
git diff --check
```

결과: 통과.

## 잔여 위험과 후속 작업

| 항목 | 내용 | 후속 |
|---|---|---|
| Swift wrapper 미적용 | Stage 4 smoke는 C ABI 직접 호출만 검증했다. Swift `UnsafeMutablePointer` 수명과 `Data` 복사는 아직 미검증이다. | #256 |
| native link dependency | Skia static archive에 필요한 native framework/library는 project target에 명시했다. #256에서 실제 Swift wrapper 호출 경로의 build와 runtime smoke를 이어서 확인한다. | #256 |
| Quick Look/Thumbnail 미적용 | 제품 surface의 기본 동작은 바꾸지 않았다. | #257, #258 |
| size 증가 | universal staticlib가 약 108 MB에서 190 MB로 증가했다. | #259 |
| upstream diagnostic 출력 | `KTX.hwp` render smoke에서 layout overflow diagnostic이 stdout/stderr로 출력됐다. | #256, #259 |
| feature parser 제약 | `scripts/build-rust-macos.sh`의 feature parser는 현재 single-line dependency 선언 형식을 전제로 한다. | dependency 선언 형식 변경 시 보강 |

## #256 handoff

#256에서 바로 사용할 입력:

- `RhwpRenderStatus` enum 값과 Swift fallback reason 매핑 후보
- `rhwp_render_page_png` C signature
- `scale == 0.0`, `max_dimension == 0` sentinel 규칙
- 성공 시 PNG bytes를 `rhwp_free_bytes`로 해제하는 소유권 규칙
- C smoke 기준 정상 PNG byte length: `KTX.hwp` 62,065 bytes, `request.hwp` 50,986 bytes
- Xcode target link에는 Skia native framework/library dependency가 반영되어 있음
- Swift wrapper 단계에서 `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs` 진단 필드 연결 필요

## 작업지시자 승인 요청

#255는 RustBridge native-skia PNG FFI와 build/provenance gate 추가 범위로 완료한다. PR 리뷰와 merge 승인 후에는 #256 Swift wrapper/backend abstraction 작업으로 넘어갈 수 있다.
