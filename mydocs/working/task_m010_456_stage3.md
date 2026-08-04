# Task #456 Stage 3 완료보고서

## 단계 목적

알한글 native 저장 메뉴와 패널에서 결정한 HWP/HWPX 형식을 exporter, bridge response 검증, atomic write, current source 갱신과 후속 `Command+S`까지 하나의 값으로 연결한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/HostApp/Services/DocumentSaveContract.swift` | 저장 command별 format 결정과 response format·base64·byte count·signature·destination 검증 계약 107줄 신규 작성 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | 형식별 native command interception, HWP/HWPX exporter, response format, `notifySaved` 동기화 bridge 추가 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | destination+format pending state, 형식별 panel/export/write, current source 전환과 저장 상태 동기화 연결 |
| `Tests/HostAppTests/DocumentSaveContractTests.swift` | command format 유지와 write 전 response 거부 조건 단위 테스트 11개 신규 작성 |
| `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift` | 명시적 저장 command, `exportHwpx`, response format과 `notifySaved` bridge 계약 테스트 3개 신규 작성 |
| `project.yml` | HostAppTests source에 신규 계약과 bridge script 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 위 source 구성을 재생성 |

## 구현 결과

### 메뉴에서 exporter까지의 format 연결

- `file:save-as-hwp`와 `file:save-as-hwpx`를 native/non-mutating command set에 추가해 upstream handler보다 capture 단계에서 알한글이 처리한다.
- 일반 `file:save`와 `file:save-as`는 current source URL, 현재 filename, HWP 기본값 순으로 format을 정한다.
- 명시적 저장 command는 source format과 관계없이 각각 HWP 또는 HWPX를 선택한다.
- HWP는 기존 `exportHwpBase64` fast path와 `exportHwp` fallback을 유지한다.
- HWPX는 bundled upstream의 `requestRhwp("exportHwpx")` 결과를 기존 chunked base64 encoder로 변환한다.
- 저장 응답은 `format`, 정규화한 `fileName`, `base64`, `byteCount`를 함께 전달한다.

### write 전 저장 계약 검증

`PendingSaveRequest`가 destination과 format을 함께 보관한다. Swift coordinator는 다음 조건을 모두 만족한 뒤에만 atomic write를 수행한다.

1. pending request가 존재한다.
2. response format을 지원 형식으로 decode한다.
3. response와 요청 format이 일치한다.
4. base64와 byte count가 유효하다.
5. payload가 HWP CFB 또는 HWPX ZIP signature와 일치한다.
6. destination 확장자가 요청 format과 일치한다.

검증 실패 시 파일, current source, recent document와 clean state를 변경하지 않는다. source write가 실패하면 동일 format의 native save panel로만 fallback한다.

### HWPX 저장 뒤 `Command+S`

- 저장 성공 직후 `currentSourceDocument`를 실제 저장 URL로 갱신한다.
- 따라서 HWP 파일을 `HWPX 형식으로 저장`한 뒤 current source가 `.hwpx`가 되고, 다음 일반 `Command+S`는 source URL에서 HWPX를 다시 결정해 `exportHwpx`를 사용한다.
- 반대 방향인 HWPX → HWP 저장도 같은 규칙으로 후속 `Command+S`가 `exportHwpBase64`/`exportHwp` 경로를 유지한다.
- 이 우선순위는 stale HWP filename보다 `.hwpx` source URL이 우선하는 계약 테스트로 고정했다.

### 저장 성공과 editor 상태 동기화

- durable write와 HostApp current source 갱신이 성공한 뒤 bundled upstream의 `notifySaved(fileName)` RPC를 호출한다.
- RPC 성공 시 upstream dirty/recovery 상태와 filename을 갱신하고 저장 완료 상태를 표시한다.
- RPC 실패는 별도 `save-sync-error`로 알리며 이미 저장된 파일과 HostApp source 갱신은 유지한다.
- 기존 HWP share, print와 PDF command routing은 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- HWP/HWPX parser, renderer와 document body 변환 로직: 변경 없음
- bundled `rhwp-studio` asset: 변경 없음
- `Sources/RhwpCoreBridge`: 변경 없음
- 저장 bytes: upstream exporter 결과를 base64 decode한 뒤 format/signature를 검사하고 atomic write하며, 별도 본문 재작성 없음
- share, print와 기존 PDF 경로: 변경 없음
- Xcode project: `project.yml`을 원본으로 `xcodegen generate`한 source reference만 변경

따라서 이번 단계는 exporter 선택과 저장 경계만 연결하며 문서 본문을 중간 형식으로 변환하거나 재구성하지 않는다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `xcodegen generate` | 통과. `Alhangeul.xcodeproj`를 `project.yml`에서 재생성했다. |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task456/stage3-tests CODE_SIGNING_ALLOWED=NO test` | 통과. 전체 100개, 실패 0개. 신규 `DocumentSaveContractTests` 11개와 `RhwpStudioHostBridgeScriptTests` 3개가 모두 통과했다. |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task456/stage3-build CODE_SIGNING_ALLOWED=NO build` | 통과. `** BUILD SUCCEEDED **`. |
| bridge Swift 문자열 추출 후 `node --check` | 통과. 실제 주입될 JavaScript의 구문이 유효하다. |
| `rg -n "file:save-as-hwp|file:save-as-hwpx|exportHwpx|notifySaved|PendingSaveRequest|DocumentSaveFormat" Sources Tests project.yml` | 통과. command, exporter, pending contract와 테스트 연결을 확인했다. |
| `scripts/verify-rhwp-studio-assets.sh build.noindex/task456/stage3-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio` | 통과. 빌드 앱의 bundled upstream 자산이 기준과 일치한다. |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code에 AppKit/UIKit 의존이 없다. |
| `git diff --check` | 통과. whitespace 오류가 없다. |

중간 검증에서 Swift multiline string의 JavaScript 정규식 escape가 부족해 첫 compile이 실패했다. source에 `\\.`를 사용해 실제 JavaScript가 `\.`를 받도록 수정한 뒤 전체 테스트와 빌드를 다시 실행해 위 최종 결과로 통과했다. 최종 재검증의 첫 sandbox 시도는 Xcode/SwiftPM cache 접근 권한 때문에 package resolution 전에 종료됐으며, 같은 명령을 허용된 환경에서 실행해 100개 테스트가 모두 통과했다.

## 잔여 위험

- 단위 테스트는 format 선택과 write 전 계약을 검증하지만 실제 메뉴 클릭, `NSSavePanel`, WKWebView RPC 왕복은 Stage 4 UI smoke에서 확인해야 한다.
- runtime HWPX guard는 ZIP magic까지만 검사한다. `mimetype`, `Contents/` entry와 재열기 결과는 Stage 4에서 검증한다.
- 대용량 HWPX는 chunked base64 encoder로 JavaScript call-stack 위험을 줄였지만 JS/Swift 양쪽에 전체 payload를 보유하는 메모리 비용은 남는다.
- `notifySaved`는 durable write 뒤 비동기 호출이므로 실패 시 파일은 저장됐지만 upstream dirty/recovery 상태가 남을 수 있다. 이 경우 사용자에게 동기화 오류를 표시한다.

## 다음 단계 영향

Stage 4에서는 실제 HWP/HWPX 샘플을 원본과 분리한 임시 경로에서 다음 시나리오로 검증한다.

- 같은 format 제자리 저장
- 반대 format으로 다른 이름 저장
- HWPX 저장 뒤 추가 편집과 `Command+S` 재저장
- output 확장자, CFB/ZIP magic, HWPX container entry, 파일 크기와 수정 시각
- 저장 output 재열기, page count, 대표 텍스트·표·이미지와 non-blank render

## 승인 요청

Stage 3 `형식별 export와 제자리 재저장 연결` 구현과 검증을 완료했다. Stage 4 `HWP/HWPX 저장·재열기 통합 검증` 진행 승인을 요청한다.
