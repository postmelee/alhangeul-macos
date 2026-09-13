# Task #537 구현계획서

## Stage 1 — 원인과 회귀 고정

실제 고정 Studio의 `notifySaved`, 문서 상태 조회, native session 처리와 종료 확인을 비교한다. 저장 전후 서로 다른 dirty 상태가 관찰되는 경우를 재현하는 실패 테스트를 만들고 원인을 기록한다.

## Stage 2 — 저장 완료 상태 동기화

원인이 확인된 Host bridge 경계만 수정한다. token/load/epoch/change sequence 검증을 유지하며 저장 실패·취소나 동시 편집을 성공으로 덮지 않는다. HWP/HWPX 저장과 반복 foreground/background 조회의 회귀를 실행한다.

## Stage 3 — 통합 검증·PR·병합

HostApp Debug 빌드, 관련 HostApp 테스트, 고정 bundled Studio를 사용한 저장 후 refresh·닫기/종료 통합 검증을 수행한다. 가능하면 실제 UI 증거를 남긴다. HF PR 템플릿과 최종 head 링크로 보고서를 게시하고 자체 리뷰와 CI 통과 후 승인된 병합·부산물 정리를 수행한다.

## 운영

산출물은 `build.noindex/task537/`에 둔다. 사용자 설치 앱·문서·설정은 변경하지 않는다. 등록된 개발 앱은 소유 경로만 해제한다. #536 의 검증 도구 변경은 이번 브랜치에 포함하지 않는다.
