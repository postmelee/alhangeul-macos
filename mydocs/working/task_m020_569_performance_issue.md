# Task M020 #569 — Finder 글꼴 준비 성능 후속 이슈 초안

- 상태: 2026-10-10 작업지시자의 “진행해줘”로 등록·계획 정렬 승인 후 [#580](https://github.com/postmelee/alhangeul-macos/issues/580) 등록 완료. 기존 #562의 GitHub 하위 이슈로 연결하고 #562/#569의 진행 순서를 보정했다. live 조회에서 같은 성능 개선 이슈는 확인되지 않았다.
- 권장 milestone: 기존 **글꼴 마이그레이션**(문서 코드 M020).
- 권장 label: `bug`, `area:quick-look`, `area:thumbnail`, `area:rendering`.
- 선행 근거: [#569](https://github.com/postmelee/alhangeul-macos/issues/569) Stage 2, 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562).
- 이슈 등록·수행계획 작성·후속 정렬은 승인받았으며 제품 구조 구현은 #580 계획 승인 후 진행한다. 웹 안내는 #569에 유지하고 최종 Mac 수용·출시는 개선 후 후보로 확인한다.

## 제목

Finder 로컬 글꼴 준비 비용과 다수 파일 썸네일 busy 개선

## 문제

로컬 글꼴을 사용할 때 Quick Look/Thumbnail은 요청마다 전체 CoreText 목록·공급 metadata·원본 stat을 준비한 뒤 bitmap cache를 확인한다. 캐시가 적중해도 반복 준비 비용이 남는다. 설치 글꼴 사용을 꺼도 현행 경로는 목록 준비를 반복한다.

arm64/macOS 26.5.2의 최적화된 Developer ID 로컬 서명 확장에서, 같은 HWPX의 256px exactHit 10건 metadata 중앙값은 OFF 1008.69ms, ON 독립 workload 두 번 1051.00/1018.37ms다. 전체 provider 응답에서 차지하는 대응 비율은 약 98%다. 128px의 largerBucketHit도 같은 비용을 보인다. 이는 provider callback 완료 구간이며 화면 paint 시간이나 순수 CoreText scan 시간이 아니다.

실제 Finder GUI의 폴더 표시·아이콘 크기 변경에서 Thumbnail 55건 중 31건이 `busy`로 실패했고 일부 기본 파일 아이콘이 남았다. 별도 제어 `qlmanage -t` 63건은 모두 성공했다. 오류/성능 시나리오를 합쳐 한 성공률이나 중앙값으로 설명하지 않는다.

## 근거

- 제품 core/Studio v0.8.7 유지, #569 Stage 2 진단만 추가한 Release 최적화 후보.
- 직접 실제 CoreText probe 530건과 signed provider 157건의 metadata/전체 단조 구간 대응.
- 같은 signed PID의 ON workload 두 번에서 재현. 직접 probe에는 새 PID 반복도 포함.
- 공식 OFL Gowun Batang Regular/Bold 관리 fixture 사용. 사용자 OS 글꼴 설치/삭제나 전역 cache reset 없음.
- [측정 결과](../tech/task_m020_569_finder_measurement.md), [signed 요약](assets/task_m020_569_stage2/signed-summary.json), [Stage 2 보고](task_m020_569_stage2.md).

공개 본문에는 위 로컬 상대 링크 대신 핵심 측정 표와 이슈 참조를 포함했다. 아직 게시하지 않은 측정 커밋을 공개 링크처럼 제시하지 않았다. 등록된 #580은 열린 **글꼴 마이그레이션** milestone과 승인한 기존 4개 label로 확인했다. 이 문서는 등록 전 초안을 보존하는 기록이며 최신 범위·완료 기준은 #580 및 그 수행계획에서 관리한다.

## 범위

- 반복/동시 요청의 전체 목록 준비를 공유·재사용할 수 있는 조건과 무효화 설계.
- 설치 사용 OFF에서 불필요한 준비를 줄일 수 있는 경로.
- 정상 10개 파일 표시에서 렌더 한도를 지키며 요청을 처리하는 대기/병합 흐름.
- CoreText 변경·공유 정책 revision·관리 선택/객체·원본 교체·삭제·권한 변경의 freshness 검증.
- 동일 직접 workload와 signed Finder/제어 요청의 개선 전후 측정 및 소비자 회귀.

무기한 목록 cache, 모든 글꼴 bytes 선읽기, 한도 증가만으로 busy를 숨기는 변경, core/ABI 확장·backend 기본 전환·Windows 지원은 제외한다. 구체 구현은 새 이슈의 승인된 계획에서 결정한다.

## 완료 기준

1. 같은 환경의 exact/larger warm metadata를 낮추고, 잠정 목표는 중앙값 200ms 미만·provider 300ms 미만으로 검토한다. OS 부하/표본·PID·cache를 기록하며 목표 조정에는 측정 근거를 남긴다.
2. 정상 10개 파일 첫/반복 표시·크기 변경에서 준비 대기 때문에 실패하는 busy가 재현되지 않는다. 실제 admission 초과는 기존 명시 busy 정책을 유지한다.
3. 설치/비활성/원본 교체·삭제·복구·권한 상실, 정책 OFF/ON·관리 선택/객체 변화·새 PID에서 필요한 cache 무효화를 확인한다.
4. stale 결과 반환·취소 후 PNG 반환·누락/중복 lease 해제가 없고 2건 render/16건 admission/96개·64MiB bitmap 한도를 유지한다.
5. 필요한 face만 읽고 실제 style/bytes를 보존한다. 목록 metadata만으로 모든 face가 적용 가능하다고 판정하지 않는다.
6. 같은 개선 후보의 signed Finder 재측정과 원래 설치본/등록 복원까지 끝난 뒤 #569 최종 Mac 수용에 결과를 인계한다.

## 진행 순서

이슈 등록·브랜치/수행계획 정렬 → 수행·구현계획 승인 → 지배 구간과 무효화 설계 확정 → 구현·정확성 회귀 → 같은 workload signed 재측정 → #569 웹 안내·최종 후보 수용·출시 운영으로 연결한다. #580은 최신 devel에서 독립 브랜치로 시작하며 #569 측정 코드를 제품에 중복 반영하는 방법을 미리 확정하지 않는다.
