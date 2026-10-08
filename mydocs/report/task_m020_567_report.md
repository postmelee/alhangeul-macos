# Task M020 #567 — v0.8.7 반영과 설치·가져오기 글꼴의 Studio 연결

## 1. 작업 요약

- 이슈: [#567 설치·가져오기 글꼴의 Studio 적용 및 기존 매칭 연동](https://github.com/postmelee/alhangeul-macos/issues/567), 상위 #562
- 마일스톤: M020 — 글꼴 마이그레이션 / v0.2, PR base `devel`, 작업 `local/task567`
- 수행: 기본 5단계, Stage 3.1/3.2/3.3·4.1/4.2를 포함한 9개 단계 커밋. 최종 보고·PR 게시 승인: 2026-10-08 “진행해줘”.

Mac 설치 글꼴 사용 설정을 켜면 문서를 열 때 필요한 글꼴만 읽어 Studio 표시·편집에 사용한다. 로컬 글꼴은 상단 기존 글꼴 목록에서 선택하며, 정상 권한에서는 재실행 후 별도 감지·가져오기 없이 적용된다. 설정은 Studio 환경설정의 ‘Mac 글꼴 → 글꼴 설정 열기…’ 또는 앱 설정의 글꼴 탭으로 진입한다. 별도로 가져온 독립 복사본은 같은 설정의 ‘글꼴 가져오기…’에서 관리한다. 사용 기본값 false와 기존 사용자 선택은 보존했다.

공식 upstream `v0.8.7` / `1a76570e833917d15817415a53c09ad61ab3203f`의 host-font API를 사용한다. core·native archive·WASM·Studio provenance를 갱신했고, 앱 소유 source adapter로 기존 toolbar와 Mac 환경설정을 연결했다. minified 산출물을 직접 수정하거나 browser Local Font Access shim을 제품 API로 사용하지 않는다.

## 2. 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/InstalledFontServiceProvider.swift`, `InstalledFontCatalogService.swift`, `FontLibraryService.swift`, `FontLibraryChanges.swift` | 설정/모든 문서의 단일 service, 설치·관리 변경 구독, 초기 준비와 첫 활성화의 중복 탐색 병합 |
| `Sources/HostApp/Services/StudioFontSupply.swift`, `StudioFontSession.swift`, `StudioFontMessageHandler.swift`, `StudioFontProviderScript.swift` | metadata·opaque ID·revision/session 기반 필요 bytes 공급, chunk/동시 한도·취소·stale/busy 처리, snapshot lease와 공개 API 연결 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift`, `Sources/HostApp/HostApp.swift`, `Services/RhwpStudioHostBridgeScript.swift` | 문서/탐색 수명별 연결·정리·캐시 갱신, main frame native 설정 명령, 앱 시작·활성화 공유 |
| `Sources/HostApp/Services/AppSettingsNavigation.swift`, `Views/AppSettingsOpener.swift`, `AppSettingsView.swift`, `InstalledFontSettings*`, `FontLibrarySettings*` | 실제 Settings Scene의 글꼴 탭 진입, 설치 상세 접기·검색·권한 복구, 가져오기 직접 진입·지원 범위 안내 |
| `scripts/studio-font-menu-adapter.mjs`, `build-rhwp-studio.mjs`, `sync-rhwp-studio.sh`, `verify-rhwp-studio-assets.sh`, bundled `rhwp-studio/` | upstream matcher/편집 명령을 재사용해 전체/시스템 글꼴 목록 연결, source 변환·typecheck·receipt/hash 검증 |
| `rhwp-core.lock`, `RustBridge/Cargo.*`, `RhwpCoreBuildInfo.swift`, `scripts/update-rhwp-core.sh`, producer golden 및 README | 공식 v0.8.7 pin/산출물·build info 갱신, 검증된 동일 checkout 재사용. FFI header hash/size는 이전과 동일 |
| `Tests/FontLibraryTests/`, `StudioFontIntegrationProbe/`, `StudioFontSettingsProbe/`, `StudioFontAcceptanceProbe/`, `InstalledFontStartupProbe/`, 관련 `scripts/`·`project.yml`·생성 Xcode project | native/JS 보안·수명, 실제 renderer·선택·입력·저장·변경·설정·sandbox 재실행·계측 및 재현 도구 |
| `mydocs/plans/`, `working/task_m020_567_stage*.md`, `working/assets/task_m020_567*/`, `tech/task_m020_567*`, `tech/font_library_integration.md`, `orders/` | 승인 이력·계약·검증 증거·지원 제한·후속 소비자 인계 |

PDF·인쇄·native·Quick Look/Thumbnail 연결, Windows ZIP, 웹 안내·배포는 이 PR 범위가 아니다. RhwpCoreBridge에 AppKit 의존을 추가하지 않았고 Xcode project는 `project.yml`로 생성했다.

## 3. 변경 전·후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 제품 core/Studio | v0.8.6 | 공식 v0.8.7, 동일 resolved SHA |
| 설치/관리 공급 | native 기반만 있고 제품 Studio 미연결 | 실제 문서와 기존 글꼴 메뉴 연결, 필요한 face만 공급 |
| 선택 UX | Stage 3.2 중간 구현의 별도 로컬 선택 창 | 기존 전체/시스템 메뉴·선택 영역/커서 입력 명령 사용 |
| 설정 UX | 상세 목록·별도 보관함 창, 브라우저 감지 문구 | 접힌 상세·직접 가져오기, Mac 안내·단일 native 설정 버튼 |
| 최초 탐색 | 시작+첫 활성화 재현에서 2회 | 같은 조건에서 1회. CoreText 변경·늦은/후속 활성화·권한 복구 보존 |
| native 글꼴 XCTest | 시작 기준 91개 | 109개 통과 |
| 실제 목록 준비/메뉴 열기 | 전체 bytes 여부를 제품에서 확인하지 못함 | 실제 CoreText 수용에서 추가 bytes 읽기 0회 |

Stage 4.2의 같은 CLI 목록에서 metadata scan 시간 합계 중앙값은 188.68→101.33ms였다. Stage 5 앱 프로세스의 실제 목록은 232 family/809 face이고 기존 시스템 메뉴는 204 family다. 감지·메뉴 개수를 모든 파일의 지원 성공 수로 취급하지 않는다. 다른 프로세스/목록의 수치를 섞어 전체 앱 launch의 개선률을 주장하지 않는다.

## 4. 수용 기준별 검증

| 기준 | 판정 | 근거와 검증 경계 |
|------|------|------------------|
| 기존 matching·공개 API 재사용 | OK | 공식 v0.8.7 host API, source adapter·receipt. upstream matcher/편집 엔진을 중복 구현하지 않음 |
| 신뢰 frame/session·원본 경로 비노출·요청 수명 | OK | native 109·JS 25, 실제 WK IPC/잘못된 token·iframe 거부, chunk·두 slot·busy/stale/취소·늦은 응답·lease 회귀 |
| 정확한 Regular/Bold·각 renderer | OK | 고운바탕 공급 및 실제 설치 NanumSquareR/B의 PS/hash 대조. Canvas2D FontFace 2·실제 fillText alias, CanvasKit Typeface 2·완료/오류 0 |
| 이름·글꼴 선택·커서 입력·저장/재열기 | OK | 기존 메뉴·caret 입력 및 HWP/HWPX의 원래 family·bold 보존, renderer alias 미유출. 한국어 문자열/alias는 계약 테스트; 실제 지역화 family 전체 수용은 별도 |
| 정상 권한 재실행 자동 사용 | OK | 같은 sandbox 앱 새 프로세스의 설정 복원·활성 재검사·실제 bytes 공급. 기존 승인 폴더 bookmark는 동일 별도 앱/서명에서 두 번 복원 |
| cold/warm 필요 읽기·동시 병합 | OK | 실제 준비/메뉴 읽기 0, 각 문서 2 face, 반복 표시 추가 0. 동시 prepare 8회+초기 활성화 scan 1, 같은 face 8요청→1읽기, 다른 두 face 두 slot |
| 상태 변경·캐시·원본 부재/독립 보관 | OK | WK 변경/복원 40: 사용 설정, private 원본 제거·권한/동명 bytes 변경, 관리 제거/재가져오기, fallback/복구·stale·문서 상태 보존. 실제 OS 삭제 조작과 구분 |
| TTC/가변·동명 충돌 제한 | OK | 임의 face/축·충돌 선택을 하지 않고 제한/fallback 기록. 미검증 형식 지원으로 표시하지 않음 |
| core/Studio/FFI·golden·최소 빌드 | OK | Stage 3.2 strict source/Cargo/header/FFI·arm64/Intel archive·XCFramework·producer/Swift decode·native smoke 3. HostApp Debug/macOS 12 target 빌드 |
| 실제 Settings Scene·가져오기·문서 수명 | OK | Settings Scene 8·lifecycle 43. 가져오기 sheet는 기존 model action 검증과 물리 조작을 구분 |
| 현재 최종 소스/증거 정합성 | OK | Stage 5 서명 sandbox 20+17·저장 위치 8 대조, SHA256SUMS/build receipt 일치. 이번 최종 보고에서 Studio strict provenance·build info·JS 25·no-AppKit 재확인 |

단계별 실제 실행·재사용 근거는 [Stage 2](../working/task_m020_567_stage2.md), [Stage 3](../working/task_m020_567_stage3.md), [Stage 4](../working/task_m020_567_stage4.md), [Stage 5](../working/task_m020_567_stage5.md)에서 확인한다. 최종 보고 단계는 제품 소스를 수정하지 않았다. native/HostApp/WK 수용을 이 단계에서 전부 다시 실행했다고 주장하지 않는다. 최종 점검 로그는 `build.noindex/task567/final-report/`에 있다.

## 5. 잔여 위험과 후속 작업

| 범위 | 판정/인계 |
|------|-----------|
| PDF·인쇄·native·Quick Look/Thumbnail | 범위 외·미연결. #568 에서 출력 snapshot/별도 WebView의 face 준비 대기·PS/style/hash 대조, 프로세스별 권한·lease 및 Finder smoke 수행 |
| Windows ZIP·웹 안내·전체 마이그레이션 | 범위 외. #566 입력 구현과 #569 소비자별 수용/안내, 상위 #562 추적 유지 |
| macOS 12/Intel 실제 실행·배포 후보·제품 App Group 서명 | MISS(수용 환경 미확보). compile/archive·로컬 서명 sandbox 결과로 대체하지 않음. #569 수용에서 취합 |
| 실제 한컴 설치본/제거·영구 OS 설치/비활성·다른 볼륨·실제 신규 권한 패널 제출 | MISS(이번 승인 범위 외). 기존 승인 폴더 복원과 private 변경 fixture의 결과를 확대하지 않음 |
| 실제 다국어 지역화 이름 전체·TTC/가변 지원 확대 | 미검증 경계 유지. 검증한 영문 family와 한국어 문자열/alias 계약 테스트를 전체 지역화 이름 수용으로 주장하지 않음 |
| 큰 글꼴·다수 문서의 메모리/공정성·전체 제품/OS cold 시작 비용 | 한도/병합 회귀는 통과했지만 대규모 실측은 미수행. Stage 5 준비 약 0.45초·native 읽기 69.73–86.81ms는 해당 probe 구간이며 제품 전체 launch benchmark가 아님 |
| 자동 동기화 PR #577 | 2026-10-08 최종 게시 전 발견. 같은 v0.8.7 resolved commit이며 20개 변경 중 17개 경로가 겹침. 이번 PR의 adapter 자산을 보존하도록 병합 순서/중복 반영을 리뷰에서 판단. 해당 PR은 변경/close하지 않음 |

설치 참조는 원본 삭제·비활성·권한 상실 이후 계속 사용을 보장하지 않는다. 독립 보관 조건은 별도 가져온 복사본에만 적용한다. 설치 사실·fsType·사용 체크를 사용/복사 라이선스 허가로 취급하지 않는다.

## 6. 작업지시자 승인 요청

승인된 Studio 범위의 구현과 검증을 완료하고 `publish/task567` → `devel` Open PR을 게시한다. 단계 커밋을 보존해 리뷰·merge 승인을 요청한다. merge·이슈 close·부산물 정리·제품 릴리스는 이번 게시 작업에 포함하지 않는다. 다음 소비자 작업은 #568 이며, 자동 동기화 PR #577 의 중복 처리도 통합 리뷰에서 확인한다.
