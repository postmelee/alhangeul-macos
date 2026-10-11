# Task M020 #565 Stage 6 — 최종 회귀와 소비자 인계

- 이슈: [#565](https://github.com/postmelee/alhangeul-macos/issues/565), M020 / v0.2 계열
- 브랜치: `local/task565` → `devel`
- 승인: Stage 5 UI 보완 후 작업지시자의 “승인할게 다음을 진행해줘”
- 상태: 회귀·sandbox 재실행 검증 및 소비자 인계 완료. 최종 보고/PR 절차 승인 대기.

## 검증 결과

| 항목 | 결과 |
|------|------|
| 글꼴·설정 XCTest | 89개 통과, 실패 0 |
| 개인정보 설정·Studio 세션 XCTest | 선택한 4개 suite, 42개 통과, 실패 0 |
| 최종 HostApp Debug 빌드 | BUILD SUCCEEDED |
| 실제 SwiftUI·Studio 문서 수명주기 | PASS TOTAL 39. HWP/HWPX 저장·전환·취소·쓰기 실패·종료·원본 보존 확인 |
| 공용 Swift 의존·shell 문법·diff | 통과 |
| 최종 signed sandbox 재실행 | PID 30035 → 35867, 설정 복원·bookmark 읽기 성공, 권한 오류 0 |
| 개발 등록 정리 | 최종 Issues/Warnings 없음. 정식 설치본 유지 |

로그는 `build.noindex/task565-stage6/`의 `font-tests.log`, `host-tests-build.log`, `host-tests.log`, `host-build.log`, `studio-lifecycle.log`, `sandbox-first.log`, `sandbox-relaunch.log`, `hygiene-final.log`에 있다. Studio 상세 증거는 `build.noindex/studio-lifecycle-0mwe72gb/`다.

글꼴 테스트는 실제 자체 fixture를 process scope로 등록한 뒤 원본 bytes를 교체하여 알림 없이도 오래된 원본이 거부되는 경우를 포함한다. 동명 충돌·삭제/비활성·scope 균형·stale/resolve 실패·generation 변경 도중 요청·읽기 병합·저장 실패·재실행 설정 복원은 기존 테스트로 확인했다. OS에서 실제 사용자의 글꼴을 설치·삭제하거나 권한을 바꾸지 않았다.

Stage 4의 최초 접근 거부→명시적 폴더 선택→지속 읽기 허용 증거를 보존한다. 이번 Stage 6은 그때 허용된 테스트 폴더의 권한을 최종 소스와 새 프로세스에서 재검증한다. 이전에 승인된 경로는 `build.noindex/task565-stage4/installed-font-permission-fixture`다. 키체인 승인이 필요한 로컬 서명과 사용자의 파일 접근 권한 승인은 별개다.

두 새 실행 모두 `restoredEnabled: true`, `bookmarkCount: 1`, `bookmarkRead: true`, `grantIssues: 0`, `omittedFaceCount: 0`이었다. NanumSquareR 723,640 bytes와 NanumSquareB 733,500 bytes, faceIndex 0 및 각각의 SHA-256이 두 프로세스에서 일치했다. 사용자 키체인 승인 후 서명 검증을 통과한 동일 앱을 재실행했으며 파일 선택창을 다시 열지 않았다.

## 인계

[글꼴 연동 계약](../tech/font_library_integration.md)에 소비자별 연결/미연결 표와 #569 수용 시나리오를 추가했다.

- #567: 동일 catalog 소유권, DTO 전달 경계, opaque ID+generation 요청, 기존 이름·스타일 매칭 및 renderer 캐시 무효화.
- #568: 화면/출력의 동일 선택과 원본 변경 처리, extension별 접근 권한 및 수명 확정.
- #566: Windows ZIP/외부 파일 입력과 복사본 관리. 설치 참조 수명과 구분.
- #569: 실제 문서·출력별 선택 증거, 권한 취소/복구, 원본 삭제 시 fallback 및 웹 안내.

현재 UI의 사용 설정은 저장되지만 제품 Studio와 출력 소비자에는 아직 연결되지 않았다. 전체 글꼴 사용 기능이나 한컴 삭제 후 독립 사용 완료로 안내하지 않는다.

## 검증 한계

실제 실행은 macOS 26.5.2다. macOS 12 target 컴파일은 실제 최소 OS 실행이 아니다. 실제 한컴 편집기 설치본, 폴더/볼륨 이동 후 OS bookmark 복구, 실제 영구 설치/비활성 조작 및 제품 전체 화면→출력 일치는 검증하지 않았다. 주입 테스트 및 독립 probe 성공으로 이를 대체하지 않는다.

Stage 6를 완료했다. 다음 승인 대상은 최종 보고/PR 절차다. 현재 이슈 close·PR·merge·릴리스는 수행하지 않았다.
