# Task M020 #447 Stage 4 완료보고서

## 단계 목적

Stage 3에서 재생성한 caller-owned image buffer artifact를 HostApp, Preview,
Thumbnail 제품 target과 native renderer에서 검증한다. 로컬 Release candidate를
실제 Finder provider로 단독 등록해 image-heavy HWP/HWPX thumbnail을 반복
생성하고, Stage 4 baseline 이후 `AlhangeulThumbnail` crash가 재발하지 않는지
확인한다.

Stage 4는 제품 source를 바꾸지 않고 build, renderer, package와 Finder
exact-provider 회귀 검증만 소유한다. public release signing, notarization,
GitHub Release와 Homebrew 배포는 #441 Release Operations 범위로 유지한다.

## 산출물

| 파일 또는 진단 | 변경 | 요약 |
|----------------|------|------|
| `build.noindex/release/Alhangeul.app` | 로컬 검증 산출물 | HEAD `2224542` 기준 v0.1.9 build 15 ad-hoc Release candidate |
| `build.noindex/release/alhangeul-macos-0.1.9.zip` | 로컬 검증 산출물 | Finder smoke 입력과 재현용 로컬 package |
| `build.noindex/task447-stage4-images/summary.md` | 로컬 검증 산출물 | HWP 3종과 HWPX 1종 native/studio visual diff 결과 |
| `build.noindex/task447-stage4-finder/` | 로컬 검증 산출물 | 표준 Finder HWP/HWPX smoke 출력과 진단 |
| `build.noindex/task447-stage4-finder-repeated/` | 로컬 검증 산출물 | candidate-only provider의 5회 × 4문서 thumbnail 출력 |
| `build.noindex/task447-stage4-hygiene-final/` | 로컬 검증 산출물 | 복원 후 provider와 LaunchServices hygiene 진단 |
| `mydocs/working/task_m020_447_stage4.md` | 신규 | Stage 4 build·renderer·Finder 검증과 복원 결과 기록 |
| `mydocs/orders/20260729.md` | 1행 갱신 | #447을 Stage 4 완료·Stage 5 승인 대기로 전환 |

`build.noindex/` 산출물은 Git 추적 대상이 아니다. Stage 4 커밋에는 완료보고서와
오늘할일 상태만 포함하며 제품 source와 generated artifact는 Stage 3 commit
상태를 유지한다.

### Candidate와 baseline

Stage 4 baseline은 `2026-07-29 18:37:17 KST`로 기록했다. baseline 이전
`AlhangeulThumbnail` crash report는 다음 두 건이었다.

- `AlhangeulThumbnail-2026-07-29-171601.ips`
- `AlhangeulThumbnail-2026-07-29-171610.ips`

로컬 package는 Stage 3 HEAD
`2224542f9cf2293ccaf076c7645a200f008d1daa`에서
`./scripts/package-release.sh 0.1.9`로 다시 생성했다.

| 항목 | 결과 |
|------|------|
| App version/build | `0.1.9` / `15` |
| App signature | ad-hoc, `TeamIdentifier=not set` |
| App CDHash | `5369570fde44c892080c07ceea9e7f40f89f4008` |
| Architecture | App, Preview, Thumbnail 모두 arm64 + x86_64 |
| Zip SHA-256 | `26e8c01c89ccb0b187bf435ba2d6c337e4490175006b3ab5dda2e82334a2bd69` |

이 package는 로컬 smoke 전용이다. Developer ID signing, notarization과 public
release workflow는 실행하지 않았다.

### Exact-provider Finder 검증

표준 helper가 v0.1.9과 기존 `/Applications` v0.1.8 provider를 함께 보고해
결과가 모호해지지 않도록, 기존 앱 파일은 유지한 채 해당 extension 등록만
일시 해제했다. candidate를 다시 등록한 뒤 다음 두 경로만 표시되는 것을
확인했다.

```text
/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

표준 Finder smoke는 `복학원서.hwp`와 `hwpx-01.hwpx` thumbnail을 모두
생성하고 exit 0으로 완료됐다. 이어 매 회 Quick Look cache를 reset한 뒤
다음 네 문서를 5회씩 생성했다.

| 문서 | 반복 결과 | 매회 동일한 SHA-256 |
|------|-----------|---------------------|
| `복학원서.hwp` | 5/5 PASS | `979482bbc5c2d12cdb5e3930554a5851d23df6c35846e2a781f9b27b9c4464af` |
| `hwp-img-001.hwp` | 5/5 PASS | `f4f0ffa1d6e2fe5d905f26c14ec1c86fa3e8b7783d4e257361e0efe477c23435` |
| `img-start-001.hwp` | 5/5 PASS | `cbd796a108c30da91e4c9e1217281b5bedac0cad48dab27039ec6b3782af764b` |
| `hwpx-01.hwpx` | 5/5 PASS | `3ef08ff54aaac5419a4efcdf21d874407d86640ee24b793fbb78b6848daad6b0` |

총 20개 thumbnail이 생성됐고 문서별 output hash는 다섯 회 모두
byte-identical했다. Stage 4 baseline 이후 신규
`AlhangeulThumbnail-*.ips` 또는 `AlhangeulPreview-*.ips`는 발생하지 않았다.

### 사용자 설치본과 provider 복원

smoke 전 사용자 설치본
`/Users/melee/Applications/Alhangeul.app`을
`build.noindex/task447-stage4-backup/Alhangeul.app`에 보존했다. smoke 종료
뒤 candidate app/appex를 unregister하고 백업을 원래 위치에 복원했다.

| 복원 항목 | 결과 |
|-----------|------|
| 사용자 앱 | v0.1.8 build 14, ad-hoc |
| 사용자 앱 CDHash | `13eb26f8958c5b94d5c2dbad2fadd0f162374cb6` |
| `/Applications` 앱 | v0.1.8 build 14, Developer ID Application |
| `/Applications` 앱 CDHash | `8a9f55ae5ec255ae1ea07617bf3c068606b04c10` |
| active Preview provider | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex` |
| active Thumbnail provider | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex` |
| 최종 registration hygiene | issue 없음, development registration 없음 |

`build.noindex` 아래 Debug/Release app bundle은 검증 산출물로 존재하지만
LaunchServices 또는 PlugInKit provider로 등록된 항목은 없다.

## 본문 변경 정도 / 본문 무손실 여부

- Stage 4에서는 Rust, Swift, Xcode target, generated header/XCFramework와
  `rhwp-core.lock`을 변경하지 않았다.
- `xcodegen generate` 뒤 `project.yml`과
  `Alhangeul.xcodeproj/project.pbxproj`에는 diff가 없다.
- 기존 Rust 7개와 Swift 27개 test는 삭제·완화하지 않고 같은 Stage 3 source
  상태에서 다시 통과했다.
- Finder smoke는 표준 helper와 candidate app/appex 단위의
  `lsregister`/`pluginkit` 조작만 사용했다. 전역 LaunchServices reset이나
  Quick Look daemon kill은 수행하지 않았다.
- 사용자 설치본은 version, build, CDHash와 deep code signature까지 확인한
  백업으로 복원했다.
- release tag, Developer ID signing, notarization, GitHub Release, Sparkle
  feed와 Homebrew Cask는 변경하지 않았다.

## 검증 결과

구현계획서 Stage 4에 고정한 build, renderer와 Finder 검증을 같은 source
상태에서 실행했다.

| 검증 | 결과 | 핵심 출력 |
|------|------|-----------|
| `cargo test --locked` | PASS | 7 passed, 0 failed |
| `build-rust-macos.sh --verify-lock` | PASS | checked-in artifact와 lock 일치 |
| `check-no-appkit.sh` | PASS | shared Swift code의 AppKit/UIKit 의존 없음 |
| `xcodegen generate` | PASS | project 생성 성공, project diff 없음 |
| HostApp Debug build | PASS | `CODE_SIGNING_ALLOWED=NO`, build 성공 |
| QLExtension Debug build | PASS | `CODE_SIGNING_ALLOWED=NO`, build 성공 |
| ThumbnailExtension Debug build | PASS | `CODE_SIGNING_ALLOWED=NO`, build 성공 |
| `ExternalImageTests` | PASS | 27 passed, 0 failed, 0 unexpected |
| `validate-stage3-render.sh` | PASS | KTX, request, exam_kor 모두 OK |
| image visual diff harness | PASS | HWP 3종, HWPX 1종 모두 OK |
| release package integrity | PASS | app/appex deep codesign과 universal architecture 확인 |
| 표준 Finder smoke | PASS | HWP/HWPX thumbnail 생성 |
| candidate-only 반복 thumbnail | PASS | 5회 × 4문서, 20/20 생성 및 hash 안정 |
| crash report gate | PASS | baseline 이후 신규 알한글 Preview/Thumbnail crash 없음 |
| 복원 후 hygiene | PASS | active provider `/Applications`, development registration 없음 |
| `git diff --check` | PASS | whitespace 오류 없음 |

최종 Swift test:

```text
Test Suite 'HwpExternalImageResolverTests' passed
Executed 18 tests, with 0 failures

Test Suite 'RhwpDocumentExternalImageBridgeTests' passed
Executed 9 tests, with 0 failures

Test Suite 'All tests' passed
Executed 27 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

### Preview CLI 비교 진단

계획의 Thumbnail crash gate와 별도로 Preview extension을 출력형
`qlmanage -p -x -o`로 자동 확인하려 했다. candidate v0.1.9에서
`qlmanage`가 exit 134로 종료됐지만, 기존 Developer ID 서명 v0.1.8을
단독 provider로 등록한 비교 실행에서도 같은 예외와 stack으로 종료됐다.

```text
NSInvalidArgumentException
-[EXConcreteExtension makeExtensionContextAndXPCConnectionForRequest:error:]
-[QLExtension _setupConnectionIfNeededWithCompletionHandler:]
```

두 crash report의 process는 알한글 extension이 아니라 Apple
`com.apple.quicklook.qlmanage`이고, stack은 알한글 provider code 진입 전
`ExtensionFoundation`에만 있다. 따라서 Task #447 source 또는 v0.1.9
candidate의 신규 회귀로 판정하지 않았다. 이 비교로 생성된
`qlmanage-2026-07-29-185622.ips`와
`qlmanage-2026-07-29-185759.ips`는 원인 구분 증거로 보존했다.

## 잔여 위험

- `qlmanage -p -x -o`는 현재 macOS 환경에서 기존 v0.1.8과 candidate 모두
  Apple `ExtensionFoundation` 예외로 사용할 수 없다. #441의 실제
  Developer ID signed candidate에서는 Finder/Space 입력의 Preview UI를
  수동으로 다시 확인한다.
- 이번 exact-provider gate는 Task #447의 crash queue였던 Thumbnail
  extension과 image-heavy 문서에 집중했다. 앱의 전체 사용자 동작과 배포
  채널 검증은 #441 release rehearsal이 소유한다.
- x86_64는 Rust universal archive와 세 제품 bundle slice까지 검증했으며
  runtime test는 arm64 Mac에서 수행했다.
- 로컬 ad-hoc zip은 public 배포 산출물이 아니다. #441은 Task #447 merge
  SHA를 포함해 signed candidate를 새로 생성해야 하며 기존 draft artifact나
  이 로컬 zip을 재사용하면 안 된다.
- `imageDataLength`의 full lazy-byte allocation 비용과 exact length free
  계약은 Stage 3에서 기록한 범위를 유지한다.

## 다음 단계 영향

Stage 5는 Task #447의 최종 보고와 #441 Release Operations 인계를 수행한다.

1. caller-owned allocation 선택과 memory trade-off를 최종 보고서에 정리한다.
2. Rust/Swift test, artifact provenance, 세 target, renderer와
   exact-provider 결과를 PR body와 일치시킨다.
3. #441에 Task #447 fix commit과 PR/merge SHA, 새 signed candidate 생성
   조건을 전달한다.
4. `task-final-report` 절차로 오늘할일 완료, 최종 커밋,
   `publish/task447` push와 `devel` 대상 ready PR을 생성한다.
5. PR CI 완료와 merge는 작업지시자의 별도 승인 절차를 따른다.

Stage 5 전에는 원격 branch push, PR 생성, #441 공개 코멘트, release signing,
notarization 또는 배포 workflow를 실행하지 않는다.

## 승인 요청

Stage 4 제품 build, image renderer와 candidate-only Thumbnail 20/20 결과,
신규 알한글 extension crash 없음 및 사용자 설치본/provider 복원을 승인하고,
구현계획서의 Stage 5 `최종 보고, PR 게시와 #441 인계`에 진입할지 승인
요청한다.

Stage 5 승인 전에는 최종 보고서, 원격 `publish/task447`, GitHub PR과 #441
인계 작업을 시작하지 않는다.
