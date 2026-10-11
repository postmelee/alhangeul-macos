# Task M020 #569 — Mac 로컬 글꼴 출시 준비 구현계획

- 수행계획: [task_m020_569.md](task_m020_569.md)
- 이슈: [#569](https://github.com/postmelee/alhangeul-macos/issues/569), 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562)
- 시작 기준: `devel` / `dac73a589dc17143e744da6a12a51d638a81fb77`, 작업 `local/task569`
- 재개 기준: `devel` / PR #582 merge `34ae2f4b14ea6baf5cce6346b5d491a8e6e6ba11`을 `4a17ea87` merge로 통합했다. 제품·테스트·도구는 검토된 devel과 일치하며 #569 기존 증거·이력을 보존한다.
- 승인: 2026-10-10 수행계획서 제시 후 작업지시자의 “진행해줘”를 수행계획 승인·구현계획 작성 지시로 기록한다.
- 구현계획/Stage 1 승인: 2026-10-10, 구체 구현계획 제시 후 작업지시자의 “진행해줘”.
- Stage 2 승인: 2026-10-10, Stage 1 보고 후 작업지시자의 “진행해줘”.
- Finder 시험 승인: 2026-10-10, 구체 후보의 로컬 서명·임시 설치·복원 요청 후 작업지시자의 “진행해줘”.
- 후속 정렬 승인: 2026-10-10, 작업지시자의 “진행해줘”로 성능 이슈 등록·수행계획 작성·후속 순서 정렬을 승인받았다. 성능 제품 구조 구현은 해당 계획 승인 후 진행한다.
- 재개 승인: 2026-10-11 “#569의 웹페이지 로컬 글꼴 안내와 Mac 최종 수용 검증을 진행해줘”. Stage 3 웹 안내·도움말 구현과 Stage 4 수용 준비를 진행한다. 구체 후보의 Developer ID 사용·임시 설치는 준비 후 승인한다.
- 현재: [Stage 3](../working/task_m020_569_stage3.md) 구현·로컬 검증 완료.웹 안내와 Mac 최종 수용을 함께 명시 지시받아 Stage 4 후보 준비를 이어간다. #580 완료·현재 signed 결과를 수용했으며 <300ms 후속 #581은 선행 조건이 아니다. Stage 4 같은 후보 Mac 수용 → Stage 5 부분 PR·release 운영 인계를 유지한다.

## 1. 실행 순서와 완료 범위

| 단계 | 작업 | 변경 범위 | 종료 조건 |
|------|------|-----------|-----------|
| 1 | 기존 증거·지원 범위·측정 계약 확정 | 기술 계약·단계 보고서·계획 상태 | 근거 SHA/형식/권한/소비자별 지원 표, 실제와 격리 측정 경계, 후보 준비와 복원 절차가 구체적임 |
| 2 | 반복 탐색 비용 측정·개선 판단 | 격리 측정 probe·집계 스크립트, 필요한 최소 진단 | 최초/반복·OFF/ON·cache·동시 요청·변경 수치와 정확성 근거, 개선 필요 여부 결정 |
| 3 | 웹 안내·화면·도움말 동선 | `docs/fonts/index.html`, 홈 링크·필요 CSS·선별 이미지, HostApp 도움말 연결 | 직접 확인 가능한 desktop/mobile 화면, 실제 메뉴·지원 문구·링크 검증 |
| 4 | 동일 후보 Mac 사용자 수용 | 후보/fixture·검증 결과·지원 표 | 설정→문서→출력→재실행·Finder·변경/복구를 같은 후보에 연결, 미검증 환경을 명시 |
| 5 | 최종 회귀·보고·부분 PR·release 인계 | 최종 보고·오늘할일·검증 인계 | Mac 준비 결과와 Windows 잔여 조건, 배포 운영에 필요한 후보·문서·증거가 취합됨 |

각 단계 종료 후 보고서와 해당 변경을 묶어 커밋하고 다음 단계 승인을 받는다. 최종 보고/PR 게시·merge와 실제 public release는 각 정형 절차의 승인 범위에 따라 진행한다. 이번 부분 PR은 `Refs #569`를 사용하고 `Closes #569`를 사용하지 않는다.

Stage 2 이후의 제품 성능 개선은 #580 독립 계획·브랜치에서 먼저 진행한다. #569의 5단계는 유지하며 #580의 개선 후 signed 결과를 Stage 3–5에 인계한다. 이미 작성한 진단 코드와 새 성능 변경의 겹침은 통합 시 대조하고, #569 전체 PR 병합을 #580 구현의 선행 조건으로 만들지 않는다.

## 2. Stage 1 — 지원 표와 측정 계약

[#568 소비자 인계](../tech/task_m020_568_consumer_handoff.md), #567/#568 보고서 및 선별 evidence를 현재 소스와 대조한다. 다음 두 기술 문서를 작성한다.

- `mydocs/tech/task_m020_569_mac_acceptance.md`: 소비자·OS/CPU·원본·형식·style·권한·후보·검증 증거와 확인됨/조건부/미지원/미검증 상태.
- `mydocs/tech/task_m020_569_finder_performance.md`: 현재 호출 순서·측정 구간·입력/반복 수·집계 방식·한도·정확성·개선 판단 기준.

현재 소스 확인 사항:

- `ExtensionFontSupply.snapshot()`은 공유 정책을 읽고 `catalog.setEnabled` → `catalog.refresh` → 공급 snapshot·원본/관리 객체 stat fingerprint·current 검사를 수행한다.
- `setEnabled`는 설정 저장/세대 변경이며 그 자체가 scan을 실행하지 않는다. 목록 준비를 요청하는 `refresh`가 실제 환경의 CoreText scan을 호출한다.
- Thumbnail은 16건 admission 이후 공급 snapshot을 준비한 다음 bitmap 캐시를 조회한다. 동일 요청의 bitmap exact/larger hit도 공급 준비를 거친다.
- 기존 `metadataMs`는 snapshot 전체 구간이다. CoreText scan만의 시간이나 전체 요청시간과 같지 않다. Thumbnail의 `renderMs` 역시 metadata·대기 포함 전체 응답으로 해석하지 않는다.
- 기존 `Tests/ExtensionFontProbe/main.swift`는 설치 scan을 빈 목록으로 주입한다. 이 결과를 실제 로컬 글꼴 목록 준비 성능으로 사용하지 않는다.
- 기존 signed smoke 스크립트는 #568 경로와 fixture를 고정한다. #569에서 실행하려면 실행 루트·고유 identity·백업/복원 계약을 검토한 뒤 재사용 가능한 범위를 보정해야 한다.

Stage 1에는 제품 소스 수정·새 build·서명·설치·등록·OS 글꼴 변경을 하지 않는다. 원본 fixture와 현재 lock/receipt의 존재·hash·구현 위치를 확인하고 측정 환경에 없는 조건을 기록한다.

## 3. Stage 2 — 성능 측정과 개선 판단

### 3.1 격리 직접 측정

`Tests/ExtensionFontPerformanceProbe/main.swift`와 `scripts/probe-extension-font-performance.py`를 새 진입점으로 검토한다. 실제 `InstalledFontSystem().environment`의 scan/read를 계측 wrapper로 감싸고 프로덕션 `ExtensionFontSupply`·`HwpThumbnailRenderCache`·preview renderer를 호출한다. scan을 가짜 목록으로 교체하거나 결과를 성공으로 강제하지 않는다. 격리 관리 저장소와 공개 OFL fixture만 생성하며 사용자 설치 목록·글꼴 파일은 변경하지 않는다.

| 시나리오 | 반복과 분리 | 확인 사항 |
|----------|-------------|-----------|
| 공급 snapshot 최초/반복 | OFF/ON 각각 새 프로세스 3회, 프로세스당 최초 1회 + 반복 10회 | scan 횟수·scanMs·snapshotMs, 목록/선택 identity, bytes 선읽기 없음 |
| 동일 문서 Thumbnail | HWP/HWPX, 256px 요청 최초 1회 + 반복 10회, 각 조건 2회 | miss/exactHit, 준비/총시간·읽기 횟수·현재성, bitmap 재사용 |
| 큰 bucket 재사용 | 256px 준비 후 128px 요청 반복 10회 | 실제 matched bucket·larger hit와 공급 비용 |
| 다수 파일 | 고유 이름의 격리 문서 10개, 순차 3 pass와 동시 최대 4건 3 pass를 분리 | 동일 PID·작업량의 OFF/ON 비교, 성공·busy·취소·실패 수와 대기 |
| preview | 단일 페이지 HWP/HWPX와 2페이지 HWPX, 최초/반복 각각 기록 | snapshot 한 번/다중 페이지 재사용·전체 반환, 실제 face/style |
| 변화·복구 | OFF/ON, 관리 선택/제거/복구, 격리 원본 변경, 새 프로세스 | 새 identity·cache miss·stale 폐기·정확한 복구, 해제/bytes 한도 |

이 반복 수는 계획값이며 실행 결과로 표현하지 않는다. 설치 원본 교체/비활성화는 사용자 글꼴에 실행하지 않고 격리 자산과 주입 회귀로 검증한다. 실제 OS 변화 수용이 필요하면 독립 시험 원본/설치 범위를 준비해 승인받는다.

### 3.2 실제 Finder 측정

signed/sealed 후보와 고유 fixture·보관함·앱 백업/복원 계획을 준비한 뒤 구체 시험 범위를 확인한다. 표준 smoke 안에서만 등록/임시 설치를 수행한다. 전역 cache reset이나 사용자 문서 mtime 변경을 측정의 정상 절차로 쓰지 않는다.

- 같은 파일의 Quick Look 열기/닫기 10회와 고유 파일 10개의 순차 열기를 2 pass 시도한다. 실제 요청이 관찰된 것만 sample로 집계한다.
- 고유 문서 10개의 Finder icon view 첫 표시/반복 표시와 크기 변경을 확인한다. OS cache로 extension 호출이 없으면 `요청 없음`으로 기록한다.
- 실제 PID·policy/backend·문서 alias·요청/완료 timestamp·cache event·font identity를 수집한다. 같은 PID의 동시 요청에서 metadata 로그를 특정 문서에 확실히 대응할 수 없으면 개별 대응을 추정하지 않는다.
- 기존 로그로 전체 응답 구간을 분리하기 어렵다면 `ExtensionFontSupply`, QL/Thumbnail provider에 opaque 요청 식별자와 단조 시계 기반 시작/완료 진단만 추가한다. 원본 경로/bytes를 새로 공개 로그에 남기지 않는다.

직접 probe는 공통 서비스 비용·정확성을, 실제 Finder는 signed 프로세스·실제 요청·사용 동작을 입증한다. 두 결과를 별도 표에 둔다. 최종 배포 산출물과 probe flag/고유 저장소를 사용한 시험 빌드도 구분한다.

### 3.3 결과와 판정

`build.noindex/task569/stage2/{run-id}/`에 source/lock/fixture hash·기계 환경·설정·반복 수·단조 시계 원시 samples와 결과 JSON을 저장한다. scan, snapshot, bytes, render, 전체 응답의 겹치는 구간을 단순 합산하지 않는다. 시간값이 확보되지 않은 구간은 미측정으로 남긴다.

- 유효 성공 sample의 count/min/median/max, 10개 이상일 때 nearest-rank p90을 집계한다. 최초와 warm을 분리하고 실패/busy/취소는 별도 집계하여 조용히 제외하지 않는다.
- OFF/ON의 같은 환경·같은 문서 작업량을 비교한다. direct/unrestricted 결과를 sandbox Finder 수치로 바꾸지 않는다. peak RSS를 실제로 측정하지 않았으면 메모리 전체 통과로 표시하지 않는다.
- **개선 검토 기준(이 타스크의 잠정 판단값)**: 안정된 warm/cache-hit에서 metadata median ≥ 500ms이고 유효 전체 응답의 ≥ 30%를 차지하는 결과가 2회 반복되거나, 정상 다수 파일 사용에서 준비 대기/busy가 반복되는 경우. 이 수치는 OS 표준이나 자동 합격/불합격 기준이 아니다.
- 위 조건이면 재현된 비용과 목표를 별도 성능 이슈/계획으로 넘기고 Mac 출시 전에 개선 필요성을 결정한다. 목록 재사용·변경 알림·cache 순서 등의 구조 변경을 이 측정 단계에서 즉시 구현하지 않는다.
- 지원 face가 달라짐, stale 반환, 취소/해제 실패, 권한 우회, 한도 초과는 성능과 무관한 출시 차단 결함으로 분리한다. 개선 후 같은 입력·측정 방식으로 필요한 회귀를 반복한다.

## 4. Stage 3 — 웹 안내와 앱 접근

`docs/fonts/index.html`에 **Mac에 설치된 글꼴 사용** 안내를 작성한다. `docs/index.html`에 안내 링크와 검증된 기능 설명을 추가하고, `docs/styles.css`의 기존 header/card/본문 스타일을 재사용한다. 기존 기능 영상 단계 수와 스크립트를 바꾸는 작업은 기본 범위에 넣지 않는다.

안내 흐름:

1. 알한글 설정(⌘,) → **글꼴** 탭.
2. **Mac에 설치된 글꼴 사용** 켜기와 필요한 경우의 최초 접근 허용.
3. 문서의 기존 상단 글꼴 목록에서 선택, Regular/Bold와 대표 본문 확인.
4. 문서 저장·재열기/PDF 확인, 정상 권한에서 재실행마다 가져오기를 반복할 필요가 없다는 설명.
5. 목록 확인·**다시 감지**·**폴더 다시 선택…**으로 복구.
6. **보관한 글꼴 → 글꼴 가져오기…**의 독립 복사본과 원본 설치 참조의 차이, 원본 삭제/비활성화 영향 및 출력 전 안내.

설정·글꼴 목록·문서/PDF의 실제 후보 화면을 `docs/assets/`에 선별한다. 가상 28개 목록·고운바탕 하나만 공급한 과거 probe 화면을 실제 사용자 전체 감지 결과로 사용하지 않는다. 공식 OFL 시험 문서·font source/PS/style 근거와 촬영 후보를 내부 영수증에 기록한다.

현재 HostApp의 native command에는 글꼴 안내 링크가 없다. `Sources/HostApp/HostApp.swift`의 Help 메뉴에 **Mac 글꼴 사용 안내**를 연결하는 작은 변경을 계획한다. URL은 기존 Pages origin의 `/fonts/`로 고정하고 웹 공개와 앱 배포 시점을 맞춘다. 설치 사용 설정 UI와 Studio source adapter는 바꾸지 않는다.

desktop 1280px와 mobile 390px/320px에서 줄바꿈·가로 overflow·이미지·명암·키보드 focus·홈/FAQ/도움말 링크를 직접 확인한다. 로컬 preview를 열어 사용자에게 실제 화면과 조작 경로를 제공한다. 버전 확정 전에는 개발 안내임을 표시하고 공개 릴리스 게이트에서 기능 제공 버전과 맞춘다.

## 5. Stage 4 — 같은 후보의 Mac 수용

후보 commit·제품 코드/Studio/core receipt·build flag·배포 산출물 hash를 고정한다. 실제 제품 후보와 격리 probe의 차이를 기록하며 signed probe 성공만으로 최종 DMG 통과를 선언하지 않는다. 성능 개선 PR이나 기능 수정으로 후보가 바뀌면 영향을 받는 수용을 변경 후 후보에서 수행한다.

- 정상 설정/필요 권한 → 실제 설치 face 선택 → HWP/HWPX 편집·저장/재열기 → 종료/재실행 자동 사용.
- Regular/Bold의 PS/style/공급 bytes, 실제 저장 PDF 원문·검색·font resource와 확대 화면. 출력 불가 face의 기본 취소·명시 대체 동선.
- 인쇄용 immutable payload와 macOS 패널 열기/취소. 물리 프린터 전송은 하지 않는다.
- Finder Quick Look 단일 PNG/다중 PDF와 Thumbnail, 새로운 요청의 변경/복구·cache identity·자원 한도.
- 실제 현재 OS의 사용자 동선과 지원 범위 표를 대조한다. macOS 12/Intel 실행 등 환경이 없는 조건은 미검증으로 남기고 별도 출시 판단에 반영한다.
- 서명/임시 설치 시험은 구체 후보·인증서·설치 대상·백업/복원·고유 보관함이 준비된 뒤 승인된 범위에서만 실행한다. 끝나면 원래 앱과 공급/등록 상태를 복원한다.

## 6. Stage 5 — 회귀·부분 PR·릴리스 인계

변경 경계에 맞춰 `scripts/test-font-library.sh`, 관련 HostApp/출력·캐시 테스트와 no-AppKit·matcher/Studio receipt를 검증한다. Help 메뉴 변경은 HostApp build/실제 열기, 웹은 로컬 링크/HTML·desktop/mobile 시각 확인을 수행한다. 관련 없는 큰 suite를 문서 변경만으로 반복하지 않는다. 동일 후보의 CI와 필요한 native/Finder 회귀 결과를 함께 기록한다.

`mydocs/report/task_m020_569_report.md`에 Mac 준비 결과를 남기고 Windows 부분 미완료를 명시한다. 부분 PR은 `publish/task569` → `devel`이며 #569/#562 이슈 close는 수행하지 않는다. 최종 보고·push/PR 게이트에서 이 부분 완료와 브랜치 정리를 맞춘다.

public release는 M900 운영 이슈로 추적한다. 확정 버전/build number·후보 SHA, 직전 v0.2.2 이후 포함 PR 분석, 사용자 release note, 지원 제한, signed/notarized pre-public DMG 설치 smoke와 원래 앱 복원, 최종 Pages 안내·appcast·Cask 반영 게이트를 해당 운영 계획에 인계한다. 태그·Release·Pages 공개 실행을 이 단계의 문서 수용으로 대체하지 않는다.

## 7. 자산·안전 경계와 정리

모든 신규 앱/확장·시험 문서·cache는 `build.noindex/task569/` 아래에 둔다. #568 보존 PDF·로그·JSON과 #567 OFL 원본은 읽기 전용 입력으로 취급한다. 사용자 OS 글꼴·한컴 앱·원본 문서와 다른 작업자의 창은 변경하지 않는다.

공개 가능한 PNG/작은 JSON·영수증만 단계 evidence로 선별한다. 상용 font bytes·앱/DMG·개인 경로/문서는 커밋하지 않는다. 사용이 끝난 실행별 build/cache·시험 등록은 소유 범위를 확인해 정리하고 후보 검증·release 운영에 필요한 자료는 보존한다.

## 8. 공통 보고와 현재 승인 범위

각 단계는 `mydocs/working/task_m020_569_stage{N}.md`에 실제 명령·환경·입력·판정·실패/미검증·소유 정리 결과를 기록한다. stage commit은 `Task #569 Stage {N}: ...` 형식이다. 문서 작성 단계는 링크/구조·오늘할일·diff 확인만 수행한다.

기존 Stage 1–2와 해당 signed Finder 측정·복원 승인은 완료된 실행의 근거로 보존한다. 2026-10-11 PR #582 병합 후 웹 안내와 Mac 최종 수용 재개를 명시 승인받아 Stage 3의 기존 범위를 실행한다. 구체 후보의 Developer ID 사용·임시 설치는 준비 후 승인하며, 각 단계 종료 보고와 최종 공개 배포 게이트를 유지한다. 이번 웹 초안 작성이나 ad-hoc 격리 UI 촬영을 최종 제품/DMG 수용 완료로 판정하지 않는다.
