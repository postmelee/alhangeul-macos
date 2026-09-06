# Task M900 #474 Stage 2 완료보고서

## 연결과 운영 규칙

main/devel 대상 PR CI의 script-checks는 complete history checkout 후 최신 origin/main과 event의 실제 PR head SHA를 비교한다. GitHub merge checkout HEAD를 source로 쓰지 않는다. 문서-only PR에도 적용하고 native-viewer-editor는 제외한다. release rehearsal/publish와 local release preflight는 최신 main/devel을 fetch하여 branch invariant를 검사한다. public tag identity와 최신 branch 인계 상태는 분리한다.

매뉴얼에 transport-only 이력 허용, 실제 main hotfix·문서·workflow 변경 owner의 devel 인계 책임과 다음 개발/release 전 완료 시점을 명시했다. helper는 back-merge/history rewrite를 자동 실행하지 않는다.

## 검증

- Git fixture 17개 통과. GitHub merge checkout은 통과해도 실제 PR source head는 누락 main content로 차단되는 재현과 Actions summary env 검증을 추가했다.
- 실제 CI env를 켠 golden fixture 16개도 통과. 선행 #469 CI 출력 환경 보완을 merge로 상속했다.
- 모든 shell syntax, workflow YAML parse와 변경 workflow 4개 actionlint(semantic 검사) 통과.
- release helper help와 diff check 통과. release/full sync를 dispatch하지 않았다.
