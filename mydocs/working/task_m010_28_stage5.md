# Issue #28 Stage 5 완료 보고서

## 단계 목적

Issue #28 전체 변경을 검증하고 최종 결과 보고서를 작성한다.

## 검증 결과 요약

통과:

- `./scripts/build-rust-macos.sh`
- `./scripts/check-no-appkit.sh`
- `xcodegen generate`
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `./scripts/validate-stage3-render.sh output/task28-stage5-render`
- `rg -n "Vendor/rhwp/samples|Vendor/rhwp/samples/basic|Vendor/rhwp/samples/exam_kor" README.md scripts mydocs/manual`
- `git diff --check`

실패:

- `./scripts/build-rust-macos.sh --verify-lock`

실패 원인:

```text
ERROR: artifact differs from /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
Artifact: Frameworks/universal/librhwp.a
Expected sha256: 725b65ad445660292bb1a5f2a0f9107ff810e65a699ade78e0a3b26dd901dd50
Actual sha256:   5e1255b5eb30cef156c43d123faa177c3014ebfa3a4fd4daf5764f025a80db2f
Expected size:   102627384
Actual size:     102631504
```

`Vendor/rhwp` submodule commit은 lock의 `rhwp_commit`과 동일한 `1e9d78a1d40c71779d81c6ec6870cd301d912626`이며, generated header hash는 lock과 일치했다. 이번 #28 변경은 샘플 경로와 문서 변경이므로 `rhwp-core.lock`은 갱신하지 않았다.

## render smoke 결과

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455 png=/Users/melee/Documents/projects/rhwp-mac/output/task28-stage5-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724 png=/Users/melee/Documents/projects/rhwp-mac/output/task28-stage5-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464 png=/Users/melee/Documents/projects/rhwp-mac/output/task28-stage5-render/exam_kor-page1.png
```

## 기본 경로 제거 확인

다음 명령은 결과 없음으로 통과했다.

```bash
rg -n "Vendor/rhwp/samples|Vendor/rhwp/samples/basic|Vendor/rhwp/samples/exam_kor" README.md scripts mydocs/manual
```

## 생성된 로컬 산출물

다음 경로는 `.gitignore` 대상이며 커밋하지 않는다.

- `Frameworks/`
- `RustBridge/target/`
- `build.noindex/`
- `output/task28-stage5-render/`

## 참고 사항

`xcodebuild`와 `xcodebuild -create-xcframework` 실행 중 CoreSimulatorService 관련 경고가 출력되었다. macOS Debug build와 render smoke test는 exit code 0으로 성공했다.

## 완료 판단

Issue #28의 핵심 완료 조건인 “기본 render smoke 샘플 경로가 `Vendor/rhwp` 없이 설명/실행 가능해야 한다”는 충족했다. 다만 `rhwp-core.lock` artifact 검증 불일치는 별도 후속 조사가 필요하다.

## 승인 요청

이 Stage 5 완료 보고서와 최종 결과 보고서 기준으로 PR 생성 절차 진행 승인을 요청한다.
