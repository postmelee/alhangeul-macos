# Task M019 #225 Stage 1 완료보고서

## 단계 목적

`rhwp v0.7.11` 반영 전 현재 저장소 상태와 구현 touchpoint를 확정했다. 특히 core/studio update 대상, About provenance 표시 위치, update 후 LaunchServices/thumbnail refresh 구현 경계, v0.1.2 public 배포 gate를 Stage 2 이후 작업자가 같은 기준으로 이어갈 수 있게 정리했다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/working/task_m019_225_stage1.md` | 신규 | Stage 1 inventory, 검증 결과, Stage 2 진입 조건 기록 |

소스 코드는 변경하지 않았다.

## Inventory 결과

### Upstream `rhwp`

- GitHub release 목록 기준 `v0.7.11`이 latest release다.
- `v0.7.11`은 draft/prerelease가 아니며 publishedAt은 `2026-05-10T19:50:46Z`다.
- 원격 tag `refs/tags/v0.7.11`은 `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`다.
- `scripts/update-rhwp-core.sh --channel stable --tag v0.7.11 --check` 결과, RustBridge가 요구하는 upstream API check를 통과했다.

### 현재 저장소 provenance

현재 source는 아직 `v0.7.10` 기준이다.

| 영역 | 현재 값 | Stage 2 변경 필요 |
|------|---------|-------------------|
| `rhwp-core.lock` | `rhwp_release_tag = "v0.7.10"`, commit `62a458aa317e962cd3d0eec6096728c172d57110` | `v0.7.11` / `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` |
| `RustBridge/Cargo.toml` | `rhwp` git dependency tag `v0.7.10` | `v0.7.11` |
| `RustBridge/Cargo.lock` | `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.10#62a458...` | `?tag=v0.7.11#a9dcdee...` |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | `source_release_tag = v0.7.10`, `source_resolved_commit = 62a458...` | `v0.7.11` manifest 재생성 |
| `scripts/sync-rhwp-studio.sh` | `EXPECTED_RELEASE_TAG=v0.7.10`, `EXPECTED_COMMIT=62a458...` | `v0.7.11` 기준으로 갱신 후 실행 |
| `scripts/verify-rhwp-studio-assets.sh` | `EXPECTED_RELEASE_TAG=v0.7.10`, `EXPECTED_COMMIT=62a458...` | `v0.7.11` 기준 검증 |
| `Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md` | core/studio provenance `v0.7.10` | `v0.7.11` |
| `README.md` 최신 공개 릴리즈 요약 | 포함된 `rhwp v0.7.10` | Stage 4에서 v0.1.2 public candidate 기준 정리 |

### 현재 앱 버전과 release workflow

- HostApp, Quick Look extension, Thumbnail extension 모두 `CFBundleShortVersionString=0.1.1`, `CFBundleVersion=4`다.
- `.github/workflows/release-rehearsal.yml` default version은 `0.1.1`이다.
- `.github/workflows/release-publish.yml` default version은 `0.1.1`, `expected_rhwp_tag` default는 `v0.7.10`이다.
- v0.1.2 release candidate 단계에서는 version/build를 `0.1.2`와 새 build number로 올리고, `expected_rhwp_tag`는 `v0.7.11`, `previous_release_ref`는 `v0.1.1` 기준으로 보정해야 한다.

### About/provenance 표시 위치

- `Sources/HostApp/Support/BuildInfo.swift`는 현재 앱 display name, version, build, displayVersion만 제공한다.
- `Sources/HostApp/Views/AboutView.swift`는 “버전”, “빌드” row와 extension 상태 섹션만 표시한다.
- Stage 3에서는 bundle resource의 `rhwp-studio/manifest.json`을 읽거나 별도 generated metadata를 추가해 `rhwp v0.7.11 (a9dcdee)` 형식의 row를 추가하는 방향이 적합하다.
- fallback은 manifest 누락/파싱 실패 시 About 창 자체가 깨지지 않도록 `확인 불가` 또는 숨김 처리를 둔다.

### Extension registration refresh

- 현재 `AppDelegate.applicationDidFinishLaunching`은 매 실행마다 `ExtensionSystemRegistrationRefresher.refreshCurrentBundle()`을 호출한다.
- `ExtensionSystemRegistrationRefresher`는 `LSRegisterURL(appBundleURL, true)`와 `NSWorkspace.shared.noteFileSystemChanged`를 app bundle, `Contents/PlugIns`, 각 `.appex` 경로에 호출한다.
- About window의 “상태 새로고침”도 같은 public API refresh를 호출한다.
- Stage 3에서는 이 동작을 build-scoped maintenance marker로 감싸, 새 build 최초 실행 때만 update maintenance가 실행되도록 정리한다. About의 수동 새로고침은 그대로 수동 refresh 역할을 유지할 수 있다.

### Targeted thumbnail refresh 경계

- 제품 앱 자동 path에는 전역 `qlmanage -r cache`, `pluginkit -a`, `pluginkit -e use`, Finder 재실행을 넣지 않는다.
- 기존 매뉴얼도 제품 앱의 About/시작 경로는 `LSRegisterURL(..., true)`와 `NSWorkspace.noteFileSystemChanged(...)`만 사용하고, `qlmanage -r cache`와 `pluginkit` 명령은 smoke/troubleshooting에서만 실행하도록 정한다.
- 최근 문서 후보는 `RecentDocumentStore`가 저장하는 최대 8개의 security-scoped bookmark와 `NSDocumentController` recent list를 우선 사용한다.
- Stage 3 구현 경계:
  - HWP/HWPX 확장자 또는 UTType 후보만 대상으로 한다.
  - bookmark resolution과 security scope 접근에 실패한 파일은 건너뛴다.
  - 파일 내용, mtime, extended attribute를 변경하지 않는다.
  - 접근 가능한 URL에 `NSWorkspace.shared.noteFileSystemChanged(url.path)`를 호출해 Finder/Quick Look 쪽 재평가를 유도한다.
  - 실패는 로깅만 하고 앱 실행을 막지 않는다.
- 실제 cache reset과 provider path 판정은 `scripts/smoke-sparkle-extension-refresh.sh`와 `scripts/smoke-finder-integration.sh`의 release smoke 영역에서 수행한다.

### Release gate

- v0.1.2 public 배포는 `local/task225 -> publish/task225 -> devel-webview` PR merge만으로 실행하지 않는다.
- release policy 기준으로 `devel-webview`의 검증된 commit을 `main`에 반영한 뒤, `main` 기준 `v0.1.2` tag를 생성하고 GitHub Release를 생성한다.
- `Release Publish DMG` official path, GitHub Release 게시, Pages deployment, stable Sparkle appcast 갱신은 별도 명시 승인 후 실행한다.
- Stage 2~5는 source/rehearsal/smoke 검증이고, Stage 6에서 PR 게시와 main release handoff를 분리 기록한다.

## 검증 결과

### `gh release list`

```text
[{"isDraft":false,"isLatest":true,"isPrerelease":false,"name":"v0.7.11 — 5/10+5/11 사이클 누적 (Skia P8/P9 + HWP3 native + rhwp-studio editor 신규 기능)","publishedAt":"2026-05-10T19:50:46Z","tagName":"v0.7.11"},{"isDraft":false,"isLatest":false,"isPrerelease":false,"name":"v0.7.10 — 외부 기여자 7명 + AI/VLM 연동 + CLI 바이너리 릴리즈","publishedAt":"2026-05-05T17:56:40Z","tagName":"v0.7.10"},{"isDraft":false,"isLatest":false,"isPrerelease":false,"name":"v0.7.9 — Task #501 cell.padding 한컴 방어 로직 + PR cherry-pick 사이클","publishedAt":"2026-04-30T23:44:59Z","tagName":"v0.7.9"},{"isDraft":false,"isLatest":false,"isPrerelease":false,"name":"v0.7.8 — 외부 컨트리뷰터 다수 + 메인테이너 회귀 정정","publishedAt":"2026-04-29T03:09:48Z","tagName":"v0.7.8"},{"isDraft":false,"isLatest":false,"isPrerelease":false,"name":"v0.7.7 — TypesetEngine 회귀 정정 사이클","publishedAt":"2026-04-27T04:21:36Z","tagName":"v0.7.7"}]
```

### `git ls-remote`

```text
a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae	refs/tags/v0.7.11
```

### `rg` inventory

주요 결과:

```text
rhwp-core.lock:4:rhwp_release_tag = "v0.7.10"
RustBridge/Cargo.toml:11:rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.10" }
Sources/HostApp/Resources/rhwp-studio/manifest.json:5:  "source_release_tag": "v0.7.10",
Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md:11:- Rust core와 Web/WASM viewer asset은 `edwardkim/rhwp` `v0.7.10` release-tag snapshot 기준이다.
.github/workflows/release-publish.yml:17:        default: "v0.7.10"
Sources/HostApp/Support/BuildInfo.swift:3:enum BuildInfo {
Sources/HostApp/Views/AboutView.swift:15:                AboutInfoRow(title: "버전", value: BuildInfo.version)
Sources/HostApp/Views/AboutView.swift:16:                AboutInfoRow(title: "빌드", value: BuildInfo.build)
Sources/HostApp/Services/ExtensionSystemRegistrationRefresher.swift:13:        let registrationStatus = LSRegisterURL(appBundleURL as CFURL, true)
Sources/HostApp/Services/RecentDocumentStore.swift:64:        NSDocumentController.shared.noteNewRecentDocumentURL(document.url)
```

### `update-rhwp-core --check`

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.11
  commit:  a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae
```

### Version plist check

```text
HostApp CFBundleShortVersionString: 0.1.1
HostApp CFBundleVersion: 4
QLExtension CFBundleShortVersionString: 0.1.1
QLExtension CFBundleVersion: 4
ThumbnailExtension CFBundleShortVersionString: 0.1.1
ThumbnailExtension CFBundleVersion: 4
```

## 본문 변경 정도 / 본문 무손실 여부

신규 단계 보고서만 추가했다. 기존 문서와 소스 본문은 변경하지 않았으므로 본문 무손실 이슈는 없다.

## 잔여 위험

- Stage 2에서 실제 `v0.7.11` Rust build와 `rhwp-studio` build를 수행해야 하므로 Rust target, `cbindgen`, Xcode CLI, Docker/Node dependency 상태가 blocker가 될 수 있다.
- `scripts/sync-rhwp-studio.sh`와 `scripts/verify-rhwp-studio-assets.sh`는 현재 expected tag/commit이 hardcode되어 있어 Stage 2에서 먼저 갱신해야 한다.
- `build.noindex/`에는 현재 `rhwp-upstream-task225` checkout이 없으므로 Stage 2에서 upstream checkout을 새로 준비해야 한다.
- `rhwp-studio` WASM build는 Docker file sharing 경계 영향을 받는다. 이전 작업 기록상 `/private/tmp`보다 repository의 `build.noindex/rhwp-upstream-task225` 경로가 안전하다.
- targeted thumbnail refresh는 Finder thumbnail cache를 직접 삭제하지 않으므로 recent 후보 밖 파일은 stale 상태가 남을 수 있다.
- Stage 1에서 실행한 네트워크 검증은 샌드박스 DNS 제한 때문에 승인 경로로 실행했다. Stage 2의 fetch/cargo build도 동일하게 네트워크 승인이 필요할 수 있다.

## 다음 단계 영향

Stage 2는 다음 순서로 진행하는 것이 적절하다.

1. `scripts/update-rhwp-core.sh --channel stable --tag v0.7.11`로 Cargo dependency와 `rhwp-core.lock` skeleton 갱신
2. `scripts/build-rust-macos.sh --update-lock`로 Rust bridge artifact와 lock artifact metadata 갱신
3. `scripts/check-no-appkit.sh`로 `Sources/RhwpCoreBridge` AppKit/UIKit 의존 금지 확인
4. `build.noindex/rhwp-upstream-task225`에 upstream `v0.7.11` checkout 준비
5. upstream checkout에서 WASM package와 `rhwp-studio/dist` 생성
6. `scripts/sync-rhwp-studio.sh`, `scripts/verify-rhwp-studio-assets.sh` expected tag/commit을 `v0.7.11` 기준으로 갱신
7. `scripts/sync-rhwp-studio.sh build.noindex/rhwp-upstream-task225`
8. `scripts/verify-rhwp-studio-assets.sh`

Stage 3에서 About/update maintenance를 구현할 때는 현재 매 실행 refresh를 build-scoped maintenance로 감싸고, recent HWP/HWPX document URL에만 `NSWorkspace.noteFileSystemChanged`를 적용하는 방향을 기준으로 한다.

## 승인 요청

Stage 1 완료를 승인하면 Stage 2 `rhwp v0.7.11` core와 studio asset 갱신을 진행한다.
