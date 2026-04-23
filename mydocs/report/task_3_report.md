# Issue #3 최종 보고서

## 작업 요약

`ios/devel`에서 사용하던 native viewer core 변경을 개인 fork `postmelee/rhwp`의 `devel`에 선별 포팅하고, `alhangeul-macos`가 해당 core fork를 submodule로 추적하도록 전환했다.

이번 작업은 upstream에 PR을 생성하지 않고, `alhangeul-macos` 저장소의 Issue #3과 PR에서만 추적한다.

## 주요 변경

- `Vendor/rhwp` submodule URL을 `https://github.com/postmelee/rhwp.git`로 변경했다.
- `rhwp-core.lock`을 `postmelee/rhwp` commit `1e9d78a3209d7750d47b6e3af4af621b8fed4127`로 갱신했다.
- `postmelee/rhwp` core에 native viewer용 최소 API를 추가했다.
  - 상세 render tree serde JSON 직렬화
  - `build_page_render_tree`
  - `get_bin_data`
- `RustBridge`를 갱신했다.
  - `rhwp_render_page_tree`가 Swift `RenderTree` 모델이 기대하는 상세 JSON을 반환한다.
  - `rhwp_image_data`가 bin data를 반환한다.
- README와 architecture 문서를 개인 fork core 기준으로 갱신했다.

## 검증

- `cargo check --lib` (`Vendor/rhwp`)
- `./scripts/build-rust-macos.sh`
- `./scripts/check-no-appkit.sh`
- `xcodegen generate`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `./scripts/validate-stage3-render.sh`

`validate-stage3-render.sh` 결과:

- `KTX.hwp`: textRuns=435, nonWhitePixels=450455
- `request.hwp`: textRuns=104, nonWhitePixels=54724
- `exam_kor.hwp`: textRuns=69, nonWhitePixels=96464

## 남은 사항

- Finder Quick Look/Thumbnail extension을 실제 Finder 환경에서 smoke test해야 한다.
- 향후 core 고도화는 `postmelee/rhwp`의 `devel`에서 진행하고, 앱 연동 변경은 `alhangeul-macos` Issue/PR로 추적한다.
