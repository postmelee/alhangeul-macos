# Task #516 구현계획서

## 작업 개요

- 이슈: [#516 — 새 문서 저장 실패와 Word·HTML 내보내기 연결 누락 수정](https://github.com/postmelee/alhangeul-macos/issues/516)
- 마일스톤: `v0.1` (`M010`)
- 수행계획서: [task_m010_516.md](task_m010_516.md)
- 작업 브랜치: `local/task516`, 대상 통합 브랜치: `devel`
- 분리 worktree: `build.noindex/worktrees/task516`
- 기준 커밋: `56fe1ca6afda3baba1975a3cc5fda53fcf58f944`
- 고정 의존성: rhwp / rhwp-studio `v0.8.6`, resolved commit `f1f9c6ae58344ee9368996d3543f76b9345cf227`
- 수행계획 승인: 2026-09-10, 같은 스레드의 “진행해줘” 지시
- 구현계획 승인: 2026-09-10 같은 스레드의 “진행해줘” 지시
- 현재 단계: 같은 스레드의 “진행해줘” 승인으로 Stage 1~5 및 최종 보고 완료, 같은 스레드에서 PR 게시 승인. 사용자 검토·merge 대기.

파일 bytes를 가진 native 문서 payload와 실제 편집 중인 문서의 존재를 구분하고, 새 문서를 기존 저장 계약에 연결한다. 별도 단계에서 Word(.doc)·HTML의 브라우저 다운로드를 native 파일 저장에 연결한다. 기존 파일의 source URL·암호 보호·HWP3 변환 정책은 문서 교체와 비동기 응답 처리까지 포함해 보존한다.

## 구현 원칙

1. `currentDocument != nil` 검사만 제거하거나 빈 Data로 정상 문서를 가장하지 않는다. 준비 완료된 편집 문서를 나타내는 상태를 명시적으로 둔다.
2. native가 요구한 파일 로드와 이미 열린 editor 문서의 상태 동기화를 분리한다. 화면에서 입력한 내용을 앱에 등록하거나 첫 저장을 완료했다는 이유로 WebView를 재로드하지 않는다.
3. 파일명이나 상태 표시 문자열만으로 새 문서·평문 상태·문서 교체를 확정하지 않는다. 고정된 editor API의 실제 생성·로드 완료와 세대 정보를 Stage 1에서 확인한다.
4. 새 문서 교체 시 이전 source URL, 원본 bytes, 암호 보호·HWP3 상태를 분리한다. 외부 문서의 보호 상태를 새 문서와 혼동하거나 알 수 없는 상태를 임의로 평문으로 낮추지 않는다.
5. 저장 패널·export·write·완료 통지는 같은 문서 세션과 요청에 속해야 한다. 기존 검증에서 사용하는 revision과 새 editor 세대의 대응을 한 곳에서 정한다.
6. 저장 snapshot 이후 추가 편집이 있으면 완료 응답이 최신 편집을 clean으로 만들지 않아야 한다. 현재 API에서 편집 세대 비교가 가능한지 확인하고, 불가능하면 export부터 완료 통지까지 짧은 편집 차단 등 입증 가능한 직렬화 방식을 설계한다.
7. 파일 write 성공과 editor 상태 동기화 실패를 구분한다. 실제 저장된 파일은 보존하고 상태 동기화 오류를 별도로 처리한다.
8. Word·HTML과 PDF는 내보내기이다. 성공·취소·실패 모두 HWP/HWPX 원본 경로·저장 형식·dirty state를 임의로 바꾸지 않는다.
9. 기존 AppKit/FFI 경계와 core pin을 유지한다. target 변경은 `project.yml`을 수정하고 XcodeGen으로 생성한다.
10. 단계 보고서는 해당 단계 산출물과 함께 커밋한다. 다음 단계와 최종 보고·PR 게시에는 각각 승인을 받는다.

## 문서 상태와 저장 계약

이 표는 구현해야 할 동작 기준이다. Stage 1에서 확정한 API 근거와 상세 계약은 [Stage 1 보고서](../working/task_m010_516_stage1.md)의 “확정한 구현 계약”을 따른다. 새 모델은 `RhwpStudioEditorSession`으로 두며, native load intent와 editor 세대·dirty·source 연결을 분리한다. 자동복구 등 출처를 입증하지 못한 editor 문서는 이전 source를 계승하지 않고 `invalidOrUnknown` 복사본 정책을 적용한다.

| 상태/사건 | native 문서 상태 | source 및 보호 상태 | 요구 동작 |
|-----------|------------------|---------------------|-----------|
| 앱 시작·editor 준비 중 | 문서 준비 대기 | source 없음 | 문서 명령을 준비 완료 전에 실행하지 않음 |
| editor 빈 문서 생성 완료 | 새 편집 세션, 최초 clean | source 없음, 확인된 새 평문 문서 | 준비 완료 등록·도구 버튼 활성화, WebView 재로드 없음 |
| 새 문서에 입력 | 같은 세션, dirty | source 없음 | native 종료 확인 대상, 입력 내용 유지 |
| 기존 파일 로드 완료 | 파일에 대응하는 편집 세션 | native가 분류한 원본·보호 정보 | 기존 파일 열기·실패 복구 계약 유지 |
| 기존 파일에서 새 문서 생성 | 새 세션으로 교체 | 이전 source·보호 정보 해제 | 이전 dirty 문서 교체 확인, 새 문서 저장으로 이전 원본을 덮어쓰지 않음 |
| 첫 저장 성공 | 같은 편집 세션에 저장 결과 반영 | 새 URL·bytes·형식·결과 보호 상태 | 최근 문서 갱신·완료 통지, 다음 Command+S는 새 URL 사용 |
| 저장 취소 또는 export/write 실패 | 기존 세션·편집 내용 유지 | 성공 전 source로 유지 | pending 정리, 종료 요청이면 창 보존 |
| Word/HTML/PDF 내보내기 | 현재 세션 유지 | 원본 정보 유지 | 내보내기 산출물만 생성, 편집 완료로 취급하지 않음 |
| 문서 교체·reload·WebContent 종료 | 이전 비동기 요청 무효화 | 새 세션 또는 실패 상태에 맞게 관리 | 이전 응답이 다른 문서의 파일·dirty 상태를 바꾸지 않음 |

파일 로드용 `RhwpStudioDocumentPayload`는 실제 bytes를 전달하는 책임을 유지한다. 편집 세션 존재·세대·표시 파일명과 source metadata를 별도 모델 또는 명시적인 상태로 표현하는 방향을 우선 검토한다. Store와 Coordinator가 서로 다른 진실 원천을 만들지 않도록 상태 소유자와 전달 방향을 확정한다.

## Stage 1. 재현과 문서·출력 계약 확정

### 작업

- 실제 bundled asset과 native bridge 기준으로 자동 빈 문서 생성, 메뉴 새로 만들기, 외부 파일 열기, 저장·다른 이름 저장·PDF·Word·HTML 명령 경로를 조사한다.
- 앱 시작 → `ㅇㅇ` 입력 → 저장 실패를 독립적으로 재현하고, 기존 파일에서 새 문서로 교체한 경우의 source 잔류와 dirty state를 확인한다.
- 새 문서 및 기존 문서 각각에서 Word·HTML 내보내기 실행 결과, 다운로드 요청과 native callback 도달 여부를 기록한다.
- 문서 준비 완료·교체·dirty 이벤트와 editor 문서 세대, `pageCount`, 저장 exporter, `notifySaved` 및 HTML 출력 접근 가능성을 고정 소스와 실행 결과로 대조한다.
- 이벤트 구독 전 생성된 초기 문서를 확인할 handshake와 이후 이벤트의 순서를 정한다. 기존 native 파일 로드·실패 복구·editor 내부 교체의 구분 방법을 정한다.
- 재시도, 중복 이벤트, 기존 문서 교체 취소, 저장 중 추가 편집을 포함한 상태 전이와 무효화 조건을 표로 확정한다.
- Word/HTML 출력 경로는 직접 접근 가능한 고정 exporter/API가 확인되면 native bridge로 연결하는 방식을 우선한다. 이 경로가 없으면 기존 Blob 다운로드의 생성 주체·파일명·형식을 식별하여 전용 WKDownload 처리 가능성을 실제 WKWebView에서 검증한다.
- 둘 중 어느 방식이든 exporter 호출 전 입력 확정, 실제 파일 저장 완료·취소·오류 통지, 원본 dirty state 보존과 macOS 최소 지원 기준을 만족해야 한다. core/bundle 변경 없이는 만족할 수 없으면 실패 원인과 범위 조정안을 보고한다.

### 산출물과 완료 기준

- `mydocs/working/task_m010_516_stage1.md`: 재현 결과, API 근거, 상태 소유권, 세션·요청 식별자 계약, Word/HTML 경로 선택과 테스트 위치
- 필요 시 본 구현계획서의 구체적인 파일·타입·이벤트 이름 보정
- 실행하지 못한 환경은 미검증으로 기록하고, 정적 분석 결과와 실행 증거를 구분한다.
- Stage 2가 사용할 초기 동기화·교체·dirty 메시지 및 stale response 방어 계약이 결정되어야 한다.
- 제품 소스는 이 단계에서 변경하지 않는다. 진단 산출물과 임시 runner는 task 전용 `build.noindex/`에 둔다.

### 검증과 커밋

- source/bundle provenance 확인, 기존 앱 또는 준비된 개발 앱으로 재현표 실행, `git diff --check`
- 커밋: `Task #516 Stage 1: 새 문서와 내보내기 상태 계약 확정`

## Stage 2. 새 문서 세션과 편집 상태 동기화

### 작업

- `DocumentViewerStore`와 문서 세션 상태 모델에 준비 대기, 새 문서, 기존 문서, 교체·실패를 표현한다.
- `RhwpStudioHostBridgeScript`에 Stage 1에서 검증한 초기 handshake와 생성·교체·편집 이벤트 전달을 연결한다. 메시지에는 현재 WebView load 및 editor 세션에 대응할 식별 정보를 포함한다.
- `RhwpStudioWebView.Coordinator`가 native 파일 요청과 editor 내부 생성·교체 통지를 구분하여 Store에 반영하도록 한다.
- `updateNSView`/`update`의 파일 reload 판정과 metadata 갱신을 분리한다. 동일 세션의 편집·파일명 갱신·첫 저장으로 reload가 발생하지 않게 한다.
- 기존 파일에서 새 문서로 교체하는 경로는 이전 원본과 보호 metadata를 제거한다. 교체 취소 시 기존 문서와 source를 유지한다.
- `document-edited`를 새 문서에서도 처리하되, 준비 대기·다른 세션·단순 내보내기 이벤트는 잘못 dirty로 처리하지 않는다.
- 새로운 순수 상태 모델은 `HostAppTests`에 직접 포함하고, 필요한 경우 `project.yml`의 source 목록을 추가한다. Store/Coordinator의 실제 연결은 WKWebView 통합 검증으로 보완한다.

Stage 2에서 공개 `getSelectionContext`의 epoch·changeSeq를 실제로 확인하여 일반 상태 갱신에 사용했다. `getDocumentState`의 전체 export/SHA는 첫 등록·epoch 교체에만 수행한다. 고정 bundle의 렌더 준비 표시를 `ready`로 분리했으며 이는 source·보호 분류의 근거가 아니다. 상세 구현·검증과 `editorOnly`의 후속 저장 계약은 [Stage 2 보고서](../working/task_m010_516_stage2.md)를 따른다.

### 검증과 완료 기준

- 초기 생성 이벤트가 구독 전/후에 발생하는 두 경우 모두 문서가 한 번 등록된다.
- 초기 입력, 반복 SwiftUI 갱신, 동일 세션 metadata 변경에서 reload가 발생하지 않고 내용이 유지된다.
- 기존 문서 A → 새 문서 B에서 A의 늦은 편집·준비 완료 통지가 B의 상태를 덮어쓰지 않는다.
- 새 문서가 native dirty state와 도구 활성 상태에 반영되고, 교체 취소 시 A의 상태가 유지된다.
- 변경한 상태 모델·bridge 동작 테스트와 HostApp compile이 통과한다.
- 산출물: 상태 모델·Store·bridge·Coordinator 연결, 관련 테스트, `task_m010_516_stage2.md`
- 커밋: `Task #516 Stage 2: 새 문서 세션과 편집 상태 동기화`

## Stage 3. 첫 저장·후속 저장과 native 문서 명령 연결

### 작업

- `requestSaveDocument`, `requestSaveAsDocument`, `PendingSaveRequest`와 응답 검증이 파일 bytes 유무 대신 유효한 편집 세션과 source 계약을 사용하게 한다.
- 새 문서는 기존 `DocumentSaveFormat` 규칙에 따라 저장 패널을 열고, 형식별 exporter·byte count·signature·원본 보호·atomic write 검증을 거친다.
- Coordinator와 Store의 `recordSavedDocument`에서 기존 payload가 없던 첫 저장도 처리한다. 새 URL·bytes·파일명·형식을 등록하면서 editor 세션과 입력 내용을 보존한다.
- 패널 선택, export와 write 경계에서 세션·요청을 확인하고 중복 저장을 제어한다. snapshot 이후 편집과 저장 완료 통지의 순서는 Stage 1 계약을 적용한다.
- PDF 요청, 문서 도구 활성 판정, 닫기·앱 종료 확인을 유효한 편집 세션과 dirty state에 연결한다.
- `notifySaved` 실패는 durable write 성공과 구분하며, 원본 보호·HWP3 정책은 기존 검증을 통과해야 한다.

### 검증과 완료 기준

- 새 문서 HWP/HWPX 첫 저장과 재열기, 각 형식의 후속 Command+S가 내용·경로·형식을 보존한다.
- 메뉴·단축키·종료 확인의 저장 경로에서 취소·쓰기 실패 시 입력과 창이 유지된다.
- 저장 중 중복 요청, 문서 교체, 늦은 응답 및 export 이후 추가 편집에서 잘못된 write 또는 clean 전환이 없다.
- 기존 파일 → 새 문서 저장 후 이전 원본 hash가 유지된다.
- 새 문서 PDF에 현재 한글 입력과 페이지가 반영되고 원본 dirty state가 유지된다.
- 기존 HWP/HWPX, 암호 문서 평문 복사본, HWP3 변환 복사본 관련 테스트와 HostApp build가 통과한다.
- 산출물: 저장·명령 연결 및 검증, `task_m010_516_stage3.md`
- 커밋: `Task #516 Stage 3: 새 문서 저장과 종료 확인 연결`

## Stage 4. Word·HTML native 내보내기 연결

### 작업

- Stage 1에서 검증한 WKDownload 경로를 전용 내보내기 서비스로 연결한다. `exportHtml` RPC는 고정본에 없으며, DOC/HTML Blob 모두 실제 다운로드 성공을 확인했다. 일반 파일 열기·PDF·공유와 요청 상태를 혼용하지 않는다.
- `.doc`와 `.html`의 출력 형식, MIME, 기본 파일명과 저장 패널 확장자를 한 계약으로 묶는다. upstream의 HTML 기반 .doc 의미를 유지한다.
- 명령 실행 시 editor 입력을 확정하고 현재 세션의 출력만 저장한다. request ID, 세션 변경, 중복 실행, WebContent 종료와 다운로드 실패를 처리한다.
- native 파일 저장 권한과 destination 선택을 처리한다. WKDownload destination은 존재하지 않는 staging 파일을 제공하고 완료 검증 후 선택한 destination에 게시한다. 취소·실패 시 이번 요청의 임시 산출물만 정리하며 기존 destination을 먼저 삭제하지 않는다.
- `file:export-doc`와 `file:export-html`을 비변경 명령으로 분류한다. 내보내기 성공 시 원본 source·형식·최근 문서·저장 완료 통지를 변경하지 않는다.
- 사용 가능한 API/OS 동작이 Stage 1 가정과 다르면 경로 선택 근거와 검증 결과를 갱신한다.

Stage 4에서는 공개 exporter의 anchor 클릭을 잠시 포착해 Blob을 보존하고, native에 정확한 URL을 등록한 뒤 다운로드를 시작했다. WKDownload 완료 후 원본·출력 검증과 atomic 게시를 수행한다. 구체적인 계약, 조합 입력과 실패 검증은 [Stage 4 보고서](../working/task_m010_516_stage4.md)를 따른다.

### 검증과 완료 기준

- 새 문서와 기존 HWP/HWPX에서 각각 Word·HTML 출력이 생성되고 현재 텍스트·대표 서식이 포함된다.
- 한글 조합 및 서식 입력 확정 직후 내보내기에서 마지막 입력이 빠지지 않는다.
- dirty/clean 문서의 내보내기 전후 원본 상태가 같고, 편집 후 내보낸 문서를 닫으면 저장 확인이 유지된다.
- 저장 패널 취소·쓰기/다운로드 실패·문서 교체·중복 요청 후 원본과 기존 destination을 부당하게 삭제하거나 손상시키지 않는다.
- 호환 앱에서 열기 결과를 기록한다. 실제 Word 실행이 불가능하면 HTML 구조·내용 검사로 확인한 범위와 Word 실행 미검증을 구분한다.
- 관련 자동 테스트, HostApp build와 WKWebView 실제 내보내기 검증이 통과한다.
- 산출물: 내보내기 서비스·bridge/delegate 연결, 테스트, `task_m010_516_stage4.md`
- 커밋: `Task #516 Stage 4: Word와 HTML native 내보내기 연결`

## Stage 5. 통합 회귀와 문서 정리

### 작업

- 최종 변경 상태에서 HostAppTests, HostApp build, bundle asset 검증과 문서 저장·재열기 smoke를 실행한다. 직전 단계 결과는 해당 코드가 바뀌지 않았다면 재사용하고, 새로운 실패·변경에 필요한 검증만 반복한다.
- 새 문서 시작부터 저장·재편집·다른 형식 저장·PDF/Word/HTML 내보내기·종료까지 실제 사용자 흐름을 확인한다.
- 기존 파일 열기 실패 복구와 새 문서 교체, 암호 문서·HWP3 보호 정책을 회귀 확인한다.
- 이슈 #516 완료 기준별로 증거 파일, 실행 명령, 결과와 미검증 환경을 연결한다.
- `project_architecture.md`의 문서 상태·저장·내보내기 책임을 갱신한다. 반복 가능한 새 smoke 절차가 필요한 경우에만 빌드 매뉴얼을 보완한다.
- task 소유 임시 runner·문서·앱 산출물의 보존 필요성을 정리하고, 다른 작업의 원본과 설치본을 유지한다.

### 검증과 완료 기준

- 승인된 이슈 범위의 회귀가 해소되고 각 완료 기준에 실행 증거나 명시적인 환경 제한이 남는다. 핵심 저장·내보내기 동작이 미검증이면 검증 완료로 보고하지 않는다.
- 대표 HWP/HWPX output의 컨테이너, 페이지 수와 본문이 재열기에서 확인된다.
- Word(.doc)의 HTML 기반 형식 한계와 실제 호환 앱 실행 결과가 구분된다.
- 문서 내용이 실제 상태·command 계약과 일치하고 원본 fixture는 변경되지 않는다.
- 산출물: `task_m010_516_stage5.md`, architecture 및 필요한 smoke 문서, 최종 보고에 사용할 검증 결과
- 커밋: `Task #516 Stage 5: 저장과 내보내기 통합 회귀 검증`

## 공통 검증과 산출물 관리

모든 명령은 task516 분리 worktree에서 실행한다. 현재 구현계획 작성 단계의 검증은 문서 diff·참조·단계 구성에 한정한다.

구현 단계 공통 명령:

```bash
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
# Spotlight 경로 테스트의 선행 앱을 테스트와 같은 DerivedData에 준비한다.
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp \
  -configuration Debug -derivedDataPath build.noindex/task516/DerivedDataTests \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests \
  -configuration Debug -derivedDataPath build.noindex/task516/DerivedDataTests \
  CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp \
  -configuration Debug -derivedDataPath build.noindex/task516/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/task516/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
git diff --check
```

- 변경한 target source 설정은 `xcodegen generate` 이후 검증한다. 현재 HostAppTests는 선택한 서비스 소스를 직접 포함하므로 새 순수 상태 모델과 필요한 framework dependency를 `project.yml`에 명시한다.
- 새 worktree의 generated framework는 고정 의존성과 ABI를 확인하여 준비한다. 의존성 조회·생성 산출물 누락을 코드 회귀로 기록하지 않는다.
- 행동 검증을 우선한다. Swift 상태 전이, JavaScriptCore에서 실행 가능한 bridge 함수, 필요한 WKWebView 통합 harness를 사용하며 단순 source 문자열 포함 검사를 성공 근거로 삼지 않는다.
- 앱·확장과 테스트 산출물은 `build.noindex/task516/`에 둔다. stage별 진단·출력은 그 아래 stage 폴더로 분리한다.
- native renderer를 바꾸지 않는 현재 범위에서는 renderer 전체 회귀를 반복하지 않는다. 변경 범위가 renderer 해석까지 넓어지면 범위를 보고하고 매뉴얼의 render smoke를 적용한다.
- 시스템 Finder 확장 등록이 필요하면 표준 smoke 절차 안에서만 수행하고 종료 시 개발 산출물 등록을 해제한다.
- 최소 지원 macOS와 제보 환경의 실제 실행 여부를 기록하며 최신 OS 성공을 다른 OS 실행 증거로 대체하지 않는다.

## 단계 승인과 최종 인계

각 Stage 완료 후 검증 결과와 해당 `_stageN.md`를 소스·문서와 함께 커밋하고 다음 Stage 승인을 요청한다. 실패가 있으면 같은 단계에서 원인을 해결하거나 범위·환경 제한을 보고하며 완료로 표시하지 않는다.

Stage 5 완료 승인 후 `task-final-report` 절차에서 최종 결과보고서, 오늘할일 완료 처리와 `publish/task516` 대상 게시 및 `devel` PR을 준비한다. 현재 이슈는 구현·검증 진행 중이므로 close하지 않으며 public release는 별도 절차로 진행한다.

## 승인 요청 사항

2026-09-10 같은 스레드의 “진행해줘” 승인에 따라 Stage 5 통합 회귀와 문서 정리를 완료했다. 최종 제품 소스의 자동 201개·통합/회귀 결과를 재사용하고 실제 native 패널과 종료 버리기 검증을 보완했다. 초기 진단 실패와 환경 제한을 [Stage 5 보고서](../working/task_m010_516_stage5.md)에 구분했다. 같은 스레드에서 최종 보고·PR 게시를 승인받았다. 최신 devel 통합 후 218개 테스트와 빌드가 통과했으며 [최종 보고서](../report/task_m010_516_report.md)에 기록했다.


## Stage 6. PR 보완 — 확인된 새 문서의 일반 저장

사용자가 첫 저장 보호 경고를 제보하고 “보완을 진행해줘”로 수정을 승인했다. #516 / PR #517 안에서 다음 범위로 수행한다.

- documentStart에 공개 automation 확장 명령을 통해 문서 생성 성공과 documentGeneration을 관찰한다. 파일명·본문·dirty만으로 새 문서를 판정하지 않는다.
- 생성이 확인된 현재 세션만 newDocument로 분리해 plain 저장 정책을 사용한다. 복구·파일 로드·관찰 전 생성·관찰 실패는 기존 unknown/native 보호 정책을 유지한다.
- source 분리, 첫 저장 뒤 native 연결, 저장 전후 검증에 같은 분류를 적용한다.
- 생성/취소/실패/복구 세대 테스트와 실제 시작·메뉴 새 문서의 경고 없는 HWP/HWPX 저장·본문 재열기를 확인한다. 기존 보호 정책 및 출력 회귀도 확인한다.
- 보완 보고서와 최종 보고서를 갱신하고 PR #517에 게시한다. 실행 중인 사용자 앱의 입력을 강제 종료하거나 덮어쓰지 않는다.

Stage 6 보완을 완료했다. [보완 보고서](../working/task_m010_516_stage6.md)에 221개 테스트·실제 생성/저장·Word/HTML 회귀와 초기 진단 실패를 구분했다. 같은 PR #517에 반영한다.
