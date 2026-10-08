# #567 Stage 3.3 — 기존 글꼴 목록 연결 재현

공식 v0.8.7 core/Studio pin을 유지하며 앱 소유 빌드 어댑터로 기존 글꼴 목록을 연결했다. [단계 보고](../../task_m020_567_stage3.md) · [구현계획](../../../plans/task_m020_567_impl.md).

## 빌드와 검증

고정된 upstream checkout의 WASM/pkg와 `rhwp-studio` npm dependencies를 준비한 뒤 앱 저장소 루트에서 실행한다. 승인된 시험 고운바탕 Regular/Bold와 OFL은 `build.noindex/task567/fonts/gowun-batang/`에 두고 구현계획의 다운로드 provenance/hash를 대조한다. OS에 설치하지 않는다.

```sh
node scripts/build-rhwp-studio.mjs --upstream-dir <checkout>
scripts/sync-rhwp-studio.sh --upstream-dir <checkout> \
  --tag v0.8.7 --commit 1a76570e833917d15817415a53c09ad61ab3203f \
  --actual-wasm-build-command '<실제 사용한 WASM 빌드 명령>'
scripts/verify-rhwp-studio-assets.sh --upstream-dir <checkout>
python3 scripts/probe-studio-font-integration.py
python3 scripts/probe-studio-font-integration.py --interactive --skip-build
```

빌드 helper는 변환 소스를 별도 사본에서 typecheck하며 원본 tracked 소스를 쓰지 않는다. `alhangeul-font-menu-adapter.json`의 builder/adapter fingerprint가 달라지면 다시 빌드해야 한다. upstream 소스 형태가 달라지면 변환/검증이 실패한다. minified 파일을 수정해 우회하지 않는다.

probe는 현재 제품 Coordinator와 실제 Studio를 사용한다. 사용자 OS catalog 대신 메모리 fixture 두 face만 공급하고 live observer를 끈다. Canvas2D 두 형식, CanvasKit/WebGL, 기존 글꼴 메뉴, 선택/커서 입력, repaint·HWP/HWPX 저장/재열기를 검증한다. 최종 실행은 `--output-dir build.noindex/task567/stage3-3/final`을 사용했다. 자동 실행은 종료 후 자신의 앱 등록을 해제한다.

## 직접 조작

직접 조작 모드의 **알한글 — 고운바탕 연결 체험 · 테스트 문서** 창에서 상단 `Gowun Batang` 드롭다운을 누른다. 왼쪽 **시스템 글꼴** 또는 **모든 글꼴**에 `Gowun Batang`이 표시된다. family 한 항목이 Regular/Bold를 포함한다. 문서에서 글자를 선택해 적용하거나 커서를 옮겨 선택 후 입력한다. 별도 로컬 글꼴 메뉴/대화창은 없다. 앱 기본 서식·언어·굵기 처리도 그대로 사용한다. 창을 닫으면 자신의 provider/lease·앱 등록을 정리한다.

## 보존 자료

- `local-font-dropdown.png`: 기존 시스템 글꼴 목록에 한 family 표시.
- `studio-after-dropdown.png`: 마지막 ‘확인’의 글꼴 변경 및 새 `입력` glyph의 실제 CanvasKit repaint 완료 후 화면.
- `integration-result.json`: 실제 제품 연결·메뉴·선택/입력·repaint·export 27개 확인.
- `saved-font-proof.json`: 두 저장 형식의 4개 위치, 원래 family·굵기. 입력 내용과 7개 언어 이름도 검증.
- `adapter-receipt.json`·`studio-manifest.json`: upstream SHA 및 빌드/변환 fingerprint.
- `checksums.json`: 다른 보존 파일의 hash/size.

실제 OS 전체 목록, signed sandbox·권한 복원, 설치/제거, 최소 macOS/Intel 실기, 대규모 catalog 성능·모든 문서 수용은 별도 단계다. 이 검증은 제품 배포가 아니다.
