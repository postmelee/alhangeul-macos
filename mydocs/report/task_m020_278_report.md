# Task M020 #278 최종 결과 보고서

## 작업 요약

| 항목 | 내용 |
| --- | --- |
| 이슈 | [#278 rhwp 새 release tag 반영 후 Skia Quick Look/Thumbnail upstream 회귀 확인](https://github.com/postmelee/alhangeul-macos/issues/278) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task278` |
| 대상 upstream | `edwardkim/rhwp` `v0.7.13` |
| resolved commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| 단계 수 | 5단계 |

목표는 upstream `rhwp` stable release `v0.7.13`을 앱 저장소의 core provenance 기준으로 반영하고, bundled `rhwp-studio` reference와 Quick Look/Thumbnail renderer smoke를 같은 release 기준으로 다시 맞추는 것이었다.

결론:

- Rust core dependency와 `rhwp-core.lock`을 `v0.7.13` release tag + resolved commit 기준으로 갱신했다.
- bundled `rhwp-studio`도 `v0.7.13` asset으로 동기화해 visual diff reference와 native core 기준을 일치시켰다.
- FFI symbol set과 generated header hash는 변경되지 않아 Swift bridge 호출부 수정은 필요하지 않았다.
- Skia opt-in 경로는 두 대표 샘플에서 CoreGraphics 대비 changed pixel 비율을 낮췄지만, diff가 여전히 두 자릿수이고 `request.hwp` 첫 렌더 시간이 크게 느려 기본 전환 근거로는 부족하다.
- #282는 #278 merge 후 최신 `devel`에 재정렬하고, `v0.7.13` PageLayerTree image node의 resolved payload와 embedded bytes availability를 기준으로 이어가는 것이 맞다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
| --- | --- |
| `RustBridge/Cargo.toml` | `rhwp` dependency tag를 `v0.7.12`에서 `v0.7.13`으로 갱신 |
| `RustBridge/Cargo.lock` | `rhwp`와 일부 transitive dependency resolved source 갱신 |
| `rhwp-core.lock` | release tag, resolved commit, static library hash/size, build timestamp 갱신 |
| `Sources/HostApp/Resources/rhwp-studio/**` | bundled WebView reference renderer asset을 `v0.7.13` 기준으로 교체 |
| `scripts/sync-rhwp-studio.sh` | `recommended_wasm_build_command`와 `actual_wasm_build_command` manifest 기록 지원 |
| `scripts/verify-rhwp-studio-assets.sh` | WASM build command provenance 필드 검증 추가 |
| `mydocs/plans/task_m020_278.md` | 수행계획서 추가 |
| `mydocs/plans/task_m020_278_impl.md` | 단계별 구현계획서 추가 |
| `mydocs/working/task_m020_278_stage1.md` | release provenance와 영향 범위 조사 보고 |
| `mydocs/working/task_m020_278_stage2.md` | RustBridge/core lock 갱신 보고 |
| `mydocs/working/task_m020_278_stage3.md` | bundled `rhwp-studio` 동기화 보고 |
| `mydocs/working/task_m020_278_stage4.md` | build, smoke, visual diff, hygiene 검증 보고 |
| `mydocs/orders/20260528.md` | 오늘할일 완료 처리 |

전체 diff 규모:

| 항목 | 값 |
| --- | ---: |
| 변경 파일 | 27 |
| insertions | 1,728 |
| deletions | 112 |
| 새 `rhwp-studio` copied file count | 57 |
| 새 `rhwp-studio` copied total bytes | 36,462,802 |

## 변경 전·후 정량 비교

Core provenance:

| 항목 | 변경 전 | 변경 후 |
| --- | --- | --- |
| `rhwp` release tag | `v0.7.12` | `v0.7.13` |
| `rhwp` resolved commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| `librhwp.a` size | 200,488,800 | 203,436,808 |
| `librhwp.a` sha256 | `d0513faa5fddd6b1575a15756f74712686d68910a36614f61db9077caaec6360` | `e382867272a5b9fa5518c2e1a19a1f6fa1fae467627ca9dc67e19559a4fd3ffb` |
| `generated_rhwp.h` sha256 | `31ed496ccbe86082885a82c584166669e1913a552dba26556ef5182842959601` | `31ed496ccbe86082885a82c584166669e1913a552dba26556ef5182842959601` |
| FFI symbol set | 12 symbols | 12 symbols, 변경 없음 |

`librhwp.a` 크기 변화:

```text
+2,948,008 bytes
+1.47%
```

Bundled `rhwp-studio`:

| 항목 | 변경 전 | 변경 후 |
| --- | --- | --- |
| release tag | `v0.7.12` | `v0.7.13` |
| resolved commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| copied file count | 54 | 57 |
| copied total bytes | 28,579,739 | 36,462,802 |
| main JS | `assets/index-DRLw2Nmm.js` | `assets/index-DokHBifW.js` |
| main CSS | `assets/index-C_SbAHsx.css` | `assets/index-Dp_1IBLX.css` |
| rhwp WASM | `assets/rhwp_bg-2AkAqrUl.wasm` | `assets/rhwp_bg-BPam6dJo.wasm` |

Quick Look Skia policy smoke:

| File | Reply | Pages | CG backend | CG sec | Skia backend | Skia sec | Fallback |
| --- | --- | ---: | --- | ---: | --- | ---: | ---: |
| `request.hwp` | `png` | 1 | `skia:0,cg:1,embedded:0` | 0.990051 | `skia:1,cg:0,embedded:0` | 12.158348 | 0 |
| `hwpx-01.hwpx` | `pdf` | 9 | `skia:0,cg:9,embedded:0` | 0.358134 | `skia:9,cg:0,embedded:0` | 0.617731 | 0 |

Visual diff baseline:

| File | Native policy | Changed percent | Mean RGB delta | Native backend | Native ms |
| --- | --- | ---: | ---: | --- | ---: |
| `request.hwp` | CoreGraphics | 17.8542% | 11.0716 | `coreGraphics` | 961.7 |
| `request.hwp` | Skia | 12.8683% | 10.1453 | `skia` | 6240.1 |
| `hwpx-01.hwpx` | CoreGraphics | 15.0285% | 15.2088 | `coreGraphics` | 29.8 |
| `hwpx-01.hwpx` | Skia | 14.6452% | 16.0791 | `skia` | 64.4 |

CoreGraphics 대비 Skia 변화:

| File | Changed percent delta | Mean RGB delta 변화 | Native ms 변화 |
| --- | ---: | ---: | ---: |
| `request.hwp` | -4.9859 pp | -0.9263 | +5,278.4 ms |
| `hwpx-01.hwpx` | -0.3833 pp | +0.8703 | +34.6 ms |

Overlay metadata smoke:

| File | Upstream images | Overlay | Behind | Front | Tree images | Embedded availability |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `request.hwp` | 1 | 0 | 0 | 0 | 1 | 1/1 |
| `hwpx-01.hwpx` | 2 | 0 | 0 | 0 | 2 | 2/2 |
| `tac-img-02.hwp` | 1 | 0 | 0 | 0 | 1 | 1/1 |
| `tac-img-02.hwpx` | 1 | 0 | 0 | 0 | 1 | 1/1 |
| `hwp-img-001.hwp` | 4 | 0 | 0 | 0 | 4 | 4/4 |
| `img-start-001.hwp` | 0 | 0 | 0 | 0 | 0 | 0/0 |

## 단계별 결과

| Stage | 커밋 | 결과 |
| --- | --- | --- |
| 계획 | `c7fca15` | 수행계획서와 구현계획서를 작성하고 오늘할일을 등록 |
| Stage 1 | `b1afb04` | `v0.7.13` release/tag/resolved commit 확인, `v0.7.12..v0.7.13` viewer impact 확인 |
| Stage 2 | `4543a74` | Rust core dependency, Cargo lock, `rhwp-core.lock`을 `v0.7.13`으로 갱신 |
| Stage 3 | `4885636` | bundled `rhwp-studio` asset을 `v0.7.13` 기준으로 동기화 |
| Stage 4 | `014fee7` | HostApp Debug build, Quick Look smoke, visual diff, overlay metadata, registration hygiene 검증 |
| Stage 5 | 현재 | 최종 보고서와 오늘할일 완료 처리, PR 게시 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
| --- | --- | --- |
| `v0.7.13` release tag + resolved commit 고정 | OK | `rhwp-core.lock`, `RustBridge/Cargo.lock`, `rhwp-studio/manifest.json` 모두 `b3e16ef...` 기록 |
| RustBridge lock 검증 | OK | `./scripts/build-rust-macos.sh --verify-lock` 통과 |
| FFI ABI surface 유지 | OK | FFI symbol 12개 변경 없음, generated header hash 동일 |
| AppKit/UIKit shared dependency 금지 | OK | `./scripts/check-no-appkit.sh` 통과 |
| bundled `rhwp-studio` asset 정합성 | OK | `./scripts/verify-rhwp-studio-assets.sh` 통과 |
| HostApp Debug build | OK | `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 성공 |
| Quick Look Skia policy smoke | OK | CG/Skia 정책별 backend 선택과 fallback 0 확인 |
| Visual diff baseline | OK | CoreGraphics/Skia 양쪽 summary 생성 |
| Overlay metadata smoke | OK | 기본 sample set 통과 |
| 개발 산출물 registration hygiene | OK | `check-extension-registration-hygiene.sh --check-only` 최종 issue 없음 |
| whitespace 검증 | OK | `git diff --check` 통과 |

최종 단계에서 재실행한 검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh
git diff --check
```

Stage 4에서 실행한 smoke:

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task278 CODE_SIGNING_ALLOWED=NO build
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task278-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task278-visual-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task278-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/overlay-metadata-smoke.sh build.noindex/task278-overlay-metadata
./scripts/check-extension-registration-hygiene.sh --check-only
```

## 잔여 위험과 후속 작업

| 항목 | 내용 |
| --- | --- |
| Skia 기본 전환 | 아직 이르다. changed pixel 비율은 개선됐지만 두 샘플 모두 diff가 두 자릿수이고 `request.hwp` Skia 시간이 크게 느렸다. |
| #282 handoff | #278 merge 후 #282 branch를 최신 `devel`에 재정렬해야 한다. overlay/image compositor는 compact overlay metadata뿐 아니라 PageLayerTree image node의 resolved payload와 embedded bytes availability를 같이 봐야 한다. |
| Overlay positive fixture | 기본 sample set에서는 behind/front overlay positive case가 나오지 않았다. #282에서 positive fixture 확보가 필요하다. |
| Thumbnail 설치본 smoke | 이번 작업은 Debug build와 renderer smoke 중심이다. signed Release package 기반 `qlmanage -t` 설치본 smoke는 실행하지 않았다. |
| `rhwp-studio` build provenance | Docker 표준 WASM build가 로컬 컨테이너 메모리 문제로 실패해 host `wasm-pack` fallback으로 asset을 생성했다. manifest는 권장 Docker command와 실제 fallback command를 분리해 기록하고 hash를 검증하지만, Docker build와 byte-identical 여부는 확인하지 못했다. |
| npm advisory | upstream `rhwp-studio` 기준 `npm ci`가 `1 moderate severity vulnerability`를 보고했다. 이번 작업에서는 upstream release asset 동기화 목적상 dependency를 수정하지 않았다. |

## Handoff

- #282는 이 PR merge 후 `devel` 최신 기준으로 재정렬한 다음 Stage 3를 이어간다.
- Swift renderer 쪽에서 core 변경을 복제하기보다 `v0.7.13` PageLayerTree의 `displayText`, image `resolved` payload, embedded image bytes availability를 소비하는 쪽이 유지보수 비용이 낮다.
- Skia opt-in smoke 산출물은 다음 위치에서 확인할 수 있다.
  - `build.noindex/task278-skia-policy`
  - `build.noindex/task278-visual-basic`
  - `build.noindex/task278-visual-skia`
  - `build.noindex/task278-overlay-metadata`
- PR 리뷰에서는 `rhwp-core.lock`, `RustBridge/Cargo.lock`, `rhwp-studio/manifest.json` provenance 일치와 Stage 4 수치 해석을 우선 확인하면 된다.

## 작업지시자 승인 요청

최종 보고서 작성과 오늘할일 완료 처리를 끝낸 뒤 `publish/task278` 원격 브랜치를 만들고 `devel` 대상 Open PR로 게시한다. PR merge 후에는 `pr-merge-cleanup` 절차로 이슈 close와 브랜치/worktree 정리를 진행한다.
