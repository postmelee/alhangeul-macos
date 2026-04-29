# Task #82 구현 계획서

본 문서는 [`task_m010_82.md`](task_m010_82.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 진행한다.

## 작업 환경

- **Worktree**: `/Users/melee/Documents/projects/rhwp-mac`
- **Branch**: `local/task82`
- **기준 이슈**: [#82](https://github.com/postmelee/alhangeul-macos/issues/82)
- **업스트림 기준**: `origin/devel` `3238972` 반영 후 진행
- **범위**: 렌더링 smoke/debug compare 도구의 역할, 사용 시점, 산출물 해석, PR 검증 기록 문서 정리

## 구현 원칙

- `validate-stage3-render.sh`는 기본 샘플에 대한 자동 smoke 관문으로 설명한다.
- `render-debug-compare.sh`는 특정 문서의 core/native 차이를 분해하는 진단 도구로 설명한다.
- 상세 판단 흐름은 renderer 비교 매뉴얼에 모으고, README/CONTRIBUTING에는 짧은 진입 링크만 둔다.
- 실제 renderer 동작, core dependency, Finder/Quick Look 등록 로직은 수정하지 않는다.
- 문서 이동 시 기존 경로 링크가 완전히 끊기지 않도록 forwarding 문서 또는 링크 보정을 함께 처리한다.
- PR 템플릿은 모든 PR에 과한 검증을 강제하지 않고 renderer 관련 변경에서만 선택적으로 기록할 수 있게 한다.

## Stage 1: 문서 위치와 링크 구조 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/troubleshootings/render_core_native_compare.md` | manual 이동 대상 여부 최종 확인 | 반복 절차 문서 성격 |
| `mydocs/manual/render_core_native_compare_guide.md` | 필요 시 새 manual 경로로 이동 | 상세 절차 진실 원천 |
| `mydocs/troubleshootings/render_core_native_compare.md` | 이동 시 forwarding 문서로 축약 | 기존 링크 보호 |
| `README.md`, `CONTRIBUTING.md`, `mydocs/manual/build_run_guide.md` | 기존 링크 검색과 Stage 2~3 수정 대상 확정 | Stage 1에서는 최소 수정 |

### 확인 기준

- `render_core_native_compare.md`가 특정 장애 기록인지, 반복 사용 매뉴얼인지 기준을 문서 구조 규칙에 맞춰 판단한다.
- manual 이동 시 상대 링크가 가리킬 최종 경로를 확정한다.
- 기존 `../troubleshootings/render_core_native_compare.md` 링크를 모두 찾아 Stage 2~3에서 보정할 목록을 만든다.

### 단계 검증

```bash
rg -n "render_core_native_compare" README.md CONTRIBUTING.md mydocs .github
git diff --check
git status --short
```

### 커밋

```text
Task #82 Stage 1: 렌더 비교 매뉴얼 위치와 링크 구조 정리
```

## Stage 2: build/run guide와 렌더 비교 매뉴얼 보강

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/build_run_guide.md` | `validate-stage3-render.sh` 역할, 실패 조건, 출력 위치, custom sample 사용법 추가 | smoke 관문 설명 강화 |
| `mydocs/manual/render_core_native_compare_guide.md` | `render-debug-compare.sh` 산출물, summary 해석, table-in-tbox 실제 활용 예시 보강 | 상세 진단 절차 |
| `mydocs/troubleshootings/render_core_native_compare.md` | forwarding 문서 유지 시 manual 링크 안내 | 이동 시 한정 |

### 반영할 핵심 내용

- `validate-stage3-render.sh`는 기본 샘플 1페이지에서 문서 open, render tree, 한글 text run, glyph lookup, page size, native PNG non-white pixel을 확인한다.
- smoke test 통과는 전체 시각 정합성을 보장하지 않는다.
- `render-debug-compare.sh`는 core SVG와 native PNG를 나란히 보고 render tree JSON/summary로 core 문제와 Swift renderer 문제를 분리할 때 사용한다.
- `table-in-tbox` 예시는 core에는 본문/표가 있고 native에는 외곽선만 보이는 경우를 Swift renderer 해석 문제로 좁히는 흐름으로 짧게 설명한다.

### 단계 검증

```bash
rg -n "validate-stage3-render|render-debug-compare|TextRuns|MissingHangulGlyphs|table-in-tbox|core/native" \
  mydocs/manual mydocs/troubleshootings
git diff --check
```

### 커밋

```text
Task #82 Stage 2: 렌더 smoke와 core/native 비교 매뉴얼 보강
```

## Stage 3: README, CONTRIBUTING, 코드 규칙, PR 템플릿 보정

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `README.md` | 디버깅 프로토콜을 렌더링 문제와 Finder/Quick Look 통합 문제로 분리 | 상세는 manual 링크 |
| `CONTRIBUTING.md` | 버그 리포트와 디버깅 가이드에 summary/core/native 산출물 안내 추가 | 외부 기여자 진입점 |
| `mydocs/manual/swift_macos_code_rules_guide.md` | renderer 변경 시 smoke/debug compare 검증 기준 추가 | 개발 규칙 |
| `.github/pull_request_template.md` | `build.noindex/DerivedData` 경로 정리, renderer 관련 선택 검증 안내 추가 | PR 기록 |
| `mydocs/tech/project_architecture.md` | 필요 시 `rhwp_render_page_svg` 진단 용도에서 비교 매뉴얼로 연결 | 한 줄 링크 수준 |

### 확인 기준

- README/CONTRIBUTING에는 상세 절차를 복제하지 않는다.
- bug report에는 가능하면 `render-debug-compare.sh` summary, core PNG, native PNG, diff PNG를 첨부하라는 안내를 둔다.
- PR 템플릿의 renderer 추가 검증은 조건부 안내로 작성한다.
- `build/DerivedData`는 남기지 않고 `build.noindex/DerivedData` 기준으로 맞춘다.

### 단계 검증

```bash
rg -n "render-debug-compare|validate-stage3-render|render_core_native_compare|build/DerivedData|build.noindex/DerivedData|core PNG|native PNG|summary" \
  README.md CONTRIBUTING.md .github mydocs
git diff --check
```

### 커밋

```text
Task #82 Stage 3: 기여자 안내와 PR 검증 템플릿 보정
```

## Stage 4: `validate-stage3-render.sh` usage/help 보강

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `scripts/validate-stage3-render.sh` | `--help`/`-h` usage 추가 | self-documenting 개선 |
| `mydocs/manual/build_run_guide.md` | usage 문구와 문서 설명 정합성 확인 | 필요 시 보정 |

### 확인 기준

- 기존 기본 호출 `./scripts/validate-stage3-render.sh` 동작을 바꾸지 않는다.
- 기존 custom 호출 `<output-dir> <sample...>` 형태를 유지한다.
- `--help`는 빌드 산출물 없이도 사용법을 보여주고 종료한다.
- unknown option 처리는 기존 custom sample 경로와 충돌하지 않도록 보수적으로 둔다.

### 단계 검증

```bash
bash -n scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh --help
./scripts/validate-stage3-render.sh -h
git diff --check
```

### 커밋

```text
Task #82 Stage 4: render smoke script usage 안내 추가
```

## Stage 5: 최종 문서 검증과 보고서 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m010_82_stage{N}.md` | 각 단계 완료 보고서 작성 | 단계별 승인 후 진행 |
| `mydocs/report/task_m010_82_report.md` | 최종 결과 보고서 작성 | 모든 단계 완료 후 |
| `mydocs/orders/20260429.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
git diff --check
bash -n scripts/validate-stage3-render.sh scripts/render-debug-compare.sh
./scripts/validate-stage3-render.sh --help
rg -n "render_core_native_compare|validate-stage3-render|render-debug-compare|build/DerivedData|build.noindex/DerivedData" \
  README.md CONTRIBUTING.md .github mydocs scripts
git status --short --branch
```

### full build 제외 기준

이번 작업은 문서와 shell usage 개선에 한정한다. Swift/Rust source와 project 설정을 바꾸지 않으면 `xcodebuild`와 실제 render smoke full run은 최종 검증 필수에서 제외하고, 제외 사유를 최종 보고서에 기록한다.

### 커밋

```text
Task #82 Stage 5 + 최종 보고서: 렌더링 디버깅 문서 정리 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다.
