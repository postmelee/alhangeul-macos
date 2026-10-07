# #567 Stage 3.2 재현과 증거

공식 v0.8.7 `1a76570e833917d15817415a53c09ad61ab3203f`의 core/Studio를 반영한 실제 제품 연결 검증이다. 과거 PR #7405 head 검증과 구분한다. 자세한 범위·중간 실패·환경은 [단계 보고](../../task_m020_567_stage3.md)에 있다.

이 자료와 아래 명령은 앱 commit `f8ed454`의 Stage 3.2 이력이다. Stage 3.3부터 별도 선택 창은 제거됐고 probe 기본 출력 폴더도 바뀌었다. 현재 소스의 재현은 [Stage 3.3 자료](../task_m020_567_stage3_3/REPRODUCE.md)를 따른다.

## 사전 준비

1. 앱 저장소의 고정 toolchain과 `scripts/build-rust-macos.sh --verify-portable`로 native bridge를 준비한다. shared cache를 사용할 때에는 build script가 기대하는 `RustBridge/target` 경로를 맞춰야 한다. 이번 실행의 임시 symlink는 종료 후 제거했다.
2. 테스트용 글꼴은 [Google Fonts 고정 커밋](https://github.com/google/fonts/tree/c1eda9233c33ad7775b27efd794f931095cf6133/ofl/gowunbatang)의 Regular/Bold 및 OFL.txt다. `build.noindex/task567/fonts/gowun-batang/`에 두고 [구현계획](../../../plans/task_m020_567_impl.md)의 size/SHA256을 대조한다. OS나 Font Book에 설치하지 않는다.
3. Node, Python 및 로그인된 macOS의 Swift/WebKit 환경이 필요하다. 시스템/사용자 글꼴 설정·bookmark를 변경하지 않는다. 이 probe는 live observer를 끄고 메모리 기반 fixture 공급만 사용한다.

## 실행

```sh
python3 scripts/probe-studio-font-integration.py
python3 scripts/probe-studio-font-integration.py --interactive --skip-build
```

첫 명령은 현재 bundle의 실제 WASM으로 고운바탕 Regular/Bold와 마지막 돋움 문장을 가진 HWP/HWPX를 생성한다. 모든 제품 Swift 소스와 실제 Coordinator를 포함한 고유 진단 앱을 빌드하고, Canvas2D·CanvasKit/WebGL·공개 선택 창·저장·재열기를 검사한다. 실패 시 0이 아닌 종료 코드를 반환한다. 자동 검증의 출력과 앱은 `build.noindex/task567/stage3-2/`에 남으며 앱 등록은 자신의 경로만 해제한다.

두 번째 명령은 앞서 빌드한 앱을 사용한다. 자동 확인 후 **고운바탕 연결 체험 · 테스트 문서** 창을 유지하며, 선택 창의 적용/취소 및 **서식 → 로컬 글꼴 선택…**을 직접 조작할 수 있다. 터미널 실행 세션은 창을 닫을 때까지 유지한다. provider/native lease와 해당 앱의 등록은 창 닫기 시 정리한다. 실제 사용자 문서는 입력으로 쓰지 않는다.

## 보존한 결과

- `integration-result.json`: 제품 Coordinator/실제 Studio 연결, 각 문서 generation의 Regular/Bold bytes, Canvas2D 실제 host alias paint, CanvasKit 실제 backend/GPU, 선택 창·새 revision repaint·HWP/HWPX export.
- `saved-font-proof.json`: 실제 저장 파일 재열기에서 처음 Regular, 중간 Bold, 마지막 바뀐 글꼴의 원래 family/굵기. 각 위치의 7개 language font name도 검증한다.
- `canvaskit-diagnostics.json`·`canvaskit-gpu.json`: fallback 없음, 로컬 typeface 2개/load failure 0개/render complete, 실제 WebGL 2.0/Apple GPU. 적용 전 연결 증거다.
- `local-font-picker.png`: 실제 선택 창. `studio-after-picker.png`: 새 문서 revision의 paint 완료 후 마지막 ‘확인’도 고운바탕으로 변경. `studio-hwpx-canvaskit.png`: 적용 전 비교 화면.
- `provenance.json`: native lock, Studio manifest, 공식 다운로드 글꼴 provenance와 toolchain. `checksums.json`: 보존 결과의 해시·크기.

한글 본문과 영문 family/PS 이름을 확인했다. 이 무료 글꼴 자체에는 실제 한국어 family name이 없으므로 지역화 family 이름의 모든 경우를 검증했다고 주장하지 않는다. 계약 테스트의 한국어 문자열·alias 검증과 다른 실제 글꼴의 전체 수용을 구분한다. 실제 OS 지속 설치·signed sandbox·최소 macOS/Intel 실기·권한 복원·모든 glyph/실문서·출력/Finder 지원은 별도 단계다.
