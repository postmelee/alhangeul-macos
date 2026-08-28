# Task M010 #488 Stage 2 완료 보고서

## 단계 목적

승인되지 않은 다른 HTTPS origin을 source configuration gate에서 차단하고, built app endpoint reader를 current XML·future binary plist 계약에 맞춘다. Ubuntu portable fixture와 macOS XML/binary fixture를 분리해 production origin, Debug empty, Release exact-match와 fallback 한계를 자동 검증한다.

## 산출물

| 파일 | 변경 정도 | 내용 |
|------|-----------|------|
| `scripts/ci/verify-app-execution-endpoint-config.sh` | +53/-5 | Expected production origin 고정, URI origin 비교, XML-only fallback과 binary 오류 명시 |
| `scripts/ci/test-app-execution-endpoint-config.sh` | +94/-11 | Invalid origin, XML/binary built app, mismatch와 no-`plutil` fixture 추가 |
| `.github/workflows/pr-ci.yml` | +6/-0 | macOS validation에서 plist fixture helper 실행 |
| `mydocs/plans/task_m010_488_impl.md` | +26/-23 | Stage 1 측정에 따라 binary 전제를 current XML·future binary 계약으로 보정 |
| `mydocs/working/task_m010_488_stage2.md` | 신규 1개 | Stage 2 구현·검증·잔여 위험 기록 |
| `mydocs/orders/20260828.md` | 1행 수정 | Stage 2 완료·Stage 3 승인 대기로 상태 갱신 |

보고서 작성 전 source diff는 4개 파일, 179줄 추가·39줄 삭제였다. 제품 runtime, `project.yml`, endpoint 값, payload/outbox와 Release helper는 Stage 2에서 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- HostApp·Quick Look·Thumbnail Swift/Rust source 변경: 0개
- `project.yml` production endpoint 변경: 없음
- 공개 payload, endpoint path, analytics runtime 변경: 없음
- `release.sh`, `package-release.sh` 변경: 없음 — Stage 3 범위 유지
- Public workflow dispatch, app 실행, production 네트워크 요청: 수행하지 않음
- 계획 보정: Stage 1에서 실제 Release plist가 XML임을 측정한 결과만 반영했으며 전체 3단계 범위와 Stage 3 목표는 유지

## 구현 내용

### 1. Production origin을 독립적으로 고정

Verifier에 다음 expected origin을 명시했다.

```text
https://alhangeul-install-events.postmelee.workers.dev
```

`project.yml`은 endpoint 전체 URL의 단일 편집 원본으로 유지한다. 별도 expected origin은 scheme·lowercase host·effective port 배열로 비교하며, path는 origin 비교에서 제외한다. Expected origin 자체도 HTTPS 절대 origin인지, credential·query·fragment와 비-root path가 없는지 방어적으로 검증한다.

Current endpoint와 다른 `https://collector.example/v1/install-events` fixture는 다음 오류로 실패한다.

```text
HostApp Release endpoint origin must be https://alhangeul-install-events.postmelee.workers.dev, got: https://collector.example
```

같은 origin 안의 path는 source 진실 원천인 `project.yml`이 소유하고, built Release app은 기존처럼 전체 문자열 exact match를 통과해야 한다. Intentional host 이전은 verifier constant, project configuration, fixture와 문서를 같은 review에서 변경해야 한다.

### 2. Current XML과 future binary plist 책임을 분리

macOS에서는 기존처럼 `plutil`을 우선 사용해 XML·binary plist를 읽는다. `plutil`이 없는 환경에서는 current `INFOPLIST_OUTPUT_FORMAT = same-as-input` 출력과 같은 XML plist만 REXML fallback으로 지원한다.

Fallback은 `File.binread`로 header를 먼저 확인한다. `bplist` binary 입력이면 REXML parse를 시도하지 않고 다음 오류로 중단한다.

```text
plutil is required to read binary built Info.plist
```

XML parse 실패, endpoint key 누락과 non-string 값도 `error:` prefix가 있는 구체적 메시지로 통일했다. Stage 1에서 실제로 동작한 XML fallback은 유지하고, 지원하지 않는 binary를 처리하는 것처럼 보이던 모호함만 제거했다.

### 3. Portable·macOS fixture를 확장

Portable fixture는 다음 계약을 검증한다.

- Current source configuration 정상
- Invalid base/Debug override 실패
- HTTP Release endpoint 실패
- 다른 HTTPS origin 실패
- Source plist placeholder drift 실패
- XML Debug empty endpoint 통과
- XML Release exact endpoint 통과
- XML Release same-origin path mismatch 실패
- `plutil` 없는 제한 PATH에서 XML REXML fallback 통과

macOS에서 `plutil`이 있으면 추가로 다음을 검증한다.

- Synthetic binary Debug empty endpoint 통과
- Synthetic binary Release exact endpoint 통과
- 같은 binary Release app이 no-`plutil` 제한 PATH에서는 명시적 실패

`pr-ci.yml`의 macOS validation에 동일 helper 실행 단계를 추가했다. Ubuntu `script-checks`는 기존 helper 호출을 유지해 source/XML portable 계약을 검증하고, macOS job은 binary 분기를 추가로 실행한다. 실제 Debug built app에 대한 기존 `--debug-app` gate도 유지했다.

### 4. 구현계획 보정

승인된 Stage 1 보고서에 따라 `task_m010_488_impl.md`의 다음 전제를 고쳤다.

- “Xcode built plist는 binary” → Current Release output은 `same-as-input` XML
- “REXML fallback 제거” → `plutil` 우선, XML-only fallback 유지, binary 명시 실패
- Ubuntu source fixture와 macOS binary fixture → Ubuntu source/XML + macOS synthetic binary fixture

Stage 3의 `release.sh` pre-signing hook, `package-release.sh` copied app gate와 운영 문서 보강 범위는 변경하지 않았다.

## 검증 결과

| 검증 | 결과 | 핵심 출력 |
|------|------|-----------|
| `bash -n` verifier/test helper | OK | 구문 오류 없음 |
| `scripts/ci/test-app-execution-endpoint-config.sh` | OK | Source 실패 4개, XML built, mismatch, XML fallback, binary 성공/실패 fixture 통과 |
| `scripts/ci/verify-app-execution-endpoint-config.sh` | OK | Current Release-only source configuration 통과 |
| `shellcheck` 두 helper | OK | 진단 없음 |
| `Psych.parse_file(.github/workflows/pr-ci.yml)` | OK | Workflow YAML parse 성공 |
| 제한 PATH 전체 fixture | OK | `plutil` 없이 source/XML fixture 전체 통과, binary 분기 미실행 |
| Stage 1 실제 Release app `--release-app` | OK | Current production endpoint exact match 통과 |
| `git diff --check` | OK | 오류 없음 |

macOS 전체 fixture의 주요 출력은 다음과 같다.

```text
Verified failure fixture: invalid-origin
Verified Debug built endpoint is disabled: .../debug-xml/Alhangeul.app
Verified Release built endpoint: .../release-xml/Alhangeul.app
Verified failure fixture: release-mismatch-xml
Verified XML built endpoint fallback without plutil.
Verified Debug built endpoint is disabled: .../debug-binary/Alhangeul.app
Verified Release built endpoint: .../release-binary/Alhangeul.app
Verified failure fixture: release-binary-without-plutil
Analytics endpoint configuration fixtures passed.
```

Local system Ruby는 미사용 `ffi-1.13.1` native extension 경고를 출력했지만 모든 helper exit status와 REXML/Psych 검증은 성공했다. 이 경고는 변경 전 baseline에서도 동일하며 Stage 2 source 실패가 아니다.

## 잔여 위험

- `--release-app`은 아직 `release.sh`와 `package-release.sh`에서 호출되지 않는다. 실제 artifact 자동 차단은 Stage 3 완료 전까지 없다.
- Expected origin은 `project.yml` endpoint와 별도 상수다. 중복은 destination 변경을 명시적으로 review하기 위한 의도된 gate이며 운영 문서 설명이 Stage 3에 필요하다.
- Current Xcode output은 XML이지만 설정 변경으로 binary가 될 수 있다. macOS `plutil` 경로는 synthetic binary fixture로 보호하고, non-macOS fallback은 binary를 지원하지 않는다.
- PR CI의 macOS fixture 단계는 `run_macos_build` job 조건 안에서 실행된다. 실제 Release artifact의 pre-signing 순서는 Stage 3 release helper 통합 검증으로 별도 확인해야 한다.
- 같은 production origin 안의 endpoint path 변경은 origin guard가 허용한다. Source diff review와 built app의 `project.yml` exact-match가 path 계약을 담당한다.

## 다음 단계 영향

Stage 3는 보강된 verifier를 다음 위치에 연결한다.

1. `release.sh`: `build_app` 완료 후, `sign_release_app_for_notarization` 이전에 copied `APP_OUTPUT`을 `--release-app`으로 검증
2. `package-release.sh`: copied Release app을 zip으로 만들기 전에 동일 verifier 실행
3. Rehearsal/publish workflow: 명령 중복 없이 공통 helper의 pre-signing gate를 summary에 명시
4. Analytics 계약과 CI/release packaging 가이드: expected origin review gate, built exact-match, XML/binary reader와 실행 순서 기록
5. Unsigned Release build와 필요 시 `--skip-notarize` rehearsal에서 endpoint gate가 signing/DMG 생성보다 먼저 실행되는지 확인

Stage 3에서도 production endpoint로 앱을 실행하거나 이벤트를 전송하지 않으며 public workflow, Developer ID 서명과 notarization을 수행하지 않는다.

## 승인 요청

Stage 2 production origin guard, XML/binary reader 계약, portable/macOS fixture와 PR CI 연결을 완료했다. 구현계획서의 Stage 1 반증 보정도 승인 내용대로 반영했다.

Stage 3의 release artifact preflight 연결, workflow summary·운영 문서 보강과 unsigned 통합 검증 진행 승인을 요청한다.
