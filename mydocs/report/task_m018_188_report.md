# Task M018 #188 최종 결과 보고서

## 작업 요약

| 항목 | 값 |
|------|----|
| 이슈 | [#188 v0.1.1 patch release 준비와 public 배포 실행](https://github.com/postmelee/alhangeul-macos/issues/188) |
| 마일스톤 | M018 `v0.1.1` |
| 브랜치 | `local/task188` |
| 단계 | Stage 1-9 + 최종 정리 |
| 최종 public release | `v0.1.1` build `4` |
| Release workflow | https://github.com/postmelee/alhangeul-macos/actions/runs/25645869039 |
| Release tag peeled commit | `5a40c9869bb94ff0ad59d6ba89c1f9af38643a02` |
| Public DMG SHA256 | `12c5755fa0ac75dd13f813c6e65f0fc37a7e43e07080317c7df54b06e9c60e16` |

`v0.1.1` original public build `2` 배포 후 설치본 smoke에서 Quick Look/Thumbnail extension render crash가 확인됐다. Stage 6-9에서 bitmap backing memory ownership, extension diagnostics, clean visual smoke, About extension 상태 표시, build `4` respin을 처리했고, 최종 public DMG와 Sparkle appcast를 build `4` 기준으로 교체했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/release-publish.yml`, `.github/workflows/release-rehearsal.yml`, `.github/workflows/pr-ci.yml` | release/publish/rehearsal/PR CI 입력값, signing/notarization, Sparkle appcast helper 검증 보강 |
| `scripts/build-rust-macos.sh`, `scripts/ci/import-developer-id-certificate.sh`, `scripts/release.sh` | release workflow 실패 원인 보정과 Developer ID/import/staticlib 검증 보강 |
| `scripts/smoke-clean-quicklook-install.sh` | 기존 앱/extension/cache 오염을 줄인 Quick Look/Thumbnail visual smoke helper 추가 |
| `scripts/smoke-sparkle-extension-refresh.sh` | Sparkle 업데이트 후 active provider가 새 app path를 가리키는지 검증하는 smoke helper 추가 |
| `Sources/Shared/HwpPageImageRenderer.swift` | Swift 배열 backing store에 의존하던 bitmap context를 CoreGraphics 소유 memory로 전환해 extension crash 완화 |
| `Sources/QLExtension/HwpPreviewProvider.swift`, `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | Quick Look/Thumbnail provider 진단 로그와 failure 추적 보강 |
| `Sources/HostApp/HostApp.swift`, `Sources/HostApp/Services/ExtensionStatusModel.swift`, `Sources/HostApp/Services/ExtensionSystemRegistrationRefresher.swift` | app launch/About refresh 시 LaunchServices 기반 extension refresh 수행, sandboxed `pluginkit` CLI 조회 제거 |
| `Sources/HostApp/Info.plist`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist` | `CFBundleShortVersionString=0.1.1`, 최종 `CFBundleVersion=4` 반영 |
| `Casks/alhangeul-macos.rb` | #209 handoff용 Cask source를 final public build `4` DMG SHA256으로 갱신 |
| `README.md`, `docs/updates/v0.1.1.html` | v0.1.1 release 안내, Quick Look/Thumbnail hotfix, respin build 기준 반영 |
| `mydocs/manual/*`, `mydocs/release/v0.1.1.md`, `mydocs/working/task_m018_188_stage*.md` | release 운영 기록, smoke 절차, stage별 결과 기록 |
| `mydocs/orders/20260510.md`, `mydocs/orders/20260511.md` | 작업 진행 상태와 완료 상태 갱신 |

## 변경 전후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| App short version | `0.1.0` | `0.1.1` |
| Public build | `0.1.1 (2)` original | `0.1.1 (4)` final respin |
| Sparkle appcast | build `2` item | build `4` item |
| Public DMG SHA256 | `5b17271d7724cf9d9aff2badbdbbe936eccc16178c66b28c6207e89cd6de5d29` | `12c5755fa0ac75dd13f813c6e65f0fc37a7e43e07080317c7df54b06e9c60e16` |
| Quick Look/Thumbnail build 2 smoke | extension render crash | build 4 clean reinstall smoke 정상 확인 |
| About extension 상태 | sandboxed `pluginkit` 조회 실패를 `시스템 등록 확인 불가`로 표시 가능 | embedded appex 정합성과 LaunchServices refresh 기준으로 `시스템 등록됨` 표시 |

## 검증 결과

| 수용 기준 | 결과 |
|-----------|------|
| GitHub Release `v0.1.1` public 상태 | OK, `draft=false`, `prerelease=false` |
| Release workflow | OK, run `25645869039` success |
| Public appcast | OK, `sparkle:version=4`, `sparkle:shortVersionString=0.1.1` |
| DMG checksum | OK, `shasum -a 256 -c` 통과 |
| DMG image verify | OK, `hdiutil verify` VALID |
| Signing/notarization | OK, `codesign`, `xcrun stapler validate`, `spctl -t install` 통과 |
| App/Preview/Thumbnail bundle version | OK, mounted DMG 기준 모두 `0.1.1 (4)` |
| Clean reinstall Quick Look/Thumbnail smoke | OK, 작업지시자가 build `4` 재설치 후 정상 동작 확인 |
| `v0.1.0` Sparkle update detection | OK, 작업지시자가 update 진행 완료 확인 |
| Homebrew Cask source | OK, final build `4` SHA256으로 갱신. tap 반영과 brew smoke는 #209 범위 |

## 잔여 위험과 후속 작업

- `v0.1.0` 또는 original `v0.1.1`에서 Sparkle 업데이트한 사용자는 Finder가 과거 thumbnail cache를 계속 보여줄 수 있다. 앱 업데이트 후 targeted thumbnail refresh UX와 About rhwp version 표시, rhwp `v0.7.11` 반영은 #225에서 처리한다.
- `require_latest_rhwp=false`는 이번 hotfix respin에서 의도적으로 사용한 예외다. `v0.1.2`에서는 upstream 최신 `rhwp v0.7.11` 반영을 별도 작업으로 진행한다.
- Intel Mac 실기기 smoke는 접근 가능한 환경에서 별도 확인해야 한다. 현재 public DMG 자체는 universal slice 검증을 통과했다.
- Homebrew tap 공개 배포, `brew style`/`brew audit`/install/uninstall smoke는 #209에서 진행한다.

## 작업지시자 승인 요청

#188 작업은 build `4` public respin, clean reinstall smoke 확인, release 기록/Cask handoff 갱신까지 완료됐다. 이 최종 보고서 승인 후 `publish/task188` PR을 `devel-webview` 대상으로 게시하고, merge 후 #188을 close한다.
