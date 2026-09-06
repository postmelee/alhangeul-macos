# Task M900 #494 Stage 2 완료보고서

## 단계 목적

[구현계획서](../plans/task_m900_494_impl.md)의 Stage 2에 따라 포함 PR과 이슈·보고서를 대조하고, v0.1.11 릴리스 기록과 README·Pages·GitHub Release 본문 후보를 준비한다.

2026-09-06 작업지시자가 Stage 2 진행을 승인했다. 작업 브랜치는 `local/task494`이며 분석 범위는 `v0.1.10..54a6866e074aefc62557aa25df5838e870105c49`다. 앱·build·upstream 기준은 `0.1.11 (17)`, `rhwp v0.8.6`이다.

## 산출물

| 파일 | 변경 |
|------|------|
| `mydocs/release/v0.1.11.md` | 포함 PR 10개 분석, 공개 본문 여섯 절, 단계별 검증 인계와 알려진 한계 |
| `mydocs/release/index.md` | v0.1.11 공개 준비 상태와 후보 링크 추가 |
| `README.md` | v0.1.11 후보 요약·provenance, 현재 공개 v0.1.10 및 저장 주의 구분 |
| `docs/index.html` | 준비 안내, 예정된 다운로드·노트 링크, 저장 경계·Homebrew 현재 상태 |
| `docs/updates/index.html` | 신규 릴리스 항목, 공개 준비·설치 안내 |
| `docs/updates/v0.1.11.html` | 사용자용 변화, 한계와 설치 안내 |
| `docs/updates/v0.1.0.html` ~ `v0.1.10.html` | helper로 이전 버전 안내 banner만 갱신 |
| `mydocs/plans/task_m900_494.md`, `task_m900_494_impl.md` | Stage 2 완료와 Stage 3 승인 대기 반영 |
| `mydocs/orders/20260906.md` | Task #494 진행 상태 갱신, 기존 Task #492 완료 행 보존 |
| 이 보고서 | 검증 결과·보정 사항과 다음 단계 승인 범위 |

추적 변경은 문서 21개 파일이다. 로컬 산출물은 `build.noindex/task494/stage2/`에 두었다. PR·Issue·upstream 원문 JSON은 `evidence/`, 자동 초안은 `pr-analysis.md`·`delta-checklist.md`, 본문 검사 후보는 `release-notes-template.md`, 최종 검사 출력은 `verification.log`다. Pages artifact는 `pages/`, 실제 화면은 `home-viewport.png`, `updates-viewport.png`, `release-viewport.png`, `previous-release-viewport.png`다.

## 본문 변경 정도와 무손실 여부

신규 문서는 릴리스 기록·사용자 노트·단계 보고서 3개이며 나머지 18개는 기존 문서의 필요한 부분만 변경했다. 제품 source, plist, workflow, Rust dependency, bundled Studio, Xcode project, CSS·JavaScript와 Cask는 변경하지 않았다.

이전 버전 HTML 11개에서 generated banner를 제거한 뒤 변경 전후 전체 문자열이 같음을 확인했다. 따라서 v0.1.10의 HWP3·보호 문서 저장 위험을 포함한 역사적 본문과 해당 버전 다운로드 링크는 보존된다. `mydocs/release/v0.1.10.md`, repository `docs/appcast.xml`과 `Casks/alhangeul.rb`도 변경하지 않았다.

README의 이전 긴 릴리스 요약은 v0.1.11 후보 요약으로 교체하고, 현재 공개 v0.1.10의 짧은 요약·실제 설치 링크·저장 주의를 유지했다. 과거 상세 설명은 기존 릴리스 기록과 Pages에서 계속 조회할 수 있다. 홈은 기존 notice 스타일을 재사용했고 앱 기능이나 페이지 동작 코드는 수정하지 않았다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| PR 분석 helper, `v0.1.10 HEAD` | 성공, 포함 merge PR 10개와 원문 근거 생성 |
| delta checklist helper, 같은 범위 | 성공, exact candidate와 변경 path 목록 생성 |
| PR·Issue·보고서 대조 | 사용자-facing 7개, 개발·배포 2개, 이전 closeout 1개로 보정 |
| GitHub Release note writer | 성공, 지정 여섯 절과 표준 설치·상세 기록 구조 생성 |
| release note template checker | 통과, 초기 PR 설명의 금지 문자열 `보정합니다`를 완료 동작 표현으로 바꾼 뒤 재검증 |
| GitHub body validator | 통과 |
| 이전 버전 banner 갱신·`--check` | 통과, latest note v0.1.11 기준 11개 정렬 |
| HTML·링크 | 14개 페이지, 로컬 asset/link/fragment 참조 164개, 중첩 tag·중복 ID·aria-labelledby 검사 통과 |
| 포함 PR 표·이슈 구분 | 10행·9개 column, 해결 이슈 7개, 미완료 #480 및 upstream #6635 별도 분리 |
| 과거 본문 보존 | banner 제외 이전 HTML 11개 byte 문자열 동일, 기존 릴리스 기록·appcast·Cask diff 없음 |
| Pages artifact·appcast | 공개 XML 정상, 최신 `0.1.10 (16)`, artifact의 appcast와 byte 동일 |
| 실제 화면 | Browser 기본 1280×720에서 홈·업데이트 목록·새 노트·이전 노트 확인, 목록 이동·banner 링크 확인 |
| `git diff --check` | 통과 |

공개 appcast SHA256은 `36b5d62bc9477bf6b586c19888071ba8610be0ac42a116b2a8be7bf5cee3af5a`다. 첫 item의 version/build는 `0.1.10 (16)`, DMG는 `alhangeul-macos-0.1.10.dmg`, 길이는 169,177,234 bytes이며 기존 EdDSA signature를 그대로 보존했다. 이를 로컬 Pages artifact에 복사했고 공개 feed는 수정하지 않았다.

GitHub Release 본문의 64자리 0 digest는 ignored 형식 검사 후보에만 사용했다. 릴리스 기록에는 v0.1.11 digest·size를 미확정으로 명시했으며 실제 배포에 사용할 값으로 제시하지 않았다. 신규 Release/DMG/Pages의 원격 경로는 아직 게시되지 않은 예정 링크이므로 현재 HTTP 다운로드 성공으로 판정하지 않았다.

### 분석에서 바로잡은 내용

- PR #481 변경은 upstream sync가 아니라 보호 문서 원본 저장 차단이다. Issue #480 항목은 OPEN이며 암호 저장 자체의 완료 이슈로 분류하지 않았다.
- PR #483 변경은 앱의 HWP3 변환 저장 안전성 개선이다. #482, #484, #372, #459, #492, #479, #488 항목만 live CLOSED 및 해당 타스크 근거를 확인해 해결 목록에 넣었다.
- PR #487/#490 변경은 개발·배포 검증이므로 사용자 주요 변화에서 제외하고 관련 PR·해결 이슈에만 설명했다. PR #478 이전 v0.1.10 closeout과 이전에 해결한 #455/#453/#149/#472 항목도 신규 공개 해결 목록에서 제외했다.
- `edwardkim/rhwp#6635`는 실제로 키보드 활성화 이슈이며 CLOSED다. upstream PR #6786 merge `3960844b2f4a546a120cbbb50ae72ef2e5e7239f`와 고정 v0.8.6 비교는 `diverged`, ahead 373 / behind 1이다. 따라서 해당 수정은 이번 tag의 조상으로 포함되지 않으며 downstream 색상 선택기 위치 수정과 구분했다. 혼합 서식 문제 해결 여부는 이 이슈 종료로 추정하지 않았다.

## 잔여 위험

- Stage 2는 문서 검증이다. 기존 PR의 테스트·GUI 결과를 새 v0.8.6 통합 후보나 signed 설치본의 통과 결과로 이월하지 않았다. 앱·package·서명·공증·실제 업데이트 검증은 아직 대기 중이다.
- 준비 문구와 예정 다운로드 링크는 Stage 4 후보 재검토 및 Stage 5 공식 공개 시 실제 상태에 맞춰 갱신해야 한다. 이전 버전 banner의 “최신 v0.1.11”도 배포용 후보 상태이며 현재 public Pages에 올리지 않았다.
- Homebrew Cask는 v0.1.10을 유지한다. v0.1.11 official digest가 확정되고 해당 배포가 승인되기 전에는 새 버전 반영 완료로 표시하지 않는다.
- native 암호 저장·HWP3 원형 저장은 미지원이며 PDF 한글 mapping을 모든 글꼴·OCR·읽기 순서 보장으로 확대하지 않는다. upstream 키보드·혼합 서식과 macOS picker 위치를 별도 검증한다.
- main docs-only Pages workflow는 draft flag 자체를 검사하지 않는다. Stage 4에서 asset 미공개로 skip을 확인한 뒤 draft를 만들고, draft 뒤 재실행의 공개 효과를 다시 확인해야 한다.

## 다음 단계 영향

Stage 3에서는 이 문서 후보와 Stage 1 source를 기준으로 exact upstream provenance, Rust/ABI, Swift 테스트·Debug/Release build, native renderer·Finder 정책, universal package를 검증한다. 특히 저장 원본 보존, PDF 한글 선택·반복 인쇄, 열기 복구와 색상 선택기는 v0.8.6 통합 결과로 다시 확인한다.

Source 준비 중 실제 실패나 새 변경이 생기면 검증 결과와 공개 문구를 함께 보정한다. 외부 rehearsal은 exact ref·입력·별도 산출물 경로를 준비한 뒤 승인 범위를 확인한다. Stage 4의 source PR/main/tag와 signed draft, Stage 5의 official 공개·Pages/Sparkle·Homebrew는 해당 단계 절차를 따른다.

## 승인 요청

Stage 2의 문서 후보와 검증 결과 검토 후 **Stage 3: source·앱·package 검증** 진행 승인을 요청한다. 저장소의 단계별 승인 규칙에 따라 다음 단계는 작업지시자의 진행 지시 뒤 시작한다.
