# Issue #433 구현 계획서

수행계획서: `mydocs/plans/task_m040_433.md`

## 작업 개요

- 이슈: #433 HOP Quick Look 충돌 가능성 감지와 최신 rhwp 안내 UI 추가
- 마일스톤: M040 (`v0.4`)
- 브랜치: `local/task433`
- 기준 브랜치: `devel`
- 목표: HOP과 알한글 Preview가 함께 설치된 환경에서 충돌 가능성과 검증된 버전 차이를 사실 기반으로 알리고, 사용자가 Quick Look 시스템 설정에서 알한글 미리보기를 선택할 수 있게 한다.

## 구현 원칙

- 공개 API와 읽을 수 있는 bundle metadata만 사용한다.
- `/usr/bin/pluginkit`, 비공개 PlugInKit API, 다른 앱의 binary string scan을 제품 런타임에 사용하지 않는다.
- 실제 선택된 preview provider나 경쟁 확장의 활성 상태를 확인했다고 표현하지 않는다.
- 알한글이 HOP보다 더 최신인 `rhwp`를 포함한 경우에만 비교 추천을 표시한다.
- 절대적인 “최신 `rhwp`”라는 표현을 사용하지 않는다.
- HOP app version, Preview extension version, `rhwp` version을 서로 다른 값으로 표시한다.
- 알려진 HOP Preview 버전과 검증된 `rhwp` 매핑만 사용하며 알 수 없는 버전은 `확인 불가`로 처리한다.
- 알한글이 경쟁 확장을 자동으로 끄거나 사용자 election 상태를 변경하지 않는다.
- 안내는 동일한 충돌 fingerprint에 대해 반복해서 자동 노출하지 않되 About 화면에서는 언제든 다시 확인할 수 있게 한다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 의존을 추가하지 않는다.
- `project.yml`을 Xcode project 원본으로 유지한다.

## 상태 모델

### 감지 결과

`QuickLookConflictSnapshot` 또는 동등한 값 타입이 다음 정보를 소유한다.

- HOP 설치 여부
- 선택한 HOP app bundle URL
- HOP app version
- HOP Preview bundle identifier
- HOP Preview version
- 매핑된 HOP `rhwp` version 또는 `unknown`
- 알한글 app/Preview version
- 알한글 `rhwp` release tag와 resolved commit
- 안내 수준
  - 충돌 없음
  - 중복 provider 가능성
  - 알한글의 더 최신 `rhwp` 사용 권장
- 자동 안내 중복 방지용 fingerprint

### 알려진 버전 매핑

초기 catalog는 다음 검증값을 포함한다.

| HOP Preview bundle ID | Preview version | 검증된 rhwp |
|---|---:|---:|
| `net.golbin.hop.quicklook.preview` | `0.2.0` | `v0.7.13` |

알한글 버전은 `RhwpProvenanceLoader`의 bundle manifest 결과를 사용한다. 버전 비교는 `v` prefix와 숫자 segment를 정규화한 뒤 수행하며, 파싱할 수 없는 값에서는 최신 여부를 단정하지 않는다.

### 자동 안내 정책

- HOP 미설치: 자동 안내 없음, About 충돌 카드 없음
- HOP 설치 + 알려진 Preview + 알한글이 더 최신: 자동 안내 대상
- HOP 설치 + 알려지지 않은 Preview: About에서 중복 provider 가능성과 `rhwp 확인 불가` 표시, 최신 비교 자동 안내는 생략
- HOP bundle은 찾았지만 Preview metadata 접근 불가: About에서 제한된 일반 안내만 표시
- `나중에`: 현재 fingerprint의 자동 안내만 숨김
- 알한글 또는 HOP app/Preview/`rhwp` version이 바뀌어 fingerprint가 달라지면 다시 평가

## Stage 1. HOP 감지와 rhwp 비교 정책 구현

### 목표

UI와 분리된 값 모델·catalog·감지 서비스를 만들고, 설치 없음·알려진 버전·알 수 없는 버전의 판단을 결정론적으로 검증한다.

### 작업

- `QuickLookConflictDetector`와 감지 결과 값 타입을 HostApp 서비스 영역에 추가한다.
- `NSWorkspace.shared.urlsForApplications(withBundleIdentifier: "net.golbin.hop")`로 HOP 후보를 조회한다.
- HOP app bundle metadata와 `Contents/PlugIns/HopQuickLookPreview.appex` metadata를 읽는다.
- HOP Preview bundle identifier가 `net.golbin.hop.quicklook.preview`인지 검증한다.
- 알려진 Preview version → `rhwp` version catalog를 별도 정책 타입으로 둔다.
- 기존 `RhwpProvenanceLoader` 결과를 비교 입력으로 사용한다.
- semantic version 비교, 안내 수준, fingerprint 생성을 UI와 분리한다.
- 감지 입력을 주입할 수 있게 구성해 실제 `/Applications` 설치 여부에 종속되지 않는 검증 경로를 만든다.
- 프로젝트 구조에 맞는 HostApp unit test target을 `project.yml`에 추가하고 정책 테스트를 작성한다.

### 검증 시나리오

- HOP 미설치 → `.none`
- HOP Preview `0.2.0` + `rhwp v0.7.13`, 알한글 `rhwp v0.7.18` → 알한글 권장
- HOP Preview 알 수 없는 버전 → 중복 provider 일반 안내, 최신 여부 미표시
- Preview bundle ID 불일치 또는 metadata 접근 실패 → 제한된 일반 안내
- 알한글 provenance 확인 불가 → 최신 여부 미표시
- 버전 순서가 같거나 HOP 쪽이 더 높은 synthetic case → 알한글 최신 주장 없음
- fingerprint가 app/Preview/`rhwp` version 변화에 따라 달라짐

### 완료 기준

- 감지와 비교 정책이 UI 없이 검증 가능하다.
- 알려진 버전 외에는 `rhwp`를 추정하지 않는다.
- 런타임 binary scan과 `pluginkit` 호출이 없다.
- Stage 1 테스트와 HostApp compile 검증이 통과한다.

### 검증

- `xcodegen generate`
- HostApp conflict policy unit test
- `xcodebuild` HostApp 또는 test target compile/test
- `rg -n 'pluginkit|PlugInKit|strings ' Sources/HostApp`
- `git diff --check`

### 커밋 메시지

- `Task #433 Stage 1: Quick Look 충돌 감지와 버전 비교 모델 추가`

## Stage 2. About 충돌 안내와 시스템 설정 진입 UI 구현

### 목표

기존 About 확장 상태 영역에서 충돌 가능성, 설치된 버전, 추천 이유와 해결 경로를 이해할 수 있게 한다.

### 작업

- `ExtensionStatusModel` 새로고침 흐름에 conflict snapshot을 연결한다.
- About 확장 섹션에 충돌 안내 카드 또는 인라인 배너를 추가한다.
- 알려진 비교 결과에서는 다음 항목을 구분해 표시한다.
  - 알한글 app/Preview version
  - 알한글 `rhwp` release tag와 short commit
  - HOP app/Preview version
  - 검증된 HOP `rhwp` version
- 사용자 문구를 다음 원칙으로 적용한다.
  - “알한글은 HOP Preview보다 최신인 `rhwp` 렌더러를 포함합니다.”
  - “HOP Quick Look Preview를 끄고 알한글 미리보기를 켜는 것을 권장합니다.”
  - 실제 활성 상태가 아닌 “충돌 가능성”이라고 설명한다.
- 알 수 없는 HOP version에서는 `rhwp 확인 불가`와 일반 중복 안내만 표시한다.
- `다시 확인`으로 extension registration refresh와 HOP metadata 감지를 함께 재실행한다.
- `Quick Look 설정 열기` 서비스를 추가한다.
  - macOS 13 이상에서는 로그인 항목 및 확장 프로그램 상위 화면 진입을 우선한다.
  - macOS 12에서는 Extensions preference pane 진입을 시도한다.
  - deep link 실패 시 System Settings/System Preferences 실행과 수동 경로 문구를 제공한다.
- VoiceOver label, 버튼 순서, 색상 외 상태 전달을 확인한다.

### 완료 기준

- HOP 미설치에서는 기존 About 화면만 보인다.
- 알려진 HOP 설치본에서는 네 가지 version 축과 추천 근거가 표시된다.
- 알 수 없는 version에서는 최신 여부를 주장하지 않는다.
- 설정 버튼과 다시 확인이 동작하며 다른 확장 상태를 변경하지 않는다.

### 검증

- HostApp build
- 알려진/알 수 없는/미설치 fixture를 사용한 About view 검증
- 현재 설치된 HOP `0.3.1` / Preview `0.2.0` 환경 수동 확인
- 시스템 설정 진입과 fallback 문구 확인
- `./scripts/check-no-appkit.sh`
- `git diff --check`

### 커밋 메시지

- `Task #433 Stage 2: About 충돌 안내와 설정 진입 UI 추가`

## Stage 3. 실행 시 안내와 나중에 정책 연결

### 목표

사용자가 About 화면을 찾아 들어가지 않아도 알려진 실질 충돌 가능성을 한 번 확인하고, 같은 환경에서 반복 안내를 받지 않도록 한다.

### 작업

- App launch 완료 후 conflict detector를 비동기로 실행하는 coordinator를 추가한다.
- 알려진 HOP Preview와 더 최신인 알한글 `rhwp` 조합에서만 자동 안내를 표시한다.
- 기존 `AboutWindowPresenter`를 재사용하거나 전용 SwiftUI notice presenter를 추가해 버전 비교 UI를 공유한다.
- `Quick Look 설정 열기` 선택 시 시스템 설정을 열고 현재 fingerprint를 확인한 것으로 기록한다.
- `나중에` 선택 시 현재 fingerprint의 자동 안내를 `UserDefaults`에 저장한다.
- About 메뉴로 직접 연 화면에서는 자동 안내 dismissal과 무관하게 충돌 정보를 계속 표시한다.
- app/Preview/`rhwp` version이 변하면 새 fingerprint로 다시 안내한다.
- 여러 문서 창이 열리거나 앱이 다시 활성화되어도 중복 notice window가 생기지 않게 한다.

### 완료 기준

- 알려진 비교 우위가 있는 충돌 환경에서 launch notice가 한 번 표시된다.
- `나중에` 이후 같은 fingerprint에서는 다시 자동 표시되지 않는다.
- version 변화 synthetic case에서는 다시 표시 대상이 된다.
- 알 수 없는 HOP version과 HOP 미설치 환경에서는 자동 notice가 없다.
- About 화면의 수동 확인 경로는 항상 유지된다.

### 검증

- launch notice policy unit test
- `UserDefaults` test suite 또는 격리된 suite name으로 fingerprint 저장 검증
- HostApp Debug 실행에서 단일 notice, 나중에, 재실행, About 수동 진입 확인
- 다중 문서 창과 앱 재활성화 시 중복 표시 여부 확인
- `git diff --check`

### 커밋 메시지

- `Task #433 Stage 3: 실행 시 충돌 안내와 재표시 정책 연결`

## Stage 4. 통합 빌드와 사용자 시나리오 검증

### 목표

HostApp 빌드, 정책 테스트, 샌드박스 실행, About/launch notice UI를 통합 검증하고 결과를 문서화한다.

### 작업

- 생성 프로젝트와 test target 정합성을 확인한다.
- HostApp Debug build와 policy tests를 실행한다.
- 현재 설치된 HOP과 알한글 metadata가 감지되는지 샌드박스 Debug 앱에서 확인한다.
- About에서 버전 비교와 추천 문구를 확인한다.
- 시스템 설정 진입 후 사용자가 변경해야 할 Quick Look 항목을 확인한다.
- 앱이 `pluginkit`, `qlmanage`, 다른 확장 election 변경을 실행하지 않는지 코드와 로그를 확인한다.
- HOP 미설치/알 수 없는 버전은 fixture 또는 주입된 resolver로 검증한다.
- 단계 완료보고서와 최종 결과보고서를 작성하고 오늘할일 상태를 갱신한다.

### 완료 기준

- 전체 정책 테스트와 HostApp build가 통과한다.
- `Sources/RhwpCoreBridge` 경계 검사가 통과한다.
- 실제 설치 환경에서 HOP `0.3.1`, Preview `0.2.0`, `rhwp v0.7.13`과 알한글 `rhwp v0.7.18`이 의도한 문구로 표시된다.
- 다른 확장을 자동 변경하지 않는다.
- 알려진 제한과 검증 결과가 단계·최종 보고서에 남는다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- HostApp conflict policy unit test
- `./scripts/check-no-appkit.sh`
- `rg -n 'pluginkit|PlugInKit|qlmanage|Process\\(' Sources/HostApp`
- `git diff --check`
- Debug HostApp 실행 후 About/launch notice 수동 시나리오 확인

### 커밋 메시지

- `Task #433 Stage 4 + 최종 보고서: 통합 검증과 충돌 안내 UX 확정`

## 단계 승인 게이트

- Stage 1 완료 후 감지·버전 비교 모델과 테스트 결과를 보고하고 Stage 2 승인을 요청한다.
- Stage 2 완료 후 About UI와 시스템 설정 진입 결과를 보고하고 Stage 3 승인을 요청한다.
- Stage 3 완료 후 launch notice와 dismissal 정책을 보고하고 Stage 4 승인을 요청한다.
- Stage 4 완료 후 최종 결과보고서와 PR 게시 승인을 별도로 요청한다.

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 구현 진행 승인을 요청한다.
