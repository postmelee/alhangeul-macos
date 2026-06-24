# Task M900 #378 Stage 3 완료보고서

## 단계 요약

`v0.1.7` release candidate source preflight, Debug build, render smoke, unsigned Release package, local rehearsal DMG 생성을 완료했다. public publish, Developer ID signing, notarization, stable Sparkle appcast, Pages deploy, Homebrew Cask 반영은 실행하지 않았다.

| 항목 | 결과 |
|------|------|
| App version | `0.1.7` |
| Build | `13` |
| rhwp tag | `v0.7.17` |
| rhwp commit | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| Release package zip | `build.noindex/release/alhangeul-macos-0.1.7.zip` |
| Rehearsal DMG | `build.noindex/release/alhangeul-macos-0.1.7-rehearsal.dmg` |

## Source preflight 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `git status --short --branch` | 통과 | `local/task378`, source 변경 없음 |
| `bash scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag` | 통과 | `v0.7.17` |
| `bash scripts/ci/read-rhwp-core-lock.sh rhwp_commit` | 통과 | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| `scripts/verify-rhwp-studio-assets.sh` | 통과 | bundled `rhwp-studio` asset 검증 |
| `plutil -lint` | 통과 | HostApp, Quick Look, Thumbnail plist 모두 OK |
| `./scripts/check-no-appkit.sh` | 통과 | `Sources/RhwpCoreBridge` AppKit/UIKit 의존 없음 |
| `xcodegen generate` | 통과 | generated project diff 없음 |

## Rust bridge 검증

`./scripts/build-rust-macos.sh --verify-lock`는 source provenance, `RustBridge/Cargo.lock`, generated header, FFI symbol 검증을 통과한 뒤 `Frameworks/universal/librhwp.a` byte hash/size에서 실패했다.

```text
Artifact: Frameworks/universal/librhwp.a
Expected sha256: 96f550e03ead0af52f8952bf013c9c997fb2c193e073f5f5fdbe647f0a9ef8a6
Actual sha256:   7545723577c72d66e1eabeb3ff27c2d8be670a4a3d0a2436e17fa770d4d49526
Expected size:   202902712
Actual size:     202925096
```

이는 `mydocs/manual/build_run_guide.md`와 #370 보고서에 문서화된 Rust static archive byte reproducibility 차이다. lock metadata는 갱신하지 않았다. 정책에 따라 다음 명령으로 staticlib byte hash/size만 제외하고 나머지 gate를 다시 확인했다.

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock
```

결과는 통과했다. 이 skip은 `Frameworks/universal/librhwp.a` byte-for-byte hash/size 비교만 제외하며, source provenance, `Cargo.lock`, generated header, FFI symbol 검증은 유지된다.

## Build와 render smoke

| 검증 | 결과 | 비고 |
|------|------|------|
| Debug build | 통과 | `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` |
| Native render smoke | 통과 | `./scripts/validate-stage3-render.sh` |

render smoke 결과:

| 샘플 | 결과 |
|------|------|
| `KTX.hwp` | page 1, `1123x794`, textRuns `410`, hangulRuns `76`, nonWhitePixels `455062` |
| `request.hwp` | page 1, `567x794`, textRuns `102`, hangulRuns `36`, nonWhitePixels `70189` |
| `exam_kor.hwp` | page 1, `1123x1588`, textRuns `133`, hangulRuns `86`, nonWhitePixels `173993` |

## Release package와 rehearsal

| 검증 | 결과 | 비고 |
|------|------|------|
| Release package | 통과 | `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/package-release.sh 0.1.7` |
| Universal app check | 통과 | Host app, Preview appex, Thumbnail appex 모두 `x86_64 arm64` |
| Built app version | 통과 | Host app `0.1.7 (13)` |
| Built Preview appex version | 통과 | `0.1.7 (13)` |
| Built Thumbnail appex version | 통과 | `0.1.7 (13)` |
| Release helper help | 통과 | `./scripts/release.sh --help` |
| Local rehearsal DMG | 통과 | `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/release.sh --skip-notarize 0.1.7` |
| `hdiutil verify` | 통과 | rehearsal DMG checksum valid |

산출물 checksum:

| 산출물 | SHA256 |
|--------|--------|
| `build.noindex/release/alhangeul-macos-0.1.7.zip` | `904b8f7a6450841df6d7f6709a771184ea17b12097acb74a0ac799cafcb2501d` |
| `build.noindex/release/alhangeul-macos-0.1.7-rehearsal.dmg` | `b1edbfd95a46afa0c0aad2746e5f43dde44d73f3e742ddcb115897548db52c9b` |

## 관찰된 경고

- `xcodebuild`가 macOS destination 후보 중 첫 번째를 사용한다는 경고를 출력했다. build는 성공했다.
- `appintentsmetadataprocessor`가 `No AppIntents.framework dependency found` 경고를 출력했다. 현재 AppIntents 의존이 없는 상태라 release blocker로 보지 않는다.
- `./scripts/release.sh --skip-notarize`는 unsigned rehearsal artifact라 codesign verification, release signing preflight, DMG signing을 의도적으로 건너뛰었다.

## 실행하지 않은 항목

- Developer ID signed/notarized public DMG 생성
- draft GitHub Release asset 기반 pre-public 설치 smoke
- official stable GitHub Release publish
- stable Sparkle appcast 갱신과 EdDSA signature 확인
- GitHub Pages public deploy 확인
- Homebrew Cask SHA256 반영
- installed candidate 기준 Finder Quick Look/Thumbnail smoke
- About 창의 bundled `rhwp v0.7.17 (0335119)` 표시 확인

## 다음 단계 요청

Stage 4에서는 `devel` release candidate를 `main`에 반영할 release PR과 `v0.1.7` tag/publish gate를 준비한다. `main` PR, tag 생성, pre-public signed/notarized DMG workflow, official stable publish는 각각 별도 승인 gate로 진행한다.

Stage 4 진행 승인을 요청한다.
