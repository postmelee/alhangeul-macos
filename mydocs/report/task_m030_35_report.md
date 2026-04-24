# Task M030 #35 최종 결과보고서

## 작업 개요

- 이슈: #35 Quick Look/Thumbnail 공통 group drawing 저해상도 렌더링 수정
- 마일스톤: `v0.3.0`
- 브랜치: `local/task35`
- 기준 브랜치: `devel`

## 최종 변경 요약

Quick Look preview와 Finder thumbnail에서 embedded preview와 직접 렌더링 결과가 섞여 보일 수 있는 경로를 제거했다. 현재 최종 상태에서는 Quick Look preview와 Finder thumbnail 모두 embedded thumbnail fast path를 사용하지 않고 첫 페이지를 직접 렌더링한다.

추가로 `group-drawing-02.hwp`에서 확인된 선 객체 렌더링 누락 원인을 보정하기 위해 `LineNode` 렌더링에도 node `bbox` 기준 transform을 적용했다.

## 코드 변경

### `Sources/Shared/HwpPageImageRenderer.swift`

- embedded thumbnail 사용 정책을 `HwpEmbeddedThumbnailPolicy`로 분리했다.
- 기본 렌더링 정책을 `.never`로 고정했다.
- Quick Look preview 기본 경로는 embedded preview를 사용하지 않는다.

### `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`

- Finder thumbnail 요청에서도 `embeddedThumbnailPolicy: .never`를 명시했다.
- 요청 크기와 무관하게 ThumbnailExtension은 직접 렌더링 결과만 사용한다.
- PR #23에서 추가된 thumbnail render cache 구조는 유지하고, embedded fast path만 제거했다.

### `Sources/RhwpCoreBridge/CGTreeRenderer.swift`

- `LineNode` 렌더링 시 node `bbox`와 line transform을 함께 적용하도록 수정했다.
- group drawing 계열 문서에서 선 객체 위치와 크기 해석이 누락되는 문제를 보정했다.

## PR #23과의 관계

이번 변경은 PR #23의 thumbnail 관련 코드를 단순 복구한 것이 아니다. PR #23은 Task #22 전체 변경으로 bridge, plist, project 설정, thumbnail cache 추가까지 포함한다. 이번 작업은 최신 `devel`에 반영된 PR #23 이후 구조를 유지한 상태에서 embedded thumbnail 정책과 line transform 렌더링을 새로 수정했다.

즉, PR #23 이전 코드로 되돌린 것이 아니라 현재 구조 위에서 Finder/Quick Look 표시 일관성을 맞춘 작업이다.

## Finder 캐시 확인

사용자 환경에서 `/Users/melee/Documents/samples`의 일부 파일이 줌 변경 시 저화질/고화질을 오가는 것처럼 보이는 현상이 있었다.

확인 내용:

- `AlhangeulMacThumbnail`, `AlhangeulMacPreview`, `com.apple.quicklook.ThumbnailsAgent`, Finder를 재시작했다.
- `qlmanage -r`, `qlmanage -r cache`를 실행했다.
- 원본 samples 경로와 새 임시 복사본 경로에서 Finder 아이콘 보기 줌을 조정했다.
- `qlmanage -t`로 `24`, `32`, `64`, `112`, `256` 크기의 thumbnail 출력을 확인했다.

판단:

- 현재 코드와 `qlmanage` 출력은 embedded fast path를 사용하지 않는다.
- Finder에서 보인 저화질/고화질 전환은 기존 Quick Look/Finder thumbnail cache가 남아 있다가 새 thumbnail로 교체되는 현상으로 판단했다.
- 사용자 재검증에서도 캐시 초기화 후 문제가 해결된 것으로 확인됐다.

## 검증 결과

### Shared bridge 경계

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### 렌더링 smoke test

```bash
./scripts/validate-stage3-render.sh output/task35-stage6-render
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED **
```

### Release package smoke test

```bash
./scripts/package-release.sh 0.3.0-task35-smoke3
```

결과:

```text
** BUILD SUCCEEDED **
```

설치 후 `tac-img-02.hwp`의 `32`, `48`, `64`, `80`, `96`, `112`, `128`, `160`, `192`, `256`, `512` 크기 thumbnail을 `qlmanage -t`로 생성해 비교했고, 모든 크기에서 직접 렌더 결과에 가까운 것으로 확인했다.

## 남은 위험과 후속

- embedded thumbnail fast path 제거로 cold thumbnail 생성 비용은 증가한다.
- Finder/Quick Look 캐시가 생성 이후 비용을 줄이지만, 매우 큰 문서의 최초 thumbnail 생성 지연은 별도 성능 개선 이슈로 분리할 수 있다.
- 이번 이슈 범위에서는 표시 일관성과 PDF 유사 동작을 우선한다.

## 최종 판단

이슈 #35의 목표였던 Quick Look/Thumbnail 공통 저해상도 렌더링 문제와 Finder thumbnail 표시 일관성 문제를 현재 앱 저장소 코드 범위에서 해결했다. embedded thumbnail fast path는 현재 최종 코드에서 사용하지 않는다.
