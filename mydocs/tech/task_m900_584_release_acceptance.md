# Task M900 #584 릴리즈 후보 수용표

## 기준과 상태

2026-10-12 Stage 1에서 만든 검증 계약이다. 계획은 v0.2.3 / build 21이며 source SHA는 c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 / tag v0.2.3, 승인한 publish run은 38180977764다. 최종 일반 Release signed/notarized DMG의 artifact는 11717953850, SHA256은 d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63이다. I1 파일/서명과 I2/I3 양 VM은 **PASS**이며 실제 Mac 앱 runtime·공개 행은 **대기**다. Stage 2의 source/unsigned build·helper·로컬 Pages 선행 검증은 PASS지만 아래 최종 DMG 수용을 뜻하지 않는다. [Stage 2 보고](../working/task_m900_584_stage2.md)와 새 DMG 검사 결과를 구분한다.

[릴리즈 기록](../release/v0.2.3.md), [구현계획](../plans/task_m900_584_impl.md), [Stage 1 출처](../report/assets/task_m900_584/stage1/context.json)를 기준으로 한다.

## 동일 파일 계약

- source SHA → immutable v0.2.3 tag → 성공 publish run/head SHA → 해당 public-dmg artifact → 추출/내려받은 DMG SHA256을 고정한다.
- 최종 네 bundle은 0.2.3/21, core/Studio는 공식 v0.8.7 / 1a76570e833917d15817415a53c09ad61ab3203f여야 한다. 생성 직전 latest와 다시 대조한다.
- ARM/Intel VM, 실제 Mac, 공개 URL, Sparkle/Cask의 검사·게시 파일은 같은 DMG bytes여야 한다. 생성/소스가 달라지면 이전 PASS를 재사용하지 않는다.
- 최종 앱에는 이전 probe의 진단 flag·App Group UUID를 주입하지 않는다. 이미 sealed된 앱의 로컬 재서명·파일 수정으로 검사하지 않는다.
- 증거는 환경/아키텍처, source/run/artifact/hash, 실제 대상 경로, 설정/권한, 자동/수동 범위와 실패/미실행을 포함한다.

## 수용 목록

| ID | 단계·경로 | 확인 사항 | 증거와 상태 |
|----|-----------|-----------|-------------|
| I1 | Stage 3 파일/서명 | checksum·hdiutil verify·source/tag·네 bundle·arm64+x86_64·strict seal·staple/Gatekeeper·layout | [동일 파일 검증 PASS](../report/assets/task_m900_584/stage3/publish/file-verification.json), [source/artifact/hash](../report/assets/task_m900_584/stage3/publish/download-proof.json), [실제 레이아웃](../report/assets/task_m900_584/stage3/publish/dmg-layout.jpg) |
| I2 | ARM/Intel 새 VM | schema 3 양 install/verdict PASS, 최초·종료 후 검색·실제 importer·새 설치 객체 | [양 VM PASS](../report/assets/task_m900_584/stage3/vm/retry/summary.json), run 38185285770 / attempt 1, schema 3·source proof·최초/종료 후·실제 importer 수용. 첫 ARM 환경 실패 별도 보존 |
| I3 | 같은 파일 재설치 | bytes/경로/build/mtime/기존 요청 기록 유지, 사전 안정 검색·새 요청 관찰, maintained/recovered 구분 | [ARM](../report/assets/task_m900_584/stage3/vm/retry/arm-verification.json)·[Intel](../report/assets/task_m900_584/stage3/vm/retry/intel-verification.json) PASS, 재설치/종료 후 snapshot·각 lifecycle 33개·cleanup. 양쪽 maintained·각 91개 판정. 실제 색인 복구 시간 측정으로 확대하지 않음 |
| M1 | Mac 설정/목록 | 기본 OFF 또는 원래 선택 유지, ⌘, 글꼴 ON/OFF·기존 시스템 목록·실제 family/style·재실행 | 화면·실제 count·설정 원래 값/시험 값 / 대기 |
| M2 | HWP/HWPX | 소유 문서 복사본의 Regular/Bold 선택·실제 save-as·재열기·원문/family/서식 유지, host alias 없음 | 문서/hash·공식 WASM 판독·실제 UI / 대기 |
| M3 | PDF | 실제 앱 PDF의 선택 face/program·ToUnicode·원문 추출/검색·확대 화면·실패/명시 대체 안내 | PDF·PDFKit/Poppler·필요 화면, 별도 helper와 구분 / 대기 |
| M4 | 인쇄 | 두 형식의 실제 macOS 패널 열기·취소·문서 복귀 및 글꼴 준비 상태 | 취소 기록·화면, 물리 전송 없음 / 대기 |
| M5 | Finder | fresh single/multiple Quick Look·Thumbnail, 설치 경로의 실제 active provider·지원 face/fallback | 표준 smoke receipt·GUI·새 경로·표본/시간 / 대기 |
| M6 | 원본·권한·동명 상태 | 기존 current/source/fallback 계약 대조, 실제 확인 가능한 권한/원본 복구 동선 | 이전 #569 근거와 새 직접 시험 구분. 추가 mutation은 소유 fixture/명시 승인 / 대기 |
| M7 | Spotlight | 저장된 평문 본문 GUI 검색·결과 열기·실제 importer, 기존 설치 이력 구분 | 실제 검색·원본/종료 상태·실제 UI / 대기 |
| M8 | 저장·닫기/종료 | 기존 저장·취소·실패 시 문서 유지, 정상 종료/재열기 | 소유 시험 문서·UI·결과/hash / 대기 |
| S1 | #480 안전 차단 | 소유 합성 보호 입력에서 경고 취소·원본/동일 파일 목적지 거부·원본 hash 유지, 명시 다른 평문 복사본 및 재열기 | 현재 retained guard는 정적 PASS. 실제 최종 DMG runtime 대기 |
| S2 | #525 복구 한계 | 충분한 autosave 후 저장하지 않음의 실제 복구 후보·원본/hash, 다른 문서 및 취소/저장 동선 보존 | 최신 재현 미실행. 후속 이슈 유지·공개 owner의 구체 한계 수용 대기 |
| R1 | 임시 시험 복원 | 원래 앱 inventory/서명·버전·provider·승인된 설정 값, 소유 파일/보관함·개발 등록 정리 | backup/restore/cleanup receipt / 대기 |
| P1 | 동일 파일 공개 | 인증 없는 public DMG/checksum 신규 다운로드, 검사 hash 동일·stable latest·Pages/폰트 안내·배너 | public URL/hash·배포·appcast XML/정확한 항목 / 대기 |
| P2 | 실제 Sparkle | 실제 v0.2.2 → v0.2.3 다운로드/설치/자동 재실행·문서/검색/확장·글꼴 설정 | 실제 update UI·최종 설치 버전·기존 설정/원본 / 대기 |
| P3 | Homebrew | 정확한 public hash의 tap/본 저장소 Cask·audit·업데이트/설치 또는 승인된 독립 후속 | 실제 tap/receipt/시험 혹은 명시 분리 / 대기 |

## 기존 증거와 실제 새 수용의 구분

#569 작업의 Mac 진단 후보는 글꼴 선택·원문 보존·PDF·인쇄 취소·Finder 및 원상복원을 수용했다. #580 성능 보정과 busy 개선은 인계된 증거다. 이 단계의 read-only 검사는 해당 진단 앱을 다시 실행하지 않았으며 최종 DMG PASS를 만들지 않았다.

현재 #480 무경고 원본 덮어쓰기 방지는 기존 공개 v0.2.2에도 존재하며 native 암호화 저장은 미지원이다. encrypted-export RPC 제공 여부와 구현 자체는 별도 #480 범위다. S1이 실패하거나 소유 원본이 바뀌면 공개를 차단하고 별도 수정안을 제시한다.

#525 native 폐기/Studio 복구 수명 연결은 아직 별도 후속이다. 현재 source에서 native bool 해제만 확인했고 새로운 runtime은 관찰하지 않았다. S2의 결과·정확한 영향 및 사용자 안내로 최종 공개 수용을 판단하며 미완료를 해결된 이슈로 표시하지 않는다.

## 운영 경계·지원 공백

Mac 설치 원본은 존재/활성/읽기 권한에 의존하며 별도 보관 복사본과 다르다. 한컴 앱 내부 추출·삭제 후 모든 글꼴 유지·Windows ZIP·TTC/가변/HFT·라이선스·한컴 레이아웃 동일성을 보장하지 않는다. 실제 설치 목록 수는 환경 관측으로 기록하고 232/809나 가상 28개를 예상값으로 고정하지 않는다.

최소 macOS 12와 Intel 실기기 GUI는 환경이 없으면 미검증이다. Intel VM의 검색·install PASS나 universal slice로 실제 Intel 글꼴 GUI 성공을 대신하지 않는다. 실제 한컴 제거·물리 인쇄·전역 cache reset·사용자 OS 글꼴 변경은 현재 범위 밖이다.

임시 설치/설정·권한 시험은 구체 후보와 백업/복원·소유 파일 범위를 준비한 뒤 별도 승인한다. 최초 설치 workflow·공개 승격·Pages/Sparkle·Homebrew도 각각 gate를 따른다. 모든 표의 status는 실제 결과가 생길 때만 갱신한다.
