# Task M010 #479 Stage 3 완료보고서

## 단계 목적

새 Debug·Release HostApp 산출물에서 analytics endpoint configuration 분리를 최종 검증한다. 전체 HostAppTests와 공통 bundle 계약을 재확인하고, 설정 분리 전 운영 집계의 해석 한계·미보정 원칙·production smoke 금지 경계를 장기 analytics 계약에 반영한다.

## 산출물

| 산출물 | 내용 |
|--------|------|
| Debug HostApp | `build.noindex/task479-stage3-debug/Build/Products/Debug/Alhangeul.app` |
| Release HostApp | `build.noindex/task479-stage3-release/Build/Products/Release/Alhangeul.app` |
| HostAppTests 결과 | `build.noindex/task479-stage3-tests/Logs/Test/Test-HostAppTests-2026.08.26_11-44-46-+0900.xcresult` |
| 장기 계약 | `mydocs/tech/task_m040_453_app_execution_analytics_contract.md` |
| 단계 보고서 | `mydocs/working/task_m010_479_stage3.md` |
| 오늘할일 | `mydocs/orders/20260826.md`의 #479 상태 갱신 |

Build·test 산출물은 ignored `build.noindex/`에만 두며 커밋하지 않는다.

## 최종 bundle 검증

### Analytics endpoint

같은 source와 generated project에서 새 Debug·Release app을 unsigned build하고 Stage 2 verifier로 두 bundle을 함께 검사했다.

| configuration | built `AlhangeulAppExecutionEndpoint` | 판정 |
|---------------|----------------------------------------|------|
| Debug | 빈 문자열 | resolver `nil`, production 전송 경로 비활성 |
| Release | `https://alhangeul-install-events.postmelee.workers.dev/v1/install-events` | `project.yml`과 exact 일치 |

Release URL은 host가 있는 절대 HTTPS URL이며 credential, query와 fragment가 없다. Debug와 Release 모두 unexpanded `$(...)` token이 남지 않았다.

Debug 앱은 build와 plist 정적 검사만 수행하고 실행하지 않았다. Endpoint 없음에서 connectivity resolver 0회, transport 0회, outbox 유지 계약은 전체 HostAppTests의 기존 stub 검증으로 판정했다. Release 앱도 build만 수행하고 실행하지 않아 production Worker 요청과 합성 이벤트를 만들지 않았다.

### 공통 bundle 계약

두 bundle에서 다음 값이 동일하게 유지됐다.

| key/영역 | Debug·Release 결과 |
|----------|--------------------|
| `CFBundleShortVersionString` | `0.1.10` |
| `CFBundleVersion` | `16` |
| `SUFeedURL` | 기존 stable appcast URL |
| `SUPublicEDKey` | 기존 공개 EdDSA key |
| `CFBundleDocumentTypes` | byte-equivalent XML extraction |
| `UTExportedTypeDeclarations` | byte-equivalent XML extraction |
| bundled rhwp-studio | source·Debug·Release 검증 통과 |

따라서 endpoint configuration 분리 외 Sparkle, version, 문서 UTI와 bundled Studio 계약 변화는 없다.

## 운영 계약 문서화

기존 `mydocs/tech/task_m040_453_app_execution_analytics_contract.md` 내용을 보존하고 `빌드 구성과 endpoint` 절만 추가했다.

- `project.yml`의 HostApp custom setting을 production endpoint의 단일 편집 원본으로 정의
- 공통 source plist는 custom setting placeholder만 참조
- base/Debug는 빈 값, Release만 production URL을 얻는 configuration 경계
- endpoint 없음·잘못된 값에서 resolver와 coordinator가 fail-closed·비차단으로 동작하는 계약
- configuration 기준 분리이므로 unsigned Release도 production URL을 포함한다는 주의점
- production 전송 smoke 대신 별도 승인된 staging endpoint와 제거 정책이 필요하다는 경계
- 설정 분리 전 Debug가 production endpoint를 포함할 수 있었던 사실
- 2026-08-04·08-12의 `0.1.9 existing_baseline` 각 1건은 개발 build에서 발생한 것으로 추정되지만 payload만으로 사후 증명할 수 없다는 한계
- 기존 행을 삭제·재분류·보정하지 않고 공개 설치·사용자 수로 단정하지 않는 원칙

이미 공개 완료된 `mydocs/release/v0.1.10.md`와 일반 build manual은 수정하지 않았다. 이번 변경은 공개 v0.1.10 artifact 자체를 바꾸는 release 작업이 아니며, endpoint 구성·운영 해석의 장기 진실 원천은 analytics 계약 한 곳이면 충분하다.

## 본문 변경 정도 / 본문 무손실 여부

Stage 3에서는 제품 source, Xcode project, workflow와 test를 변경하지 않았다. HWP/HWPX 본문, parser, renderer, 저장, PDF·인쇄, Quick Look와 Thumbnail 동작에 영향이 없다.

Analytics payload 여섯 key, event/outbox schema, opt-out, server와 기존 운영 데이터도 변경하지 않았다. Production Worker 조회·전송, 기존 행 삭제·보정, public release, 서명과 공증을 수행하지 않았다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 성공, generated project 추가 diff 없음 |
| HostApp Debug unsigned build | 성공, 19.037초 |
| HostApp Release unsigned build | 성공, 31.049초 |
| Debug built endpoint | 빈 문자열, verifier 통과 |
| Release built endpoint | `project.yml` exact URL, verifier 통과 |
| Release URL 정책 | HTTPS·host·credential/query/fragment 없음 통과 |
| Debug·Release version/Sparkle key | 동일·기존 값 유지 |
| Debug·Release document type/UTI | 동일 |
| source·bundle rhwp-studio assets | 모두 통과 |
| 전체 HostAppTests | 161/161 통과, 실패 0, 18.553초 |
| verifier 정상·실패 fixture | 모두 통과 |
| verifier `shellcheck` | 통과 |
| `scripts/check-no-appkit.sh` | 통과 |
| core build info | 통과 |
| `git diff --check` | 통과 |

HostAppTests 실행 중 WebKit process의 RunningBoard·pasteboard sandbox 경고가 출력됐지만 PDF renderer 19개를 포함한 전체 161개 테스트가 통과했고 xcodebuild가 성공으로 종료했다.

## 등록 위생

Debug·Release build가 Stage 3 app을 LaunchServices에 자동 등록했다. 표준 cleanup과 두 app exact path unregister를 실행했다.

- PlugInKit provider app root는 `/Applications/Alhangeul.app`과 `/Users/melee/Applications/Alhangeul.app` 설치본만 표시됐다.
- Stage 3 Debug·Release와 과거 `build.noindex/` 앱의 stale LaunchServices record는 계속 남았다.
- 두 Stage 3 exact unregister는 Spotlight `-10814`를 반환했다.
- app bundle 삭제, 전역 LaunchServices reset, Finder/Quick Look daemon kill은 수행하지 않았다.

활성 개발 extension provider 유입은 없으며 이 로컬 stale record는 analytics configuration 완료 조건을 막지 않는다.

## Issue #479 완료 조건 대조

| 완료 조건 | 근거 | 판정 |
|-----------|------|------|
| Debug·개발 빌드 production 전송 차단 | base 빈 값, Debug built plist 빈 값, resolver/coordinator test | 충족 |
| Release production 수집 유지 | Release built plist exact HTTPS endpoint | 충족 |
| endpoint와 무관한 앱·문서 비차단 | missing/invalid endpoint test와 전체 HostAppTests | 충족 |
| 식별자·상세 build dimension 미추가 | payload·runtime source 무변경 | 충족 |
| project.yml 진실 원천 | source plist placeholder와 XcodeGen 생성 project | 충족 |
| 관련 단위·최소 빌드 검증 | 161 tests, Debug·Release build와 verifier | 충족 |
| 과거 운영 집계 한계 문서화 | 장기 analytics 계약의 설정 분리 전 행 해석 절 | 충족 |
| 기존 데이터·production 합성 event 제외 | 외부 변경·요청 미수행 | 충족 |

Issue #479의 구현·검증 완료 조건은 모두 충족한다. Issue는 PR merge 전까지 열린 상태로 유지한다.

## 잔여 위험

- Endpoint 분리는 서명 여부가 아니라 Release configuration 기준이다. 개발자가 unsigned Release app을 실행하면 production endpoint를 사용할 수 있으므로 Release local smoke는 정적 bundle 검증으로 제한해야 한다.
- PR CI는 Debug app을 직접 검사하고 Release는 source gate로 확인한다. Release full bundle은 이번 Stage 3에서 검증했으며 향후 release artifact preflight에서도 exact endpoint를 확인해야 한다.
- 설정 분리 전 운영 행은 payload만으로 공개·개발 실행을 사후 구분할 수 없다. 식별 dimension을 새로 추가하거나 기존 행을 보정하지 않는 원칙을 유지한다.
- 로컬 LaunchServices에는 과거 build path의 stale record가 남아 있다. 활성 provider와 구분하되 Finder/release smoke 전에 계속 위생을 확인한다.

## 다음 단계 영향

세 구현 Stage가 모두 완료됐다. 다음 단계는 `task-final-report` 절차로 최종 결과 보고서 작성, 오늘할일 완료 처리, 최종 커밋, `publish/task479` push와 `devel` 대상 PR 생성을 수행하는 것이다.

최종 보고 전 추가 제품 변경은 필요하지 않다. Public release, production Worker 변경과 Issue close는 이번 PR 게시 단계에서도 수행하지 않으며 Issue는 merge 뒤 정리한다.

## 승인 요청

Stage 3 최종 Debug·Release bundle 검증, 전체 회귀와 운영 한계 문서화를 완료했다. Task #479 최종 보고와 PR 게시를 위한 명시적 `task-final-report` 진행 승인을 요청한다.
