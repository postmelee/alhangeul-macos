# Task M020 #600 구현계획서

2026-11-08 · [승인된 수행계획](task_m020_600.md) · [이슈 #600](https://github.com/postmelee/alhangeul-macos/issues/600) · 대상 `devel`

모든 단계의 upstream 입력은 v0.9.0, `c9095c5f67632e6721e800ccc7fb43ea49d26682`다. 명령 예시에서 `UP`은 해당 태그의 깨끗한 checkout이고, `RUN`은 이번 실행만의 T7 검증 디렉터리다. `CARGO_TARGET_DIR`에는 로컬 저장 정책의 공용 target을 설정한다. RustBridge가 참조하는 target과 같은 실제 경로인지 확인한다.

## 1. 태그와 소비자 계약 확인

- `gh release view`, 원격 tag와 checkout HEAD, 공식 수정 다섯 건의 ancestor 결과를 대조한다. #8104의 `rhwpCommandErrors`와 embed 명령·이벤트, #8614의 fetch 취소·FontFace 대기 한도, #8397과 후속 HFT 윤곽·조판 전 공급을 최종 소스에서 추적한다.
- `scripts/update-rhwp-core.sh --check --channel stable --tag v0.9.0 --upstream-dir "$UP"`로 필수 API를 확인한다. 앱 어댑터의 변환 지점, matcher가 import하는 upstream 함수, Swift/Rust 수명과 native render tree 전후 요청 시점을 조사한다.
- upstream 오류 계약·웹폰트 기한 테스트를 실행한다. #598 인계서의 sample10 HWP3/HWPX·독립 PDF·글꼴 입력은 출처와 실제 해시로 확보 상태를 기록한다.
- 산출물은 태그·소스 위치·실행 결과·후속 위험을 담은 1단계 보고서다. 커밋은 `Task #600 Stage 1: 공식 태그와 소비자 호환성 확인`으로 남긴다.

## 2. 같은 태그에서 후보 생성 및 인계

1. `scripts/update-rhwp-core.sh --channel stable --tag v0.9.0 --upstream-dir "$UP"`와 `scripts/build-rust-macos.sh --update-lock`을 실행한다. 컴파일·헤더·ABI 실패가 있으면 새 API를 대조하고 기존 호출과 오류·수명 계약을 보존하는 최소 변경을 검증한다.
2. 완성된 lock에서 `scripts/update-rhwp-core-build-info.sh`를 실행한다. golden의 이전 출력과 새 producer 결과 차이를 검토하고 `scripts/update-render-tree-golden.sh`로 기록한다. build-info와 golden은 각각 verifier로 재검증한다.
3. upstream에서 `scripts/wasm-pack-locked.sh --target web --out-dir pkg`를 최적화까지 완료한다. Studio의 lock으로 `npm ci`한 뒤 앱의 `node scripts/build-rhwp-studio.mjs --upstream-dir "$UP"`로 변환 소스 typecheck와 Vite 빌드를 수행한다. 실제 WASM이 해당 커밋의 API, pkg/public과 일치하는지 확인한다.
4. `scripts/sync-rhwp-studio.sh`에 upstream-dir·tag·commit·실제 WASM 명령을 전달한다. 생산 기록에는 재현 가능한 명령을 남기고 기기 절대 경로는 커밋하지 않는다. `scripts/verify-rhwp-studio-assets.sh`에서 checkout과 bundle을 엄격히 대조한다. #594의 실험용 어댑터는 공식 빌드 입력에서 제외한다.
5. `node scripts/build-native-font-matcher.mjs --upstream-dir "$UP" --tool-dir "$RUN/matcher-tools"`로 생성한다(esbuild 0.25.12). 같은 upstream으로 `--verify`, README 배지 writer와 `--check`, portable Rust 검증, HostApp Debug 빌드와 stage3 render를 실행한다.
6. 후보 checkout, upstream HEAD, Studio Resources 실제 경로·manifest SHA256·WASM/JS 해시, matcher receipt·Frameworks 경로·universal archive/header 해시를 이 채팅에 남긴다. #594 담당자가 동일 파일을 확인하고 smoke를 시작할 수 있는 시점에 인계한다.

T7 실경로와 기존 probe의 build.noindex 경계 검사가 충돌하면 동일 커밋의 T7 실경로 검증 사본에서 실행해 경계 검사를 유지한다. 부정확한 receipt나 이전 빌드 재사용은 실패로 취급한다. 커밋은 `Task #600 Stage 2: v0.9.0 core와 Studio 및 native matcher 동기화`로 남긴다.

## 3. 글꼴 공급·재열기·최종 소비자

- `node --test`로 HFT 공급, Studio provider/bootstrap, menu/output 테스트를 실행하고 `python3 scripts/test-hft-font-supply-runner.py`로 runner 자체를 확인한다. fixture, 실제 딸기, Pretendard와 Hack 양성 대조를 서로 다른 새 출력 디렉터리에서 실행한다.
- `sample10-baseline.mjs`로 원본 HWP3/HWPX를 두 차례 열어 입력·SVG·family·page 수를 수집한다. 독립 PDF와 실제 대응 글꼴이 있으면 PS/style·실제 프로그램·glyph·글줄·쪽 배치를 대조한다.
- 고운바탕 4개 자산을 고정 해시로 확인한다. `scripts/probe-studio-font-integration.py --changes`에서 공급 세대 전환, 저장 문서의 이름과 새 프로세스 재열기를 검증한다. 설정 캡처 권한 실패는 원인을 남기고 기능만 별도 실행한다.
- native 단계의 실제 선택·측정·그리기 차이를 점검하고 PDF·인쇄 결과의 글꼴·텍스트 및 배치를 확인한다. 서명된 Finder 검증은 표준 smoke의 등록·해제 및 원복 절차를 따른다. 필요한 실물·권한·OS가 없는 항목은 NOT_RUN 사유와 재개 조건을 남긴다.
- 이전 fixture 67 PASS 및 Studio 40 PASS/재열기 6건을 대조한다. 커밋은 `Task #600 Stage 3: 글꼴 공급 및 소비자 수용 결과 기록`으로 남긴다.

### 3단계 수정계획 · 2026-11-09 승인

작업지시자는 같은 sample10 원본과 딸기 OTF로 공식 rhwp와 알한글이 처음 달라지는 지점을 확인하고 그 원인에 맞춰 수정하도록 승인했다. [3단계 결과](../working/task_m020_600_stage3.md)에 비교와 재검증을 기록한다.

먼저 같은 원본과 딸기 OTF를 사용해 공식 v0.9.0이 선택한 프로그램과 굵게 표현을 확인한다. 이를 알한글 화면·PDF·native의 같은 글줄과 비교해 차이가 처음 발생한 지점을 수정 대상으로 삼는다. 출력 기준은 공식 렌더러의 동작과 한컴 참조 PDF에서 관찰된 결과다. 특정 합성 횟수나 딸기 전용 예외를 수용 조건으로 두지 않는다.

#### 실패 재현과 확인한 경계

기준 앱은 `f4bb8b03`, 입력은 [1단계에서 해시를 확인한 sample10 두 원본과 한컴 PDF](../working/task_m020_600_stage1.md)다. 관리 라이브러리로 가져온 `HGSTRBRY.otf`는 한글명 ‘딸기’, 영문명 ‘Strawberry’, PS `Strawberry-HGSTRBRY`, 정적 CFF, face 0, weight 400, SHA256 `6844aed54084783e28e7be0da351d08f4c0fe9e16e0844cbad4e4164c47488ca`다. 지정 폴더에서 같은 가족의 Bold는 발견되지 않았다.

| 경계 | 관찰 | 수정 시 판정할 사항 |
|------|------|------------------|
| HWP3 첫 쪽 ‘창원대학교 데이타베이스 연구실’ | 원본 Bold=true, charShapeId 49. 화면·재열기에서 딸기 bytes를 읽었다. PDF와 native CG·Skia는 `딸기/700/normal`을 요청해 `unavailable`로 종료했다. | 문서 굵기, 실제 공급된 face 굵기, 적용한 그리기 효과를 각각 검증한다. HWP3의 유형 미상(altType 0)과 paint 전용 API의 false 반환만으로 원본을 HFT로 재분류하지 않는다. |
| HWPX의 같은 줄 | 원본 Bold=true, charShapeId 23. 원본 슬롯은 딸기(HFT)이고 첫 쪽을 그릴 때는 돋움으로 바뀌어 딸기 읽기가 0회였다. PDF 생성 후에도 대체 서체와 중복 추출 문자가 남았다. | 원본 슬롯을 먼저 조회하고 조판, 화면, 출력이 소비한 프로그램을 연결한다. PDF 생성 또는 검사기 종료 0만으로 통과시키지 않는다. |

동봉 WASM으로 공개 API의 적용·해제를 문서별로 확인했다. `getDocumentFontSelectionPlan`의 한글 슬롯 요청은 HWP3가 `딸기`, HWPX가 `딸기 → 돋움 → Dotum` 순이었다. 실제 OTF의 SHA와 CFF 식별자로 만든 프로그램 목록을 `buildFontEnvironmentFromAvailablePrograms`와 `setFontEnvironment`에 전달했을 때 HWPX의 첫 줄 family와 폭이 `돋움 / 360.0 → 딸기 / 377.2`로 바뀌었다. 환경을 해제하자 원래 layout 해시로 복귀했다. HWP3는 같은 절차에서 `딸기 / 377.2`와 layout 해시를 유지했다. 모두 763쪽이었다. 이 실험은 메모리에서 core의 선택을 확인한 것으로, 제품 provider의 실제 읽기와 렌더 증거는 아래 검증에서 수집한다.

#### 수정 순서와 소유 경계

1. **원본 슬롯을 host 공급에 연결한다.** Studio의 `wasm-bridge.ts`에서 `prepareDeclaredFontEnvironment`는 host provider가 있을 때 브라우저 local() 경로를 건너뛴다. 앱의 Studio 빌드 어댑터에서 공식 선언 계획과 host catalog를 연결하고, 문서가 요청한 후보 중 provider가 읽고 PS·SHA·face index·실제 파일 형식을 확인한 프로그램만 core에 전달한다. 첫 표시 및 출력용 트리를 요청하기 전에 준비하고, 가져오기·제거·비활성화 때 같은 문서의 환경을 갱신한다. 문서 교체나 공급 세대 변경 중 끝난 이전 요청은 폐기한다. 사용자 명시 환경과 원본 저장 이름·Bold·저장된 줄 정보는 보존한다. native는 `HwpNativeFontPageRenderer`가 `nativeFontRequests`를 호출하면 이미 생성된 layer tree에서 슬롯을 읽으므로, 같은 문서 핸들에 선언 계획 조회와 환경 적용을 먼저 연결한다. Swift/C ABI가 필요하면 앱 소유 RustBridge에 추가하고 기존 호출자의 기본 동작과 수명 계약을 검증한다.
2. **공식 렌더러와 앱의 출력 경계를 대조한다.** 후보 WASM의 기본 HWP3 SVG와 앱 출력용 SVG 모두 표지의 ‘창’에 `딸기`, `font-weight="bold"`가 있고 획 지정은 없다. 앱의 PDF resolver는 이 요청을 700으로 조회해 `unavailable`을 반환한다. native도 `HwpNativeFontPageRenderer`에서 문서 Bold를 700 요청으로 변환하고 선택한 face의 굵기를 검사한다. 같은 OTF를 정식 공급 경로에 연결한 upstream에서 실제 선택 face, SVG·Skia 그리기 결과를 확인한다. 알한글에서만 실패하면 기존 renderer의 프로그램 선택과 그리기 지시를 끊은 앱 경계를 고친다. upstream에서도 재현되면 원본과 한컴 출력의 차이 및 최소 재현을 제시해 core 수정 범위를 판단한다. PDF Type 3 이름만으로 한컴이 사용한 프로그램이나 합성 방법을 확정할 수 없다. 실제 Bold 우선 선택, 기울임, 가족 충돌, glyph coverage, 임베딩 제한과 취소는 [#568 출력 계약](../tech/task_m020_568_output_contract.md)으로 회귀 검증한다.
3. **통과 여부를 검사기에 반영한다.** 현재 HWPX 검사는 원본 face 읽기가 0회여도 PDF가 만들어지면 종료 0이다. Studio와 native의 `--hft-document` 검사에 원본 입력 범위, 예상 슬롯·face SHA, 요청/선택 굵기·적용 효과, 독립 출력 관찰을 추가한다. 두 원본의 화면과 공통 PDF/인쇄용 첫 쪽, native CoreGraphics 및 Skia 각각의 결과를 낸다. 필요한 공개 core API나 양쪽 backend의 재생 기능이 v0.9.0에 없으면 최소 재현과 부족한 계약을 기록해 upstream 변경 범위를 요청한다. Stable 후보의 다음 입력은 해당 변경이 포함된 공식 태그와 resolved commit으로 정한다. 앱 소유 수정으로 가능하면 기존 pin에서 writer로 Studio·bridge와 provenance를 다시 생성한다.

#### 재검증 및 완료 조건

| 조건 | 수집할 증거와 기대 결과 |
|------|----------------------|
| 관리 글꼴 없음 → 가져오기 → 같은 원본을 새 프로세스에서 재열기 → 관리 해제 | 원본 두 문서 모두 가져오기·재열기에서 한글 줄의 요청과 실제 PS·SHA·index가 연결되고 해제 후 기존 대체 결과를 복원한다. 공급 도중 문서가 바뀌는 경우 이전 프로그램을 적용하지 않는다. |
| 실제 Bold 있음 / Regular만 있음 | 고운바탕은 실제 700 프로그램 선택을 확인한다. 딸기는 문서의 굵게 속성, 실제 읽은 400 프로그램, upstream이 그리기에 사용한 효과를 각각 기록한다. 동일 입력에서 앱의 PDF·CG·Skia가 그 지시를 보존하는지와 한컴 참조 PDF의 대상 글줄 모양을 대조한다. 실제 딸기 Bold 파일을 사용하는 경우는 해당 face 확보 시 검증한다. |
| 소비자별 첫 쪽 | PDF·인쇄 준비 결과의 임베드 프로그램을 읽고 PDFKit·Poppler에서 대상 한글 줄을 순서대로 한 번 추출한다. CG·Skia는 실제 backend, 선택 face, glyph 재생과 이미지로 확인한다. 독립 한컴 PDF와 같은 A4 좌표·명도·영역에서 잉크 경계와 교집합/합집합을 비교한다. 기존 HWP3 미공급/공급 화면은 0.2411/0.6790, HWPX 미공급은 0.1324다. 공급 효과와 재열기 재현성을 확인하고 기존 HWP3 화면의 저하는 원인을 조사한다. 표지의 다른 글꼴·외부 이미지, Type 3 이름으로 식별할 수 없는 원본 PS, 물리 프린터는 별도 관찰 범위다. |
| 일반 회귀·인계 | 기존 Node 35건·Python 5건, 공급 fixture 67 PASS·0 FAIL·30 NOT_RUN, 고운바탕 Studio 40건·저장본 재열기 6개 위치, native 및 확장 공통 경로를 재실행한다. 해당 변경의 실제 writer/strict Studio 검증·portable ABI·golden·HostApp 빌드를 확인한다. Stage 3 승인 후 4단계에서 #601 기준 `7a0103a477177a77e7458419d999dc5a0471790e`에 실제 제품 수정이 통합된 커밋과 산출물 해시를 기록해 #594 복구 smoke와 함께 재검증한다. |

재현할 때 두 원본 각각에 `python3 scripts/probe-studio-font-integration.py --hft-font "$FONT" --hft-document "$DOC" --output-dir "$STUDIO_OUT"`과 `python3 scripts/probe-native-font-supply.py --hft-font "$FONT" --hft-document "$DOC" --output "$NATIVE_OUT"`을 사용한다. 출력 변수는 T7 검증 사본의 `build.noindex` 아래 형식·실행별 새 디렉터리를 가리킨다. 진단 JSON·비교 이미지·폰트·한컴 PDF는 비공개 검증 경로에 둔다.

## 4. #594 통합 및 릴리스 운영 인계

#594 담당자의 커밋·후보 해시·복구 smoke 결과를 대조한다. 두 변경을 실제 통합한 커밋에서 provenance, HostApp, 글꼴 공급·재열기, 편집 실패 복구를 다시 검증한다. 릴리스 운영 담당자가 사용할 후보 SHA, 산출물 해시, 성공·실패·미실행 항목을 기록한다.

각 단계의 변경과 보고서를 해당 커밋에 묶는다. 마지막 단계 커밋은 `Task #600 Stage 4: 통합 후보 검증 및 릴리스 인계`다. 공개 배포는 별도 릴리스 운영 이슈에서 진행한다.
