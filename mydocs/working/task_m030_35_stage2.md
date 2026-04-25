# Task M030 #35 Stage 2 완료보고서

## 단계 목표

thumbnail 방식 변경 이력을 GitHub PR과 관련 문서 기준으로 추적하고, 현재 이슈 해결에 필요한 embedded preview 정책을 확정한다.

## 확인한 이력

### PR #23 — Task #22

- PR: `https://github.com/postmelee/alhangeul-macos/pull/23`
- 커밋: `d5bd508 Task #22: rework rhwp bridge and finder thumbnail flow`
- 핵심 변경:
  - `hwpql` 참고 구현을 바탕으로 `rhwp_extract_thumbnail` FFI를 추가했다.
  - `RhwpDocument.extractEmbeddedThumbnail(from:)` Swift bridge를 추가했다.
  - `HwpPageImageRenderer`를 `embedded preview 우선 -> render tree fallback` 구조로 바꿨다.
  - Thumbnail 요청 크기 기반 `HwpThumbnailRenderCache`와 in-flight dedupe를 추가했다.

### PR #36 — Task #26

- PR: `https://github.com/postmelee/alhangeul-macos/pull/36`
- 커밋: `ba772ce Task #26: add thumbnail embedded preview quality gate`
- 핵심 변경:
  - embedded preview가 요청 크기에 비해 작으면 full render fallback으로 전환하는 품질 게이트를 추가했다.
  - `group-drawing-02.hwp`는 embedded preview가 `177x250` GIF라 큰 thumbnail 요청에는 부족함을 확인했다.
  - 다만 full render fallback 이후에도 낮은 품질처럼 보이는 문제는 #35로 분리했다.

## hwpql 참고 결과

`hwpql`의 공개 저장소를 확인했다.

- Thumbnail: `HWPThumbnailer/ThumbnailProvider.swift`
- Preview: `HWPPreviewer/PreviewProvider.swift`
- FFI: `rhwp-ffi/src/lib.rs`

확인 결과 `hwpql`은 thumbnail에서는 `PrvImage`를 직접 사용하고, preview에서는 HTML/SVG 렌더를 사용한다. 즉 참고 구현 자체도 thumbnail fast path와 preview render path가 분리되어 있다.

## 현재 코드의 문제 지점

현재 `HwpPageImageRenderer.renderFirstPage(fileURL:)`는 `maximumPixelSize == nil`로 호출된다. 기존 정책은 `maximumPixelSize == nil`이면 embedded preview를 항상 허용했다.

그 결과 Quick Look preview처럼 큰 미리보기 화면에서도 `group-drawing-02.hwp`의 `177x250` embedded GIF가 우선 사용될 수 있었다.

Thumbnail 쪽은 PR #36 이후 큰 요청에서 full render fallback으로 전환되지만, Quick Look preview는 같은 품질 게이트를 타지 않았다.

## 정책 결정

작업지시자 승인에 따라 Finder thumbnail 정책은 Finder가 PDF를 다루는 방식에 맞춘다.

- Quick Look preview는 embedded preview를 사용하지 않고 항상 첫 페이지를 직접 렌더한다.
- Finder thumbnail은 작은 요청에서만 embedded preview fast path를 허용한다.
- 큰 Finder icon view thumbnail은 PDF처럼 요청 크기에 맞춰 직접 렌더한다.
- `group-drawing-02.hwp`처럼 embedded preview가 낮은 해상도인 파일은 목록 보기 수준에서만 fast path를 탈 수 있다.

## 다음 단계

Stage 3에서 `HwpPageImageRenderer`의 embedded preview 정책을 명시적으로 분리한다.
