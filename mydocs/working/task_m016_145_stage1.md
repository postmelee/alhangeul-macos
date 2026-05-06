# Task M016 #145 Stage 1 보고서

## 단계 목적

v0.1 release artifact 생성 경로와 provenance 기준을 변경 없이 조사한다. `package-release` zip, rehearsal DMG, public DMG, release note skeleton, core/studio provenance, FFI symbol snapshot의 현재 상태를 확인해 Stage 2 artifact 구성 설계 입력을 확정한다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m016_145_stage1.md` | Stage 1 inventory, 검증 결과, Stage 2 설계 입력 정리 |

이번 단계에서는 소스, 스크립트, workflow, manual 파일을 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

본문 변경은 Stage 1 보고서 신규 작성뿐이다. 기존 release script, GitHub Actions workflow, `rhwp-core.lock`, `rhwp-studio` manifest, README/manual 문서는 읽기 전용으로 확인했다.

## 검증 결과

### 브랜치 상태

초기 확인 중 터미널이 `devel-webview`로 돌아와 있는 상태를 발견해, 보고서 작성 전 `local/task145`로 다시 전환했다. Stage 1 산출물 작성 전 기준 상태:

```text
$ git status --short --branch
## local/task145
```

### shell syntax

```text
$ bash -n scripts/package-release.sh scripts/release.sh scripts/ci/write-release-notes.sh
통과
```

### release script interface

```text
$ ./scripts/release.sh --help
Usage: ./scripts/release.sh [options] <version>

Options:
  --skip-notarize    Build a local rehearsal DMG without notarization or staple.
  --output <dir>     Write artifacts to the given directory. Defaults to build.noindex/release.
  --keep-staging     Keep intermediate files after the script exits.
```

public release mode는 `ALHANGEUL_DEVELOPER_ID_APPLICATION`, `ALHANGEUL_NOTARY_PROFILE`, 선택 `ALHANGEUL_DEVELOPER_ID_DMG`, `ALHANGEUL_BUILD_ROOT`를 입력으로 받는다.

### app/extension version

```text
$ plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
0.1.0

$ plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
0.1.0

$ plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
0.1.0
```

HostApp, Quick Look extension, Thumbnail extension의 user-facing version은 모두 `0.1.0`으로 일치한다.

### rhwp core lock

```text
lock_version = 2
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_ref_kind = "release-tag"
rhwp_release_tag = "v0.7.9"
rhwp_commit = "0fb3e6758b8ad11d2f3c3849c83b914684e83863"
built_at = "2026-05-01T03:42:53Z"
ffi_symbols_file = "rhwp-ffi-symbols.txt"
```

기록된 Rust bridge artifact:

| path | sha256 | size |
|------|--------|------|
| `Frameworks/universal/librhwp.a` | `4fc34a8cb7b6489d18705ee342fab13a79df5bd559893c10c163a0787c04e619` | `104179008` |
| `Frameworks/generated_rhwp.h` | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` | `1349` |

### rhwp-studio manifest

`Sources/HostApp/Resources/rhwp-studio/manifest.json`은 core lock과 같은 provenance를 기록한다.

| 항목 | 값 |
|------|----|
| source repository | `https://github.com/edwardkim/rhwp.git` |
| source ref kind | `release-tag` |
| source release tag | `v0.7.9` |
| source resolved commit | `0fb3e6758b8ad11d2f3c3849c83b914684e83863` |
| copied file count | `50` |
| copied total bytes | `27704089` |

entrypoint hash:

| entrypoint | path | sha256 |
|------------|------|--------|
| index_html | `index.html` | `4bcec64910b0fdfcacb8bae593b614c4af76c3c4d3f1d2252372a3d1a4202a29` |
| main_js | `assets/index-CCXookfl.js` | `3bb81abc018113c808253d75a62aa8ce19545bbccd4ece16d1b4c4df2f465986` |
| main_css | `assets/index-ro3nVBB2.css` | `d669a5f84fd2945f4d6be9a5471d6d2782ff629f77658a73f6f5d0f1133d7179` |
| wasm | `assets/rhwp_bg-DtQ01XFR.wasm` | `bfcf7632d7f4877b69abe3a95e52fa23636f5253c149de877d1975fdac608b41` |

### FFI symbol snapshot

`rhwp-ffi-symbols.txt` 현재 snapshot:

```text
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_size
rhwp_render_page_svg
rhwp_render_page_tree
```

총 10개 symbol이 release artifact provenance의 ABI 기준으로 기록되어 있다.

### artifact generation paths

검색 명령:

```text
$ rg -n "ZIP_NAME|DMG_NAME|sha256|checksum|expected_rhwp_tag|require_latest_rhwp|write-release-notes|release artifact" \
  scripts/package-release.sh scripts/release.sh scripts/ci/write-release-notes.sh .github/workflows/release-rehearsal.yml .github/workflows/release-publish.yml mydocs/manual/release_distribution_guide.md
```

확인 결과:

| 경로 | 산출물 | checksum 처리 | public release 사용 여부 |
|------|--------|---------------|--------------------------|
| `scripts/package-release.sh` | `alhangeul-macos-$VERSION.zip` | `shasum -a 256 "$ZIP_NAME"` stdout 출력만 수행 | 개발/검증용, 설치본 smoke 입력 |
| `scripts/release.sh --skip-notarize` | `alhangeul-macos-$VERSION-rehearsal.dmg` | `alhangeul-macos-$VERSION-rehearsal.dmg.sha256` 생성 | public release 사용 금지 |
| `scripts/release.sh` public mode | `alhangeul-macos-$VERSION.dmg` | `alhangeul-macos-$VERSION.dmg.sha256` 생성 | public release 기준 |
| `.github/workflows/release-rehearsal.yml` | rehearsal DMG artifact upload | `.sha256` 파일 검증 후 upload | public release 사용 금지 |
| `.github/workflows/release-publish.yml` | public DMG + `.sha256` GitHub Release upload | `.sha256` 검증, digest를 release note writer에 전달 | public release 기준 |

### release workflow core expectation

`.github/workflows/release-publish.yml` 기본 입력:

```yaml
expected_rhwp_tag:
  default: "v0.7.10"
require_latest_rhwp:
  default: true
```

현재 lock은 `v0.7.9`이므로, 기본 입력 그대로 public publish workflow를 실행하면 `Read and validate core lock` 단계에서 실패한다. `require_latest_rhwp`도 기본 `true`이므로 latest release 검증 역시 통과하려면 current lock을 upstream latest와 맞춰야 한다.

upstream latest 확인:

```text
$ gh release view -R edwardkim/rhwp --json tagName,publishedAt,url
{"publishedAt":"2026-05-05T17:56:40Z","tagName":"v0.7.10","url":"https://github.com/edwardkim/rhwp/releases/tag/v0.7.10"}
```

일반 sandbox에서는 `api.github.com` 연결이 실패해, 승인된 `gh release view` 실행으로 확인했다.

### release note skeleton

검증 명령:

```text
$ bash scripts/ci/write-release-notes.sh 0.1.0 \
  0000000000000000000000000000000000000000000000000000000000000000 \
  /private/tmp/rhwp-task145-release-notes.md
```

생성된 핵심 내용:

```text
# Alhangeul v0.1.0

## 산출물

- DMG: `alhangeul-macos-0.1.0.dmg`
- SHA256: `0000000000000000000000000000000000000000000000000000000000000000`

## 포함된 rhwp core

- release tag: `v0.7.9`
- commit: `0fb3e6758b8ad11d2f3c3849c83b914684e83863`
```

현재 skeleton은 public DMG 파일명, SHA256, `rhwp-core.lock`의 tag/commit을 포함한다. 다만 `rhwp-studio/manifest.json`, `THIRD_PARTY_LICENSES.md`, `FONTS.md`, smoke/known limitation 문서의 구체 링크는 아직 포함하지 않는다.

## Stage 2 설계 입력

- artifact 기준은 세 갈래로 분리해야 한다.
  - `package-release` zip: 개발/검증용 Release package, #151 설치본 smoke 입력
  - rehearsal DMG: layout/checksum rehearsal, public release 사용 금지
  - public DMG: signed/notarized/Gatekeeper/checksum 검증 후 GitHub Release와 사용자 배포 기준
- public checksum 공개 기준은 `alhangeul-macos-0.1.0.dmg.sha256`과 release note의 digest다.
- zip checksum은 현재 stdout으로만 출력되므로, public checksum으로 오해하지 않게 문서에서 분리해야 한다.
- current artifact provenance는 `v0.7.9`이고 upstream latest 및 publish workflow 기본 기대값은 `v0.7.10`이다. 이번 task에서 core pin을 바꾸지 않는다는 원칙을 유지하면, public publish 전 별도 core update 또는 workflow 입력 override 판단이 필요하다.
- release note skeleton은 core tag/commit과 checksum은 이미 포함하지만, `rhwp-studio` manifest와 third-party notice 진입점은 Stage 2/3에서 보강 후보로 판단해야 한다.

## 잔여 위험

- public publish workflow 기본값이 current lock과 충돌한다. core update 없이 publish하면 기본 설정에서는 실패한다.
- upstream latest `v0.7.10` 확인은 GitHub 네트워크 접근에 의존한다. CI에서는 workflow가 같은 검증을 수행하지만, 로컬 재현 시 네트워크 실패 가능성이 있다.
- Stage 1은 실제 artifact build를 수행하지 않았다. bundle 포함과 checksum의 실제 산출물 검증은 Stage 4에서 수행한다.
- release note의 fallback/smoke/known limitation 문구는 #150, #149, #151, #146 결과가 아직 없으므로 현재 단계에서 확정할 수 없다.

## 다음 단계 영향

Stage 2에서는 artifact별 공개/비공개/검증용 구분과 release note 공개 항목을 먼저 확정해야 한다. 특히 workflow 기본 `v0.7.10` 기대값을 문서 리스크로 유지할지, current `v0.7.9` artifact 기준으로 workflow default를 조정할지 결정해야 한다.

## 승인 요청

Stage 1 inventory 확인을 완료했다. 다음 단계는 Stage 2 `artifact 구성과 공개 항목 설계` 진입 승인이다.
