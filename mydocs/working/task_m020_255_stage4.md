# Task M020 #255 Stage 4 보고서

## 단계 목적

Stage 4의 목적은 Stage 3에서 생성한 Skia PNG ABI artifact가 실제 universal staticlib에 들어갔는지 확인하고, 정상/실패 FFI status가 Swift wrapper로 넘길 수 있을 만큼 동작하는지 smoke로 검증하는 것이다.

이 단계에서는 RustBridge source, generated artifact, lock 파일을 추가 변경하지 않는다.

## 산출물

| 파일 | 요약 |
|---|---|
| `mydocs/working/task_m020_255_stage4.md` | ABI symbol, 정상 PNG render, 실패 status smoke 검증 결과. |
| `mydocs/orders/20260518.md` | #255 상태를 Stage 4 완료 및 Stage 5 승인 대기로 갱신. |

임시 산출물:

- `/private/tmp/task255_ffi_smoke`: C smoke binary. 저장소에는 남기지 않았다.

## ABI smoke 내용

임시 C smoke는 `Frameworks/modulemap/rhwp.h`와 `Frameworks/universal/librhwp.a`를 직접 사용했다. Skia가 포함된 static archive 링크에는 다음 native framework/runtime이 필요했다.

- `CoreFoundation`
- `CoreText`
- `CoreGraphics`
- `Foundation`
- `ImageIO`
- `CoreServices`
- `ApplicationServices`
- `Security`
- `Metal`
- `QuartzCore`
- `IOSurface`
- `ColorSync`
- `libc++`
- `libiconv`
- `zlib`

첫 clang 시도는 `-x c`가 static archive 입력에도 적용되어 archive를 C source처럼 읽는 실수로 실패했다. `-x none`을 library 입력 앞에 추가하고 위 framework들을 명시한 뒤 smoke binary를 정상 빌드했다.

검증한 FFI 흐름:

1. `rhwp_render_page_png(NULL, ...)`이 `RHWP_RENDER_INVALID_HANDLE`을 반환하고 output을 null/0으로 초기화하는지 확인.
2. null output pointer가 `RHWP_RENDER_INVALID_OUTPUT`을 반환하는지 확인.
3. `rhwp_open`으로 sample 문서를 열고 `rhwp_page_count`를 확인.
4. `page == page_count`가 `RHWP_RENDER_INVALID_PAGE_INDEX`를 반환하는지 확인.
5. `scale < 0`이 `RHWP_RENDER_INVALID_OPTIONS`를 반환하는지 확인.
6. `rhwp_render_page_png(handle, 0, 0.0, 512, ...)`가 `RHWP_RENDER_OK`와 PNG signature를 반환하는지 확인.
7. 반환된 PNG bytes를 `rhwp_free_bytes`로 해제하고 handle을 `rhwp_close`로 닫음.

## 정상 샘플 결과

`samples/basic/KTX.hwp`:

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=28 line=0 y=768.5 col_bottom=755.9 overflow=12.5px
LAYOUT_OVERFLOW: page=0, col=0, para=28, type=PartialParagraph, y=776.5, bottom=755.9, overflow=20.5px
null_handle_status=1
invalid_output_status=2
page_count=1
invalid_page_status=3
invalid_scale_status=4
render_status=0
png_len=62065
```

`samples/basic/request.hwp`:

```text
null_handle_status=1
invalid_output_status=2
page_count=1
invalid_page_status=3
invalid_scale_status=4
render_status=0
png_len=50986
```

두 샘플 모두 PNG signature 검증까지 통과했다. `KTX.hwp`는 upstream layout overflow diagnostic을 출력했지만 ABI status는 정상이다. 이 diagnostic은 #256 Swift wrapper에서 stderr/stdout을 직접 수집하지 않는 한 제품 로그와 별개다.

## symbol 확인

```bash
nm -gU Frameworks/universal/librhwp.a | rg "rhwp_render_page_png|rhwp_free_bytes|rhwp_open|rhwp_close"
```

결과:

```text
0000000000002c04 T _rhwp_close
0000000000002f0c T _rhwp_free_bytes
0000000000002fa0 T _rhwp_open
000000000000331c T _rhwp_render_page_png
```

## 본문 변경 정도 / 본문 무손실 여부

- 코드, RustBridge source, build script, lock 파일은 Stage 4에서 변경하지 않았다.
- 문서 변경은 Stage 4 보고서와 오늘할일 상태 갱신뿐이다.
- 기존 문서 본문 삭제는 없다.

## 검증 결과

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과. Stage 3과 동일하게 `xcodebuild -create-xcframework` 과정에서 CoreSimulator 관련 warning이 출력됐지만, xcframework 생성과 lock verification은 성공했다.

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

```bash
nm -gU Frameworks/universal/librhwp.a | rg "rhwp_render_page_png|rhwp_free_bytes|rhwp_open|rhwp_close"
```

결과: 통과. 새 PNG ABI와 open/free/close symbol이 universal staticlib에 존재한다.

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- Stage 4 smoke는 Swift wrapper가 아니라 C binary로 직접 FFI를 호출했다. Swift `UnsafeMutablePointer` 수명/해제 래핑은 #256에서 별도 검증해야 한다.
- staticlib를 직접 링크할 때 Skia/CoreText 관련 framework/runtime을 명시해야 한다. Xcode target link 단계에서 `Rhwp.xcframework`가 같은 native dependency를 만족하는지 #256 또는 app build에서 확인해야 한다.
- `KTX.hwp`에서 upstream layout overflow diagnostic이 출력됐다. 렌더 실패는 아니지만 extension 환경에서 stdout/stderr 노이즈가 문제되는지 후속 smoke에서 관찰해야 한다.
- 실패 status는 null handle, null output pointer, out-of-range page, invalid scale까지만 확인했다. upstream render failure 강제 유도와 memory/timeout failure는 #256/#259에서 다룬다.

## 다음 단계 영향

Stage 5에서는 #255 최종 보고서를 작성하고 #256 handoff를 정리한다.

#256에서 바로 받을 수 있는 입력:

- `RhwpRenderStatus` enum 값
- `rhwp_render_page_png` C signature
- 성공 시 PNG bytes + `rhwp_free_bytes` 해제 규칙
- 실패 status와 Swift fallback reason 매핑 후보
- sample smoke 결과의 정상 PNG byte length
- native link/framework dependency 확인 필요성

## 승인 요청

Stage 4는 ABI smoke와 실패 경로 검증으로 마무리한다. Stage 5 `최종 보고서와 PR 준비`로 진행하려면 작업지시자 승인이 필요하다.
