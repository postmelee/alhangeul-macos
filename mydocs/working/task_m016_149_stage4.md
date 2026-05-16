# Task M016 #149 Stage 4 보고서

## 단계 목적

Quick Look preview와 Finder thumbnail에서 손상, 미지원, 빈 문서, render/encoding 실패가 raw extension error로 전파되지 않도록 fallback mapping을 보강했다. 50 MB 초과 정책은 기존 Quick Look/Thumbnail preview 제한으로 유지했다.

## 산출물

| 파일 | 요약 | 라인 수 |
|---|---|---:|
| `Sources/Shared/HwpDocumentInputValidator.swift` | shared fallback reason/classifier 추가 | 112 |
| `Sources/Shared/HwpPageImageRenderer.swift` | `.never` thumbnail 정책에서 대용량 파일을 full read 전에 차단 | 240 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | PNG/PDF data 선계산 후 reply 생성, fallback plain text mapping 추가 | 70 |
| `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | fallback-eligible error를 기존 thumbnail fallback tile로 mapping | 94 |

## 변경 내용

- `HwpDocumentFallbackClassifier`를 추가해 `HwpDocumentInputError`, `HwpRenderError`, `RhwpError`, Foundation file read error를 fallback reason으로 분류한다.
- Quick Look fallback 문구를 Stage 2 taxonomy에 맞췄다.
  - 50 MB 초과: `이 파일은 50 MB보다 커서 미리보기를 만들지 않습니다.`
  - 빈 문서/손상/미지원: `이 파일은 HWP/HWPX 형식이 아니거나 손상되어 미리보기를 만들 수 없습니다.`
  - render/encoding 실패: `이 문서의 미리보기를 만들 수 없습니다. 알한글 앱에서 열어 확인해 주세요.`
  - 파일 접근 실패: `문서를 읽을 수 없습니다. 파일 접근 권한 또는 위치를 확인한 뒤 다시 시도해 주세요.`
- `HwpPreviewProvider`는 단일 페이지 PNG와 다중 페이지 PDF data를 `QLPreviewReply` 생성 전에 만든다. 이로써 data block 내부 throw가 raw error로 전파되는 범위를 줄였다.
- `HwpThumbnailProvider`는 `fileTooLarge`뿐 아니라 parse/render/access fallback 대상 오류에서도 기존 `drawFallback` tile을 반환한다. 별도 오류 텍스트는 그리지 않는다.
- `HwpThumbnailRenderCache`는 변경하지 않았다. 기존 구조대로 성공 결과만 cache하고 실패 결과는 저장하지 않는다.
- `HwpPageImageRenderer.renderFirstPage`는 `embeddedThumbnailPolicy == .never`일 때 file size를 full data read 전에 확인한다.

## 본문 무손실 여부

해당 없음. 이번 단계는 코드 변경이며 사용자 문서나 sample 파일은 수정하지 않았다.

## 검증 결과

```text
$ git status --short --branch
## local/task149
 M Sources/QLExtension/HwpPreviewProvider.swift
 M Sources/Shared/HwpDocumentInputValidator.swift
 M Sources/Shared/HwpPageImageRenderer.swift
 M Sources/ThumbnailExtension/HwpThumbnailProvider.swift
```

```text
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
$ xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [3.156 sec]
```

```text
$ xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [1.494 sec]
```

두 빌드 모두 CoreSimulator 관련 경고와 provisioning profile 경고를 출력했지만 macOS extension build는 성공했다.

```text
$ git diff --check
```

출력 없음.

## 잔여 위험

- `qlmanage` 기반 실제 Finder/Quick Look smoke는 이번 단계에서 실행하지 않았다. extension 등록과 설치 상태 영향을 받기 때문에 Stage 5 synthetic negative smoke에서 HostApp, Quick Look, Thumbnail을 함께 확인한다.
- Quick Look은 reply 생성 전에 PNG/PDF data를 만든다. 50 MB 제한은 유지되지만 페이지 수가 큰 문서에서는 preview provider 응답 시점의 작업량이 늘 수 있다.
- HWPX는 ZIP magic만 signature preflight로 보며, 실제 구조 검증은 parser/render 단계 fallback으로 처리한다.

## 다음 단계 영향

Stage 5에서는 synthetic `empty.hwp`, `corrupt.hwp`, `large.hwp`와 정상 sample control case로 HostApp, Quick Look, Thumbnail smoke를 묶어 확인한다. README와 build/run guide의 fallback 절차 또는 release gate 문구가 실제 동작과 다르면 필요한 범위만 갱신한다.

## 승인 요청

Stage 4 완료 검토 후 Stage 5 synthetic negative smoke와 release gate 정리 진행 승인을 요청한다.
