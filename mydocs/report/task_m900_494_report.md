# Task M900 #494 최종 보고서

## 작업 요약

PR #491을 병합하고 rhwp v0.8.6 기반 알한글 **v0.1.11 (17)**을 공식 공개했다. 서명·공증된 후보에서 발견한 HWP3 복사본 저장 오류는 별도 Task #497로 수정·재검증한 뒤 배포했다. 공식 DMG, Pages·Sparkle, Homebrew와 실제 v0.1.10 → v0.1.11 업데이트·Finder 제공자 검증을 통과했다.

| 항목 | 결과 |
|------|------|
| 실행 이슈 | [#494](https://github.com/postmelee/alhangeul-macos/issues/494), M900 Release Operations |
| 작업 / 게시 / 통합 브랜치 | `local/task494` / `publish/task494` / `devel`; 공개 문구 종료 정리는 `main` |
| 공개 릴리스 | [Alhangeul v0.1.11 (rhwp v0.8.6)](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.11) |
| 공개 시각 | 2026-09-07 02:16:00 KST |
| 앱·Preview·Thumbnail | `0.1.11 (17)`, arm64 + x86_64 |
| rhwp core / Studio | `v0.8.6` / `f1f9c6ae58344ee9368996d3543f76b9345cf227` |
| official tag / commit | `v0.1.11` / `abdf88f9846650e5920039f2807615ea1b285f91` |
| annotated tag object | `7c778a75d7a911615540279fb7232d8493914b6f` |
| official Publish | [run 34047148092](https://github.com/postmelee/alhangeul-macos/actions/runs/34047148092), publish·Pages 성공 |
| Homebrew tap | [commit 6f4abf8](https://github.com/postmelee/homebrew-tap/commit/6f4abf8ff3fa8db64a0dfa27c0c22f50b86e2153) |
| 최종 정리 | [main PR #501](https://github.com/postmelee/alhangeul-macos/pull/501) merge `0272172e543d59fd87eebb11d98904ee344a4487`, [Pages 34049769039](https://github.com/postmelee/alhangeul-macos/actions/runs/34049769039) 성공·public byte 검증 완료 |

## 사용자에게 보이는 변화

- 암호 문서와 HWP3 원본을 덮어쓰지 않도록 보호하고, 변환·보호 해제 안내 후 새 복사본으로 저장한다. HWP3 복사본 저장의 sandbox 권한 오류도 수정했다.
- PDF 한글 선택·검색·복사를 보강하고 PDF·인쇄의 중복 실행과 이전 응답 간섭을 방어한다.
- 지원하지 않는 파일 열기 오류에서 기존 문서를 보존하고 다시 시도할 수 있다. 글자색·형광펜 선택기 위치와 표시를 보정했다.
- rhwp v0.8.6의 조판·저장 호환성, 한글 입력·표 편집 개선을 통합했다.

공개 요약의 근거는 [릴리스 기록의 포함 PR 분석](../release/v0.1.11.md#포함-pr-분석)이다. 릴리스 tag 범위의 16개 PR 중 사용자-facing 8개를 구분했고, Issue #480 전체나 v0.8.6 이후 upstream 수정은 해결 항목에 포함하지 않았다.

## 변경 범위

| 단계 | 변경 |
|------|------|
| 후보 준비 | 세 target version/build, 두 release workflow 입력, README·Pages·이전 버전 banner, release record |
| 차단 오류 수정 | Task #497 / PR #498에서 sandbox가 허용하는 임시 저장 경로 사용. 원본 보호·배타적 게시 유지 |
| 종료 정리 | repository Cask의 공식 DMG digest, README·Pages 3문서의 공개·Homebrew 안내, 계획·orders·release/단계/최종 기록 |

종료 정리에서는 제품 source, workflow, core lock, bundled Studio와 공식 tag를 바꾸지 않는다. 생성된 repository appcast를 커밋하지 않고 배포 중인 public appcast를 docs-only artifact에 그대로 전달한다. v0.1.10의 과거 저장 위험 안내는 당시 동작의 기록으로 보존한다.

## 단계별 결과와 PR 이력

| 단계 | 주요 커밋 | 결과 |
|------|-----------|------|
| [Stage 1](../working/task_m900_494_stage1.md) | `54a6866` | version/build·workflow 입력 정렬, main/devel 실제 tree 비교 |
| [Stage 2](../working/task_m900_494_stage2.md) | `a346130` | PR·Issue·완료 보고 근거 분석, 사용자용 문서 후보와 형식 검증 |
| [Stage 3](../working/task_m900_494_stage3.md) | `09ff64b` | source·ABI·Rust/Swift 테스트, Debug/Release·native renderer·package 검증 |
| [Stage 4](../working/task_m900_494_stage4.md) | `f1c633f`, `5753205`, `32428ad`, `9f2323b`, `92092b8` | 최초 signed 실패 기록, Task #497 수정 후보 재생성·저장 6조합·GUI·Finder 검증과 복원 |
| [Stage 5](../working/task_m900_494_stage5.md) | `9159e1f`, `58194a6` | 공식 공개·Homebrew·실제 Sparkle 업데이트와 자연 등록 Finder 검증, 원본 설치 복원 |
| [Stage 6](../working/task_m900_494_stage6.md) | 이 보고서와 함께 커밋 | main PR #501·Pages 성공, public byte 검증과 devel 최종 기록 인계 |

이번 작업에서 생성·병합한 PR은 다음과 같다. 원래 요청한 PR #491은 기존 upstream sync PR이다.

| PR | 역할 / 결과 |
|----|-------------|
| [#491](https://github.com/postmelee/alhangeul-macos/pull/491) | upstream v0.8.6 동기화, merge `eec7869fb958aec8e30df3a4e6cdaf67253c5a5a` |
| [#495](https://github.com/postmelee/alhangeul-macos/pull/495) | Stage 1~3 source 준비·검증, devel 반영 |
| [#496](https://github.com/postmelee/alhangeul-macos/pull/496) | 최초 후보 main 승격. signed smoke에서 HWP3 저장 실패 발견 |
| [#498](https://github.com/postmelee/alhangeul-macos/pull/498) | Task #497 차단 오류 수정, merge `6fac59e2f3a19d9762cece3165d1da211d094aea` |
| [#499](https://github.com/postmelee/alhangeul-macos/pull/499) | 수정 후보·재검증·실패 증거 기록 devel 반영 |
| [#500](https://github.com/postmelee/alhangeul-macos/pull/500) | 수정 후보 main 승격, 최종 official tag commit 확정 |
| [#501](https://github.com/postmelee/alhangeul-macos/pull/501) | 단일 main 공개 문구·Cask·검증 기록 종료 정리, Pages 배포 확인 |

차단 오류 때문에 수정 PR·검증 기록·main 재승격이 추가됐다. 다음 릴리스에서도 sandbox 저장은 공증 후보 설치 gate로 유지하고, 공개 이후 사용자 문구 보정은 하나의 main 종료 정리 PR에 모은다. main 배포 이후에만 알 수 있는 Pages 결과는 devel 최종 기록에 묶어 공개 문구 PR을 반복하지 않는다.

PR #498~501에서 Copilot quota 메시지는 실제 코드 review나 approval로 간주하지 않았다. exact head·tree·변경 범위와 CI를 별도로 확인했다.

## 검증 결과

| 영역 | 실행 결과 |
|------|-----------|
| core·Studio·ABI | 동일 release tag/commit, Cargo.lock fingerprint·header·FFI symbol·decoder 계약 검증 |
| 자동 테스트 | Stage 3 Rust locked 9개, HostAppTests 181개, ExternalImageTests 30개 통과. Task #497 수정 후 HostAppTests 184개 통과 |
| 빌드·렌더 | Debug·universal Release, endpoint·Legal·bundle·native renderer 3문서와 thumbnail 정책 24회 검증 통과 |
| 수정 공증 저장 | 평문·보호 HWP3 → HWP5/HWPX, 일반 HWP5/HWPX 저장 총 6조합·후속 저장·재열기 통과 |
| PDF·인쇄 | 수정 signed HWPX PDF 9페이지·869,612 bytes, Preview 한글 선택·검색·복사, 인쇄 취소/재진입 확인 |
| 열기·색상 | 빈 파일 오류·재시도 취소 후 기존 9페이지 유지, HWP 글자색·HWPX 형광펜 부분 적용과 undo/redo |
| 공식 DMG | GitHub asset digest·size, 다운로드 bytes·checksum·본문·workflow 로그 일치, hdiutil verify·staple·Gatekeeper 통과 |
| 공식 앱 | 8개 서명 구성요소, 예상 Team ID·timestamp·hardened runtime·sandbox, debug entitlement 부재, universal·Legal·staple·Gatekeeper 통과 |
| Sparkle 서명 | 기존 v0.1.10 public key로 official DMG Ed25519 서명 독립 검증, 새 앱 public key 동일 |
| 실제 업데이트 | `/Applications` v0.1.10 (16)에서 180.2MB 다운로드·설치·재실행. About v0.1.11 (17), rhwp v0.8.6 |
| 실제 새 제공자 | 격리·수동 등록 repair 없이 기본 helper exit 0. Thumbnail PID 21138·Preview PID 21977이 업데이트된 `/Applications`에서 실행 |
| 앱·Finder | 공식 업데이트 앱 HWP 1페이지·HWPX 9페이지, Finder Space HWP·HWPX 표시·페이지 확인 |
| Homebrew | style·audit·new 참고 검사, 별도 appdir 실제 설치·제거 모두 exit 0. 설치 실행 파일과 official 앱 byte 일치 |
| 원본 복원 | 기존 `/Applications` v0.1.10 147개·사용자 v0.1.8 146개 항목, samples 180개·입력 fixture 2개 보존. 기존 등록 복원, 테스트 앱/확장 프로세스 종료 |

Stage 4 Finder 성공은 기존 제공자를 분리한 환경의 결과다. Stage 5 actual Sparkle에서는 기존 HOP와 사용자 v0.1.8 등록을 그대로 두고 새 제공자 실행을 확인했다. 이 두 검증 조건을 혼합하지 않는다. Homebrew는 기존 앱을 보존하기 위해 공식 `--appdir` 옵션을 사용했으므로 기본 `/Applications` 설치를 새로 실행한 것으로 확대하지 않는다.

Mac 잠금으로 UI 확인이 두 차례 멈췄지만 잠금 해제 뒤 남은 확인을 마쳤다. HWPX 종료 시 의도적인 텍스트 편집 없이도 변경 사항 저장 확인이 표시돼, `public-open-preserved.hwpx` 사본으로 저장하고 정상 종료했다. 사본은 ZIP CRC 정상이며 원래 입력과 samples hash는 그대로다. 원인은 이번 릴리스에서 확정하지 않았다.

## 배포 provenance

| 항목 | 값 |
|------|----|
| official DMG | [alhangeul-macos-0.1.11.dmg](https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.11/alhangeul-macos-0.1.11.dmg) |
| official SHA256 | `12f3263ab7a44e87f4b61dc1157590cc3a480e2cd1eabdfd78e5708836bf1e75` |
| official size | 180,206,064 bytes |
| signed draft | [run 34043285977](https://github.com/postmelee/alhangeul-macos/actions/runs/34043285977), SHA256 `99fcc789d500d13fede37e6f810653a5bdaf92372dac1094a0fdba228926069b`, 180,205,988 bytes |
| stable appcast | [public feed](https://postmelee.github.io/alhangeul-macos/appcast.xml), v0.1.11 (17), minimum macOS 12.0 |
| appcast SHA256 | `f880f5047ffea8f41f5675900a3fbb5261b9c5d1015a29f007fdbd3be604f234` |
| 사용자 릴리스 노트 | [v0.1.11](https://postmelee.github.io/alhangeul-macos/updates/v0.1.11.html) |
| Homebrew 설치 | `brew install --cask postmelee/tap/alhangeul` |

공식 실행은 `previous_release_ref=v0.1.10`, `expected_rhwp_tag=v0.8.6`, `require_latest_rhwp=true`, `include_rhwp_in_title=true`, `draft=false`, `prerelease=false`였다. 같은 tag에서 다시 만든 official DMG digest를 사용하며 draft digest를 Cask에 재사용하지 않았다. Homebrew 완료 후 GitHub Release 본문에 설치 명령을 반영하고 원격 exact 본문을 대조했다.

## 알려진 한계와 미실행 범위

- 로컬 strict static archive hash/size는 lock reference와 불일치했다. lock을 갱신하지 않았고 승인된 portable source·Cargo·header·ABI 경계로 검증했다. strict 재현성 통과로 표시하지 않는다.
- 이전 설치 경로 두 개와 기존 LaunchServices 잔여 때문에 global hygiene helper는 exit 1이었다. 이번 테스트 제공자와 프로세스 정리 성공을 전역 목록 정리 성공으로 확대하지 않는다.
- Intel Mac·macOS 12 실기기, maintainer가 직접 조작한 smoke, 모든 창 크기·혼합 서식·모든 문서 요소 무손실은 검증하지 않았다. 자동화한 macOS UI 결과만 기록한다.
- native 암호 유지·새 암호 설정, HWP3 원형 저장, OCR과 모든 글꼴·수식의 PDF 텍스트 추출은 제공하지 않는다. Issue #480은 OPEN을 유지한다.
- 보호 HWP5/HWPX 저장 64/23페이지 확인은 최초 후보의 결과다. 수정 공증 후보에서는 보호 HWP3를 포함한 위 6조합을 확인했다.
- upstream #6635 키보드 활성화 수정은 v0.8.6 이후 commit이므로 이번 번들에 포함하지 않았다.

## 최종 정리와 완료 조건

main PR #501에 README·Pages 공개 문구, repository Cask, Stage 4~6와 최종 검증 기록 14파일을 모아 반영했다. PR CI 34049467483은 분류·스크립트·release helper 3개 job success, macOS scope skip이다. 02:48:53 KST merge 후 docs-only Pages 34049769039의 두 job이 성공했다.

02:50 KST public home·updates·v0.1.11·이전 v0.1.10 HTML을 source와 byte 대조했고, 최신 세 페이지의 공개 준비 문구 제거와 Homebrew 명령 반영을 확인했다. latest·tag 고정 다운로드는 HTTP 200, 180206064 bytes이며 stable appcast 1,167 bytes와 SHA256은 기존과 동일하다. official tag는 다시 지정하지 않았다.

이 최종 결과를 devel에 전달하는 PR은 main 공개 문구를 재수정하지 않는다. main과의 추가 차이는 운영 문서뿐이다. 관련 PR merge 확인 뒤 Issue #494 체크리스트·상태, 로컬·원격 작업 브랜치를 정리하고 devel로 복귀한다. 오늘할일은 공개·업데이트·문구 검증 완료 시각 02:50을 기록한다.

실행 증거는 `build.noindex/task494/stage2/`, `stage3/`, `stage4/`, `stage5/`, `stage6/` 및 [릴리스 장기 기록](../release/v0.1.11.md)에 있다. 테스트 문서·보존 사본·기존 앱 백업은 재현을 위해 ignored 경로에 유지한다. 비밀 값은 보고서와 GitHub 본문에 기록하지 않았다.
