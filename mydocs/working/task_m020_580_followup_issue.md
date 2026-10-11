# Finder 로컬 글꼴의 반복 현재성 검사 비용 후속 최적화

상위 기능: #562 · 선행 구현: #580 · Mac 통합 수용·웹 안내: #569

## 배경과 분리 결정

#580 작업은 확장의 설치 글꼴 metadata 재사용·동시 준비 병합·OFF 경로와 제한된 썸네일 렌더 대기를 구현했다. 마지막 Developer ID 로컬 서명 후보(`580.4.3`, 제품 소스 `1624842b`)에서 정확성·변경/복구·실제 Finder/Quick Look·원상복원과 정상 자동 Thumbnail 186건의 busy 0을 확인했다.

arm64/macOS 26.5.2의 같은 Thumbnail PID에서 HWP/HWPX × OFF/ON × exact/larger warm 각 10건을 측정했다. ON의 두 독립 workload는 metadata 중앙값 약 160~170ms, 전체 provider 중앙값 약 328~343ms였다. metadata <200ms는 충족했지만 잠정 provider <300ms 목표는 충족하지 못했다. 화면 paint나 앱 시작 시간이 아니며 최초 miss·동시 대기·다른 PID의 결과와 합치지 않는다.

2026-10-11 작업지시자가 현재 검증 결과를 수용하도록 #580 Stage 4 완료 기준을 보정하고, 추가 최적화를 후속 작업으로 분리하도록 승인했다. 이 이슈는 **#580 완료 및 #569 Mac 통합 수용·안내·출시 준비의 선행 조건이 아니다.** 구체 공개 배포와 이 후속 구현 착수는 각 승인 절차를 따른다.

## 조사할 비용

- ON1 HWP exact warm 10요청의 `activeSignature` 40구간 중앙값은 81.039ms, 그 안의 `systemEnumerate`는 25.480ms다. metadata에는 signature 2회, 전체 요청에는 4회가 있다. 포함 구간을 합산하지 않는다.
- 공급 조립 2.640ms·원본 fingerprint 0.238ms·관리 queue 대기 0.028ms와 구분한다.
- 별도 3초 sampler에는 최초 cold 준비와 warm 두 요청이 섞였다. CoreText getter·FontRegistry XPC·JSON/stat 관찰만으로 warm 비용의 원인이나 비율을 확정하지 않는다.

## 제안 범위 — 착수 전 계획·승인 필요

1. 진단 flag에 한해 signature capture별 URL/PS·최소 속성, 경로/stat, key 구성·조회, 필드 miss, 정렬/digest 비용을 나눈다. warm만 분리하고 진단 오버헤드를 대조한다. 사용자 경로/이름을 새 로그에 남기지 않는다.
2. SDK bulk 속성 조회와 정확한 전체 값 비교를 유지하는 cache key 구성의 동등성과 비용을 직접 실험한다. 행 순서·중복·missing/CFNull·URL/PS·variation/traits·digest/reusable을 대조하고 불일치 조건을 기록한다.
3. 동등성과 비용 이득이 입증된 작은 보완만 확장 경로에 적용한다. 불명확하거나 지원하지 못하는 조건은 기존 엄격 조회로 처리한다.
4. 동일 workload의 직접 회귀와 새 signed 후보 검증으로 효과를 평가한다. 최초 준비·다수 파일 대기는 별도 표로 남기며 warm 개선으로 cold 단축을 주장하지 않는다.

## 완료 기준과 보존할 계약

- 정확성·현재성·원본/권한·정책/manifest·epoch·전후/current 검증과 정확한 face/bytes를 보존한다. 목표를 맞추기 위한 검사 횟수 감소·TTL·포인터/hash만의 판정·missing 무시는 제외한다.
- HostApp 기본 경로, full key equality, descriptor cache 20,000항목/16MiB, render 2/admission 16/bitmap 96항목·64MiB와 요청별 lease·취소/물리 I/O 수명을 유지한다.
- 실제 process-scope 글꼴 등록·비활성화·재활성화·해제 및 변경/복구·동시 요청·취소·PNG/2페이지 PDF 회귀를 확인한다. 사용자 OS 글꼴을 설치·삭제하지 않는다.
- 동일 고정 입력·source receipt·Release 최적화·sandbox/sign·PID/image/request 대응으로 각 warm 조건 10건 이상, ON 두 workload와 OFF 대조를 기록한다. provider <300ms는 최적화 목표이며 착수 계획에서 실측에 근거한 수용 기준을 확정한다. 일반 CI의 고정 시간 게이트나 OS 보장으로 쓰지 않는다.
- 새 후보 서명·임시 설치·원상복원은 구체 후보와 복원 계획 준비 후 승인받는다. core/C ABI·Studio/UI·renderer 기본값·한도 증가·전역 reset·공개 배포는 범위 밖이다.

## 근거

#580 작업의 `mydocs/working/task_m020_580_stage4.md` §12–13 및 `mydocs/working/assets/task_m020_580_stage4_3_signed/`의 측정·검증·profile·SHA256SUMS를 진실 원천으로 삼는다. #580 PR 게시 후 commit 고정 문서 링크를 확인할 수 있으며, 미게시 커밋의 공개 링크를 만들어 근거로 사용하지 않는다.

이 문서는 후속 이슈 등록 본문이다. #580 범위에서 Stage 4.4 제품 변경을 시작하지 않았고, 후속 이슈에 소스 변경·서명·설치 승인을 자동 승계하지 않는다.
