# Task M020 #418 Stage 4 보고서

## 단계 목적

Stage 3에서 통합한 `rhwp v0.7.18` core와 bundled studio 조합이 기존 RustBridge C ABI, HostApp, Quick Look Preview, Finder Thumbnail target과 compile/link되고 대표 HWP/HWPX 및 embedded image 렌더 경로를 회귀시키지 않는지 검증한다.

이번 단계는 runtime 검증 중 확인된 core build metadata 불일치를 현재 lock과 맞추는 최소 downstream 보정을 포함한다. public release, signed Finder 설치본 smoke, external image 제품 연결은 범위 밖이다.

## 산출물

| 파일/경로 | 변경 요약 |
|-----------|-----------|
| `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift` | 앱에 노출되는 core release tag와 resolved commit을 `v0.7.18` 기준으로 갱신 |
| `mydocs/working/task_m020_418_stage4.md` | ABI, build, render, visual baseline과 등록 정리 결과 기록 |
| `mydocs/orders/20260717.md` | #418을 Stage 4 완료 및 Stage 5 승인 대기로 갱신 |
| `build.noindex/task418-*` | render, policy smoke, visual baseline, 등록 diagnostics 산출물. ignored이며 commit하지 않음 |

## Downstream 보정

Stage 3 full sync에는 `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`가 포함되지 않아 첫 `verify-rhwp-core-build-info.sh` 실행이 다음 stale 값 때문에 실패했다.

```text
releaseTag: v0.7.17
commit: 03351190ec35436e58cbfee0aa9278a8fdc04a59
```

이를 `rhwp-core.lock` 및 studio manifest와 같은 값으로 갱신했다.

```text
releaseTag: v0.7.18
commit: 93862a4e16df59834ebce46d91e948cd739208e9
enabledFeatures: native-skia
```

수정 후 core build info 검증과 세 Xcode target build가 모두 통과했다. ABI나 renderer 동작 변경은 없다.

## RustBridge와 artifact 검증

| 검증 | 결과 |
|------|------|
| `cargo fmt --manifest-path RustBridge/Cargo.toml --check` | 통과 |
| `cargo check --manifest-path RustBridge/Cargo.toml --locked` | 통과 |
| `cargo test --manifest-path RustBridge/Cargo.toml --locked` | 4개 통과, 실패 0 |
| `./scripts/build-rust-macos.sh --verify-lock` | arm64/x86_64 universal archive, header, lock, 15개 symbol 일치 |
| `./scripts/check-no-appkit.sh` | shared Swift code에 AppKit/UIKit 의존 없음 |
| `./scripts/verify-rhwp-core-build-info.sh` | 보정 후 통과 |
| `./scripts/verify-rhwp-studio-assets.sh` | `v0.7.18` / `93862a4e...` asset과 manifest 통과 |

Rust unit test는 external reference loaded state, refs JSON owned string lifecycle, injection input/missing reference, filename context UTF-8와 handle validation을 포함한다.

## Xcode compile/link 결과

`xcodegen generate` 후 다음 세 무서명 Debug build가 모두 `BUILD SUCCEEDED`로 끝났다.

| scheme | DerivedData | 결과 |
|--------|-------------|------|
| `HostApp` | `build.noindex/DerivedData-task418-host` | 성공 |
| `QLExtension` | `build.noindex/DerivedData-task418-ql` | 성공 |
| `ThumbnailExtension` | `build.noindex/DerivedData-task418-thumbnail` | 성공 |

첫 HostApp/QLExtension sandbox 실행은 Sparkle 2.9.1 package 해석 중 DNS 제한으로 실패했다. 네트워크 접근이 가능한 동일 명령에서는 package 해석 후 compile/link가 성공했으므로 source 또는 ABI 실패가 아니다.

## Native render 회귀

### 기본 fixture

```bash
./scripts/validate-stage3-render.sh build.noindex/task418-render
```

| fixture | page size | textRuns | hangulRuns | hangulScalars | nonWhitePixels |
|---------|-----------|----------|------------|---------------|----------------|
| `KTX.hwp` | 1123x794 | 410 | 76 | 209 | 455,341 |
| `request.hwp` | 567x794 | 102 | 36 | 309 | 70,188 |
| `exam_kor.hwp` | 1123x1588 | 133 | 86 | 1,368 | 173,981 |

세 문서 모두 document open, render tree, 한글 glyph, page size, native PNG와 non-blank gate를 통과했다.

### Embedded image fixture

```bash
./scripts/validate-stage3-render.sh \
  build.noindex/task418-image samples/hwp-img-001.hwp
```

`hwp-img-001.hwp`는 794x1123, `textRuns=66`, `hangulRuns=35`, `hangulScalars=190`, `nonWhitePixels=57,024`로 통과했다. 생성 PNG를 직접 확인해 상단 정부 로고와 하단 기관/OPEN 로고가 출력되므로 기존 embedded image lookup과 bitmap 합성 경로가 유지됨을 확인했다.

## Quick Look과 Thumbnail 정책 smoke

Quick Look 대표 HWP/HWPX 3개는 모두 성공했다.

| fixture | reply/pages | CoreGraphics | Skia decode | Skia direct | fallback |
|---------|-------------|--------------|-------------|-------------|----------|
| `request.hwp` | PNG / 1 | `cg:1` | `skia:1` | `skia:1` | 0 |
| `KTX.hwp` | PNG / 1 | `cg:1` | `skia:1` | `skia:1` | 0 |
| `hwpx-01.hwpx` | PDF / 9 | `cg:9` | `skia:9` | 해당 없음 | 해당 없음 |

Thumbnail resolver는 `OK`였고 세 문서 각각 CoreGraphics/Skia 조합 8회, 총 24회 render가 실패 없이 끝났다. 각 정책에서 첫 요청은 `miss`, 같은 요청은 `exactHit`, 작은 요청은 `largerBucketHit(1024x1024)`로 기록돼 cache signature와 larger bucket reuse가 유지됐다.

## Visual baseline

`preview-renderer-baseline.sh build.noindex/task418-baseline` quick suite는 CoreGraphics와 Skia 정책 모두 5개 입력에서 exit code 0이었다. Studio reference는 전부 `domComposite;ui=clean`, native size drift는 전부 0px였다.

| sample | CG changed | Skia changed | Skia-CG | CG ms | Skia ms | 판정 |
|--------|------------|--------------|---------|-------|---------|------|
| `request.hwp` | 17.6976% | 11.6340% | -6.0636pp | 1070.0 | 50.6 | `warn:skia-changed` |
| `KTX.hwp` | 30.7744% | 46.2037% | +15.4293pp | 61.1 | 22.0 | `warn:skia-delta` |
| `복학원서.hwp` | 7.5013% | 7.0360% | -0.4653pp | 40.7 | 32.7 | `known-risk` |
| `hwp-multi-001.hwp` | 14.0349% | 13.9063% | -0.1286pp | 34.1 | 21.9 | `warn:skia-changed` |
| `hwpx-01.hwpx` | 14.0861% | 13.8750% | -0.2111pp | 29.1 | 18.4 | `warn:skia-changed` |

`KTX.hwp`의 `+15.4293pp`는 Task #396 기준 `+15.4874pp`와 같은 알려진 Skia default 전환 blocker sentinel이다. 이번 sync에서 새로 생긴 방향 변화나 추가 size drift는 아니다. 나머지 네 sample은 Skia가 changed percent와 native render 시간에서 CoreGraphics보다 낮았다.

첫 sandbox 실행은 WebKit, LaunchServices service 접근이 차단돼 studio readiness timeout이 발생했다. macOS service 접근이 가능한 동일 명령으로 재실행해 양 정책의 전체 run을 완료했으며 runtime timeout이나 render failure는 남지 않았다.

## 개발 등록 정리

Xcode의 `RegisterWithLaunchServices`가 세 DerivedData app을 발견 가능한 상태로 만들었으므로 표준 hygiene helper로 appex와 부모 app 등록을 해제하고 Quick Look cache를 reset했다.

helper의 app path 추출은 nested Sparkle `Updater.app` 경로를 부모 `Alhangeul.app`까지만 잘라 세 registration을 남겼다. 실제 등록된 세 `Updater.app`을 각각 `lsregister -u`로 해제한 뒤 check-only를 다시 실행했다.

최종 결과:

- development registration: 없음
- provider app root: `/Applications/Alhangeul.app` 한 곳
- legacy app/extension candidate: 없음
- development app bundle 파일은 `build.noindex`에 남지만 등록되지 않음

파일 삭제나 전역 LaunchServices reset은 수행하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경은 stale core provenance를 맞춘 `RhwpCoreBuildInfo.swift` 두 값뿐이다.
- RustBridge source, C header ABI, expected symbol 목록, renderer와 policy source는 변경하지 않았다.
- `xcodegen generate`는 generated `Alhangeul.xcodeproj`만 갱신했고 tracked project source diff는 없다.
- 빌드, PNG, diff, cache, diagnostics는 모두 ignored `build.noindex` 산출물이다.
- bundled studio generated asset과 local WKWebView overlay는 Stage 3 상태에서 무손실이다.

## 잔여 위험

- `KTX.hwp`의 Skia visual delta는 기존 sentinel과 같은 수준이며 해결되지 않았다. 따라서 Skia default 전환 근거로 사용할 수 없고 현재 opt-in 정책을 유지해야 한다.
- 이번 Xcode build는 unsigned compile/link gate다. signed 설치본의 Finder provider routing, HOP exact UTI, 실제 `qlmanage` output은 public release task의 manual blocking gate로 남는다.
- #408 external image C ABI unit test는 통과하지만 #409 Swift wrapper가 미완료이므로 알한글 제품에서 external linked image를 지원한다고 표현할 수 없다.
- registration hygiene helper의 nested `Updater.app` 경로 추출 한계는 수동 정리로 우회했다. helper 자체 보정은 별도 운영 개선 후보다.
- visual suite는 quick first-page 5종 기준이다. extended suite와 Intel 실기기 검증은 이번 단계에서 실행하지 않았다.

## 다음 단계 영향

Stage 5에서는 Stage 1~4 결과를 최종 보고서로 묶고 public release task가 사용할 previous release, version/build 후보, core/studio provenance, release note 경계와 blocking manual smoke를 확정한다. fresh automation PR #419와 branch의 cleanup 시점도 task PR merge 이후로 명시한다.

## 승인 요청

Stage 4 `ABI, 앱 target, 렌더 회귀 검증`은 완료됐다. Stage 5 `최종 보고와 public release handoff`로 진행하려면 작업지시자 승인이 필요하다.
