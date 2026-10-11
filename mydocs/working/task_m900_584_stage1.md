# Task M900 #584 Stage 1 — 포함 변경·출처·공개 수용 기준 조사

## 완료 결과와 승인

2026-10-12 작업지시자의 **“구현계획 승인·Stage 1 진행”**으로 승인된 read-only 조사와 문서 준비를 완료했다. v0.2.2 이후 전체 병합 PR 28개를 분류하고 공식 v0.8.7의 core/Studio/Cargo/산출물·네 bundle 기준을 대조했다. 제품 소스·스크립트·웹사이트·앱 설치·tag·서명·공증·공개 상태는 변경하지 않았다.

시작 작업 commit은 b62083b8, 제품 조사 기준은 origin/devel e75d3ec4, 직전 public source는 64ed89f8이다. 현재 source bundle은 모두 0.2.2/20이며 다음 0.2.3/21의 구현은 Stage 2 승인 후다.

## 주요 판단

- rhwp v0.8.7의 공식 commit·native/WASM/Studio를 일치시킨 #578 이후 Mac 설치 글꼴의 기존 목록·문서·출력·Finder 연결이 병합되어 있다. Mac scope의 #562 / #569 종료 상태와 Windows #566 및 성능 #581 독립 OPEN 상태를 확인했다.
- first-parent PR 19개 / 전체 병합 PR 28개. 기존 웹 공개와 v0.2.2 수용·종료·main 운반을 새 앱 기능으로 중복 집계하지 않았다. 새 앱 요약은 #572 / #578 / #579 / #582 / #583 중심으로 준비한다.
- #480 완료 코멘트의 PR #481 안전 차단이 현재 코드에 있다. 저장 policy/경고는 v0.2.2와 byte 동일하며 보호 원본에 in-place 저장을 허용하지 않는다. 미완료는 native 암호화 저장/round-trip이지 이번 조사에서 새로 발견한 무경고 원본 overwrite가 아니다. 최신 runtime 확인은 최종 DMG의 S1로 남긴다.
- #525 폐기 후 복구 후보는 OPEN 후속이다. native clearUnsavedChanges는 bool만 해제하고 폐기 bridge 추가가 없다. controller 변화는 property 접근성뿐이며 이를 수정 완료로 표시하지 않는다. 최신 UI 재현·원본 보존 및 명시 한계 수용은 최종 후보 S2로 남긴다.
- 읽기 전용 조사에서 Stage 2 준비의 새 차단 요소를 발견하지 않았다. 전체 공개 수용/승인은 아직 대기이며 S1/S2 등 최종 후보의 실제 실패·손상이 발생하면 별도 수정/공개 차단 판정을 제시한다.

## 검증

| 확인 | 결과와 경계 |
|------|-------------|
| 최신 앱·upstream | public v0.2.2, upstream v0.8.7. 10/11 CLI 재패키징은 동일 source이며 알한글 CLI 번들 입력이 아님 |
| main/devel content gate | PASS, main-only 0, prospective tree = devel tree |
| core generated info | verifier PASS |
| Studio 자산·menu adapter | verifier PASS, 공식 tag/commit·asset receipt 일치 |
| native matcher | --verify PASS |
| Cargo/native pin | repo/tag/features와 resolved commit 일치 |
| 네 bundle/manifest/lock | 0.2.2/20 공통 및 v0.8.7/1a76570e 공통 |
| reference header/staticlib | 실제 SHA256·size 모두 lock과 일치. 새 빌드/컴파일 성공 주장 아님 |
| PR/delta helper | 정해진 v0.2.2..e75d3ec4에서 완료. 원문/보고서와 local merge 경로로 수동 분류 보완 |
| 제품 경로 변경 | origin/devel 대비 Sources/RustBridge/Frameworks/scripts/project.yml/.github/docs/README/core lock 변경 없음 |

PR API files의 100개 제한으로 #578 / #579 보고서/파일 경로가 누락될 수 있어 local merge의 290/218개 전체 경로를 대조했다. 자동 helper의 분류/closing 후보는 실제 공개 목록으로 사용하지 않았다. 관련/참고 이슈와 완료 scope를 직접 구분했다.

새 앱 빌드, XCTest/GUI/성능·새 VM 설치·공증 DMG·PDF/인쇄·공개 URL/Sparkle 검증은 이번 단계에서 실행하지 않았다. 기존 #569/#580 결과는 인계 근거이며 새 최종 후보 PASS가 아니다. 의미 있는 필수 read-only 검사는 모두 통과했다.

## 산출물

- [v0.2.3 준비 기록](../release/v0.2.3.md): 28개 PR 표, 사용자 변화 초안·기존 위험·현재/미확정 identity.
- [최종 후보 수용표](../tech/task_m900_584_release_acceptance.md): I1–I3 / M1–M8 / S1–S2 / R1 / P1–P3, 모든 runtime 대기.
- [선별 출처](../report/assets/task_m900_584/stage1/context.json), [분류](../report/assets/task_m900_584/stage1/pr-analysis.json), [source 조사](../report/assets/task_m900_584/stage1/source-review.json), [산출물](../report/assets/task_m900_584/stage1/reference-artifacts.json), [checksum](../report/assets/task_m900_584/stage1/SHA256SUMS).
- 원문·helper 초안/raw 로그는 build.noindex/task584/stage1. 재현 가능한 read-only 자료만 만들었으며 대형 app/DMG/cache를 추가하지 않았다. 가용 공간 약 15GiB 관측은 삭제량/공간 확보 성공으로 해석하지 않는다.

## 다음 승인 대상

Stage 1 결과 수용 및 [구현계획 Stage 2](../plans/task_m900_584_impl.md)의 네 bundle 0.2.3/21·필요 workflow 입력·릴리즈/Pages/Mac 안내 후보·최소 build/helper/화면 검증을 승인받는다. 실제 Pages는 public asset gate를 유지하여 공개 전 v0.2.2 제공 상태를 보존한다.

이번 단계에서는 공개 위험의 조사/조건을 제시했으며 #480 / #525 수정·이슈 close, 새로운 최소 성능 목표, Windows 기능 또는 별도 upstream 작업을 추가하지 않았다. Stage 2의 준비 보고/구체 push·Open PR은 결과가 준비된 후 별도 승인한다. tag·서명·공증·임시 설치·공개 배포도 후속 gate를 따른다.
