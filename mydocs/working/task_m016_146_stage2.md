# Task M016 #146 Stage 2 보고서 - known limitations 문구 설계

## 단계 목적

Stage 1 inventory를 기준으로 v0.1 release 문서에 넣을 렌더 경로와 known limitations 문구를 설계했다. 이번 단계에서는 README, 아키텍처 문서, release guide, release note script를 직접 수정하지 않고, Stage 3-4에서 적용할 문서별 소유 범위와 문구 초안을 확정했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m016_146_stage2.md` | known limitations 범주, 문서별 소유 범위, 사용자-facing 문구 초안, milestone 분리 기준, Stage 3-4 수정 방향 |

## 본문 변경 정도 / 본문 무손실 여부

- 본문 소스, README, 아키텍처 문서, release guide, release note script는 변경하지 않았다.
- Stage 2 산출물은 설계 보고서 1개뿐이다.
- Stage 1의 inventory 결론은 유지했고, 문서화 방향만 구체화했다.

## known limitations 범주

| 범주 | 사용자-facing 요지 | 개발자 근거 | 후속 범위 |
|------|--------------------|-------------|-----------|
| 렌더 경로 차이 | 앱 화면 viewer와 Finder/Quick Look, PDF export, print는 같은 renderer를 쓰지 않는다. 같은 문서라도 경로별 표시 차이가 있을 수 있다. | HostApp viewer/editor 화면은 WKWebView `rhwp-studio`; Quick Look/Thumbnail/PDF export는 Rust bridge + Swift native render tree 계열; print는 `rhwp-studio` page payload를 별도 WKWebView/PDFKit/AppKit으로 처리한다. | v0.5 native viewer에서 경로 통합과 parity 개선 |
| native renderer parity | Finder preview/thumbnail과 PDF export는 v0.1에서 기본 표시와 smoke를 목표로 하며, 모든 HWP/HWPX 시각 요소를 완전히 재현하지 않는다. | `validate-stage3-render.sh` smoke는 통과해도 style, image effect/fill, text layout, body overflow, RawSvg/OLE 등은 pixel/visual parity 보장이 아니다. | v0.5 native renderer parity, visual diff corpus |
| fallback 한계 | 손상·대용량·미지원 문서는 crash/hang/raw error 대신 fallback을 보이도록 처리하지만, 복구나 부분 렌더링을 보장하지 않는다. | #149에서 HostApp 50 MB hard block은 두지 않았고, 50 MB 제한은 Quick Look/Thumbnail preview 제한으로 유지했다. HWPX preflight는 ZIP magic 수준이다. | corrupt corpus 확장, 대용량 성능/호환성 후속 |
| 검증 한계 | 설치본 smoke gate는 extension 등록과 HWP/HWPX thumbnail 생성 확인까지 자동화한다. preview 시각 품질과 renderer parity는 별도 확인 대상이다. | #151에서 `qlmanage -t -x` 자동 thumbnail gate와 `qlmanage -p`/Finder Space 수동 preview 확인을 분리했다. | public DMG smoke, visual QA, native renderer 후속 |
| WKWebView runtime 한계 | `rhwp-studio` viewer는 custom scheme 환경에서 일부 PWA 부가 기능 오류가 발생할 수 있으며, 문서 렌더와 무관한 benign runtime issue는 fatal fallback으로 취급하지 않는다. | #150에서 service worker registration류 false positive를 fatal fallback에서 제외했다. asset/document/navigation/runtime failure는 별도 fallback taxonomy로 분리했다. | WKWebView asset/runtime fallback 유지보수 |
| release 한계 | v0.1 public artifact는 signed/notarized DMG를 기준으로 하지만, release note는 smoke 결과와 known limitations를 함께 공개해야 한다. | #148/#145/#151은 artifact/provenance/smoke 기준을 분리했고, `write-release-notes.sh`는 아직 limitations 섹션이 없다. | Stage 4 release note skeleton 보강 |

## 문서별 소유 범위

| 문서/파일 | 소유할 내용 | 넣지 않을 내용 |
|-----------|-------------|----------------|
| `README.md` | public 사용자용 짧은 요약. Rendering Paths를 표로 정리하고 v0.1 알려진 제한 사항을 4-6개 bullet로 제공한다. | renderer 내부 함수명, 과거 task 번호 전체 목록, 디버깅 절차, 긴 known issue catalog |
| `mydocs/tech/project_architecture.md` | 실제 runtime data flow. HostApp viewer, PDF export, print, Quick Look, Thumbnail 경로를 코드 기준으로 정확히 맞춘다. | 사용자-facing 과장/마케팅 문구, release note 문장 |
| `mydocs/manual/release_distribution_guide.md` | release note에 known limitations와 smoke 결과를 반드시 포함하는 운영 기준. #151 smoke gate와 #146 known limitations의 관계. | README와 같은 사용자 설명의 중복 표 전체 |
| `scripts/ci/write-release-notes.sh` | public GitHub Release note skeleton에 `렌더링 경로와 알려진 제한 사항` 섹션을 추가한다. | 상세 task 보고서 본문 복제, 동적으로 검증하지 않은 smoke 성공 주장 |
| `mydocs/report/task_m016_146_report.md` | 문서화 근거, 변경 파일, 검증 결과, 남은 renderer parity 후속 범위. | 사용자가 먼저 보는 release note 대체 문서 역할 |

## README 문구 초안

Stage 3에서 README에는 다음 수준의 짧은 사용자-facing 문구를 적용한다.

```md
### v0.1 알려진 제한 사항

- 앱 화면의 viewer/editor는 `rhwp-studio`를 WKWebView에서 실행하는 경로이고, Quick Look preview와 Finder thumbnail은 Rust bridge + Swift native renderer 경로입니다.
- PDF 내보내기는 현재 문서 bytes를 native render tree PDF 경로로 다시 렌더링하므로, 앱 화면과 출력물이 완전히 같은 renderer를 쓰지는 않습니다.
- Quick Look/Thumbnail smoke 통과는 extension 등록과 기본 렌더 성공을 뜻하며, 모든 문서의 시각적 동일성을 보장하지 않습니다.
- 손상·대용량·미지원 문서 fallback은 앱과 extension이 멈추지 않도록 하는 안전장치이며, 파일 복구나 부분 렌더링을 보장하지 않습니다.
- native renderer의 style, image effect/fill, text layout, RawSvg/OLE 등 parity 개선은 v0.5 이후 Swift native viewer 범위에서 계속 다룹니다.
```

README의 Rendering Paths는 bullet 나열보다 표가 더 적합하다. Stage 3에서는 다음 축을 기준으로 정리한다.

| 표면 | v0.1 renderer | 한계 문구 |
|------|---------------|-----------|
| HostApp viewer/editor | WKWebView `rhwp-studio` | 첫 배포 기준선, native viewer 전 fallback/비교 기준 |
| PDF export | Rust bridge + Swift native render tree PDF | 앱 화면과 동일 renderer가 아님 |
| Print | `rhwp-studio` page payload + 별도 WKWebView/PDFKit/AppKit | PDF export와 다른 출력 경로 |
| Quick Look preview | Rust bridge + Swift native render tree bitmap/PDF | smoke와 visual parity 분리 |
| Finder thumbnail | Rust bridge + Swift native first-page bitmap/cache | 문서 전체 호환성 보장 아님 |

## 아키텍처 문서 보정 방향

Stage 3에서 `project_architecture.md`는 다음 보정을 적용한다.

| 위치 | 보정 방향 |
|------|-----------|
| HostApp 제품 타깃 설명 | HostApp 화면 viewer는 native render tree를 호출하지 않지만, PDF export는 HostApp 서비스에서 native preview/PDF renderer를 호출한다는 점을 분리한다. |
| Shared 설명 | `HwpPreviewPDFRenderer`가 Quick Look뿐 아니라 HostApp PDF export에서도 재사용된다는 점을 추가한다. |
| RhwpCoreBridge 설명 | “HostApp, Quick Look, Thumbnail이 모두 공유”를 “HostApp PDF export와 Quick Look/Thumbnail, 장기 native viewer 전환 경로가 공유”처럼 viewer 화면과 구분한다. |
| HostApp runtime flow | `PDF로 내보내기` 단계는 `exportHwp` payload -> `RhwpDocument` -> `HwpPreviewPDFRenderer` native PDF 생성으로 수정한다. |
| print runtime flow | “page SVG response”를 “page HTML/SVG payload” 또는 “page payload”로 완화해 실제 `RhwpStudioPrintController` 경로와 맞춘다. |

## release guide 보정 방향

Stage 3에서 `release_distribution_guide.md`에는 다음 운영 기준을 추가한다.

- public release note에는 artifact/provenance/checksum만이 아니라 렌더링 경로와 known limitations를 포함한다.
- #151 smoke gate 결과는 “설치본 extension 등록과 thumbnail 생성” 증거이며, preview 수동 확인과 native renderer visual parity를 대체하지 않는다.
- known limitations에는 최소한 다음을 포함한다.
  - HostApp viewer와 Quick Look/Thumbnail/PDF export의 renderer 차이
  - native renderer parity 미보장
  - 손상/대용량 fallback의 비복구 성격
  - public DMG smoke와 local Release package smoke의 차이
- release note에서 smoke 결과를 적을 때 실제 실행한 항목만 쓴다. 실행하지 않은 `qlmanage -p`, Finder Space preview, public DMG Gatekeeper 검증은 “수동/후속”으로 분리한다.

## release note skeleton 구조

Stage 4에서 `scripts/ci/write-release-notes.sh`는 기존 구조를 유지하되, `Third Party notices`와 `검증` 사이 또는 `검증` 앞에 다음 섹션을 추가한다.

```md
## 렌더링 경로와 알려진 제한 사항

- 앱 viewer/editor 화면은 bundled `rhwp-studio`를 WKWebView에서 실행합니다.
- Quick Look preview, Finder thumbnail, PDF 내보내기는 Rust bridge와 Swift native renderer 계열 경로를 사용하므로 앱 화면과 표시가 다를 수 있습니다.
- 인쇄는 `rhwp-studio` page payload를 별도 WKWebView/PDFKit/AppKit 출력 경로로 처리합니다.
- v0.1은 기본 열기, preview, thumbnail, fallback, smoke를 목표로 하며 모든 HWP/HWPX 문서의 완전한 시각 동일성을 보장하지 않습니다.
- 손상·대용량·미지원 문서 fallback은 복구가 아니라 앱과 extension이 raw error나 중단으로 끝나지 않게 하는 안전장치입니다.
```

`검증` 섹션의 마지막 문장은 다음처럼 바꾸는 방향이 적합하다.

```md
- 상세 smoke test 결과, preview 수동 확인 여부, 알려진 제한 사항은 해당 릴리스의 최종 보고서를 기준으로 확인합니다.
```

## milestone 분리 기준

| milestone | 이번 문서에서의 기준 |
|-----------|----------------------|
| v0.1 | WKWebView viewer/editor, Quick Look/Thumbnail 기본 표시, PDF/print/share/save, fallback, smoke, release artifact/provenance를 공개한다. |
| v0.2 | 문서 정보/본문 추출, Spotlight/mdimporter, Finder/서비스/공유 extension 재사용 API처럼 앱 화면 밖의 정보 접근을 다룬다. |
| v0.5 | Swift native viewer, native renderer parity, visual diff, native viewport/zoom/search/copy를 다룬다. |
| v0.6/v1.0 | native editor 기반, 저장 안정성, 제한된 안전 편집, round-trip 검증을 다룬다. |

## 제외할 과한 상세

Stage 3-4 문서화에서 다음은 넣지 않는다.

- 각 과거 task의 전체 조사 내용과 commit 목록
- renderer 내부 함수명 전체 목록
- 모든 미지원 HWP control/object의 exhaustive catalog
- 법률 자문처럼 읽힐 수 있는 license 해석
- 실행하지 않은 public DMG Gatekeeper 검증 성공 주장
- `qlmanage -p` 또는 Finder Space preview를 자동 gate처럼 보이게 하는 표현
- 손상 파일 fallback을 파일 복구, partial rendering, data recovery처럼 읽히게 하는 표현

## 검증 결과

Stage 2 구현계획서의 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과: `## local/task146`

```bash
rg -n "known limitations|알려진 제한|한계|문서 호환성|렌더링 한계|native renderer|visual parity|smoke|fallback|v0\\.5|v0\\.2" \
  README.md mydocs/manual/release_distribution_guide.md mydocs/tech/project_architecture.md \
  scripts/ci/write-release-notes.sh \
  mydocs/report/task_m016_149_report.md \
  mydocs/report/task_m016_150_report.md \
  mydocs/report/task_m016_151_report.md \
  mydocs/report/task_m016_167_report.md
```

결과: README의 v0.2/v0.5/renderer smoke 문구, release guide의 smoke/알려진 한계 체크, release note skeleton의 최종 보고서 참조 문장, M016 보고서의 #146 handoff 항목을 확인했다.

Stage 2 보고서 작성 후에는 구현계획서의 보고서 대상 검증을 다시 실행한다.

```bash
rg -n "렌더 경로|known limitations|한계|v0\\.1|v0\\.2|v0\\.5|v0\\.6|v1\\.0|Quick Look|Thumbnail|WKWebView|fallback|smoke" \
  mydocs/working/task_m016_146_stage2.md
git diff --check
```

결과: Stage 2 보고서 안에서 렌더 경로, known limitations, milestone, Quick Look/Thumbnail, WKWebView, fallback, smoke 관련 설계 문구가 확인됐고, `git diff --check`는 whitespace error 없이 통과했다.

## 잔여 위험

- README에 known limitations를 너무 길게 넣으면 public 첫 화면의 가독성이 떨어질 수 있다. Stage 3에서는 요약 위주로 두고, 상세 근거는 최종 보고서로 넘긴다.
- release note skeleton은 실제 smoke 결과를 자동으로 수집하지 않는다. Stage 4 문구는 “실행한 결과를 최종 보고서에서 확인”하는 구조로 두어야 한다.
- PDF export는 `rhwp-studio`에서 export한 HWP bytes를 native renderer로 다시 PDF화하는 결합 경로다. 사용자 문구는 짧게 쓰되, 아키텍처 문서에는 정확한 data flow를 남겨야 한다.

## 다음 단계 영향

Stage 3에서는 이 설계에 따라 README, `project_architecture.md`, `release_distribution_guide.md`를 보정한다. Stage 4에서는 `scripts/ci/write-release-notes.sh`에 렌더 경로와 known limitations 섹션을 추가하고 dummy output으로 검증한다.

## 승인 요청

Stage 2 `known limitations와 milestone 분리 기준 설계`를 완료했다. Stage 3 `README와 운영 문서 보정`으로 진행해도 되는지 승인 요청한다.
