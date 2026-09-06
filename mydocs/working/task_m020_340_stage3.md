# Task M020 #340 Stage 3 완료보고서

## universal artifact·기존 회귀 검증 및 보고

## universal 및 회귀 검증

- `scripts/build-rust-macos.sh --update-lock`: arm64/x86_64 빌드, generated header/심볼 대조, XCFramework 생성 성공. 의도적 새 ABI에 한해 header/staticlib hash·size·생성 시각을 갱신했다. core 저장소/ref/tag/commit/features는 동일하다.
- `scripts/build-rust-macos.sh --verify-portable`: PASS.
- 실제 C caller: generated header 두 architecture macOS 12 target syntax 및 arm64 staticlib link, request.hwp 추출/bytes 해제/NULL reset PASS.
- `scripts/verify-render-tree-golden.sh`: pinned producer와 Swift decoder PASS (TextRun 103, Table 4, TextLine 65).
- `scripts/validate-stage3-render.sh build.noindex/spotlight-work/task340-native`: KTX/request/exam_kor 모두 비어 있지 않은 native PNG 생성 PASS.
- `scripts/check-no-appkit.sh`, workflow YAML parse, `cargo fmt --check`, `git diff --check`: PASS.

## 제한과 인계

현재 OS 실행이며 macOS 12 runtime은 미실행이다. native PNG는 기존 회귀 증거이고 신규 사용자 화면 변경은 없다. #341 importer가 C ABI를 사용하도록 연결한다. 공개 릴리스·공증과 PR merge는 수행하지 않았다.
