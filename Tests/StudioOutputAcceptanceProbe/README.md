# Task #568 Stage 3 — 실제 Studio PDF·인쇄 수용

제품 Coordinator, 설치/관리 provider, save lock, 출력 job, 별도 WebView, atomic write 및 인쇄 seal/close를 사용한다. 문서 입력도 실제 편집 입력에서 추가한다. PDF 목적지만 private 시험 경로로 주고 인쇄 operation은 기본적으로 PDF를 기록한 뒤 `false`를 반환한다. 이 callback 결과는 실제 인쇄 패널이나 종이 출력의 증거가 아니다.

## 실행

허가된 고운바탕 Regular/Bold 원본과 OFL, 빌드된 `Rhwp.xcframework`, 로그인한 macOS가 필요하다. 기존 앱·산출물을 덮지 않도록 새 경로를 지정한다. OS 글꼴 설치, 기존 #567 체험 앱/사용자 문서 변경, Quick Look 등록, 배포를 수행하지 않는다.

```bash
python3 scripts/probe-studio-output-acceptance.py \
  --output-dir build.noindex/task568/stage3/acceptance-new \
  --font-dir build.noindex/task567/fonts/gowun-batang
```

- `managed`: 앱 bundle에 포함한 승인 글꼴 두 개를 private 보관함으로 가져온다.
- `installed`: 실제 Mac의 `NanumSquareR/B`를 사용한다. 설정은 이 시험 앱의 private 저장소에만 기록한다. 원본 글꼴을 수정·삭제하지 않는다.
- `baseline`: 설치 글꼴을 비활성하고 빈 보관함을 사용한다. Noto 본문/Bold·system ASCII 대조다.
- HWP/HWPX마다 현재 편집 본문, 두 PS/style, 실제 font program·한글 ToUnicode, PDFKit 추출·검색·영역 선택, page count/bounds, 원본 SHA/dirty/changeSeq 보존을 검사한다. 줄바꿈은 원문과 대조하여 처리하며 줄 내부 공백은 정확히 비교한다.
- 설치/관리 경로의 실제 bytes 반환 직후 취소는 기존 목적지를 보존해야 한다. 진행 중 물리 I/O 취소 자체를 이 observer로 검증했다고 취급하지 않는다. 관리 경로는 private 자산 제거로 stale 중단 후 복원·재출력을 검사한다. 사용자 OS 폰트 삭제는 수행하지 않는다.
- `--skip-build`: 같은 소스·서명 설정의 이미 빌드한 앱을 재사용한다. fingerprint가 다르면 거부한다.
- `--build-only`: 앱 준비만 한다. `--sandbox --sign-identity <기존 인증서>`는 별도로 승인된 로컬 서명 범위에서만 사용한다. private bundle ID/container이며 사용자 App Group을 공유하지 않는다.
- `--panel`: 실제 시스템 인쇄 패널을 열고 수동 취소 결과를 최대 180초 기다린다. 일반 자동 동작의 45초 대기와 구분한다. 인쇄/프린터 전송을 선택하지 않는다. `--source managed` 등 하나의 경로를 지정한다.
- `--interactive`: 수용 후 시험 창을 유지한다. 목적지는 private `current.pdf`, 인쇄는 `--panel`을 사용하지 않으면 callback이다. 사용자 앱을 설치한 결과로 취급하지 않는다.

## 증거와 경계

`result.json`은 실제 읽기 source/PS/style/hash/bytes와 검증 항목, `hwp.pdf`·`hwpx.pdf` 및 인쇄 PDF, `*-text.json`, `editor.png`를 남긴다. 서명 앱의 결과는 private container에서 지정한 build 경로로 복사한다. 저장 파일과 screenshot은 커밋하지 않고 필요한 작은 JSON/PNG만 단계 보고서의 assets에 선별한다.

PDF font program은 subset이므로 원본 font hash와 같다고 가정하지 않는다. `CGPDFFontResourceInspector`와 pypdf/Poppler를 함께 사용한다. 기본 시스템 영문 header의 PDFKit 반복 글자 누락은 #568 Stage 2에서 확인한 별도 제약이며 이 한글/ASCII 본문 수용으로 해결됐다고 주장하지 않는다.

페이지 SVG와 같은 portable metrics transaction의 layer-tree schema 1.23에서 일반 가로 본문 Bold만 검증한다. 외곽선/그림자/회전/첨자/장평·모호한 중복은 임의로 true Bold로 바꾸지 않는다. 한도·원본 상실·선택/임베딩 제한·WebContent 실패 등은 단위 주입 검증과 실제 수용 범위를 구분하여 보고한다. minimum OS/Intel/Windows/한컴 삭제/물리 인쇄/공증·배포 수용은 이 시험의 성공으로 대신하지 않는다.
