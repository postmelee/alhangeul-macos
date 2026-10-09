# Task M020 #568 — macOS PDF CI의 조립 객체와 저장 파일 검사 보정

## 증상과 재현

[PR #579](https://github.com/postmelee/alhangeul-macos/pull/579)의 macOS 15.7.9 CI에서 PDF·인쇄 관련 81개 검사 중 4건이 실패했다. `PDFPage.string`과 `PDFDocument.findString`에서 `㈀`·`㉠`·`²`가 다르게 표현됐고 외부 연결 차단 fixture의 표시 문구도 검출되지 않았다. 로컬 macOS 26.5.2에서는 같은 문자의 검사들이 통과했다.

- 초기 실패: [run 37964819628 / macOS job](https://github.com/postmelee/alhangeul-macos/actions/runs/37964819628/job/113936836296), 4개 test case / 11개 assertion 실패.
- 진단 head: `05b8b97ef23c7f8a70f0c278de7ce0f617409846`.
- 실제 PDF 수집: [run 37969798803 / macOS job](https://github.com/postmelee/alhangeul-macos/actions/runs/37969798803/job/113953285941), artifact `studio-pdf-output-diagnostics` / ID `11638030730`. 외부 연결 차단 검사는 통과했고 문자 검사 3개 / assertion 10개만 남았다.
- [reader 대조 JSON](../working/assets/task_m020_568_ci/reader-comparison.json)에 PDF SHA256·환경·현재/재열기 추출과 검색·독립 reader·원문 ToUnicode 매핑을 보존했다. 사용자 문서나 원본 글꼴 파일을 수집하지 않았다.

## 실제 파일 대조와 판정

| 검사 대상 | macOS 15의 조립 직후 객체 | 같은 macOS 15에서 저장 bytes 재열기 | macOS 26·Poppler로 같은 파일 읽기 |
|-----------|-------------------------|-------------------------------------|----------------------------------|
| `㈀`·`㉠`·`²`의 `string` | `(ᄀ)`·`ᄀ`·`2`로 표현, 일부 줄 합침 | 원문과 줄 복원 | 원문 보존 |
| 원문 query 검색 | 호환 문자 포함 query 0건 | 원래 query 각각 1건 | 원래 query 검출 |
| 영역 선택 문자열 | 원문 보존 | 원문 보존 | 원문 보존 |
| `attributedString` | nil | 원문 보존 | 로컬 PDFKit 원문 보존 |

실제 PDF의 ToUnicode에는 `U+3200`·`U+3260`·`U+00B2`가 들어 있고 PNG에서도 원래 원문자·위첨자가 표시된다. PDF 생성 bytes의 문자 손실이나 글꼴 공급 실패로 판정하지 않는다. macOS 15에서 page를 insert한 조립 객체와 직렬화·재열기한 문서의 텍스트 API 결과가 다른 현상을 확인했으며, PDFKit 내부 원인까지 확정한 것은 아니다.

제품 PDF 저장은 `RhwpStudioPDFExportController`가 `dataRepresentation()` bytes를 atomic write한다. 검사가 저장 전 조립 객체의 문자열 상태를 저장 파일의 원문 보존 기준으로 취급한 것이 이번 실패의 원인이었다. 인쇄는 별도의 `PDFDocument.printOperation` 경로이며 이번 조사로 macOS 15의 실제 인쇄 패널·물리 출력을 수용했다고 선언하지 않는다.

## 보정과 재발 방지

- 문자 검사 3건은 실제 저장과 같은 `dataRepresentation()` 결과를 `PDFDocument(data:)`로 다시 열어 검사한다. 원래 `㈀`·`㉠`·`²`, 공백/문장·ToUnicode·검색 건수 조건은 그대로 유지한다. 원문을 정규화하거나 assertion을 제거하지 않는다.
- 조립 직후 객체의 영역 선택 원문도 별도로 검사해 기존 복사 검증을 유지한다.
- 외부 paint URL이 차단돼도 표지가 보이도록 CSS에 `black` fallback을 명시한다. 문구가 페이지 폭에 잘리지 않도록 fixture를 200→260으로 넓힌다. loopback 양성 대조·외부 접속 0건 조건은 유지한다.
- 진단은 고정 합성 fixture 4개만 opt-in으로 저장하고 CI 실패에도 artifact를 보존한다. 현재 객체와 재열기 결과를 구분한다.

## 검증

로컬 macOS 26.5.2에서 HostApp을 같은 DerivedData에 먼저 빌드한 뒤 `bash scripts/test-studio-output.sh build.noindex/task568/stage5/host-tests`의 81개 검사가 실패 0으로 통과했다. 실제 CI 파일 4개를 Poppler와 로컬 PDFKit으로 대조하고, macOS 15 진단의 저장 후 검색·선택이 원문 그대로 통과하는 것을 확인했다. 보정 head의 전체 원격 CI는 별도로 확인한다. 제품 renderer·core pin·새 API/ABI·signed 설치 시험은 변경하지 않았다.
