# Task M020 #342 구현계획서

## Stage 1: 격리 설치·시험 corpus와 추출 smoke

재현 가능한 Rust fixture generator와 단계별 smoke CLI를 만든다. 파일명에 없는 고유 본문 단어를 가진 HWP3/HWP5/HWPX, 대조/빈/보호/손상/한도 입력을 생성한다. build.noindex에는 중간 산출물만 두고 실제 corpus는 Documents 아래 새 격리 폴더를 사용한다. 기존 앱과 provider/색인 상태를 기록한다. 별도 Applications 하위 폴더의 후보 앱을 설치하고 mdimport 발견/선택/본문을 확인한다.

## Stage 2: 실제 색인·수정·삭제·교체 검증

mdimport -t 결과와 실제 mdimport -i/mdfind를 구분한다. 이전 본문 단어가 없는 대조군과 파일명만으로는 찾을 수 없는 양성군을 검사한다. 문서 수정/보호·손상·한도 전환/삭제, 앱 미실행/첫 실행/로컬 앱 교체 이후 재색인을 수행한다. 각 검색은 제한된 시간 동안 정확한 경로 집합을 기다리며 timeout은 실패로 기록한다.

## Stage 3: 복원·정리·실행 결과와 증거 인계

실제 Finder 본문 검색의 Before/After screenshot을 수집할 수 있으면 공개 자료에 첨부한다. 사용자 기존 창/문서 내용은 게시하지 않는다. 새 설치본·corpus와 등록만 정리하고 원래 provider 상태와 기존 앱 hash를 확인한다. 최초 설치와 로컬 교체는 공개 Sparkle 업데이트와 구분한다. macOS 12 runtime은 미실행으로 기록한다.

## 수용 기준

실제 사용 importer 경로·metadata 본문·mdfind 경로 집합과 변경/삭제/복원 결과를 재현 명령 및 보고서에 남긴다. 전체 Spotlight index reset, daemon kill, 기존 앱 교체 또는 사용자 데이터 삭제는 하지 않는다. 검증 산출물은 합성 데이터만 포함한다. 신규 표준 smoke 경로의 등록은 목적과 수명을 제한하고 cleanup 명령으로 복구할 수 있어야 한다.
