# Task M020 #447 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#447 rhwp v0.8.2 반영 후 RustBridge image data 수명 회귀와 Thumbnail 크래시 수정](https://github.com/postmelee/alhangeul-macos/issues/447) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task447` |
| 기준 통합 SHA | `1b1213db5a0bd75638f54bf03d49fbf4cb63edcc` |
| upstream core/studio | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| 차단 대상 | [#441 v0.1.9 public release 준비와 배포 실행](https://github.com/postmelee/alhangeul-macos/issues/441) |
| 단계 | 수행계획, 구현계획, Stage 1~4, 최종 보고 |

rhwp v0.8.2에서 `get_bin_data()`가 owned `Vec<u8>`를 반환하도록 바뀐 뒤
RustBridge가 함수 종료와 함께 해제되는 임시 bytes의 pointer를 Swift에 넘기던
use-after-free를 수정했다. 기존 `rhwp_image_data` symbol을 caller-owned
allocation 계약으로 전환하고 Swift가 `Data` 복사 직후
`rhwp_free_bytes(pointer, length)`로 해제하도록 source, generated header와
문서를 일치시켰다.

핵심 결론:

- `rhwp_image_data`는 non-empty bytes를 독립 `Box<[u8]>` allocation으로
  넘기며 explicit free 전까지 document handle 수명과 독립적으로 유효하다.
- Swift `imageData`와 `imageDataLength`는 성공 pointer를 모든 경로에서
  정확히 한 번 해제한다.
- 공개 C ABI symbol은 기존 15개를 유지하고 새 symbol을 추가하지 않았다.
- Rust 7개와 Swift 27개 test, 세 제품 target, representative renderer와
  image visual harness가 통과했다.
- v0.1.9 candidate-only provider로 HWP/HWPX thumbnail 20건을 반복 생성했고
  Stage 4 baseline 이후 신규 알한글 Preview/Thumbnail crash가 없다.
- 사용자 설치본과 active provider를 원래 v0.1.8
  `/Applications/Alhangeul.app` 상태로 복원했고 development registration은
  0건이다.
- Developer ID signed/notarized candidate와 public publish는 실행하지 않았다.
  Task #447 merge SHA를 포함한 새 후보 생성은 #441 이슈에 인계한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `RustBridge/src/lib.rs` | `rhwp_image_data`를 caller-owned mutable allocation으로 전환하고 null/empty/panic 계약과 allocator-pressure·handle-close Rust test 추가 |
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | image bytes copy와 length query가 성공 pointer를 exact length로 즉시 free하도록 수정 |
| `Tests/ExternalImageTests/RhwpDocumentExternalImageBridgeTests.swift` | 반복 query, allocator pressure, document deinit 뒤 copied `Data`와 invalid id test 추가 |
| `RustBridge/README.md` | rhwp v0.8.2 provenance와 image allocation copy/free 계약 반영 |
| `mydocs/tech/project_architecture.md` | stale borrowed document buffer 설명을 caller-owned allocation 경계로 갱신 |
| `rhwp-core.lock` | 같은 v0.8.2 source로 재생성한 archive/header hash, size와 build 시각 반영 |
| `mydocs/plans/task_m020_447.md` | use-after-free 증거, 범위, 5단계 계획과 release 인계 경계 기록 |
| `mydocs/plans/task_m020_447_impl.md` | owned-buffer 선택, ABI·Swift 계약, test matrix와 단계별 gate 확정 |
| `mydocs/working/task_m020_447_stage1.md` | upstream API, crash stack과 구현 대안 조사 기록 |
| `mydocs/working/task_m020_447_stage2.md` | RustBridge owned allocation 구현과 Rust lifetime test 결과 기록 |
| `mydocs/working/task_m020_447_stage3.md` | Swift free, generated artifact와 ownership 문서 정합성 기록 |
| `mydocs/working/task_m020_447_stage4.md` | 세 제품 target, exact-provider Finder 반복 smoke와 복원 결과 기록 |
| `mydocs/report/task_m020_447_report.md` | 전체 수용 기준, 정량 비교, #441 signed candidate 재개 조건 기록 |
| `mydocs/orders/20260729.md` | #447 진행 단계와 완료 시각 반영 |

제품 동작 변경은 RustBridge FFI 한 함수와 Swift wrapper 두 함수로 제한된다.
upstream `rhwp`, Cargo dependency, bundled `rhwp-studio`, `project.yml`, Xcode
target 구성, app version/build와 release workflow에는 Task #447 diff가 없다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행계획 | `9e92331` | #447 원인, 범위, branch와 오늘할일 등록 |
| Stage 1 | `a148dd2` | owned-buffer/free를 단일 계약으로 선택하고 구현계획 확정 |
| Stage 2 | `ae74a2a` | 임시 Vec pointer escape 제거, Rust lifetime test 7/7 통과 |
| Stage 3 | `2224542` | Swift exact free, generated artifact와 문서 정합화, Swift 27/27 통과 |
| Stage 4 | `ccc87a1` | 세 target, image renderer와 candidate-only Thumbnail 20/20 검증 |
| 최종 보고 | 이번 커밋 | 전체 수용 기준, PR 범위와 #441 release handoff 정리 |

## Ownership 계약과 설계 판단

### 변경 전

```text
core Option<Vec<u8>>
→ local Vec.as_ptr()
→ Rust 함수 종료와 Vec drop
→ Swift Data(bytes:count:)가 해제된 pointer를 복사
```

v0.1.9 build 15 crash 두 건은 `_platform_memmove → Data.InlineSlice →
RhwpDocument.imageData → CGTreeRenderer.renderImage`에서 발생했다. source의
drop/copy 순서와 crash stack이 같은 use-after-free 경계를 가리킨다.

### 변경 후

```text
core Option<Vec<u8>>
→ Vec.into_boxed_slice()
→ pointer/length ownership을 caller에게 전달
→ Swift Data 독립 복사
→ defer rhwp_free_bytes(pointer, length)
```

성공 계약:

1. non-empty bytes만 caller-owned allocation으로 반환한다.
2. pointer는 `rhwp_free_bytes` 전까지 유효하고 document handle과 독립이다.
3. Swift caller는 반환받은 동일 pointer와 exact length를 정확히 한 번 free한다.
4. Swift가 반환하는 `Data`는 Rust allocation과 document 수명에서 독립적이다.

실패 계약:

- null `out_len`은 null pointer를 반환한다.
- non-null `out_len`은 query 시작 시 0으로 초기화한다.
- null handle, id 0, missing id, empty bytes와 panic은 null/0으로 정규화한다.

handle-owned raw-byte cache는 decoded `CGImage` cache와 image 원본을 문서
종료까지 중복 보유하고 upstream lazy BinData의 메모리 절감 의도와 충돌한다.
기존 `rhwp_free_bytes`를 재사용하는 caller-owned 계약은 Swift 복사 직후
원본 allocation을 회수하므로 별도 cache와 새 FFI symbol을 만들지 않는다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| image pointer lifetime | 함수 종료 시 임시 Vec와 함께 해제 | explicit `rhwp_free_bytes` 전까지 유효 |
| document handle 의존 | 실제로는 유효 수명 보장 없음 | allocation이 handle close와 독립 |
| RustBridge `lib.rs` | 649줄 | 748줄 |
| Swift `RhwpDocument.swift` | 409줄 | 421줄 |
| Swift bridge test file | 138줄 | 197줄 |
| RustBridge 전체 test | 4개 | 7개 |
| Swift `ExternalImageTests` | 24개 | 27개 |
| 공개 FFI symbol | 15개 | 15개, byte-identical |
| generated C 반환형 | `const uint8_t *` | `uint8_t *` |
| generated header | 3,310 bytes / `c4cba072…` | 3,242 bytes / `5dab4c02…` |
| universal archive | 212,505,600 bytes / `b35e9352…` | 212,514,840 bytes / `5083f2a0…` |
| candidate 반복 thumbnail | crash blocker 2건 | 4문서 × 5회, 20/20 PASS |
| Stage 4 이후 app-extension crash | 기준 crash 2건 | 신규 0건 |

최종 보고서 작성 전 `origin/devel..ccc87a1` 범위는 13개 파일,
`+1687 / -42`다. 이 중 실제 source·test·contract 6개 파일은
`+212 / -41`이며 나머지는 계획·단계 검증 기록이다.

## 검증 결과

### 최종 통합 검증

최종 PR head 후보에서 통합 검증을 다시 실행했다.

| 검증 | 결과 | 핵심 출력 |
|------|------|-----------|
| `cargo fmt --check` | OK | 출력 없음 |
| `cargo check --locked` | OK | RustBridge와 rhwp v0.8.2 check 완료 |
| `cargo test --locked` | OK | 7 passed, 0 failed |
| `build-rust-macos.sh --verify-lock` | OK | archive/header/XCFramework와 lock 일치 |
| core build info | OK | tag, commit, features와 lock 일치 |
| FFI symbol diff | OK | 15개, expected/generated SHA-256 동일 |
| no-AppKit boundary | OK | shared Swift AppKit/UIKit 의존 없음 |
| `xcodegen generate` | OK | tracked project drift 없음 |
| `ExternalImageTests` | OK | 27 passed, 0 failed, 0 unexpected |
| HostApp Debug build | OK | `BUILD SUCCEEDED` |
| QLExtension Debug build | OK | `BUILD SUCCEEDED` |
| ThumbnailExtension Debug build | OK | `BUILD SUCCEEDED` |
| representative render | OK | KTX, request, exam_kor 통과 |
| image visual harness | OK | HWP 3종, HWPX 1종 모두 OK |
| registration hygiene | OK | active `/Applications`, development registration 0건 |
| `git diff --check` | OK | whitespace 오류 없음 |

build가 Sparkle embedded `Updater.app`을 LaunchServices에 등록한 세 경로는
app/appex 단위 표준 cleanup과 exact Updater path unregister로 제거했다.
Quick Look cache를 reset한 뒤 active Preview/Thumbnail provider는 다시
`/Applications/Alhangeul.app` v0.1.8만 남았고 사용자 앱도 기존
v0.1.8 build 14/CDHash로 유지된다.

### 수용 기준

| 수용 기준 | 판정 | 근거 |
|-----------|------|------|
| image pointer가 명시 수명 동안 유효 | OK | allocator pressure와 handle close 뒤 Rust bytes 동일 |
| 반복 query가 독립 allocation을 제공 | OK | 두 allocation 동시 유지와 한쪽 free 뒤 bytes 동일 |
| Swift copy/free 계약 | OK | 128회 pressure, document deinit, invalid id test 통과 |
| 공개 ABI 호환 경계 | OK | symbol 15개 유지, header/caller 같은 build로 갱신 |
| App/Preview/Thumbnail build | OK | 세 target 모두 Debug compile/link 통과 |
| image-heavy renderer | OK | HWP 3종과 HWPX 1종 visual harness OK |
| exact candidate Thumbnail | OK | candidate-only provider path, 20/20 output과 안정 hash |
| 신규 Thumbnail crash 없음 | OK | Stage 4 baseline 이후 알한글 extension report 0건 |
| 설치본/provider 복원 | OK | 사용자 v0.1.8과 `/Applications` provider 복원 |
| signed/notarized 최종 candidate | #441 후속 gate | merge SHA를 포함한 새 후보가 필요하므로 release owner 절차로 인계 |

Issue 초기 완료 기준의 signed candidate smoke는 Task #447 merge 전
artifact로 완료 처리하지 않는다. 승인된 구현계획은 #447 작업에서 local Release
package와 exact-provider 회귀를 통과시키고, fix merge SHA가 생긴 뒤 #441
이슈에서 Developer ID signed/notarized candidate를 새로 생성하도록 범위를
구체화했다.

## Finder 검증과 Preview CLI 진단

HEAD `2224542` 기준 로컬 v0.1.9 build 15 ad-hoc package는 deep codesign,
arm64+x86_64 app/appex와 표준 HWP/HWPX Finder smoke를 통과했다.
candidate-only 상태에서 active path는 다음과 같았다.

```text
/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

`복학원서.hwp`, `hwp-img-001.hwp`, `img-start-001.hwp`,
`hwpx-01.hwpx`를 cache reset과 함께 다섯 번씩 생성했다. 총 20개 output이
생성됐고 같은 문서의 PNG SHA-256은 매회 동일했다.

출력형 Preview 진단 `qlmanage -p -x -o`는 candidate에서 Apple
`ExtensionFoundation`의 nil dictionary key 예외로 종료됐다. 기존 Developer
ID v0.1.8을 단독 provider로 바꾼 비교 실행도 같은 `qlmanage` process,
같은 stack과 exit 134를 재현했다. 알한글 provider code 진입 전 Apple tool
경로이므로 Task #447 신규 회귀로 판정하지 않았지만, #441 signed candidate에서
Finder Space 입력의 실제 Preview UI를 수동으로 다시 확인한다.

## #441 Release Operations 인계

Task #447 PR merge만으로 v0.1.9 public publish가 승인되는 것은 아니다.
#441 이슈에서 다음 순서를 지킨다.

1. Task #447 PR merge commit을 포함한 최신 `devel`을 candidate 기준으로
   확정한다.
2. 기존 signed draft workflow run `30432036513`, merge 전 v0.1.9 DMG,
   Task #447 로컬 ad-hoc app/zip을 재사용하지 않는다.
3. 새 candidate SHA로 Release Rehearsal과 Developer ID signed/notarized
   draft DMG를 다시 생성한다.
4. app과 Preview/Thumbnail의 `0.1.9 (15)`, universal slice, signature,
   notarization과 Gatekeeper를 확인한다.
5. image-heavy HWP 3종과 HWPX 1종을 실제 signed Thumbnail provider에서
   반복 표시하고 신규 `AlhangeulThumbnail` crash가 없는지 확인한다.
6. Finder Space Preview, 앱 HWP/HWPX open, bundled editor repaint와
   저장·공유·인쇄/PDF 시작 경로를 다시 확인한다.
7. 작업지시자의 #441 승인 gate 전에는 GitHub Release, Pages/Sparkle,
   Homebrew와 official stable publish를 실행하지 않는다.

Task #447 이슈의 PR head와 merge SHA, CI 결과는 PR 생성·merge 뒤 #441 이슈에
추가 기록한다.

## 본문 변경 정도 / 본문 무손실 여부

- upstream `edwardkim/rhwp` source, release tag, resolved commit과
  `native-skia` feature는 변경하지 않았다.
- bundled `rhwp-studio` asset, HostApp UI, Quick Look/Thumbnail renderer
  policy와 production CoreGraphics default는 유지했다.
- 기존 Rust 4개와 Swift 24개 test는 삭제·완화하지 않고 lifetime test
  3개씩만 추가했다.
- `rhwp-ffi-symbols.txt`는 수정하지 않았고 generated symbol 파일과
  byte-identical하다.
- `project.yml`과 generated Xcode project에는 Task #447 diff가 없다.
- app version/build, release record, workflow input, release tag, public
  artifact, appcast와 Cask를 변경하지 않았다.
- build, package, visual, Finder와 registration 진단은 `build.noindex/`
  아래 ignored artifact로만 생성했다.

## 잔여 위험과 후속 작업

| 항목 | 상태 | 후속 |
|------|------|------|
| signed/notarized v0.1.9 candidate | 미생성 | #447 merge SHA를 포함해 #441 승인 gate로 새로 생성 |
| Finder Preview 자동 CLI | 기존 v0.1.8도 동일 Apple tool crash | #441 signed candidate에서 실제 Finder Space UI 수동 확인 |
| Intel Mac runtime | 미실행 | universal slice 확인 완료, 가능한 Intel 환경에서 smoke |
| `imageDataLength` 비용 | full lazy bytes allocation 유지 | 성능 문제가 측정되면 별도 metadata ABI 이슈로 분리 |
| raw FFI 신규 caller | exact pointer/length free 의무 | architecture/README 계약을 적용하고 regression test 추가 |
| 로컬 build 산출물 | unregistered 상태로 존재 | PR merge 뒤 task cleanup에서 불필요 artifact 정리 |

새 기능 이슈는 필요하지 않다. v0.1.9 signed candidate 재생성과 public
release 재개는 이미 열려 있는 #441 이슈가 소유한다.

## 최종 결론

rhwp v0.8.2의 owned BinData API와 불일치하던 borrowed-pointer 구현이
v0.1.9 Thumbnail crash의 직접 원인이었다. 기존 symbol을 caller-owned
allocation으로 전환하고 Swift exact free를 적용해 use-after-free를 제거했다.
Rust/Swift lifetime test, ABI/artifact provenance, 세 제품 target, renderer와
candidate-only image-heavy Thumbnail 20/20에서 신규 blocker가 없다.

Task #447 source와 local package 회귀 gate는 완료됐다. public release는
Task #447 merge commit을 포함한 새 signed/notarized candidate 검증 전까지
계속 차단하며, 후속 실행은 #441 승인 절차를 따른다.

## 작업지시자 승인 요청

최종 보고서와 `devel` 대상 ready PR을 검토하고 merge 여부를 승인 요청한다.
merge 전에는 #441 release candidate 갱신, Release Rehearsal과 public publish를
실행하지 않는다.
