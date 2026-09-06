# Task M020 #469 Stage 2 완료보고서

full sync는 complete core build 뒤 writer/verify/minimal decoder를 실행하고 golden을 stage하며 summary에 기록한다. PR CI는 native producer/Swift gate를 universal build 전에 실행하여 계약 오류를 먼저 차단한다. release rehearsal/publish와 로컬 package/release helper, source preflight는 verifier만 사용한다. CI golden 경로에는 공식 setup-python v6로 Python 3.12를 준비한다. 로컬 최소 버전은 Python 3.11이다.

classifier에 producer/helper/fixture 경로를 명시했다. isolated temporary Git repo에서 7종 golden 경로가 macOS gate를 켜고 pixel smoke는 추가하지 않는 것을 검증했다. 생성 JSON은 `.gitattributes`에서 generated로 표시하여 PR 기본 diff를 접을 수 있게 했다.

검증: helper unittest 16개(7개 path subcase 포함), 모든 shell syntax, 모든 workflow YAML parse, writer/verifier help, diff check 통과. writer의 실제 자동화 호출은 full sync 한 곳에만 있고 PR의 호출은 help, release는 verifier뿐이다. 공개 release/full sync workflow를 실제 dispatch하지 않았다.
