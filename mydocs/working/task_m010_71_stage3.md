# Task #71 Stage 3 — 가독성/지엽 표현 개선과 core 운영 가이드 rename

## 단계 목적

문서 가독성과 위치 적합성을 개선하는 6개 항목(C1~C6)을 일괄 처리한다. 핵심은 폐기된 용어가 남은 파일명(`core_submodule_operation_guide.md`)을 atomic하게 rename해 매뉴얼 인덱스 정합을 회복하는 것이다.

## 산출물

### C1 — `swift_macos_code_rules_guide.md` 함수명 예시 일반화

```diff
- - iOS에서 가져온 초기 이름은 가능하면 플랫폼 중립 이름으로 정리한다.
-   - 예: `mapHWPFontToApple`, `resolveAppleFont`
+ - iOS에서 가져온 초기 이름은 macOS 또는 platform-neutral 이름으로 정리한다.
```

### C2 — `build_run_guide.md` 시행착오 규칙 일부를 troubleshootings로 이동

| 파일 | 변경 |
|------|------|
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 신규 (4개 절: `qlmanage -m plugins` 표시 한계, `pluginkit -mAvvv` 미노출 진단 순서, 이전 이름 설치본 처리, 표시명 vs extension 실패 혼동 방지) |
| `mydocs/manual/build_run_guide.md` | "반복 시행착오 방지 규칙" 7개 → 핵심 3개 + troubleshootings 링크 (10줄 → 7줄) |

매뉴얼에 유지한 핵심 3개:
- `CODE_SIGNING_ALLOWED=NO` Debug 산출물로 `pluginkit` 등록 판정 금지
- `build.noindex/` 위치 정책
- 동일 검증 중 단일 설치 경로 고정

troubleshootings로 이동한 4개: `qlmanage -m plugins` 한계, `pluginkit -mAvvv` 미노출 진단 순서, 이전 이름 설치본 처리, 표시명 문제와 extension 실패 혼동 방지.

### C3 — README 로드맵 ASCII 다이어그램 교체

```diff
-```text
-0.1 ──── 0.5 ──── 1.0 ──── 2.0
-뷰어      안정화    편집      에이전트
-```
+`v0.1 (뷰어) → v0.5 (안정화) → v1.0 (편집) → v2.0 (에이전트)`
```

ASCII art 정렬에 의존하지 않는 인라인 표현으로 교체. 그 아래 표(L34-38)가 같은 정보를 더 정확히 제공.

### C4 — `tech/task_m010_28_sample_provenance.md` 삭제

`git rm mydocs/tech/task_m010_28_sample_provenance.md`

근거 (구현계획서 Stage 3에 명시):
- task #28은 `report/task_m010_28_report.md`와 5개 stage report를 이미 가짐
- 본 문서의 핵심 결론(샘플 동일성, MIT 라이선스 판단, fixture 정책)은 final report와 `THIRD_PARTY_LICENSES.md`에 흡수됨
- `Vendor/rhwp/` 디렉터리가 더 이상 존재하지 않아 검증 명령(`cmp -s ... Vendor/rhwp/...`)이 stale
- 외부 참조 0건 (사전 grep 확인)

### C5 — `release_distribution_guide.md` "확정해야 할 사항" 분리

13개 bullet 단일 섹션 → 두 섹션으로 분리:
- **확정된 기준** (7개): GitHub 저장소, Cask token, app bundle name, internal product name, bundle id, 표시명, public DMG 산출물명
- **공개 release 전 확정 항목** (2개): DMG `sha256` 교체 시점, Developer ID 서명/notarization 실행 시점

이미 결정된 사항을 "확정해야 할" 톤으로 표기하던 혼선을 해소.

### C6 — `core_submodule_operation_guide.md` → `core_dependency_operation_guide.md` rename

```bash
git mv mydocs/manual/core_submodule_operation_guide.md \
       mydocs/manual/core_dependency_operation_guide.md
```

본문 첫 단락의 자가 모순 문장 제거:

```diff
- 이 문서는 ... 정리한다. 파일명은 과거 submodule 운영 문서명을 유지하지만, 현재 기준은 RustBridge의 git dependency와 lock provenance다.
+ 이 문서는 ... 정리한다. 현재 기준은 RustBridge의 git dependency와 lock provenance다.
```

운영 문서/매뉴얼/아키텍처에서 4개 참조 갱신:
- `AGENTS.md` L50 (핵심 강제 규칙)
- `AGENTS.md` L62 (필수 참조 문서)
- `RustBridge/README.md` L61 (관련 상세 문서)
- `mydocs/tech/project_architecture.md` L220 (운영 기준 문서)

## 본문 변경 정도

- C1, C3: 표면적 표현 개선. 의미 동일.
- C2: 매뉴얼 본문 정보는 troubleshootings 신규 문서로 이전, 손실 없음. 매뉴얼은 핵심 3개로 압축되어 가독성 향상.
- C4: 정보가 다른 문서에 이미 보존된 stale 문서 제거.
- C5: 정보 그대로 두 섹션으로 분리.
- C6: rename + 자가 모순 해소. core 기준 contract는 그대로 유지.
- 매뉴얼 인덱스 일관성: AGENTS.md의 두 참조 모두 갱신, 4개 운영 문서/매뉴얼/아키텍처 모두 새 파일명을 가리킴.

## 검증 결과

```text
=== git diff --check === diff ok
=== C1: function name examples removed === ok
=== C2: troubleshootings file exists === ok
=== C2: build_run_guide links to it === 1 (linked)
=== C3: ASCII roadmap removed === ok
=== C4: sample_provenance deleted === ok
=== C5: 확정된 기준 section === 1
=== C5: 공개 release 전 확정 항목 section === 1
=== C6: rename complete - old file gone === ok
=== C6: new file exists === ok
=== C6: stale refs in operational docs === ok — operational docs clean
=== C6: 첫 단락 self-contradiction 제거 === ok
=== Code safety net (check-no-appkit.sh) === OK: shared Swift code has no AppKit/UIKit dependencies
```

C6의 historical task docs(`mydocs/plans/task_m010_*`, `mydocs/working/task_m010_*_stage*.md`, `mydocs/report/*`)에 남은 옛 파일명 언급은 수행계획서의 "기존 보고서 본문 수정 금지(역사적 기록 보존)" 정책에 따라 의도적으로 유지. 본 task의 plan/impl/stage1/stage2 문서에 남은 옛 파일명은 rename 행위 자체를 설명하는 의도된 언급.

## 잔여 위험

- 신규 troubleshootings 문서 `finder_integration_validation_pitfalls.md`는 `task_m050_40_quicklook_thumbnail_registration_validation.md`와 주제가 일부 겹침. 두 문서는 적용 시점이 다름(전자: 일반 시행착오 방지 가이드, 후자: 특정 task 검증 기록)이라 공존 가능하지만, 향후 cross-reference 보강 여지 있음.
- C5의 두 섹션 명("확정된 기준" / "공개 release 전 확정 항목")이 release pipeline 진행 중 항목 분류와 정합한지는 다음 release 작업 시 재검토 필요.

## 다음 단계 영향

- Stage 4의 D1~D4는 모두 README, PR template, git_workflow_guide의 표현 개선. 본 단계와 독립적.
- 본 단계의 C6 rename으로 `core_dependency_operation_guide.md`라는 새 파일명이 4개 운영 문서에 등장. Stage 4 최종 정합성 확인에서 grep으로 일관성 재확인.
- 신규 troubleshootings 문서는 D2(PR template) 변경에 영향을 주지 않음.

## 승인 요청

- 본 단계 결과 검토 후 Stage 4(D1~D4 작은 표현 개선과 최종 정합성 확인) 진입 승인
