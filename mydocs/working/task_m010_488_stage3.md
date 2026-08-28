# Task M010 #488 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 보강한 production origin·built app exact-match verifier를 실제 Release 산출물 생성 경로에 연결한다. Rehearsal/public DMG와 개발용 zip 모두 staging app을 복사한 직후 endpoint를 검증하고, 불일치 시 post-build 재서명·공증·DMG·zip 생성 전에 실패하도록 한다. CI 안내와 analytics/패키징 운영 문서를 같은 계약으로 맞추고 로컬 무서명 리허설로 실행 순서를 확인한다.

## 산출물

| 파일 | 변경 정도 | 내용 |
|------|-----------|------|
| `scripts/release.sh` | +8/-0 | Ruby preflight 의존성 확인, copied Release app endpoint gate를 post-build 재서명 전에 연결 |
| `scripts/package-release.sh` | +3/-0 | copied Release app endpoint gate를 universal 검증·zip 생성 전에 연결 |
| `.github/workflows/release-rehearsal.yml` | +1/-0 | Rehearsal summary에 built endpoint preflight 순서 명시 |
| `.github/workflows/release-publish.yml` | +1/-0 | Publish summary에 built endpoint preflight 차단 범위 명시 |
| `mydocs/tech/task_m040_453_app_execution_analytics_contract.md` | +4/-0 | 승인 origin, exact-match, plist reader와 endpoint 이전 규칙 기록 |
| `mydocs/manual/ci_workflow_guide.md` | +5/-2 | Workflow 역할, 로컬 fixture, rehearsal/publish gate 문서화 |
| `mydocs/manual/release_packaging_dmg_guide.md` | +7/-0 | Release build, 개발 zip, public/rehearsal DMG 검증 순서 문서화 |
| `mydocs/working/task_m010_488_stage3.md` | 신규 1개 | Stage 3 구현·검증·잔여 위험 기록 |
| `mydocs/orders/20260828.md` | 1행 수정 | Stage 3 완료·최종 보고 승인 대기로 상태 갱신 |

보고서 작성 전 source diff는 7개 파일, 29줄 추가·2줄 삭제였다. 제품 runtime Swift/Rust source와 `project.yml` endpoint 값은 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- HostApp·Quick Look·Thumbnail Swift/Rust source 변경: 0개
- `project.yml` production endpoint와 payload/outbox 계약 변경: 없음
- Release helper의 산출물 처리 순서만 보강: build와 staging 복사는 유지하고 검증 단계를 재서명·공증·패키징 전에 추가
- Workflow trigger, 권한, secret, signing/notarization 설정 변경: 없음
- Public workflow dispatch, GitHub Release/Homebrew 업로드, production endpoint 앱 실행·이벤트 전송: 수행하지 않음
- 검증 산출물은 모두 `build.noindex/task488-stage3-*` 전용 경로에 생성

## 구현 내용

### 1. Public/rehearsal DMG 경로 연결

`scripts/release.sh`에 `verify_app_execution_endpoint()`를 추가하고 다음 순서를 고정했다.

```text
build_app
→ copied APP_OUTPUT endpoint 검증
→ sign_release_app_for_notarization
→ universal/signing preflight
→ notarization
→ DMG 생성
```

Verifier가 Ruby 표준 라이브러리로 source configuration을 파싱하므로 `run_preflight`의 required tool에 `ruby`를 추가했다. Built app 검증은 `--release-app "$APP_OUTPUT"`을 사용하며, production origin이나 `project.yml` 전체 URL과 다르면 뒤 단계가 실행되지 않는다.

### 2. 개발용 zip 경로 연결

`scripts/package-release.sh`는 Xcode build app을 release staging의 `Alhangeul.app`으로 복사한 직후 동일 verifier를 실행한다. 검증 성공 후에만 app/extension universal architecture를 확인하고 zip을 만든다. 기본 `build.noindex/release` 대신 전용 `ALHANGEUL_BUILD_ROOT`에서 실제 package helper를 실행해 copied app 검증, universal app 검증과 zip 생성까지 확인했다.

### 3. Workflow와 운영 문서 정합화

Rehearsal/publish workflow에는 별도 검증 명령을 중복하지 않고 공통 `release.sh`가 소유하는 built artifact gate를 summary에 명시했다. Rehearsal은 선택적 post-build Developer ID 재서명과 DMG 생성 전, publish는 재서명·공증 제출·public DMG 생성 전 차단임을 구분했다.

Analytics 계약과 CI/패키징 가이드에는 다음을 기록했다.

- `project.yml` 전체 URL과 별도 승인 production origin의 책임 분리
- 의도적인 host 이전 시 project, verifier, fixture와 문서를 같은 review에서 갱신
- built Release app 전체 URL exact-match
- macOS `plutil` 우선, non-macOS XML-only fallback, binary plist의 `plutil` 요구
- 개발 zip, rehearsal DMG와 public DMG의 공통 preflight 순서

## 검증 결과

| 검증 | 결과 | 핵심 출력 |
|------|------|-----------|
| `bash -n scripts/release.sh scripts/package-release.sh` | OK | 구문 오류 없음 |
| 전체 workflow `Psych.parse_file` | OK | 6개 YAML parse 성공 |
| `scripts/ci/test-app-execution-endpoint-config.sh` | OK | Origin, XML/binary, mismatch, no-`plutil` fixture 통과 |
| `shellcheck -e SC2054` 관련 helper | OK | 신규 진단 없음 |
| `xcodegen generate` | OK | `Alhangeul.xcodeproj` 재생성, tracked diff 없음 |
| unsigned Release HostApp build | OK | `** BUILD SUCCEEDED **` |
| 실제 Release app `--release-app` | OK | Built endpoint exact-match 통과 |
| `check-no-appkit`, core build info, studio assets | OK | 세 검증 모두 통과 |
| `release.sh --skip-notarize --output build.noindex/task488-stage3-rehearsal 0.1.10` | OK | Universal app, endpoint preflight, DMG 생성·검증·checksum 성공 |
| 전용 build root `package-release.sh 0.1.10` | OK | Endpoint preflight, universal app, locally signed zip 생성 성공 |
| Rehearsal DMG checksum | OK | `7a742cc862b7313fe7d74395f686375d4382424f1c7fa1add3c43de92b4d92a0` |
| Package zip checksum / 압축 검사 | OK | `ec25b6f87599a942687481ba0b119c29f18c5fc184465d031b6118a7b678ac44`, `unzip -tq` 성공 |
| `git diff --check` | OK | 오류 없음 |

전체 DMG 리허설의 핵심 실행 순서는 다음 출력으로 확인했다.

```text
INFO: Building Release app
INFO: Verifying Release analytics endpoint
Verified Release built endpoint: .../task488-stage3-rehearsal/Alhangeul.app
INFO: Verifying universal app architectures
WARN: Skipping codesign verification because this rehearsal build is unsigned.
WARN: Skipping release signing preflight because this rehearsal build is unsigned.
INFO: Creating DMG
...
hdiutil: verify: checksum of ".../alhangeul-macos-0.1.10-rehearsal.dmg" is VALID
```

따라서 endpoint gate가 DMG 생성 전에 실제 실행됨을 확인했다. Package helper도 `Verifying Release analytics endpoint` 성공 뒤 universal architecture와 zip checksum을 출력했다.

일반 `shellcheck`는 변경 전부터 있던 `scripts/release.sh:340`의 `SC2054` 경고 1건을 재현했다. 해당 줄은 2026-05-11 도입된 기존 `codesign_developer_id` 배열이며 Stage 3 변경 범위가 아니다. 이 known baseline 규칙만 제외한 네 관련 script 검증은 통과했다.

Local Ruby는 미사용 `ffi-1.13.1` native extension 경고를 출력했지만 모든 Psych/REXML helper가 exit 0으로 완료됐다. Xcode build가 자동 등록한 정확한 direct Release 개발 app/extension 경로는 해제했고, 최종 PlugInKit 조회에는 `build.noindex/task488-stage3-*` 경로가 남지 않았다. 기존 `/Applications`와 사용자 `Applications` 설치본 등록은 변경하지 않았다.

## 잔여 위험

- Public mode의 실제 Developer ID 재서명·공증 submit은 권한 범위 밖이므로 실행하지 않았다. 공통 함수 순서와 unsigned rehearsal로 preflight 위치를 확인했으며 실제 public credential 검증은 release 단계에서 필요하다.
- Workflow dispatch 자체는 실행하지 않았다. YAML parse, summary 문구와 workflow가 호출하는 공통 `release.sh`의 로컬 end-to-end 리허설로 검증했다.
- 승인 production origin은 의도적으로 `project.yml`과 verifier에 이중화되어 있다. Host 이전은 자동 동기화 대상이 아니라 명시적 review 대상이다.
- Current built plist는 XML이지만 future binary 출력은 macOS `plutil`에 의존한다. Stage 2 synthetic binary fixture가 이 경로를 보호한다.
- 일반 `shellcheck`의 기존 `SC2054` warning은 Task #488 범위에서 수정하지 않았다. 신규 변경 회귀와 무관하지만 전체 lint 무경고를 목표로 한다면 별도 범위 판단이 필요하다.

## 다음 단계 영향

승인된 3개 구현 단계를 모두 완료했다. 다음 단계에서는 Task #488 최종 결과 보고서에 Stage 1의 실제 artifact 계약 측정, Stage 2의 production origin/plist reader 보강, Stage 3의 Release helper 통합과 end-to-end 검증을 합쳐 기록한다.

최종 보고 단계 전까지 다음 작업은 수행하지 않는다.

- `task-final-report`에 따른 최종 보고서 작성
- 오늘할일 완료 처리
- 최종 커밋, `publish/task488` push와 PR 생성

## 승인 요청

Stage 3 Release artifact preflight 연결, workflow summary·운영 문서 보강, unsigned DMG와 개발 zip 통합 검증을 완료했다.

Task #488 최종 결과 보고서 작성과 PR 게시 단계 진행 승인을 요청한다.
