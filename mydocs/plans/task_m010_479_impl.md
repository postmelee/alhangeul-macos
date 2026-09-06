# Task M010 #479 구현계획서

수행계획서: `mydocs/plans/task_m010_479.md`

## 1. 작업 개요

- 이슈: [#479 Debug·개발 빌드의 production 익명 이벤트 전송을 차단한다](https://github.com/postmelee/alhangeul-macos/issues/479)
- 마일스톤: `M010` (`v0.1`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task479`
- 게시 브랜치: `publish/task479`
- 기준 커밋: `a2d15e2a5519b027002ce109d2c0277cbf08c8ca`
- 단계 수: 3

현재 HostApp 공통 `Info.plist`에 production 익명 이벤트 endpoint가 literal로 고정되어 Debug와 Release가 같은 URL을 해석한다. 이 작업은 production endpoint를 Release configuration에만 주입하고 Debug에서는 기존 endpoint resolver가 `nil`을 반환하게 만들어 production 네트워크 경로를 시작하지 않도록 한다.

구현계획 승인 전에는 Stage 1을 시작하지 않는다. 각 Stage 종료 뒤에는 `task-stage-report` 절차로 소스·테스트·단계 보고서를 함께 커밋하고 다음 단계 승인을 받는다. Public release, 서명, 공증과 production 합성 이벤트 전송은 어느 Stage에서도 실행하지 않는다.

## 2. 구현 전 확인 결과

| 항목 | 현재 상태 | 구현 영향 |
|------|-----------|-----------|
| production endpoint | `Sources/HostApp/Info.plist`의 `AlhangeulAppExecutionEndpoint`가 Worker URL literal을 보유한다. | 공통 plist에서 literal을 제거하고 build setting placeholder로 전환한다. |
| XcodeGen 설정 | `project.yml`의 HostApp 설정은 `base`만 사용하며 analytics용 Debug/Release 분기가 없다. | configuration별 custom setting을 `project.yml`에 추가하고 생성 project는 XcodeGen으로만 갱신한다. |
| endpoint resolver | `AppExecutionAnalyticsEndpoint.resolve()`는 nil, 빈 문자열, non-HTTPS, credential·query·fragment URL을 `nil`로 처리한다. | Debug 전용 runtime 분기 없이 빈 build setting과 기존 fail-closed 계약을 재사용할 수 있다. |
| 전송 시작 조건 | coordinator는 endpoint가 `nil`이면 connectivity 확인과 transport 생성을 모두 생략하고 outbox를 유지한다. | Debug 비활성 상태에서도 이벤트 상태·앱 실행을 막지 않으며 네트워크 요청 0건을 검증할 seam이 이미 있다. |
| 기존 테스트 | endpoint 형식 allowlist와 missing endpoint의 connectivity/transport 0건 테스트가 존재한다. | 새 runtime 구조보다 configuration과 built bundle drift 검증에 집중한다. |
| PR CI | macOS validation은 HostAppTests와 HostApp Debug build를 수행하지만 Release built plist를 직접 검사하지 않는다. | Debug bundle 검사와 Release configuration 검증을 최소 비용으로 자동화할 지점을 Stage 1에서 확정한다. |
| release build | package/release helper는 `-configuration Release`를 사용한다. | Release custom setting은 기존 배포 경로에 자연스럽게 주입돼야 하며 실제 built plist exact-value로 확인한다. |
| 개인정보 계약 | 공개 payload는 여섯 key로 고정되고 build identifier가 없다. | payload를 바꾸지 않고 build-time 전송 차단만 적용한다. |
| 운영 데이터 | v0.1.9 `existing_baseline` 두 행은 공개 Release와 개발 실행을 사후 구분할 수 없다. | 기존 행을 임의 보정하지 않고 관측 한계와 변경 시점만 문서화한다. |

## 3. 공통 설계·안전 계약

### 3.1 configuration source of truth

- `project.yml`을 HostApp build setting의 유일한 편집 원본으로 사용한다.
- `Sources/HostApp/Info.plist`의 endpoint 값은 `$(ALHANGEUL_APP_EXECUTION_ENDPOINT)` 같은 전용 custom setting placeholder만 참조한다.
- HostApp base 또는 Debug configuration의 custom setting은 빈 문자열로 고정한다.
- Release configuration에만 현재 공개 production HTTPS endpoint를 둔다.
- `Alhangeul.xcodeproj/project.pbxproj`는 직접 편집하지 않고 `xcodegen generate` 결과만 반영한다.
- command line 환경 변수나 개인 `.xcconfig` 없이는 public Release endpoint가 재현되지 않는 구조를 만들지 않는다.

### 3.2 Debug fail-closed와 Release fail-fast 검증

- Debug built plist의 endpoint key가 빈 문자열이면 `AppExecutionAnalyticsEndpoint.resolve()`가 `nil`을 반환해야 한다.
- 미정의 setting token이 `$(...)` 형태로 built plist에 남는 것을 정상 상태로 인정하지 않는다.
- Debug에서 outbox 관찰은 유지하되 connectivity resolver와 transport는 호출하지 않는다.
- Release built plist에는 exact production endpoint가 있어야 하고, HTTPS·host 존재·credential/query/fragment 없음 조건을 통과해야 한다.
- Release endpoint 누락이나 placeholder 잔존은 조용히 통과시키지 않고 configuration verifier 또는 Stage 3 built bundle 검증을 실패시킨다.
- production endpoint로 실제 HTTP 요청을 보내는 방식은 검증에 사용하지 않는다.

### 3.3 개인정보·운영 경계

- event payload, `event_id`, `occurred_date`, version, channel과 outbox schema는 변경하지 않는다.
- Debug/Release, build number, 서명 상태 또는 개발자 식별자를 새 payload field로 추가하지 않는다.
- endpoint는 공개 URL이며 secret·token·query parameter를 포함하지 않는다.
- 기존 production 행은 삭제·재분류하지 않는다. v0.1.10 변경 전에는 개발 빌드가 같은 endpoint를 사용했으므로 version별 집계를 공개 설치 수로 단정할 수 없다는 한계만 기록한다.
- staging endpoint는 별도 이슈와 승인이 있기 전에는 만들거나 사용하지 않는다.

### 3.4 자동화 최소화 원칙

- configuration drift를 잡는 작은 verifier로 충분하면 매 PR의 Release 전체 build를 새로 추가하지 않는다.
- verifier는 최소한 공통 plist가 custom setting을 참조하는지, Debug가 비어 있는지, Release가 유효한 공개 HTTPS URL인지 확인한다.
- macOS CI에서 이미 생성하는 Debug app을 사용할 수 있으면 built plist가 비어 있는지도 함께 확인한다.
- Release built plist의 최종 확인은 Stage 3의 local unsigned Release build에서 blocking 검증한다.
- CI 변경이 필요할 때도 release publish/rehearsal workflow와 secret 경계는 수정하지 않는다.

## 4. Stage 1 — 현행 재현과 configuration 계약 확정

### 4.1 목적

제품 소스를 변경하기 전에 현재 Debug와 Release가 모두 production endpoint를 포함하는 사실을 built bundle 기준으로 재현한다. XcodeGen configuration syntax, 기존 CI와 release helper 소비 경로를 확인해 Stage 2의 최소 변경 파일과 자동화 방식을 확정한다.

### 4.2 작업 범위

1. `project.yml`, HostApp source plist와 generated build setting에서 analytics endpoint의 현재 소유 위치를 표로 정리한다.
2. `xcodebuild -showBuildSettings`로 Debug와 Release의 configuration 이름, plist 경로와 custom setting 주입 가능 지점을 확인한다.
3. 현재 기준 Debug·Release HostApp을 각각 `build.noindex/task479-stage1-*`에 unsigned build한다.
4. 두 built app `Contents/Info.plist`의 endpoint 값과 URL 정책을 확인한다.
5. endpoint nil에서 connectivity와 transport를 호출하지 않는 기존 테스트, endpoint 형식 allowlist와 outbox 유지 계약을 재확인한다.
6. `.github/workflows/pr-ci.yml`의 macOS validation과 release helper check에서 verifier를 호출할 최소 지점을 결정한다.
7. Stage 2에서 사용할 setting 이름, Debug 빈 값 표현, Release URL source와 verifier 범위를 확정한다.

### 4.3 예상 산출물

- `mydocs/working/task_m010_479_stage1.md`
- `mydocs/orders/20260826.md`

Stage 1에서는 production source, `project.yml`, 테스트와 workflow를 수정하지 않는다. Debug·Release app과 진단 출력은 `build.noindex/`에만 두고 커밋하지 않는다.

### 4.4 검증

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task479-stage1-debug \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/task479-stage1-release \
  CODE_SIGNING_ALLOWED=NO \
  build
plutil -extract AlhangeulAppExecutionEndpoint raw -o - \
  build.noindex/task479-stage1-debug/Build/Products/Debug/Alhangeul.app/Contents/Info.plist
plutil -extract AlhangeulAppExecutionEndpoint raw -o - \
  build.noindex/task479-stage1-release/Build/Products/Release/Alhangeul.app/Contents/Info.plist
git diff --check
```

HostAppTests 전체 실행은 Stage 2에서 수행한다. Stage 1에서는 기존 endpoint/missing endpoint 테스트를 source와 이전 결과로 확인하거나 필요한 경우 해당 test class만 선택 실행한다.

### 4.5 완료 기준

- 현재 Debug와 Release built plist의 endpoint 값이 기록된다.
- Debug/Release custom setting의 단일 진실 원천과 exact 이름이 확정된다.
- 빈 setting이 built plist에서 빈 문자열로 resolve되는지 또는 별도 key 제거가 필요한지 판단된다.
- Stage 2에서 수정할 파일과 verifier/CI 필요 여부가 승인 가능한 수준으로 좁혀진다.
- 사용자 데이터나 production Worker 요청 없이 재현이 완료된다.

### 4.6 커밋

`Task #479 Stage 1: analytics endpoint 구성 경계와 회귀 재현`

## 5. Stage 2 — Release-only endpoint 주입과 회귀 gate 구현

### 5.1 목적

공통 plist의 production literal을 제거하고 Release configuration에만 endpoint를 주입한다. Debug 비활성·Release 유효 endpoint와 기존 missing endpoint 비차단 계약을 자동 검증해 configuration drift를 차단한다.

### 5.2 예상 변경 파일

- `Sources/HostApp/Info.plist`
- `project.yml`
- `Alhangeul.xcodeproj/project.pbxproj` (`xcodegen generate` 결과)
- `Tests/HostAppTests/AppExecutionAnalyticsRuntimeTests.swift` (기존 계약 보강이 필요한 경우만)
- 필요 시 신규 `scripts/ci/verify-app-execution-endpoint-config.sh`
- 필요 시 `.github/workflows/pr-ci.yml`
- `mydocs/working/task_m010_479_stage2.md`
- `mydocs/orders/20260826.md`

Stage 1에서 기존 테스트와 CI가 충분하다고 판정하면 불필요한 runtime source·test·workflow 변경은 만들지 않는다.

### 5.3 구현 항목

1. `Info.plist`의 endpoint literal을 승인된 custom setting placeholder로 교체한다.
2. `project.yml` HostApp settings에 다음 configuration 계약을 추가한다.
   - base/Debug: 빈 값
   - Release: 기존 production HTTPS endpoint
3. `xcodegen generate`로 project를 재생성하고 analytics setting 외 예상 밖 project 변경이 없는지 확인한다.
4. Debug configuration에서 다음을 검증한다.
   - built plist endpoint가 빈 문자열 또는 승인된 부재 상태
   - resolver 결과 `nil`
   - seeded outbox가 있어도 connectivity/transport 0건
5. Release configuration에서 다음을 검증한다.
   - custom setting과 built plist에 exact production endpoint 존재
   - HTTPS/host/credential/query/fragment 정책 통과
   - placeholder token 잔존 없음
6. 필요한 경우 isolated configuration verifier를 추가한다.
   - source plist placeholder 일치
   - `project.yml` Debug/Release 분리
   - Release URL 공개 HTTPS 정책
   - production URL literal의 공통 plist 재유입 차단
7. verifier를 PR CI에 연결할 때 기존 `classify-changes`와 macOS validation 구조를 유지하고 Release publish workflow는 건드리지 않는다.
8. 기존 analytics runtime·outbox·opt-out·Sparkle·payload 테스트를 모두 유지한다.

### 5.4 자동 회귀

- endpoint resolver: nil, 빈 값, placeholder-like invalid value, non-HTTPS와 credential/query/fragment URL은 `nil`
- missing endpoint coordinator: connectivity 0회, transport 0회, outbox 유지
- configured endpoint coordinator: 기존 stub endpoint에만 요청하고 production URL은 호출하지 않음
- Debug config: production endpoint 불포함
- Release config: exact endpoint 포함, 유효한 공개 HTTPS URL
- XcodeGen 재생성: 두 번째 실행에서 추가 diff 없음
- 공개 payload: 기존 여섯 key만 유지

### 5.5 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task479-stage2-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task479-stage2-debug \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/check-no-appkit.sh
git diff --check
```

신규 verifier를 추가하면 shell syntax, `shellcheck`와 정상·실패 fixture를 함께 검증한다. Release 전체 built bundle 검증은 Stage 3에서 수행하되, Stage 2에서는 `xcodebuild -showBuildSettings -configuration Release` 또는 동등한 정적 gate로 Release setting을 확인한다.

### 5.6 완료 기준

- Debug built app에서 production endpoint가 해석되지 않는다.
- Release configuration에서 production endpoint가 정확히 해석된다.
- endpoint 없음에서 네트워크 경로를 시작하지 않는 테스트가 통과한다.
- 기존 analytics·앱 실행 계약과 generated project 정합성이 유지된다.
- configuration drift를 자동으로 검출할 최소 gate가 마련된다.

### 5.7 커밋

`Task #479 Stage 2: Release 전용 analytics endpoint 주입`

## 6. Stage 3 — 전체 산출물 검증과 운영 한계 문서화

### 6.1 목적

깨끗한 Debug·Release 산출물에서 configuration 분리를 최종 확인하고, 기존 운영 집계의 한계와 향후 개발 smoke 정책을 장기 analytics 계약에 반영한다.

### 6.2 예상 변경 파일

- `mydocs/tech/task_m040_453_app_execution_analytics_contract.md`
- 필요 시 `mydocs/release/v0.1.10.md`
- 필요 시 `mydocs/manual/build_run_guide.md`
- `mydocs/working/task_m010_479_stage3.md`
- `mydocs/orders/20260826.md`

문서는 기존 내용을 먼저 읽고 configuration 소유·운영 한계·검증 절차에 필요한 부분만 수정한다. Public release 실행 결과나 기존 운영 데이터 보정 사실을 만들지 않는다.

### 6.3 작업 항목

1. 새 `build.noindex/task479-stage3-*` 경로에서 HostAppTests, Debug HostApp과 Release HostApp을 빌드한다.
2. 두 app의 `Contents/Info.plist`를 비교한다.
   - Debug: production endpoint 없음/빈 값
   - Release: exact production endpoint
   - 공통 Sparkle, bundle version과 문서 UTI key 유지
3. Release endpoint를 `AppExecutionAnalyticsEndpoint` 정책과 같은 조건으로 정적 검증한다.
4. Debug 산출물은 실제 production 네트워크 smoke 대신 resolver/configuration/transport stub 증거로 요청 0건을 판정한다.
5. 전체 HostAppTests에서 outbox·opt-out·Sparkle·payload 회귀를 확인한다.
6. analytics 장기 계약에 configuration 소유와 다음 운영 해석 한계를 추가한다.
   - 변경 전 Debug가 production endpoint를 포함할 수 있었음
   - v0.1.9 기존 행은 공개 설치와 개발 실행을 사후 구분할 수 없음
   - 기존 행을 삭제·보정하지 않음
   - 이후 Debug는 production 전송 경로가 비활성
7. staging 실제 전송 smoke가 필요하면 production과 분리된 endpoint 및 별도 승인 없이는 수행하지 않는다고 기록한다.
8. XcodeGen 재생성, AppKit 경계, git diff와 extension registration hygiene를 최종 확인한다.

### 6.4 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task479-stage3-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task479-stage3-debug \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/task479-stage3-release \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/task479-stage3-debug/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/task479-stage3-release/Build/Products/Release/Alhangeul.app/Contents/Resources/rhwp-studio
git diff --check
```

추가 확인:

- `plutil`로 Debug/Release endpoint와 기존 주요 plist key 비교
- production URL이 `project.yml`의 Release 설정과 최종 Release app 외 불필요한 product source에 중복되지 않는지 검사
- `scripts/check-extension-registration-hygiene.sh`로 개발 extension 등록이 새로 남지 않았는지 확인
- 실제 production Worker 요청, public package와 서명·공증은 미실행

### 6.5 완료 기준

- Debug built app이 production endpoint를 포함하거나 해석하지 않는다.
- unsigned Release built app에는 exact production endpoint가 포함된다.
- endpoint 없음·잘못된 endpoint에서 앱 실행과 문서 기능이 비차단으로 유지된다.
- 전체 HostAppTests와 Debug/Release build가 통과한다.
- 기존 운영 집계의 관측 한계와 미보정 원칙이 문서화된다.
- public 배포나 production 합성 이벤트 없이 Issue #479 완료 조건을 충족한다.

### 6.6 커밋

`Task #479 Stage 3: analytics configuration 검증과 운영 한계 문서화`

## 7. 중단·보정 기준

1. XcodeGen의 빈 custom setting이 built plist에 unexpanded token으로 남으면 이를 정상으로 간주하지 않는다. Stage 2 구현 전에 key omission, plist preprocessing 또는 별도 config plist 중 최소 변경 대안을 Stage 1 보고에서 승인받는다.
2. Release helper가 표준 `Release` 외 configuration을 사용하거나 command line에서 setting을 덮어쓴다면 임의로 두 소스를 병행하지 않고 `project.yml`과 release 경로 중 단일 진실 원천을 다시 확정한다.
3. Debug 비활성을 위해 runtime source에 `#if DEBUG`를 추가해야 한다면 Release-only 주입과 책임이 중복되는 이유를 보고하고 승인 없이 적용하지 않는다.
4. CI에서 Release full build 추가가 큰 시간 증가를 만들면 configuration verifier와 local Stage 3 Release build로 역할을 분리한다.
5. 운영 데이터에서 개발 실행임을 입증할 수 없는 행을 발견해도 삭제·재분류하지 않는다. 외부 analytics 저장소 변경이 필요하면 별도 이슈와 승인을 요청한다.
6. staging endpoint, secret, public release 또는 signed/notarized artifact 검증이 필요해지면 이번 범위를 확대하지 않는다.

## 8. 단계 승인·보고 경계

- Stage별 작업은 직전 단계 또는 구현계획 승인 후에만 시작한다.
- 각 Stage 완료 시 `task-stage-report`를 명시 적용해 `mydocs/working/task_m010_479_stage{N}.md`를 작성하고 관련 변경과 하나의 Stage 커밋으로 묶는다.
- 단계 검증이 실패하면 보고서·커밋을 만들지 않고 같은 Stage 안에서 원인을 해결한다. 범위가 달라지면 구현계획 보정 승인을 요청한다.
- Stage 3까지 승인된 뒤에만 `task-final-report` 절차로 최종 보고서, 오늘할일 완료 처리, 최종 커밋, `publish/task479` push와 `devel` 대상 PR을 진행한다.
- Issue #479는 PR merge 전까지 열린 상태로 유지한다.

## 9. 구현계획 승인 요청

1. Stage 1에서 현재 Debug·Release built plist의 production endpoint 포함을 실제 요청 없이 재현하고 configuration 계약을 확정하는 방향 승인
2. Stage 2에서 공통 plist literal을 custom setting으로 바꾸고 `project.yml` Release에만 production endpoint를 두는 방향 승인
3. Debug는 기존 resolver/coordinator의 nil fail-closed 경로를 재사용하고 payload·runtime schema를 바꾸지 않는 방향 승인
4. configuration verifier와 기존 macOS CI를 우선 사용하고 Release 전체 build는 Stage 3 local blocking 검증으로 두는 최소 자동화 방향 승인
5. Stage 3에서 기존 운영 행을 보정하지 않고 관측 한계와 staging 금지 경계만 문서화하는 방향 승인
6. 위 3개 Stage, 중단 기준과 단계별 승인·보고 경계 승인 후 Stage 1 진행 승인
