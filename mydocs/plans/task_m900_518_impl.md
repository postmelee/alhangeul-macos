# Task M900 #518 구현계획서

## Stage 1 — 설치 검증 계약과 러너 조사

후보 출처·hash·버전·판정 스키마·권한·상태 흐름을 설계한다. 설치/빌드 없이 Spotlight 환경을 측정하는 Python helper와 자동 조사 workflow를 만든다. 별도의 Apple Silicon/Intel 새 VM을 사용한다. 조사 실행 성공과 설치 수용 PASS를 구분한다. 환경 조정은 하지 않는다.

## Stage 2 — 서명·공증 후보 설치 workflow

workflow_dispatch/workflow_call 입력은 동일 저장소의 성공한 release-publish 실행 ID, artifact ID, 소스 SHA, DMG SHA256, 기대 버전·빌드로 고정한다. 현재 배포 artifact 형식을 재사용한다. ZIP 추출 경로를 검사하고 검증 VM에서는 빌드하지 않는다. 합성 fixture는 별도 준비 job에서 생성하여 전달한다. 권한은 contents/actions read로 한정한다.

표준 자동 smoke의 prepare → environment → install → launch → automatic-search → stop-app → automatic-search → lifecycle → cleanup을 연결한다. 최초 성공 state를 별도 보존하고 보조 등록/시각 변경이 없는지 검사한다. 실패/미실행과 cleanup 실패는 release eligibility false로 남긴다. 단일 설치 경로, DMG 읽기 전용 mount, 후보 서명·공증 검증을 유지한다.

## Stage 3 — 회귀 및 배포 인계

입력/출처/추출 경로/불완전 결과/환경 불가의 거짓 PASS 회귀를 검증하고 workflow 구문·기존 smoke 회귀를 실행한다. 새 VM 환경 조사 결과를 보존하고 실제 서명 후보 미실행과 구분한다. 검증 DMG와 게시 DMG의 hash 일치, 재빌드 시 재검증, 실제 UI/업데이트 잔여 항목을 매뉴얼과 보고서에 명시한다. 하이퍼-워터폴 PR 템플릿으로 게시한다.
