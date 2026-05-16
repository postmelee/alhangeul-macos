# Task M010 #166 Stage 1 보고서

## 단계 목적

`v0.1.0` public release 실행 전에 M16과 #177 선행 조건, release 기준 lock/plist/workflow, GitHub Actions secret/variable 준비 상태를 확인했다. 이 단계는 조사와 문서 보정만 수행했고, `main` 반영, tag 생성, GitHub Release workflow 실행, Homebrew Cask 변경은 수행하지 않았다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m010_166.md` | 현재 `gh` CLI가 `isLatest` JSON field를 지원하지 않는 점을 반영해 latest 확인 명령을 별도 호출로 보정 |
| `mydocs/plans/task_m010_166_impl.md` | Stage 4 검증 명령을 지원 가능한 `gh release view` field로 보정 |
| `mydocs/working/task_m010_166_stage1.md` | Stage 1 preflight 결과 기록 |
| `mydocs/orders/20260509.md` | #166 비고를 Stage 1 완료 후 승인 대기로 갱신 |

## 본문 변경 정도 / 본문 무손실 여부

앱 소스, release workflow, Cask, Pages asset은 변경하지 않았다. 계획서의 검증 명령만 로컬 `gh` CLI 호환성에 맞게 보정했다. 수행계획과 구현계획의 release 범위, 단계 구조, 승인 경계는 유지했다.

## 검증 결과

### 작업 브랜치와 기준 commit

| 항목 | 결과 |
|------|------|
| 현재 브랜치 | `local/task166` |
| 현재 HEAD | `45f1cb92fe27507d23d17b71dff2282a7002b518` |
| `origin/devel-webview` | `6a74f071d03916daa0ca362247dd4625fac5967f` |
| `origin/devel-webview` 포함 여부 | OK. `origin/devel-webview`는 현재 HEAD의 ancestor |
| `origin/devel-webview..HEAD` 변경 | #166 계획/오늘할일 문서 3개만 존재 |
| `origin/main` | `359ce0f4f95a4e249fa2b85cb6dccd92b663794f` |

`origin/main`은 현재 release source와 fast-forward 관계가 아니다. 또한 local `main`에는 `.github/workflows/release-publish.yml`과 `.github/workflows/release-rehearsal.yml`이 없었다. Stage 3에서는 `main` 반영 방식을 별도로 승인받아야 한다.

### 선행 이슈 상태

| 이슈 | 상태 | closedAt | 보고서 |
|------|------|----------|--------|
| #148 v0.1 서명·공증 배포 수준 결정 | CLOSED | `2026-05-08T04:51:35Z` | `mydocs/report/task_m016_148_report.md` |
| #145 v0.1 release artifact 구성과 provenance 정리 | CLOSED | `2026-05-07T03:23:00Z` | `mydocs/report/task_m016_145_report.md` |
| #151 Quick Look/Thumbnail 설치본 smoke gate 정리 | CLOSED | `2026-05-08T06:38:15Z` | `mydocs/report/task_m016_151_report.md` |
| #150 WKWebView viewer asset loading 실패 fallback 보강 | CLOSED | `2026-05-07T05:45:55Z` | `mydocs/report/task_m016_150_report.md` |
| #149 손상·대용량 HWP/HWPX 파일 opening fallback 보강 | CLOSED | `2026-05-08T05:24:44Z` | `mydocs/report/task_m016_149_report.md` |
| #146 Viewer와 Quick Look/Thumbnail 렌더 경로 한계 문서화 | CLOSED | `2026-05-08T07:12:46Z` | `mydocs/report/task_m016_146_report.md` |
| #167 rhwp v0.7.10 stable tag 반영과 M16 release 기준 재검증 | CLOSED | `2026-05-06T09:34:06Z` | `mydocs/report/task_m016_167_report.md` |
| #177 Sparkle 기반 업데이트 확인과 GitHub Pages appcast 준비 | CLOSED | `2026-05-08T16:38:01Z` | `mydocs/report/task_m010_177_report.md` |

선행 이슈와 최종 보고서 파일은 모두 확인됐다.

### core와 bundled studio provenance

| 항목 | 결과 |
|------|------|
| `rhwp-core.lock` release tag | `v0.7.10` |
| `rhwp-core.lock` commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| `Frameworks/universal/librhwp.a` sha256 | `fefa08d741cfdd6645081ca838601f677f6da064d95308555e29629f7609f7a2` |
| `Frameworks/generated_rhwp.h` sha256 | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` |
| `rhwp-studio` manifest release tag | `v0.7.10` |
| `rhwp-studio` manifest commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| copied file count | `54` |
| copied total bytes | `28412739` |

#167 handoff 기준과 현재 repository state가 일치한다. Stage 2에서 `./scripts/build-rust-macos.sh --verify-lock`와 `scripts/verify-rhwp-studio-assets.sh`로 다시 machine check를 수행한다.

### plist와 Sparkle 설정

| 항목 | 결과 |
|------|------|
| HostApp `CFBundleShortVersionString` | `0.1.0` |
| QLExtension `CFBundleShortVersionString` | `0.1.0` |
| ThumbnailExtension `CFBundleShortVersionString` | `0.1.0` |
| HostApp `CFBundleVersion` | `1` |
| `SUFeedURL` | `https://postmelee.github.io/alhangeul-macos/appcast.xml` |
| `SUPublicEDKey` | `5bIatnE362KFmrf9NneeE7gVvkKfTnWK7c26MwfFLSs=` |
| `SUEnableInstallerLauncherService` | `true` |
| `docs/appcast.xml` XML lint | OK |

현재 `docs/appcast.xml`은 release item이 없는 skeleton이다. #177 보고서의 handoff와 일치하며, official release workflow가 non-draft/non-prerelease 실행에서 stable item을 추가해야 한다.

### release workflow와 GitHub 상태

| 항목 | 결과 |
|------|------|
| `.github/workflows/release-publish.yml` parse | OK (`release-publish.yml ok`) |
| workflow default `version` | `0.1.0` |
| workflow default `expected_rhwp_tag` | `v0.7.10` |
| workflow default `draft` | `false` |
| workflow default `prerelease` | `false` |
| default branch | `main` |
| `gh workflow list` 현재 노출 workflow | `Copilot code review`, `pages-build-deployment` |
| 원격 `v0.1.0` tag | 없음 |
| GitHub Release `v0.1.0` | 없음 (`release not found`) |

release workflow 파일은 현재 `devel-webview` 계열에는 있지만, GitHub default branch인 `main`에는 아직 없다. Stage 3에서 release source를 `main`에 반영한 뒤 workflow 노출 여부를 다시 확인해야 한다.

### GitHub Actions secret/variable 준비 상태

| 확인 | 결과 |
|------|------|
| repository environments | `github-pages`만 존재 |
| `release` environment | 없음. `gh secret list --env release`, `gh variable list --env release` 모두 HTTP 404 |
| repository-level secrets | 목록 비어 있음 |
| repository-level variables | 목록 비어 있음 |

이 상태에서는 `Release Publish DMG` workflow의 signing/notarization/appcast 단계가 실행될 수 없다. 최소한 Stage 4 전에 `release` environment 또는 repository-level secret/variable을 구성해야 한다.

필요 이름:

- variables: `ALHANGEUL_DEVELOPER_ID_APPLICATION`, `ALHANGEUL_DEVELOPER_ID_DMG`, `ALHANGEUL_NOTARY_PROFILE`, `APPLE_TEAM_ID`, `ALHANGEUL_PAGES_BRANCH`
- secrets: `DEVELOPER_ID_APPLICATION_P12_BASE64`, `DEVELOPER_ID_APPLICATION_P12_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_APP_SPECIFIC_PASSWORD`, `RELEASE_KEYCHAIN_PASSWORD`, `SPARKLE_ED_PRIVATE_KEY`
- `APPLE_TEAM_ID`는 workflow에서 variable 또는 secret fallback을 허용하지만, 둘 중 하나는 필요하다.

### 명령 호환성 보정

현재 `gh release view`가 지원하는 JSON field에는 `isLatest`가 없다. 기존 계획서의 검증 후보 명령은 `Unknown JSON field: "isLatest"`로 실패했다. 따라서 다음처럼 보정했다.

```bash
gh release view v0.1.0 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,url,assets
gh release view --repo postmelee/alhangeul-macos --json tagName,url
```

첫 번째 명령은 특정 release 상태를, 두 번째 명령은 current latest release를 확인한다.

## 잔여 위험

- Stage 4 official release는 현재 GitHub Actions `release` environment와 secret/variable 부재로 blocked 상태다.
- GitHub default branch `main`이 `devel-webview` release source와 fast-forward 관계가 아니며, release workflows도 아직 `main`에 없다. Stage 3에서 반영 방식을 명시 승인받아야 한다.
- Stage 2 로컬 검증은 가능하지만, Developer ID signing/notarization과 Sparkle appcast signing은 GitHub secret 준비 전에는 검증할 수 없다.
- repository-level secret/variable 목록이 비어 있으므로, release credential 준비 상태는 작업지시자가 GitHub UI 또는 `gh secret set`/`gh variable set`으로 별도 구성해야 한다.
- `gh workflow list`는 default branch 기준으로 workflow를 보여주므로, Stage 3 전에는 `Release Publish DMG` workflow가 보이지 않는 것이 현재 상태와 일치한다.

## 다음 단계 영향

Stage 2 `release candidate 로컬 검증과 rehearsal`은 진행 가능하다. 다만 Stage 4 전에 다음 조치가 필요하다.

1. GitHub repository에 `release` environment 생성 또는 workflow의 environment 운용 방식 확정
2. release workflow가 요구하는 variables/secrets 등록
3. Stage 3에서 `main` 반영 방식 결정
4. `main` 반영 후 `Release Publish DMG` workflow 노출 확인

## 승인 요청

Stage 1 preflight를 완료했다. 다음 단계로 Stage 2 `release candidate 로컬 검증과 rehearsal`을 진행할지 승인 요청한다.
