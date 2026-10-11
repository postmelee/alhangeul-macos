# Task M020 #580 Stage 5 — 최종 증거·보고·PR 준비와 Mac 수용 인계

- 이슈: [#580](https://github.com/postmelee/alhangeul-macos/issues/580), 상위 #562, 후속 Mac 수용·안내 #569.
- 승인: 2026-10-11 현재 결과 수용·Stage 4 완료 기준 보정·추가 최적화의 후속 분리·Stage 5 진행.
- Stage 4 완료 커밋: `d9171d80`. 제품 최종 구현은 `1624842b`이며 이번 단계는 제품 소스 변경 없음.
- 상태: **Stage 5 완료.** 최종 보고/구체 공개 범위를 승인받아 [후속 #581](https://github.com/postmelee/alhangeul-macos/issues/581) 등록·기존 #580 기준 갱신·`publish/task580` push·[Open PR #582](https://github.com/postmelee/alhangeul-macos/pull/582) 게시를 완료했다. CI/리뷰 대기이며 PR merge·이슈 close·공개 배포 미수행.

## 1. 현재 수용 결정

[Stage 4 보고 §13](task_m020_580_stage4.md#13-stage-4-완료-기준-보정과-후속-분리)에 따라 같은 signed 후보 `580.4.3`의 metadata 약 160~170ms·provider 약 328~343ms, 정상 자동 Thumbnail 186건 busy 0·정확성·현재성/원본/권한·취소/lease·한도·실제 Finder/Preview·원상복원을 수용했다. 원래 <300ms는 미충족으로 보존하고 후속 최적화로 분리했다. 기존 JSON의 `goalsMet: false`를 바꾸거나 새로운 일반 시간 상한을 만들지 않았다.

승인된 [독립 후속 본문](task_m020_580_followup_issue.md)을 [#581](https://github.com/postmelee/alhangeul-macos/issues/581)로 등록했다. 이 후속은 warm 현재성 검사 내부 비용·bulk 속성/전체 key 비교의 동등성 실험을 인계한다. #580 완료와 #569 Mac 수용·안내·출시 준비의 선행 조건이 아니며 구현·새 서명/설치 승인을 자동 승계하지 않는다. [#580 본문 갱신안](task_m020_580_issue_update.md)은 기존 baseline/범위/정확성 계약을 보존하고 승인된 현재 결과와 cold/다수 파일 지연을 추가한다.

## 2. 최종 검증

| 검증 | 결과 |
|------|------|
| 마지막 signed 제품 Source 126개 | 현재 전체 집합/hash와 일치하고 제품 commit `1624842b`의 내용과도 일치 |
| 직접 receipt의 제품/테스트/스크립트 | 126/24/7개 모두 현재 hash 일치 |
| 고정 core/asset/native | lock·Studio manifest·staticlib/header 4개 일치 |
| 기존 선별 evidence | SHA256SUMS 8묶음·31개 일치, 원래 목표 false·186건 busy 0·328개 대응/4개 의도적 fallback·각 warm 10건 의미 대조 |
| 경계/receipt | no-AppKit·native matcher·Studio adapter/assets·core build-info·로그 parser self-test PASS |
| 후보 helper guards | 새 격리 mock 16조건 PASS. 실제 codesign/등록/설치 외부 명령 없음; fixture bundle은 시험 내부에서 제거 |
| main/source content gate | `origin/main` `43b4e998` → source `d9171d80`: main-only/content 후보 0, 예상 merge tree 동일 PASS. 첫 sandbox Git 임시 object 접근 제한은 동일 읽기 검증 권한으로 회복 |
| 원래 앱 읽기 확인 | v0.2.2 243항목 파일/link/mode digest `fa694017af3e0b3705510b353ef0e9dc5549be57493b74e99e5ca05540b3707b` 동일, strict codesign exit 0; xattr 비교 제외 |
| 읽기 전용 등록 점검 | provider `/Applications/Alhangeul.app`, 개발 등록/bundle·문제·경고 0 |

최종 성공 XCTest FontLibrary 162개·Host 출력 81개, 같은 최종 소스의 직접 정상 consumer 1,152건 busy 0, 기본/진단 Release·PNG/2페이지 PDF·queue/current/lease는 Stage 4.3 결과를 재사용했다. source 대조를 새 consumer 시험으로 부르지 않으며 전체 성능·signed 설치 시험을 반복하지 않았다. Stage 5에서는 새 앱/DMG를 만들지 않았다.

[evidence-audit.json](assets/task_m020_580_stage5/evidence-audit.json), [validation.json](assets/task_m020_580_stage5/validation.json), [게시 결과](assets/task_m020_580_stage5/publication.json), [SHA256SUMS](assets/task_m020_580_stage5/SHA256SUMS)를 보존한다. 읽기 점검 원시는 `build.noindex/task580/stage5/`, helper mock 결과는 허용된 `build.noindex/task580/stage4/final-report-guards-01/result.json`에 있다. 내용이 같은 결과를 새 signed 수용으로 기록하지 않았다.

## 3. 최종 보고와 후속 순서

[최종 결과보고서](../report/task_m020_580_report.md)에 변경 경계·baseline/최종 signed 값·300ms 미충족과 승인 수용·실제 소비자/오류 구분·최초 준비/다수 파일 대기·환경 제한·원상복원·공간/후속 인계를 정리했다. 정상 자동 186건·GUI Thumbnail 85건·Preview 31건·전체 328개 대응을 혼동하지 않는다. ON 첫 miss 중앙값 1,877.938ms/최대 5,339.784ms와 다수 파일 warm exact 357.995ms도 남겼다.

#580 PR의 base는 `devel`, 원격 head는 `publish/task580`, 완료 참조는 `Closes #580`만 사용한다. #562/#569는 `Refs`이며 전체 기능·Windows·출시 완료로 닫지 않는다. PR 본문은 저장소 template의 Stage별 보고·commit 고정 문서 링크·핵심 경계/검증·잔여 위험을 따른다.

#580 merge 후 #569 Stage 3 웹 안내 → Stage 4 같은 최종 후보의 설정/권한·Studio 기존 글꼴 목록·저장/재열기·PDF/인쇄 경로·Finder·재실행·변경/복구 수용 → Mac 부분 보고/PR·Release Operations 인계다. `local/task569`의 기존 진단/보고/원시 자료를 보존하고 필요한 중복만 승인된 통합 절차로 대조한다. 최소 macOS/Intel 실행·사용자 OS 글꼴 변경·실제 한컴 제거·Windows·물리 프린터·public DMG는 이번 근거로 통과했다고 판정하지 않는다.

## 4. 공개 게시 승인과 결과

최초 후속 이슈 등록 시도는 자동 승인 검토가 구체 측정·경로·커밋 정보의 GitHub 공개 권한 부족을 이유로 거절했다. 당시 외부 변경은 없었다. 작업지시자가 이어서 “최종 보고 승인·이슈/기준 갱신·push/Open PR 게시”로 준비된 본문과 공개 push 범위를 명시 승인해 권한 요구를 해소했다. 이는 새로운 Stage 4 성능 최적화 승인이 아니다.

승인된 본문 그대로 [#581](https://github.com/postmelee/alhangeul-macos/issues/581)을 milestone `글꼴 마이그레이션`과 기존 label로 등록했고, #580 본문을 갱신한 뒤 OPEN 유지·승인 본문 일치를 읽기 확인했다. 준비 커밋 `95b739d9`를 `publish/task580`에 push해 `devel` 대상 [Open PR #582](https://github.com/postmelee/alhangeul-macos/pull/582)를 생성·현재 작업에 연결했다. 생성 시 CI `Classify changed files`가 IN_PROGRESS였다. 등록된 이슈/PR 링크와 게시 상태만 문서에 후속 반영하며 제품 소스는 바꾸지 않는다.

승인 범위는 `postmelee/alhangeul-macos`의 후속 이슈 등록·#580 완료 기준 갱신·현재 source/테스트/측정 증거/보고서 push·`devel` 대상 Open PR이다. 최종 보고 승인 절차는 `task_workflow_guide.md`의 “모든 단계 완료 시 최종 결과 보고서 작성 → 승인 요청”을 따른다. PR merge·이슈 close·새 후보 서명/설치·공개 release는 이 게시 범위에 포함하지 않는다.
