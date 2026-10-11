# Task M020 #569 — Mac 출시 수용 기준

- 최초 기준일: 2026-10-10, 작업 `local/task569`, 당시 제품 기준 `dac73a589dc17143e744da6a12a51d638a81fb77`. 2026-10-12 Stage 4 제품 소스는 `46b3d66828bc2616842abdff6821b4aea3aed162`로 고정했다.
- 현재 단계: [Stage 4](../working/task_m020_569_stage4.md) 같은 소스의 Developer ID 진단 후보 Mac 주요 수용·복원/정리 결과 수용 승인. [Stage 5](../working/task_m020_569_stage5.md) 회귀·[Mac 부분 최종 보고](../report/task_m020_569_report.md)를 수용받고 [PR #583](https://github.com/postmelee/alhangeul-macos/pull/583) 게시. CI/검토·출시 게이트는 별도다. 과거 증거·현재 진단 후보·최종 배포 DMG 수용을 구분한다.
- core/Studio: 공식 `v0.8.7` / `1a76570e833917d15817415a53c09ad61ab3203f`.
- 근거: [#568 소비자 인계](task_m020_568_consumer_handoff.md), [Stage 1 대조 영수증](../working/assets/task_m020_569_stage1/evidence-audit.json).

## 1. 상태와 판단 단위

**확인됨**은 명시한 원본·형식·환경·소비자에서 실제 검증된 결과다. **조건부**는 선행 설정/원본/권한 또는 제한된 형식에 의존하는 상태다. **미지원**은 현재 exact 공급 경계 밖이며, **미검증**은 실제 실행 증거가 없는 상태다. 과거 단계 수용과 이번 최종 후보 수용은 별도 열로 기록한다.

목록에 보이는 글꼴 수, 폴더 파일 수, 화면 유사성은 실제 적용 증거를 대신하지 않는다. 선택된 PS/style·bytes/hash·소비자 결과와 후보 SHA를 함께 기록한다.

## 2. 현재까지 확인된 Mac 소비자

| 소비자 | 기존 실제 수용과 원본 | 현재 지원/조건 | 이번 Mac 준비 후보 수용 (최종 DMG 별도) |
|--------|----------------------|----------------|----------------------|
| Studio·기존 글꼴 목록 | #567 signed sandbox의 활성 NanumSquare R/B, HWP/HWPX 저장/재열기·재실행. 별도 관리 Gowun R/B의 격리 WK 변경/복구 | 조건부: 활성 원본·접근 권한과 지원 face. Canvas2D/CanvasKit, 화면 목록과 출력 exact 지원은 구분 | 확인됨: 같은 Developer ID 후보의 실제 설정/시스템 메뉴·NanumSquare·두 형식 저장 패널/재열기·새 PID 복원. 내부 bytes/renderer 상세는 같은 소스의 ad-hoc probe와 구분 |
| 사용자 PDF | #568 Stage 3 signed sandbox, 설치 NanumSquare·관리 Gowun R/B, HWP/HWPX. 실제 PS/program·한글 ToUnicode·원문/검색/선택, 독립 reader 대조 | 조건부: 검증한 static SFNT·R/B·일반 가로 본문. 임베딩/읽기 실패는 기본 취소·명시 대체 | 확인됨: 같은 후보의 실제 PDF 저장·Nanum R/B program/ToUnicode·원문/한글 검색/확대. 제한 face의 실제 GUI 대체 안내는 이번 새 수용에서 미검증 |
| 인쇄 | #568 Stage 3 seal된 실제 인쇄 PDF·callback. 관리 경로는 실제 macOS 패널 열기·사용자 취소 | 확인됨: 해당 payload·패널/취소 경로. 물리 프린터 출력은 미검증 | 확인됨: 같은 후보의 두 형식 실제 macOS 패널 열기/취소. 현재 소스의 ad-hoc sandbox 70 check로 immutable PDF·문서 보존·취소/복구를 별도 확인 |
| native CoreGraphics | #568 Stage 4/5, 관리 Gowun R/B·실제 OS ArialUnicodeMS·프로세스 fixture, HWP/HWPX | 조건부: exact PS/style/hash의 제한된 glyph replay. 전체 재조판/complex shaping 아님 | 확인됨: 같은 후보의 Finder CoreGraphics PNG/PDF·Gowun R/B. #580의 공통 정확성 회귀와 동일 소스 경계로 연결 |
| native Skia | #568 Stage 4/5 unsigned 공통 renderer, 관리 R/B·동일 PS 다른 bytes·설치 원본 대조 | 조건부: unsigned decode/direct 경로. signed Release 확장 기본은 CoreGraphics | 조건부: #580의 동일 공통 코드 최적화 회귀 인계. 현재 signed Finder 기본은 CoreGraphics이며 Skia 기본 전환 아님 |
| Quick Look | #568 Stage 5 실제 signed 확장·Finder, OS ArialUnicodeMS 및 관리 Gowun, 단일 PNG·2페이지 PDF·새 PID | 조건부: 확장 자체 권한·App Group 읽기 전용 공급. 실패는 기본 대체, stale는 폐기 | 확인됨: 같은 후보의 실제 Finder 단일 PNG 2개·2페이지 PDF/이동·정확한 Gowun R/B·fallback 0. 변경/복구는 별도 실제 Thumbnail 요청 |
| Thumbnail | #568 Stage 5 signed 설치/관리 공급·새 PID, exact/larger cache·정책/객체 제거/복구·동일 경로 무효화 | 조건부: 새 extension 요청의 cache identity. OS가 요청을 생략하는 영구 cache 즉시 갱신은 미보증 | 확인됨: 표준 PNG 3개·GUI 요청, 같은 경로 10 phase/20 요청. 정상 16·예상 fallback 4를 구분. 다수 문서/성능은 #580 accepted 증거 인계·#581 분리 |

이전 signed 출력과 Finder는 서로 다른 단계 빌드다. Stage 1에서는 제품 입력 소스 125개가 signed Finder provenance와 같고 보존 증거 61개·checksum 26개·PDF 12개가 기존 hash와 일치함을 확인했다. 과거 앱 executable은 정리되었으며 현재 바이너리를 다시 확인한 것으로 표현하지 않는다. 이 결과가 새로운 후보 전체 통과를 의미하지 않는다.

## 3. 원본·형식·환경 경계

- 정상 설치 사용은 원본이 활성 상태이고 읽기 권한이 유효할 때 유지된다. 설정을 켠 뒤 매 실행마다 수동 가져오기를 반복하는 흐름이 아니다. 필요한 face만 실제 사용 시 읽는다.
- 원본 삭제/비활성화/접근 상실은 정확 적용 성공이 아닌 상태 안내·대체/취소 경로로 수용한다. 별도 관리 복사본의 독립 유지와 설치 참조를 구분한다.
- 검증된 시험은 Gowun/NanumSquare Regular 400·Bold 700의 static face 중심이다. 정책상 허용되는 다른 slant/style를 전부 실증한 것으로 확대하지 않는다.
- TTC/가변 축/HFT는 이번 출력·native exact 지원 보증 범위 밖이다. Studio의 metadata/목록/선택 가능 여부와 각 소비자의 exact 공급을 구분한다. AppleMyungjo/AppleGothic의 기존 inspector 제한은 유지한다.
- 기본 대체·complex shaping·효과·회전·전체 pagination/모든 문서의 한컴 동일 레이아웃을 보증하지 않는다. 별도 합성 영문 header의 PDFKit 반복 글자 추출 제약도 잔여 조건이다.
- 기존 실제 실행은 arm64/macOS 26.5.2이며 같은 환경을 이번 Stage 1에서 확인했다. macOS 15.7.9 출력 CI는 별도 head/환경의 회귀 근거다. macOS 12 target compile·Intel archive와 해당 환경의 실제 실행을 구분한다.
- 실제 한컴 제품 설치/제거·최소 OS/Intel runtime·물리 프린터·Windows 입력은 미검증이다. 설치 사실·fsType·사용 체크를 외부 사용/복사 라이선스 보증으로 설명하지 않는다.

## 4. 최종 후보 기록과 필수 Mac 동선

Stage 4의 569.4.1/UUID 후보는 보고서·영수증에 기록했다. 최종 공개 버전/DMG 등 release 운영에서 아직 만들어지지 않은 항목은 `미검증/미확정`으로 유지한다.

| 필드 | 기록할 값 |
|------|-----------|
| 제품 후보 | commit, 버전/build number, source·core/Studio receipt, build flag, 앱/DMG hash |
| 환경 | macOS build·CPU·PID·설치 경로·해당 App Group·권한 상태 |
| 원본/공급 | 설치 참조 또는 관리 복사, PS/style·원본 hash·공급 identity, 실제/주입 구분 |
| 결과 | 문서 hash/형식·페이지, 실제 저장/출력 결과, fallback/stale/실패, 원시 증거·그림 |
| 정리 | 시험 대상·백업 identity·복원 검증, 소유 등록/보관함 정리, 다른 작업과 구분 |

필수 흐름은 설정(⌘,) → 글꼴 → **Mac에 설치된 글꼴 사용** → 필요한 권한 → 기존 상단 글꼴 목록 선택 → HWP/HWPX 편집·저장/재열기 → PDF·인쇄 경로 → 앱 재실행이다. Finder는 같은 후보의 단일/다중 페이지 Quick Look과 Thumbnail을 별도로 확인한다. 원본/설정/관리 객체 변경과 복구, 반복 요청 freshness와 비용을 함께 수용한다.

웹 안내는 **다시 감지**, **폴더 다시 선택…**, **보관한 글꼴 → 글꼴 가져오기…**를 실제 메뉴와 대조한다. 가상 목록이나 한 face만 공급한 과거 화면을 실제 전체 감지 화면으로 쓰지 않는다. 공개 안내의 기능 제공 버전은 release 시점에 맞춘다.

### 2026-10-12 Stage 3 추가 근거

PR #582의 `34ae2f4b`를 `4a17ea87`로 통합한 제품 소스와 웹·Help 변경을 기준으로 126개 Swift 입력 hash를 보존했다. 현재 UI probe의 기록 입력 192개가 실행 후 소스와 일치한다. 실제 Mac 목록 232 family/809 face, 시스템 메뉴 204 family, NanumSquareR/B의 HWP Canvas2D·HWPX CanvasKit·native 저장·새 프로세스 복원 20/17 check가 ad-hoc sandbox 앱에서 통과했다. 첫 실행 `restoredEnabled=false`와 재실행 `true`를 구분한다.

Stage 3의 실제 목록/안내 이미지 검증과 Stage 4의 Developer ID 후보 실제 앱·출력·Finder 검증을 구분한다. 2026-10-12 Stage 4 결과로 위 표를 갱신했다. #580의 승인된 성능/정확성 결과와 <300ms 후속 #581 분리를 유지하며 최종 DMG·공개 gate는 별도로 남긴다.

## 5. 후보 준비·복원과 출시 인계

- Stage 2 직접 probe는 실제 CoreText 환경과 격리 관리 저장소를 사용한다. 기존 user store/OS 설치 글꼴을 변경하지 않는다.
- 기존 Stage 2 후보와 구분하여 이번 같은 소스 후보는 `build.noindex/task569/stage4/finder-candidate-01/`에 앱·fixture·backups·install-state를 배치했다. 제품 ID와 고유 probe UUID/compile flag의 차이를 영수증에 기록하고 해당 UUID의 시험 보관함만 사용한다.
- 기존 #568 전용 helper의 경로 guard를 우회하지 않는다. Stage 2에서 승인된 #569 입력/출력 루트·고유 marker·백업 digest·상태 검사를 갖춘 재사용 경계를 마련한 뒤 `plan` 결과를 검토한다.
- 구체 서명·기존 `/Applications/Alhangeul.app` 보존/임시 교체·복원은 후보와 절차가 준비된 시점에 범위를 확인한다. 사용자 문서 창이 열려 있거나 다른 작업의 설치본으로 바뀌었으면 교체/자동 복원을 진행하지 않는다.
- 표준 smoke 안에서만 소유 후보/확장 등록을 수행한다. 전역 cache reset 없이 소유 경로를 해제하고 원래 앱·등록·보관함을 복원한다. 다른 앱 등록·원본 문서는 변경하지 않는다.
- 최종 제품 후보는 probe flag가 없는 실제 산출물과 구분한다. M900 release 운영의 signed/notarized pre-public DMG 설치 smoke를 통과한 뒤 공개 gate로 인계한다.
- Mac 준비/선출시와 Windows #566/#569 후속을 구분한다. 이번 부분 PR이나 release로 #569/#562 전체를 닫지 않는다.
