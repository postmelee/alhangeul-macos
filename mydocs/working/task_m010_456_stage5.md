# Task #456 Stage 5 완료보고서

## 단계 목적

Stage 2~4에서 구현·검증한 HWP/HWPX format-aware 저장 경로를 프로젝트 architecture의 현재 기준으로 반영하고, HostApp과 bundled upstream의 소유 경계, runtime guard와 HWPX container 검증의 차이, exporter 호환 제한을 인계 가능한 상태로 정리한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/tech/project_architecture.md` | HWP-only로 남아 있던 저장 설명을 형식 인식형 native 저장 경로로 갱신하고 command matrix, exporter/write 상태 전이, 검증 경계와 호환 제한 추가 |
| `mydocs/working/task_m010_456_stage5.md` | Stage 5 문서 변경과 검증 결과, 최종 보고서 입력과 잔여 위험 정리 |
| `mydocs/orders/20260804.md` | Task #456 상태를 Stage 5 완료보고서 승인 대기로 갱신 |

제품 source, 테스트, bundled `rhwp-studio` asset과 Xcode project는 이번 단계에서 변경하지 않았다.

## architecture 반영 결과

### 저장 소유 경계

- 알한글 HostApp이 upstream 파일 메뉴의 저장 command를 intercept한다.
- HostApp이 저장 형식 결정, `NSSavePanel`, destination과 security-scoped 접근, response 검증, atomic write, current source와 최근 문서 갱신을 소유한다.
- bundled `rhwp-studio`는 editor state settle, `exportHwpBase64`/`exportHwp`/`exportHwpx` 호출과 저장 성공 뒤 `notifySaved`를 통한 filename·dirty·recovery 상태 동기화를 담당한다.
- upstream은 로컬 저장 위치 선택이나 파일 write를 수행하지 않는다.
- `notifySaved` 실패는 이미 성공한 durable write를 되돌리지 않고 별도 editor sync 오류로 처리한다.

### command matrix

| command | 형식 | destination |
|---------|------|-------------|
| `file:save` | source URL → filename → 기본 HWP | 같은 형식 source에 제자리 저장, source 없음/write 실패 시 같은 형식 panel |
| `file:save-as` | source URL → filename → 기본 HWP | 현재 형식 native panel |
| `file:save-as-hwp` | 명시적 HWP | HWP native panel |
| `file:save-as-hwpx` | 명시적 HWPX | HWPX native panel |

저장 패널 title, UTI, 기본 filename, 확장자와 signature 규칙이 `DocumentSaveFormat`에서 파생됨을 기록했다. HWPX 저장 성공 뒤 current source가 실제 `.hwpx` URL로 전환되고 후속 `Command+S`가 panel 없이 `exportHwpx`를 계속 사용하는 상태 전이도 명시했다. HWPX → HWP 전환 뒤에는 반대로 HWP exporter가 유지된다.

### exporter와 write guard

- HWP: `exportHwpBase64`, 미지원 시 `exportHwp` fallback
- HWPX: `exportHwpx`, chunked base64 encode
- write 전 검증: pending request → response format → base64/byte count → CFB/ZIP signature → destination extension
- 제자리 write 실패: 원래 요청 format을 유지한 native save panel fallback
- panel/export 진행 중 중복 요청: 새 pending request를 만들지 않음

runtime signature guard는 HWP/HWPX payload 오연결을 막는 최소 방어로 정의했다. HWPX의 `mimetype`, `Contents/`, `META-INF/` entry, 손상 ZIP과 실제 재열기는 별도 container/render smoke의 책임으로 구분했다.

### 호환 제한

- HostApp은 upstream exporter bytes를 별도 본문 재구성 없이 저장하지만 upstream parser/document model/exporter의 모든 기능에 대해 완전 무손실을 보증하지 않는다.
- Stage 4의 네 형식 조합과 대표 page render는 현재 fixture 기준의 호환 확인이며 전체 HWP/HWPX 의미론의 증명은 아니다.
- runtime HWPX guard는 ZIP magic만 확인하므로 필수 entry가 빠진 container도 별도 검사 전에는 통과할 수 있다.
- chunked base64는 JavaScript call-stack overflow를 피하지만 JS와 Swift 양쪽이 전체 payload를 보유하는 메모리 비용은 남는다.
- 공유와 현재 PDF export는 저장 경로와 분리된 기존 HWP exporter payload 경로를 유지한다. PDF ownership 변경은 별도 Task #455 범위다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| architecture·Stage 보고서 keyword `rg` | 통과. 파일 저장, HWPX exporter, 후속 `Command+S`와 `notifySaved` 설명을 대조했다. |
| 저장 구현 symbol 대조 `rg` | 통과. 명시적 command, `exportHwpx`, `notifySaved`, signature/destination guard와 `canSaveInPlace`가 문서 설명과 일치했다. |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task456/stage4-tests CODE_SIGNING_ALLOWED=NO test` | 재실행 통과. 전체 100개, 실패 0개, `** TEST SUCCEEDED **`. |
| `scripts/verify-rhwp-studio-assets.sh build.noindex/task456/stage4-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio` | 통과. Stage 4 빌드 앱의 bundled upstream asset을 재확인했다. |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift 계층의 AppKit/UIKit 비의존 경계를 유지했다. |
| HWPX Stage 4 결과 세 개 `unzip -t` | 모두 통과. container 손상이 없다. |
| Stage 4 저장 결과와 fallback 결과 5개 render smoke 재실행 | 모두 통과. page 1의 text run과 non-white pixel을 확인했다. |
| `git diff --check` | 통과. whitespace 오류가 없다. |

HostAppTests의 첫 재실행은 sandbox에서 Xcode/SwiftPM cache에 쓸 수 없어 package resolution 전에 종료됐다. 동일 명령을 허용된 환경에서 다시 실행해 100개 테스트가 모두 통과했다. 문서나 제품 결함에 따른 실패는 아니다.

## Stage 1~5 최종 결과 요약

1. Stage 1에서 upstream `exportHwpx`/`notifySaved` capability와 네 저장 command의 format/state 계약을 확정했다.
2. Stage 2에서 `DocumentSaveFormat`과 형식 인식형 native panel, CFB/ZIP signature 규칙을 순수 모델과 테스트로 고정했다.
3. Stage 3에서 명시적 메뉴, 형식별 exporter, response 검증, atomic write, current source 전환과 `notifySaved`를 연결했다.
4. Stage 4에서 HWP ↔ HWPX 네 조합, HWPX 뒤 `Command+S`, 재열기, 취소, 읽기 전용 fallback, 중복 요청과 unsaved guard를 실제 UI와 core render로 검증했다.
5. Stage 5에서 구현된 저장 정책, 소유 경계와 호환 제한을 architecture의 현재 기준으로 반영했다.

## 최종 보고서와 PR 인계

최종 보고서에는 다음 내용을 포함할 수 있는 상태다.

- Task #456 요구사항과 command/exporter matrix
- 주요 제품·테스트 변경 파일
- HWPX 저장 뒤 `Command+S`가 `exportHwpx`를 유지한다는 단위/UI 증거
- 전체 100개 테스트와 Debug build 성공
- 네 형식 조합, 읽기 전용 fallback, signature/container/render 결과
- upstream exporter의 완전 무손실 비보장과 대용량 payload 메모리 비용

Stage 5 완료 시점의 작업 트리에는 architecture, 이 보고서와 오늘할일 외에 미보고 변경이 없어야 한다. 최종 보고서 작성과 PR 게시 전 전체 staged diff와 branch 상태를 다시 확인한다.

## 승인 요청

Stage 5 `저장 정책 문서와 잔여 호환 제한 정리`를 완료했다. Task #456 최종 결과보고서 작성, 최종 커밋, `publish/task456` push와 `devel` 대상 PR 게시 단계 진행 승인을 요청한다.
