# Task M016 #145 Stage 3 보고서

## 단계 목적

Stage 2에서 확정한 artifact 3계층과 checksum/provenance 공개 기준을 실제 운영 문서와 release note generator에 반영한다. #167 merge 이후 current core/studio provenance가 `v0.7.10`으로 정합화되었으므로, Stage 1-2의 `v0.7.9`/`v0.7.10` 불일치 판단은 이력으로 보존하고 Stage 3 이후 기준 문서는 현재 `v0.7.10` 상태를 따른다.

이번 단계에서는 실제 package, DMG, signing, notarization, GitHub Release 생성을 실행하지 않는다. 산출물 생성과 bundle 포함 검증은 Stage 4 범위다.

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `mydocs/manual/release_distribution_guide.md` | v0.1 artifact 3계층, checksum 공개 기준, provenance 진실 원천, `rhwp-studio` manifest/third-party notice release note 항목을 보강 |
| `scripts/ci/write-release-notes.sh` | release note skeleton에 bundled `rhwp-studio` tag/commit/manifest와 third-party notices 섹션 추가 |
| `mydocs/plans/task_m016_145.md` | #167 이후 current `v0.7.10` 기준으로 배경, Stage 1 입력, 리스크, 승인 기준 보정 |
| `mydocs/plans/task_m016_145_impl.md` | Stage 3 이후 기준을 `v0.7.10` 정합 상태로 보정하고 Stage 4 WASM 검증 파일명을 최신 asset으로 갱신 |
| `mydocs/orders/20260507.md` | #145 Stage 3 재개를 오늘할일에 등록 |

## 보강한 release 기준

### artifact 3계층

| 계층 | 기준 산출물 | public 사용 |
|------|-------------|-------------|
| 개발/설치본 smoke | `Alhangeul.app`, `alhangeul-macos-<version>.zip` | 아니오 |
| public release rehearsal | `alhangeul-macos-<version>-rehearsal.dmg`, `.sha256` | 아니오 |
| public release | `alhangeul-macos-<version>.dmg`, `.sha256` | 예 |

zip checksum은 단계 보고서와 설치본 smoke report용 식별자로만 남긴다. public하게 공개할 checksum은 signed/notarized public DMG의 `.sha256` 파일과 release note의 digest로 한정한다.

### provenance 진실 원천

| 대상 | 기준 |
|------|------|
| `rhwp` core tag/commit | `rhwp-core.lock` |
| Rust bridge artifact hash/size | `rhwp-core.lock` |
| FFI ABI surface | `rhwp-ffi-symbols.txt` |
| bundled `rhwp-studio` asset | `Sources/HostApp/Resources/rhwp-studio/manifest.json` |
| third-party notices | `THIRD_PARTY_LICENSES.md`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` |

## release note generator 변경

`scripts/ci/write-release-notes.sh`는 기존에 `rhwp-core.lock`에서 core tag/commit만 읽었다. 이번 단계에서 다음을 추가했다.

- `Sources/HostApp/Resources/rhwp-studio/manifest.json` 존재 확인
- `THIRD_PARTY_LICENSES.md` 존재 확인
- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` 존재 확인
- `plutil`로 `source_release_tag`, `source_resolved_commit` 추출
- release note에 `viewer asset provenance`와 `Third Party notices` 섹션 출력

검증용 dummy digest로 생성한 release note 핵심 출력:

```text
## 포함된 rhwp core
- release tag: `v0.7.10`
- commit: `62a458aa317e962cd3d0eec6096728c172d57110`

## 포함된 viewer asset provenance
- rhwp-studio release tag: `v0.7.10`
- rhwp-studio commit: `62a458aa317e962cd3d0eec6096728c172d57110`
- manifest: `Sources/HostApp/Resources/rhwp-studio/manifest.json`

## Third Party notices
- `THIRD_PARTY_LICENSES.md`
- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`
```

검증 산출물 `build.noindex/release/test-release-notes-0.1.0.md`는 ignored build output이며 commit 대상이 아니다.

## 변경하지 않은 파일

| 파일 | 이유 |
|------|------|
| `.github/workflows/release-publish.yml` | 기본 `expected_rhwp_tag: v0.7.10`이 #167 이후 current lock과 일치하므로 조정하지 않았다. |
| `.github/workflows/release-rehearsal.yml` | rehearsal artifact의 non-public 성격과 checksum summary가 이미 있고, manual 보강으로 충분하다. |
| `scripts/package-release.sh` | zip checksum stdout-only 동작을 유지한다. zip은 public checksum 기준이 아니다. |
| `scripts/release.sh` | public/rehearsal DMG와 `.sha256` 생성 경로가 이미 분리되어 있다. |
| `README.md` | #147/#167 이후 provenance 진입점이 있고, Stage 3 운영 절차는 manual에 두는 것이 적절하다. |

## 검증 결과

```bash
bash -n scripts/package-release.sh scripts/release.sh scripts/ci/write-release-notes.sh
./scripts/release.sh --help
scripts/verify-rhwp-studio-assets.sh
bash scripts/ci/write-release-notes.sh 0.1.0 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa build.noindex/release/test-release-notes-0.1.0.md
rg -n "alhangeul-macos-.*dmg|alhangeul-macos-.*zip|SHA256|rhwp-core.lock|rhwp-studio|manifest.json|THIRD_PARTY_LICENSES|FONTS.md|rehearsal|public release|expected_rhwp_tag|v0\.7\.9|v0\.7\.10" \
  README.md mydocs/manual/release_distribution_guide.md scripts/ci/write-release-notes.sh .github/workflows/release-rehearsal.yml .github/workflows/release-publish.yml scripts/package-release.sh scripts/release.sh mydocs/plans/task_m016_145.md mydocs/plans/task_m016_145_impl.md
git diff --check
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

- `bash -n` 통과
- `release.sh --help` 통과
- `write-release-notes.sh`는 직접 실행 권한이 없어 `bash scripts/ci/write-release-notes.sh ...`로 검증했고 성공
- release note 생성 결과에 `rhwp` core, bundled `rhwp-studio`, third-party notices 항목이 포함됨을 확인
- `git diff --check` 통과

## 잔여 위험

- Stage 4에서 아직 실제 `scripts/package-release.sh 0.1.0` 산출물을 만들지 않았다.
- public DMG, signing, notarization, GitHub Release upload는 이번 단계 범위가 아니다.
- `release-publish.yml`의 `require_latest_rhwp: true`는 현재 latest가 `v0.7.10`일 때 통과하는 기준이다. release 시점에 upstream latest가 바뀌면 별도 판단이 필요하다.
- #151 설치본 smoke, #146 known limitations, #150/#149 fallback 결과는 후속 단계/이슈에서 release note와 최종 보고서에 연결해야 한다.

## 판정

Stage 3 기준은 충족했다. 다음 단계는 Stage 4 `artifact 생성 리허설과 bundle 포함 검증`이며, 기본 입력은 `./scripts/package-release.sh 0.1.0`이다. public DMG rehearsal 또는 signing/notarization은 별도 승인 없이는 실행하지 않는다.
