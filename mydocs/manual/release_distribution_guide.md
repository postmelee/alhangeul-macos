# 릴리스/배포 가이드

## 목적

이 문서는 `alhangeul-macos` 릴리스/배포 작업의 진입점이다. AI agent와 작업자는 이 문서에서 권한 원칙, 전체 흐름, 필요한 세부 매뉴얼을 먼저 확인한 뒤 해당 작업에 맞는 하위 문서만 추가로 읽는다.

공개 `README.md`는 프로젝트 소개와 소스 빌드 중심으로 유지한다. 릴리스/배포 절차는 권한, 인증서, 배포 정책, 버전 확정이 필요한 작업이므로 `mydocs/manual/`의 릴리즈 매뉴얼 묶음에서만 다룬다.

## 권한 원칙

- 릴리스/배포 작업은 저장소 소유자의 명시 지시가 있을 때만 수행한다.
- Claude와 Codex가 임의로 버전 태그, GitHub Release, Homebrew Cask PR, 서명/공증 작업을 시작하지 않는다.
- public release 실행, GitHub Release 게시, Sparkle appcast 갱신, Homebrew Cask 반영은 각각 작업지시자의 명시 승인 후 수행한다.
- 인증서 private key, Apple Developer 계정, notarization credential, GitHub token, Homebrew tap 권한은 작업지시자가 직접 관리한다.
- 민감 정보는 문서, commit, PR, shell history에 남기지 않는다.
- Team ID, signing identity 표시명, keychain profile name처럼 비밀이 아닌 운영 식별자는 [`release_environment.md`](../tech/release_environment.md)에만 기록한다.

## 하위 매뉴얼

| 문서 | 읽는 시점 | 내용 |
|------|-----------|------|
| [`ci_workflow_guide.md`](ci_workflow_guide.md) | PR CI, release rehearsal/publish workflow, upstream check의 역할과 재현 명령을 확인할 때 | workflow trigger, 권한, 변경 범위 flag, docs-only skip, release delta checklist summary/artifact |
| [`release_policy_guide.md`](release_policy_guide.md) | 릴리스 정책, 산출물 계층, 사용자 안내 기준을 판단할 때 | 운영 기준, 배포 브랜치, public 배포 수준, artifact/checksum/provenance, 렌더링 경로와 알려진 한계 |
| [`release_packaging_dmg_guide.md`](release_packaging_dmg_guide.md) | package/release script, DMG, Finder smoke를 다룰 때 | 릴리스 전 확인, build 검증, zip, public/rehearsal DMG, DMG layout, Finder 통합 smoke |
| [`release_signing_notarization_guide.md`](release_signing_notarization_guide.md) | Developer ID, notarytool, Gatekeeper 검증을 다룰 때 | credential 원칙, 기록 금지 정보, signing/notarization 확인, `codesign`/`stapler`/`spctl` |
| [`release_github_pages_sparkle_guide.md`](release_github_pages_sparkle_guide.md) | GitHub Release, Pages, Sparkle appcast를 다룰 때 | release note template, delta checklist, Pages 업데이트 문서, stable appcast |
| [`release_homebrew_cask_guide.md`](release_homebrew_cask_guide.md) | Homebrew Cask와 tap 배포를 다룰 때 | Cask source, public DMG SHA256, tap 반영, `brew style`/`brew audit` |

릴리즈별 실제 결정, SHA256, 검증 기록은 [`mydocs/release/`](../release/)에 남긴다. 환경 스냅샷은 [`release_environment.md`](../tech/release_environment.md)에 둔다. 실패 증상, 재현 조건, 원인, 재발 방지 절차가 모인 경우에만 `mydocs/troubleshootings/`로 분리한다.

## 현재 release 자산

- `scripts/package-release.sh`: Release configuration 개발/검증용 zip 생성
- `scripts/release.sh`: public DMG 생성, Developer ID 서명, notarization, staple, Gatekeeper 검증, sha256 생성
- `scripts/ci/write-release-notes.sh`: GitHub Release 본문 후보 생성
- `scripts/ci/check-release-notes-template.sh`: release note 필수 heading 검증
- `scripts/ci/write-release-delta-checklist.sh`: 직전 public release 대비 영향 영역 checklist 초안 생성
- `scripts/ci/write-sparkle-appcast.sh`: stable Sparkle appcast 생성
- `scripts/ci/classify-pr-changes.sh`: PR CI 변경 범위 flag 생성
- `.github/workflows/pr-ci.yml`: PR 생성/갱신 시 기본 gate와 조건부 macOS/release helper 검증
- `.github/workflows/release-rehearsal.yml`: rehearsal DMG/checksum과 release delta checklist artifact 생성
- `.github/workflows/release-publish.yml`: signed/notarized DMG, GitHub Release asset, stable appcast, release delta checklist artifact 생성
- `docs/appcast.xml`, `docs/updates/`: Sparkle feed와 사용자용 업데이트 페이지
- `Casks/alhangeul-macos.rb`: Homebrew Cask source 초안
- `rhwp-core.lock`, `Sources/HostApp/Resources/rhwp-studio/manifest.json`: core/viewer asset provenance

## 전체 release flow

1. release version, release candidate commit, 포함 PR 범위를 확정한다.
2. [`release_policy_guide.md`](release_policy_guide.md)의 branch, artifact, 사용자 안내 기준을 확인한다.
3. [`ci_workflow_guide.md`](ci_workflow_guide.md)의 PR CI와 release workflow 역할을 확인한다.
4. [`release_packaging_dmg_guide.md`](release_packaging_dmg_guide.md)의 릴리스 전 확인과 build 검증을 수행한다.
5. 필요한 경우 `Release Rehearsal DMG` workflow를 실행하고 DMG/checksum과 delta checklist artifact를 확인한다.
6. [`release_signing_notarization_guide.md`](release_signing_notarization_guide.md)의 credential 확인을 수행한다.
7. `Release Publish DMG` workflow 또는 `scripts/release.sh <version>` public mode로 signed/notarized DMG를 생성한다.
8. public DMG SHA256을 기록하고 DMG layout, Finder Quick Look, Finder thumbnail smoke를 반복한다.
9. [`release_github_pages_sparkle_guide.md`](release_github_pages_sparkle_guide.md)의 release note와 delta checklist를 실제 SHA256/provenance로 보정한다.
10. GitHub Release를 공식 release 기준으로 게시하고 `Release Publish DMG` workflow 결과를 확인한다.
11. Pages 업데이트 페이지, latest DMG link, stable Sparkle appcast를 확인한다.
12. Homebrew 배포를 진행할 경우 [`release_homebrew_cask_guide.md`](release_homebrew_cask_guide.md)에 따라 SHA256을 고정하고 tap 검증을 수행한다.
13. [`mydocs/release/v<version>.md`](../release/)와 최종 release report에 실제 결과와 잔여 위험을 기록한다.

## public release 전 확정 항목

- release version과 release candidate commit
- `devel-webview`에서 `main`으로 반영할 release PR 범위
- Developer ID 서명/notarization 실행 시점
- GitHub Release를 draft/prerelease가 아닌 public release로 게시할 시점
- Cask 초안의 `sha256 :no_check`를 public DMG 생성 후 실제 digest로 교체할 시점
- Homebrew tap 공개 여부

## 최종 체크리스트

- [ ] 릴리스 버전 확정
- [ ] 릴리스 기준 branch/commit 확정
- [ ] `mydocs/release/v<version>.md` 릴리즈 상세 기록 초안 작성
- [ ] PR CI 또는 동등한 로컬 검증 결과 확인
- [ ] `scripts/ci/write-release-delta-checklist.sh`로 직전 public release 대비 delta checklist 생성
- [ ] workflow 사용 시 `previous_release_ref` 입력과 delta checklist summary/artifact 확인
- [ ] release owner가 delta checklist 누락/과잉 항목 보정
- [ ] `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock` 정합성 확인
- [ ] `./scripts/build-rust-macos.sh --verify-lock` 통과
- [ ] `scripts/verify-rhwp-studio-assets.sh` 통과
- [ ] Debug build 통과
- [ ] Release build 통과
- [ ] `validate-stage3-render.sh` 통과
- [ ] Finder Quick Look smoke test 완료
- [ ] Finder thumbnail smoke test 완료
- [ ] 개발용 zip 산출물 생성
- [ ] public DMG 산출물 생성
- [ ] public DMG SHA256 기록
- [ ] public DMG layout smoke 완료
- [ ] DMG root에 `설치 안내.txt` 같은 보조 안내 파일이 노출되지 않는지 확인
- [ ] DMG background가 720x460 PNG 기준인지 확인
- [ ] release note에 `rhwp-core.lock`, `rhwp-studio` manifest, third-party notices 기준 기록
- [ ] release note에 렌더링 경로, 알려진 한계, 수동 확인 항목 기록
- [ ] release note template 필수 섹션 검증
- [ ] 서명/공증 검증 완료
- [ ] GitHub Release note 작성
- [ ] Pages 릴리즈 노트와 업데이트 index의 version/DMG URL 확인
- [ ] README 최신 공개 릴리즈 요약 갱신 여부 결정
- [ ] `SPARKLE_ED_PRIVATE_KEY` secret 등록 확인
- [ ] `Release Publish DMG` workflow를 공식 release 기준 `draft=false`, `prerelease=false`로 실행
- [ ] `docs/appcast.xml`이 Pages branch에 갱신되었는지 확인
- [ ] Pages 다운로드 버튼과 appcast URL이 public DMG asset을 가리키는지 확인
- [ ] Homebrew 배포 시 `scripts/update-cask-sha256.sh`로 Cask version/sha256 갱신
- [ ] Homebrew tap 대상 확정
- [ ] tap 반영 후 `brew style`/`brew audit` 검증
- [ ] Homebrew Cask 갱신 여부 결정
- [ ] 릴리스 최종 보고서 작성

## Rollback

릴리스에 문제가 있으면 다음 순서로 대응한다.

1. GitHub Release asset을 숨기거나 삭제한다.
2. Homebrew Cask가 공개된 경우 해당 버전 설치 경로를 중단하거나 새 patch release를 만든다.
3. 문제를 GitHub Issue로 등록한다.
4. 원인, 영향 범위, 재발 방지책을 `mydocs/troubleshootings/`에 기록한다.
5. 수정 PR을 출시 대상 통합 브랜치로 merge한 뒤 새 릴리스 후보를 만든다.

현재 WebView-backed release line 기준은 `devel-webview`이며, native renderer 장기 브랜치에도 필요한 수정은 별도 PR 또는 cherry-pick으로 `devel`에 후속 반영한다.
