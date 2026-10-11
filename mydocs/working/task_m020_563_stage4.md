# Task M020 #563 Stage 4 완료보고서

- 일자: 2026-09-17
- 승인 근거: Stage 3 완료 보고 후 작업지시자의 “진행해줘”
- 마일스톤: M020 / 글꼴 마이그레이션 / v0.2 계열
- 브랜치: `local/task563`
- 상태: 지원 범위 정리·GitHub 후속 인계 완료, 최종 보고 승인/PR 대기

## 1. 결과

조사·독립 실험으로 확인한 범위와 실제 제품에 남은 검증을 분리하고, **다음 구현은 #564 공통 글꼴 가져오기·관리 기반부터 시작**하도록 인계했다. 제품 기능은 아직 완성되지 않았다.

static TTF·OTF를 우선 구현한다. TTC는 raw 공급의 bold 오선택을 해결한 뒤, 가변은 renderer별로 검증한 축·범위에 한해 지원하도록 했다. HFT 초기 미지원과 Windows helper 제외는 유지한다. 실제 Mac/Windows 입력·signed sandbox·Studio·출력·확장은 후속 수용 대상이다.

결정의 진실 원천은 [설계서 17절](../tech/font_migration_design.md#17-stage-4-확정-범위-및-제품-구현-인계)이며, 전체 작업 결과는 [최종 보고서](../report/task_m020_563_report.md)에 정리했다.

## 2. GitHub 반영·재조회

기존 본문을 읽고 변경 직전에 다시 대조한 뒤 body-file로 반영했다. 각 본문은 `scripts/validate-github-body.sh`를 통과했으며 반영 후 기대 본문과 정확히 일치하는지 재조회했다.

| 대상 | 반영 내용 | 확인 결과 |
|------|-----------|-----------|
| [#562](https://github.com/postmelee/alhangeul-macos/issues/562) | 우선/조건부 형식, 독립 복사, 제품 미완료 상태, 구현 순서 | 본문 일치, OPEN 유지 |
| [#563](https://github.com/postmelee/alhangeul-macos/issues/563) | 조사 결과·산출물·후속 소유권, 표/설계 완료 표시, 최종 승인 대기 | 본문 일치, OPEN 유지 |
| [#564](https://github.com/postmelee/alhangeul-macos/issues/564) | App Group, 불변 객체·manifest, 중복/충돌, snapshot/lease·삭제·복구 | 본문 일치, OPEN 유지 |
| [#565](https://github.com/postmelee/alhangeul-macos/issues/565) | 뷰어/편집기/OS 글꼴 구분, 실제 경로·권한 선택·취소 | 본문 일치, OPEN 유지 |
| [#566](https://github.com/postmelee/alhangeul-macos/issues/566) | Windows 실입력, ZIP 제한, 원본 이름 보존과 hash 저장명 구분 | 본문 일치, OPEN 유지 |
| [#567](https://github.com/postmelee/alhangeul-macos/issues/567) | CSS/CanvasKit 각각 공급, 실제 이름 resolver, TTC/가변·캐시·저장 | 본문 일치, OPEN 유지 |
| [#568](https://github.com/postmelee/alhangeul-macos/issues/568) | signed 공유, PDF/Noto·Unicode, CoreGraphics/Skia·캐시·실인쇄 | 본문 일치, OPEN 유지 |
| [#569](https://github.com/postmelee/alhangeul-macos/issues/569) | OS별 단계 안내, 원본 부재 수용, 한컴 삭제 안내의 조건 | 본문 일치, OPEN 유지 |
| [마일스톤 22](https://github.com/postmelee/alhangeul-macos/milestone/22) | M020/v0.2 계열, TTC/가변 조건부, 구체 patch·일정 미정 | 설명 일치, 이름·기한·상태 유지 |

상위 #562 아래 native sub-issue 연결 7개(#563 ~ #569)가 유지됨을 API로 확인했다. 모든 이슈의 기존 제목과 마일스톤 연결을 유지했다. 새 이슈·공개 코멘트는 만들지 않았으며 이슈 종료, PR 생성·push, 제품/웹페이지 배포는 수행하지 않았다.

## 3. 후속 순서와 사용자 안내

1. #563 최종 보고 승인·PR 검토/통합 후 #564 공통 관리 계층의 수행계획을 시작한다.
2. #564 이후 #565 Mac 탐색·#566 Windows 입력·#567 화면/이름 해석을 구현한다. Mac 사용자 사례를 우선 확인하되 Windows 범위는 유지한다.
3. #568 출력·확장 최종 수용은 위 입력/화면 결과에 의존한다. #569 에서 전체 통합 결과와 실제 제품 안내를 확정한다.

사용자가 한컴을 지운 뒤에도 쓸 수 있다는 문구는 실제 한컴 자산의 사용 조건·관리 복사·원본 부재 후 재실행·화면/PDF/인쇄/Quick Look/썸네일 수용을 완료한 제품과 버전에 한정한다. 권한 선택이 필요한 Mac까지 무조건 한 번 클릭으로 끝난다고 안내하지 않는다. Windows는 검증된 버전별 경로에서 복사·압축·전송·가져오기·적용 확인을 안내한다.

## 4. 검증 및 변경 범위

- GitHub 본문 8개와 마일스톤 설명의 준비·반영·재조회, native 연결 7개 및 OPEN 상태 보존을 확인했다. 실행 중 임시 영수증은 `/tmp/task563-stage4/verified.json`에 남겼고 결과는 위 표에 기록했다.
- 설계 지원 표의 미확인 항목마다 후속 소유 이슈를 배정했다. 현재 배포 앱의 기능 지원으로 오해할 문구와 원본 참조/복사 선택의 모호함을 보정했다.
- 변경 문서의 링크·이슈 표기, `git diff --check`, 기대 파일 범위를 검증했다. Stage 3 증거와 스크립트는 변경하지 않아 렌더 실험·제품 빌드를 반복하지 않았다.
- 이번 단계의 저장소 변경은 설계·계획 상태·오늘할일·단계 보고·최종 보고뿐이다. 제품 소스·entitlement·core pin 및 사용자 파일은 변경하지 않았다.

## 5. 승인 요청

Stage 1–4의 조사·설계·최소 실험·후속 인계 작업은 완료했다. 최종 보고 승인 후 `devel` 대상 PR 게시 절차로 진행한다. #563 종료는 merge 확인 또는 별도 승인 뒤에 수행하고, 후속 #564 제품 구현은 자체 계획·승인 단계로 시작한다.
