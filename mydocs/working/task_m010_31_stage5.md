# Task #31 Stage 5 완료 보고서

## 단계 목적

직접 비교 명칭 제거 여부, Demo/Preview vs Stable 표현, active 문서 검색 gate를 검증한다. Stage 5는 검증 중심 단계이며, source/project/build script는 변경하지 않는다.

## 변경 파일

- `mydocs/plans/task_m010_31.md`
- `mydocs/working/task_m010_31_stage1.md`
- `mydocs/working/task_m010_31_stage2.md`
- `mydocs/working/task_m010_31_stage3.md`
- `mydocs/working/task_m010_31_stage4.md`
- `mydocs/working/task_m010_31_stage5.md`
- `mydocs/orders/20260426.md`

## 변경 내용

현재 Task #31 문서 보정:

- 계획서와 단계 보고서의 검증 예시에서 직접 비교 명칭과 제외 비교 표현을 실제 문자열로 쓰지 않도록 보정했다.
- 외부 참고 구현에서 도입하지 않는 방향은 “native render tree 기반 viewer/preview 방향 유지”, “제품 타깃 경계 유지”, “현재 Rust bridge FFI 경계 유지”처럼 이 저장소의 현재 정책 중심으로 표현했다.

검색 gate:

- `README.md`, `mydocs/tech`, `mydocs/manual`, `Sources`, `RustBridge`에서 직접 비교 명칭과 제외 비교 표현이 검출되지 않는 것을 확인했다.
- 현재 Task #31 계획서와 Stage 1-4 보고서에서도 같은 표현이 검출되지 않는 것을 확인했다.
- `RustBridge/target/**`는 생성 산출물 노이즈이므로 검색 범위에서 제외했다.

Demo/Preview vs Stable:

- `README.md`, `project_architecture.md`, `build_run_guide.md`, `RustBridge/README.md`에서 Demo/Preview는 `git` + `rev` commit pin으로 설명된다.
- Stable은 release tag + resolved commit 기준이며, upstream release tag가 필요한 bridge API를 포함할 때 별도 승격하는 경로로 설명된다.
- branch/floating ref는 배포 기준으로 사용하지 않는다고 설명된다.
- 현재 v0.1.0 목표는 Demo/Preview release라는 표현이 유지된다.

Submodule 표현:

- 사용자-facing 문서 검색에서 과거 submodule 경로 표현은 검출되지 않았다.
- `core_submodule_operation_guide.md` 파일명 링크는 호환 유지 목적의 기존 매뉴얼 이름으로 남아 있으며, Stage 5에서는 문서 파일명 변경 범위가 아니므로 유지했다.

## 검증 결과

diff whitespace:

```text
$ git diff --check
결과: 통과
```

직접 비교 명칭과 제외 비교 표현:

```text
$ rg --line-number '<실제 비교 대상 프로젝트명>|<제외 비교 표현>' README.md mydocs/tech mydocs/manual Sources RustBridge --glob '!RustBridge/target/**'
결과: 출력 없음
```

현재 Task #31 문서:

```text
$ rg --line-number '<실제 비교 대상 프로젝트명>|<제외 비교 표현>' mydocs/plans/task_m010_31.md mydocs/working/task_m010_31_stage1.md mydocs/working/task_m010_31_stage2.md mydocs/working/task_m010_31_stage3.md mydocs/working/task_m010_31_stage4.md
결과: 출력 없음
```

Demo/Preview와 Stable 표현:

```text
$ rg --line-number 'Demo/Preview|Stable|release tag|resolved commit|git dependency|rev|tag|branch/floating|prerelease' README.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md Sources/README.md RustBridge/README.md mydocs/plans/task_m010_31.md
결과: Demo/Preview commit pin, Stable release tag 기준, branch/floating ref 금지 표현 확인
```

Submodule 표현:

```text
$ rg --line-number 'Vendor/rhwp|git submodule|submodule' README.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md Sources/README.md RustBridge/README.md
결과: 기존 매뉴얼 파일명 링크만 검출. 본문 정책 표현 문제 없음.
```

## 잔여 위험

- Stage 5는 문서 검색 gate 단계이므로 build는 실행하지 않았다.
- 과거 완료된 task plan/report에는 당시의 조사 기록이 남아 있을 수 있다. 이번 단계의 gate는 현재 사용자-facing 문서와 현재 Task #31 문서 기준으로 수행했다.

## 다음 단계

Stage 6에서는 최종 보고서를 작성하고 오늘할일 완료 처리, 최종 커밋, publish branch/PR 준비 절차를 진행한다.

## 승인 요청

Stage 5 검색 gate 검증을 완료했다. 이 보고서 기준으로 Stage 6 `최종 보고서 작성, 오늘할일 완료 처리, PR 준비`를 진행할지 승인 요청한다.
