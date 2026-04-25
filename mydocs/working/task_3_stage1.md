# Issue #3 단계 완료 보고서

## 단계

core bridge 포팅 및 macOS 연동 검증

## 수행 내용

- `edwardkim/rhwp`의 `devel`을 최신 기준으로 갱신했다.
- `ios/devel`의 native viewer core 변경 중 필요한 항목만 선별 포팅했다.
  - render tree 타입 serde 직렬화
  - `DocumentCore::build_page_render_tree`
  - `DocumentCore::get_bin_data`
  - 관련 style/model 타입 `Serialize` derive
- `RustBridge`가 compact JSON 대신 상세 render tree JSON을 반환하도록 수정했다.
- `rhwp_image_data`가 문서 내 bin data를 반환하도록 수정했다.
- `alhangeul-macos`의 submodule URL과 lock 파일을 `edwardkim/rhwp` 기준으로 전환했다.

## 검증

- `cargo check --lib` (`Vendor/rhwp`)
- `./scripts/build-rust-macos.sh`
- `./scripts/check-no-appkit.sh`
- `xcodegen generate`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `./scripts/validate-stage3-render.sh`

## 결과

Quick Look/Thumbnail/HostApp이 사용하는 Swift render tree 디코드 경로가 다시 상세 JSON 기반으로 동작한다. `validate-stage3-render.sh`에서 `KTX.hwp`, `request.hwp`, `exam_kor.hwp` 3개 샘플 렌더링이 통과했다.
