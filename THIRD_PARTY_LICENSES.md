# Third Party Licenses

이 문서는 Alhangeul macOS v0.1 release artifact에 포함되는 third-party code와 bundled asset의 attribution/provenance 기준을 정리한다. 저장소 자체 license는 `LICENSE`가 소유한다.

## 범위

현재 release artifact 고지는 실제 bundle과 lock 파일에 고정된 항목만 기준으로 한다.

- Rust core와 Web/WASM viewer asset은 `edwardkim/rhwp` `v0.7.10` release-tag snapshot 기준이다.
- `rhwp` upstream의 별도 GitHub Release 바이너리 asset은 Alhangeul app bundle에 포함하지 않는다.
- 한컴/HY/HCR/Microsoft proprietary font 파일은 저장소와 release artifact에 포함하지 않는다.

## rhwp core

이 프로젝트는 `RustBridge/Cargo.toml`에서 `rhwp`를 Cargo git dependency로 사용한다.

- Repository: https://github.com/edwardkim/rhwp
- License: MIT
- Ref kind: release-tag
- Release tag: `v0.7.10`
- Resolved commit: `62a458aa317e962cd3d0eec6096728c172d57110`
- Provenance: `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`

`Sources/RhwpCoreBridge`의 일부 Swift bridge 코드는 upstream iOS viewer 구현에서 출발했으며, 현재 macOS bridge와 renderer 정책은 이 저장소에서 유지보수한다.

## Rust bridge generated artifacts

다음 산출물은 `rhwp` core와 이 저장소의 `RustBridge` build output이다.

- `Frameworks/universal/librhwp.a`
- `Frameworks/generated_rhwp.h`

각 산출물의 sha256과 size는 `rhwp-core.lock`의 `[[artifacts]]` 항목을 기준으로 한다.

## Bundled rhwp-studio static assets

HostApp WKWebView viewer는 app bundle의 `Sources/HostApp/Resources/rhwp-studio` 정적 asset을 사용한다. 이 asset은 `edwardkim/rhwp`의 `rhwp-studio/dist` output에서 복사한 것이다.

- Source repository: https://github.com/edwardkim/rhwp.git
- Ref kind: release-tag
- Release tag: `v0.7.10`
- Resolved commit: `62a458aa317e962cd3d0eec6096728c172d57110`
- Source path: `rhwp-studio/dist`
- Excluded path: `samples/`
- Provenance manifest: `Sources/HostApp/Resources/rhwp-studio/manifest.json`

`manifest.json`은 `index.html`, main JS/CSS, WASM entrypoint hash와 copied file count/bytes를 기록한다.

## Bundled fonts

HostApp bundle에는 `Sources/HostApp/Resources/rhwp-studio/fonts` 아래 WOFF2 font 35개가 포함된다. WebView viewer는 이 font를 CSS/WebFont로 사용하고, Swift native renderer는 같은 WOFF2를 CoreText process-local font로 등록해 fallback 후보로 재사용한다.

font별 또는 font family별 파일명, license, source, 대체 대상은 `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`가 소유한다.

## Proprietary fonts not bundled

HWP 문서에는 한컴, HY, HCR, Microsoft 계열 proprietary font name이 등장할 수 있다. 이 저장소와 release artifact는 해당 proprietary font 파일을 포함하지 않는다.

문서 표시에는 bundled WOFF2와 macOS system font fallback을 사용한다. native renderer fallback 정책은 `mydocs/tech/font_fallback_strategy.md`를 기준으로 한다.

## 법률 해석

이 문서는 attribution과 provenance를 정리한 운영 문서이며 법률 자문이 아니다. 배포 전 법적 해석이 필요한 경우 별도 검토 대상으로 분리한다.
