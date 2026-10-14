# Task M900 #584 최종 보고 — v0.2.3 공개·설치 수용

## 결론

**v0.2.3(21)을 2026-10-15 05:07:41 KST 공개하고 Pages/Sparkle·실제 업데이트·Mac 글꼴/문서/Finder·Homebrew 설치와 앱 없음/관련 설정 원상복원을 완료했다.** rhwp v0.8.7과 Mac 로컬 글꼴 기능을 포함한 동일 공증 DMG다. 실제 Mac Spotlight 검색은 양 VM 검색 PASS·실제 Mac 본문 추출 PASS를 대체 근거로 명시 수용했으며 원인 조사·필요 수정은 다음 릴리즈 후속으로 남긴다. 과거 최근 문서 이력 공백과 기존 저장 한계는 해결로 바꾸지 않는다. 작업지시자가 최종 보고 수용·종료 정리 게시/병합·후속 이슈 등록을 승인했다. 종료 PR과 devel 인계를 진행하며 Spotlight 원인 조사는 [#587](https://github.com/postmelee/alhangeul-macos/issues/587)로 분리했다.

준비 [PR #585](https://github.com/postmelee/alhangeul-macos/pull/585)는 검증 이미지 보정 head `938b59b9`의 CI 4개 통과 후 `5146d91e`로 devel에 병합했다. 이후 [Stage 3](../working/task_m900_584_stage3.md)에서 [main PR #586](https://github.com/postmelee/alhangeul-macos/pull/586)의 통합 리뷰·CI 4개를 확인하고, **“main 병합·다음 실행 준비”** 승인으로 main `c9d59f93`에 병합했다. **“v0.2.3 태그 생성·push”** 승인으로 해당 실제 SHA에 tag를 생성·게시·검증했다. DMG workflow의 실행 입력·운영 이름 준비 후 별도 승인으로 run 38180977764를 실행해 success / attempt 1과 artifact 11717953850의 동일 원본 파일 검증 PASS를 확인했다. 별도 승인한 VM 첫 run의 ARM 환경 실패는 보존했고 같은 입력의 재시험 38185285770에서 양 아키텍처 및 verdict, 원본 schema 3·설치/재설치·검색·lifecycle/cleanup 대조를 통과했다. 이후 실제 Mac 검색의 대체 근거 수용과 Stage 5 공개·설치 검증을 완료했다. 아래는 각 단계 당시 증거를 구분한 기록이다.

## 구현과 사용자 변화

설정에서 Mac 글꼴 사용을 켠 뒤 기존 시스템 글꼴 목록에서 선택하는 방법을 중심으로 릴리즈 노트·홈 FAQ·Mac 안내를 연결했다. 원본 참조와 별도 보관 복사본, 권한·지원 스타일·출력 실패 동작을 구분한다. 한컴 제거 후 모든 글꼴 유지·Windows ZIP 가져오기·모든 글꼴 및 한컴 배치 동일성을 약속하지 않는다.

rhwp v0.8.7과 Mac 글꼴 연결 코드는 앞선 PR에서 이미 devel에 반영했다. 이번 준비 PR은 해당 기능의 버전·workflow 기본값·출시 안내를 정렬한다. Swift 동작·Studio·core pin·FFI·renderer 선택을 추가로 바꾸지 않았다. 이전 15개 릴리즈의 본문·공개일·다운로드는 보존하고 최신 안내만 정규화했다. README는 실제 public v0.2.2를 유지하고 미공개 준비 상태를 명시한다.

## 검증 근거

Rust 양 target portable·core/Studio·producer golden/Swift decoder·unsigned Debug 및 universal Release·네 bundle 값/실행 파일 양 slice·Release endpoint·Legal·세 문서 native smoke를 통과했다. 재빌드한 header/staticlib SHA256·size는 기존 lock과 같다. release/Pages helper의 55개 fixture 검사, 본문/YAML/shell/HTML 링크·과거 본문 보존, 12개 desktop/mobile viewport와 키보드 동선도 통과했다.

새로 받은 public appcast를 XML로 읽고 v0.2.2 bytes/hash를 로컬 조립에 그대로 보존했다. Stage 2 당시 v0.2.3 자산은 404였으며 현재 생성한 후보도 draft 상태라 기존 Pages asset gate가 조기 배포를 막는다. 생성 본문의 hash 검증에는 별도 synthetic fixture만 썼으며 실제 DMG hash로 기록하거나 게시하지 않았다.

- [Stage 1 보고](../working/task_m900_584_stage1.md), [Stage 2 보고](../working/task_m900_584_stage2.md).
- [Stage 2 증거](assets/task_m900_584/stage2/validation.json), [제품/arch 기록](assets/task_m900_584/stage2/built-products.json), [Pages 보호](assets/task_m900_584/stage2/pages-proof.json), [등록 정리](assets/task_m900_584/stage2/registration-cleanup.json), [공간 정리](assets/task_m900_584/stage2/storage-cleanup.json).
- [Mac 안내 화면](assets/task_m900_584/stage2/fonts-desktop.jpg), [새 노트 화면](assets/task_m900_584/stage2/release-desktop.jpg), [checksum](assets/task_m900_584/stage2/SHA256SUMS).

## 수용 결과와 남은 한계

| 영역 | 상태 |
|------|------|
| 준비 PR | #585 devel 병합 완료. main #586 새 CI 4개 PASS·통합 리뷰 후 c9d59f93에 병합 완료 |
| 최종 provenance/DMG | source SHA c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 및 v0.2.3 tag 게시·검증 완료. publish run 38180977764 / attempt 1 / success, artifact 11717953850. DMG SHA256 d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63 / 211405232 bytes, 파일/서명·공증·레이아웃 PASS |
| ARM/Intel VM | [run 38185285770 / attempt 1 PASS](assets/task_m900_584/stage3/vm/retry/summary.json), 양 schema 3·최초/종료 후·재설치/종료 후·각 lifecycle 33개·cleanup. 양쪽 maintained. 첫 실패 38184399238 보존 |
| 실제 Mac | [Stage 4](../working/task_m900_584_stage4.md): macOS 26.5.2/arm64 일반 최종 앱의 실제 232 family/204 공급, HWP/HWPX 저장·새 프로세스 재열기·실제 PDF·프린트 취소·Finder PASS. 실제 검색은 색인 활성화 상태에서도 TXT 대조군이 검색되지 않아 환경 미확인(원인 미확정), 현재 설치 importer 추출 및 양 VM 검색 PASS |
| 복원·증거 공백 | 사용자가 삭제한 앱 부재로 복원·후보 등록/mount/소유 Documents 폴더 정리·OFF/grant 0·원본 hash 유지. UUID container/sfl4를 늦게 확인해 확보한 최근 항목은 복구했으나 전체 사전 동등성은 미증명. 과거 전체 동등성 미증명은 유지. Stage 5는 사전 UUID·7개 recent/sfl4·관련 설정 정확한 복원 PASS |
| 저장·복구 | #480 보호 경고·취소·원본 hash 유지·명시 다른 평문 복사본 재열기 PASS, native 암호화 저장 미지원. #525 저장하지 않음 뒤 소유 복구 후보 잔존을 최종 앱에서 관측·정리. 해당 한계와 동일 목적지 패널 재선택 미시험을 수용표에 구분 |
| 공개·업데이트 | [Stage 5](../working/task_m900_584_stage5.md) 공개·Pages/Sparkle·실제 0.2.2→0.2.3 업데이트·문서/글꼴/Finder·tap PR #2·Homebrew 설치·원상복원 PASS. README/웹 안내·최종 기록의 종료 정리 게시 대기 |
| 독립 후속 | Windows #566·추가 현재성 비용 최적화 #581 OPEN. <300ms·무지연 실행을 완료 기준으로 다시 요구하지 않음 |

최소 macOS 12·Intel 실기기 GUI·실제 한컴 제거·물리 인쇄를 이번 unsigned 검증으로 수행했다고 주장하지 않는다. 새 원본 손상이나 보호 우회가 확인되면 공개를 차단한다.

## 이전 준비 PR과 단계별 gate 이력

`local/task584`의 준비 소스·문서·증거·부분 보고는 승인에 따라 `publish/task584`의 #585로 게시했다. source 준비 커밋 `ee453da2`, 보고 묶음 `39e3e131`, 이미지·checksum 보정 `938b59b9`를 포함해 최신 head의 CI 4개를 통과했고, 병합 승인에 따라 `5146d91e`로 devel에 반영했다. PR은 Refs #584 형식이며 #584는 계속 OPEN이다.

승인된 main PR 본문을 #586으로 게시하고 [통합 리뷰](../feedback/task_m900_584_pr586_review.md)와 CI 증거를 보존했다. 승인받은 main 병합 후 tree·content gate·네 bundle·공개 feed 유지와 실제 Pages deploy skip을 확인했다. 태그 생성도 별도로 승인받아 정확한 main SHA에 고정했고 [태그 증거](assets/task_m900_584/stage3/tag/tag-verification.json)를 보존했다. 승인된 draft 생성과 [동일 파일 검증](assets/task_m900_584/stage3/publish/file-verification.json)은 PASS이며 기존 앱 0.2.2/20·public feed를 유지하고 mount/시험 창·중복 ZIP을 정리했다. 승인된 양 VM 수용도 완료했고 [실제 Mac 준비안](../working/task_m900_584_stage4.md)을 제시했다. Stage 3 완료이며 실제 Mac 설치와 공개는 [구현계획](../plans/task_m900_584_impl.md)의 각각의 gate를 따른다. 최종 릴리즈 성공이나 #584 전체 완료로 기록하지 않는다.

2026-10-12~13 승인된 [Stage 4](../working/task_m900_584_stage4.md)를 실행했다. [최소 증거](assets/task_m900_584/stage4/acceptance-summary.json)와 [정리 receipt](assets/task_m900_584/stage4/installation-restoration.json)를 보존했다. 실제 Mac 검색 환경 제약·최근 이력 증거 공백과 #480/#525 한계의 수용, Stage 5 준비가 다음 승인 대상이다. 공개 승격이나 실제 Sparkle 설치는 아직 실행하지 않았다. 현재 설치 앱이 없으므로 업데이트 시험의 기존 v0.2.2 준비와 최종 설치 유지 여부도 구체 범위에 포함해야 한다.


2026-10-15 재부팅 후 같은 후보를 재검증했다. [새 검색 증거](assets/task_m900_584/stage4/reboot-20261015/summary.json)는 설치 전 TXT 3.73초 PASS 후 후속 TXT·문서 검색 미충족, 실제 설치 importer 추출 PASS다. 후보 제거 후에도 TXT 회복을 확인하지 못해 실제 검색은 환경 전제 미충족으로 유지한다. OS/도구/후보의 원인은 미확정이며 제품 회귀를 확정하거나 배제하지 않는다. 이번에는 실행 전에 실제 UUID의 관련 key/sfl4를 보존해 현재 시험의 최근 7개 및 관련 설정 복원을 확인했고, 앱 부재·등록/mount·소유 파일 정리를 완료했다. 이전 시험의 역사적 이력 공백은 그대로 남는다. 다음 좁은 폴더 재색인안은 [Stage 4 보고서](../working/task_m900_584_stage4.md)에 준비했으며 미승인·미실행이다. Stage 5는 시작하지 않았다.


별도 승인된 [폴더 한정 재색인](assets/task_m900_584/stage4/reindex-06d6d117/summary.json)도 실행했다. 실제 검색 제외 목록에 시험 폴더 하나만 추가·제거하고 원래 목록을 복원했다. 후보 미설치 상태의 TXT 두 개가 180초 관찰(실제 182.30초, 59회)에서 모두 양성 0회여서 환경 전제를 충족하지 못했다. 이번 후보 설치/실행·HWP/HWPX 재검증은 계획의 전제에 따라 미실행으로 남기고, 파일 hash 확인 후 소유 폴더를 정리했다. Mac 환경 복구는 별도로 두고 기존 양 VM 검색·실제 설치 importer 추출을 대체 근거로 수용해 Stage 5 준비로 진행할 것을 권고한다. 역사적 이력 공백과 #480/#525 한계의 수용도 승인 대기이며, 공개 명령은 실행하지 않았다.


## Stage 5 최종 결과·보고 수용

[공개 승격](https://github.com/postmelee/alhangeul-macos/actions/runs/38629062837)은 두 job 모두 성공했다. Release 409973398 및 기존 asset 632029048/632029049를 유지했으며, public 신규 다운로드는 확정 DMG SHA256 d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63 / 211405232 bytes와 같다. public appcast 0.2.3/21·서명·동일 enclosure·홈/폰트 안내·새 노트·이전 배너 접근을 확인했다. 재빌드·재서명·태그 이동·DMG 교체는 없다.

실제 0.2.2/20에서 Sparkle 다운로드·설치·자동 재실행(37569→38722)을 도구가 앱을 다시 켜기 전에 확인했다. HWP/HWPX 열기, Mac 글꼴 기본 OFF·ON 및 재실행 유지, 실제 포인터 시스템 글꼴 266개, Quick Look 두 형식과 새 경로의 썸네일 두 개를 확인했다. 첫 AX select 조작이 기본 선택창을 연 결과를 제품 회귀로 확정하지 않았으며, 포인터 비교는 수동 재실행 후 수행했다.

[Homebrew PR #2](https://github.com/postmelee/homebrew-tap/pull/2)는 version/hash 두 줄을 검토·style·audit 후 병합했다. receipt 0.2.2→0.2.3 upgrade 당시 앱은 이미 Sparkle 0.2.3이었음을 구분한다. 제거·신규 설치 0.2.3/21, universal·seal·staple·Gatekeeper 및 Sparkle 설치본 실행 파일 일치를 확인했다. 원래 앱 없는 상태와 기존 Homebrew metadata를 복원했고, 관련 앱 설정 7개·최근 문서 7개/sfl4·글꼴 정책의 bytes도 복원했다. 소유 시험 문서·등록만 정리하고 사용자 TXT와 Finder 검색 창을 유지했다.

[Stage 5 증거](assets/task_m900_584/stage5/SHA256SUMS)를 보존한다. 첫 위생 검사의 VM metadata bundle 3개 등록 잔존은 ZIP/hash로 원본 보존 후 해당 경로만 정리했고 최종 검사는 PASS다. 전역 색인·캐시 초기화는 없다. 초기 XML 경로/fully-qualified brew list/tap 밖 style 오류는 제품 실패와 분리해 원시 기록에 남겼다.

다음 공개 변경은 README·홈/업데이트 Homebrew 배지·Cask mirror·릴리즈 수용 기록을 한 main 대상 종료 정리 PR로 제출하고 CI·리뷰·병합 및 docs-only Pages의 appcast 보존을 확인하는 것이다. 이후 devel 인계와 #584 종료를 수행한다. [Spotlight 후속 이슈 초안](../working/task_m900_584_spotlight_followup_issue.md)은 기존 종료된 #513과 다른 현재 관측의 원인 분리를 소유한다. 작업지시자가 **“최종 보고 수용·종료 정리/병합·후속 이슈 등록”**을 승인했으며, 후속 [#587](https://github.com/postmelee/alhangeul-macos/issues/587)을 등록했다.

필요 회귀는 Ruby 문법·실제 tap style/audit·공개 파일/실제 설치 검증, Pages 조립/public appcast 보존·업데이트 탭 화면, 문서 링크·이미지 형식·checksum·공백 검사다. 제품 Swift/Rust/Studio를 바꾸지 않아 전체 빌드를 반복하지 않았다. [검증 요약](assets/task_m900_584/stage5/validation.json)과 [Homebrew 안내 미리보기](assets/task_m900_584/stage5/closeout-homebrew-preview.jpg)를 보존한다.
