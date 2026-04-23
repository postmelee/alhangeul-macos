# rhwp core bridge 정리 계획

## 배경

`alhangeul-macos`는 개인 fork `postmelee/rhwp`를 `Vendor/rhwp` submodule로 사용한다. 코어 최신화 기준은 `postmelee/rhwp`의 `devel`이다.

기존 prototype은 `ios/devel`의 iOS viewer용 Swift/FFI 코드를 직접 공유했지만, 개인 레포 분리 후에는 이 전략을 유지하지 않는다. Swift bridge는 이 레포가 소유하고, `rhwp`는 코어 엔진으로만 소비한다.

## 현재 상태

upstream `devel`은 native viewer C ABI를 직접 제공하지 않는다. 이 레포는 `RustBridge`에서 C ABI를 소유하고, 개인 fork core는 Swift renderer가 기대하는 상세 render tree JSON과 이미지 데이터 조회에 필요한 최소 public API만 제공한다.

## 권장 방향

1. 이 레포의 `RustBridge/` crate가 `Vendor/rhwp`를 path dependency로 사용하고, C ABI만 export한다.
2. `cbindgen`은 `RustBridge`를 대상으로 실행한다.
3. Swift는 `Rhwp.xcframework`의 `Rhwp` C module만 import한다.
4. 부족한 render tree/image public API는 개인 fork `postmelee/rhwp`의 `devel`에서 먼저 고도화한다.

## RustBridge 구조

```text
RustBridge/
├── Cargo.toml
├── cbindgen.toml
└── src/lib.rs
```

`Cargo.toml`:

```toml
[package]
name = "rhwp_mac_bridge"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib"]

[dependencies]
rhwp = { path = "../Vendor/rhwp" }
serde_json = "1"
```

## ABI 원칙

- C ABI는 이 레포가 소유한다.
- ABI 변경 시 `rhwp-ffi-symbols.txt`, Swift bridge, release note를 함께 갱신한다.
- submodule 업데이트와 ABI 변경은 같은 커밋에 섞지 않는다.
