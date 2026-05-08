# Task #104 Stage 1 완료 보고서 - v0.7.9 stable tag와 검증 기준 재확인

## 목적

`edwardkim/rhwp` release `v0.7.9`가 앱 저장소의 Stable core 기준을 만족하는지 확인하고, 이후 단계에서 적용할 app/extension version 및 Release package 등록 검증 기준을 확정한다.

## 확인 결과

### 1. 현재 앱 저장소 기준

현재 작업 브랜치는 `local/task104`이고, Stage 1 시작 시점 working tree는 깨끗했다.

현재 core pin:

```text
RustBridge/Cargo.toml: tag = "v0.7.8"
rhwp-core.lock rhwp_ref_kind = "release-tag"
rhwp-core.lock rhwp_release_tag = "v0.7.8"
rhwp-core.lock rhwp_commit = "42cf91b6ba7b50fa1c853c01158a52ef68b45442"
```

현재 app/extension source plist version:

```text
HostApp:             CFBundleShortVersionString = 0.1.0, CFBundleVersion = 1
QLExtension:         CFBundleShortVersionString = 0.1.0, CFBundleVersion = 1
ThumbnailExtension:  CFBundleShortVersionString = 0.1.0, CFBundleVersion = 1
```

표준 설치 경로 `$HOME/Applications/AlhangeulMac.app`에는 기존 설치본이 있으며, 해당 설치본도 `0.1.0 (1)` 기준이다.

### 2. upstream release 확인

`gh release view v0.7.9 --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url,name,body` 결과:

```text
tagName: v0.7.9
name: v0.7.9 — Task #501 cell.padding 한컴 방어 로직 + PR cherry-pick 사이클
targetCommitish: main
publishedAt: 2026-04-30T23:44:59Z
url: https://github.com/edwardkim/rhwp/releases/tag/v0.7.9
```

`git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.9 'refs/tags/v0.7.9^{}'` 결과:

```text
0fb3e6758b8ad11d2f3c3849c83b914684e83863 refs/tags/v0.7.9
```

따라서 Stage 2에서 기록할 Stable resolved commit 후보는 다음이다.

```text
0fb3e6758b8ad11d2f3c3849c83b914684e83863
```

### 3. release note 영향 범위

`v0.7.9`는 `v0.7.8` 후속 패치 사이클이다. release note 기준 주요 내용은 다음이다.

- Task #501: 비정상 큰 `cell.padding`이 `cell.height`보다 큰 표 셀 케이스 방어 로직 보정
- 외부 PR cherry-pick 4건 / 18 commits
  - 그룹 내 Picture 직렬화
  - `Paragraph::utf16_pos_to_char_idx` 외부 노출
  - Layout 정합 + 수식 정정 일부
  - Canvas visual diff 파이프라인
- upstream 검증: `cargo test --lib` 1102 passed, SVG snapshot, issue_418/issue_501, clippy, WASM 빌드 정합

앱 저장소 관점에서는 core source를 수정하지 않고 `RustBridge` dependency와 산출물 provenance를 갱신하는 범위로 충분하다. 다만 layout/그림 직렬화 관련 변경이 포함되어 있으므로 Stage 4의 render smoke와 Stage 5의 Quick Look/Thumbnail smoke를 그대로 수행한다.

### 4. required API gate

`./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.9` 결과:

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.9
  commit:  0fb3e6758b8ad11d2f3c3849c83b914684e83863
```

이 check는 다음 required API 존재를 확인한다.

- `build_page_render_tree`
- `get_bin_data`
- `render_page_svg_native`
- `get_page_info_native`
- `extract_thumbnail_only`

따라서 `v0.7.9`는 Stage 2 Stable tag dependency 전환 후보로 사용할 수 있다.

### 5. app/extension version 방침

현재 product milestone은 `v0.1`이고 source plist의 app short version도 `0.1.0`이다. `scripts/release.sh`는 public release 시 입력 version과 세 plist의 `CFBundleShortVersionString` 일치를 강제한다.

이번 작업의 public release, notarization, Homebrew Cask 갱신은 제외 범위다. 따라서 Stage 4의 기본 방침은 다음이다.

- `CFBundleShortVersionString`은 `0.1.0` 유지
- `CFBundleVersion`도 Stage 4에서 registration 충돌 필요성이 확인되지 않으면 `1` 유지
- Release package는 `./scripts/package-release.sh 0.1.0`으로 생성
- "릴리즈 버전을 응용프로그램에 등록"은 Debug 산출물이 아니라 Release configuration package 산출물을 `$HOME/Applications/AlhangeulMac.app`에 설치 및 LaunchServices/PlugInKit 등록하는 의미로 처리

Stage 4에서 version 변경 필요성이 확인되면 HostApp, QLExtension, ThumbnailExtension 세 plist를 같은 기준으로만 조정한다.

### 6. 표준 설치/등록 기준

현재 PlugInKit 조회 결과 기존 등록 후보는 다음과 같다.

```text
com.postmelee.alhangeulmac.QLExtension(0.1.0)
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app

com.postmelee.alhangeulmac.ThumbnailExtension(0.1.0)
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app
```

Stage 5에서는 같은 표준 경로의 기존 설치본만 새 Release package 산출물로 교체한다. 이 경로 밖의 이전 설치본은 임의 삭제하지 않는다.

## Stage 2 진입 조건

다음 단계에서는 `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.9`를 실행해 다음 파일을 변경한다.

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`

Stage 2 완료 조건은 세 파일이 모두 `v0.7.9`와 resolved commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863` 기준으로 일치하는 것이다.

## 검증

실행한 명령:

```bash
git status --short --branch
gh issue view 104 --repo postmelee/alhangeul-macos --json number,title,state,body,labels,milestone,url
gh release view v0.7.9 --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url,name,body
git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.9 'refs/tags/v0.7.9^{}'
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.9
rg -n "rhwp_render_page_tree|rhwp_image_data|bin_data_id|RenderNode|build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only" \
  RustBridge Sources/RhwpCoreBridge Sources/Shared Sources/HostApp Sources/QLExtension Sources/ThumbnailExtension mydocs/tech mydocs/manual
rg -n "CFBundleShortVersionString|CFBundleVersion|package-release|validate_source_versions|0\\.1\\.0" \
  Sources scripts mydocs/manual/build_run_guide.md mydocs/manual/release_distribution_guide.md mydocs/tech/project_architecture.md
pluginkit -mAvvv | rg -n -C 6 "com\\.postmelee\\.alhangeulmac|AlhangeulMac(Preview|Thumbnail)"
```

결과:

- Issue #104는 `OPEN`, milestone `v0.1`, label `enhancement`, `area:core`, `area:ci-cd`, `kind:verification` 상태다.
- `v0.7.9` release tag와 URL을 확인했다.
- `v0.7.9` resolved commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863`을 확인했다.
- `v0.7.9` required API check가 통과했다.
- 현재 app/extension source plist는 모두 `0.1.0 (1)`로 일치한다.
- 기존 PlugInKit 등록 경로는 표준 설치 경로 `$HOME/Applications/AlhangeulMac.app`다.

## 다음 단계

작업지시자 승인 후 Stage 2에서 `v0.7.9` Stable tag dependency와 lock provenance skeleton을 갱신한다.
