# Task M020 #342 Stage 4 — 재개 진단과 검증 스크립트 보완

## 범위와 상태

2026-09-08 작업지시자가 실제 Spotlight 검증을 재개하도록 지시했다. 이 단계는 원인 범위를 좁히고 검증 스크립트의 누락을 수정했다. 코드 회귀 검사는 통과했으며, 실제 시스템 검색 성공을 확인하는 Stage 5는 **진행 중**이다. #342 및 PR #511 전체 완료가 아니다.

## 진단 결과

- macOS 26.5.2에서 시스템 TextEdit 앱과 기존 Documents 텍스트 색인은 조회됐다. 새 합성 txt는 Apple RichText importer의 직접 추출이 가능하지만 파일명/본문 검색과 mdls는 실패했다.
- `mdutil -as`의 시스템 볼륨은 enabled, Data 볼륨은 unknown이다. 기존 색인이 조회되므로 Data 볼륨 전체가 검색 불능이라고 단정하지 않는다.
- 검색 설정의 파일/폴더는 켜져 있고 검색 제외 목록은 비어 있었다. 설정을 변경하지 않았다. 시험 경로에는 일반 읽기 권한이 있고 Data 볼륨은 잠기지 않은 쓰기 가능한 APFS였다.
- mds는 실행 중이었다. mds_stores 로그에서 `Connection interrupted`가 반복됐지만 이것만으로 원인을 확정하지 않았다.
- `mdutil -P`는 root 조회를 요구하고 `sudo -n`은 암호가 필요해 실패했다. 작업지시자에게 `sudo mdutil -s /System/Volumes/Data`, `sudo mdutil -P /System/Volumes/Data`의 조회 출력만 요청했다. 암호는 요청하지 않았다.
- 후보 앱을 설치하기 전 일반 txt만 재색인하는 `environment` 단계도 60초 후 FAIL이었다. 시험 문서 정리는 통과했고 원래 앱 hash·확장 provider 및 importer 목록을 보존했다. 검색 삭제 반영은 MISS이다.

## 보완

1. 앱 등록 전에 txt 양성 대조를 확인하는 environment 단계를 추가했다. 실패 시 전체 볼륨 상태와 시험 파일 metadata를 남긴다.
2. 한글 본문을 직접 검색하고 query 연산자는 거부한다. Data 경로 별칭을 정규화하고 삭제 뒤에도 존재하는 Documents 범위에서 소유한 시험 경로만 판정한다.
3. 0건 판정은 txt 대조군이 계속 검색되는 상태에서 4초 이상 유지돼야 통과한다. 수정된 새 단어와 한글 단어를 삭제한 뒤에도 제거 여부를 검사한다.
4. 출력 잘림 fixture에 앞/뒤 표식을 넣어 한도 내 본문 검색과 한도 밖 본문 미검색을 검사한다.
5. cleanup은 txt를 마지막까지 남긴다. 색인 제거 판정 실패 시에도 소유 파일을 정리하되 완료 상태로 바꾸지 않는다.

## 검증

| 실행 | 결과 |
|---|---|
| `python3 scripts/ci/test-spotlight-system-smoke.py` | PASS — 8 tests, 일시적 빈 응답·서비스 응답 없음·stale 경로·정리 실패 회귀 |
| `python3 scripts/ci/test-spotlight-bundle.py` | PASS — 3 tests |
| `cargo fmt --manifest-path RustBridge/Cargo.toml --check` | PASS |
| locked/offline arm64 release fixture generator | PASS — 새 v3 corpus 생성 |
| 기존 Release CFPlugIn checker로 새 truncated.hwpx 앞 표식 직접 추출 | PASS — 349,542 UTF-16 units, 실제 색인 검증은 아님 |
| `git diff --check` | PASS |
| 새 txt 시스템 색인 대조 | FAIL — Stage 5 환경 진단 대상 |
| 시험 문서/등록 정리 및 기존 앱/provider 보존 | PASS |

실행 결과는 [재개 결과 JSON](../report/assets/task_m020_342/recheck-results.json)에 남겼다. 사용자 경로는 치환했고 전체 시스템 로그나 계정이 보이는 설정 화면은 게시하지 않는다. 기존 Finder 0건 화면은 그대로 실패 관찰 자료이며 새 성공 스크린샷은 아직 없다.

## 다음 단계

관리자 진단 결과를 확인하고 시험 폴더 범위의 복구 가능성을 먼저 판단한다. [Apple 공식 안내](https://support.apple.com/en-ie/102321)는 대상 폴더를 검색 제외에 잠시 넣었다 빼는 재색인을 설명한다. 현재는 이 설정 변경과 전역 색인 초기화, daemon 종료를 실행하지 않았다. 실제 검색·수정·보호·삭제·앱 교체 후 재검색이 성공하기 전까지 이슈를 완료 처리하지 않는다.
