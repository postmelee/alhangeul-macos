# GitHub Release, Pages, Sparkle 가이드

## 목적

이 문서는 GitHub Release 본문, Pages 업데이트 문서, Sparkle stable appcast, release delta checklist 기준을 정리한다. public DMG 생성과 signing/notarization은 각각 [`release_packaging_dmg_guide.md`](release_packaging_dmg_guide.md), [`release_signing_notarization_guide.md`](release_signing_notarization_guide.md)를 따른다.

## 권한 원칙

- GitHub Release 게시, release asset upload, Sparkle appcast 갱신, Pages deployment는 작업지시자의 명시 승인 후 수행한다.
- draft 또는 prerelease가 아닌 official release에서만 stable appcast와 Pages deployment를 실행한다.
- `main`에 merge된 `docs/**` 변경의 docs-only Pages 자동 배포는 승인된 merge 결과를 반영하는 운영 경로이며, Sparkle appcast를 새로 생성하지 않고 기존 public appcast를 보존한다.
- GitHub token과 Sparkle EdDSA private key는 저장소에 기록하지 않는다.

## GitHub Release 생성 전 확인

- release branch 또는 tag 기준 commit이 정확한가
- 릴리즈 상세 기록 `mydocs/release/v<version>.md`가 현재 release candidate 기준으로 갱신되었는가
- 직전 public release 대비 delta checklist가 생성되고 release owner가 보정했는가
- GitHub Release title이 기본형 `Alhangeul v<version>`을 쓰는가, 또는 upstream `rhwp` 반영 중심 release라서 `(rhwp vX.Y.Z)` 병기 조건을 충족하는가
- `rhwp-core.lock`의 core repository와 commit이 release note에 기록되었는가
- `rhwp-studio` manifest의 release tag와 commit이 release note에 기록되었는가
- third-party notices 위치가 release note에 기록되었는가
- `validate-stage3-render.sh` 결과가 release report에 기록되었는가
- DMG 파일 SHA256이 기록되었는가
- 렌더링 경로, 알려진 한계, 수동 확인 항목이 기록되었는가

## GitHub Release title

기본 title은 앱 버전만 사용한다.

```text
Alhangeul v<version>
```

Upstream `rhwp` core 또는 bundled `rhwp-studio` 반영이 release의 중심 사용자-facing 변화일 때만 다음 형식을 허용한다.

```text
Alhangeul v<version> (rhwp v<rhwp-version>)
```

이 예외를 쓰는 경우 release body의 `Release metadata`와 주요 변경 사항에 bundled `rhwp` 변경 영향과 검증 결과를 함께 기록한다. 앱 자체 bugfix, packaging, Pages/appcast, Homebrew, 문서 변경 중심 release는 기본 title을 유지한다.

## Delta checklist

delta checklist 초안 생성:

```bash
scripts/ci/write-release-delta-checklist.sh <previous-release-tag> <candidate-ref> build.noindex/release/delta-checklist-<version>.md
```

GitHub Actions workflow에서 생성되는 경우:

- `Release Rehearsal DMG`
  - input: `previous_release_ref`
  - candidate ref: workflow checkout commit인 `$GITHUB_SHA`
  - artifact: `alhangeul-macos-<version>-rehearsal-delta-checklist`
- `Release Publish DMG`
  - input: `previous_release_ref`
  - candidate ref: `v<version>`
  - artifact: `alhangeul-macos-<version>-release-delta-checklist`

두 workflow 모두 `GITHUB_STEP_SUMMARY`에 previous ref, candidate ref, checklist path를 남긴다. workflow artifact 또는 로컬 helper 출력 중 하나를 release owner가 검토하고 보정한다.

이 helper는 변경 파일 path 기반 초안만 만든다. release owner는 누락, 과잉, 실제 사용자 영향, 수동 smoke 필요 여부를 보정해야 한다.

영향 영역 후보:

- HostApp viewer
- Quick Look preview
- Finder thumbnail
- 저장/다른 이름 저장
- PDF/인쇄/공유
- Sparkle/appcast/Pages
- DMG/signing/notarization
- Homebrew Cask
- `rhwp` core/viewer asset provenance
- 문서 전용 변경

## Release note 본문

Release note에 포함할 내용:

- 사용자용 요약
- 설치 방법
- 지원 macOS 버전과 지원 아키텍처
- 설치 후 첫 실행과 Quick Look/Thumbnail 활성화 안내
- 업데이트 확인 방법
- 주요 변경 사항
- 다운로드 산출물과 SHA256
- Homebrew Cask 공개 상태
- `Release metadata`: app version, `edwardkim/rhwp` core tag/commit, bundled `rhwp-studio` tag/commit, `rhwp-core.lock`, studio manifest
- HostApp viewer, PDF 내보내기, 인쇄, Quick Look, Thumbnail의 렌더링 경로와 알려진 한계
- 설치본 smoke 결과와 수동 확인 항목
- 릴리즈 delta 기반 추가 확인 항목
- Third Party notices와 bundled font notice 위치
- 설치/실행 주의사항
- Quick Look/Thumbnail extension 등록 확인 방법
- 알려진 문제

Homebrew Cask 안내 기준:

- #209의 tap context 검증이 끝나기 전에는 Homebrew 설치 명령을 public 안내에 확정 문구로 쓰지 않는다.
- 검증 전 공식 설치 경로는 GitHub Release DMG와 Pages 다운로드 버튼이다.
- Cask URL은 Sparkle enclosure와 마찬가지로 tag 고정 public universal DMG URL을 사용하고, Intel Mac/Apple Silicon Mac용 URL을 나누지 않는다.
- #209 완료 후 공개할 명령은 `brew install --cask postmelee/tap/alhangeul-macos`를 기준으로 하며, README, GitHub Release 본문, Pages 문구가 같은 명령을 써야 한다.

본문 후보 생성:

```bash
scripts/ci/write-release-notes.sh <version> <public-dmg-sha256> build.noindex/release/release-notes-<version>.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-<version>.md
```

`Release metadata`는 `rhwp-core.lock`과 `Sources/HostApp/Resources/rhwp-studio/manifest.json`에서 읽은 값을 기준으로 생성한다. 수동 release note를 작성할 때도 같은 항목명을 사용해 내부 release record와 대조할 수 있게 한다.

## Pages 업데이트 문서

Pages는 사용자용 릴리즈 안내 표면이다. GitHub Release body의 긴 provenance, delta checklist, PR별 검증 기록을 그대로 복제하지 않는다.

확인 기준:

- `docs/updates/v<version>.html`이 현재 사이트의 header, hero, action button, content section, footer 구조를 유지하는가
- `docs/updates/index.html`의 최신 항목과 latest DMG link가 최신 public release 파일명을 가리키는가
- Pages 다운로드 버튼이 아키텍처 선택 UI 없이 단일 universal DMG latest URL을 직접 가리키는가
- 사용자가 필요한 설치 방법, 첫 실행 안내, 업데이트 확인, 알려진 한계를 간결하게 확인할 수 있는가
- Intel Mac과 Apple Silicon Mac이 같은 DMG를 사용한다는 안내가 최신 다운로드 주변 또는 FAQ/릴리즈 노트에 있는가
- bundled `rhwp`를 안내해야 하는 release라면 `rhwp v<version>`과 upstream release 링크를 짧게 표시하고, commit/manifest/checksum 표는 GitHub Release body와 내부 release record로 연결하는가
- 실제 public DMG SHA256이 아직 확정되지 않은 문서는 release candidate 또는 #188 handoff 상태를 명확히 표시하는가

Pages 다운로드 버튼은 사용자를 위한 latest DMG URL을 사용한다.

```text
https://github.com/postmelee/alhangeul-macos/releases/latest/download/alhangeul-macos-<version>.dmg
```

### Pages 배포 모델

Pages/appcast 배포는 GitHub Actions Pages deployment 기준이다. repository Pages source는 `build_type=workflow`이어야 하며, `Release Publish DMG` workflow의 official stable release path가 generated `appcast.xml`을 포함한 Pages artifact를 업로드한 뒤 `deploy-pages` job으로 배포한다.

필수 repository 설정:

- Pages source: `workflow`
- environment: `github-pages`
- `github-pages` deployment branch/tag policy: docs-only 배포용 `main` branch와 release tag ref `v<version>`을 허용하는 tag rule `v*`

workflow 기준:

- `scripts/ci/prepare-pages-artifact.sh`가 release tag에 포함된 `docs/` 정적 파일과 generated `appcast.xml`을 Pages artifact directory로 조립한다.
- `actions/upload-pages-artifact@v5`가 Pages artifact를 업로드한다.
- `actions/deploy-pages@v5`가 `github-pages` environment로 배포하고 `page_url` output을 남긴다.
- `deploy-pages` job은 `pages: write`, `id-token: write` 권한을 가진다.
- release workflow와 docs-only workflow는 `pages-deploy` concurrency group을 공유하고 `cancel-in-progress: false`로 Pages deployment를 취소 없이 직렬화한다.
- generated appcast는 Pages source branch에 commit하지 않는다. 장기 기록은 workflow artifact/deployment 기록과 `mydocs/release/v<version>.md`에 남긴다.

### Docs-only Pages 배포

`Docs-only Pages Deploy` workflow는 release와 무관한 `docs/**` 변경을 public Pages에 반영한다. 이 workflow는 `push` to `main` with `docs/**`와 `workflow_dispatch`에서 실행되며, 내부에서 `GITHUB_REF=refs/heads/main`을 확인한다.

역할 분리:

- `Release Publish DMG`: official stable release에서 signed/notarized DMG, GitHub Release asset, generated stable appcast, Pages artifact를 함께 게시한다.
- `Docs-only Pages Deploy`: 이미 public Pages에 배포된 latest appcast를 보존하면서 `docs/` 정적 파일 변경만 배포한다.

appcast 보존 기준:

- docs-only workflow는 Sparkle appcast를 새로 생성하지 않는다.
- public `https://postmelee.github.io/alhangeul-macos/appcast.xml`을 다운로드해 `test -s`와 `xmllint --noout` 검증을 통과한 파일만 Pages artifact root의 `appcast.xml`로 사용한다.
- repository의 `docs/appcast.xml`은 stale copy일 수 있으므로 docs-only 배포 source로 사용하지 않는다.
- public appcast 다운로드 또는 XML 검증이 실패하면 Pages deployment를 중단한다.
- stale `docs/appcast.xml` fallback은 허용하지 않는다.

## Sparkle appcast

알한글 앱은 stable feed 하나만 사용한다.

```text
https://postmelee.github.io/alhangeul-macos/appcast.xml
```

앱에 포함된 `SUPublicEDKey`는 Sparkle update archive 검증용 public key다. private key는 저장소에 기록하지 않고, release workflow에서는 GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY`로만 전달한다.

Sparkle private key를 GitHub Actions secret에 등록해야 할 때는 release 관리자 로컬 Keychain에서 다음 방식으로 export한다.

```bash
build.noindex/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  -x /path/to/sparkle_ed_private_key.txt
```

export한 파일 내용 전체를 `SPARKLE_ED_PRIVATE_KEY` secret 값으로 등록한 뒤, 파일은 안전하게 삭제한다. 이 값은 Keychain의 “Private key for signing Sparkle updates” 항목 password와 동일한 민감 정보로 취급한다.

`Release Publish DMG` workflow의 appcast 동작 기준:

- `draft=false`이고 `prerelease=false`인 공식 release에서만 stable appcast를 갱신한다.
- draft 또는 prerelease 실행에서는 stable appcast를 갱신하지 않고 step summary에 skip 사유만 남긴다.
- workflow는 signed/notarized DMG를 GitHub Release asset으로 업로드한 뒤 `sign_update --ed-key-file - -p`로 DMG EdDSA signature를 만든다.
- `scripts/ci/write-sparkle-appcast.sh`가 tag 고정 DMG URL과 release notes URL로 `appcast.xml`을 생성한다.
- workflow는 generated `appcast.xml`을 Pages artifact root의 `appcast.xml`로 포함한다.
- `deploy-pages` job이 성공해야 stable appcast 배포 성공으로 본다. branch push fallback을 기본 경로로 사용하지 않는다.

appcast enclosure URL은 latest URL이 아니라 tag 고정 URL을 사용한다.

```text
https://github.com/postmelee/alhangeul-macos/releases/download/v<version>/alhangeul-macos-<version>.dmg
```

이 URL은 단일 universal DMG를 가리킨다. Sparkle appcast는 아키텍처별 enclosure를 나누지 않고, `scripts/release.sh`/workflow가 검증한 `arm64 + x86_64` app/extension bundle을 포함한 public DMG만 stable item으로 사용한다.

Sparkle appcast의 version/build와 enclosure filename은 앱 버전만 사용한다. Bundled `rhwp` 버전은 appcast item version에 넣지 않고, release notes URL이 가리키는 GitHub Pages/GitHub Release metadata에서 확인하게 한다.

따라서 공식 release 완료 후에는 다음을 확인한다.

- `https://github.com/postmelee/alhangeul-macos/releases/latest`가 방금 게시한 non-draft, non-prerelease release를 가리키는가
- `Release Publish DMG` workflow의 `deploy-pages` job이 성공했고 `page_url`이 `https://postmelee.github.io/alhangeul-macos/`를 가리키는가
- Pages 다운로드 버튼의 asset filename이 최신 public DMG 파일명과 일치하는가
- `https://postmelee.github.io/alhangeul-macos/appcast.xml`이 새 release item과 Sparkle EdDSA signature를 포함하는가
