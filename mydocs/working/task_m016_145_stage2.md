# Task M016 #145 Stage 2 보고서

## 단계 목적

Stage 1 inventory를 바탕으로 v0.1 release artifact의 종류별 책임 경계와 공개 항목을 설계한다. 개발/검증용 zip, rehearsal DMG, public DMG의 사용 범위, checksum 공개 기준, release note provenance 항목, Stage 3 변경 대상을 확정한다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m016_145_stage2.md` | artifact 구성표, checksum/provenance 공개 기준, Stage 3 변경안 정리 |

이번 단계에서는 설계 보고서만 추가했다. 기존 `README.md`에 남아 있는 미커밋 변경은 Stage 1 완료 시점부터 존재한 별도 변경으로, 이번 단계에서도 수정하거나 staging하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

본문 변경은 Stage 2 보고서 신규 작성뿐이다. 스크립트, workflow, manual, README는 읽기 전용으로 판단했고 실제 보강은 Stage 3에서 수행한다.

## artifact 구성 설계

### 전체 기준

v0.1 artifact는 사용 목적을 기준으로 세 계층으로 분리한다.

| 계층 | 기준 산출물 | 목적 | public 사용 |
|------|-------------|------|-------------|
| 개발/설치본 smoke | `package-release` zip과 staging app | Release configuration bundle 구성과 #151 설치본 smoke 입력 | 아니오 |
| public release rehearsal | `*-rehearsal.dmg`와 `.sha256` | DMG layout, checksum, release script path 확인 | 아니오 |
| public release | signed/notarized/stapled DMG와 `.sha256` | GitHub Release asset, 사용자 배포, Cask digest 기준 | 예 |

### artifact별 상세

| artifact | 생성 경로 | 포함/형태 | checksum | 사용 기준 |
|----------|-----------|-----------|----------|-----------|
| `build.noindex/release/Alhangeul.app` | `scripts/package-release.sh 0.1.0` | Release build app bundle. HostApp, Quick Look/Thumbnail appex, `rhwp-studio` resources 포함 여부를 확인하는 staging app | 별도 파일 없음 | #151 설치본 smoke와 bundle 포함 검증 입력 |
| `build.noindex/release/alhangeul-macos-0.1.0.zip` | `scripts/package-release.sh 0.1.0` | `Alhangeul.app`을 `ditto --keepParent`로 압축한 개발/검증용 zip | stdout `shasum -a 256` | smoke/report 기록용. GitHub Release public asset 또는 Cask 기준으로 사용하지 않음 |
| `build.noindex/release/Alhangeul.app` | `scripts/release.sh --skip-notarize 0.1.0` | rehearsal build의 app bundle. Developer ID env가 없으면 unsigned rehearsal | DMG checksum과 분리 | DMG layout rehearsal 입력. 설치본 smoke 보증으로 사용하지 않음 |
| `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg` | `scripts/release.sh --skip-notarize 0.1.0` | `/Applications` symlink과 `Alhangeul.app`을 담은 rehearsal DMG | `.sha256` 파일 생성 | layout/checksum rehearsal 전용. public upload, Cask, 사용자 배포 금지 |
| `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256` | `scripts/release.sh --skip-notarize 0.1.0` | rehearsal DMG digest | `shasum -a 256 -c`로 검증 | rehearsal report 전용. public checksum으로 사용 금지 |
| `build.noindex/release/Alhangeul.app` | `scripts/release.sh 0.1.0` | Developer ID signed, notarized, stapled app bundle | public DMG checksum과 분리 | public release DMG staging과 Gatekeeper 검증 대상 |
| `build.noindex/release/alhangeul-macos-0.1.0.dmg` | `scripts/release.sh 0.1.0` 또는 `release-publish.yml` | signed/notarized/stapled public DMG | `.sha256` 파일 생성 | GitHub Release asset, 사용자 배포, Homebrew Cask URL 기준 |
| `build.noindex/release/alhangeul-macos-0.1.0.dmg.sha256` | `scripts/release.sh 0.1.0` 또는 `release-publish.yml` | public DMG digest | `shasum -a 256 -c`로 검증 | GitHub Release asset, release note SHA256, Cask checksum 교체 기준 |

## checksum 공개 기준

public하게 공개할 checksum은 signed/notarized public DMG의 `.sha256` 파일과 release note의 `SHA256` 값으로 한정한다.

| checksum | 공개 범위 | 판단 |
|----------|-----------|------|
| zip stdout checksum | Stage 4/Stage 5 보고서, #151 smoke report | 개발/검증용 산출물 식별자. public release checksum으로 쓰지 않음 |
| rehearsal DMG `.sha256` | rehearsal workflow artifact와 단계 보고서 | public release checksum으로 쓰지 않음 |
| public DMG `.sha256` | GitHub Release asset, release note, Homebrew Cask 교체 입력 | 사용자 배포 기준 checksum |

Stage 3에서는 `release_distribution_guide.md`에서 위 세 checksum의 공개 범위를 명확히 분리한다. `scripts/package-release.sh`가 zip `.sha256` 파일을 만들지 않는 현재 동작은 유지해도 된다. zip checksum은 public digest가 아니므로 `.sha256` 파일을 추가하면 오히려 public artifact와 혼동될 수 있다.

## provenance 공개 기준

release artifact provenance는 기존 진실 원천을 중복하지 않고 연결한다.

| 대상 | 진실 원천 | release note/manual 공개 수준 |
|------|-----------|-------------------------------|
| `rhwp` core repository/ref/commit | `rhwp-core.lock` | release tag와 commit은 release note에 직접 표시 |
| Rust bridge artifact hash/size | `rhwp-core.lock` | manual과 최종 보고서에서 `rhwp-core.lock` 확인 절차로 연결 |
| FFI ABI surface | `rhwp-ffi-symbols.txt` | 최종 보고서와 manual에서 snapshot 파일 위치 연결 |
| bundled `rhwp-studio` asset | `Sources/HostApp/Resources/rhwp-studio/manifest.json` | release note에 manifest 위치를 짧게 추가 |
| third-party notices | `THIRD_PARTY_LICENSES.md`, `FONTS.md` | release note에 notice 위치를 짧게 추가 |
| 설치본 smoke 결과 | #151 결과보고서 | #145에서는 후속 gate로 연결, release note에는 최종 release report 기준 문구 유지 |
| known limitations | #146 결과보고서/README/release note | #145에서는 placeholder와 후속 연결만 남김 |

## release note 공개 항목

`scripts/ci/write-release-notes.sh`가 생성하는 public release note skeleton은 다음 항목을 포함해야 한다.

| 섹션 | 포함 내용 | Stage 3 변경 필요 |
|------|-----------|-------------------|
| 설치 | macOS 12 이상, DMG 다운로드, `Alhangeul.app` Applications 이동 | 현재 유지 |
| 산출물 | `alhangeul-macos-0.1.0.dmg`, SHA256 digest | 현재 유지 |
| 포함된 `rhwp` core | release tag, commit | 현재 유지 |
| 포함된 viewer asset provenance | `rhwp-studio` manifest path | 추가 |
| Third Party notices | `THIRD_PARTY_LICENSES.md`, `FONTS.md` | 추가 |
| 검증 | release publish workflow의 signing/notarization/staple/Gatekeeper/checksum 검증 통과 | 현재 유지하되 smoke/known limitations 문구를 후속 report 기준으로 명확화 |

`scripts/ci/write-release-notes.sh`는 실제 DMG digest를 인자로 받기 때문에, Stage 3에서 `rhwp-studio` manifest와 third-party notice 링크를 추가해도 reproducibility를 해치지 않는다.

## workflow 기본값 판단

Stage 2 판단:

- `.github/workflows/release-publish.yml`의 기본 `expected_rhwp_tag: v0.7.10`, `require_latest_rhwp: true`는 유지한다.
- 이유: public publish workflow의 기본값은 “현재 포함 artifact”보다 “public publish 시 upstream latest 검증”을 강제하는 안전장치에 가깝다.
- 이번 #145는 core update 작업이 아니므로 `rhwp-core.lock`을 `v0.7.10`으로 바꾸지 않는다.
- `v0.7.9` 상태로 public publish를 진행해야 한다면 작업지시자가 workflow dispatch에서 `expected_rhwp_tag=v0.7.9`, `require_latest_rhwp=false`를 명시하는 예외를 선택해야 한다.
- 일반 경로는 public publish 전 별도 core compatibility/update task로 `rhwp-core.lock`, `rhwp-studio` manifest, generated artifacts를 `v0.7.10` 기준으로 맞추는 것이다.

Stage 3에서는 workflow default를 바꾸지 않고, `release_distribution_guide.md`에 위 판단을 public release 전 확인 항목으로 추가한다. 필요하면 release note skeleton에는 current lock의 tag/commit만 표시하되 “latest 여부” 판단은 workflow와 최종 보고서가 담당하게 한다.

## Stage 3 변경안

Stage 3에서 변경할 파일:

| 파일 | 변경안 |
|------|--------|
| `mydocs/manual/release_distribution_guide.md` | artifact 3계층, checksum 공개 기준, `v0.7.9` current lock과 `v0.7.10` publish default 판단, release note 공개 항목 보강 |
| `scripts/ci/write-release-notes.sh` | `rhwp-studio` manifest와 third-party notices 섹션 추가 |
| `mydocs/working/task_m016_145_stage3.md` | Stage 3 변경/검증 보고 |

Stage 3에서 변경하지 않을 파일:

| 파일 | 사유 |
|------|------|
| `.github/workflows/release-publish.yml` | 최신 core 강제 기본값을 유지한다. current `v0.7.9` publish는 명시 예외 또는 core update로 처리한다. |
| `.github/workflows/release-rehearsal.yml` | 현재 rehearsal summary는 DMG/SHA256과 non-public 문구를 이미 포함한다. manual 보강으로 충분하다. |
| `scripts/package-release.sh` | zip checksum stdout-only 동작을 유지한다. zip은 public checksum 기준이 아니다. |
| `scripts/release.sh` | public/rehearsal DMG와 `.sha256` 생성 경로가 이미 분리되어 있다. |
| `README.md` | 현재 별도 미커밋 변경이 있고, #147에서 license/provenance 진입점이 이미 추가되어 있다. Stage 3에서는 건드리지 않는다. |

## 검증 결과

Stage 2 보고서 작성 전 상태:

```text
$ git status --short --branch
## local/task145
 M README.md
```

`README.md` 변경은 Stage 1 완료 시점부터 있던 별도 미커밋 변경이다. Stage 2에서는 이 파일을 수정하거나 staging하지 않는다.

보고서 작성 후 Stage 2 검증을 실행했다.

```text
$ rg -n "zip|rehearsal|public DMG|SHA256|rhwp-core.lock|manifest.json|release note|Homebrew|Cask|v0.7.9|v0.7.10" \
  mydocs/working/task_m016_145_stage2.md mydocs/plans/task_m016_145.md mydocs/plans/task_m016_145_impl.md

핵심 match:
- Stage 2 보고서: artifact 3계층, zip/rehearsal/public DMG 구분, checksum 공개 기준, `v0.7.9`/`v0.7.10` 판단 확인
- 수행계획서: artifact/provenance 범위와 current lock/publish default 리스크 확인
- 구현계획서: Stage 2/3/4/5 검증 계획과 public DMG 기준 확인

$ git diff --check
통과
```

## 잔여 위험

- current artifact provenance `v0.7.9`와 public publish 기본값 `v0.7.10`은 의도적으로 불일치 상태로 남긴다. 이 상태에서 default publish는 실패하는 것이 정상이다.
- release note skeleton은 `rhwp-studio` manifest와 third-party notices를 추가하더라도 #150/#149/#151/#146 결과를 아직 직접 반영할 수 없다.
- `README.md`에 별도 미커밋 변경이 남아 있어 Stage 3에서 README를 건드리지 않는다는 결정이 중요하다.
- 실제 artifact build와 bundle 포함 검증은 Stage 4에서만 확인된다.

## 다음 단계 영향

Stage 3에서는 변경 범위를 `release_distribution_guide.md`, `scripts/ci/write-release-notes.sh`, Stage 3 보고서로 제한한다. workflow/script의 산출물 동작은 현재 구조가 설계와 맞으므로 최소 변경으로 유지한다.

## 승인 요청

Stage 2 artifact 구성과 공개 항목 설계를 완료했다. 다음 단계는 Stage 3 `스크립트/워크플로우/문서 정합성 보강` 진입 승인이다.
