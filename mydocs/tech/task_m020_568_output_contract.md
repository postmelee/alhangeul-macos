# Task M020 #568 — 출력 소비자의 글꼴 계약

- 기준: 제품 `db8a94d1eb03f5a14f265621191f85f0ddf149cb`, 공식 core/Studio v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`.
- 근거: [구현계획](../plans/task_m020_568_impl.md), [Stage 1 실험](../working/task_m020_568_stage1.md), [#567 인계](font_library_integration.md).
- 상태: 2026-10-09 [Stage 3](../working/task_m020_568_stage3.md)의 실제 editor PDF·인쇄 연결과 로컬 서명 sandbox·패널 취소 수용 완료. native·Finder 연결은 Stage 4–5 승인 후 진행한다.

## 1. 소비자 경계와 현재 결함

| 소비자 | 현재 구현 | 이 계약의 후속 작업 |
|--------|-----------|--------------------|
| Studio 화면 | 공유 설치/관리 catalog, 공식 host provider와 matcher | 기존 선택 정책 재사용; 출력 수명은 독립 |
| HostApp PDF | 공유 설치/관리 snapshot·공식 matcher·별도 WebView, 저장 직전 문서/글꼴 검사·atomic write 연결 | 실제 한컴/최소 OS·다양한 문서 수용은 #569 |
| HostApp 인쇄 | 같은 공급/collection lock·immutable PDF seal·실제 `NSPrintOperation` 연결, 패널 취소 수용 | 물리 spool/종이 출력은 별도 승인·미검증 |
| CoreGraphics | `CGTreeRenderer` → `resolveAppleFont`, bundled font의 process 등록·정적 이름 정책 | 관리/설치 exact 공급, glyph·equation 등 별도 경로와 cache key 검증 |
| Skia | `RustBridge` PNG 출력의 `font_paths: Vec::new()` | bytes/선택과 bridge 수명 조사. 전체 시스템 폴더 주입으로 대체하지 않음 |
| Quick Look | `HwpPreviewProvider` → Shared PDF/PNG renderer | 프로세스별 접근·snapshot·선택과 Finder 수용 |
| Thumbnail | `HwpThumbnailProvider` → `HwpThumbnailRenderCache` | cache identity에 font snapshot 결합, 별도 sandbox/Finder 수용 |

PDF의 기존 준비 script는 한글을 포함한 미분류 SVG text에 Noto family를 앞세운다. 실제 FontFace를 추가해도 이 처리에 덮인다. Stage 1의 `naive`는 고운바탕이 ASCII MacRoman subset으로 포함되었지만 한글 subset은 Noto였다. 검색 성공·FontFace loaded·PS 존재만으로 모든 대상 글자에 정확한 face가 적용됐다고 판정할 수 없다.

Stage 1에서 기존 Noto 대조군의 공백은 `#`로 추출됐다. Stage 2는 한글과 원래 fallback 문자의 run을 나눠 Noto 본문·공백·구두점·수식 회귀를 보정했다. custom/대조 본문 exact와 기본 시스템 영문 header의 PDFKit 반복 글자 누락을 구분한다. 후자는 남아 있고 Poppler에서는 정상이며 Stage 3 실제 reader 수용에 포함한다. 전체 페이지 exact로 확대하거나 OCR·bitmap·숨긴 중복 텍스트로 대체하지 않는다.

## 2. 공식 matcher를 재사용하는 앱 adapter

공식 `local-fonts.ts`의 `resolveRendererLocalFont`는 다음 우선순위를 갖는다.

1. 유일한 exact PostScript 이름: run style과 별개로 해당 face.
2. family와 다른 유일한 exact fullName/`family style`: 해당 face.
3. family/alias: 동일 weight·slant의 유일한 face. italic/oblique는 exact가 없을 때 상대 slant만 확인.
4. 누락·동명 모호성·지원하지 않는 style: `null`.

`loadRendererLocalFont`는 선택한 `hostReference`를 직접 소비한다. `collectHostFontRequests`는 group/clipRect의 `textRun`·`charOverlap`을 모으며 bold는 700, 그 외는 400이다. Stage 1의 실제 원본 module 검사 10개와 collection·in-flight·stale 검사가 통과했다. 한글 alias는 실제 TTF name table에 없어 fixture에 추가한 alias이며, 원본에 지역화 이름이 있다고 주장하지 않는다.

이 함수들은 TS module export이며 현재 `window.rhwpStudio.fonts` 공개 surface는 `setProvider/getState`다. getState의 count로 선택 ID를 얻을 수 없다. 추가 upstream release를 기다리기보다 기존 앱 소유 빌드 adapter에 **출력 요청 → 공식 matcher → 선택 ID/revision/generation**의 좁은 함수를 추가한다. matcher를 Swift에 복제하거나 minified 자산을 수정하지 않는다. 원본 checkout은 그대로 두고 transformed source typecheck·source/adapter receipt·bundle manifest/hash를 갱신한다.

출력 요청은 출력 WebView의 앱 준비 script가 읽은 실제 SVG text/tspan의 family/style과 node identity를 사용한다. layer tree collection은 화면의 대조 근거이며, chart label·equation·faux-bold 등 모든 SVG text를 다룬다는 보증으로 사용하지 않는다. Stage 2에서 adapter와 준비 callback을 연결해 페이지 token·node mapping을 확인하고, Stage 3 실제 HWP/HWPX에서 화면 선택과 대조한다.

원본 SVG는 family 체인·`bold/500/italic`·stroke 효과를 내보낼 수 있다. Regular/Bold의 표준 400/700은 우선 지원한다. Stage 3의 `getOutputPageSvg` adapter는 같은 portable metrics transaction에서 얻은 SVG와 schema 1.23 layer tree를 대조한다. 일반 가로 본문에서 Bold=true, 좌표·크기·색·family·본문이 유일하게 일치하고 core의 0.02em faux stroke임을 입증한 경우에만 700으로 보정하고 해당 stroke를 제거한다. 사용자 공급이 없는 Noto Bold에도 같은 보정을 적용해 PDFKit 반복 문자 추출을 방지한다. 화면 renderer의 결과와 원본 문서는 바꾸지 않는다.

외곽선/그림자/회전/첨자/장평·겹침·모호한 중복은 임의 보정하지 않는다. 500·그 외 faux-bold·slant 또는 glyph resource를 근거 없이 400/700으로 반올림해 exact 성공으로 표시하지 않는다. 명시 Regular PS가 700 요청에 선택돼도 400으로 조용히 출력하지 않으며 미지원 안내/명시 대체로 처리한다. 명시 PS/fullName이 선택한 face와 요청 효과도 별도로 기록한다. 지원하지 않는 사용자 face의 출력은 5절 정책으로 처리한다.

## 3. 출력 작업 identity와 상태

작업은 다음 값을 native에서 소유한다.

- opaque request ID와 작업 token, editor loadToken·documentEpoch·changeSeq/revision.
- 설치 generation와 활성 설정, 관리 generation/digest·선택 정책, 해당 관리 snapshot lease.
- matcher 세대와 revision, 요청 family/style·페이지/node → 선택 source/ID.
- 동일 읽기에서 검증된 `FontFaceID`, PS·weight/slant·SFNT index·원본 SHA-256, 기술적 임베딩 선언과 보존된 사용 근거.
- 작업 안에서 유지하는 bytes·허용 route·실패/명시 fallback 목록. raw path/bookmark는 native 밖으로 보내지 않음.

상태는 `collecting → resolving/reading → preparing/rendering → sealed → published/finished`이며 실패/취소로도 종료한다. preparing 이전과 각 async 응답 뒤에 문서·catalog 세대를 확인한다. 일부 페이지/face가 준비된 상태에서 다른 세대의 자산을 섞지 않는다. 변경된 작업은 폐기하고 새 요청으로 다시 시작한다.

관리 lease는 작업 종료까지 유지한다. 설치 원본은 lease로 파일을 고정했다고 취급하지 않으며 필요한 읽기마다 현재 상태와 동일 bytes를 검사한다. 읽은 bytes는 작업 내부의 immutable 보유 값으로만 재사용하고 다음 출력에 영구 cache로 넘기지 않는다. 취소해도 진행 중 I/O가 반환하기 전에는 동시 slot을 해제하지 않는다. 늦은 결과는 폐기하고 completion·lease 해제·route 만료는 exactly once다.

### PDF 저장

목적지 선택 뒤 최신 문서에서 기존 save bridge lock을 잡아 SVG와 선택을 수집한다. 마지막 페이지 완료 뒤, atomic write 직전에 document lock과 글꼴 설정/선택/세대·출력 policy를 다시 검증한다. 변경/취소/준비 실패는 기존 목적지를 보존하고 partial PDF를 게시하지 않는다.

### 인쇄

현재 print payload의 파일명·SVG만으로 문서 identity를 검증하지 않는다. 같은 collection lock과 face 계약으로 모든 페이지의 PDF를 만든 뒤, **패널을 열기 직전** 문서·글꼴 상태를 검사하고 immutable PDF를 seal한다. 이 시점에 collection lock을 풀어도 패널에는 그 PDF만 사용한다.

seal 후 사용자 편집·설치/관리 상태 변경은 이미 만들어진 PDF의 내용을 교체하지 않는다. 패널이 보여주는 시점의 출력이라는 계약이다. 패널을 자동 종료하거나 spool된 출력물을 회수할 수 있다고 약속하지 않는다. 새 작업은 새 snapshot으로 시작한다. lease/bytes는 패널 종료까지 유지하고 그 뒤 해제한다.

Apple SDK의 `NSPrintOperation.run()`은 성공이면 true, 오류 또는 사용자 취소면 false다. false만으로 두 원인을 분리할 수 없으므로 별도 관측 근거 없이는 `cancelledOrFailed`로 기록하고 완료 성공으로 합산하지 않는다. 렌더/operation 생성 오류, 패널 취소 수용, 실제 spool/종이 출력은 각각 분리한다. [Apple API](https://developer.apple.com/documentation/appkit/nsprintoperation)와 로컬 SDK `NSPrintOperation.h`를 근거로 한다.

## 4. 공급 route·준비·초기 한도

내장 `alhangeul-pdf-font://bundle/<Noto 4종>`의 exact route를 유지한다. 사용자 route는 `alhangeul-pdf-font://snapshot/<opaque job token>/<allowlisted opaque face ID>`만 허용한다. 다른 token·만료 job·미허용 ID·query/fragment/user/password/port·이중 decode/path 이탈·임의 filename/외부 URL을 거부한다. task stop/완료 후 해당 route는 만료된다.

사용자 FontFace는 작업 내부 CSS alias를 쓴다. PS/name table·문서에 저장된 family·원본 bytes는 바꾸지 않는다. custom font 준비를 앱이 확정한 node만 Noto 보정에서 제외한다. 문서의 `data-*`·CSS class·가짜 내부 alias를 신뢰하지 않으며, tspan 상속/혼합 스타일과 page token도 검증한다. 공급 대상이 아닌 text는 기존 fallback을 유지한다.

출력은 nonpersistent store, content JS false, 앱 `.defaultClient` script, 초기 about:blank navigation만 허용, 기존 CSP/font scheme·외부 resource 차단을 유지한다. `document.fonts.ready/load/check`, 선택 alias/실제 face loaded 상태, PS/스타일·PDF program·한글 ToUnicode와 실제 추출을 함께 검사한다.

| 대상 | Stage 2 초기 구현 한도 | 판단 근거 |
|------|-----------------------|-----------|
| 고유 사용자 face/job | 64 | metadata 전체 열거와 출력에 필요한 subset을 분리 |
| 고유 요청 family/style/job | 2,048 | 글자별 중복을 합침; 요청 폭증 시 명시 실패 |
| 이름·ID·alias | 기존 최대 1,024 / alias 32 | 공식 provider와 #567 DTO의 기존 검증 유지 |
| 개별 bytes | 64 MiB | 기존 inspector/provider 한도 유지 |
| native 유지 사용자 bytes/job | 128 MiB | 측정된 두 face 16,612,008 bytes 수용, 무제한 유지 방지 |
| 읽기 동시 slot | 화면+출력 합계 2 | `StudioFontTransferBudget.shared` 재사용 |

bytes budget은 예약과 검증된 실제 크기를 모두 계산하고 초과면 게시하지 않는다. 한도 초과를 자동 시스템 교체나 끝없는 queue로 숨기지 않는다. 이 값은 **초기 구현 제한**이며 2종의 실측으로 전체 프로세스 최대 메모리·최소 OS 성능을 검증했다고 주장하지 않는다. Swift inspector의 임시 배열·WebKit/FontFace/PDFKit 복제 메모리는 별도 측정해야 한다.

## 5. 임베딩 선언·사용 근거·실패 정책

`FontUsageEvidence.embedding`의 `unknown/allowed/restricted`는 별도 기록이다. 이를 fsType에서 만들어 넣지 않는다. 설치 metadata 접근 성공도 임베딩 허가가 아니다. 새 사용 근거 수집/라이선스 승인 UI를 이 기능의 정상 흐름에 추가하지 않는다.

Stage 2의 기술적 출력 자격은 **검증된 OS/2 선언**을 사용한다. 명시 `restricted` 사용 근거는 우선 차단한다. `unknown`은 그대로 남으며, 읽은 font의 유효한 fsType 선언이 기술적으로 허용하는 출력만 후보로 둔다. 이 후보를 라이선스 검증 완료나 `usageEvidence.allowed`로 설명하지 않는다. 사용 근거가 `allowed`여도 기술적 금지를 우회하지 않는다.

OpenType 명세에서 permissions 0/4/8과 restricted 2, no-subsetting 0x0100, bitmap-only 0x0200은 서로 다른 조건이다. 버전에 따른 해석도 다르다. 이 계약은 명세를 재정의하지 않고, subset을 생성하는 현재 경로에서 아래 범위만 지원한다. [Microsoft OS/2 fsType 명세](https://learn.microsoft.com/en-us/typography/opentype/spec/os2#fstype).

| 조건 | 처리 |
|------|------|
| 유효한 단독 permissions 0/4/8, 허용 형식·선택, 명시 금지 없음 | PDF·인쇄의 기술적 후보; 원본 선언과 evidence 그대로 보존 |
| restricted 2 또는 명시 사용 근거 restricted | exact embed 차단 |
| no-subsetting (해당 bit가 정의된 version), bitmap-only | 현재 subset/outline 경로에서 미지원; WebKit이 무시하게 두지 않음 |
| 오래된 table의 다중 permissions·예약값·해석할 수 없는 선언 | 초기 exact 지원 미확인으로 차단; 모든 legacy font가 invalid라는 의미 아님 |
| TTC·가변 축·선택/identity 검증 실패 | 소비자 미지원/실패 |

`FontFileInspector`는 OS/2 version을 읽고 검사하지만 `FontFace`에는 version을 보존하지 않는다. 출력 policy helper는 **이미 검증해 읽은 동일 bytes**에서 version을 얻어 기술적 해석에 사용해야 한다. persisted manifest를 바꾸거나 없는 선언을 0으로 채우지 않는다. version 0/1에서 상위 bit가 정의되지 않은 점도 검증한다.

없는 family의 기존 fallback과 “존재했지만 공급/임베딩/충돌/한도 때문에 못 쓰는 face”를 구분한다. 후자는 어떤 글꼴이 대체되는지 보여주고 **취소를 기본값, 대체 출력은 명시 선택**으로 둔다. 새 라이선스 확인 checkbox는 만들지 않는다. 선택은 해당 작업과 최신 identity에만 적용한다. 로드 실패를 exact 성공으로 처리하지 않으며 원본 문서·사용 설정도 바꾸지 않는다.

## 6. 실험 증거와 다음 단계의 종료 조건

고운바탕의 두 원본은 OFL/provenance·SHA-256·PS·weight 400/700·fsType 0을 확인했다. 새 프로세스의 CoreText 목록에 두 PS는 없고 NanumSquareR/B는 있었다. Stage 1 원본 metadata/receipt와 대조해 이 문장의 오기를 Stage 2에서 보정했다. 영구 설치와 실제 설치 참조 bytes 공급을 시험한 결과가 아니다.

custom PDF는 두 face 모두 `/FontFile2` program이 있으며 한글 subset은 `/ToUnicode`, ASCII subset은 MacRoman encoding을 사용했다. input hash와 subset hash는 다르다. PDFKit 문자열·선택·한글 검색 5건과 Poppler의 custom 본문 exact 추출을 확인했고, 794×1123 pt 한 페이지의 PNG를 눈으로 검토했다.

위 Stage 1 결과는 합성 SVG·native 비-sandbox prototype의 이력이다. Stage 3은 실제 HWP/HWPX의 편집 본문으로 설치 NanumSquareR/B·관리 고운바탕·공급 없는 Noto를 각각 PDF 저장 및 인쇄용 PDF에서 검증했다. 실제 bytes 반환 직후 취소와 private 관리 자산 제거/stale/복원·재출력을 검사했다. 물리 I/O 중 취소·문서/세대 변경·임베딩 제한·FontFace 실패·쓰기 실패·seal 수명은 단위 주입 검증과 실제 수용을 구분한다. 사용자 OS 원본 삭제·WebContent 강제 종료의 전체 Coordinator 수용을 완료했다고 주장하지 않는다.

기존 인증서로 로컬 서명한 sandbox 앱의 세 경로와 실제 인쇄 패널 취소를 확인했다. managed 패널의 성공 기록은 30개 검사/18회 읽기, installed는 25개/14회, baseline은 16개/0회다. 각 정상 출력 job은 필요한 두 face를 각 1회 읽는다. 독립 pypdf/Poppler로 12 PDF의 program·한글 ToUnicode·본문을 대조했고 PDFKit 검색·선택 및 PNG 시각 검사도 통과했다. 페이지는 기존 SVG의 논리 bounds를 유지하며 물리 A4 mm 교정·물리 인쇄·최소 OS/Intel 실행은 미검증이다. Stage 2의 별도 시스템 영문 header PDFKit 추출 제약은 남는다.

B는 따로 진행한다. HostApp snapshot/bytes를 다른 프로세스의 권한으로 취급하지 않으며 RhwpCoreBridge의 AppKit/UIKit 금지를 유지한다. Stage 4 API/FFI·캐시 key 구체 승인과 Stage 5 설치본 보존/복원·표준 Finder smoke 승인이 필요하다. A 성공으로 #568 전체 close, Windows 지원 또는 Finder 지원을 선언하지 않는다.
