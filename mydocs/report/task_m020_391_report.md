# Task #391 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #391 `filename/external image context ABI 조사 및 bridge 설계` |
| 연결 이슈 | #404 upstream 렌더 PR 대표 샘플 diff 측정, #396 visual suite, #387 Skia readiness |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 단계 수 | 5 |
| 작업 브랜치 | `local/task391` |

`edwardkim/rhwp` upstream의 filename context, external image refs, external bytes injection 계약을 조사하고, 알한글 Quick Look/Thumbnail/HostApp native 경로에 필요한 RustBridge C ABI와 Swift/macOS 책임 경계를 설계했다.

최종 판단은 "upstream 개선만으로는 자동 반영되지 않는다"이다. upstream에는 `HwpDocument` 기준 filename 설정, external reference JSON, key-based injection API가 있으나, 현재 다운스트림 RustBridge C ABI는 `rhwp_open(data,len)`, `rhwp_render_tree_json`, `rhwp_image_data(binDataId)`만 노출한다. Swift 모델도 `ImageNode.externalPath`를 decode하지 않고, bytes가 없거나 decode에 실패한 image는 CoreGraphics renderer에서 조용히 생략될 수 있다.

따라서 후속 구현은 `RustBridge additive ABI`와 `Swift resolver/renderer/cache`를 분리해 진행하는 것이 안전하다. Quick Look Preview는 cache 구조 영향이 작으므로 1차 적용 후보이고, Finder Thumbnail은 external resource signature가 cache key에 들어간 뒤 resolver를 켜야 한다. WKWebView bundled `rhwp-studio` 경로는 native ABI 적용과 다른 host bridge 이슈로 분리한다.

제품 Swift/Rust source, `rhwp-core.lock`, sample fixture, build artifact는 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m020_391.md` | #391 수행계획서 |
| `mydocs/plans/task_m020_391_impl.md` | Stage 1-5 구현계획서 |
| `mydocs/working/task_m020_391_stage1.md` | current ABI와 image data 계약 inventory |
| `mydocs/working/task_m020_391_stage2.md` | upstream external resource contract 조사 |
| `mydocs/working/task_m020_391_stage3.md` | external image ABI 후보 설계 |
| `mydocs/working/task_m020_391_stage4.md` | macOS external resource 책임 경계 설계 |
| `mydocs/report/task_m020_391_report.md` | 본 최종 보고서와 후속 이슈 초안 |
| `mydocs/orders/20260710.md` | #391 오늘할일 상태 갱신 |

최종 diff는 문서 변경만 포함한다.

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| 계획 | `4c85fa3`, `0fa15da` | 수행계획서, 오늘할일, 구현계획서 작성 |
| Stage 1 | `e3afbba` | current ABI와 Swift image render 계약 inventory |
| Stage 2 | `3421a32` | upstream filename/external image refs/injection 계약 조사 |
| Stage 3 | `daa245f` | RustBridge additive C ABI와 Swift wrapper 후보 설계 |
| Stage 4 | `3fa98dd` | Quick Look/Thumbnail/HostApp 책임 경계와 resolver/cache 정책 설계 |
| Stage 5 | 이번 커밋 | 최종 보고서 작성과 후속 이슈 초안 정리 |

## 핵심 결론

| 질문 | 최종 판단 |
|------|-----------|
| upstream parser/renderer가 external image를 더 잘 처리하면 다운스트림도 자동 반영되는가 | current ABI에서는 제한적이다. embedded `binDataId -> bytes`가 기존 shape로 들어오는 경우만 자동 반영 후보이며, external refs/injection은 C ABI에 없다. |
| filename context가 필요한가 | 필요하다. upstream `HwpDocument`는 filename context와 external refs cache invalidation을 제공하지만, 현재 `rhwp_open(data,len)` 호출에는 filename이 들어가지 않는다. |
| external image bytes는 누가 찾고 읽어야 하는가 | Swift/macOS shell이 source URL 권한, path policy, bytes read, cache signature를 소유해야 한다. RustBridge/core가 product path에서 filesystem을 직접 읽지 않는다. |
| Swift renderer 보강이 필요한가 | 필요하다. `ImageNode.externalPath` additive decode, missing external placeholder, decode failure diagnostic이 필요하다. |
| Thumbnail에 바로 resolver를 켜도 되는가 | 안 된다. current cache key에 external file state가 없으므로 stale thumbnail 위험이 있다. prepared request 또는 external refs cache bypass가 선행되어야 한다. |
| WKWebView `rhwp-studio`에도 같은 방식으로 적용되는가 | 아니다. bundled studio WASM에는 upstream API가 있지만 macOS host가 external bytes를 전달하는 JS bridge가 없으므로 별도 이슈가 필요하다. |

## Stage 1 current ABI inventory

확인한 current downstream 계약은 다음과 같다.

| 영역 | 현 상태 | 영향 |
|------|---------|------|
| Swift open API | `RhwpDocument(data:filename:)` | filename은 Swift error/title/log context로만 쓰이고 FFI에는 전달되지 않는다. |
| RustBridge handle | `DocumentCore` opaque handle | upstream `wasm_api::HwpDocument`의 filename/external refs/injection API를 직접 쓸 수 없다. |
| C ABI | `rhwp_open(data,len)` | source filename, base directory, external resource context가 없다. |
| image data lookup | `rhwp_image_data(handle, binDataId)` | bytes nil 이유가 embedded missing인지 external missing인지 decode failure인지 구분되지 않는다. |
| Swift render tree | `ImageNode.binDataId` 중심 | `externalPath` 필드가 모델에 없다. |
| CoreGraphics renderer | bytes nil/decode fail 시 image 생략 가능 | visual diff나 diagnostic 없이는 누락이 조용히 지나갈 수 있다. |
| Quick Look/Thumbnail | main file URL에서 bytes만 읽어 document open | sibling/external image lookup과 injection 지점이 없다. |
| Thumbnail cache | main file path/mtime/size/pixel/render signature | external file 변경을 cache key가 반영하지 못한다. |

## Stage 2 upstream contract

현재 lock 기준은 `rhwp v0.7.17`, commit `03351190ec35436e58cbfee0aa9278a8fdc04a59`, feature `native-skia`다.

external resource와 관련해 확인한 upstream 흐름은 다음과 같다.

| upstream PR/흐름 | 내용 | 다운스트림 의미 |
|------------------|------|-----------------|
| #1174 | filename context와 cache invalidation | C ABI에 filename setter 또는 open context가 필요하다. |
| #1175 | external refs JSON: `key`, `binDataId`, `originalPath`, `basename`, `extension`, `loaded` | Swift resolver가 읽을 reference list의 기준 shape다. |
| #1185 | `injectExternalImageByKey`와 missing/injected diagnostic | Swift가 bytes를 읽은 뒤 core state에 명시 주입해야 한다. |
| #1913 | external BinData Link roundtrip preservation | external image 문서가 더 정확히 보존될 가능성이 높아진다. 다운스트림 ABI 없이는 render에는 반영되지 않는다. |
| #1917/#1924 | large BinData limit 확대 | large image fixture와 size cap 정책을 downstream에서 별도 검증해야 한다. |
| #1927 | BinData load failure placeholder pic preservation | missing placeholder와 diagnostic을 Swift renderer가 표현할 준비가 필요하다. |
| #1930 | `imgDim` preservation | image geometry가 더 정확해질 수 있으나 renderer replay 정합성 검증이 필요하다. |
| #2040 | BinData storage id max+1, position과 storage id 분리 | `binDataId`를 storage id로 오해하지 말고 render lookup id로 취급해야 한다. |

중요한 설계 포인트는 upstream의 public API가 `wasm_api::HwpDocument`에 이미 모여 있다는 점이다. current RustBridge가 `DocumentCore`를 handle로 들고 있어 이 surface를 노출하지 못하는 것이 downstream gap이다.

## Stage 3 ABI 설계 결론

권장 후보는 `RhwpHandle` 내부를 `DocumentCore`에서 `rhwp::wasm_api::HwpDocument`로 전환하고, additive C ABI를 노출하는 방식이다.

후보 C ABI:

```c
RhwpExternalImageStatus rhwp_set_file_name_utf8(
    RhwpHandle *handle,
    const uint8_t *name,
    uintptr_t name_len
);

char *rhwp_external_image_refs_json(RhwpHandle *handle);

RhwpExternalImageStatus rhwp_inject_external_image_by_key(
    RhwpHandle *handle,
    const uint8_t *key,
    uintptr_t key_len,
    const uint8_t *data,
    uintptr_t data_len,
    const uint8_t *display_path,
    uintptr_t display_path_len
);

char *rhwp_image_state_json(RhwpHandle *handle, uint32_t bin_data_id);
```

보조 후보:

| 후보 | 판단 |
|------|------|
| `rhwp_open_with_context` | filename 전달에는 유용하지만 external bytes injection을 대체하지 못하므로 보조 API다. |
| `rhwp_populate_external_images_from_dir` 직접 노출 | core가 filesystem을 읽게 되므로 macOS sandbox, privacy, cache 책임 경계와 맞지 않아 제품 기본 경로에서 제외한다. |
| `DocumentCore` public API upstream 요청 | `HwpDocument` handle 전환이 어렵다는 compile spike 결과가 있을 때만 후순위로 검토한다. |

Swift wrapper 후보:

- `RhwpExternalImageReference`
- `RhwpExternalImageStatus`
- `RhwpDocumentOpenContext`
- `RhwpExternalResourceResolution`
- `RhwpExternalResourceReport`
- `ImageNode.externalPath` additive decode

상태 구분은 Rust/core가 `embedded`, `external`, `missing`, `injected`를 보고하고, Swift renderer가 `decodeFailed`를 별도로 보고하는 구조가 적절하다.

## Stage 4 macOS 책임 경계

최종 책임 분리는 다음과 같이 고정한다.

| 계층 | 책임 |
|------|------|
| Swift/macOS shell | source URL 권한, external path policy, sibling candidate resolution, bytes read, cache signature, privacy-safe logging |
| RustBridge/core | filename context, external refs enumeration, explicit bytes injection, render tree/image data export |
| Swift renderer | injected document state replay, `externalPath` placeholder, decode failure diagnostic |
| Thumbnail cache | external resource signature 포함 또는 external refs 문서 cache bypass |
| WKWebView host bridge | bundled studio에 external bytes를 전달하는 별도 JS/native bridge |

v1 path resolver 정책:

1. `sourceURL`이 없으면 resolver disabled.
2. file URL이 아니면 resolver disabled.
3. `reference.basename` 또는 `originalPath`에서 basename만 추출한다.
4. 빈 이름, `.`, `..`, path separator 포함 이름은 reject한다.
5. 후보는 source document parent directory의 sibling file 하나로 제한한다.
6. standardized/resolved path가 source parent 밖으로 나가면 reject한다.
7. directory와 size cap 초과 file은 reject한다.
8. read 성공 bytes만 `rhwp_inject_external_image_by_key`로 주입한다.

명시 금지:

- `originalPath` absolute path를 그대로 열지 않는다.
- Windows drive path, UNC/network path, URL string을 접근 경로로 해석하지 않는다.
- symlink traversal로 source parent 밖 파일을 읽지 않는다.
- renderer나 RustBridge가 filesystem에 직접 접근하지 않는다.

## 기존 다운스트림 보정 후보와의 연결

#404에서 정리한 upstream 렌더 후보 축 중 #391은 `external/large image data` 축을 구체화한 작업이다. 나머지 축은 관련 맥락으로 유지하되 #391 구현 범위에는 넣지 않는다.

| 후보 축 | 관련 upstream/관찰 | #391과의 관계 |
|---------|--------------------|---------------|
| RawSvg/차트 | upstream #1890 계열. Swift `RawSvg`는 단일 raster image data URL 중심이고 일반 SVG vector는 fallback risk가 있다. | external image ABI와 별개다. chart가 external image bytes를 참조하는 exact fixture가 확인될 때만 resolver와 함께 측정한다. |
| HWP3 group/shape/transform | upstream #1905 계열. Swift `GroupNode`에는 group transform 필드가 없고 renderer도 group-level transform을 적용하지 않는다. | external image ABI와 별개다. image bbox/clip과 겹칠 수 있으므로 visual suite에서만 함께 관찰한다. |
| 미주 배치/구분선 | upstream #1875 계열. core가 Line/TextRun 좌표로 내보내면 자동 반영 후보지만 order/clip 확인이 필요하다. | external image ABI 범위 밖이다. diagnostic/report 구조만 공유 가능하다. |
| 그림 wrap/TAC 높이/글리프 가드 | upstream #1881 계열. layout 좌표는 자동 반영 후보지만 CoreText/clip/table cell slack 차이가 남을 수 있다. | image fixture에서 clip과 external missing이 동시에 나타날 수 있어 #396 visual suite에서 교차 검증한다. |
| PDF font option/수식 SVG font | upstream #1895 계열. 알한글 Quick Look/Thumbnail에는 직접 반영되지 않지만 equation SVG parser와 font fallback 검증은 필요하다. | external image ABI와 별개다. Swift renderer diagnostic 방식만 재사용 가능하다. |

## 후속 이슈 초안

아래 초안은 즉시 등록하지 않는다. 작업지시자 승인 후 GitHub Issue로 분리 등록한다.

### 1. RustBridge external image context C ABI 구현

목적:

- upstream `HwpDocument`의 filename context, external refs, key-based injection을 macOS Swift에서 호출 가능한 C ABI로 노출한다.

배경:

- current `RhwpHandle`은 `DocumentCore`를 들고 있어 `setFileName`, `getExternalImageRefs`, `injectExternalImageByKey` 계열 upstream API를 노출하지 못한다.
- #1913, #1927 등 upstream external BinData preservation 개선은 이 ABI 없이는 Quick Look/Thumbnail native render에 충분히 반영되지 않는다.

범위:

- `RhwpHandle` 내부 타입을 `HwpDocument`로 전환하는 compile spike와 regression 확인
- `rhwp_set_file_name_utf8`
- `rhwp_external_image_refs_json`
- `rhwp_inject_external_image_by_key`
- optional `rhwp_image_state_json`
- generated C header와 `rhwp-ffi-symbols.txt` 갱신
- Swift wrapper가 소비할 status enum과 memory ownership 문서화

검증:

- RustBridge build/test
- C header generation
- symbol list diff
- Swift package/app compile
- embedded image 기존 fixture regression 없음

제외:

- Swift path resolver 구현
- Quick Look/Thumbnail UI 변경
- upstream API 변경 요청

### 2. Swift external image wrapper/resolver와 Quick Look Preview 적용

목적:

- Quick Look Preview에서 source document sibling external image를 안전하게 찾아 RustBridge에 injection한다.

배경:

- Preview는 `QLFilePreviewRequest.fileURL`을 갖고 있고, document open 직후 page count/size/render 전에 resolver를 실행할 수 있어 1차 적용 surface로 적합하다.

범위:

- `RhwpDocumentOpenContext`
- `RhwpExternalImageReference` JSON decode
- `RhwpExternalResourceResolution`과 report summary
- v1 basename-only sibling resolver
- `RhwpDocument(data:context:)` 또는 동등한 open helper
- `HwpPreviewPDFRenderer.load(fileURL:)` 적용
- permission denied, missing, invalid basename, too large diagnostic

검증:

- external image fixture Preview smoke
- source URL 없음 또는 dropped bytes resolver disabled
- privacy-safe log 확인
- page count/page size/render가 injection 후 호출되는지 확인

제외:

- Thumbnail cache 변경
- HostApp WKWebView bridge
- directory recursive lookup

### 3. CoreGraphics `ImageNode.externalPath`와 missing/decode diagnostic 보강

목적:

- render tree에 external image metadata가 남는 경우 Swift renderer가 missing external image와 decode failure를 구분해 표현한다.

배경:

- current Swift `ImageNode`는 `binDataId` 중심이고 `externalPath`를 decode하지 않는다.
- `rhwp_image_data`가 nil이면 embedded missing과 external missing을 구분할 수 없고, decode 실패도 render 결과에서 조용히 누락될 수 있다.

범위:

- `ImageNode.externalPath` additive decode
- bytes nil + `externalPath != nil` placeholder
- bytes 있음 + decode failure diagnostic
- user-facing placeholder에서 full original path 숨김
- render diagnostics에 external missing/decode failed count 추가

검증:

- embedded image 기존 fixture regression 없음
- missing external fixture placeholder 확인
- decode failure fixture가 render 전체 실패로 올라가지 않는지 확인
- visual suite metric에 non-white/placeholder sanity 추가

제외:

- full SVG engine 도입
- Skia placeholder rendering 변경

### 4. Thumbnail external resource cache signature와 prepared request 적용

목적:

- Finder Thumbnail에서 external resource 변경이 stale cache로 남지 않도록 cache key와 render flow를 조정한다.

배경:

- current `HwpThumbnailCacheKey`는 main file path/mtime/size/pixel/render signature만 포함한다.
- external resolver를 이 상태에서 켜면 sibling image 변경 후에도 오래된 thumbnail이 재사용될 수 있다.

범위:

- document open + external refs enumeration 이후 cache lookup하는 prepared request flow 검토
- `RhwpExternalResourceCacheSignature`
- decision, basename, file size, mtime 기반 v1 signature
- external refs 문서 cache bypass fallback 정책
- cache log/diagnostic에 external signature 요약 추가

검증:

- external file mtime/size 변경 시 cache miss
- external refs 없는 문서는 기존 cache behavior 유지
- missing/rejected 상태도 cache key에 반영
- Thumbnail smoke 8회 request 안정성 유지

제외:

- byte hash 필수화
- directory mtime broad key
- recursive lookup

### 5. external/large image fixture suite와 visual regression 측정

목적:

- upstream external/large image 개선이 알한글 native render에 실제로 반영되는지 fixture 기반으로 측정한다.

배경:

- #404에서 external BinData Link, large BinData, placeholder exact fixture는 미측정으로 남았다.
- #1913, #1917/#1924, #1927, #1930, #2040 변화는 ABI 구현 전후 regression suite가 필요하다.

범위:

- external BinData Link exact fixture 확보
- large BinData fixture size cap 정책
- missing placeholder fixture
- sparse/storage id와 render `binDataId` 분리 fixture
- CoreGraphics/Skia/SVG render-debug 비교
- Quick Look/Thumbnail smoke 편입

검증:

- injected/missing 상태별 visual artifact 생성
- `binDataId`를 storage id로 오해하지 않는 lookup 검증
- large image memory/latency smoke
- #396 visual suite에 metric 연결

제외:

- fixture 라이선스/개인정보 확인 전 repository 편입
- upstream sample 무조건 vendoring

### 6. HostApp WKWebView external image bridge 설계

목적:

- bundled `rhwp-studio` WASM 경로에서도 external refs를 native host permission model과 연결할 수 있는지 설계한다.

배경:

- upstream studio JS API에는 filename/external refs/injection이 있으나, current HostApp document scheme은 main document bytes만 제공하고 resource scheme은 bundled assets만 제공한다.
- native Quick Look/Thumbnail ABI와 WKWebView JS bridge는 적용 지점이 다르다.

범위:

- WKScriptMessageHandler 또는 custom scheme 기반 external refs request 설계
- security-scoped URL 보유 문서와 dropped bytes 문서 분리
- native resolver report를 JS에 전달하는 shape
- full path privacy와 user-facing permission UX

검증:

- opened file 경로에서 sibling external image injection
- dropped bytes resolver disabled
- no network/no arbitrary file access 확인

제외:

- #391 1차 native Quick Look/Thumbnail 구현 범위
- bundled `rhwp-studio` 대규모 수정

## 구현 권장 순서

1. RustBridge additive ABI 구현 spike
2. Swift wrapper와 `RhwpDocumentOpenContext` 추가
3. Quick Look Preview resolver 적용
4. CoreGraphics `externalPath` placeholder/diagnostic 적용
5. Thumbnail prepared request 또는 cache bypass 선택 후 cache signature 반영
6. HostApp native PDF export에 source URL context 전달
7. external/large fixture suite와 visual regression 측정
8. WKWebView external image bridge 별도 설계

Quick Look Preview를 먼저 잡는 이유는 cache correctness 부담이 작고, single opened document에 injected state를 유지하기 쉽기 때문이다. Thumbnail은 cache key 설계 없이는 제품 품질을 해칠 수 있으므로 별도 단계가 필요하다.

## 잔여 위험과 처리

| 항목 | 상태 | 처리 |
|------|------|------|
| `HwpDocument` handle 전환 compile risk | 잔여 | RustBridge ABI 구현 이슈에서 spike로 먼저 검증 |
| upstream API shape drift | 잔여 | `rhwp-core.lock` 갱신 시 external refs JSON contract 재검증 |
| Thumbnail stale cache | 중요한 잔여 | resolver 적용 전 external cache signature 선행 |
| path privacy/logging | 중요한 잔여 | full original path는 user-facing surface와 public log에서 숨김 |
| sandbox permission variation | 잔여 | Quick Look/Thumbnail/HostApp surface별 smoke 필요 |
| exact external fixture 부재 | 잔여 | fixture suite 이슈에서 확보 후 측정 |
| large image memory/latency | 잔여 | size cap과 byte hash 비용을 별도 측정 |
| `binDataId` storage id 오해 | 잔여 | #2040 반영 fixture로 render lookup id 기준 검증 |
| WKWebView 적용 범위 | 후속 | native ABI와 별도 bridge 이슈로 분리 |

## 지금 하지 않을 작업

| 항목 | 이유 |
|------|------|
| RustBridge ABI 구현 | #391은 조사/설계 이슈다. 구현은 후속 이슈로 분리한다. |
| Swift renderer 수정 | externalPath shape와 ABI가 확정된 뒤 적용한다. |
| Thumbnail resolver 즉시 적용 | current cache key가 external file state를 반영하지 못한다. |
| HostApp WKWebView bridge 구현 | native Quick Look/Thumbnail path와 적용 방식이 달라 별도 설계가 필요하다. |
| Skia default 전환 | #387/#390/#404 판단에 따라 CoreGraphics default + Skia opt-in diagnostic 상태를 유지한다. |
| upstream exact fixture 편입 | 라이선스, 크기, 개인정보, 재현성 검토와 작업지시자 승인이 먼저 필요하다. |

## 검증 결과

| 명령 | 결과 |
|------|------|
| current ABI/source `rg` 조사 | 통과. Swift open path, RustBridge handle, image lookup, renderer nil 처리, Thumbnail cache key 확인 |
| upstream PR/API `gh pr view`와 source 조사 | 통과. #1174/#1175/#1185, #1913/#1917/#1924/#1927/#1930/#2040 연결 확인 |
| `gh issue view` 계열 | 통과. #387/#390/#404/#396/#392/#389 연결 맥락 확인 |
| Stage 3 ABI 후보 문서 검토 | 통과. `HwpDocument` handle 전환 + additive C ABI를 권장안으로 확정 |
| Stage 4 macOS surface inventory | 통과. Quick Look, Thumbnail, HostApp WKWebView/native export 책임 경계 확인 |
| `rg -n "#391\|filename\|external\|BinData\|C ABI\|Swift wrapper\|Quick Look\|Thumbnail\|후속\|residual\|#387\|#390\|#404" ...` | 통과. 최종 보고서와 오늘할일에 핵심 키워드/연결 이슈 반영 확인 |
| `rg -n "RustBridge\|HwpDocument\|externalPath\|cache signature\|prepared request\|WKWebView\|fixture\|resolver\|placeholder\|decodeFailed\|binDataId" ...` | 통과. ABI, Swift wrapper, renderer, cache, fixture 후속 항목 반영 확인 |
| `git diff --check` | 통과 |

## PR 게시 준비 메모

권장 PR 제목:

```text
Task #391: filename/external image context ABI 조사와 bridge 설계
```

권장 리뷰 포인트:

- upstream external image 개선이 current downstream ABI에 자동 반영되지 않는다는 판단이 타당한지
- `HwpDocument` handle 전환 + additive C ABI를 1차 후보로 두는 설계가 적절한지
- Swift/macOS shell이 path policy와 bytes read를 소유하고 RustBridge/core는 명시 injection만 담당하는 책임 경계가 맞는지
- Quick Look Preview를 1차 적용, Thumbnail은 cache signature 선행으로 분리하는 순서가 안전한지
- WKWebView bundled `rhwp-studio` bridge를 native ABI 적용과 별도 이슈로 분리하는 정렬이 적절한지
- 후속 이슈 초안 6개가 구현 단위로 과도하게 크거나 작지 않은지

PR 게시 전 상태:

- Stage 1-4 조사/설계 보고서 작성 완료
- Stage 5 최종 보고서 작성 완료
- 제품 코드 변경 없음
- 후속 구현 이슈는 초안만 작성했고 등록하지 않음
- PR 게시에는 작업지시자 승인 후 `publish/task391` 브랜치와 PR 생성 단계가 필요

## 작업지시자 승인 요청

Task #391의 filename/external image context ABI 조사와 bridge 설계를 완료했다. PR 게시 단계 진입 여부와 후속 구현 이슈 등록 여부를 승인해 달라.
