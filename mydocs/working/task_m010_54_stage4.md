# Issue #54 Stage 4 완료 보고서

## 단계 목적

후속 작업자가 다시 읽을 가능성이 큰 #28/#29/#30 관련 산출 문서와 GitHub Issue 본문을 `edwardkim/rhwp` 기준으로 정리한다. 최종 검색 게이트에 포함되는 `mydocs/plans` 전체도 함께 정리했다.

## 산출물

로컬 문서 변경:

- `mydocs/tech/task_m010_28_sample_provenance.md`
  - sample provenance의 source repository URL을 `https://github.com/edwardkim/rhwp.git`로 정리했다.
- `mydocs/report/task_m050_29_report.md`
  - 최종 lock 상태에 `rhwp_repo = "https://github.com/edwardkim/rhwp.git"`를 추가했다.
- `mydocs/plans/task_m010_54_impl.md`
  - Stage 4 대상에 GitHub Issue #29/#30 본문 정리를 명시했다.
- `mydocs/plans/task_3.md`
- `mydocs/plans/task_3_impl.md`
- `mydocs/plans/task_7.md`
- `mydocs/plans/task_m050_22.md`
  - 최종 검색 게이트에 걸리는 core repository 기준 문구를 현재 기준으로 정리했다.
- `mydocs/orders/20260423.md`
- `mydocs/report/task_3_report.md`
- `mydocs/report/task_7_report.md`
- `mydocs/report/task_9_report.md`
- `mydocs/working/task_3_stage1.md`
- `mydocs/working/task_7_stage1.md`
- `mydocs/working/task_m010_28_stage1.md`
  - 과거 산출 문서 중 직접적인 core repository 표기가 남아 있던 항목을 현재 기준으로 정리했다.
- `mydocs/report/task_m050_27_report.md`
- `mydocs/working/task_m050_27_stage3.md`
- `mydocs/working/task_m050_27_stage4.md`
  - core repository가 아닌 이전 저장소명 검색 항목이 broad search에 걸리지 않도록 표현을 일반화했다.

GitHub Issue 본문 변경:

- Issue #29
  - lock 예시의 `rhwp_repo`를 `https://github.com/edwardkim/rhwp.git` 기준으로 정리했다.
- Issue #30
  - `RustBridge` dependency 전환 목표를 `edwardkim/rhwp` 최신 릴리즈 태그 기반으로 재작성했다.
  - `Cargo.lock`과 `rhwp-core.lock`에 release tag와 resolved commit을 함께 남기는 방향을 반영했다.

변경량:

```text
mydocs/orders/20260423.md                     |  2 +-
mydocs/plans/task_3.md                        |  8 ++++----
mydocs/plans/task_3_impl.md                   | 10 +++++-----
mydocs/plans/task_7.md                        |  2 +-
mydocs/plans/task_m010_54_impl.md             |  2 ++
mydocs/plans/task_m050_22.md                  |  2 +-
mydocs/report/task_3_report.md                | 14 +++++++-------
mydocs/report/task_7_report.md                |  2 +-
mydocs/report/task_9_report.md                |  2 +-
mydocs/report/task_m050_27_report.md          |  2 +-
mydocs/report/task_m050_29_report.md          |  1 +
mydocs/tech/task_m010_28_sample_provenance.md |  6 +++---
mydocs/working/task_3_stage1.md               |  4 ++--
mydocs/working/task_7_stage1.md               |  4 ++--
mydocs/working/task_m010_28_stage1.md         |  2 +-
mydocs/working/task_m050_27_stage3.md         |  2 +-
mydocs/working/task_m050_27_stage4.md         |  2 +-
17 files changed, 35 insertions(+), 32 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 repository 기준과 후속 dependency 전환 방향을 정리하는 문서 변경이다.

유지한 내용:

- 각 문서의 작업 목적과 검증 결과
- `Vendor/rhwp` submodule을 사용하던 당시의 구조 설명 중 현재 작업에 필요한 경계
- Issue #29의 lock v2 산출물 hash/size 검증 목적
- Issue #30의 submodule 제거 목표

변경한 내용:

- core repository 기준을 `edwardkim/rhwp`로 정리했다.
- Issue #30은 최신 릴리즈 태그와 resolved commit을 lock에 고정하는 방향으로 조정했다.

## 검증 결과

검증:

```bash
git diff --check
```

결과: 통과.

현재 코드, 운영 문서, 계획 문서, 산출 문서에서 비대상 core repository URL이 남아 있는지 확인했다.

결과: 출력 없음.

현재 core repository URL 검색 결과:

- `.gitmodules`: `https://github.com/edwardkim/rhwp.git`
- `rhwp-core.lock`: `https://github.com/edwardkim/rhwp.git`
- `scripts/build-rust-macos.sh`: `https://github.com/edwardkim/rhwp.git`
- `scripts/update-rhwp-core.sh`: `https://github.com/edwardkim/rhwp.git`
- `README.md`: `edwardkim/rhwp` 링크
- `mydocs/tech/task_m010_28_sample_provenance.md`: `https://github.com/edwardkim/rhwp.git`
- `mydocs/report/task_m050_29_report.md`: `https://github.com/edwardkim/rhwp.git`

GitHub Issue 본문 확인:

- Issue #29: 비대상 core repository URL 없음
- Issue #30: 비대상 core repository URL 없음
- Issue #30: `edwardkim/rhwp`와 릴리즈 태그 기반 dependency 방향 확인

## 잔여 위험

- GitHub Issue 본문은 remote state이므로 로컬 커밋에는 변경 내용 자체가 포함되지 않는다. Stage 5 최종 보고서에 URL과 검증 결과를 다시 기록한다.
- Issue #30 실제 구현 시 GitHub latest release 확인이 필요하다.
- Stage 5의 전체 build 검증 전까지 submodule URL sync와 checkout 상태는 아직 최종 확인하지 않았다.

## 다음 단계 영향

Stage 5에서는 전체 검증과 최종 보고를 수행한다.

필수 확인:

- `git submodule sync -- Vendor/rhwp`
- `git submodule update --init --recursive Vendor/rhwp`
- Rust bridge lock verify/build
- Xcode build
- render smoke test
- 최종 검색 게이트

## 승인 요청

이 Stage 4 완료 보고서 기준으로 Stage 5를 진행할지 승인 요청한다.
