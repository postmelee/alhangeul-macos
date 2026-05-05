# Issue #144 Stage 2 보고서

## 단계 목적

WKWebView 내부 drag/drop 문서 로드를 HostApp native bridge가 인지할 수 있도록 message 경로를 추가한다. bundled `rhwp-studio` generated JS는 직접 수정하지 않고, HostApp injected bridge script와 `RhwpStudioWebView.Coordinator` 사이에 filename/bytes 전달 경계를 만든다.

## 산출물

- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
  - 총 478줄
  - injected script에 HWP/HWPX drop 감지, bytes base64 인코딩, `dropped-document` native message 전송 추가
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
  - 총 960줄
  - `RhwpStudioDroppedDocument` payload 타입, `onDroppedDocument` callback, `dropped-document` message decoding 추가
- `mydocs/working/task_m010_144_stage2.md`
  - Stage 2 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

- HostApp source 2개 파일 변경
- 변경 규모: 2 files changed, 94 insertions(+), 4 deletions(-)
- bundled `Sources/HostApp/Resources/rhwp-studio` generated asset은 변경하지 않았다.
- `Sources/RhwpCoreBridge`, Quick Look, Thumbnail extension source는 변경하지 않았다.
- 기존 save/share/print/PDF export payload decoding은 `decodedData(from:missingMessage:)` helper로 분리했지만, 허용 입력(`base64`, `[NSNumber] bytes`, `byteCount`)과 오류 메시지 정책은 유지했다.

## 구현 내용

### injected bridge script

`RhwpStudioHostBridgeScript`에 `isSupportedDocumentFile(file)`과 `postDroppedDocument(file)`를 추가했다. HWP/HWPX 파일이 drop되면 같은 `File` 객체에서 `arrayBuffer()`를 읽고 base64로 인코딩해 native message를 보낸다.

전송 message:

```text
type: "dropped-document"
fileName: file.name 또는 document.hwp
base64: dropped file bytes
byteCount: bytes.length
```

drop listener는 capture phase에 등록하되 `preventDefault()`, `stopPropagation()`, `stopImmediatePropagation()`을 호출하지 않는다. 따라서 Stage 2만 적용된 상태에서도 기존 bundled viewer의 drop 로드 경로를 막지 않는다. 실제 Swift store 갱신과 toolbar 활성화는 Stage 3에서 이 callback을 연결해 처리한다.

### Swift WebView coordinator

`RhwpStudioWebView`에 `RhwpStudioDroppedDocument`와 `onDroppedDocument` callback을 추가했다. `Coordinator.userContentController(_:didReceive:)`는 새 `dropped-document` message를 받아 다음 검증 후 callback으로 전달한다.

- `fileName` 존재 및 확장자 `hwp`/`hwpx` 확인
- `base64` 또는 `[NSNumber] bytes` decoding
- `byteCount`가 있으면 실제 data size와 일치하는지 확인

`decodedData(from:missingMessage:)` helper를 추가해 기존 export payload decoding과 dropped document decoding이 같은 크기 검증 경로를 쓰게 했다.

## 검증 결과

실행 명령:

```bash
git diff --check
```

결과: 통과. 출력 없음.

실행 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [21.200 sec]
```

빌드 중 CoreSimulatorService와 `~/Library/Logs/CoreSimulator` 접근 경고가 출력되었다. macOS HostApp build 자체는 성공했고, Swift compile/link 및 embedded JS multiline string compile 문제는 발견되지 않았다.

## 잔여 위험

- Stage 2는 bridge message와 callback 경계까지만 추가했으므로, 이 단계만으로 toolbar 활성화 버그는 아직 사용자 관점에서 해결되지 않는다.
- Stage 3에서 `DocumentViewerStore`에 source-less document load API를 연결하면 기존 bundled viewer drop 로드와 Swift store reload가 같은 bytes로 한 번 더 일어날 수 있다. 중복 로드 UX가 눈에 띄면 Stage 3에서 drop event 차단 또는 native-first 로드 방식으로 조정한다.
- JS `File` 객체 기반 message에는 원본 filesystem URL이 없으므로, Stage 3에서도 `Finder에서 보기`는 비활성 유지가 기본 정책이다.

## 다음 단계 영향

Stage 3에서 다음 작업을 진행한다.

- `DocumentViewerStore`에 dropped bytes를 source-less document로 반영하는 API 추가
- `DocumentViewerView`에서 `onDroppedDocument` callback을 store에 연결
- titlebar AppKit toolbar가 store 변경 후 즉시 validation refresh를 수행하도록 보정
- drag/drop HWP 수동 smoke로 `공유`와 `PDF로 내보내기` 활성화 확인

## 승인 요청

Stage 2 bridge/message 구현을 완료했다. Stage 3의 store 상태 갱신 및 toolbar validation 보정 구현으로 진입하려면 작업지시자 승인이 필요하다.
