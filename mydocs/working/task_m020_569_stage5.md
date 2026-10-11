# Task M020 #569 Stage 5 — Mac 부분 회귀·최종 보고·PR 초안

- 일자: 2026-10-12, 작업 `local/task569`, 기준 Stage 4 커밋 `9e82b1d5`.
- 승인: 작업지시자의 “Stage 4 수용·Stage 5 준비 진행”. Stage 4 결과 수용, 필요한 회귀·최종 보고·부분 PR 초안 준비까지다. 공개 push/PR 게시·이슈 close·릴리스는 제외한다.
- 결과: 현재 소스의 회귀와 증거 대조를 통과했고 [Mac 부분 최종 보고](../report/task_m020_569_report.md)·[PR 본문 초안](task_m020_569_pr_draft.md)을 준비했다. 이후 “최종 보고 수용·push/Open PR 게시” 승인을 받아 [Open PR #583](https://github.com/postmelee/alhangeul-macos/pull/583)을 생성했다. 제품 코드 추가 변경은 없다.

## 1. 변경 경계와 필요한 검증

검토된 `devel` / PR #582 기준 제품 소스 차이는 `Sources/HostApp/HostApp.swift`의 Help 링크 8줄이다. 웹 안내·실제 화면·후보 helper의 #569 경로 허용과 단계 증거/문서를 함께 인계한다. core/Studio pin·로컬 글꼴 공급/renderer 기본값은 유지한다.

| 검증 | 명령·판정 |
|------|-----------|
| FontLibrary·브라우저 연동 | `./scripts/test-font-library.sh`: XCTest 162개, Node 30개, 실패/skip 0. App Group·fixture hash도 통과 |
| Host 출력·인쇄·Spotlight | `bash scripts/test-studio-output.sh build.noindex/font-library-tests/DerivedData`: 81개 실패 0. WebKit face load 실패와 명시 대체 시 차단 family 제거·bytes 읽기 0의 현재 계약 포함 |
| 테스트 전제/Host compile | 같은 DerivedData에 현재 HostApp Debug를 `CODE_SIGNING_ALLOWED=NO REGISTER_APP_WITH_LAUNCH_SERVICES=NO`로 빌드해 성공. Stage 3 기본 Release·Stage 4 진단 Release 및 실제 Help 클릭 결과는 소스 일치로 인계 |
| 공통 경계·provenance | `scripts/check-no-appkit.sh`, `scripts/verify-rhwp-core-build-info.sh`, `scripts/verify-rhwp-studio-assets.sh`, `node scripts/build-native-font-matcher.mjs --verify` 모두 통과 |
| 후보 helper 회귀 | `scripts/test-extension-font-smoke-guards.py --task 569/580 --output <각 task의 stage4 새 경로>`: 각 16개 통과, 실제 외부 서명/설치 명령 0 |
| 소스/증거 audit | Stage 4 제품 Swift 집합/126개 hash, 출력 probe의 기록 입력 188개, core/Studio/native receipt 일치. Stage 2/3/4 checksum 23/15/21개 일치 |
| 웹 | 홈·안내 HTML의 한국어/중복 ID/이미지 alt·로컬 참조/fragment 확인. 홈 26개·안내 22개 로컬 참조 정상. 변경 없는 1280/390/320px 시각·키보드 검증은 Stage 3에서 인계 |
| 원래 앱·등록 | 원래 `/Applications/Alhangeul.app` strict/deep 서명 정상. 회귀 앱 제거·시험 등록 해제 후 provider 하나, 개발 등록/앱·legacy·issues/warnings 0 |

원시 로그와 검증 script는 `build.noindex/task569/stage5/`에 보존한다. 공개 선별 결과는 [validation](assets/task_m020_569_stage5/validation.json), [audit](assets/task_m020_569_stage5/evidence-audit.json), [checksum](assets/task_m020_569_stage5/SHA256SUMS)에 있다. GitHub CI는 PR 게시 후 실행할 관문이며 이번 로컬 검증을 CI 통과로 표현하지 않는다.

## 2. 실패·회복과 판정 한계

첫 Host 81개 실행은 현재 Debug 앱이 없는 상태여서 `SpotlightReindexServiceTests.testProductImporterURLMatchesBuiltAppBundle` 1개가 실패했다. CI와 같은 전제의 Host Debug를 먼저 빌드한 뒤 동일 script를 재실행해 81개 모두 통과했다. 첫 실패 로그를 남기며 제품/테스트 수정으로 숨기지 않는다. guard 첫 호출은 필수 `--output` 누락으로 사용법만 출력했고, 기존 경로 guard를 유지한 새 소유 경로로 재실행해 통과했다. 로컬 audit의 root/checksum 경로 처리 오류도 같은 검증 도구 안에서 바로잡았다.

출력 불가 face의 실제 사용자 alert·명시 대체 클릭을 Stage 4에서 새로 재현한 것으로 확대하지 않는다. Stage 5는 현재 WebKit/명시 대체 계약을 주입된 실패로 검증했다. 같은 Developer ID 후보의 실제 저장/PDF/인쇄 취소와 별도 ad-hoc sandbox 출력 70 checks는 Stage 4에서 구분한 대로 보존한다. macOS 12/Intel 실제 실행·최종 공증 DMG·물리 인쇄·Windows는 미검증/후속이다.

## 3. 소유 정리

새로 빌드한 회귀용 Debug 앱만 제거했다. 논리 크기 **292,569,881 bytes(약 279MiB)**이며 실제 디스크 가용 증가량과 같다고 주장하지 않는다. 재사용 XCTest·module/package cache·로그·영수증은 보존한다.

빌드의 LaunchServices 등록 흔적 1개를 읽기 전용 점검에서 발견했다. 표준 hygiene helper의 `--cleanup-dev-registrations --no-cache-reset`으로 부모 앱/확장을 해제했으나 같은 시험 경로가 남았다. 시험 bundle을 같은 캐시로 잠시 다시 만들고 dump의 정확한 항목을 확인한 결과 하위 Sparkle `Updater.app`였다. 해당 경로만 해제하고 시험 bundle을 다시 제거한 뒤 최종 점검했다. 다른 앱/설치본 변경·전역 cache reset은 없다. Stage 4의 원상복원과 고유 보관함 정리를 반복 서명/설치로 대체하지 않았다.

## 4. 최종 공개 게이트와 인계

- 부분 PR 제목: **Mac 로컬 글꼴 안내와 동일 후보 수용 결과 정리**.
- 게시: `local/task569` → 원격 `publish/task569`, 대상 `devel`, [Open PR #583](https://github.com/postmelee/alhangeul-macos/pull/583). [검토할 본문](task_m020_569_pr_draft.md)을 사용했다.
- #569/#562 전체를 닫지 않으며 Windows #566 후속을 유지한다. #581 추가 최적화는 Mac 인계의 선행 조건이 아니다.
- 최종 보고 수용·공개 push/PR 게시를 2026-10-12 별도 승인받아 수행했다. merge·이슈 close·Pages/Release/appcast/Cask 공개는 포함하지 않는다.
- M900 release 운영에서 구체 버전/build·후보 SHA와 정상 제품 flag, signed/notarized pre-public DMG 설치 smoke·지원 제한·웹 제공 상태/배포 시점을 맞춘다. 현재 Help 공개 URL의 404는 미게시 상태로 기록돼 있다.

## 5. 공개 게시 기록

최신 `origin/devel`은 승인 기준 `34ae2f4b`로 유지됐고, `origin/main` / `43b4e998`의 내용이 source에 포함된 content gate를 통과했다. gate 첫 실행은 sandbox의 Git 임시 객체 쓰기 거부로 실패했고 같은 검사를 필요한 권한으로 재실행해 통과했다. source 변경은 없다.

승인된 `d7270a7a60117fd6ae4cab1fa85fb699a1d3e84b`를 원격 `publish/task569`에 push하고, 본문 토큰 검증·최종 보고 commit 고정 링크로 #583을 생성했다. milestone은 기존 ‘글꼴 마이그레이션’, base `devel`, Open/non-draft·mergeable이며 closing issue references는 빈 목록이었다. 게시 직후 `PR CI / Classify changed files`의 시작을 확인했다. 결과 확정 전이므로 CI 통과로 기록하지 않는다.

[게시 영수증](assets/task_m020_569_stage5/publication.json)과 승인/게시 상태 문서만 후속 커밋으로 반영한다. 이번 새 커밋에서 소스·테스트·웹 안내 내용은 변경하지 않는다.
