# Task M900 #494 Stage 6 보고서

## 실행 범위

작업지시자가 남은 실제 업데이트 검증과 README·Pages 최종 문구 정리를 계속 진행하도록 지시했다. Stage 5 actual Sparkle·Finder 확인과 기존 설치 복원을 완료한 뒤, 승인된 종료 정리 범위에서 공개 문구·배포 기록·최종 보고서를 단일 main PR로 묶는다. main 종료 정리 PR #501 병합을 완료했으며 아래에 실제 결과를 기록한다.

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

## main 종료 정리 PR 결과

| 항목 | 결과 |
|------|------|
| PR | [#501](https://github.com/postmelee/alhangeul-macos/pull/501), `publish/task494 → main` |
| 검토 head / base | `573ebc043c0451aa3f4a96fb25aae64825b24919` / `abdf88f9846650e5920039f2807615ea1b285f91` |
| 범위 | 공개 문서·Cask·기록 14파일, 제품 source·workflow·tag 변경 없음 |
| CI | [34049467483](https://github.com/postmelee/alhangeul-macos/actions/runs/34049467483), 분류·스크립트·release helper 3개 job success, macOS scope skip |
| 검토 | Copilot quota로 실제 review 없음. exact head·base·body·tree diff·검증 근거 수동 확인, 변경 요청 없음 |
| 본문 검증 | 최초 issue 번호 뒤 조사 표기 오류를 보정하고 validator 재검증·원격 body equality 확인 후 merge |
| merge | `0272172e543d59fd87eebb11d98904ee344a4487`, 2026-09-07 02:48:53 KST |
| Pages | [34049769039](https://github.com/postmelee/alhangeul-macos/actions/runs/34049769039), 위 merge commit의 artifact 준비·배포 두 job success |

## 현재 상태

main 공개 문구 PR 병합과 Pages 검증을 완료했다. 02:50 KST에 public home·updates·v0.1.11·이전 v0.1.10 HTML이 repository source와 byte 동일한 것을 확인했다. 최신 세 문서에서 공개 준비 문구가 사라지고 Homebrew 명령이 반영됐다. latest·tag 고정 DMG 링크는 모두 HTTP 200, Content-Length 180206064다.

public appcast는 1,167 bytes, SHA256 `f880f5047ffea8f41f5675900a3fbb5261b9c5d1015a29f007fdbd3be604f234`로 Stage 5와 byte 동일하다. official annotated tag object와 peeled commit도 유지했다. `stage6/public-after-closeout.json`과 `pages-final.json`에 결과를 보관했다.

devel 최종 PR에는 main에 반영한 공개 문구·Cask와 이 실제 관찰 기록을 함께 전달한다. main 대비 추가 diff는 계획·orders·release/단계/최종 보고만이며, 공개 HTML·Cask·제품 source는 동일하다. CI와 merge를 확인한 뒤 Issue #494 완료 처리, `publish/task494`·`local/task494` 삭제와 devel 복귀를 수행한다.

[최종 보고서](../report/task_m900_494_report.md)에 전체 검증과 알려진 한계를 모았다.
