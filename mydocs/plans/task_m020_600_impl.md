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

## 4. #594 통합 및 릴리스 운영 인계

#594 담당자의 커밋·후보 해시·복구 smoke 결과를 대조한다. 두 변경을 실제 통합한 커밋에서 provenance, HostApp, 글꼴 공급·재열기, 편집 실패 복구를 다시 검증한다. 릴리스 운영 담당자가 사용할 후보 SHA, 산출물 해시, 성공·실패·미실행 항목을 기록한다.

각 단계의 변경과 보고서를 해당 커밋에 묶는다. 마지막 단계 커밋은 `Task #600 Stage 4: 통합 후보 검증 및 릴리스 인계`다. 공개 배포는 별도 릴리스 운영 이슈에서 진행한다.
