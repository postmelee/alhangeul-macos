# Task M010 #479 Stage 1 완료보고서

## 단계 목적

제품 소스를 변경하기 전에 현재 Debug와 Release HostApp의 analytics endpoint 소유·확장 경계를 built bundle 기준으로 재현한다. XcodeGen의 configuration별 custom setting과 빈 기본값 확장 동작을 격리 probe로 확인하고, Stage 2에서 수정할 최소 파일·검증·CI 경계를 확정한다.

## 산출물

| 산출물 | 내용 |
|--------|------|
| Debug HostApp | `build.noindex/task479-stage1-debug/Build/Products/Debug/Alhangeul.app` |
| Release HostApp | `build.noindex/task479-stage1-release/Build/Products/Release/Alhangeul.app` |
| analytics 선택 테스트 | `build.noindex/task479-stage1-tests/Logs/Test/Test-HostAppTests-2026.08.26_11-24-19-+0900.xcresult` |
| XcodeGen 격리 probe | `build.noindex/task479-stage1-xcodegen-probe/` 아래 base 빈 값과 Release override 검증 산출물 |
| package cache | `build.noindex/task479-stage1-packages/`의 pinned Sparkle 2.9.1 checkout |
| 단계 보고서 | `mydocs/working/task_m010_479_stage1.md` |
| 오늘할일 | `mydocs/orders/20260826.md`의 #479 상태 갱신 |

Build·test·probe 산출물은 모두 ignored `build.noindex/`에만 두고 커밋하지 않는다. Stage 1 커밋에는 본 보고서와 오늘할일 갱신만 포함한다.

## 현행 configuration 재현

### Source와 resolved setting

현재 endpoint를 참조하는 제품 경로는 다음 두 곳뿐이다.

| 경로 | 현재 역할 |
|------|-----------|
| `Sources/HostApp/Info.plist` | `AlhangeulAppExecutionEndpoint`에 production Worker URL literal 보관 |
| `Sources/HostApp/Services/AppExecutionAnalyticsRuntime.swift` | 동일 key를 읽고 유효한 HTTPS URL만 반환 |

`project.yml`과 generated project에는 analytics용 custom build setting이 없다. `xcodebuild -showBuildSettings` 결과 Debug와 Release 모두 다음 경계를 공유했다.

| 항목 | Debug | Release |
|------|-------|---------|
| `CONFIGURATION` | `Debug` | `Release` |
| `INFOPLIST_FILE` | `Sources/HostApp/Info.plist` | `Sources/HostApp/Info.plist` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.postmelee.alhangeul` | `com.postmelee.alhangeul` |
| analytics custom setting | 없음 | 없음 |

### Built plist 결과

현재 source를 unsigned Debug·Release로 각각 빌드한 뒤 `plutil`로 확인한 결과다.

| configuration | `AlhangeulAppExecutionEndpoint` |
|---------------|----------------------------------|
| Debug | `https://alhangeul-install-events.postmelee.workers.dev/v1/install-events` |
| Release | `https://alhangeul-install-events.postmelee.workers.dev/v1/install-events` |

따라서 Issue #479의 원인은 재현됐다. 공통 source plist literal이 두 configuration의 `ProcessInfoPlistFile -expandbuildsettings`에 그대로 들어가므로 Debug 앱도 production endpoint를 해석한다.

다음 주요 key는 두 built plist에서 동일하게 유지됐다.

| key | Debug·Release 값 |
|-----|------------------|
| `CFBundleShortVersionString` | `0.1.10` |
| `CFBundleVersion` | `16` |
| `SUFeedURL` | `https://postmelee.github.io/alhangeul-macos/appcast.xml` |
| `SUPublicEDKey` | 기존 공개 EdDSA key 유지 |

## XcodeGen configuration 계약 확정

`build.noindex/task479-stage1-xcodegen-probe/`에 production target과 분리된 최소 macOS app spec을 만들고 다음 형태를 검증했다.

```yaml
settings:
  base:
    ALHANGEUL_APP_EXECUTION_ENDPOINT: ""
  configs:
    Release:
      ALHANGEUL_APP_EXECUTION_ENDPOINT: https://collector.example/v1/install-events
```

Probe plist는 endpoint 값을 `$(ALHANGEUL_APP_EXECUTION_ENDPOINT)`로 참조했다. XcodeGen 생성 project와 실제 Debug·Release build 결과는 다음과 같았다.

| 항목 | Debug | Release |
|------|-------|---------|
| generated build setting | `""` | 지정 HTTPS URL |
| built plist endpoint | 빈 문자열 | 지정 HTTPS URL |
| unexpanded `$(...)` token | 없음 | 없음 |
| build | 성공 | 성공 |

따라서 Stage 2에서는 별도 Debug override 없이 base를 빈 문자열로 두고 Release만 override한다. 이 방식은 Debug뿐 아니라 향후 추가되는 개발 configuration도 기본적으로 비활성화하며, Release만 명시적으로 production endpoint를 얻는다.

Custom setting 이름은 `ALHANGEUL_APP_EXECUTION_ENDPOINT`로 확정한다. Source plist key `AlhangeulAppExecutionEndpoint`와 구분되고 기존 코드의 key 이름은 바꾸지 않는다.

## Runtime·테스트 경계 확인

현재 runtime은 configuration을 직접 알 필요가 없다.

- `AppExecutionAnalyticsEndpoint.resolve()`는 nil·빈 문자열·잘못된 URL을 `nil`로 반환한다.
- `AppExecutionAnalyticsCoordinator.startIfNeeded()`는 endpoint가 `nil`이면 connectivity 확인과 transport factory 호출을 모두 생략한다.
- outbox는 제거하지 않고 유지하므로 다음 유효한 Release 실행에서 기존 보존 정책에 따라 처리할 수 있다.
- 앱 launch path는 coordinator completion을 기다리지 않는다.

`AppExecutionAnalyticsRuntimeTests`만 선택 실행해 12개 모두 통과했다.

| 대표 테스트 | 결과 |
|-------------|------|
| HTTPS·credential/query/fragment endpoint allowlist | 통과 |
| missing endpoint에서 connectivity 0회 | 통과 |
| missing endpoint에서 transport 0회·outbox 유지 | 통과 |
| 연결 없음·중복 flush·opt-out 취소 | 통과 |
| ephemeral transport·redirect 거부·payload 전송 | 통과 |

Stage 2는 `#if DEBUG` runtime 분기나 payload schema 변경 없이 configuration 주입만으로 목표를 달성할 수 있다. 기존 test에 unexpanded placeholder 형태를 명시적으로 추가할 수 있으나 핵심 제품 bundle 계약은 source verifier와 built plist 검증이 담당해야 한다.

## Stage 2 변경·자동화 경계

### 확정 변경

| 파일 | 변경 방향 |
|------|-----------|
| `Sources/HostApp/Info.plist` | production URL literal을 `$(ALHANGEUL_APP_EXECUTION_ENDPOINT)`로 교체 |
| `project.yml` | HostApp base에 빈 setting, Release override에 기존 production URL 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate` 결과만 반영 |

### 권장 verifier

`scripts/verify-app-execution-endpoint-config.sh`를 작은 portable verifier로 추가하는 방향을 확정한다.

- source plist가 custom setting placeholder를 참조하고 production URL literal을 보유하지 않는지 확인
- `project.yml` HostApp base 값이 빈 문자열인지 확인
- Release override가 credential·query·fragment 없는 HTTPS URL인지 확인
- Debug/기타 configuration이 production URL을 별도로 override하지 않는지 확인
- 선택적으로 Debug/Release built app 경로를 받아 built plist의 빈 값·유효 URL·placeholder 잔존을 검사
- `--help`, 정상 fixture와 잘못된 base/Release/placeholder fixture 제공

Verifier는 Ubuntu의 script-checks에서도 동작하도록 macOS 전용 API 대신 Ruby 표준 `Psych`, XML parser와 `URI` 또는 동등한 portable 도구를 사용한다. Production URL의 유일한 설정 원본은 `project.yml`로 유지하고 verifier 안에 같은 URL을 상수로 복제하지 않는다.

### CI 연결

- `project.yml`과 `Sources/HostApp/Info.plist` 변경은 기존 classifier에서 `run_macos_build=true`를 만든다.
- `script-checks`는 모든 PR에서 실행되므로 source configuration verifier를 여기에 연결한다.
- 기존 macOS validation의 `Build HostApp Debug` 다음에 built Debug app을 verifier로 확인하면 production endpoint 재유입을 실제 산출물에서 차단할 수 있다.
- Release 전체 build를 매 PR에 추가하지 않는다. Source verifier가 Release override를 검사하고 Stage 3에서 unsigned Release built plist를 blocking 검증한다.
- `.github/workflows/pr-ci.yml` 변경 때문에 이번 PR에서는 기존 release helper checks도 함께 실행될 수 있으나 release publish/rehearsal workflow 자체는 수정하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

Stage 1에서는 제품 source, `project.yml`, generated project, test와 장기 기술 문서를 수정하지 않았다. HWP/HWPX 문서 본문, 앱 저장 데이터, analytics production 집계와 endpoint server에도 변경이 없다.

실제 production Worker 요청은 전송하지 않았다. Debug·Release app은 build만 수행하고 실행하지 않았으며, endpoint 비교는 built plist 정적 검사로 완료했다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| 최초 `showBuildSettings` sandbox 실행 | Sparkle clone DNS 제한으로 실패, 제품 회귀 아님 |
| shared package cache resolution | Sparkle 2.9.1 성공 |
| Debug `showBuildSettings` | 성공, 공통 source plist·custom setting 없음 확인 |
| Release `showBuildSettings` | 성공, 공통 source plist·custom setting 없음 확인 |
| HostApp Debug unsigned build | 성공, 24.763초 |
| HostApp Release unsigned build | 성공, 33.029초 |
| 현재 Debug built endpoint | production URL 포함 재현 |
| 현재 Release built endpoint | 같은 production URL 포함 확인 |
| XcodeGen 격리 probe Debug | build 성공, built endpoint 빈 문자열 |
| XcodeGen 격리 probe Release | build 성공, Release override URL 포함 |
| `AppExecutionAnalyticsRuntimeTests` | 12/12 통과, 실패 0 |
| `git diff --check` | 통과 |

최초 sandbox 실패는 외부 Sparkle package DNS 접근 제한이었다. `build.noindex/task479-stage1-packages`에 exact 2.9.1을 한 번 해석한 뒤 `-disableAutomaticPackageResolution`로 모든 제품 조회·빌드를 재실행해 성공했다.

## 등록 위생

Xcode build가 Debug·Release app을 LaunchServices에 자동 등록했다. 표준 `check-extension-registration-hygiene.sh --cleanup-dev-registrations`와 Task #479/Probe exact path `lsregister -u`를 실행했다.

- PlugInKit provider app roots는 허용된 `/Applications/Alhangeul.app`, `/Users/melee/Applications/Alhangeul.app`만 표시됐다.
- Task #479 app과 이전 task build path의 stale LaunchServices record는 check-only 결과에 계속 남았다.
- Exact unregister는 Task #479 Alhangeul app에 `-10814 from spotlight`를 반환했다.
- App bundle 파일 삭제, 전역 LaunchServices reset, Finder/Quick Look daemon kill은 수행하지 않았다.

이 잔여 record는 active extension provider 오염과 분리된 로컬 환경 상태이며 Stage 2 제품 설계를 막지 않는다. 후속 Stage 빌드에서도 active provider roots와 stale registration을 구분해 기록한다.

## 잔여 위험

- Source verifier가 `project.yml`만 검사하면 XcodeGen 또는 build setting expansion 회귀를 완전히 보장하지 못한다. Debug built app 검사를 macOS validation에 함께 연결한다.
- Release 전체 built plist는 매 PR CI에서 직접 만들지 않으므로 Stage 3 local Release build와 release artifact preflight가 최종 경계를 담당한다.
- Base 빈 문자열은 probe에서 안정적으로 확장됐지만 HostApp의 실제 plist·project에 적용한 뒤 Stage 2에서 다시 확인해야 한다.
- `project.yml` Release URL이 다른 유효 HTTPS endpoint로 바뀌면 형식 검증만으로 의도된 production host까지 판정하지 못한다. Project 설정을 단일 진실 원천으로 두고 code review와 Stage 3 exact 비교로 보완한다.
- 변경 전 운영 집계의 v0.1.9 행은 공개 설치와 개발 실행을 사후 구분할 수 없다. Stage 3에서 삭제·보정 없이 관측 한계를 기록해야 한다.
- 로컬 LaunchServices에는 여러 과거 build path의 stale registration이 남아 있다. Active provider 판정과 혼동하지 않되 release/Finder smoke 전에 별도 위생 확인이 필요하다.

## 다음 단계 영향

Stage 2는 upstream, RustBridge, bundled Studio와 analytics server 변경 없이 진행할 수 있다. 핵심 구현은 공통 plist literal 제거, `project.yml` base 빈 값/Release override와 portable verifier다.

Runtime source 변경은 필요하지 않다. 기존 endpoint resolver와 coordinator test seam을 유지하고 configuration 및 built bundle 검증에 집중한다. CI에는 source verifier와 기존 Debug build 산출물 검사만 추가하며 Release full build는 Stage 3까지 미룬다.

## 승인 요청

Stage 1의 현행 재현, XcodeGen probe, runtime·CI 조사와 configuration 계약 확정을 완료했다. 다음 방향으로 Stage 2 진입 승인을 요청한다.

1. `ALHANGEUL_APP_EXECUTION_ENDPOINT` base 빈 값과 Release-only production URL override 적용
2. 공통 `Info.plist`는 해당 custom setting placeholder만 참조
3. runtime·payload schema는 변경하지 않고 기존 nil fail-closed 경로 재사용
4. portable source verifier와 macOS Debug built plist 검사 추가
5. Release full build는 Stage 3 blocking 검증으로 유지
