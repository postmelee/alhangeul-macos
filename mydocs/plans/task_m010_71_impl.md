# Task #71 구현 계획서

본 문서는 [`task_m010_71.md`](task_m010_71.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/Users/melee/Documents/projects/rhwp-mac-task71` (분리 worktree)
- **Branch**: `local/task71` (origin/devel 기준)
- **메인 worktree** (`/Users/melee/Documents/projects/rhwp-mac`)에서 동시 진행 중인 task #70 코드 작업과 격리

---

## Stage 1 — 사실 오류와 깨진 참조 정정 (A1~A4)

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `THIRD_PARTY_LICENSES.md` | L5 "git submodule" → "Cargo git dependency from `RustBridge/Cargo.toml`" | A1 |
| `mydocs/feedback/.gitkeep` | 신규 생성 (empty) | A2 — 4개 문서가 절차상 참조하는 폴더 활성화 |
| `mydocs/manual/pr_process_guide.md` | L7 "AGENTS.md의 Git 워크플로우" → `[git_workflow_guide.md](git_workflow_guide.md)` | A3 |
| `CONTRIBUTING.md` | 신규 생성 | A4 — edwardkim/rhwp 포맷 참고, 본 프로젝트(`postmelee/alhangeul-macos`)에 맞게 적응 |

### `CONTRIBUTING.md` 구조 (A4)

edwardkim/rhwp의 CONTRIBUTING.md 섹션 구조를 그대로 따르되 본 프로젝트 기준으로 명령/링크/예시를 교체.

1. 처음 참여하시나요? — Releases 안내, 개발 환경 설정(`rustup target add`, `cargo install cbindgen`, `brew install xcodegen`, `./scripts/build-rust-macos.sh`, `xcodegen generate`, `xcodebuild`), 첫 기여 찾기
2. 기여 방법 — 버그 리포트(macOS/Xcode 버전, 한컴/rhwp/알한글 비교 스크린샷, `pluginkit -mAvvv` 결과), Fork & PR 워크플로우, PR 전 체크리스트(`build-rust-macos.sh`, `check-no-appkit.sh`, `xcodegen generate`, `xcodebuild`, `validate-stage3-render.sh`), HWP 샘플 제공
3. 브랜치 규칙 — `main`/`devel` + 컨트리뷰터/메인테이너 차이, 상세는 `git_workflow_guide.md` 링크
4. 디버깅 가이드 — `validate-stage3-render.sh`, `render-debug-compare.sh`, `qlmanage -p`, `qlmanage -t -x`
5. 프로젝트 구조 — Sources/RustBridge/Frameworks/scripts/mydocs 트리, 의존성 방향
6. 코드 스타일 — `check-no-appkit.sh`, FFI 안전성 규칙, `project.yml` 원본 정책
7. 문서 작성 규칙 — `mydocs/` 폴더 표, 파일명 규칙, 기여자 작성 범위, `pr/` 폴더는 메인테이너 전용
8. HWPUNIT 참고
9. 라이선스 — MIT

### 단계 검증

```bash
cd /Users/melee/Documents/projects/rhwp-mac-task71
git diff --check
grep -n "submodule" THIRD_PARTY_LICENSES.md && echo "FAIL" || echo "ok"
grep -n "AGENTS.md.*Git 워크플로우" mydocs/manual/pr_process_guide.md && echo "FAIL" || echo "ok"
test -d mydocs/feedback && echo "ok"
test -f CONTRIBUTING.md && echo "ok"
grep -c "git_workflow_guide" mydocs/manual/pr_process_guide.md   # ≥1
```

### 커밋

```
Task #71 Stage 1: 사실 오류와 깨진 참조 정정
```

---

## Stage 2 — 중복 설명 정리 (B1~B4)

### B1. Demo/Preview vs Stable 채널 표 5곳 → tech 진실 원천

진실 원천: [`mydocs/tech/core_release_compatibility.md`](../tech/core_release_compatibility.md) (현행 유지, 변경 없음)

| 파일 | 위치 | 정리 방향 |
|------|------|----------|
| `README.md` | L317 산문 | "현재 lock은 Demo/Preview commit pin이며 자세한 channel/lock contract는 [core_release_compatibility.md] 참조" 1~2문장으로 축약 |
| `RustBridge/README.md` | L29-32 표 | 표 제거, "channel별 dependency 기준은 [core_release_compatibility.md] 참조" |
| `mydocs/manual/build_run_guide.md` | L42-49 표 | 표 제거, "channel별 dependency 기준은 [core_release_compatibility.md] 참조". 그 아래 운영 흐름 설명은 유지 |
| `mydocs/manual/core_submodule_operation_guide.md` | L22-27 산문 | 산문 핵심 결론(Stable=tag+commit, Demo=commit, branch 금지)만 1~2문장으로 유지 + tech 링크 (이 파일은 Stage 3에서 rename됨) |

### B2. `mydocs/` 폴더 트리/표 정리

진실 원천: [`mydocs/manual/document_structure_guide.md`](../manual/document_structure_guide.md) (현행 유지)

| 파일 | 위치 | 정리 방향 |
|------|------|----------|
| `README.md` | L443-462 | 폴더 트리만 유지(`feedback/` 추가 후), 그 아래의 "파일명 규칙" 표 삭제하고 "자세한 폴더 역할/파일명 규칙은 [document_structure_guide.md] 참조" |

### B3. Project Structure 트리 3곳

진실 원천: [`mydocs/tech/project_architecture.md`](../tech/project_architecture.md) (현행 유지)

| 파일 | 위치 | 정리 방향 |
|------|------|----------|
| `README.md` | L323-347 | 트리는 유지하되 트리 아래 추가 설명("`project.yml`은 ..." 단락)은 유지(빌드 안내라 README에 필요), 단 architecture doc 링크 한 줄 강조 |
| `Sources/README.md` | L5-12 | 변경 없음 (Sources/ 한정 안내라 적절) |

### B4. Finder smoke test 명령 시퀀스 3곳

진실 원천: [`mydocs/manual/build_run_guide.md`](../manual/build_run_guide.md) (현행 유지)

| 파일 | 위치 | 정리 방향 |
|------|------|----------|
| `README.md` | L236-256 | `package-release.sh`, `ditto`, `pluginkit -a`, `pluginkit -mAvvv` 핵심 4~5줄만 남기고 "전체 smoke 흐름과 LSREGISTER 갱신 절차는 [build_run_guide.md] 참조" |
| `mydocs/manual/release_distribution_guide.md` | L108-123 | "Finder 통합 smoke test 절차는 [build_run_guide.md] 참조"로 압축. release pipeline 특수 항목(`qlmanage -p` 자동화 주의 등)만 유지 |

### 단계 검증

```bash
cd /Users/melee/Documents/projects/rhwp-mac-task71
git diff --check
# 정보 누락 점검 — 핵심 키워드는 어딘가에 여전히 존재
grep -l "Demo/Preview\|Stable" README.md RustBridge/README.md mydocs/manual/build_run_guide.md mydocs/manual/core_submodule_operation_guide.md mydocs/tech/core_release_compatibility.md
grep -l "feedback/\|orders/\|plans/\|working/\|report/" README.md mydocs/manual/document_structure_guide.md
grep -l "pluginkit -a\|build-rust-macos.sh" mydocs/manual/build_run_guide.md
# 진실 원천으로의 링크가 만들어졌는지 확인
grep -c "core_release_compatibility" README.md RustBridge/README.md mydocs/manual/build_run_guide.md mydocs/manual/core_submodule_operation_guide.md
grep -c "document_structure_guide" README.md
grep -c "build_run_guide" README.md mydocs/manual/release_distribution_guide.md
```

### 커밋

```
Task #71 Stage 2: 중복 설명 정리와 단일 진실 원천 통합
```

---

## Stage 3 — 가독성/지엽 표현 개선과 rename (C1~C6)

### C1. `swift_macos_code_rules_guide.md` 함수명 예시 일반화

L25-26:

```diff
- - iOS에서 가져온 초기 이름은 가능하면 플랫폼 중립 이름으로 정리한다.
-   - 예: `mapHWPFontToApple`, `resolveAppleFont`
+ - iOS에서 가져온 초기 이름은 macOS 또는 platform-neutral 이름으로 정리한다.
```

### C2. `build_run_guide.md` "반복 시행착오 방지 규칙" 일부 이동

L249-258 6개 항목 중:

- **유지(매뉴얼)**: 항상 적용되는 핵심 3개 — `CODE_SIGNING_ALLOWED=NO`로 등록 판정 금지, `build.noindex/` 위치 정책, 동일 검증 중 단일 설치 경로 고정
- **이동(troubleshootings)**: 디버깅 노하우 3개 — `qlmanage -m plugins` 한계, 이전 이름 설치본 처리, `pluginkit` 실패 시 codesign/plist/InfoPlist.strings 진단 순서

이동 대상 신규 파일: `mydocs/troubleshootings/finder_integration_validation_pitfalls.md`

신규 troubleshooting 문서 구조:
- 목적: Finder/Quick Look/Thumbnail 통합 검증 중 반복 시행착오 패턴
- 1. `pluginkit`/`qlmanage`의 표시 한계
- 2. 이전 이름 설치본(`RhwpMac.app`, `알한글.app`) 충돌 의심 시 진단 순서
- 3. `pluginkit -mAvvv` 미노출 시 codesign/plist/`InfoPlist.strings` 점검 순서
- 4. 표시명 문제와 extension 실패 혼동 방지 기준

`build_run_guide.md`에는 한 줄 링크 추가: "Finder 통합 검증 중 반복되는 시행착오 패턴은 [`finder_integration_validation_pitfalls.md`](../troubleshootings/finder_integration_validation_pitfalls.md) 참조"

### C3. README 로드맵 ASCII 다이어그램 교체

L29-32:

```diff
-```text
-0.1 ──── 0.5 ──── 1.0 ──── 2.0
-뷰어      안정화    편집      에이전트
-```
```

ASCII 블록을 삭제. 그 아래 L34-38 표가 같은 정보를 더 정확하게 담고 있으므로, 그 표 위에 한 문장의 인라인 요약만 둔다:

```
v0.1 (뷰어) → v0.5 (안정화) → v1.0 (편집) → v2.0 (에이전트)
```

### C4. `tech/task_m010_28_sample_provenance.md` 삭제

작업지시자 승인된 방향: 삭제. 근거:
- task #28의 final report `mydocs/report/task_m010_28_report.md`가 존재
- 본 문서 핵심 결론(샘플 동일성 검증, 라이선스 판단)은 final report와 코드(`samples/` 자체)에 흡수됨
- `Vendor/rhwp/` 디렉터리가 더 이상 존재하지 않아 검증 명령(`cmp -s ... Vendor/rhwp/...`)은 stale
- 외부 참조 0건 (사전 grep 확인)

```bash
git rm mydocs/tech/task_m010_28_sample_provenance.md
```

### C5. `release_distribution_guide.md` "확정해야 할 사항" 분리

L26-37 13개 항목을 두 섹션으로 분리:

- **확정된 기준** (이미 확정된 7개): 저장소명 `postmelee/alhangeul-macos`, 산출물명/Cask token `alhangeul-macos`, 앱 표시명(`알한글`/`AlhangeulMac`), filesystem bundle name `AlhangeulMac.app`, 내부 Xcode product name, bundle identifier `com.postmelee.alhangeulmac`, public DMG 산출물명 `alhangeul-macos-<version>.dmg`
- **공개 release 전 확정 항목** (남은 결정 사항): SHA256 `:no_check` → 실제 digest 교체 시점, Developer ID 서명/notarization 실행 시점

### C6. `core_submodule_operation_guide.md` rename + 4개 참조 갱신

```bash
git mv mydocs/manual/core_submodule_operation_guide.md mydocs/manual/core_dependency_operation_guide.md
```

본문 첫 단락에서 "파일명은 과거 submodule 운영 문서명을 유지하지만, 현재 기준은 RustBridge의 git dependency와 lock provenance다." 문장 제거 (rename으로 모순 해소).

참조 갱신 4곳:
- `AGENTS.md` L50: `[\`core_submodule_operation_guide.md\`](mydocs/manual/core_submodule_operation_guide.md)` → `[\`core_dependency_operation_guide.md\`](mydocs/manual/core_dependency_operation_guide.md)`
- `AGENTS.md` L62: 동일 패턴 갱신
- `RustBridge/README.md` L61: `mydocs/manual/core_submodule_operation_guide.md` → `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/tech/project_architecture.md` L220: 동일 패턴 갱신

### 단계 검증

```bash
cd /Users/melee/Documents/projects/rhwp-mac-task71
git diff --check
grep -n "mapHWPFontToApple\|resolveAppleFont" mydocs/manual/swift_macos_code_rules_guide.md && echo "FAIL" || echo "ok"
grep -rln "core_submodule_operation_guide" . --include="*.md" && echo "FAIL" || echo "ok"
test -e mydocs/manual/core_dependency_operation_guide.md && echo "ok"
test ! -e mydocs/manual/core_submodule_operation_guide.md && echo "ok"
test ! -e mydocs/tech/task_m010_28_sample_provenance.md && echo "ok"
test -f mydocs/troubleshootings/finder_integration_validation_pitfalls.md && echo "ok"
grep -c "finder_integration_validation_pitfalls" mydocs/manual/build_run_guide.md   # ≥1
grep -c "확정된 기준" mydocs/manual/release_distribution_guide.md   # 1
```

### 커밋

```
Task #71 Stage 3: 가독성과 지엽 표현 개선, core 운영 가이드 rename
```

---

## Stage 4 — 작은 표현 개선과 최종 정합성 확인 (D1~D4)

### D1. `README.md` L108 섹션 분리 라인

```diff
- Codex Plugin 또는 Claude Code 연동 도구로 packaging
+ Codex Plugin 또는 Claude Code 연동 도구로 packaging
+
+---

자세한 구조와 bridge 정책은 [아키텍처 문서](mydocs/tech/project_architecture.md)를 참조하세요.
```

### D2. `.github/pull_request_template.md` placeholder 명시

L37-46 영역:

- 주석에 "아래 `m{milestone}_{issue}` 부분은 placeholder입니다. 실제 마일스톤/이슈 번호로 치환하세요." 추가
- 예시 `task_m000_0`을 `task_m{milestone}_{issue}`로 교체 (`m000`은 `document_structure_guide.md`에서 금지)

### D3. `git_workflow_guide.md` 다이어그램 단순화

L24-34:

```diff
-```
-local/task{N}  ──커밋──커밋──┐
-local/task{N+1}──커밋──커밋──┤
-                              ├─→ publish/task{N} push
-                              │
-                              ├─→ devel 대상 PR 생성 + 리뷰 + merge
-                              │
-                              ├─→ devel 누적
-                              │
-                              ├─→ main PR 생성 + 리뷰 + merge + 태그 (릴리즈 시점)
-```
+```
+local/task{N} ── 커밋 · 커밋 · 커밋 ──→ publish/task{N} push
+                                          │
+                                          └─→ devel 대상 PR → 리뷰 → merge
+                                                                       │
+                                                                       └─→ devel 누적
+                                                                              │
+                                                                              └─→ main PR (릴리즈 시점) → 태그
+```
+
+병렬 task는 각각 독립적인 `local/task{N}` 브랜치로 위 흐름을 반복한다.
```

### D4. README "타스크 진행 절차" 섹션 압축

L417-432 6단계 산문 형태를 한 줄 + 링크로 압축:

```diff
-### 타스크 진행 절차
-
-1. `gh issue create` → GitHub Issue 등록
-2. `origin/devel` 기준으로 `local/task{issue번호}` 브랜치 생성
-3. 수행계획서 작성 → 구현 계획서 작성 → 구현 → 검증
-4. 단계별 완료 보고서와 최종 보고서 작성
-5. `publish/task{issue번호}`로 push 후 `.github/pull_request_template.md` 기준으로 `devel` 대상 draft PR 생성
-6. PR merge 후 이슈, 오늘할일 상태, merge 완료된 `publish/task{issue번호}` 원격 브랜치 정리
+### 타스크 진행 절차
+
+이슈 → 브랜치 → 오늘할일 → 수행계획서 → 구현계획서 → 구현 → 검증 → 단계 보고 → 최종 보고 → PR 게시 → merge 후 정리.
+
+15단계 상세, 승인 게이트, 커밋 메시지 규칙은 [`task_workflow_guide.md`](mydocs/manual/task_workflow_guide.md)를 참고하세요.
```

### 최종 정합성 확인

```bash
cd /Users/melee/Documents/projects/rhwp-mac-task71
git diff --check
# 19개 점검 대상 문서 잔존 이슈 점검
grep -rn "git submodule" THIRD_PARTY_LICENSES.md && echo "FAIL" || echo "ok"
grep -rn "AGENTS.md.*Git 워크플로우" mydocs/manual/ && echo "FAIL" || echo "ok"
grep -rn "task_m000_0" .github/ && echo "FAIL" || echo "ok"
grep -rln "core_submodule_operation_guide" . --include="*.md" && echo "FAIL" || echo "ok"
test -e CONTRIBUTING.md && test -d mydocs/feedback && echo "ok"
test -e mydocs/manual/core_dependency_operation_guide.md && echo "ok"
test ! -e mydocs/tech/task_m010_28_sample_provenance.md && echo "ok"
# 코드 무영향 보장
./scripts/check-no-appkit.sh
```

### 커밋

```
Task #71 Stage 4: 작은 표현 개선과 최종 정합성 확인
```

---

## 단계별 산출물 요약

| Stage | 변경/생성/삭제 파일 수 (예상) | 핵심 검증 |
|-------|-------------------------|----------|
| 1 | 4개 변경/생성 | 깨진 참조 0건 |
| 2 | 7개 변경 | 진실 원천 링크 일치 |
| 3 | 8~10개 변경 (rename + delete + 신규 troubleshootings) | rename 참조 누락 0건 |
| 4 | 3개 변경 | 19개 문서 잔존 이슈 0건 + `check-no-appkit.sh` 통과 |

## 작업 후 진행

- 모든 단계 완료 후 [`task-final-report`](../skills/task-final-report/SKILL.md) skill로 최종 보고서 작성
- `publish/task71` push → devel 대상 draft PR
- PR merge 후 [`pr-merge-cleanup`](../skills/pr-merge-cleanup/SKILL.md) skill로 worktree/branch 정리

## 승인 요청 사항

1. 본 구현계획서의 4단계 분해와 단계별 변경 범위
2. C2의 신규 troubleshooting 문서명 `finder_integration_validation_pitfalls.md` (한국어 제목 톤은 본문에 한국어로 기록)
3. C5의 "확정된 기준" / "공개 release 전 확정 항목" 두 섹션 분리 방향
4. C6 rename 시 `core_submodule_operation_guide.md` 본문 첫 단락의 "파일명은 과거 submodule ..." 문장 제거 (rename으로 자가 모순 해소)
5. 본 구현계획서 승인 후 Stage 1부터 순차 진행
