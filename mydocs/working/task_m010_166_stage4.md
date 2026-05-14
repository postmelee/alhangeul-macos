# Task M010 #166 Stage 4 보고서

## 단계 목적

`v0.1.0` tag 기준으로 official `Release Publish DMG` workflow를 실행해 signed/notarized public DMG와 GitHub Release asset을 게시했다. 실패한 release workflow는 원인을 좁혀 보정했고, 최종 run에서 notarization, GitHub Release publish, appcast 생성까지 통과했다.

## 산출물

| 항목 | 결과 |
|------|------|
| release tag | `v0.1.0` |
| final tag object | `0937bb2d98e8fdb98b4d4eaaa79d8f89323c1d9e` |
| final tag target | `a889c1551884fb3820012e63d81fd60874751dac` |
| GitHub Actions run | `25574049810` |
| run URL | `https://github.com/postmelee/alhangeul-macos/actions/runs/25574049810` |
| GitHub Release | `https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.0` |
| DMG asset | `alhangeul-macos-0.1.0.dmg` |
| DMG size | `66111087` bytes |
| DMG SHA256 | `98d4e1807dfece2acd08510441c0f1a41cad9a8f5bbe1b82cf9ed4d3abb0f3c4` |

## workflow 실패와 보정

Stage 4에서는 official workflow를 실제로 실행하면서 release-only 실패를 순차 보정했다.

| run | 결과 | 원인과 조치 |
|-----|------|-------------|
| `25572054975` | failure | CI에 `cbindgen`이 없어 Rust bridge lock 검증이 실패했다. workflow에 `brew install cbindgen`을 추가했다. |
| `25572501549` | failure | CI Rust artifact hash가 로컬 lock과 달랐다. `rust-toolchain.toml`로 Rust `1.94.1`을 고정했다. |
| `25572956176` | failure | CI 환경의 Rust staticlib size/hash가 로컬 macOS 26/Xcode 26 결과와 달랐다. `rhwp-core.lock`에 CI artifact variant를 추가했다. 이후 app notarization에서 Sparkle nested code, timestamp, `get-task-allow` 문제가 확인됐다. |
| `25574049810` | success | `scripts/release.sh`가 release bundle을 재서명하고 nested Sparkle code의 Developer ID/timestamp를 검증하도록 보정한 뒤 성공했다. |

최종 signing 보정 commit:

```text
a889c15 Task #166 [Stage 4.5]: release notarization signing 보정
```

주요 보정:

- Release build에 `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`, `OTHER_CODE_SIGN_FLAGS=--timestamp` 적용
- Host app, Quick Look/Thumbnail appex entitlements를 release용으로 재생성 후 Developer ID로 재서명
- Sparkle `Downloader.xpc`, `Installer.xpc`, `Updater.app`, `Autoupdate`, `Sparkle.framework`를 Developer ID와 secure timestamp로 재서명
- `codesign --generate-entitlement-der` 적용
- `get-task-allow`, invalid entitlements blob, Developer ID authority, secure timestamp를 release script에서 사전 검증
- notary failure 시 `notarytool log`를 workflow log에 출력하도록 보강

## 최종 workflow 결과

```json
{
  "conclusion": "success",
  "createdAt": "2026-05-08T19:02:18Z",
  "updatedAt": "2026-05-08T19:12:48Z",
  "headBranch": "v0.1.0",
  "headSha": "a889c1551884fb3820012e63d81fd60874751dac",
  "url": "https://github.com/postmelee/alhangeul-macos/actions/runs/25574049810"
}
```

통과한 주요 workflow step:

- `Verify rhwp lock`
- `Build signed and notarized DMG`
- `Verify public release artifact`
- `Publish GitHub Release asset`
- `Validate published release state`
- `Write Sparkle appcast`
- `Publish Sparkle appcast to Pages branch`
- `Upload Sparkle appcast artifact copy`
- `Upload signed DMG artifact copy`

GitHub Actions annotation으로 Node.js 20 actions deprecation warning이 표시됐지만, release artifact 생성과 게시에는 영향을 주지 않았다.

## GitHub Release 검증

`gh release view v0.1.0` 결과:

| 항목 | 값 |
|------|----|
| `isDraft` | `false` |
| `isPrerelease` | `false` |
| `publishedAt` | `2026-05-08T19:12:21Z` |
| target | `main` |
| DMG asset digest | `sha256:98d4e1807dfece2acd08510441c0f1a41cad9a8f5bbe1b82cf9ed4d3abb0f3c4` |
| checksum asset digest | `sha256:96aa62e6e03626ea7fec4ce42c5c74c4e4e58fd2fa5513c742ee8da5cdac0454` |

다운로드 검증:

```bash
gh release download v0.1.0 \
  --repo postmelee/alhangeul-macos \
  --dir /private/tmp/alhangeul-release-0.1.0.bMxXuh \
  --pattern alhangeul-macos-0.1.0.dmg \
  --pattern alhangeul-macos-0.1.0.dmg.sha256 \
  --clobber

shasum -a 256 -c alhangeul-macos-0.1.0.dmg.sha256
hdiutil verify /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg
codesign --verify --verbose=2 /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg
```

결과:

```text
alhangeul-macos-0.1.0.dmg: OK
hdiutil: verify: checksum of ".../alhangeul-macos-0.1.0.dmg" is VALID
.../alhangeul-macos-0.1.0.dmg: valid on disk
.../alhangeul-macos-0.1.0.dmg: satisfies its Designated Requirement
```

`releases/latest/download/alhangeul-macos-0.1.0.dmg`는 `v0.1.0` release asset으로 redirect되고 최종 응답은 `HTTP/2 200`, `content-length: 66111087`이었다.

## 잔여 위험

- GitHub Release와 public DMG는 게시 완료됐지만, Stage 4 직후 Pages source가 아직 `devel-webview`로 설정되어 공개 appcast URL은 이전 빈 feed를 보고 있었다. 이 문제는 Stage 5에서 `main` `/docs`로 전환하고 Pages 재배포를 수동 요청해 해소했다.
- Homebrew Cask digest 고정, release note 문구 보정, mounted app Gatekeeper/stapler 검증은 Stage 5 범위로 넘겼다.

## 다음 단계 영향

Stage 5에서는 appcast 공개 URL, Pages 배포 설정, public DMG mounted app 검증, Cask SHA256 고정, 최종 보고서와 오늘할일 완료 처리를 수행한다.
