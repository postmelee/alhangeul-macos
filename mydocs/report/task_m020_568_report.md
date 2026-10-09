# Task M020 #568 — 설치·가져오기 글꼴의 출력·native·Finder 연결

## 1. 작업 요약

- 이슈: [#568 설치·가져오기 글꼴의 PDF·인쇄·native·미리보기 연동](https://github.com/postmelee/alhangeul-macos/issues/568), 상위 #562.
- 마일스톤: M020 — 글꼴 마이그레이션 / v0.2. 작업 `local/task568`, 게시 `publish/task568`, PR base `devel`.
- 수행: 6단계 및 Stage 4.0/4.1의 조사·격리 검증. 최종 보고·PR 게시 승인: 2026-10-10 Stage 6 완료 보고 후 “진행해줘”.
- 기준: #567 Studio 연결 이후 `db8a94d1eb03f5a14f265621191f85f0ddf149cb`; 제품 최종 구현 `817d1931`, 증거/인계 `d67b3363`.

Studio에서 쓰는 설치 참조·관리 복사본을 PDF·인쇄 및 공통 native CG/Skia·Quick Look·Thumbnail에 연결했다. 공식 matcher가 고른 실제 PS/style/hash의 필요한 bytes만 공급하며, 지원하지 못하는 글꼴을 정확한 적용 성공으로 처리하지 않는다. PDF·인쇄는 작업별 snapshot·문서 identity·준비·취소·seal/쓰기 검증을 소유하고, 확장은 자체 권한·읽기 전용 App Group 공급과 font/source identity를 사용하는 캐시로 동작한다.

core/Studio는 공식 `v0.8.7` / `1a76570e833917d15817415a53c09ad61ab3203f`를 유지했다. upstream source를 수정하지 않고 앱 소유 Studio source adapter와 두 C ABI를 추가했다. HostApp viewer는 계속 Studio이며 native viewer UI 전환은 범위 밖이다. 지원 판정은 [소비자 인계](../tech/task_m020_568_consumer_handoff.md)의 Mac 설치/관리·Windows·signed/unsigned·실제/주입 구분을 따른다.

## 2. 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioOutputFont{Job,Policy,Preparation,BridgeScript,FallbackAlert}.swift`, `RhwpStudioPDFFontProvider.swift` | 출력 전용 snapshot·공식 선택·검증 bytes·token/ID route·임베딩 기술 정책·취소 기본/명시 대체. 기존 Noto와 WebKit 격리 유지 |
| `RhwpStudioWebView.swift`, `RhwpStudioHostBridgeScript.swift`, `RhwpStudioPDFExportController.swift`, `RhwpStudioPagePDFRenderer.swift`, `RhwpStudioPrint{Controller,Lifecycle}.swift` | 실제 PDF/인쇄 진입·collection lock·문서/글꼴 current·atomic write·패널 전 seal·패널 반환까지 bytes/lease 수명·늦은 callback 정리 |
| `scripts/studio-font-menu-adapter.mjs`, `build-rhwp-studio.mjs`, bundled `rhwp-studio/` | 공식 matcher 선택 결과의 좁은 출력 API와 ordinary Bold의 portable SVG/layer tree 대조. transformed source typecheck·receipt/manifest/hash 갱신, WASM/core pin 유지 |
| `RustBridge/src/font_context*`, `lib.rs`, `Cargo.*`, `cbindgen.toml`, `rhwp-ffi-symbols.txt`, `rhwp-core.lock`, `RhwpNativeFontContext.swift`, `RhwpDocument.swift`, `CGTreeRenderer.swift`, `FontFallback.swift` | 원본 slot/family/style 조회와 exact static bytes 기반 제한된 native replay. 기존 ABI 유지·새 header/symbol/artifact 검증. RhwpCoreBridge의 AppKit/UIKit 금지 유지 |
| `Sources/Shared/FontLibrary/{HostFontSupplyTypes,RhwpNativeFontMatcher,RhwpNativeFontMatcherSource}.swift`, matcher receipt, `Shared/NativeFonts/HwpNativeFontPageRenderer.swift`, `HwpNativeFontSupply.swift` | pinned 공식 matcher를 JavaScriptCore 작업별 realm에서 재사용. 필요 face만 읽어 bytes context 생성·budget·generation·문서/취소·cache identity 검증. matcher 생성 파일 15,273줄은 직접 작성한 매칭 알고리즘이 아님 |
| `Sources/Shared/FontLibrary/`의 이동한 9개 service, `FontConsumerPolicyStore.swift`, `ExtensionFontSupply.swift`, `FontLibrary{FileSystem,Store,Location,Models}.swift` | Foundation/CoreText 서비스의 공통 소유, flag/revision만 공유, pending 게시 실패 차단·metadata 선읽기 제거. 실제 확장 sandbox의 쓰기 거부에 맞춘 읽기 전용 목록/FD snapshot/shared flock |
| `Shared/NativeFonts/ExtensionFontRenderer.swift`, Shared preview/compositor, `HwpPreviewProvider.swift`, `HwpThumbnail{Provider,RenderCache}.swift`, 확장 Info/entitlements | 확장 자체 설치 목록/권한과 관리 bytes 공급, 외부 이미지 context 보존, 실패의 기본 대체·stale 폐기. thumbnail exact/larger·설정/원본/문서 identity·동시/캐시 제한 |
| `Tests/{FontLibraryTests,HostAppTests,StudioOutputFontProbe,StudioOutputAcceptanceProbe,NativeFontSupplyProbe,ExtensionFontProbe}/`, 관련 `scripts/`, `.github/workflows/pr-ci.yml`, `project.yml`, 생성 Xcode project | 필요한 공급·선택·보안·수명/출력·cache 회귀와 실제 수용/재현 도구. CI output 검사를 연결하고 project는 `project.yml`로 재생성 |
| `scripts/smoke-clean-quicklook-install.sh`, `prepare-extension-font-smoke.py`, `extension-font-finder-smoke.py`, `mydocs/{plans,working,tech,report,orders}/`, `.gitignore` | 승인된 signed/sealed 시험·원래 앱 보존/복원·소유 등록 정리. 단계 계약/증거·지원 경계·#566/#569 인계, Python cache 제외 |

원본 사용자 글꼴·상용 font bytes·생성 앱/DMG는 커밋하지 않는다. 선별 PNG·작은 unsigned PDF·JSON은 실제/시험 범위를 명시해 보존했다. 제품 UI의 지원 안내는 Studio/출력 가능 범위만 보정했으며 전체 글꼴 이전·한컴 제거 후 유지·Windows 지원을 선언하지 않았다.

## 3. 변경 전·후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| PDF/인쇄 사용자 글꼴 | 화면 공급과 독립, Noto 보정에 정확한 한글 face가 가려질 수 있음 | 실제 설치/관리 두 face·program·한글 mapping·본문 확인. 불가 face는 취소 기본/명시 대체 |
| native/Finder 공급 | 앱 저장소·Studio 결과만으로 확장 원본 접근을 확인하지 못함 | CG/Skia exact bytes context, 실제 signed QL/Thumbnail 설치/관리·재실행 수용 |
| 관리 metadata 열거 | snapshot 획득에 전체 선택 object 판독 포함 | metadata/lease와 실제 필요한 resource 판독 분리, 필요 없는 object bytes 읽기 없음 |
| Thumbnail cache | font snapshot·원본/정책 변화의 identity 미연결 | 새 snapshot 확인 후 exact/larger 재사용, settings/managed/source stamp·문서 inode/ctime 반영. 대체 bitmap 미보관 |
| FontLibraryTests | #567 최종 109개 | 최종 133개 통과 |
| 실제 출력 필요 bytes | 제품 소비자별 측정 미완료 | 정상 고운바탕 job R/B 각 1회, 합계 16,612,008 bytes. NanumSquare R/B 1,457,140 bytes |
| 자원 제한 | 출력/native/확장 사용자 공급 한도 미연결 | 2 read slot, 64 face·개별 64MiB·job 128MiB. thumbnail 2 render·16 준비·96항목/64MiB bitmap |

확장 metadata 준비는 signed 32건 최소 453.64ms / 중앙값 1,089.77ms / 최대 2,949.45ms였다. cache hit에도 전체 scan/stat 비용이 남고 동시 대기를 포함한다. #567의 HostApp 최초 활성화 중복 탐색 제거와 다른 문제이며 전체 앱 실행 시간이나 peak 메모리 개선률로 사용하지 않는다.

## 4. 수용 기준별 검증

| 기준 | 판정 | 근거와 검증 경계 |
|------|------|------------------|
| 공식 선택·좁은 공급·경로 비노출 | OK | v0.8.7 matcher/source adapter·생성 receipt, PS/style/hash·opaque ID/route·외부 resource 차단. 원래 문서 family 보존 |
| PDF 실제 face/한글 text layer | OK | signed sandbox의 관리 Gowun R/B·설치 NanumSquare R/B·Noto 대조, HWP/HWPX 편집 본문. program·ToUnicode·추출·검색/영역 선택, Poppler/pypdf 12개 PDF 대조 |
| 인쇄의 독립 진입·seal·패널 수명 | OK | 각 공급 경로의 인쇄 PDF/callback·수명 회귀, 관리 경로 실제 macOS 패널 열기/사용자 취소. false는 취소/실패 공통. 물리 출력의 성공이 아님 |
| native CG/Skia exact bytes | OK | 관리 R/B HWP/HWPX·혼합 한글/ASCII, 실제 OS ArialUnicodeMS·프로세스 등록 fixture. 동명/원본 변경·glyph 변경/복원·문서 current·stale/취소·필요 읽기·budget 검사 |
| Quick Look signed 프로세스 | OK | 실제 Release CoreGraphics 설치/관리 PNG·2페이지 PDF의 양쪽 페이지 PS·실패/복구·새 PID. PDF 파일 복사본 대신 실제 UI/로그 증거 |
| Thumbnail signed 프로세스·cache | OK | 실제 Release 설치/관리·동일 경로 exact/larger·설정/원본 제거/복구·PID 재실행. 2-job/admission·취소/lease 회귀는 unsigned 공통 수용과 구분 |
| read-only App Group·GC/세대 | OK | 실제 첫 두 확장의 lock 쓰기 거부를 보정한 최종 signed 시험. RO lock/FD metadata·읽는 동안 shared flock·선택/hash 재검사, 생성/쓰기 없음·GC 후 stale 회귀 |
| 원래 설치본 복원·등록 정리 | OK | Stage 5의 152개 파일/링크 원본 일치·서명, 설치 provider `/Applications/Alhangeul.app`, 개발 등록/앱/issue/warning 0. 고유 group fixture 삭제, 전역 reset 없음 |
| 최종 소스·증거·빌드 | OK | Stage 5 source 125개 전부 현재 일치·signed checksum 26개·PDF 12개·고운바탕 2개·core artifact 2개 대조. 최종 FontLibrary 133/HostApp 237, 일반/probe Release 빌드 통과 |
| core/ABI·producer 회귀 | OK | Rust 29개·arm64/x86_64 archive·header/symbol·portable/동일 환경 strict·golden 수용. core release/commit 유지 |
| 최종 보고 시 가벼운 검증 | OK | main/source content gate·build info·native matcher/Studio receipt·no-AppKit·증거/local 링크·diff 검사. 제품 소스 변경 없이 기존 시험 결과 재사용 |
| PR 게시 후 Cargo.lock fixture 보정 | OK(로컬), 원격 CI 재검증 | 초기 CI의 가짜 upstream에 새 adapter 입력 `src/main.ts`가 없어 ENOENT. 해당 fixture 파일을 추가하고 동일 `test-rhwp-studio-cargo-lock-verification.sh` 및 shell syntax 통과. 제품/어댑터·검증 정책은 그대로 유지 |

단계별 실행·재사용은 [Stage 1](../working/task_m020_568_stage1.md), [Stage 2](../working/task_m020_568_stage2.md), [Stage 3](../working/task_m020_568_stage3.md), [Stage 4](../working/task_m020_568_stage4.md), [Stage 5](../working/task_m020_568_stage5.md), [Stage 6](../working/task_m020_568_stage6.md)를 따른다. 최종 보고 단계에서 native/HostApp/signed 수용을 전부 재실행하지 않았다. Stage 6 JS 30개 및 최종 133/237개 성공은 서로 다른 시험 집합/시점이다.

Stage 3 signed 출력 compiled 입력은 177개 중 162개 현재 hash 일치, 15개 공통 service/native/probe 입력 변경이다. Stage 4 receipt는 31개 중 27개 일치, 4개 변경이며 Stage 5 회귀로 연결한다. 이후 제품 source 125개는 최종 signed Finder 입력과 전부 일치한다. 모든 소비자를 같은 최신 signed 배포 후보에서 재수용했다는 뜻은 아니다. [증거 대조](../working/assets/task_m020_568_stage6/evidence-audit.json)와 최종 점검 로그 `build.noindex/task568/final-report/`를 보존한다.

2026-10-10 [PR #579](https://github.com/postmelee/alhangeul-macos/pull/579) 게시 직후 `Script syntax checks`의 Cargo.lock fixture 단계가 실패했다. [실패 job](https://github.com/postmelee/alhangeul-macos/actions/runs/37964231501/job/113934497967)의 ENOENT와 `sourcePaths` 4개/fixture 3개 차이를 확인했다. 기존 시험만 현재 adapter 입력 계약에 맞게 보정했고, 로컬에서 Cargo.lock fingerprint/checkout·receipt·sync·production 불변 회귀가 통과했다. `cargo-lock-fixtures.log`와 초기 CI 로그를 보존하며 원격 CI 통과 여부는 수정 head에서 별도로 확인한다.

같은 날 다음 [macOS CI job](https://github.com/postmelee/alhangeul-macos/actions/runs/37964819628/job/113936836296)의 PDF 검사 4건이 실패했다. macOS 15.7.9의 `PDFPage.string`/검색에서는 `㈀`·`㉠`·`²`가 호환 분해된 반면 영역 선택의 원문 검사는 통과했다. PDF 생성과 reader 동작을 구분하기 위해 고정 합성 fixture 4개만 PDF·현재/재열기 추출·검색·font resource JSON으로 보존하도록 연결했다. 외부 paint URL 차단 fixture에는 검은색 fallback과 문구가 잘리지 않는 폭을 명시했다. macOS 26.5.2에서 출력 관련 81개 검사와 Poppler 원문 추출·PNG 대조가 통과했으며, macOS 15의 실제 PDF 대조와 최종 원인 판정은 진행 중이다. 이 시점에 제품 renderer 변경이나 원문 보존 기준 완화는 하지 않았다.

같은 수용 문서의 사용자 공급 없는 Noto 기준선과 관리 고운바탕 적용 결과다. 과거 제품 화면을 새로 촬영한 Before/After로 해석하지 않는다.

| PDF 기준선 | 관리 글꼴 PDF |
|------------|--------------|
| ![Noto 기준선](../working/assets/task_m020_568_stage3/baseline-pdf.png) | ![고운바탕 적용](../working/assets/task_m020_568_stage3/managed-pdf.png) |

## 5. 잔여 위험과 후속 작업

| 범위 | 판정/인계 |
|------|-----------|
| Windows ZIP·독립 입력 | MISS/범위 외. #566 실제 Windows 입력·ZIP 경계·원본 제거 후 독립 보관, #569 Windows 소비자 수용. Mac 성공으로 대체하지 않음 |
| 최종 제품 시나리오·웹 안내 | #569 최종 후보의 설정/권한→문서/출력→재실행·변경/복구 및 메뉴/그림/링크·지원 범위 수용. 공개 배포는 별도 승인 |
| 최소 macOS/Intel runtime·실제 한컴/제거·물리 프린터 | MISS(실환경 미확보/범위 외). macOS 12 compile·Intel archive·OFL fixture·인쇄 패널 취소로 대체하지 않음 |
| 형식/typography | 제한된 static SFNT·출력/native 400/700 스타일·PositionAdjusted replay. TTC/가변/HFT·전체 shaping/효과/pagination 미지원. AppleMyungjo/AppleGothic inspector 제한 유지 |
| PDF reader·물리 geometry | 별도 합성 영문 header의 PDFKit 반복 문자 누락이 남음. 일반 가로 Bold 밖 효과/모호한 run·모든 복합 문서·물리 A4 mm 교정은 미검증. 스캔/path 글자 OCR 없음 |
| 반복 탐색·큰 입력의 성능/메모리 | 확장 매 요청 metadata 중앙값 약 1.09초. 새 최적화 이슈 범위 검토 후보. 전체 프로세스 peak RSS·대형 목록/다수 문서 공정성 미측정 |
| 즉시 갱신/OS cache | 새 요청의 same-path 무효화는 확인. 활성 job 중 새 후보 추가의 즉시 재선택, 이미 열린 QL 즉시 갱신·OS가 요청하지 않는 영구 thumbnail cache 자동 갱신은 미보증 |
| upstream 기여 | static bytes/slot/style의 범용 Rust helper·공개 가능한 회귀부터 분리 검토. family당 한 face 의심은 독립 runtime 재현 전 버그로 선언하지 않음. 앱 C ABI·CoreText/App Group/QL 운영은 앱 소유 |

설치 참조는 원본 삭제/비활성/권한 상실 이후 계속 사용을 보장하지 않는다. 독립 보관은 별도 가져온 복사본에만 해당한다. fsType의 기술적 자격과 usage evidence는 구분하며 unknown을 라이선스 허가로 바꾸지 않는다.

Stage 5 승인 시험 후 기존 앱을 복원하고 후보/백업/staging/helper를 정리했다. 최종 signed 정리 논리 합계 3,416,632,974 bytes와 앞선 unsigned 866,676,388 bytes를 구분하며 APFS 실제 여유 공간 증가량으로 단정하지 않는다. 최종 보고에서 앱/DMG를 다시 만들지 않았고 리뷰에 필요한 로그·PDF·CLI 결과는 보존했다.

## 6. 작업지시자 승인 요청

2026-10-10 승인된 최종 보고/`publish/task568` → `devel` Open PR #579 게시를 완료했다. 초기 CI fixture 누락은 동일 게시 검증 범위의 기존 시험 보정으로 회복했다. 6단계의 제한된 Mac 소비자 연결·검증·인계를 완료했으며 #568 merge/이슈 close, 후속 이슈 구현·upstream 공개 게시·제품/웹 배포 승인은 포함하지 않는다. 수정 head의 PR CI와 리뷰에서 범위·잔여 조건을 확인한 뒤 merge 승인을 요청한다. #566/#569·상위 #562 추적은 유지한다.
