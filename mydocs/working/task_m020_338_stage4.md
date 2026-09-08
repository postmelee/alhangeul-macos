# Task M020 #338 Stage 4 — UTI 검증 참조와 PR 운영 정보 보완

HostApp Info.plist를 UTI 진실 원천으로 명시하고 후속 PR #510의 자동 대조 스크립트를 안내했다. 이 설계 PR 자체에 아직 없는 스크립트를 상대 파일 링크로 연결하지 않고 구현 PR을 참조한다.

HostApp의 9개 UTI가 문서 목록에 모두 있음을 plist 기반으로 확인했고 git diff --check를 통과했다. 제품 코드와 공개 자산은 변경하지 않았다. PR #507의 비어 있던 milestone·label은 v0.2 / enhancement / kind:architecture로 정렬한다. 선행 계약 문서의 forward reference는 후속 스택에서 구체화되는 구조를 유지한다.
