# Task M020 #563 글꼴 마이그레이션 조사·설계 최종 보고서

- 일자: 2026-09-17
- 이슈: [#563](https://github.com/postmelee/alhangeul-macos/issues/563), 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562)
- 마일스톤: [글꼴 마이그레이션](https://github.com/postmelee/alhangeul-macos/milestone/22) / M020 / v0.2 계열
- 작업 브랜치: `local/task563`, PR 대상: `devel`
- 상태: 조사·설계·독립 실험·GitHub 인계 완료, 2026-09-17 최종 보고·PR 게시 승인, PR 검토/통합 단계

## 결과

**기존 글꼴을 알한글 관리 영역에 독립 복사하고 새 프로세스의 화면·PDF에 공급하는 방식은 구현 가능하다.** 공개 테스트 자산의 static TTF·OTF와 가변 TTF 1종(wght 400/700)에서 이를 확인했다. 실제 제품의 가져오기 UI·정식 저장소·Studio·출력·확장 연결은 후속 구현으로 남겼다.

사용자 요구인 한컴 제거 후 사용을 위해 원본 참조가 아닌 독립 관리 객체를 선택했다. 원본 bookmark는 재가져오기 보조이며 렌더 필수 조건이 아니다. 실제 한컴 글꼴의 사용 조건과 signed 제품에서 모든 표시·출력 경로를 검증하기 전에는 한컴 제거 후 사용이 보장된다고 안내하지 않는다.

## 확인한 사실과 지원 경계

| 항목 | 결과 및 한계 |
|------|-------------|
| Mac 위치 | 설치된 한컴 뷰어 12.31.8의 문서용 TTF 9개 확인. 편집기 공식 위치와 다르며 편집기 실환경·권한 수용은 남음 |
| TTF·OTF | 관리 복사본만으로 새 프로세스에서 화면·PDF 적용. signed 제품 전체 지원을 검증한 것은 아님 |
| TTC | 두 face metadata 조회 가능. raw 공급의 bold 요청이 regular로 표시돼 별도 face 선택/공급 검증 필요 |
| 가변 | 공개 1종의 1 sfnt face·9 named instances 및 wght 400/700 확인. 임의 글꼴·다른 축은 미검증 |
| PDF | 목표 PS 임베딩·비 MacRoman subset ToUnicode·한글/영문 8행 정확 추출 확인. 제품 Noto 정책·검색/복사 회귀·실인쇄는 후속 |
| Windows | 공식 버전별 위치와 입력·ZIP 설계 정리. 실제 Windows 폴더/ZIP 가져오기 구현·검증은 후속 |
| HFT | 초기 미지원. decoder/변환 구현 없음 |
| 실제 이름/확장 | 한글 별칭 resolver, Studio CSS/CanvasKit, signed App Group, CoreGraphics/Skia, Finder 캐시와 최소 OS는 후속 |

실험 환경은 macOS 26.5.2, arm64다. macOS 12 target 컴파일 통과와 macOS 12 runtime 검증은 구분한다. 상용 글꼴·사용자 원본은 수정하거나 저장소에 추가하지 않았다.

## 설계와 산출물

- [설계서](../tech/font_migration_design.md): 위치/형식/사용 조건, 독립 저장소, 원자적 게시, 중복·충돌, 다국어 이름·face/axes, snapshot/lease, renderer 공급, 지원 표와 인계의 진실 원천.
- [재현 스크립트](../../scripts/probe-font-migration.sh): 명시적 OFL 입력으로 fixture를 준비하고 A/B/C/D 새 프로세스 실험을 실행한다. [Python 보조 코드](../../scripts/font_migration_probe.py)와 [Swift WebView probe](../../scripts/font_migration_probe.swift)는 제품 dependency에 편입하지 않는다.
- [Stage 1](../working/task_m020_563_stage1.md): 실제 위치·metadata·공식 자료 조사.
- [Stage 2](../working/task_m020_563_stage2.md): 독립 저장·중복/이름·renderer 공급 계약.
- [Stage 3](../working/task_m020_563_stage3.md): 재현 명령, 원본/관리 파일 부재 대조군, PDF·화면 증거 및 실패 보정.
- [Stage 4](../working/task_m020_563_stage4.md): 지원 범위 확정·GitHub 본문 반영/재조회·후속 소유권.

불변 객체와 manifest를 분리하고 기존 선택을 자동 덮어쓰지 않는다. 출력 snapshot/lease는 진행 중 삭제에도 사용 객체를 보존한다. App Group identifier/서명과 복구 구현은 #564 에서, 실제 확장 공유는 #568 에서 수용한다. 용량·개수 한도는 설계 후보이며 성능 검증 전 확정치가 아니다.

## 검증 근거

Stage 3의 최종 실행 `build.noindex/task563-font-migration/run-68pxsn4y/summary.json`에서 static·variable 일부 공급, 재실행 화면/PDF 일치, 대조군 구별, 변조 거부를 통과했다. TTC bold 불일치는 미해결 제약으로 명시했다.

- A 정상 공급 → 실험용 원본 제거 → B 새 프로세스에서 행별 raster/폭·화면 PNG·PDF raster가 정확히 같았다.
- C 관리 경로 부재에서는 8개 font load가 거부됐고 리소스 공급 0개, PDF 목표 PS 부재 및 다른 fallback을 확인했다.
- D 관리 bytes 변조는 WebView/PDF 생성 전 hashMismatch로 거부됐다.
- `pdffonts`·`pdftotext`·`pdftoppm` 및 이미지 확인을 함께 사용했고 원본 글꼴/고지 8개 입력 파일의 전후 hash가 같았다.
- Swift 경고 없는 컴파일·CLI 실패 경계·구문·문서 링크/표기 검증을 수행했다. Stage 4는 문서와 이슈 인계만 변경해 렌더 실험을 다시 실행하지 않았다.

생성 font/PDF/PNG는 Git 제외인 `build.noindex/`에 있고 재현 방법은 추적 문서에 있다. 기존 제품 전체 테스트를 이번 기능 지원의 증거로 주장하지 않는다. `.app`/`.appex` 등록, 사용자 한컴 삭제, 제품 배포는 수행하지 않았다.

## 후속 구현과 승인 요청

[상위 #562](https://github.com/postmelee/alhangeul-macos/issues/562)와 #563 ~ #569 본문 및 마일스톤 설명에 결과를 반영·재조회했다. native 하위 연결 7개, 제목·마일스톤 및 OPEN 상태는 유지했다. 제품 미구현 항목과 #563 최종 승인 항목은 완료 표시하지 않았다.

| 순서 | 이슈 | 구현·수용 책임 |
|------|------|----------------|
| 1 | [#564 공통 기반](https://github.com/postmelee/alhangeul-macos/issues/564) | 독립 저장·복구·충돌·snapshot/lease·공급 계약 |
| 2 | [#565 Mac 탐색](https://github.com/postmelee/alhangeul-macos/issues/565) | 확인된 후보 탐색·권한/위치 선택·실제 설치본 |
| 2 | [#566 Windows 입력](https://github.com/postmelee/alhangeul-macos/issues/566) | 실제 폴더/ZIP·제한·한글 경로·원본 입력 부재 |
| 2 | [#567 이름·화면](https://github.com/postmelee/alhangeul-macos/issues/567) | 실제 이름/스타일·CSS/CanvasKit·저장/재열기·TTC/가변 |
| 3 | [#568 출력·확장](https://github.com/postmelee/alhangeul-macos/issues/568) | 전용 PDF·실인쇄·signed 공유·native 공급/캐시 |
| 4 | [#569 통합 검증·안내](https://github.com/postmelee/alhangeul-macos/issues/569) | 실제 제품별 이전·원본 부재 수용, Mac/Windows 단계 안내 |

2026-09-17 작업지시자의 “진행해줘”로 최종 보고와 PR 게시를 승인받았다. `publish/task563`에서 `devel` 대상 PR을 게시한다. merge 확인 또는 별도 승인 전에는 #563 이슈를 닫지 않는다. 다음 제품 구현은 #564 의 자체 수행계획·구현계획 승인부터 시작한다. 공개 릴리스·웹페이지 배포는 별도 지시에 따른다.


## PR #570 CI 보완 — 저장 실패 완료 대기

- 작업지시자의 CI 실패 제보에 따라 기존 문서 lifecycle smoke를 진단했다. [실패 실행](https://github.com/postmelee/alhangeul-macos/actions/runs/35201102610)의 macOS validation은 HWPX의 close save failure 뒤 `timeout: confirmation sheet`로 종료됐다. Script syntax checks는 통과했다.
- 기존 테스트는 `webViewErrorMessage != nil`만 기다렸다. 실제 Coordinator는 `onError` → 비동기 JS save lock 해제 → 저장 completion 순서로 실행하므로 오류 표시가 close controller의 확인 처리 완료를 보장하지 않는다. 그 사이 termination 요청은 진행 중 확인으로 인해 즉시 취소될 수 있다.
- controller의 `isPresentingConfirmation`을 내부 읽기 전용으로 노출하고, smoke에서 오류와 확인 처리 완료를 함께 기다리도록 변경했다. 상태 전이·저장·종료의 제품 동작은 변경하지 않는다. 다음 termination 요청의 `.terminateLater`와 즉시 취소되지 않았음도 명시적으로 검증한다. timeout 증대·테스트 제외는 하지 않았다.
- 로컬 독립 진단은 실제 `DocumentCloseConfirmationController`/`DocumentTerminationCoordinator`와 500ms 지연 저장 callback을 사용했다. 기존 오류-only 조건의 즉시 취소를 재현하고, 새 완료 조건 이후 실제 NSAlert sheet 표시·취소·dirty 보존을 통과했다. 이는 mock Store/dispatcher 진단이며 전체 Studio 통합 실행을 대신하지 않는다. 경고 없는 Swift 컴파일 및 출력은 `build.noindex/task563-close-race/result.log`에 있다.
- 동일 구 head의 실패 job 재실행도 시작했지만 근본 경합이 코드·독립 진단에서 확인돼 보완 커밋을 별도로 게시한다. 최종 전체 macOS/Studio 결과는 보완 head의 PR CI를 기준으로 확인한다.
