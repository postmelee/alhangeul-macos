# Task M020 #568 — Stage 5 Quick Look·Thumbnail 글꼴 공급 수용

- 이슈: [#568](https://github.com/postmelee/alhangeul-macos/issues/568), 부모 #562, M020/v0.2.
- 작업: `local/task568`, core/Studio v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f` 유지.
- 승인: Stage 5 “진행해줘”, 2026-10-10 Developer ID 로컬 서명·기존 앱 보존/임시 Finder 시험/복원, 키체인 인증 완료.
- 상태: Stage 5 완료. 원래 설치본 복원·이번 등록 정리 완료. Stage 6와 최종 PR/공개 기여는 후속 승인 단계다.

## 1. 결과와 변경

Quick Look/Thumbnail이 각자의 CoreText 목록·실제 권한으로 필요한 글꼴을 읽고, Stage 4의 공식 matcher·PS/style/hash 검증·bytes context를 사용하도록 연결했다. HostApp의 bookmark는 공유하지 않는다. Release의 기존 CoreGraphics 기본 정책을 유지하며 공통 PNG의 Skia decode/direct는 unsigned 격리 시험으로 검증했다. 새 Rust ABI/core pin 변경은 없다.

Foundation/CoreText 서비스 9개를 `HostApp/Services`에서 `Shared/FontLibrary`로 이동하고 `project.yml` 및 probe의 소스 목록을 갱신했다. `RhwpCoreBridge`의 AppKit/UIKit 금지 경계를 유지했다. 공유 설정은 version/installedEnabled/revision만 담으며 private 설정 저장과 게시 사이의 중단은 pending marker로 차단한다.

실제 signed 시험에서 중요한 권한 차이를 발견했다. 일반 sandbox fixture helper는 성공했지만 Quick Look/Thumbnail은 App Group lock의 쓰기 모드 열기를 거부했다. [kernel 거부 기록](assets/task_m020_568_stage5/signed-initial-denials.txt)의 `file-write-data .../consumer-policy/lock`과 `FontLibraryError:io(1)`을 대조했고, 첫 두 실행의 기본 글꼴 결과를 성공으로 합산하지 않았다. 매 실행 원래 앱을 복원한 뒤 읽기 전용 소비자를 보정했다.

- 설정 읽기는 기존 lock의 O_RDONLY/shared lock만 사용하고 파일/디렉터리를 만들지 않는다. 없는 설정은 기본 false다.
- 확장 관리 snapshot은 디스크 lease를 만들지 않고 FD 수명을 소유한다. 필요한 object의 실제 읽기 동안만 기존 library lock의 shared flock으로 writer/GC를 막는다. 선택/세대/크기/hash를 잠금 아래 검증하고, 읽기 사이의 변경은 stale로 폐기한다. HostApp의 디스크 lease와 GC는 유지한다.
- 기존 document context를 사용해 Quick Look의 외부 이미지 주입을 보존했다. Thumbnail은 기존 bytes-only 입력 정책을 유지한다.
- 공급 실패는 기본 CoreText 글꼴로 명시적으로 대체한다. 원래 이름의 OS/Skia 조회로 거부를 우회하지 않는다. stale/취소는 결과를 폐기한다. 실제 I/O 종료 후 snapshot을 한 번 해제한다.
- Thumbnail은 설정/관리/설치 원본 stamp와 문서 inode/ctime를 cache identity에 포함한다. 동일 작업을 합치고 exact/larger hit도 새 snapshot을 확인한다. 대체 bitmap은 보관하지 않으며 render 2건·준비 16건·96항목/64 MiB bitmap 한도를 유지한다.

## 2. 실제 signed Finder 수용

최종 후보는 `signed-candidate-03`, 고유 보관함 UUID `86066D3B-F312-4F45-A5D6-69D88D012CB0`다. 기존 `Developer ID Application: Taegyu Lee (XH6JHKYXV8)`와 App Group `XH6JHKYXV8.com.postmelee.alhangeul.font-library`를 사용했다. probe compile flag와 UUID Info marker로 보관함을 격리했고 HostApp을 실행하지 않았다. 기존 사용자 설정/원본 글꼴/문서는 변경하지 않았다.

표준 `smoke-clean-quicklook-install.sh`의 preserve-signature/scoped-registrations/skip-global-reset 옵션으로 `/Applications/Alhangeul.app`에 잠시 설치했다. 실제 provider 경로·코드 서명·프로세스 로그와 Finder 화면을 대조했다.

| 시험 | Thumbnail | Quick Look |
|------|-----------|------------|
| 고운바탕 Regular/Bold 관리 복사본 | HWP/HWPX에서 두 PS 선택, 공급 대체 없음 | HWP/HWPX PNG 및 2페이지 PDF의 양쪽 페이지에서 두 PS 선택, 공급 대체 없음 |
| 실제 Mac 설치 ArialUnicodeMS | 실제 원본 읽기와 정확한 PS 적용 | PNG에서 실제 원본 읽기와 정확한 PS 적용 |
| 설치 사용 false | 같은 경로 재요청에서 이전 cache를 쓰지 않고 기본 글꼴 대체 | 새 시험 문서에서 기본 글꼴 대체. 관리 복사본 공급은 유지 |
| 고유 관리 object 한 개 삭제 | 같은 문서 cache miss, `corruptObject` 대체. 대체 결과 미보관 | 2페이지 전체 기본 대체, 양쪽 페이지에 실패 분류 기록 |
| object 복구·설정 복구 | 같은 경로 cache miss와 정확한 face 복구. 생성 PNG는 최초 성공 PNG와 byte 일치 | 새 프로세스에서 관리/설치 face 모두 다시 적용 |
| 실제 확장 재실행 | PID 52517 → 56552, 새 요청 성공 | PID 52692 → 59467, 새 요청 성공 |
| cache 재요청 | 실제 `qlmanage -t -x`의 exactHit 2회·largerBucketHit 및 Finder 목록의 작은 bucket 재사용 | Quick Look의 출력은 영구 font bytes cache를 만들지 않음 |

고운바탕은 #567에서 승인·다운로드한 OFL Regular/Bold 두 파일이다. 사용자 Mac에 영구 설치된 고운바탕으로 표현하지 않는다. ArialUnicodeMS는 현재 OS에서 실제 활성인 원본이며 사용자 파일을 복사해 설치하거나 설정을 변경하지 않았다. 일부 OS 글꼴의 기존 inspector 제한은 유지한다.

실제 Quick Look 단일/2페이지 화면과 두 번째 페이지 전환을 UI 도구로 확인하고 스크린샷을 대화에 제시했다. 설치본 복원 후에는 보존한 [HWPX 결과](assets/task_m020_568_stage5/finder-hwpx.png), [HWP 결과](assets/task_m020_568_stage5/finder-hwp.png), [설치 원본 결과](assets/task_m020_568_stage5/finder-installed.png), [관리 원본 상실 결과](assets/task_m020_568_stage5/finder-missing-managed-fallback.png)를 확인한다. [signed 로그](assets/task_m020_568_stage5/signed-font-events.json), [요약](assets/task_m020_568_stage5/signed-summary.json), 소스·executable hash와 [SHA256SUMS](assets/task_m020_568_stage5/SHA256SUMS)를 함께 보존했다. 실제 signed Quick Look PDF의 디스크 복사본을 확보했다는 뜻은 아니다.

## 3. 회귀·성능·범위

- FontLibraryTests **133건**, HostAppTests **237건**, 실패 0. 읽기 전용 권한/디스크 생성 없음·metadata 원본 선읽기 없음·삭제/GC 후 stale·빈 보관함 3건을 추가했다. 기존 pending 시험은 reader가 저장소를 생성하지 않는 계약에 맞춰 publisher로 장애 fixture를 준비한다.
- 공통 unsigned 공급/렌더/cache 시험 통과: PNG CG/Skia decode/direct, 2페이지 PDF, 권한 거부 대체, stale 폐기, exact/larger, 설정/원본 stamp·문서 inode/ctime, 2건 I/O/추가 busy와 exactly-once release. [최종 읽기 전용 결과](assets/task_m020_568_stage5/readonly-result.json) 및 앞선 admission gate 결과를 구분한다.
- Stage 4 실제 Mac 공급/native CG·Skia 회귀와 기존 Thumbnail baseline 8회 렌더 통과. renderer 변경 없는 기존 Rust/golden 기준은 재사용했다.
- 일반 Release 및 최종 probe Release의 HostApp/두 확장 compile/link 통과. project는 `project.yml`로 재생성했다. no-AppKit, pinned matcher/Studio receipt와 diff 검사 통과.
- actual metadata 로그 32건: 최소 **454 ms**, 중앙값 **1,090 ms**, 최대 **2,949 ms**. 단일 요청의 전체 scan/stat는 보통 약 1초이며 동시 요청 대기가 포함된 경우 더 길다. cache hit에도 발생한다. 렌더 진단의 renderMs와 공급 준비 시간을 합산하지 않고 구분한다. 전체 catalog 반복 탐색을 줄이는 후속 최적화 후보를 Stage 6에 인계한다.

실제 환경은 arm64/macOS 26.5.2(25F84)다. macOS 12 target compile을 실제 macOS 12/Intel 실행으로 표현하지 않는다. static SFNT·정확한 스타일과 Stage 4의 제한된 glyph replay 범위를 유지하며 전체 pagination/complex shaping을 보증하지 않는다. 2페이지 PDF는 같은 두 face를 페이지별로 읽어 4회 읽는다. font bytes/budget/bitmap 제한은 전체 프로세스 peak 메모리 측정이 아니다.

same-path `qlmanage -t -x`와 실제 확장 cache 갱신을 확인했다. Finder/OS가 요청 자체를 보내지 않는 경우의 영구 thumbnail cache 자동 갱신과 이미 열려 있는 Quick Look 창의 즉시 재표시는 보증하지 않는다. 전역 cache reset이나 원본 문서 mtime 변경으로 시험을 통과시키지 않았다. 초기에 `-x`를 빠뜨린 수동 qlmanage 요청의 timeout은 표준 확장 시험으로 합산하지 않는다.

## 4. 복원·정리와 다음 단계

최종 복원에서 설치본 152개 파일/링크를 원래 백업과 전부 대조해 일치를 확인했다. 원래 Info SHA256은 `41f64c73e4d2848e2b8d34d4b3a1954e0645121072074f5d299929b5d52279a7`이다. 서명 검증과 [복원 receipt](assets/task_m020_568_stage5/restore-verification.json)를 보존했다. 고유 group 하위 fixture는 삭제했고 이번 확장·앱/helper 등록만 해제했다. 설치 provider는 `/Applications/Alhangeul.app`이며 전역 reset·다른 작업의 등록 변경은 없다.

복원 후 중복 후보/백업/staging 앱·helper cache를 정리했다. [정리 기록](assets/task_m020_568_stage5/cleanup.json)의 논리 파일 크기 합계는 **3,416,632,974 bytes**다. 앞선 unsigned 정리 866,676,388 bytes와 구분하며 APFS 실제 가용 공간 증가량으로 단정하지 않는다. 자동 재등록이 남는 최종 임시 앱/fixture도 제거했다. 다음 단계용 Xcode 중간 산출물·검증 결과·소스/서명 hash와 재현 script를 남겼다.

Stage 6에서 소비자별 최종 회귀·지원 경계·미검증 환경·#566/#569 인계를 취합한다. 탐색 비용과 OS cache 자동 갱신 경계도 그 인계에 포함한다. upstream 후보는 Stage 4의 일반적인 bytes/스타일/slot 연결에서 추리며 macOS 전용 App Group/Quick Look 운영을 그대로 제안하지 않는다. 현재 PR/push/공개 기여·배포는 수행하지 않았다.
