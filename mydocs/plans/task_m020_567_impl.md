# Task #567 — Studio 글꼴 연결 구현계획

- 수행계획: [task_m020_567.md](task_m020_567.md)
- 이슈: [#567](https://github.com/postmelee/alhangeul-macos/issues/567), M020 / v0.2
- 브랜치: `local/task567`, 기준 `devel` / `0fa65fa`
- 상태: 전체 단계 완료. 2026-10-08 최종 보고·PR 게시를 승인받아 [최종 보고](../report/task_m020_567_report.md)에 수용 결과·한계·#568/#569 인계를 정리했다. PR 리뷰·merge 승인 대기. [Stage 5](../working/task_m020_567_stage5.md) · [Stage 3 보고](../working/task_m020_567_stage3.md) · [Stage 4/4.1/4.2 보고](../working/task_m020_567_stage4.md) · [시작 비용 조사](../tech/task_m020_567_startup.md). [계약](../tech/task_m020_567_adapter.md) · [진행 보정](../tech/task_m020_567_replan.md).
- Stage 2 native 소스와 테스트를 변경했다. upstream pin과 Studio bundle은 유지했다.

## Stage 5 승인 범위 — 2026-10-08

- 현재 #567 / `local/task567`에서 실제 CoreText 목록과 제품 service·Coordinator·공식 bundled Studio를 사용하는 격리 앱의 서명 sandbox 수용을 진행한다. 테스트 도구와 필요한 결함 수정, 검증 증거·인계·단계 보고를 포함한다.
- 이미 설치된 NanumSquare Regular/Bold를 우선 사용한다. 새 글꼴 영구 설치나 사용자 원본 변경 없이 실제 목록·필요 face bytes·기존 메뉴·문서 저장/재열기를 검증한다. 설치 목록 수와 지원/읽기 성공 수를 구분한다.
- 새 프로세스의 준비·사용 설정 복원, 최초 활성화 탐색 병합, 동일 face 동시 요청 병합과 반복 표시의 읽기 수/시간을 기록한다. 격리 앱 준비부터 첫 문서 ready까지를 측정하며 전체 제품 시작·OS font server cold·최소 OS 실행으로 일반화하지 않는다.
- #565의 동일 bundle ID와 기존 승인된 로컬 서명 기준으로 테스트 폴더 bookmark 복원을 최종 소스에서 재검증한다. 허용 범위는 기존 `build.noindex/task565-stage4/installed-font-permission-fixture`이며 새 Studio probe로 권한을 복사하지 않는다.
- 실제 목록의 설정·기존 메뉴 화면과 직접 조작 가능한 창을 제공한다. 이전 fixture 상태 전이/원본 상실·독립 관리 복사본 대조 및 완료한 회귀 증거는 재사용하고 새 sandbox 경계에 필요한 검증을 추가한다.
- #568의 출력/확장과 #569의 Mac/Windows 수용·제품 안내에 계약·제약을 인계한다. 최종 보고/PR 게시·이슈 close·공개 배포·공증·Quick Look 등록은 포함하지 않는다.

## 1. 확인한 출발점

- native 공급은 `InstalledFontCatalogService`, `InstalledFontSupplyCatalog`를 재사용한다. 현재 service는 `InstalledFontSettingsModel`의 private 멤버이므로 공유 소유권을 명시적으로 분리하거나 접근 경계를 제공해야 한다.
- Studio manifest와 core lock은 모두 `v0.8.6` / `f1f9c6ae58344ee9368996d3543f76b9345cf227`이다. 운영 매뉴얼의 과거 버전 예시보다 이 실제 lock을 기준으로 한다.
- pinned `rhwp-studio/src/core/local-fonts.ts`는 `LocalFontRecord`와 별칭 lookup을 갖는다. `detectLocalFonts()`는 `queryLocalFonts()` → `collectLocalFontRecords()`를 호출하며 이름 보강 과정에서 blob을 읽는다. 단순 shim은 필요 bytes만 읽는 제품 요구를 충족한다고 볼 수 없다.
- 같은 모듈의 `loadLocalFontBytesFor()`는 PS 기반 바이트 조회와 in-flight 병합을 제공한다. native ID·generation과 버전 충돌을 그대로 보존하는 adapter가 필요하다.
- `canvaskit-renderer.ts`의 `resetDocumentResources()`는 local Typeface 및 실패 캐시를 정리한다. 열린 문서 갱신에 이를 연결할 수 있는지, 다른 측정·CSS 캐시까지 정리되는지는 Stage 1에서 추적한다.
- HostApp `RhwpStudioWebView.Coordinator`에 메시지 처리와 editor session 경계가 있다. 새 글꼴 요청에는 해당 WebView·main frame·신뢰 origin·현재 session을 모두 검사한다.

## 2. 구현 계약과 결정 지점

### native 공급과 수명

단일 service를 앱 설정과 모든 문서가 공유한다. native 소유자가 catalog를 준비하고 최신 generation을 전달한다. WebView 요청에는 경로가 아닌 출처 종류, opaque ID, generation 또는 관리 snapshot token, 요청 식별자를 사용한다. token은 해당 문서 session의 허용 집합에 묶으며 Swift snapshot 자체를 직렬화하지 않는다.

bytes 전송 방법은 기존 resource scheme과 응답형 메시지를 Stage 1에서 비교해 확정한다. 64 MiB 파일 한도에 따른 메모리 복제·base64 팽창을 포함해 판단하며 임의 URL 요청은 받지 않는다. catalog 개수·메시지 크기·미완료 요청 한도와 응답 제한을 명시한다. 설치 bytes 요청은 service의 최대 2개 동시 요청과 맞추고 busy는 제한된 재시도 대상으로 처리한다.

문서 종료·이동·재로드·실패 시 요청을 취소하고 관리 snapshot lease를 해제한다. 늦게 도착한 응답은 session 및 generation 확인 후 폐기한다. 설치 상태 변화와 관리 자산 선택 변화는 각각의 세대에서 소비자 revision으로 반영하며 둘의 수명을 혼동하지 않는다.

### 매칭과 렌더러

기존 PS/full/family+style 및 검증된 alias lookup을 재사용한다. 설치 참조·명시적으로 선택한 관리 복사본·bundled/system fallback 간 순서는 기존 resolver 분석 후 Stage 1 계약으로 확정한다. 동명 다른 원본을 PS 이름만으로 합치거나 실패 시 조용히 다른 버전을 선택하지 않는다.

native metadata snapshot 공급과 필요 face bytes 요청을 분리한다. CSS FontFace와 CanvasKit의 적용·실패·캐시를 따로 확인한다. 내부 식별 alias와 문서 원래 이름은 별개로 유지한다. 필요한 다국어 이름 정보가 현재 DTO에 부족하면 정확한 SFNT 메타데이터 확보 위치·시점을 정하고 전체 파일 선읽기를 피한다.

TTC/가변은 현재 native 제한을 유지한다. 정확한 face/axes가 검증되지 않은 파일을 단일 face로 잘못 공급하지 않는다. 지원 확대가 필요하면 계획 보정 후 수행한다.

### 자동 사용과 UI

현재 false 기본값과 이미 저장한 사용자 선택은 우선 보존한다. 사용 설정을 켠 상태에서는 재실행·문서 열기에 자동 준비/공급한다. 최초 기본값을 true로 바꾸거나 기존 false의 의미를 바꾸는 것은 Stage 1에서 별도 결정안으로 제시한다.

실제 연결이 확인된 뒤 ‘문서 적용 준비 중’ 안내를 현재 지원 범위에 맞게 수정한다. 실패는 원본 부재·권한 복구·충돌·미지원으로 구분하고 기존 설정 UI를 재사용한다. 화면 변경 단계에는 스크린샷과 직접 조작 가능한 실행 경로를 제공한다.

## 3. 단계별 산출물·검증·커밋

| 단계 | 산출물 | 완료 검증 | 커밋 |
|------|--------|-----------|------|
| 1 | pinned 소스의 감지→매칭→각 renderer→저장 경로, adapter API·우선순위·세대/캐시 계약, upstream 필요 여부와 변경 경계 | 소스 위치 근거, 고운바탕을 사용하는 실제 문서 검증 시나리오, 미결정 사항 해소 | `Task #567 Stage 1: Studio 글꼴 adapter와 캐시 계약 확정` |
| 2 | 단일 service 소유권, session 범위 catalog/bytes bridge, 관리 snapshot 수명 및 취소 | 비신뢰 frame/origin, 잘못된 ID·세대, 종료 후 응답, 요청 한도, busy 재시도, lease 해제·오류 경로 | `Task #567 Stage 2: Studio native 글꼴 공급 연결` |
| 3.1 | 병합 API용 앱 adapter, metadata 정규화, IPC queue·취소·재연결 | metadata만 열거, 필요 face만 읽기, source별 weight/slant, 충돌 제외, busy/stale·늦은 응답·API 부재 검증. 제품 pin 유지 | `Task #567 [Stage 3.1]: Studio 공개 API용 글꼴 어댑터 준비` |
| 3.2 | 정식 릴리즈 반영 후 adapter를 제품 Studio에 연결 | core/Studio provenance 일치, 실제 이름·Regular/Bold·bytes hash, HWP/HWPX 표시·편집·저장, alias 미유출 | `Task #567 [Stage 3.2]: 정식 Studio 글꼴 API 연결` |
| 3.3 | 호스트 family를 기존 글꼴 메뉴 전체/시스템 범주에 연결하고 별도 팝업 제거 | 기존 편집 명령으로 선택/커서 글꼴 적용, 중복·갱신·저장, adapter provenance와 실제 화면 | `Task #567 [Stage 3.3]: 기존 글꼴 목록에 로컬 글꼴 통합` |
| 4 | 설치/관리 변경 전파, Typeface·측정·실패 캐시 갱신, 자동 준비와 설정 안내 | 열린 문서에서 삭제·비활성·갱신·권한 상실·설정 변경·복구, 빠른 문서 전환, 실제 UI 확인 | `Task #567 Stage 4: 글꼴 변경 반영과 자동 사용 흐름 구현` |
| 4.1 | 기본 설정을 사용 여부·개수·재감지로 간소화, 상세 접기·가져오기 직접 진입, 시작 비용 조사 | 실제 설정/가져오기 화면과 권한 안내, 서비스 준비/탐색/bytes 횟수·실측, 기존 제품 회귀 | `Task #567 [Stage 4.1]: 글꼴 설정 간소화와 시작 탐색 비용 조사` |
| 4.2 | Studio 환경설정에서 native 글꼴 설정 진입, Mac 안내/버튼 통일, 시작과 최초 활성화 탐색 병합 | 실제 설정 탭·가져오기 진입/문서 상태 보존, 정상 시작 1회·변경/권한 복구 유지, 동일 조건 비용 재측정·화면 | `Task #567 [Stage 4.2]: 글꼴 설정 진입 통일과 최초 탐색 병합` |
| 5 | 실제 문서 수용·signed sandbox 재실행·성능 회귀 및 #568/#569 인계 | 새 프로세스·cold/warm 읽기 수·동시 병합, 저장/재열기, 원본 부재/관리 복사본 대조, 관련 빌드·테스트 | `Task #567 Stage 5: Studio 글꼴 통합 검증과 소비자 인계` |

각 단계는 해당 소스와 단계 보고서를 함께 커밋하고 승인을 받은 후 다음 단계로 진행한다. Stage 3.1/3.2/3.3은 Stage 3의 하위 단계로 추적하며 Stage 4/5의 수용 범위를 줄이지 않는다. upstream 확장은 병합되었으며 정식 릴리즈 pin/sync는 Stage 3.2의 선행 조건이다. 외부 저장소 게시·PR 생성·pin 변경은 확정 범위의 승인 뒤 진행하며 minified 산출물 직접 편집으로 우회하지 않는다.

### Stage 3.3 확정 범위 — 2026-10-07

- 사용자의 기존 글꼴 목록 통합 지시를 승인으로 기록한다. 기존 #567 브랜치에서 진행하며 Stage 4/5, OS 지속 설치·배포는 포함하지 않는다.
- 앱 소유 Vite 변환으로 공개 provider의 family 목록을 기존 `getLocalFonts()` UI 소비자에 연결한다. renderer 매칭·바이트 공급·편집 엔진은 유지하고 upstream checkout 및 minified 번들은 직접 수정하지 않는다.
- 기존 글꼴 메뉴의 전체/시스템 범주와 글자 모양 등 같은 목록 소비자를 일관되게 연결한다. 호스트 provider가 활성일 때는 공급 가능한 family만 반환하고, 해제 시 기존 브라우저 경로로 돌아간다.
- host 세대 변경은 열린 메뉴의 이전 목록을 폐기하고 새 snapshot 완료 후 갱신한다. 선택한 문서 이름·범위는 기존 toolbar 명령으로 보존한다.
- 별도 선택 창과 확장 명령/메뉴를 제거한다. 빌드 helper·변환 fingerprint·sync/CI에 같은 경로를 기록해 다음 upstream sync에서도 기능이 보존되게 한다. upstream 소스 형태가 달라지면 빌드를 실패시킨다.
- 실제 WKWebView의 기존 메뉴에서 선택·새 글자 입력·저장/재열기와 CanvasKit repaint를 확인하고 스크린샷·직접 조작 창을 제공한다.

### Stage 4 확정 범위 — 2026-10-07

- 사용자 테스트 후 “다음을 진행해줘” 지시를 승인으로 기록한다. 기존 false 기본값·사용자 설정을 보존하며 Stage 5·OS 지속 설치·배포는 포함하지 않는다.
- 보관함 UI와 Studio의 관리 서비스/변경 스트림을 공유한다. 격리 저장소도 같은 native 공급·observer 경로로 검증할 수 있게 주입 경계를 일치시킨다.
- 최초 준비를 공유하고 재실행 시 저장된 권한·활성 설정을 다시 검사한다. 수동 새로고침은 이전 읽기 실패를 재시도하며 앱 활성화·CoreText 알림은 debounce 갱신을 사용한다. 알림 없는 파일 변경에 즉시 반응한다고 보장하지 않는다.
- 기존 renderer의 generation·리소스/측정/실패 캐시 갱신을 실제 Canvas2D/CanvasKit에서 검증한다. 사용 끄기/켜기, 설치 후보 제거·권한 실패/복구·같은 이름 다른 bytes, 관리 가져오기/제거, 빠른 문서 전환 뒤 stale 응답과 dirty/문서 이름 보존을 확인한다.
- 설치 사용 toggle을 쉽게 찾을 수 있게 표시하고 ‘준비 중’ 안내를 지원되는 화면 표시·편집 및 기존 목록 선택에 맞게 수정한다. 인쇄/PDF/Finder 지원을 주장하지 않는다.
- native 상태 전이 회귀와 실제 WKWebView, 격리 새 프로세스 재실행·설정 창 screenshot/직접 조작으로 증거를 남긴다. 실제 OS 설치·signed sandbox 권한 복원은 Stage 5 수용과 구분한다.

### Stage 4.1 확정 범위 — 2026-10-08

- “그렇게 진행하고 싶어” 지시를 설정 간소화 제안의 승인으로 기록한다. 기존 #567 브랜치·공급 계약을 유지하고 Stage 5·서명 sandbox·OS 설치·배포는 포함하지 않는다.
- 기존 toolbar 선택은 유지한다. 설정 기본 화면은 사용 설정·감지 개수·다시 감지 중심으로 구성하고 설치 상세 목록은 접어 둔다. 저장된 권한 문제와 해당 글꼴 접근 복구 경로는 보존한다.
- 설정에 보관한 글꼴 요약/상세와 가져오기 버튼을 직접 배치하여 보관함 sheet를 거치지 않고 한 번의 가져오기 sheet를 연다. 원본 참조와 복사 보관의 차이 및 화면 적용/출력 제한을 일관되게 안내한다.
- 실제 시작 호출·활성화·문서 snapshot·수동 갱신과 native bytes 경로를 추적하고 실제 CoreText 목록의 시간·호출 횟수·bytes 요청 수를 격리 저장소에서 측정한다. 기존 시작/사용 기본값 정책은 이번 조사에서 변경하지 않는다.
- 새 프로세스와 같은 프로세스 준비 공유를 구분하고, 폰트 서버의 OS cold 상태나 앱 전체 시작 시간을 측정했다고 주장하지 않는다. 설치 상태 변화·권한 검사를 생략한 영구 캐시로 우회하지 않는다.
- HostApp build·글꼴 회귀·실제 WK 변경 및 lifecycle smoke와 실제 설정/상세/가져오기 screenshot·직접 조작 창을 제공한다. 발견한 성능 위험과 후속 권고를 단계 보고에 남긴다.

### Stage 4.2 확정 범위 — 2026-10-08

- “그렇게 진행해줘” 지시를 직전 제안의 승인으로 기록한다. 기존 열린 #567 / M020 / local/task567에서 진행하며 Stage 5·OS 설치·서명·배포는 포함하지 않는다.
- 앱 소유 Studio 빌드 어댑터로 환경설정의 로컬 글꼴 영역을 Mac 안내와 “글꼴 설정 열기…” 버튼으로 바꾼다. native bridge가 없는 환경에서는 upstream 브라우저 동작을 유지한다. 최근/대표 글꼴과 파일 탭은 보존한다.
- 신뢰한 main frame의 새 비편집 native 명령만 허용하고, 제품 Settings Scene의 글꼴 탭을 선택하여 연다. macOS 14+ 공개 openSettings와 기존 지원 OS 경로를 분리한다. 격리 probe도 동일 native 진입점을 거쳐 실제 설정·가져오기 창을 확인한다.
- 최초 활성화가 시작 준비와 겹치거나 준비 직후인 경우만 같은 metadata 검사로 충족한다. 백그라운드 시작 뒤 늦은 최초 활성화, 이후 활성화, CoreText 변경, 권한 실패 복구, 수동 재감지는 보존한다. 사용 꺼짐의 지연 준비·영구 캐시 정책은 변경하지 않는다.
- 회귀와 실제 WK/설정 진입·스크린샷, HostApp 빌드, 어댑터/공식 checkout provenance를 확인한다. 이전과 같은 실제 CoreText probe 5개 새 프로세스에서 scan/bytes 횟수와 시간을 측정하되 전체 앱 launch/OS cold 성능으로 일반화하지 않는다.

### Stage 3.1 구현 경계

- 같은 page realm에서 공개 `fonts.setProvider/getState`만 소비한다. provider는 `getSnapshot/readFace/subscribe`를 구현하며 upstream matcher·renderer를 복제하지 않는다.
- native `postScriptName`을 `postscriptName`으로 변환한다. 빈 필수 이름·빈 alias 및 미지원/모호한 face를 검증하고 설치 CoreText traits와 관리 OS/2 traits를 각각 정규화한다. metadata로 증명되지 않는 weight/slant를 정확한 스타일로 주장하지 않는다.
- 관리 선택 우선순위·미해결 충돌 차단을 목록 구성에서 처리한다. 새 API는 브라우저/호스트 목록의 우선순위를 자동 병합하지 않는다.
- native 두 transfer slot에 맞는 제한 queue와 busy/stale 재시도·일시 오류 복구를 구현한다. 실패가 upstream 동일 세대 실패 캐시에 영구 고착되지 않게 복구 동작을 검증한다.
- documentEpoch/loadToken 변경 시 handshake를 갱신하고 이전 작업을 폐기한다. AbortSignal, close/cancel, 구독 해제, bytes/lease 수명을 검증한다.
- API 없는 v0.8.6에서는 연결 성공으로 표시하지 않는다. 제품 번들·pin·현재 준비 중 UI를 유지하며 계약 mock과 격리 시험으로 준비 범위만 검증한다.
- host 목록은 toolbar에 자동 추가되지 않는다. 기존 문서 표시와 글꼴 메뉴 선택을 별도 완료 항목으로 두고 Stage 3.2에서 실제 메뉴 연결 경로를 확인한다. 내부 렌더 별칭을 메뉴/저장 값에 사용하지 않는다.

### Stage 3.2 확정 범위 — 2026-10-07

- v0.8.7의 resolved commit과 #7405 포함·최종 API를 확인하고 stable core pin, bridge/FFI 산출물, build info 및 producer golden을 정식 절차로 갱신한다.
- 태그 helper의 반복 shallow fetch가 큰 원격 pack 준비에서 지연되어, 동일 원격 태그 commit과 core source/lock 무변경을 검증한 기존 checkout 재사용 옵션을 추가한다. 원래 원격 조회 경로와 임시 checkout 정리는 유지한다.
- 같은 commit의 fresh WASM·Studio를 빌드·sync하고 manifest/Cargo provenance·정적 자원을 검증한다. 임시 source patch는 넣지 않는다.
- Studio sync의 checkout 판정은 `.git` 디렉터리 유무 대신 Git 검증을 사용하여 정상 detached worktree도 수용한다.
- 앱 소유 user script에서 공개 API 준비 시 provider를 연결한다. 문서 epoch 교체 후 native begin/adapter refresh, navigation·종료·실패에서 dispose/reset을 연결한다.
- 실제 Studio main/Canvas2D/CanvasKit에 승인된 고운바탕 static Regular/Bold를 공급하여 이름·선택 face·bytes·화면 및 저장 이름을 검증한다. 실제 OS 설치가 필요한 수용은 기존 별도 승인 경계를 유지한다.
- 글꼴 메뉴는 정식 API/확장점을 조사하여 실제 제공 범위를 확인한다. 공개 진입점으로 해결할 수 없는 경우 산출물 직접 패치를 하지 않고 잔여 의존을 기록한다.
- 공개 automation extension command/menu와 `applyCharPropsToRange`로 앱 소유 선택 창을 연결했다. 검색·family 중복 제거·원래 이름 저장·문서/권한/목록 변경 시 적용 차단을 구현했고, 실제 v0.8.7 Studio에서 표시·적용·저장·재열기를 통과했다. [Stage 3.2 결과](../working/task_m020_567_stage3.md#stage-32-완료--2026-10-07).
- 제품 전체 수용·설정 안내 수정과 signed sandbox 회귀는 Stage 4/5, 출력·Finder는 #568에 남긴다. 이 단계는 알한글 공개 배포 승인이 아니다.

## 4. 다운로드한 테스트 글꼴

사용자 지시에 따라 Google Fonts 공식 저장소에서 **고운바탕(Gowun Batang) Regular/Bold, Version 2.000**을 확보했다. 한글 완성형 11,172자 cmap 매핑을 각 파일에서 확인했다. static TTF이며 fvar 테이블은 없다. 이는 파일 검사 결과이며 실제 renderer의 전체 글리프 표시 검증은 아직 아니다.

- 배포 위치: https://github.com/google/fonts/tree/c1eda9233c33ad7775b27efd794f931095cf6133/ofl/gowunbatang
- 배포 커밋: `c1eda9233c33ad7775b27efd794f931095cf6133`
- 제작자 저장소: https://github.com/yangheeryu/Gowun-Batang
- 배포 metadata의 제작자 commit: `4e73f5a9a004927220354f4b68a4c720da538147`
- 라이선스: SIL Open Font License 1.1. 다운로드 파일 옆 `OFL.txt`의 원문·저작권 표시를 유지한다.
- 로컬: `build.noindex/task567/fonts/gowun-batang/`
- 동봉 기록: `METADATA.pb`, `provenance.json`(URL·커밋·크기·SHA256), `inspection.json`(이름·버전·굵기·한글 범위)
- 재현 다운로드 URL: `https://raw.githubusercontent.com/google/fonts/c1eda9233c33ad7775b27efd794f931095cf6133/ofl/gowunbatang/{파일명}`

| 파일 | bytes | SHA256 |
|------|------:|--------|
| GowunBatang-Regular.ttf | 8433296 | `466c593e7147412e748af4856d5ad14709b5a860bdf62b9c2546f2c5874e9849` |
| GowunBatang-Bold.ttf | 8178712 | `dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94` |
| OFL.txt | 4397 | `49a57cc769fa9affd6eefb9070a61e3d3f6b757c97cafb15848bc6d1c81acc78` |
| METADATA.pb | 1307 | `5ab6c5630b85b7d20e8cec7a3be246f9cd5a8f247dea4993f6fb9cf1cc24478e` |

OS 지속 설치는 아직 하지 않았다. 초기에는 별도 파일 공급/관리 복사본과 격리 프로세스 등록으로 검증한다. 실제 OS 설치 수용 시 같은 PS 이름의 기존 설치 여부를 확인하고 기존 파일을 덮어쓰지 않는다. 새 설치 위치와 정리 범위를 제시한 뒤 테스트용 두 파일만 설치·제거한다. 시스템/앱 번들에 이미 같은 face가 있으면 미설치 대조군으로 사용할 수 없으므로 별도 검증 환경을 선택한다.

## 5. 검증 기준과 증거

- 이름/스타일 요청, 선택 출처·ID·PS, 실제 bytes hash, renderer별 적용 결과를 묶어서 기록한다. 실제 사용자 경로·문서 내용은 진단 로그에 포함하지 않는다.
- 고운바탕은 한글 표시·스타일 비교에, 자체 작은 fixture는 충돌·손상·권한·세대 경계 검증에 사용한다. 테스트용 파일의 라이선스를 다른 설치 글꼴로 일반화하지 않는다.
- 관리 복사본 원본 삭제 후 유지, 설치 원본 부재 시 fallback, 공급 자산이 없는 대조군을 구분한다. OS 폰트 fallback이 native 연결 실패를 가리지 않게 정확한 선택 증거를 확인한다.
- 편집·글꼴 선택·저장·재열기에서 문서 원래 이름과 굵기를 대조한다. HWP/HWPX 각각 실제 지원 저장 경로를 확인하고 미지원 경로는 성공으로 집계하지 않는다.
- 변경 유형별 `build_run_guide.md` 최소 검증을 적용한다. 기본은 HostApp 빌드, `scripts/test-font-library.sh`, 영향받은 HostApp/Studio 회귀 및 lifecycle smoke다. upstream 변경 시 해당 소스 테스트와 provenance·Studio 산출물 검증을 추가한다.
- signed sandbox에서 정상 권한 재실행과 권한 복구를 확인한다. 이전 probe 승인 폴더를 새 다운로드 폴더의 승인으로 간주하지 않는다.
- 앱 산출물은 `build.noindex/` 아래에 둔다. Quick Look/Thumbnail 개발 등록은 표준 smoke 안에서만 수행하고 끝나면 정리한다.
- macOS 12 target 컴파일과 실제 최소 OS 실행은 구분해 보고한다. 출력 소비자·Windows ZIP·웹 안내는 이 이슈 완료로 주장하지 않는다.

## 6. 승인 요청

Stage 1 계약과 Stage 2 native 공급 구현·검증을 완료했다. 2026-09-26 지시에 따라 Stage 3.1은 정식 릴리즈 전에 준비하고, Stage 3.2에서 확정 릴리즈 pin/sync 및 실제 제품 연결을 수행한다. [Stage 2 보고](../working/task_m020_567_stage2.md)와 [이슈 재정렬 검토](../tech/task_m020_567_replan.md)를 참고한다. 이번 보정은 이슈 완료나 릴리즈 승인이 아니다.
