# Task M900 #584 Stage 4 최종 DMG Mac 시험·복원 준비안

## 현재 상태와 실행 경계

**준비안 / 실제 Mac 설치·설정 변경·시험 미승인·미실행.** [구현계획 §5](../plans/task_m900_584_impl.md)의 최종 일반 앱 수용과 원상복원 절차를 구체화한다. [Stage 3](task_m900_584_stage3.md)의 양 VM 결과를 수용하고 아래 실제 Mac 범위를 승인받은 뒤 실행한다. 양 VM 수용은 [38185285770](https://github.com/postmelee/alhangeul-macos/actions/runs/38185285770)에서 schema 3 PASS이며 source·DMG·양 install/verdict·snapshot·lifecycle/cleanup을 대조했다. 첫 run 38184399238의 ARM 환경 실패는 별도로 보존했다. 아직 실행하지 않은 실제 Mac 결과를 PASS로 표시하지 않는다.

## 고정 후보·기존 앱·소유 문서

| 항목 | 준비한 대상 |
|------|-------------|
| 원본 DMG | build.noindex/task584/stage3/publish/candidate/alhangeul-macos-0.2.3.dmg |
| SHA256 / size | d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63 / 211405232 bytes |
| source / publish artifact | c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 / 11717953850 |
| 후보 | 일반 0.2.3 / build 21, 기존 Developer ID 서명·공증 완료. 로컬 재서명·bundle/Info 수정·진단 flag 주입 없음 |
| 기존 설치 대상 | /Applications/Alhangeul.app, 0.2.2 / build 20. 사전 조사 당시 실행 프로세스 없음 |
| 기존 앱 백업 예정 | build.noindex/task584/stage4/original-backup/Alhangeul.app, 아직 복사하지 않음 |
| 원본 inventory | 파일·symlink·mode·mtime 243개, 파일 bytes 총 446248370. 조사 시 deep/strict seal PASS |
| 소유 시험 문서 | build.noindex/task584/stage4/owned-documents/F779350F-3DE4-4E94-B7C2-A16578D1BA26의 font-single.hwp, font-single.hwpx, font-two.hwpx |
| 저장/복구 소유 문서 | 같은 경로의 protected.hwpx, legacy-hwp3.hwp, recovery-owned.hwpx. 이번 VM fixture artifact 11718713502에서 확보 |
| 시험 글꼴 | 기존 /Library/Fonts/NanumSquareRegular.ttf 및 NanumSquareBold.ttf. 읽기만 사용, OS 설치·삭제 없음 |

[기존 앱 조사](../report/assets/task_m900_584/stage4/preparation/original-app-summary.json), [복원 inventory](../report/assets/task_m900_584/stage4/preparation/original-app-inventory.json), [소유 문서 hash](../report/assets/task_m900_584/stage4/preparation/owned-documents.json), [글꼴·설정 경계](../report/assets/task_m900_584/stage4/preparation/font-settings-preparation.json)를 보존한다. 글꼴 시험 문서는 #569의 소유 합성 문서를 새 UUID 경로로 복사한 것이며, 새 앱에 #569의 진단 보관함/UUID를 주입하는 것은 아니다. 추가 문서 3개는 이번 후보 source의 VM fixture다. 저장/PDF 복사본도 이 경로 아래에 만든다.

## 임시 설치와 공간 사용

1. 실행 직전 실제 설치 버전·실행 여부·원본 inventory를 다시 확인한다. 원래 앱이나 사용자의 작업 상태가 달라졌다면 이전 상태를 가정해 덮어쓰지 않는다.
2. 원래 앱을 ditto의 resource fork·extended attribute·ACL 보존 방식으로 위 백업 경로에 복사한다. 파일 hash·mode·symlink 및 strict seal이 원래 앱과 일치해야 교체한다. 백업은 복원 검증 전 삭제하지 않는다.
3. 동일 DMG를 build.noindex/task584/stage4/source-mount에 읽기 전용으로 mount한다. 표준 helper의 staging 복사본을 사용해 별도 후보 앱 복사를 줄인다. 원본 DMG bytes와 서명을 유지한다.
4. 아래 표준 절차로 승인된 앱 경로만 교체하고 새 경로의 Finder 샘플을 만든다. 다른 앱 등록·전역 캐시·사용자 OS 글꼴은 변경하지 않는다. helper의 backup/restore 기능을 가정하지 않는다.

```sh
scripts/smoke-clean-quicklook-install.sh \
  --version 0.2.3 \
  --app build.noindex/task584/stage4/source-mount/Alhangeul.app \
  --install-app /Applications/Alhangeul.app \
  --replace-applications-install --preserve-signature \
  --scoped-registrations --skip-global-reset \
  --output-dir build.noindex/task584/stage4/finder-results \
  --sample build.noindex/task584/stage4/owned-documents/F779350F-3DE4-4E94-B7C2-A16578D1BA26/font-single.hwp \
  --sample build.noindex/task584/stage4/owned-documents/F779350F-3DE4-4E94-B7C2-A16578D1BA26/font-single.hwpx \
  --sample build.noindex/task584/stage4/owned-documents/F779350F-3DE4-4E94-B7C2-A16578D1BA26/font-two.hwpx
```

helper는 staging과 설치 경로에만 app을 복사하며 --preserve-signature에서 재서명하지 않는다. staging·원본 백업 공간을 우선 확보하고 실행 직전 여유 공간을 다시 확인한다. 사전 조사의 가용 공간은 약 6.9GiB이며 추가 로컬 Rust/Xcode 빌드·DMG 재생성·ZIP 중복 보존은 하지 않는다. Home의 별도 Alhangeul.app이 발견되면 자동 삭제하지 않고 충돌을 보고한다.

## 글꼴 설정·권한과 수용 동선

- 설정(⌘,) → 글꼴에서 Mac 설치 글꼴 ON/OFF와 실제 목록을 확인한다. 기존 시스템 글꼴 목록에서 NanumSquare Regular/Bold를 선택하고 감지 count는 실제 관측값으로 기록한다.
- 기존 설치 글꼴 파일의 읽기만 사용한다. 새 권한이 필요하면 표시된 폴더와 읽기 범위를 구체화한다. 보관함 import/delete·원본 글꼴 mutation은 이번 계획에 없다.
- 일반 앱의 HWP/HWPX 편집 → 소유 복사본 저장 → 재열기 → 새 프로세스의 설정 유지, PDF 저장·font/ToUnicode/텍스트/화면, macOS 인쇄 패널 열기·취소를 각각 기록한다. 진단 alias 저장이나 실제 프린터 전송은 하지 않는다.
- Finder의 single/multiple Quick Look·Thumbnail과 실제 provider 경로, 소유 문서의 Spotlight 본문 검색 및 앱 종료 후 검색을 구분해 확인한다. 자동 helper 추출 결과를 실제 UI 확인으로 바꾸지 않는다.
- #480 보호 원본의 경고·취소·hash 보존과 #525 소유 문서의 저장/닫기·복구 한계를 [수용표](../tech/task_m900_584_release_acceptance.md)에 기록한다. 보호 fixture는 이번 고정 source의 VM 생성 artifact에서 확보했고 합성 시험 암호는 test-only-spotlight다. 사용자 보호 문서를 사용하거나 암호를 요구하지 않는다. 기존 사용자 복구 항목은 조작하지 않는다.
- Help의 정확한 /fonts/ URL과 아직 미공개인 안내 상태를 구분한다. macOS 12·Intel 실기기 GUI·한컴 실제 삭제·물리 인쇄·Sparkle 업데이트는 이 Mac 시험의 PASS로 확대하지 않는다.

개인 설치 글꼴 목록은 HostApp container의 Alhangeul/InstalledFonts/installed-fonts-v1.json, 공유 ON/OFF policy는 App Group FontLibrary/v1/consumer-policy에 있다. 사전 조사에서는 두 JSON과 pending이 없었다. 실행 직전 존재 여부·원래 enabled·권한 grant와 hash를 다시 확인하고 **해당 파일만** 비공개 백업한다. bookmark나 사용자 목록 원문은 공개 증거에 넣지 않는다. 테스트로 생긴 항목만 정리하고 원래 설정/부재 상태를 복원한다. 전체 preferences·보관함·container 초기화는 하지 않는다.

## 실패 시에도 적용할 원상복원

1. 시험 앱과 시험 문서만 닫고, 신규 저장 파일/복구 후보의 소유 경로를 대조한다. 다른 사용자 문서나 기존 복구 항목은 건드리지 않는다.
2. 바꾼 설치 글꼴 설정을 원래 값으로 돌린 뒤 앱을 종료한다. 위 두 저장 파일의 원래 bytes/부재 상태를 필요한 범위에서 복원한다. 테스트 최근 문서의 정리도 소유 경로와 관련 key로 한정한다.
3. candidate와 owned staging의 QL/Thumbnail/LaunchServices 등록만 해제한다. 원래 앱 백업으로 /Applications/Alhangeul.app을 복원하고 그 경로의 기존 등록과 active provider를 확인한다. 전역 qlmanage cache reset이나 다른 앱 등록 제거는 하지 않는다.
4. 복원된 0.2.2/20의 파일 hash·mode·symlink·서명 및 설정의 원래 상태를 확인한다. 시험 mount·창·소유 출력 등록을 정리하고 원본 DMG hash 유지도 확인한다.
5. 복원 PASS 이후 staging/백업 중 더 필요 없는 app 복사본을 정리한다. 최소 증거·실패 원문·다운로드 원본 DMG는 보존한다.

원시 실패와 복원 실패를 성공으로 덮어쓰지 않는다. 실제 시험·복원 PASS와 공개 전 한계 수용을 확인하기 전에는 Stage 4 완료나 #584 완료로 표시하지 않는다. 공개 Release·Pages/Sparkle·Homebrew는 이후 별도 승인 대상이다.
