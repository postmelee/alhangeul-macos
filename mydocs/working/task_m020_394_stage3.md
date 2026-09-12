# Task M020 #394 Stage 3 완료보고서

## 실제 macOS 검증

- `./scripts/build-rust-macos.sh --verify-portable`: arm64/x86_64 build, universal archive/XCFramework, source/header/FFI 검증 통과(exit 0).
- `./scripts/build-rust-macos.sh --verify-strict`: source/header/FFI 통과 후 strict staticlib reference mismatch로 의도대로 차단(exit 1). strict byte 일치를 달성했다고 주장하지 않는다.
- reference SHA256 `25ba743d7e3774c81177e849308fba98ce0e6b7a22eff3d1b6380a11ab9f0544`, 로컬 `062ba3a4f4d73c4b6494c209cc68a9ec188b2668a031b037bbed1ad354ddf5e8`.
- `check-no-appkit.sh`, `verify-rhwp-core-build-info.sh`, release helper help 통과.
- core/Cargo pin과 FFI symbol lock은 `origin/devel` 대비 byte 변경 없음.
- 로그: `build.noindex/task394/{portable,strict}.log`. Stage 1 CLI fixture 18개 및 Stage 2 shell/YAML 검증 통과.

배포·앱 설치·확장 등록은 수행하지 않았다. strict 불일치의 정확한 toolchain 원인 분석과 reproducible archive 구축은 이 이슈의 제외 범위다.
