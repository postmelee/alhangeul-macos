# Task M020 #390 Stage 4 완료보고서

## 단계 목적

Stage 1-3의 `rhwp v0.7.17` Skia readiness 재측정 결과를 종합하고, package/build gate와 Quick Look/Thumbnail surface별 default 유지 여부를 판단한다.

이번 단계는 제품 Swift/Rust source와 renderer 정책을 수정하지 않고, build gate와 readiness 판단만 문서화했다.

## 산출물

| 경로 | 내용 |
|------|------|
| `mydocs/working/task_m020_390_stage4.md` | package/build gate와 readiness 판단 보고 |
| `mydocs/orders/20260629.md` | #390 비고를 `Stage 4 완료보고서 승인 대기`로 갱신 |
| `build.noindex/DerivedData-task390/` | QLExtension/ThumbnailExtension Debug build 산출물 |

`build.noindex/` 산출물은 로컬 검증 결과이며 커밋 대상이 아니다.

## package/static artifact

| 항목 | #259 `v0.7.13` | #390 `v0.7.17` | 변화 |
|------|---------------|---------------|------|
| `Frameworks/universal/librhwp.a` exact size | 203,436,808 bytes | 202,925,096 bytes | -511,712 bytes |
| `Frameworks/Rhwp.xcframework/macos-arm64_x86_64/librhwp.a` exact size | - | 202,925,096 bytes | current xcframework 내부 staticlib와 일치 |
| `Frameworks/generated_rhwp.h` exact size | 2,059 bytes | 2,059 bytes | 변화 없음 |
| `Frameworks/Rhwp.xcframework/.../Headers/rhwp.h` exact size | - | 2,059 bytes | generated header와 일치 |
| `du -sh Frameworks/universal/librhwp.a` | `194M` | `194M` | 변화 없음 |
| `du -sh Frameworks/Rhwp.xcframework` | `194M` | `194M` | 변화 없음 |

해석:

- `native-skia` 포함 artifact의 package cost는 #259와 같은 수준이다.
- staticlib exact byte size는 소폭 줄었지만 `du -sh` 기준 배포 크기 판단은 달라지지 않았다.
- package size만으로 Skia default 전환을 새로 정당화할 근거는 없다.

## build gate

| 명령 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | `Alhangeul.xcodeproj/project.pbxproj` diff 없음 |
| `xcodebuild ... -scheme QLExtension ... build` | sandbox 내부 1회 실패, sandbox 밖 재실행 통과 | 최초 실패는 Sparkle SwiftPM dependency를 GitHub에서 resolve하지 못한 네트워크 제한 |
| `xcodebuild ... -scheme ThumbnailExtension ... build` | sandbox 내부 1회 실패, sandbox 밖 재실행 통과 | 최초 실패는 SwiftPM/module cache를 사용자 cache 경로에 기록하지 못한 sandbox 제한 |

빌드 통과 기준:

```text
** BUILD SUCCEEDED ** [14.412 sec]
** BUILD SUCCEEDED ** [1.666 sec]
```

Xcode 실행 중 `CoreSimulator is out of date` 경고가 반복됐지만 macOS Debug build 자체는 통과했다. 이번 단계에서는 simulator workflow를 사용하지 않으므로 renderer readiness blocker로 보지 않는다.

## Stage 2-3 종합

| surface | positive signal | negative/risk signal | Stage 4 판단 |
|---------|-----------------|----------------------|--------------|
| Quick Look 단일 PNG | 3개 단일 샘플 모두 fallback 0. `request.hwp`, `KTX.hwp` smoke latency는 Skia 우위 | `KTX.hwp` Skia visual diff가 CG보다 +15.4874pp 악화. `복학원서.hwp` reference capture contamination으로 visual 판단 불가 | CoreGraphics default 유지. Skia는 opt-in/diagnostic 유지 |
| Quick Look 다중 PDF | `hwp-multi-001.hwp`, `hwpx-01.hwpx` 모두 fallback 0. #259 대비 Skia latency gap 감소 | 두 샘플 모두 Skia smoke latency가 CG보다 느림. Visual page 1만 비교했고 다중 page 전체 visual coverage는 없음 | CoreGraphics default 유지. Skia PDF default 전환 근거 부족 |
| Finder Thumbnail | 3개 샘플 모두 `renders=8 failed=0`, signature가 current core metadata 포함, cache sequence 정상 | Skia output pixel dimension이 CG와 1px 차이. `KTX.hwp` visual regression이 thumbnail 기본 전환에도 위험 신호 | CoreGraphics default 유지. Skia opt-in diagnostic과 maxDimension 실험을 먼저 진행 |

## sample별 핵심 판단

| 샘플 | Stage 4 판단 |
|------|--------------|
| `request.hwp` | Skia가 latency와 visual diff 모두 유리하다. 다만 단일 성공 사례로 default 전환을 정당화하기에는 부족하다. |
| `KTX.hwp` | latency는 개선됐지만 visual regression이 유지된다. Skia default 전환의 가장 명확한 blocker다. |
| `복학원서.hwp` | Quick Look/Thumbnail smoke는 통과했지만 visual reference에 `로컬 글꼴 감지` overlay가 섞여 이번 visual 수치는 품질 신호로 쓰지 않는다. |
| `hwp-multi-001.hwp` | Skia PDF latency가 #259보다 개선됐지만 여전히 CG보다 느리다. page count가 #259의 10에서 9로 달라진 점은 별도 확인 대상이다. |
| `hwpx-01.hwpx` | visual page 1 차이는 유사하나 Skia PDF latency가 CG보다 느리다. HWPX default 전환 근거는 없다. |

## 후속 이슈 우선순위

| 이슈 | 제목 | #390 측정 근거상 우선순위 |
|------|------|--------------------------|
| #396 | 업스트림 renderer baseline 방식을 Quick Look/Thumbnail Skia 품질 검증에 이식 | 높음. Skia default 전환 전 대표/확장 visual suite가 필요하다. 전수 샘플 비교보다 upstream식 manifest + 수동 full sweep이 적합하다. |
| #392 | Thumbnail Skia maxDimension mapping 실험 | 높음. Thumbnail smoke에서 Skia output pixel dimension이 CG와 1px 차이난다. cache bucket과 시각 비교 기준을 안정화하려면 먼저 확인해야 한다. |
| #389 | Thumbnail Skia opt-in diagnostic path와 cache logging 추가 | 높음. fallback은 없었지만 backend/cache/signature 관찰이 smoke 산출물에 의존한다. 실제 Finder 경로에서 진단을 남기는 기반이 필요하다. |
| #393 | Quick Look 단일 페이지 Skia direct PNG opt-in fast path 실험 | 중간. `request.hwp`, `KTX.hwp` latency는 긍정적이지만 `KTX.hwp` visual regression이 남아 default 전환 실험보다 opt-in fast path로 제한해야 한다. |
| #391 | filename/external image context ABI 조사 및 bridge 설계 | 중간. 이번 샘플 세트의 직접 blocker는 아니지만 renderer fidelity 확장과 upstream parity에는 필요하다. |
| #394 | build-rust-macos verify-lock strict 실패 UX 개선과 portable verify 분리 | 중간. readiness 판단 blocker는 아니지만 장기 CI/로컬 검증 UX를 안정화해야 한다. |

## 결론

`rhwp v0.7.17` 기준 Skia backend는 fallback 없이 동작하고, 일부 단일 PNG/Thumbnail latency는 #259보다 좋아졌다. 그러나 다음 이유로 Quick Look/Thumbnail default 전환은 보류한다.

1. `KTX.hwp` visual regression이 #259와 같은 방향으로 유지된다.
2. 다중 PDF 경로에서 Skia는 여전히 CoreGraphics보다 느리다.
3. Thumbnail Skia output pixel dimension이 CoreGraphics와 1px 차이난다.
4. `복학원서.hwp` visual reference capture가 오염되어 대표 샘플 하나를 품질 판단에 사용할 수 없다.
5. package size는 #259와 같은 `194M` 수준으로 유지되어 default 전환의 추가 근거가 되지 않는다.

따라서 현 정책은 `CoreGraphics default + Skia opt-in diagnostic backend`로 유지하는 것이 맞다. Skia를 기본 후보로 다시 올리려면 #396 대표/확장 visual suite와 #392 Thumbnail dimension mapping, #389 diagnostic path를 먼저 진행해야 한다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 build/package 검증과 판단 보고서 작성만 수행했다. 제품 Swift/Rust source, renderer 정책, `project.yml`, `Alhangeul.xcodeproj`에는 최종 diff가 없다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `du -sh Frameworks/universal/librhwp.a Frameworks/Rhwp.xcframework` | 통과: 둘 다 `194M` |
| `stat -f '%z %N' ...` | 통과: staticlib/header exact size 기록 |
| `xcodegen generate` | 통과: project diff 없음 |
| `xcodebuild -scheme QLExtension ... build` | sandbox 밖 재실행 통과 |
| `xcodebuild -scheme ThumbnailExtension ... build` | sandbox 밖 재실행 통과 |

## 잔여 위험

- Stage 3 visual diff는 page 1 중심이다. 다중 PDF 전체 page visual coverage는 #396에서 별도 suite로 다루는 편이 적절하다.
- `복학원서.hwp` reference capture contamination은 visual harness 안정성 문제로 분리해야 한다.
- xcodebuild는 sandbox 내부에서 SwiftPM network/cache 접근 때문에 실패할 수 있다. Stage 4 build gate는 sandbox 밖 재실행 통과로 판정한다.
- `hwp-multi-001.hwp` page count 변화는 이번 Stage 4에서 원인 분석까지 포함하지 않았다. 후속 visual suite 또는 별도 smoke 정리에서 확인해야 한다.

## 다음 단계 영향

Stage 5에서는 #390 최종 보고서를 작성하고 오늘할일을 완료 처리한다. 최종 보고서에는 `Skia default 전환 보류`, `#396/#392/#389 우선`, `#393 opt-in 제한`, `#394 별도 UX 개선`을 후속 관계로 정리한다.

## 승인 요청

Stage 4 결과에 따라 Stage 5 `최종 보고서와 PR 정리`로 진행해도 되는지 승인 요청한다.
