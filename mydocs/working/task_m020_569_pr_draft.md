## 변경

Mac에 설치된 글꼴을 알한글에서 사용하는 절차를 웹 안내로 추가하고, 앱 Help 메뉴에서 연결합니다. 사용자는 설정에서 **Mac에 설치된 글꼴 사용**을 켠 뒤 문서의 기존 글꼴 목록에서 **시스템 글꼴**을 선택합니다. 실제 설정/선택 화면과 권한 복구·설치 원본/보관 복사 차이·출력 및 지원 제한을 안내합니다.

현재 공개 v0.2.2에는 기능이 포함되지 않는다고 명시합니다. Pages 공개와 기능 제공 버전은 release 운영에서 맞춥니다. core/Studio pin과 기존 공급·renderer 기본값은 유지하며 제품 소스 변경은 Help 링크 8줄입니다. 후보 helper는 기존 #568/#580 경계를 유지하면서 #569 수용을 지원합니다.

## 검증

- 같은 Developer ID 후보의 실제 HWP/HWPX 글꼴 선택·저장/재열기·재실행, PDF 내장 글꼴/한글 검색, 인쇄 패널 취소와 Finder 단일 PNG/다중 PDF·Thumbnail 확인.
- 변경/복구 10 phase: 정상 16건 exact 공급과 의도적인 공급 fallback 4건을 구분하고, 복구 후 공급/재사용 확인.
- 현재 소스의 FontLibrary XCTest 162개, Studio Node 30개, 출력·인쇄·Spotlight 81개 통과. 명시 대체의 차단 family bytes 읽기 0 계약 포함.
- no-AppKit·native matcher·core build-info·Studio receipt, 후보 guards 각 16개, 제품 소스 126개/출력 입력 188개/증거 checksum 59개 일치.
- 기본/진단 Release 및 Debug compile, 웹 1280/390/320px·키보드/로컬 참조 확인. 시험 후 원래 v0.2.2 앱·등록·고유 보관함 복원/정리.

최초 Host 회귀의 Spotlight 1개 실패는 전제 Debug 앱을 빌드한 뒤 같은 81개 suite로 회복했으며 제품/테스트 변경은 없습니다. 출력 불가 face의 실제 alert/명시 대체 클릭은 이번 후보에서 새로 재현하지 않았고 현재 회귀에서 실패/대체 계약을 검증했습니다.

## 인계

Mac 부분 완료이며 Windows #566 및 #569/#562 전체 완료 조건을 유지합니다. #580 작업에서 수용한 ON warm provider 약 328~343ms와 <300ms 후속 #581 분리를 인계하며 새로운 최적화를 포함하지 않습니다. macOS 12/Intel runtime·물리 인쇄·최종 signed/notarized DMG는 이번 실제 실행 범위 밖이고 release 운영의 별도 관문입니다.

최종 보고: `mydocs/report/task_m020_569_report.md`.

Refs #569, #562. 관련 후속: #566, #581.
