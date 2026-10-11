# Task M020 #569 Stage 3 — Mac 글꼴 웹 안내·실제 UI·도움말 연결

- 일자: 2026-10-11~12, 작업 `local/task569`.
- 승인: PR #582 병합 후 작업지시자의 “#569의 웹페이지 로컬 글꼴 안내와 Mac 최종 수용 검증을 진행해줘”. 상단 안내 문구의 서체를 본문과 맞추는 추가 요청도 반영했다.
- 제품 통합: PR #582 merge `34ae2f4b14ea6baf5cce6346b5d491a8e6e6ba11`을 `4a17ea87` merge로 반영했다. 충돌한 진단·측정 6개 파일은 검토된 devel 구현을 유지하고 두 타스크의 일지·기존 측정 증거와 커밋 이력을 보존했다. 통합 직후 `Sources/Tests/scripts/project.yml/Alhangeul.xcodeproj/rhwp-core.lock`의 devel 대비 차이는 없다.
- 결과: **웹 안내·앱 도움말 구현과 로컬 검증 완료. 최종 Mac 후보/DMG 수용 완료는 아니다.**

## 1. 변경과 화면

`docs/fonts/index.html`에 설정(⌘,) → 글꼴 사용 켜기 → 기존 시스템 글꼴 목록 선택 → 저장·PDF/인쇄 확인 → 다시 감지·권한 복구를 안내했다. 설치 원본을 참조하는 기능과 보관함의 독립 복사, 한컴 앱 내부 글꼴/삭제·Windows·TTC/가변/HFT 제한을 구분했다.

홈 FAQ와 푸터에서 안내로 이동할 수 있다. 기존 영상·JavaScript 동작은 바꾸지 않았고 전용 CSS는 `.font-guide` 범위에서 기존 사이트 색상과 탐색 스타일을 재사용한다. 상단 **Mac 글꼴 사용 안내**는 본문과 동일한 `17px` 기본 서체와 보통 자간으로 맞췄다.

HostApp Help 메뉴에 **Mac 글꼴 사용 안내**를 추가해 기존 Pages origin의 `/fonts/`로 연결한다. 실제 공개 페이지/앱 제공은 release gate에서 함께 맞춘다. Help의 실제 제품 클릭은 Stage 4 후보에서 확인하고, 이번 compile 성공을 공개 페이지 열기 성공으로 표현하지 않는다.

- 로컬 미리보기: `http://127.0.0.1:3569/fonts/` (localhost 전용 서버, Codex 브라우저에 열어둠).
- [desktop 화면](assets/task_m020_569_stage3/guide-desktop.jpg), [390px 화면](assets/task_m020_569_stage3/guide-mobile-390.jpg), [320px 화면](assets/task_m020_569_stage3/guide-mobile-320.jpg), [글꼴 선택 안내](assets/task_m020_569_stage3/guide-font-choice.jpg).
- 앱 이미지는 `docs/assets/fonts/`의 실제 설정·기존 글꼴 목록이다. 처음 임시로 대조한 과거 #567 이미지와 CUA 촬영본은 최종 웹 자산으로 사용하지 않고, 이번 소스의 자체 창 촬영본으로 교체했다.

## 2. 실제 목록·UI 촬영 근거

`scripts/probe-studio-font-acceptance.py --output-dir build.noindex/task569/stage3/current-ui --sign-identity -`로 현재 제품 service/view/Studio 경계를 사용하는 격리 앱을 **ad-hoc** 서명했다. Developer ID는 사용하지 않았다. 사용자 설정/App Group·설치본·OS 글꼴은 변경하지 않았고, 저장 destination만 고유 sandbox 컨테이너로 주입했다.

| 항목 | 실제 결과 |
|------|-----------|
| 환경 | arm64 / macOS 26.5.2 (25F84), 첫 PID 21149·재실행 PID 21176 |
| 실제 목록 | 232 family / 809 face, metadata 실패·omitted 0, 기존 시스템 메뉴 204 family |
| 시험 글꼴 | 실제 설치 NanumSquareR / NanumSquareB, 두 bytes/PS·style와 renderer 진단 확인 |
| 첫 실행 | 20개 check 성공, HWP Canvas2D·HWPX CanvasKit, 기존 메뉴 선택·한글 입력·native HWP/HWPX 저장 |
| 새 프로세스 | 17개 check 성공, 사용 설정/저장 문서·한글 입력·두 face 공급 복원 |
| 원본/범위 | 실제 CoreText 환경이며 가상 28개/단일 고운바탕 목록이 아니다. 모든 face의 출력 수용이나 한컴 제거 시험은 아니다 |

[first 결과](assets/task_m020_569_stage3/first-ui-result.json)·[재실행 결과](assets/task_m020_569_stage3/reopen-ui-result.json)·[source receipt](assets/task_m020_569_stage3/source-receipt.json)에 기록한다. 192개 기록 입력 hash와 현재 입력이 일치한다. 이 probe는 `HostApp.swift`/updater entry를 제외하며 실제 product Scene/Help 메뉴·Developer ID 설치·물리 파일 패널/IME 조작을 대신하지 않는다. 공개 이미지에는 개인정보나 사용자 문서를 포함하지 않고 글꼴 bytes·bookmark/전체 catalog 파일은 커밋하지 않는다.

## 3. 검증

| 검증 | 결과 |
|------|------|
| 웹 링크/자산 | 홈 43개·안내 22개 참조 대조, 상대 경로/anchor·이미지 alt·한국어 lang 확인. [검증 결과](assets/task_m020_569_stage3/web-validation.json) |
| desktop/mobile | 1280·390·320px 직접 표시, 가로 overflow 없음. 320px main 내부의 화면 밖 수평 요소 없음 |
| 키보드/동선 | 4개 목차의 실제 hash 일치, FAQ Enter 펼침, 본문 바로가기/이미지 크게 보기의 경로 확인. [browser 결과](assets/task_m020_569_stage3/browser-checks.json) |
| 제품 compile | `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/task569/stage3/host-build CODE_SIGNING_ALLOWED=NO build` 성공. Swift 제품 입력 126개 hash 보존 |
| 공통 경계 | no-AppKit·Studio asset receipt·native matcher receipt 성공. font/core/ABI/renderer 변경 없음 |
| 공개 버전 | GitHub latest stable API 확인: v0.2.2 / non-draft/non-prerelease. 개발 안내임을 표시했고 현재 지원 기능으로 광고하지 않음 |
| 소유 등록 정리 | 빌드가 만든 HostApp·두 appex 개발 등록을 표준 helper `--cleanup-dev-registrations --no-cache-reset`로 해제. 남은 경로는 같은 후보의 Sparkle Updater.app으로 확인해 해당 하위 등록만 추가 해제 |
| 최종 위생 | 원래 `/Applications/Alhangeul.app`만 provider, 개발 등록/legacy/issues 0. 다음 단계용 unsigned 앱이 존재한다는 filesystem 경고 1은 보존함 |

probe 실행 후 자체 등록 해제가 완료됐다. 설치본 교체·Developer ID·공증·전역 cache reset·물리 인쇄·Pages/appcast 게시·원격 push/PR은 수행하지 않았다. build/log/receipt와 다음 단계용 unsigned 산출물은 `build.noindex/task569/stage3/`에 보존한다. final 회귀를 문서 변경만으로 다시 모두 실행하지 않았다.

## 4. Stage 4 인계와 승인 경계

#580의 승인된 signed ON warm metadata 약 160~170ms/provider 약 328~343ms와 정상 자동 Thumbnail 186건 busy 0을 인계한다. 원래 <300ms 후속 #581은 이번 수용의 선행 조건이 아니다.

다음은 같은 제품 소스의 최종 Mac 수용이다. 기존 계획의 후보 준비·필요 probe/helper 보완과 고유 fixture를 준비해 설정/문서·PDF 실제 저장 bytes/검색·인쇄 payload/패널 취소·Finder·변경/복구를 묶는다. `prepare-extension-font-smoke.py`와 Finder helper는 현재 #568/#580만 허용하므로 기존 guard를 유지하면서 #569 Stage 4의 명시 경로/receipt를 추가할 필요가 있다. 임의 경로로 guard를 우회하지 않는다.

각 단계 완료 후 다음 단계 승인을 따른다. 이번 명시 지시에는 웹 안내와 Mac 최종 수용 검증이 함께 포함되어 있어 Stage 3 보고/커밋 후 기존 Stage 4 범위의 후보·검증 준비를 이어간다. 구체 Developer ID 사용·`/Applications/Alhangeul.app` 임시 교체·복원은 후보 UUID/hash와 백업/복원 계획이 준비된 뒤 별도 승인받는다. public release·OS 사용자 글꼴 변경·전체 #569/#562 close를 포함하지 않는다. Windows #566·최소 OS/Intel runtime·한컴 앱 제거·물리 프린터는 별도 미검증/후속 범위로 남긴다.
