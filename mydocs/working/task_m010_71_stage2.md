# Task #71 Stage 2 — 중복 설명 정리와 단일 진실 원천 통합

## 단계 목적

같은 정보가 여러 문서에 중복 기재되던 4개 영역(B1~B4)을 단일 진실 원천 + 링크 구조로 재편해, 향후 정보 갱신이 한 곳에서만 이뤄지도록 한다.

## 산출물

### B1 — Demo/Preview vs Stable 채널 표 5곳 → tech 진실 원천

| 파일 | 변경 |
|------|------|
| `mydocs/tech/core_release_compatibility.md` | 진실 원천, 변경 없음 |
| `RustBridge/README.md` | "Core dependency 기준" 섹션의 표 제거. 핵심 결론 1문장 + tech 링크 (8줄 → 3줄) |
| `mydocs/manual/build_run_guide.md` | "Core dependency 모드" 섹션의 표와 중복 산문 제거. 핵심 1문장 + tech 링크 + update 명령 유지 (24줄 → 13줄) |
| `mydocs/manual/core_submodule_operation_guide.md` | "core 기준" 섹션 6개 bullet → 4개 압축 (6줄 → 4줄) |
| `README.md` L315-317 | Demo/Preview/Stable 산문 2단락 → 1단락 + tech 링크 |

### B2 — `mydocs/` 폴더 트리/표 → README는 트리만

| 파일 | 변경 |
|------|------|
| `mydocs/manual/document_structure_guide.md` | 진실 원천, 변경 없음 |
| `README.md` L443-462 | 폴더 트리는 유지하되 `pr/` 항목 추가, 그 아래 5행 파일명 규칙 표 제거 → "자세한 폴더 역할/파일명 규칙은 [document_structure_guide.md] 참조" 1줄 |

### B3 — Project Structure 섹션 architecture doc 링크 강화

| 파일 | 변경 |
|------|------|
| `mydocs/tech/project_architecture.md` | 진실 원천, 변경 없음 |
| `Sources/README.md` | 변경 없음 (Sources/ 한정 안내라 적절) |
| `README.md` L347 직후 | "타깃 간 소유 경계, 공통 Swift 계층, Rust bridge, 런타임 데이터 흐름은 [project_architecture.md] 참조" 1줄 추가 |

### B4 — Finder smoke test 명령 시퀀스 3곳 → build_run_guide 진실 원천

| 파일 | 변경 |
|------|------|
| `mydocs/manual/build_run_guide.md` | 진실 원천, 변경 없음 (Stage 2에서는 B1만 변경, "Finder 통합 확인" 섹션은 그대로) |
| `README.md` L236-262 | `qlmanage -r`, `qlmanage -r cache`, thumbnail smoke, `qlmanage -p` 별도 코드 블록 4개 제거. 핵심 4줄(package/ditto/pluginkit) + build_run_guide 링크 1줄로 통합 (27줄 → 11줄) |
| `mydocs/manual/release_distribution_guide.md` L106-127 | LSREGISTER + ditto + pluginkit + qlmanage 16줄 + 산문 2줄 → build_run_guide 링크 + release pipeline 특수 항목 3 bullet (22줄 → 7줄) |

## 본문 변경 정도

- 핵심 정보(Demo/Preview vs Stable contract, mydocs 폴더 역할, Project Structure 의미, Finder smoke 명령)는 모두 단일 진실 원천에 그대로 남아 있고, 다른 문서는 결론 + 링크로 압축.
- 정보 손실 없음 검증: B1은 5개 문서 모두 "Demo/Preview" 또는 "Stable" 키워드를 여전히 포함(grep 통과), B4의 핵심 명령(`pluginkit -a`, `pluginkit -mAvvv`, `package-release.sh`)은 README에 유지.
- 문서 길이 감소 합계 약 60줄 (중복 표/명령 시퀀스 제거).

## 검증 결과

```text
=== git status ===
 M README.md
 M RustBridge/README.md
 M mydocs/manual/build_run_guide.md
 M mydocs/manual/core_submodule_operation_guide.md
 M mydocs/manual/release_distribution_guide.md

=== git diff --check ===
diff ok

=== B1: 5 docs still mention Demo/Preview or Stable ===
mydocs/manual/build_run_guide.md
mydocs/manual/core_submodule_operation_guide.md
README.md
RustBridge/README.md
mydocs/tech/core_release_compatibility.md

=== B1: links to truth source exist ===
mydocs/manual/core_submodule_operation_guide.md:1
RustBridge/README.md:1
mydocs/manual/build_run_guide.md:1
README.md:1

=== B1: redundant tables removed ===
ok — tables gone

=== B2: README mydocs tree intact ===
2 (orders/yyyymmdd.md 표기 잔존 — tree 그대로)

=== B2: file naming table removed ===
inline 예시 1회만 잔존 (table 자체는 제거됨)

=== B2: link to document_structure_guide ===
1

=== B3: link to project_architecture ===
3

=== B4: README smoke commands reduced ===
qlmanage -r 1회 (build_run_guide 링크 설명 안 inline)

=== B4: README link to build_run_guide ===
2

=== B4: release_distribution short ===
qlmanage 언급 3회 (build_run_guide 링크 설명 안 inline)
```

모든 검증 통과. B2의 inline `task_{milestone}_{issue}.md` 1회 잔존, B4의 `qlmanage -r` 1회 잔존은 모두 "build_run_guide에 자세히"라는 안내문 안에 위치한 의도적 inline 언급으로, 별도 코드 블록/표가 아님.

## 잔여 위험

- 본 단계는 정보 통합/링크화에 집중. 진실 원천 4개(`core_release_compatibility.md`, `document_structure_guide.md`, `project_architecture.md`, `build_run_guide.md`)는 본 단계에서 변경하지 않았으므로 진실 원천 자체의 내용은 검증 범위 밖.
- 향후 진실 원천 갱신 시 본 단계에서 만든 링크가 깨지지 않도록 주의 (rename/section 이름 변경 시).

## 다음 단계 영향

- Stage 3의 C6 rename(`core_submodule_operation_guide.md` → `core_dependency_operation_guide.md`)이 본 단계에서 만든 4개 문서의 tech 링크에는 영향 없음 (모두 `core_release_compatibility.md` 링크).
- C6 rename은 별도로 AGENTS.md, RustBridge/README.md, project_architecture.md, core_submodule_operation_guide.md(파일 자신) 4곳을 갱신해야 함.
- B2에서 README 트리에 `pr/` 항목을 새로 추가했으므로, document_structure_guide.md와 정합 유지 (이미 거기에는 `pr/` 항목 있음).

## 승인 요청

- 본 단계 결과 검토 후 Stage 3(C1~C6 가독성/지엽 표현 개선과 core 가이드 rename) 진입 승인
