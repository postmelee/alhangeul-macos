# Issue #26 최종 보고서

## 개요

Issue #26은 Issue #22 / PR #23에서 추가한 Thumbnail embedded preview fast path 이후, 특정 파일의 Finder thumbnail이 큰 preview 영역에서 저해상도로 보이는 회귀를 조사하고, embedded preview 품질 게이트를 추가한 작업이다.

초기 가설은 embedded preview 자체가 작은 파일에서도 요청 크기와 무관하게 fast path를 우선 사용하는 문제였다. 재현 파일 `group-drawing-02.hwp`의 embedded preview는 `177x250` GIF였고, Finder의 `512px` thumbnail 요청에서 이 이미지를 확대하면 저해상도로 보일 수 있다.

다만 Finder 직접 테스트와 추가 `qlmanage` 확인 결과, `group-drawing-02.hwp`는 embedded preview를 회피해 full render fallback을 사용해도 Quick Look preview와 Finder thumbnail 모두에서 여전히 작은 저해상도 그림처럼 보인다. 따라서 Issue #26의 변경은 유효한 방어 로직이지만, 해당 파일의 근본 원인은 Quick Look/Thumbnail 공통 렌더링 품질 문제로 분리한다.

## 원인 분석

초기 조사 결과는 다음과 같다.

| 파일 | embedded preview | 판단 |
|------|------------------|------|
| `group-drawing-02.hwp` | `177x250` GIF | 큰 thumbnail 요청에는 부족 |
| `pic-in-head-02.hwp` | `724x1024` PNG | `512px` 요청에 충분 |

`group-drawing-02.hwp`는 full render 경로로는 `794x1123` 수준의 렌더가 가능했다. 이 확인으로 embedded preview fast path를 회피하는 방어 로직의 필요성은 확인했다.

그러나 full render fallback 산출물과 Finder UI를 직접 확인한 결과, 해당 파일의 group drawing 자체가 고해상도 벡터/shape로 보이지 않고 저해상도 이미지처럼 렌더된다. 즉, `group-drawing-02.hwp`의 근본 문제는 Thumbnail extension만의 fast path가 아니라 `HwpPageImageRenderer` / `CGTreeRenderer` / core render tree의 group drawing 렌더링 경로로 보는 것이 맞다.

## 변경 내용

`Sources/Shared/HwpPageImageRenderer.swift`에 embedded preview 품질 게이트를 추가했다.

- `maximumPixelSize`가 없는 호출은 기존 동작을 유지한다.
- 요청 긴 변이 `128px` 이하이면 embedded preview fast path를 유지한다.
- 요청 긴 변이 큰 경우 embedded preview 긴 변이 요청 긴 변의 `75%` 이상일 때만 fast path를 사용한다.
- 기준에 못 미치면 `decodeEmbeddedThumbnail`이 `nil`을 반환해 기존 full render fallback으로 전환한다.

이 정책으로 작은 Finder icon 요청에서는 성능 경로를 유지하고, 큰 Finder preview 요청에서는 저해상도 embedded preview 확대를 피한다.

## 분기 확인

임시 probe 결과:

| 파일 | 요청 | 결과 이미지 | logical size | 판단 |
|------|------|-------------|--------------|------|
| `group-drawing-02.hwp` | `64px` | `45x64` | `177x250` | embedded preview 유지 |
| `group-drawing-02.hwp` | `512px` | `363x512` | `793x1122` | full render fallback |
| `pic-in-head-02.hwp` | `64px` | `45x64` | `724x1024` | embedded preview 유지 |
| `pic-in-head-02.hwp` | `512px` | `362x512` | `724x1024` | embedded preview 유지 |

## 검증 결과

### Shared bridge 경계

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### Xcode project 재생성

```bash
xcodegen generate
```

결과: 성공

### HostApp Debug build

```bash
xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 성공

- `QLExtension`, `ThumbnailExtension`, `HostApp`가 dependency order로 빌드됐다.
- `RhwpMacThumbnail.appex`가 HostApp bundle에 포함되고 embedded binary validation을 통과했다.

### Finder thumbnail smoke test

```bash
qlmanage -r cache
qlmanage -t -x -s 512 -o /tmp/rhwp-task26-ql-512 /Users/melee/Documents/samples/group-drawing-02.hwp
qlmanage -t -x -s 512 -o /tmp/rhwp-task26-ql-512 /Users/melee/Documents/samples/pic-in-head-02.hwp
qlmanage -t -x -s 64 -o /tmp/rhwp-task26-ql-64 /Users/melee/Documents/samples/group-drawing-02.hwp
```

결과: 모두 `produced one thumbnail`

생성 PNG 크기:

| 출력 | 크기 |
|------|------|
| `/tmp/rhwp-task26-ql-512/group-drawing-02.hwp.png` | `363x512` |
| `/tmp/rhwp-task26-ql-512/pic-in-head-02.hwp.png` | `362x512` |
| `/tmp/rhwp-task26-ql-64/group-drawing-02.hwp.png` | `46x64` |

### Finder 직접 확인

Finder에서 `/Users/melee/Documents/samples/group-drawing-02.hwp`와 `pic-in-head-02.hwp`를 직접 선택해 우측 preview 영역을 비교했다.

- `pic-in-head-02.hwp`: 정상 문서 preview처럼 표시된다.
- `group-drawing-02.hwp`: full render fallback을 타는 상태에서도 group drawing 영역이 작은 저해상도 그림처럼 보인다.

추가로 `1024px` thumbnail 산출물도 확인했으나, `group-drawing-02.hwp`의 group drawing 품질은 근본적으로 개선되지 않았다.

### diff 형식

```bash
git diff --check
```

결과: 통과

## 남은 리스크

- 품질 게이트 기준값 `75%`는 현재 재현 샘플 기준으로 보수적으로 정했다. 더 다양한 embedded preview 샘플이 쌓이면 threshold 조정 여지는 있다.
- `group-drawing-02.hwp`의 근본 품질 문제는 Issue #35로 분리했다. 이 문제는 Thumbnail fast path가 아니라 Quick Look/Thumbnail 공통 렌더링 경로에서 다뤄야 한다.
- Finder/Quick Look 캐시는 이전 썸네일을 재사용할 수 있으므로 실사용 확인 전 `qlmanage -r cache`가 필요할 수 있다.

## 결론

Issue #26에서는 저해상도 embedded preview를 큰 Finder thumbnail 요청에 그대로 사용하는 위험을 shared renderer 품질 게이트로 방어했다.

작은 요청에서는 기존 fast path가 유지되고, 큰 요청에서만 full render fallback으로 전환되는 것을 확인했다. 따라서 #26 변경은 “embedded preview 품질 게이트 추가”라는 제한된 범위에서 유지한다.

다만 `group-drawing-02.hwp`의 실제 저해상도 표시 문제는 full render fallback 후에도 남아 있으므로 #26에서 해결 완료로 보지 않는다. 근본 원인 분석과 수정은 Issue #35 `Quick Look/Thumbnail 공통 group drawing 저해상도 렌더링 수정`에서 진행한다.
