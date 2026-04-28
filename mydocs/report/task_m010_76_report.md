# Task #76 최종 결과 보고서

## 작업 요약

- **이슈**: [#76 rhwp PR #385 반영 core pin 갱신과 native bridge 검증](https://github.com/postmelee/alhangeul-macos/issues/76)
- **마일스톤**: v0.1.0 (M010)
- **브랜치**: `local/task76`
- **단계 수**: 5단계
- **목적**: `edwardkim/rhwp` PR #385 merge commit을 alhangeul-macos Demo/Preview core pin으로 반영하고, RustBridge/Swift bridge/HostApp/Quick Look/Thumbnail use case가 유지되는지 검증

## 단계별 진행

| Stage | Commit | 핵심 내용 |
|-------|--------|-----------|
| 계획 | `4014065`, `fb3cd78` | 수행계획서, 구현계획서 작성 |
| 1 | `fef3d63` | 기존 pin, PR #385, Issue #363, latest release `v0.7.7`, native bridge contract 조사 |
| 2 | `dcd17a4` | Demo/Preview core pin을 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 갱신 |
| 3 | `02cf2aa` | RustBridge lock verify, FFI symbol diff, no-AppKit 검증 |
| 4 | `656c41a` | HostApp Debug build, render smoke, image data smoke 검증 |
| 5 | 본 커밋 | release 상태 문서 보정, 설치본 기준 Quick Look/Thumbnail 확인 결과와 upstream 회신 요약 정리 |

## 변경 파일 목록과 영향 범위

### Core pin과 lock

- `RustBridge/Cargo.toml`
  - `rhwp` dependency rev를 `1e9d78a1d40c71779d81c6ec6870cd301d912626`에서 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 갱신했다.
- `RustBridge/Cargo.lock`
  - `rhwp v0.7.7` source가 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 resolved 되도록 갱신했다.
  - upstream dependency graph 변화에 따라 `wasm-bindgen`, `zip`, `libc`, futures 계열 일부 의존성이 함께 갱신되었다.
- `rhwp-core.lock`
  - `rhwp_ref_kind = "commit"`과 `rhwp_release_transition_status = "demo-commit-pin"`을 유지했다.
  - `rhwp_commit`을 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 갱신했다.
  - latest checked release를 `v0.7.7` / `033617e23847982135c02091a62f55031a3817b5`로 보정했다.
  - `Frameworks/universal/librhwp.a` artifact hash/size를 새 산출물 기준으로 갱신했다.

### 문서

- `mydocs/tech/core_release_compatibility.md`
  - 현재 Demo/Preview pin, latest release `v0.7.7`, Stable blocked 사유를 최신 확인 기준으로 보정했다.
  - alhangeul-macos use case 검증 결과를 추가했다.
- `mydocs/manual/core_dependency_operation_guide.md`
  - core 기준 설명을 `v0.7.7`과 현재 blocked 사유 기준으로 보정했다.
- `mydocs/tech/project_architecture.md`
  - Demo/Preview와 Stable 기준 요약의 stale release 표현을 보정했다.
- `mydocs/orders/20260429.md`
  - #76 상태를 완료로 갱신했다.
- `mydocs/plans/task_m010_76.md`, `mydocs/plans/task_m010_76_impl.md`
  - 수행계획서와 구현계획서를 추가했다.
- `mydocs/working/task_m010_76_stage{1,2,3,4,5}.md`
  - 단계별 조사, 구현, 검증, 문서 보정 결과를 기록했다.

생성 산출물인 `Frameworks/`, `build.noindex/`, `output/`, `AlhangeulMac.xcodeproj`는 tracked 변경에 포함하지 않았다.

## 검증 결과

### Core release 상태

```text
gh release view --repo edwardkim/rhwp:
tagName=v0.7.7
targetCommitish=main
publishedAt=2026-04-27T04:21:36Z
url=https://github.com/edwardkim/rhwp/releases/tag/v0.7.7

git ls-remote refs/tags/v0.7.7:
033617e23847982135c02091a62f55031a3817b5
```

`./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.7` 결과:

```text
ERROR: missing core API: build_page_render_tree
ERROR: missing core API: target 033617e23847982135c02091a62f55031a3817b5 does not satisfy RustBridge requirements
```

따라서 Stable release tag 전환은 보류하고, PR #385 merge commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d` 기준 Demo/Preview commit pin을 유지했다.

### RustBridge와 ABI

| 항목 | 결과 |
|------|------|
| `./scripts/build-rust-macos.sh --verify-lock` | 통과 |
| `diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt` | 출력 없음, symbol set 일치 |
| `grep -n "width_pt\|height_pt" Frameworks/generated_rhwp.h` | `RhwpPageSize` field 유지 |
| `./scripts/check-no-appkit.sh` | `OK: shared Swift code has no AppKit/UIKit dependencies` |

### HostApp와 render use case

| 항목 | 결과 |
|------|------|
| `xcodegen generate` | 통과 |
| HostApp Debug build | `** BUILD SUCCEEDED **` |
| `./scripts/validate-stage3-render.sh` | `KTX.hwp`, `request.hwp`, `exam_kor.hwp` 통과 |
| 이미지 샘플 render smoke | `hwp-img-001.hwp`, `pic-in-head-02.hwp`, `pic-in-table-01.hwp`, `tac-img-02.hwp` 통과 |
| Swift bridge image data 조회 smoke | 이미지 node 9개, unique `bin_data_id` 9개 조회 성공 |

### 설치본 기준 Quick Look/Thumbnail 확인

`./scripts/package-release.sh 0.1.0`으로 signed/sealed Release package 산출물을 생성한 뒤 `/Users/melee/Applications/AlhangeulMac.app`으로 교체하고 LaunchServices/PlugInKit 등록을 갱신했다.

등록 확인:

```text
com.postmelee.alhangeulmac.QLExtension
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app

com.postmelee.alhangeulmac.ThumbnailExtension
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app
```

`codesign --verify --deep --strict --verbose=2 /Users/melee/Applications/AlhangeulMac.app` 결과는 통과했다.

`qlmanage -t -x -s 512` thumbnail smoke는 다음 샘플에서 통과했다.

- `samples/basic/KTX.hwp`
- `samples/basic/request.hwp`
- `samples/basic/KTX-003.hwp`
- `samples/exam_kor.hwp`
- `samples/hwp-img-001.hwp`
- `samples/pic-in-head-02.hwp`
- `samples/pic-in-table-01.hwp`
- `samples/tac-img-02.hwp`

작업지시자가 Finder에서 thumbnail과 Quick Look preview를 직접 확인했다.

## 수용 기준 충족 여부

| 수용 기준 | 결과 |
|----------|------|
| upstream PR #385 merge commit 기준으로 Demo/Preview pin 갱신 | OK |
| `Cargo.toml`, `Cargo.lock`, `rhwp-core.lock` 기준 일치 | OK |
| Stable release tag 전환 가능 여부 재확인 | OK, `v0.7.7`은 `build_page_render_tree` 누락으로 blocked |
| RustBridge artifact lock verify | OK |
| FFI symbol set 유지 | OK |
| Swift bridge no-AppKit 규칙 유지 | OK |
| HostApp Debug build 통과 | OK |
| render tree decode/text/non-white pixel smoke 통과 | OK |
| 이미지 `bin_data_id` 기반 data 조회 smoke 통과 | OK |
| 설치본 기준 Quick Look/Thumbnail smoke 확인 | OK |
| 문서의 stale release/pin 표현 보정 | OK |

## 메인테이너 회신용 한국어 요약

아래 문구를 `edwardkim/rhwp` 쪽 회신에 사용할 수 있다.

```text
alhangeul-macos 쪽 use case 검증 결과 공유드립니다.

- rhwp pin을 PR #385 merge commit e91ecea3174a0da0ad7a1ea495cacc4f8772c31d 기준으로 갱신했습니다.
- RustBridge C ABI symbol set은 기존과 동일하며, rhwp-core.lock artifact verify도 통과했습니다.
- HostApp Debug build와 기본 render smoke(KTX/request/exam_kor) 모두 통과했습니다.
- 이미지 포함 샘플(hwp-img-001, pic-in-head-02, pic-in-table-01, tac-img-02)에서 render tree의 bin_data_id를 통해 rhwp_image_data를 조회하는 경로가 정상 동작함을 확인했습니다.
- 현재 release package 산출물을 설치본으로 교체한 뒤 Finder thumbnail과 Quick Look preview를 직접 확인했습니다. qlmanage thumbnail smoke도 KTX/request/KTX-003/exam_kor 및 이미지 포함 샘플에서 통과했습니다.
- 최신 release v0.7.7은 build_page_render_tree가 없어 Stable release tag 전환은 아직 보류했고, alhangeul-macos에서는 이번 검증 범위를 Demo/Preview commit pin으로 유지했습니다.
```

## 잔여 위험과 후속 작업

- `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`는 release tag가 아니라 upstream merge commit이다. v0.1.0 Demo/Preview 배포에는 사용할 수 있지만 Stable 기준으로 표시하지 않는다.
- 다음 `edwardkim/rhwp` release가 `build_page_render_tree`를 포함하면 Stable release tag 전환 task를 별도로 진행한다.
- Finder/Quick Look smoke는 현재 개발자 환경의 LaunchServices/PlugInKit 상태에 의존한다. 배포 전 release rehearsal에서도 같은 설치/등록 절차로 재확인한다.
- `LAYOUT_OVERFLOW_DRAW` diagnostic이 일부 이미지 샘플에서 출력되지만 command exit code와 render/image smoke는 통과했다. 별도 렌더 품질 이슈가 필요하면 core/render task로 분리한다.

## 작업지시자 승인 요청

본 최종 보고서와 Stage 5 결과 검토 후 `publish/task76` 원격 push 및 devel 대상 draft PR 생성 진행 승인을 요청한다.
