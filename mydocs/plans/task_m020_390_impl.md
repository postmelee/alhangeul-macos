# Task M020 #390 구현계획서

수행계획서: `mydocs/plans/task_m020_390.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #390 `rhwp v0.7.17` 기준 Skia readiness gate 재측정
- 추적 이슈: #387 Preview/Thumbnail Skia readiness 후속 개선 추적
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task390`
- 목표: #259의 `v0.7.13` 기준 Skia visual/performance/package 판단을 현재 `rhwp v0.7.17` core/studio 기준으로 재측정하고, Quick Look/Thumbnail surface별 후속 작업 조건을 정리한다.

## 구현 원칙

- #390은 측정과 판단 기록 작업이다. 제품 renderer 정책, Skia default 여부, cache policy를 변경하지 않는다.
- `CoreGraphics default + Skia opt-in diagnostic backend`라는 현재 정책을 기준으로 양쪽 결과를 비교한다.
- #388에서 정리한 `RhwpCoreBuildInfo`와 Thumbnail render signature 정합성을 readiness 측정의 선행 조건으로 본다.
- #394의 strict static archive byte hash UX 문제는 이번 작업의 blocker가 아니다. source/header/ABI 중심 검증과 static archive byte hash mismatch는 분리해 기록한다.
- visual diff 숫자 하나로 default 전환을 판단하지 않는다. `ChangedPercent`, `MeanRGBDelta`, `NativeMs`, fallback, output bytes, package size, sample 성격을 함께 본다.
- WebKit/rhwp-studio reference capture 실패와 renderer 회귀를 혼동하지 않는다. sandbox/WebKit readiness 실패가 나오면 실패 phase를 기록하고 승인 경로 재실행으로 분리한다.
- 측정 도구 결함이나 제품 코드 보정 필요성이 발견되면 즉시 별도 승인 또는 후속 이슈로 분리한다.

## 측정 기준

### 기본 샘플 세트

| 샘플 | 용도 |
|------|------|
| `samples/basic/request.hwp` | #259에서 Skia latency 변동과 visual 개선이 함께 관찰된 기본 HWP |
| `samples/basic/KTX.hwp` | #259에서 Skia visual regression이 컸던 HWP |
| `samples/복학원서.hwp` | #259에서 Skia visual diff가 크게 개선된 watermark 계열 HWP |
| `samples/hwp-multi-001.hwp` | Quick Look 다중 PDF 성능과 page 반복 경로 |
| `samples/hwpx/hwpx-01.hwpx` | HWPX 다중 PDF/visual 기준 |

### 주요 비교 항목

| 항목 | 기록 방식 |
|------|-----------|
| core/studio provenance | `rhwp-core.lock`, `RhwpCoreBuildInfo`, rhwp-studio manifest |
| Quick Look policy smoke | reply type, pages, CoreGraphics seconds, Skia seconds, fallback count |
| Thumbnail policy smoke | policy별 cache event, bucket reuse, backend, fallback, render ms, signature |
| Visual diff | `ChangedPercent`, `MeanRGBDelta`, `MaxRGBDelta`, `DiffBounds`, `NativeBackend`, `NativeMs` |
| package/static artifact | `Frameworks/universal/librhwp.a`, `Frameworks/Rhwp.xcframework` size |
| #259 대비 delta | `v0.7.13` 기준 표와 `v0.7.17` 측정값의 방향성 비교 |

## Stage 1. 기준 inventory와 측정 설계 확정

### 목표

#259, #388, current `rhwp-core.lock` 기준을 하나로 정렬하고, Stage 2-3에서 실행할 측정 명령과 sample set을 확정한다.

### 대상

- `rhwp-core.lock`
- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- `mydocs/report/task_m020_259_report.md`
- `mydocs/report/task_m020_388_report.md`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md`
- `scripts/smoke-quicklook-skia-policy.sh`
- `scripts/smoke-thumbnail-skia-policy.sh`
- `scripts/preview-visual-diff-harness.sh`
- `mydocs/working/task_m020_390_stage1.md`

### 작업

1. current core/studio provenance를 확인한다.
2. #388 보고서에서 current Thumbnail signature 전제와 #390 handoff를 추출한다.
3. #259 보고서에서 `v0.7.13` 기준 Quick Look smoke, visual diff, package size, final policy 결론을 추출한다.
4. 세 measurement script의 입력/출력 형식과 summary 위치를 확인한다.
5. 기본 샘플 파일 존재 여부와 다중 page/단일 page 분류를 확인한다.
6. Stage 1 보고서에 Stage 2-3 실행 명령, 산출물 경로, 비교표 template을 고정한다.

### 검증

```bash
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
rg -n "v0\\.7\\.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia" \
  rhwp-core.lock Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift \
  Sources/HostApp/Resources/rhwp-studio/manifest.json
rg -n "request\\.hwp|KTX\\.hwp|복학원서\\.hwp|hwp-multi-001\\.hwp|hwpx-01\\.hwpx|changed|fallback|NativeMs|package" \
  mydocs/report/task_m020_259_report.md mydocs/report/task_m020_388_report.md \
  mydocs/working/task_m020_390_stage1.md
test -f samples/basic/request.hwp
test -f samples/basic/KTX.hwp
test -f samples/복학원서.hwp
test -f samples/hwp-multi-001.hwp
test -f samples/hwpx/hwpx-01.hwpx
git diff --check
```

### 완료 조건

- `v0.7.17` 기준 측정 전제가 Stage 1 보고서에 정리되어 있다.
- #259와 비교할 표의 컬럼과 sample set이 확정되어 있다.
- Stage 2-3 명령과 산출물 경로가 확정되어 있다.

### 커밋 메시지

```text
Task #390 Stage 1: Skia readiness 측정 기준 inventory
```

## Stage 2. Quick Look/Thumbnail policy smoke 재측정

### 목표

current `v0.7.17` 기준으로 Quick Look과 Thumbnail의 CoreGraphics/Skia opt-in smoke 결과를 측정하고, fallback과 latency, output bytes, Thumbnail signature/cache behavior를 기록한다.

### 대상

- `build.noindex/task390-skia-policy/`
- `build.noindex/task390-thumbnail-policy/`
- `mydocs/working/task_m020_390_stage2.md`

### 작업

1. 기본 검증 command를 실행해 core/studio/build boundary를 확인한다.
2. Quick Look policy smoke를 기본 샘플 5개로 실행한다.
3. Thumbnail policy smoke를 단일 page 중심 샘플 3개로 실행한다.
4. Quick Look summary에서 reply type, page count, CG/Skia seconds, fallback count를 추출한다.
5. Thumbnail summary에서 policy별 cache event, backend, fallback, render ms, signature를 추출한다.
6. #259 smoke 결과와 `v0.7.17` 측정값의 방향 차이를 Stage 2 보고서에 기록한다.

### 검증

```bash
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task390-skia-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task390-thumbnail-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp
rg -n "fallback|Fallback|Signature|v0\\.7\\.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia|failed=0|OK" \
  build.noindex/task390-skia-policy build.noindex/task390-thumbnail-policy \
  mydocs/working/task_m020_390_stage2.md
git diff --check
```

### 완료 조건

- Quick Look 기본 샘플 5개 결과가 report에 있다.
- Thumbnail 기본 샘플 3개 결과가 report에 있다.
- fallback count와 실패 여부가 명확하다.
- Thumbnail signature가 #388 기준 current core metadata를 포함한다.

### 커밋 메시지

```text
Task #390 Stage 2: Quick Look Thumbnail Skia smoke 재측정
```

## Stage 3. visual diff harness 재측정

### 목표

rhwp-studio reference 대비 CoreGraphics와 Skia opt-in visual diff를 같은 샘플 세트로 다시 측정하고, #259 대비 개선/악화 방향을 정리한다.

### 대상

- `build.noindex/task390-visual-cg/`
- `build.noindex/task390-visual-skia/`
- `mydocs/working/task_m020_390_stage3.md`

### 작업

1. CoreGraphics policy visual diff harness를 실행한다.
2. Skia opt-in policy visual diff harness를 실행한다.
3. 각 `summary.md`에서 `ChangedPercent`, `MeanRGBDelta`, `NativeBackend`, `NativeMs`를 추출한다.
4. hard fail, reference capture failure, renderer failure를 구분한다.
5. #259 `v0.7.13` visual diff 표와 비교해 sample별 delta를 정리한다.
6. Stage 3 보고서에는 숫자뿐 아니라 `KTX.hwp`, `복학원서.hwp`, `request.hwp`의 방향성이 유지/변경됐는지 해석한다.

### 검증

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task390-visual-cg --page 1 \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task390-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
rg -n "FAIL|OK|ChangedPercent|MeanRGBDelta|NativeBackend|NativeMs|fallback|readiness timed out|WKErrorDomain" \
  build.noindex/task390-visual-cg build.noindex/task390-visual-skia \
  mydocs/working/task_m020_390_stage3.md
git diff --check
```

### 완료 조건

- CoreGraphics와 Skia opt-in visual diff summary가 모두 생성되어 있다.
- 실패가 있으면 phase와 원인을 renderer 문제와 실행 환경 문제로 분리했다.
- #259 대비 sample별 visual direction이 정리되어 있다.

### 커밋 메시지

```text
Task #390 Stage 3: Skia visual diff 재측정
```

## Stage 4. package/build gate와 readiness 판단 정리

### 목표

Stage 1-3 측정값을 종합해 surface별 readiness 판단을 정리하고, 현재 default 유지/후속 실험 조건을 명확히 한다.

### 대상

- `Alhangeul.xcodeproj/project.pbxproj` (xcodegen 결과가 바뀌는 경우만)
- `mydocs/working/task_m020_390_stage4.md`
- 필요 시 `mydocs/tech/skia_quicklook_thumbnail_backend.md`

### 작업

1. static artifact size를 기록한다.
2. `xcodegen generate`를 실행하고 diff 여부를 확인한다.
3. QLExtension과 ThumbnailExtension Debug build를 실행한다.
4. Stage 2-3 결과를 surface별로 종합한다.
   - Quick Look 단일 PNG
   - Quick Look 다중 PDF
   - Finder Thumbnail
5. #389, #392, #393, #391, #394 중 어떤 후속이 measurement 결과상 우선인지 정리한다.
6. 필요 시 기술 문서에 current readiness 요약을 추가하되, 단순 중복이면 최종 보고서로만 남긴다.

### 검증

```bash
du -sh Frameworks/universal/librhwp.a Frameworks/Rhwp.xcframework
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task390 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task390 CODE_SIGNING_ALLOWED=NO build
rg -n "#389|#391|#392|#393|#394|Quick Look|Thumbnail|CoreGraphics|Skia|readiness|fallback|package" \
  mydocs/working/task_m020_390_stage4.md
git diff --check
git status --short
```

### 완료 조건

- package/static artifact size가 기록되어 있다.
- QLExtension과 ThumbnailExtension build가 통과한다.
- Quick Look/Thumbnail surface별 default 유지 또는 후속 실험 조건이 명확하다.
- 후속 이슈 우선순위가 측정 근거와 연결되어 있다.

### 커밋 메시지

```text
Task #390 Stage 4: Skia readiness 판단 정리
```

## Stage 5. 최종 보고서와 PR 정리

### 목표

#390 결과를 최종 보고서로 정리하고 PR 게시 준비를 완료한다.

### 대상

- `mydocs/report/task_m020_390_report.md`
- `mydocs/orders/20260629.md`
- 필요 시 `mydocs/working/task_m020_390_stage5.md`

### 작업

1. 최종 보고서에 작업 요약, 변경 파일 목록, #259 대비 정량 비교, 검증 결과, 잔여 위험, 후속 작업을 표로 정리한다.
2. 오늘할일 #390 상태를 완료 처리한다.
3. PR body에 Stage별 요약, 핵심 리뷰 포인트, 검증 결과, 후속 이슈를 정리한다.
4. PR 게시 전 `git status`, `git diff --check`, branch log를 확인한다.

### 검증

```bash
rg -n "#390|#387|#389|#391|#392|#393|#394|v0\\.7\\.17|Skia|CoreGraphics|Quick Look|Thumbnail|readiness" \
  mydocs/report/task_m020_390_report.md mydocs/orders/20260629.md
git diff --check
git status --short --branch
git log --oneline devel..local/task390
```

### 완료 조건

- 최종 보고서가 존재하고 #259 대비 `v0.7.17` 재측정 결론을 포함한다.
- 오늘할일 #390이 완료 상태다.
- PR 게시 준비가 가능하다.

### 커밋 메시지

```text
Task #390 Stage 5 + 최종 보고서: Skia readiness 재측정 정리
```
