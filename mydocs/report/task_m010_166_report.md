# Task #166 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#166 M16 완료 후 v0.1 첫 공개 배포 실행](https://github.com/postmelee/alhangeul-macos/issues/166) |
| 마일스톤 | M010 / v0.1 |
| release version | `0.1.0` |
| release tag | `v0.1.0` |
| release workflow | `https://github.com/postmelee/alhangeul-macos/actions/runs/25574049810` |
| GitHub Release | `https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.0` |
| 결론 | `v0.1.0` official GitHub Release를 draft/prerelease가 아닌 public release로 게시했고, signed/notarized DMG, checksum, Sparkle appcast, Pages 배포, Cask SHA256 고정까지 완료했다. |

## 최종 산출물

| 산출물 | 결과 |
|--------|------|
| `alhangeul-macos-0.1.0.dmg` | GitHub Release asset 게시 |
| `alhangeul-macos-0.1.0.dmg.sha256` | GitHub Release asset 게시 |
| DMG SHA256 | `98d4e1807dfece2acd08510441c0f1a41cad9a8f5bbe1b82cf9ed4d3abb0f3c4` |
| DMG size | `66111087` bytes |
| Sparkle appcast | `https://postmelee.github.io/alhangeul-macos/appcast.xml` |
| release note | `https://postmelee.github.io/alhangeul-macos/updates/v0.1.0.html` |
| latest download | `https://github.com/postmelee/alhangeul-macos/releases/latest/download/alhangeul-macos-0.1.0.dmg` |
| Cask | `Casks/alhangeul-macos.rb` version `0.1.0`, fixed SHA256 |

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | release readiness preflight 완료. 선행 M16/#177 상태, lock/plist/workflow, secret/variable 준비 항목 확인 |
| Stage 2 | Rust lock, bundled asset, no-AppKit, Debug/Release build, render smoke, Finder integration smoke, rehearsal DMG 검증 완료 |
| Stage 3 | release source를 `main`에 반영하고 `v0.1.0` tag push 완료 |
| Stage 4 | release workflow 실패 원인을 보정한 뒤 official signed/notarized DMG publish 성공 |
| Stage 5 | Pages appcast, public DMG mounted app, Cask SHA256, release note 문구, 최종 보고 정리 완료 |

## release provenance

| 항목 | 값 |
|------|----|
| rhwp upstream release | `v0.7.10` |
| rhwp resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| release workflow head | `a889c1551884fb3820012e63d81fd60874751dac` |
| appcast commit on `main` | `b672f406576ee811e7e41f082b20b48303ea14a2` |
| final local `main` after appcast | `b672f406576ee811e7e41f082b20b48303ea14a2` |
| final tag object | `0937bb2d98e8fdb98b4d4eaaa79d8f89323c1d9e` |
| final tag target | `a889c1551884fb3820012e63d81fd60874751dac` |

## release workflow 결과

final run `25574049810`은 성공했다.

```text
✓ Build signed/notarized DMG and publish release asset in 10m23s
```

주요 통과 항목:

- upstream latest `rhwp` release 확인
- Rust bridge lock 검증
- Developer ID certificate import
- notarization credential 저장
- signed/notarized DMG build
- public release artifact 검증
- GitHub Release asset publish
- Sparkle appcast 작성
- Pages branch appcast publish

## public artifact 검증

```bash
gh release view v0.1.0 --repo postmelee/alhangeul-macos \
  --json tagName,isDraft,isPrerelease,url,assets,publishedAt,targetCommitish
gh release download v0.1.0 --repo postmelee/alhangeul-macos \
  --dir /private/tmp/alhangeul-release-0.1.0.bMxXuh \
  --pattern alhangeul-macos-0.1.0.dmg \
  --pattern alhangeul-macos-0.1.0.dmg.sha256 \
  --clobber
shasum -a 256 -c alhangeul-macos-0.1.0.dmg.sha256
hdiutil verify /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg
codesign --verify --verbose=2 /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg
```

결과:

- release `isDraft=false`, `isPrerelease=false`
- public DMG와 `.sha256` asset 존재
- SHA256 검증 통과
- DMG image verify 통과
- DMG codesign verify 통과
- latest download URL이 `v0.1.0` DMG asset으로 redirect되고 `HTTP/2 200` 응답

mounted app 검증:

```bash
xcrun stapler validate .../mnt/Alhangeul.app
spctl --assess --type execute --verbose .../mnt/Alhangeul.app
xcrun stapler validate .../alhangeul-macos-0.1.0.dmg
spctl --assess --type open --context context:primary-signature --verbose .../alhangeul-macos-0.1.0.dmg
```

결과:

```text
The validate action worked!
.../mnt/Alhangeul.app: accepted
source=Notarized Developer ID
The validate action worked!
.../alhangeul-macos-0.1.0.dmg: accepted
source=Notarized Developer ID
```

## Sparkle와 Pages

`Release Publish DMG` workflow가 `docs/appcast.xml`을 `main`에 커밋했다.

```text
b672f40 Task #177: Update Sparkle appcast for v0.1.0
```

repository Pages source는 기존 `devel-webview` `/docs`에서 `main` `/docs`로 전환했고, Pages deployment run `25574667555`가 성공했다.

공개 appcast 검증:

```bash
curl -I -L https://postmelee.github.io/alhangeul-macos/appcast.xml
curl -fsSL -o /private/tmp/alhangeul-release-0.1.0.bMxXuh/appcast-pages.xml \
  https://postmelee.github.io/alhangeul-macos/appcast.xml
xmllint --noout /private/tmp/alhangeul-release-0.1.0.bMxXuh/appcast-pages.xml
```

appcast에는 다음 item이 포함된다.

| 항목 | 값 |
|------|----|
| title | `Alhangeul v0.1.0` |
| `sparkle:shortVersionString` | `0.1.0` |
| `sparkle:version` | `1` |
| enclosure URL | `https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg` |
| enclosure length | `66111087` |
| `sparkle:edSignature` | `sPMvi7Rc8Q8MXrndfwYDE97q+jG7ShngPv59H1VwB4nCz+3f1jezWP2PHGETl7zOZO4KaUKKkWP0nHSFED92BQ==` |
| minimum system | `12.0` |

## Homebrew Cask

`Casks/alhangeul-macos.rb`를 public DMG checksum으로 고정했다.

```ruby
version "0.1.0"
sha256 "98d4e1807dfece2acd08510441c0f1a41cad9a8f5bbe1b82cf9ed4d3abb0f3c4"
```

검증:

```bash
./scripts/update-cask-sha256.sh --dry-run 0.1.0 \
  /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg.sha256
ruby -c Casks/alhangeul-macos.rb
```

`brew audit --cask Casks/alhangeul-macos.rb`는 현재 Homebrew 환경에서 path audit이 비활성화되어 수행하지 못했다. 외부 tap push나 tap PR은 수행하지 않았다.

## 미실행/후속

| 항목 | 상태 |
|------|------|
| Sparkle GUI `업데이트 확인...` smoke | 통과. 사용자가 public DMG 설치본에서 메뉴를 직접 클릭했고 `최신 버전입니다` 창 표시 확인 |
| Homebrew tap 배포 | 미실행. repository 내 Cask digest 고정까지만 수행 |
| GitHub Actions Node.js 20 deprecation 대응 | 후속. 이번 release 성공에는 영향 없음 |
| 창 확대 시 WebView runtime error | 후속 이슈 #183으로 분리. `v0.1.1` patch release 후보에서 재검증 |

## 완료 판단

#166의 public release 실행 목표는 충족했다.

- `v0.1.0` GitHub Release가 public 상태로 게시됐다.
- signed/notarized/stapled DMG와 checksum이 release asset으로 존재한다.
- public DMG checksum과 Gatekeeper assessment가 검증됐다.
- Sparkle stable appcast가 public Pages URL에서 `v0.1.0` item을 제공한다.
- public DMG 설치본에서 Sparkle 수동 업데이트 확인 UI가 표시된다.
- GitHub Pages source가 앞으로의 운영 기준인 `main` `/docs`로 전환됐다.
- Homebrew Cask는 public DMG SHA256으로 고정됐다.
- release note의 다운로드 안내 문구가 게시 후 상태와 일치한다.

## 배포 회고와 재발 방지

이번 첫 public release에서 확인한 운영 교훈은 [`release_distribution_guide.md`](../manual/release_distribution_guide.md)의 `v0.1.0 public release 회고`와 릴리스 체크리스트에 반영했다.

사건 단위 troubleshooting 기록:

- [`release_v010_pages_appcast_source_mismatch.md`](../troubleshootings/release_v010_pages_appcast_source_mismatch.md)
- [`release_v010_installed_app_smoke_findings.md`](../troubleshootings/release_v010_installed_app_smoke_findings.md)

핵심 반영 사항:

- `ALHANGEUL_PAGES_BRANCH`와 GitHub Pages source branch/path가 일치해야 public appcast가 실제로 갱신된다.
- public appcast는 저장소 파일이 아니라 `https://postmelee.github.io/alhangeul-macos/appcast.xml` 응답을 직접 검증한다.
- release tag는 appcast bot commit 이전 release source commit을 가리킬 수 있으며, 공개 후 같은 version/tag를 덮어쓰지 않는다.
- Sparkle 수동 smoke는 첫 실행 자동 창이 아니라 메뉴의 `업데이트 확인...` 직접 실행으로 판정한다.
- public DMG 설치본 smoke에는 창 확대/resize 동작을 포함한다.
