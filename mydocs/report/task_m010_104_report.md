# Task #104 최종 결과 보고서

## 작업 요약

- **이슈**: [#104 rhwp v0.7.9 stable tag 반영 및 앱 검증 버전 등록](https://github.com/postmelee/alhangeul-macos/issues/104)
- **마일스톤**: v0.1.0 (M010)
- **브랜치**: `local/task104`
- **단계 수**: 6단계
- **목적**: `edwardkim/rhwp` `v0.7.9` release tag를 앱 저장소의 Stable core 기준으로 반영하고, Release 앱을 등록해 Quick Look preview, Finder thumbnail, HostApp viewer 검증이 가능한 상태로 만드는 것

## 단계별 진행

| Stage | Commit | 핵심 내용 |
|-------|--------|-----------|
| 계획 | `0614f13`, `05fae68` | 수행계획서, 구현계획서, 오늘할일 작성 |
| 1 | `80c302f` | `v0.7.9` release tag, resolved commit, required API, version/등록 기준 확인 |
| 2 | `eb2367c` | `RustBridge/Cargo.toml`, `Cargo.lock`, `rhwp-core.lock`을 `v0.7.9` Stable tag dependency skeleton으로 전환 |
| 3 | `5ac62d9` | Rust bridge artifact 재생성, `rhwp-core.lock` artifact hash/size 갱신, FFI symbol diff 확인 |
| 4 | `19eaed6` | app/extension version 정합성, no-AppKit, Debug build, render smoke 검증 |
| 5 | `4f3a915` | Release package 생성, `$HOME/Applications/AlhangeulMac.app` 설치/등록, Thumbnail/Viewer smoke 검증 |
| 6 | 본 커밋 | 현재 기준 문서 보정, 오늘할일 완료 처리, 최종 검증과 최종 보고서 작성 |

## 변경 파일과 영향 범위

### Core dependency와 lock

- `RustBridge/Cargo.toml`
  - `rhwp` dependency를 `tag = "v0.7.9"`로 고정했다.
- `RustBridge/Cargo.lock`
  - `rhwp` source가 `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.9#0fb3e6758b8ad11d2f3c3849c83b914684e83863`로 resolved 되도록 갱신했다.
- `rhwp-core.lock`
  - `rhwp_ref_kind = "release-tag"`, `rhwp_release_tag = "v0.7.9"`를 기록했다.
  - `rhwp_commit = "0fb3e6758b8ad11d2f3c3849c83b914684e83863"`을 기록했다.
  - `Frameworks/universal/librhwp.a`와 `Frameworks/generated_rhwp.h` artifact hash/size를 `v0.7.9` 재생성 산출물 기준으로 갱신했다.

### Rust bridge artifact

- `Frameworks/universal/librhwp.a`
  - `v0.7.9` 기준으로 재생성했다. git tracked 대상은 아니며, `rhwp-core.lock` hash/size로 검증한다.
- `Frameworks/generated_rhwp.h`
  - 기존 C ABI header surface를 유지했다.
- `Frameworks/generated_rhwp_symbols.txt`
  - `rhwp-ffi-symbols.txt`와 diff 없음.
- `Frameworks/Rhwp.xcframework`
  - `v0.7.9` 기준 static library로 재생성했다.

### 문서와 운영 상태

- `mydocs/tech/core_release_compatibility.md`
  - current release 상태, dependency 형식, artifact 기준, smoke 결과를 `v0.7.9`로 보정했다.
- `mydocs/tech/project_architecture.md`
  - 현재 lock 설명을 `v0.7.9` Stable release tag pin으로 보정했다.
- `mydocs/manual/core_dependency_operation_guide.md`
  - 운영 가이드의 current core 기준을 `v0.7.9`와 resolved commit 기준으로 보정했다.
- `mydocs/orders/20260501.md`
  - #104 상태를 완료로 갱신했다.
- `mydocs/plans/task_m010_104.md`, `mydocs/plans/task_m010_104_impl.md`
  - 수행계획서와 구현계획서를 추가했다.
- `mydocs/working/task_m010_104_stage{1,2,3,4,5,6}.md`
  - 단계별 조사, 구현, 검증, 등록, 문서 보정 결과를 기록했다.

## 핵심 기준

```text
release tag: v0.7.9
target branch: main
publishedAt: 2026-04-30T23:44:59Z
resolved commit: 0fb3e6758b8ad11d2f3c3849c83b914684e83863
```

`v0.7.9`은 다음 RustBridge required API를 포함한다.

- `build_page_render_tree`
- `get_bin_data`
- `render_page_svg_native`
- `get_page_info_native`
- `extract_thumbnail_only`

`v0.7.9` release note 기준 주요 앱 영향 범위는 비정상 큰 `cell.padding` 방어 로직 보정과 그림/레이아웃 관련 외부 PR cherry-pick이다. 앱 저장소에서는 core source를 수정하지 않고 Stable tag pin과 Rust bridge 산출물 provenance만 갱신했다.

## 검증 결과

### Core release와 lock

| 항목 | 결과 |
|------|------|
| `./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.9` | required API gate 통과 |
| `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.9` | Stable tag dependency skeleton 갱신 |
| `./scripts/build-rust-macos.sh --update-lock` | Rust staticlib, header, XCFramework 재생성 |
| `./scripts/build-rust-macos.sh --verify-lock` | `rhwp-core.lock` 검증 통과 |
| `diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt` | 출력 없음, symbol set 일치 |

`rhwp-core.lock` artifact 기준:

```text
Frameworks/universal/librhwp.a
sha256 = 4fc34a8cb7b6489d18705ee342fab13a79df5bd559893c10c163a0787c04e619
size = 104179008

Frameworks/generated_rhwp.h
sha256 = 69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5
size = 1349
```

### Swift/macOS build와 render

| 항목 | 결과 |
|------|------|
| `./scripts/check-no-appkit.sh` | `OK: shared Swift code has no AppKit/UIKit dependencies` |
| `xcodegen generate` | 성공, tracked project diff 없음 |
| HostApp Debug build | `** BUILD SUCCEEDED ** [7.052 sec]` |
| `./scripts/validate-stage3-render.sh` | `KTX.hwp`, `request.hwp`, `exam_kor.hwp` 통과 |

최종 render smoke 결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452034
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53257
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=174108
```

`KTX.hwp`에서 layout overflow 진단 로그가 출력됐지만, 기본 smoke 기준의 문서 open, page size, render tree decode, 한글 text run, non-white bitmap 생성은 모두 통과했다.

### Release package와 Finder 통합

Release package:

```text
build.noindex/release/AlhangeulMac.app
build.noindex/release/alhangeul-macos-0.1.0.zip
sha256: c96ce24dfef7f0af996d84a096130a321ee973169b03b70a512cd7b9fe77af19
```

설치 위치:

```text
/Users/melee/Applications/AlhangeulMac.app
```

app/extension version:

```text
AlhangeulMac.app:             0.1.0 (1)
AlhangeulMacPreview.appex:    0.1.0 (1)
AlhangeulMacThumbnail.appex:  0.1.0 (1)
```

PlugInKit 등록:

```text
com.postmelee.alhangeulmac.QLExtension(0.1.0)
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
SDK = com.apple.quicklook.preview

com.postmelee.alhangeulmac.ThumbnailExtension(0.1.0)
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
SDK = com.apple.quicklook.thumbnail
```

Thumbnail smoke:

```text
qlmanage -t -x -s 512 -o /private/tmp/rhwp-task104-ql-stage5 samples/basic/KTX.hwp
produced one thumbnail
/private/tmp/rhwp-task104-ql-stage5/KTX.hwp.png: PNG image data, 512 x 363, 8-bit/color RGBA, non-interlaced
```

Viewer smoke:

```text
open -n -a "$HOME/Applications/AlhangeulMac.app" samples/basic/KTX.hwp
/Users/melee/Applications/AlhangeulMac.app/Contents/MacOS/AlhangeulMacHost
window: 알한글
```

Quick Look preview:

- Preview extension은 PlugInKit에서 `com.apple.quicklook.preview` SDK와 설치본 경로로 등록 확인됨.
- `qlmanage -p` 자동 smoke는 `KTX.hwp`와 대조군 `README.md` 모두에서 같은 ExtensionFoundation 예외로 종료됨.
- 대조군에서도 재현되므로 이번 작업에서는 macOS `qlmanage` preview harness 환경 이슈로 분리하고, Finder Quick Look 수동 검증 가능 상태인 등록 결과를 남겼다.

## 수용 기준 충족 여부

| 수용 기준 | 결과 |
|----------|------|
| `v0.7.9` release tag와 resolved commit 확인 | OK |
| `Cargo.toml`, `Cargo.lock`, `rhwp-core.lock`이 같은 Stable 기준을 가리킴 | OK |
| RustBridge artifact lock verify | OK |
| FFI symbol set 유지 | OK |
| Swift bridge no-AppKit 규칙 유지 | OK |
| HostApp Debug build 통과 | OK |
| render tree decode/text/non-white pixel smoke 통과 | OK |
| Release package 생성 | OK |
| `$HOME/Applications/AlhangeulMac.app` 설치와 LaunchServices/PlugInKit 등록 | OK |
| Thumbnail extension smoke 통과 | OK |
| HostApp viewer smoke 통과 | OK |
| Preview extension 등록 확인 | OK |
| 현재 기준 문서의 stale `v0.7.8` current 상태 보정 | OK |
| 오늘할일 완료 처리 | OK |

## 잔여 위험과 후속 작업

- `qlmanage -p` preview 자동 smoke는 현재 macOS 실행 환경에서 기본 문서(`README.md`)도 같은 예외로 실패했다. Preview extension 등록은 확인했지만, Finder Quick Look UI 수동 검증은 PR 전후 별도 환경에서 재확인하는 것이 좋다.
- `v0.7.9`의 PageLayerTree API는 이번 작업에서 앱 ABI로 노출하지 않았다. PageLayerTree renderer 전환은 별도 task로 설계해야 한다.
- Xcode/CoreSimulatorService, DVT cache, provisioning profile 관련 경고는 반복되는 로컬 Xcode 실행 환경 경고다. 이번 최종 build와 lock verify는 성공했다.
- 과거 수행계획서와 단계 보고서에 남아 있는 `v0.7.8` 언급은 당시 시점 기록으로 보존했다.

## 작업지시자 승인 요청

본 최종 보고서와 Stage 6 결과 검토 후 `publish/task104` 원격 push 및 `devel` 대상 draft PR 생성 진행 승인을 요청한다.
