# Task M900 #584 릴리즈 후보 수용표

## 기준과 상태

2026-10-12 Stage 1에서 만든 검증 계약이다. v0.2.3 / build 21, source c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4 / tag v0.2.3, publish run 38180977764, artifact 11717953850, DMG SHA256 d0050cb7de5d3fea17708aef1bebb7da54d326c7a540afbaf28276c3e50b1e63을 고정했다. I1/I2/I3는 PASS다. 2026-10-12~13 [Stage 4](../working/task_m900_584_stage4.md)의 일반 Mac 앱 주요 동선도 통과했으며 M7 환경 미확인 및 R1 최근 이력의 증거 공백 수용을 기다린다. 공개 행은 대기다. [Stage 2](../working/task_m900_584_stage2.md)의 선행 unsigned/Pages 검증과 최종 DMG 직접 결과를 구분한다.

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
| M1 | Mac 설정/목록 | OFF/ON·기존 시스템 목록·실제 family/style·재실행 | PASS: 실제 232 family/809 records, ON 공급 204/OFF 0, 재실행 ON 유지 후 OFF 복원 |
| M2 | HWP/HWPX | Regular/Bold·save-as·새 프로세스 재열기·원문/family/서식·alias 없음 | [직접 PASS](../report/assets/task_m900_584/stage4/saved-core-proof.json), 두 형식 전 언어 NanumSquare·원문·굵기 유지 |
| M3 | PDF | 실제 출력 face/program·ToUnicode·원문·검색/선택·확대 | [PDF](../report/assets/task_m900_584/stage4/pdf-proof.json)·[PDFKit](../report/assets/task_m900_584/stage4/pdfkit-proof.json) PASS. pypdf 공백 차이/object 6/8 경고 보존 |
| M4 | 인쇄 | 실제 macOS 패널 열기·취소·문서 복귀 | 두 형식 PASS, 물리 출력 없음 |
| M5 | Finder | fresh single/two-page Quick Look·Thumbnail·실제 active provider | 최종 0.2.3 경로, 단일 PNG 2건·PDF 2페이지 선택·새 Thumbnail 3개 표시 PASS. 앞선 stale 요청 3개는 raw 보존, 일반 Release의 개별 PS debug 추적은 미확인 |
| M6 | 원본·권한·동명 상태 | 기존 계약 대조 및 승인된 직접 설정 동선 | 직접 ON/OFF·grant 0·OS 글꼴 hash 유지 PASS. 원본/권한 상실·동명 회귀는 #569/#580 인계, 이번 OS mutation 재시험 없음 |
| M7 | Spotlight | 실제 Mac 검색·결과 열기·실제 importer | ENVIRONMENT_UNAVAILABLE: [10월 15일 재부팅 재검증](../report/assets/task_m900_584/stage4/reboot-20261015/summary.json)에서 설치 전 TXT 1회 PASS 후 TXT까지 재실패, Finder 0개. 실제 설치 importer 추출 PASS. 원인/회귀 미확정, 폴더 재색인 진단 또는 대체 근거 수용 승인 대기 |
| M8 | 저장·닫기/종료 | 저장·취소·정상 종료/재열기 | 관측 동선 PASS. 모든 저장 실패 유형으로 확대하지 않음 |
| S1 | #480 안전 차단 | 경고 취소·원본/동일 목적지 금지·명시 다른 평문 복사본 | [경고/취소·원본 hash·다른 복사본 재열기 PASS](../report/assets/task_m900_584/stage4/protection-proof.json). 동일 목적지 패널 재선택은 정적 정책 인계, 직접 미시험. native 암호 저장 미지원 |
| S2 | #525 복구 한계 | 저장하지 않음 후 후보·원본 보존 | 최종 앱에서 소유 후보 1개 잔존 관측·해당 후보만 삭제, 원본 유지. 별도 후속 및 공개 한계 수용 대기 |
| R1 | 임시 시험 복원 | 승인된 앱/설정·소유 파일/등록 정리 | [앱 부재/설치 정리 PASS](../report/assets/task_m900_584/stage4/installation-restoration.json). [OFF·권한·policy 부재·확보한 최근 항목 복구](../report/assets/task_m900_584/stage4/settings-restoration.json). UUID/sfl4 사전 경로 누락 때문에 전체 최근 이력 동등성은 미증명·수용 대기 |
| P1 | 동일 파일 공개 | 인증 없는 public DMG/checksum 신규 다운로드, 검사 hash 동일·stable latest·Pages/폰트 안내·배너 | public URL/hash·배포·appcast XML/정확한 항목 / 대기 |
| P2 | 실제 Sparkle | 실제 v0.2.2 → v0.2.3 다운로드/설치/자동 재실행·문서/검색/확장·글꼴 설정 | 실제 update UI·최종 설치 버전·기존 설정/원본 / 대기 |
| P3 | Homebrew | 정확한 public hash의 tap/본 저장소 Cask·audit·업데이트/설치 또는 승인된 독립 후속 | 실제 tap/receipt/시험 혹은 명시 분리 / 대기 |

## 기존 증거와 실제 새 수용의 구분

#569 작업의 Mac 진단 후보는 글꼴 선택·원문 보존·PDF·인쇄 취소·Finder 및 원상복원을 수용했다. #580 성능 보정과 busy 개선은 인계된 증거다. 이 단계의 read-only 검사는 해당 진단 앱을 다시 실행하지 않았으며 최종 DMG PASS를 만들지 않았다.

현재 #480 무경고 원본 덮어쓰기 방지는 기존 공개 v0.2.2에도 존재하며 native 암호화 저장은 미지원이다. encrypted-export RPC 제공 여부와 구현 자체는 별도 #480 범위다. S1이 실패하거나 소유 원본이 바뀌면 공개를 차단하고 별도 수정안을 제시한다.

#525 native 폐기/Studio 복구 수명 연결은 아직 별도 후속이다. 최종 앱에서도 저장하지 않고 종료한 소유 문서의 복구 후보 잔존을 관측했다. 원본은 바뀌지 않았고 해당 후보만 정리했다. S2의 영향·안내 및 공개 owner의 한계 수용으로 출시 여부를 판단하며 해결된 이슈로 표시하지 않는다.

## 운영 경계·지원 공백

Mac 설치 원본은 존재/활성/읽기 권한에 의존하며 별도 보관 복사본과 다르다. 한컴 앱 내부 추출·삭제 후 모든 글꼴 유지·Windows ZIP·TTC/가변/HFT·라이선스·한컴 레이아웃 동일성을 보장하지 않는다. 실제 설치 목록 수는 환경 관측으로 기록하고 232/809나 가상 28개를 예상값으로 고정하지 않는다.

최소 macOS 12와 Intel 실기기 GUI는 환경이 없으면 미검증이다. Intel VM의 검색·install PASS나 universal slice로 실제 Intel 글꼴 GUI 성공을 대신하지 않는다. 실제 한컴 제거·물리 인쇄·전역 cache reset·사용자 OS 글꼴 변경은 현재 범위 밖이다.

임시 설치/설정·권한 시험은 구체 후보와 백업/복원·소유 파일 범위를 준비한 뒤 별도 승인한다. 최초 설치 workflow·공개 승격·Pages/Sparkle·Homebrew도 각각 gate를 따른다. 모든 표의 status는 실제 결과가 생길 때만 갱신한다.
