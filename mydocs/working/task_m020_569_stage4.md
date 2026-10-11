# Task M020 #569 Stage 4 — 동일 소스 Mac 수용

- 일자: 2026-10-12, 작업 `local/task569`.
- 승인: 웹 안내와 Mac 최종 수용을 함께 명시 지시받아 Stage 3 보고/커밋 `46b3d668` 후 기존 Stage 4의 후보·검증 준비를 이어간다.
- 현재: **4.1 미서명 후보·고유 fixture·복원 계획 준비 완료. 실제 Developer ID/sandbox·Mac 출력/Finder 수용은 미실행이다.**

## 1. 구체 후보

| 항목 | 준비 결과 |
|------|-----------|
| 제품 소스 | `46b3d66828bc2616842abdff6821b4aea3aed162`, Swift 126개 현재 hash 일치. 이후 변경은 도구/문서만 |
| 후보·fixture | `build.noindex/task569/stage4/finder-candidate-01/`의 `Alhangeul.app`·`FontExtensionFixtureProbe.app` |
| 시험 marker/build | `88FFC8FB-E8C2-47D6-A818-08FDA89C2CC2` / `569.4.1`, `ALHANGEUL_FONT_EXTENSION_PROBE` Release. 공개 버전이 아님 |
| 후보 inventory digest | `8c16a46027f4b388c282d08f4b1910f71407040bcd336b27139e5f3f095e3a4c` |
| fixture inventory digest | `fca79bbed0f0ee02292b8fe606a457bf593ee4f66008e01cca971ddb547d9a14` |
| 소유 보관함 | App Group의 `Library/Application Support/FontLibrary/v1/extension-probes/88FFC8FB-E8C2-47D6-A818-08FDA89C2CC2` |
| 입력/글꼴 | 고정 hash의 단일 HWP·HWPX·2페이지 HWPX, 기존 OFL Gowun Batang R/B와 사용 조건 파일 |
| 기존 인증서 | `Developer ID Application: Taegyu Lee (XH6JHKYXV8)` 존재만 읽기 전용 확인. 서명 미실행 |

후보의 `preparation.json`·`operation-plan.json`과 [요약 영수증](assets/task_m020_569_stage4/candidate-preparation.json)을 보존한다. 앱/DMG·글꼴 bytes·사용자 catalog/bookmark는 커밋하지 않는다.

## 2. 도구 보정·사전 검증

prepare/Finder helper는 기존 #568/#580 경계를 유지하며 #569의 `stage4` 경로와 task receipt만 추가 허용한다. 전 제품 source set·fixture/core/Studio/native/input hash·unsigned/signed 전체 inventory·원래 앱 inventory·고유 marker·실행 중 앱 거부·모드 분리·실패 자동 복원을 유지한다.

- 기본 Release는 Stage 3, 같은 제품 소스의 진단 Release는 이번 준비에서 HostApp/두 확장 포함 빌드 성공.
- #569 guard 16개와 기존 #580 guard 16개 통과. 외부 명령은 mock으로 차단하여 서명/설치를 실행하지 않았다. 세 Python helper 문법 검증 통과.
- 준비 후 Swift 126개·후보/fixture inventory 재대조 일치.
- 원래 `/Applications/Alhangeul.app`만 provider, 개발 등록/legacy/issues 0. 필요한 후보 앱 존재 경고 1은 유지한다.
- #580의 승인된 성능 결과와 <300ms 후속 #581 분리를 그대로 인계한다. 새로운 최적화 목표를 시작하지 않는다.

## 3. 승인 후 실제 수용

1. 고정 후보/fixture를 기존 인증서로 로컬 서명하고 strict/deep seal·entitlement·signed inventory를 기록한다.
2. 원래 앱/사용자 문서 창·준비 당시 원본 inventory를 확인하고 백업 후 표준 smoke 안에서 잠시 교체한다. guard 실패 시 설치하지 않는다.
3. 고유 보관함만 설정한다. 같은 제품 소스의 실제 설정/face·기존 글꼴 목록·HWP/HWPX 저장/재열기·재실행을 확인하고 제품 후보/격리 probe 차이를 기록한다. 실제 Help 클릭과 아직 미공개인 URL 상태도 구분한다.
4. 실제 저장 PDF의 PS/program·한글 원문/검색·확대 화면, immutable print payload와 macOS 패널 열기/취소를 확인한다. 필요한 driver 보완은 기존 수용 범위 안에서 추적한다. 물리 프린터로 전송하지 않는다.
5. Finder 단일 PNG/다중 PDF·Thumbnail·정책/소유 객체/원본 변화·복구와 자원 수명을 확인한다. OS가 요청하지 않은 표시를 새 성공으로 합산하지 않는다.
6. 성공/실패 모두 원래 앱·등록을 복원하고 UUID 저장소·자체 worker/창을 정리한 뒤 최종 수용표에 취합한다.

실제 창/패널 시험 전에 Mac 잠금 해제 상태를 확인한다. 이번 준비 말미에는 Mac이 잠겨 있었으며 추가 UI 조작을 하지 않았다.

## 4. 백업·원상복원 계획

- 설치 대상: `/Applications/Alhangeul.app`, 현재 v0.2.2.
- 원본 파일/링크/권한 243개, digest `fa694017af3e0b3705510b353ef0e9dc5549be57493b74e99e5ca05540b3707b`.
- 백업: 후보 폴더의 `backup/Alhangeul.app`. 설치 직전에 `ditto` 후 strict seal·준비 당시 inventory 일치를 확인한다.
- 실패는 helper 복원 경로로 회복한다. 다른 작업이 설치본을 변경하면 자동으로 덮어쓰지 않는다.
- 복원 시 bytes/링크/권한·strict 서명·원래 provider를 확인한다. xattr 전체 비교를 보증한 결과로 표현하지 않는다.
- 전역 cache reset·다른 앱 등록 변경·사용자 OS 글꼴/한컴 앱/원본문서 변경·공개 Release/Pages/appcast는 제외한다.

## 5. 공간 정리와 다음 gate

후보 inventory 확인 후 완료된 Stage 3 앱 3개·옛 dSYM과 복사 완료한 Stage 4 raw 앱을 정리했다. **716,686,096 bytes(약 683MiB, 논리 크기)**이며 실제 가용 공간 증가량과 같다고 주장하지 않는다. 후보/fixture·새 dSYM·package/module cache·로그/JSON/그림·OFL 원본/문서 입력은 보존하고 자체 Sparkle 하위 등록까지 해제했다.

위 고정 후보와 복원 계획의 **기존 Developer ID 로컬 서명·임시 Finder/Mac 출력 시험·원상복원** 승인 후 실행한다. 구현계획 §5는 “서명/임시 설치 시험은 구체 후보·인증서·설치 대상·백업/복원·고유 보관함이 준비된 뒤 승인된 범위에서만 실행”하도록 정했다. Windows/최소 OS/Intel runtime·실제 한컴 제거·물리 프린터 및 #569/#562 전체 잔여 조건은 유지한다.
