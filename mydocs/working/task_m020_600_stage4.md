# Task M020 #600 4단계 통합 검증 및 릴리스 인계

2026-11-09 · [구현계획](../plans/task_m020_600_impl.md) · [3단계 보고서](task_m020_600_stage3.md) · [v0.2.4 릴리스 준비 기록](../release/v0.2.4.md)

## 제품 후보

`local/task600`에서 글꼴 수정 `b7bba77d`와 #594 복구 변경을 포함한 #601 후보 `33013d24`를 병합했다. 제품 커밋은 `22717d830efb0b8a72e6986e4d67711f1a7db8e3`, 버전은 0.2.4 / build 22다. 이 커밋의 소스와 자산으로 HostApp과 각 probe를 빌드했다. T7 실경로가 필요한 probe는 같은 커밋의 git archive를 사용했다. native Frameworks는 3단계에서 고정한 파일을 사용하고 lock의 SHA-256과 다시 대조했다.

| 산출물 | 검증한 SHA-256 |
|---|---|
| Studio manifest | `ff3cd3090446c2bb78439bb388c15acce6884f1e4ef558b774cb5cd806203b6a` |
| Studio JS | `d7d4e244cab5c0c1285eec4798b404363c841bfdada54afbf431c6da61a36a4a` |
| WASM | `5feacb4a6f29ba1b8c3ad27c2ab29feb937f93b8c98a16c21979bc83787134de` |
| native matcher receipt | `dde9fe0057630144e5e3831fbb76f02e2d9c2e61f4a99227b5a9388981f7bdf0` |
| universal archive | `d2e31bc11f49d0a40f20c6bf8b8cd7f37ebdfe03bc64577e03aa33bf2225353b` |
| 생성 헤더 | `45c5145b8e26801e699ed5668a69c9a6cc44d0989a3d62477fb8147211f908e6` |

## sample10 글꼴과 출력

3단계와 동일한 HWP3·HWPX, 딸기 Regular OTF를 사용했다. 각 형식의 첫 쪽 ‘창원대학교 데이타베이스 연구실’을 검사했다.

| 검사 | 통합 후보에서 확인한 결과 |
|---|---|
| Studio 화면 | 두 형식 모두 관리 라이브러리로 가져온 뒤 실제 Strawberry-HGSTRBRY와 원본 SHA를 읽었다. 새 프로세스에서 다시 연 화면은 가져온 직후와 같았다. 열린 문서에서 글꼴을 해제하면 미공급 화면·출력 SVG가 복원됐다. |
| PDF·인쇄 준비 | 두 형식의 가져오기·재열기에서 문서 요청 굵기 700, 선택한 face 굵기 400, 굵게 효과 및 실제 PS 임베딩을 확인했다. PDFKit과 Poppler 모두 대상 문장을 순서대로 한 번 추출했다. |
| 네이티브 | 두 형식 × CoreGraphics·Skia 모두 지정한 backend에서 공급 시 원본 1,925,224바이트를 1회 읽었다. 미공급 대조에서는 읽기 0회였다. |
| 3단계 출력 대조 | 두 형식 × 미공급·가져오기·재열기의 화면 PNG·출력 SVG가 각각 동일했다. PDF도 첫 쪽을 1190×1682 회색조로 변환한 결과가 6건 모두 같았다. 두 형식의 네이티브 PNG도 공급 유무와 backend별 8건이 모두 일치했다. |
| 일반 글꼴 회귀 | 고운바탕 Regular·Bold 공급·설정 전환·새 프로세스 재열기 31+5+4건이 통과했다. 저장한 HWP·HWPX를 다시 열어 두 형식의 오프셋 0·3·24에서 원래 글꼴 이름과 굵게 상태를 확인했다. |

동일 HWPX의 Windows 한컴 Microsoft Print to PDF와 비교한 앞선 측정에서, 이 한 줄의 가로 위치는 공식 rhwp PDF가 약 4.1pt, 알한글 PDF가 약 4.0pt 오른쪽이었다. 이번 검증에서 해당 알한글 출력의 첫 쪽 래스터가 3단계와 일치했다. 원인 추적과 공식 Studio 외부 공급자의 HFT 조판 전 조회는 rhwp 프로젝트의 별도 조사다.

## #594 복구와 제품 조립

| 검사 | 통합 후보에서 확인한 결과 |
|---|---|
| 정상 네트워크 | 실제 WKWebView에 편집 명령 실패를 주입해 40건 통과. HWP·HWPX 준비 3.01초·0.81초. 같은 창의 내용·선택, undo/redo와 후속 저장·재열기를 확인했다. |
| 웹 글꼴 CDN 무응답 | 같은 검사 44건 통과. 두 창 모두 요청 2건을 취소하고 5.80초·5.69초에 준비됐다. 복구 중 저장 거부와 미준비 오류의 보호 동작, 원본 보존 및 검사 앱 등록 해제를 확인했다. |
| 출처·회귀 | 공식 v0.9.0 커밋 `c9095c5f67632e6721e800ccc7fb43ea49d26682` 기준 Studio 자산 대조, matcher 검증, core build-info, host 글꼴 테스트 35건 및 render-tree golden 검증 통과. |
| HostApp | Debug HostApp과 테스트를 함께 빌드한 후 XCTest 전체 265건 통과, 실패 0건. |
| 로컬 Release | 미서명 HostApp·Quick Look·Thumbnail·Spotlight가 모두 0.2.4 / 22 및 arm64·x86_64다. 패키징된 Studio 109개 파일, Legal 4개 파일 및 matcher receipt가 소스와 일치했다. |

재현에는 `scripts/probe-studio-font-integration.py`와 `scripts/probe-native-font-supply.py`의 [실제 문서 명령](../plans/task_m020_600_impl.md), 그리고 `scripts/probe-studio-font-integration.py --changes`를 사용한다. 복구 검사는 `scripts/smoke-studio-document-lifecycle.py --fixture samples/hwpx/ref/ref_text.hwpx --upstream-recovery`를 실행하고 무응답 조건에 `--stall-web-fonts`를 추가한다. 각 실행에는 별개의 출력 경로를 사용한다.

#601의 다음 패키징 입력은 위 제품 커밋이다. 이전 리허설 DMG 이후 글꼴 수정이 추가됐다. 이번 단계의 범위는 두 sample10의 첫 쪽, PDF·인쇄 공통 준비 경로 및 로컬 앱이다. 763쪽 전체 대조, 물리 프린터, Intel·최소 지원 OS 실기, 배포 서명본의 Finder·설치·업데이트 및 공증 DMG 검증은 미실행이다.
