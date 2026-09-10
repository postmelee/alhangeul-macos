# Task M900 #518 Stage 1 — 계약과 환경 조사 준비

## 변경

수행/구현계획과 재사용 설치 검증 설계에 후보 출처·hash·상태·책임 경계를 고정했다. 새 macOS-15 arm64/Intel VM에서 기존 등록 부재, GUI 세션, TXT 자동 검색을 측정하는 환경 조사 workflow를 작성했다. 시스템 설정을 변경하지 않는다. 환경 조사 job의 성공과 후보 설치 PASS를 구분한다.

## 검증과 상태

Python 구문 및 workflow YAML 구문을 로컬 확인했다. 원격 publish 브랜치 push의 환경 조사로 실제 결과를 수집한다. 이 문서는 조사 도구/계약 단계 기록이며 아직 러너 적합성을 통과로 선언하지 않는다. 실제 결과는 최종 보고서에 연결한다.

## 첫 조사 도구 보정

실행 34451904493에서 두 러너의 GUI 세션과 기존 등록 부재는 확인됐으나 하위 문서 폴더를 mdutil -s 대상으로 주자 `unknown indexing state`가 반환됐다. 이는 비활성 확정 근거가 아니며 TXT 시도 전 종료한 도구 결함이다. 볼륨 전체 조회와 실제 TXT 자동 검색을 판정 기준으로 보정하여 다시 측정한다. 최초 ENVIRONMENT_UNAVAILABLE 기록을 러너의 확정 실패로 인용하지 않는다.

## 실제 재조사 결과

[실행 34452311307](https://github.com/postmelee/alhangeul-macos/actions/runs/34452311307), head 958f734:

- macOS 15.7.9 arm64 / image 20260829.0321.1: ENVIRONMENT_READY, 51.34초.
- macOS 15.7.9 x86_64 / image 20260824.0482.1: ENVIRONMENT_READY, 34.12초.
- 양쪽 모두 GUI 사용자 세션, 기존 알한글 등록 부재, root/Data 볼륨의 Indexing enabled, TXT 자동 본문 검색, 소유 문서 정리를 확인했다.
- 시스템 설정 변경, 색인 활성화/초기화, 앱 빌드·설치·실행을 하지 않았다.
- 실제 앱 첫 실행·HWP/HWPX 검색·서명 후보 검증은 이 환경 조사에 포함하지 않았다.
