# Task M900 #494 Stage 6 보고서

## 실행 범위

작업지시자가 남은 실제 업데이트 검증과 README·Pages 최종 문구 정리를 계속 진행하도록 지시했다. Stage 5 actual Sparkle·Finder 확인과 기존 설치 복원을 완료한 뒤, 승인된 종료 정리 범위에서 공개 문구·배포 기록·최종 보고서를 단일 main PR로 묶는다. 이 문서의 merge·Pages 결과는 실제 실행 후 갱신한다.

## 변경

| 대상 | 결과 |
|------|------|
| README·Pages 3문서 | 공개 준비 상태를 v0.1.11 공개로 변경, 현재 Homebrew 설치 명령과 다운로드 연결 정렬 |
| repository Cask | 이미 공개한 tap과 같은 v0.1.11 official SHA256 |
| release record/index | 공식 배포·실제 Sparkle·HWP/HWPX Finder·Homebrew와 원본 복원 결과 반영 |
| 계획·오늘할일 | Mac 잠금 대기 상태 해제, 실제 완료한 검증과 종료 정리 상태 표시 |
| Stage 4~5·최종 보고 | 실패 후보와 수정 공증 후보, official DMG 구분. 테스트 수·서명·provider 경로·미실행 한계 기록 |

제품 source·workflow·core lock·bundled Studio는 변경하지 않는다. official annotated tag와 appcast bytes도 유지한다. GitHub Release 본문은 Stage 5에서 Homebrew 명령 반영을 완료했으므로 중복 수정하지 않는다.

## 검증

- public appcast를 입력한 로컬 Pages artifact 준비·byte 비교 통과.
- 이전 버전 notice helper, release note template·GitHub body, HTML 15개 문서의 내부 링크·앵커 174개와 중복 ID 검사, `git diff --check`를 통과했다.
- main PR exact head·diff와 CI를 확인한 뒤 merge한다. `Casks/` 변경으로 release helper 검증 대상이며 제품 재빌드·render는 변경 범위 밖이다.
- docs-only Pages workflow가 현재 public feed를 보존해 배포하는지 확인한다. 기존 `docs/appcast.xml`을 fallback으로 쓰지 않는다.

## PR 운영

원래 요청한 #491 외에 후보 준비 #495, 최초 main 승격 #496, 차단 오류 수정 #498, 수정 기록 #499, main 재승격 #500이 발생했다. sandbox HWP3 저장 실패의 수정·재검증이 PR 증가 원인이다. 공개 문구를 여러 PR로 나누지 않고 이 종료 정리 PR에 모으며, 이후에만 확정되는 public 배포 관찰은 devel 최종 기록에 반영한다.

## 현재 상태

공식 배포·Homebrew·실제 Sparkle·Finder 검증과 원본 복원은 완료했다. main 공개 문구 PR 게시·CI·merge 및 Pages 실제 결과 확인, devel 최종 기록과 Issue #494 종료는 후속 실행 대상이다. 아직 실행하지 않은 결과를 완료로 표시하지 않는다.

[최종 보고서](../report/task_m900_494_report.md)에 전체 검증과 알려진 한계를 모았다.
