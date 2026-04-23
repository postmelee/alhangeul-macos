# Issue #3 수행 계획서

## 작업명

`ios/devel` core bridge 변경 포팅

## 배경

`alhangeul-macos`는 별도 파생 프로젝트로 분리되었고, upstream `edwardkim/rhwp`의 최신 core는 `devel`에서 관리된다. 다만 기존 iOS/macOS 렌더링 경로에서 검증된 native viewer bridge 변경은 `ios/devel`에 남아 있다.

부모 저장소에만 core 변경을 적용하면 submodule 내부 변경이 보존되지 않으므로, 개인 fork `postmelee/rhwp`의 `devel`에 필요한 core 변경을 포팅하고 `alhangeul-macos`가 해당 fork를 추적하도록 정리한다.

## 목표

- `postmelee/rhwp`의 `devel`에 native viewer용 최소 core API를 반영한다.
- `alhangeul-macos`의 `Vendor/rhwp` submodule URL과 포인터를 개인 fork 기준으로 전환한다.
- `RustBridge`가 compact render tree JSON 대신 상세 serde JSON을 반환하도록 갱신한다.
- `rhwp_image_data`가 문서 이미지 데이터를 반환하도록 복구한다.

## 완료 기준

- `./scripts/build-rust-macos.sh` 통과
- `./scripts/check-no-appkit.sh` 통과
- `xcodegen generate` 통과
- HostApp Debug 빌드 통과
- 최종 보고서 작성 후 `local/task3 -> devel` PR 생성
