# Task #456 Stage 1 완료보고서

## 단계 목적

`file:save`, `file:save-as`, `file:save-as-hwp`, `file:save-as-hwpx`의 현재 HostApp 경계와 bundled `rhwp-studio` RPC capability를 조사하고, HWP/HWPX 저장에 사용할 format 결정·검증·상태 동기화 계약을 소스 변경 전에 확정한다.

## 산출물

- 현재 native command interception, exporter, save panel, pending state와 제자리 저장 조건 조사
- bundled `rhwp-studio`의 `exportHwp`, `exportHwpx`, `notifySaved` RPC 제공 여부 확인
- 네 저장 command의 format·destination·후속 `Command+S` 동작 matrix 확정
- `DocumentSaveFormat`, `PendingSaveRequest`, save response 검증 경계 확정
- Stage 2 모델·패널·테스트 및 Stage 3 bridge·coordinator 변경 범위 확정

제품 소스와 bundled upstream asset은 이번 단계에서 변경하지 않았다. 조사 결과가 구현 계획과 일치해 `mydocs/plans/task_m010_456_impl.md`의 보정도 필요하지 않았다.

## 현재 저장 경계 조사 결과

### HostApp native command와 exporter

- `RhwpStudioHostBridgeScript.nativeCommands`는 `file:save`와 `file:save-as`만 포함하고, upstream 메뉴가 발생시키는 `file:save-as-hwp`와 `file:save-as-hwpx`는 포함하지 않는다.
- bridge의 `requestHwpExportPayload()`와 `exportHwpDocument()`는 `exportHwpBase64` 또는 `exportHwp`만 호출한다. 응답에도 format 식별자가 없다.
- `RhwpStudioWebView.Coordinator`는 destination만 `pendingSaveDestination`에 저장하므로 요청 exporter와 응답 payload format을 대조할 수 없다.
- `DocumentSavePanel`은 HWP UTType, `HWP 문서 저장`, `.hwp` filename에 고정되어 있다.
- `canSaveInPlace`는 source 확장자가 `.hwp`일 때만 참이므로 `.hwpx` source의 `Command+S`는 제자리 저장으로 이어질 수 없다.
- 저장 성공 뒤 `DocumentViewerStore.recordSavedDocument(at:)`로 HostApp source/recent/dirty 상태는 갱신하지만 upstream `notifySaved`는 호출하지 않는다.

### bundled `rhwp-studio` capability

bundled asset은 수정 없이 필요한 기능을 이미 제공한다.

| capability | 확인 결과 | HostApp 사용 계획 |
|------------|-----------|-------------------|
| `exportHwp` | embed RPC와 WASM wrapper에 존재 | HWP 저장 payload 생성 |
| `exportHwpx` | embed RPC와 WASM wrapper에 존재 | HWPX 저장 payload 생성 |
| `notifySaved` | embed RPC와 `notify-saved-v1` capability에 존재 | filename 갱신, editor clean 처리, recovery draft 폐기 |
| `file:save-as-hwp` | upstream command registry에 존재 | HostApp가 capture 단계에서 native command로 intercept |
| `file:save-as-hwpx` | upstream command registry에 존재 | HostApp가 capture 단계에서 native command로 intercept |

`notifySaved(fileName)`은 upstream filename을 갱신하고 document state를 `host-save` 사유로 clean 처리한 뒤 recovery draft를 폐기한다. 따라서 HostApp의 `recordSavedDocument(at:)`만 호출하면 native 상태와 browser editor 상태가 서로 어긋난다.

## 확정한 format 계약

### command matrix

| command | format 결정 | destination | 성공 뒤 다음 `Command+S` |
|---------|-------------|-------------|---------------------------|
| `file:save` | source URL 확장자 → 현재 filename → HWP 기본값 | 지원 source면 제자리, 실패·미지원이면 같은 format panel | 저장된 current source format으로 재export |
| `file:save-as` | source URL 확장자 → 현재 filename → HWP 기본값 | 결정된 format panel | 선택한 URL의 동일 format으로 재export |
| `file:save-as-hwp` | 명시적 HWP | HWP panel | 새 `.hwp` source에 `exportHwp` 사용 |
| `file:save-as-hwpx` | 명시적 HWPX | HWPX panel | 새 `.hwpx` source에 `exportHwpx` 사용 |

명시적 format이 source format보다 우선한다. 일반 save/save-as는 source format을 보존하고, source URL과 filename 어디에서도 format을 판정할 수 없는 새 문서는 기존 호환 정책대로 HWP를 기본값으로 사용한다.

HWPX로 저장한 뒤 current source URL과 filename을 `.hwpx`로 갱신해야 이후 `Command+S`가 다시 `exportHwpx`를 사용한다. exporter 선택을 최초 메뉴 command에만 묶어 두면 이 요구사항을 만족할 수 없다.

### 상태와 응답 검증 경계

Stage 2와 Stage 3은 다음 단일 format 값을 공유한다.

- `DocumentSaveFormat`: bridge raw value, 확장자, panel title·UTType·기본 filename, payload signature를 소유
- `PendingSaveRequest`: destination과 `DocumentSaveFormat`을 함께 보관
- save response: `format`, `fileName`, `base64`, `byteCount`를 제공

Swift coordinator의 write 전 검증 순서는 다음으로 확정했다.

1. pending request 존재
2. response format decode 성공
3. pending format과 response format 일치
4. base64 decode와 `byteCount` 일치
5. payload signature와 format 일치
6. destination 확장자와 format 일치
7. security-scoped atomic write

HWP는 CFB magic, HWPX는 ZIP magic을 runtime guard로 사용한다. HWPX container의 `mimetype`, `Contents/` entry 검증은 UI write hot path에 ZIP parser를 추가하지 않고 Stage 4 통합 산출물 검증에서 수행한다.

write 성공 뒤에는 HostApp current source/recent document를 먼저 갱신하고 upstream `notifySaved(fileName)`을 호출한다. `notifySaved` 실패는 이미 durable write된 파일을 되돌리지 않고 별도 동기화 오류로 처리한다.

## 다음 단계 변경 범위

### Stage 2

- 신규 `Sources/HostApp/Services/DocumentSaveFormat.swift`
- `Sources/HostApp/Services/DocumentSavePanel.swift` 형식 인식형 API
- `Tests/HostAppTests`의 format 판정·filename·signature 단위 테스트
- `project.yml` source 반영과 `xcodegen generate`

### Stage 3

- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`의 형식별 command/export/response
- `Sources/HostApp/Views/RhwpStudioWebView.swift`의 pending request, 제자리 저장, 검증, source 전환과 `notifySaved`

Issue #456에서는 share와 기존 PDF 경로의 HWP payload 사용을 유지한다. SVG 기반 native PDF는 별도 Issue #455에서 처리한다.

## 본문 변경 정도와 무손실 확인

- 제품 소스: 변경 없음
- bundled `rhwp-studio` asset: 변경 없음
- Xcode project와 의존성: 변경 없음
- 조사 문서: 이 Stage 1 완료보고서 신규 작성
- 오늘할일: Stage 1 완료보고서 승인 대기로 상태 갱신

기존 저장 구현이나 upstream 산출물을 재생성·정규화하지 않았으므로 본문 무손실 조건에 영향이 없다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `rg -n "file:save\|file:save-as-hwp\|file:save-as-hwpx\|exportHwp\|exportHwpx\|notifySaved\|pendingSaveDestination\|canSaveInPlace" Sources/HostApp` | 통과. HostApp HWP 고정 지점, missing native command, upstream HWPX/RPC 표면을 확인했다. |
| `rg -n -o '.{0,240}(exportHwpx\|notifySaved\|file:save-as-hwpx).{0,360}' Sources/HostApp/Resources/rhwp-studio/assets/*.js` | 통과. `exportHwpx`, `file:save-as-hwpx`, `notifySaved`, `notify-saved-v1` 제공을 확인했다. |
| `git diff --check` | 통과. 보고서와 오늘할일 변경에 whitespace 오류가 없다. |

이번 단계는 read-only 조사 단계이므로 build와 test는 수행하지 않는다. Stage 2부터 순수 모델 테스트와 HostApp build를 수행한다.

## 잔여 위험

- upstream minified asset의 RPC surface는 확인했지만 native bridge에서 HWPX byte payload를 대용량으로 base64 변환하는 실제 메모리 특성은 Stage 3과 Stage 4에서 검증해야 한다.
- runtime ZIP magic은 파일 형식 오연결을 막는 최소 guard다. 정상 HWPX container 여부는 Stage 4에서 별도 entry 검사로 보완해야 한다.
- source URL과 filename이 서로 다른 format을 가리키는 비정상 상태에서는 URL을 우선한다. Stage 2 단위 테스트와 Stage 3 coordinator test에서 우선순위를 고정해야 한다.
- write 성공 뒤 `notifySaved`만 실패한 경우 파일 저장 성공과 editor 동기화 오류를 구분하는 사용자 메시지가 필요하다.

## 다음 단계 영향

Stage 2는 이 보고서의 `DocumentSaveFormat` 계약을 순수 Foundation 모델과 format-aware `NSSavePanel`로 구현한다. bridge와 coordinator의 동작 변경은 Stage 3까지 보류하므로 Stage 2 단위 테스트에서 format 결정·filename 정규화·signature 검증을 먼저 독립적으로 고정할 수 있다.

## 승인 요청

Stage 1 조사와 저장 형식 계약 확정을 완료했다. Stage 2 `저장 형식 모델과 native panel 일반화` 구현 진행 승인을 요청한다.
