# Task M020 #568 Stage 3 — 실제 Studio PDF·인쇄 글꼴 연결 수용

- 이슈: [#568](https://github.com/postmelee/alhangeul-macos/issues/568), 상위 #562, M020 / v0.2 계열.
- 작업: `local/task568`, 직전 단계 `43fc8c3`. [수행계획](../plans/task_m020_568.md)·[구현계획](../plans/task_m020_568_impl.md)·[출력 계약](../tech/task_m020_568_output_contract.md).
- 승인: 작업지시자의 “진행해줘”로 Stage 3 진입. 이후 특정 `sandbox-output-01/StudioOutputAcceptanceProbe.app`와 기존 Developer ID 인증서의 로컬 서명, 실제 인쇄 패널 열기/취소를 명시 승인받았다.
- 상태: 2026-10-09 A의 실제 PDF·인쇄 연결 및 아래 Mac 수용 완료. B의 Stage 4 진입 승인 대기. #568 전체 완료·이슈 close·PR 게시·배포 단계가 아니다.

## 1. 결과와 제품 변경

실제 Studio HWP/HWPX 편집 본문에서 화면과 동일한 설치/관리 공급 계층을 출력에 연결했다. PDF 저장은 목적지 선택 이후 최신 문서를 잠그고 출력 snapshot을 획득한다. 공식 matcher의 선택 ID와 같은 읽기에서 검증한 PS/style/bytes를 출력 WebView에 공급하며, 마지막 문서·글꼴 검증 뒤 atomic write한다. 준비 실패·취소·stale은 기존 목적지와 문서 상태를 보존한다.

인쇄는 같은 collection/공급 계약으로 PDF를 만든 뒤 패널 직전 검증·seal한다. editor lock은 seal 이후 해제하되 관리 lease와 이미 읽은 bytes는 패널 반환까지 유지한다. 준비 취소, operation 생성 실패, `run()`의 true와 false를 구분하고 false만으로 오류와 사용자 취소를 모두 식별했다고 주장하지 않는다. 실제 패널에서 취소한 이번 수용은 성공 출력으로 집계하지 않았다.

주요 변경은 다음과 같다.

| 경계 | 변경과 목적 |
|------|-------------|
| `StudioFontMessageHandler` | 화면과 같은 service의 출력 snapshot 제공. 실제 읽기 관측 hook은 기본값 nil이며 시험 때만 사용 |
| `RhwpStudioWebView.Coordinator` | 문서 token/epoch/changeSeq/loadID/source revision, save lock, 최신 공급 identity, 요청·취소·최종 검증 연결 |
| PDF export/renderer | job 전달, 준비 오류 원인 보존, 쓰기 직전 검증·취소, 늦은 이전 generation 응답 거부, 완료 전 lease 정리 |
| print controller/lifecycle | immutable seal·패널 수명, 중복/늦은 callback·취소, 완료/실패/취소 결과와 정확히 한 번의 정리 |
| output job/preparation | family별 공급/로드 실패 수집, stale/취소 우회 차단, 제한된 busy 재시도, 요청 700을 Regular 400으로 조용히 출력하지 않음 |
| 대체 안내 | 포함할 수 없는 family 목록, 취소 기본값, 명시적 대체 출력만 재시도. 원본 문서/사용 설정은 그대로 유지 |
| host bridge | 실제 native PDF·인쇄 진입, 출력용 페이지 API 사용, 이전 raw print 응답/오류 경로 제거 |
| 설정 안내 | 문서/기존 글꼴 목록의 사용과 PDF·인쇄에 포함할 수 없는 글꼴의 출력 전 안내를 검증한 범위로 표시 |

core pin·Rust FFI·RhwpCoreBridge·native/Finder 소비자는 변경하지 않았다. source adapter는 앱 소유 빌드 변환만 수정하고 upstream checkout은 유지했다. `project.yml`로 인쇄 controller 테스트 등록을 보강하고 생성 Xcode project를 재생성했다.

## 2. 실제 Bold와 Noto 기준선 보정

v0.8.7의 일반 가로 본문 Bold는 portable SVG에서 weight 400 및 글자색과 같은 0.02em stroke로 나올 수 있다. SVG의 weight만 보고 선택하면 실제 Bold face가 쓰이지 않는다. custom만 바꾼 초기 시도는 Noto 기준선의 PDFKit 추출에서 문자가 반복돼 최종 구현으로 사용하지 않았다.

앱 adapter의 `getOutputPageSvg`는 하나의 동기 `withPortableMetrics` 안에서 portable SVG와 layer tree를 함께 얻는다. schema 1.23의 ordinary textRun Bold, identity placement·가로 방향·비효과 스타일·verbatim cluster와 SVG의 본문/family/좌표/크기/색이 유일하게 일치할 때만 700으로 보정하고 그 core faux stroke를 제거한다. transaction 내부에 await를 넣지 않으며 화면 Canvas metrics는 기존 finally 경로로 복원된다.

관리·설치·공급 없는 Noto 모두 같은 보정을 사용하고 공식 matcher/출력 job이 실제 face를 선택한다. 외곽선/그림자/회전/첨자/장평·겹침·모호한 중복은 추측하지 않는다. 이런 효과 전체의 true Bold/레이아웃 일치나 TTC·가변 축 지원을 완료한 결과가 아니다. Stage 2의 별도 합성 영문 header에서 PDFKit의 반복 문자 누락 제약은 남고, 이번 실제 한글/ASCII 본문 수용과 구분한다.

## 3. 실제 문서 수용

환경은 macOS 26.5.2 (25F84) / arm64 / Xcode 26.6 (17F113), deployment target macOS 12.0이다. 실제 제품 Coordinator·WKWebView·편집 입력·provider·output job·atomic write·print seal을 사용하는 별도 probe를 만들었다. 문서 목적지만 private 시험 경로로 주며, 기본 인쇄 callback은 seal된 PDF를 기록하고 false를 반환한다. 이 callback 결과와 실제 시스템 패널 수용은 따로 기록했다.

HWP/HWPX 각각 원본 문서를 열고 실제 편집 입력으로 ` 입력`을 추가한 본문 `한글 가나다 ABC 0123 고운바탕 글꼴 확인 입력`을 출력했다. `가나다`는 Bold이고 나머지 요청은 Regular/기존 fallback이다. PDFKit 추출·검색·영역 선택, 원래 문서 SHA/dirty/changeSeq와 출력 전후 상태를 대조했다. 줄 내부 문자·공백은 exact 비교하며 한글 단어 중간 줄바꿈과 원래 공백에서의 줄바꿈만 원문에 맞춰 허용한다. 공백을 모두 지운 문자열로 성공 처리하지 않는다.

| 공급 경로 | HWP/HWPX PDF 저장 | 인쇄용 PDF·callback | 로컬 서명 sandbox | 실제 패널 |
|-----------|-------------------|----------------------|--------------------|-----------|
| private 관리 고운바탕 Regular/Bold | 두 PS·program·한글 ToUnicode·본문/선택/검색 통과 | seal 뒤 두 face 읽기·false 결과·본문·원본 상태 통과 | 통과 | 실제 패널 열림과 사용자 취소·결과/close 확인 |
| Mac 설치 NanumSquareR/B | 같은 지표 통과 | 같은 지표 통과 | 통과 | 이 경로의 별도 패널 조작은 미실행 |
| 사용자 공급 없는 Noto 기준선 | 한글 Regular/Bold·본문/선택/검색 통과 | 사용자 bytes 읽기 0·false 결과·원본 상태 통과 | 통과 | 이 경로의 별도 패널 조작은 미실행 |

독립 pypdf 6.10.0 및 Poppler 26.07.0으로 PDF 저장/인쇄 PDF 각 HWP/HWPX, 세 공급 경로 합계 **12개 PDF**를 대조했다. Regular/Bold font program과 한글 ToUnicode, 줄 내부 공백을 포함한 본문이 확인됐다. 고운바탕/NanumSquare/Noto PDF를 PNG로 렌더하여 표시·Bold·줄바꿈을 눈으로 확인했다. NanumSquare의 단어 중간 줄바꿈은 원문 대조에 맞게 처리했다. Noto serif 기준선은 `NotoSerifKRExtraLight-Regular/Bold`, 입력의 기존 fallback은 `NotoSansKR-Regular` 등을 사용한다.

ASCII subset은 MacRoman 등 기존 encoding을 사용하며 모든 subset에 ToUnicode가 있어야 한다고 가정하지 않는다. PDF subset hash는 원본 TTF hash와 다르다. pypdf는 PDFKit 재직렬화물의 미사용 xref offset 0 항목에 경고를 남겼으나 위 font/text 검사는 통과했고 Poppler에서도 읽혔다. 별도 PDF 표준 적합성 인증을 수행한 결과는 아니다.

기존 SVG 논리 bounds에 따른 794×1123 pt 한 페이지를 유지했다. 물리 A4의 mm 크기 교정이나 종이 출력/프린터별 배율은 이번 글꼴 검증으로 보증하지 않는다. 표/수식의 기존 단위 회귀는 통과했지만 모든 실제 복합 문서의 시각 수용을 완료한 것은 아니다.

### 필요한 face만 읽은 증거

| 경로 | 최종 검사 수 | 전체 읽기 관측 | 정상 job별 사용자 bytes |
|------|--------------|----------------|--------------------------|
| managed + 실제 패널 | 30 | 18회 | R 8,433,296 + B 8,178,712 = 16,612,008 bytes |
| installed | 25 | 14회 | R 723,640 + B 733,500 = 1,457,140 bytes |
| baseline | 16 | 0회 | 0 |

전체 횟수에는 반복 PDF/인쇄와 의도한 취소·제거·복원/재출력이 포함된다. 정상 job마다 필요한 두 face를 각각 한 번 읽고 다음 출력은 새 snapshot/bytes를 사용한다. 영구 bytes cache나 전체 설치 목록의 파일 선읽기를 추가하지 않았다. resident 한도 128 MiB는 native job 보유 bytes의 제한이고 WebKit/PDFKit 및 inspector 임시 복제를 포함한 프로세스 최고 메모리 측정치가 아니다.

원본 식별:

| face | SHA-256 |
|------|---------|
| GowunBatang-Regular | `466c593e7147412e748af4856d5ad14709b5a860bdf62b9c2546f2c5874e9849` |
| GowunBatang-Bold | `dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94` |
| NanumSquareR | `5a51deae5237435d9a0bc0cc6cc30619a914b29801f895698cfdacadcad06e94` |
| NanumSquareB | `f737d58294faec9c632189af3a2a3e48e49c03c0256de09db61e879e2857bfbf` |

고운바탕은 #567에서 승인 다운로드한 Google Fonts commit `c1eda9233c33ad7775b27efd794f931095cf6133`, v2.000/OFL 입력을 재사용했다. 영구 OS 설치는 수행하지 않았다. NanumSquare는 기존 Mac의 활성 원본을 읽기만 했고 삭제/교체하지 않았다. 기술적 fsType 자격은 사용 근거 unknown을 라이선스 허가로 바꾸지 않는다.

## 4. 실패·취소와 실제 범위

- 실제 관리/설치 bytes가 반환된 직후 시험 observer가 준비를 취소해 기존 목적지를 보존하고 늦은 결과를 폐기했다. **물리 파일 I/O 진행 중 취소**를 이 observer로 검증했다고 주장하지 않는다.
- private 관리 자산을 실제 제거하면 generation 변화로 stale 중단했다. 대체 확인 hook을 우회하지 않고, 해당 복사본을 다시 가져온 뒤 새 job으로 재출력했다. 사용자 원본/OS 글꼴은 제거하지 않았다.
- snapshot 읽기 중 취소의 slot/lease 수명, 문서 identity·provider generation 변경, 임베딩 선언/사용 근거 차단·unsupported·모호성·한도는 단위 시험으로 확인했다.
- `FontFace.load` 실패는 private-world 시험에서 의도적으로 주입하여 family별 실패 식별과 lease 종료를 확인했다. 기본 취소/명시 대체는 Noto 준비와 함께 검증했으며 stale/취소는 대체로 우회하지 않는다.
- PDF 최종 validation 대기 중 취소·재진입, validation/atomic write 실패·기존 목적지 유지, print seal 뒤 원본 변화와 bytes/lease 유지, false/nil operation 및 늦은 callback은 단위 수명 시험이다.
- 실제 사용자 OS 원본 삭제·권한 상실, 문서 교체/강제 WebContent 종료의 전체 Coordinator 수용은 이번 probe에서 수행하지 않았다. 공유 service·job/renderer의 주입 검증 및 기존 lifecycle smoke와 구분하여 #569에 남긴다.

## 5. 서명·패널과 시험 지연 원인

승인 대상은 `build.noindex/task568/stage3/sandbox-output-01/StudioOutputAcceptanceProbe.app` 하나이며 `Developer ID Application: Taegyu Lee (XH6JHKYXV8)`로 로컬 서명했다. sandbox/network client/user-selected read-write/bookmark/print entitlement만 쓰고 사용자 App Group을 공유하지 않는다. 공증·설치·배포·물리 프린터 전송은 수행하지 않았다.

같은 시험 ID의 ad-hoc 앱을 Developer ID로 바꾼 최초 시도는 macOS의 “이전에 열었던 버전과 다릅니다” 데이터 접근 확인창에서 멈췄다. sample의 `_libsecinit_appsandbox`로 앱 main 이전 대기임을 확인했고 사용자 첨부 이미지도 같은 알림을 보여줬다. 기존 데이터 접근을 승인/이전하지 않고 시험 ID를 `com.postmelee.alhangeul.OutputAcceptance.a1ba3091ff.signed`로 분리한 빈 컨테이너에서 진행했다. 제품 bundle ID/서명 정책은 바꾸지 않았다.

그 다음 두 번의 패널 시험은 UI 도구의 오래된 앱 ID 참조와 수동 취소를 포함한 시험의 45초 제한 때문에 timeout이었다. 실제 프로세스 stack은 `NSPrintPanel.runModalWithPrintInfo`에 도달했다. 패널 전용 시험 대기만 180초로 보정하여 같은 승인 앱/인증서로 다시 빌드·서명했다. 최종 실행은 사용자 취소 후 `cancelledOrFailed`·close 결과를 기록하고 30개 검사 모두 통과했다. 기본 자동 동작의 45초 제한은 유지했다.

UI 도구의 이전 ID 캐시를 피하기 위해 동일 서명 앱의 임시 복사 경로를 잠시 등록했다. [소유 경로 13개 등록 잔존 0](assets/task_m020_568_stage3/registration-cleanup.json)을 확인했고 QL/Thumbnail을 등록하지 않았다. 이 정리는 HostApp 빌드 중 자동 등록된 소유 Sparkle Updater도 포함한다. 기존 사용자 앱·#567 체험 앱·원본 글꼴을 변경하지 않았다. 체험 창은 29개 검사/16회 읽기로 통과한 별도 managed 인스턴스로 남긴다. 실제 패널 screenshot은 UI 도구가 문서 창만 반환해 확보하지 못했으며, 사용자 취소·native panel stack·결과 JSON을 근거로 삼는다. PDF와 편집기 screenshot은 아래 assets에 보존했다.

## 6. 검증 명령과 결과

| 명령/검증 | 결과 | raw 근거 |
|-----------|------|----------|
| `scripts/test-font-library.sh` | 122개 통과 | `build.noindex/task568/stage3-font-tests.log` |
| `node --test scripts/ci/test-studio-font-*.cjs` | 30개 통과 | `stage3-js-tests.log` |
| `scripts/test-studio-output.sh` | 출력·PDF·print 등 9개 class, 81개 통과 | `stage3-output-tests.log` |
| `python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/re-font-dotum-empty-hancom.hwp` | HWP/HWPX·저장/close·실제 font IPC 포함 43개 통과 | `stage3-lifecycle.log`, `build.noindex/studio-lifecycle-lfrnogyg/` |
| HostApp Debug `CODE_SIGNING_ALLOWED=NO` / macOS 12 target | compile/link 통과 | `stage3-host-build.log`, `stage3/host/` |
| Studio transformed source build/typecheck·asset sync | 통과, 공식 v0.8.7/WASM/Cargo pin 유지 | `stage3-studio-build.log`, `stage3-studio-sync.log`, bundle manifest/adapter receipt |
| `scripts/check-no-appkit.sh`·`scripts/verify-rhwp-studio-assets.sh`·`git diff --check` | 통과 | 최종 source·receipt와 대조 |
| probe managed/installed/baseline + 실제 panel | 각각 30/25/16 검사 통과 | `stage3-panel-final.log`, `stage3-installed-final.log`, `stage3-baseline-final.log` |
| pypdf/Poppler 12 PDF 및 세 PNG 시각 검사 | 통과 | [독립 PDF 증거](assets/task_m020_568_stage3/independent-pdf-proof.json) |

새 `RhwpStudioPrintControllerTests`는 기존 CI가 실행하는 output helper의 목록에 추가했다. compiled 제품 소스가 바뀌지 않은 뒤 테스트 probe의 수동 timeout만 보정했으므로 통과한 전체 제품 테스트를 불필요하게 반복하지 않았다. 최종 probe는 compiler 입력·bundle 자산·exe hash·sandbox/ID/서명을 확인하고 같은 최종 바이너리에서 세 경로를 확인했다. 실행 driver hash와 compiled 입력 fingerprint를 구분하며 `--skip-build`는 compiled source/asset/exe 변경을 우회하지 못한다.

재현 명령은 [probe 안내](../../Tests/StudioOutputAcceptanceProbe/README.md)를 따른다. 승인된 기존 앱 재사용의 실제 패널 명령은 다음과 같다. physical print는 선택하지 않는다.

```bash
python3 scripts/probe-studio-output-acceptance.py \
  --output-dir build.noindex/task568/stage3/sandbox-output-01 \
  --font-dir build.noindex/task567/fonts/gowun-batang \
  --sandbox --skip-build \
  --sign-identity 'Developer ID Application: Taegyu Lee (XH6JHKYXV8)' \
  --source managed --panel --interactive
```

## 7. 선별 증거·체험·다음 단계

- [환경/서명/실행·검사 집계](assets/task_m020_568_stage3/acceptance-summary.json), [managed 결과](assets/task_m020_568_stage3/managed-result.json), [installed 결과](assets/task_m020_568_stage3/installed-result.json), [baseline 결과](assets/task_m020_568_stage3/baseline-result.json).
- [관리 글꼴 편집기](assets/task_m020_568_stage3/managed-editor.png), [고운바탕 PDF](assets/task_m020_568_stage3/managed-pdf.png), [설치 NanumSquare PDF](assets/task_m020_568_stage3/installed-pdf.png), [Noto 기준선 PDF](assets/task_m020_568_stage3/baseline-pdf.png).
- raw PDF·private 결과는 `build.noindex/task568/stage3/sandbox-output-01/{managed,installed,baseline}/`에 유지한다. 원본 글꼴·PDF·app·거대한 receipt/source dump는 커밋하지 않는다.
- 직접 조작 창: `알한글 — PDF·인쇄 글꼴 · Stage 3 격리 검증`. 패널 수용과 별개로 `--run=interactive-final --source=managed --interactive`로 창을 다시 열었다. PDF 목적지는 private `current.pdf`, 인쇄는 PDF를 기록하고 false를 반환하는 시험 hook이다. 일반 저장창·실제 인쇄 패널과 구분한다.

최소 macOS/Intel 실제 실행, 실제 한컴 설치본 제거, Windows ZIP, native CoreGraphics/Skia, signed Finder 수용, 물리 인쇄·공증/배포는 미완료다. 다음은 Stage 4의 native 공급·우선순위·캐시/FFI 경계를 구체화하는 작업이며 단계 승인 후 진행한다. A 성공만으로 #568을 close하거나 Finder/Windows 지원을 선언하지 않는다.
