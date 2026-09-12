# Task M020 #342 Stage 3 완료보고서

## 복원·정리·실행 결과와 증거 인계

## 정리와 보존

시험 앱 프로세스, 격리 Applications 하위 설치본 및 Documents corpus를 제거했다. 기존 두 앱의 Info.plist·실행 파일 hash와 Preview/Thumbnail provider 선택/경로가 시험 전과 같음을 확인했다. 표준 smoke 안에서 Quick Look cache를 정리했다. Xcode 재귀 등록이 남긴 이번 작업의 Sparkle Updater 경로도 지정 해제했다.

mdimport 목록은 파일 삭제 직후 이전 경로를 계속 반환했다. cleanup에 최대 60초 대기와 pending 상태 기록을 추가했다. 마지막 재검증에서는 후보 경로가 사라져 **cleaned**로 종료했다. 파일 제거와 목록 정리를 같은 성공으로 섣불리 표시하지 않도록 5번째 회귀 테스트를 추가했다.

기존 Finder 창을 보존하고 검증용 창만 닫았다. 공개 screenshot에는 합성 검색어/폴더만 표시하며 개인 Sidebar 항목은 포함하지 않는다.

## 증거와 검증 한계

- 실제 Finder Before/After는 모두 검색 결과 0건이다. 기능 성공 화면이 아니라 txt 대조까지 검색되지 않는 현재 환경의 관찰 기록이다.
- 실제 mdimport metadata 3형식/8전환, 교체 및 미실행 추출, 원래 앱/provider 보존과 후보 목록 제거는 PASS.
- 실제 본문 검색·수정/삭제 전파와 macOS 12/Intel runtime·공개 서명/공증/Sparkle 업데이트는 MISS.
- 전체 Quick Look 등록 위생 helper는 기존 두 설치본 및 과거 개발 레코드로 실패한다. 이번 시험의 provider 보존·등록 제거 PASS와 구분한다. 다른 작업의 산출물은 제거하지 않았다.
- 운영 회귀 5 tests, bundle 3 tests, core build info, no-AppKit, YAML, diff PASS.

## 공개 산출물

`mydocs/report/assets/task_m020_342/results.json`에는 본문 출력/사용자 문서 없이 결과와 HOME 치환 경로만 남긴다. 실제 화면 두 장은 원본 screenshot이며 수정하거나 합성하지 않았다. 최종 보고서와 PR은 하이퍼워터폴 템플릿에 따라 계획·단계·커밋 링크 및 출시 전 미검증 항목을 연결한다.
