# Task #154 Stage 5 보고서

## 단계 목표

Task #154의 최종 검증을 수행하고, 배포 브랜치 기준과 최종 보고 자료를 정리한다.

## 수행 내용

| 항목 | 결과 |
|------|------|
| 기준 브랜치 최신화 | `origin/devel-webview` 최신 변경을 `local/task154`에 merge했다. Task #153 merge까지 반영했으며, `mydocs/orders/20260506.md` add/add 충돌은 Task #153/#154 항목을 모두 유지하도록 해결했다. |
| 배포 브랜치 기준 문서화 | v0.1.x public release는 `devel-webview` 검증 commit을 `main`에 반영한 뒤 `main`에서 tag/GitHub Release를 만든다는 기준을 `release_distribution_guide.md`에 추가했다. |
| `devel` 반영 경로 정리 | `devel`은 native viewer renderer 장기 통합 브랜치로 두고, release-critical 변경은 별도 PR 또는 cherry-pick으로 후속 동기화한다고 명시했다. |
| 최종 산출물 리허설 | ZIP 패키징과 notarization 제외 DMG 리허설을 실행했다. 실제 notarization, GitHub Release, Homebrew tap 반영은 실행하지 않았다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `./scripts/build-rust-macos.sh --verify-lock` | OK | `Rhwp.xcframework` 재생성과 `rhwp-core.lock` 검증 완료 |
| `./scripts/check-no-appkit.sh` | OK | shared Swift code AppKit/UIKit 의존 없음 |
| `xcodegen generate` | OK | `Alhangeul.xcodeproj` 생성 성공 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | OK | `** BUILD SUCCEEDED **` |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/DerivedDataRelease CODE_SIGNING_ALLOWED=NO build` | OK | `** BUILD SUCCEEDED **` |
| `bash -n scripts/package-release.sh scripts/release.sh` | OK | shell syntax error 없음 |
| `./scripts/release.sh --help` | OK | public release env 변수와 rehearsal 옵션 출력 확인 |
| `ruby -c Casks/alhangeul-macos.rb` | OK | `Syntax OK` |
| `./scripts/package-release.sh 0.1.0` | OK | `alhangeul-macos-0.1.0.zip` 생성 |
| `./scripts/release.sh --skip-notarize 0.1.0` | OK | sandbox 내부 `hdiutil create` 실패 후 sandbox 밖 재실행 성공. rehearsal DMG verify 완료 |
| old identity 잔여 문자열 scan | OK | current source/manual scope에서 `AlhangeulMac`, `alhangeulmac`, `com.postmelee.alhangeulmac` 잔여 없음 |
| bundle id 확인 | OK | app `com.postmelee.alhangeul`, QL `com.postmelee.alhangeul.QLExtension`, Thumbnail `com.postmelee.alhangeul.ThumbnailExtension` |
| `git diff --check` | OK | whitespace error 없음 |
| 최신 merge 후 재점검 | OK | Task #153 병합 후 보고서/오늘할일을 재적용하고 충돌 해결 |

## 리허설 산출물

| 산출물 | SHA-256 |
|------|---------|
| `build.noindex/release/alhangeul-macos-0.1.0.zip` | `d969ed45aa12d2417af882157f836252e423985a284fce8c0cff425b5f3f20a9` |
| `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg` | `a90e4e8cbd9d5397efddec01a7fbefdabd0371e291e6eeb946ca1a1eea860c99` |

이 산출물은 검증용 로컬 산출물이다. `--skip-notarize` DMG는 unsigned/not notarized rehearsal artifact이므로 public release 또는 Homebrew Cask 배포에 사용하지 않는다.

## 잔여 확인

| 항목 | 내용 |
|------|------|
| public notarization | `ALHANGEUL_DEVELOPER_ID_APPLICATION`, `ALHANGEUL_NOTARY_PROFILE` 설정 후 별도 승인 하에 실행해야 한다. |
| GitHub Release/Homebrew tap | 이 task에서는 생성/업로드/PR을 수행하지 않았다. |
| App Store Connect | bundle id와 signing capability 확정 후 별도 배포 task에서 확인한다. |
| historical 문서 | 기존 `mydocs/plans`, `mydocs/working`, `mydocs/report`의 과거 기록에 남은 이전 이름은 이력 보존 대상으로 둔다. |
