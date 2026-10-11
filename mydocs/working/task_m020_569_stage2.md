# Task M020 #569 Stage 2 — Finder 반복 준비 측정·개선 판단

- 일자: 2026-10-10, 작업 `local/task569`.
- 승인: Stage 1 보고 후 “진행해줘”로 Stage 2 구현/측정, 구체 후보 요청 후 “진행해줘”로 로컬 서명·임시 설치·복원을 승인받았다. 키체인 인증은 작업지시자가 직접 완료했다.
- 기준: `22e92164307f4cab4f16167513bd65dec1b6fd84` + 이번 단계 변경, core/Studio v0.8.7 유지.
- 결과: **측정·정확성 회귀·복원 완료. 출시 전 성능 개선 필요.** 제품 최적화나 Mac 출시 수용 완료 판정은 아니다.

## 1. 단계 목적

실제 CoreText 환경에서 반복 요청의 공급 준비 비용을 bitmap cache/렌더 비용과 구분하고, signed Finder의 지연·실패가 출시 전에 개선할 문제인지 판단했다.

## 2. 산출물

| 파일 | 내용 |
|------|------|
| `Tests/ExtensionFontPerformanceProbe/main.swift`, `scripts/probe-extension-font-performance.py` | 실제 scan/read wrapper, 직접 소비자·정책/객체 변화와 취소/한도 guard 측정 |
| 공급·Preview·Thumbnail 3개 Swift 파일 | probe flag의 opaque UUID·단조 metadata/provider 구간. 일반 공급·캐시·한도 동작 보존 |
| `scripts/summarize-extension-font-performance.py` | UUID interval 집계, 동기 callback의 동일 thread 직전 로그만 cache/조건 대응 |
| 후보 prepare/Finder helper·표준 smoke | #569 경로·source/sample/signed hash guard, 승인 후보 서명·백업/복원, 등록 조회의 bounded 재시도 |
| [측정 결과](../tech/task_m020_569_finder_measurement.md)·[선별 evidence](assets/task_m020_569_stage2/signed-summary.json) | 직접 530건·signed 157건, 정확성·제약·복원·정리 근거 |
| [성능 후속 이슈 초안](task_m020_569_performance_issue.md) | 반복 준비·다수 파일 busy의 범위/목표/freshness 회귀. 게시 전 |

## 3. 본문 변경·기존 내용 보존

새 probe·집계·후속 초안과 본 보고서를 추가했다. 계획/오늘할일의 현재 상태와 측정 결과 문서만 보정했다. 기존 #567/#568 입력·문서·근거는 유지했다. 프로젝트·ABI·lock·Studio·웹·글꼴 bytes는 변경하지 않았다. `.app`/확장/DMG와 원본 글꼴 bytes는 커밋하지 않는다. 선별 evidence의 개인 경로는 저장소 상대 경로/placeholder로 보정했고 원본은 로컬에 보존했다.

## 4. 검증 결과

| 검증 | 결과 |
|------|------|
| 직접 snapshot/consumers/transitions | 같은 최종 binary 12개 프로세스, 530건: 성공 514/busy 16. 원시 hash·단조 구간·요청별 scan/read/release 대조 통과 |
| 정확성/한도 guard | bytes 선읽기 없음·hit 추가 읽기 없음·lease 1회, 정책/객체/선택/원본 변화, 취소/stale·2 render/16 admission 회귀 통과 |
| 기존 native 기능 | CoreGraphics/Skia PNG·2페이지 PDF·권한 fallback·inode/ctime 무효화·한도 회귀 통과 |
| 제품 compile | 동일 source의 probe flag ON/OFF Release HostApp·두 확장 포함 빌드 성공. 123개 Swift 입력 hash 유지 |
| signed 실제 호출 | 후보 image UUID 일치, 157건의 314개 trace 전부 대응. 성공 126/busy 31, 역전/미대응/중복 interval 없음 |
| 제어 Thumbnail | 63건 PNG 성공. label별 miss 1/exact 10/larger 10, 같은 크기의 반복·OFF/ON PNG bytes 동일 |
| parser·helper | interleaved UUID/PID·누락/중복/역전/실패·다른 thread/시간 간격 거부, 잘못된 후보 guard 4건과 등록 경로 settle/거부 검증 통과 |
| 원래 앱 복원 | 두 백업과 v0.2.2 복원본 152개 파일/링크·hash/권한 일치, strict/deep 서명·원래 provider 경로·private UUID 제거 확인 |
| 환경 정리 | 최종 registration check issues/warnings 없음, 새 확장 crash 없음, 시험 창·소유 로그 수집 종료 |
| 문서/경계 | Python compile·shell 문법·no-AppKit·문서 링크/한국어·`git diff --check` 검증 결과를 선별 evidence에 보존 |

성능 수치는 통과 판정이 아니라 이 단계의 조사 결과다. 실제 Finder busy 31건은 다음 개선 과제이며 성공 행에 포함하지 않았다.

## 5. 결론과 잔여 위험

signed exactHit 10건의 metadata 중앙값은 OFF 1008.69ms, ON 두 번 1051.00/1018.37ms다. 같은 요청 전체 응답의 약 98%이며 larger hit도 같다. 잠정 500ms/30% 기준을 두 ON workload에서 충족하고 실제 다수 파일 busy도 재현됐다. **출시 전에 준비 비용과 정상 폴더 요청 처리를 개선하도록 권고한다.**

metadata는 전체 준비/내부 대기이며 순수 scan이나 화면 paint 시간이 아니다. 두 signed 반복은 같은 확장 PID의 독립 문서 workload다. 첫 ON Quick Look의 10회 키 조작에서 actual 요청은 6건이므로 10개 성능 sample로 부풀리지 않았다. 사용자 설치 원본의 bytes·상용 글꼴·최소 macOS/Intel·실제 한컴 삭제는 이번 수용 범위가 아니다.

## 6. 다음 단계 영향과 부산물

성능 후속 이슈/계획 승인 후 구조 최적화를 수행하고 최종 Mac 수용은 개선 후 같은 후보에 연결한다. #569 웹 안내는 아직 시작하지 않았다. Windows #566 및 #569/#562 전체 완료, PR·공개 배포도 수행하지 않았다.

예비 compile/build 정리 1,301,600,879 bytes에 더해, 복원과 provenance 대조 후 이번 후보·fixture·staging·중복 백업 6개 **1,733,261,022 bytes(논리 크기)**를 정리했다. 원시 로그/JSON·receipt·fixture·최종 직접 probe 및 SPM cache는 후속에 보존했다. 실제 가용 공간 증가량과 논리 크기를 같다고 주장하지 않는다.

## 7. 승인 요청

[성능 후속 이슈 초안](task_m020_569_performance_issue.md)의 등록·개선 계획 정렬을 다음으로 권고한다. 웹 안내와 출시 수용의 진행 순서를 해당 선행 개선에 맞추어 보정한다. 이번 단계에서 성능 구조 구현이나 Stage 3를 시작하지 않는다.
