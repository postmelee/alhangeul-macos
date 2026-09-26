# Task #567 Stage 3 — Studio 공개 글꼴 API 연결

## Stage 3.1 완료 — 2026-09-26

사용자가 기존 이슈의 진행 순서·완료 기준 보정과 작업 진행을 승인했다. #562/#566/#567/#568/#569의 기존 본문을 보존하면서 최신 실행 순서와 완료 기준을 추가하고 원격 본문 일치를 재조회했다. 이슈 상태·마일스톤은 유지했다. [재정렬 근거](../tech/task_m020_567_replan.md).

`StudioFontProviderScript`에 공개 `getSnapshot/readFace/subscribe` 계약을 구현했다. 제품 pin/bundle을 바꾸거나 현재 WebView에 주입하지 않았으며, API 부재 시 native 조회 없이 unsupported로 끝난다. 별도 임시 core fork·minified 패치는 없다.

### 구현 결과

- metadata 페이지 조회와 bytes 읽기를 분리했다. native source별 PS 이름·weight/slant 변환, 빈 이름/alias, 미지원·중복 ID·관리 충돌 및 선택 우선순위를 처리한다.
- 글꼴 파일은 native가 확인한 ID로만 요청한다. JS에는 원본 경로·bookmark를 전달하지 않는다. 실제 openFace의 PS/weight와 목록이 다르면 bytes를 게시하지 않는다.
- 2개 동시 transfer/64개 대기열, 256 KiB chunk, 64 MiB face 제한을 적용했다. 다른 창과 공유하는 앱 전체 2개 한도는 native가 유지한다.
- 제한된 busy 재시도, catalog stale 시 handshake 재시작, 일시 실패 캐시의 1회 세대 갱신을 구현했다. 이전 session/revision과 문서 token의 결과를 폐기한다.
- 취소·구독 해제·provider detach 및 늦게 발급된 transfer의 close를 처리한다. 문서 교체의 `refresh`, 종료의 `dispose`와 native reset 호출은 Stage 3.2 coordinator 연결 책임으로 명시했다.
- 실제 Swift raw string을 실행하는 Node 계약 테스트를 기존 font 테스트 스크립트와 CI에 추가했다. 별도 WebKit probe도 macOS CI에서 실행하도록 연결했다. Xcode 프로젝트는 `xcodegen generate`로 갱신했다.

### 검증

| 검증 | 결과 | 실행 범위 |
|---|---|---|
| `node --test scripts/ci/test-studio-font-provider.cjs` | 20 PASS | metadata-only/페이지·출처별 style/우선순위·충돌/queue 한도/busy·stale/취소·늦은 응답/bytes·세대·구독/API 부재 |
| `scripts/test-font-library.sh` | JS 20 PASS + XCTest 100 PASS | 기존 관리·설치 service·native 공급 회귀, 새 Swift 소스 컴파일 |
| `bash scripts/probe-studio-font-provider.sh` | PASS | 실제 WKWebView custom origin → 응답형 handler → 기존 native session → 새 JS adapter, fixture 1,124 bytes 전체 일치·faceIndex 0 |
| HostApp Debug `xcodebuild`, `CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED | 기존 고정 core/Studio 사용, macOS 12 target |
| `scripts/check-no-appkit.sh` | PASS | 공통 Swift 계층의 AppKit/UIKit 금지 유지 |
| `git diff --check`·문서 상대 링크 검사 | PASS | 변경 문서·소스 형식·링크 |

로그: `build.noindex/task567/stage3-1/{adapter-tests,font-tests,webkit-probe,host-build}.log`. 별도 probe 코드는 `Tests/StudioFontProviderProbe/main.swift`, 실행/재현 도구는 `scripts/probe-studio-font-provider.sh`다. fixture는 저장소의 공개 시험용 `Tests/FontLibraryTests/Fixtures/regular.ttf`이며 사용자 설치 글꼴·문서는 사용하지 않았다.

이전 upstream 검증 보고·재현 자료도 함께 보존했다. 원시 `probe-build.log`에 도구가 출력한 trailing space 한 곳은 증적 해시 유지를 위해 수정하지 않고 해당 파일만 `.gitattributes`의 whitespace 검사에서 제외했다. 코드·문서의 공백 검사는 유지하며 증적 47개 SHA-256을 대조했다.

초기 제한 환경 빌드는 Sparkle 다운로드의 DNS 제한으로 실패하여 승인된 권한으로 재실행했다. 처음 WebKit 검증을 XCTest에 넣었을 때에는 byte 테스트에 도달하기 전 xctest의 NSApplication 중복 생성(SIGTRAP)으로 종료되었고 단독 실행도 같았다. 해당 UI 테스트를 일반 XCTest에서 제거하고 정상 NSApplication 초기화를 하는 독립 probe로 분리했다. probe의 누락된 컴파일 입력과 throwing 호출을 수정한 후 위 최종 실행이 통과했다. 실패를 통과로 집계하지 않는다.

Xcode가 자동 등록한 이번 개발용 HostApp 경로는 `lsregister -u`로 해제했다. probe는 종료 trap에서 자기 경로를 해제한다. Quick Look/Thumbnail 개발 등록·OS 글꼴 설치·사용자 권한 변경은 수행하지 않았다.

### 한계와 다음 단계

이 단계는 어댑터 준비 완료이며 **#567 전체 완료나 현재 제품의 글꼴 적용 지원이 아니다.** probe의 Studio API는 공개 계약을 따르는 작은 mock이고 실제 native handler/session과 WebKit transport를 사용한다. upstream main/renderer/toolbar와의 제품 연결은 아직 하지 않았다. 이전 #7405의 29개 검증은 이전 head의 별도 증거로 보존한다.

알 수 없는 installed style은 보수적으로 제외하고 실제 읽은 weight/PS가 목록과 다른 경우 실패 처리한다. 모든 지역화된 글꼴 스타일·TTC·가변 지원을 주장하지 않는다. 화면 변경이 없어 새 제품 스크린샷은 없다. 실제 최소 OS 실행·signed sandbox·OS 권한 복원·다중 창 전체 수용·실문서 편집/저장·PDF/인쇄/Finder 확장은 미검증이다.

Stage 3.2는 API가 포함된 정식 릴리즈와 해당 단계 승인 후 진행한다. 기존 sync PR 여부를 확인해 core/Studio provenance·ABI·자산을 갱신하고, coordinator의 API 준비 시점·문서 token 교체·dispose를 연결한다. 실제 renderer 및 편집 글꼴 메뉴를 각각 검증한 뒤 Stage 4/5로 진행한다. 현재 제품 v0.8.6 pin과 준비 중 안내는 유지했다.
