# Task M020 #568 — 글꼴 소비자 수용·지원 범위 인계

- 기준일: 2026-10-10. `local/task568`, Stage 5 제품 기준 `817d1931`.
- core/Studio: `v0.8.7` / `1a76570e833917d15817415a53c09ad61ab3203f`.
- 용도: #566 입력 작업과 #569 통합 수용·사용 안내에 전달하는 내부 기준. 공개 출시·웹 게시 완료 문서가 아니다.
- 근거: [#567 Stage 4](../working/task_m020_567_stage4.md)·[Stage 5](../working/task_m020_567_stage5.md), [#568 Stage 3](../working/task_m020_568_stage3.md)·[Stage 4](../working/task_m020_568_stage4.md)·[Stage 5](../working/task_m020_568_stage5.md), [최종 대조](../working/task_m020_568_stage6.md).

## 1. 소비자별 Mac·Windows 수용표

‘확인’은 아래 특정 원본·환경·형식에서의 실제 수용이다. 목록에 보이는 모든 글꼴, 모든 한컴 제품과 문서에 대한 보증으로 확대하지 않는다. 공통 실제 실행 환경은 arm64/macOS 26.5.2(25F84)이며 macOS 12는 target compile만 확인했다.

| 소비자 | Mac 활성 설치 참조 | 별도 관리 복사본 | 실제 확인과 지원 경계 | Windows 입력 |
|--------|--------------------|------------------|-----------------------|---------------|
| Studio·기존 글꼴 목록 | 실제 NanumSquare R/B, signed sandbox·새 프로세스·HWP/HWPX 저장/재열기 확인 | 고운바탕 R/B의 격리 WK 공급·변경/복구·원본 없는 새 프로세스 확인 | Canvas2D/CanvasKit. metadata·메뉴 수는 실제 적용 성공 수와 다름. 관리 경로의 WK 시험과 설치 경로의 signed 수용을 구분 | #566 이후 별도 수용 |
| 사용자 PDF 저장 | 실제 NanumSquare R/B, signed sandbox HWP/HWPX 확인 | 고운바탕 R/B, signed sandbox HWP/HWPX 확인 | PS/style/program·한글 ToUnicode·본문/공백·PDFKit 검색/선택, 독립 Poppler/pypdf 대조. 일반 가로 Bold, static SFNT 중심 | #566 이후 별도 수용 |
| 인쇄 | 설치 경로의 seal된 인쇄 PDF·callback 반환 확인 | 관리 경로의 seal된 PDF와 실제 macOS 패널 열기·사용자 취소 확인 | 설치/기준선 패널은 별도 조작하지 않음. false는 취소/실패를 자동 구분하지 못함. 물리 프린터 spool/종이 출력 미검증 | #566 이후 별도 수용 |
| native CoreGraphics | 실제 OS ArialUnicodeMS, 별도 프로세스 등록 고운바탕 fixture 확인 | 실제 private store 고운바탕 R/B·HWP/HWPX 확인 | exact PS/style/hash bytes context. 기존 producer 위치를 유지하는 PositionAdjusted replay, 전체 재조판/complex shaping 아님 | #566 이후 별도 수용 |
| native Skia | 위 원본의 공통 native CLI 수용 확인 | 관리 R/B·동일 PS의 glyph 변경/복원 확인 | unsigned 공통 renderer의 decode/direct·Skia 출력. signed Release 확장은 CoreGraphics 기본 정책 | #566 이후 별도 수용 |
| Quick Look | 실제 signed 확장의 ArialUnicodeMS 원본 읽기·PNG·새 프로세스 확인 | signed 확장의 고운바탕 R/B·HWP/HWPX PNG·2페이지 PDF 양쪽 페이지 확인 | 자체 권한·App Group 읽기 전용 공급. 실제 Finder UI/로그가 근거이며 signed PDF 디스크 파일은 확보하지 않음. 실패 시 전체 기본 대체, stale/취소는 폐기 | #566 이후 별도 수용 |
| Thumbnail | 실제 signed 확장의 ArialUnicodeMS 원본 읽기·새 프로세스 확인 | signed R/B·설정/관리 object 제거/복원·같은 경로 cache 무효화 확인 | exact/larger cache와 2건 렌더 한도 확인. 대체 bitmap 미보관. OS가 새 요청을 보내지 않는 영구 cache 갱신은 미보증 | #566 이후 별도 수용 |

PDF·인쇄의 signed 실증은 Stage 3 빌드, native는 Stage 4 및 Stage 5 회귀, Finder는 Stage 5 최종 signed 빌드다. Stage 6의 소스 대조에서 이 시점 차이를 기록했으며 하나의 최종 배포 후보에서 모든 소비자를 재수용했다고 주장하지 않는다. #569에서 출시 후보·지원 OS에 맞춰 필요한 최종 사용자 수용을 수행한다.

## 2. 동일한 선택·원본과 수명

관리 선택 → 유일한 활성 설치 후보 → 기존 fallback 순서를 공식 matcher로 적용한다. PS/fullName exact 선택과 요청 Bold/Italic이 어긋나면 native/출력 exact 성공으로 처리하지 않는다. 문서에 저장한 원래 family 이름은 유지하며 내부 alias·resource ID·경로를 저장하지 않는다.

| 검증 자산 | 식별과 근거 |
|-----------|-------------|
| GowunBatang-Regular / Bold | OFL v2.000, Google Fonts commit `c1eda9233c33ad7775b27efd794f931095cf6133`. 원본 SHA256 `466c593e7147412e748af4856d5ad14709b5a860bdf62b9c2546f2c5874e9849` / `dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94`, 합계 16,612,008 bytes. 사용자 OS 영구 설치 아님 |
| NanumSquareR / B | #567/#568 Stage 3 당시 활성 Mac 원본. SHA256 `5a51deae5237435d9a0bc0cc6cc30619a914b29801f895698cfdacadcad06e94` / `f737d58294faec9c632189af3a2a3e48e49c03c0256de09db61e879e2857bfbf`, 합계 1,457,140 bytes. Stage 4 이후 같은 활성 상태였다고 가정하지 않음 |
| ArialUnicodeMS | Stage 4/5 실제 활성 OS 원본 23,278,008 bytes. native 검증·signed 확장의 읽기/정확한 PS 적용을 구분. 설치/삭제/교체하지 않음 |

metadata snapshot은 원본 font bytes를 미리 읽지 않는다. 실제 사용할 face만 읽고 동일 bytes의 길이/hash/PS/style을 확인한다. PDF subset hash는 원본 TTF hash와 다르므로 두 hash의 일치를 수용 기준으로 삼지 않는다. 필요한 한글 subset의 program/ToUnicode와 본문·검색/선택·raster를 함께 본다.

HostApp 관리 job은 디스크 lease를 유지한다. 확장은 쓰기 권한을 요구하지 않는 FD snapshot을 소유하며 실제 object 읽기 동안 shared flock으로 게시/GC를 막는다. 읽기 사이의 세대/선택 변경은 stale로 폐기한다. Host bookmark는 확장에 복사하지 않고 공유 정책은 사용 flag/revision만 게시한다. 설치 원본의 stat·활성/권한·내용은 선택 bytes 읽기에서 다시 검사한다.

PDF는 최종 문서/글꼴 검증 후 atomic write, 인쇄는 패널 직전 immutable seal 후 패널 반환까지 bytes/lease 유지다. 확장 공급 실패는 원래 이름의 OS 조회로 우회하지 않는 기본 대체이며 stale/취소는 결과를 버린다. 취소한 실제 I/O가 반환하기 전에 slot/lease를 해제하지 않는다.

## 3. 사용자 안내에 반영할 동선

아래는 #569의 안내 작성 기준이다. 제품 소스의 실제 명칭을 확인했으며 Stage 6에서는 UI·문구·시각 요소를 새로 바꾸지 않았다.

1. macOS 알한글 앱 메뉴에서 설정(⌘,)을 열고 **글꼴** 탭으로 이동한다. Studio의 환경 설정에서도 native 글꼴 설정으로 이동할 수 있다.
2. **Mac에 설치된 글꼴 사용**을 켠다. 최초 metadata 확인 뒤 지원되는 face를 문서에 적용하며 기존 상단 글꼴 목록에서 선택한다. 매 실행마다 사용자가 ‘가져오기’를 반복할 필요는 없다.
3. 변경된 목록은 **다시 감지**, 세부 목록은 **감지한 글꼴 N개**에서 확인한다. 필요한 경우에만 원본 폴더 접근을 허용하거나 **폴더 다시 선택…**으로 권한을 복구한다. 설정의 권한이 확장에 자동 전달된다고 안내하지 않는다.
4. 원본과 별개의 복사본을 보관하려면 같은 탭의 **보관한 글꼴 → 글꼴 가져오기…**를 사용한다. 기본 Mac 사용 흐름에서 이 sheet를 먼저 열 필요는 없다. Windows ZIP 입력 UI의 완료를 이 버튼으로 대신 주장하지 않는다.
5. 실제 문서에서 Regular/Bold를 선택하고 PDF를 저장하여 확인한다. PDF·인쇄에 포함하지 못하는 face는 출력 전에 안내하며 취소가 기본이다. 명시 대체 출력은 해당 작업의 대체 결과다.
6. 앱을 종료·재실행하여 설치 원본의 정상 권한과 복사본 사용을 확인한다. 한컴을 제거할 때 설치 원본까지 사라지면 참조 사용은 유지되지 않는다. 한컴 내부 전용 글꼴의 무조건적 추출이나 제거 후 모든 글꼴 유지를 약속하지 않는다.

기존 설정 문구는 지원되는 face·상단 목록·PDF/인쇄 실패 안내와 원본 의존성을 설명한다. Finder 전체 형식 지원이나 한컴 제거 후 지속 사용을 보증하는 문구를 추가할 근거는 없다. 공개 안내의 최종 메뉴 캡처·링크·지원 범위는 #569에서 배포 후보와 대조한다.

## 4. 형식·환경·출력 제약

| 구분 | 현재 범위 / 미검증 |
|------|--------------------|
| 형식·스타일 | 출력/native exact는 검증한 단일 static SFNT·400/700 normal/italic 경계. Studio 메뉴·선택 범위와 구분. TTC/가변 축·HFT는 이번 exact 지원 범위 밖. 모든 static macOS 글꼴을 보증하지 않으며 AppleMyungjo/AppleGothic의 기존 inspector `malformedStructure` 사례가 있음 |
| typography | native replay의 complex shaping·자모 조합·회전/효과 등 제약. PDF 일반 가로 Bold 보정 밖 효과·모호한 run·모든 복합 문서의 동일 레이아웃은 미검증 |
| PDF reader | 실제 한글/ASCII 본문 수용과 별도 합성 영문 header의 PDFKit 반복 글자 누락을 구분. 이미지/스캔/path 글자는 text layer가 아니며 OCR 없음. 물리 A4 mm 교정도 별도 |
| OS/CPU | macOS 12 target compile·Intel Rust archive 확인. 실제 macOS 12/Intel 실행 미검증 |
| 실제 한컴·Windows | 실제 한컴 제품/버전별 설치·제거 및 Windows 생성 ZIP 수용 미검증. OFL 합성 문서를 대신 근거로 쓰지 않음 |
| 인쇄·배포 | 관리 경로 패널 취소 확인. 물리 프린터·공증/제품 릴리스·웹 배포 미실행 |
| 성능·메모리 | 2-slot·face/file/job bytes·bitmap 한도 확인. inspector/CoreText/Skia/WebKit/PDFKit 복제를 포함한 peak RSS·대형 목록/문서의 전체 비용은 미측정 |
| 실시간 갱신 | 확장은 매 요청 시작에 전체 목록을 재확인하고 선택 source/object stamp를 current 검사에 사용. 기존 활성 job 중 새 후보 추가만으로 즉시 재선택하는 보증·이미 열린 QL의 즉시 재표시는 없음. 실제 OS 활성화/비활성화 통합 수용은 #569에 남김 |
| OS thumbnail cache | 새 확장 요청의 same-path 무효화는 확인. OS가 요청을 보내지 않는 영구 cache의 자동 갱신 미보증. 문서 mtime 변경/전역 reset을 정상 기능으로 사용하지 않음 |

임베딩 기술적 후보와 `FontUsageEvidence`의 unknown/allowed/restricted는 별개다. unknown을 허가로 바꾸지 않는다. 정확한 정책은 [출력 계약](task_m020_568_output_contract.md)을 따른다.

## 5. #566 / #569 인계와 순서

2026-10-10 GitHub에서 #568/#566/#569가 OPEN이며 기존 완료 기준과 Mac/Windows 분리 방침을 확인했다. 이번 단계에서 이슈를 편집·close하거나 공개 코멘트를 게시하지 않았다.

| 대상 | 재사용할 결과 | 남은 완료 조건 |
|------|---------------|----------------|
| #568 최종 보고·PR | 6개 단계 보고, 이 표, source/evidence 대조 및 signed 복원/등록 정리 | 별도 단계 승인 후 최종 보고/게시·CI·리뷰. 제한된 Mac 소비자 연결을 전체 마이그레이션/출시 완료로 바꾸지 않음 |
| #566 Windows 입력 | #564 관리 복사·name/style·선택·snapshot과 #567/#568 소비자 | 실제 Windows 입력 확보, ZIP 경계/한도/오류, 원본 ZIP·폴더 제거 후 새 프로세스의 독립 보관. 소비자별 Windows 출력 증거 추가 |
| #569 Mac 수용·안내 | 현재 Mac 소비자 증거, 실제 설정 동선·원본 참조/독립 복사 구분 | 최종 후보의 설정→필요 권한→문서→출력→재실행, 실제 한컴/지원 OS와 변화/복구, 메뉴·스크린샷·링크 대조. Windows와 공개 배포는 별도 조건 |
| #569 Windows 수용 | #566 완료 입력과 위 소비자 계약 | Mac 성공과 구분한 Windows 수용 행·단계별 전송/가져오기 안내. 미완료 상태면 전체 안내/이슈 완료로 덮지 않음 |

권장 순서는 #568 최종 보고/PR 검토 후 Mac 안내 초안·후속 성능 범위 결정, 독립 #566 구현, #569의 Mac/Windows·최종 배포 후보 수용이다. Mac 안내 준비는 Windows 완료를 기다릴 필요가 없으며 공개 배포는 별도 승인 단계다.

## 6. 반복 탐색 최적화 후보

HostApp의 최초 활성화 중복 탐색은 #567에서 한 번으로 합쳤다. 이번 발견은 **확장 매 요청의 전체 CoreText scan/stat** 비용이다. signed 로그 32건은 최소 453.64ms / 중앙값 1,089.77ms / 최대 2,949.45ms이고 동시 대기를 포함한다. cache hit에서도 metadata 준비가 발생한다. 전체 앱 실행 지연의 측정치로 사용하지 않는다.

후속 구현 전 결정할 기준은 다음과 같다.

- 확장 프로세스별 metadata 준비 공유·변경 알림/정책 revision·필요 원본 검증을 조합하되 cache hit가 오래된 face를 반환하지 않도록 한다.
- 초기 bundled font의 process 등록과 사용자 설치 변화 알림을 구분한다. 단순 TTL·한 번 스캔 후 무기한 재사용으로 generation 검증을 없애지 않는다.
- 다수 파일의 최초/반복 Thumbnail, 설정 변경·관리 제거/복구·선택 설치 원본 변경·새 프로세스에서 준비 횟수와 시간을 비교한다. bitmap cache 진단과 font 준비 시간을 구분한다.
- 현재 정확성/2건 renderer·16건 준비 admission/96항목·64MiB bitmap 한도를 회귀한다. 최적화가 실제 OS cache 미요청 문제를 해결했다고 주장하지 않는다.

새 이슈 번호·구현 승인은 아직 없으며 #569의 성능 수용 입력으로 인계한다. 출시 전 반복 파일 사용성을 판단하는 데 우선 검토할 가치가 있다.

## 7. upstream 기여 후보

이번 native 연결은 v0.8.7 공개 core API 위의 앱 소유 adapter로 완성했다. 추가 upstream 수정이 구현의 필수 전제는 아니다. 기여는 다음 범위의 독립 가치와 유지 비용을 먼저 대조한다.

| 후보 | 가치 / 제출 전 조건 |
|------|-------------------|
| host-selected static bytes·원본 slot/style 요청·portable glyph resource 연결 helper | Rust/다른 native host에도 같은 정확한 face 연결을 제공할 수 있음. 우리 C ABI를 그대로 옮기기보다 Rust 소유 bytes/수명/오류 경계를 작게 설계하고 일반 font/문서 fixture로 수용 |
| Regular/Bold·동일 PS 다른 bytes·혼합 한글/ASCII·missing glyph/stale 대조 | 앱의 수용에서 범용 회귀를 추출할 가치가 있음. 공개 가능한 fixture와 upstream 기존 시험에 합치는 작은 범위로 준비 |
| 폴더 custom-font의 family당 한 face 의심 | 독립 runtime 재현이 남아 있음. 코드 구조만으로 upstream 버그를 선언하거나 우리 bytes 경로 성공을 해당 결함의 증거로 쓰지 않음 |

Swift/CoreText bytes context, App Group read-only/lease/bookmark, macOS QL/Thumbnail 등록·캐시·설정 운영은 이 저장소가 소유한다. 실제 검증된 일반 helper/회귀부터 분리하고 복합 shaping·전체 layout 지원을 묶어 약속하지 않는다. 공개 이슈/PR 작성·게시와 merge/릴리스는 별도 승인 범위다.
