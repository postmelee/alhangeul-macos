# Task #134 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 upstream `rhwp-studio` 정적 asset을 HostApp bundle resource로 포함할 수 있게 구성하고, 같은 산출물을 재생성/검증할 수 있는 최소 script를 마련한다.

## 산출물

- `Sources/HostApp/Resources/rhwp-studio/`
  - `rhwp-studio` production build 산출물
  - WASM glue와 `rhwp_bg-*.wasm`
  - font/icon/PWA 보조 asset
  - provenance metadata `manifest.json`
- `project.yml`
  - HostApp target에서 `Resources/rhwp-studio`를 folder reference resource로 포함
- `AlhangeulMac.xcodeproj/project.pbxproj`
  - `xcodegen generate`로 재생성된 resource build phase
- `scripts/sync-rhwp-studio.sh`
  - upstream checkout에서 bundle resource를 동기화하고 manifest를 생성
- `scripts/verify-rhwp-studio-assets.sh`
  - 필수 entrypoint, 상대 경로, sample 제외 여부, provenance를 검증
- `mydocs/working/task_m010_134_stage2.md`
  - Stage 2 완료 보고서
- `mydocs/orders/20260503.md`
  - #134 비고를 Stage 2 승인 대기 상태로 갱신

이번 단계에서는 HostApp Swift viewer 코드, Quick Look/Thumbnail code path, `Sources/Shared`, `Sources/RhwpCoreBridge`를 변경하지 않았다. `mydocs/tech/project_architecture.md`는 WKWebView 실제 연결 후 Stage 4에서 viewer 경로 설명을 보정한다.

## 본문 변경 정도 / 본문 무손실 여부

- 신규 bundle asset directory를 추가했다.
- 신규 script 2개를 추가했다.
- `project.yml`의 HostApp source/resource 항목만 변경했다.
- Xcode project는 `project.yml` 기준으로 재생성했다.
- 기존 Swift/Rust source 본문은 수정하지 않았다.

## asset 기준

- source repository: `https://github.com/edwardkim/rhwp.git`
- source release tag: `v0.7.9`
- source resolved commit: `0fb3e6758b8ad11d2f3c3849c83b914684e83863`
- app repository 기준: `rhwp-core.lock` 및 Stage 1에서 확인한 resolved commit과 동일
- WASM build command: `docker-compose --env-file .env.docker run --rm wasm`
- studio build command: `npx tsc && npx vite build --base ./`

`vite build` 기본값은 `/assets/...` root-relative 경로를 만들었으므로, bundle/file URL 로딩을 위해 `--base ./`로 다시 build했다. 최종 `index.html`은 JS/CSS를 `./assets/...`로 참조한다.

## 작업 내용

### upstream build

처음에는 `/private/tmp/rhwp-upstream-task134`에서 build를 시도했으나 Docker container가 macOS Docker file sharing 범위 밖의 `/private/tmp` clone을 crate root로 mount하지 못해 `Cargo.toml`을 찾지 못했다. 이후 upstream clone을 `/Users/melee/Documents/projects/rhwp-mac/build.noindex/rhwp-upstream-task134`로 복사해 Docker file sharing 범위 안에서 build했다.

또한 현재 환경에서는 `docker compose` subcommand가 동작하지 않고 `docker-compose` binary만 사용할 수 있어 다음 명령으로 WASM package를 생성했다.

```bash
docker-compose --env-file .env.docker run --rm wasm
```

그 뒤 `rhwp-studio`에서 다음 명령으로 production asset을 생성했다.

```bash
npx tsc && npx vite build --base ./
```

### bundle resource 구성

`rhwp-studio/dist` 산출물을 `Sources/HostApp/Resources/rhwp-studio`로 복사했다. upstream sample 문서 directory는 앱 번들에 포함하지 않았다.

- copied dist file count: 50
- copied dist total bytes: 27,704,113 bytes
- final resource directory size: 27M
- final resource file count: 51
  - copied dist 50 files
  - generated `manifest.json` 1 file
- excluded path: `samples/`

주요 entrypoint hash:

| path | sha256 |
|------|--------|
| `index.html` | `10d10f4ae25f797d18f7de31812041574cde2e121e00d2c3caffb5361343acb0` |
| `assets/index-CCXookfl.js` | `3bb81abc018113c808253d75a62aa8ce19545bbccd4ece16d1b4c4df2f465986` |
| `assets/index-ro3nVBB2.css` | `d669a5f84fd2945f4d6be9a5471d6d2782ff629f77658a73f6f5d0f1133d7179` |
| `assets/rhwp_bg-DtQ01XFR.wasm` | `bfcf7632d7f4877b69abe3a95e52fa23636f5253c149de877d1975fdac608b41` |

### project.yml/XcodeGen

HostApp target에서 `Sources/HostApp`를 그대로 source root로 쓰되 `Resources/rhwp-studio`는 source compile 대상으로 보지 않도록 exclude했다. 같은 directory를 별도 folder reference resource로 추가해 hashed asset filename이 바뀌어도 Xcode project에 파일별 항목을 매번 나열하지 않게 했다.

```yaml
- path: Sources/HostApp
  excludes:
    - Resources/rhwp-studio
- path: Sources/HostApp/Resources/rhwp-studio
  type: folder
```

`xcodegen generate` 후 `AlhangeulMac.xcodeproj/project.pbxproj`에는 `rhwp-studio in Resources` build file과 folder file reference가 추가되었다.

## 검증 결과

```bash
$ scripts/sync-rhwp-studio.sh /Users/melee/Documents/projects/rhwp-mac/build.noindex/rhwp-upstream-task134
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task134/Sources/HostApp/Resources/rhwp-studio
```

```bash
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task134/Sources/HostApp/Resources/rhwp-studio
```

```bash
$ test -f Sources/HostApp/Resources/rhwp-studio/index.html
```

결과: 성공.

```bash
$ find Sources/HostApp/Resources/rhwp-studio -maxdepth 3 -type f
```

결과 요약: `index.html`, `registerSW.js`, `manifest.webmanifest`, `sw.js`, `workbox-66610c77.js`, `assets/index-CCXookfl.js`, `assets/index-ro3nVBB2.css`, `assets/rhwp_bg-DtQ01XFR.wasm`, fonts/icons/image asset이 존재한다. `samples/`는 존재하지 않는다.

```bash
$ rg -n "rhwp-studio|Resources" project.yml AlhangeulMac.xcodeproj/project.pbxproj Sources/HostApp scripts mydocs/tech/project_architecture.md
```

결과 요약:

- `project.yml`에 `Resources/rhwp-studio` exclude 및 folder resource 항목이 있다.
- generated `project.pbxproj`에 `rhwp-studio in Resources` 항목이 있다.
- sync/verify script가 `Sources/HostApp/Resources/rhwp-studio`를 대상으로 한다.

```bash
$ xcodegen generate
Created project at /tmp/rhwp-mac-task134/AlhangeulMac.xcodeproj
```

결과: 성공.

## 잔여 위험

- `registerSW.js`, `sw.js`, `manifest.webmanifest`는 upstream PWA build 산출물이다. WKWebView file URL 환경에서 service worker/manifest가 실제로 필요한지와 실패 시 영향은 Stage 3에서 wrapper 구현 후 확인한다.
- bundled JS에는 일부 fallback font를 CDN URL로 참조하는 코드가 남아 있다. MVP 표시에는 bundled font fallback이 있으나, 완전 offline 정책이 필요하면 후속 단계에서 upstream asset patch 또는 network policy 조정을 검토해야 한다.
- 이번 단계는 정적 asset bundle 구성까지만 다뤘다. 실제 HWP/HWPX 문서 전달과 WKWebView navigation 제한은 Stage 3 범위다.

## 다음 단계 영향

Stage 3은 이 bundle resource를 기준으로 `RhwpStudioWebView`, resource locator, document scheme handler를 구현하면 된다. entrypoint는 `Sources/HostApp/Resources/rhwp-studio/index.html`이며, 문서 전달 기본 후보는 Stage 1에서 확정한 `alhangeul-document://current` custom scheme + `?url=` loader 방식이다.

## 승인 요청

Stage 2는 여기서 중단한다. 작업지시자 승인 후 Stage 3 `WKWebView wrapper와 문서 전달 브리지 구현`으로 진행한다.
