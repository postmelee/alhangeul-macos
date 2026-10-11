# Task #567 Stage 2 — Studio native 글꼴 공급 연결

## 단계 목적

설정과 문서가 단일 설치 catalog를 공유하고, 신뢰한 Studio 문서에서만 metadata와 필요한 글꼴 bytes를 요청하도록 연결한다. 작업지시자의 Stage 2 ‘진행해줘’ 승인 범위에서 구현했다.

## 산출물

- `InstalledFontServiceProvider.swift`: 동시 최초 생성 Task 공유, 생성 실패 후 재시도.
- `FontLibraryChanges.swift`, `FontLibraryService.swift`: 단일 관리 서비스, 실제 generation의 단조 증가 알림, 부분 import·선택·삭제 변경 구독.
- `StudioFontSupply.swift`: 설치/관리 snapshot DTO·필요 bytes·정확한 face 공급, 관리 충돌·metadata 한도 및 snapshot lease.
- `StudioFontSession.swift`: session/revision, catalog 페이지, 256 KiB chunk, 64 MiB 파일·앱 전체 2개 slot·문서별 8개 미완료 요청 제한, 취소·30초 만료.
- `StudioFontMessageHandler.swift`: 응답형 WK handler, main frame·origin·WebView·load token 검사, 설치/관리 변경 이벤트.
- HostApp/설정 모델/Studio WebView: 공유 서비스, navigation·문서 epoch 전환·fatal failure·view 해체 시 세션 정리.
- `StudioFontSessionTests.swift`: 새로운 9개 테스트. 기존 앱 기반 lifecycle smoke에 실제 WebKit handshake·chunk bytes 대조·잘못된 load token 거부 추가.
- `project.yml` 및 xcodegen 생성 프로젝트, 기존 글꼴 probe 스크립트 4개에 새 서비스 의존 연결.
- [계약 문서](../tech/task_m020_567_adapter.md): 실제 메시지 필드와 후속 소비자 책임 명시.

## 본문 변경 정도 / 무손실 여부

기존 core pin·Studio bundle은 수정하지 않았다. UI 문구·화면과 문서 저장 이름/렌더링은 변경하지 않았으며 시각적 변경이 없어 별도 스크린샷은 없다. 사용자 글꼴을 설치·제거하지 않았다. 다운로드한 고운바탕을 읽기 전용 테스트 입력으로 사용했다.

## 검증 결과

| 검증 | 결과 / 근거 |
|------|-------------|
| `scripts/test-font-library.sh` | 100개 통과, 기존 91 + 새 9. `build.noindex/task567/stage2-font-tests.log` |
| HostApp Debug build | 성공, macOS 12 target. `build.noindex/task567/stage2-host-build.log` |
| 실제 SwiftUI/Studio lifecycle smoke | 43항목 통과. HWP/HWPX 문서 수명 회귀와 실제 WebKit 전송. `build.noindex/task567/stage2-studio-lifecycle.log` |
| 고운바탕 데이터 전송 | Regular 8,433,296 bytes를 native FontFileInspector로 검사 후 chunk 전송·재조립하여 원본 Data와 동일함 확인. PS와 SHA256도 대조 |
| `scripts/verify-rhwp-studio-assets.sh` | 성공. bundle/pin 유지 |
| `scripts/check-no-appkit.sh` | 성공 |
| 변경 probe 스크립트 `bash -n`, `git diff --check` | 성공 |

새 단위 테스트는 정확한 bytes/hash, chunk 경계·다른 문서 transfer ID 거부, 잘못된 token·타입·추가 필드·과대 요청, 앱 전체 slot·만료, 세대 변경, 읽기 중 문서 전환 후 늦은 결과 폐기·slot/lease 해제, 신뢰 frame 정책, 부분 import/삭제 알림, 동시 catalog 생성 공유를 확인한다.

실제 WK 검증은 격리한 공급 snapshot을 주입하되 제품 Session/MessageHandler와 WebKit을 사용했다. 다운로드 파일이 없는 CI에서는 저장소 자체 regular.ttf로 같은 경로를 검증한다. 이번 로컬 결과는 로그의 `GowunBatang-Regular`로 구분한다. 이 검증은 signed 제품 sandbox에서 설치 원본을 자동 읽는 수용이나 renderer 적용을 대신하지 않는다.

중간 검증에서 actor 격리 기본 인자 컴파일 오류를 수정했다. 호스트 없는 XCTest에서 WKWebView를 생성하면 실행기가 종료되어 실제 WK 검증은 기존 앱 기반 smoke로 옮겼다. 수정 뒤 단위 테스트와 앱 smoke 모두 통과했다. XCTest의 최소 OS보다 최신 SDK 링크 경고와 AppIntents metadata 생략 경고는 기능 실패로 집계하지 않았다.

이번 task567 개발 앱과 내부 번들의 LaunchServices 등록 해제를 시도했고 앱 본체 해제는 성공했다. 등록되지 않은 helper는 -10814를 반환했다. 최종 `registration-hygiene/20260920-105122/`의 issues.txt와 dev-registered-apps.txt는 비어 있으며, 개발 산출물이 디스크에 남아 있다는 일반 경고만 있다. 기존 설치 앱과 사용자 확인용 UI probe는 변경하지 않았다.

## 잔여 위험

- 제품 Studio는 아직 이 provider를 소비하지 않는다. 실제 글꼴 매칭/표시 성공 및 캐시 무효화 완료로 주장하지 않는다.
- busy/stale 재시도, metadata weight/style 정규화, 한글 alias 보강과 CSS/CanvasKit 연결은 Stage 3의 upstream 확장 대상이다.
- 관리 서비스 오류는 안전한 unavailable 응답으로 끝난다. 소비자에서 오류 안내·fallback을 연결해야 한다.
- 최소 OS 실제 실행·signed sandbox 원본 접근·OS 지속 설치/삭제 수용은 후속 단계다.
- 실제 큰 파일 메모리 압박·다수 문서 공정성은 Stage 5에서 측정한다. native slot은 128 MiB까지 허용하지만 JS와 renderer 복사 메모리까지 그 한도로 제한되는 것은 아니다.

## 다음 단계 영향

Stage 3은 pinned upstream local-fonts API에 metadata provider·style-aware 선택·opaque identity/revision을 추가하고 CSS/CanvasKit 소비자를 연결한다. 정식 upstream 변경·pin/sync 범위를 먼저 구체화해야 한다. 임시 queryLocalFonts shim이나 minified bundle 직접 패치는 하지 않는다.

## 승인 요청

Stage 2 결과를 검토하고 Stage 3의 정식 upstream 확장·Studio 연결 작업 진행을 승인받는다. 외부 PR 게시 및 배포는 별도 승인 범위다.
