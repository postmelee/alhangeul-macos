# Task M020 #563 Stage 3 완료보고서

- 일자: 2026-09-17
- 단계: 최소 글꼴 적용·새 프로세스·원본 부재 실험
- 승인 근거: Stage 2 완료 보고 후 작업지시자의 “진행해줘”
- 마일스톤: M020 / 글꼴 마이그레이션 / v0.2 계열
- 브랜치: `local/task563`
- 상태: 독립 실험 및 제약 조사 완료, Stage 4 승인 대기

## 1. 결과

**관리 복사본만으로 TTF·OTF와 가변 TTF 일부를 새 프로세스의 화면·PDF에 공급할 수 있음을 확인했다.** 제품 알한글의 기능 구현 완료를 의미하지 않는다.

| 실험 | 결과 |
|------|------|
| A: 관리 복사본 공급 | TTF·OTF regular/bold 및 가변 wght 400/700의 요청 hash·PS, 화면과 PDF 확인 |
| B: 실험 원본 제거 후 재실행 | A와 행별 글리프/폭·화면 snapshot·PDF raster 정확히 일치 |
| C: 관리 경로도 없는 새 프로세스 | 8개 글꼴 로드 거부, 리소스 공급 0개, 실험 PS가 PDF에 없음. A/B와 다른 fallback 확인 |
| D: 관리 bytes 변조 | hashMismatch로 종료 코드 1, PDF 생성 전 거부 |
| TTC 2 faces | CoreText 목록 조회 가능. raw bytes + CSS weight만으로 bold face를 선택하지 못함 |
| 가변 TTF | 1 sfnt face/9 named instances 구분, wght 400/700 실제 글리프·PDF PS·재실행 확인 |
| 중복·충돌·손상 | 동일 hash, 동일 PS/다른 hash를 구별하는 fixture 및 잘린 폰트 parser 거부 확인 |

TTC의 bold 선택 실패는 의도적으로 관측·기록한 지원 제약이다. 독립 공급의 핵심 판정은 통과했고, TTC까지 지원 성공으로 표시하지 않았다. 한글 별칭 resolver와 정식 충돌 UI는 아직 구현하지 않았다.

## 2. 산출물 및 실행 환경

- [probe-font-migration.sh](../../scripts/probe-font-migration.sh): `--help`, 명시적 입력/출력 인자, Python runner 진입점.
- [font_migration_probe.py](../../scripts/font_migration_probe.py): OFL fixture의 내부 이름 분리, TTC 구성, 가변 입력, 프로세스 A/B/C/D 실행, PDF·화면 판정, 원본 hash 보존 기록. 준비와 판정 코드를 Swift에서 분리한 보조 파일이다.
- [font_migration_probe.swift](../../scripts/font_migration_probe.swift): NSApplication/WKWebView 독립 실행 파일, 비영속 WebView, 좁은 custom scheme, 관리 hash/descriptor 확인, DOM·Canvas 계측, snapshot·PDF 출력. 제품 source·entitlement는 변경하지 않는다.
- [설계서 16절](../tech/font_migration_design.md#16-stage-3-실측--독립-화면pdf-공급): 관측과 후속 계약 보정.

macOS 26.5.2 (25F84), arm64, Python 3.14.4, fontTools 4.59.1. Swift compile target은 macOS 12.0이며 `-warnings-as-errors`로 통과했다. macOS 12에서 실행한 결과는 아니다. 화면/WebContent 실행은 host 권한으로 수행했으며 실제 앱 sandbox 검증과 구분한다.

공개 글꼴의 파생 이름은 실행별 `Task563<무작위 ID>TTF/OTF/VAR`다. name/CFF/fvar instance 이름을 변경하고 원본 고지를 보존했다. 글꼴 파일은 Git에 넣지 않았다. [Spoqa OFL](https://github.com/spoqa/spoqa-han-sans/blob/master/LICENSE), [Pretendard OFL](https://github.com/orioncactus/pretendard/blob/main/LICENSE), [가변 TTF v1.3.9](https://github.com/orioncactus/pretendard/blob/v1.3.9/packages/pretendard/dist/public/variable/PretendardVariable.ttf), [같은 태그 OFL](https://github.com/orioncactus/pretendard/blob/v1.3.9/LICENSE)을 사용했다.

가변 원본의 resolved commit은 `5c41199ea0024a9e0b2cb31735265056e5472d76`, SHA-256은 `3090ccde0442bb347aa7685d9ba8b17436a60682df6e8f92a9a670de14056e22`다. 다른 static 입력 hash는 Stage 1 기록과 이번 `provenance.json`에 있으며 실행 전후 동일하다.

## 3. 재현 명령

로그인된 macOS, Xcode Swift 및 `pdffonts`·`pdftotext`·`pdftoppm`이 필요하다. fontTools는 제품 dependency가 아닌 작업 전용 Python 환경에 준비한다. 입력은 해당 이름의 OFL 글꼴과 각 공급자의 고지 파일이다. 스크립트는 다운로드하지 않고 읽기 전용 입력을 받아 `build.noindex/` 아래 실행별 폴더를 새로 만든다.

```sh
python3 -m venv build.noindex/task563-tools
build.noindex/task563-tools/bin/pip install fonttools==4.59.1

FONT_PROBE_PYTHON=build.noindex/task563-tools/bin/python \
  scripts/probe-font-migration.sh \
  --ttf-regular "$HOME/Library/Fonts/SpoqaHanSansNeo-Regular.ttf" \
  --ttf-bold "$HOME/Library/Fonts/SpoqaHanSansNeo-Bold.ttf" \
  --otf-regular "$HOME/Library/Fonts/Pretendard-Regular.otf" \
  --otf-bold "$HOME/Library/Fonts/Pretendard-Bold.otf" \
  --ttf-license build.noindex/task563-assets/Spoqa-OFL.txt \
  --otf-license build.noindex/task563-assets/Pretendard-OFL.txt \
  --variable build.noindex/task563-assets/PretendardVariable-v1.3.9.ttf \
  --variable-license build.noindex/task563-assets/Pretendard-v1.3.9-OFL.txt
```

가변 입력 두 인자는 선택이며 생략하면 static/TTC 실험만 수행하고 가변은 UNTESTED로 표시한다. `--output`은 이 저장소 `build.noindex/` 아래 부모 폴더만 허용한다. 입력 위치가 다른 환경에서는 실제 경로를 지정한다.

## 4. 증거와 판정

최종 통과 증거: `build.noindex/task563-font-migration/run-68pxsn4y/`. Git에는 실험 코드·보고서만 포함하고 생성 bytes/PNG/PDF는 로컬 증거로 보존했다.

- `summary.json`: static PASS, variableWght400700 PASS, 재실행 화면/PDF 일치, 대조군 구별, 변조 거부, TTC bold 불일치.
- `manifest.json`, `metadata.json`, `provenance.json`: ID/file/face/선택 weight/원본·파생 hash와 이름·축 기록.
- `A-managed`, `B-source-absent`, `C-no-managed`의 `result.json`: PID, 시스템 PS 충돌 목록(모두 비어 있음), 실제 공급 ID/hash, descriptor, load 결과, DOM·Canvas 폭, 행별 raster hash.
- 같은 폴더의 `screen.png`, `row-*.png`, `sample.pdf`, `pdf.png`, `pdffonts.txt`, `text.txt`: 실제 화면/PDF와 독립 도구의 확인 결과.
- `D-tampered/run.log`: native hashMismatch 거부.
- `original-preservation.json`: 입력 글꼴·라이선스 8개 파일의 전후 SHA-256 일치.

최종 A/B/C native PID는 `73754 / 73762 / 73771`이다. 매번 새 NSApplication과 비영속 WebView를 사용했다. 파생 이름을 시스템에 등록하지 않았고 C는 managed 경로를 읽을 수 없도록 비운 상태에서 리소스를 모두 실패시킨다. 보존용 `held-managed`는 C의 allowlist에 넣지 않는다.

| 행 | A/B Canvas 폭(px) | C 폭(px) |
|----|------------------|----------|
| static TTF regular | 455.487976 | 507.237457 |
| static TTF bold | 458.527985 | 507.237457 |
| static OTF regular | 439.968750 | 507.237457 |
| static OTF bold | 442.281250 | 507.237457 |
| raw TTC regular | 455.487976 | 507.237457 |
| raw TTC bold 요청 | 455.487976 (regular와 동일) | 507.237457 |
| variable wght 400 | 439.968750 | 507.237457 |
| variable wght 700 | 442.390625 | 507.237457 |

A/B 화면 PNG SHA-256은 `ef998812ed317d860ca0205505999a85c57d05262fd7cf1f7a6afc04180ef19c`, PDF raster는 `a3821fff6f99d666b6dbc655068cc4359c3e4046580e3ed516d2fd5b3a1d7a7e`로 각각 같다. C는 두 hash 모두 다르다. 화면/PDF 이미지를 직접 확인해 한글·굵기 표시와 clipping 부재를 확인했다. PDF는 표본 `한글 글꼴 독립 복사 확인 ABC 123` 8행을 정확히 추출했고 static 및 variable의 실제 PS와 임베딩을 확인했다.

## 5. 실패에서 보정한 내용

1. 최초 Swift callback에 async API의 argument label을 사용해 컴파일 오류가 났다. 현재 제품 renderer와 같은 callback label `in: .page`로 수정했다. 최종 빌드는 경고 0개다.
2. 제한된 도구 환경의 WebView 실행은 65초 timeout으로 끝났다. 로그인된 host 권한으로 동일 독립 실험을 실행해 회복했다. runner는 timeout 출력도 로그에 남기도록 보완했다.
3. 최초 PDF 검사는 모든 subset에 ToUnicode를 요구해 실패했다. 실제 PDF에는 TTF의 MacRoman subset(매핑 없음)과 비 MacRoman subset(매핑 있음)이 함께 있었으며 전체 한글/영문 추출은 정확했다. 임베딩 전부 확인·face별 ToUnicode 존재·비 MacRoman 매핑·전체 표본 추출을 함께 검사하도록 보정한 뒤 A/B/C/D를 다시 실행했다. 한글 추출 실패를 무시하도록 바꾼 것이 아니다.
4. TTC는 load가 fulfilled여도 bold 글리프가 regular였다. 단순 CSS weight 지정은 face index 선택 계약을 대신하지 못한다. 개별 SFNT는 정상인 점을 비교 근거로 삼아 face-aware 공급/분리 방안을 후속 검증 조건으로 남겼다. 이번 단계에서 TTC 분리기를 제품에 추가하지 않았다.
5. 가변 자산은 공식 tag tree에서 실제 경로를 확인해 확보한 뒤 최종 실행에 포함했다. static만 통과한 `run-f1oq5t3x`와 구분해 최종 증거는 `run-68pxsn4y`로 고정한다.

## 6. 검증 및 잔여 조건

- 전체 실험 종료 코드 0; 의도한 변조 실행만 종료 코드 1. `--help`, 필수 인자 누락, build.noindex 밖 출력 및 존재하지 않는 입력 거부도 확인했다.
- shell 구문, Python 구문, Swift 경고 없는 compile, `git diff --check`, 문서 참조 표기·로컬 링크를 검증했다.
- 기존 `CGPDFFontResourceInspector.swift`, `RhwpStudioPagePDFRendererTests.swift`, 제품 font provider를 참고했다. 변경 없는 제품 전체 테스트를 새 기능의 검증으로 주장하지 않는다.
- `.app`/`.appex`를 만들거나 Quick Look/시스템 글꼴을 등록하지 않았다. 한컴 앱·사용자 글꼴·제품 소스·project.yml·entitlement·core pin을 수정하지 않았다.
- signed sandbox/App Group, 실제 Studio CSS/CanvasKit·전용 PDF/Noto 정책·CoreGraphics/Skia/확장, 한글 별칭·동명 버전 선택, Windows ZIP, 실제 HFT, 다른 variable 축·글꼴, 최소 OS, 실인쇄 및 실제 한컴 제거 수용은 미검증이다.

Stage 4에서 이번 결과를 지원 표와 후속 #564 ~ #569 이슈의 수용 조건으로 정리하고 인계하도록 승인을 요청한다. GitHub 반영과 최종 보고는 해당 단계의 승인된 인계 내용에 따라 진행한다.
