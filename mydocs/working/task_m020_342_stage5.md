# Task M020 #342 Stage 5 — 실제 본문 검색과 변경·삭제 전파 검증

## 범위와 판정

2026-09-09 재검증에서 일반 txt 대조와 HWP3/HWP5/HWPX 실제 본문 검색, 문서 변경·삭제 및 앱 교체/종료 후 재검색을 통과했다. Spotlight 화면에서도 결과가 표시되고 선택한 합성 문서가 열렸다. **새 경로 최초 설치의 importer 자동 발견은 별도 미해결 항목이다.** 같은 경로 앱 교체 후 성공을 최초 설치 성공으로 바꾸어 기록하지 않는다. Stage 6과 #342 전체 완료는 보류한다.

## 실행 결과

#341의 universal Release ad-hoc 개발 후보를 표준 smoke 절차로 검증했다. 앱 실행 파일이나 importer 코드는 바꾸지 않았다. 새 fixture는 파일명에 없는 독립 한글 단어를 사용한다. 실제 검색은 txt 대조가 유지되는 상태에서 정확한 시험 파일 집합으로 판정했고, 0건은 4초 이상 연속으로 확인했다.

| 검증 | 결과 |
|---|---|
| 일반 txt 본문 양성 대조 | PASS |
| HWP3/HWP5/HWPX 실제 후보 importer와 metadata | PASS — 각각 36/58/58 UTF-8 bytes |
| 본문 영문 표식 검색 | PASS — HWP3/HWP5/HWPX 3개 |
| 한글 `나비` 검색 | PASS — HWP5/HWPX 2개 |
| 수정 후 이전 표식 제거, 새 영문·한글 `바다` 검색 및 삭제 | PASS |
| 암호·빈 HWPX / 손상·DRM·배포용·32 MiB 초과 HWP 전환 | PASS — 이전 본문 검색 결과 제거 |
| 1 MiB 잘림 출력 | PASS — 앞부분 영문 표식·`호랑이` 검색, 뒷부분 표식 미검색, 삭제 반영 |
| 동일 경로 앱 교체 후 corpus 복원·앱 종료·metadata와 실제 검색 | PASS |
| Spotlight 본문 결과 표시와 선택한 HWP 열기 | PASS — 기존 기본 연결 앱에서 동일 본문 확인 |
| 새 경로 최초 설치/첫 실행 importer 발견 | MISS — 두 독립 시험에서 재현, Stage 6 대상 |

이번 실행은 `developer-register`를 사용하지 않았다. 최초 설치 MISS 이후 표준 `replace-app`의 복사·bundle timestamp 갱신·일반 등록·첫 실행에서 발견됐다. 동일 후보의 로컬 교체이며 새 공개 버전이나 Sparkle 업데이트가 아니다. source 복사본의 timestamp를 미리 갱신한 경우에도 최초 발견 실패가 재현돼, 이를 해결책으로 단정하지 않는다.

## 한글 fixture 보완 근거

기존 연결어 `은빛나비검색`은 동일 본문을 가진 일반 txt와 HWP/HWPX에서 모두 0건이었다. 같은 본문의 `나비`는 txt와 HWP/HWPX 모두 검색됐다. [비교 결과](../report/assets/task_m020_342/korean-token-comparison.json)를 보존했다. importer의 한글 누락으로 단정하지 않으며, 일반 단어의 검색을 확인하도록 `나비`·`바다`·`호랑이`로 fixture와 helper를 맞췄다. 모든 한글 연결어의 동작을 보장하는 결과는 아니다.

## 실제 화면

[영문 표식](../report/assets/task_m020_342/spotlight-body-ascii.png)과 [한글 단어 결합](../report/assets/task_m020_342/spotlight-body-korean.png)은 Spotlight가 표시한 실제 화면이다. 저장소의 테스트 코드/가이드도 같은 표식을 포함해 함께 표시되며, 시험 문서는 파일명으로 식별된다. [검색 결과 열기](../report/assets/task_m020_342/spotlight-opened-document.png)에서는 기존 기본 연결 앱인 한컴 뷰어에 `나비 AlhangeulSpotlightProbe 문서 본문 검색 검증`이 표시됐다. 기본 앱 연결은 변경하지 않았다.

이전 0건 화면은 연결어를 사용한 과거 기록이므로 새 화면과 같은 조건의 Before/After로 짝짓지 않았다. 공개 증거에는 합성 문서와 제품 검증 결과만 포함한다.

## 코드 검증과 정리

- `python3 scripts/ci/test-spotlight-system-smoke.py`: PASS — 8 tests. 출력 중 FAIL/MISS는 실패 판정 회귀를 위한 주입 사례이며 suite 결과는 OK다.
- `cargo fmt --manifest-path RustBridge/Cargo.toml --check`: PASS.
- locked/offline arm64 release fixture generator: PASS — v4 corpus 생성 및 위 실제 검색에 사용.
- `git diff --check`: PASS.
- 시험 문서 삭제 뒤 영문/한글 7개 표식 제거 및 기존 앱 hash·Quick Look/Thumbnail provider 보존: PASS.
- 시험 앱·문서 제거 후 importer catalog는 비동기로 정리된다. 첫 대기에서는 MISS였고 재확인 후 PASS, 최종 상태는 cleaned다. 최종 판정은 [실행 결과](../report/assets/task_m020_342/post-reboot-results.json)에 기록한다.

## 인계

실제 검색 성공은 확인했지만 일반 최초 설치 발견, macOS 12/Intel runtime 및 공개 서명·공증·Sparkle 검증을 대체하지 않는다. 최초 설치 문제는 기존 #342 / PR #511의 Stage 6에서 추적하며 별도 이슈를 만들거나 상위 #337의 목적을 바꾸지 않는다. #343 지원 문서와 미공개 릴리스 초안에는 이 판정 경계를 반영한다.
