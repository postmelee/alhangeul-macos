# #587 2단계 — Polaris HWP importer 연결과 HWPX 대조

## 변경과 확인

Spotlight importer의 Info.plist 및 schema에 Polaris HWP UTI를 넣었다. CI 계약은 HostApp의 UTI에 Spotlight 전용 UTI를 더한 집합을 검증한다. OS의 문서 열기 연결은 기존 HostApp 목록을 사용한다.

arm64·x86_64 importer 빌드, plist 구문, 여섯 가지 bundle 계약 시험, 실제 bundle의 CFPlugIn factory 및 HWP·HWPX 본문 반환 검사를 통과했다. 같은 UTI·schema로 만든 계측 후보를 이 Mac의 Spotlight에 등록했을 때, `mdimport -t`에서 Polaris HWP에 후보가 선택됐고 시험 본문이 반환됐다.

## 자동 색인 경계

| 환경 | 자동과 파일 단위 요청 | 시험 추출 |
|---|---|---|
| T7의 계측 후보 | 자동 150초 및 파일 단위 요청 후 60초까지 두 문서의 본문 검색 결과 없음. TXT·RTF 대조 검색 성공. | 두 형식 모두 후보 importer 선택, 본문 반환. |
| T7에 담은 별도 APFS 이미지 | 자동 90초 및 파일 단위 요청 후 60초까지 두 문서의 본문 검색 결과 없음. TXT·RTF 대조 검색 성공. | 두 형식 모두 후보 importer 선택, 본문 반환. |
| 공개판으로 Finder에서 같은 폴더 검색 | 파일명에 없는 영문 단어로 TXT·RTF 두 개만 표시됐다. | 해당 없음. |

두 볼륨을 비교해 특정 T7 색인 저장소 하나에만 나타나는 현상은 아님을 확인했다. HWPX 자동 색인에서는 제공된 제목도 보이지 않았다. 계측 로그는 직접 호출에서는 관찰됐으나 Spotlight test mode에서도 확인되지 않아 로그 부재로 실제 worker의 callback 호출 여부를 단정할 수 없다.

별도 합성 UTI와 후보의 병행 진단 중 `mdfind`가 제한 시간에 도달했고 두 `mdimport -t` 프로세스가 `mdsCopyImportInfo`에서 대기했다. 따라서 합성 UTI 대조로 원인을 일반화하지 않는다. 기존 앱이 제공한 HWPX 본문을 검색 저장소에 반영하는 과정은 미해결이다. macOS 전체 검색 설정과 색인 데이터는 유지했고, 시험용 importer 및 비교 볼륨을 정리했다.

시험 등록을 제거해 catalog가 공개 importer 하나로 돌아온 뒤 새 표본에서도 Polaris HWP에 연결된 importer가 없었고, 공개 HWPX는 본문을 반환했다. 이때 명령줄 본문 검색은 TXT 대조까지 제한 시간에 도달했다. 이전 Finder 양성 대조와 이 시점의 명령줄 오류를 구분했다.
