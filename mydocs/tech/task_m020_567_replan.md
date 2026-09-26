# #567 — upstream 병합 후 진행 순서와 글꼴 이슈 재정렬 검토

확인일: 2026-09-26. 사용자는 추천한 순서로 진행하고 열린 로컬 글꼴 이슈의 재구성 필요성을 판단하도록 지시했다. 후속으로 기존 이슈 보정·작업 진행을 승인하여 #562/#566/#567/#568/#569 본문에 아래 진행 순서와 완료 기준을 반영하고 원격 원문 일치를 확인했다. 기존 본문은 보존했으며 상태·마일스톤은 변경하지 않았다.

## 판단

새 이슈 생성·기존 이슈 병합 없이 현재 상위/하위 구조를 유지하고 의존성·완료 기준을 보정하는 것이 적절하다. #567의 릴리즈 전 준비와 릴리즈 후 제품 수용을 분리하면 대기 중에도 필요한 작업을 할 수 있다. #568은 같은 공급 계층을 공유하므로 우선 한 이슈 안에서 PDF·인쇄와 native·Finder 확장의 단계를 구분한다. 독립 담당자·별도 배포 일정이 확정되면 그때 하위 이슈 분리를 검토한다.

## 병합본 확인

- upstream PR: [edwardkim/rhwp#7405](https://github.com/edwardkim/rhwp/pull/7405), MERGED, 2026-09-25 08:23:49 UTC.
- 실제 실행 검증 head: `bf371e200cfbc343094b552169864ba6c9235a27`.
- 최종 PR head: `7978d00b8253ccc5876f95ed8e668a5ab93fbff5`. 검증 head 대비 2개 문서(`mydocs/orders/20260924.md`, `mydocs/pr/archives/pr_7405_review.md`)만 변경되었다.
- squash 병합 commit: `aeb9f489e1d5e297c1e98cf1ca8ff84532270aca`, 부모 `eb321165eca0320a4a307c53c49284b122a28482`.
- 병합 commit이 변경한 파일 중 `mydocs/` 밖 27개 파일의 Git blob을 검증 head와 대조했고 전부 동일했다. 공개 계약은 병합본 `rhwp-studio/HOST_FONTS.md`로 재확인했다.
- 다만 검증 head와 병합 tree 전체는 217개 파일이 다르다. 다른 upstream 작업의 코어·fixture 변경이 포함되며 Studio에도 `src/engine/command.ts` 및 관련 테스트 2개 차이가 있다. 글꼴 코드 동일성은 전체 통합본 재실행 성공을 의미하지 않는다.
- 조회 당시 최신 공개 릴리즈는 [v0.8.6](https://github.com/edwardkim/rhwp/releases/tag/v0.8.6), 2026-09-02 게시다. 글꼴 API를 포함한 정식 릴리즈는 아직 없다. 제품 pin은 변경하지 않았다.
- 재확인 방법: `gh pr view 7405 --repo edwardkim/rhwp`, `gh release list --repo edwardkim/rhwp`, 검증 head와 최종 head의 `git diff --name-only`, 병합 부모→병합본의 변경 경로를 추출한 뒤 경로별 `git rev-parse <sha>:<path>` 비교. 소스 조회만 수행했으며 다른 작업 트리는 수정하지 않았다.

기존 [실행 검증 보고](../working/task_m020_567_pr7405_validation.md)의 29개 통과는 원래 head에 대한 증거로 유지한다. 이번 작업은 정적 차이 대조이며 새 실행 테스트로 집계하지 않는다.

## 열린 이슈별 수정 제안

| 이슈 | 유지할 책임 | 권장 보정 |
|---|---|---|
| [#562](https://github.com/postmelee/alhangeul-macos/issues/562) | 전체 기능의 상위 추적 | 완료된 #563/#564/#565와 진행 중 #567을 구분한다. upstream 병합 완료·정식 릴리즈 대기와 아래 실행 순서를 표시한다. 전체 완료 기준은 유지한다. |
| [#567](https://github.com/postmelee/alhangeul-macos/issues/567) | Studio 표시·편집·저장과 앱 adapter | Stage 3.1: 공개 API용 어댑터 준비. Stage 3.2: 정식 릴리즈 포함 확인·pin/sync·실제 제품 연결. Stage 4/5: 변경 전파·설정·signed sandbox·회귀 수용을 유지한다. 기존 문서 표시와 편집 글꼴 메뉴를 별도 항목으로 검증한다. |
| [#568](https://github.com/postmelee/alhangeul-macos/issues/568) | PDF·인쇄·native·Quick Look·Thumbnail | PDF/인쇄와 native/Finder 확장의 실행·완료 표를 나눈다. 출력 snapshot·별도 WebView 공급·준비 대기를 앱 책임으로 명시한다. upstream 추가 API를 당연한 선행 조건으로 두지 않는다. Mac 수용을 #566 완료에 묶지 않고 Windows 입력 수용만 별도로 의존시킨다. |
| [#566](https://github.com/postmelee/alhangeul-macos/issues/566) | Windows 폴더·ZIP 및 독립 보관 입력 | 현재 분리를 유지한다. #564 기반에서 독립 진행할 수 있으며 Mac 설치 글꼴의 선행 조건이 아니다. 실행 순서는 Mac Studio·출력 경로 우선으로 제안한다. |
| [#569](https://github.com/postmelee/alhangeul-macos/issues/569) | 소비자별 통합 수용·웹/도움말 | Mac과 Windows를 별도 수용표로 관리한다. Mac 안내 준비는 #567/#568 결과로 진행하되 Windows 미완료 상태에서 전체 이전 기능 완료로 닫지 않는다. 제품 검증과 공개 배포를 구분한다. |

#563(조사), #564(관리 기반), #565(설치 감지·권한 기반)는 모두 closed다. 다시 열거나 같은 작업을 재등록할 이유는 발견하지 못했다. #562의 과거 #565 단계 설명은 이력으로 남기고 현재 요약을 완료 상태로 보정하면 된다.

M020/v0.2 목표와 각 이슈의 기존 지원 범위를 유지한다. Windows나 Finder 지원을 이번 판단만으로 출시 범위에서 제외하지 않는다. 기능 일부의 선출시가 필요해지면 별도 범위 결정을 남긴다.

## 실행 순서와 완료 구분

1. 현재: 최종 병합 API 대조와 #567 계획 보정. 추가 임시 core fork/backport 없이 진행한다.
2. Stage 3.1: 앱 어댑터, source별 metadata 정규화, native slot 제한 queue, 취소·세대·문서 재연결, API 부재 동작을 구현·검증한다. 테스트 mock은 공개 계약을 재현하고 제품의 matcher/renderer를 복제하지 않는다.
3. 정식 릴리즈 후 Stage 3.2: 릴리즈가 병합 API를 실제 포함하는지 확인하고 기존 full-sync 절차로 core/Studio provenance·ABI·자산을 검증한다. 이미 동일 릴리즈 sync PR이 있으면 중복 생성하지 않고 그것을 선행 작업으로 연결한다.
4. #567 Stage 4/5: 설정·권한·변경·실문서·재실행 수용 후 #568 출력·확장에 인계한다. #568 준비는 확정 공급 계약으로 가능하지만 각 소비자의 실제 적용은 별도로 검증한다.
5. #569 Mac 수용·안내와 #566 Windows 입력 수용을 구분해 취합한다. 이슈 전체 완료·릴리즈는 기존 완료 기준과 별도 배포 승인을 따른다.

현재 화면 API는 host 목록을 편집 toolbar에 자동 추가하지 않는다. 앱 소유 UI/공개 편집 진입점으로 해결할 수 있는지 Stage 3.2에서 확인하며, 불가능한 경우에만 작은 별도 upstream 개선 필요성을 보고한다. 이 미확인 항목을 이유로 지금 새로운 core 확장을 시작하지 않는다.
