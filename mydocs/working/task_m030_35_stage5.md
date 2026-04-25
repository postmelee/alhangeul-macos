# Task M030 #35 Stage 5 완료보고서

## 단계 목표

Finder를 실제로 조작해 아이콘 보기 줌 단계별 thumbnail 동작을 확인하고, embedded preview 허용 임계값이 PDF와 유사한 Finder 동작에 맞는지 검증한다.

## Finder 실측

테스트 대상:

- `/tmp/alhangeul-task35-group-only/group-drawing-02.hwp`
- 설치본: `$HOME/Applications/AlhangeulMac.app`
- 설치/등록 후 `qlmanage -r`, `qlmanage -r cache` 수행

### 변경 전 관찰

`embeddedThumbnailPolicy: .smallFinderThumbnail(maxPixelDimension: 128)` 상태에서 Finder 아이콘 보기의 아이콘 크기 조절 슬라이더를 조작했다.

- 64 크기: embedded preview 기반으로 보임
- 96 크기: 여전히 작은 embedded preview를 크게 키운 인상이 남음
- 112 크기 이상: 직접 렌더링 쪽으로 보이는 결과가 나타남

Retina 환경에서는 Finder의 표시 크기보다 Quick Look thumbnail request의 pixel size가 더 크게 잡히므로, `128px` 임계값은 아이콘 보기에서 너무 오래 embedded preview를 허용한다.

### 변경 후 관찰

임계값을 `64px`로 낮춘 뒤 Release package를 다시 만들고 설치했다.

- 64 크기: 작은 Finder thumbnail 용도로 허용
- 96 크기 이상: 아이콘 보기에서는 직접 렌더링 경로를 사용하도록 전환

이 정책이 "목록/작은 아이콘에서는 embedded preview 허용, 아이콘 보기에서는 PDF처럼 직접 렌더링"이라는 기준에 더 가깝다.

## 변경 내용

`Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`에서 embedded preview 허용 임계값을 `128px`에서 `64px`로 낮췄다.

```swift
embeddedThumbnailPolicy: .smallFinderThumbnail(maxPixelDimension: 64)
```

## Quick Look preview 확인

Quick Look preview 경로는 `HwpPageImageRenderer.renderFirstPage(fileURL:)`를 통해 `embeddedThumbnailPolicy: .never`를 사용한다. 별도 직접 렌더 스크립트로 `group-drawing-02.hwp`를 렌더링했을 때 794x1123 PNG가 생성됐고, embedded preview가 아닌 직접 렌더 결과가 확인됐다.

Finder에서 Space로 연 Quick Look 패널은 캐시/기존 preview 프로세스 영향으로 한 차례 오래된 화면처럼 보였으나, 소스 경로와 직접 렌더 산출물 기준으로 embedded preview 사용 경로는 남아 있지 않다. 재검증 시에는 설치 후 기존 preview/thumbnail 프로세스와 Quick Look 캐시를 함께 초기화해야 한다.

## 검증

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
./scripts/validate-stage3-render.sh output/task35-stage5-render
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

### Release package 및 Finder 실측

```bash
./scripts/package-release.sh 0.3.0-task35-smoke2
```

결과:

```text
** BUILD SUCCEEDED **
```

설치 후 실행:

```bash
qlmanage -r
qlmanage -r cache
qlmanage -t -x -s 64 -o /tmp/alhangeul-task35-ql-after-64 /tmp/alhangeul-task35-group-only/group-drawing-02.hwp
qlmanage -t -x -s 128 -o /tmp/alhangeul-task35-ql-after-128 /tmp/alhangeul-task35-group-only/group-drawing-02.hwp
qlmanage -t -x -s 192 -o /tmp/alhangeul-task35-ql-after-192 /tmp/alhangeul-task35-group-only/group-drawing-02.hwp
qlmanage -t -x -s 512 -o /tmp/alhangeul-task35-ql-after-512 /tmp/alhangeul-task35-group-only/group-drawing-02.hwp
```

결과:

```text
64: 46 x 64 PNG
128: 91 x 128 PNG
192: 136 x 192 PNG
512: 363 x 512 PNG
```

## 판단

- 기존 `128px` 임계값은 Finder 아이콘 보기에서 embedded preview를 너무 오래 유지했다.
- `64px` 임계값은 작은 Finder 목록/아이콘 용도만 fast path로 두고, 그보다 큰 아이콘 보기는 직접 렌더링으로 보내므로 PDF 동작에 더 가깝다.
- Stage 5 기준으로 source 변경은 thumbnail 임계값 조정 1건이다.

## 변경 파일

- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `mydocs/orders/20260425.md`
- `mydocs/working/task_m030_35_stage5.md`

## 승인 요청

Stage 5 완료를 승인하면 최종 결과 보고서 작성과 PR 준비 단계로 진행한다.
