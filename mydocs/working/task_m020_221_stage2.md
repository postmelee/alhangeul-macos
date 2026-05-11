# Task M020 #221 Stage 2 완료보고서

## 단계 목적

현재 native bitmap PDF 생성 경로와 rhwp core SVG 생성 경로를 같은 입력 파일에서 측정하는 helper를 추가한다.

이번 단계는 제품 preview 동작을 바꾸지 않고, 비교용 스크립트와 측정 보고서만 추가한다.

## 산출물

| 파일 | 요약 |
|------|------|
| `scripts/quicklook_pdf_renderer_compare.swift` | native bitmap PDF와 core SVG 생성 시간, 출력 크기, page count를 측정하는 Swift helper |
| `scripts/compare-quicklook-pdf-renderers.sh` | Swift helper를 현재 RustBridge staticlib과 함께 빌드하고 실행하는 shell wrapper |
| `mydocs/working/task_m020_221_stage2.md` | Stage 2 결과 보고서 |

라인 수:

```text
     295 scripts/quicklook_pdf_renderer_compare.swift
      71 scripts/compare-quicklook-pdf-renderers.sh
     366 total
```

## 구현 내용

### Swift helper

`quicklook_pdf_renderer_compare.swift`는 입력 파일별로 다음 값을 측정한다.

- 파일 크기
- page count
- 현재 Quick Look reply 정책상 예상 reply 타입
- 첫 페이지 크기
- `HwpPreviewPDFRenderer.inspect(fileURL:)` 시간
- `HwpPreviewPDFRenderer.render(previewInfo:)` 시간
- native bitmap PDF bytes
- native bitmap PDF page count
- core SVG 측정용 file data read 시간
- `RhwpDocument` open 시간
- 전체 page `renderPageSVG(at:)` 시간
- 전체 SVG bytes
- SVG 생성 실패 page 목록

출력은 전체 `summary.txt`와 파일별 `{basename}-compare.txt`로 나눈다.

### Shell wrapper

`compare-quicklook-pdf-renderers.sh`는 기존 `render-debug-compare.sh`와 같은 방식으로 다음 산출물을 확인하고 Swift helper를 빌드한다.

- `Frameworks/universal/librhwp.a`
- `Frameworks/modulemap/module.modulemap`

빌드 입력은 현재 제품 경로와 같은 helper를 포함한다.

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/FontFallback.swift`
- `Sources/RhwpCoreBridge/FontResourceRegistry.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/Shared/HwpPreviewPDFRenderer.swift`

## 측정 결과

검증 샘플:

- `/Users/melee/Desktop/files/group-drawing-02.hwp`
- `/Users/melee/Desktop/files/footnote-01.hwp`

실행 결과:

```text
OK group-drawing-02.hwp: pages=1 nativePDF=1.116109 coreSVG=0.000376
OK footnote-01.hwp: pages=6 nativePDF=0.149368 coreSVG=0.002855
```

생성된 `summary.txt`:

```text
| File | Status | FileBytes | Pages | CurrentReply | FirstPageSize | NativeInspectSeconds | NativePDFSeconds | NativePDFBytes | NativePDFPages | CoreDataReadSeconds | CoreOpenSeconds | CoreSVGSeconds | CoreSVGBytes | CoreSVGFailures |
|------|--------|-----------|-------|--------------|---------------|----------------------|------------------|----------------|----------------|---------------------|-----------------|----------------|--------------|-----------------|
| `group-drawing-02.hwp` | OK | 13824 | 1 | png | 793.7x1122.5 | 0.002921 | 1.116109 | 43366 | 1 | 0.000064 | 0.000218 | 0.000376 | 68534 | - |
| `footnote-01.hwp` | OK | 32768 | 6 | pdf | 793.7x1122.5 | 0.000839 | 0.149368 | 534723 | 6 | 0.000116 | 0.000358 | 0.002855 | 473743 | - |
```

해석:

- `group-drawing-02.hwp`는 실제 제품 Quick Look에서는 단일 페이지 PNG reply 대상이다. 이번 helper는 PDF UI 비교 기준을 위해 native bitmap PDF도 별도 측정한다.
- core SVG 생성 자체는 두 샘플 모두 매우 빠르게 끝났다.
- native bitmap PDF 시간은 첫 샘플에서 상대적으로 크게 나왔다. 이 값은 CoreText/font/cold-start 영향이 섞일 수 있으므로 Stage 4에서 반복 측정으로 다시 판단한다.
- 이 단계 결과만으로 SVG 기반 PDF가 최종적으로 빠르다고 결론내릴 수는 없다. SVG를 PDF로 변환하는 비용은 Stage 3 이후에 별도로 더해져야 한다.

## 검증 결과

### Rust staticlib 준비

새 worktree에는 `Frameworks/universal/librhwp.a`가 없어서 다음 명령으로 산출물을 만들었다.

```bash
./scripts/build-rust-macos.sh
```

결과:

- `Frameworks/universal/librhwp.a`: `x86_64 arm64` universal 확인
- FFI symbol set 확인 통과
- `Frameworks/Rhwp.xcframework` 생성
- `xcodebuild`가 CoreSimulator 관련 경고를 출력했지만 `xcframework successfully written out`으로 종료

### Stage 2 검증 명령

```bash
bash -n scripts/compare-quicklook-pdf-renderers.sh
```

결과: 통과

```bash
./scripts/compare-quicklook-pdf-renderers.sh output/task221-stage2 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/footnote-01.hwp
```

결과: 통과

```bash
test -s output/task221-stage2/summary.txt
```

결과: 통과

```bash
git diff --check -- scripts/quicklook_pdf_renderer_compare.swift scripts/compare-quicklook-pdf-renderers.sh mydocs/working/task_m020_221_stage2.md
```

결과: 통과

## 잔여 위험

- Stage 2는 SVG 생성까지만 측정한다. SVG를 PDF로 변환하는 비용과 실패 양상은 아직 포함하지 않는다.
- 첫 샘플의 native PDF 시간이 크므로, Stage 4에서 반복 측정 또는 warm/cold 구분이 필요하다.
- `summary.txt`는 ignored output 아래에 생성되는 측정 산출물이므로 커밋하지 않는다.
- Rust build 산출물인 `Frameworks/`, `RustBridge/target/`, `output/`은 ignored 상태로 유지한다.

## 다음 단계 영향

Stage 3에서는 SVG를 Quick Look PDF reply로 연결할 수 있는 후보를 검토한다. 특히 Swift/Quartz/CoreGraphics만으로 충분한지, 아니면 Rust FFI에서 PDF bytes를 직접 생성하는 방식이 필요한지 판단한다.

## 승인 요청

Stage 2 완료를 승인하면 Stage 3 SVG 기반 PDF 후보 가능성 검증으로 진행한다.
