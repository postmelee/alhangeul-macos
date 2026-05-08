# Task #167 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#167 rhwp v0.7.10 stable tag 반영과 M16 release 기준 재검증](https://github.com/postmelee/alhangeul-macos/issues/167) |
| 마일스톤 | M016 / v0.1 출시 전 보강 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task167` |
| 작업 위치 | `/private/tmp/rhwp-mac-task167` |
| 단계 수 | 5단계 |
| 결론 | `rhwp` core, Rust bridge lock/artifact provenance, bundled `rhwp-studio` asset manifest, release 기준 문서를 `v0.7.10` Stable release tag 기준으로 정합화했다. HostApp Debug/Release build, native render smoke, asset 검증, no-AppKit 검증도 통과했다. |

## 최종 release 기준

### rhwp core

| 항목 | 값 |
|------|----|
| Release tag | `v0.7.10` |
| Published at | `2026-05-05T17:56:40Z` |
| Tag object | `2a6f59f1f64958ace5181f04cdf40cf77fa709b5` |
| Resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| Dependency | `RustBridge/Cargo.toml` `tag = "v0.7.10"` |
| Cargo source | `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.10#62a458aa317e962cd3d0eec6096728c172d57110` |

### Rust bridge artifact

| Artifact | sha256 | size |
|----------|--------|------|
| `Frameworks/universal/librhwp.a` | `fefa08d741cfdd6645081ca838601f677f6da064d95308555e29629f7609f7a2` | `107120120` |
| `Frameworks/generated_rhwp.h` | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` | `1349` |

`rhwp-ffi-symbols.txt`는 변경되지 않았다. 따라서 Swift bridge C ABI surface는 이번 core update에서 유지되었다.

### bundled rhwp-studio

| 항목 | 값 |
|------|----|
| Source release tag | `v0.7.10` |
| Source resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| WASM build command | `docker-compose --env-file .env.docker run --rm wasm` |
| Studio build command | `npx tsc && npx vite build --base ./` |
| Copied file count | `54` |
| Copied total bytes | `28412739` |
| `index.html` sha256 | `6f6de3327714df769695875cdcada550b49532c3e8950494eb2bb048f954e32b` |
| Main JS | `assets/index-BN69C-Lp.js` / `594133fe7dbe7464af580f573dbddf71c8c251cf0e27311694256c3050a7ecd6` |
| Main CSS | `assets/index-ro3nVBB2.css` / `d669a5f84fd2945f4d6be9a5471d6d2782ff629f77658a73f6f5d0f1133d7179` |
| WASM | `assets/rhwp_bg-BZNodj2e.wasm` / `bdfbd391aa8f4204ff517938fc5b1ad83bb810c80de59f97a72e2be95b9e56fe` |

HostApp resource에는 WOFF2 font 35개가 포함된다. `SourceHanSerifK-OldHangul-subset.woff2`와 `SourceHanSerifK-OFL.txt`를 추가했고, Swift native renderer도 `FontResourceRegistry` allowlist를 통해 이 asset을 등록한다.

## 변경 파일 목록과 영향 범위

| 파일/영역 | 내용 |
|-----------|------|
| `RustBridge/Cargo.toml` | `rhwp` dependency를 `v0.7.10` tag로 갱신 |
| `RustBridge/Cargo.lock` | Cargo resolved source를 `62a458aa317e962cd3d0eec6096728c172d57110`으로 갱신 |
| `rhwp-core.lock` | release tag, resolved commit, artifact hash/size를 `v0.7.10` 기준으로 갱신 |
| `Sources/HostApp/Resources/rhwp-studio/**` | `v0.7.10` build output으로 static asset, manifest, entrypoint, WASM, JS/CSS를 정합화 |
| `scripts/sync-rhwp-studio.sh` | `v0.7.10` 기준 commit 검증, file mode 정규화, local overlay manifest 기록, WKWebView override CSS 삽입을 보강 |
| `scripts/verify-rhwp-studio-assets.sh` | `v0.7.10` tag/commit과 local override CSS link 검증을 보강 |
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | old Hangul fallback WOFF2 allowlist 추가 |
| `THIRD_PARTY_LICENSES.md`, `FONTS.md`, `font_fallback_strategy.md` | `v0.7.10` asset과 WOFF2 35개 기준으로 고지 갱신 |
| `README.md`, `mydocs/tech/project_architecture.md`, `mydocs/tech/core_release_compatibility.md`, `mydocs/manual/core_dependency_operation_guide.md`, `mydocs/manual/build_run_guide.md` | 살아있는 release/core/viewer 기준 문서를 `v0.7.10`으로 보정 |
| `mydocs/plans/task_m016_167*.md`, `mydocs/working/task_m016_167_stage*.md` | 하이퍼-워터폴 계획과 단계 보고 기록 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `0293885` | 수행계획서와 오늘할일 항목을 작성했다. |
| 구현계획 | `15e1f70` | 5단계 구현계획서를 작성했다. |
| Stage 1 | `3563b32` | `v0.7.10` release tag, resolved commit, compatibility gate, `rhwp-studio` sync 경로를 확인했다. |
| Stage 2 | `e69ec41` | core dependency, Cargo lock, `rhwp-core.lock`, Rust bridge artifact hash/size를 `v0.7.10` 기준으로 갱신했다. |
| Stage 3 | `264e287` | bundled `rhwp-studio` asset과 manifest를 `v0.7.10` 기준으로 동기화했다. |
| Stage 4 | `e777c4f` | HostApp Debug/Release build, native render smoke, release 기준 문서 보정을 완료했다. |
| 통합 브랜치 병합 | `a88466e` | #145가 merge된 최신 `origin/devel-webview`를 병합하고 오늘할일 충돌을 해결했다. |
| Stage 5 | 이번 최종 보고 커밋 | 최종 보고서, Stage 5 보고서, 오늘할일 완료 처리를 정리한다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `gh release view -R edwardkim/rhwp v0.7.10 --json tagName,publishedAt,url` | OK | release tag와 published date 확인 |
| `git ls-remote refs/tags/v0.7.10` | OK | tag object와 peeled commit 확인 |
| `./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.10` | OK | required API gate 통과 |
| `./scripts/build-rust-macos.sh --update-lock` | OK | Rust bridge artifact와 `rhwp-core.lock` 갱신 |
| `./scripts/build-rust-macos.sh --verify-lock` | OK | artifact hash/size lock 검증 |
| `rhwp-ffi-symbols.txt` diff | OK | 변경 없음 |
| `scripts/verify-rhwp-studio-assets.sh` | OK | `v0.7.10` manifest와 resource 구조 검증 |
| `./scripts/check-no-appkit.sh` | OK | shared Swift code boundary 유지 |
| `xcodegen generate` | OK | tracked project diff 없음 |
| HostApp Debug build | OK | `** BUILD SUCCEEDED ** [14.016 sec]` |
| HostApp Release build | OK | `** BUILD SUCCEEDED ** [26.801 sec]` |
| Debug app bundle asset check | OK | index, main JS, WASM, override CSS, WOFF2 35개 확인 |
| `./scripts/validate-stage3-render.sh` | OK | `KTX.hwp`, `request.hwp`, `exam_kor.hwp` native render smoke 통과 |
| 작업지시자 직접 앱 실행 확인 | OK | Debug build app 실행 후 동작 확인 |
| stale 기준 검색 | OK | 살아있는 기준 문서와 스크립트에서 `v0.7.9`, 이전 commit, 이전 WASM 파일명 검색 결과 없음 |
| `git diff --check` | OK | whitespace error 없음 |

Stage 4 build 중 Xcode/CoreSimulator 관련 sandbox 경고가 출력되었지만 Debug/Release build는 모두 성공했다. `validate-stage3-render.sh`에서는 기존 native renderer layout overflow 진단 로그가 일부 샘플에서 출력되지만 명령은 exit code 0으로 완료했다.

## Handoff

| 후속 이슈 | 기준 |
|----------|------|
| #145 | release artifact/provenance 문서는 `rhwp-core.lock`과 `rhwp-studio/manifest.json` 모두 `v0.7.10` / `62a458aa317e962cd3d0eec6096728c172d57110` 기준으로 이어받는다. #145의 기존 `v0.7.9` inventory 내용은 이 작업 결과로 대체되는 기준이다. |
| #151 | 설치본 smoke gate는 이 작업의 Debug/Release build 통과와 asset 검증 결과를 전제로 진행한다. 실제 `package-release`, LaunchServices/PlugInKit 등록, `qlmanage` 판정은 #151에서 수행한다. |
| #146 | Viewer known limitations는 WKWebView `rhwp-studio v0.7.10` 경로와 native renderer smoke 결과를 기준으로 문서화한다. native renderer parity 개선은 이번 작업 범위가 아니다. |
| #166 | core bump, Rust bridge artifact 재생성, bundled `rhwp-studio` sync를 반복하지 않는다. #166은 이 작업 결과를 release artifact 입력으로 확인하고 실제 package/signing/notarization/publish 절차에 집중한다. |

## 잔여 위험과 제외 범위

| 구분 | 내용 |
|------|------|
| 설치본 extension smoke | Debug/Release build는 통과했지만 설치본 기준 Quick Look/Thumbnail smoke는 #151 범위로 남겼다. |
| 실제 public release | GitHub Release 게시, Developer ID signing/notarization, Homebrew Cask checksum 교체는 수행하지 않았다. |
| native renderer parity | `v0.7.10` smoke는 통과했지만 WebView와 native renderer의 시각 동등성 개선은 후속 milestone 범위다. |
| npm transitive license | bundled `rhwp-studio` JS/CSS/WASM의 npm transitive dependency license manifest는 이번 범위에 새로 만들지 않았다. |
| upstream source | `edwardkim/rhwp` source는 수정하지 않았다. |

## 작업지시자 승인 요청

Task #167의 `rhwp v0.7.10` stable tag 반영과 M16 release 기준 재검증을 완료했다. 다음 단계는 `publish/task167` 브랜치 push와 `devel-webview` 대상 PR 생성 승인이다.
