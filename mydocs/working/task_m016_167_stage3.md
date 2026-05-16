# Task M016 #167 Stage 3 보고서

## 단계 목적

Stage 2에서 `rhwp` core lock을 `v0.7.10`으로 올린 뒤 남아 있던 bundled `rhwp-studio` resource/manifest 기준 불일치를 해소한다. HostApp WKWebView viewer가 bundle에서 로드하는 static asset, WASM, manifest, font/license 고지, sync/verify script를 모두 `v0.7.10` 기준으로 맞춘다.

## 산출물

| 파일 | 라인 수 또는 요약 | 내용 |
|------|------------------|------|
| `Sources/HostApp/Resources/rhwp-studio/**` | 55 files | `rhwp-studio` v0.7.10 dist/WASM resource tree |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | 37 | v0.7.10 tag/commit, entrypoint hash, local overlay 기록 |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | 82 | v0.1 bundle font 고지 유지, Source Han Serif K 추가 |
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | 188 | 새 WOFF2 `SourceHanSerifK-OldHangul-subset.woff2` 등록 allowlist 반영 |
| `THIRD_PARTY_LICENSES.md` | 63 | core/studio provenance를 v0.7.10과 WOFF2 35개 기준으로 갱신 |
| `mydocs/tech/font_fallback_strategy.md` | 62 | bundled WOFF2 35개와 Source Han Serif K 반영 |
| `scripts/sync-rhwp-studio.sh` | 106 | v0.7.10 기준 sync, local overlay 보존, file mode 정규화 |
| `scripts/verify-rhwp-studio-assets.sh` | 49 | v0.7.10 commit/tag와 local override stylesheet 검증 |
| `mydocs/working/task_m016_167_stage3.md` | 257 | Stage 3 갱신/검증 결과 |
| `mydocs/orders/20260506.md` | 17 | #167 상태를 Stage 4 승인 대기로 갱신 |

## 본문 변경 정도 / 본문 무손실 여부

bundled `rhwp-studio` resource는 upstream `v0.7.10` build output으로 교체했다. 기존 Alhangeul-specific WKWebView override stylesheet와 #147에서 정리한 `FONTS.md` 고지는 upstream dist 복사 중 사라지면 안 되는 local overlay로 분리해 보존했다.

제품 Swift 코드는 새 bundled WOFF2가 native renderer font registration에서 누락되지 않도록 `FontResourceRegistry.swift` allowlist에 한 줄만 추가했다. `Sources/RhwpCoreBridge`에 AppKit/UIKit 의존은 추가하지 않았다.

## 실행 기록

### upstream checkout과 Docker path 이슈

처음에는 task worktree 내부의 `/private/tmp/rhwp-mac-task167/build.noindex/rhwp-upstream-task167` checkout으로 Docker WASM build를 시도했지만, Docker/Colima bind mount가 `/private/tmp` 경로를 컨테이너의 `/app`에 빈 디렉터리로 노출했다.

```text
$ docker-compose --env-file .env.docker run --rm wasm
Error: crate directory is missing a `Cargo.toml` file; is `.` the wrong directory?
```

확인:

```text
$ docker-compose --env-file .env.docker run --rm wasm ls -la /app
total 8
drwxr-xr-x 2 root root 4096 May  6 08:39 .
drwxr-xr-x 1 root root 4096 May  6 08:40 ..
```

따라서 tracked 파일을 건드리지 않는 ignored directory인 `/Users/melee/Documents/projects/rhwp-mac/build.noindex/rhwp-upstream-task167`에 같은 upstream tag를 다시 checkout해 Docker build input으로 사용했다.

```text
$ git -C /Users/melee/Documents/projects/rhwp-mac/build.noindex/rhwp-upstream-task167 rev-parse HEAD
62a458aa317e962cd3d0eec6096728c172d57110

$ docker-compose --env-file .env.docker run --rm wasm ls -la /app
... Cargo.toml, rhwp-studio/, src/, docker-compose.yml 확인 ...
```

### WASM build

```text
$ docker-compose --env-file .env.docker run --rm wasm
[INFO]: Checking for the Wasm target...
[INFO]: Compiling to Wasm...
   Compiling rhwp v0.7.10 (/app)
    Finished `release` profile [optimized] target(s) in 43.31s
[INFO]: Installing wasm-bindgen...
[INFO]: Optimizing wasm binaries with `wasm-opt`...
[INFO]: :-) Done in 1m 07s
[INFO]: :-) Your wasm pkg is ready to publish at /app/pkg.
```

### studio dist build

```text
$ npm ci
added 430 packages, and audited 431 packages in 2s
1 moderate severity vulnerability
```

`npm ci`의 vulnerability warning은 upstream `rhwp-studio/package-lock.json` 기준 dependency 상태다. Stage 3에서는 upstream lockfile을 수정하지 않았다.

```text
$ npx tsc
통과

$ npx vite build --base ./
vite v8.0.10 building client environment for production...
dist/registerSW.js                     0.13 kB
dist/manifest.webmanifest              0.60 kB
dist/index.html                       55.17 kB
dist/assets/rhwp_bg-BZNodj2e.wasm  4,535.95 kB
dist/assets/index-ro3nVBB2.css        59.69 kB
dist/assets/index-BN69C-Lp.js        687.42 kB
✓ built in 818ms
PWA v1.2.0
precache  52 entries (23192.43 KiB)
```

### sync script 보강과 동기화

기존 `scripts/sync-rhwp-studio.sh`에는 두 가지 문제가 있었다.

- `EXPECTED_COMMIT`과 manifest `source_release_tag`가 v0.7.9로 hardcode되어 있었다.
- `crossorigin` 제거 perl 치환식이 `s/pattern/replacement/g` 형태가 아니라 sync 중 실패했다.

이번 단계에서 수정한 sync 기준:

- `EXPECTED_RELEASE_TAG="v0.7.10"`
- `EXPECTED_COMMIT="62a458aa317e962cd3d0eec6096728c172d57110"`
- `samples/`, `alhangeul-wkwebview-overrides.css`, `fonts/FONTS.md`는 rsync 제외
- resource file mode는 `0644`로 정규화
- `index.html`에 Alhangeul WKWebView override stylesheet link가 없으면 자동 삽입
- manifest에 `local_overlay_paths`로 overlay 파일을 기록

최종 sync:

```text
$ scripts/sync-rhwp-studio.sh /Users/melee/Documents/projects/rhwp-mac/build.noindex/rhwp-upstream-task167
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task167/Sources/HostApp/Resources/rhwp-studio
```

## manifest 결과

`Sources/HostApp/Resources/rhwp-studio/manifest.json` 핵심 값:

```text
source_release_tag: v0.7.10
source_resolved_commit: 62a458aa317e962cd3d0eec6096728c172d57110
copied_file_count: 54
copied_total_bytes: 28412739
local_overlay_paths: alhangeul-wkwebview-overrides.css, fonts/FONTS.md
index_html: index.html / 6f6de3327714df769695875cdcada550b49532c3e8950494eb2bb048f954e32b
main_js: assets/index-BN69C-Lp.js / 594133fe7dbe7464af580f573dbddf71c8c251cf0e27311694256c3050a7ecd6
main_css: assets/index-ro3nVBB2.css / d669a5f84fd2945f4d6be9a5471d6d2782ff629f77658a73f6f5d0f1133d7179
wasm: assets/rhwp_bg-BZNodj2e.wasm / bdfbd391aa8f4204ff517938fc5b1ad83bb810c80de59f97a72e2be95b9e56fe
```

resource tree count:

```text
$ find Sources/HostApp/Resources/rhwp-studio -maxdepth 3 -type f | sort | wc -l
      55

$ find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | sort | wc -l
      35
```

entrypoint size:

```text
Sources/HostApp/Resources/rhwp-studio/index.html 55219
Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js 687421
Sources/HostApp/Resources/rhwp-studio/assets/index-ro3nVBB2.css 59693
Sources/HostApp/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm 4535953
```

## 주요 변경 요약

### asset 변화

- 삭제: `assets/index-CCXookfl.js`, `assets/rhwp_bg-DtQ01XFR.wasm`
- 추가: `assets/index-BN69C-Lp.js`, `assets/rhwp_bg-BZNodj2e.wasm`
- 추가: `rhwp.d.ts`
- 추가: `fonts/SourceHanSerifK-OldHangul-subset.woff2`
- 추가: `fonts/SourceHanSerifK-OFL.txt`
- 유지: `assets/index-ro3nVBB2.css`
- 유지: `alhangeul-wkwebview-overrides.css`와 index stylesheet link

### font/license 변화

`rhwp-studio` v0.7.10 dist에 Source Han Serif K Old Hangul subset WOFF2와 OFL text가 추가됐다. 이에 맞춰:

- `FONTS.md`에 Source Han Serif K row 추가
- `FontResourceRegistry.swift` allowlist에 `SourceHanSerifK-OldHangul-subset.woff2` 추가
- `THIRD_PARTY_LICENSES.md`의 core/studio tag/commit과 WOFF2 count를 v0.7.10/35개로 갱신
- `font_fallback_strategy.md`에 WOFF2 35개와 Source Han Serif K 계열을 반영

## 검증 결과

### asset verifier

```text
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task167/Sources/HostApp/Resources/rhwp-studio
```

검증 항목:

- 필수 파일: `index.html`, `manifest.json`, `registerSW.js`, `manifest.webmanifest`
- Alhangeul overlay: `alhangeul-wkwebview-overrides.css`, index link
- main JS/CSS/WASM 각 1개
- `samples/` 미포함
- relative JS/CSS asset path
- `crossorigin` 제거
- manifest tag/commit이 v0.7.10 기준과 일치
- relative-base build command 기록

### provenance 검색

```text
$ rg -n "v0\.7\.9|0fb3e6758b8ad11d2f3c3849c83b914684e83863|DtQ01XFR|CCXookfl" \
  Sources/HostApp/Resources/rhwp-studio THIRD_PARTY_LICENSES.md \
  mydocs/tech/font_fallback_strategy.md scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
출력 없음
```

```text
$ rg -n "BZNodj2e|BN69C-Lp|SourceHanSerifK|local_overlay_paths|alhangeul-wkwebview-overrides" \
  Sources/HostApp/Resources/rhwp-studio/manifest.json \
  Sources/HostApp/Resources/rhwp-studio/index.html \
  Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md \
  Sources/RhwpCoreBridge/FontResourceRegistry.swift \
  scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
Sources/HostApp/Resources/rhwp-studio/index.html:10:  <script type="module" src="./assets/index-BN69C-Lp.js"></script>
Sources/HostApp/Resources/rhwp-studio/index.html:12:  <link rel="stylesheet" href="./alhangeul-wkwebview-overrides.css">
Sources/RhwpCoreBridge/FontResourceRegistry.swift:53:        "SourceHanSerifK-OldHangul-subset.woff2",
Sources/HostApp/Resources/rhwp-studio/manifest.json:13:  "local_overlay_paths": [
Sources/HostApp/Resources/rhwp-studio/manifest.json:25:      "path": "assets/index-BN69C-Lp.js",
Sources/HostApp/Resources/rhwp-studio/manifest.json:33:      "path": "assets/rhwp_bg-BZNodj2e.wasm",
Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md:48:| SourceHanSerifK-OldHangul-subset.woff2 | Source Han Serif K Old Hangul subset | SIL OFL 1.1 | Adobe Source Han Serif | 옛한글/세리프 보조 |
```

### shared Swift boundary

```text
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

### whitespace

```text
$ git diff --check
통과
```

## 잔여 위험

- Stage 3는 bundled asset 구조 검증까지 수행했다. HostApp Debug build, bundle 포함 확인, WKWebView render smoke는 Stage 4에서 이어서 수행해야 한다.
- `npm ci`는 upstream lockfile 기준 `1 moderate severity vulnerability`를 보고했다. 이번 작업은 upstream dependency 변경이 아니라 `v0.7.10` release artifact sync이므로 lockfile 수정은 하지 않았다.
- `mydocs/manual/build_run_guide.md`와 README에는 이전 WASM asset filename 또는 `v0.7.9` reference가 남아 있을 수 있다. Stage 4의 release 기준 문서 연결에서 stale reference를 정리한다.
- `/Users/melee/Documents/projects/rhwp-mac/build.noindex/rhwp-upstream-task167`와 `/private/tmp/rhwp-mac-task167/build.noindex/rhwp-upstream-task167`은 ignored build input이다. commit 대상이 아니다.

## 다음 단계 영향

Stage 4에서는 다음을 확인한다.

- `xcodegen generate`
- Debug HostApp build
- app bundle 안의 `rhwp-studio` v0.7.10 asset 포함 여부
- `./scripts/validate-stage3-render.sh`
- release/manual/README stale reference 정리
- 필요 시 package/release build 후보 검증

## 승인 요청

Stage 3 완료를 보고한다. 승인 후 Stage 4 `build/render 검증과 release 기준 문서 연결`로 진행한다.
