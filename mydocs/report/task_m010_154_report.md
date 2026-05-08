# Task #154 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#154 제품 identity를 Alhangeul로 통일](https://github.com/postmelee/alhangeul-macos/issues/154) |
| 마일스톤 | M010 / v0.1.0 Viewer 기반 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task154` |
| 단계 수 | 5단계 |
| 결론 | 앱, bundle id, Xcode project/product/executable, extension product, UTI, 배포 스크립트, Cask app stanza, 현재 운영 문서의 제품 identity를 `Alhangeul` 기준으로 통일했다. |

저장소명, Homebrew Cask token, GitHub Release asset filename은 기존 public distribution 경로와 맞추기 위해 `alhangeul-macos`로 유지했다. 실제 public notarization, GitHub Release 생성, Homebrew tap 반영, App Store Connect 제출은 실행하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `project.yml` | Xcode project name을 `Alhangeul`로 변경하고 app/extension product, executable, bundle id를 `Alhangeul` 계열로 정리했다. |
| `Sources/HostApp/Info.plist` | app 기본 표시명, exported UTI, document type content type을 `Alhangeul` / `com.postmelee.alhangeul.*` 기준으로 변경했다. |
| `Sources/QLExtension/Info.plist` | Quick Look extension 기본 이름과 supported content type을 새 app UTI로 맞췄다. |
| `Sources/ThumbnailExtension/Info.plist` | Thumbnail extension 기본 이름과 supported content type을 새 app UTI로 맞췄다. |
| `Sources/**/Resources/en.lproj/InfoPlist.strings` | 영어 사용자 표시명을 `Alhangeul`, `Alhangeul Preview`, `Alhangeul Thumbnail`으로 통일했다. |
| `Sources/HostApp/Services/**`, `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | extension bundle id, appex name, allowed UTI, error domain, share temp directory, queue label을 새 identity로 변경했다. |
| `scripts/package-release.sh`, `scripts/release.sh` | project/app 이름, cleanup pattern, DMG volume, release artifact 내부 app name을 `Alhangeul.app` 기준으로 정리했다. |
| `Casks/alhangeul-macos.rb` | Cask token은 유지하고 `app "Alhangeul.app"` stanza로 변경했다. |
| `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `.github/**`, `mydocs/manual/**`, `mydocs/tech/**` | 현재 운영 문서의 build/run/smoke/release/architecture 기준을 `Alhangeul`로 갱신했다. |
| `mydocs/manual/release_distribution_guide.md` | `devel-webview -> main` 릴리스 기준과 `devel` 후속 동기화 정책을 추가했다. |
| `mydocs/plans/task_m010_154*.md`, `mydocs/working/task_m010_154_stage*.md` | 수행계획, 구현계획, 단계별 보고서를 작성했다. |
| `mydocs/orders/20260506.md` | 오늘할일 상태를 완료로 갱신했다. |

## 변경 전·후 정리

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| Xcode project | `AlhangeulMac.xcodeproj` | `Alhangeul.xcodeproj` |
| app bundle name | `AlhangeulMac.app` | `Alhangeul.app` |
| app executable/module | `AlhangeulMac` | `Alhangeul` |
| app bundle id | `com.postmelee.alhangeulmac` | `com.postmelee.alhangeul` |
| QL appex | `AlhangeulMacPreview.appex` | `AlhangeulPreview.appex` |
| Thumbnail appex | `AlhangeulMacThumbnail.appex` | `AlhangeulThumbnail.appex` |
| app UTI | `com.postmelee.alhangeulmac.hwp`, `com.postmelee.alhangeulmac.hwpx` | `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx` |
| Cask app stanza | `app "AlhangeulMac.app"` | `app "Alhangeul.app"` |
| Cask token / release asset | `alhangeul-macos` | 유지 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `91165f5` | 수행 계획서와 오늘할일 항목을 작성했다. |
| 구현 계획 | `a11f382` | rename 대상, 배포 스크립트, 문서, 최종 검증 단계를 분리했다. |
| Stage 1 | `38752e0` | `AlhangeulMac` 사용처를 변경/유지/legacy 범위로 분류했다. |
| Stage 2 | `d86379d` | Xcode identity, bundle id, UTI, extension product 이름을 정합화했다. |
| Stage 3 | `4dc2c65` | Swift runtime 상수, 배포 스크립트, Cask stanza를 새 이름으로 변경했다. |
| Stage 4 | `2d134d3` | 현재 운영 문서와 smoke 기준을 `Alhangeul`로 갱신했다. |
| 최신 기준 병합 | `f8801c1`, `402e425` | `origin/devel-webview` 최신 변경을 작업 브랜치에 병합했다. 두 번째 병합에서 Task #153 완료 항목과 Task #154 완료 항목을 모두 유지하도록 오늘할일 충돌을 해결했다. |
| Stage 5 | 이번 최종 보고 커밋 | 최종 검증, 배포 브랜치 기준 문서화, 최종 보고서를 정리했다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `./scripts/build-rust-macos.sh --verify-lock` | OK | Rust bridge와 lock 검증 |
| `./scripts/check-no-appkit.sh` | OK | shared Swift code 경계 검증 |
| `xcodegen generate` | OK | `Alhangeul.xcodeproj` 생성 |
| Debug build | OK | `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 성공 |
| Release build | OK | `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 성공 |
| `bash -n scripts/package-release.sh scripts/release.sh` | OK | shell syntax 검증 |
| `./scripts/release.sh --help` | OK | release usage와 env 문서화 확인 |
| `ruby -c Casks/alhangeul-macos.rb` | OK | Cask 문법 검증 |
| `./scripts/package-release.sh 0.1.0` | OK | `alhangeul-macos-0.1.0.zip` 생성 |
| `./scripts/release.sh --skip-notarize 0.1.0` | OK | rehearsal DMG 생성과 `hdiutil verify` 완료 |
| old identity 잔여 문자열 scan | OK | current source/manual scope에 이전 identity 잔여 없음 |
| release app bundle id 확인 | OK | app/QL/Thumbnail bundle id가 `com.postmelee.alhangeul` 계열 |
| `git diff --check` | OK | whitespace error 없음 |

## 배포 기준

| 항목 | 결정 |
|------|------|
| 우선 배포 기준 | `devel-webview` 기준으로 release candidate를 검증한다. |
| public release branch | 검증된 `devel-webview` commit을 `main`에 반영한 뒤 `main`에서 tag와 GitHub Release를 생성한다. |
| `devel` 반영 | `devel-webview`에 들어간 release-critical 변경은 별도 PR 또는 cherry-pick으로 `devel`에 후속 동기화한다. |
| Homebrew tap | 초기 tap 후보는 `postmelee/homebrew-alhangeul`이며, Cask token은 `alhangeul-macos`로 유지한다. 설치 명령은 tap 등록 방식에 따라 `brew install --cask postmelee/alhangeul/alhangeul-macos` 또는 `brew tap postmelee/alhangeul` 후 `brew install --cask alhangeul-macos`가 된다. |

## 잔여 위험과 후속 작업

| 구분 | 내용 |
|------|------|
| public release | 실제 notarization, stapling, GitHub Release asset upload, Homebrew tap PR은 별도 승인 후 수행해야 한다. |
| Apple Developer | local rehearsal은 unsigned/not notarized 기준이다. public release 전 Developer ID Application identity와 `notarytool` keychain profile 실검증이 필요하다. |
| App Store | App Store Connect bundle id, signing capability, sandbox 정책은 추후 App Store 배포 task에서 별도 확인한다. |
| 기존 설치본 | 사용자 환경에 남은 `AlhangeulMac.app` 또는 old LaunchServices/pluginkit 등록은 삭제하지 않았다. 필요 시 승인 후 별도 cleanup smoke를 수행한다. |
| historical 문서 | 과거 계획/보고서의 이전 이름은 이력 보존 대상이므로 current operational scan 범위에서 제외했다. |

## 작업지시자 승인 요청

Task #154는 `Alhangeul` identity 통일과 release branch 기준 문서화를 완료했다. 다음 단계는 `publish/task154` 브랜치 push와 `devel-webview` 대상 PR 생성 승인이다. PR merge 후에는 동일 변경을 `devel`에 후속 동기화하고, release candidate 확정 시 `devel-webview` 기준 commit을 `main`에 반영한다.
