# Task M020 #342 Stage 1 완료보고서

## 격리 설치·시험 corpus와 추출 smoke

## 구현과 실제 설치

합성 HWP3/HWP5/HWPX 및 빈/보호/손상/한도/수정 corpus generator와 단계별 설치·추출·색인·복원 CLI를 추가했다. 검색어가 파일명에 없고 수정 전후 검색어가 서로 포함되지 않게 구성했다. 일반 txt 양성 대조군을 별도로 사용한다.

기존 /Applications와 사용자 Applications의 앱을 보존하고 임의 식별자를 가진 새 하위 디렉터리에 #341 개발 패키지를 복사했다. ad-hoc 서명 무결성을 확인했다. 설치/첫 실행의 보통 등록은 60초 내 importer를 발견하지 못했다. 자체 빌드 후보에 Xcode와 같은 개발 등록 및 timestamp 갱신을 적용한 뒤 실제 mdimport가 후보 경로를 선택했다.

## 검증

- Rust fixture generator 실제 실행, cargo fmt, Python 구문, git diff 검사 PASS.
- 실제 mdimport HWP3/HWP5/HWPX 세 형식의 본문·UTI 확인 PASS.
- mdimport 출력은 OpenStep plist이고 -o는 append하므로, 재실행마다 출력 삭제 후 plutil JSON 변환으로 판독한다.
- 일반 설치/첫 실행 발견 MISS, 개발 등록 발견 PASS를 분리했다.
- 실제 색인 환경 대조와 파일 전환·교체·정리는 Stage 2/3에서 판정한다.

## 기존 기록 보완

#341 단계에서 명시적으로 설치하지 않았지만 Xcode가 build.noindex의 Debug/Release 앱 importer를 자동 발견 가능하게 등록했다. 두 산출물은 이번 작업이 만든 앱임을 확인하고 등록 해제 후 제거했다. 기존 사용자 설치본은 그대로 보존했다. build.noindex만으로 importer 등록이 격리된다는 보장은 하지 않는다.
