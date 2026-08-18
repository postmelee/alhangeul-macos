# Task #480 Stage 1 완료보고서

## 단계 목적

v0.1.10 release artifact와 exact bundled `rhwp-studio`를 기준으로 암호 보호 HWP3, HWP5, HWPX의 native 저장 결과를 재현한다. 그 결과를 바탕으로 즉시 적용할 평문 덮어쓰기 차단 기준, HWP3 출력 정책, native 암호 저장에 필요한 upstream host API 계약을 소스 변경 전에 확정한다.

## 산출물

- v0.1.10 release app에서 세 암호 문서 계열의 `Command+S` 저장 결과 실증
- release app과 bundled Studio/WASM의 provenance 및 asset hash 일치 확인
- exact pinned `rhwp v0.8.4` parser·serializer·embed RPC 경계 조사
- typed source protection probe의 로컬 구현 가능성 확인
- HWP3 암호 입력의 HWP5 EncryptVersion 4 변환 정책 확정
- Stage 2의 보수적 write 차단 계약과 Stage 3의 upstream 선행 계약 확정
- 수행계획서와 구현계획서의 유효하지 않은 `swift test` 명령을 실제 `HostAppTests`용 `xcodebuild` 명령으로 보정
- 테스트 실행으로 생긴 release app LaunchServices 개발 등록 해제

제품 소스와 bundled upstream asset은 이번 단계에서 변경하지 않았다. 재현 파일, 빌드 결과와 테스트 로그는 `build.noindex/` 아래에만 두고 커밋하지 않는다.

## exact 기준과 provenance

| 항목 | 확인 결과 |
|------|-----------|
| release app | `build.noindex/release/Alhangeul.app` |
| app version | `0.1.10` (`CFBundleVersion` 16) |
| pinned core | `rhwp v0.8.4` |
| resolved commit | `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| bundled manifest | 저장소 manifest와 SHA-256 일치 |
| bundled JS/WASM | manifest에 기록된 SHA-256과 일치 |

`scripts/verify-rhwp-studio-assets.sh`도 같은 bundle의 무결성을 통과했다. exact upstream checkout의 parser, WASM API, embed RPC와 암호 fixture 관련 파일은 모두 pinned commit의 blob hash와 일치했다. checkout 자체에 기존 index 이상 상태가 있어 정리하거나 수정하지 않고 read-only로 조사했다.

## release app 재현 결과

upstream 공개 암호 fixture의 일회성 복사본만 `build.noindex/task480-stage1-reproduction/` 아래에 만들었다. 각 문서를 release app에서 열고 바로 `Command+S`한 뒤 SHA-256과 무암호 재열기 결과를 비교했다. fixture 암호는 명령행, 로그와 이 보고서에 기록하지 않았다.

| 입력 | 저장 전 SHA-256 | 저장 후 SHA-256 | 무암호 재열기 | 판정 |
|------|-----------------|-----------------|----------------|------|
| HWP3 암호 문서 | `db743d084efc9e08e839a5b4d978b16b8676434011776e090e4cda43e57304be` | `b5336f3d2c7072288aa5d149864545e6f140b76f3fc17d56c0866171d05ef676` | 성공, 암호화 아님 | 평문화와 HWP5 변환 |
| HWP5 암호 문서 | `59d4bed335b9552fe78fa68d2a56f7cfa3d586bcdeaaba839af80df13f3e08dc` | `af8fc7bedfe621b6836740d65cd3197b89bc1dfb1a5b5074bab256ca7c6174eb` | 성공, 암호화 아님 | 평문화 |
| HWPX 암호 문서 | `93e7a62565e0f3efa4feee2812aaf518347dbbcc09d2f26a0d9385f9a4e26060` | `948de6b69a46f624dbb4e74a4d437ec49909c37aa693e646e755fe0dd8b1b4c4` | 성공, 암호화 아님 | 평문화 |

HWP3 원본은 `HWP Document Fil` 계열 signature였지만 저장 결과는 CFB signature로 바뀌었다. 저장 결과의 문서 버전도 HWP5로 판정되므로 현행 native 저장은 HWP3 원형을 보존하지 않는다.

따라서 세 입력 계열 모두 `Command+S`가 암호 보호를 제거한 다른 byte를 원본 URL에 경고 없이 쓴다. 이 문제는 serializer 가능성만으로 추정한 것이 아니라 실제 배포 artifact에서 재현됐다.

## 현재 Save As·취소·오류 경계

- upstream Studio 자체의 명시적 `다른 이름으로 저장`은 HWP/HWPX에서 암호 설정 UI와 password exporter를 제공한다.
- Alhangeul의 native save interception은 이 UI를 거치지 않고 production embed RPC의 `exportHwp` 또는 `exportHwpx`를 호출한다.
- production embed RPC에는 `exportHwpWithPassword`, `exportHwpxWithPassword`와 source protection state가 노출되지 않는다. 따라서 native `다른 이름으로 저장`도 현재 계약으로는 보호된 결과를 만들 수 없다.
- save panel 취소는 export 요청과 write 전에 반환한다.
- export 오류는 pending request를 제거하고 write를 실행하지 않는다.
- payload 검증 오류와 atomic write 오류도 성공 처리나 saved-state 통지를 실행하지 않는다.

취소와 export 오류의 원본 보존은 이 write-before/after 경계를 기준으로 확인했다. Stage 2에서는 보호 입력의 차단을 반드시 export 전으로 옮기고, fixture hash 회귀 테스트로 이 조건을 직접 고정한다.

## source protection 판정 계약

exact pinned core는 public `rhwp::parser::ParseError::EncryptedDocument`와 public `parse_document`/`parse_document_with_password`를 제공한다. 따라서 제품 코드가 오류 문자열이나 DOM 상태를 해석하지 않고 RustBridge에서 typed protection probe를 제공할 수 있다.

Stage 2 분류는 다음으로 확정한다.

| 분류 | 판정과 저장 정책 |
|------|------------------|
| `plain` | parse 성공. 현행 payload 검증 뒤 in-place write 허용 |
| `passwordProtected` | `ParseError::EncryptedDocument`. 보호된 export가 없으면 in-place write 금지 |
| `unsupportedProtection` | typed하게 식별되는 미지원 DRM/보호. in-place write 금지 |
| `invalidOrUnknown` | 손상, 빈 입력, 판정 실패나 알 수 없는 status. 보수적으로 in-place write 금지 |

bridge는 암호 문자열과 raw parser 오류를 반환하지 않는다. 기존 `rhwp_open` ABI도 변경하지 않고 별도 status probe로 추가한다. `Sources/RhwpCoreBridge`는 Foundation-only 경계를 유지한다.

## HWP3 출력 정책

upstream의 `exportHwpWithPassword`는 HWP5 EncryptVersion 4를 출력한다. HWP3 암호 입력을 그대로 HWP3로 다시 저장하는 exporter는 현재 없다.

따라서 HWP3 암호 문서는 다음 정책을 적용한다.

1. 원본 위치에는 평문과 HWP5 변환 결과 모두 쓰지 않는다.
2. 보호 저장을 지원하게 되더라도 HWP5 변환을 명시한 `다른 이름으로 저장`만 허용한다.
3. 사용자에게 형식 변환과 원본 비보존을 저장 전에 알린다.
4. HWP3 보존 exporter가 제공되기 전에는 이를 HWP3 암호 저장 지원으로 표시하지 않는다.

## upstream 선행 계약 제안

Stage 3 native 암호 저장은 bundled minified JavaScript를 패치하거나 별도 WASM 문서를 재구성하지 않는다. 동일한 편집 session의 IR을 사용하는 upstream 정식 RPC가 stable release tag에 포함된 경우에만 연결한다.

필요한 최소 계약은 다음과 같다.

- `password-save-v1`과 같은 명시적 capability
- format과 일회성 password를 입력받아 한 transaction에서 export하는 typed RPC
- transferable bytes와 format, protection, byte count, content-loss metadata 반환
- 암호 문자열 없이 source protection/save-required state 제공
- password-open 성공 뒤 Studio의 `requiresPasswordForSave`가 `true`로 유지되는 상태 계약
- 암호를 전역 상태, DOM, URL, console, 응답과 오류 문자열에 보관하거나 반향하지 않는 수명 규칙
- release tag와 resolved commit으로 검증 가능한 배포 provenance

현재 Studio는 password-open 이후에도 `loadDocumentAtomically`에서 `_requiresPasswordForSave`를 `false`로 초기화한다. upstream도 암호로 연 문서의 다음 저장에 보호를 요구하는 상태를 유지하지 못하므로 RPC 추가와 함께 수정이 필요하다.

평문 export를 로컬에서 다시 parse한 뒤 암호화하는 2차 serializer 방식은 동일 편집 transaction의 reported export를 잃고 이중 직렬화에 따른 content loss 위험을 추가하므로 채택하지 않는다. 외부 upstream 이슈나 PR은 별도 승인 전까지 만들지 않는다.

## 본문 변경 정도와 무손실 확인

- 제품 소스: 변경 없음
- bundled `rhwp-studio` asset: 변경 없음
- Xcode project와 dependency pin: 변경 없음
- 계획서: 실제 repository 검증 방식에 맞춰 `swift test`를 `HostAppTests` scheme의 `xcodebuild test`로 보정
- 조사 문서: 이 Stage 1 완료보고서 신규 작성
- 오늘할일: Stage 1 완료와 Stage 2 승인 대기로 상태 갱신
- 재현용 fixture 복사본과 산출물: `build.noindex/`에만 존재하며 commit 대상 아님

원본 fixture와 release artifact를 수정하지 않았고 테스트용 복사본만 사용했다. UI smoke 종료 뒤 `build.noindex/release/Alhangeul.app`과 포함 extension의 LaunchServices 등록을 해제했으며 설치된 `/Applications/Alhangeul.app`은 건드리지 않았다.

## 검증 결과

### 구현계획서 Stage 1 필수 검증

| 명령 | 결과 |
|------|------|
| `rg -n "exportHwpWithPassword\|exportHwpxWithPassword\|exportHwp\|exportHwpx" Sources/HostApp/Resources/rhwp-studio Sources/HostApp` | 통과. WASM wrapper에는 password exporter가 있지만 production host bridge/embed RPC에는 plain exporter만 연결된 상태를 확인했다. |
| `scripts/verify-rhwp-studio-assets.sh` | 통과. `OK: rhwp-studio assets verified` |
| `git diff --check` | 통과. whitespace 오류 없음 |

### 보조 회귀 검증

| 검증 | 결과 |
|------|------|
| exact upstream HWP3/HWP5/HWPX 암호 fixture와 password write contract | 19개 테스트 통과, 실패 0 |
| `HostAppTests` (`xcodebuild`, Debug, code signing 비활성화) | 128개 테스트 통과, 실패 0 |
| v0.1.10 release app UI smoke | HWP3/HWP5/HWPX 열기 성공 및 `Command+S` 평문화 재현 |

`HostAppTests` 최초 sandbox 실행은 Sparkle dependency의 GitHub DNS 접근이 차단되어 실패했지만, 같은 명령을 허용된 외부 실행으로 재시도해 전체 통과했다. 제품 테스트 실패는 없었다.

## 잔여 위험

- Stage 2 typed probe가 core parser status를 잘못 축약하면 손상 문서를 plain으로 오분류할 수 있다. unknown 값과 parse 실패를 반드시 `invalidOrUnknown`으로 fail-closed 처리해야 한다.
- source document 교체, reload와 WebView 재생성 때 이전 보호 상태가 누수되지 않도록 document revision에 상태를 결합해야 한다.
- Stage 2의 명시적 평문 복사본 정책은 destination이 원본과 다른지 canonical URL 기준으로 확인해야 한다.
- HWP3의 암호 저장은 현재 HWP5 변환일 뿐 원형 보존이 아니다.
- upstream stable password-save RPC가 없으므로 Stage 2 뒤에는 안전 차단만 독립적으로 merge할 수 있고 native 암호 저장은 완료할 수 없다.
- HWP3 smoke 종료 시 저장 직후에도 unsaved-changes 경고가 한 차례 관찰됐다. 재현 타이밍 또는 post-load state일 수 있어 이번 안전 차단 범위의 blocker로 보지 않으며, 반복 확인이 필요하면 별도 승인 아래 분리한다.

## 다음 단계 영향

Stage 2에서는 exact pinned parser enum을 C ABI status로 변환하고 Swift Foundation enum으로 연결한다. `passwordProtected`, `unsupportedProtection`, `invalidOrUnknown`은 export 전에 원본 URL plain write를 차단하고, 평문 복사본은 별도 destination과 보호 해제 경고를 거친 경우에만 허용한다.

Stage 2는 upstream 변경 없이 수행할 수 있으며 현 배포의 데이터 보호 회귀를 즉시 차단한다. Stage 3은 upstream stable release tag, source protection state와 단일 transaction password-export RPC가 준비되고 sync 범위를 다시 승인받은 뒤에만 시작한다.

## 승인 요청

Stage 1 exact 재현과 저장 보호 계약 확정을 완료했다. Stage 2 `native 보호 상태와 안전 차단` 구현 진행 승인을 요청한다.
