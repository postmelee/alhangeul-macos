# Task M900 #584 Stage 2 소스·검증 준비 보고

## 결과와 승인 범위

작업지시자의 “Stage 1 수용·Stage 2 진행”에 따라 v0.2.3 / build 21 소스·안내 후보와 unsigned 검증을 준비했다. **소스 준비 완료 / 최종 공증 DMG·설치·공개 수용 대기**이며 #584 전체 완료가 아니다. push/Open PR·tag·Developer ID 서명/공증·임시 설치·공개 배포는 수행하지 않았다.

## 변경

| 영역 | 결과 |
|------|------|
| 네 bundle | HostApp·Quick Look·Thumbnail·Spotlight source와 Debug/Release built bundle 모두 0.2.3 / 21 |
| release workflow | rehearsal/publish 0.2.3·previous v0.2.2·rhwp v0.8.7, promote build 21. 기존 gate와 draft 정책 유지 |
| 공개 본문 후보 | 공식 v0.8.7 변화와 앱 글꼴 연결 구분, 설정 → 기존 시스템 글꼴 목록 순서. Windows·원본/권한·지원 face·저장/복구 한계 유지 |
| Pages/README | v0.2.3 노트·홈/업데이트·Mac 안내 후보. README는 실제 public v0.2.2와 미공개 후보를 구분. Homebrew v0.2.2 유지 |
| 과거 릴리즈 | 15개 페이지는 helper의 최신 안내만 변경, 과거 본문·공개일·고정 다운로드 그대로 |

Swift·Studio·FFI·core pin·renderer 기본값은 변경하지 않았다. Stage 2.1 source 커밋은 `ee453da2c68721542d05d88580f9cd26a22eb2af`다.

## 검증

| 검사 | 실제 결과 |
|------|-----------|
| Rust portable | arm64/x86_64 locked build·header·FFI symbol·XCFramework PASS. 재빌드 header/staticlib SHA256·size도 기존 lock과 동일 |
| core/Studio | generated 정보·고정 v0.8.7/1a76570e·자산/adapter receipt PASS |
| render-tree golden | producer·provenance·Swift decoder 계약 PASS |
| 공유 Swift | AppKit/UIKit 직접 의존 없음 PASS |
| Xcode | xcodegen·unsigned Debug·unsigned universal Release PASS. 배포와 같은 ARCHS=arm64 x86_64 / ONLY_ACTIVE_ARCH=NO 적용 |
| built 앱 | 네 bundle version/build·네 실행 파일 양 slice·Release endpoint·Legal canonical 일치 PASS |
| native smoke | KTX.hwp·request.hwp·exam_kor.hwp 첫 페이지 PNG/한글/비어 있지 않은 화면 PASS. 문서 배치 parity 검사가 아님 |
| helper | news 14·promotion 16·install 25개 fixture 검사 PASS. 실제 게시/DMG 설치 없음 |
| 문서/Pages | 본문 필수 heading·GitHub body·YAML/shell·246개 HTML local link/anchor·이전 본문 보존·배지/notice PASS |
| 공개 보호 | 새 public appcast의 v0.2.2 bytes/hash를 로컬 artifact에 그대로 보존. v0.2.3 Release HTTP 404이므로 변경하지 않은 Pages asset gate는 deploy=false 조건 |
| 화면 | 홈·업데이트·새 노트·Mac 안내 각 1280/390/320px, 총 12개 가로 넘침 없음. skip-link·FAQ Enter·Homebrew ArrowRight 확인 |
| main 내용 | source 커밋 기준 main-only content 0, prospective tree 동일 PASS |

첫 sandbox Cargo/Xcode 호출은 캐시/네트워크 접근 제한으로 실패했고 승인된 unsigned 범위에서 접근을 허용해 다시 통과했다. 최초 로컬 Release 호출은 arm64만 만들어 universal 검사에 실패했으며 배포 스크립트의 양 ARCHS를 명시해 통과했다. source 수정으로 우회하지 않았다. Rust/golden의 LAYOUT_TABLE_OVERLAP 진단은 비치명적 기존 표시로 남겼으며 한컴 시각 동일성 성공으로 계산하지 않는다.

## 공간과 등록 정리

이번 Cargo fetch에서 중단된 2,183,053,311-byte 임시 pack만 제거했다. 공식 고정 cache는 Git sparse-checkout으로 PR 이미지(mydocs/pr/assets)·비교 PDF만 제외하고 모든 제품 코드·tag/lock을 유지했다. upstream 전체 blob은 약 5.62GB이며 두 제외 경로 약 3.88GB를 다시 펼치지 않는다. 표본 문서·작업 소스·다른 저장소는 유지한다.

Xcode가 자동 등록한 이번 Debug/Release 및 해당 appex·번들 내부 Updater만 해제했다. 처음 hygiene에서는 Updater 등록이 남았으므로 해당 두 경로도 개별 정리했다. 최종 등록/공간 receipt는 아래 증거를 따른다. 원래 /Applications/Alhangeul.app은 0.2.2 / 20·strict seal PASS이며 교체하지 않았다. 전역 cache reset·다른 앱 등록 변경은 없었다.

최종 hygiene PASS 뒤 다음 단계에 쓰지 않는 이번 DerivedData/DerivedDataRelease·렌더 module cache·Pages 조립 복사본·이번에 생성한 Rust target을 정리했다. 논리 파일 약 5.19GB를 제거했고 가용 공간은 10.62GB에서 15.01GB(약 14GiB)로 늘었다. 실제 삭제량과 남은 공간은 [cleanup receipt](../report/assets/task_m900_584/stage2/storage-cleanup.json)에 기록한다. 공개 후보 DMG나 백업은 삭제하지 않는다.

## 인계와 다음 승인

- [부분 최종 보고](../report/task_m900_584_report.md), [PR 본문](task_m900_584_pr_draft.md), [릴리즈 후보 기록](../release/v0.2.3.md).
- [검증 증거](../report/assets/task_m900_584/stage2/validation.json), [built 제품](../report/assets/task_m900_584/stage2/built-products.json), [checksum](../report/assets/task_m900_584/stage2/SHA256SUMS).
- [Mac 안내 화면](../report/assets/task_m900_584/stage2/fonts-desktop.jpg), [릴리즈 노트 화면](../report/assets/task_m900_584/stage2/release-desktop.jpg). 로컬 미리보기 http://127.0.0.1:3569/fonts/ 및 /updates/v0.2.3.html은 미공개 후보다.

다음 승인 대상은 구체 local commit의 publish/task584 push와 devel 대상 Open 준비 PR이다. 실제 PR CI·fresh review·병합 승인 후 Stage 3의 main 인계·tag·고정 DMG·ARM/Intel VM으로 이어간다. #480/#525 최종 앱 수용, 실제 Mac/업데이트·Homebrew는 이후 gate이며 #584 이슈를 닫지 않는다.
