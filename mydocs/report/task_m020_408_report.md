# Task M020 #408 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #408 `RustBridge external image context C ABI 구현` |
| Parent | #407 `external image context ABI 후속 구현 추적` |
| 선행 조사 | #391 filename/external image context ABI 조사, #404 upstream 렌더 diff 측정 |
| 후속 구현 | #409 Swift wrapper/resolver와 Quick Look Preview 적용 |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 작업 브랜치 | `local/task408` |
| 단계 수 | 수행계획/구현계획 + Stage 1-5 |

현재 pinned `rhwp v0.7.17`의 `HwpDocument`가 제공하는 filename context, external image reference 조회, key-based bytes injection을 macOS Swift에서 호출할 수 있는 additive C ABI로 노출했다.

기존 opaque `RhwpHandle`, open/page/render/image ABI와 `bin_data_id` lookup 계약은 유지했다. RustBridge는 external file을 직접 찾거나 읽지 않으며, 후속 #409의 Swift/macOS shell이 source URL 권한, resolver policy, size 제한과 bytes read를 소유하도록 경계를 고정했다.

Quick Look/Thumbnail 제품 동작은 이번 이슈에서 변경하지 않았다. #408 완료 시점은 “external image를 해결할 bridge가 준비된 상태”이며 “Preview resolver가 실제로 동작하는 상태”는 #409 완료 후다.

## 최종 결과

| 수용 기준 | 결과 |
|-----------|------|
| `RhwpHandle`을 `HwpDocument` 기반으로 전환 | 완료 |
| 기존 page/render/image ABI 호환성 유지 | 완료 |
| filename context C ABI | 완료 |
| external refs JSON C ABI | 완료 |
| key-based bytes injection C ABI | 완료 |
| status enum과 invalid-input taxonomy | 완료 |
| generated header/staticlib/xcframework 반영 | 완료 |
| expected/generated symbol lock 일치 | 완료 |
| artifact provenance 갱신 | 완료 |
| Swift import 및 HostApp/extension compile/link | 완료 |
| embedded image render 회귀 없음 | 완료 |
| RustBridge filesystem lookup 없음 | 완료 |
| `rhwp_image_state_json` | pinned public API 부재로 보류 |
| external injection 성공 visual fixture | exact fixture 부재로 #409/#412 이관 |

## 변경 파일과 영향 범위

### Product/bridge source

| 파일 | 내용 |
|------|------|
| `RustBridge/src/lib.rs` | `HwpDocument` handle 전환, `RhwpExternalImageStatus`, 세 신규 ABI, pointer/JSON helper, unit test 4개 |
| `RustBridge/cbindgen.toml` | external status enum export |
| `RustBridge/examples/svg_pdf_benchmark.rs` | Stage 1 formatter gate를 위한 기존 rustfmt drift 정규화, 동작 변경 없음 |

### ABI/artifact/provenance

| 파일 | 내용 |
|------|------|
| `rhwp-ffi-symbols.txt` | expected set에 신규 symbol 세 개 추가, 총 15개 |
| `rhwp-core.lock` | source pin 유지, staticlib/header artifact metadata 갱신 |
| `scripts/build-rust-macos.sh` | 숫자 포함 symbol을 온전히 추출하도록 regex 보강 |

### 계약 문서

| 파일 | 내용 |
|------|------|
| `RustBridge/README.md` | external image ABI, status, ownership, filesystem 책임 경계 |
| `mydocs/tech/project_architecture.md` | current FFI 표면과 Swift/macOS shell 경계 |

### 하이퍼-워터폴 문서

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m020_408.md` | 수행계획서 |
| `mydocs/plans/task_m020_408_impl.md` | 5단계 구현계획서와 ABI 확정안 |
| `mydocs/working/task_m020_408_stage1.md` | handle 전환 및 기존 ABI 호환성 |
| `mydocs/working/task_m020_408_stage2.md` | external context ABI와 Rust test |
| `mydocs/working/task_m020_408_stage3.md` | generated artifact, provenance, 문서 |
| `mydocs/working/task_m020_408_stage4.md` | Swift compile/link와 embedded render regression |
| `mydocs/report/task_m020_408_report.md` | 본 최종 결과와 #409 handoff |
| `mydocs/orders/20260710.md`, `20260711.md` | 착수·단계 진행·완료 상태 |

Swift product source, `project.yml`, core dependency tag/commit, sample fixture는 변경하지 않았다. Generated `Frameworks/**`, `RustBridge/target/**`, `build.noindex/**`, `output/**`는 검증에 사용했지만 ignored 산출물로 commit하지 않는다.

## 단계와 커밋

| 구분 | 커밋 | 결과 |
|------|------|------|
| 수행계획 | `71c24f9` | 이슈 범위, 5단계, 검증·리스크 승인 기준 |
| 구현계획 | `bf4c9dc` | pinned API inventory와 최종 ABI 초안 |
| Stage 1 | `6cbe649` | `HwpDocument` handle 전환, 기존 ABI compile 호환성 |
| Stage 2 | `3ddeb62` | status enum, 세 C ABI, unit test 4개 |
| Stage 3 | `5a29f81` | header/symbol/artifact/provenance와 계약 문서 |
| Stage 4 | `5af44e2` | Swift compile/link, render regression, Swift import type |
| Stage 5 | 이번 커밋 | 최종 보고서와 #409 handoff, 오늘할일 완료 |

## 최종 C ABI 계약

### Status enum

```c
typedef enum RhwpExternalImageStatus {
  RHWP_EXTERNAL_IMAGE_OK = 0,
  RHWP_EXTERNAL_IMAGE_INVALID_HANDLE = 1,
  RHWP_EXTERNAL_IMAGE_INVALID_INPUT = 2,
  RHWP_EXTERNAL_IMAGE_INVALID_UTF8 = 3,
  RHWP_EXTERNAL_IMAGE_REFERENCE_NOT_FOUND = 4,
  RHWP_EXTERNAL_IMAGE_ALREADY_LOADED = 5,
  RHWP_EXTERNAL_IMAGE_FAILURE = 6,
} RhwpExternalImageStatus;
```

| rawValue | Swift mapping 권장 | 의미 |
|----------|--------------------|------|
| 0 | `.ok` | filename 설정 또는 injection 성공 |
| 1 | `.invalidHandle` | null document handle |
| 2 | `.invalidInput` | pointer/length 불일치, 빈 key/data |
| 3 | `.invalidUTF8` | filename/key/display path UTF-8 오류 |
| 4 | `.referenceNotFound` | refs JSON에 key 없음 |
| 5 | `.alreadyLoaded` | 해당 external reference가 이미 loaded |
| 6 | `.failure` | JSON shape, upstream injection 또는 panic failure |

### Filename context

```c
RhwpExternalImageStatus rhwp_set_file_name_utf8(
    RhwpHandle *handle,
    const uint8_t *name,
    uintptr_t name_len
);
```

- `name_len == 0`이면 null pointer를 허용하고 빈 filename context로 설정한다.
- `name_len > 0`이면 non-null UTF-8 buffer가 필요하다.
- upstream `set_file_name`의 page tree cache invalidation을 유지한다.

### External references

```c
char *rhwp_external_image_refs_json(const RhwpHandle *handle);
```

- 성공 시 upstream JSON 배열 문자열, external ref가 없으면 `[]`다.
- 반환 pointer는 Rust-owned이며 `rhwp_free_string`으로 해제한다.
- null handle/panic/CString failure는 null pointer다.

기준 JSON shape:

```json
[
  {
    "key": "binData:1",
    "binDataId": 1,
    "originalPath": "C:\\source\\image.gif",
    "basename": "image.gif",
    "extension": "gif",
    "loaded": false
  }
]
```

Swift decoder는 field 추가를 허용해야 하며 `key`, `binDataId`, `basename`, `loaded`를 필수 계약으로 취급한다. `originalPath`는 resolver가 그대로 열 경로가 아니라 diagnostic/source metadata다.

### Key-based injection

```c
RhwpExternalImageStatus rhwp_inject_external_image_by_key(
    RhwpHandle *handle,
    const uint8_t *key,
    uintptr_t key_len,
    const uint8_t *data,
    uintptr_t data_len,
    const uint8_t *display_path,
    uintptr_t display_path_len
);
```

- key와 data는 non-null/non-empty다.
- display path는 길이 0일 때 null pointer를 허용한다.
- refs JSON preflight로 key 미존재와 already-loaded를 구분한다.
- 성공 시 upstream document가 image bytes를 복사해 소유한다.
- RustBridge는 key/original/display path로 filesystem을 열지 않는다.

## 메모리·수명·호출 순서

### Ownership

| 데이터 | 소유자 | caller 규칙 |
|--------|--------|-------------|
| filename/key/display path 입력 | Swift caller | FFI 호출 동안 pointer/length 유효 |
| injection image bytes | Swift caller, 호출 중 borrowed | `Data.withUnsafeBytes` 범위 안에서 호출 |
| refs JSON 반환 | Rust | Swift 복사 후 `rhwp_free_string` |
| injected image bytes | upstream document | injection 성공 후 document handle 수명에 종속 |
| `rhwp_image_data` 반환 | document-owned | 즉시 `Data`로 복사, 별도 free 금지 |

`rhwp_image_data` pointer를 setter/injection 같은 mutable document 호출을 넘겨 보관하지 않는다.

### #409 권장 호출 순서

1. main document bytes로 `rhwp_open`한다.
2. source filename이 있으면 `rhwp_set_file_name_utf8`를 호출한다.
3. `rhwp_external_image_refs_json`을 조회·복사·해제한다.
4. Swift resolver가 허용한 sibling image bytes만 읽는다.
5. 각 reference를 `rhwp_inject_external_image_by_key`로 주입한다.
6. injection 완료 후 page count, page size, render tree/PNG/image data를 조회한다.

page tree/render 전에 injection해야 cache invalidation 뒤 최신 document 상태를 렌더한다.

## Swift import 결과

generated `Rhwp` module을 실제 Swift compiler로 typecheck한 결과다.

```swift
RhwpExternalImageStatus(rawValue: UInt32) -> RhwpExternalImageStatus

rhwp_set_file_name_utf8:
  (OpaquePointer?, UnsafePointer<UInt8>?, UInt)
    -> RhwpExternalImageStatus

rhwp_external_image_refs_json:
  (OpaquePointer?) -> UnsafeMutablePointer<CChar>?

rhwp_inject_external_image_by_key:
  (OpaquePointer?,
   UnsafePointer<UInt8>?, UInt,
   UnsafePointer<UInt8>?, UInt,
   UnsafePointer<UInt8>?, UInt)
    -> RhwpExternalImageStatus
```

#409 wrapper는 `RhwpExternalImageStatus.rawValue`를 downstream enum으로 매핑하고, 문자열은 UTF-8 bytes와 명시 길이로 전달해야 한다. Empty display path는 nil/0으로 전달할 수 있다.

## Artifact와 provenance

source 기준은 변경하지 않았다.

| 필드 | 값 |
|------|----|
| ref kind | `release-tag` |
| release tag | `v0.7.17` |
| resolved commit | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| enabled features | `native-skia` |

artifact 결과:

| artifact | 이전 | 최종 | 변화 |
|----------|------|------|------|
| universal `librhwp.a` | 202,902,712 bytes | 202,931,144 bytes | +28,432 bytes |
| generated header | 2,059 bytes | 3,310 bytes | +1,251 bytes |
| expected symbol | 12개 | 15개 | +3개 |

- staticlib sha256: `e454ac6b32667c84509d320ce6da7972277a5d97655f3187f19f2f5a9a8a5acd`
- header sha256: `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5`
- architectures: `x86_64 arm64`
- staticlib/xcframework 표시 크기: 각각 194M

## 검증 결과

| 검증 | 결과 | 핵심 근거 |
|------|------|-----------|
| Rust format/check/test | 통과 | unit test 4개, 0 failure |
| Clippy 보강 | 통과 | 기존 raw-pointer lint만 명시 allow, 나머지 `-D warnings` |
| cbindgen header | 통과 | enum 값 0-6, 세 C signature |
| expected/generated symbol | 통과 | 15개 exact match |
| universal staticlib symbol | 통과 | 기존 open/image/close + 신규 세 symbol |
| artifact update/verify | 통과 | `--update-lock`, `--verify-lock` |
| no-AppKit boundary | 통과 | Shared Swift 계층 AppKit/UIKit 없음 |
| HostApp/extension compile/link | 통과 | HostApp, QLExtension, ThumbnailExtension, `-lrhwp` |
| 기본 native render | 통과 | KTX/request/exam_kor non-blank·한글 glyph |
| embedded image render | 통과 | `hwp-img-001.hwp`, 정부/기관 logo 시각 확인 |
| Swift module import | 통과 | enum raw type과 세 function interface type 확인 |
| whitespace | 통과 | `git diff --check` |

주요 render metric:

| fixture | bitmap | textRuns | hangulRuns | nonWhitePixels |
|---------|--------|----------|------------|----------------|
| `KTX.hwp` | 1123x794 | 410 | 76 | 455,061 |
| `request.hwp` | 567x794 | 102 | 36 | 70,188 |
| `exam_kor.hwp` | 1123x1588 | 133 | 86 | 173,981 |
| `hwp-img-001.hwp` | 794x1123 | 66 | 35 | 57,037 |

환경성 실패는 모두 회복 후 동일 gate가 통과했다.

- Skia binary cache와 Sparkle package fetch: sandbox DNS 제한, 네트워크 허용 재실행 성공
- Xcode/xcframework의 CoreSimulatorService 경고: 비치명적, exit 0
- Swift import default module cache: sandbox 밖 cache 접근 실패, `/private/tmp` cache 지정 후 성공
- Debug app LaunchServices: 종료 확인에서 개발 산출물 path 잔존 없음

## Build gate 보정

신규 함수 `rhwp_set_file_name_utf8`의 숫자 `8` 때문에 기존 symbol parser가 이름을 `rhwp_set_file_name_utf`으로 잘랐다. `scripts/build-rust-macos.sh`의 추출 regex를 다음처럼 보정했다.

```diff
-\brhwp_[a-z_]+
+\brhwp_[a-z0-9_]+
```

보정 후 generated/expected symbol set, update-lock, verify-lock이 통과했다. 이는 이번 ABI뿐 아니라 향후 숫자가 들어간 symbol의 provenance gate도 올바르게 만든다.

## #409 Handoff

#409는 다음 구현 단위를 바로 소비할 수 있다.

### Swift model/wrapper

- `RhwpExternalImageReference: Decodable`
  - `key: String`
  - `binDataId: UInt16`
  - `originalPath: String`
  - `basename: String`
  - `extension: String`
  - `loaded: Bool`
- downstream `RhwpExternalImageStatus` enum과 rawValue 0-6 mapping
- `RhwpDocument.setFileName(_:)`
- `RhwpDocument.externalImageReferences()`
- `RhwpDocument.injectExternalImage(key:data:displayPath:)`
- refs JSON pointer copy와 `defer { rhwp_free_string(...) }`
- 모든 input string을 UTF-8 pointer/length로 전달

### Open context와 resolver

- `RhwpDocumentOpenContext`
  - source URL optional
  - display filename optional
  - max external resource bytes
- source URL이 없거나 file URL이 아니면 resolver disabled
- reference의 `basename`만 사용한 source parent sibling lookup
- 빈 이름, `.`, `..`, path separator 포함 이름 reject
- standardized/resolved candidate가 source parent 밖이면 reject
- directory, symlink escape, size cap 초과 reject
- network/URL/Windows absolute/UNC path 해석 금지
- full original path를 user-facing log에 노출하지 않음

### Preview 적용 순서

- `HwpPreviewPDFRenderer.load(fileURL:)`에서 main bytes open
- filename setter
- refs 조회
- resolver와 injection
- 그 뒤 page count/size/render
- resolver 실패는 document render 전체 failure로 올리지 않고 report/diagnostic에 누적

### #409 검증 최소 기준

- source URL 없음: resolver disabled, 기존 render 유지
- external refs 없음: `[]`, 기존 render 유지
- invalid basename/path escape/too large: reject status/report
- valid sibling: injection success 후 `loaded == true`
- page/render 호출이 injection 뒤 실행됨
- refs JSON Rust string 해제와 image bytes caller lifetime 확인
- privacy-safe log

Thumbnail cache는 #411 전까지 resolver를 활성화하지 않는다. CoreGraphics missing/decode placeholder는 #410, exact fixture/full visual regression은 #412, WKWebView 경로는 #413이 소유한다.

## 보류 및 잔여 위험

| 항목 | 현재 상태 | 후속 |
|------|-----------|------|
| `rhwp_image_state_json` | pinned public API가 전체 image state를 제공하지 않아 미구현 | #410 또는 upstream API 확장 검토 |
| external injection 성공 fixture | repository exact fixture 없음 | #409 최소 fixture, #412 정식 suite |
| external missing/decode placeholder | renderer 미구현 | #410 |
| Thumbnail stale cache | external signature 없음 | #411 |
| large image memory/latency | 미측정 | #412 |
| WKWebView external bridge | native ABI와 별도 경로 | #413 |
| safe Rust raw-pointer lint | current C ABI 전체가 safe extern wrapper 정책 | 별도 FFI safety 정리 시 검토 |

## 최종 판단

#391에서 설계한 RustBridge downstream 보정 중 #408 범위는 완료됐다. Upstream `HwpDocument`의 filename/external refs/injection 기능이 이제 macOS Swift에서 호출 가능한 ABI로 노출되고 generated artifact와 provenance gate까지 일치한다.

다만 실제 Quick Look에서 external image가 보이기 위한 작업은 끝나지 않았다. #409가 Swift wrapper와 resolver를 연결해야 하며, renderer placeholder/cache/fixture는 #410-#412에서 각각 완료해야 parent #407의 전체 목표가 충족된다.

## 작업지시자 승인 요청

#408 Stage 1-5와 최종 결과보고서가 완료됐다. 최종 보고 승인 후 `task-final-report` 절차를 호출해 `publish/task408` push와 `devel` 대상 PR 게시를 진행한다.
