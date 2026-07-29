# Task M900 #441 Stage 3 완료보고서

## 단계 목적

`v0.1.9 (15)` release candidate가 `rhwp v0.8.2` provenance, Rust/Swift boundary, 세 제품 target, representative renderer와 unsigned universal package 기준을 통과하는지 확인하고, 별도 승인된 Release Rehearsal DMG의 exact candidate, checksum, layout과 수동 앱 동작을 검증한다.

이번 단계에서 처음 실행한 rehearsal 뒤 HostApp 반응형 툴바 회귀가 발견됐다. 해당 산출물을 폐기하고 Issue #442 / PR #443 수정이 반영된 새 후보에서 source preflight와 rehearsal을 모두 다시 수행했다.

## 검증 기준점

| 항목 | 값 |
|------|----|
| candidate branch | `local/task441` / `origin/publish/task441` |
| exact candidate commit | `07b9f34cb14827223e085bc583406ba2654171c0` |
| 반영한 `devel` | `e2aef4c232a48963f7e2abcaaca4bc4230b3b454`, PR #443 merge |
| previous release ref | `v0.1.8` |
| app / extension | `0.1.9 (15)` |
| rhwp core / studio | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| 유효 rehearsal run | [`30424930226`](https://github.com/postmelee/alhangeul-macos/actions/runs/30424930226) |
| 폐기한 rehearsal run | `30365232108`, candidate `1d358103a877a9d0b6c924a280b84e60e94d6739` |
| 최신 공개 앱 | `v0.1.8`, non-draft / non-prerelease |
| 최신 upstream | `rhwp v0.8.2`, candidate lock과 일치 |

Stage 3 완료 시점에 `v0.1.9` tag와 `publish/task441` source PR은 없다. tracked worktree는 검증 시작 전 clean이었고, 문서 반영 전 검증 종료 시에도 clean이었다.

## 후보 이동과 차단 해소

최초 rehearsal run `30365232108`은 workflow 자체는 성공했지만 candidate `1d358103...`의 HostApp에서 상단 toolbar와 style bar가 창 너비에 따라 겹치거나 잘리는 사용자-facing 회귀가 확인됐다.

- 해당 run과 DMG는 공개 릴리스 승인 근거에서 제외했다.
- Issue #442를 release blocker로 분리하고 PR #443에서 stale WKWebView layout override를 제거했다.
- PR #443 merge commit `e2aef4c...`를 Task #441 branch에 merge commit `a9760bbe...`로 통합했다.
- release communication과 포함 PR 분석을 `07b9f34...`에서 보정했다.
- source preflight와 Release Rehearsal을 새 exact candidate에서 처음부터 다시 실행했다.

따라서 Stage 3 승인 근거는 run `30424930226`과 candidate `07b9f34...`뿐이다.

## Source preflight

### Core와 bundled studio provenance

| 검증 | 결과 |
|------|------|
| `rhwp-core.lock` | `v0.8.2` / `9b16aa9e...` |
| `RustBridge/Cargo.lock` | 같은 upstream tag와 resolved commit |
| `RhwpCoreBuildInfo` | lock과 일치 |
| bundled studio manifest/assets | `v0.8.2` / `9b16aa9e...`, ownership guard 포함 검증 통과 |
| mounted rehearsal override | source `alhangeul-wkwebview-overrides.css`와 byte-identical |
| shared Swift boundary | AppKit/UIKit 직접 의존 없음 |

다음 검증이 통과했다.

```text
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh --tag v0.8.2 --commit 9b16aa9e...
./scripts/check-no-appkit.sh
```

### Strict와 portable artifact 판정

`./scripts/build-rust-macos.sh --verify-lock`은 source, Cargo lock, generated header, 15개 FFI symbol과 XCFramework를 검증한 뒤 `Frameworks/universal/librhwp.a`의 byte hash/size 비교에서만 실패했다.

| 항목 | lock reference | local artifact |
|------|----------------|----------------|
| SHA256 | `b35e935283f97c20d41f634f559e623ccd510f54f1341ca83d0f2108345a58eb` | `427e4b88300cb732c0c8986889f4ee45859a5a3e1c9a9f06569ac655d980e26f` |
| size | `212,505,600` bytes | `212,514,296` bytes |

lock은 수정하지 않았다. 문서화된 portable 경계인 다음 명령은 통과했다.

```text
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  ./scripts/build-rust-macos.sh --verify-lock
```

이 옵션은 static archive byte hash/size 비교만 건너뛰며 source provenance, Cargo lock, generated header, 15개 FFI symbol과 universal XCFramework 검증은 유지한다. 유효 rehearsal workflow도 같은 경계를 명시적으로 사용했고 `Verify rhwp source, header, and ABI lock` step이 성공했다.

Release artifact 판정은 기존 Task #438 결과와 이번 exact candidate 재검증에 따라 portable 경계를 허용하되 strict mismatch를 성공으로 바꾸어 기록하지 않는 것으로 확정한다.

## Rust, Xcode와 renderer 검증

| 검증 | 결과 |
|------|------|
| `cargo fmt --check` | 통과 |
| RustBridge locked tests | `4/4`, 실패 0 |
| ExternalImageTests | `24/24`, status `succeeded` |
| `xcodegen generate` 2회 | tracked project drift 없음 |
| HostApp Release build | `BUILD SUCCEEDED` |
| QLExtension Release build | `BUILD SUCCEEDED` |
| ThumbnailExtension Release build | `BUILD SUCCEEDED` |
| representative renderer | HWP 4개 + HWPX 1개, page 1 PNG `5/5` |
| Quick Look policy | HWP/HWPX와 764쪽 external fixture 성공, fallback 0 |
| external missing fixture | total 3 / injected 2 / missing 1, 764쪽 main render 유지 |
| Thumbnail policy | 5개 문서 × 2 policy × 4 request `40/40`, cache signature 분리 |

최종 Xcode 재검증의 첫 sandbox 실행은 SwiftPM/Xcode user cache 접근 제한으로 package resolve 단계에서 실패했다. 같은 exact source를 승인된 Xcode cache 접근으로 다시 실행해 ExternalImageTests와 세 Release target이 모두 통과했다. 이는 제품 또는 source 실패로 판정하지 않는다.

## Local universal package

`./scripts/package-release.sh 0.1.9`로 만든 local package는 다음과 같다.

| 항목 | 결과 |
|------|------|
| HostApp / Preview / Thumbnail version | 모두 `0.1.9 (15)` |
| HostApp architecture | `x86_64 + arm64` |
| Preview architecture | `x86_64 + arm64` |
| Thumbnail architecture | `x86_64 + arm64` |
| Legal | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` canonical byte 일치 |
| 개발용 zip | `163,657,825` bytes |
| 개발용 zip SHA256 | `ec843834768b8296648b7e50dbf2885a70dce89c42731a3586c5f316265de227` |

이 package와 zip은 local unsigned 검증 산출물이며 public DMG, Sparkle enclosure 또는 Homebrew 입력이 아니다.

## Release helper

exact candidate `07b9f34...`에서 다음 ignored 산출물을 다시 생성했다.

- `build.noindex/task441-stage3-07b9f34/pr-analysis-v0.1.9.md`
- `build.noindex/task441-stage3-07b9f34/delta-checklist-v0.1.9.md`
- `build.noindex/task441-stage3-07b9f34/release-notes-v0.1.9.md`

결과:

- previous release `v0.1.8`, candidate `07b9f34...`로 고정
- merge PR 7개에 PR #443 포함
- release note template check 통과
- GitHub body validator 통과
- latest release notice check 통과
- `git diff --check` 통과

final `devel -> main` candidate가 Stage 4에서 이동하므로 PR analysis와 delta checklist는 release PR과 tag 직전에 다시 생성한다.

## Release Rehearsal DMG

별도 승인으로 `origin/publish/task441` exact commit `07b9f34...`에서 `Release Rehearsal DMG` workflow를 실행했다.

| 항목 | 값 |
|------|----|
| run | [`30424930226`](https://github.com/postmelee/alhangeul-macos/actions/runs/30424930226) |
| workflow / job | `Release Rehearsal DMG` / `Build rehearsal DMG` |
| conclusion | `success` |
| head branch / SHA | `publish/task441` / `07b9f34cb14827223e085bc583406ba2654171c0` |
| inputs | `0.1.9`, `v0.1.8`, `v0.8.2` |
| DMG | `alhangeul-macos-0.1.9-rehearsal.dmg` |
| size | `163,108,702` bytes |
| SHA256 | `e5b03e67a03d1e4aecada0f78fc351dfeb904158a7259bdea5a3b6d8988f7db0` |
| checksum file | 같은 digest, `shasum` 대조 통과 |
| `hdiutil verify` | `VALID`, 독립 재검증 통과 |
| app / extensions | 모두 `0.1.9 (15)`, `x86_64 + arm64` |
| local override | mounted app과 source byte-identical |
| signing | unsigned rehearsal, signing/notarization 근거로 사용하지 않음 |

Mounted layout 확인:

| 항목 | 결과 |
|------|------|
| visible root | `Alhangeul.app`, `Applications` |
| Applications link | `/Applications` |
| background | `.background/alhangeul-dmg-background.png`, `720x460` |
| app/extension universal | 모두 통과 |
| 별도 설치 안내 파일 | 없음 |

rehearsal workflow에는 Pages 또는 stable appcast deploy job이 없었다. 실행 뒤에도 latest GitHub Release, public Pages와 Sparkle appcast는 `v0.1.8 (14)`를 유지했다.

## 수동 앱 검증

### 반응형 툴바

PR #443 검증에서 900, 1023, 1024, 1280, 1600px, light/dark와 빈 문서/HWP/HWPX 조합을 확인했다.

- style control 경계 이탈 0
- document 수평 overflow 없음
- 1023px tablet grid에서 1024px desktop flex 전환 정상
- style/language/font/size/line-spacing interaction 정상
- exact rehearsal bundle의 local override가 검증된 source와 byte-identical

### 줌과 대형 문서

작업지시자가 exact rehearsal 앱을 직접 조작해 다음을 확인했다.

- `KTX.hwp`의 우하단 돋보기 버튼으로 `78% -> 88% -> 78%` 변경이 자연스럽다.
- 트랙패드 pinch에서 배율 숫자가 변하고, 반대 pinch로 약 `78%`에 돌아오며 문서 중심이 유지된다.
- `samples/issue1949_giant_cell_nested_tables_perf.hwp`는 파일 크기 `303,616` bytes지만 115쪽 문서다. exact rehearsal v0.1.9에서는 물리 pinch가 동작한다.
- `/Applications/Alhangeul.app`의 기존 public v0.1.8에서는 같은 대형 문서 pinch가 멈춘 것처럼 보이지만, 이는 bundled `rhwp-studio v0.7.18`의 event마다 전체 재렌더하는 이전 구현과 v0.1.9의 coalesced smooth zoom 구현 차이다.

따라서 대형 파일 자체나 native HostApp gesture 충돌을 새 release blocker로 판정하지 않는다. 이번 확인은 v0.1.9 upstream pinch zoom 개선이 rehearsal 후보에 정상 반영됐다는 수동 증거다.

## Registration과 mount 정리

- 수동 비교에 사용한 exact rehearsal process만 종료했다.
- exact rehearsal mount `/dev/disk9`만 정상 detach했다.
- `/Applications/Alhangeul.app`의 기존 public v0.1.8 process는 변경하지 않았다.
- 이전 차단 rehearsal mount `/dev/disk8`은 이번 정리 대상에 포함하지 않았다.
- 전역 LaunchServices reset, 설치본 삭제 또는 다른 app registration 변경은 수행하지 않았다.

## 미실행 항목

rehearsal은 unsigned artifact이므로 다음을 성공으로 기록하지 않는다.

- Developer ID signing, notarization submit/wait, staple와 Gatekeeper
- draft 또는 official GitHub Release asset
- signed candidate의 registered Finder Quick Look/Thumbnail provider provenance
- signed candidate external sibling sandbox fallback
- bundled editor 장문서 후반 page repaint, 인쇄 preview와 PDF export 시작 경로
- `v0.1.8 -> v0.1.9` Sparkle update와 extension refresh
- official stable Pages/appcast와 Homebrew Cask
- Intel Mac 실기기 설치·실행

위 항목 중 signed candidate 수동 gate는 Stage 4, official public surface와 update는 Stage 5에서 별도 승인 후 수행한다.

## 판정

- Gate 2 source preflight와 Gate 3 Release Rehearsal 기준은 통과했다.
- PR #443 이전 run `30365232108`과 artifact는 계속 폐기 상태다.
- exact candidate `07b9f34...`의 run `30424930226`만 Stage 4 인계 근거로 사용한다.
- strict static archive mismatch는 숨기지 않고 portable source/header/FFI 경계 허용으로 판정했다.
- 반응형 툴바 차단 회귀는 PR #443과 새 rehearsal에서 해소됐다.
- 대형 문서 pinch 차이는 public v0.1.8과 rehearsal v0.1.9의 bundled upstream 구현 차이이며 새 blocker가 아니다.
- Stage 4 진입을 막는 미해결 Stage 3 blocker는 없다.

## 승인 요청

Stage 3 완료 결과를 승인하고 Stage 4 `Source 반영, main/tag와 pre-public signed candidate` 진입을 요청한다.

Stage 4에서도 다음 mutation은 각각 별도 승인 gate를 유지한다.

1. Stage 3 보고 commit을 `publish/task441`에 push하고 `devel` 대상 source PR 생성
2. source PR CI/review 통과 뒤 merge
3. 필요 시 `main -> devel` back-merge PR 생성·merge
4. `devel -> main` release PR 생성·merge
5. exact release commit의 annotated `v0.1.9` tag 생성·push
6. `draft=true`, `prerelease=false` Publish workflow 실행
