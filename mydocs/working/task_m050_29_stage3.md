# Issue #29 Stage 3 완료 보고서

## 단계 목적

`scripts/build-rust-macos.sh`의 lock update/verify 동작을 완성한다.

이번 단계의 완료 기준은 다음과 같다.

- `--update-lock`이 실제 산출물의 sha256/size를 `rhwp-core.lock`에 기록한다.
- `--verify-lock`이 lock의 commit과 artifact metadata를 현재 빌드 결과와 비교한다.
- 불일치 또는 metadata 누락 시 expected/actual 또는 해결 안내를 출력하고 실패한다.

## 변경 내용

### lock parser helper 추가

`scripts/build-rust-macos.sh`에 v2 lock 형식만 대상으로 하는 최소 helper를 추가했다.

- `lock_scalar`
  - top-level scalar 값을 읽는다.
  - 예: `lock_version`, `rhwp_commit`
- `lock_artifact_value`
  - 특정 `[[artifacts]]` block에서 `sha256`, `size` 값을 읽는다.

범용 TOML parser를 구현하지 않고, 현재 repository가 쓰는 lock v2 형식에 필요한 범위만 처리한다.

### verify 동작 완성

`verify_lock_file`을 추가해 다음을 확인한다.

1. `rhwp-core.lock` 존재 여부
2. `lock_version = 2`
3. `Vendor/rhwp` 현재 commit과 `rhwp-core.lock`의 `rhwp_commit` 일치 여부
4. 각 artifact 파일 존재 여부
5. 각 artifact의 expected/actual sha256 일치 여부
6. 각 artifact의 expected/actual size 일치 여부

불일치 시 출력하는 정보:

- artifact path
- expected sha256
- actual sha256
- expected size
- actual size
- 의도한 변경일 때 `--update-lock` 실행 안내

### `rhwp-core.lock` metadata 기록

`./scripts/build-rust-macos.sh --update-lock`로 현재 산출물 기준 metadata를 기록했다.

기록된 artifact:

| path | sha256 | size |
|------|--------|------|
| `Frameworks/universal/librhwp.a` | `725b65ad445660292bb1a5f2a0f9107ff810e65a699ade78e0a3b26dd901dd50` | `102627384` |
| `Frameworks/generated_rhwp.h` | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` | `1349` |

`built_at`은 `2026-04-25T00:16:18Z`로 기록되었다.

## 검증

### shell 문법 검사

```bash
bash -n scripts/build-rust-macos.sh
```

결과: 통과.

### 비어 있는 metadata verify 실패 확인

Stage 2 상태의 lock은 `sha256 = ""`, `size = 0`이었다. 이 상태에서 다음 명령을 실행했다.

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 의도대로 실패.

확인된 오류:

```text
ERROR: missing lock metadata for artifact: Frameworks/universal/librhwp.a
Run: ./scripts/build-rust-macos.sh --update-lock
```

### update 확인

```bash
./scripts/build-rust-macos.sh --update-lock
```

결과: 통과.

확인된 출력:

```text
Updated: /private/tmp/rhwp-mac-task29/rhwp-core.lock
```

### verify 성공 확인

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과.

확인된 출력:

```text
Verified: /private/tmp/rhwp-mac-task29/rhwp-core.lock
```

### 기본 build 확인

```bash
./scripts/build-rust-macos.sh
```

결과: 통과.

기본 실행은 `rhwp-core.lock`을 갱신하지 않는다.

### 동시 옵션 방지 확인

```bash
./scripts/build-rust-macos.sh --update-lock --verify-lock
```

결과: 의도대로 실패.

확인된 오류:

```text
ERROR: --update-lock and --verify-lock cannot be used together
```

### hash/size 직접 확인

```bash
shasum -a 256 Frameworks/universal/librhwp.a Frameworks/generated_rhwp.h
stat -f '%N %z' Frameworks/universal/librhwp.a Frameworks/generated_rhwp.h
```

결과: `rhwp-core.lock` 기록과 일치.

### diff whitespace 검사

```bash
git diff --check -- scripts/build-rust-macos.sh rhwp-core.lock
```

결과: 통과.

## 참고 사항

검증 중 `xcodebuild -create-xcframework`에서 CoreSimulatorService 관련 경고가 출력되었다. 하지만 `xcframework successfully written out` 메시지와 함께 `Frameworks/Rhwp.xcframework` 생성은 성공했고, 명령 exit code도 성공이었다.

## 생성된 로컬 산출물

다음 경로는 `.gitignore` 대상이며 커밋하지 않는다.

- `Frameworks/`
- `RustBridge/target/`

## 다음 단계

Stage 4에서 `scripts/package-release.sh`가 package 생성 전에 lock verify를 수행하도록 연동한다.

## 승인 요청

이 Stage 3 완료 보고서 기준으로 Stage 4를 진행할지 승인 요청한다.
