# Issue #22 최종 보고서

## 개요

Issue #22는 배포 준비 관점에서 `rhwp` 코어 소싱/FFI 결합 구조를 정리하고, Finder thumbnail 동작과 관련된 실사용 이슈를 함께 정리하는 작업이다.

이번 작업에서 실제로 달성한 목표는 다음과 같다.

- macOS 네이티브 브리지가 `wasm_api` 어댑터가 아니라 `DocumentCore`에 직접 붙도록 정리했다.
- Thumbnail 전용 embedded preview fast path를 FFI와 Swift bridge에 추가했다.
- Finder thumbnail이 실제 설치본 기준으로 동작하도록 bundle path, 설치/등록 경로를 정리했다.
- small-size thumbnail 제한을 제거해 `16pt` 같은 작은 요청도 extension이 직접 처리하도록 바꿨다.
- thumbnail 경로의 `MainActor` 병목, 요청당 재계산, 중복 렌더 문제를 줄이기 위한 성능 최적화를 적용했다.
- 후속 분석을 통해 Finder grouped icon view 버벅임의 근본 원인은 앱 extension이 아니라 Finder 보기 모드 자체일 가능성이 높다는 점을 문서화하고, `Feedback Assistant` 제출용 문서까지 정리했다.

즉, 이번 타스크는 단순한 FFI 정리에서 끝나지 않고, 실제 배포/운영에 필요한 Finder 통합 문제와 원인 분리까지 포함한 안정화 작업으로 마무리됐다.

## 주요 변경

### 1. Rust FFI와 코어 결합 구조 정리

- `RustBridge/src/lib.rs`에서 `rhwp::wasm_api::HwpDocument` 의존을 제거하고 `rhwp::DocumentCore` 직접 결합으로 전환했다.
- 기존 C ABI 심볼 집합은 최대한 유지해 Swift 상위 계층의 충격을 줄였다.
- 이 변경으로 macOS 앱 브리지가 WASM 래퍼 변경에 덜 종속되게 됐다.

### 2. Thumbnail fast path 추가

- `rhwp_extract_thumbnail`과 `rhwp_free_bytes`를 추가했다.
- HWP/HWPX 내부 embedded preview를 전체 문서 렌더 없이 읽을 수 있는 thumbnail 전용 FFI 표면을 마련했다.
- Swift 쪽에서는 `RhwpDocument.extractEmbeddedThumbnail(from:)`로 이 경로를 감싸 raw pointer 수명 규칙을 bridge 내부로 숨겼다.

### 3. Swift thumbnail 호출 경로 정리

- `Sources/Shared/HwpPageImageRenderer.swift`를 `embedded preview 우선 -> 실패 시 기존 render tree 첫 페이지 렌더 fallback` 정책으로 바꿨다.
- large file에서도 embedded preview가 있으면 먼저 fast path를 타도록 조정했다.
- Viewer와 Quick Look은 기존 render tree 중심 구조를 유지했다.

### 4. 실제 Finder 동작을 위한 설치/등록 경로 정리

- `project.yml`과 각 `Info.plist`를 조정해 실제 bundle path는 ASCII, 표시명은 한글로 분리했다.
- `HostApp.entitlements`에 sandbox/read-only entitlement를 반영했다.
- 설치본은 `~/Applications/RhwpMac.app`로 고정하고, build 산출물은 `.app.disabled`로 내려 LaunchServices/Quick Look이 중복 discovery하지 않도록 운영 규칙을 맞췄다.

이 변경으로 `pluginkit`과 `qlmanage` 기준의 실제 Finder thumbnail 동작이 안정화됐다.

### 5. small-size thumbnail 지원

- `Sources/ThumbnailExtension/Info.plist`에서 `QLThumbnailMinimumDimension = 64`를 제거했다.
- 그 결과 작은 아이콘 크기에서도 thumbnail extension이 직접 호출되도록 바뀌었다.
- 사용자 제보 파일 3개 모두 `16pt` 요청에서 `produced one thumbnail`을 확인했다.

### 6. thumbnail 성능 경로 최적화

- `RhwpDocument`, `CGTreeRenderer`, `HwpPageImageRenderer`의 `@MainActor` 고정을 제거했다.
- 요청 크기 기반 size-aware 렌더를 도입했다.
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`를 추가해 cache와 in-flight dedupe를 넣었다.
- `HwpThumbnailProvider`는 더 이상 `Task { @MainActor in ... }`를 사용하지 않는다.

이 변경으로 HWP가 많은 폴더에서 thumbnail 경로가 메인 액터를 직접 점유하고 같은 파일을 반복 렌더하던 구조적 병목은 제거됐다.

### 7. Finder grouped icon view 문제 원인 분리와 Apple 제출 문서 정리

- 후속 분석 결과 `.hwp` / `.hwpx`가 전혀 없는 `Desktop` 폴더에서도 `아이콘 보기 + 최근 사용일 그룹 + 2축 스크롤` 조합에서 같은 버벅임이 재현됐다.
- 따라서 Finder 스크롤 버벅임의 근본 원인을 우리 HWP thumbnail extension으로 단정할 수 없음을 확인했다.
- 이 문제를 Apple에 바로 제출할 수 있도록 아래 문서를 작성했다.
  - `mydocs/troubleshootings/finder_icon_view_recent_opened_scroll_feedback_assistant.md`

## 산출물

- 코드/설정
  - `RustBridge/src/lib.rs`
  - `Sources/RhwpCoreBridge/RhwpDocument.swift`
  - `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
  - `Sources/Shared/HwpPageImageRenderer.swift`
  - `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
  - `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
  - `Sources/ThumbnailExtension/Info.plist`
  - `Sources/HostApp/HostApp.entitlements`
  - `Sources/HostApp/Info.plist`
  - `Sources/QLExtension/Info.plist`
  - `project.yml`
  - `rhwp-ffi-symbols.txt`
- 문서
  - `mydocs/orders/20260423.md`
  - `mydocs/plans/task_m050_22.md`
  - `mydocs/plans/task_m050_22_impl.md`
  - `mydocs/working/task_m050_22_stage1.md`
  - `mydocs/working/task_m050_22_stage2.md`
  - `mydocs/working/task_m050_22_stage3.md`
  - `mydocs/working/task_m050_22_stage4.md`
  - `mydocs/working/task_m050_22_stage5.md`
  - `mydocs/working/task_m050_22_stage6.md`
  - `mydocs/working/task_m050_22_stage7.md`
  - `mydocs/troubleshootings/finder_icon_view_recent_opened_scroll_feedback_assistant.md`
  - `mydocs/report/task_m050_22_report.md`

## 검증 결과

### 1. Rust/FFI 산출물 검증

- `./scripts/build-rust-macos.sh`
  - arm64/x86_64 staticlib 빌드 성공
  - universal staticlib 생성 성공
  - `cbindgen` header 및 `rhwp-ffi-symbols.txt` 비교 통과
  - `Rhwp.xcframework` 재생성 성공

### 2. Shared Swift bridge 경계 검증

- `./scripts/check-no-appkit.sh`
  - 결과: `OK: shared Swift code has no AppKit/UIKit dependencies`

### 3. Xcode/앱 빌드 검증

- `xcodegen generate`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build/DerivedDataReleaseSigned CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES build`

### 4. Finder thumbnail 검증

- `pluginkit -a /Users/melee/Applications/RhwpMac.app`
- `pluginkit -mAvvv -D -i com.postmelee.rhwpmac.ThumbnailExtension`
  - 활성 경로:
    - `/Users/melee/Applications/RhwpMac.app/Contents/PlugIns/RhwpMacThumbnail.appex`
- `qlmanage -r`
- `qlmanage -r cache`
- `qlmanage -t -x -s 512 -o /tmp Vendor/rhwp/samples/basic/KTX.hwp`
  - 결과: `produced one thumbnail`
- 사용자 제보 파일 3종에 대한 `16pt` thumbnail 검증
  - 결과: 모두 `produced one thumbnail`
- 대표 파일의 `32pt`, `64pt` 추가 검증
  - 결과: 모두 `produced one thumbnail`

### 5. render smoke test

- `./scripts/validate-stage3-render.sh output/stage3-render-20260424`
  - `KTX.hwp`: `page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455`
  - `request.hwp`: `page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724`
  - `exam_kor.hwp`: `page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464`

### 6. 문서/패치 형식 검증

- `git diff --check`
  - 형식 오류 없음

## 최종 판단

이번 작업으로 정리된 결론은 다음과 같다.

1. macOS 앱의 FFI 결합 구조는 더 이상 `wasm_api` 어댑터에 기대지 않고 `DocumentCore` 중심으로 정리됐다.
2. Thumbnail은 embedded preview fast path와 render fallback을 함께 가지는 구조가 됐다.
3. 작은 아이콘 크기에서 썸네일이 안 보이던 직접 원인은 `QLThumbnailMinimumDimension` 설정이었고, 이 제한은 제거됐다.
4. HWP thumbnail 경로의 `MainActor` 병목과 반복 렌더 비용은 코드 수준에서 줄였다.
5. 다만 Finder의 grouped icon view 버벅임은 `.hwp`가 없는 폴더에서도 재현되므로, 우리 앱 extension이 근본 원인이라고 볼 수 없다.

즉, 이번 타스크는 앱 쪽에서 해결 가능한 문제와 Finder 자체 문제를 분리해 정리한 상태로 마무리된다.

## 남은 리스크와 후속 권장 사항

### 1. Finder grouped icon view 버벅임

- 앱 최적화와 별개로 Finder 자체 문제가 남아 있다.
- 이미 `Feedback Assistant` 제출용 문서를 준비했으므로, 실제 화면 녹화와 함께 Apple에 제출하는 것이 맞다.

### 2. 검증 산출물 캐시 재사용 주의

- `./scripts/validate-stage3-render.sh`를 기본 출력 경로 `output/stage3-render`로 반복 실행하면, 과거 다른 작업 디렉터리의 module cache가 남아 `SwiftShims` cache path mismatch가 재발할 수 있다.
- 이는 제품 기능 회귀가 아니라 로컬 검증 산출물 재사용 문제이므로, 새 출력 경로를 주거나 캐시를 정리하는 식으로 운영하는 것이 안전하다.

### 3. 문서/브랜치 후속 절차

- 이 최종 보고서 승인 후에는 작업지시자 판단에 따라 stage 문서와 코드 변경을 커밋하고, 이후 `publish/task22` 생성 및 `devel` 대상 draft PR 절차로 넘어가면 된다.

## 결론

- `rhwp` 코어 결합 구조, thumbnail fast path, Finder 실제 thumbnail 동작, small-size 지원, thumbnail 성능 경로 최적화까지 배포 준비에 필요한 핵심 정리는 완료됐다.
- 동시에 Finder 스크롤 버벅임은 우리 앱 문제와 Apple 플랫폼 문제를 구분해 설명 가능한 상태가 됐다.
- 다음 액션은 `Feedback Assistant` 제출과 PR 준비다.
