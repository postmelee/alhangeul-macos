# Task #537 최종 결과보고서 — 저장 후 창 닫기·앱 종료 정상화

기존 파일에서 Studio의 새 문서를 만든 뒤 저장해도 파일명이 연결되지 않고 종료의 저장 경고가 반복되는 문제를 수정했다. 원인은 문서 bytes가 nil로 분리될 때 SwiftUI의 revision 기반 `.id`가 WKWebView를 교체하여 같은 loadID 안에서 epoch/sequence를 초기화한 것이다. 기존 Store는 새 응답을 오래된 것으로 거부했다.

## 구현

`DocumentViewerView`의 불필요한 `.id`를 제거했다. 명시적 열기/재시도는 기존 Coordinator의 loadID 처리로 유지하며, 저장/내부 생성은 같은 편집기에서 진행한다. 세션의 token·epoch·sequence 검증이나 실패 시 창 보존을 완화하지 않았다.

실제 ContentView·Store·Coordinator·종료 controller·bundled Studio를 함께 사용하는 반복 가능한 smoke를 추가하고 PR macOS CI에 연결했다. 기존 단독 Coordinator 진단에서는 원래 결함이 재현되지 않았기 때문에 SwiftUI 생명주기를 회귀 경계로 포함했다. 입력은 읽기 전용 fixture, 저장은 실행별 고유 출력 경로를 사용한다.

## 검증과 검토

| 검증 | 결과 |
|------|------|
| 수정 전 동일 통합 테스트 | WKWebView 유지 검사 실패, exit 1 — 결함 검출 확인 |
| 수정 후 통합 테스트 | 31개 PASS, exit 0 |
| HostAppTests | 224개 PASS |
| HostApp Debug | BUILD SUCCEEDED |
| Studio 자산·공통 AppKit 경계 | PASS |
| actionlint·Python 구문·diff 공백 | PASS |
| main → 작업 브랜치 내용 gate | PASS, 역사만 다른 transport merge |

HWP/HWPX 각각 새 문서의 객체/epoch 일치, 취소·쓰기 실패, 최초/반복 저장, 재열기, 창 닫기 취소·저장 실패, 종료 취소·저장 허용, 저장 후 실제 창 닫힘, 버리기와 원본 보존을 확인했다. core 재열기로 컨테이너·한글 표식을 검사했다. PR head의 CI와 diff 검토는 게시 후 PR 코멘트에 기록한다.

## 증거

- [Stage 1](../working/task_m010_537_stage1.md): 실제 SwiftUI와 단독 Coordinator의 재현 차이
- [Stage 2](../working/task_m010_537_stage2.md): 구현·31개 통합 검증
- [Stage 3](../working/task_m010_537_stage3.md): 수정 전 실패 대조와 정리
- [수정 전 실제 저장 경고](../working/assets/task_m010_537/quit-save-before.png)
- 로컬 `build.noindex/task537/`: build/tests, 이전/이후 재현, 소유 앱 정리 기록
- 로컬 `build.noindex/studio-lifecycle-l2fxnv07/`: 최종 31개 실행 및 cleanup 로그

## 제한과 후속

검증 환경은 macOS 26.5.2 arm64다. 진단은 실제 제품 UI 구성요소를 사용하지만 입력·저장 destination·NSAlert 응답·종료 reply를 주입한다. 물리 IME·실제 NSSavePanel·signed sandbox·새 DMG 수용으로 일반화하지 않는다. macOS 12 실행은 미검증이다.

사용자 설치본 0.2.0(18)과 활성 제공자를 유지했고 개발 산출물은 이번 소유 경로만 등록 해제했다. #525 복구 후보 잔존은 별도다. #532 에서 새 배포 후보 검증을 계속하며 #513 / #337 / #520 및 #535 는 별도 수용 기준이 충족될 때까지 열린 상태로 유지한다. 기존 v0.2.1 태그·DMG 및 공개 배포를 변경하지 않았다.
