# Task M020 #568 Stage 1/2 — 출력 글꼴 격리 검증

현재 제품 PDF renderer·HTML·글꼴 공급자를 컴파일해 검사한다. Stage 1의 원본 matcher 실험과 Stage 2의 제품 output job 검사를 구분한다. 공식 v0.8.7 matcher는 Node 24의 TypeScript type stripping으로 실행하며, Stage 2 adapter 검사는 별도 복사본만 변환한다. 원본 checkout·core pin은 수정하지 않는다.

## 전제와 실행

- macOS GUI 세션, Xcode Swift compiler, Node 24, Poppler(`pdfinfo`, `pdffonts`, `pdftotext`, `pdftoppm`) 필요.
- 이미 승인해 확보한 고운바탕 Regular/Bold와 OFL·provenance 디렉터리 필요. 다운로드·OS 글꼴 설치·사용자 폴더 권한 요청은 수행하지 않는다.
- 새 `build.noindex/task568/` 하위 출력 디렉터리만 허용하며 기존 출력은 덮지 않는다. `.app`은 고유 ID의 ad-hoc 서명이다. Developer ID·키체인·App Group·sandbox 수용을 시험하는 앱은 아니다.
- Stage 1의 `ProbeResources`는 자체 fixture만 읽는 동기 시험 handler다. Stage 2는 제품 job·scheme·준비·공유 slot을 사용하지만 snapshot/current/lease와 editor resolver는 fixture로 주입한다. 실제 관리 App Group lease와 문서 lock 수용은 Stage 3 범위다.

```bash
python3 scripts/probe-studio-output-fonts.py \
  --upstream-dir build.noindex/task567/stage3-2/upstream-v087 \
  --font-dir build.noindex/task567/fonts/gowun-batang \
  --output-dir build.noindex/task568/stage1/new-run \
  --node /Users/melee/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node
```

Codex의 shell sandbox 안에서는 AppKit의 LaunchServices 연결이 중단될 수 있다. 승인된 격리 실험 범위로 GUI 실행 권한을 사용한다. 프로세스 timeout은 해당 자식 앱만 종료하며, 종료 때 해당 `.app` 경로만 LaunchServices 등록 해제한다. Quick Look/Thumbnail 등록, 전역 reset, 실제 인쇄는 하지 않는다.

## 대조군과 성공의 의미

| 모드 | 변경 | 확인 사항 |
|------|------|-----------|
| `baseline` | 제품 Noto handler·준비 그대로 | 현재 출력의 PS·텍스트 fidelity를 측정 |
| `naive` | TTF 공급·FontFace 추가, 기존 Noto 준비 유지 | 한글 face는 계속 Noto인 점과 ASCII 부분의 실제 공급을 분리 |
| `custom` | 자체 fixture의 지정 node만 Noto 보정에서 제외 | 고운바탕 Regular/Bold·임베딩·ToUnicode·본문 추출/검색·geometry |
| `missing` | Bold 읽기 거부 | 준비 실패, PDF 파일 미생성 |
| `wrong-token` | 다른 작업 토큰으로 Bold 요청 | route 거부, PDF 파일 미생성 |

제품 `webViewFactory`의 configuration에는 이미 handler가 등록되어 있어 WebKit이 교체를 거부한다. custom 대조군은 시험 configuration에 같은 nonpersistent store·content JS 차단·window 차단 값을 적용해 시험 handler를 등록한다. 나머지 렌더 수명·HTML·CSP·PDF 생성은 제품 구현을 사용한다.

`data-face`/`data-probe-owned`는 자체 합성 SVG의 시험 표시다. 제품에서 문서가 제공한 이 표시를 신뢰해서 Noto 검사를 생략하면 안 된다. 실제 연결은 검증된 선택과 앱 소유 node mapping을 사용한다.

Stage 1 당시 `receipt.json`의 `passed`는 실험 절차·custom 본문·실패 대조군 통과였다. Noto의 공백→`#`와 PDFKit header의 `fallback`→`falback`은 [Stage 1 보고](../../mydocs/working/task_m020_568_stage1.md)에 별도로 남았다. 현재 renderer로 재실행한 결과를 당시 source/hash의 결과와 혼용하지 않는다.

## Stage 2 제품 경로

```bash
python3 scripts/probe-studio-output-fonts.py --stage2 \
  --upstream-dir build.noindex/task567/stage3-2/upstream-v087 \
  --font-dir build.noindex/task567/fonts/gowun-batang \
  --output-dir build.noindex/task568/stage2/new-run \
  --node /Users/melee/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node
```

`baseline`은 현재 Noto 준비를, `job`은 제품 `RhwpStudioOutputFontJob`·scheme handler·준비를 사용한다. 별도 변환 module의 공식 matcher 결과를 fixture callback으로 전달한다. 원본의 name table에 없는 한국어 alias 대신 실제 fullName을 사용한다. source/hash·두 읽기·16,612,008 bytes·단일 release·close 후 bytes 0, PS/program/ToUnicode·본문 검색·영역 선택·Poppler 추출을 검사한다. 일부 기본 시스템 영문에 남은 PDFKit 반복 글자 추출 제약을 전체 페이지 exact 성공으로 합산하지 않는다. 실제 editor API/저장·인쇄 진입·sandbox는 이 probe의 완료 판정에 포함하지 않는다.

## 독립 font program 검사

`pypdf`가 제공되는 Python으로 별도 실행한다. 이 의존성은 제품 runtime에 추가하지 않는다.

```bash
/Users/melee/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Tests/StudioOutputFontProbe/inspect_pdf.py \
  build.noindex/task568/stage1/new-run/custom/sample.pdf \
  build.noindex/task568/stage1/new-run/custom/programs.json
```

`pdffonts`와 함께 실제 `/FontFile2`와 `/ToUnicode` stream을 확인한다. ASCII MacRoman subset에 ToUnicode가 없어도 실제 문자열 추출로 판정한다. SFNT 입력 hash와 PDF subset program hash가 같아야 한다고 검사하지 않는다. 이 PDF의 pypdf 6.10.0 읽기에서는 offset 0의 일부 object 경고가 발생했으며, Poppler와 PDFKit의 읽기 결과를 함께 남겼다.

보고서: [Stage 1](../../mydocs/working/task_m020_568_stage1.md), [출력 계약](../../mydocs/tech/task_m020_568_output_contract.md).
