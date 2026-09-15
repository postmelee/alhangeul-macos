# Task M900 #532 Stage 1 — 새 패치 기준과 버전

PR #531 병합 devel `08fa297785fda59082c9b263ff32b75764d99763`에서 시작했다. 최신 공개 v0.2.0(18), upstream 최신/고정 core·Studio v0.8.6 (`f1f9c6ae58344ee9368996d3543f76b9345cf227`)을 확인했다. main 콘텐츠 gate는 transport-only 이력만 남고 실제 누락 없이 PASS다.

HostApp·Quick Look·Thumbnail·Spotlight의 Info.plist를 0.2.1(19)로 정렬했다. rehearsal/publish의 기본 version은 0.2.1, previous ref는 v0.2.0이며 core pin은 유지했다. plist 읽기 대조·`python3 scripts/ci/check-spotlight-bundle.py`·`git diff --check` PASS. 공개 앱·태그·DMG는 변경하지 않았다.

포함 merge 범위는 #524 / #526 / #529 / #530 / #531 이며 #529 가 #528 공개 기록 콘텐츠를 인계한다. 사용자 변화는 #530 의 재설치 재색인 복구다. #531 은 배포 검증, 나머지는 기존 공개 운영/기록이며 앱의 새 기능으로 나열하지 않는다. 실제 후보 SHA는 준비/main PR 병합 후 고정한다.
