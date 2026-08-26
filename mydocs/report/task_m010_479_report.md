# Task M010 #479 최종 결과 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#479 Debug·개발 빌드의 production 익명 이벤트 전송을 차단한다](https://github.com/postmelee/alhangeul-macos/issues/479) |
| 마일스톤 | `M010` (`v0.1`) |
| 대상 통합 브랜치 | `devel` |
| 작업 브랜치 | `local/task479` |
| 단계 수 | 3 |
| 결과 | Debug·기본 개발 configuration의 production endpoint를 비활성화하고 Release에만 기존 공개 endpoint를 주입 |

`v0.1.10` analytics 기능 병합 뒤 실행한 Debug·개발 빌드가 공통 plist의 production URL을 사용해 운영 집계에 이벤트를 보낼 수 있던 문제를 수정했다. `project.yml`을 endpoint configuration의 단일 편집 원본으로 두고, 공통 plist는 전용 build setting placeholder만 참조한다.

Runtime과 payload schema는 변경하지 않았다. Debug에서는 빈 endpoint를 기존 resolver가 `nil`로 거부하고 coordinator가 connectivity·transport 경로를 시작하지 않는다. Release는 동일한 production HTTPS endpoint를 유지한다.

## 단계별 결과

| 단계 | 결과 | 커밋 |
|------|------|------|
| Stage 1 | 현행 Debug·Release 공통 production URL을 재현하고 XcodeGen base 빈 값·Release override 계약 확정 | `f867544` |
| Stage 2 | Release-only setting, source/bundle verifier, 실패 fixture와 PR CI Debug bundle gate 구현 | `cf9dd26` |
| Stage 3 | 새 Debug·Release bundle과 전체 회귀 최종 검증, 과거 운영 집계 한계 문서화 | `fde142f` |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Info.plist` | production URL literal을 `$(ALHANGEUL_APP_EXECUTION_ENDPOINT)` placeholder로 교체 |
| `project.yml` | HostApp base endpoint를 빈 값으로 두고 Release에만 production URL 주입 |
| `Alhangeul.xcodeproj/project.pbxproj` | XcodeGen이 생성한 Debug 빈 setting·Release URL 반영 |
| `scripts/ci/verify-app-execution-endpoint-config.sh` | source configuration과 선택적 Debug·Release built plist 검증 |
| `scripts/ci/test-app-execution-endpoint-config.sh` | 정상 configuration과 invalid base·Release·plist fixture 검증 |
| `.github/workflows/pr-ci.yml` | script-checks fixture와 macOS Debug built bundle endpoint gate 추가 |
| `mydocs/tech/task_m040_453_app_execution_analytics_contract.md` | configuration 소유, unsigned Release 주의점과 설정 분리 전 운영 집계 한계 추가 |
| `mydocs/plans/task_m010_479.md` | 이슈 수행 범위·완료 조건·제외 경계 기록 |
| `mydocs/plans/task_m010_479_impl.md` | 3개 Stage 구현·검증·중단 기준 기록 |
| `mydocs/working/task_m010_479_stage1.md` | 현행 재현과 configuration 계약 확정 근거 |
| `mydocs/working/task_m010_479_stage2.md` | Release-only 구현과 자동 회귀 gate 결과 |
| `mydocs/working/task_m010_479_stage3.md` | 최종 bundle·운영 계약 검증 결과 |
| `mydocs/orders/20260826.md` | Task #479 오늘할일 완료 처리 |
| `mydocs/report/task_m010_479_report.md` | 최종 결과와 수용 기준 대조 |

HostApp analytics runtime, payload/outbox schema, 문서 parser·renderer·저장·PDF·인쇄, Quick Look·Thumbnail source는 변경하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| Debug built endpoint | production URL | 빈 문자열 |
| Release built endpoint | production URL | 동일 production URL |
| source `Info.plist` production URL literal | 1개 | 0개 |
| endpoint configuration source | 공통 plist literal | `project.yml` HostApp Release setting |
| configuration 자동 fixture | 없음 | 정상 1개 + 실패 3개 |
| PR CI built bundle 검사 | 없음 | Debug app endpoint 1개 gate |
| analytics runtime·payload field 변경 | 해당 없음 | 0개 |
| 전체 HostAppTests | 기준 유지 | 161/161 통과 |
| clean Debug·Release app build | 둘 다 production URL | 둘 다 성공, endpoint 분리 확인 |
| 구현 단계 | 계획 전 | 3/3 완료 |

최종 보고서 작성 전 `devel...fde142f` task diff는 13개 파일, 1,265줄 추가·1줄 삭제였다. 이 중 948줄은 수행·구현계획과 3개 단계 보고서이며, 제품 동작 변경은 plist·XcodeGen setting과 CI verifier에 한정된다.

## 검증 결과

| 수용 기준 | 검증 근거 | 결과 |
|-----------|-----------|------|
| Debug·개발 build production 전송 차단 | base 빈 값, Debug built plist 빈 값, missing endpoint connectivity·transport 0회 test | OK |
| Release production 수집 유지 | Release built plist가 `project.yml` exact HTTPS URL과 일치 | OK |
| endpoint 없음·잘못된 값의 비차단 | resolver allowlist, coordinator/outbox test와 전체 HostAppTests | OK |
| opt-out·outbox·payload 회귀 없음 | 전체 HostAppTests 161/161, payload 여섯 key 유지 | OK |
| XcodeGen 단일 진실 원천 | `project.yml` 편집 후 연속 generate에서 추가 diff 없음 | OK |
| configuration drift 자동 검출 | source verifier, 실패 fixture 3개, PR CI Debug bundle gate | OK |
| Debug·Release 최소 build | unsigned Debug 19.037초, Release 31.049초 성공 | OK |
| 공통 bundle 계약 유지 | `0.1.10 (16)`, Sparkle key, document type·UTI 동일 | OK |
| bundled Studio·Swift 경계 유지 | source/두 bundle assets, no-AppKit, core build info 검증 | OK |
| 과거 운영 집계 한계 문서화 | analytics 장기 계약에 v0.1.9 행의 사후 구분 불가·미보정 원칙 반영 | OK |
| production 합성 이벤트·외부 데이터 변경 제외 | 앱 미실행, Worker 요청·삭제·재분류 미수행 | OK |

최종 보고 절차에서 커밋된 HEAD 기준으로 XcodeGen, 전체 HostAppTests, Debug·Release build, 두 built plist verifier, 정상·실패 fixture, shellcheck, no-AppKit, core build info와 source·bundle Studio asset 검증을 다시 실행해 모두 통과했다.

## 잔여 위험과 후속 작업

- Endpoint 분리는 서명·공증 상태가 아니라 Xcode `Release` configuration 기준이다. 로컬 unsigned Release app도 production endpoint를 포함하므로 production 네트워크 smoke에 실행하지 않는다.
- PR CI는 Debug built bundle을 직접 검사하고 Release는 source configuration gate로 검증한다. 이번 Stage 3에서 clean Release bundle을 확인했으며 실제 release artifact preflight에서도 exact endpoint를 확인해야 한다.
- 설정 분리 전 운영 행은 payload만으로 공개·개발 실행을 사후 구분할 수 없다. 기존 행을 삭제·재분류하지 않고 관측 이벤트로만 해석한다.
- 로컬 LaunchServices에는 과거 `build.noindex/` app의 stale record가 남지만 active PlugInKit provider root는 두 설치본뿐이다. Finder/release smoke 전 등록 위생 확인을 계속 적용한다.

별도 후속 이슈가 필요한 미완료 구현은 없다. Staging endpoint나 production 합성 smoke가 필요해질 때는 데이터 제거 정책과 함께 별도 이슈·승인을 받아야 한다.

## 작업지시자 승인 요청

Issue #479의 세 Stage, 수용 기준과 최종 통합 검증을 모두 완료했다. `publish/task479`를 `devel` 대상으로 게시한 PR의 리뷰와 merge 승인을 요청한다. Issue는 PR merge 뒤 `pr-merge-cleanup` 절차에서 close한다.
