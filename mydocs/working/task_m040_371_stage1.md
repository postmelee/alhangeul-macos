# Task M040 #371 Stage 1 완료보고서

## 단계 목적

HostApp 파일 열기 초기에 사용하는 Swift 입력 검증에서 HWP 3.0 signature를 지원 문서로 인정하도록 보강했다. 이번 단계는 `HwpDocumentInputValidator`의 사전 차단만 해소하며, bundled `rhwp-studio` URL byte guard는 Stage 2 범위로 남긴다.

## 산출물

| 파일 | 변경량 | 요약 |
|------|--------|------|
| `Sources/Shared/HwpDocumentInputValidator.swift` | 115 lines, 일부 변경 | `HWP Document File V3.` ASCII prefix를 추가하고 `isSupportedDocumentSignature(_:)` 판정에 포함 |
| `mydocs/orders/20260624.md` | 7 lines, 1행 갱신 | #371 상태를 Stage 1 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m040_371_stage1.md` | 신규 | Stage 1 완료보고서 |

핵심 변경 위치:

```text
18: private static let hwpMagic: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
19: private static let hwp3MagicPrefix: [UInt8] = Array("HWP Document File V3.".utf8)
35: static func isSupportedDocumentSignature(_ data: Data) -> Bool {
36:     data.starts(with: hwpMagic)
37:         || data.starts(with: hwp3MagicPrefix)
38:         || hwpxMagics.contains { data.starts(with: $0) }
```

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 변환이나 저장 경로를 건드리지 않았다. 이번 변경은 입력 bytes의 앞부분 signature 판정만 확장하며, 실제 HWP 3.0 parsing/rendering은 기존 `rhwp` core 경로에 그대로 맡긴다.

기존 HWP5 CFB magic과 HWPX ZIP magic 판정, 빈 문서 오류, `unsupportedOrCorrupt` 오류 문구, Quick Look/Thumbnail fallback 분류는 변경하지 않았다.

## 검증 결과

```bash
git diff --check
```

- 결과: 통과, 출력 없음.

```bash
rg -n "HWP Document File V3|hwp3|isSupportedDocumentSignature|hwpMagic|hwpxMagics" Sources/Shared/HwpDocumentInputValidator.swift
```

주요 출력:

```text
18:    private static let hwpMagic: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
19:    private static let hwp3MagicPrefix: [UInt8] = Array("HWP Document File V3.".utf8)
20:    private static let hwpxMagics: [[UInt8]] = [
35:    static func isSupportedDocumentSignature(_ data: Data) -> Bool {
36:        data.starts(with: hwpMagic)
37:            || data.starts(with: hwp3MagicPrefix)
38:            || hwpxMagics.contains { data.starts(with: $0) }
```

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

- 결과: 통과.
- 최종 출력: `** BUILD SUCCEEDED ** [1.383 sec]`

새 worktree에는 generated `Frameworks/Rhwp.xcframework`가 없어서 최초 `xcodebuild`는 missing framework로 실패했다. 이는 코드 회귀가 아니라 `build_run_guide.md`에 명시된 새 worktree 준비 단계 누락이었다. `./scripts/build-rust-macos.sh`로 Rust bridge 산출물을 생성했고, 이전 실패의 XCBuildData를 배제하기 위해 `xcodebuild ... clean build`를 1회 수행한 뒤 계획서의 원래 build 명령을 다시 실행해 통과를 확인했다.

## 잔여 위험

- Swift validator는 이제 HWP 3.0 파일을 HostApp 초기 단계에서 차단하지 않는다.
- 다만 bundled `rhwp-studio` asset의 URL byte guard는 아직 HWP5 CFB/HWPX ZIP만 허용하므로, HostApp WebView 내부 URL 로드 경로에서는 Stage 2 전까지 HWP 3.0이 다시 차단될 수 있다.
- HWP 3.0 signature는 `HWP Document File V3.` prefix만 허용하므로 HWP 2.x 또는 알 수 없는 legacy 변형은 이번 변경으로 지원 대상에 포함하지 않는다.
- 저장소에는 제보 샘플 fixture가 포함되어 있지 않아 자동 회귀 테스트는 아직 build와 정적 검증 중심이다.

## 다음 단계 영향

Stage 2에서는 `Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js`의 문서 byte kind 판정에 동일한 HWP 3.0 prefix를 추가해야 한다. Stage 2가 끝나야 HostApp의 `alhangeul-document://` URL 전달 후 WebView 내부 guard까지 통과하는 흐름을 검증할 수 있다.

## 승인 요청

Stage 1 산출물 검토와 Stage 2 진입 승인을 요청한다. 승인 전에는 bundled `rhwp-studio` asset 변경을 시작하지 않는다.
