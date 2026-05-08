# Task M016 #149 Stage 3 보고서

## 단계 목적

HostApp에서 빈 파일, 손상 또는 미지원 signature, WebView 내부 문서 load 실패가 빈 화면이나 generic error로 끝나지 않도록 opening fallback을 보강했다. 이번 단계는 Quick Look/Thumbnail 동작을 바꾸지 않고 HostApp 경로만 다룬다.

## 산출물

| 파일 | 요약 | 라인 수 |
|---|---|---:|
| `Sources/Shared/HwpDocumentInputValidator.swift` | HWP OLE magic과 HWPX ZIP magic 기반 입력 preflight 추가 | 37 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | 파일 읽기, 빈 문서, 손상/미지원 입력 메시지 taxonomy 적용 | 189 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | `rhwp-studio` status 영역의 `파일 로드 실패:` 메시지를 native event로 전달 | 596 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `document-load-error` native message 처리 추가 | 1173 |
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | 사용자 문서 load failure category와 기본 문구 추가 | 515 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 새 Shared 파일을 각 target source에 반영 | 해당 없음 |

## 변경 내용

- HostApp 문서 입력 preflight를 추가해 빈 데이터는 `비어 있는 문서는 열 수 없습니다.`, signature mismatch는 `이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다.`로 구분한다.
- 파일 읽기 또는 security-scoped URL 접근 실패는 `문서를 읽을 수 없습니다. 파일 접근 권한 또는 위치를 확인한 뒤 다시 열어 주세요.`로 정리했다.
- drag-and-drop 실패는 기존 banner 경로를 유지하되 같은 taxonomy 메시지를 붙인다.
- `rhwp-studio` 내부에서 표시하던 `파일 로드 실패:` 상태 메시지를 host bridge가 감지해 Swift의 `RhwpStudioWebViewFailure.documentLoad`로 승격한다.
- #150의 asset/resource failure category와 사용자 문서 load failure category를 분리했다.
- `project.yml`의 `Sources/Shared` 포함 정책에 맞춰 `xcodegen generate`로 `Alhangeul.xcodeproj`를 재생성했다. 프로젝트 파일은 직접 편집하지 않았다.

## 본문 무손실 여부

해당 없음. 이번 단계는 코드 변경이며 문서 본문 변환이나 사용자 파일 수정은 수행하지 않았다. smoke용 synthetic 파일은 `build.noindex/task149-negative/` 아래에만 생성했다.

## 검증 결과

```text
$ git status --short --branch
## local/task149
 M Alhangeul.xcodeproj/project.pbxproj
 M Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift
 M Sources/HostApp/Services/RhwpStudioResourceLocator.swift
 M Sources/HostApp/Stores/DocumentViewerStore.swift
 M Sources/HostApp/Views/RhwpStudioWebView.swift
?? Sources/Shared/HwpDocumentInputValidator.swift
```

```text
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
$ xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [5.268 sec]
```

빌드 중 CoreSimulator 관련 경고와 provisioning profile 경고가 출력됐지만 macOS HostApp build는 성공했다.

```text
$ mkdir -p build.noindex/task149-negative
$ touch build.noindex/task149-negative/empty.hwp
$ printf 'not-hwp-data' > build.noindex/task149-negative/corrupt.hwp
$ /usr/bin/open -n -a build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app build.noindex/task149-negative/empty.hwp
$ /usr/bin/open -a build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app build.noindex/task149-negative/corrupt.hwp
$ pgrep -x Alhangeul
23550
```

negative smoke는 Debug app이 빈 파일과 손상 파일을 받은 뒤 프로세스가 유지되는 수준까지 확인했다. UI 문구의 눈검증은 Stage 5 synthetic smoke에서 다시 묶어 확인한다.

```text
$ git diff --check
```

출력 없음.

## 잔여 위험

- HostApp UI 문구를 자동 UI 테스트로 검증하지는 않았다. Stage 5에서 HostApp, Quick Look, Thumbnail synthetic negative smoke를 다시 수행하며 수동 확인 항목으로 남긴다.
- HWPX signature는 ZIP container magic만 preflight한다. 실제 HWPX 구조 검증은 기존 renderer 또는 `rhwp-studio` parse 단계에서 처리한다.
- Quick Look/Thumbnail의 parse/render fallback은 아직 Stage 4 범위로 남아 있다.

## 다음 단계 영향

Stage 4에서 `HwpDocumentInputValidator` 또는 같은 taxonomy를 Quick Look/Thumbnail fallback mapping에 재사용할 수 있다. 다만 extension의 UI/reply 정책은 target별로 유지해야 하며, `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.

## 승인 요청

Stage 3 완료 검토 후 Stage 4 Quick Look/Thumbnail negative fallback 보강 진행 승인을 요청한다.
