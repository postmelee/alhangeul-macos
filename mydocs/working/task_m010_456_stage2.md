# Task #456 Stage 2 완료보고서

## 단계 목적

HWP와 HWPX의 확장자, 저장 패널 표시, 기본 파일명과 payload signature 규칙을 하나의 순수 Foundation 모델로 고정하고, `NSSavePanel`이 요청 format에 맞는 파일명과 content type을 사용하도록 일반화한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/HostApp/Services/DocumentSaveFormat.swift` | HWP/HWPX raw format, 추론 우선순위, filename·destination 정규화, CFB/ZIP signature guard를 제공하는 모델 신규 작성 |
| `Sources/HostApp/Services/DocumentSavePanel.swift` | 모든 panel/save API가 `DocumentSaveFormat`을 필수로 받고 title, filename, UTType과 반환 URL을 format에서 구성하도록 변경 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | Stage 3 전까지 기존 동작을 유지하도록 현재 HWP 전용 호출부에 `.hwp`를 명시 |
| `Tests/HostAppTests/DocumentSaveFormatTests.swift` | format decode·추론·정규화·signature guard 단위 테스트 10개 신규 작성 |
| `project.yml` | `DocumentSaveFormat.swift`를 HostAppTests source에 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 위 source 구성을 재생성 |

`DocumentSaveFormat`은 AppKit에 의존하지 않는다. panel에 필요한 문자열과 exported UTI identifier만 Foundation 값으로 제공하고, 실제 `UTType`과 `NSSavePanel` 구성은 `DocumentSavePanel`이 담당한다.

## 구현 결과

### format 판정과 filename 정규화

- bridge raw value는 소문자 `hwp`, `hwpx`만 허용해 protocol 오입력을 조기에 거부한다.
- source format은 URL 확장자를 먼저 보고, 판정할 수 없으면 현재 filename, 둘 다 없으면 HWP를 선택한다.
- HWP/HWPX 확장자는 대소문자와 관계없이 판정한다.
- 대상 format과 다른 지원 확장자는 교체하고, `sample.hwp.hwpx`처럼 연속된 지원 suffix도 하나로 정규화한다.
- `.txt` 같은 미지원 확장자는 filename stem의 일부로 보존해 `sample.txt.hwp`처럼 결과가 결정적이다.
- 빈 filename은 `document.hwp` 또는 `document.hwpx`를 사용한다.

### 저장 패널

- 호출자는 format을 반드시 전달해야 한다.
- title은 `HWP 문서 저장` 또는 `HWPX 문서 저장`으로 달라진다.
- app이 export하는 `com.postmelee.alhangeul.hwp` 또는 `com.postmelee.alhangeul.hwpx` UTType을 우선 사용하고, 사용할 수 없으면 확장자 기반 UTType으로 fallback한다.
- `allowsOtherFileTypes`를 끄고 확장자를 표시한다.
- sheet/modal 어느 경로든 panel 반환 URL을 선택 format으로 다시 정규화해 다른 지원 확장자가 남지 않게 한다.

### payload signature guard

- HWP: 8바이트 CFB magic `D0 CF 11 E0 A1 B1 1A E1`
- HWPX: ZIP local header, empty archive, spanning marker magic 허용
- 짧은 payload와 HWP/ZIP이 서로 뒤바뀐 payload는 거부

이 단계에서는 모델만 구현했다. 실제 bridge response와 destination을 이 guard로 검사하는 연결은 Stage 3에서 수행한다.

## 본문 변경 정도 / 본문 무손실 여부

- HWP/HWPX parser, renderer와 document body: 변경 없음
- bundled `rhwp-studio` asset: 변경 없음
- `Sources/RhwpCoreBridge`: 변경 없음
- 기존 save exporter와 atomic write: Stage 3 전까지 HWP 동작 유지
- Xcode project: `project.yml`을 원본으로 `xcodegen generate`한 source reference만 변경

문서 bytes를 읽거나 다시 쓰는 제품 경로는 이번 단계에서 변경하지 않았으므로 기존 문서 본문 무손실 조건에 영향이 없다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `xcodegen generate` | 통과. `Alhangeul.xcodeproj`를 `project.yml`에서 재생성했다. |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task456/stage2-tests CODE_SIGNING_ALLOWED=NO test` | 통과. 전체 86개, 실패 0개이며 신규 `DocumentSaveFormatTests` 10개가 모두 통과했다. |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task456/stage2-build CODE_SIGNING_ALLOWED=NO build` | 통과. `** BUILD SUCCEEDED **`. |
| `./scripts/check-no-appkit.sh` | 통과. `OK: shared Swift code has no AppKit/UIKit dependencies`. |
| `git diff --check` | 통과. 단계 소스·테스트·보고서와 오늘할일 변경에 whitespace 오류가 없다. |

첫 sandbox 내 테스트 시도는 Sparkle 저장소의 DNS 접근이 차단돼 package resolution 전에 종료됐다. 같은 명령을 허용된 네트워크 환경에서 재실행해 의존성을 2.9.1로 해석한 뒤 위 테스트와 빌드가 정상 통과했다. 코드나 테스트 실패는 아니었다.

## 잔여 위험

- ZIP magic은 HWPX container의 완전성을 보장하지 않는다. Stage 4에서 `mimetype`, `Contents/` entry를 별도 검사해야 한다.
- panel URL은 format에 맞게 정규화하지만 실제 exporter response format·byte count·signature·destination 확장자의 교차 검증은 Stage 3에서 연결해야 한다.
- HWPX로 저장한 뒤 current source를 전환하고 다음 `Command+S`에서 `exportHwpx`를 선택하는 동작은 아직 연결하지 않았다.
- `notifySaved`를 통한 upstream clean/recovery state 동기화도 Stage 3 범위다.

## 다음 단계 영향

Stage 3은 `DocumentSaveFormat`을 단일 기준으로 다음을 연결한다.

- `file:save-as-hwp`, `file:save-as-hwpx` native command interception
- HWP `exportHwp`와 HWPX `exportHwpx` 선택
- destination+format을 함께 보관하는 `PendingSaveRequest`
- response format·byte count·signature·destination extension 검증
- `.hwp`와 `.hwpx` 제자리 저장 및 같은 format fallback panel
- 저장한 URL을 current source로 전환한 뒤 `notifySaved` 호출

Stage 2 호출부에 넣은 임시 `.hwp`는 Stage 3에서 command/source에 따라 결정한 format으로 교체한다.

## 승인 요청

Stage 2 `저장 형식 모델과 native panel 일반화` 구현과 검증을 완료했다. Stage 3 `형식별 export와 제자리 재저장 연결` 진행 승인을 요청한다.
