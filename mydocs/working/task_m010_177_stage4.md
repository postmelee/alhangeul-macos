# Task M010 #177 Stage 4 보고서

## 목표

release publish workflow가 GitHub Release DMG asset과 Sparkle EdDSA signature를 기준으로 `docs/appcast.xml`을 갱신할 수 있게 한다.

이번 단계는 실제 public DMG를 생성하거나 GitHub Release를 실행하지 않는다. script, workflow, 운영 문서를 연결하고 fixture 값으로 생성 결과를 검증했다.

## 변경 사항

### appcast 생성 script

`scripts/ci/write-sparkle-appcast.sh`를 추가했다.

입력:

- `--version`: `CFBundleShortVersionString`
- `--build`: `CFBundleVersion`
- `--dmg-url`: tag 고정 GitHub Release DMG URL
- `--length`: DMG byte length
- `--ed-signature`: Sparkle EdDSA signature
- `--release-notes-url`: Pages release notes URL
- `--pub-date`: RSS `pubDate`
- `--minimum-system-version`: 기본값 `12.0`
- `--output`: 출력 XML path

출력:

- Sparkle RSS feed XML
- `sparkle:version`은 build number를 사용
- `sparkle:shortVersionString`은 사용자 표시 version을 사용
- `enclosure`에는 DMG URL, length, `sparkle:edSignature`를 기록
- `sparkle:minimumSystemVersion`을 기록

### release publish workflow

`.github/workflows/release-publish.yml`을 갱신했다.

공식 release 기준을 기본값으로 맞췄다.

- `draft` 기본값: `false`
- `prerelease` 기본값: `false`

release publish 후 `gh release edit`을 실행해 기존 release가 있더라도 입력값에 맞춰 draft/prerelease 상태와 release note를 갱신하게 했다. `draft=false`, `prerelease=false`일 때는 `--latest`도 지정한다.

새 appcast 단계:

1. publish된 GitHub Release 상태를 검증한다.
2. stable release(`draft=false`, `prerelease=false`)에서만 Sparkle CLI tool을 resolve한다.
3. `SPARKLE_ED_PRIVATE_KEY` secret으로 DMG EdDSA signature를 생성한다.
4. `scripts/ci/write-sparkle-appcast.sh`로 `appcast.xml`을 생성하고 XML lint를 수행한다.
5. Pages source branch를 별도 clone한 뒤 `docs/appcast.xml`만 GitHub Actions bot commit으로 갱신한다.
6. 생성된 appcast를 workflow artifact로도 업로드한다.

draft 또는 prerelease 실행에서는 stable appcast를 갱신하지 않고 step summary에 skip 사유만 남긴다.

### 운영 문서

`mydocs/manual/release_distribution_guide.md`에 Sparkle appcast 운영 기준을 추가했다.

- stable feed URL
- `SPARKLE_ED_PRIVATE_KEY` secret 등록 기준
- `generate_keys -x`를 통한 private key export 방법
- `ALHANGEUL_PAGES_BRANCH` repository variable 기준
- appcast enclosure는 tag 고정 URL을 사용하고 Pages 다운로드 버튼은 latest URL을 사용한다는 차이
- release checklist의 appcast 확인 항목

## 검증

```bash
bash -n scripts/ci/write-sparkle-appcast.sh
```

결과: 문법 오류 없음.

```bash
bash scripts/ci/write-sparkle-appcast.sh --help
```

결과: 사용법 출력 정상.

```bash
bash scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.0 \
  --build 1 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg \
  --length 123456 \
  --ed-signature TEST_SIGNATURE \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.0.html \
  --pub-date 'Fri, 08 May 2026 09:00:00 +0000' \
  --output /tmp/alhangeul-stage4-appcast.xml
xmllint --noout /tmp/alhangeul-stage4-appcast.xml
```

결과: XML 문법 오류 없음.

생성 XML에서 확인한 항목:

```text
sparkle:version = 1
sparkle:shortVersionString = 0.1.0
sparkle:releaseNotesLink = https://postmelee.github.io/alhangeul-macos/updates/v0.1.0.html
enclosure url = https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg
sparkle:minimumSystemVersion = 12.0
```

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release-publish.yml"); puts "ok"'
```

결과:

```text
ok
```

실행 환경의 Ruby `ffi` gem warning이 함께 출력되었지만 YAML parse 자체는 성공했다.

```bash
./scripts/release.sh --help
```

결과: release script interface 출력 정상.

```bash
git diff --check
```

결과: 문제 없음.

## 리스크와 후속 처리

- 실제 Sparkle `sign_update` 실행은 public DMG와 `SPARKLE_ED_PRIVATE_KEY` GitHub Actions secret이 있어야 검증할 수 있으므로 Stage 4에서는 fixture signature로 XML 생성만 확인했다.
- `SPARKLE_ED_PRIVATE_KEY` secret이 없으면 official stable release workflow는 appcast signing 단계에서 fail-fast 한다.
- Pages branch push는 repository permission 또는 branch protection에 영향을 받는다. 실패하면 workflow가 실패하고 `docs/appcast.xml`은 수동 복구해야 한다.
- 현재 workflow는 `docs/appcast.xml`만 자동 갱신한다. 새 버전마다 Pages release note page와 최신 다운로드 asset filename 갱신 여부는 release checklist에서 확인해야 한다.

## 다음 단계

작업지시자가 Stage 5를 요청하면 통합 검증과 최종 보고를 진행한다.
