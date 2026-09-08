# Task M020 #513 Stage 4 — 병합 전 최신 개발 후보 검증

## 범위와 기준

작업지시자가 관련 PR을 검증 후 순서대로 병합하되 #513 및 상위 #337 이슈를 열린 상태로 유지하도록 승인했다. 선행 #341의 rg 의존 제거, #513 Stage 3.2 외부 변경 오판 방지 및 당시 최신 devel을 통합했다. 이번 단계에서는 새로운 최초 설치 원인 비교나 제품 수정을 수행하지 않는다.

## 새 개발 후보 검증

기존 버전 0.1.11을 유지하여 package-release.sh로 universal Release 개발 zip을 새로 생성했다. source/ABI portable 검사, golden 검사, Release build, 앱·확장·importer universal 검사와 endpoint 검사가 통과했다. ad-hoc strict 서명 확인 및 rg 없는 표준 PATH의 직접 callback 11개 + NDEBUG 양성/음성 2개가 통과했다.

- 운영 회귀 23 tests, bundle 회귀 5 tests: PASS.
- 새 후보 build, portable source/ABI, direct callback 13사례: PASS.
- 새 direct 격리 시험의 일반 TXT 자동 색인 대조: 60초 내 검색되지 않아 FAIL.
- 설치·첫 실행·기존 문서 자동 본문 검색: 환경 전제 실패로 미실행. importer 자동 발견 실패로 확대 해석하지 않는다.
- 소유 시험 경로/프로세스/catalog 정리 및 빌드 전 기존 앱 hash/provider 집합 보존: PASS.
- Python 구문, 변경 문서 상대 파일 링크 5개, 공개 요약의 경로 제외, git diff: PASS.

[최신 후보 결과 JSON](../report/assets/task_m020_513/pre-merge-candidate-results.json)에 source commit과 산출물 SHA 및 단계 결과를 기록했다. 원시 로그/경로는 build.noindex 안에 보존하며 공개하지 않는다. 설치 단계로 진행하지 않았으므로 새 Spotlight 검색 성공 화면도 없다.

## 병합 판단과 남은 범위

최신 코드의 개발 후보 빌드·직접 추출과 도구 회귀는 검증했지만 일반 최초 설치 수용 기준은 여전히 미완료다. 이번 PR은 자동 판정 도구와 조사 기록을 통합하는 범위로 병합하며 제품 해결을 주장하지 않는다. 새로운 사용자 환경과 최종 서명·공증 후보, macOS 12/Intel 실행 검증은 #513 및 #337 이슈에 남긴다. 공개 배포·버전 상향·새 최초 설치 해결 작업은 시작하지 않는다.
