# Task M010 #488 최종 결과 보고서

## 작업 요약

- 이슈: [#488 분석 endpoint 검증 gate 보강: release artifact preflight와 production host 고정](https://github.com/postmelee/alhangeul-macos/issues/488)
- 마일스톤: `M010` (`v0.1`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task488`
- 구현 단계: 3단계

Task #479가 도입한 Release-only 익명 실행 이벤트 endpoint 계약을 source configuration에서 실제 Release artifact까지 확장했다. 승인된 production origin을 verifier에 독립적으로 고정하고, built Release app의 전체 endpoint가 `project.yml`과 정확히 일치해야만 post-build 재서명·공증·DMG·zip 생성으로 진행하도록 blocking preflight를 연결했다.

Stage 1에서 기존 HTTPS host 우회와 release helper 미연결 상태, current XML plist 형식을 재현했다. Stage 2에서 origin guard, XML/binary reader 경계와 portable/macOS fixture를 구현했다. Stage 3에서 `release.sh`와 `package-release.sh`에 built artifact gate를 연결하고 무서명 DMG·개발 zip end-to-end 검증으로 실제 실행 순서를 확인했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/pr-ci.yml` | macOS validation에서 endpoint XML/binary fixture helper 실행 |
| `.github/workflows/release-rehearsal.yml` | Rehearsal summary에 built endpoint preflight 순서 명시 |
| `.github/workflows/release-publish.yml` | Publish summary에 재서명·공증·DMG 전 endpoint gate 명시 |
| `scripts/ci/verify-app-execution-endpoint-config.sh` | 승인 production origin 고정, exact built endpoint와 XML/binary plist reader 계약 보강 |
| `scripts/ci/test-app-execution-endpoint-config.sh` | Invalid origin, XML/binary built app, mismatch와 no-`plutil` fixture 추가 |
| `scripts/release.sh` | Copied Release app endpoint 검증을 post-build 재서명·공증·DMG 전에 연결 |
| `scripts/package-release.sh` | Copied Release app endpoint 검증을 universal 검증·zip 생성 전에 연결 |
| `mydocs/tech/task_m040_453_app_execution_analytics_contract.md` | Origin review gate, built exact-match와 plist reader 운영 계약 기록 |
| `mydocs/manual/ci_workflow_guide.md` | PR CI, rehearsal/publish endpoint preflight와 로컬 재현 절차 보강 |
| `mydocs/manual/release_packaging_dmg_guide.md` | Release build, 개발 zip, public/rehearsal DMG 검증 순서 보강 |
| `mydocs/plans/task_m010_488.md` | 작업 범위, 안전 제약과 단계 계획 수립 |
| `mydocs/plans/task_m010_488_impl.md` | 3단계 구현 설계, 수용 기준과 검증 명령 확정 |
| `mydocs/working/task_m010_488_stage1.md` | HTTPS origin 우회, release 경로와 current plist 측정 기록 |
| `mydocs/working/task_m010_488_stage2.md` | Origin guard, reader와 fixture 구현·검증 기록 |
| `mydocs/working/task_m010_488_stage3.md` | Release helper 통합과 DMG/zip 검증 기록 |
| `mydocs/orders/20260828.md` | Task #488 진행 단계와 완료 시간 기록 |
| `mydocs/report/task_m010_488_report.md` | 전체 변경, 수용 기준, 잔여 위험과 PR handoff 정리 |

제품 HostApp·Quick Look·Thumbnail Swift/Rust source, `project.yml` production endpoint 값, analytics payload/outbox와 workflow trigger·권한·secret은 변경하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 승인 production origin guard | 없음 — 임의의 유효한 HTTPS host 허용 | `https://alhangeul-install-events.postmelee.workers.dev` scheme·host·effective port 고정 |
| Built Release endpoint 자동 gate | Verifier option만 있고 release 경로 호출 0개 | `release.sh`, `package-release.sh` 2개 산출 경로에서 blocking 실행 |
| Built plist fixture 분기 | 자동 fixture 없음 | XML Debug/Release/mismatch/fallback 4개 + binary Debug/Release/no-`plutil` 3개 |
| Release artifact end-to-end | Endpoint preflight 순서 미검증 | Universal rehearsal DMG 1개, locally signed 개발 zip 1개 생성·무결성 검증 |
| 구현 단계/단계 보고서 | 0 | 3단계 / 3개 |
| 최종 보고 전 Git diff | 해당 없음 | 16개 파일, 1,040줄 추가·18줄 삭제 |
| 최종 보고 전 작업 커밋 | 0 | 계획 2개 + Stage 3개 = 5개 |

Stage 1–3 계획·보고 문서는 총 851줄이다. 자동 검증은 source origin drift, XML/binary plist, 실제 Release bundle, workflow YAML과 release packaging 순서를 함께 다룬다.

검증용 산출물 checksum은 다음과 같다.

| 산출물 | SHA-256 |
|--------|---------|
| `alhangeul-macos-0.1.10-rehearsal.dmg` | `7a742cc862b7313fe7d74395f686375d4382424f1c7fa1add3c43de92b4d92a0` |
| `alhangeul-macos-0.1.10.zip` | `ec25b6f87599a942687481ba0b119c29f18c5fc184465d031b6118a7b678ac44` |

두 산출물은 Task 전용 `build.noindex/task488-stage3-*` 경로에만 생성했으며 public asset으로 게시하지 않았다.

## 검증 결과

### 수용 기준

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 다른 HTTPS origin도 source gate에서 실패 | OK | `invalid-origin` fixture가 expected/actual origin 오류로 실패 |
| Current production source와 exact built Release endpoint 통과 | OK | Source verifier와 실제 Release app `--release-app` 성공 |
| XML fallback과 binary `plutil` 경계 명확화 | OK | XML no-`plutil` 통과, binary no-`plutil` 명시 실패 fixture 통과 |
| Ubuntu portable + macOS synthetic binary 자동 회귀 | OK | PR CI script-checks 유지, macOS validation에 fixture helper 추가 |
| `release.sh`가 signing/notarization/DMG 전에 검증 | OK | 무서명 rehearsal 로그에서 endpoint → universal/signing skip → DMG 순서 확인 |
| `package-release.sh`가 zip 전에 검증 | OK | 전용 build root에서 endpoint → universal → zip/checksum 순서 성공 |
| Workflow별 verifier 명령 중복 없음 | OK | Rehearsal/publish 모두 공통 `release.sh` 사용, summary만 보강 |
| 운영 문서가 origin·exact-match·실행 순서 설명 | OK | Analytics 계약, CI와 release packaging 가이드 갱신 |
| Public release·production 네트워크 요청 미실행 | OK | Unsigned rehearsal과 locally signed 개발 zip만 생성, 앱 실행·업로드 없음 |

MISS 항목은 없다.

### 최종 통합 검증

| 검증 | 결과 |
|------|------|
| `bash -n` release/package/verifier/test helper | OK |
| Verifier/test helper `shellcheck` | OK |
| 전체 6개 workflow `Psych.parse_file` | OK |
| `scripts/ci/test-app-execution-endpoint-config.sh` | OK |
| `xcodegen generate` | OK, tracked project diff 없음 |
| Unsigned HostApp Release build | OK, `** BUILD SUCCEEDED **` |
| 실제 built Release app `--release-app` | OK |
| `scripts/check-no-appkit.sh` | OK |
| `scripts/verify-rhwp-core-build-info.sh` | OK |
| `scripts/verify-rhwp-studio-assets.sh` | OK |
| Rehearsal DMG `hdiutil verify`와 SHA-256 | OK |
| Package zip `unzip -tq`, local signature와 SHA-256 | OK |
| `git diff --check` | OK |

Local Ruby가 미사용 `ffi-1.13.1` native extension 경고를 출력했지만 Psych/REXML helper는 모두 exit 0으로 완료됐다. Xcode 검증이 등록한 Task 전용 개발 app/extension 경로는 해제했고, 최종 PlugInKit 조회에는 `build.noindex/task488-stage3-*` 경로가 남지 않았다.

## 잔여 위험과 후속 작업

- Public mode의 실제 Developer ID 재서명, notarization submit과 GitHub Actions workflow dispatch는 이번 작업의 권한 범위 밖이라 실행하지 않았다. 공통 helper의 unsigned rehearsal로 gate 위치를 검증했으며 실제 credential 검증은 정식 release 단계에서 수행한다.
- 승인 origin은 destination 변경을 자동 통과시키지 않기 위해 `project.yml`과 verifier에 의도적으로 이중화했다. Host 이전 시 project, verifier, fixture와 운영 문서를 같은 review에서 갱신해야 한다.
- Non-macOS fallback은 XML plist만 지원한다. Future binary plist는 macOS `plutil`이 필요하며 synthetic fixture가 이 계약을 보호한다.
- `scripts/release.sh`에는 Task #488 이전부터 존재한 `shellcheck SC2054` warning 1건이 있다. 변경 줄과 무관하고 Task verifier helper lint는 깨끗하므로 이번 범위에서 수정하지 않았다.

별도 후속 이슈를 새로 만들 필요는 없다고 판단한다. Public signing/notarization 검증은 기존 release 절차의 필수 gate이고, intentional host 이전은 운영 변경 시 함께 수정할 계약이며, 기존 `SC2054` warning은 기능 결함이나 Task #488 수용 기준 누락이 아니다.

## 작업지시자 승인 요청

Task #488의 3개 구현 단계와 전체 수용 기준 검증을 완료했다. `publish/task488` 브랜치와 `devel` 대상 PR에서 다음을 중심으로 리뷰해 달라.

1. 승인 production origin을 전체 endpoint 진실 원천과 별도 review gate로 둔 설계
2. `release.sh`의 `build_app → endpoint preflight → post-build signing/notarization/DMG` 순서
3. `package-release.sh`의 copied app endpoint preflight와 zip 우회 차단
4. XML-only fallback과 binary `plutil` 요구를 fixture·운영 문서에 같은 계약으로 반영한 부분

리뷰 완료 후 merge 승인을 요청한다.
