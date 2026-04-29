# Task #95 최종 결과 보고서

## 작업 요약

- **이슈**: [#95 rhwp v0.7.8 stable tag 승격](https://github.com/postmelee/alhangeul-macos/issues/95)
- **마일스톤**: v0.1.0 (M010)
- **브랜치**: `local/task95`
- **단계 수**: 5단계
- **목적**: `edwardkim/rhwp` `v0.7.8` release tag를 Stable 기준으로 승격하고, RustBridge/Swift/macOS/Quick Look/Thumbnail use case가 유지되는지 검증

## 단계별 진행

| Stage | Commit | 핵심 내용 |
|-------|--------|-----------|
| 계획 | `3153430`, `c9c9bc7` | 수행계획서와 구현계획서 작성 |
| 1 | `0e336d9` | `v0.7.8` release tag, resolved commit, required API 확인 |
| 2 | `0e4796a` | `RustBridge/Cargo.toml`, `Cargo.lock`, `rhwp-core.lock`을 Stable tag dependency로 전환 |
| 3 | `544cb70` | Rust bridge artifact 재생성, lock verify, FFI symbol diff 확인 |
| 4 | `78fa154` | HostApp build, PageRenderTree render smoke, 이미지/thumbnail smoke 검증 |
| 5 | 본 커밋 | 현재 기준 문서 보정, 오늘할일 완료 처리, 최종 결과 보고서 작성 |

## 변경 파일 목록과 영향 범위

### Core dependency와 lock

- `RustBridge/Cargo.toml`
  - `rhwp` dependency를 `tag = "v0.7.8"`로 고정했다.
- `RustBridge/Cargo.lock`
  - `rhwp` source가 `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.8#42cf91b6ba7b50fa1c853c01158a52ef68b45442`로 resolved 되도록 갱신했다.
- `rhwp-core.lock`
  - `rhwp_ref_kind = "release-tag"`, `rhwp_release_tag = "v0.7.8"`를 기록했다.
  - `rhwp_commit = "42cf91b6ba7b50fa1c853c01158a52ef68b45442"`를 기록했다.
  - `Frameworks/universal/librhwp.a`와 `Frameworks/generated_rhwp.h` artifact hash/size를 `v0.7.8` 재생성 산출물 기준으로 갱신했다.

### Rust bridge artifact

- `Frameworks/universal/librhwp.a`
  - `v0.7.8` 기준으로 재생성했다. git tracked 대상은 아니며, `rhwp-core.lock` hash/size로 검증한다.
- `Frameworks/generated_rhwp.h`
  - 기존 C ABI header surface를 유지했다.
- `Frameworks/generated_rhwp_symbols.txt`
  - `rhwp-ffi-symbols.txt`와 diff 없음.
- `Frameworks/Rhwp.xcframework`
  - `v0.7.8` 기준 static library로 재생성했다.

### 문서

- `mydocs/tech/project_architecture.md`
  - 현재 core 기준을 `v0.7.8` Stable release tag pin으로 보정했다.
- `mydocs/manual/core_dependency_operation_guide.md`
  - 운영 가이드의 current lock 설명을 `v0.7.8`과 resolved commit 기준으로 보정했다.
- `mydocs/tech/core_release_compatibility.md`
  - current release 상태, dependency 형식, compatibility gate 결과, 수동 smoke 결과를 갱신했다.
- `mydocs/orders/20260430.md`
  - #95 상태를 완료로 갱신했다.
- `mydocs/plans/task_m010_95.md`, `mydocs/plans/task_m010_95_impl.md`
  - 수행계획서와 구현계획서를 추가했다.
- `mydocs/working/task_m010_95_stage{1,2,3,4,5}.md`
  - 단계별 조사, 구현, 검증, 문서 보정 결과를 기록했다.

## 핵심 기준

```text
release tag: v0.7.8
resolved commit: 42cf91b6ba7b50fa1c853c01158a52ef68b45442
tag object: 6813f3ebc70a9476c4f9dc919ffda63f2a5c467d
publishedAt: 2026-04-29T03:09:48Z
```

`v0.7.8`은 다음 RustBridge required API를 포함한다.

- `build_page_render_tree`
- `get_bin_data`
- `render_page_svg_native`
- `get_page_info_native`
- `extract_thumbnail_only`

`v0.7.8`에는 PageLayerTree API도 포함되어 있지만, 이번 작업은 기존 PageRenderTree 기반 C ABI와 Swift renderer를 유지했다. PageLayerTree 기반 renderer와 신규 ABI 전환은 후속 작업 범위다.

## 검증 결과

### Core release와 lock

| 항목 | 결과 |
|------|------|
| `./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.8` | required API gate 통과 |
| `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.8` | Stable tag dependency skeleton 갱신 |
| `./scripts/build-rust-macos.sh --update-lock` | Rust staticlib, header, XCFramework 재생성 |
| `./scripts/build-rust-macos.sh --verify-lock` | `rhwp-core.lock` 검증 통과 |
| `diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt` | 출력 없음, symbol set 일치 |

`rhwp-core.lock` artifact 기준:

```text
Frameworks/universal/librhwp.a
sha256 = 257f3689f86f661e7cebf7f2b0debdcdfe872fe1e3b9be132917976389a9859f
size = 104102400

Frameworks/generated_rhwp.h
sha256 = 69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5
size = 1349
```

### Swift/macOS build와 render

| 항목 | 결과 |
|------|------|
| `./scripts/check-no-appkit.sh` | `OK: shared Swift code has no AppKit/UIKit dependencies` |
| `xcodegen generate` | Xcode project 재생성 성공, tracked diff 없음 |
| HostApp Debug build | `** BUILD SUCCEEDED **` |
| `./scripts/validate-stage3-render.sh` | `KTX.hwp`, `request.hwp`, `exam_kor.hwp` 통과 |
| 이미지 포함 샘플 render smoke | `hwp-multi-001.hwp`, `20250130-hongbo.hwp`, `aift.hwp` 통과 |
| 이미지 node와 `bin_data_id` 확인 | `hwp-multi-001.hwp` 2개, `20250130-hongbo.hwp` 3개 확인 |

Stage 5 재검증에서 HostApp Debug build는 다음 결과로 통과했다.

```text
** BUILD SUCCEEDED ** [5.709 sec]
```

Stage 5 재검증의 기본 render smoke 결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=434 hangulRuns=75 hangulScalars=205 nonWhitePixels=410503
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53220
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=131 hangulRuns=84 hangulScalars=1336 nonWhitePixels=171049
```

이미지 포함 샘플 summary:

```text
hwp-multi-001.hwp: PageCount=10, NativePNGSize=794x1123, NativeNonWhitePixels=140721, TextRuns=277, HangulRuns=113, MissingHangulGlyphs=0
20250130-hongbo.hwp: PageCount=4, NativePNGSize=794x1123, NativeNonWhitePixels=83133, TextRuns=60, HangulRuns=35, MissingHangulGlyphs=0
aift.hwp: PageCount=77, NativePNGSize=794x1123, NativeNonWhitePixels=132970, TextRuns=25, HangulRuns=15, MissingHangulGlyphs=0
```

### Quick Look와 Finder smoke

`qlmanage -t` thumbnail smoke는 외부 권한에서 다음 샘플을 통과했다.

- `samples/hwp-multi-001.hwp`
- `samples/20250130-hongbo.hwp`

출력 PNG는 각각 `363 x 512` RGBA PNG로 생성됐다.

작업지시자가 현재 앱으로 다음 수동 smoke 체크리스트를 모두 통과했다고 확인했다.

- HostApp
- Quick Look Preview
- Finder Thumbnail

## 수용 기준 충족 여부

| 수용 기준 | 결과 |
|----------|------|
| `v0.7.8` release tag와 resolved commit 확인 | OK |
| `Cargo.toml`, `Cargo.lock`, `rhwp-core.lock`이 같은 Stable 기준을 가리킴 | OK |
| Demo/Preview `demo-commit-pin` 상태값이 current lock provenance에서 제거됨 | OK |
| RustBridge artifact lock verify | OK |
| FFI symbol set 유지 | OK |
| Swift bridge no-AppKit 규칙 유지 | OK |
| HostApp Debug build 통과 | OK |
| render tree decode/text/non-white pixel smoke 통과 | OK |
| 이미지 `bin_data_id` 기반 data 조회 smoke 통과 | OK |
| Quick Look Preview와 Finder Thumbnail 수동 smoke 통과 | OK |
| 현재 기준 문서의 stale `v0.7.7`/Stable blocked 표현 보정 | OK |
| 오늘할일 완료 처리 | OK |

## 잔여 위험과 후속 작업

- `v0.7.8`의 PageLayerTree API는 이번 작업에서 앱 ABI로 노출하지 않았다. PageLayerTree renderer 전환은 별도 task로 설계해야 한다.
- Quick Look/Finder 수동 smoke는 현재 개발자 환경의 LaunchServices/PlugInKit 상태에 의존한다. release rehearsal과 배포 전에는 설치/등록 상태에서 재확인해야 한다.
- `render-debug-compare.sh`의 선택적 SVG rasterize/pixel diff는 sandbox qlmanage 오류로 생성되지 않았다. 필수 산출물인 render tree JSON, core SVG, native PNG, summary는 생성됐다.
- 과거 계획서와 단계 보고서에 남아 있는 `v0.7.7`, `e91ecea`, Stable blocked 표현은 당시 시점 기록으로 보존했다.

## 작업지시자 승인 요청

본 최종 보고서와 Stage 5 결과 검토 후 `publish/task95` 원격 push 및 devel 대상 draft PR 생성 진행 승인을 요청한다.
