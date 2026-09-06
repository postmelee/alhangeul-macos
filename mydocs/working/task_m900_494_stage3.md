# Task M900 #494 Stage 3 검증 보고서

## 단계 목적

[구현계획서](../plans/task_m900_494_impl.md)의 Stage 3에 따라 `0.1.11 (17)` / rhwp `v0.8.6` 후보의 provenance, Rust·Swift, 앱·renderer와 개발 package를 검증한다. 2026-09-06 작업지시자의 Stage 3 진행 지시를 받아 수행했다.

검증 source는 `local/task494`의 `a34613064902e266d80061ef7dcc94bc6249a79b`다. 이 단계에서는 제품 source를 바꾸지 않았다. 아래 strict archive 비교와 등록 환경 검사의 실패를 남긴 채, 계획서의 완료 기준인 통과·실패 경계와 다음 배포 검증 조건을 정리한다. 모든 검사가 통과했다는 판정이나 공식 배포 승인은 아니다.

## 산출물

| 경로 | 내용 |
|------|------|
| `build.noindex/task494/stage3/` | 환경·provenance·테스트·build·package 로그, archive 비교, 원본 hash, GUI 화면·PDF, 등록 진단 |
| `build.noindex/task494/upstream-rhwp/` | 공식 v0.8.6 exact commit checkout과 root Cargo.lock 확인 자료 |
| `build.noindex/task494/tests/` | HostAppTests·ExternalImageTests xcresult |
| `build.noindex/task494/debug/`, `release-build/` | Debug 앱과 universal Release 앱 |
| `build.noindex/task494/render/`, `quicklook/`, `thumbnail/` | native renderer·Finder 정책 helper 산출물 |
| `build.noindex/task494/package/release/` | 별도 build root에서 생성한 개발 앱·ZIP |
| `build.noindex/task494/stage3/source-pr-body.md` | Stage 4 source 준비 PR의 검증한 본문 후보, `Refs #494` |
| `mydocs/release/v0.1.11.md`, `index.md` | Stage 3 결과와 signed/public 검증 인계 |
| 두 계획서·오늘할일·이 보고서 | 현재 단계와 다음 승인 범위 |

개발 ZIP은 `alhangeul-macos-0.1.11.zip`, 179,262,963 bytes이며 SHA256은 `54d8bbd5c24afcb20b3bdcc9829dc8922fac0cb01851d86d6271709ce221015e`다. 앱과 두 extension은 모두 `0.1.11 (17)`, `x86_64 arm64`다. ad hoc 서명 검증·ZIP 무결성·canonical Legal 문서 일치를 확인했다. 이 값은 public DMG의 checksum이 아니다.

## 본문 변경 정도와 무손실 여부

추적 변경은 내부 문서 6개다. source, plist, workflow, core lock·Cargo.lock, generated header·symbol 기준, bundled Studio, Xcode project, README·Pages·appcast·Cask는 수정하지 않았다. XcodeGen 재생성 후 추적 project diff도 없다.

`samples/`의 180개 파일을 작업 전후 SHA256·크기·수정 시각으로 비교해 변경 0개를 확인했다. GUI는 task 디렉터리의 복사본으로 진행했다. 미저장 상태는 새 `task494-smoke-preserved.hwpx`로 보존했고, 기존 복사본과 원본은 덮어쓰지 않았다. 기존 Task #492 Debug 프로세스와 사용자 설치 앱 두 개도 보존했다.

## 검증 결과

| 검증 | 결과와 근거 |
|------|-------------|
| 환경 | Apple Silicon, macOS 26.5.2 (25F84), Xcode 26.6 (17F113), Rust/Cargo 1.94.1, XcodeGen 2.45.4 |
| upstream provenance | v0.8.6 checkout HEAD `f1f9c6ae58344ee9368996d3543f76b9345cf227`, root Cargo.lock SHA256 `a094d90fbf3d1f312eb746468334cce5d862ad147dc2eb276062fc3e49cbc373` 일치 |
| build-info·Studio·AppKit 경계 | source verifier, build-info·Cargo.lock fingerprint fixtures, DOM 6개, decoder fixture, AppKit 의존 검사 통과 |
| strict Rust build | 두 architecture 빌드·XCFramework 생성 성공 후 `librhwp.a` hash/size 비교 실패, exit 1; `rust-strict.log` |
| portable Rust build | static archive byte 비교만 제외한 별도 실행 성공, exit 0; `rust-portable.log` |
| Rust locked tests | 9 passed, 0 failed, 0 ignored |
| HostAppTests | 181개 통과; PDF·저장 정책·열기 복구·색상 geometry 등 기존 회귀 검사 |
| ExternalImageTests | 30개 통과 |
| XcodeGen·Debug·Release | 생성·빌드 성공, Release app·Preview·Thumbnail 모두 universal |
| endpoint | Debug 비활성, 실제 Release bundle 승인 endpoint 일치; Release 실행은 하지 않음 |
| native renderer | KTX/request/exam_kor 3개 첫 페이지 nonblank·텍스트·한글 검사 통과 |
| Quick Look 정책 | KTX 1페이지 PNG, HWPX 9페이지 PDF; CG·Skia 정책 성공, fallback 0 |
| Thumbnail 정책 | 문서 3개 × 8회 = 24회 렌더 성공, 실패 0; cache miss/exact/larger bucket 경로 |
| 개발 package | portable 설정을 명시해 생성, ZIP 검사·universal·bundle identity·Legal·ad hoc codesign 검증 통과 |
| GUI | HWP 1페이지·HWPX 9페이지 열기, 두 문서 글자색 popover 표시·위치 확인 |
| PDF·인쇄 GUI | HWPX PDF 9페이지·869,612 bytes·794×1123 pt, 한글 1,796자 추출; 9페이지 인쇄 미리보기 취소 후 PDF 내보내기 재진입·취소 성공 |
| 열기 복구 GUI | 빈 HWP 오류 안내 → 다시 시도 → 파일 선택 취소 후 기존 HWPX URL·9페이지와 화면 유지 |
| 원본 보존 | samples 180개 SHA256·size·mtime 일치, 변경 0 |
| 등록 위생 | 시작·정리 후 검사 모두 exit 1; 기존 설치본 두 경로와 LaunchServices 잔여 기록, 아래 별도 기록 |
| rehearsal | 로컬 DMG·workflow 모두 미실행. 별도 서명/rehearsal 실행 승인 전이며 개발 ZIP 검증과 구분 |
| 문서·PR 본문 | GitHub body·release note template·변경 문서 local link 검사 통과, HTML 14개·참조 164개와 이전 본문 보존 재확인, `git diff --check` 통과 |

### Archive 비교 경계

| 대상 | lock 기준 | 로컬 결과 |
|------|-----------|-----------|
| `librhwp.a` SHA256 | `25ba743d7e3774c81177e849308fba98ce0e6b7a22eff3d1b6380a11ab9f0544` | `062ba3a4f4d73c4b6494c209cc68a9ec188b2668a031b037bbed1ad354ddf5e8` |
| `librhwp.a` size | 233,144,976 | 233,122,232 |
| generated header SHA256 | `04106bbc024e72309ba5ac084cd61f756899f1185573c14b53263f3809cb72a8` | 동일 |
| generated header size | 3,600 | 동일 |

`ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`은 별도 진단과 개발 package 생성에 사용했다. source provenance, Cargo resolution, feature, header·FFI symbol과 universal 검증을 유지했다. lock을 갱신하지 않았다. [core 운영 매뉴얼](../manual/core_dependency_operation_guide.md)의 GitHub CI/release portable 경계 및 현재 Publish workflow도 같은 archive 제외 설정을 사용한다. 로컬 결과로 strict byte 재현 성공을 주장하지 않으며, Stage 4는 실제 CI와 서명된 후보를 다시 검증한다.

### GUI·등록 정리의 관찰 범위

Computer Use로 Task #494 Debug 앱의 실제 창을 조작했다. 시작 시 나타난 기존 복구 문서 안내는 나중에로 넘겨 사용자 복구 자료를 유지했다. 자동 검증은 signed 설치본 또는 Finder 실제 provider 실행을 대신하지 않는다. 한글 PDF 추출은 `pdfinfo`·`pdftotext`로 확인했으며 Preview의 선택·검색·복사 조작은 아직 확인하지 않았다.

새 HWPX 복사본 저장 직후 종료 시 저장 안내가 한 차례 더 표시됐다. 다시 저장을 선택한 뒤 정상 종료했다. 재표시 원인과 dirty 상태는 이번 관찰만으로 확정하지 않으며 Stage 4에서 저장·재열기와 함께 재확인한다. 혼합 색상·부분 적용·undo/redo, 보호 문서·HWP3 실제 저장 조합은 signed 후보 검증에 남긴다.

종료 과정의 `저장하지 않음` 클릭은 미저장 변경 폐기를 이유로 자동 승인 검토에서 거부됐다. 이 클릭을 재시도하지 않고 종료를 취소한 뒤 새 검증 파일로 저장해 보존했으며, 저장 선택으로 앱을 종료했다.

표준 `--cleanup-dev-registrations` helper로 개발 앱·extension 등록 해제와 Quick Look cache 정리를 실행했다. 설치본 `/Applications/Alhangeul.app` v0.1.10과 `~/Applications/Alhangeul.app` v0.1.8은 유지했다. 최종 PlugInKit provider는 이 두 설치 경로만 보이고 Task #494 경로는 없다. LaunchServices 집계에는 개발 경로 32개가 남으며 그중 Task #494 경로 3개가 포함된다. raw dump에서 Task #494 Debug 앱은 `launch-disabled`이고 세 경로의 nested Sparkle Updater 기록도 확인했다. 따라서 helper의 exit 1을 성공으로 바꾸지 않았다. 시작 시부터 있던 중복 설치와 잔여 기록은 Stage 4 실제 Finder 설치 smoke에서 실행 provider를 확인하고 표준 복원 절차로 다룬다. 전역 등록 초기화나 기존 설치 삭제는 수행하지 않았다.

## 잔여 위험

- strict archive byte 재현과 등록 위생 검사 전체는 통과하지 않았다. source·ABI·package 결과와 분리해 검토해야 한다.
- Developer ID 서명, 공증·staple·Gatekeeper, signed DMG layout·설치본 GUI·실제 Finder preview/thumbnail은 Stage 4 대기다.
- Intel Mac·macOS 12 실기기, Sparkle 실제 업데이트, Homebrew 배포는 미실행이다.
- native 렌더 로그의 일부 table overlap 진단과 글꼴 차이는 nonblank 성공만으로 시각 정합성 해결을 의미하지 않는다. PDF 텍스트 추출도 모든 글꼴·기호·읽기 순서를 보장하지 않는다.
- Public Release·Pages·appcast·Cask는 이번 단계에서 변경하지 않았다. 개발 ZIP hash를 public DMG 값에 재사용하지 않는다.

## 다음 단계 영향

Stage 4는 `publish/task494 → devel` source 준비 PR과 CI, `devel → main` release PR, annotated `v0.1.11` tag 및 `draft=true` Publish가 대상이다. 공개 입력은 `version=0.1.11`, `previous_release_ref=v0.1.10`, `expected_rhwp_tag=v0.8.6`, `require_latest_rhwp=true`, `include_rhwp_in_title=true`, `prerelease=false`다.

직전 upstream latest·main/devel content와 새 delta를 재조회하고 후보가 달라지면 검증 범위를 갱신한다. main docs-only Pages가 새 asset 부재로 skip된 실제 run을 확인한 뒤 draft를 만든다. draft 뒤의 Pages 재실행은 공개 영향을 따로 검토한다. signed 후보의 필수 smoke가 통과하기 전 official 공개로 진행하지 않는다.

## 승인 요청

위 검증 결과와 strict/등록 환경 예외를 검토한 뒤 **Stage 4: source PR·main·tag와 서명된 draft 검증** 진행 승인을 요청한다. Source PR 본문 후보와 실행 입력을 준비했으며 원격 PR·tag·Publish는 아직 실행하지 않았다. Official 공개와 Homebrew는 Stage 5 승인 범위다.
