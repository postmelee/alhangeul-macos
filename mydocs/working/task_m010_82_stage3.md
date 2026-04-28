# Task #82 Stage 3 완료 보고서

## 단계 목적

README, CONTRIBUTING, Swift/macOS 코드 규칙, PR 템플릿, 아키텍처 문서를 보정해 renderer 디버깅 도구의 역할과 산출물 기록 방법을 기여자 진입점에서 확인할 수 있게 했다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `README.md` | Checks 링크에 core/native 렌더 비교 가이드를 추가하고, 디버깅 프로토콜을 렌더링 문제와 Finder/Quick Look 통합 문제로 분리 |
| `CONTRIBUTING.md` | 버그 리포트에 `render-debug-compare.sh` 산출물 첨부 권장, renderer PR 추가 검증 안내, 디버깅 가이드 역할 설명과 manual 링크 보정 |
| `.github/pull_request_template.md` | Debug build 경로를 `build.noindex/DerivedData`로 보정하고 renderer 변경 시 `render-debug-compare.sh` 선택 검증과 산출물 첨부 안내 추가 |
| `mydocs/manual/swift_macos_code_rules_guide.md` | renderer 변경 시 smoke/debug compare 검증 기준 추가 |
| `mydocs/tech/project_architecture.md` | `rhwp_render_page_svg` 진단 용도 설명에서 core/native 렌더 비교 가이드로 연결 |

## 본문 변경 정도 / 본문 무손실 여부

Stage 3는 진입 문서와 PR 기록 안내를 보강하는 변경이다. 상세 절차는 `mydocs/manual/render_core_native_compare_guide.md`에 유지하고, README/CONTRIBUTING/PR 템플릿에는 짧은 역할 설명과 링크만 추가했다. 기존 과거 작업 보고서의 역사적 기록은 수정하지 않았다.

## 검증 결과

### Stage 3 검색 검증

```bash
rg -n "render-debug-compare|validate-stage3-render|render_core_native_compare|build/DerivedData|build.noindex/DerivedData|core PNG|native PNG|summary" \
  README.md CONTRIBUTING.md .github mydocs
```

결과 요약:

- 최신 진입 문서인 `README.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md`에 `render-debug-compare.sh`와 core/native 비교 가이드 연결이 노출됨.
- `build_run_guide.md`, `swift_macos_code_rules_guide.md`, `project_architecture.md`에서 manual 경로가 연결됨.
- `build/DerivedData` 문자열은 과거 작업 보고서와 시행착오 기록에도 남아 있으나, 최신 README/CONTRIBUTING/.github/manual/tech의 실제 명령 예시에는 `-derivedDataPath build/DerivedData`가 남지 않았다.

### 최신 링크/경로 추가 확인

```bash
rg -n "mydocs/troubleshootings/render_core_native_compare|../troubleshootings/render_core_native_compare|render_core_native_compare.md" \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
```

결과: 매칭 없음.

```bash
rg -n -- "-derivedDataPath build/DerivedData" README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
```

결과: 매칭 없음.

### diff check

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- `validate-stage3-render.sh` 자체의 `--help`/usage는 아직 추가하지 않았다. Stage 4에서 처리한다.
- PR 템플릿의 renderer 검증은 조건부 안내로 추가했으므로, 모든 PR에서 강제되지 않는다. 실제 renderer 변경 PR에서는 리뷰어가 산출물 첨부 여부를 확인해야 한다.

## 다음 단계 영향

Stage 4에서는 `validate-stage3-render.sh`에 `--help`/`-h` usage를 추가하고, 문서 설명과 script usage가 일치하는지 확인한다.

## 승인 요청

Stage 3 산출물 검토 후 Stage 4 진행 승인을 요청한다.
