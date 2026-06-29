# Task #388 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #388 Thumbnail render signature를 `rhwp-core.lock` 기준으로 생성/검증 |
| 추적 이슈 | #387 Preview/Thumbnail Skia readiness 후속 개선 추적 |
| 마일스톤 | v0.2.x Skia Quick Look/Thumbnail Backend |
| 단계 수 | 4 |
| 작업 브랜치 | `local/task388` |

`HwpThumbnailRenderSignature`가 stale `rhwp v0.7.13` metadata 대신 current `rhwp-core.lock` 기준 `v0.7.17`, `03351190ec35436e58cbfee0aa9278a8fdc04a59`, `native-skia`를 사용하도록 정리했다. 이후 core pin 변경 시 Swift build info 갱신 누락을 잡는 standalone verification command도 추가했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift` | `rhwp-core.lock` 기준 release tag, resolved commit, enabled features를 Swift target에서 참조할 platform-neutral build info로 추가 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | `HwpThumbnailRenderSignature`의 core metadata 기본값을 `RhwpCoreBuildInfo` 참조로 변경 |
| `scripts/verify-rhwp-core-build-info.sh` | lock/build info mismatch를 실패시키는 검증 명령 추가 |
| `scripts/check-no-appkit.sh` | `RhwpCoreBuildInfo.swift`도 AppKit/UIKit 금지 검사 대상에 포함 |
| `scripts/smoke-thumbnail-skia-policy.sh` | smoke compile source list에 `RhwpCoreBuildInfo.swift` 포함 |
| `Alhangeul.xcodeproj/project.pbxproj` | XcodeGen 생성 결과로 `RhwpCoreBuildInfo.swift` target source phase 포함 |
| `mydocs/plans/task_m020_388.md` | 수행계획서 |
| `mydocs/plans/task_m020_388_impl.md` | 구현계획서 |
| `mydocs/working/task_m020_388_stage1.md` | build info 위치와 lock parser 조사 보고 |
| `mydocs/working/task_m020_388_stage2.md` | signature refactor 보고 |
| `mydocs/working/task_m020_388_stage3.md` | lock/build info 검증 추가 보고 |
| `mydocs/working/task_m020_388_stage4.md` | build/smoke 최종 검증 보고 |
| `mydocs/orders/20260629.md` | 오늘할일 완료 처리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| Thumbnail signature core tag | `v0.7.13` 하드코딩 | `RhwpCoreBuildInfo.releaseTag = "v0.7.17"` |
| Thumbnail signature core commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` 하드코딩 | `RhwpCoreBuildInfo.commit = "03351190ec35436e58cbfee0aa9278a8fdc04a59"` |
| enabled features | `native-skia` 하드코딩 | `RhwpCoreBuildInfo.enabledFeatures` 참조 |
| build info source | 없음 | `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`, 5 lines |
| lock/build info 검증 | 없음 | `scripts/verify-rhwp-core-build-info.sh`, 83 lines |
| stale metadata 검색 | release-critical Swift source에 존재 | `Sources`와 `scripts`에서 stale 문자열 없음 |

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| Stage 1 | `d3151c7` | build info 위치를 `Sources/RhwpCoreBridge`로 정하고 기존 lock parser 재사용 경로 확인 |
| Stage 2 | `36643d9` | `RhwpCoreBuildInfo` 추가와 Thumbnail signature core metadata refactor |
| Stage 3 | `6756ba1` | lock/build info standalone verification command 추가 |
| Stage 4 | 이번 커밋 | XcodeGen, ThumbnailExtension build, thumbnail smoke, 최종 보고 정리 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| lock과 Swift build info 일치 검증 | OK | `./scripts/verify-rhwp-core-build-info.sh` 통과 |
| AppKit/UIKit boundary 유지 | OK | `./scripts/check-no-appkit.sh` 통과 |
| Xcode project 생성 | OK | `xcodegen generate` 통과 |
| ThumbnailExtension Debug build | OK | `xcodebuild ... ThumbnailExtension ... build`에서 `BUILD SUCCEEDED` |
| thumbnail signature smoke | OK | `KTX.hwp`, `request.hwp` 모두 `renders=8 failed=0` |
| signature current lock metadata 포함 | OK | smoke output에 `v0.7.17`, `03351190ec35436e58cbfee0aa9278a8fdc04a59`, `native-skia` 포함 |
| stale metadata 제거 | OK | `rg -n "v0\\.7\\.13\|b3e16ef" Sources scripts` 결과 없음 |
| whitespace 점검 | OK | `git diff --check` 통과 |

## 잔여 위험과 후속 작업

| 항목 | 상태 | 처리 |
|------|------|------|
| local strict static archive byte hash mismatch | 잔여 | #394 `build-rust-macos verify-lock strict 실패 UX 개선과 portable verify 분리`로 등록 |
| #390 readiness 재측정 | 후속 | 이번 작업의 signature 정합화 결과를 입력으로 사용 |
| `RhwpCoreBuildInfo` 갱신 자동화 | 제한적 수동 | 현재는 검증으로 누락을 잡는다. future core pin update에서 생성 자동화 필요성이 커지면 별도 작업으로 분리 |

## 작업지시자 승인 요청

Task #388의 구현과 검증은 완료했다. PR 게시 단계 진입 여부를 승인해 달라.
