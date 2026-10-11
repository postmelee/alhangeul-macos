## 2026-10-11 Stage 4 완료 기준 보정·Stage 5 진행

작업지시자가 현재 검증 결과 수용·추가 최적화의 독립 후속 분리·Stage 5 진행을 승인했다. 제품 소스 `1624842b`, 마지막 Developer ID 로컬 서명 후보 `580.4.3`에서 ON metadata 중앙값 약 160~170ms, provider 각 warm 조건 중앙값 약 328~343ms를 확인했다. 각 조건 10건 이상, 같은 Thumbnail PID의 ON 독립 workload 두 번과 OFF 대조다.

정상 자동 Thumbnail 186건 모두 완료·busy 0, 실제 Finder/Quick Look·정확한 Regular/Bold·현재성/원본/권한·취소/lease·기존 한도·관리 변경/복구·원래 v0.2.2 앱과 등록의 복원을 수용했다. 원래 provider <300ms는 통과하지 못했다는 사실과 모든 표본을 보존하고 현재 후보의 결과를 명시 수용한다.

ON 다수 파일 첫 miss 중앙값 1,877.938ms/최대 5,339.784ms와 warm exact 중앙값 357.995ms는 별도 지연 한계다. provider 완료 시간은 화면 paint·앱 시작 시간과 다르며 arm64/macOS 26.5.2의 결과를 최소 macOS/Intel에 확대하지 않는다.

추가 최적화는 [후속 #581](https://github.com/postmelee/alhangeul-macos/issues/581)에서 현재성 검사 내부 비용·동등성이 입증된 작은 보완을 조사한다. 해당 이슈는 #580 완료나 #569 Mac 수용·웹 안내·출시 준비의 선행 조건이 아니다. 기능/정확성 검사를 완화하지 않고, Stage 4.4 제품 변경·새 후보 서명/설치는 시작하지 않는다.

최종 보고·구체 공개 범위 승인 후 [Open PR #582](https://github.com/postmelee/alhangeul-macos/pull/582)를 게시했다. CI/리뷰를 확인한다. #580 이슈는 PR merge 확인 전 닫지 않으며 #562/#569 전체 완료·Windows 지원·공개 release를 포함하지 않는다.

---

상위 이슈: #562
통합 수용·웹 안내: #569

## 문제

로컬 글꼴을 사용할 때 Quick Look/Thumbnail은 요청마다 전체 CoreText 목록·공급 metadata·원본 stat을 준비한 뒤 bitmap cache를 확인한다. 캐시가 적중해도 반복 준비 비용이 남는다. 설치 글꼴 사용을 꺼도 현행 경로는 목록 준비를 반복한다.

arm64/macOS 26.5.2의 최적화된 Developer ID 로컬 서명 확장에서, 같은 HWPX의 256px exactHit 10건 metadata 중앙값은 OFF 1008.69ms, ON 독립 workload 두 번 1051.00/1018.37ms다. 전체 provider 응답에서 차지하는 대응 비율은 약 98%다. 128px의 largerBucketHit도 같은 비용을 보인다. 이는 provider callback 완료 구간이며 화면 paint 시간이나 순수 CoreText scan 시간이 아니다.

실제 Finder GUI의 폴더 표시·아이콘 크기 변경에서 Thumbnail 55건 중 31건이 `busy`로 실패했고 일부 기본 파일 아이콘이 남았다. 별도 제어 `qlmanage -t` 63건은 모두 성공했다. 오류/성능 시나리오를 합쳐 한 성공률이나 중앙값으로 설명하지 않는다.

## 근거

- 제품 core/Studio v0.8.7 유지, #569 Stage 2 진단만 추가한 Release 최적화 후보.
- 직접 실제 CoreText probe 530건과 signed provider 157건의 metadata/전체 단조 구간 대응.
- 같은 signed PID의 ON workload 두 번에서 재현. 직접 probe에는 새 PID 반복도 포함.
- 공식 OFL Gowun Batang Regular/Bold 관리 fixture 사용. 사용자 OS 글꼴 설치/삭제나 전역 cache reset 없음.
- #569 Stage 2에서 측정·원래 앱 복원까지 완료했다. 상세 보고와 원시 구간 증거는 #569 작업 브랜치에 보관하며 아직 공개된 문서 링크는 없다.

| 같은 signed PID의 exactHit 10건 | metadata 중앙값 | provider 중앙값 | 대응 metadata/전체 비율 중앙값 |
|---|---:|---:|---:|
| 설치 사용 OFF | 1008.69ms | 1027.78ms | 98.25% |
| 설치 사용 ON, workload 1 | 1051.00ms | 1068.09ms | 98.33% |
| 설치 사용 ON, workload 2 | 1018.37ms | 1035.08ms | 98.38% |

ON 두 번은 독립 workload이며 새 PID 두 번을 뜻하지 않는다. 128px largerBucketHit도 metadata 중앙값 약 1초였다. 실제 signed 157건 중 성공 126건·busy 31건이며 GUI Thumbnail 55건(성공 24건·busy 31건)과 제어 요청 63건(모두 성공)을 분리했다.

## 범위

- 반복/동시 요청의 전체 목록 준비를 공유·재사용할 수 있는 조건과 무효화 설계.
- 설치 사용 OFF에서 불필요한 준비를 줄일 수 있는 경로.
- 정상 10개 파일 표시에서 렌더 한도를 지키며 요청을 처리하는 대기/병합 흐름.
- CoreText 변경·공유 정책 revision·관리 선택/객체·원본 교체·삭제·권한 변경의 freshness 검증.
- 동일 직접 workload와 signed Finder/제어 요청의 개선 전후 측정 및 소비자 회귀.

무기한 목록 cache, 모든 글꼴 bytes 선읽기, 한도 증가만으로 busy를 숨기는 변경, core/ABI 확장·backend 기본 전환·Windows 지원은 제외한다. 구체 구현은 새 이슈의 승인된 계획에서 결정한다.

## 완료 기준

1. 같은 환경의 exact/larger warm metadata <200ms는 유지한다. 2026-10-11 승인에 따라 후보 `580.4.3`의 ON metadata 약 160~170ms·provider 각 warm 조건 중앙값 약 328~343ms를 현재 결과로 수용한다. 원래 잠정 provider <300ms는 미충족으로 기록하고 독립 후속 최적화 목표로 분리한다. OS 부하/표본·PID·cache·최초 miss/다수 파일 대기를 기록하며 새로운 일반 시간 상한이나 목표 통과를 주장하지 않는다.
2. 정상 10개 파일 첫/반복 표시·크기 변경에서 준비 대기 때문에 실패하는 busy가 재현되지 않는다. 실제 admission 초과는 기존 명시 busy 정책을 유지한다.
3. 설치/비활성/원본 교체·삭제·복구·권한 상실, 정책 OFF/ON·관리 선택/객체 변화·새 PID에서 필요한 cache 무효화를 확인한다.
4. stale 결과 반환·취소 후 PNG 반환·누락/중복 lease 해제가 없고 2건 render/16건 admission/96개·64MiB bitmap 한도를 유지한다.
5. 필요한 face만 읽고 실제 style/bytes를 보존한다. 목록 metadata만으로 모든 face가 적용 가능하다고 판정하지 않는다.
6. 같은 개선 후보의 signed Finder 재측정과 원래 설치본/등록 복원까지 끝난 뒤 #569 최종 Mac 수용에 결과를 인계한다.

## 진행 순서

이슈 등록·브랜치/계획 정렬 → 지배 구간과 무효화 설계 확정 → 구현·정확성 회귀 → 같은 workload signed 재측정 → #569 최종 후보 수용·출시 운영으로 연결한다. 측정 코드의 반영 경로와 #569 웹 안내 진행 순서는 등록 후 계획에서 정렬한다.

## 참고 및 운영 경계

- #565 설치 감지·설정·권한, #567 공식 v0.8.7 Studio 연결, #568 출력·확장 연결은 완료된 선행이다.
- #569 웹 안내 초안은 별도로 유지하고 최종 Mac 수용·출시는 이 개선이 반영된 후보로 확인한다. #566 Windows 입력은 독립 후속이다.
- milestone: **글꼴 마이그레이션**, 내부 문서 코드 M020 / v0.2 계열. 구체 버전·공개 배포는 확정하지 않는다.
- label: `bug`는 재현된 반복 지연·busy, `area:quick-look`·`area:thumbnail`은 대상 확장, `area:rendering`은 두 확장의 공통 준비·렌더 정책 소유를 나타낸다.
- 구체 구현·새 후보의 로컬 서명·임시 설치 및 공개 release는 각각 대상과 계획에 맞는 승인 후 진행한다.

