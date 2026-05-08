# Task M010 #166 Stage 5 보고서

## 단계 목적

official release 이후 Sparkle appcast, GitHub Pages source, public DMG 설치본 검증, Homebrew Cask digest, 사용자-facing release note 문구를 최종 정리했다.

## 산출물

| 파일/외부 상태 | 내용 |
|----------------|------|
| `docs/appcast.xml` | workflow가 `v0.1.0` item을 추가한 GitHub Actions bot commit `b672f40` 반영 |
| GitHub Pages 설정 | source를 `main` `/docs`로 전환 |
| Pages deployment | run `25574667555`, `main` / `b672f406576ee811e7e41f082b20b48303ea14a2`, success |
| `Casks/alhangeul-macos.rb` | public DMG SHA256 고정 |
| `docs/updates/v0.1.0.html` | release가 이미 게시된 현재 상태에 맞게 다운로드 안내 문구 보정 |
| `mydocs/working/task_m010_166_stage5.md` | Stage 5 결과 기록 |
| `mydocs/report/task_m010_166_report.md` | 최종 결과 보고서 |
| `mydocs/orders/20260509.md` | #166 완료 처리 |

## Pages와 appcast 검증

workflow는 `ALHANGEUL_PAGES_BRANCH=main` 기준으로 `docs/appcast.xml`을 갱신했다.

```text
b672f40 Task #177: Update Sparkle appcast for v0.1.0
 docs/appcast.xml | 10 ++++++++++
```

다만 repository Pages source는 여전히 `devel-webview` `/docs`였다. 사용자 의도와 workflow variable에 맞춰 GitHub Pages source를 `main` `/docs`로 전환했다.

```json
{
  "build_type": "legacy",
  "source": {
    "branch": "main",
    "path": "/docs"
  },
  "html_url": "https://postmelee.github.io/alhangeul-macos/"
}
```

수동 Pages build 요청:

```text
POST repos/postmelee/alhangeul-macos/pages/builds
{"status":"queued","url":"https://api.github.com/repositories/1218518435/pages/builds/latest"}
```

Pages deployment 결과:

| 항목 | 결과 |
|------|------|
| run | `25574667555` |
| workflow | `pages-build-deployment` |
| branch | `main` |
| headSha | `b672f406576ee811e7e41f082b20b48303ea14a2` |
| conclusion | `success` |

공개 appcast URL 재검증:

```bash
curl -I -L https://postmelee.github.io/alhangeul-macos/appcast.xml
curl -fsSL -o /private/tmp/alhangeul-release-0.1.0.bMxXuh/appcast-pages.xml \
  https://postmelee.github.io/alhangeul-macos/appcast.xml
xmllint --noout /private/tmp/alhangeul-release-0.1.0.bMxXuh/appcast-pages.xml
```

응답:

```text
HTTP/2 200
content-type: application/xml
last-modified: Fri, 08 May 2026 19:16:33 GMT
content-length: 1159
```

appcast item 확인:

| 항목 | 값 |
|------|----|
| title | `Alhangeul v0.1.0` |
| `sparkle:shortVersionString` | `0.1.0` |
| `sparkle:version` | `1` |
| enclosure URL | `https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg` |
| enclosure length | `66111087` |
| `sparkle:edSignature` | `sPMvi7Rc8Q8MXrndfwYDE97q+jG7ShngPv59H1VwB4nCz+3f1jezWP2PHGETl7zOZO4KaUKKkWP0nHSFED92BQ==` |
| minimum system | `12.0` |

## public DMG 설치본 검증

다운로드한 public DMG를 mount해 내부 `Alhangeul.app`까지 검증했다.

```bash
hdiutil attach -nobrowse -readonly \
  -mountpoint /private/tmp/alhangeul-release-0.1.0.bMxXuh/mnt \
  /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg

xcrun stapler validate /private/tmp/alhangeul-release-0.1.0.bMxXuh/mnt/Alhangeul.app
spctl --assess --type execute --verbose /private/tmp/alhangeul-release-0.1.0.bMxXuh/mnt/Alhangeul.app
xcrun stapler validate /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg
spctl --assess --type open --context context:primary-signature --verbose \
  /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg
hdiutil detach /private/tmp/alhangeul-release-0.1.0.bMxXuh/mnt
```

결과:

```text
The validate action worked!
.../mnt/Alhangeul.app: accepted
source=Notarized Developer ID
The validate action worked!
.../alhangeul-macos-0.1.0.dmg: accepted
source=Notarized Developer ID
"disk14" ejected.
```

앱 메뉴의 `업데이트 확인...` GUI smoke는 실행하지 않았다. 이유는 사용자 세션에 앱을 foreground 실행하고 Sparkle UI를 확인해야 하므로 자동 release gate로 고정하지 않았기 때문이다. 대신 public appcast XML, EdDSA signature, release notes link, notarized app/DMG Gatekeeper assessment를 검증했다.

## Homebrew Cask

public DMG checksum으로 Cask digest를 고정했다.

```bash
./scripts/update-cask-sha256.sh --dry-run 0.1.0 \
  /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg.sha256
./scripts/update-cask-sha256.sh 0.1.0 \
  /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg.sha256
ruby -c Casks/alhangeul-macos.rb
```

결과:

```text
Cask: Casks/alhangeul-macos.rb
Version: 0.1.0
SHA256: 98d4e1807dfece2acd08510441c0f1a41cad9a8f5bbe1b82cf9ed4d3abb0f3c4
Syntax OK
```

`brew audit --cask Casks/alhangeul-macos.rb`는 이 Homebrew 설치에서 path audit이 비활성화되어 실행하지 못했다.

```text
Error: Calling `brew audit [path ...]` is disabled! Use `brew audit [name ...]` instead.
```

Homebrew tap push나 외부 tap PR은 수행하지 않았다. 이번 단계에서는 repository 내 Cask digest 고정까지만 완료했다.

## release note 보정

`docs/updates/v0.1.0.html`에 남아 있던 "릴리즈 게시 전에는 다운로드 파일이 준비되지 않았을 수 있음" 문구를 현재 public release 상태에 맞게 보정했다.

변경 후 문구:

```text
릴리즈 DMG와 checksum은 GitHub Release v0.1.0에서 함께 확인할 수 있습니다.
```

## 검증 결과

```bash
shasum -a 256 -c alhangeul-macos-0.1.0.dmg.sha256
hdiutil verify /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg
codesign --verify --verbose=2 /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg
xmllint --noout /private/tmp/alhangeul-release-0.1.0.bMxXuh/appcast-pages.xml
rg -n "v0\\.1\\.0|sparkle:edSignature|alhangeul-macos-0\\.1\\.0\\.dmg|sparkle:shortVersionString|minimumSystemVersion" \
  /private/tmp/alhangeul-release-0.1.0.bMxXuh/appcast-pages.xml
ruby -c Casks/alhangeul-macos.rb
./scripts/update-cask-sha256.sh --dry-run 0.1.0 \
  /private/tmp/alhangeul-release-0.1.0.bMxXuh/alhangeul-macos-0.1.0.dmg.sha256
xmllint --html --noout docs/updates/v0.1.0.html
```

결과:

- DMG checksum 검증 통과
- DMG image checksum 검증 통과
- DMG codesign 검증 통과
- appcast XML 검증 통과
- appcast `v0.1.0` item과 EdDSA signature 확인
- app/DMG stapler validate 통과
- app/DMG Gatekeeper assessment 통과
- Cask Ruby syntax 통과
- Cask SHA256 dry-run 통과
- HTML parser는 HTML5 tag 경고를 출력했지만 exit code 0으로 종료했다. 기존 문서 구조 문제이며 이번 문구 보정으로 새로 만든 오류는 확인되지 않았다.

## 완료 판단

Stage 5 완료 기준을 충족했다.

- Sparkle appcast 공개 URL이 official `v0.1.0` item과 EdDSA signature를 포함한다.
- Pages source가 `main` `/docs`로 전환됐고 deployment가 성공했다.
- public DMG와 내부 app이 notarized Developer ID로 Gatekeeper assessment를 통과했다.
- public DMG SHA256이 Cask에 고정됐다.
- 최종 보고서와 오늘할일 완료 처리 준비가 끝났다.

