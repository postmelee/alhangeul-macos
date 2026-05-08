# Task M016 #146 Stage 3 보고서 - 렌더 경로 문서 보정

## 단계 목적

Stage 2에서 설계한 v0.1 렌더링 경로와 알려진 제한 사항을 README, 아키텍처 문서, 릴리스/배포 가이드에 반영했다. 이번 단계의 목표는 public 사용자 문서와 운영 문서가 HostApp viewer, PDF 내보내기, 인쇄, Quick Look preview, Finder thumbnail의 실제 경로 차이를 과장 없이 설명하도록 맞추는 것이다.

## 산출물

| 파일 | 내용 |
|------|------|
| `README.md` | Rendering Paths 표로 v0.1 표면별 렌더링 경로를 정리하고, v0.1 Known Limitations 요약을 추가 |
| `mydocs/tech/project_architecture.md` | HostApp viewer 화면과 HostApp PDF export 경로를 분리하고, PDF export runtime flow를 `exportHwp` payload -> `RhwpDocument` -> `HwpPreviewPDFRenderer` 경로로 보정 |
| `mydocs/manual/release_distribution_guide.md` | public release note에 렌더링 경로, 알려진 한계, 실제 smoke 결과와 수동 확인 항목을 포함하는 기준 추가 |

변경 규모는 `README.md` 22줄, `project_architecture.md` 13줄, `release_distribution_guide.md` 20줄 diff이며 전체 합계는 42줄 추가, 13줄 삭제다.

## 본문 변경 정도 / 본문 무손실 여부

- Swift/Rust 소스, Xcode project, bundled `rhwp-studio` asset, release note script는 변경하지 않았다.
- `mydocs/tech/product_roadmap_notes.md`는 Stage 3 검증 대상에 포함했지만 기존 로드맵 문구만으로 충분해 수정하지 않았다.
- README의 기존 기능/설치/기여 안내는 유지하고, Rendering Paths 섹션을 표와 제한 사항 요약으로 교체했다.
- 아키텍처 문서는 현재 코드 경로와 어긋나던 PDF export 설명을 보정했으며, 기존 HostApp/Quick Look/Thumbnail 흐름은 유지했다.

## 주요 변경

### README

- HostApp viewer/editor 화면은 `rhwp-studio` Web/WASM을 WKWebView에서 실행하는 경로로 명시했다.
- PDF 내보내기는 Rust bridge와 Swift native render tree PDF 경로를 사용하며, 앱 화면과 같은 renderer를 쓰지 않는다고 분리했다.
- 인쇄는 `rhwp-studio` page payload를 별도 WKWebView/PDFKit/AppKit print operation으로 처리한다고 정리했다.
- Quick Look preview와 Finder thumbnail은 Rust bridge + Swift native render tree bitmap/cache 계열로 설명했다.
- v0.1 Known Limitations에 renderer 차이, smoke와 시각 결과의 차이, fallback의 비복구 성격, native renderer parity 후속 범위를 추가했다.

### 아키텍처 문서

- HostApp MVP viewer 화면은 native render tree를 직접 호출하지 않지만, HostApp PDF export는 `Shared/HwpPreviewPDFRenderer`와 native render tree 경로를 사용한다고 분리했다.
- `RhwpCoreBridge` 공유 범위를 HostApp 화면 전체가 아니라 HostApp PDF export, Quick Look preview, Finder thumbnail, 장기 Swift native viewer/editor 전환 경로로 정정했다.
- PDF export runtime flow를 `rhwp-studio` page SVG response 기반 설명에서 `exportHwp` response bytes를 native로 전달해 `RhwpDocument`와 `HwpPreviewPDFRenderer`로 PDF를 생성하는 설명으로 바꿨다.
- print runtime flow는 실제 payload 성격에 맞춰 page HTML/SVG payload와 별도 WKWebView/PDFKit/AppKit 출력 경로로 완화했다.

### release guide

- public release note에는 artifact/provenance/checksum뿐 아니라 v0.1 렌더링 경로와 알려진 한계를 함께 기록하도록 기준을 추가했다.
- Quick Look/Thumbnail 설치본 smoke는 extension 등록과 HWP/HWPX thumbnail 생성 확인이며, preview 수동 확인과 native renderer visual parity를 대체하지 않는다고 명시했다.
- 실행하지 않은 `qlmanage -p`, Finder Space preview, public DMG Gatekeeper 검증은 성공으로 쓰지 않고 수동 확인 또는 후속 확인으로 분리하도록 했다.
- GitHub Release checklist와 release note 포함 항목에 렌더링 경로, 알려진 한계, 수동 확인 항목을 추가했다.

## 검증 결과

Stage 3 구현계획서의 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과: `local/task146`에서 `README.md`, `mydocs/tech/project_architecture.md`, `mydocs/manual/release_distribution_guide.md`만 수정 상태로 확인했다.

```bash
rg -n "Rendering Paths|렌더링 경로|Known Limitations|알려진 제한|WKWebView|rhwp-studio|Quick Look|Thumbnail|PDF 내보내기|인쇄|native renderer|v0\\.5|smoke" \
  README.md \
  mydocs/tech/project_architecture.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/tech/product_roadmap_notes.md
```

결과: README의 Rendering Paths/Known Limitations, 아키텍처 문서의 HostApp/PDF/print/Quick Look/Thumbnail 경로, release guide의 public release note 기준과 smoke 분리 문구가 확인됐다. `product_roadmap_notes.md`에는 기존 WKWebView/native viewer 로드맵 문구가 유지되어 별도 수정하지 않았다.

```bash
rg -n "완전 호환|완벽|100%|동일" README.md mydocs/tech/project_architecture.md mydocs/manual/release_distribution_guide.md
```

결과: 새 known limitations 문구에는 완전 호환 또는 100% 보장 표현이 없었다. 남은 match는 기존 문맥의 `filesystem name과 동일`, `동일 요청 또는 더 큰 cached bitmap`, 기여 안내의 `동일 영역`뿐이라 과장 표현으로 보지 않았다.

```bash
git diff --check
```

결과: whitespace error 없이 통과했다.

## 잔여 위험

- `scripts/ci/write-release-notes.sh`는 아직 렌더링 경로와 알려진 제한 사항 섹션을 생성하지 않는다. Stage 4에서 별도 보강해야 한다.
- 이번 단계는 문서 보정만 수행했으므로 Xcode build, Rust build, Finder/Quick Look smoke는 실행하지 않았다.
- README의 Known Limitations는 public 사용자용 요약이다. 상세 renderer parity 항목과 검증 이력은 최종 보고서와 후속 native renderer task에서 다룬다.

## 다음 단계 영향

Stage 4에서는 release note skeleton이 README와 release guide의 책임 경계를 따라 `렌더링 경로와 알려진 제한 사항` 섹션을 생성하도록 `scripts/ci/write-release-notes.sh`를 보강한다. dummy release note output을 만들어 provenance, 설치 안내, renderer 경로, known limitations가 함께 존재하는지 확인한다.

## 승인 요청

Stage 3 `README와 운영 문서 보정`을 완료했다. Stage 4 `release note skeleton과 검증 정리`로 진행해도 되는지 승인 요청한다.
