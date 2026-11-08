# Task M020 #600 3단계 글꼴 소비자 수정·검증 보고서

2026-11-09 · [구현계획](../plans/task_m020_600_impl.md) · [2단계 후보](task_m020_600_stage2.md)

## 같은 원본에서 처음 달라진 지점

[입력 해시](task_m020_600_stage1.md)가 같은 HWP3·HWPX 각 763쪽의 첫 쪽 ‘창원대학교 데이타베이스 연구실’을 비교했다. 사용자가 지정한 폴더에서 387개 글꼴 프로그램의 이름과 굵기를 검사했다. 딸기 가족에는 정적 CFF OTF 한 개가 있었다. `HGSTRBRY.otf`는 Strawberry-HGSTRBRY, face 0, Regular 400, 1,925,224바이트, SHA256 `6844aed54084783e28e7be0da351d08f4c0fe9e16e0844cbad4e4164c47488ca`다. Bold 파일이나 굵기 변화 축은 발견되지 않았다. 두 문서 모두 이 문장에 굵게를 지정한다. 한컴 참조 PDF의 Type 3 이름만으로 한컴이 사용한 원본 프로그램을 식별할 수는 없다.

공식 태그 `v0.9.0`의 `c9095c5f67632e6721e800ccc7fb43ea49d26682`에서 native-skia CLI를 빌드했다. 동일 파일을 단독으로 공급하거나 제외하고 두 형식 각각 첫 쪽 PNG, 기본 SVG 경유 PDF, direct PDF를 내보냈다. 공급한 두 PNG의 선택 기록은 모두 `딸기 → Strawberry`, CFF, programId `26b2cba13463ea796f7bd409703362ef4d4ccbd5edd689006f8280595e73ed31`였다. 이 값은 원본 bytes 뒤에 face 0을 4바이트 big-endian으로 붙인 SHA256과 일치한다. 미공급 대조에는 해당 선택이 없었다.

| 소비자 | 2단계 알한글에서 처음 달라진 지점 | 3단계 제품 변경 |
|---|---|---|
| HWPX 화면과 native | host provider 연결 시 조판 전 선언 글꼴 준비를 건너뛰었다. 첫 쪽 한글 슬롯이 이미 돋움으로 바뀌어 나중에 딸기를 조회할 기회가 없었다. | Studio·native에서 원본 문서의 후보와 공급 가능한 실제 프로그램을 먼저 대조한다. 확인된 HFT 가족을 같은 문서 핸들의 공식 font environment에 전달한 뒤 트리를 읽는다. |
| HWP3 PDF·인쇄 준비 | 화면은 딸기를 사용했다. 출력 resolver가 문서의 굵기 700을 실제 face 굵기로 요구해 400만 있을 때 중단했다. | 실제 Bold를 먼저 찾는다. 같은 HFT 가족의 유일한 정상 Regular CFF만 있으면 공식 출력처럼 원래 face와 문서 굵게 효과를 함께 사용한다. 이미 획 효과가 있거나 지원하지 않는 글자 배치는 기존 출력 오류로 처리한다. |
| HWP3·HWPX native | 700 요청과 실제 face를 구분한 후에는 딸기에 U+0020 글리프가 없어 표지 줄 전체의 coverage 검사가 실패했다. | CoreGraphics는 실제 글자 윤곽의 coverage를 검사하고 굵게를 그린다. Skia는 조판된 위치를 쓰고 해당 공백이 차지하는 원문 범위와 다음 글자의 위치를 보존한다. 다른 누락 글리프는 계속 실패로 처리한다. |

공식 PDF의 글꼴 목록에는 실제 Strawberry-HGSTRBRY가 임베드됐다. PDF 콘텐츠에서 24단위 크기 글자에 폭 0.48의 획, 채움과 획 모드(`2 Tr`), 글자당 한 번의 텍스트 그리기를 확인했다. 이는 공식 `src/renderer/pdf_synthetic_bold.rs`의 0.02em 규칙이다. 공식 Studio Canvas는 600 이상 요청에 실제 굵은 face가 없으면 Regular를 조회한다. native Skia의 일반 텍스트와 portable glyph replay에는 각각 별도의 굵게 그리기 경로가 있다. direct PDF 첫 쪽에서는 임베드 텍스트 글꼴을 식별할 수 없어 임베딩 증거는 기본 PDF에서 얻었다.

알한글의 WebKit에서 굵게를 자동 합성하거나 SVG text에 직접 획을 적용하면 눈에 보이는 글리프 하나가 PDF 텍스트로 두 번 추출됐다. 그래서 지원 범위의 개별 수평 글자는 원래 face로 한 번 채우고, 같은 OTF에서 읽은 윤곽으로 0.02em 획만 더한다. PDF에서 글자 검색·복사와 굵기 양쪽을 검사했다. 이 처리는 한글 완성형·출력 가능 ASCII의 검증된 개별 좌표에 적용된다. 수직·복합 조판이나 실제 딸기 Bold 파일에 대한 검증은 이번 표지 결과의 범위 밖이다.

## 재현과 결과

- 두 원본 각각 실제 제품 WKWebView에서 미공급 → 격리 라이브러리 가져오기 → 새 프로세스 재열기를 실행했다. 실제 PS·원본 SHA·face 0을 읽었고, 두 형식 모두 재열기 PNG가 가져오기 PNG와 바이트 단위로 같았다. 그 문서를 연 상태에서 관리 글꼴을 제거하자 미공급 화면 PNG와 출력 SVG가 복원됐다.
- 두 원본의 PDF·인쇄 공통 첫 쪽에 같은 PS 프로그램이 임베드됐다. PDFKit과 Poppler 모두 표지 문장을 올바른 순서로 한 번 추출했다. PDF의 subset은 원본 파일 전체와 바이트 단위로 같을 필요가 없어 원본 읽기 SHA, 임베드 PS, 텍스트, 윤곽을 함께 검사했다.
- 두 원본의 CoreGraphics와 Skia 결과 네 건 모두 실제 요청한 backend에서 딸기 OTF를 1회, 1,925,224바이트 읽고 렌더했다. 미공급 대조의 딸기 읽기는 0회였다.
- 같은 A4를 1190×1682픽셀로 맞추고 (410,1336)–(1040,1458) 범위에서 명도 120 미만인 픽셀의 교집합/합집합을 계산했다. 한컴의 대상 잉크 경계는 (425,1390)–(981,1414)다. 아래 값은 해당 한 줄에 한정한다.

| 실제 출력 | HWP3와 한컴 | HWPX와 한컴 |
|---|---:|---:|
| 공식 rhwp PNG | 0.7748 | 0.2408 |
| 공식 rhwp 기본 PDF | 0.4392 | 0.1773 |
| 알한글 Studio 화면 | 0.8622 | 0.2411 |
| 알한글 PDF | 0.7269 | 0.2242 |
| 알한글 CoreGraphics | 0.7730 | 0.2313 |
| 알한글 Skia | 0.6718 | 0.2162 |

HWP3 알한글 PDF의 잉크 경계는 한컴과 일치했다. HWPX에서는 공식 PNG와 알한글 PDF·native 모두 (434,1390)–(990,1414)로 약 4.5pt 오른쪽이었다. 공식 SVG가 기록한 첫 글자의 x도 두 입력 사이에서 282.16→287.84로 달랐다. 앱에서 위치를 보정하지 않고 형식별 공식 조판을 유지했다. backend별 획의 래스터화 차이가 남는다. 외부 그림 세 개와 전체 763쪽의 시각 일치는 확인 범위 밖이다.

## 회귀 및 후보 식별

| 검증 | 결과 |
|---|---|
| 공식 matcher·host·공급 | Node 35건, Python 5건, RustBridge 29건, PDF 출력·인쇄 관련 XCTest 61건 모두 통과. fixture 공급 67 PASS, 0 FAIL, 문서 소비와 별도인 30건 NOT_RUN. 실제 설치된 Pretendard 23건과 Hack 13건 공급 통과 |
| 기존 문서 편집 | 고운바탕 Regular·Bold로 Studio 31+5+4건, 설정 캡처 6회, HWP·HWPX 저장본 재열기 6개 위치 일치 |
| native 및 확장 | 고운바탕과 설치 글꼴 대조, 취소·캐시·모호한 선택·파일 제한, 확장 공통 PNG·PDF·Thumbnail 회귀 통과 |
| 빌드 | 공식 Studio 변환 소스 typecheck·빌드·strict asset 대조, 검증기 fixture, matcher receipt, portable ABI, build-info, golden 재생성 대조, 기본 3문서 PNG, HostApp 및 두 확장 Debug 빌드 통과 |
| 최종 SHA256 | Studio manifest `ff3cd3090446c2bb78439bb388c15acce6884f1e4ef558b774cb5cd806203b6a`, native matcher receipt `dde9fe0057630144e5e3831fbb76f02e2d9c2e61f4a99227b5a9388981f7bdf0` |
| native 산출물 | arm64·x86_64 archive `d2e31bc11f49d0a40f20c6bf8b8cd7f37ebdfe03bc64577e03aa33bf2225353b`, 생성 헤더 `45c5145b8e26801e699ed5668a69c9a6cc44d0989a3d62477fb8147211f908e6`. 앱에 링크된 두 추가 심볼을 확인 |

재현 명령은 [3단계 수정계획](../plans/task_m020_600_impl.md)의 두 probe를 사용한다. 비교용 공식 CLI의 첫 쪽은 `export-png`, `export-pdf`에 `--page 0 --font-path`로 같은 OTF 디렉터리를 전달해 얻는다. 비공개 증거에는 공식 CLI 출력·로그, 제품 PDF·폰트 읽기 기록, 같은 좌표의 이미지와 측정값이 있다. 저장소에는 원본 OTF·PDF를 포함하지 않는다.

배포 서명을 사용한 Finder 실기, 물리 프린터, 실제 OS 글꼴 설치·삭제, Intel 및 최소 지원 OS 실기는 미실행이다. #594가 받은 2단계 후보는 자체 산출물로 보존했으며 4단계는 #601 통합 커밋에 이번 수정을 반영한 뒤 별도 승인으로 검증한다.
