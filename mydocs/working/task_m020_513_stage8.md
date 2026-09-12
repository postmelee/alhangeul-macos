# Task M020 #513 Stage 8 — 동일 버전 재설치 식별 보완

## 근거와 변경

[#520 Stage 5](task_m900_520_stage5.md)에서 같은 경로·버전·importer mtime의 요청 기록 유지와 기존 HWP3 누락, 해당 키만 분리한 회복을 관찰했다. 새 설치 객체를 기존 설치와 구분하지 못하는 중복 방지 조건을 보완했다. 과거 비동기 실패 전체를 이 원인으로 확정하지 않는다.

importer 디렉터리의 볼륨 UUID·inode·생성 시각(나노초)을 receipt에 추가했다. UUID 없는 볼륨에서는 device 번호로 비교하며 재마운트에 따른 추가 요청 가능성을 허용한다. 파일 식별 조회/발견/요청 실패는 완료 기록을 만들지 않는다. 구형 receipt는 성공한 요청 한 번으로 전환하며 일반 앱 재실행은 계속 중복을 생략한다. 사용자 설정 초기화, bundle 변경 시각 조작, 전역 색인 초기화는 제품에 추가하지 않았다.

Apple의 [stat 필드](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/stat.2.html)와 [fileResourceIdentifier의 재부팅 지속성 한계](https://developer.apple.com/documentation/foundation/urlresourcekey/fileresourceidentifierkey)를 확인했다. 파일 경로/내용/시각이 같아도 복사로 새 inode가 생기는 조건을 실제 임시 디렉터리 테스트로 검증한다. 같은 디렉터리 객체를 유지한 채 내부 파일만 덮어쓰는 작업 전체를 새 설치로 판정한다고 주장하지 않는다.

## 검증

- HostApp Debug build PASS (macOS 26.5.2 arm64, 최소 배포 대상 12.0 유지).
- SpotlightReindexServiceTests 20개 PASS: 실제 같은 경로 제거/복사와 mtime 보존, receipt 유지 상태에서 두 번째 요청, 일반 재실행 생략, 구형 receipt 전환/실패 보존, 다른 설정 보존, 발견/시작 호출 연결.
- `verify-spotlight-importer.sh` 번들 계약과 직접 callback 13사례 PASS.
- `check-no-appkit.sh`, `git diff --check` PASS.

위 테스트의 외부 발견/요청은 주입한 동작이다. 실제 Spotlight 검색 PASS와 구분하고 Stage 9에서 시스템 검증을 진행한다. 공개 v0.2.0 DMG에는 이 수정이 없으며 macOS 12 실행·새 서명 공증 후보 검증은 수행하지 않았다.
