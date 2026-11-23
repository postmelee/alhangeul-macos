# #587 실제 Mac Spotlight 검색 결과

공개 v0.2.7의 HWPX 본문 검색을 macOS 26.5.2 Apple Silicon에서 확인했다. 같은 APFS 원본과 합성 문서에서 볼륨 소유권을 활성화하면 한글·영문 본문으로 HWPX가 검색됐다. 소유권을 무시한 경우 TXT·RTF 대조군이 검색된 뒤에도 관측 시간 내에 HWPX가 나타나지 않았다. 이 조건을 실제 Mac 릴리스 수용 절차와 사용자 안내에 반영했다.

Polaris HWP는 실제 UTI가 공개 importer 지원 목록에서 빠져 있었다. PR #639에서 importer와 schema에 해당 UTI를 추가했다. 정식 설치 경로에 로컬 서명 후보만 등록된 상태에서 Polaris HWP와 한컴 HWPX 모두 새 문서 생성 뒤 15초 관측에서 자동 검색됐다. 공개 v0.2.7은 Polaris 수정을 포함하지 않는다.

[공개판 재현](../working/task_m900_587_stage1.md) · [Polaris 지원과 추출 검증](../working/task_m900_587_stage2.md) · [실제 Mac의 소유권 대조 및 후보 자동 색인](../working/task_m900_587_stage3.md)

## 공개 후 확인

다음 공개 앱에서 같은 UTI와 소유권 조건, 앱 종료 상태에서 두 형식의 자동 본문 검색을 확인한 뒤 이슈에 결과를 남긴다. 외장 볼륨의 소유권 무시 조건과 TXT까지 실패하는 검색 지연은 계속 구분한다.

## 공개판 재검증

실제 Sparkle 업데이트 후 설치한 v0.2.8 빌드 26에서 앱 종료 후 HWP·HWPX의 한글·영문 자동 본문 검색을 확인했다. [공개 검증 기록](../release/v0.2.8.md), [이슈 종료 근거](https://github.com/postmelee/alhangeul-macos/issues/587#issuecomment-7110855063).
