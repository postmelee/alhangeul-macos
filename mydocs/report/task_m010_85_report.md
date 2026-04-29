# Task #85 최종 결과 보고서

## 작업 요약

- **이슈**: [#85 Quick Look preview를 전체 페이지 미리보기로 확장](https://github.com/postmelee/alhangeul-macos/issues/85)
- **마일스톤**: v0.1 (M010)
- **브랜치**: `local/task85`
- **Worktree**: `/private/tmp/rhwp-mac-task85`
- **단계 수**: 5단계
- **완료 시각**: 2026-04-29 09:34 KST
- **목적**: Quick Look preview가 첫 페이지만 보여주던 동작을 rhwp render tree 기반 전체 페이지 preview로 확장하고, PR 전 확인된 초기 응답 지연을 보정

## 단계별 진행

| Stage | Commit | 내용 |
|-------|--------|------|
| 1 | `d2611ce` | Quick Look PDF preview 설계 확정 |
| 2 | `6e46a33` | 페이지 번호 기반 렌더링 helper 분리 |
| 3 | `e800f2a` | Quick Look 전체 페이지 PDF preview 구현 |
| 4 | `4867d58` | Quick Look/Thumbnail 통합 검증과 문서 정리 |
| 5 | 본 커밋 | Quick Look preview 응답 지연 보정과 최종 보고서 갱신 |

## 최종 구현

Quick Look preview는 다중 페이지 문서에 대해 `.pdf` content type의 `QLPreviewReply`를 반환한다. 단, 이 PDF는 사용자용 PDF export나 HWP/HWPX 구조 변환 산출물이 아니다.

최종 경로:

1. `HwpPreviewProvider`가 Finder Quick Look 요청을 받는다.
2. `HwpPreviewPDFRenderer.inspect(fileURL:)`가 파일 크기, file data, page count, 첫 페이지 size를 먼저 확인한다.
3. page count가 1이면 `.png` reply를 반환하고 data creation block에서 첫 페이지 bitmap을 PNG로 encoding한다.
4. page count가 2 이상이면 `.pdf` reply를 반환하고 data creation block에서 전체 페이지 PDF preview data를 만든다.
5. PDF 생성 시에는 `RhwpDocument.pageCount`만큼 page index를 순회한다.
6. 각 페이지는 `HwpPageImageRenderer.renderPage(document:pageIndex:)`가 render tree 기반 bitmap으로 렌더링한다.
7. 각 bitmap을 PDF page에 삽입한다.

Thumbnail extension은 기존처럼 첫 페이지 bitmap을 사용한다.

## Stage 5 성능 보정

Stage 4 이후 작업지시자가 제공한 Finder Quick Look 영상에서, 목록을 빠르게 전환하는 동안 preview가 즉시 갱신되지 않고 선택 전환을 멈춘 뒤 로딩이 시작되는 패턴이 확인됐다.

원인은 Stage 3 구현이 `providePreview` 경로에서 전체 페이지 PDF data 생성을 끝낸 뒤 `QLPreviewReply`를 반환하는 구조였기 때문이다. Stage 5에서는 다음 보정을 적용했다.

- `providePreview`의 `MainActor.run` 경계를 제거했다.
- reply 생성 전에 모든 페이지를 렌더링하지 않고, `inspect(fileURL:)`로 page count와 첫 페이지 size만 먼저 확인한다.
- 단일 페이지 문서는 PNG reply로 처리한다.
- 다중 페이지 문서의 전체 PDF 생성은 `QLPreviewReply` data creation block 안으로 지연했다.

단일 페이지 PNG 분기는 benchmark상 명확한 속도 우위가 확인된 최적화라기보다는, 단일 페이지 문서를 다중 페이지 PDF container 경로에서 제외하고 Task #85 이전의 PNG 기반 Quick Look 경로에 가깝게 되돌리는 보수적 경로 복원이다. `samples/basic/KTX.hwp` 기준으로 Stage 5 이전 1 page PDF data 생성은 0.066s였고, Stage 5 이후 PNG data block 생성은 0.126s였다. 대신 reply 반환 전 작업은 0.004s 수준의 inspect로 축소됐다.

Stage 5는 실제 다중 페이지 PDF 생성 비용을 없애지는 않는다. 현재 data reply 방식은 첫 페이지만 먼저 보여준 뒤 나머지 page를 append하는 true lazy pagination을 제공하지 않는다. 그 수준의 지연 렌더링은 view 기반 Quick Look preview 또는 `PDFDocument`/`PDFPage` 생성 block 기반 구조를 별도 spike로 검토해야 한다.

## 변경 파일 목록과 영향 범위

### 제품 코드

- `Sources/QLExtension/HwpPreviewProvider.swift`
  - 단일 PNG reply에서 page count 기반 PNG/PDF reply 선택 구조로 전환
  - `MainActor.run` 제거
  - 단일 페이지 PNG data block과 다중 페이지 PDF data block 분리
- `Sources/Shared/HwpPageImageRenderer.swift`
  - page index 기반 render helper 추가
  - `pageOutOfRange`, `pdfEncodingFailed` 오류 추가
- `Sources/Shared/HwpPreviewPDFRenderer.swift`
  - 전체 페이지 Quick Look PDF preview container 생성
  - `HwpPreviewDocumentInfo`와 `inspect(fileURL:)` 추가
  - `render(previewInfo:)` 경로 추가
- `AlhangeulMac.xcodeproj/project.pbxproj`
  - `xcodegen generate` 결과로 새 Shared source 포함

### 문서

- `Sources/README.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/orders/20260429.md`
- `mydocs/plans/task_m010_85.md`
- `mydocs/plans/task_m010_85_impl.md`
- `mydocs/working/task_m010_85_stage1.md`
- `mydocs/working/task_m010_85_stage2.md`
- `mydocs/working/task_m010_85_stage3.md`
- `mydocs/working/task_m010_85_stage4.md`
- `mydocs/working/task_m010_85_stage5.md`
- `mydocs/report/task_m010_85_report.md`

### 제외/미변경

- Rust core ABI 변경 없음
- `edwardkim/rhwp` core 코드 변경 없음
- `Sources/RhwpCoreBridge`의 AppKit/UIKit 비의존 경계 유지
- 사용자용 PDF export 기능 추가 없음
- Thumbnail extension의 다중 페이지 동작 추가 없음
- 다중 페이지 true lazy pagination 추가 없음

## 정량 확인

### page count

| 샘플 | 원본 page count | Quick Look preview PDF page count | 결과 |
|------|------------------|-----------------------------------|------|
| `samples/basic/KTX.hwp` | 1 | 1 | OK |
| `samples/hwp-multi-001.hwp` | 10 | 10 | OK |
| `samples/hwpx/hwpx-01.hwpx` | 9 | 9 | OK |

### Stage 5 benchmark

| 샘플 | page count | reply 전 inspect | data block PNG/PDF |
|------|------------|------------------|--------------------|
| `samples/basic/KTX.hwp` | 1 | 0.004s | PNG 0.126s |
| `samples/hwp-multi-001.hwp` | 10 | 0.006s | PDF 0.443s |
| `samples/basic/exam_math.hwp` | 20 | 0.006s | PDF 0.723s |
| `samples/basic/exam_kor.hwp` | 30 | 0.166s | PDF 1.882s |
| `samples/basic/aift.hwp` | 77 | 0.077s | PDF 2.511s |
| `samples/hwpx/hwpx-01.hwpx` | 9 | 0.006s | PDF 0.409s |

### 단일 페이지 PNG/PDF 비교

| 샘플 | Stage 5 이전 1 page PDF data | Stage 5 reply 전 inspect | Stage 5 PNG data block | 해석 |
|------|------------------------------|--------------------------|------------------------|------|
| `samples/basic/KTX.hwp` | 0.066s | 0.004s | 0.126s | PNG가 data 생성 시간에서 더 빠르다고 단정할 수는 없다. 변경 목적은 단일 페이지를 다중 페이지 PDF container 경로에서 제외하고, reply 반환 전 전체 PDF 생성을 피하는 것이다. |

## 검증 결과

| 검증 항목 | 결과 |
|-----------|------|
| `git diff --check` | OK |
| `./scripts/check-no-appkit.sh` | OK |
| `./scripts/validate-stage3-render.sh` | OK |
| HostApp Debug build | OK (`** BUILD SUCCEEDED ** [6.889 sec]`) |
| Release package build | OK |
| Release zip SHA-256 | `640b7fb4c5d1f0df5d7a69c05ed413aeba2b8e7784025d1482b5a33e98901f10` |
| 설치 app codesign verify | OK |
| PlugInKit QLExtension 등록 | OK |
| PlugInKit ThumbnailExtension 등록 | OK |
| `qlmanage -p samples/basic/KTX.hwp` | OK, preview 세션 유지 후 수동 종료 |
| `qlmanage -p samples/hwp-multi-001.hwp` | OK, preview 세션 유지 후 수동 종료 |
| `qlmanage -t -x -s 512` thumbnail | OK, HWP/HWPX 3개 PNG 생성 |
| PDF page count smoke | OK, HWP 10 page/HWPX 9 page 확인 |

## PDF 방식의 의미

이번 작업에서 PDF를 쓰는 이유는 macOS Quick Look이 다중 페이지 preview를 자연스럽게 표시할 수 있는 content type이기 때문이다. HWP/HWPX 원본을 PDF 문서 구조로 변환하지 않는다. 텍스트, 문단, 표, 객체를 PDF semantics로 export하는 기능도 아니다.

실제 렌더링 기준은 기존 rhwp render tree와 `CGTreeRenderer`다. PDF에는 각 페이지의 bitmap 렌더 결과만 들어간다.

## 잔여 위험과 후속 작업

- 다중 페이지 문서는 여전히 전체 페이지 PDF data를 만들어야 표시된다. Stage 5는 provider reply 생성 전 지연을 줄이는 보정이지, true lazy pagination 구현은 아니다.
- `inspect(fileURL:)`에서도 `RhwpDocument`를 한 번 열어 page count와 첫 페이지 크기를 확인한다. 일반 샘플에서는 수 ms 수준이었지만, `exam_kor.hwp`는 0.166s가 걸렸다.
- 단일 페이지 PNG preview smoke에서 ImageKit 로그가 출력됐다. 표시 crash는 없었지만 설치본 실사용 중 같은 로그가 반복되는지 관찰 대상이다.
- 자동화 환경에서 Finder Quick Look 창 내부 스크롤 조작까지 캡처하지는 못했다. 다중 페이지 산출은 PDF page count smoke로 확인했다.
- `qlmanage -p -o` 출력 파일 모드는 이 환경에서 ExtensionFoundation 예외로 종료했다. 일반 `qlmanage -p` preview와 `qlmanage -t` thumbnail은 통과했다.
- true lazy pagination은 후속 이슈로 분리했다.
  - [#87 PDFKit 기반 Quick Look lazy PDF preview 가능성 검증](https://github.com/postmelee/alhangeul-macos/issues/87)
  - [#88 View-based Quick Look preview visible-page lazy rendering 전환](https://github.com/postmelee/alhangeul-macos/issues/88)

## 작업지시자 승인 요청

- 본 최종 보고서 검토
- 승인 후 `publish/task85` 원격 push 및 devel 대상 draft PR 생성 진행
- PR 게시 전 `local/task85`가 `origin/devel`보다 behind인 상태를 해소하고 충돌 여부를 확인해야 함
