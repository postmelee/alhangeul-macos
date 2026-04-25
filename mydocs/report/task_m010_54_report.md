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
- `hulryung/hwpql`의 git rev pinning + lock + release hash 검증 방식을 확인했다.
- `edwardkim/rhwp` 최신 release `v0.7.3` 전환 빌드를 검증했고, 현재 `RustBridge` 필수 API가 없어 즉시 전환할 수 없음을 확인했다.
- lock과 운영 문서에서 현재 core ref를 release tag 전환 대기 상태로 명시하고, `devel` branch를 안정 기준처럼 설명하는 문구를 제거했다.
- release tag 전환을 막고 있는 API compatibility/update architecture 작업을 GitHub Issue #55로 분리했다.
- Issue #30에는 #55 완료 후 진행한다는 관계를 남겼다.

## 최종 lock 상태

```text
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_ref_kind = "branch"
rhwp_branch = "devel"
rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"
rhwp_release_transition_status = "blocked-missing-bridge-apis"
rhwp_latest_checked_release_tag = "v0.7.3"
rhwp_latest_checked_release_commit = "c2e8a3461de800a02f76127ff4797bade1d4e532"
Frameworks/universal/librhwp.a sha256 = 09f9d18f54aa8012aba51fcf32e925286eecbbbd7222c033e37b7779674a7e20
Frameworks/universal/librhwp.a size = 102631496
Frameworks/generated_rhwp.h sha256 = 69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5
Frameworks/generated_rhwp.h size = 1349
```

## release tag 전환 확인

`edwardkim/rhwp` 최신 release 확인 결과:

- latest release: `v0.7.3`
- release target branch: `main`
- resolved commit: `c2e8a3461de800a02f76127ff4797bade1d4e532`

`Vendor/rhwp`를 일시적으로 `v0.7.3`으로 전환해 `RustBridge` arm64 build를 검증했다.

결과: 실패.

```text
no method named `build_page_render_tree` found for struct `DocumentCore`
no method named `get_bin_data` found for struct `DocumentCore`
```

현재 bridge가 사용하는 native render tree와 image data API가 최신 release에 포함되지 않아, 이번 작업에서는 release tag 전환 대기 상태를 lock과 문서에 기록했다.

## 검증 결과

통과:

```bash
git diff --check
git submodule sync -- Vendor/rhwp
git submodule update --init --recursive Vendor/rhwp
./scripts/build-rust-macos.sh --verify-lock
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
bash -n scripts/build-rust-macos.sh
bash -n scripts/update-rhwp-core.sh
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

새 선행 이슈:

- Issue #55: release tag dependency 전환을 위한 core API compatibility와 update architecture 정리

Issue #30은 #55 완료 후 `Vendor/rhwp` submodule 제거와 `RustBridge` release tag dependency 전환을 다시 계획하면 된다. 진행 시점에는 `edwardkim/rhwp`의 최신 release tag와 resolved commit을 확인해야 한다.

Issue #30은 release tag가 위 API를 포함하는지 먼저 검증해야 한다. 통과 전에는 branch나 floating ref를 안정 기준으로 사용하지 않는다.

권장 진행 순서:

1. Issue #52: 기존 PR 문서 링크를 merge 후 조회 가능한 고정 URL로 보정
2. Issue #55: release tag dependency 전환을 위한 core API compatibility와 update architecture 정리
3. Issue #31: README와 아키텍처 문서를 타깃별 제품 경계 중심으로 재정렬
4. Issue #30: RustBridge를 release tag dependency로 전환하고 `Vendor/rhwp` submodule 제거
5. Issue #32: 서명, 공증, DMG까지 포함한 release pipeline 자동화

## 완료 판단

Issue #54의 목표인 core dependency/provenance 기준 정합화는 완료되었다.

## 승인 요청

이 최종 결과 보고서 기준으로 PR 생성 절차를 진행할지 승인 요청한다.
