# Task M900 #474 Stage 4 — PR 리뷰 보완

Public runbook에 publish/rehearsal 재실행도 각 preflight fetch 시점의 최신 main/devel 인계 완료를 요구함을 명시했다. 불변 tag identity와 branch 인계 조건을 분리하며 과거 tag를 최신 main과 같게 만들지 않는다. 로컬 release의 네트워크와 remote-tracking ref 갱신, Python 조기 검사도 설명했다.

native 브랜치는 기존 정책대로 별도 공통 수정 인계를 수행하며 적용 제외 근거를 연결했다. built-in union/binary에도 최종 tree/conflict 판정이 적용됨을 주석으로 남겼다. 요청한 summary 기록 실패는 명시 stderr와 exit 2를 유지한다. PR CI에 Python helper compileall을 추가했다.

검증: Git fixture 17개, 선행 golden/helper fixture 21개, Python compileall, workflow YAML/actionlint, diff 검증 통과. 최신 main/devel을 fetch한 뒤 실제 후보의 main content gate도 통과했다. 최초 merge-tree의 임시 Git 객체 쓰기는 sandbox가 막았고 해당 쓰기를 허용한 재실행에서 통과했다. 코드 오류나 콘텐츠 누락으로 분류하지 않는다.

로그: `build.noindex/task474/review-{git,golden-helper,content-gate}.log`. core/Cargo/FFI lock은 불변이다. 전체 stack의 head별 원격 CI와 공개 코멘트는 게시 후 확인한다.

리뷰 사실관계: classify-changes의 fetch-depth 0은 이번 작업 전 `ed325b2`에도 존재했다. 이 PR이 추가한 것은 script-checks의 전체 이력 checkout이다. partial deepen/별도 job 최적화는 shallow 거부 정책과 함께 설계할 후속 사항이며 이번 보완에서 바꾸지 않았다.
