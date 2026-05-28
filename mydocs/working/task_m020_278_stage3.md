# Task M020 #278 Stage 3 완료 보고서

## 단계 목적

bundled `rhwp-studio` WebView reference renderer를 upstream `rhwp` `v0.7.13` 기준으로 동기화했다. Stage 2에서 native core는 이미 `v0.7.13`으로 올라갔으므로, 이번 단계의 목적은 visual diff reference와 WebView viewer가 같은 release provenance를 가리키게 하는 것이다.

## 산출물

동기화 대상:

- `Sources/HostApp/Resources/rhwp-studio/**`

주요 변경:

| 항목 | v0.7.12 | v0.7.13 |
| --- | --- | --- |
| release tag | `v0.7.12` | `v0.7.13` |
| resolved commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| copied file count | `54` | `57` |
| copied total bytes | `28,579,739` | `36,462,802` |
| main JS | `assets/index-DRLw2Nmm.js` | `assets/index-DokHBifW.js` |
| main CSS | `assets/index-C_SbAHsx.css` | `assets/index-Dp_1IBLX.css` |
| rhwp WASM | `assets/rhwp_bg-2AkAqrUl.wasm` | `assets/rhwp_bg-BPam6dJo.wasm` |

변경 파일 상태:

```text
D  3
M  5
?? 6
```

새 asset 목록:

```text
canvaskit-DB1zH3nD.wasm
canvaskit-renderer-Dz1dV4AX.js
index-DokHBifW.js
index-Dp_1IBLX.css
rhwp_bg-BPam6dJo.wasm
```

`rhwp_bg.wasm.d.ts`도 새로 번들에 포함됐다.

## build 준비 과정

처음에는 기존 `/private/tmp/rhwp-upstream-v0713` checkout을 사용하려 했지만 `pkg/`와 `rhwp-studio/dist`가 준비되어 있지 않았다.

Docker 경로 시도:

1. `/private/tmp/rhwp-upstream-v0713`에서 `docker-compose --env-file .env.docker run --rm wasm` 실행
2. Docker mount 안의 `/app`에서 `Cargo.toml`을 찾지 못해 실패
3. checkout을 `build.noindex/rhwp-upstream-v0713`로 복사 후 재실행
4. 이번에는 WASM compile까지 진행됐지만 `rhwp` crate compile 중 `SIGKILL`로 실패

실패 원인 판단:

- 첫 실패는 `/private/tmp` 경로 mount 문제로 판단했다.
- 두 번째 실패는 Docker/Colima 컨테이너 메모리 제한에 의한 `rustc` kill로 판단했다.

fallback:

```bash
rustup target add wasm32-unknown-unknown
cargo install wasm-pack@0.15.0
wasm-pack build --target web
```

host `wasm-pack` 빌드는 성공했다.

```text
Done in 1m 47s
Your wasm pkg is ready to publish at .../build.noindex/rhwp-upstream-v0713/pkg.
```

이후 `rhwp-studio` dist를 생성했다.

```bash
npm ci
npx tsc && npx vite build --base ./
```

Vite build 결과:

```text
dist/assets/rhwp_bg-BPam6dJo.wasm           5,062.20 kB
dist/assets/canvaskit-DB1zH3nD.wasm         7,159.34 kB
dist/assets/index-Dp_1IBLX.css                 67.07 kB
dist/assets/canvaskit-renderer-Dz1dV4AX.js    143.00 kB
dist/assets/index-DokHBifW.js                 843.93 kB
precache  53 entries (23508.65 KiB)
```

`npm ci`는 완료됐지만 `1 moderate severity vulnerability`를 보고했다. 이번 단계는 upstream release asset sync가 목적이므로 npm dependency 수정을 하지 않았다.

## sync 결과

실행 명령:

```bash
./scripts/sync-rhwp-studio.sh \
  --upstream-dir build.noindex/rhwp-upstream-v0713 \
  --tag v0.7.13 \
  --commit b3e16ef212af81ef37d973ddb86d6816d3804642
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac-task278/Sources/HostApp/Resources/rhwp-studio
OK: rhwp-studio synced to /Users/melee/Documents/projects/rhwp-mac-task278/Sources/HostApp/Resources/rhwp-studio from v0.7.13 at b3e16ef212af81ef37d973ddb86d6816d3804642
```

동기화 후 manifest:

```text
source_release_tag = v0.7.13
source_resolved_commit = b3e16ef212af81ef37d973ddb86d6816d3804642
main_js = assets/index-DokHBifW.js
main_css = assets/index-Dp_1IBLX.css
wasm = assets/rhwp_bg-BPam6dJo.wasm
wasm sha256 = 6de7b5ae2b0ddc9640558ea6124e6b04ed724aec9bf12e75b7bddfc992618708
```

## 보존 확인

local overlay는 보존됐다.

```text
overlay-css-ok
fonts-md-ok
```

`index.html`은 WKWebView용 override CSS를 계속 로드한다.

```html
<link rel="stylesheet" href="./alhangeul-wkwebview-overrides.css">
```

`crossorigin` attribute는 제거되어 있고, `samples/`는 HostApp bundle resource에 포함되지 않았다.

## 검증 결과

실행한 검증:

```bash
./scripts/verify-rhwp-studio-assets.sh
git diff --check
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac-task278/Sources/HostApp/Resources/rhwp-studio
```

`git diff --check`도 통과했다.

## 잔여 위험

- manifest의 `wasm_build_command`는 upstream 표준 절차인 Docker command를 기록하지만, 이번 로컬 Stage 3 산출물은 Docker 메모리 실패 때문에 host `wasm-pack` fallback으로 만들었다. 산출물 hash는 manifest에 기록됐으므로 현재 번들 자체의 정합성은 검증되지만, Docker 표준 빌드와 byte-identical 여부는 확인하지 못했다.
- `npm ci`가 `1 moderate severity vulnerability`를 보고했다. upstream release dependency를 그대로 사용하기 위해 이번 작업에서는 수정하지 않았다.
- Stage 3는 asset sync 검증까지만 수행했다. HostApp build, Quick Look/Thumbnail smoke, visual diff baseline은 Stage 4에서 실행한다.

## 다음 단계 영향

이제 core와 bundled `rhwp-studio`가 모두 `v0.7.13` / `b3e16ef212af81ef37d973ddb86d6816d3804642` 기준이다. Stage 4 visual diff는 더 이상 `v0.7.13` native core와 `v0.7.12` WebView reference를 비교하지 않는다.

Stage 4에서는 다음을 확인한다.

- `xcodegen generate`
- HostApp Debug build
- Quick Look/Thumbnail Skia policy smoke
- visual diff harness
- overlay metadata smoke

## 승인 요청

Stage 4로 진행하려면 앱 빌드와 Quick Look/Thumbnail smoke를 실행한다.
