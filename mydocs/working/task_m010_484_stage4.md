# Task M010 #484 Stage 4 완료 보고

## 단계 목적

HostApp PDF/인쇄 renderer의 font source, readiness, Unicode mapping 검증과 알려진 선택 제한을 architecture·사용자 문서에 반영한다. Stage 1~3의 전체 변경을 clean derived data에서 다시 검증하고, 한글 text layer 개선이 보안 경계와 기존 제품 소유 경계를 침범하지 않았는지 최종 확인한다.

## 산출물

| 파일 | 규모 | 변경 요약 |
|------|------|-----------|
| `mydocs/tech/project_architecture.md` | 486줄, Stage 4에서 +40/-10 | page SVG → 격리 WebView → PDF 전용 Noto font readiness → page PDF → PDFKit merge 흐름, exact scheme allowlist, CSP·navigation, `/ToUnicode` 검증, Stage 3 측정치와 잔여 제한 문서화 |
| `README.md` | 476줄, Stage 4에서 +2/-1 | 다음 패치 릴리스 후보의 한글 PDF text mapping 개선과 positioned SVG·Hanja·수식·이미지/OCR 제한 안내 |
| `mydocs/orders/20260824.md` | 7줄 | Stage 4 완료와 최종 보고서·PR 게시 승인 대기 상태 기록 |
| `mydocs/working/task_m010_484_stage4.md` | 신규 | Stage 4 문서 변경, 최종 검증, 잔여 위험과 PR 단계 영향 기록 |

Stage 4에서 production source, test source, project 설정과 bundled binary/resource는 추가 변경하지 않았다. 최종 source commit은 Stage 3 커밋 `cf64b13`이며, Stage 3의 공개 HWP/HWPX smoke도 이 source 상태에서 수행됐다.

## 본문 변경 정도 / 본문 무손실 여부

- HWP/HWPX 문서 본문, page SVG, 수식·표·도형·이미지와 원본 sample은 변경하지 않았다.
- 사용자 v0.1.10 PDF와 Stage 3 smoke 산출물은 읽기·검증 기준으로만 사용하며 저장소에 추가하지 않았다.
- `README.md`는 v0.1.10 공개본이 이미 수정된 것처럼 소급하지 않고 적용 대상을 `다음 패치 릴리스 후보`로 명시했다.
- architecture는 앱 bundle에 이미 포함되고 provenance·license가 기록된 Noto Sans/Serif KR WOFF2 네 종만 PDF 전용 exact route로 제공하며 원본 proprietary font binary는 포함하지 않는 정책을 기록했다.
- 한글 선택 보강은 Hangul/Jamo 범위의 허가된 fallback과 `/ToUnicode`에 한정한다. positioned SVG의 읽기 순서, viewer별 drag selection, Hanja·일부 수식/기호 system subset의 `uni=no`, 이미지·스캔·도형 text와 OCR 부재는 잔여 제한으로 명시했다.
- 일반 인쇄와 PDF 저장은 계속 같은 `RhwpStudioPagePDFRenderer` 결과를 공유한다. Quick Look/Thumbnail, Rust FFI, `rhwp-core.lock`과 bundled Studio asset의 소유 경계는 변경하지 않았다.

## 검증 결과

| 명령/검증 | 결과 |
|-----------|------|
| `xcodegen generate` | 통과. `Alhangeul.xcodeproj` 재생성 완료, 추가 worktree diff 없음 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task484-final-tests CODE_SIGNING_ALLOWED=NO test` | 통과. 150 tests, 0 failures, `TEST SUCCEEDED` `[19.299 sec]` |
| `xcodebuild ... -only-testing:HostAppTests/RhwpStudioPagePDFRendererTests test` | 통과. 18 tests, 0 failures, `TEST SUCCEEDED` `[5.327 sec]` |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task484-final-build CODE_SIGNING_ALLOWED=NO build` | 통과. `BUILD SUCCEEDED` `[15.002 sec]` |
| `scripts/verify-rhwp-studio-assets.sh build.noindex/task484-final-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio` | 통과. 최종 앱 bundle의 Studio asset과 font 자산 무결성 확인 |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code에 AppKit/UIKit 직접 의존 없음 |
| `git diff --check` | 통과. whitespace 오류 없음 |
| `git diff --stat devel...HEAD` | 통과. 전체 Task #484 변경 범위 확인 |
| 금지 경계 변경 검사 | 통과. `Sources/RhwpCoreBridge`, `Sources/HostApp/Resources/rhwp-studio`, `Sources/QLExtension`, `Sources/ThumbnailExtension`, `rhwp-core.lock` 변경 없음 |
| Stage 3 smoke와 최종 source 대조 | 통과. Stage 4 source 변경이 없어 21쪽 HWP·9쪽 HWPX 결과와 commit `cf64b13` 일치 |

최초 sandbox test 실행은 Xcode 사용자 cache와 Sparkle package의 GitHub DNS 접근 제한 때문에 dependency resolve 단계에서 종료됐다. 동일 명령을 허용된 host 환경에서 다시 실행해 package resolve부터 전체 150개 테스트까지 통과했으며 코드·테스트 실패는 없다. WebKit test 중 출력되는 RunningBoard·pasteboard 관련 sandbox 진단은 테스트 실패로 이어지지 않았고 외부 resource/navigation 차단 검증도 통과했다.

표적 18개 테스트는 다음 계약을 최종 상태에서 다시 확인했다.

- 합성 Korean/math PDF의 한글·수식 선택, 검색과 Noto subset `/ToUnicode`
- PDF font exact allowlist route와 invalid path/query/traversal·symlink·signature 거부
- `document.fonts` readiness와 unresolved family의 typed failure
- HTTP/HTTPS resource 0건과 최초 `about:blank` 외 navigation 차단
- page geometry, portrait/landscape, data PNG·nested data SVG와 script 비실행

## 잔여 위험

- positioned SVG text의 추출 순서와 drag selection 경계는 viewer마다 다를 수 있으며 논리 문단 순서를 완전히 보장하지 않는다.
- Hangul/Jamo의 Noto subset은 `uni=yes`지만 Apple/STIX 등 system font resource에는 `uni=no`가 남을 수 있다. 모든 Hanja·수식·기호 glyph의 완전한 선택은 이번 범위가 아니다.
- 이미지·스캔과 path/도형으로 그린 문자는 text layer가 아니므로 선택되지 않는다. OCR이나 숨은 text overlay는 제공하지 않는다.
- page별 font subset 때문에 장문 문서의 font resource 수, 생성 시간과 memory 비용이 증가할 수 있다. Stage 3의 21쪽 HWP는 228개 font resource와 7,540,583-byte PDF였고 동일 조건 v0.1.10보다 크기 증가는 없었다.
- 현재 allowlist에 없는 새 한글 family가 upstream page SVG에 추가되면 조용히 system fallback하지 않고 page 단위 font preparation error로 종료한다. 향후 Studio 동기화에서 alias drift를 함께 확인해야 한다.
- 실제 HWP/HWPX smoke는 수동 회귀다. CI의 deterministic 보장은 합성 Korean/math와 보안 경계 테스트가 담당한다.

## 다음 단계 영향

Stage 1~4 구현·검증·문서화가 모두 완료됐다. 다음 단계에서는 `task-final-report` 절차로 다음 작업만 수행한다.

- `task_m010_484_report.md` 최종 결과 보고서 작성
- 오늘할일 #484 완료 처리와 완료 시각 기록
- 최종 커밋과 `publish/task484` 원격 push
- 대상 통합 브랜치 `devel`의 Open PR 생성

PR merge, Issue #484 close와 local/remote branch·worktree 정리는 별도 승인과 merge 확인 전에는 수행하지 않는다.

## 승인 요청

작업지시자는 Stage 4 문서화·최종 검증 결과를 확인한 뒤 `진행해줘`라고 지시해 Stage 4 종료 보고서 작성과 단계 커밋을 승인했다. 이 보고서와 Stage 4 문서 변경을 하나의 커밋으로 확정한다. 최종 결과 보고서 작성, publish branch push와 PR 생성은 `task-final-report` 절차 진입 승인을 별도로 요청한다.
