# Studio native 글꼴 adapter 계약 — #567 Stage 1

이 문서는 구현할 계약이다. 현재 제품 연결 완료를 의미하지 않는다. 기준은 core/Studio `v0.8.6`, commit `f1f9c6ae58344ee9368996d3543f76b9345cf227`이며 [구현계획](../plans/task_m020_567_impl.md)을 따른다.

## 소스 추적과 변경 필요성

아래 upstream 경로는 고정 commit의 `rhwp-studio/src/` 기준이다.

| 경로·위치 | 현재 동작 | 필요한 변경 |
|-----------|-----------|-------------|
| `core/local-fonts.ts:264` | PS → full → family+style → 유일한 family/alias, family 여러 face이면 null | 기존 lookup 재사용, 문서 weight/slant를 받는 face 선택 추가 |
| `core/local-fonts.ts:381`, `:877` | 감지 시 각 FontData의 blob에서 SFNT 이름 보강 | native metadata 공급을 별도 진입점으로 분리, 열거 시 전체 bytes 금지 |
| `core/local-fonts.ts:949`, `:994` | 이름 기반 face key 및 PS 기반 bytes 조회 | source/ID/revision 포함 identity와 필요 bytes provider 추가 |
| `core/font-substitution.ts:371` | local face, 기존 치환·bundled·문서 대체 후보 구성 | 표시용 내부 alias만 주입하고 기존 fallback 규칙 재사용 |
| `view/canvaskit-renderer.ts:552` | 이름 목록만으로 prepare, 기존 성공/실패 face 건너뜀 | 실제 문서 run의 weight/slant 포함 준비, revision으로 성공·실패 객체 갱신 |
| `view/canvaskit-renderer.ts:711` | 문서 리소스 reset 시 local/bundled Typeface·실패·pending 정리 | 글꼴 revision 변경을 reset 경로와 연결 |
| `view/renderer-session.ts:124`, `view/canvas-view.ts:386` | 문서 revision과 리소스 무효화·선택 epoch 존재 | 글꼴 변경용 공개 조정 함수 추가, 늦은 선택 결과 폐기 |
| `main.ts:469`, `:1148` | 변경 이벤트는 detectedAt/source/count 비교 후 준비·재표시 | 같은 개수·이름의 bytes 변경도 revision으로 판정, 먼저 reset 후 재준비 |
| `view/page-renderer.ts:196` | 페이지 revision 무효화 진입점 | 글꼴 변경 후 페이지 요약·진단·재렌더 작업까지 갱신 |
| `core/wasm-bridge.ts:1102` | clearLayerResourceCache는 예약된 no-op | 이 호출만으로 측정·표시 캐시를 지웠다고 판단하지 않음 |
| `ui/toolbar.ts:272` | 선택 이름을 findOrCreateFontId/ForLang에 전달 | option 값은 원래 문서용 이름 유지, 표시 alias 입력 금지 |
| `core/wasm-bridge.ts:535`, `:577`, `main.ts:1993` | HWP/HWPX export가 문서 모델 직렬화로 연결 | 화면 공급과 분리, 두 export를 재열어 이름·굵기 확인 |

결론: native bridge만 추가하거나 queryLocalFonts/chrome.storage를 흉내 내는 것으로는 요구를 충족하지 못한다. upstream의 metadata provider·스타일 선택·revision 전달 및 renderer 무효화 확장이 필요하다. Stage 2 native 계층은 mock 소비자로 먼저 검증할 수 있지만 Stage 3 제품 연결은 정식 upstream 변경·고정 산출물 sync가 선행 조건이다. Rust layout 변경은 현재 범위로 확정하지 않으며 JS 연결로 해결되지 않는 경우 별도로 보고한다.

## 소유권과 API

- HostApp 전용 환경 객체가 설치 catalog의 지연 생성 Task를 한 번만 소유한다. 설정 모델과 문서 coordinator가 같은 인스턴스를 주입받는다. 초기 실패 시 재시도 가능하게 하고 MainActor에서 디스크 생성하지 않는다.
- 관리 복사본은 기존 FontLibraryService를 공유한다. 현재 서비스에는 updates 스트림이 없으므로 import/select/remove의 게시된 generation 변화를 알리는 구독 경로를 추가한다. 부분 성공 import도 최종 manifest 재조회로 변경을 알린다. 문서 시작/앱 재활성화 때도 최신 generation을 확인한다.
- 공급 revision은 설치 generation, enabled, 관리 snapshot generation/digest를 결합한 native 발급 opaque token이다. 요청 session 및 document load token과 함께 검증한다.
- upstream에는 native provider 설치, metadata snapshot 교체, `resolve(name, weight, slant)`, `readFace(resourceID, revision, signal)`, revision 변경 구독을 정식 API로 추가한다. 기존 브라우저 provider는 유지한다. 구체 함수 이름은 upstream 구현에서 조정할 수 있으나 native 계약은 바꾸지 않는다.
- catalog에는 source, opaque ID, PS/full/family/style, traits, 검증된 alias, 제한 상태만 전달한다. 원본 URL·bookmark·파일 stat는 native에 남긴다.
- 이름 메타데이터는 CoreText의 canonical/지역화 이름과 관리 자산의 기존 SFNT 메타데이터를 사용한다. 실제 읽은 face의 이름은 필요 bytes 검증 때 보강한다. 무조건 전체 원본을 읽어 모든 언어 이름을 확보하지 않는다. metadata로 해결되지 않는 이름은 unresolved로 보고하고 정확한 연결 증거가 없는 alias를 추정하지 않는다.

## 전송·제한·인증

Stage 2의 기준은 **응답형 메시지와 제한된 chunk 전송**이다. 기존 resource scheme은 정적 bundle 파일용이며 CORS `*`와 빈 stop 처리이므로 외부 글꼴 원본용으로 확장하지 않는다. custom scheme fetch의 origin 동작과 URL 노출에 의존하지 않고 모든 chunk 요청을 인증한다.

| 항목 | 계약 |
|------|------|
| 인증 | 등록된 전용 handler, 현재 WKWebView identity, main frame, 정확한 Studio origin 및 현재 문서 session/load token 모두 일치 |
| 준비 | main-frame handshake 후 version=1과 session 발급, navigation/종료/renderer process 종료 시 취소·폐기 |
| 요청 | catalog 페이지 조회, openFace, readChunk, closeFace, cancel; 임의 파일/URL/오프셋 범위 외 요청 거부 |
| 요청 크기 | 직렬화 4 KiB 이하, 이름/토큰 문자열 길이 각각 제한, 추가 필드/잘못된 타입 거부 |
| catalog | 페이지 최대 128개·직렬화 256 KiB, metadata 문자열 1 KiB 상한·alias 최대 32개; 초과 face는 잘라서 오매칭시키지 않고 제한 상태로 제외 |
| 목록 총량 | 설치 20,000개, 관리 기존 4,096 입력 제한과 별개로 소비자 활성 face도 최대 4,096개; 초과는 명시적 제한 오류 |
| 바이트 | 파일 최대 64 MiB, chunk raw 최대 256 KiB(base64 약 342 KiB), offset/length 정수 및 정확한 경계 확인 |
| 동시성 | 앱 전체 openFace 읽기/보관 최대 2개·128 MiB, 문서별 미완료 메시지 최대 8개, 무제한 대기열 없음 |
| 타임아웃 | transfer 마지막 활동 후 30초 해제, navigation/세대 교체 즉시 해제, 상대가 사라져도 lease/bytes 누수 없음 |
| 오류 | busy는 100/250/500ms 최대 3회 재시도 후 이번 적용 fallback, 손상·미지원 캐시에 영구 기록하지 않음 |

64 MiB 전체 base64 문자열을 만들지 않는다. native가 검증한 Data를 transfer 동안만 보관하고 chunk별 인코딩한다. JS 조립 버퍼와 renderer 복사 메모리는 native 128 MiB 한도에 포함되지 않으므로 별도 측정한다. 읽기 완료 및 마지막 chunk 응답 시에도 generation을 재검사한다. transfer 종료·실패·취소·세대 교체 모두 버퍼와 해당 lease를 해제한다.

보안 경계는 신뢰한 bundled Studio 문서다. 같은 문서에서 실행되는 임의 스크립트와 정상 Studio를 token만으로 구분할 수 있다고 주장하지 않는다. 하위 frame 및 외부 navigation은 요청을 허용하지 않는다.

## 매칭·표시·저장

1. 기존 이름 정규화와 exact PS/full/family+style lookup을 재사용한다. explicit PS/full은 다른 굵기의 sibling으로 조용히 바꾸지 않는다.
2. family만 요청하면 문서 run의 weight/slant로 정확한 static face를 고른다. weight 정보가 없는 family 다중 후보나 동명 동급 버전은 모호함으로 처리한다. 지원되지 않는 synthetic 굵기를 실제 Bold 선택으로 표시하지 않는다.
3. 동일 요청에 **활성 선택된 관리 복사본 → 사용 설정이 켜진 유일한 설치 face → 기존 rhwp fallback** 순서를 적용한다. 관리 미해결 충돌을 설치 face로 숨기지 않고 오류와 fallback을 표시한다. 명시 선택된 관리 face 읽기가 실패해도 다른 버전의 설치 face로 조용히 대체하지 않는다.
4. OS에 보이는 것만으로 bytes 사용 가능을 뜻하지 않는다. 적용 실패는 기존 fallback으로 이어지되 source/PS/hash 진단에서 실패를 드러낸다.
5. CSS에는 source/ID/revision 기반 내부 family를 사용해 동명 OS local() 선택을 피한다. 준비된 FontFace를 DOM FontFaceSet에 등록하고 CSS/SVG/Canvas2D 모두 같은 mapping을 사용한다. CanvasKit은 동일 bytes와 face key를 사용한다.
6. toolbar·문서 모델은 원래 family/선택 이름을 보존한다. renderer 내부 alias는 findOrCreateFontId나 export 입력으로 전달하지 않는다. UI 목록도 내부 ID를 문서 이름으로 사용하지 않는다.

## 변경과 캐시

revision 교체는 순서대로 처리한다: 이전 요청 취소 → provider revision 교체 → 기존 CSS FontFace 제거 및 mapping 폐기 → renderer resource/selection revision 무효화 → 기존 페이지 캐시/진단/재렌더 작업 무효화 → 필요한 face 재준비 → 최신 revision 확인 후 재표시.

Typeface와 실패·pending 캐시를 함께 버린다. 이름/count가 같아도 bytes 또는 선택 원본이 바뀌면 갱신한다. renderer 측정·glyph 객체의 key에는 revision과 face/style을 포함한다. 브라우저 측정은 FontFace 준비 후 다시 수행하며 Rust 문서 layout을 임의 재작성하지 않는다. renderer별 실제 측정 경로의 전체 검증은 Stage 3/4에서 수행한다.

글꼴 갱신은 표시 리소스 변경이므로 document-mutated/dirty 이벤트를 발생시키지 않고 저장되지 않은 사용자 편집을 보존한다. 전체 문서 재열기로 캐시 문제를 우회하지 않는다. 새 managed snapshot을 획득한 뒤 해당 문서 소비자를 전환하고 이전 transfer 종료 후 기존 snapshot을 해제한다. 다른 출력 작업이 보유한 lease에는 영향을 주지 않는다.

## 기본값과 수용 시나리오

이번 단계에서는 설치 글꼴 사용 기본값 false와 기존 사용자 선택을 보존하는 것으로 확정한다. 한 번 켜면 정상 권한에서 다음 실행부터 자동 적용한다. default=true 및 기존 설정 이관은 요청 없이 시행하지 않는다.

고운바탕 Regular/Bold는 Stage 2 격리 공급에 먼저 사용한다. 실제 Studio 수용은 다음 대조를 수행한다.

- HWP/HWPX 각각 한글·영문·숫자와 같은 family의 Regular/Bold run을 준비한다. canonical/한국어 alias는 파일/OS metadata에 실제 존재하는 이름만 사용한다.
- CSS/SVG/Canvas2D와 CanvasKit에서 요청 weight, 선택 PS, 다운로드 기록과 일치하는 bytes hash, 실제 적용 화면을 따로 기록한다. 단순 FontFace.load 또는 FontMgr 생성 성공만으로 판정하지 않는다.
- 글꼴 선택·편집·저장·재열기 후 내부 alias 미유출과 원래 이름/굵기를 확인한다. 지원 export와 실제 제품 저장 경로의 차이도 기록한다.
- 원본 부재, 관리 복사본만 존재, 둘 다 부재인 세 조건을 비교한다. 기존 OS 동명 face가 fallback으로 시험을 가리지 않는지 확인한다.
- 켜기/끄기, 같은 이름 다른 bytes, 삭제/비활성, 권한 실패/복구, 빠른 문서 전환, 여러 문서·동시 요청·재실행을 검증한다.
- OS 지속 설치는 별도 수용 시 수행한다. 현재 다운로드만 완료했으며 기존 글꼴 삭제·변경은 하지 않는다.

## 단계 경계

Stage 2는 native 전용 공유 환경·catalog/transfer bridge·관리 변경 구독·수명 테스트를 구현한다. 제품 Studio에 임시 shim을 주입하지 않는다. Stage 3 진입 전 upstream 변경 범위와 정식 pin/sync 대상을 승인받는다. 외부 PR 게시·core 변경·배포는 Stage 1 완료 승인에 포함시키지 않는다.


## Stage 2 구현 인계

`StudioFontMessageHandler`는 page content world의 `alhangeulFonts` 응답형 handler다. 모든 요청에 `version: 1`, `op`, 현재 `window.__alhangeulEditorLoad.token`의 `loadToken`을 넣는다. handshake 응답의 session/revision을 이후 요청에 넣는다. catalog는 offset(기본 0)을 받으며 nextOffset/total로 순회한다. openFace에는 catalog face ID를, readChunk/closeFace에는 openFace가 발급한 transfer ID를 넣는다. cancel은 진행 중 face ID 또는 이미 발급된 transfer ID를 받는다. offset/length는 정수이며 추가 필드·bool 정수는 거부한다.

최초 handshake에 공급 목록 준비가 필요하다. 준비 중 native generation이 변하면 staleSession을 반환할 수 있으므로 소비자는 최신 handshake부터 재시도한다. 설치/관리 변경 시 기존 세션을 폐기하고 `alhangeul-fonts-changed` DOM 이벤트를 알린다. 실제 소비자 구독과 busy/stale의 제한된 재시도는 Stage 3에서 구현한다. 제품에는 queryLocalFonts shim을 추가하지 않았다.

현재 설치 metadata의 weight는 nil이며 traits와 style을 공급한다. 실제 읽은 face의 정확한 weight·PS·SFNT index·SHA256은 openFace 응답에 포함한다. 관리 자산은 저장한 weight와 이름 aliases를 공급하며 미해결 충돌 face는 limitation=conflict로 표시한다. 설치 traits는 CoreText, 관리 traits는 OS/2 selectionFlags이므로 source와 함께 해석해야 한다. Stage 3의 공통 style 모델 정규화에서 둘을 같은 비트 집합으로 취급하지 않는다.

관리 snapshot lease는 문서 세션의 catalog가 소유한다. closeFace/만료는 transfer bytes와 앱 전체 slot을 해제하고, lease는 revision/문서 전환·종료에서 해제한다. 취소된 읽기는 실제 I/O 반환까지 slot을 유지해 취소 반복으로 앱 전체 읽기 한도를 우회하지 못한다. 해제 이후 진행 중 읽기는 정상 취소/실패로 끝나며 이전 bytes를 새 session에 게시하지 않는다.

현 구현은 native 공급 경계이며 실제 renderer 적용·캐시·최소 OS/signed sandbox 검증을 완료한 것은 아니다. [Stage 2 검증 보고](../working/task_m020_567_stage2.md)에 해당 범위와 증거를 구분했다.
