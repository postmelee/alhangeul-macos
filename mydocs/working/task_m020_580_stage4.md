# Task M020 #580 — Stage 4 재측정·복원 및 성능 보완 근거

- 이슈: [#580](https://github.com/postmelee/alhangeul-macos/issues/580), 상위 #562, 후속 #569.
- 계획: [구현계획](../plans/task_m020_580_impl.md), [확정 계약](../tech/task_m020_580_extension_font_contract.md).
- 기준 커밋: `36184af0c22a12784a31e2499cec848210e8fae0` (Stage 3), 브랜치 `local/task580`.
- 승인: Stage 3 보고 후 “진행해줘.” 지시로 Stage 4 직접 재측정·후보 준비를 승인받았다. 아래 고정 후보에 대해 2026-10-11 “로컬 서명·임시 Finder 시험·원상복원 허용” 승인을 받아 시험했다. 공간 확보 지시도 유지한다.
- 판정: **두 후보의 서명 시험·원상복원 완료, Stage 4 미완료.** 첫 후보의 정상 썸네일 요청 186건 busy는 0이나 설치 글꼴 ON 시간 목표는 미달이었다. 2026-10-11 승인받은 Stage 4.2 보완·직접 검증·새 후보 준비를 완료했다(§9). 아래 1~8은 보완 전 Stage 4.1 기준이다. 새 후보의 실제 Finder GUI/Preview도 확인했다(§10). ON 시간 목표가 여전히 미달이므로 부모 Stage 4 완료 커밋·Stage 5·PR로 넘기지 않는다.

## 1. Stage 4.1 고정 소스의 직접 비교

동일 source receipt·HWP/HWPX·OFL Gowun Batang·OFF/ON workload를 비최적화와 `swiftc -O`로 각각 실행했다. 각 14개 새 프로세스·650개 시간 표본이며 정상 consumer는 OFF/ON 각각 288건, 모두 success/busy 0이다. 관리 객체 삭제의 예상된 명시적 fallback 및 의도적인 17번째 접수 busy는 별도 proof로 보존한다.

HWP/HWPX의 warm exactHit 표본을 각 조건 40건씩 집계한 중앙값:

| 직접 CLI 조건 | metadata (ms) | 전체 요청 (ms) | hit bytes 읽기 |
|------|------:|------:|------:|
| 비최적화 OFF | 9.382 | 16.474 | 0 |
| 비최적화 ON | 214.733 | 427.190 | 0 |
| `-O` OFF | 2.137 | 4.063 | 0 |
| `-O` ON | 150.217 | 299.840 | 0 |

순차·동시 4건·동시 최대 10건의 10파일×3 pass, exact/larger hit, PNG/단일·다중 PDF의 정확한 Regular/Bold·한 snapshot/페이지별 처리·획득/해제 proof를 유지했다. ON은 프로세스 최초 full scan 1회, 동일 세대 반복 full scan 0이며 OFF는 full scan 0이다. 최적화 signature 진단 경로도 별도 2회/22건을 통과했다.

이 표는 **unsigned 직접 호출**이다. signed 목표인 각 조건 10건 이상의 warm metadata <200ms/provider <300ms 달성으로 판정하지 않는다. 특히 `-O` ON 전체 중앙값은 목표에 가까우며 HWPX만의 중앙값은 307.877ms였다. 비최적화 ON은 이전 Stage 2/3보다 느렸고 시스템 부하·CoreText 상태를 완전히 통제한 실험이 아니므로 일부 좋은 실행만 골라 개선 수치로 삼지 않는다. 과거 #569 signed baseline과 이번 직접 값을 혼합하지 않는다.

canonical 경로는 `build.noindex/task580/stage4/direct-none-02`와 `direct-speed-05`다. [측정 증거](assets/task_m020_580_stage4/measurements.json)에 workload별 표본·상태·중첩 구간과 원시 JSON SHA를 보존한다.

## 2. 최적화 진단·회귀 보정

최적화 비교에서 진단 flag의 동기 `TaskLocal.withValue`가 GCD 관리 보관함 큐와 detached 설치 준비 worker에서 `swift_task_localValuePushImpl` 안의 SIGSEGV로 재현됐다. 글꼴 코드 없는 최소 재현과 호출 스택을 남겼다. 현재 Swift 6.3.3/arm64 환경의 관찰이며 일반적인 Swift 버그나 기본 제품 경로의 실패로 확대하지 않는다.

`ALHANGEUL_FONT_EXTENSION_PROBE` 안의 동기 경계만 thread dictionary의 짧은 context로 바꿨다. 중첩·throw·nil override 뒤 이전 상태를 복원하고 continuation resume 전에 정리한다. await를 가로질러 이 context를 유지하지 않으며 기존 async TaskLocal은 유지한다. 직접 meter도 같은 동기 request를 사용해 detached scan을 다른 요청에 귀속하지 않는다. **기본 제품 준비·현재성·대기·렌더 동작은 변경하지 않았다.**

새 `TraceContextAcceptance.swift`의 중첩/오류/nil/누출 회귀와 production PNG/CoreGraphics·Skia 두 방식·2페이지 PDF·cache/권한 fallback·취소/한도/정확히 한 번 해제를 `-O` 진단 실행에서 통과했다. 네 PNG SHA는 Stage 3 기본 회귀와 동일하다.

첫 최적화 큐 시험은 “고유 miss FIFO·동일 key는 한 번 렌더” assertion에서 중단됐다. 두 worker의 실제 read 진입 순서를 FIFO로 가정하고 참가자 접수 전에 다음 요청을 만든 시험의 문제였다. 동일 key 참가자의 공급 접수를 기다리고, 두 번째 I/O를 유지한 채 한 slot씩 열어 다음 고유 job의 FIFO를 검증하도록 보정했다. gate가 먼저 열려도 이후 진입이 놓치지 않게 했다. 제품 scheduler는 변경하지 않았다. 최종 `optimized-acceptance-03`은 전체 회귀를 통과했다.

이전 SIGSEGV·중간 scan 귀속 실패·compile 중 source 수정 거부·초기 시험 실패는 canonical 성공에서 제외하며 로그를 보존했다. 첫 LLDB 시도의 기존 private 보관함 재사용에 따른 import assertion은 원래 실패 위치의 근거로 쓰지 않는다. 새 보관함의 stack/disassembly가 실제 실패를 확인했다.

## 3. 빌드와 후보 고정

| 검증 | 결과 |
|------|------|
| 기본 HostApp Release | BUILD SUCCEEDED, 64.775초; 앱/확장 probe marker 없음 |
| 진단 flag HostApp Release | BUILD SUCCEEDED, 63.013초; 앱/확장 probe marker·요청 시간 진단 확인 |
| 최적화 확장 회귀 | PASS; 최종 source의 PNG/PDF·current·queue·trace context |
| 후보 guard | 16조건 PASS; source 내용/추가·삭제·core/asset/native/input·resource/권한/link 변화 거부, 외부 명령 mock |
| no-AppKit·matcher/Studio receipt·parser self-test·Python/shell 구문·diff check | PASS |

현재 arm64/macOS에서 실행하고 macOS 12 target으로 컴파일했다. 최소 OS/Intel 실제 실행은 하지 않았다. 기존 AppIntents 미사용 경고는 남는다. Stage 2의 공통 FontLibrary/Host 출력 XCTest는 기본 공통 동작이나 출력 구현이 바뀌지 않아 반복하지 않았다. native staticlib/헤더·core lock·Studio asset은 유지했다.

최초 후보 준비는 미서명 복사·fixture 컴파일·hash 기록만 수행했다. 구체 승인을 받은 뒤 동일 후보를 기존 Developer ID로 로컬 서명하고 고유 fixture·임시 설치 시험을 수행했다. 서명 전후 영수증을 구분한다.

| 항목 | 고정값 |
|------|------|
| 후보/fixture 폴더 | `build.noindex/task580/stage4/finder-candidate-01` |
| 시험 UUID | `02FB58C8-150B-4C37-903E-DD4C0A6B92A9` |
| 후보 build version | `580.4.1` |
| 후보 전체 unsigned inventory SHA | `2abd4f6370e7ed9430238f2d90969a1738306c3727cee86be9cc7aa3827316e5` |
| fixture 전체 unsigned inventory SHA | `3ea9b01082db2d81bb913d1c856943d87512efa0b08bbf45a0b718aa073c4372` |
| Preview image UUID | `E0356498-05F9-3131-98DC-067D7121F767` |
| Thumbnail image UUID | `353D18CA-27A8-3FDF-8122-30546E16145E` |
| 원래 설치본 | `/Applications/Alhangeul.app`, v0.2.2 |
| 원래 Info SHA | `41f64c73e4d2848e2b8d34d4b3a1954e0645121072074f5d299929b5d52279a7` |
| 원래 파일/link/권한 inventory SHA | `fa694017af3e0b3705510b353ef0e9dc5549be57493b74e99e5ca05540b3707b` (243항목) |

전체 resource까지 포함한 후보 digest와 앱/fixture/확장의 Info/executable SHA, source/fixture·core/asset/native/input SHA를 준비 영수증으로 고정했다. [후보 요약](assets/task_m020_580_stage4/candidate-preparation.json)과 원시 `preparation.json`, `operation-plan.json`을 따랐다. 서명 후 새 seal/bytes를 별도로 기록하고 임시 설치 때 다시 대조했다. signed 앱 inventory는 `9a7e2f06ba0de34f508716c680d68a769f3ac7bb469b8f07fa34c61974e14d76`, fixture는 `5da8cd887d814af74eedfc31d8e2513e1612b2c1a978a7795a43bf9d2e95effc`다. 시험 후 이 후보·fixture·staging·백업 bundle은 삭제하고 영수증과 원시 결과를 보존했다.

## 4. 승인받은 시험·복원 절차

1. 준비된 후보 앱과 fixture만 기존 Developer ID로 로컬 서명한다. timestamp 없는 격리 서명이며 공증·배포를 수행하지 않는다.
2. 실행 중인 설치본 창이 없고 원래 설치본 inventory가 준비 시점과 같은지 확인한다. 바뀌면 교체를 중단한다. 원래 앱을 후보 폴더의 `backup/Alhangeul.app`으로 복사하고 strict 서명·전체 파일/link/권한을 원본과 대조한 뒤에만 교체한다.
3. 같은 UUID의 고유 `extension-probes/<UUID>` 보관함에 OFL Regular/Bold 복사본만 만든다. 실제 사용자 보관함·사용자 글꼴 설치/비활성·Host 설정을 바꾸지 않는다.
4. 기존 표준 smoke를 해당 후보 경로에 한정해 수행한다. OFF/ON 두 독립 workload×HWP/HWPX의 256px 첫/반복 10회 및 128px 반복 10회, 10파일 폴더 반복/크기 변화와 preview 단일/2페이지를 확인한다. OS가 요청하지 않은 UI 시도는 `요청 없음`으로 남기고 실제 PID/request/image UUID의 유효 표본으로만 판단한다.
5. 고유 보관함의 정책 OFF/ON·관리 객체 삭제/복구·권한 상실/복구·관리 선택 변화/원복에서 stale 폐기와 재준비를 확인한다. 실제 설치 글꼴의 OS 변화·다른 PID·OS 취소는 관찰/직접 주입과 구분한다. 사용자 OS 글꼴을 변경하지 않는다.
6. 성공/실패 모두 원래 앱을 복원한다. 백업 seal/hash/inventory 검증, 해당 UUID 설치본 확인, 복원 후 전체 inventory·strict 서명·active provider를 대조하고 고유 보관함/후보/백업의 개발 등록만 정리한다. 다른 앱이 교체돼 있으면 자동 덮어쓰지 않는다. 전역 reset은 하지 않는다.

입력 38개 복사본과 hash·최소 표본/안전 조건은 `build.noindex/task580/stage4/signed-workload-plan.json`에 고정했다. Release는 CoreGraphics 기본으로 측정하고 Skia opt-in 정확성은 위 직접 회귀와 구분했다. 아래 결과는 이 절차 중 실제 관찰한 범위다. 목표나 표본 수를 낮추지 않는다.

## 5. signed 썸네일 시간과 다수 파일

arm64/macOS 26.5.2 (25F84)의 실제 Developer ID/sandbox Thumbnail 확장을 비UI `qlmanage -t -x`로 호출했다. 모든 대응 표본의 image UUID가 위 Thumbnail UUID와 일치한다. PID/subsystem/request/단조 구간이 대응한 표본은 212건이다. 표준 smoke 3건·순차/크기 변화 126건·최대 10개 동시 부하 60건·별도 profile 3건·관리 변경 20건을 구분한다. 정상 성능 workload **186건 모두 success, busy 0**이다. 관리 오류 4건은 예상된 명시적 공급 fallback이므로 정상 성공에 합치지 않는다. parser의 callback success 자체가 글꼴 공급 성공을 뜻하지 않는다.

각 조건은 warm exactHit 10건과 256px bitmap을 재사용하는 작은 크기 hit 10건의 중앙값이다. ON1/ON2는 같은 프로세스에서 수행한 두 독립 입력 workload이며 서로 다른 PID로 간주하지 않는다.

| 상태·입력 | exact metadata / 전체 (ms) | 작은 크기 metadata / 전체 (ms) |
|------|------:|------:|
| OFF HWP | 4.506 / 8.744 | 5.007 / 9.294 |
| OFF HWPX | 4.608 / 8.586 | 4.564 / 9.301 |
| ON1 HWP | 927.836 / 1,872.983 | 930.096 / 1,866.777 |
| ON1 HWPX | 937.426 / 1,887.932 | 942.599 / 1,971.148 |
| ON2 HWP | 843.736 / 1,690.503 | 947.567 / 1,888.079 |
| ON2 HWPX | 874.766 / 1,792.918 | 913.465 / 1,820.541 |

OFF는 metadata <200ms·전체 <300ms를 충족하고 ON은 모두 미달이다. #569의 이전 signed baseline에서 metadata는 OFF 1,008.69ms / ON 1,051.00·1,018.37ms였다. OFF 준비의 개선은 관찰했지만 ON 전체는 이번에 약 1.7~2.0초였다. 성공한 직접 CLI의 값만으로 개선을 주장하지 않는다. 이전 측정과 OS 상태·부하를 완전히 고정하지 않았으므로 순수한 개선율도 단정하지 않는다.

10개 고유 입력을 최대 10건 동시 요청하는 workload를 OFF/ON 각각 3 pass(각 30건) 실행했다.

| 상태·cache | 건수 | metadata 중앙값 / 최대 (ms) | 전체 중앙값 / 최대 (ms) |
|------|------:|------:|------:|
| OFF miss | 10 | 6.546 / 16.125 | 114.920 / 196.294 |
| OFF hit | 20 | 7.729 / 12.175 | 15.166 / 19.163 |
| ON miss | 10 | 966.592 / 3,609.866 | 9,568.402 / 16,612.407 |
| ON hit | 20 | 865.735 / 918.746 | 1,753.061 / 1,812.533 |

정상 60건은 busy 0이고 miss의 렌더 시작 전 30초 제한 안에서 처리됐지만, ON의 첫 묶음은 여전히 느리다. 이는 실제 확장 요청의 결과이며 Finder 화면의 표시 완료나 OS 자체 재요청/취소 검증은 아니다. [signed 측정 증거](assets/task_m020_580_stage4/signed-measurements.json)에 전체 표본·중앙값/최대/p90·원시 SHA를 보존했다.

## 6. 관리 변경·원상복원과 GUI 제한

승인받은 UUID 전용 보관함에서만 10개 phase를 실행했고, 각 fixture 조작은 exit 0이며 각 phase에 실제 확장 요청 2건이 대응했다.

- OFF baseline, 동명 관리 객체 추가, variant 선택, 선택 원복, 권한 복구, 객체 복구, ON/OFF 전환의 8개 phase는 첫 요청 miss·다음 exactHit이었다. identity 변화와 정확한 Gowun Batang Regular/Bold 공급을 확인했다. variant는 Regular 복제본에 마지막 1byte를 추가한 같은 face이며 OS의 다른 실제 글꼴을 교체한 시험은 아니다.
- 권한 거부 2건은 `FontLibraryError:io(13)`, 객체 삭제 2건은 `FontLibraryError:corruptObject`의 명시적 공급 fallback이었다. identity/face는 비었고 매번 miss여서 이전 bitmap과 fallback을 cache 재사용하지 않았다. 복구 후 정확한 Regular/Bold로 돌아왔다.
- cleanup의 중복 `--restore-managed-permission`은 상태 파일이 이미 삭제된 오류를 기록했다. 위 10개 phase 성공과 구분하며, 최종적으로 UUID 보관함이 존재하지 않음을 확인했다.

GUI 도구로 새 Finder 창과 이동 경로 입력을 시도했지만 다음 관찰이 다른 창으로 돌아가 고유 10파일 폴더 표시를 확인하지 못했다. 대상이 불명확한 창을 닫지 않고 중단했다. GUI에서 발생한 유효 요청은 미확인이며 실제 Preview 요청도 0건이다. 직접 CLI의 단일/2페이지 PDF 회귀를 실제 Preview 합격으로 바꾸지 않는다.

시험용 Thumbnail worker는 PID·실행 경로·시험 marker로 소유를 확인해 종료한 뒤 원래 v0.2.2 앱을 복원했다. 원본 243항목의 파일 내용·링크 대상·권한 inventory가 일치하며 strict 서명 검증을 통과했다. inventory는 xattr 비교를 포함하지 않는다. 설치본에 probe marker가 없고 고유 UUID 보관함도 삭제됐다. 마지막 등록 점검은 `/Applications/Alhangeul.app`을 provider로 확인했으며 개발 등록·개발 bundle·문제·경고 모두 0이다. 원래 앱·사용자 OS 글꼴·공유 Host 설정에 시험 변경을 남기지 않았다.

## 7. ON 비용의 원인과 Stage 4.2 보완안

성능 표본과 구분한 동일 signed 확장의 3초 sample 및 ON1 HWP exactHit 10건의 구간을 대조했다. warm 1요청의 metadata에는 `activeSignature`가 2회, 전체에는 4회 발생했다. 40개 구간 중앙값은 464.824ms였다. `systemEnumerate` 중앙값은 102.692ms, `supplyAssembly`는 3.738ms, `sourceFingerprint`는 0.254ms, 관리 queue 대기는 0.031ms였다. 구간은 서로 포함되므로 합산하지 않는다. warm 전체 metadata scan을 재사용해도 반복 현재성 검사의 비용이 남는다.

sample의 utility worker 호출 트리에서 family/style/variation/traits getter와 CoreText 내부 속성 계산이 많이 나타났다. 이는 호출 스택 표본의 관찰이며 CPU 사용률 추정치가 아니다. [profile 증거](assets/task_m020_580_stage4/signed-profile.json)에 원시 sample SHA와 구간 분포를 보존한다.

다음은 [InstalledFontActiveSignature](../../Sources/Shared/FontLibrary/InstalledFontActiveSignature.swift)의 속성 조회와 정규화 정보 재사용을 보완한다. SDK의 `CTFontDescriptorCopyAttributes`는 descriptor를 특정하는 최소 속성 dictionary를 반환하므로 필요한 계산 속성이 모두 포함된다고 가정하지 않는다. 전체 속성 key·원본 stamp·변경 epoch로 안전하게 재사용할 수 있는지 먼저 직접 실험하고, 입증된 조건만 확장 전용 bounded cache에 반영하는 안을 [구현계획 Stage 4.2](../plans/task_m020_580_impl.md)에 구체화했다.

기존 signature의 digest/reusable 일치와 활성 상태·원본·축·traits·권한·epoch 변경 시 이전 결과 폐기가 전제다. TTL만 사용하는 재사용, 필수 전후/current 검사 삭제, 알 수 없는 속성 무시는 하지 않는다. 이 보완 범위를 승인받아 직접 실험과 조건부 구현을 진행 중이다. 보완 결과와 새 source receipt는 별도로 기록한다.

## 8. 공간 정리와 남은 gate

삭제 전에 journal과 검증 hash를 남기고 완료/제외 실행의 중복 private 보관함·module·중간 CLI·Release bundle 및 복원 확인 후 signed 후보/fixture/staging/백업 4개 bundle을 삭제했다. 합계 **3,412,007,751 bytes, 약 3.178GiB(논리 파일 합계)**다. 원본 OFL/문서 fixture·원시 로그/JSON/PNG/PDF·canonical 직접 CLI·다음 빌드에 필요한 Release compile/SwiftPM cache는 보존했다. 마지막 관찰의 볼륨 여유는 약 13GiB다. APFS와 동시 작업 때문에 논리 삭제량과 볼륨 여유 변화는 일치하지 않는다. [검증 기록](assets/task_m020_580_stage4/validation.json)에 정리·복원 근거를 보존했다. 다른 작업의 Rust cache나 사용자 앱은 정리 대상으로 삼지 않는다.

남은 gate는 승인받은 Stage 4.2의 현재성을 지키는 ON 비용 보완, 동일 기준의 새 후보 signed 재측정, 실제 Finder GUI/Preview 확인이다. 새 후보 hash를 준비한 뒤 서명·임시 설치는 별도 승인을 요청한다. 공개 release·전역 cache reset·사용자 OS 글꼴 변경은 이번 승인에 포함하지 않는다. 성능 목표를 충족하기 전 Stage 4 완료 보고나 Stage 5로 넘어가지 않는다.

## 9. Stage 4.2 — 속성 재사용·직접 수용·새 후보 준비

2026-10-11 “Stage 4.2 보완안 승인·진행” 범위의 실험·조건부 구현·직접 검증과 미서명 후보 준비를 완료했다. **새 후보의 서명·임시 설치는 아직 하지 않았다.** 아래 결과는 [Stage 4.2 증거](assets/task_m020_580_stage4_2/validation.json)에 구분해 보존한다. 부모 Stage 4의 signed 시간 목표와 실제 GUI/Preview gate는 여전히 남는다.

실제 최초 목록 528개에서 `CTFontDescriptorCopyAttributes`는 모두 PostScript 이름만 반환했다. 누락된 family/style/variation/traits를 빈 값으로 대체하지 않고, 기존 getter로 계산한 필드를 보관하도록 구현했다. 원본 URL/PS·stat·enabled 및 전체 최소 속성 dictionary를 새 요청마다 확인한다. 알림 epoch·cache session과 전체 key가 같은 경우에만 필드를 재사용하며, source stat 실패·불완전 signature·취소·epoch 변화 뒤 오래된 session의 저장을 차단한다. unknown/NaN/무한대/과도한 key와 저장 한도 초과는 기존 엄격한 조회로 돌아간다. key의 Data 전체를 비교하고 TTL이나 descriptor 포인터만으로 재사용하지 않는다. 최대 20,000항목·직렬화 논리 크기 16MiB이며 bytes/FD/요청 snapshot을 보관하지 않는다.

`ExtensionFontSupply` 기본 환경에 같은 변경 epoch를 사용하는 cache를 연결했다. HostApp 기본 system은 cache 없음으로 유지한다. 전후 signature/current·공유 정책·관리 manifest·렌더 슬롯·대기·실제 bytes 검증은 유지했고 core/ABI/Studio/UI는 바꾸지 않았다. 상세는 [계약](../tech/task_m020_580_extension_font_contract.md)을 따른다.

초기 동일 descriptor의 연속 비교는 두 번째 enabled getter가 WOFF2 재분석을 반복해 재사용 경로를 약 0.6초로 측정했다. 별도 sample에서 key 생성이 아닌 `CopyIsEnabled → GetScriptAnalysisValue → WOFF2` 호출을 확인했다. 제품처럼 각 capture에 새 collection을 얻도록 비교를 보정했다. 소스 보완과 겹친 첫 실험도 canonical에서 제외했다. 실패·편향 근거를 삭제하거나 빠른 실행만 선별하지 않았다.

최종 실제 collection 2프로세스·22쌍은 기존/새 digest·reusable이 모두 일치했고 Stage 1 reference digest도 일치했다. warm 기존 signature 중앙값은 약 51.38/52.83ms, 새 경로는 27.72/29.15ms(새 collection 획득 포함)였다. 각 프로세스의 565개 계산 필드·key가 약 287KiB로 저장됐다. 실제 OS 글꼴을 설치·변경하지 않았다. [동등성 근거](assets/task_m020_580_stage4_2/attribute-equivalence.json)에 전체 비교와 제외 이유를 기록했다.

동일 최종 source/fixture/workload의 직접 비교는 비최적화와 `-O` 각각 14프로세스·650표본이다. 정상 consumer는 각 비교의 OFF/ON 288건씩, 합계 **1,152건 success/busy 0**이다. ON 첫 전체 scan 1회·warm 0회, exact/larger hit bytes 0, 정밀 Regular/Bold·단일/2페이지·획득/해제 및 관리 실패/과부하의 명시적 분류를 통과했다.

HWP/HWPX warm exactHit의 조건별 40건 중앙값:

| 직접 조건 | Stage 4.1 metadata / 전체 (ms) | Stage 4.2 metadata / 전체 (ms) |
|------|------:|------:|
| 비최적화 OFF | 9.382 / 16.474 | 2.491 / 4.712 |
| 비최적화 ON | 214.733 / 427.190 | 72.482 / 144.166 |
| `-O` OFF | 2.137 / 4.063 | 1.885 / 3.609 |
| `-O` ON | 150.217 / 299.840 | 58.798 / 117.007 |

`-O` ON HWP/HWPX별 전체 중앙값은 115.792/119.035ms, 최대는 118.361/124.311ms였다. 이전/현재 시스템 부하를 완전히 고정하지 않았으므로 순수한 개선율을 단정하지 않는다. 이 숫자는 unsigned 직접 요청이며 **signed <200ms/<300ms 합격을 대신하지 않는다.** [측정 근거](assets/task_m020_580_stage4_2/measurements.json)의 표본·proof·source receipt를 따른다.

| 최종 검증 | 결과 |
|------|------|
| 공통 FontLibrary XCTest | 160개, 실패 0; 새 key/타입/중복/축/traits/원본·권한/epoch/동시 저장/한도/취소 회귀 포함 |
| Host 출력·Spotlight 선택 XCTest | 81개, 실패 0 |
| 최적화 진단 확장 probe | PNG/CoreGraphics·Skia 두 경로·2페이지 PDF·current/queue/lease PASS; 네 PNG SHA가 이전 baseline과 동일 |
| 기본/진단 Release | BUILD SUCCEEDED; 기본 probe marker 없음·진단 marker 있음, Source 126개 고정 |
| 후보 guard | 16조건 PASS; 외부 명령 mock |
| no-AppKit·Python/shell 구문·문서/증거 SHA·diff check | PASS |

첫 Host 출력 실행은 앞서 정리한 Debug 앱이 없어 importer `Bundle` 검사 1개가 실패했다. 필요한 Host 산출물을 다시 빌드한 뒤 같은 81개가 통과했다. 실패 로그는 보존하며 제품 오류로 처리하거나 검사를 제거하지 않았다. 기본/진단 Release에 사용한 캐시를 유지하고 새 Rust build는 하지 않았다.

이번 보완에서는 완료한 시험의 중복 보관함·binary/module과 Debug/Release 앱·standalone 확장/importer·native archive 복사본을 **추가 약 2.512GiB(논리 파일 합계)** 정리했다. 새 후보/fixture·필요 입력·현재 canonical CLI·증거·Release dSYM·원본 Frameworks·재사용할 Xcode/SwiftPM 캐시는 보존했다. Xcode가 빌드 앱을 자동 등록하여 소유 경로의 개발 등록을 해제했고, 최종 확장 점검은 원래 설치본 provider·개발 등록/문제 0이다. 미서명 후보 1개 존재 경고는 승인 대기 때문에 남는다. `mdimport -L`에는 원래 설치본과 삭제한 Debug/Release importer 경로 2개의 stale 표기가 남았다. 실제 파일이 없고 개별 해제 후에도 남아 전역 reset을 수행하지 않았다. 원래 앱 243항목 inventory·strict 서명 검증은 그대로 통과했다.

새 후보는 `build.noindex/task580/stage4/finder-candidate-02`, build `580.4.2`, 고유 UUID **`8649CF03-60CF-439C-B228-5A0C038BF374`**다. unsigned 전체 inventory는 앱 `a6dc66498c31389e6ddee1b63df93ea5579ee4a658b255d44b4d4cdaae21df9d`, fixture `c00c6a1f5f8ba2609a6ebb4325ba0ff722327afd34d6a52a373114e44dafe093`로 고정했다. [후보·복원 계획](assets/task_m020_580_stage4_2/candidate-preparation.json)은 원래 `/Applications/Alhangeul.app` v0.2.2·243항목을 기준으로 한다. 준비 후 source/asset/native/input·후보 bytes를 다시 대조하며 원본이 바뀌면 설치하지 않는다.

이 후보에 대해서만 기존 Developer ID 로컬 서명·고유 시험 보관함 변경·원래 앱 백업/임시 Finder 시험·원상복원의 구체 승인을 요청한다. 표준 smoke와 동일 최소 표본, 정상 다수 파일 busy 0·현재성/복구·실제 GUI/Preview를 검증한다. 복원 전 시험 worker의 경로·고유 marker 소유를 확인해 종료하고 원본 inventory/서명/provider와 고유 보관함 제거를 확인한다. 공개 배포·사용자 OS 글꼴 변경·전역 reset은 포함하지 않는다.

## 10. 새 후보의 signed·실제 Finder/Preview 시험과 원상복원

2026-10-11 작업지시자가 “새 후보의 로컬 서명·임시 Finder 시험·원상복원을 허용할게. 진행해줘.”로 §9의 `finder-candidate-02` 시험을 승인했다. 소스 `f7e5e129`·준비 영수증의 Source 126개·fixture/core/asset/native/input·unsigned 전체 inventory guard를 통과한 동일 후보를 기존 Developer ID로 로컬 서명하고 원본 앱을 백업·임시 설치했다. 표준 scoped smoke를 사용했으며 공증·공개 배포·전역 reset은 수행하지 않았다. 결과는 [signed 측정](assets/task_m020_580_stage4_2_signed/measurements.json), [복원·정리 검증](assets/task_m020_580_stage4_2_signed/validation.json)에 보존한다.

Thumbnail image UUID는 `F2C0F5C8-D0A5-342A-8655-A358151E09FF`, Preview는 `17E0D162-7BB1-3639-BDD4-20961FC58D4B`다. ON1/ON2는 같은 Thumbnail PID의 별도 workload이며 새 PID 2개라는 의미가 아니다. 각 조건 유효 10건을 PID/request/image·포함 구간으로 대응했다.

| 조건 | cache | metadata 중앙값 (ms) | provider 중앙값 (ms) | <200 / <300ms |
|------|------|------:|------:|------|
| OFF / HWP | 256 exact | 4.852 | 9.186 | PASS |
| OFF / HWP | 256→128 larger | 4.844 | 9.202 | PASS |
| OFF / HWPX | 256 exact | 4.727 | 9.051 | PASS |
| OFF / HWPX | 256→128 larger | 4.891 | 9.283 | PASS |
| ON1 / HWP | 256 exact | 310.716 | 611.537 | 미달 |
| ON1 / HWP | 256→128 larger | 302.265 | 613.179 | 미달 |
| ON1 / HWPX | 256 exact | 318.961 | 643.507 | 미달 |
| ON1 / HWPX | 256→128 larger | 320.910 | 652.681 | 미달 |
| ON2 / HWP | 256 exact | 317.714 | 652.065 | 미달 |
| ON2 / HWP | 256→128 larger | 307.592 | 614.513 | 미달 |
| ON2 / HWPX | 256 exact | 310.290 | 624.137 | 미달 |
| ON2 / HWPX | 256→128 larger | 311.050 | 620.840 | 미달 |

ON 전체 중앙값은 약 612~653ms다. 같은 첫 후보의 약 1.7~2.0초보다 줄었지만 **두 시간 목표에 미달**했다. 직접 `-O` 약 117ms를 sandbox 결과로 확대하지 않는다. 서로 다른 시점의 시스템 부하를 완전히 고정하지 않았으므로 순수한 개선율을 단정하지 않는다.

정상 자동 Thumbnail은 단일 반복 126건과 최대 동시 10파일×3 pass×OFF/ON 60건, 합계 **186건 모두 완료·busy 0**이다. 다수 파일 최초 miss의 OFF/ON 전체 중앙값은 158.971/3,770.765ms, 최대 444.323/8,023.890ms였다. 반복 exact 20건씩 중앙값은 14.027/674.143ms였다. 최초 대기와 warm hit를 합산하지 않는다.

고유 보관함 변경 10단계·20요청을 모두 수행했다. 정상 정책·선택·복구 8단계는 첫 miss→두 번째 exactHit와 정확한 Regular/Bold 공급을 확인했다. 권한 차단/객체 삭제의 4요청은 매번 miss·identity 없음·명시적 공급 fallback으로 정상 성공 집계에서 제외했다. 허용/원본/선택을 복구한 뒤 정확한 두 face가 돌아왔으며, 마지막 권한 복구는 이미 state 파일이 제거된 경우 재실행하지 않도록 운영 명령을 보정했다.

Finder는 다른 작업의 ‘폴더로 이동’ 창을 먼저 닫아 달라는 요청에 작업지시자가 “창을 닫았고 Finder 시험 가능”으로 응답한 뒤 별도 시험 창을 만들었다. 고유 두 폴더의 10개 아이콘을 각각 첫 표시·재방문·크기 변경 후 모두 확인했고 실제 화면을 CUA 결과로 보여 드렸다. 슬라이더 값은 pixel 값이 아니며 최초 128 입력이 최대 112로 제한돼 큰 아이콘이 표시됐다. 즉시 40으로 보정하고, 재방문에서는 32를 사용했다. 이 과정의 추가 1024px 요청도 실제 요청으로 보존했다. GUI Thumbnail **77건**은 첫 OFF 32px, ON 크기/폴더 변경·재방문·prefetch 등을 포함하며 정상 제어 186건과 분리한다. OS가 추가로 요청하지 않은 표시를 새 요청으로 늘려 세지 않았다.

실제 Preview **38요청**이 완료됐다. 단일 `gui-single.hwpx` 열기/닫기 10요청, 2페이지 문서 1요청과 고유 10파일의 2 pass/prefetch 27요청이다. 빠른 연속 키 입력 도중 AX 상태가 이전 항목에 머물 때 현재 항목을 다시 확인했고 최종 09까지 도착했다. 전체 preview는 단일 PNG 37요청·2페이지 PDF 1요청이다. PNG 37개와 PDF 두 페이지의 font 메시지 모두 정확한 Regular/Bold·supplyFallback 없음이며 PDF 양쪽 페이지를 화면에서 확인했다. OS의 prefetch/추가 요청 7개를 사용자의 20회 순회 시도에 더하지 않는다. 최초·반복·prefetch가 섞인 Preview 중앙값 1,121.803ms는 warm gate로 주장하지 않는다. 추가 작업에서 필요한 최소 OS/Intel·실제 OS 취소 관찰과도 구분한다.

전체 로그에는 327개 대응 callback 완료가 있다(표준 smoke 3, 정상 자동 186, 변경 20, GUI Thumbnail 77, Preview 38, 별도 profile 3). 명시적 공급 fallback 4개가 포함되므로 327개를 모두 글꼴 공급 성공으로 부르지 않는다. busy trace는 전체 0이다. 단일/2페이지 실제 표시와 공급은 확인했지만 ON 목표 미달이므로 **Stage 4는 미완료**다.

### 10.1 남은 비용과 다음 보완 후보

ON1 HWP exact 10요청은 `activeSignature` 전체 40구간 중앙값 148.865ms, 그 안의 `systemEnumerate` 40구간은 92.492ms다. 공급 조합 중앙값 2.913ms·원본 fingerprint 0.182ms이며 포함 관계가 있으므로 합산하지 않는다. 동일 signed worker의 별도 3초 sample은 `kCTFontEnabledAttribute` 조회가 CoreText `CopyIsEnabled`·FontRegistry XPC 동기 대기로 이어지는 호출 스택을 보여 준다. 이는 sample 관찰이며 CPU 비율 추정치가 아니다. [profile 근거](assets/task_m020_580_stage4_2_signed/profile.json)를 따른다.

읽기 전용으로 확인한 Apple SDK `CTFontCollection.h`는 collection에 disabled fonts를 포함하는 별도 옵션을 정의한다. 기본 collection의 활성 목록 계약을 기존 개별 enabled getter와 대조하면 추가 통신을 줄일 가능성이 있다. 현재 코드의 `captureActive`는 enabled를 다시 조회하지 않으므로 같은 capture 내부의 중복 getter로 오인하지 않는다. **활성 판정 생략·결과 장기 cache는 아직 구현하지 않았으며**, SDK 계약과 실제 sandbox 동등성을 먼저 확인하는 [구현계획 §6.2](../plans/task_m020_580_impl.md)의 Stage 4.3 안을 제시한다.

### 10.2 원상복원과 공간 정리

GUI Preview와 소유 시험 Finder 창을 닫고, 설치 marker·실행 경로·image UUID가 모두 맞는 Thumbnail PID 89446와 Preview PID 93253만 종료했다. 원본 v0.2.2의 **243개 파일 내용·링크 대상·권한 inventory**가 준비/백업/복원본과 같고 strict 서명 검증을 통과했다. digest는 `fa694017af3e0b3705510b353ef0e9dc5549be57493b74e99e5ca05540b3707b`이며 xattr 비교는 포함하지 않는다. 고유 UUID 보관함이 없어졌고, 해당 출력 파일과 `/usr/bin/log` 실행 경로로 확인한 소유 수집기만 종료했다.

첫 복원 뒤 등록 점검은 후보/staging의 LaunchServices 등록 2개를 발견해 exit 1이었다. 소유 네 bundle의 경로/marker/inventory를 검증해 개별 등록을 해제·삭제한 뒤 최종 점검은 원래 `/Applications/Alhangeul.app` provider, 개발 등록/개발 bundle/문제/경고 **모두 0**으로 통과했다. 일부 이미 미등록인 importer 개별 해제는 exit 1로 기록했으며 최종 점검과 구분한다. 이전 `mdimport -L` stale 표기를 해결하기 위한 전역 reset은 하지 않았다.

완료한 후보·fixture·staging·복원 백업 네 bundle 합계 **1,015,108,423 bytes(약 968MiB 논리 파일 합계)**를 추가 정리했다. 원본 앱·사용자 글꼴·공유 Host 설정을 유지하고 원시 로그/JSON/PNG·입력/원본 OFL·dSYM·필요 compile cache는 보존했다. 마지막 볼륨 여유는 약 16GiB로 관찰했으며 APFS·동시 작업의 영향 때문에 삭제량과 여유 변화가 같다고 주장하지 않는다.
