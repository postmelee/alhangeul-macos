# Task M020 #389 Stage 2 완료 보고서

## 단계 목적

Thumbnail provider에 DEBUG/internal opt-in policy resolver를 추가하고, provider 성공 로그가 cache/backend/fallback 진단 값을 포함하도록 구현한다.

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Sources/ThumbnailExtension/HwpThumbnailPolicyResolver.swift` | 신규 resolver 추가. `ALHANGEUL_THUMBNAIL_RENDER_POLICY` env 값을 DEBUG 빌드에서만 해석 |
| `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | resolver 결과를 render request policy로 전달하고 `renderedPageResult(for:)` 결과를 로그에 사용 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 신규 resolver source를 ThumbnailExtension target source phase에 반영 |
| `mydocs/orders/20260701.md` | Stage 2 완료보고서 승인 대기 상태로 갱신 |

## resolver 동작

`HwpThumbnailPolicyResolver`는 다음 contract로 구현했다.

| 입력 | DEBUG 결과 | Release 결과 |
|------|------------|--------------|
| missing/empty/invalid | `.coreGraphicsOnly` | `.coreGraphicsOnly` |
| `coreGraphics` | `.coreGraphicsOnly` | `.coreGraphicsOnly` |
| `coreGraphicsOnly` | `.coreGraphicsOnly` | `.coreGraphicsOnly` |
| `skia` | `.skiaOptIn` | `.coreGraphicsOnly` |
| `skiaOptIn` | `.skiaOptIn` | `.coreGraphicsOnly` |

값 비교는 trim, lowercase, `-`/`_` 제거 후 수행한다. display identifier helper는 `coreGraphicsOnly`, `skiaOptIn` 문자열을 반환한다.

## provider 변경

`HwpThumbnailProvider.provideThumbnail`의 public reply/fallback shape는 유지했다.

변경된 흐름:

1. request 시작 시 `HwpThumbnailPolicyResolver.resolve()`로 policy를 결정한다.
2. `HwpThumbnailRenderRequest(fileURL:maximumSize:scale:policy:)`에 policy를 전달한다.
3. 기존 `renderedPage(for:)` 대신 `renderedPageResult(for:)`를 호출한다.
4. success log에 다음 값을 포함한다.
   - `policy`
   - `cache`
   - `requestedBucket`
   - `matchedBucket`
   - `backend`
   - `fallback`
   - `renderMs`
   - `pixels`
   - `context`
   - `page`
5. fallback/failure log에도 `policy`를 포함한다.

Cache source는 변경하지 않았다. Stage 1에서 확인한 대로 cache는 이미 policy/render signature별 key와 `HwpThumbnailRenderResult`를 제공하고 있어 provider logging에서 소비하는 것으로 충분했다.

## project 반영

`project.yml`은 `Sources/ThumbnailExtension` directory source를 포함한다. 신규 Swift source를 실제 Xcode project에 반영하기 위해 `xcodegen generate`를 실행했고, 생성된 `Alhangeul.xcodeproj/project.pbxproj`에는 `HwpThumbnailPolicyResolver.swift` source phase 추가만 반영되었다.

`scripts/smoke-thumbnail-skia-policy.sh`의 manual compile list는 Stage 2에서 변경하지 않았다. Stage 3에서 smoke runner가 resolver contract를 직접 검증하게 되면 compile list에 resolver source를 추가한다.

## 검증 결과

실행:

```bash
./scripts/check-no-appkit.sh
git diff --check
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask389Stage2 CODE_SIGNING_ALLOWED=NO build
rg -n "HwpThumbnailPolicyResolver|ALHANGEUL_THUMBNAIL_RENDER_POLICY|renderedPageResult|cache|backend|fallback|coreGraphicsOnly|skiaOptIn" \
  Sources/ThumbnailExtension mydocs/working/task_m020_389_stage2.md
```

결과:

- `check-no-appkit`: 성공. shared Swift code에 AppKit/UIKit 의존 없음.
- `git diff --check`: 성공.
- `xcodegen generate`: 성공.
- `xcodebuild`: 성공. `BUILD SUCCEEDED`.
- `rg`: 신규 resolver, env key, provider `renderedPageResult`, cache/backend/fallback 로그 항목 확인.

`xcodebuild` 중 CoreSimulator framework 버전 경고가 출력되었지만, macOS target build는 성공했다.

## 잔여 위험

- Release에서 env opt-in이 차단되는지는 source의 `#if DEBUG` 경계로 보장한다. Release build smoke는 이번 Stage 2 범위에 포함하지 않았다.
- provider OSLog는 smoke summary 파일이 아니므로, Stage 3에서 smoke helper가 resolver contract와 cache/backend/fallback column을 별도로 검증하도록 보강한다.
- 정상 샘플에서는 `fallback=-`가 기대값일 수 있다. forced fallback fixture는 이번 작업 완료 조건에 넣지 않는다.

## 완료 조건 확인

- provider 기본 policy는 CoreGraphics로 유지된다.
- DEBUG/internal env opt-in path가 source상 명확하다.
- provider success log에 cache/backend/fallback 진단 값이 들어간다.
- public reply/fallback 동작은 변경하지 않았다.

## 승인 요청

Stage 2는 완료했다. Stage 3 `smoke/helper와 resolver 검증 보강`으로 진행해도 되는지 승인 요청한다.
