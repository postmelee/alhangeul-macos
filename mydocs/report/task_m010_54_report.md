# Issue #54 최종 결과 보고서

## 목적

앱 저장소의 core dependency, lock provenance, 운영 문서, 검증 스크립트를 `edwardkim/rhwp` 기준으로 일관화했다.

## 최종 변경 요약

- `.gitmodules`, `rhwp-core.lock`, `scripts/build-rust-macos.sh`, `scripts/update-rhwp-core.sh`의 core repository 기준을 `https://github.com/edwardkim/rhwp.git`로 정리했다.
- README, AGENTS, architecture, build/release/core operation manual의 core 설명을 현재 구조 기준으로 정리했다.
- Issue #28/#29/#30 관련 산출 문서 중 후속 작업에 영향을 주는 문서를 현재 core 기준으로 정리했다.
- GitHub Issue #29와 #30 본문을 현재 core 기준과 후속 release tag dependency 방향에 맞춰 정리했다.
- `rhwp-core.lock`의 `librhwp.a` artifact sha256/size를 현재 고정 commit의 재생성 산출물 기준으로 갱신했다.
- `scripts/validate-stage3-render.sh`가 자체 module cache를 새로 만들도록 해 기본 render smoke 명령의 재실행 안정성을 높였다.

## 최종 lock 상태

```text
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_branch = "devel"
rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"
Frameworks/universal/librhwp.a sha256 = 5e1255b5eb30cef156c43d123faa177c3014ebfa3a4fd4daf5764f025a80db2f
Frameworks/universal/librhwp.a size = 102631504
Frameworks/generated_rhwp.h sha256 = 69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5
Frameworks/generated_rhwp.h size = 1349
```

## 검증 결과

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

## render smoke 결과

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

## 참고 사항

`xcodebuild`와 `xcodebuild -create-xcframework` 실행 중 CoreSimulatorService, provisioning profile 관련 경고가 출력되었다. macOS Debug build와 render smoke test는 exit code 0으로 성공했다.

GitHub Issue 본문 변경은 remote state이므로 로컬 커밋에는 본문 diff가 포함되지 않는다. Stage 4와 Stage 5에서 Issue #29/#30 본문 검색을 확인했다.

## 후속 작업

Issue #30은 이 기준 위에서 `Vendor/rhwp` submodule 제거와 `RustBridge` release tag dependency 전환을 다시 계획하면 된다. 진행 시점에는 `edwardkim/rhwp`의 최신 release tag와 resolved commit을 확인해야 한다.

## 완료 판단

Issue #54의 목표인 core dependency/provenance 기준 정합화는 완료되었다.

## 승인 요청

이 최종 결과 보고서 기준으로 PR 생성 절차를 진행할지 승인 요청한다.
