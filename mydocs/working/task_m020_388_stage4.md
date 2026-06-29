# Task #388 Stage 4 완료 보고서

## 단계 목적

Thumbnail render signature의 core metadata 정합화가 실제 `ThumbnailExtension` target build와 thumbnail smoke에서 동작하는지 확인한다. 또한 #390 readiness 재측정으로 넘길 기준 상태와 residual risk를 최종 보고서에 정리한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Alhangeul.xcodeproj/project.pbxproj` | XcodeGen 재생성 결과. `RhwpCoreBuildInfo.swift`를 HostApp, ThumbnailExtension, QLExtension source phase에 포함 |
| `mydocs/working/task_m020_388_stage4.md` | Stage 4 검증 결과 보고 |
| `mydocs/report/task_m020_388_report.md` | Task #388 최종 보고서 |
| `mydocs/orders/20260629.md` | #388 오늘할일 완료 처리 |

## 변경 내용

- `xcodegen generate`로 생성 프로젝트를 갱신해 Stage 2에서 추가한 `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`가 Xcode build target에 포함되도록 했다.
- Thumbnail policy smoke 산출물에서 signature가 current lock 기준 `v0.7.17`, `03351190ec35436e58cbfee0aa9278a8fdc04a59`, `native-skia`를 포함함을 확인했다.
- `build-rust-macos --verify-lock` strict static archive byte hash 실패 UX는 이번 task 범위 밖으로 분리하고, 후속 이슈 #394를 등록했다.

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 변환 작업은 없다. 런타임 정책 변경 없이 build target 포함 범위와 검증/보고 문서만 정리했다.

## 검증 결과

| 명령 | 결과 | 메모 |
|------|------|------|
| `./scripts/check-no-appkit.sh` | 통과 | shared Swift code AppKit/UIKit 의존 없음 |
| `xcodegen generate` | 통과 | `Alhangeul.xcodeproj` 생성 완료 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedData-task388 CODE_SIGNING_ALLOWED=NO build` | 통과 | `BUILD SUCCEEDED`. CoreSimulator out-of-date 경고와 AppIntents metadata skip 경고는 macOS build 성공을 막지 않음 |
| `./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task388-thumbnail-signature samples/basic/KTX.hwp samples/basic/request.hwp` | 통과 | 두 샘플 모두 `renders=8 failed=0` |
| `rg -n "v0\\.7\\.13\|b3e16ef" Sources scripts` | 통과 | release-critical `Sources`와 `scripts`에는 stale core metadata 없음 |
| `rg -n "v0\\.7\\.13\|b3e16ef" Sources scripts mydocs` | 참고 통과 | `mydocs`에는 과거 기준 설명과 이번 task 계획/단계 보고서의 stale 상태 기록이 남음 |
| `git diff --check` | 통과 | whitespace error 없음 |

대표 smoke signature:

```text
coreGraphicsOnly|thumbnail-renderer-v1|v0.7.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia|skia-max-dimension-0
skiaOptIn|thumbnail-renderer-v1|v0.7.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia|skia-max-dimension-0
```

## 잔여 위험

- `Alhangeul.xcodeproj`는 XcodeGen 산출물이다. 원본은 계속 `project.yml`이며, 직접 편집은 하지 않았다.
- local strict `./scripts/build-rust-macos.sh --verify-lock`의 static archive byte hash mismatch는 #394에서 별도 UX 개선과 portable verify 분리로 추적한다.

## 다음 단계 영향

#390 readiness 재측정은 Thumbnail render signature가 current core lock 기준으로 cache를 분리한다는 전제에서 진행할 수 있다. 특히 Stage 4 smoke 산출물은 CoreGraphics/Skia 양쪽 policy signature가 모두 current lock metadata를 포함한다는 입력으로 사용할 수 있다.

## 승인 요청

Stage 4 산출물과 최종 보고서를 검토한 뒤 PR 게시 단계 진입 여부를 승인해 달라.
