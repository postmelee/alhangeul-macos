# Task M010 #479 Stage 2 완료보고서

## 단계 목적

HostApp 공통 plist에서 production analytics endpoint literal을 제거하고 Release configuration에만 endpoint를 주입한다. Debug 산출물에서는 endpoint가 빈 값으로 확장돼 기존 fail-closed runtime이 connectivity·transport 경로를 시작하지 않게 하고, source configuration과 실제 Debug bundle의 drift를 PR CI에서 자동 검출한다.

## 산출물

| 산출물 | 내용 |
|--------|------|
| configuration 원본 | `project.yml`의 HostApp base 빈 값과 Release 전용 운영 endpoint |
| source plist | `Sources/HostApp/Info.plist`의 전용 build setting placeholder |
| generated project | `Alhangeul.xcodeproj/project.pbxproj`의 Debug 빈 값·Release URL |
| source/bundle verifier | `scripts/ci/verify-app-execution-endpoint-config.sh` |
| verifier fixture | `scripts/ci/test-app-execution-endpoint-config.sh` |
| PR CI gate | source fixture와 Debug built app endpoint 검사 |
| Debug HostApp | `build.noindex/task479-stage2-debug/Build/Products/Debug/Alhangeul.app` |
| HostAppTests 결과 | `build.noindex/task479-stage2-tests/Logs/Test/Test-HostAppTests-2026.08.26_11-37-04-+0900.xcresult` |
| 단계 보고서 | `mydocs/working/task_m010_479_stage2.md` |

Build·test 산출물은 ignored `build.noindex/`에만 두며 커밋하지 않는다.

## 구현 결과

### Release-only configuration

HostApp endpoint의 configuration matrix는 다음과 같다.

| 경계 | Debug·기타 configuration | Release |
|------|--------------------------|---------|
| `project.yml` | `ALHANGEUL_APP_EXECUTION_ENDPOINT: ""` | 기존 production HTTPS URL |
| generated project | 빈 build setting | production URL build setting |
| source `Info.plist` | 공통 placeholder | 공통 placeholder |
| 실제/예상 built plist | 빈 문자열 | production URL |
| runtime resolver | `nil` | 유효한 `URL` |

`Sources/HostApp/Info.plist`는 더 이상 production URL literal을 보유하지 않고 `$(ALHANGEUL_APP_EXECUTION_ENDPOINT)`만 참조한다. XcodeGen source of truth인 `project.yml`의 HostApp base는 빈 문자열이며 Release override만 다음 URL을 보유한다.

`https://alhangeul-install-events.postmelee.workers.dev/v1/install-events`

Runtime source, event payload, outbox schema와 production Worker는 변경하지 않았다. 기존 `AppExecutionAnalyticsEndpoint.resolve()`가 빈 문자열을 `nil`로 거부하고 coordinator가 endpoint 없음에서 connectivity resolver와 transport factory를 호출하지 않는 계약을 그대로 재사용한다.

### XcodeGen 정합성

`xcodegen generate` 결과 generated project 변경은 HostApp 두 configuration의 custom setting 두 줄뿐이다.

- Debug: `ALHANGEUL_APP_EXECUTION_ENDPOINT = "";`
- Release: `ALHANGEUL_APP_EXECUTION_ENDPOINT = "https://.../v1/install-events";`

XcodeGen을 연속 두 번 실행해 추가 diff가 생기지 않는 것을 확인했다. `Alhangeul.xcodeproj`는 직접 수정하지 않았다.

## 자동 회귀 gate

### Portable source verifier

`scripts/ci/verify-app-execution-endpoint-config.sh`는 기본 호출에서 Ruby 표준 라이브러리만 사용해 다음을 검증한다.

- HostApp base setting이 존재하고 정확히 빈 문자열인지
- analytics setting override가 Release에만 존재하는지
- Release endpoint가 host를 가진 절대 HTTPS URL인지
- endpoint에 credential, query 또는 fragment가 없는지
- source plist가 exact custom setting placeholder를 참조하는지
- source plist에 production URL literal이 다시 들어오지 않는지

선택적인 `--debug-app`은 built `Contents/Info.plist`의 endpoint가 정확히 빈 문자열인지 확인한다. `--release-app`은 built endpoint가 `project.yml`의 Release 값과 일치하는지 확인하며 Stage 3 최종 산출물 검증에서 사용한다. Verifier 안에는 별도 production URL 상수를 복제하지 않고 `project.yml`을 단일 값 원본으로 유지했다.

### Fixture와 CI 연결

`scripts/ci/test-app-execution-endpoint-config.sh`는 tracked configuration 정상 사례와 다음 실패 fixture를 임시 디렉터리에서 검증한다.

| fixture | 검출 계약 |
|---------|-----------|
| invalid base | Debug·기본값에 endpoint가 들어오면 실패 |
| invalid Release | HTTP endpoint면 실패 |
| invalid source plist | placeholder 대신 URL literal이면 실패 |

PR CI의 `script-checks`에 helper interface와 fixture 검증을 추가했다. 기존 macOS validation의 HostApp Debug build 직후에는 실제 app 경로를 `--debug-app`으로 검사한다. Release 전체 build를 PR마다 새로 추가하지 않았으며, Release 산출물 검증은 계획대로 Stage 3의 local blocking check로 유지한다.

## 본문 변경 정도 / 본문 무손실 여부

HWP/HWPX 문서 파서, 렌더러, 저장 경로, PDF 내보내기와 문서 본문에는 변경이 없다. Analytics event payload의 여섯 key, event/outbox 상태, opt-out, Sparkle 설정과 version key도 변경하지 않았다.

Production endpoint로 실제 요청을 보내지 않았다. Debug app은 build와 plist 정적 검사만 수행했고 실행하지 않았다. Release는 Stage 2에서 `showBuildSettings`까지만 확인했으며 앱을 build·실행하지 않았다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `xcodegen generate` 연속 2회 | 성공, 추가 diff 없음 |
| generated project diff | HostApp Debug·Release setting 2줄만 변경 |
| verifier 정상 configuration | 통과 |
| invalid base fixture | 의도대로 실패 |
| invalid Release fixture | 의도대로 실패 |
| invalid source plist fixture | 의도대로 실패 |
| verifier `--help` | 통과 |
| 신규 스크립트 `bash -n` | 통과 |
| 신규 스크립트 `shellcheck` | 통과 |
| 전체 workflow·project YAML parse | 통과 |
| HostApp Debug unsigned build | 성공, 17.264초 |
| Debug built endpoint | 빈 문자열 확인 |
| Release `showBuildSettings` | exact production endpoint 확인 |
| 전체 HostAppTests | 161/161 통과, 실패 0 |
| missing endpoint runtime 계약 | 전체 테스트 안에서 통과 |
| `scripts/check-no-appkit.sh` | 통과 |
| core build info 검증 | 통과 |
| bundled rhwp-studio assets 검증 | 통과 |
| `git diff --check` | 통과 |

최초 sandbox Debug build는 SwiftPM·Clang cache의 사용자 cache directory 쓰기가 제한돼 종료 코드 74로 실패했다. 같은 source와 command를 허용된 Xcode 실행 경계에서 다시 수행해 성공했으므로 제품·설정 회귀가 아니다.

전체 HostAppTests 실행 중 WebKit process의 RunningBoard·pasteboard 경고가 출력됐지만 모든 161개 테스트와 PDF renderer 19개 테스트가 통과했고 xcodebuild가 성공으로 종료했다.

## 등록 위생

Debug build가 Stage 2 app을 LaunchServices에 자동 등록해 표준 `check-extension-registration-hygiene.sh --cleanup-dev-registrations --no-cache-reset`과 Stage 2 app exact path unregister를 수행했다.

- PlugInKit이 표시한 provider app root는 `/Applications/Alhangeul.app`과 `/Users/melee/Applications/Alhangeul.app` 두 설치본이다.
- Stage 2 app을 포함한 과거 `build.noindex/` 개발 등록이 LaunchServices dump에 남아 있다.
- Stage 2 exact unregister는 이전 단계와 같은 Spotlight `-10814`를 반환했다.
- app bundle 삭제, 전역 LaunchServices reset, Finder/Quick Look daemon kill은 수행하지 않았다.

따라서 활성 개발 extension provider 유입은 확인되지 않았지만 로컬 LaunchServices stale record 문제는 남아 있다. 이는 configuration 구현과 테스트 결과를 막지 않으며 Stage 3 최종 위생 검사에서도 별도로 기록한다.

## 잔여 위험

- Release full built plist는 아직 확인하지 않았다. Source verifier와 `showBuildSettings`는 통과했지만 실제 `ProcessInfoPlistFile` 확장 결과는 Stage 3 Release build에서 blocking 검증해야 한다.
- PR CI는 Debug built bundle만 직접 검사한다. Release endpoint가 다른 유효 HTTPS URL로 바뀌는 경우 형식 gate는 통과할 수 있으므로 code review와 Stage 3 exact source-to-bundle 비교가 필요하다.
- 변경 전 v0.1.9 운영 행은 공개 설치와 개발 실행을 사후 구분할 수 없다. 기존 행을 보정하지 않고 Stage 3 장기 계약에 관측 한계를 기록해야 한다.
- 로컬 LaunchServices stale registration은 Task #479 외 과거 build도 포함한다. 활성 provider 판정과 분리하되 Finder smoke나 release 검증 전에는 계속 확인해야 한다.

## 다음 단계 영향

Stage 3는 새 Debug·Release 산출물을 각각 만들고 verifier의 `--debug-app`·`--release-app`으로 built plist 분리를 최종 확인한다. 전체 HostAppTests를 다시 실행한 뒤 analytics 장기 계약 문서에 다음 내용을 필요한 범위만 추가한다.

1. `project.yml`이 endpoint configuration의 단일 진실 원천임
2. Debug·기타 기본 configuration은 production 전송 비활성임
3. Release만 production endpoint를 보유함
4. 변경 전 운영 집계는 공개 설치와 개발 실행을 사후 분리할 수 없음
5. 기존 운영 행은 삭제·보정하지 않음

Public release, 서명, 공증과 production 합성 이벤트 전송은 Stage 3에서도 수행하지 않는다.

## 승인 요청

Release-only endpoint 주입, Debug built bundle 차단, portable regression gate와 전체 HostAppTests 검증을 완료했다. Stage 3의 깨끗한 Debug·Release 최종 산출물 검증과 운영 한계 문서화 진행 승인을 요청한다.
