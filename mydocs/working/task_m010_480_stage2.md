# Task #480 Stage 2 완료보고서

## 단계 목적

upstream의 native 암호 export API 제공 여부와 무관하게 암호 보호 또는 보호 상태 판정 불능 문서가 평문으로 원본 URL에 덮어써지는 경로를 차단한다. source protection을 typed 상태로 판정하고 document revision과 결합하며, 보호를 해제한 평문 복사본은 경고와 별도 destination을 거친 경우에만 허용한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `RustBridge/src/lib.rs` | `RhwpDocumentProtectionStatus`와 `rhwp_document_protection` C ABI, plain/password/DRM/invalid 회귀 테스트 추가 |
| `Sources/RhwpCoreBridge/RhwpDocumentProtection.swift` | Foundation-only 보호 상태 enum과 unknown fail-closed mapping 추가 |
| `rhwp-ffi-symbols.txt`, `rhwp-core.lock` | 신규 symbol과 공식 universal staticlib/header artifact metadata 고정 |
| `Sources/HostApp/Services/DocumentSaveContract.swift` | source protection, output intent, revision 및 destination 검증 정책 추가 |
| `Sources/HostApp/Services/DocumentProtectionSaveAlert.swift` | 보호 해제 및 HWP3 변환 경고 UI 추가 |
| `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift` | document revision에 source protection을 결합하고 HWP3 입력 여부 판정 추가 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | 문서 load마다 보호 상태를 새로 판정하고 성공한 저장 결과로 payload 상태 갱신 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | 보호 입력의 in-place export/write 사전 차단, 경고·별도 저장, 저장 전후 context 재검증 추가 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | 저장된 data와 protection을 store에 전달하도록 callback 확장 |
| `Tests/HostAppTests/DocumentSaveContractTests.swift` | in-place 허용 범위, 보호 의도, 동일 destination 및 revision/protection 변경 회귀 테스트 추가 |
| `Tests/ExternalImageTests/RhwpDocumentProtectionTests.swift` | Swift raw status mapping, plain/invalid/DRM 분류 테스트 추가 |
| `project.yml`, `Alhangeul.xcodeproj/project.pbxproj` | 신규 bridge/test source 포함 및 XcodeGen 재생성 |
| `RustBridge/README.md`, `mydocs/tech/project_architecture.md` | 보호 상태 ABI, ownership, fail-closed 및 native 저장 경계 문서화 |
| `mydocs/orders/20260818.md` | Stage 2 완료와 후속 분기 승인 대기로 상태 갱신 |

`Frameworks/generated_rhwp.h`, `Frameworks/generated_rhwp_symbols.txt`, universal staticlib과 `Rhwp.xcframework`는 공식 build script로 재생성해 검증에 사용했다. 저장소 정책에 따라 generated framework 산출물 자체는 commit 대상에 포함하지 않고, 추적 파일인 `rhwp-core.lock`에 hash와 size만 고정했다.

## 보호 상태와 ABI 계약

신규 C ABI는 caller-owned 입력 buffer를 현재 호출 동안만 빌려 다음 네 상태 중 하나를 반환한다.

| C ABI 상태 | Swift/Host 상태 | 저장 정책 |
|------------|-----------------|-----------|
| `PLAIN` | `plain` | payload 검증 뒤 same-format in-place 저장 허용 |
| `PASSWORD_PROTECTED` | `passwordProtected` | 원본 in-place export/write 금지, 명시적 평문 복사본만 허용 |
| `UNSUPPORTED` | `unsupportedProtection` | 원본 in-place export/write 금지, 경고 뒤 평문 복사본만 허용 |
| `INVALID_OR_UNKNOWN` | `invalidOrUnknown` | fail-closed로 원본 in-place export/write 금지 |

null pointer, zero length, parse failure, panic과 Swift의 알 수 없는 raw value는 모두 `invalidOrUnknown`으로 축약한다. raw parser 오류, 암호 문자열, document handle과 별도 소유 buffer는 반환하지 않는다. 기존 `rhwp_open` ABI와 동작은 변경하지 않았다.

`Sources/RhwpCoreBridge`에는 Foundation과 generated `Rhwp` module 의존만 추가했으며 AppKit/UIKit 의존은 없다.

## native 저장 차단 경계

문서를 load할 때 input signature 검증 뒤 protection probe를 실행하고 결과를 현재 document revision에 결합한다. 새 문서 load는 protection을 항상 다시 계산하며, load 실패 시 이전 payload를 성공 상태로 재사용하지 않는다.

저장 요청은 다음 순서를 따른다.

1. 요청 시점의 document revision, source protection, source URL과 output intent를 snapshot한다.
2. `plain`이고 요청 format이 source format과 같은 경우에만 원본 in-place 저장을 허용한다.
3. 그 외 보호 상태는 exporter 호출 전에 평문 복사본 경고와 save panel로 전환한다.
4. source와 destination을 표준화하고 symlink를 해소한 뒤 case-insensitive 경로 비교로 동일 destination을 거부한다.
5. 경고 또는 save panel 취소, document/protection 변경은 exporter와 write 전에 반환한다.
6. exporter 응답을 받은 뒤에도 revision, protection, destination, format, byte count와 signature를 다시 검증한다.
7. 성공한 write 뒤에만 saved-state를 동기화하고 current payload를 저장된 data와 `plain` protection으로 갱신한다.

따라서 암호 보호, 미지원 보호와 판정 불능 입력은 평문 응답을 원본 URL에 쓸 수 없다. 평문 복사본 취소·정책 거부·export 오류·payload 검증 오류에서는 원본 write와 clean 동기화를 실행하지 않는다.

HWP3 보호 입력은 원형을 보존할 수 없으므로 경고문에 선택한 HWP/HWPX 형식으로 변환된다는 내용을 별도로 표시한다.

## 본문 변경 정도와 무손실 확인

- bundled `rhwp-studio` JavaScript/WASM asset: 변경 없음
- upstream core pin: `v0.8.4`, resolved commit `496333b27d21ddb9114ba9ae340bcb895870c9a7` 유지
- 기존 plain HWP/HWPX exporter와 payload validation: 동작 유지
- protected source 원본: exporter와 write 이전 정책 차단으로 변경하지 않음
- 명시적 평문 복사본: 성공한 별도 destination만 current source로 전환
- fixture와 암호: 제품 상태, URL, 로그, analytics, 보고서에 저장하지 않음
- Xcode project: `project.yml`만 수정하고 `xcodegen generate` 결과를 반영

이 단계는 문서 본문 serializer나 upstream asset을 수정하지 않는다. content fidelity를 바꾸는 새 변환은 추가하지 않았으며, 기존 plain export 결과에 보호 상태와 write destination 검증을 덧붙였다.

## 검증 결과

### 구현계획서 Stage 2 필수 검증

| 명령 | 결과 |
|------|------|
| `cargo test --manifest-path RustBridge/Cargo.toml --locked` | 통과. 9개 테스트, 실패 0 |
| `./scripts/build-rust-macos.sh --update-lock` | 통과. arm64/x86_64 universal staticlib, header, symbol, XCFramework 재생성 및 lock 갱신 |
| `./scripts/build-rust-macos.sh --verify-lock` | 통과. artifact hash/size와 lock 일치 |
| `comm -3 <(sort rhwp-ffi-symbols.txt) <(sort Frameworks/generated_rhwp_symbols.txt)` | 통과. 차이 없음 |
| `./scripts/verify-rhwp-core-build-info.sh` | 통과. Swift build info와 lock 일치 |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code의 AppKit/UIKit 의존 없음 |
| `xcodegen generate` | 통과. `Alhangeul.xcodeproj` 재생성 |
| `HostAppTests` Debug test | 통과. 133개 테스트, 실패 0, `TEST SUCCEEDED` |
| `HostApp` Debug build | 통과. app과 두 extension 전체 `BUILD SUCCEEDED` |
| `git diff --check` | 통과. whitespace 오류 없음 |

### 보완 검증

| 검증 | 결과 |
|------|------|
| `cargo fmt --manifest-path RustBridge/Cargo.toml --check` | 통과 |
| `ExternalImageTests` Debug test | 통과. 30개 테스트, 실패 0, 신규 protection bridge 3개 테스트 포함 |
| 보호 문자열 점검 | 테스트 전용 byte-array 상수 외 암호 값, password 보관 상태와 로그 경로 없음 |
| LaunchServices 잔여 레코드 점검 | `build.noindex/task480-stage2-derived-data/` 아래 개발 앱 경로 없음 |

구현 중 첫 HostApp 전체 빌드는 optional binding 뒤의 불필요한 optional chaining 3건을 발견해 보정했다. 첫 ExternalImageTests 컴파일은 test assertion의 누락된 `try` 1건을 발견해 보정했다. 두 항목 모두 최종 명령을 다시 실행해 전체 통과했다. 초기 Rust dependency 확인에서 sandbox DNS 제한이 한 차례 있었으나 허용된 환경에서 공식 build를 완료했고 이후 동일 lock 검증도 통과했다. 제품 동작 실패로 남은 검증 항목은 없다.

Xcode는 기존 `RhwpStudioPagePDFRenderer`의 Swift 6 actor-isolation 경고와 test deployment target 관련 linker 경고를 출력한다. 이번 변경에서 발생한 오류는 아니며 현재 Swift 5 mode의 Stage 2 blocker로 판단하지 않았다.

## 잔여 위험

- 현 bundled production host RPC에는 password exporter와 source protection state가 없으므로 native 암호 저장 자체는 아직 구현되지 않았다. 이번 단계는 데이터 손실을 막는 안전 차단이다.
- 평문 복사본은 보호를 제거한다. 경고와 별도 destination을 강제하지만 사용자가 보호된 결과로 오인하지 않도록 향후 README와 release note에도 제한을 명시해야 한다.
- HWP3는 보호된 HWP3로 재저장할 수 없으며 HWP/HWPX 선택 형식으로 변환된다.
- protection probe의 typed 분류는 pinned core parser 계약에 의존한다. 새 parser status와 알 수 없는 raw value는 계속 fail-closed로 다뤄야 한다.
- actual password export round-trip, 무암호·오답 거부와 정답 성공 검증은 upstream stable API가 준비된 뒤 Stage 3/4에서 수행해야 한다.
- protected fixture를 사용한 최종 app UI smoke와 dirty/clean 상호작용의 재확인은 Stage 4 회귀 검증에 남는다. 현재 차단 경계는 exporter 호출 전 정책과 자동 테스트로 고정했다.

## 다음 단계 영향

Stage 2 안전 차단은 upstream 변경 없이 독립적으로 merge 가능한 상태다. 현재 Stage 3 진입 조건인 stable release tag의 password-save capability, source protection state와 동일 편집 transaction의 password exporter가 충족되지 않았다. 따라서 Stage 3을 바로 시작하거나 bundled minified asset, private hook, unreleased commit pin으로 우회하지 않는다.

권장 분기는 Stage 2 안전 차단을 먼저 `devel` 대상 PR로 게시하되 #480은 닫지 않고, upstream 정식 API 작업을 별도 추적한 뒤 release tag와 sync 범위를 다시 승인받는 것이다.

## 승인 요청

Stage 2 `native 보호 상태와 안전 차단` 구현과 검증을 완료했다. Stage 2 안전 차단 PR을 독립 게시하고 #480을 열린 상태로 유지할지 검토와 승인을 요청한다. Stage 3은 upstream stable 선행 조건이 확인되고 작업지시자가 별도로 승인할 때까지 시작하지 않는다.
