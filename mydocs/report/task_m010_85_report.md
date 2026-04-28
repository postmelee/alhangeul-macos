# Task #85 최종 결과 보고서

## 작업 요약

- **이슈**: [#85 Quick Look preview를 전체 페이지 미리보기로 확장](https://github.com/postmelee/alhangeul-macos/issues/85)
- **마일스톤**: v0.1 (M010)
- **브랜치**: `local/task85`
- **Worktree**: `/private/tmp/rhwp-mac-task85`
- **단계 수**: 4단계
- **완료 시각**: 2026-04-29 07:18 KST
- **목적**: Quick Look preview가 첫 페이지만 보여주던 동작을 rhwp render tree 기반 전체 페이지 preview로 확장

## 단계별 진행

| Stage | Commit | 내용 |
|-------|--------|------|
| 1 | `d2611ce` | Quick Look PDF preview 설계 확정 |
| 2 | `6e46a33` | 페이지 번호 기반 렌더링 helper 분리 |
| 3 | `e800f2a` | Quick Look 전체 페이지 PDF preview 구현 |
| 4 | 본 커밋 | Quick Look/Thumbnail 통합 검증과 문서 정리 |

## 최종 구현

Quick Look preview는 이제 단일 PNG가 아니라 `.pdf` content type의 `QLPreviewReply`를 반환한다. 단, 이 PDF는 사용자용 PDF export나 HWP/HWPX 구조 변환 산출물이 아니다.

최종 경로:

1. `HwpPreviewProvider`가 Finder Quick Look 요청을 받는다.
2. `HwpPreviewPDFRenderer`가 원본 파일을 읽고 `RhwpDocument`를 한 번 생성한다.
3. `document.pageCount`만큼 page index를 순회한다.
4. 각 페이지는 `HwpPageImageRenderer.renderPage(document:pageIndex:)`가 render tree 기반 bitmap으로 렌더링한다.
5. 각 bitmap을 PDF page에 삽입한다.
6. Quick Look에는 생성된 PDF data를 preview container로 전달한다.

Thumbnail extension은 기존처럼 첫 페이지 bitmap을 사용한다.

## 변경 파일 목록과 영향 범위

### 제품 코드

- `Sources/QLExtension/HwpPreviewProvider.swift`
  - PNG reply에서 PDF data reply로 전환
- `Sources/Shared/HwpPageImageRenderer.swift`
  - page index 기반 render helper 추가
  - `pageOutOfRange`, `pdfEncodingFailed` 오류 추가
- `Sources/Shared/HwpPreviewPDFRenderer.swift`
  - 전체 페이지 Quick Look PDF preview container 생성
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
- `mydocs/report/task_m010_85_report.md`

### 제외/미변경

- Rust core ABI 변경 없음
- `edwardkim/rhwp` core 코드 변경 없음
- `Sources/RhwpCoreBridge`의 AppKit/UIKit 비의존 경계 유지
- 사용자용 PDF export 기능 추가 없음
- Thumbnail extension의 다중 페이지 동작 추가 없음

## 정량 확인

| 샘플 | 원본 page count | Quick Look preview PDF page count | 결과 |
|------|------------------|-----------------------------------|------|
| `samples/basic/KTX.hwp` | 1 | 1 | OK |
| `samples/hwp-multi-001.hwp` | 10 | 10 | OK |
| `samples/hwpx/hwpx-01.hwpx` | 9 | 9 | OK |

## 검증 결과

| 검증 항목 | 결과 |
|-----------|------|
| `git diff --check` | OK |
| `./scripts/check-no-appkit.sh` | OK |
| `./scripts/validate-stage3-render.sh` | OK |
| HostApp Debug build | OK (`** BUILD SUCCEEDED ** [0.462 sec]`) |
| Release package build | OK (`** BUILD SUCCEEDED ** [15.353 sec]`) |
| Release zip SHA-256 | `a417259d0a72e08c4e87947bed33f792650a304277e28d44c5c7a01e193a7a2f` |
| 설치 app codesign verify | OK |
| PlugInKit QLExtension 등록 | OK |
| PlugInKit ThumbnailExtension 등록 | OK |
| `qlmanage -p samples/hwp-multi-001.hwp` | OK, exit code 0 |
| `qlmanage -p samples/hwpx/hwpx-01.hwpx` | OK, preview 세션 유지 후 수동 종료 |
| `qlmanage -t -x -s 512` thumbnail | OK, HWP/HWPX 3개 PNG 생성 |
| PDF page count smoke | OK, HWP 10 page/HWPX 9 page 확인 |

## PDF 방식의 의미

이번 작업에서 PDF를 쓰는 이유는 macOS Quick Look이 다중 페이지 preview를 자연스럽게 표시할 수 있는 content type이기 때문이다. HWP/HWPX 원본을 PDF 문서 구조로 변환하지 않는다. 텍스트, 문단, 표, 객체를 PDF semantics로 export하는 기능도 아니다.

실제 렌더링 기준은 기존 rhwp render tree와 `CGTreeRenderer`다. PDF에는 각 페이지의 bitmap 렌더 결과만 들어간다.

## 잔여 위험과 후속 작업

- 모든 페이지를 한 번에 렌더링하므로 긴 문서에서 초기 preview latency와 extension 메모리 사용량이 커질 수 있다. 실제 문제가 확인되면 page cap 또는 점진 렌더링 정책을 별도 이슈로 승인받아 다룬다.
- 자동화 환경에서 Quick Look 창 내부 스크롤 조작까지 캡처하지는 못했다. 다중 페이지 산출은 PDF page count smoke로 확인했다.
- `qlmanage -p -o` 출력 파일 모드는 이 환경에서 ExtensionFoundation 예외로 종료했다. 일반 `qlmanage -p` preview와 `qlmanage -t` thumbnail은 통과했다.

## 작업지시자 승인 요청

- 본 최종 보고서 검토
- 승인 후 `publish/task85` 원격 push 및 devel 대상 draft PR 생성 진행
