# Task #567 Stage 1 — Studio 글꼴 adapter와 캐시 계약 확정

## 단계 목적

승인된 구현계획의 첫 단계로 pinned Studio의 감지·매칭·렌더링·저장 경로를 조사하고 native 공급 경계를 확정했다. 구현계획 승인은 2026-09-20 작업지시자의 ‘진행해줘’로 확인했다.

## 산출물

- [adapter 계약](../tech/task_m020_567_adapter.md): 소스 근거, 공유 service 소유권, 응답형 메시지·chunk 제한, 매칭 우선순위, revision 무효화, 고운바탕 실제 문서 수용 시나리오.
- [수행계획](../plans/task_m020_567.md), [구현계획](../plans/task_m020_567_impl.md): 승인 상태와 Stage 3 upstream 선행 조건 반영.
- [오늘할일](../orders/20260920.md): Stage 1 완료 및 Stage 2 승인 대기.

## 본문 변경 정도 / 무손실 여부

제품 소스·upstream checkout·core lock·Studio bundle은 변경하지 않았다. 기존 계획의 범위를 유지하며 상태만 갱신했다. 무료 글꼴은 다운로드 폴더에 유지했고 OS에 설치하지 않았다. 화면 변경이 없어 새 스크린샷은 없다.

## 판단과 확정 사항

- 현재 name-only resolver로는 family+Regular/Bold를 정확히 선택할 수 없다. 기존 lookup을 확장해 run의 weight/slant를 함께 받아야 한다.
- 감지 시 blob 이름 보강을 수행하므로 queryLocalFonts shim은 제품의 필요 bytes 공급 계약을 대신하지 못한다.
- 기존 local-fonts-changed는 같은 개수·이름의 원본 교체를 안정적으로 식별하지 못하고 기존 Typeface/실패 캐시를 먼저 지우지 않는다. 공급 revision과 전체 표시 리소스 갱신 경로가 필요하다.
- native bridge는 main frame·origin·session을 확인한 응답형 메시지로 연결한다. 256 KiB raw chunk, 최대 64 MiB 파일, 앱 전체 최대 2개 transfer를 기준으로 구현한다.
- 명시 선택한 관리 복사본을 설치 참조보다 우선하고 미해결 충돌이나 원본 오류를 다른 버전 자동 선택으로 숨기지 않는다. renderer 내부 alias는 저장 이름과 분리한다.
- 사용 설정의 기본값 false와 기존 사용자 선택은 유지한다. 켠 상태의 재실행 자동 적용을 구현한다.
- upstream Studio 정식 확장이 필요하다. Stage 2 native 공급은 독립 구현·검증 가능하며 Stage 3 전에 정식 upstream 변경과 pin/sync 승인이 필요하다. 외부 게시나 pin 변경은 하지 않았다.

## 검증 결과

로그: `build.noindex/task567/stage1/verification.log`.

- 고정 소스의 관련 함수·호출 표식 13개 확인: 통과.
- 고운바탕 Regular/Bold, OFL, METADATA 4개 파일의 기록된 크기·SHA256 재검증: 통과.
- Studio manifest 고정 commit 확인 1개: 통과.
- 총 18개 정적 근거/파일 검증 통과. 이는 런타임 기능 테스트 수가 아니다.
- `git diff --check`: 통과. 문서 변경만 있으므로 앱 빌드와 제품 회귀는 실행하지 않았다.

존재하지 않는 추정 파일명(document.ts/text-measurer.ts/canvas-font.ts) 조회는 실제 파일 탐색으로 바로잡았다. 실제 저장 경로는 wasm-bridge.ts와 toolbar.ts, 캐시 경계는 renderer-session/page-renderer/canvaskit-renderer에서 확인했다. clearLayerResourceCache는 현재 no-op임을 별도로 기록했다.

## 잔여 위험

upstream API는 아직 구현되지 않았다. chunk 전송의 실제 메모리·성능, renderer별 측정 및 CSS/SVG 적용, signed sandbox 접근, 실제 저장·재열기는 Stage 2~5 검증 항목이다. 계약 수치가 실제 검증에서 부족하면 변경 근거를 보고하고 수정한다. OS 지속 설치·최소 OS 실행도 아직 수행하지 않았다.

## 다음 단계 영향

Stage 2는 공유 서비스 환경, metadata/transfer bridge, 관리 자산 변경 알림, session·lease·취소·요청 제한 테스트를 구현한다. 제품 Studio 연결 완료나 문서 적용 성공으로 표시하지 않는다. Stage 3 upstream 변경은 분리된 승인 범위로 제시한다.

## 승인 요청

위 계약을 기준으로 Stage 2 native 공급 구현에 진입할 승인을 요청한다. 단계별 승인 규칙에 따라 이번 작업은 Stage 1 문서와 근거 검증까지 수행했다.
