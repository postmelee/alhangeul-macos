# Issue #22 단계 5 완료 보고서

## 작업 내용

- Finder thumbnail 경로의 `MainActor` 고정을 제거했다.
- thumbnail 요청 크기에 맞춘 size-aware 렌더를 도입했다.
- 같은 파일의 연속 thumbnail 요청에서 중복 렌더를 줄이기 위한 cache / in-flight dedupe를 추가했다.

## 코드 변경

### 1. thumbnail 렌더 경로의 actor 격리 제거

- `Sources/RhwpCoreBridge/RhwpDocument.swift`에서 `RhwpDocument`의 `@MainActor`를 제거했다.
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`에서 `CGTreeRenderer`의 `@MainActor`를 제거했다.
- `Sources/Shared/HwpPageImageRenderer.swift`에서 `HwpPageImageRenderer`의 `@MainActor`를 제거했다.

이 변경으로 thumbnail extension이 파일 읽기, embedded thumbnail decode, render tree fallback을 메인 액터에 직렬화하지 않고 수행할 수 있게 됐다.

### 2. size-aware 렌더 도입

- `Sources/Shared/HwpPageImageRenderer.swift`에 `renderFirstPage(fileURL:maximumPixelSize:)`를 추가했다.
- embedded thumbnail 경로는 `CGImageSourceCreateThumbnailAtIndex`를 사용해 요청 크기 기준으로 downsample decode 하도록 정리했다.
- render fallback 경로는 페이지 원본 크기 전체를 항상 그리던 기존 방식 대신, 요청 pixel size에 맞춰 bitmap context 크기와 렌더 scale을 계산해 그리도록 바꿨다.

즉, `16pt` thumbnail을 위해 페이지 전체를 불필요하게 큰 비트맵으로 렌더하던 과잉 작업을 줄였다.

### 3. thumbnail cache / in-flight dedupe 추가

- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`를 추가했다.
- cache key는 다음 기준을 사용한다.
  - 파일 경로
  - 수정 시각
  - 파일 크기
  - 요청 크기를 기반으로 계산한 pixel bucket
- 동일 key에 대한 동시 요청은 하나의 렌더 작업으로 합치고, 완료 후 모든 대기 요청에 같은 결과를 전달한다.
- 더 큰 pixel bucket으로 이미 만든 이미지가 있으면 더 작은 요청은 그 이미지를 재사용하도록 했다.

### 4. Thumbnail provider 호출 경로 변경

- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`는 더 이상 `Task { @MainActor in ... }`를 사용하지 않는다.
- provider는 `HwpThumbnailRenderRequest`를 만들고 `HwpThumbnailRenderCache`를 통해 background queue에서 렌더 결과를 받아 reply를 생성한다.

## 원인 정리

Finder 줌 변경/스크롤 버벅임의 핵심 원인은 thumbnail extension 경로였다.

기존 구조는 다음 문제가 겹쳐 있었다.

1. thumbnail 요청마다 `MainActor`에서 파일을 다시 읽고 렌더 경로를 다시 계산했다.
2. thumbnail 요청 크기와 무관하게 첫 페이지를 원본 페이지 크기 기준으로 렌더했다.
3. 같은 파일에 대한 연속 요청을 재사용하는 cache가 없었다.

small-size thumbnail 지원을 위해 `QLThumbnailMinimumDimension`을 제거한 뒤에는 Finder가 더 작은 요청에서도 extension을 호출하기 시작했고, 이 구조적 비용이 체감 버벅임으로 더 잘 드러났다.

## 검증

### 정적 검증

- `git diff --check -- Sources/RhwpCoreBridge/RhwpDocument.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/Shared/HwpPageImageRenderer.swift Sources/ThumbnailExtension/HwpThumbnailProvider.swift Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`

### 빌드 검증

- `xcodegen generate`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build/DerivedDataReleaseSigned CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES build`

### 설치/등록 검증

- `~/Applications/RhwpMac.app`를 새 Release 산출물로 교체
- build 경로의 `.app`는 다시 `.app.disabled`로 변경
- `pluginkit -a /Users/melee/Applications/RhwpMac.app`
- `pluginkit -mAvvv -D -i com.postmelee.rhwpmac.ThumbnailExtension`
  - 활성 경로:
    - `/Users/melee/Applications/RhwpMac.app/Contents/PlugIns/RhwpMacThumbnail.appex`

### 기능 검증

- `qlmanage -r`
- `qlmanage -r cache`
- `qlmanage -t -x -s 16 -o /tmp /Users/melee/Downloads/교양및전공이수에관한규정 [별표 1] 교양 및 최소 전공교과목 이수 현황(2025.02.06. 개정) (2).hwp`
  - 결과: `produced one thumbnail`
- `qlmanage -t -x -s 16 -o /tmp /Users/melee/Downloads/(양식)진행요원 근무일지_소프트 졸업작품 전시회.hwp`
  - 결과: `produced one thumbnail`

### 시간 측정 참고

- `/usr/bin/time -lp qlmanage -t -x -s 16 -o /tmp ...`
  - 첫 번째 대표 파일: `real 0.29`
  - 두 번째 대표 파일: `real 0.75`

이 수치는 참고만 가능하다.

- `qlmanage` 단일 실행 시간에는 quicklookd / extension 프로세스 기동, LaunchServices, 시스템 캐시 상태가 함께 섞인다.
- 따라서 이 값만으로 Finder 스크롤 체감이 얼마나 좋아졌는지 단정하기는 어렵다.

이번 단계의 핵심은 micro-benchmark 결과보다, 기존에 확인된 구조적 병목(`MainActor` 고정, 요청당 재계산, cache 부재)을 코드에서 제거했다는 점이다.

## 판단

- thumbnail 경로는 이제 메인 액터를 직접 점유하지 않는다.
- small-size 요청은 요청 크기에 맞춰 더 작은 비트맵으로 처리한다.
- 같은 파일의 반복 요청은 cache와 in-flight dedupe로 중복 작업을 줄인다.

즉, Finder zoom/scroll 버벅임에 대해 코드 수준에서 가장 직접적인 병목은 제거한 상태다.

남는 항목은 있다.

- 실제 Finder 체감 개선 폭은 폴더 구성, 파일 개수, 시스템 캐시 상태에 따라 달라질 수 있다.
- 더 정밀한 확인이 필요하면 Finder 실제 UI에서 large file set을 대상으로 시각 검증하거나, thumbnail extension에 telemetry를 추가해 cache hit / miss를 직접 기록해야 한다.

## 다음 단계

- 6단계에서 아키텍처/배포 문서에 다음 내용을 반영한다.
  - thumbnail 경로의 actor 격리 변경
  - small-size 지원 이후의 성능 최적화 구조
  - cache / in-flight dedupe 정책
  - Finder/qlmanage 성능 검증 시 해석 주의점

## 승인 요청 사항

- 이 단계 완료 기준으로 6단계(문서와 provenance 정리) 진행 승인 요청
