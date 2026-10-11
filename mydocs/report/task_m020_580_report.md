# Task M020 #580 — Finder 글꼴 준비 재사용·다수 파일 썸네일 대기 개선

## 1. 작업 요약과 완료 판정

- 대상: [#580](https://github.com/postmelee/alhangeul-macos/issues/580), 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562), Mac 통합 수용·웹 안내 [#569](https://github.com/postmelee/alhangeul-macos/issues/569). 마일스톤 M020 / v0.2 계열.
- 기준: `devel` / `dac73a589dc17143e744da6a12a51d638a81fb77`. 작업 `local/task580`, 게시 예정 `publish/task580`, PR base `devel`.
- 최종 제품 구현: `1624842b`. 같은 제품 Source 126개로 signed 후보 `580.4.3`을 검증했고 `f4b7f379`에 측정·복원 결과를 기록했다. Stage 4 완료 기준 보정 커밋은 `d9171d80`이다.
- 2026-10-11 작업지시자가 현재 검증 결과 수용·Stage 4 기준 보정·추가 최적화의 후속 분리·Stage 5 진행을 승인했다. **Stage 4 완료, Stage 5 최종 보고·PR 준비 완료. 구체 공개 게시 승인 대기이며 merge·이슈 close·출시는 미수행이다.**

확장은 변경 없는 설치 글꼴 metadata의 전체 정규화를 재사용하고 동시 준비를 합친다. 설치 사용 OFF에서는 설치 목록 준비를 생략한다. Thumbnail은 정상 세 번째 font miss를 즉시 busy로 반환하던 동작을 제한된 FIFO 대기로 바꾸고, 같은 key의 작업을 병합한다. 정확한 face/bytes·원본/권한·현재성·취소/lease·물리 I/O 수명과 기존 실행/메모리 한도를 유지했다.

core/Studio는 공식 `v0.8.7` / `1a76570e833917d15817415a53c09ad61ab3203f`를 유지했다. Rust C ABI·renderer 기본값·HostApp UI를 바꾸지 않았다. 이 작업의 실제 Finder 결과는 #569 최종 제품 수용·웹 안내로 인계하며 Windows #566 및 #562/#569 전체 완료를 대신하지 않는다.

## 2. 변경 범위

| 영역 | 변경과 리뷰 경계 |
|------|-------------------|
| `ExtensionInstalledFontPreparation.swift`, `ExtensionFontSupply.swift` | 확장 전용 직렬 준비·동시 요청 병합·metadata 재사용·OFF 경로. 요청별 snapshot/FD는 독립 소유하며 정책·즉시 epoch·전후 signature가 맞는 결과만 게시 |
| `InstalledFontActiveSignature.swift`, `InstalledFontDescriptorCache.swift`, `InstalledFontSystem.swift` | URL/PS·최소 속성·variation/traits·중복·원본 stamp를 확인. 검증된 계산 속성 cache는 전체 key equality와 20,000항목/16MiB 한도를 사용. 확장만 새 활성 collection을 매 검사마다 조회하며 HostApp 기본 경로 유지 |
| `InstalledFontCatalogService.swift`, 공급 모델·`StudioFontSupply.swift`, `FontLibraryStore.swift` | 기존 scan 수용 경계 재사용·명시적인 preparedState와 관리 manifest 전체 비교·내부 진단. HostApp 기본 준비·권한·설정은 유지 |
| `HwpThumbnailRenderCache.swift` | admission 16·물리 render 2·bitmap 96항목/64MiB 유지, FIFO·같은 key 병합·렌더 시작 전 30초 deadline. 개별/전체 취소·실제 worker 종료·slot/lease 해제·cache 게시를 구분 |
| `ExtensionFontRenderer.swift`, 두 확장 provider | 최초 자기 번들 등록 경합 방지와 진단 flag의 UUID/PID/image/단조 구간·busy 경계. 기본 renderer·fallback 정책 유지 |
| `Tests/FontLibraryTests`, 확장 정확성/성능 probe·집계 scripts | 실제 production 준비/queue·CoreText process-scope lifecycle·원본/정책/취소·한도·PNG/2페이지 PDF 회귀. unsigned 직접 조건과 signed callback 대응을 분리 |
| signed 후보 준비/smoke·inventory·guard scripts | 소스 집합/내용·core/asset/native/input·전체 bundle 파일/link/mode를 고정. 소유 후보·보관함·설치본 백업/복원·등록만 처리; 외부 명령 mock으로 16조건 guard 확인 |
| 계획·계약·단계 보고·선별 증거·오늘할일 | 승인·실제 결과·실패 이력·현재 수용 결정·#569 인계와 독립 후속 본문. Xcode project는 `project.yml` 기반 `xcodegen generate` 결과 |

활성 collection 변경 전 두 프로세스·30쌍의 URL/PS 다중집합·signature digest/reusable 동등성을 확인했다. 실제 matching descriptor의 URL/PS와 process 등록 scope를 확인한 OFL 복사본만 등록·비활성화·재활성화·해제했다. 사용자 OS 글꼴을 변경하지 않았다. default collection과 개별 enabled 필터로 돌아가는 실패 경로를 유지한다. TTL·descriptor 포인터만의 판정·현재성 검사 삭제·모든 bytes 선읽기는 추가하지 않았다.

## 3. 성능 결과와 승인된 수용 기준

각 표는 같은 signed PID의 exact/larger warm 각 10건·HWP/HWPX·ON 두 독립 workload와 OFF 대조의 조건별 중앙값이다. ON 두 workload를 새 PID 두 번으로 해석하지 않는다. 서로 다른 시점의 OS 부하가 완전히 고정되지 않아 순수한 개선율을 계산하지 않는다.

| 조건 | #569 Stage 2 baseline, metadata / provider | 마지막 #580 후보, metadata / provider |
|------|------------------------------------------:|--------------------------------------:|
| OFF exact | 1,008.69 / 1,027.78ms | HWP/HWPX 4.43~4.53 / 8.60~8.86ms |
| ON exact | 1,018.37~1,051.00 / 1,035.08~1,068.09ms | HWP/HWPX·ON1/ON2 159.96~168.98 / 329.19~342.60ms |
| OFF larger | baseline도 metadata 약 1초 | 4.54~6.35 / 8.51~11.02ms |
| ON larger | baseline도 metadata 약 1초 | 159.55~169.54 / 327.69~342.52ms |

baseline의 정확한 입력/표본은 #569 Stage 2와 #580 이슈 본문을 따른다. 최종 조건별 값과 request 대응은 [마지막 signed 측정](../working/assets/task_m020_580_stage4_3_signed/measurements.json)에 있다. 중간 후보에서 ON provider 약 1.7~2.0초, 다음 후보 약 612~653ms가 관찰됐다. 직접 CLI 약 107/140ms를 signed 성능으로 대체하지 않는다.

최초 잠정 목표 metadata <200ms·provider <300ms 중 metadata는 통과했다. **provider <300ms는 미충족 사실을 유지하고, 2026-10-11 승인으로 현재 후보의 각 warm 조건 중앙값 약 328~343ms를 수용했다.** 보편적인 350ms 상한이나 Apple/OS 기준을 만들지 않는다. 기존 signed JSON의 `goalsMet: false`·실패 이력·모든 표본/체크섬은 그대로 보존했다. 정확성·현재성·취소/lease·한도·GUI·복원 기준은 완화하지 않았다.

정상 자동 Thumbnail 186건(반복 126 + 최대 동시 10파일·3 pass·OFF/ON 60)은 모두 완료·busy 0이다. 실제 GUI Thumbnail 85건, Preview 31건과 분리한다. 전체 대응 provider 완료 328건에는 관리 객체 삭제/권한 차단의 의도적인 공급 fallback 4건이 있으므로 328건 모두 로컬 글꼴 성공으로 설명하지 않는다.

최초 준비·다수 파일 대기는 남는다. 최종 ON 다수 파일 첫 miss provider 중앙값 1,877.938ms·최대 5,339.784ms, warm exact 중앙값 357.995ms였다. 이 값을 단일 반복 요청·화면 paint·앱 시작 시간과 합치지 않으며 즉시 표시를 보장하지 않는다. 현재성 signature 비용의 추가 분해·검증된 보완은 [독립 후속 본문](../working/task_m020_580_followup_issue.md)으로 인계한다. 이 후속은 #580 완료와 #569 Mac 수용·안내·출시 준비의 선행 조건이 아니다.

## 4. 검증과 증거 대조

| 검증 | 결과와 경계 |
|------|-------------|
| 공통 FontLibrary XCTest | 최종 162개·실패 0. 실제 활성 collection/process-scope lifecycle 2개 skip 0; 사용자 OS 글꼴 설치 수용으로 확대하지 않음 |
| Host 출력·Spotlight 선택 XCTest | 실제 Debug 앱/test bundle 사전 빌드 후 81개·실패 0 |
| 실제 production 준비·queue | 재사용/동시 준비·OFF 0 scan·ON 최초 1/warm 0·변경 중 게시 금지·원본/권한/정책/manifest/epoch·취소·slot/lease·16/17번째 접수·2실행·30초 시작 전 deadline·eviction 회귀 통과 |
| 같은 최종 소스의 직접 consumer | 비최적화와 `-O` 각각 14프로세스·650시간 표본. 정상 consumer 합계 1,152건·busy 0. 실패 대조·guards는 정상 성공과 분리 |
| 확장/native 정확성 | CoreGraphics·Skia decode/direct PNG, 2페이지 PDF·current·queue·lease/취소·한도 통과. 비교 PNG 네 개 SHA 유지; renderer 기본값 변경 없음 |
| 제품 빌드 | 기본/진단 Release 모두 성공; 기본 probe marker 없음·진단 있음. macOS 12 target 컴파일이며 최소 OS/Intel 실제 실행은 아님 |
| signed 실제 소비자 | 승인된 후보 `580.4.3`로 표준 smoke·Finder 두 폴더 첫/재방문/크기 변화·Quick Look 단일/다수·PDF 양쪽 페이지 확인. Preview 31요청의 33개 글꼴 메시지는 정확한 Regular/Bold·공급 fallback 없음 |
| 복원·정리 | 원래 v0.2.2의 243항목 파일/link/mode inventory·strict 서명 일치, UUID 보관함 제거, 소유 worker/로그/후보/등록 정리. xattr 비교는 범위 밖 |
| Stage 5 source/증거 audit | 마지막 signed 제품 Source 126개·직접 receipt의 테스트 24개/스크립트 7개와 현재 hash 모두 일치. core lock·Studio manifest·native 두 산출물 4개 및 기존 선별 checksum 31개 일치 |
| Stage 5 가벼운 검증 | no-AppKit·native matcher/Studio receipt·core build-info·parser self-test·mock helper guards 16조건·main/source content gate 통과. 원래 앱 inventory/strict 서명·읽기 전용 등록 점검 재확인; 개발 등록/bundle·문제·경고 0 |

단계별 실제 실행/실패·회복 기록은 [Stage 1](../working/task_m020_580_stage1.md), [Stage 2](../working/task_m020_580_stage2.md), [Stage 3](../working/task_m020_580_stage3.md), [Stage 4](../working/task_m020_580_stage4.md)를 따른다. 최종 결과보고 단계는 제품을 변경하지 않아 XCTest·전체 성능·signed 설치 시험을 반복하지 않았다. [Stage 5 증거 audit](../working/assets/task_m020_580_stage5/evidence-audit.json), [검증/승인 receipt](../working/assets/task_m020_580_stage5/validation.json), [SHA256SUMS](../working/assets/task_m020_580_stage5/SHA256SUMS)를 보존한다.

최종 signed 첫 설치 smoke는 parent app 등록 뒤 확장 matching 실패로 중단·자동 복원됐다. 같은 고정 후보 재시도에서 설치본 marker/Info/executable SHA가 맞는 두 `.appex`만 명시 등록해 표준 smoke가 통과했다. 전역 reset이나 tracked helper 보정은 하지 않았다. 이전 실험 실패·취소/오류 대조·Rust portable 재빌드의 sandbox 접근 실패를 성공 표본/재빌드 완료로 바꾸지 않는다.

## 5. 잔여 위험·후속 인계·공간

| 항목 | 인계 |
|------|------|
| warm <300ms 추가 최적화 | [후속 이슈 본문](../working/task_m020_580_followup_issue.md) 등록 대기. signature 내부 비용·bulk 속성/전체 key 비교의 동등성을 먼저 조사. 새로운 구현·후보 서명/설치 승인을 자동 승계하지 않음 |
| #569 Mac 통합 수용·웹 안내 | #580 merge 후 Stage 3 웹 안내 → Stage 4 같은 최종 후보의 설정/권한·Studio 기존 목록·저장/재열기·PDF·인쇄 경로·Finder·재실행·변경/복구 → 부분 보고/PR·Release Operations 인계 |
| #569 미병합 브랜치 | `local/task569`의 진단/보고·`60ea06a384ce5ba9e43b60a30278ce1268efe237`/`e55cbaf6` 인계 지점을 보존. 이번 선별 진단과 대조하고 승인 없이 전체 cherry-pick/rebase/merge하지 않음 |
| 미확보 환경/지원 경계 | 최소 macOS/Intel runtime, 실제 한컴 내부 자산·한컴 제거 후 유지·사용자 OS 전체 설치/비활성·물리 프린터·public DMG는 이번 수용 밖. Windows #566 독립 후속 |
| OS cache·취소 | 실제 새 요청의 현재성을 확인했다. OS가 새 요청을 만들지 않는 이미 열린 QL/영구 thumbnail 즉시 갱신이나 QL callback의 OS 취소 전달을 보장하지 않음 |
| 큰 입력·최초 준비 | 위 cold/동시 대기 비용과 30초 렌더 시작 전 내부 deadline·기존 bytes/실행 한도 유지. 전체 프로세스 peak RSS·모든 큰 문서 공정성 보장은 미검증 |

최종 후보 signed 시험 후 후보/fixture/두 staging/두 백업 6 bundle, 논리 파일 합계 **1,736,202,094 bytes(약 1.617GiB)**를 정리했다. 그 직전 직접 검증 중간 산출물은 약 1.971GiB를 별도로 정리했다. 다른 단계 합계를 물리 확보 공간으로 환산하지 않는다. OFL/입력·원시 JSON/로그/PNG/PDF·source receipt·dSYM·필요 Xcode/SwiftPM cache는 후속 인계용으로 보존했다. Stage 5는 새 앱/DMG를 만들지 않았다.

현재 `/Applications/Alhangeul.app`은 원래 공개 v0.2.2이며 #580 후보가 설치된 상태가 아니다. Source/표본/OS·sandbox/sign·PID/image·원본/정책·복원 제한을 #569 후보 준비 시 대조한다. 설치 참조 글꼴은 원본 삭제·비활성·권한 상실 후 계속 사용을 보장하지 않는다.

## 6. 구체 공개 게시 승인

최종 보고·Stage 5 기록·오늘할일·PR 본문과 [기존 이슈 기준 갱신 본문](../working/task_m020_580_issue_update.md)을 준비했다. 공개할 범위는 `postmelee/alhangeul-macos`의 후속 이슈 등록, #580 완료 기준 본문 갱신, 현재 source/테스트/측정 증거/보고서를 포함한 `local/task580` → `publish/task580` push 및 `devel` 대상 Open PR이다. 게시 후 필수 CI/리뷰를 확인하며 merge·이슈 close·공개 배포는 이번 게시 승인에 포함하지 않는다.

후속 이슈의 첫 등록 시도는 자동 승인 검토가 “후속 작업 분리 승인만으로 측정·경로·커밋 정보를 포함한 구체 본문의 공개 권한이 명시되지 않았다”는 이유로 거절했다. 이슈/기존 본문/원격 브랜치/PR은 변경하지 않았으며 우회하지 않았다. 준비된 공개 본문과 전체 push 범위를 마지막에 한 번에 승인받는다. 추가 성능 보완 승인을 기다리는 상태가 아니다.
