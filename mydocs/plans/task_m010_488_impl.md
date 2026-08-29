# Task M010 #488 구현계획서

수행계획서: `mydocs/plans/task_m010_488.md`

## 1. 작업 개요

- 이슈: [#488 분석 endpoint 검증 gate 보강: release artifact preflight와 production host 고정](https://github.com/postmelee/alhangeul-macos/issues/488)
- 마일스톤: `M010` (`v0.1`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task488`
- 게시 브랜치: `publish/task488`
- 기준 커밋: `615573a91294ff35ef73b2b9e992fa614f242e7d`
- 단계 수: 3

Task #479가 도입한 Release-only 익명 실행 이벤트 endpoint 계약을 실제 release artifact까지 확장한다. Source configuration은 승인된 production origin을 벗어나지 못하게 하고, built Release app은 `project.yml`의 전체 endpoint와 정확히 일치해야 한다. `release.sh`는 앱 빌드 직후·Developer ID 재서명과 notarization 전에 이 검증을 blocking preflight로 실행한다.

구현계획 승인 전에는 Stage 1을 시작하지 않는다. 각 Stage 종료 뒤에는 `task-stage-report` 절차로 해당 단계 변경과 보고서를 함께 커밋하고 다음 단계 승인을 받는다. Public workflow dispatch, Developer ID 서명·공증, production 이벤트 전송은 어느 Stage에서도 실행하지 않는다.

## 2. 구현 전 확인 결과

| 항목 | 현재 상태 | 구현 영향 |
|------|-----------|-----------|
| Source 진실 원천 | `project.yml`의 HostApp Release `ALHANGEUL_APP_EXECUTION_ENDPOINT`가 전체 URL을 소유한다. | URL 편집 원본은 유지하고 verifier에 승인 origin guard를 독립적으로 둔다. |
| Source verifier | HTTPS 절대 URL과 credential·query·fragment 부재만 확인한다. | 다른 HTTPS host 실패 fixture와 origin 비교가 필요하다. |
| Built Release verifier | `--release-app`은 built plist 값이 `project.yml` endpoint와 exact 일치하는지 확인한다. | Exact-match 계약은 유지하되 실제 release helper에서 호출해야 한다. |
| Built plist reader | `plutil`이 없으면 REXML로 fallback한다. Current Release plist는 `same-as-input` XML이며 fallback으로도 읽힌다. | XML-only fallback 의도를 명시하고, `plutil` 없는 binary 입력은 명확히 실패하게 한다. |
| Portable fixture | Ubuntu `script-checks`에서 source 정상과 실패 fixture 3개를 실행한다. | Origin failure와 XML built fixture를 portable하게 추가하고 synthetic binary fixture는 macOS로 분리한다. |
| macOS PR CI | Debug app을 빌드한 뒤 `--debug-app`만 실행한다. | Mac에서 test helper를 한 번 더 실행해 current XML과 synthetic binary fixture를 검증한다. |
| Public/rehearsal workflow | 둘 다 공통 `scripts/release.sh`를 호출한다. | Workflow에 build 검증 명령을 중복하지 않고 공통 helper에 pre-signing hook을 둔다. |
| `release.sh` 순서 | `build_app` 다음에 곧바로 `sign_release_app_for_notarization`을 호출한다. | 두 호출 사이가 built endpoint preflight의 단일 위치다. |
| 개발용 zip | `package-release.sh`도 Release app을 만든 뒤 universal slice만 검증한다. | 같은 built endpoint verifier를 복사 직후 실행해 Release zip 우회 경로도 닫는다. |
| 운영 문서 | Release build·서명·공증 순서는 기록돼 있으나 endpoint preflight는 없다. | Analytics 계약과 release/CI 가이드에 origin·exact match·실행 순서를 최소 보강한다. |

## 3. 공통 설계·안전 계약

### 3.1 Endpoint 검증의 두 계층

- `project.yml`은 endpoint 전체 URL의 단일 편집 원본으로 유지한다.
- Verifier의 `EXPECTED_PRODUCTION_ORIGIN`은 승인된 전송 목적지를 보호하는 별도 review gate다.
- Source endpoint는 기존 HTTPS·host·credential/query/fragment 정책과 expected origin을 모두 통과해야 한다.
- Origin은 URI의 lowercase scheme·lowercase host·effective port로 비교한다. Path는 origin 비교에서 제외한다.
- Built Release endpoint는 `project.yml` 전체 문자열과 exact 일치해야 한다. 따라서 같은 origin 안의 path drift도 built configuration 불일치라면 실패한다.
- Intentional host 이전은 `project.yml`, expected origin, 정상·실패 fixture와 운영 문서를 같은 PR에서 명시적으로 변경해야 한다.

### 3.2 Source와 built plist reader 경계

- Source `Info.plist`는 tracked XML이므로 기존 REXML 검증을 유지한다.
- Current `--debug-app`·`--release-app` 산출물은 `INFOPLIST_OUTPUT_FORMAT = same-as-input`에 따라 tracked source와 같은 XML이다.
- macOS에서는 XML·binary 형식 모두 처리하는 `plutil`을 우선 사용한다.
- `plutil`이 없는 환경에서는 REXML fallback으로 XML built plist만 지원하고, binary 입력은 명확한 오류로 종료한다.
- Built 옵션이 없으면 Ubuntu source fixture는 `plutil` 없이 계속 실행돼야 한다.
- 오류 메시지는 secret이나 문서 정보를 포함하지 않고 설정 이름, 예상 origin과 대상 app path 정도만 제공한다.

### 3.3 Release preflight 실행 순서

- `release.sh`는 `build_app` 완료 후 copied `APP_OUTPUT`을 `--release-app`으로 검증한다.
- 이 호출은 `sign_release_app_for_notarization`, universal/signature preflight, app notarization, DMG 생성보다 앞선다.
- Rehearsal과 publish workflow는 모두 `release.sh`를 실행하므로 같은 gate를 자동 공유한다.
- `package-release.sh`도 copied Release app을 zip·staging 정리 전에 같은 verifier로 검사한다.
- Workflow 파일에는 verifier 명령을 복제하지 않고 summary에 공통 preflight 계약만 기록한다.
- 검증 실패 시 app 실행, production 네트워크 요청, signing/notarization과 DMG/zip 생성을 진행하지 않는다.

### 3.4 테스트 플랫폼 분리

- Ubuntu `script-checks`: source 정상, invalid base, invalid scheme, invalid origin, invalid placeholder fixture를 실행한다.
- macOS release-checks: 같은 source·XML built fixture와 `plutil`로 만든 synthetic binary Debug/Release app fixture를 실행한다.
- 기존 macOS validation의 실제 Debug built app `--debug-app` 검증을 유지한다.
- 실제 Release path는 로컬 unsigned Release build와 필요 시 `release.sh --skip-notarize`로 확인한다.
- Public release workflow와 production endpoint HTTP 요청은 테스트에 사용하지 않는다.

## 4. Stage 1 — Release 경로 재현과 preflight 계약 확정

### 4.1 목적

제품·helper 구현을 바꾸기 전에 현재 verifier가 승인되지 않은 HTTPS origin을 통과시키고 `--release-app`이 release 경로에서 호출되지 않는 사실을 재현한다. Current plist 출력 형식과 fallback 동작, `release.sh`의 pre-signing 삽입 지점을 고정해 Stage 2·3의 책임 경계를 확정한다.

### 4.2 작업 범위

1. 현재 verifier와 fixture를 실행해 portable baseline을 기록한다.
2. 일회용 fixture의 Release endpoint를 다른 HTTPS origin으로 바꾸고 현 verifier가 통과하는 상태를 재현한다.
3. `rg`로 `--release-app` 호출이 verifier help 외에 없는지 확인한다.
4. `release.sh` main 순서와 `build_app`이 copied `APP_OUTPUT`을 만드는 지점을 확인한다.
5. `package-release.sh`의 copied app·universal 검증·zip 순서를 확인해 built endpoint gate 포함을 확정한다.
6. Xcode built `Info.plist`의 실제 출력 형식과 REXML fallback 동작을 측정하고, current XML·future binary 책임을 구분한다.
7. Expected origin 비교 단위, `plutil` 적용 조건, Ubuntu/macOS fixture 분리를 확정한다.

### 4.3 예상 산출물

- `mydocs/working/task_m010_488_stage1.md`
- `mydocs/orders/20260828.md`

Stage 1에서는 verifier, workflow, release helper와 운영 매뉴얼을 수정하지 않는다. 재현 fixture는 임시 디렉터리에만 만들고 커밋하지 않는다.

### 4.4 검증

```bash
scripts/ci/test-app-execution-endpoint-config.sh
scripts/ci/verify-app-execution-endpoint-config.sh
rg -n -- '--release-app' .github scripts mydocs/manual
rg -n 'build_app|sign_release_app_for_notarization|main\(\)' scripts/release.sh
file build.noindex/task488-stage1/Alhangeul.app/Contents/Info.plist
git diff --check
```

Binary plist 형식 확인에 app build가 필요하면 `build.noindex/task488-stage1/` 아래에 unsigned Release app을 만들며 실행하지 않는다. 다른 origin 재현은 일회용 source fixture에서만 수행한다.

### 4.5 완료 기준

- 다른 HTTPS origin이 현재 source verifier를 통과하는 재현 결과가 있다.
- `--release-app`이 rehearsal/publish/package helper에서 호출되지 않는 현재 상태가 기록된다.
- `release.sh`의 endpoint gate가 `build_app`과 signing 사이에 들어가야 하는 근거가 확정된다.
- Built plist가 current XML임을 확인하고 `plutil` 우선·XML-only fallback·binary 명시 실패 경계가 기록된다.
- Stage 2·3의 변경 파일과 검증 명령이 구현 가능한 수준으로 확정된다.

### 4.6 커밋

`Task #488 Stage 1: Release endpoint preflight 계약 확정`

## 5. Stage 2 — Production origin 고정과 verifier 회귀 보강

### 5.1 목적

승인되지 않은 HTTPS origin을 source gate에서 차단하고 built app 검사를 current XML·future binary plist 계약에 맞춘다. Portable source/XML fixture와 macOS synthetic binary fixture로 회귀를 자동 검증한다.

### 5.2 예상 변경 파일

- `scripts/ci/verify-app-execution-endpoint-config.sh`
- `scripts/ci/test-app-execution-endpoint-config.sh`
- `.github/workflows/pr-ci.yml`
- `mydocs/working/task_m010_488_stage2.md`
- `mydocs/orders/20260828.md`

### 5.3 구현 항목

1. Verifier에 expected production origin 상수를 추가한다.
2. Expected origin 자체가 credential·query·fragment와 비-root path를 갖지 않는 유효한 HTTPS origin인지 방어적으로 검증한다.
3. Release endpoint를 URI로 파싱한 뒤 scheme·host·effective port 기준 origin을 비교한다.
4. 승인되지 않은 HTTPS origin에 expected/actual을 구분하는 오류를 출력한다.
5. Built plist reader의 REXML fallback을 XML-only로 명시하고 parse 오류를 구체화한다.
6. `plutil`이 없는 상태에서 binary built plist가 입력되면 명시적으로 실패한다.
7. Existing exact Release endpoint 비교와 Debug empty endpoint 검사를 유지한다.
8. Portable fixture에 invalid HTTPS origin을 추가한다.
9. Portable XML Debug/Release app fixture로 empty/exact/mismatch와 REXML fallback을 검증한다.
10. macOS에서 synthetic binary Debug/Release app을 만들어 `plutil` 성공과 no-`plutil` 실패를 검증한다.
11. PR CI macOS release-checks에서 test helper를 실행해 script-only 변경에도 binary fixture를 활성화하고, macOS validation의 기존 실제 Debug app 검증을 유지한다.

### 5.4 자동 회귀

- 정상 production source configuration 통과
- Base/Debug endpoint 활성화 실패
- HTTP Release endpoint 실패
- 다른 HTTPS origin 실패
- Source plist literal/placeholder drift 실패
- XML Debug empty endpoint 통과
- XML Release exact endpoint 통과와 mismatch 실패
- Synthetic binary Debug/Release endpoint의 `plutil` 경로 통과
- Source-only Ubuntu 실행에서 `plutil` 비필수
- `plutil` 없는 XML built app은 REXML fallback 통과
- `plutil` 없는 binary built app은 명시적 실패

### 5.5 검증

```bash
bash -n scripts/ci/verify-app-execution-endpoint-config.sh
bash -n scripts/ci/test-app-execution-endpoint-config.sh
scripts/ci/test-app-execution-endpoint-config.sh
scripts/ci/verify-app-execution-endpoint-config.sh
shellcheck scripts/ci/verify-app-execution-endpoint-config.sh \
  scripts/ci/test-app-execution-endpoint-config.sh
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
git diff --check
```

### 5.6 완료 기준

- `https://다른-host/...` source fixture가 HTTPS여도 실패한다.
- 현재 production source configuration과 exact built Release fixture는 통과한다.
- Current XML built plist는 `plutil` 우선·REXML fallback 모두 읽고 binary plist는 `plutil` 없이 명시적으로 실패한다.
- Ubuntu source/XML fixture와 macOS synthetic binary fixture가 각 플랫폼에서 자동 실행된다.
- 기존 Debug endpoint 비활성과 Release exact-match 계약이 유지된다.

### 5.7 커밋

`Task #488 Stage 2: Production endpoint verifier 보강`

## 6. Stage 3 — Release artifact preflight 연결과 통합 검증

### 6.1 목적

보강된 verifier를 실제 Release app 산출 경로에 연결한다. Rehearsal/public release helper는 signing/notarization 전에, 개발용 Release zip은 압축 전에 built endpoint mismatch를 차단하도록 하고 운영 문서를 실제 순서와 맞춘다.

### 6.2 예상 변경 파일

- `scripts/release.sh`
- `scripts/package-release.sh`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/tech/task_m040_453_app_execution_analytics_contract.md`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_packaging_dmg_guide.md`
- `mydocs/working/task_m010_488_stage3.md`
- `mydocs/orders/20260828.md`

Workflow 파일은 실행 명령을 중복하지 않고 summary의 preflight 설명만 실제 공통 helper 순서에 맞춰 보강한다. 문서는 기존 문단에 origin guard와 built exact-match 항목을 최소 추가한다.

### 6.3 구현 항목

1. `release.sh`에 built Release app endpoint 검증 함수를 추가한다.
2. Main 순서를 `build_app -> endpoint preflight -> signing/notarization`으로 고정한다.
3. Preflight 실패가 universal/signing/notarization/DMG 단계 전에 non-zero로 종료되는지 확인한다.
4. `package-release.sh`가 copied Release app을 zip으로 만들기 전에 같은 verifier를 호출한다.
5. Rehearsal/publish workflow summary에 built endpoint preflight가 signing/notarization보다 먼저 실행된다고 기록한다.
6. Analytics 계약에 expected origin review gate, built exact-match와 unsigned Release 비실행 원칙을 추가한다.
7. CI/release packaging 가이드에 verifier 명령과 `release.sh` 실행 순서를 추가한다.
8. Clean unsigned Release app에서 `--release-app` exact match를 검증한다.
9. 필요 시 `release.sh --skip-notarize 0.1.10`을 실행해 로그에서 endpoint gate가 signing skip·DMG 생성보다 앞서는지 확인한다.
10. 전체 helper fixture, workflow YAML, XcodeGen, shared boundary와 provenance gate를 최종 실행한다.

### 6.4 검증

```bash
bash -n scripts/release.sh
bash -n scripts/package-release.sh
for workflow in .github/workflows/*.yml; do
  ruby -e 'require "psych"; Psych.parse_file(ARGV.fetch(0))' "$workflow"
done
scripts/ci/test-app-execution-endpoint-config.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/task488-stage3-release \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/ci/verify-app-execution-endpoint-config.sh \
  --release-app build.noindex/task488-stage3-release/Build/Products/Release/Alhangeul.app
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
git diff --check
```

공통 release helper의 end-to-end 순서 확인이 필요하면 다음 rehearsal만 수행한다.

```bash
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION \
  -u ALHANGEUL_NOTARY_PROFILE \
  ./scripts/release.sh --skip-notarize 0.1.10
```

이 rehearsal은 public asset으로 게시하지 않고 완료 뒤 개발 산출물 등록 상태를 확인한다. Production endpoint로 앱을 실행하거나 이벤트를 전송하지 않는다.

### 6.5 완료 기준

- `release.sh`가 copied built app을 signing/notarization 전에 `--release-app`으로 검증한다.
- Rehearsal과 publish workflow가 별도 복제 없이 같은 blocking gate를 사용한다.
- `package-release.sh`도 Release zip 생성 전에 exact built endpoint를 검증한다.
- Origin drift, built mismatch와 XML/binary plist fixture가 자동 실패한다.
- Current unsigned Release app은 exact endpoint gate와 기존 universal/provenance 검증을 통과한다.
- 운영 문서가 source origin guard와 release artifact preflight 순서를 정확히 설명한다.
- Public release, signing/notarization과 production 네트워크 요청은 수행하지 않는다.

### 6.6 커밋

`Task #488 Stage 3: Release artifact endpoint preflight 연결`

## 7. 단계별 중단·승인 기준

- Stage 1에서 expected origin 비교가 endpoint의 합법적 운영 변경을 과도하게 막거나 `release.sh` hook이 signing 전 copied app을 볼 수 없으면 구현을 시작하지 않고 설계를 재승인받는다.
- Stage 2에서 Ubuntu portable fixture가 `plutil`에 의존하거나 current XML output과 synthetic binary 미래 경계 중 하나만 검증하면 단계 완료로 보지 않는다.
- Stage 3에서 endpoint verifier가 signing/notarization 뒤에 실행되거나 workflow별 중복 명령이 생기면 완료로 보지 않는다.
- 어느 Stage에서도 public workflow dispatch, Developer ID/notary credential 사용 또는 production 합성 이벤트가 필요해지면 즉시 멈추고 별도 승인을 요청한다.
- 검증 실패가 해당 단계 범위를 넘어 runtime, payload, endpoint 값 변경을 요구하면 구현계획을 보정하고 승인받는다.

## 8. 승인 요청 사항

1. Stage 1에서 우회 가능성과 release hook 위치를 먼저 재현·고정한 뒤 구현하는 순서 승인
2. Stage 2에서 expected origin, `plutil` 우선·XML-only fallback과 Ubuntu/macOS fixture 분리를 한 묶음으로 구현하는 범위 승인
3. Stage 3에서 `release.sh`와 `package-release.sh`에 공통 verifier를 연결하고 workflow에는 중복 명령 대신 summary만 보강하는 방향 승인
4. Public release·서명·공증·production 요청 없이 unsigned Release build와 필요 시 `--skip-notarize` rehearsal까지만 수행하는 검증 범위 승인
5. 구현계획 승인 후 Stage 1 재현과 계약 확정 작업 시작 승인
