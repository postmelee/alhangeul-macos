# Issue #3 구현 계획서

## 1단계: 기준 브랜치 및 문서 정리

- `devel`을 원격 최신 상태로 동기화한다.
- Issue #3을 생성하고 `local/task3` 브랜치를 분기한다.
- 오늘 할일과 수행/구현 계획서를 작성한다.

## 2단계: core fork 포팅

- `Vendor/rhwp`에 `postmelee/rhwp` remote를 추가한다.
- `postmelee/rhwp`의 `devel`을 기준으로 `ios/devel`의 native viewer core 변경을 최소 포팅한다.
- 포팅 대상은 render tree serde 직렬화, `build_page_render_tree`, `get_bin_data`, 관련 `Serialize` derive로 제한한다.

## 3단계: macOS bridge 연동

- `alhangeul-macos` submodule URL을 `postmelee/rhwp`로 변경한다.
- `RustBridge`가 포팅된 core API를 사용하도록 수정한다.
- 문서에 core fork 추적 정책을 반영한다.

## 4단계: 검증 및 보고

- Rust bridge, XcodeGen, HostApp 빌드를 검증한다.
- 단계 보고서와 최종 보고서를 작성한다.
- 변경분을 커밋하고 `local/task3 -> devel` PR을 생성한다.
