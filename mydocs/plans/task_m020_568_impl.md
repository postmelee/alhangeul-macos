# Task M020 #568 — 출력·native·Finder 글꼴 연결 구현계획

- 수행계획: [task_m020_568.md](task_m020_568.md)
- 이슈: [#568](https://github.com/postmelee/alhangeul-macos/issues/568), M020 / v0.2 계열, 상위 #562
- 작업: `local/task568` → `publish/task568` → `devel`
- 제품 기준: `db8a94d1eb03f5a14f265621191f85f0ddf149cb` (PR #578), 공식 core/Studio v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`
- 승인: 2026-10-08 작업지시자의 “진행해줘”로 수행계획 승인·구현계획 작성 진행.
- 상태: 2026-10-10 [Stage 6 수용/인계](../working/task_m020_568_stage6.md) 및 승인된 [최종 보고](../report/task_m020_568_report.md) 완료. core v0.8.7과 제품 소스를 유지하며 범용 upstream 기여 후보를 취합했다. `publish/task568` → `devel` Open PR 게시 진행, CI·리뷰/merge는 후속.

## 1. 단계와 완료 경계

| 단계 | 소비자 | 목표 | 진입 상태 |
|------|--------|------|-----------|
| 1 | A/B 조사, A 계약 | 출력 identity·매칭·임베딩·변경/취소 정책과 최소 실험 | 2026-10-08 완료 |
| 2 | A 공통 기반 | 제한된 출력 snapshot·font route·준비·수명 구현 | 2026-10-09 완료 |
| 3 | A 실제 연결 | PDF·인쇄 진입 연결, 정확한 face와 text layer·패널 수용 | 2026-10-09 완료 |
| 4 | B native | CoreGraphics/Skia 공급·매칭·캐시 연결 | 2026-10-09 완료 |
| 5 | B 확장 | Quick Look/Thumbnail의 signed 프로세스·Finder 수용 | 2026-10-10 구체 승인 범위 수용·복원 완료 |
| 6 | 전체 인계 | 소비자별 회귀·제약·최종 소스/증거 대조 | 2026-10-10 승인·완료 |

A 완료는 #568 전체 완료가 아니다. B와 Mac/Windows 수용을 별도 행으로 기록한다. #566 ZIP 구현, #569 웹 안내·전체 배포 수용은 해당 이슈에 남긴다. core pin/Studio 자산을 먼저 재동기화하거나 중복 PR #577을 merge하지 않는다.

## 2. 공통 구현 계약과 결정 사항

### 2.1 문서·글꼴 identity와 수명

- 작업 단위는 native 요청 ID, editor loadToken·documentEpoch/revision, 설치 generation, 관리 snapshot generation/digest와 필요한 face 선택 목록을 묶는다. PDF 목적지 선택 이후의 최신 문서 상태를 기준으로 페이지와 face를 수집한다.
- 설치 service와 관리 service는 #567의 공유 인스턴스를 사용한다. 관리 snapshot의 lease는 작업 완료/실패/취소까지 유지한다. 설치 원본은 필요한 읽기마다 동일 identity·활성 상태·bytes를 검증하며 lease가 원본 파일을 고정한다고 취급하지 않는다.
- 확정 정책은 준비 중 문서/글꼴 변경 시 중단, PDF atomic write 직전 재검증, 인쇄 패널 직전 재검증·immutable PDF seal이다. seal 이후 패널에는 해당 PDF만 유지하며 편집/글꼴 변경으로 교체하지 않는다. 이미 spool된 출력을 회수한다고 약속하지 않는다. 서로 다른 generation의 bytes는 섞지 않는다.
- UI 취소와 실제 I/O 종료를 구분한다. 늦은 응답은 폐기하며 진행 중 읽기가 반환하기 전 동시 slot을 해제하지 않는다. page watchdog·exactly-once completion·재진입을 유지하고 성공/실패/취소 모두 lease와 opaque route를 정리한다.

### 2.2 선택·공급·한도

- 공식 `resolveRendererLocalFont`, `loadRendererLocalFont`, `collectHostFontRequests`와 #567의 관리 우선·충돌 차단을 재사용할 경계를 검증한다. 이 함수들이 TS module에서 export된다는 사실을 window 공개 API 제공으로 확대하지 않는다.
- Stage 1에서 공개 surface와 앱 소유 source adapter 후보를 비교한다. 필요한 adapter가 있다면 기존 matcher를 호출하는 좁은 연결만 두고 typecheck·receipt/hash를 갱신한다. 이름/스타일 matcher를 Swift에 복제하거나 minified 자산을 직접 수정하지 않는다. 제품 변경은 Stage 2 이후 승인 범위다.
- 요청 family/style → 선택 source/opaque ID/revision → 검증된 PS·SFNT face·bytes hash → 출력 font resource의 대응을 기록한다. 지역화 별칭·family와 fullName의 차이·Regular/Bold·동명 충돌·지원하지 않는 slant를 검사한다.
- 사용자 font URL은 작업 token과 허용 face ID에만 연결한다. native 원본 경로/bookmark·전체 manifest는 JS/HTML에 보내지 않고, 다른 작업·이미 만료된 token·임의 filename/URL은 거부한다. 내장 Noto 4종의 기존 route는 유지한다.
- 파일 64 MiB, 화면+출력의 두 읽기 동시 한도를 유지한다. 초기 출력 job 한도는 고유 face 64, family/style 요청 2,048, native 유지 사용자 bytes 128 MiB다. 두 face의 실제 유지량은 16,612,008 bytes이며 전체 프로세스 peak 메모리 검증을 뜻하지 않는다. 초과를 무제한 queue나 조용한 font 교체로 우회하지 않는다.

### 2.3 임베딩·fallback·text layer

- `embeddingFlags`와 `FontUsageEvidence`를 출력 전용 정책 입력으로 보존한다. 화면 DTO에 해당 정보가 없다는 이유로 허가 상태를 만들어 넣지 않는다. `unknown`을 `allowed`로 자동 변환하지 않는다.
- 검증된 OS/2 version·fsType의 기술적 허용 선언으로 후보를 정하며 명시 restricted 근거는 차단한다. evidence unknown은 그대로 보존하고 허가로 변경하지 않는다. no-subsetting·bitmap-only·불명확한 legacy 선언은 현재 exact 경로 미지원이다. 공급/임베딩/충돌 실패는 취소 기본·명시 대체 출력으로 처리한다. 새 라이선스 승인/근거 수집 UI를 정상 흐름에 추가하지 않는다. 세부 조건은 출력 계약 5절을 따른다.
- exact face 적용과 기존 Noto fallback을 분리한다. custom face를 Noto alias 규칙으로 덮지 않고, 공급 대상이 아닌 글꼴의 기존 한글/자모·ASCII·Hanja·수식 fallback을 보존한다. 새 alias는 출력 DOM에만 적용하며 원본 문서 이름/bytes는 변경하지 않는다.
- `document.fonts.ready/load/check`뿐 아니라 해당 face의 loaded 상태와 PDF PS/스타일·font program 임베딩·ToUnicode·텍스트를 확인한다. bitmap화·OCR overlay로 searchable text를 대신하지 않는다. WebKit/PDFKit subset에서 한계가 재현되면 성공으로 합산하지 않고 Stage 2 범위를 보정한다.
- 원본 bytes hash와 PDF의 subset font program hash는 같다고 가정하지 않는다. 공급한 ID/PS/style/hash와 준비 증거를 출력 resource·glyph/텍스트 결과에 연결하고, 한글 mapping과 ASCII encoding/subset의 검증 경계를 각각 기록한다.

### 2.4 출력 WebView와 시험 범위

별도 nonpersistent WKWebView, content JS 비활성, 앱의 `.defaultClient` 준비 script, exact 초기 navigation과 외부 resource 차단을 유지한다. CSP에는 필요한 font scheme만 허용한다. 문서 SVG의 script/event handler·외부 URL·중첩 frame·CSS resource가 새 공급 route를 확장하지 못하게 검증한다.

합성 문서·허가된 테스트 글꼴·private store와 `build.noindex/task568/`를 사용한다. 이전 #567 창·사용자 문서/원본 글꼴/설치본은 변경하지 않는다. 실제 폴더 접근·로컬 인증서 사용·설치 smoke·물리 프린터 전송은 대상 앱과 조작이 구체화된 시점에 기존 승인 범위와 새 승인 필요 여부를 확인한다.

## 3. Stage 1 — 출력 계약 조사와 최소 실험

### 작업·산출물

1. 현재 PDF/인쇄 collection·save lock·document revision·렌더 timeout·completion을 비교하고, B의 기존 CoreText/Skia/확장 공급·캐시 위치를 소비자 표로 정리한다.
2. pinned source의 SVG family/style, layer-tree textRun/charOverlap, host matcher 선택과 window API/worker 경계를 확인한다. 실제 요청 스타일과 선택 ID를 portable SVG 출력에 연결하는 후보를 하나로 좁힌다.
3. 기존 Noto 제품 기준선과 승인된 고운바탕 Regular/Bold의 제한된 custom 공급 후보를 같은 합성 SVG에서 비교한다. 한국어와 ASCII, serif/sans·수식, family/fullName/PS 요청을 분리한다. 기존 NanumSquare는 현재 활성 상태를 확인한 뒤 설치 경로 대조군으로만 사용한다.
4. private prototype로 face 준비 완료·실패·정확한 PS/임베딩·ToUnicode·추출·검색·geometry를 확인한다. prototype의 CSS/handler 변경은 제품 연결 성공으로 표시하지 않는다. 전체 목록 bytes 선읽기 대신 실제 필요한 읽기 수와 유지 bytes를 기록한다.
5. 문서/글꼴 변경·로드 실패·충돌·기술적 임베딩 제한·unknown/restricted의 정책, 전체 face/bytes 한도와 인쇄 패널/취소 경계를 확정한다. 근거 부족 항목은 미결정 및 다음 단계 선행 조건으로 남긴다.

추가/변경 가능한 산출물은 `mydocs/tech/task_m020_568_output_contract.md`, `mydocs/working/task_m020_568_stage1.md`와 필요한 재현용 probe뿐이다. 재사용 가능한 probe를 저장소에 둘 경우 `Tests/StudioOutputFontProbe/`·`scripts/probe-studio-output-fonts.py`에 범위와 실행 전제를 기록한다. 일회성 복사본·font bytes·PDF·raw 사용자 위치는 커밋하지 않는다. 제품 renderer·core pin·Studio bundle·등록 정책은 변경하지 않는다.

### 통과 기준·검증

- 선택 source/ID/PS/style/hash와 출력 결과를 연결한 대조표, 지원/실패/미검증 행, 채택할 공급·매칭·변경 정책과 한도가 있다.
- 실제 custom face의 PDF 결과와 Noto 기준선의 검색·복사·시각 회귀가 분리되어 있으며, 불가능한 조건은 다음 구현 단계 진입 전에 보고한다. Stage 1은 custom 본문 exact 추출 성공과 Noto 대조군의 공백→`#` 결함을 각각 기록했다. 후자를 제품 성공으로 합산하지 않는다.
- 다음 명령은 실제 생성한 합성 출력에만 적용한다. tool 부재는 기록하고 Swift/PDFKit 결과로 가능한 범위를 구분한다. production runtime에 CLI 의존을 추가하지 않는다.

```bash
scripts/verify-rhwp-studio-assets.sh --upstream-dir build.noindex/task567/stage3-2/upstream-v087 --tag v0.8.7 --commit 1a76570e833917d15817415a53c09ad61ab3203f
pdfinfo build.noindex/task568/stage1/run-09/custom/sample.pdf
pdffonts build.noindex/task568/stage1/run-09/custom/sample.pdf
pdftotext -layout build.noindex/task568/stage1/run-09/custom/sample.pdf build.noindex/task568/stage1/run-09/custom/text.txt
```

commit: `Task #568 Stage 1: 출력 글꼴 계약과 PDF 최소 실험`

## 4. Stage 2 — A 출력 공급·준비·수명 구현

### 변경 범위

- HostApp 출력 전용 snapshot/선택 metadata·lease owner·검증 bytes와 작업 token/ID route를 구현한다. 새 helper 이름은 `RhwpStudioOutputFontSnapshot/Provider` 등을 후보로 두고 Stage 1 확정 계약에 맞춘다. 화면 `StudioFontSession`을 출력에 그대로 재사용해 navigation reset과 출력 수명을 섞지 않는다.
- `RhwpStudioPagePayload`, `RhwpStudioPDFFontProvider`, `RhwpStudioPagePDFRenderer`에서 좁은 공급·custom/Noto 매핑·font 준비 실패·취소와 최종 정리 경계를 연결한다. 공급 없는 기존 호출의 fallback을 보존한다.
- Stage 1이 source adapter를 요구하면 앱 빌드 adapter만 확장한다. 공식 checkout은 변경하지 않고, typecheck·manifest·receipt와 기존 메뉴/환경설정 회귀를 함께 검증한다.
- Stage 1의 narrow resolver 결론을 적용한다. `scripts/studio-font-menu-adapter.mjs`와 `scripts/build-rhwp-studio.mjs`의 transformed source/receipt를 갱신하며 `local-fonts.ts`/main surface를 통해 공식 matcher의 선택 ID·revision/generation만 반환한다. stage별 test double과 실제 진입 연결은 구분한다.
- Noto 대조군의 텍스트 매핑 문제를 같은 준비/출력 경계에서 조사·보완한다. custom 성공만으로 전체 fallback 복사가 정상이라고 주장하지 않는다. 기존 정확한 face·레이아웃·한글/ASCII·수식과 text layer를 함께 검사하며 수정에 다른 core/API 범위가 필요하면 해당 부분을 별도 승인 대상으로 보고한다.
- `Tests/HostAppTests`, `Tests/FontLibraryTests`와 `project.yml`에 필요한 공급/수명 회귀를 등록한다. 현재 CI는 HostAppTests의 Spotlight 검사만 직접 실행하므로 `.github/workflows/pr-ci.yml`에 영향받은 PDF/출력/인쇄 검사가 실제 실행되도록 반영한다.

### 통과 기준

정상 exact face·지원 불가/충돌·변경/취소·잘못된 token/ID/URL·stale/busy·부분 읽기 실패·늦은 callback·과대 입력/bytes·두 slot과 lease 회귀가 통과한다. 문서 script·외부 font/image·frame/navigation 차단, Noto 한글/공백/ASCII 매핑, page geometry·30초 timeout·exactly-once completion과 재진입을 검증한다. Noto 결함이 해결되지 않으면 그 경계를 미완료로 표시하고 Stage 3 진입 조건을 보정한다. 마지막 정리 전 slot/lease를 조기 해제하거나 기존 목적지를 먼저 삭제하지 않는다.

공통 A 검증 명령은 9절을 적용한다. commit: `Task #568 Stage 2: 출력 글꼴 snapshot과 제한 공급 구현`

## 5. Stage 3 — A PDF·인쇄 연결과 실제 수용

`RhwpStudioWebView.Coordinator`, host/save bridge, PDF export controller와 print controller/lifecycle의 실제 진입에서 작업 identity·선택·최종 검증·취소를 연결한다. HWP/HWPX의 현재 편집 본문·Regular/Bold·원래 family를 유지하고 source/dirty 상태를 바꾸지 않는다.

합성 입력으로 설치 참조·관리 복사본·공급 없는 Noto 대조군을 각각 검증한다. 원본 상실·관리 선택/제거·사용 설정·문서 교체·WebContent 실패·패널 취소·쓰기 실패·재출력을 포함한다. 실제 PDF 저장과 인쇄 패널/미리보기/취소, test callback 주입과 실제 spool을 구분한다. 서명 sandbox·정상 권한 새 프로세스는 준비된 고유 앱/컨테이너에서 수행하고 필요한 인증서/폴더 접근 범위를 제시한다.

Stage 2의 Noto 본문 공백·구두점 결함은 보정됐다. 기본 시스템 영문 header의 PDFKit 반복 글자 누락은 남아 있으며 Poppler에서는 정상이다. 실제 문서·선택 face/reader의 재현과 지원/제약 판정을 Stage 3에 포함하고 전체 페이지 exact 성공으로 합산하지 않는다.

### 통과 기준

- PDF의 선택된 PS/style·임베딩·ToUnicode, 한글/ASCII 추출·검색·영역 선택·복사, page count/bounds와 주요 글자·표·수식의 시각 결과가 맞는다. `CGPDFFontResourceInspector`는 현재 BaseFont/Subtype/ToUnicode만 제공하므로 font program 임베딩·하위 font dictionary 확인이 필요한 부분은 helper를 보강한다.
- PDF 내보내기·인쇄는 각각 변경/실패/취소/완료 상태와 작업 수명을 검증한다. 화면 또는 PDF 성공만으로 인쇄 성공을 대신하지 않는다.
- 준비/메뉴의 추가 전체 bytes 읽기 0, 고유 face별 읽기·반복 출력·동시 작업·한도 수치를 실제 범위로 기록한다. 모든 재출력이 영구 bytes cache를 사용하는 설계는 하지 않는다.
- 새 출력·패널은 스크린샷과 직접 조작 가능한 격리 창/실행 방법을 제공한다. A의 지원 안내만 수정하며 B·Windows·미확보 환경은 미완료로 유지한다.

산출물: `mydocs/working/task_m020_568_stage3.md`와 A 수용 증거·실행 안내. 공통 A 검증 및 실제 문서 lifecycle smoke를 실행한다. commit: `Task #568 Stage 3: PDF와 인쇄의 실제 글꼴 연결 수용`

## 6. Stage 4 — B CoreGraphics·Skia 연결

A 보고 이후 B의 구체 변경과 API·권한·테스트 자산을 재확인해 승인받는다. `FontFallback`, `CGTreeRenderer`, `FontResourceRegistry`, Shared preview helpers와 RustBridge의 `font_paths: Vec::new()` 경계를 조사·보강한다. 기존 custom/system/bundled 우선순위와 정확한 PS/style·identity를 유지하고 renderer cache key에 소비자 snapshot identity를 반영한다. 전역 OS 등록이나 전체 system 폴더의 custom path 주입으로 대체하지 않는다.

2026-10-09 진입 승인 후 임시 빌드/캐시 정리와 direct CoreText bytes 실험을 완료했다. [native 연결 조사·확장안](../tech/task_m020_568_native_contract.md)에 현재 경계, Skia family당 한 face 저장 제약, 새 bytes 기반 C ABI 후보 및 한도·수명·검증 범위를 정리했다. 이어 작업지시자가 새 C ABI/연관 wrapper/header/symbol 범위를 승인했다. public glyph replay 후보는 격리 검증 후 채택/추가 필요사항을 판단하며 정확한 스타일을 지원하지 못하면 성공으로 처리하지 않는다.

Stage 4.1에서 새 C ABI/Swift context와 public FontResolver 기반의 제한된 native 어댑터를 구현했다. 실제 HWP/HWPX에서 Regular/Bold·동일 face의 한국어/ASCII 혼합이 Skia/CG로 통과했다. 이어 Stage 4.2에서 공식 matcher의 pinned JavaScriptCore bundle·core의 slot 조회와 실제 설치/관리 snapshot·lease/budget 공급을 공통 native 진입점에 연결했다. 충돌·원본/세대/문서 변화·취소·cache identity와 glyph를 바꾼 동일 PS 원본 교체를 수용했다. metadata snapshot의 불필요한 전체 원본 판독도 제거했다. [Stage 4 보고서](../working/task_m020_568_stage4.md)의 실제 service/주입 시험 및 형식·캐시 경계를 따른다. core source/릴리즈 pin은 유지했으며 확장 프로세스 연결과 signed Finder 수용은 Stage 5에 남아 있다.

필요한 공통 DTO/수명은 AppKit 없는 계층에 둔다. 새 FFI/API가 필요하면 Stage 4 구현 전에 승인 범위를 보정하고 포인터/길이/문자열/handle 수명을 검증한다. 추가 upstream 릴리즈가 꼭 필요한 조건과 앱 bridge에서 처리 가능한 조건을 분리한다.

통과 기준: native CoreGraphics/Skia 각각의 실제 face/style/hash·대체·동명 충돌·설정/원본 변화·snapshot 캐시 결과, 기존 render tree/glyph/clip/image 회귀와 메모리 제한. 형식/축을 검증하지 않은 TTC·가변 지원을 추가하지 않는다.

검증: `scripts/check-no-appkit.sh`, `scripts/validate-stage3-render.sh build.noindex/task568/stage4/render`, 대표 문제 입력의 `scripts/render-debug-compare.sh`, core/FFI 변경 시 `scripts/build-rust-macos.sh --verify-portable`·golden/source/header/symbol 검사. 동일 기준 산출물의 strict 검증은 환경을 맞춰 수행하며 실패를 lock 갱신으로 숨기지 않는다.

산출물: `mydocs/working/task_m020_568_stage4.md`. commit: `Task #568 Stage 4: native renderer의 정확한 글꼴 공급 연결`

## 7. Stage 5 — B Quick Look·Thumbnail signed 수용

2026-10-09 소스 연결·unsigned 격리 수용을 완료하고 [구체 Finder 계약](../tech/task_m020_568_finder_contract.md)을 작성했다. 이어 2026-10-10 승인된 signed Finder 수용·읽기 전용 보정·기존 앱 복원을 완료했다. [Stage 5 보고서](../working/task_m020_568_stage5.md)의 실제 소비자별 결과와 OS cache/최소 환경 경계를 따른다. 이후 작업지시자가 Stage 6 진행을 승인했다.

`Sources/QLExtension`, `Sources/ThumbnailExtension`, Shared font location/snapshot·preview helpers를 연결한다. 각 프로세스가 권한을 실제로 얻었는지 검증하며 HostApp bookmark나 App Group 파일 존재를 원본 접근 성공으로 대신하지 않는다. 설치 참조와 관리 복사본·lease/회수·원본 변화·fallback·자원 제한·Finder 캐시를 소비자별로 기록한다.

2026-10-10 승인된 signed 시험에서 두 확장의 App Group 쓰기 거부를 발견해 설정/관리 목록을 읽기 전용으로 보정했다. 디스크 lease를 생성하지 않고 실제 읽기 동안 shared flock으로 writer/GC를 막고, 세대/선택/hash를 재검증한다. 원본 변경 시 stale로 폐기하며 HostApp의 기존 디스크 lease는 유지한다. 권한 확대·새 ABI·전역 reset은 추가하지 않았다. 같은 승인 범위에서 보정 후보를 재검증하고 원래 설치본을 복원했다.

`scripts/check-extension-registration-hygiene.sh --check-only`를 먼저 실행한다. 표준 smoke helper가 실제 설치 경로를 교체하고 등록/캐시를 바꾼다는 점을 반영해 signed/sealed 앱, 기존 설치본 보존/복원·소유 등록 해제 범위를 준비한 뒤 해당 구체 smoke를 승인받는다. 무단 설치본 교체·전역 reset·다른 작업의 앱 등록 해제는 하지 않는다. A 작업 중에는 확장을 등록하지 않는다.

통과 기준: Quick Look·Thumbnail 각각의 정확한 PS/style 선택·재실행·접근 실패·설치/관리 변화·Finder 캐시 반영, 소비자별 제한과 종료 정리. 최소 OS/Intel 실제 실행 등 미확보 조건은 명시한다.

산출물: `mydocs/working/task_m020_568_stage5.md`. commit: `Task #568 Stage 5: Quick Look과 Thumbnail 글꼴 공급 수용`

## 8. Stage 6 — 소비자별 회귀·최종 인계

최종 소스/빌드·선택·PDF/native/Finder 증거 hash를 대조하고 실제 실행·재사용 근거·미검증 환경을 구분한다. `font_library_integration.md`, 필요한 architecture/사용 안내와 설정 지원 문구를 검증된 소비자 범위로 보정한다. Windows 입력은 #566 이후 별도 수용, 전체 사용자 시나리오와 웹 안내는 #569로 인계한다.

수용 표는 Studio·PDF·인쇄·CoreGraphics·Skia·Quick Look·Thumbnail, 설치/관리·Mac/Windows를 구분한다. 실패·미연결 소비자가 남으면 #568 전체 완료로 표시하지 않고 계획/이슈 완료 경계를 다시 검토한다. 최소 OS 실행·서명 App Group·실제 물리 인쇄·한컴 제거와 prototype/mock 결과를 구분한다.

산출물: `mydocs/working/task_m020_568_stage6.md`와 소비자 인계 문서. 변경된 범위의 관련 회귀를 수행하고 새 변경 없이 통과한 무관한 대규모 빌드를 반복하지 않는다. commit: `Task #568 Stage 6: 출력 소비자별 검증 정리와 인계`

## 9. 공통 검증·보고·승인

문서 작성 단계에서는 형식·링크·승인 범위·`git diff --check`만 검사한다. 아래 제품 검증은 해당 Stage 구현 후 실행할 명령이며 현재 통과했다고 주장하지 않는다. 재생성 Xcode project는 `project.yml`로만 변경한다.

```bash
xcodegen generate
scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
scripts/test-font-library.sh
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task568/host CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -destination 'platform=macOS' -derivedDataPath build.noindex/task568/tests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing
xcrun xctest build.noindex/task568/tests/Build/Products/Debug/HostAppTests.xctest
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/re-font-dotum-empty-hancom.hwp
```

HostApp Debug의 macOS 12 target compile/link와 실제 최소 OS runtime은 별도로 기록한다. source adapter가 바뀌면 공식 checkout typecheck/receipt와 JS·기존 메뉴/환경설정 probe를 추가하고 실제 결과를 보존한다.

각 Stage 종료 시 `mydocs/working/task_m020_568_stage{N}.md`에 실제 명령·환경·입력 provenance·선택/준비/출력·hash·실패/제약을 기록해 해당 변경과 묶어 commit한다. 다음 단계는 작업지시자 승인 후 진행한다. 최종 보고/원격 push/PR은 10절의 최신 승인 범위를 따르며 merge·issue close·정리는 별도 승인 시점이다.

## 10. 현재 승인 범위

2026-10-10 PR #579의 macOS 15.7.9 PDF 텍스트 검사 실패 보고 후 작업지시자의 “진행해줘”로 원인 조사·필요한 PDF/시험 fixture 보정·회귀·동일 PR 반영을 승인받았다. 실제 합성 PDF/reader 대조로 원인을 구분하고 문자 보존/외부 차단 기준을 유지한다. core pin·새 기능/ABI 확대·설치 시험·merge/배포는 추가하지 않는다.

2026-10-10 Stage 6 완료 보고 후 작업지시자의 “진행해줘”로 최종 보고·오늘할일 완료 처리·`publish/task568` 원격 push·`devel` Open PR 게시를 승인받았다. merge/이슈 close·후속 구현·upstream 공개 기여·제품/웹 배포는 포함하지 않는다.

2026-10-10 Stage 5 완료 보고 후 작업지시자의 “진행해줘”로 Stage 6의 소비자별 회귀·지원 범위 보정·소스/증거 hash 대조·#566/#569 인계를 승인받았다. 공개 이슈 변경·upstream 기여 게시·최종 보고/원격 push/PR·제품/웹 배포는 별도 단계다.

2026-10-10 작업지시자가 준비된 Stage 5 후보/fixture의 기존 Developer ID 로컬 서명, 고유 보관함, `/Applications/Alhangeul.app` 보존·임시 교체·표준 Finder 시험·복원을 명시 승인했다. [Finder 계약](../tech/task_m020_568_finder_contract.md)의 해당 UUID와 앱만 대상으로 하며 전역 reset·다른 앱 등록 변경·공개 배포는 제외한다.

2026-10-09 작업지시자의 “진행해줘”로 Stage 5 공통 서비스·App Group 설정 공유, 확장 자체 권한의 원본 읽기, preview/thumbnail 연결·캐시 갱신과 격리 검증 준비를 승인받았다. HostApp bookmark는 공유하지 않는다. 구체 인증서 서명·기존 설치본 교체·Finder 등록은 산출물/보존/복원 절차를 준비한 후 승인받으며 현재 실행하지 않는다.

Stage 4와 [native 연결안](../tech/task_m020_568_native_contract.md)의 **앱 소유 bytes 기반 C ABI 설계·격리 검증 및 Swift wrapper/header/symbol 변경**이 승인됐다. core v0.8.7과 기존 ABI는 유지한다. exact Skia가 검증되지 않으면 완료로 처리하지 않고 추가 API/선행 조건을 보고한다. 완성된 검증에서 upstream에 도움되는 부분만 분리하는 방향에 동의했으며 공개 이슈/PR 게시는 별도 범위다. Stage 4 승인 당시에는 Stage 5의 Finder 설치/등록·새 인증서/폴더 권한·물리 프린터 전송·push/PR·공개 배포를 제외했다. 위 2026-10-10 승인으로 구체 Stage 5 로컬 서명·설치 시험만 추가했으며 나머지 제외 범위는 유지한다.
