# Task M016 #146 최종 보고서 - Viewer와 Quick Look/Thumbnail 렌더 경로 한계 문서화

## 작업 요약

- 이슈: [#146](https://github.com/postmelee/alhangeul-macos/issues/146)
- 마일스톤: M016 (`v0.1 출시 전 보강`)
- 브랜치: `local/task146`
- 기준 브랜치: `devel-webview`
- 단계 수: 수행계획서, 구현계획서, Stage 1-4, Stage 5 최종 보고
- 목표: v0.1 사용자가 HostApp viewer/editor와 PDF 내보내기, 인쇄, Quick Look preview, Finder thumbnail의 렌더링 경로 차이와 smoke gate의 의미를 오해하지 않도록 문서화한다.

이번 작업은 문서와 release note skeleton 정합화만 수행했다. Swift/Rust renderer, extension 코드, `project.yml`, Xcode project, bundled `rhwp-studio` asset, milestone/issue 재분류는 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `README.md` | Rendering Paths 표와 v0.1 Known Limitations 섹션을 추가해 HostApp viewer/editor, PDF 내보내기, 인쇄, Quick Look preview, Finder thumbnail 경로를 public 사용자 문서에서 구분 |
| `mydocs/tech/project_architecture.md` | HostApp MVP viewer 화면과 HostApp PDF export 경로를 분리하고, PDF export runtime flow를 `exportHwp` payload -> `RhwpDocument` -> `HwpPreviewPDFRenderer` 경로로 보정 |
| `mydocs/manual/release_distribution_guide.md` | public release note에 렌더링 경로, 알려진 한계, 실제 smoke 결과와 수동 확인 항목을 포함하는 기준 추가 |
| `scripts/ci/write-release-notes.sh` | release note skeleton에 `렌더링 경로와 알려진 제한 사항` 섹션을 추가하고, smoke 결과와 preview 수동 확인 여부를 최종 보고서로 연결 |
| `mydocs/plans/task_m016_146.md` | #146 수행계획서 작성 |
| `mydocs/plans/task_m016_146_impl.md` | 5단계 구현계획서 작성 |
| `mydocs/working/task_m016_146_stage1.md` | HostApp/PDF/print/Quick Look/Thumbnail 실제 경로 inventory 정리 |
| `mydocs/working/task_m016_146_stage2.md` | known limitations 문구와 milestone 분리 기준 설계 |
| `mydocs/working/task_m016_146_stage3.md` | README, 아키텍처 문서, release guide 보정 결과와 검증 기록 |
| `mydocs/working/task_m016_146_stage4.md` | release note skeleton 보강 결과와 dummy output 검증 기록 |
| `mydocs/orders/20260508.md` | #146 오늘할일 상태를 완료로 갱신 |

## 렌더링 경로 최종 정리

| 표면 | 문서화한 v0.1 경로 | 공개한 한계 |
|------|-------------------|-------------|
| HostApp viewer/editor 화면 | bundled `rhwp-studio` Web/WASM을 WKWebView에서 실행 | 첫 공개 배포의 viewer/editor 경로이며 native viewer 전환 전 fallback/비교 기준 |
| PDF 내보내기 | `rhwp-studio`가 export한 HWP bytes를 native로 전달하고 Rust bridge + Swift native render tree PDF 경로로 생성 | 앱 화면과 같은 renderer를 쓰지는 않음 |
| 인쇄 | `rhwp-studio` page payload를 별도 WKWebView/PDFKit/AppKit 출력 경로로 처리 | PDF 내보내기와도 다른 출력 경로 |
| Quick Look preview | Rust bridge + Swift native render tree bitmap/PDF 경로 | smoke 통과가 visual parity 보장은 아님 |
| Finder thumbnail | Rust bridge + Swift native first-page bitmap/cache 경로 | thumbnail 생성 성공이 문서 전체 호환성 보장은 아님 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| README 렌더링 경로 설명 | bullet 6개 중심 | 표 + v0.1 Known Limitations 4개 bullet |
| release note skeleton | 설치, 산출물, core, viewer asset, Third Party, 검증 | 위 항목 + `렌더링 경로와 알려진 제한 사항` 섹션 |
| 아키텍처 PDF export 설명 | page SVG response 기반 설명 | `exportHwp` response bytes -> native `RhwpDocument`/`HwpPreviewPDFRenderer` 설명 |
| 단계 보고서 | 없음 | Stage 1-4 보고서 4개 |
| 브랜치 diff | 없음 | 최종 보고 전 기준 11개 파일, 957 insertions, 14 deletions |
| Xcode/Rust 소스 변경 | 없음 | 없음 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행계획 | `51d92bb` | 오늘할일 등록과 수행계획서 작성 |
| 구현계획 | `16a1c4a` | 5단계 구현계획서 작성 |
| Stage 1 | `cf124a3` | 실제 renderer 경로와 기존 문서 표현 inventory 확정 |
| Stage 2 | `b9dfe58` | known limitations 문구, 문서별 소유 범위, milestone 분리 기준 설계 |
| Stage 3 | `52674b2` | README, `project_architecture.md`, `release_distribution_guide.md` 보정 |
| Stage 4 | `f54868c` | `write-release-notes.sh` skeleton에 렌더링 경로와 알려진 제한 사항 섹션 추가 |

## 수용 기준 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| README에서 HostApp viewer와 Quick Look/Thumbnail 경로가 모순 없이 설명됨 | OK | Rendering Paths 표와 Known Limitations 섹션 추가 |
| PDF export와 print가 viewer 화면 경로와 같은 renderer라고 오해되지 않음 | OK | README 표, 아키텍처 runtime flow, release note skeleton에서 각각 다른 경로로 설명 |
| release note skeleton에 v0.1 known limitations 또는 renderer 경로 한계 섹션 포함 | OK | `scripts/ci/write-release-notes.sh`에 `렌더링 경로와 알려진 제한 사항` 섹션 추가 |
| Quick Look/Thumbnail smoke gate와 native renderer visual parity가 별도 문제로 설명됨 | OK | README, release guide, release note skeleton에 smoke와 시각 결과 보장을 분리 |
| 손상·대용량·미지원 입력 fallback이 완전 복구나 완전 호환으로 표현되지 않음 | OK | fallback은 raw error, hang, crash 방지 안전장치로 표현 |
| native renderer parity 개선은 v0.5 이후 후속 범위로 남음 | OK | README와 release note skeleton에 v0.5 이후 Swift native viewer 범위로 명시 |
| renderer 구현, milestone 이동, release 실행 작업은 이번 PR에 포함되지 않음 | OK | 문서와 release note skeleton만 변경 |

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `git status --short --branch` | OK | Stage 5 시작 시 worktree clean |
| `bash -n scripts/ci/write-release-notes.sh` | OK | release note helper syntax 통과 |
| `bash scripts/ci/write-release-notes.sh 0.1.0 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef /tmp/alhangeul-task146-release-note.md` | OK | dummy release note 생성 |
| `rg -n "렌더|Quick Look|Thumbnail|WKWebView|rhwp-studio|PDF|인쇄|한계|제한|smoke|최종 보고서|rhwp core|Third Party" /tmp/alhangeul-task146-release-note.md` | OK | provenance, Third Party, 렌더링 경로, 제한사항, 최종 보고서 연결 문구 확인 |
| `rg -n "Rendering Paths|렌더링 경로|Known Limitations|알려진 제한|WKWebView|rhwp-studio|Quick Look|Thumbnail|PDF 내보내기|인쇄|native renderer|v0\\.5|smoke" README.md mydocs/tech/project_architecture.md mydocs/manual/release_distribution_guide.md mydocs/tech/product_roadmap_notes.md` | OK | README/아키텍처/release guide 문구 확인 |
| `rg -n "완전 호환|완벽|100%|동일" README.md mydocs/tech/project_architecture.md mydocs/manual/release_distribution_guide.md` | OK | 남은 match는 기존 filesystem/cache/기여 안내 문맥으로 과장 표현 아님 |
| `git diff --check` | OK | whitespace error 없음 |

구현계획서 Stage 4의 직접 실행 예시는 현재 file mode가 100644라 `permission denied`가 발생했다. 기존 release workflow와 #145 선례가 `bash scripts/ci/write-release-notes.sh ...` 방식으로 호출하므로 file mode 변경 없이 같은 방식으로 검증했다.

## 실행하지 않은 검증

| 항목 | 사유 |
|------|------|
| Xcode build/test | Swift/AppKit/Rust 소스 변경 없음 |
| Rust bridge 재생성/검증 | FFI, `rhwp-core.lock`, `Rhwp.xcframework` 변경 없음 |
| Finder/Quick Look smoke | extension 구현 변경 없음 |
| public DMG signing/notarization/Gatekeeper | release 실행 작업이 이번 범위가 아님 |

## 잔여 위험과 후속 작업

- release note skeleton은 실제 smoke 결과를 자동 수집하지 않는다. public release 시점에는 workflow 결과와 최종 릴리스 보고서를 기준으로 성공/미실행 항목을 별도 기록해야 한다.
- native renderer의 style, image effect/fill, text layout, RawSvg/OLE 등 parity 개선은 v0.5 이후 Swift native viewer 범위로 남아 있다.
- v0.2 범위의 문서 정보/본문 추출, Spotlight/mdimporter, Mac 서비스 연동은 이번 #146에서 다루지 않았다.
- v0.6/v1.0 범위의 Swift native editor와 저장 안정성, round-trip 검증은 후속 milestone에서 다룬다.

## 승인 요청

#146 문서화 작업을 완료했다. PR 생성 후 `devel-webview` 대상 리뷰와 merge 승인을 요청한다.
