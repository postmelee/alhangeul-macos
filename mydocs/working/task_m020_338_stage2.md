# Task M020 #338 Stage 2 완료보고서

## importer 구조·지원 정책·검증 흐름 설계

- mydocs/tech/spotlight_importer_design.md에 CFPlugIn 구조, bundle/UTI 9종, UI/외부 자원 없는 경계, metadata·파일 읽기 정책을 정리했다.
- 직접 bundle 호출, mdimport test, 실제 index/mdfind를 분리했다. 기존 설치·문서를 보존하고 격리 설치와 복원 증거를 남기는 절차를 정의했다.
- macOS 12 compile과 runtime, 로컬 교체와 실제 Sparkle, 개발 산출물과 공증 배포본을 구별했다.
- importer 서명·universal·package/CI는 #341 입력, 검색·수정·삭제·교체·정리는 #342 입력이다. 본문 정책은 #339 계약 문서로 연결하고 이 단계에서 임의 구현하지 않았다.
- 기존 앱/코드/등록은 변경하지 않았다. git diff --check 통과.
