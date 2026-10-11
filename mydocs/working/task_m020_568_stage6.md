# Task M020 #568 Stage 6 — 소비자별 최종 검증·지원 범위·인계

- 수행일: 2026-10-10. 이슈 [#568](https://github.com/postmelee/alhangeul-macos/issues/568), 부모 #562, M020/v0.2.
- 승인: Stage 5 완료 보고 후 작업지시자의 “진행해줘”. [구현계획](../plans/task_m020_568_impl.md) 8절의 회귀·증거 대조·문서화·인계 범위.
- 기준: `local/task568`, 제품 소스 `817d1931`, core/Studio `v0.8.7` / `1a76570e833917d15817415a53c09ad61ab3203f` 유지.
- 판정: **Stage 6 완료, 최종 보고·PR 단계 승인 대기**. 계획된 Mac 소비자 연결을 취합했으며 Windows·실제 한컴 제거·최소 OS/Intel·물리 인쇄·공개 출시 완료로 확대하지 않는다. GitHub 이슈는 OPEN이며 close하지 않았다.

## 1. 결과와 변경

[소비자 인계](../tech/task_m020_568_consumer_handoff.md)에 Studio/PDF/인쇄/CG/Skia/Quick Look/Thumbnail 각각의 Mac 설치 참조·관리 복사본·Windows 입력 상태와 실제 실행/주입/unsigned/signed 경계를 취합했다. 정상 문서의 정확한 face와 실패/대체·stale·취소 결과를 분리했다. #566 ZIP 입력과 #569 최종 사용자 수용·안내에 넘길 완료 조건, 반복 metadata 탐색 최적화와 범용 upstream 기여 후보를 기록했다.

구조 문서의 ‘PDF는 내장 Noto 네 파일만 사용’ 설명을 실제 구현으로 보정했다. 출력 job의 공식 선택·검증 bytes·token/ID route·준비 실패/명시 대체·seal과 atomic write를 반영했다. 기존 source adapter·CSP·native 소유 경계를 바꾸지 않았다. 공통 연동 문서는 최신 소비자 표와 #565 당시 인계 이력을 구분했고 계획서의 승인/진행 상태도 갱신했다.

제품 소스·UI 문구·시각 요소·core/Studio 자산·framework·생성 project 변경은 없다. 기존 UI 문구와 native 설정/가져오기 동선을 읽어 확인했으며 이번에 새 설정창을 실행하거나 screenshot을 만들지 않았다. 제품/웹 공개 안내 작성·배포는 #569의 별도 단계다.

## 2. 최종 소스·증거 대조

[대조 영수증](assets/task_m020_568_stage6/evidence-audit.json)은 현재 소스와 각 단계 영수증의 hash, core/Studio pin·artifact, 보존 PDF/그림/결과·시험 로그를 묶는다. 과거 결과와 현재 소스의 차이를 숨기지 않는다.

| 근거 | 대조 결과 | 재사용 판단 |
|------|-----------|-------------|
| Stage 3 signed PDF·인쇄 compiled 입력 | 177개 중 162개 hash 동일, 15개 변경, 누락 0. 이동한 9개 service는 현재 Shared 경로로 대조 | 출력 job/preparation/route/controller·Studio adapter/WebView 및 bundled 자산은 동일. 공통 service의 metadata/read-only/설정 게시, native 경로와 probe glob은 Stage 4–5에서 변경됨. signed 전체 시험을 현재 소스에서 다시 실행한 것으로 취급하지 않음 |
| Stage 4 native supply 영수증 | 31개 중 27개 hash 동일, 4개 변경, 누락 0. 2개 service 경로 이동 | renderer의 prepared context/외부 doc 수명, read-only store/service와 probe source 목록 변경을 Stage 5 native/확장 회귀와 최종 테스트로 확인. 옛 영수증 전체가 현재 빌드와 같다고 주장하지 않음 |
| Stage 5 최종 signed provenance | **125개 전부 현재 hash와 동일**, 변경/누락 0 | 실제 Finder 최종 시험 소스를 현재 제품 기준으로 재사용 |
| core lock artifact·Studio | header/universal archive 2개의 길이/SHA256 일치. core/Studio tag/commit 일치, native matcher/Studio adapter receipt 검사 통과 | Stage 4 이후 Rust/ABI 변경 없음. 기존 두 architecture·Rust 29·portable/strict/golden 수용 재사용 |
| signed Stage 5 선별 증거 | `SHA256SUMS` **26개 전부 일치** | 최종 실제 signed 결과·초기 거부·복원·정리·그림의 근거 유지 |
| Stage 3 PDF 저장/인쇄 PDF | managed/installed/baseline × HWP/HWPX × 저장/인쇄 **12개 실제 PDF hash**가 독립 pypdf/Poppler proof와 일치 | PDF 재생성/새 서명/물리 인쇄 없이 보존 결과의 정합성을 검사 |
| 원본 고운바탕 R/B | 2개 원본의 길이/SHA256이 Stage 3의 PS/hash/bytes 읽기 관측과 일치 | 합계 16,612,008 bytes. 관리/process fixture이며 사용자 영구 설치가 아님 |
| 보존 evidence index | #568 Stage 3–5 및 #567 Studio 선별 결과 **61개 파일**의 현재 hash/길이 기록 | 삭제된 시험 앱 executable은 보존된 hash 영수증만 근거로 사용. 존재하는 실제 binary를 새로 검사한 것으로 주장하지 않음 |
| 원래 설치본 | 현재 `/Applications/Alhangeul.app/Contents/Info.plist` hash가 Stage 5 원본과 일치 | 전체 152개 파일/링크 일치는 Stage 5 복원 당시 증거 재사용. Stage 6에서 전체 tree 재검사는 하지 않음 |

Stage 3 signed 실제 수용과 최종 소스의 공통 서비스 회귀를 결합한 판단이다. 모든 소비자를 하나의 최신 signed 배포 후보에서 재수용한 결과는 아니다. #569의 배포 후보 수용에서 이 시점 차이와 지원 환경을 다시 확인한다.

## 3. 검증 실행·재사용 구분

| 구분 | 명령/근거 | 결과 |
|------|-----------|------|
| 이번 실행 | `node --test scripts/ci/test-studio-font-*.cjs` | **30개 통과**, 실패 0. `build.noindex/task568/stage6-js-tests.log` |
| 이번 실행 | `node scripts/build-native-font-matcher.mjs --verify` | receipt 일치. `stage6-matcher.log` |
| 이번 실행 | `bash scripts/verify-rhwp-studio-assets.sh` | manifest/adapter/font 자산 통과. `stage6-assets.log` |
| 이번 실행 | `bash scripts/verify-rhwp-core-build-info.sh`·`bash scripts/check-no-appkit.sh` | lock 정보 일치·공통 계층 AppKit/UIKit 없음 |
| 이번 실행 | source/artifact/PDF/evidence hash 대조·변경 문서 local 링크·`git diff --check` | 통과 |
| 재사용 | Stage 5 `stage5-readonly-tests-final.log` | FontLibraryTests **133개**, 실패 0. 이번 실행 수에 합산하지 않음 |
| 재사용 | Stage 5 `stage5-host-tests-readonly.log` | HostAppTests **237개**, 실패 0. 최종 공통 서비스·출력/수명 회귀 포함 |
| 재사용 | Stage 5 일반/probe Release 빌드 로그 | 두 compile/link 통과. 이번 제품 변경이 없어 다시 빌드하지 않음 |
| 재사용 | Stage 5 native regression·unsigned extension·signed Finder | 실제/주입 및 backend 범위는 각각의 원래 보고서대로 유지 |

영수증 생성의 첫 일회성 Python 입력은 마지막 줄 들여쓰기 오류로 실행 전에 실패했다. 수정한 입력에서 모든 assert가 통과하고 최종 JSON을 저장했다. 제품 검증 실패를 숨기거나 실패한 중간 영수증을 보존하지 않았다. 단계 범위를 벗어나는 새 GUI/signing/설치·등록·전역 cache reset은 수행하지 않았다.

## 4. 남은 수용·지원 경계

- Mac 참조는 원본의 현재 활성/권한/내용에 의존한다. 독립 복사본만 원본 폴더 제거 후 관리 보관을 유지한다. 한컴 내부 글꼴의 자동 추출·모든 글꼴 유지·실제 한컴 삭제 성공으로 설명하지 않는다.
- 출력/native의 exact 형식·스타일과 glyph replay는 제한된다. TTC/가변/HFT·모든 macOS static font·전체 shaping/효과·pagination 지원을 완료한 결과가 아니다. OS AppleMyungjo/AppleGothic inspector 제한도 인계했다.
- signed Release 확장은 CoreGraphics, Skia는 unsigned 공통 renderer 수용이다. 실제 QL 2페이지는 로그/UI 증거이며 커밋한 unsigned `preview-multiple.pdf`와 구분한다.
- 실제 Mac OS 설치/비활성화 조작·권한 상실/복구의 최종 제품 시나리오, 최소 macOS/Intel runtime·다양한 복합 문서·물리 인쇄·Windows 생성 ZIP·최종 후보 전체 수용은 #566/#569 또는 별도 환경에 남는다.
- 확장은 매 요청 시 metadata를 재탐색한다. signed 32건의 중앙값 1,089.77ms이며 cache hit에도 비용이 있다. 후속 최적화는 별도 범위 결정 후 진행하고 즉시 갱신/OS 영구 cache 미요청 경계는 별개로 유지한다.

이 한계는 연결되지 않은 소비자를 숨긴 판정이 아니다. 계획된 소비자의 제한된 Mac 연결·대조를 마쳤고, 전체 이전/출시 수용과 공개 완료 처리는 분리한다. 현 이슈의 일부 초기 이력에 Windows·최소 OS 전체 조건이 남아 있어 후속 최종 보고/리뷰에서도 최신 이슈 본문과 #566/#569 인계 경계를 대조해야 한다.

## 5. 다음 단계·부산물

새 `.app/.appex/.dmg`·framework/cache는 만들지 않았다. Stage 5의 임시 앱 제거·원래 설치본 복원·등록 정리 기록을 유지하며 다음 최종 보고/PR에 필요한 시험 로그·PDF·CLI 결과는 보존한다. 작은 검증 로그와 hash JSON만 추가했다.

다음은 #568 최종 보고서·오늘할일 완료 처리·PR 준비 단계다. 저장소의 단계 승인 규칙과 구현계획 9절에 따라 그 단계 승인 후 진행한다. 원격 push/PR·issue close·upstream 공개 기여·제품/웹 배포는 이번에 수행하지 않았다. upstream에는 일반 static bytes/slot/style helper와 공개 가능한 회귀부터 검토하고 macOS App Group/QL 운영 코드를 그대로 보내지 않는 방향을 인계했다.
