# Task M018 #198 Stage 3 완료 보고서

## 단계 목적

기존 release rehearsal/publish workflow의 보호 조건과 수동 실행 정책을 유지하면서, #185에서 추가한 release delta checklist 생성을 workflow input, step summary, artifact upload에 연결했다.

## 변경 요약

### `release-rehearsal.yml`

- `workflow_dispatch.inputs.previous_release_ref`를 추가했다.
  - 기본값: `v0.1.0`
  - 목적: 직전 공개 릴리즈 ref와 rehearsal candidate 간 변경 범위 초안 생성
- `PREVIOUS_RELEASE_REF` 환경 변수를 추가했다.
- `Read core lock` 직후 `Write release delta checklist` step을 추가했다.
  - candidate ref: `$GITHUB_SHA`
  - output: `$ALHANGEUL_BUILD_ROOT/release/delta-checklist-$VERSION.md`
  - summary: previous ref, candidate ref, checklist path
- `Upload release delta checklist artifact` step을 추가했다.
  - artifact name: `alhangeul-macos-${version}-rehearsal-delta-checklist`

ref 범위 오류를 build dependency 설치, Rust verify, DMG build보다 먼저 드러내도록 checklist 생성을 workflow 앞쪽에 배치했다.

### `release-publish.yml`

- `workflow_dispatch.inputs.previous_release_ref`를 추가했다.
  - 기본값: `v0.1.0`
- `PREVIOUS_RELEASE_REF` 환경 변수를 추가했다.
- 기존 `Validate release inputs and tag ref` step 뒤에 `Write release delta checklist` step을 추가했다.
  - candidate ref: `v$VERSION`
  - output: `$ALHANGEUL_BUILD_ROOT/release/delta-checklist-$VERSION.md`
  - summary: previous ref, candidate ref, checklist path
- `Upload release delta checklist artifact` step을 추가했다.
  - artifact name: `alhangeul-macos-${version}-release-delta-checklist`

publish workflow의 기존 보호 조건은 유지했다.

- `workflow_dispatch`
- `environment: release`
- tag `v<version>` 검증
- signing/notarization secrets 사용 위치
- GitHub Release asset publish
- stable Sparkle appcast/Page branch 갱신 조건

### `write-release-delta-checklist.sh`

release workflow 변경이 delta checklist에서 수동 분류로만 남지 않도록 release workflow path 분류를 보강했다.

- `.github/workflows/release-rehearsal.yml` -> `DMG/signing/notarization`
- `.github/workflows/release-publish.yml` -> `DMG/signing/notarization`
- 기존 `.github/workflows/release-publish.yml` -> `Sparkle/appcast/Pages` 분류는 유지

## 검증 결과

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
```

결과: 둘 다 exit code 0. 로컬 Ruby 환경에서 `ffi` gem native extension 경고가 출력됐지만 YAML parse는 통과했다.

```bash
bash -n scripts/ci/write-release-delta-checklist.sh
```

결과: exit code 0.

```bash
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
```

결과: exit code 0.

```bash
rg -n "previous_release_ref|write-release-delta-checklist|delta-checklist|GITHUB_STEP_SUMMARY|upload-artifact" .github/workflows/release-rehearsal.yml .github/workflows/release-publish.yml
```

결과 요약:

- 두 release workflow 모두 `previous_release_ref` input을 가진다.
- 두 release workflow 모두 `write-release-delta-checklist.sh`를 실행한다.
- 두 release workflow 모두 `GITHUB_STEP_SUMMARY`에 checklist ref/path를 기록한다.
- 두 release workflow 모두 delta checklist artifact를 업로드한다.

```bash
rg -n "HostApp|Quick Look|Thumbnail|Sparkle|DMG|Homebrew|문서" build.noindex/release/delta-checklist-0.1.1.md
```

결과: delta checklist의 주요 영향 영역 heading과 변경 파일 분류가 생성됐다.

Stage 3의 uncommitted workflow/helper 변경을 포함한 임시 Git tree로 추가 dry-run도 수행했다.

```bash
scripts/ci/write-release-delta-checklist.sh HEAD <stage3-temporary-commit> build.noindex/release/delta-checklist-stage3-dry-run.md
rg -n "release-rehearsal|release-publish|write-release-delta-checklist|DMG/signing/notarization|Sparkle/appcast/Pages|수동 분류 필요" build.noindex/release/delta-checklist-stage3-dry-run.md
```

결과 요약:

- `.github/workflows/release-publish.yml`은 `Sparkle/appcast/Pages`와 `DMG/signing/notarization`에 분류됐다.
- `.github/workflows/release-rehearsal.yml`은 `DMG/signing/notarization`에 분류됐다.
- `scripts/ci/write-release-delta-checklist.sh` 자체 변경은 release owner가 직접 확인해야 하므로 `수동 분류 필요`에 남았다.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

## 미실행 검증

실제 `release-rehearsal.yml`과 `release-publish.yml` workflow 실행은 수행하지 않았다. rehearsal은 macOS runner에서 DMG build를 수행하고, publish는 `environment: release`, Developer ID certificate, notarization, Sparkle private key, GitHub Release publish 권한이 필요한 보호 영역이다. 이번 단계에서는 workflow syntax, helper syntax, 로컬 delta checklist 생성, summary/artifact 연결 경로를 검증했다.

## 다음 단계 영향

Stage 4에서는 PR CI, release rehearsal, release publish, rhwp upstream check의 역할과 경계를 문서화한다. 특히 `previous_release_ref` 입력, delta checklist summary/artifact 위치, PR CI의 docs-only skip 기준을 manual entrypoint에서 찾을 수 있게 정리한다.

## 승인 요청

Stage 3 산출물 승인을 요청한다.

승인 후 Stage 4 `CI 역할과 수동 재현 문서화`로 진행한다.
