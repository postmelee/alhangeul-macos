# Task M020 #469 구현계획서

## Stage 1 — 실제 producer와 검증 도구

Rust example은 sample/page를 받아 render tree JSON을 stdout에 반환한다. Python orchestration은 current lock/Cargo resolved source와 sample SHA256를 검사하고 producer output을 canonical JSON으로 만든다. manifest에는 recipe version, source provenance, sample/page와 golden SHA256를 둔다. writer는 검증 성공 후에만 tracked 파일을 갱신한다. verifier는 manifest·실제 output·tracked golden·Swift decode를 확인하고 쓰지 않는다. Swift contract runner는 TextRun과 대표 node가 실제 decode됐는지도 확인한다.

격리 fixture는 metadata/pin/sample/hash drift, canonical 숫자 보존, stale 실패 시 파일 불변, 명시 writer 동작, malformed known 진단을 검사한다. 실제 producer 두 번의 출력이 같은지 확인한다.

## Stage 2 — 자동화와 정책

upstream full sync의 build 이후 writer/decoder 검증 및 golden stage/summary를 연결한다. PR CI/release rehearsal/publish/source preflight에는 verifier만 연결한다. helper/fixture 변경이 필요한 macOS 계약 검증을 켜도록 classifier에 경로를 명시한다. 일반 검증이 writer를 부르지 않음을 확인한다.

검증: shell/Python/Rust syntax, workflow YAML, isolated fixtures, classifier 결과. 운영 문서와 단계 보고서 커밋.

## Stage 3 — 통합 검증과 PR

실제 `update` 재실행 후 tracked golden byte 불변, `verify` 성공, stale fixture nonzero 및 파일 불변, 최소 decoder와 native smoke를 확인한다. 실제 Rust producer build는 source pin에 고정되며 staticlib reference hash를 갱신하지 않는다. 보고서·오늘할일을 커밋하고 `publish/task469`에서 devel 대상 PR을 생성한다. 선행 PR #503/#504와 자신의 `d527be8..HEAD` 범위를 명시하고 merge하지 않는다.

## Stage 4 — PR #505 리뷰 보완

Python 3.11+ 존재/버전 검사를 verifier의 check-environment 모드로 공용화하여 local release/package의 출력 초기화·cleanup trap·Rust build 전에 실패시킨다. 격리 fixture로 missing/old Python 차단과 기존 staging 보존을 검증한다. 단일 파일 Swift consumer, tree hash의 진단 역할, feature 순서 provenance, 15종 실제 coverage와 미포함 variant 한계를 문서화하고 classifier의 example 중복 사유를 없앤다. producer-before-universal 순서는 실제 CI의 host build 재사용 근거에 따라 유지한다. 보완 후 실제 golden 검증과 관련 fixture를 실행하고 결과 코멘트를 게시한다.
