# Spotlight 본문 추출 계약

## 기준과 선택

Task #339, core v0.8.6 (`f1f9c6ae58344ee9368996d3543f76b9345cf227`) 기준이다. RustBridge가 `parser::parse_document()`로 한 번 파싱하고 공통 모델을 직접 순회한다. 문서 handle이나 페이지 레이아웃을 생성하지 않는다. 이 어댑터는 macOS 검색용 표현 정책만 소유하며 upstream parser를 복제하지 않는다.

| 후보 | 확인한 특성 | 판단 |
|---|---|---|
| Unicode JSON / get_text_file_unicode | Unicode 유지, 표·글상자 scanner, DocumentCore 적재 시 layout, 빈 field guide 복구 | 전용 전체 검색 정책과 다르므로 미채택 |
| extract_page_text_native | display text·페이지 시각 순서, 페이지마다 render tree 구성 | 검색에 필요 없는 layout 비용과 반복 머리말 가능성 |
| parser::parse_document | 공통 IR, HWP3/HWP5/HWPX, layout 불필요 | 채택, 포함/제외 정책은 bridge가 명시 |
| doclang::extract_semantic | 위치 옵션 없이도 추가 SIR/수식 변환, HWP3·배포용 거부 | 검색 요구보다 넓은 변환과 형식 제약 |

## 지원과 본문 범위

평문 HWP3/HWP5/HWPX를 지원 대상으로 한다. extension만 신뢰하지 않고 bytes로 판별한다. HML과 다른 형식은 UNSUPPORTED다. 암호·DRM·배포용은 PROTECTED이며 본문을 반환하지 않는다. 암호 입력 UI, 저장된 비밀번호, 외부 이미지/URL/파일 로드는 사용하지 않는다. parser의 암호 오류와 파싱한 header의 배포용 flag를 이용하며 보호 확인만을 위한 두 번째 파싱을 하지 않는다.

| 모델 요소 | 검색 정책 |
|---|---|
| 일반 문단 | 저장된 text 포함, section/paragraph 순서 |
| 표/중첩 표 | cells의 모델 순서로 각 문단 순회, caption 포함 |
| 도형/글상자/그룹 | text box, caption, group children 순회 |
| 머리말·꼬리말·각주·미주 | 정의된 문단을 한 번 순회, 페이지마다 반복하지 않음 |
| 그림 | caption만 포함; 픽셀 OCR·외부 리소스·설명 속성 제외 |
| 수식 | 저장된 script 포함; 렌더/LaTeX 변환하지 않음 |
| 양식 | 저장된 text와 caption 포함; 실행하지 않음 |
| Ruby/글자 겹침 | main/ruby text와 저장된 문자 포함 |
| Field/Hyperlink | 문단의 표시 문자열만 포함, URL·명령·guide·memo payload를 따로 추가하지 않음 |
| 숨은 설명/메모/바탕쪽 | 전용 payload 제외 |
| 그림·차트·OLE 내부 데이터, 자동 번호/날짜/페이지 field | 새 문자열을 계산하거나 첨부 문서를 열지 않음 |

문단 text 뒤에 해당 문단의 컨트롤을 모델 순서로 깊이 우선 순회한다. 각 텍스트 조각과 문단/셀 사이에는 LF를 사용한다. 이는 검색어 보존을 위한 결정적 순서이며 화면의 읽기 순서를 재현하지 않는다. 스타일로 감춘 글, 흰색 글, 숨긴 머리말도 저장된 일반 text라면 포함될 수 있다. 따라서 가시성 필터 또는 기밀 제거 도구가 아니다. 명시적으로 제외한 종류는 정책상 제외이며 TRUNCATED가 아니다.

## 문자와 자원 한도

UTF-8 원문을 유지한다. CP949 변환·수치 참조·NFC/NFD 재정규화는 하지 않는다. NUL과 제어문자는 공백으로 바꾸고 CR/LF는 LF로 통일한다. 탭/연속 수평 공백은 공백 하나, 연속 줄바꿈은 LF 하나로 축약하며 양끝 whitespace를 제거한다. 알 수 없는 모델 문자는 원문 그대로 남긴다. delimiter를 넣어 서로 다른 셀의 단어가 붙지 않게 한다.

| 경계 | 한도와 결과 |
|---|---|
| 원본 파일 | 최대 32 MiB; importer는 읽기 전 fstat와 bounded read, ABI는 slice 생성 전에 검사; 초과 INPUT_TOO_LARGE |
| 출력 | 최대 1 MiB UTF-8 bytes; scalar 중간 절단 금지, 초과 TRUNCATED |
| 순회 | 최대 200,000개 방문 단위(section/paragraph/control/cell/shape), 최대 64개 중첩 frame; 초과 TRUNCATED |
| 시간/메모리 | parser 내부 및 압축 해제의 전체 CPU/RSS 상한을 보장하지 않음; core 자체 제한 적용 |

출력/순회 한도는 **파싱 후** 적용된다. 큰 압축 파일이나 병적인 파싱을 강제 중단하는 timeout으로 해석하면 안 된다. OOM/abort는 catch_unwind로 복구할 수 없다. 실제 CPU/RSS는 대표 corpus로 관찰하되 공개 릴리스 전 대형 악성 입력 격리 정책의 잔여 위험을 검토한다.

## C ABI와 수명

`rhwp_extract_text_utf8(data, len, out_data, out_len) -> RhwpTextStatus`를 추가한다. 상태 enum은 repr(C)이며 다음 숫자를 고정한다.

| 값 | 상태 | 출력 |
|---|---|---|
| 0 | RHWP_TEXT_OK | 비어 있지 않은 완전한 정책 범위 본문 |
| 1 | RHWP_TEXT_EMPTY | 정상 문서이나 검색 가능한 본문 없음; NULL/0 |
| 2 | RHWP_TEXT_TRUNCATED | 한도까지의 부분 본문; prefix가 없으면 NULL/0 |
| 3 | RHWP_TEXT_INVALID_INPUT | NULL/0 입력 또는 유효하지 않은 output 인자; NULL/0 |
| 4 | RHWP_TEXT_UNSUPPORTED | 지원하지 않는 형식; NULL/0 |
| 5 | RHWP_TEXT_PROTECTED | 암호/DRM/배포용; NULL/0 |
| 6 | RHWP_TEXT_INPUT_TOO_LARGE | 입력 한도 초과; NULL/0 |
| 7 | RHWP_TEXT_PARSE_ERROR | 지원 형식이지만 파싱 실패; NULL/0 |
| 8 | RHWP_TEXT_PANIC | Rust unwind 포착; NULL/0 |

유효한 각 output slot은 검사 시작 시 NULL/0으로 초기화한다. 호출자는 읽을 수 있는 data 영역과 서로 겹치지 않는 정렬된 writable output slots를 보장한다. 임의 dangling pointer를 ABI가 검증할 수는 없다. 입력은 호출 동안만 빌려 쓰며 보관하지 않는다. 반환 bytes는 NUL 종단이 아니고 out_len만큼 읽는다. 성공/부분 출력은 기존 `rhwp_free_bytes(ptr, len)`로 정확히 한 번 해제한다. 빈/실패의 NULL/0에는 해제가 필요 없다. 오류에 경로·본문을 넣지 않는다. panic 경계는 파싱과 순회 및 반환 준비를 감싼다.

importer는 OK/EMPTY/TRUNCATED를 metadata 성공으로 취급한다. 실패/보호 문서에서도 파일명 제목은 유지하고 kMDItemTextContent를 제거하는 metadata를 명시적으로 제출하여 이전 평문을 남기지 않도록 한다. 실제 오래된 단어 제거는 #342 시스템 색인 시험으로 확인한다.

## #340 수용 사례

합성 문서로 한글·영문·emoji, 문단/표/중첩/글상자/머리말/각주/수식/양식 포함과 메모·숨은 설명 제외를 확인한다. UTF-8 경계, 개행/제어문자, 빈 문서, 입력/출력/노드/깊이 한도, NULL 인자, 해제와 반복 호출, malformed HWP/HWPX, 암호/DRM/배포용 및 HWP3 fixture를 검증한다. 공개 샘플은 parse 성공 및 알려진 본문이 살아 있는지 확인한다. upstream pin과 기존 viewer API 동작은 유지한다.

## 실제 후보 측정

macOS 26.5.2 arm64, Xcode 26.6, Rust release/target aarch64-apple-darwin, deployment 12.0. 동일 프로세스 단일 실행의 관찰값(ms)이며 cold/warm 순서와 캐시 영향을 통제한 벤치마크가 아니다. 출력 길이 차이는 누락/반복/표현 차이가 함께 작용하므로 품질 점수로 해석하지 않는다.

| 샘플 | parse | Semantic | layout open | Unicode 추가 | page text 추가 | Unicode/page bytes |
|---|---:|---:|---:|---:|---:|---:|
| re-05-mixed-koen-hancom.hwp | 1.250 | 0.492 | 1.254 | 0.044 | 0.496 | 208/210 |
| inner-table-01.hwp | 1.257 | 2.054 | 5.512 | 0.093 | 4.036 | 2839/2760 |
| table-in-tbox.hwp | 3.491 | 4.855 | 5.913 | 0.183 | 5.204 | 5358/5052 |
| eq-01.hwp | 0.712 | 0.806 | 1.310 | 0.018 | 1.218 | 1484/1856 |
| field-01-memo.hwp | 0.864 | 0.862 | 1.118 | 0.024 | 1.822 | 221/290 |
| ref_text.hwpx | 0.742 | 0.297 | 0.295 | 0.002 | 0.031 | 16/16 |

6개 입력의 세 후보 모두 성공, page error 0. 중첩 표·글상자에서는 parse-only가 layout open보다 낮은 시간을 보였다. 작은 HWPX에서는 측정 순서 효과로 parse가 더 느렸다. 비용 보장의 근거는 layout 호출을 제거하는 구조이며 이 숫자의 비율을 일반화하지 않는다.

재현 명령:

```sh
MACOSX_DEPLOYMENT_TARGET=12.0 cargo run --manifest-path RustBridge/Cargo.toml --locked --offline --release --target aarch64-apple-darwin --example spotlight_extraction_probe -- samples/re-05-mixed-koen-hancom.hwp samples/inner-table-01.hwp samples/table-in-tbox.hwp samples/eq-01.hwp samples/field-01-memo.hwp samples/hwpx/ref/ref_text.hwpx
```

`--offline`은 Cargo 의존성 조회를 제한하며 Skia build script의 바이너리 다운로드까지 차단하는 옵션은 아니다. 필요한 dependency/artifact가 준비된 환경에서 실행한다. macOS 12 runtime은 사용 가능한 환경이 없어 미실행이다.
