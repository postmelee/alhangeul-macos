# Task M040 #433 Stage 1 완료보고서

## 단계 목적

HOP과 알한글의 Quick Look Preview 중복 설치 가능성을 공개 API와 bundle metadata만으로 감지하고, 검증된 `rhwp` 버전 범위에서만 알한글 사용 권장 여부를 판단하는 UI 독립 모델을 구현한다.

## 구현 결과

### 감지 모델

`Sources/HostApp/Services/QuickLookConflictDetector.swift`에 다음 값과 서비스를 추가했다.

| 구성 | 역할 |
|------|------|
| `QuickLookBundleInfo` | app/extension bundle identifier, short version, build version 보관 |
| `HopQuickLookInstallation` | HOP app URL과 app/Preview metadata 보관 |
| `AlhangeulQuickLookInstallation` | 알한글 app/Preview metadata와 `RhwpProvenance` 보관 |
| `QuickLookConflictSnapshot` | 두 설치 정보, HOP `rhwp`, 안내 수준, fingerprint 보관 |
| `HopRhwpVersionCatalog` | 검증된 HOP Preview version과 `rhwp` release tag 매핑 |
| `QuickLookConflictPolicy` | semantic version 비교, 안내 수준, fingerprint 결정 |
| `QuickLookConflictDetector` | LaunchServices 후보 조회와 bundle metadata 수집 |

실제 감지는 다음 공개 경로만 사용한다.

- `NSWorkspace.shared.urlsForApplications(withBundleIdentifier: "net.golbin.hop")`
- HOP app bundle metadata
- `Contents/PlugIns/HopQuickLookPreview.appex` bundle metadata
- 알한글 app과 `AlhangeulPreview.appex` bundle metadata
- 기존 `RhwpProvenanceLoader`의 bundled manifest

HOP Preview bundle identifier가 `net.golbin.hop.quicklook.preview`인지 확인한 뒤, Preview `0.2.0`만 검증된 `rhwp v0.7.13`으로 매핑한다. 그 밖의 버전, metadata 누락, bundle identifier 불일치에서는 HOP `rhwp`를 추정하지 않는다.

### 비교 정책

안내 수준은 다음 기준으로 고정했다.

| 조건 | 결과 |
|------|------|
| HOP app 후보 없음 | `.none` |
| HOP 후보 존재, 비교 근거 부족 | `.overlappingProvider` |
| HOP `rhwp`와 알한글 `rhwp`가 모두 숫자 버전으로 확인되고 알한글 쪽이 더 높음 | `.preferAlhangeul` |
| 두 버전이 같거나 HOP 쪽이 더 높음 | `.overlappingProvider` |

버전 비교는 선행 `v` 또는 `V`를 제거하고 점으로 구분된 숫자 segment를 비교한다. suffix가 있거나 숫자로 해석할 수 없는 값에서는 최신 여부를 주장하지 않는다.

fingerprint에는 선택된 HOP app URL, 양쪽 app/Preview identifier·short version·build version, HOP 매핑 `rhwp`, 알한글 `rhwp` release tag·resolved commit을 길이 prefix 형식으로 포함했다. 같은 설치 상태에서는 안정적이고, 사용자에게 다시 안내할 근거가 되는 버전 또는 provenance가 바뀌면 값이 달라진다.

### 테스트 구조

`project.yml`에 비호스트 `HostAppTests` 단위 테스트 target을 추가했다. 이 target은 UI와 앱 수명주기 없이 실제 production 소스인 다음 두 파일을 직접 컴파일한다.

- `Sources/HostApp/Services/QuickLookConflictDetector.swift`
- `Sources/HostApp/Support/RhwpProvenance.swift`

감지 의존성은 application URL 조회, bundle metadata 읽기, 알한글 provenance 읽기 closure로 주입할 수 있다. 따라서 `/Applications`의 실제 설치 상태를 바꾸지 않고 모든 정책 분기를 검증한다.

초기 hosted test target은 source compile과 link까지 통과했으나 Xcode의 macOS GUI test worker가 LaunchServices launch 단계에서 생성되지 않아 중단됐다. 정책 테스트에는 HostApp 실행이 필요하지 않으므로 비호스트 target으로 분리했고, HostApp 통합 compile은 별도 Debug build로 검증했다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | `HostAppTests`와 production source membership 생성 확인 |
| `HostAppTests` | 통과 | 8개 테스트, 실패 0 |
| HostApp Debug build | 통과 | app, Preview, Thumbnail과 새 감지 소스 compile/link 성공 |
| `./scripts/check-no-appkit.sh` | 통과 | shared/CoreBridge 경계에 AppKit/UIKit 추가 없음 |
| 금지 런타임 경로 검색 | 통과 | 새 감지 소스에 `pluginkit`, `PlugInKit`, `qlmanage`, `Process(`, binary `strings` 사용 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

단위 테스트는 다음 시나리오를 포함한다.

1. HOP 미설치
2. HOP Preview `0.2.0` / `rhwp v0.7.13`과 알한글 `rhwp v0.7.18`
3. 알려지지 않은 HOP Preview version
4. HOP Preview bundle identifier 불일치
5. HOP Preview metadata 접근 실패
6. 알한글 provenance 확인 실패
7. synthetic `rhwp` 동률 또는 HOP 우위
8. Preview version 또는 알한글 provenance 변화에 따른 fingerprint 변경

## 개발 산출물 등록 정리

Xcode build가 `build.noindex`의 Debug app을 LaunchServices에 자동 등록해 표준 hygiene helper를 실행했다.

- `scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations`
- Task #433 전용 `DerivedDataTask433Stage1`과 `DerivedDataTask433Stage1Host` 삭제
- 최종 PlugInKit Preview provider: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`
- 최종 PlugInKit Thumbnail provider: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex`

설치본 provider는 정상적으로 하나만 남았지만 LaunchServices app 목록에는 삭제된 Task #433 경로 두 개와 기존 `build.noindex/DerivedData` 경로 하나가 stale record로 계속 출력됐다. 파일과 PlugInKit provider는 남아 있지 않으며, 전역 LaunchServices reset은 수행하지 않았다.

## 남은 위험과 다음 단계 경계

- 공개 API로 HOP Preview의 실제 활성 상태나 현재 선택된 Quick Look provider는 판정할 수 없다. Stage 2 UI는 “충돌”이 아니라 “충돌 가능성”으로 표현해야 한다.
- HOP app은 발견되지만 Preview metadata를 읽지 못하는 경우 실제 extension 유무를 단정하지 않고 제한된 일반 안내만 제공한다.
- HOP Preview `0.2.0` 이외의 `rhwp` 버전은 계속 `확인 불가`로 표시해야 한다.
- Stage 1에는 About UI, 시스템 설정 진입, 실행 시 자동 안내, dismissal 저장이 포함되지 않았다.
- 다음 Xcode build 뒤에도 개발 산출물 registration hygiene를 다시 확인해야 한다.

## 승인 요청

Stage 1의 감지·버전 비교 모델과 단위 검증 결과를 승인하고, Stage 2 `About 충돌 안내와 시스템 설정 진입 UI 구현` 진입을 요청한다.
