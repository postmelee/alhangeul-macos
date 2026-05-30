# Task M020 #259 최종 보고서

## 작업 요약

| 항목 | 내용 |
|---|---|
| 이슈 | #259 Skia backend visual/performance/package regression gate 정리 |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task259` |
| 기준 core | `rhwp v0.7.13` |
| resolved commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` |

결론:

- Quick Look 기본 backend는 CoreGraphics/native path로 복귀했다.
- Skia backend는 제거하지 않고 `.skiaOptIn` opt-in 경로, CoreGraphics fallback, diagnostics, smoke helper를 유지했다.
- Finder Thumbnail은 이미 CoreGraphics 기본이므로 이번 release 기본 surface는 Quick Look/Thumbnail 모두 CoreGraphics 기준으로 다시 일관된다.
- #258은 이번 release 전 필수 작업에서 제외하고, 후속 Skia thumbnail opt-in/cache diagnostic 설계 이슈로 재범위화하는 것이 맞다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|---|---|
| `Sources/QLExtension/HwpPreviewProvider.swift` | Quick Look 단일 PNG와 다중 PDF preview 호출부의 policy를 `.skiaOptIn`에서 `.coreGraphicsOnly`로 변경 |
| `mydocs/plans/task_m020_259.md` | 수행계획서 작성 |
| `mydocs/plans/task_m020_259_impl.md` | 단계별 구현계획서 작성 |
| `mydocs/working/task_m020_259_stage1.md` | 선행 산출물과 현재 backend 정책 inventory |
| `mydocs/working/task_m020_259_stage2.md` | visual/performance/package gate 측정 결과 |
| `mydocs/working/task_m020_259_stage3.md` | release policy 판정과 source 보정 결과 |
| `mydocs/orders/20260530.md` | #259 완료 처리 |
| `mydocs/report/task_m020_259_report.md` | 최종 보고서 |

Source 변경은 Quick Look provider의 policy 2곳으로 제한했다. `Sources/RhwpCoreBridge`는 변경하지 않았다.

## 단계별 결과

| Stage | 커밋 | 결과 |
|---|---|---|
| 계획 | `198adba` | 수행계획서와 오늘할일 등록 |
| 구현계획 | `7b54634` | Stage 1-4 계획과 판정 기준 작성 |
| Stage 1 | `c5bfc9e` | #255/#256/#257/#278 입력과 현재 backend 정책 inventory |
| Stage 2 | `c019850` | Quick Look policy smoke, visual diff, package size 측정 |
| Stage 3 | `63d11e8` | Quick Look 기본을 CoreGraphics로 복귀, Skia opt-in 유지 |
| Stage 4 | 현재 | 최종 보고서와 오늘할일 완료 처리 |

## Stage 1 inventory 결론

현재 코드와 선행 산출물 기준으로 확인한 정책은 다음과 같았다.

| Surface | Stage 1 당시 정책 | 의미 |
|---|---|---|
| Quick Look 단일 PNG | `.skiaOptIn` | Skia 우선 |
| Quick Look 다중 PDF | `.skiaOptIn` | page별 Skia 우선 |
| Finder Thumbnail | `renderFirstPage` 기본값 | CoreGraphics 기본 |
| Shared renderer | 기본값 `.coreGraphicsOnly`, 명시 opt-in `.skiaOptIn` | default와 opt-in 분리 가능 |

이 상태에서는 Quick Look과 Thumbnail의 기본 backend가 갈라진다. 따라서 #258로 Thumbnail까지 Skia를 확장하기 전에 #259에서 release gate를 먼저 판정해야 한다고 정리했다.

## Stage 2 측정 결과

### Package size

| 기준 | `librhwp.a` size | 변화 |
|---|---:|---:|
| #255 이전 | 108,417,040 bytes | - |
| #255 native-skia 반영 | 190,410,384 bytes | +81,993,344 bytes |
| #278 v0.7.13 반영 후 현재 | 203,436,808 bytes | #255 이전 대비 +95,019,768 bytes |

현재 `du -sh` 기준 `Frameworks/universal/librhwp.a`와 `Frameworks/Rhwp.xcframework`는 모두 `194M`이다.

### Quick Look policy smoke

| File | Reply | Pages | CG sec | Skia sec | Skia fallback |
|---|---|---:|---:|---:|---:|
| `request.hwp` | png | 1 | 1.073779 | 0.069324 | 0 |
| `hwpx-01.hwpx` | pdf | 9 | 0.376997 | 0.617429 | 0 |
| `복학원서.hwp` | png | 1 | 0.160401 | 0.065900 | 0 |
| `KTX.hwp` | png | 1 | 0.069717 | 0.071174 | 0 |
| `hwp-multi-001.hwp` | pdf | 10 | 0.390930 | 0.666077 | 0 |

fallback은 0으로 안정적이었다. 그러나 다중 PDF 샘플 2개에서는 Skia가 CoreGraphics보다 느렸다.

### Visual diff

| File | CG changed | Skia changed | Delta pp | CG mean RGB | Skia mean RGB | CG ms | Skia ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| `request.hwp` | 17.8542% | 12.8683% | -4.9859 | 11.0716 | 10.1453 | 1016.7 | 5460.6 |
| `hwpx-01.hwpx` | 15.0285% | 14.6452% | -0.3833 | 15.2088 | 16.0791 | 33.8 | 69.2 |
| `복학원서.hwp` | 32.0188% | 6.4738% | -25.5450 | 18.2116 | 7.2558 | 157.6 | 61.1 |
| `KTX.hwp` | 31.1362% | 47.1389% | +16.0027 | 13.6308 | 22.5798 | 52.3 | 65.3 |
| `hwp-multi-001.hwp` | 14.8327% | 14.3340% | -0.4987 | 14.8651 | 15.7946 | 29.2 | 66.3 |

Skia는 `복학원서.hwp`에서 큰 개선을 보였지만, `KTX.hwp`에서는 크게 악화됐다. `request.hwp`는 visual diff가 개선됐지만 Skia native render time이 5초대로 측정됐다.

## 최종 backend 정책

| Surface | 최종 정책 | 설명 |
|---|---|---|
| Quick Look 단일 PNG | `.coreGraphicsOnly` | release 기본 preview는 CoreGraphics/native renderer 사용 |
| Quick Look 다중 PDF | `.coreGraphicsOnly` | 다중 page bitmap PDF도 CoreGraphics/native renderer 사용 |
| Finder Thumbnail | `.coreGraphicsOnly` 기본값 유지 | 기존 default 유지 |
| Skia backend | `.skiaOptIn` 유지 | helper, diagnostic, 후속 실험에서 명시 opt-in |

변경 후 Quick Look provider는 source에서 `.coreGraphicsOnly`를 명시한다. Shared renderer는 여전히 Skia opt-in과 fallback contract를 제공한다.

## Readiness checklist

| 항목 | 상태 | 근거 |
|---|---|---|
| Skia ABI 포함 | 준비됨 | `rhwp_render_page_png`와 status/fallback contract 유지 |
| Skia opt-in smoke | 준비됨 | `smoke-quicklook-skia-policy.sh` 유지, Stage 3 smoke fallback 0 |
| Quick Look default Skia | 보류 | visual/latency/package gate가 default 기준을 만족하지 못함 |
| Quick Look default CoreGraphics | 준비됨 | Stage 3에서 source 보정, QLExtension build 통과 |
| Thumbnail default Skia | 보류 | #258 재범위화 필요 |
| Release package size 해석 | 주의 필요 | native-skia 포함으로 staticlib가 #255 이전 대비 약 95 MB 증가 |
| 설치본 Quick Look UI smoke | 후속 package/release smoke | 이번 작업은 helper/build 중심 |

Release 후보로는 `CoreGraphics default + Skia optional backend` 상태가 가장 깔끔하다.

## release note 후보

```text
Quick Look preview 기본 렌더링 경로를 안정적인 CoreGraphics/native renderer로 유지했습니다.
Skia 기반 native PNG renderer는 opt-in 진단 경로로 남겨 두었으며, fallback과 backend diagnostics를 통해 후속 품질/성능 개선을 계속 검증할 수 있습니다.
```

## known limitation 후보

```text
Skia renderer는 일부 문서에서 reference 대비 visual diff를 크게 줄이지만, 문서별 품질 편차와 다중 페이지 preview 성능 편차가 남아 있어 이번 release에서는 기본 경로로 사용하지 않습니다.
Finder Thumbnail의 Skia 적용은 기본 release 범위에서 제외되며, 후속 cache key/backend signature 설계와 함께 재검토합니다.
```

## #258 handoff

#258은 기존 "Finder thumbnail Skia 적용" 범위 그대로 release 전 필수로 진행하지 않는다. 후속으로 이어간다면 다음 범위로 재정의하는 것이 맞다.

| 항목 | 권장 처리 |
|---|---|
| 목적 | Thumbnail Skia default 적용이 아니라 opt-in diagnostic/cache 설계 |
| cache key | backend policy, pixel bucket, render option signature 포함 |
| 성능 gate | first render latency와 repeated thumbnail cache hit/miss 분리 |
| visual gate | `KTX.hwp` 악화 사례와 `복학원서.hwp` 개선 사례를 모두 포함 |
| release 조건 | Quick Look default Skia 재검토 전까지 Thumbnail default Skia도 보류 |

## PR summary 후보

```text
## Summary
- Quick Look Skia readiness gate를 정리하고 visual/performance/package 측정 결과를 문서화했습니다.
- Stage 2 결과에 따라 Quick Look 기본 backend를 CoreGraphics/native path로 되돌렸습니다.
- Skia opt-in renderer, fallback diagnostics, policy smoke helper는 유지했습니다.
- #258은 release 전 필수 default 전환 작업이 아니라 후속 thumbnail opt-in/cache diagnostic 설계로 재범위화하는 결론을 남겼습니다.

## Verification
- ./scripts/build-rust-macos.sh --verify-lock
- ./scripts/verify-rhwp-studio-assets.sh
- ./scripts/check-no-appkit.sh
- ./scripts/smoke-quicklook-skia-policy.sh build.noindex/task259-skia-policy ...
- ./scripts/preview-visual-diff-harness.sh build.noindex/task259-visual-cg ...
- ./scripts/preview-visual-diff-harness.sh build.noindex/task259-visual-skia --policy skiaOptIn ...
- xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
- xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
- xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedData-task259 CODE_SIGNING_ALLOWED=NO build
- git diff --check
```

## 최종 검증

Stage 2-3에서 실행한 검증:

| 검증 | 결과 |
|---|---|
| `./scripts/build-rust-macos.sh --verify-lock` | 통과 |
| `./scripts/verify-rhwp-studio-assets.sh` | 통과 |
| `./scripts/check-no-appkit.sh` | 통과 |
| Quick Look policy smoke | 통과, fallback 0 |
| CoreGraphics visual diff harness | sandbox 밖 재실행 통과 |
| Skia visual diff harness | sandbox 밖 재실행 통과 |
| `xcodebuild ... QLExtension ... build` | 통과 |
| `xcodebuild ... HostApp ... build` | 통과 |
| `xcodebuild ... ThumbnailExtension ... build` | 통과 |
| `git diff --check` | 통과 |

검증 중 sandbox 제약:

- `xcodebuild`는 sandbox 내부에서 Sparkle clone network 제한 또는 SwiftPM/clang cache 쓰기 제한으로 실패한 뒤 sandbox 밖에서 통과했다.
- visual diff harness는 WKWebView/rhwp-studio readiness 단계에서 sandbox extension 오류가 나서 sandbox 밖에서 통과했다.

## 잔여 위험

| 항목 | 내용 |
|---|---|
| Skia package size | 기본 경로가 CoreGraphics여도 native-skia feature와 artifact size는 현재 포함되어 있다. 배포 package size는 release smoke에서 계속 확인해야 한다. |
| Skia 품질 편차 | `복학원서.hwp` 개선과 `KTX.hwp` 악화가 공존한다. default 재검토 전 원인 분석이 필요하다. |
| first/render cost | `request.hwp`에서 visual diff harness 기준 Skia 5초대 native render time이 남아 있다. |
| 설치본 smoke | 이번 #259는 build/helper smoke 중심이다. 실제 배포 전 signed Release package smoke는 별도 release 절차에서 수행한다. |

## 결론

#259는 Skia backend를 release default로 둘지 판단하기 위한 gate 작업을 완료했다. 현재 측정 기준으로는 Skia를 Quick Look 기본 경로로 유지하기 어렵고, CoreGraphics/native renderer를 기본으로 두는 편이 release 후보로 더 깔끔하다.

최종 상태는 `Quick Look/Thumbnail default = CoreGraphics`, `Skia = opt-in diagnostic backend`이다. 이 상태로 v0.2.x release 준비를 진행하고, #258은 후속 Skia thumbnail opt-in/cache diagnostic 설계로 재범위화하는 것을 권장한다.
