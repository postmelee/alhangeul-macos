# Issue #54 Stage 5 완료 보고서

## 단계 목적

Issue #54 전체 변경을 검증하고 최종 결과 보고서를 작성한다.

## 최종 조정

- `rhwp-core.lock`
  - `rhwp_repo`, `rhwp_branch`, `rhwp_commit`은 유지했다.
  - 현재 고정 commit에서 재생성되는 `Frameworks/universal/librhwp.a` 산출물의 sha256/size를 lock에 반영했다.
- `scripts/validate-stage3-render.sh`
  - Swift/Clang module cache가 workspace 절대 경로를 포함하므로, 렌더 검증 전에 자체 생성 cache 디렉터리를 새로 만들도록 했다.

## 검증 결과 요약

통과:

```bash
git diff --check
git submodule sync -- Vendor/rhwp
git submodule update --init --recursive Vendor/rhwp
./scripts/build-rust-macos.sh --verify-lock
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
bash -n scripts/validate-stage3-render.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
```

검색 게이트:

비대상 core repository URL 검색 결과: 출력 없음.

```bash
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git" .gitmodules rhwp-core.lock README.md AGENTS.md RustBridge scripts mydocs/tech mydocs/manual mydocs/plans
```

결과: `edwardkim/rhwp` URL과 Issue #54 계획서의 검색 정규식만 검출.

## lock 검증

초기 `./scripts/build-rust-macos.sh --verify-lock` 실행은 `Frameworks/universal/librhwp.a` artifact hash/size 불일치로 실패했다.

불일치:

```text
Expected sha256: 725b65ad445660292bb1a5f2a0f9107ff810e65a699ade78e0a3b26dd901dd50
Actual sha256:   5e1255b5eb30cef156c43d123faa177c3014ebfa3a4fd4daf5764f025a80db2f
Expected size:   102627384
Actual size:     102631504
```

동일 core commit에서 현재 빌드 산출물과 lock을 맞추기 위해 다음 명령을 실행했다.

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
```

최종 lock 상태:

```text
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_branch = "devel"
rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"
Frameworks/universal/librhwp.a sha256 = 5e1255b5eb30cef156c43d123faa177c3014ebfa3a4fd4daf5764f025a80db2f
Frameworks/universal/librhwp.a size = 102631504
```

## render smoke 결과

기본 경로에서 실행한 `./scripts/validate-stage3-render.sh` 결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

## 빌드 참고 사항

`xcodebuild`와 `xcodebuild -create-xcframework` 실행 중 CoreSimulatorService, provisioning profile 관련 경고가 출력되었다. macOS Debug build와 render smoke test는 exit code 0으로 성공했다.

## 생성된 로컬 산출물

다음 경로는 `.gitignore` 대상이며 커밋하지 않는다.

- `Frameworks/`
- `RustBridge/target/`
- `build.noindex/`
- `output/stage3-render/`

## 완료 판단

Issue #54의 완료 조건인 core dependency/provenance 기준 정합화, build 검증, render smoke 검증, 검색 게이트가 모두 충족되었다.

## 승인 요청

이 Stage 5 완료 보고서와 최종 결과 보고서 기준으로 PR 생성 절차 진행 승인을 요청한다.
