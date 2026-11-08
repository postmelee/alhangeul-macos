# Task M020 #600 최종 결과보고서

2026-11-09 · [이슈 #600](https://github.com/postmelee/alhangeul-macos/issues/600) · [수행계획](../plans/task_m020_600.md) · [구현계획](../plans/task_m020_600_impl.md)

## 릴리스 인계

알한글 v0.2.4 / build 22의 검증된 제품 커밋은 `22717d830efb0b8a72e6986e4d67711f1a7db8e3`이다. RustBridge, 내장 Studio와 글꼴 matcher의 기준을 공식 rhwp v0.8.7에서 v0.9.0(`c9095c5f67632e6721e800ccc7fb43ea49d26682`)으로 올렸다. #594 편집 복구와 #600 글꼴 수정을 함께 검증한 뒤 #601의 패키징 입력으로 기록했다. 이전 리허설 DMG는 글꼴 수정 전 제품 커밋 `7a0103a4`에서 생성했다. [v0.2.4 릴리스 준비 기록](../release/v0.2.4.md)

| 단계 | 결과 | 커밋 |
|---|---|---|
| [1. 공식 태그 호환성](../working/task_m020_600_stage1.md) | HFT 공급, 편집 오류 보고, 웹 글꼴 요청 기한의 태그 포함 및 호스트 API를 확인했다. 공식 Studio 회귀 59건 통과. | `014873eb` |
| [2. 후보 생성](../working/task_m020_600_stage2.md) | 동일 태그에서 universal bridge·WASM·Studio·matcher를 생성했다. 새 점선 형식의 Swift 디코딩과 그리기를 수정하고 #594에 공식 번들을 전달했다. | `f4bb8b03` |
| [3. 소비자 수정](../working/task_m020_600_stage3.md) | 조판 전 HFT 선택, Regular만 있는 문서의 굵게 출력, 네이티브 공백 처리를 수정했다. 실제 sample10 두 형식으로 화면·재열기·PDF·네이티브 출력을 검증했다. | `b7bba77d` |
| [4. 통합 검증](../working/task_m020_600_stage4.md) | #601 후보 `33013d24`와 글꼴 수정을 통합했다. 제품 자산별 SHA-256과 동일 커밋의 글꼴·복구 결과를 #601에 인계했다. | 제품 `22717d83`, 인계 문서 `291040a5` |

## sample10에서 달라진 동작

HWPX에서는 외부 공급자를 연결했을 때 첫 조판에서 딸기가 돋움으로 바뀌었다. 알한글은 원본 문서의 선언과 공급 가능한 글꼴을 대조해 딸기를 조판 전에 전달한다. HWP3에서는 화면에서 딸기를 사용해도 PDF 출력 시 문서의 굵기 700과 설치된 Regular의 굵기 400이 달라 출력이 중단됐다. 확인한 로컬 딸기 파일은 `HGSTRBRY.otf` 한 개로, PostScript 이름은 `Strawberry-HGSTRBRY`다.

실제 Bold가 있으면 그 파일을 우선 선택한다. 같은 HFT 가족에 지원되는 Regular CFF만 있으면 원본 글자를 한 번 그리고 윤곽에 공식 rhwp PDF와 같은 0.02em 굵게 효과를 적용한다. 두 sample10의 첫 쪽 PDF에서 딸기 임베딩을 확인했고, PDFKit과 Poppler가 ‘창원대학교 데이타베이스 연구실’을 각각 한 번 추출했다. 이 결과는 해당 표지의 수평 글줄에서 검증했다. [원본과 공식 렌더러 대조](../working/task_m020_600_stage3.md)

## 통합 후보 검증 결과

| 검사 | 결과 |
|---|---|
| 딸기 공급과 재열기 | HWP3·HWPX 모두 가져오기·재열기에서 원본 OTF를 읽었고, 해제하면 미공급 화면이 복원됐다. 3단계와 비교한 Studio 첫 쪽 PNG·SVG·PDF 래스터가 각 6건, CoreGraphics·Skia PNG가 8건 일치했다. |
| 다른 글꼴의 편집·저장 | 고운바탕 Regular·Bold 공급·재열기 검사 40건 통과. 저장본 2개를 다시 열어 총 6개 위치의 글꼴 이름·굵게 상태를 확인했다. |
| #594 편집 복구 | 일반 조건 40건, CDN 무응답 44건 통과. 같은 창에서 내용과 선택을 보존했고 undo/redo 및 후속 저장·재열기가 성공했다. 복구를 확인할 수 없는 경우 저장을 차단했다. |
| HostApp 및 Release 번들 | XCTest 265건 통과. 미서명 Release 앱·Quick Look·Thumbnail·Spotlight 모두 arm64·x86_64 및 0.2.4 / 22를 확인했다. 내장 Studio 109개 파일, Legal 4개 파일과 matcher receipt가 소스와 일치했다. |

## 남은 조사와 배포 검증

같은 sample10 HWPX를 Windows 한컴에서 Microsoft Print to PDF로 출력한 결과와 비교하면 표지 대상 줄이 공식 rhwp PDF에서 약 4.1pt, 알한글 PDF에서 약 4.0pt 오른쪽에 있다. 가운데 정렬을 계산할 때 처음 차이가 생기는 지점과 공식 Studio 외부 글꼴 공급자의 HFT 조회 시점은 rhwp 프로젝트에서 각각 추적한다. [동일 HWPX 대조와 통합 검증 범위](../working/task_m020_600_stage4.md)

전체 763쪽 대조와 물리 프린터 출력은 미실행이다. #601에서 새 제품 후보를 패키징한 뒤 확인할 항목은 배포 서명·공증 DMG의 설치·업데이트, 서명본의 Finder 동작, Intel 및 최소 지원 macOS 실기다. [릴리스 준비 기록](../release/v0.2.4.md)
