# Task M020 #569 — Mac 로컬 글꼴 안내·수용 최종 보고 (부분 완료)

- 이슈: [#569](https://github.com/postmelee/alhangeul-macos/issues/569), 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562).
- 일자/브랜치: 2026-10-12 / `local/task569`, 대상 `devel`.
- 통합 기준: PR #582 / `34ae2f4b14ea6baf5cce6346b5d491a8e6e6ba11`, merge `4a17ea87`.
- 제품 수용 기준: `46b3d66828bc2616842abdff6821b4aea3aed162`의 Swift 126개, 공식 core/Studio v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`. 이후 제품 코드 변경 없음.
- 승인: 수행/구현계획·각 단계 및 구체 시험 승인에 이어 “Stage 4 수용·Stage 5 준비 진행”, 최종 보고의 “최종 보고 수용·push/Open PR 게시”를 승인받았다. 승인된 `d7270a7a`를 게시하고 [Open PR #583](https://github.com/postmelee/alhangeul-macos/pull/583)을 생성했다. Mac 부분 인계이며 merge·이슈 close·출시는 수행하지 않았다.

## 1. 결과와 변경

이미 병합된 Mac 글꼴 기능을 실제 사용자 동선으로 안내하고, 같은 제품 소스 후보에서 문서·출력·Finder 주요 경로를 수용했다. 사용자는 **설정(⌘,) → 글꼴 → Mac에 설치된 글꼴 사용**을 켜고 문서의 기존 글꼴 목록에서 **시스템 글꼴**을 선택한다. 설정은 재실행에도 유지된다.

| 변경 | 결과 |
|------|------|
| `docs/fonts/index.html` | 사용 설정·기존 목록 선택·저장/출력·권한 복구·설치 원본/보관 복사 차이·지원 제한·Windows 후속 안내 |
| 홈 FAQ/푸터·`docs/styles.css` | 안내 진입과 1280/390/320px 반응형·키보드 동선. 상단 “Mac 글꼴 사용 안내” 글꼴을 본문과 맞춤 |
| `docs/assets/fonts/` | 실제 Mac 목록의 설정/글꼴 선택 화면. 가상 28개나 고운바탕 한 개 probe를 전체 감지 화면으로 쓰지 않음 |
| `Sources/HostApp/HostApp.swift` | Help 메뉴의 **Mac 글꼴 사용 안내** 8줄 추가, 기존 Pages origin `/fonts/`로 연결 |
| 후보 준비/Finder/guard helper | 기존 #568/#580 경계를 유지하며 #569 Stage 4 경로·task receipt 지원. 외부 명령 mock의 guard 검증 |
| 계획·수용표·단계 증거 | 기존 Finder baseline 측정, #580 성능 개선 인계, 같은 후보의 Mac 수용·복원·출시 잔여 조건을 기록 |

core pin·FFI·글꼴 공급 구조·Studio/renderer 기본값을 이 PR에서 새로 변경하지 않는다. 현재 공개 v0.2.2에는 기능이 없다는 표시를 유지했으며 안내는 로컬 초안이다. 실제 Help 클릭은 정확한 공개 URL을 열었지만 아직 게시되지 않아 404였다. Pages 공개와 기능 제공 버전은 release 게이트에서 맞춘다.

## 2. 성능 확인과 후속 분리

#569 Stage 1–2의 반복 Finder 비용 확인에서 metadata 준비 약 1초와 동시 대기를 관찰해 독립 #580을 수행했고, PR #582의 검토·병합 결과를 통합했다. 마지막 signed 측정에서 ON warm metadata 조건별 중앙값 약 **160~170ms**, provider 약 **328~343ms**, 정상 자동 Thumbnail 186건 busy 0을 수용했다.

최초 provider <300ms 목표 미충족 사실과 첫 miss/다수 파일 대기를 남긴다. 이는 앱 시작 시간·Finder 전체 화면 표시 시간이나 모든 Mac의 상한을 뜻하지 않는다. 추가 현재성 검사 최적화는 [#581](https://github.com/postmelee/alhangeul-macos/issues/581)이며 이번 Mac 인계의 선행 조건이 아니다. 원시 측정과 수용 보정은 [#580 최종 보고](task_m020_580_report.md)를 따른다.

## 3. 같은 후보의 Mac 수용

기존 Developer ID로 승인된 후보/fixture `569.4.1`, UUID `88FFC8FB-E8C2-47D6-A818-08FDA89C2CC2`를 서명하고 원래 v0.2.2 앱을 백업·임시 교체했다. arm64/macOS 26.5.2 (25F84)의 실제 제품 Scene·메뉴·파일 패널·Finder를 사용했다. 고유 시험 보관함을 쓰는 진단 flag 후보이며 최종 배포 DMG와 구분한다.

| 수용 | 결과와 경계 |
|------|-------------|
| 설정·기존 목록·재실행 | Mac 232 family/809 records, 시스템 메뉴 205 family(관리 Gowun 포함). 실제 NanumSquare 선택, 새 프로세스에서 ON 유지와 저장 문서 재열기 확인 |
| HWP/HWPX 편집·저장 | 실제 open/save-as 패널로 별도 문서 저장. 공식 WASM 재열기에서 원문·NanumSquare family·기존 Bold 유지, host alias 저장 없음 |
| 실제 PDF | NanumSquare Regular/Bold의 PS·내장 program·ToUnicode, PDFKit/Poppler 원문·‘한글’ 검색·확대 화면 정상. pypdf 빈 객체 경고는 전체 PDF 구조 적합성 보증으로 바꾸지 않음 |
| 실제 인쇄 | 두 형식의 macOS 인쇄 패널 열기/취소·문서 복귀 확인. 물리 프린터로 전송하지 않음 |
| 출력 회귀 | 같은 현재 입력의 별도 ad-hoc sandbox probe에서 managed 29/installed 25/baseline 16, 총 70 checks 통과. 필요 face 읽기·취소·기존 destination/늦은 결과 보호·변경 후 재출력·문서 상태·immutable payload 확인 |
| Finder | fresh Thumbnail PNG 3개, 실제 단일 HWP/HWPX PNG Quick Look·다중 HWPX PDF 2페이지 확인. 정확한 Gowun R/B·공급 fallback 없음, 새 extension crash report 0 |
| 변경/복구 | 같은 문서 path/bytes/mtime의 ON/OFF·충돌/선택·권한/객체 누락·복구 10 phase/20 callbacks. 정상 16건 exact 공급, 의도적 fallback 4건을 구분. 변경 identity와 복구 후 공급/재사용 확인 |

[Stage 4 보고](../working/task_m020_569_stage4.md)와 [Mac 지원/수용표](../tech/task_m020_569_mac_acceptance.md)에 후보 hash·PID/image UUID·실제 결과·한계를 연결했다. 원본/권한 계약과 과거 동선을 이번 실제 시험과 혼합하지 않는다. 출력 불가 face의 실제 alert/명시 대체 클릭은 새로 재현하지 않았고 아래 현재 회귀에서 실패/명시 대체 계약을 확인했다.

## 4. 최종 회귀와 증거 대조

- `scripts/test-font-library.sh`: XCTest **162개**·Node **30개**, 실패/skip 0. 실제 CoreText process scope lifecycle 회귀 포함.
- 현재 Debug Host를 먼저 빌드한 뒤 `scripts/test-studio-output.sh`: **81개** 실패 0. 기본 실패 결과, WebKit face load 오류 family 식별, 명시 대체의 차단 family 제거·읽기 0, PDF/인쇄 수명 회귀 포함.
- no-AppKit·native matcher·core build-info·bundled Studio receipt 정상. #569/#580 후보 helper guards 각각 **16개** 통과.
- 같은 제품 Source 집합 **126개**, 출력 probe 기록 입력 **188개**, core/Studio/native hash 및 선별 checksum **59개** 일치. 홈/안내 로컬 참조·fragment·이미지 alt 정상. 변화 없는 웹 반응형/키보드와 기본/진단 Release compile은 해당 단계 증거를 인계.

첫 Host 회귀는 Debug 앱 미준비로 Spotlight 테스트 1개가 실패했다. 전제 앱을 빌드한 뒤 같은 suite가 통과했으며 실패 로그를 보존했다. 제품/테스트를 바꾸지 않았다. [Stage 5](../working/task_m020_569_stage5.md)와 [검증 영수증](../working/assets/task_m020_569_stage5/validation.json)을 따른다. PR #583 게시 후 CI가 시작됐으며 로컬 결과를 CI 통과로 설명하지 않는다. 게시 당시 관찰은 [공개 게시 기록](../working/assets/task_m020_569_stage5/publication.json)에 구분한다.

## 5. 원상복원·공간 정리

원래 `/Applications/Alhangeul.app` v0.2.2를 복원하고 파일/link/mode **243항목** inventory·strict/deep 서명·원래 provider 일치를 확인했다. 승인 UUID 공유 보관함/private catalog·소유 probe run과 worker·앱/등록을 정리했다. 전체 preferences/최근 문서나 xattr backup/restore를 수행한 것으로 확대하지 않는다.

Stage 4 전 완료 산출물 약 683MiB, Stage 4 후보/fixture/backup/staging/probe 앱 5개 약 1.08GiB, Stage 5 회귀용 Debug 앱 약 279MiB를 정리했다. 모두 논리 크기 기준이며 실제 가용 공간 증가량을 보증하지 않는다. Stage 5 빌드의 자동 등록 흔적 한 경로도 전역 cache reset 없이 해제했다. 최종 provider 하나, 개발 등록/앱·legacy·issues/warnings 0이다. 필요한 XCTest/cache·raw 로그·문서/PDF/PNG·영수증과 선별 증거는 보존했다.

## 6. 남은 범위·부분 PR·릴리스 인계

이번 Mac 부분 [PR #583](https://github.com/postmelee/alhangeul-macos/pull/583)은 `publish/task569` → `devel`로 게시했다. [PR 본문 초안](../working/task_m020_569_pr_draft.md)에 `Refs #569, #562`를 사용하며 `Closes`는 넣지 않는다. Windows 입력 [#566](https://github.com/postmelee/alhangeul-macos/issues/566)과 #569의 Windows 수용·#562 전체 완료 조건을 남긴다.

TTC 개별 face·가변 축·HFT, 복잡한 shaping/pagination의 한컴 동일 표현, 실제 한컴 앱 제거, macOS 12/Intel runtime·물리 인쇄·최종 공증 DMG는 이번 실증 범위 밖이다. 설치 원본이 남고 활성/읽기 권한이 유지돼야 사용하며 설치 사실만으로 복사/사용 라이선스를 보증하지 않는다.

M900 release 운영에 다음을 인계한다.

1. 구체 공개 버전/build·후보 SHA와 v0.2.2 이후 포함 변경/지원 제한 확정.
2. 진단 flag가 없는 정상 signed/notarized pre-public DMG 설치 smoke와 원래 앱 복원.
3. 최종 웹 기능 제공 상태·스크린샷/Help 링크·Pages 공개 시점과 Release/appcast/Cask 게이트 정렬.

최종 보고 수용·원격 push/Open PR 게시를 2026-10-12 승인받아 수행했다. 같은 제품 소스의 게시/승인 기록만 후속 커밋으로 보완하며 merge·이슈 close·제품/사이트 공개는 이번 승인에 포함하지 않는다.
