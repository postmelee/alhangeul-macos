# Task M020 #568 — Finder 글꼴 공급·검증 계약

- 이슈: [#568](https://github.com/postmelee/alhangeul-macos/issues/568), M020
- 승인: 2026-10-09 “진행해줘”로 Stage 5 소스 연결·격리 검증 준비 승인
- 상태: 2026-10-10 소스·unsigned·signed Finder 수용 및 기존 앱 복원 완료. 최종 결과는 [Stage 5 보고서](../working/task_m020_568_stage5.md)를 따른다. 아래는 준비·진단 경계와 실행 계약이다.

## 소비자와 권한

`InstalledFontCatalogService`, `FontLibraryService`, `StudioFontSupply`와 필요한 Foundation/CoreText 모델은 `Shared/FontLibrary`로 이동했다. HostApp의 기존 provider/script/menu 경로는 유지한다. `RhwpCoreBridge`에는 AppKit 의존을 추가하지 않았다.

HostApp private `installed-fonts-v1.json`은 원본/권한 저장소다. App Group의 `consumer-policy/policy.json`에는 version·installedEnabled·revision만 게시한다. bookmark/원본 목록·경로는 게시하지 않는다. private 저장 전 pending marker를 만들고, private 저장과 공유 JSON 게시를 완료한 뒤 marker를 지운다. 실패/프로세스 종료의 pending·잘못된 JSON·잠금 경합은 이전 enabled 상태를 허가 근거로 사용하지 않는다. HostApp 재시작에서 private 상태를 읽어 복구한다. 일반 metadata 갱신은 설정 revision을 바꾸지 않는다.

Quick Look과 Thumbnail에 동일 App Group entitlement/Info 설정을 추가했다. `ExtensionFontSupply`는 확장 프로세스의 CoreText 목록을 직접 스캔하고 grants 없는 자체 catalog로 읽는다. HostApp bookmark를 가져오지 않는다. 각 요청의 cache 조회 전 metadata 목록·원본 inode/size/mtime/ctime·설정 revision·관리 generation/digest를 확인한다. metadata 단계에서 font bytes를 미리 읽지 않는다. 실제 읽기는 기존 FD·활성 face·실제 bytes/hash 검증을 사용한다. 전체 목록 스캔과 반복 stat의 실제 signed 소비자 비용은 다음 시험에서 측정한다.

관리 snapshot은 확장의 읽기 전용 store 경로를 사용한다. 실제 Quick Look/Thumbnail sandbox는 App Group의 `consumer-policy/lock`을 쓰기 모드로 여는 요청을 EPERM으로 거부했다. 설정 읽기는 기존 lock을 O_RDONLY/shared lock으로 열고, 파일/디렉터리를 만들지 않는다. 관리 metadata snapshot도 디스크 lease를 만들지 않고 FD 수명만 소유한다. 선택된 object를 읽는 동안 기존 `library.lock`의 짧은 shared lock으로 writer/GC를 막고, 잠금 아래에서 선택/세대와 실제 hash를 검증한다. 읽기 사이에 변경·삭제·회수가 있으면 stale로 폐기한다. 렌더 동안 장기 잠금을 유지하거나 HostApp 쓰기를 막지 않는다. snapshot FD는 실제 읽기 종료 후 한 번 닫으며 프로세스 종료 시 kernel이 닫는다. HostApp의 기존 디스크 lease/회수 정책은 유지한다.

## 렌더·수명·캐시

`HwpNativeFontPageRenderer.withPreparedPage/preparePage`는 외부 이미지가 주입된 기존 document를 유지한다. PNG의 CoreGraphics/Skia decode/direct 경로와 여러 페이지 PDF를 연결했다. Thumbnail은 기존 bytes-only 열기 정책을 유지하며 Quick Look처럼 외부 이미지 폴더를 새로 탐색하지 않는다. PDF는 한 snapshot의 lease를 전체 페이지에서 유지하고, 페이지별 context를 만들고 해제한다. 재사용할 영구 font bytes cache는 없다. 2페이지 fixture에서는 같은 두 face를 페이지별로 읽어 총 4회 읽었다. 다음 최적화 후보이며 전체 프로세스 메모리 한도를 뜻하지 않는다.

공급 실패의 대체 결과는 기본 CoreText face를 명시적으로 사용한다. 원래 이름의 OS 조회나 이전 Skia 경로로 거부된 원본을 다시 사용하지 않는다. 선택 충돌·지원하지 않는 형식/스타일·읽기 거부 등은 대체로 기록한다. stale/취소는 결과를 반환하지 않고 actual I/O 종료 후 snapshot을 한 번 해제한다. 실제 선택 ID/PS/hash는 Stage 4의 동일 계약을 따른다.

Thumbnail은 font snapshot과 문서의 inode/ctime를 cache key에 추가했다. 같은 key의 진행 중 작업을 합치며 exact/larger bucket hit에도 새 snapshot을 검증·해제한다. 공급 실패의 대체 bitmap은 cache하지 않는다. 동시 font render 2건·준비/대기 요청 16건을 넘으면 busy로 반환하며 무제한 문서/lease 대기를 만들지 않는다. 최대 96항목·bitmap 합계 64 MiB로 제한한다. 글꼴 한도(64 face·64 MiB/file·128 MiB 유지 bytes)와 전체 프로세스 peak 메모리는 구분한다.

이 cache는 앱 내부 cache다. Finder/macOS가 이미 보관한 동일 문서의 thumbnail 자동 갱신까지 검증됐다는 뜻이 아니다. 다음 시험에서 동일 경로와 fresh 경로를 각각 확인한다. 원본 문서의 mtime 변경이나 전역 cache reset을 자동 해결책으로 사용하지 않는다.

## 현재 검증

2026-10-10 최종 보정: shared policy read는 shared lock, 게시만 exclusive lock을 사용한다. 두 동시 요청의 정상 읽기를 변경으로 오인하던 경합을 제거했다. 추가 요청의 실제 bytes 선읽기 없이 busy 반환·실제 I/O 후 lease 해제를 확인했다.

첫 signed Finder 시험은 기본 글꼴 대체로 실패했다. App Group 조회 성공과 helper 앱 성공을 실제 확장 접근 성공으로 해석하지 않았다. 두 번째 시험에서 macOS kernel의 `file-write-data .../consumer-policy/lock` 거부와 `FontLibraryError:io(1)`을 대조했다. 두 실행 모두 원래 설치본을 복원했다. 읽기 전용 보정 후 세 번째 후보에서 실제 두 확장의 설치/관리·설정/원본 변화·재실행을 수용했다. 이전 실패는 성공으로 합산하지 않는다.

- `scripts/test-font-library.sh`: 최종 133건, 실패 0. 설정 공유/원본 권한 비공유·pending 복구·설정/관리 원본 변화와 읽기 전용 권한/삭제/빈 보관함 회귀 추가.
- `scripts/probe-extension-fonts.py`: 실제 고운바탕 Regular/Bold bytes를 private store에 복사해 PNG 세 모드·2페이지 PDF·Thumbnail exact/larger cache·설정 revision·같은 크기/mtime의 원본 inode/ctime 변화·권한 거부 대체·stale 폐기를 통과했다. CLI는 자체 catalog 환경의 빈 installed 목록을 주입했다. 실제 extension 권한 성공으로 합산하지 않는다.
- `scripts/probe-native-font-supply.py`: Stage 4 실제 Mac 설치 참조 ArialUnicodeMS, process-scope 고운바탕·관리 복사본, CG/Skia·충돌·원본/설정/문서 변화·취소/lease/budget/한도 회귀를 통과했다. OS 영구 설치는 하지 않았다.
- HostApp 전체 회귀: 237건, 실패 0. 사라진 print 함수명을 경계로 쓰던 기존 PDF bridge 테스트를 현재 다음 함수 경계로 보정했다. importer 경로 시험에는 실제 Release 빌드 앱을 테스트 산출물 옆으로 연결했다.
- 기존 thumbnail baseline: 8회 렌더·실패 0, CG/Skia cache hit/larger bucket 유지.
- 일반 Release와 probe flag Release의 HostApp/Quick Look/Thumbnail compile/link 통과. macOS 12 target, arm64 실행. 실제 macOS 12/Intel 실행은 미확보다.
- pinned native matcher·Studio receipt 검증 통과. core/Studio v0.8.7·기존 ABI 유지.

재현:

```bash
python3 Tests/ExtensionFontProbe/prepare_fixture.py build.noindex/task568/stage3/fixtures/gowun-document.hwpx build.noindex/task568/stage5/probe-inputs/multiple-two.hwpx
python3 scripts/probe-extension-fonts.py --output build.noindex/task568/stage5/extension-probe-new
```

이미 존재하는 fixture/output 경로에는 덮어쓰지 않는다. 원본은 Stage 3 합성 문서와 #567 고운바탕 다운로드 receipt/OFL을 따른다. 실행 결과의 최소 증거는 `mydocs/working/assets/task_m020_568_stage5/`에 보존한다.

## 구체 서명·설치 시험 준비

후보: `build.noindex/task568/stage5/signed-candidate/Alhangeul.app`, `FontExtensionFixtureProbe.app`.

- 고유 보관함 ID: `1035F10C-B5BC-42E2-8272-BAEC90936C30`.
- 팀/그룹: `XH6JHKYXV8.com.postmelee.alhangeul.font-library`.
- `ALHANGEUL_FONT_EXTENSION_PROBE` 전용 compile flag와 UUID Info marker가 일치할 때만 group의 `FontLibrary/v1/extension-probes/<UUID>`를 사용한다. 일반 제품에는 이 경로가 컴파일되지 않는다. HostApp을 실행하더라도 private 설정은 UUID 하위 경로를 사용한다.
- fixture helper는 App Group/sandbox 권한만 가진다. 앱 resources에 포함한 허가된 고운바탕 두 파일만 private 보관함에 복사하고, installed 사용 flag를 바꾼다. 사용자 폴더 선택이나 기존 bookmark 사용은 없다. 기존 보관함/설정은 수정하지 않는다.
- 승인할 인증서: `Developer ID Application: Taegyu Lee (XH6JHKYXV8)`. 후보·fixture와 후보 내부 framework/importer/extensions만 로컬 서명한다. 공증·업로드·DMG·공개 배포는 없다.
- 설치 대상: `/Applications/Alhangeul.app` 하나. 실행 중인 HostApp/Quick Look preview가 있으면 먼저 교체를 중단한다. 창 없이 남는 Thumbnail worker는 백업 후 설치 대상의 정확한 executable 경로에 해당하는 PID만 SIGTERM으로 종료한다. 종료되지 않으면 교체하지 않는다. 기존 설치본을 후보의 `backup/Alhangeul.app`에 보존·seal/Info identity 검증 후 교체한다.
- 표준 `smoke-clean-quicklook-install.sh`의 새 `--preserve-signature --scoped-registrations --skip-global-reset` 옵션을 사용한다. ad-hoc 재서명·다른 개발 등록 정리·전역 daemon kill·전역 cache reset을 생략한다. fresh 합성 HWP/HWPX·2페이지·실제 설치 ArialUnicodeMS 요청을 사용한다.
- actual Quick Look/Thumbnail 로그의 선택 face/identity/fallback, signed App Group 원본 접근, cache/재요청·변경·재실행을 소비자별로 확인한다. 실제 Finder 창/스크린샷과 사용자가 조작할 경로를 제공한다.
- 완료/실패 후 같은 실행의 `--mode restore`로 원래 설치본을 복원하고 private fixture/소유 등록을 정리한다. 다른 작업이 설치본을 바꾸면 덮어쓰지 않는다. 기존 앱 사용자 설정·문서는 변경하지 않는다. 백업과 산출물 삭제는 복원/등록 위생 확인 후 수행한다.

위 경로는 최초 준비 당시 기록이다. 재현에는 probe flag로 빌드한 앱과 새 후보 경로를 사용한다. 다음 명령의 로컬 서명/설치는 **해당 실행 승인 후에만** 수행한다.

```bash
python3 scripts/prepare-extension-font-smoke.py --output build.noindex/task568/stage5/signed-new --built-app <probe-flag-Release-app>
PROBE_SIGN_ID='Developer ID Application: Taegyu Lee (XH6JHKYXV8)' python3 scripts/extension-font-finder-smoke.py --candidate-dir build.noindex/task568/stage5/signed-new --mode sign
python3 scripts/extension-font-finder-smoke.py --candidate-dir build.noindex/task568/stage5/signed-new --mode install
python3 scripts/extension-font-finder-smoke.py --candidate-dir build.noindex/task568/stage5/signed-new --mode restore
```

최종 후보는 `signed-candidate-03`, UUID `86066D3B-F312-4F45-A5D6-69D88D012CB0`다. 세 번째 후보의 signed 수용·설치본 복원과 소유 등록 정리를 완료했다. Stage 6, 공개 upstream 기여·push/PR은 후속 승인 단계다.
