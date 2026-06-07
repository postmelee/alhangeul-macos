# Task M900 #356 Stage 5 완료보고서

## 단계 요약

Stage 2~4에서 만든 문서 규칙, PR 분석 helper, release note generator/checker, workflow 연결을 `v0.1.5` 사례로 end-to-end 재검증했다.

추가로 현재 public `v0.1.5` GitHub Release body와 Pages 릴리즈 노트에 `#324`, `#326`, `#329`, `#334`, `#349` 기반 사용자-facing 변화와 `직접 반영된 PR과 Issue` section이 충분히 반영되지 않은 것을 확인했다. 공개 반영 승인 후 GitHub Release body를 직접 정정했고, Pages는 main 대상 docs-only PR `#357`을 merge해 public deploy까지 확인했다.

이후 GitHub Release body의 PR/Issue 항목이 inline code 번호만으로 렌더링되어 제목과 설명을 본문에서 읽을 수 없는 문제가 추가로 확인됐다. GitHub Markdown API 확인 결과 `` `#324` ``는 autolink가 차단되고, `#324`도 제목 텍스트로 치환되지 않고 짧은 링크 텍스트로만 렌더링됐다. 이에 helper, checker, 매뉴얼, `v0.1.5` release record, public GitHub Release body를 `[#<number>: 제목](URL) - 한 줄 설명` 형식으로 재보정했다.

## 변경 내용

| 파일 | 변경 |
|------|------|
| `docs/updates/v0.1.5.html` | `포함 PR 분석` 기준 사용자-facing 변화 반영. Quick Look/썸네일/PDF/공유 표시 보강, 앱 실행 후 업데이트 확인 보강, `앱 자체 신규 기능은 크지 않습니다` 문구 제거 |
| `scripts/ci/write-release-pr-analysis.sh` | PR/Issue 후보를 제목 포함 Markdown 링크로 출력하도록 보강 |
| `scripts/ci/check-release-notes-template.sh` | GitHub Release body의 PR/Issue section에서 inline code 번호-only 항목을 금지하고 제목 포함 링크를 요구 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` 외 매뉴얼 | GitHub 자동 제목 치환에 의존하지 않고 PR/Issue 제목 또는 설명을 직접 남기는 규칙 추가 |
| `mydocs/release/v0.1.5.md` | GitHub Release body 후보의 직접 반영 PR, 해결된 Issue, 관련 Issue를 제목/설명 포함 링크로 정정 |
| `mydocs/working/task_m900_356_stage5.md` | Stage 5 완료보고서 추가 |
| `mydocs/report/task_m900_356_report.md` | 최종 보고서 추가 |
| `mydocs/orders/20260607.md` | Issue `#356` 완료 처리 |

## 공개 표면 확인

확인한 public URL:

- GitHub Release: https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.5
- Pages: https://postmelee.github.io/alhangeul-macos/updates/v0.1.5.html

확인 결과:

| 표면 | 현재 public 상태 | Stage 5 판단 |
|------|------------------|--------------|
| GitHub Release | `직접 반영된 PR과 Issue` section 없음. `앱 자체 신규 기능은 크지 않습니다` 문구 존재 | 정정 필요 |
| Pages `v0.1.5` | `앱 자체 신규 기능은 크지 않습니다` 문구 존재. 일부 사용자-facing PR 변화 미반영 | source 정정 필요 |

## GitHub Release body 후보

정정 후보 body file:

```bash
build.noindex/release/github-release-v0.1.5-corrected.md
```

이 파일은 `scripts/ci/write-release-notes.sh`로 생성했고 `scripts/validate-github-body.sh`와 `scripts/ci/check-release-notes-template.sh`를 통과했다.

공개 반영 승인 후 다음 명령으로 GitHub Release body를 정정했다.

```bash
gh release edit v0.1.5 \
  --repo postmelee/alhangeul-macos \
  --notes-file build.noindex/release/github-release-v0.1.5-corrected.md
```

반영 후보에는 다음 PR/Issue section이 들어간다.

| section | 항목 |
|---------|------|
| 직접 반영된 PR | `#324` Sparkle 백그라운드 업데이트 확인, `#326` 이미지 fill mode parity, `#329` RawSvg/OLE·차트 리소스, `#334` FormObject 정적 프리뷰, `#349` `rhwp v0.7.15` sync |
| 해결된 Issue | `#110` FormObject 정적 프리뷰 보강 |
| 관련 Issue | `#106`, `#116`, `#121`, `#122`, `#280`, `#282`, `#323`, `#348`, `#351` 제목/관련 근거 포함 |

## Pages 정정

`docs/updates/v0.1.5.html`의 사용자-facing 문구를 다음 기준으로 정정했다.

- `rhwp v0.7.15` 문서 처리 개선을 수식, 미주, HWPX 저장/내보내기 호환성 중심으로 표현.
- Finder Quick Look 미리보기, Finder 썸네일, PDF/공유 출력에서 일부 양식 컨트롤, 문서 안에 포함된 리소스, 이미지 채움 방식 표시 보강을 반영.
- 앱 실행 후 업데이트 확인이 백그라운드에서 시작되는 변화를 반영.
- `앱 자체 신규 기능은 크지 않습니다` 문구 제거.
- PR/Issue 번호는 Pages 사용자 문구에 직접 나열하지 않음.

Pages public 반영은 main 대상 docs-only PR `#357`로 진행했다.

| 항목 | 값 |
|------|----|
| PR | `#357` |
| PR URL | https://github.com/postmelee/alhangeul-macos/pull/357 |
| merge commit | `bd075695dc77259d6b0624781a1c53ba0bd084cb` |
| Pages deploy run | `27097945876` |
| 결과 | success |

## End-to-End 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `bash -n` on release helpers | 통과 | PR analysis, notes, checker, delta checklist |
| `write-release-pr-analysis.sh v0.1.4 v0.1.5` | 통과 | `build.noindex/release/pr-analysis-0.1.5.md` 생성 |
| `write-release-pr-analysis.sh v0.1.4 v0.1.5` 제목 포함 dry-run | 통과 | `build.noindex/release/release-pr-analysis-v0.1.5-dry-run.md` 생성. PR 참조는 Issue 후보에서 제외 확인 |
| `write-release-delta-checklist.sh v0.1.4 HEAD` | 통과 | path 기반 보조 checklist 생성 |
| `write-release-notes.sh 0.1.5 ...` | 통과 | release notes와 public correction body file 생성 |
| `check-release-notes-template.sh` | 통과 | `직접 반영된 PR과 Issue` section의 제목 포함 링크 검증 |
| `validate-github-body.sh` | 통과 | release notes, correction body, PR analysis, Pages source |
| `update-release-version-notices.sh --check` | 통과 | latest `v0.1.5` 상태 유지 |
| HTML parse | 통과 | `docs/updates/v0.1.5.html` 기본 parse |
| `git diff --check` | 통과 | whitespace 오류 없음 |

검증 명령:

```bash
bash -n scripts/ci/write-release-pr-analysis.sh scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh scripts/ci/write-release-delta-checklist.sh
scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5.md
scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/release-pr-analysis-v0.1.5-dry-run.md
scripts/ci/write-release-delta-checklist.sh v0.1.4 HEAD build.noindex/release/delta-checklist-0.1.5.md
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
scripts/ci/write-release-notes.sh 0.1.5 d347c13b80aeaa006776db7ae2b00f8a2d11836c94757165f4bb87a331dd585b build.noindex/release/release-notes-0.1.5.md
scripts/ci/write-release-notes.sh 0.1.5 d347c13b80aeaa006776db7ae2b00f8a2d11836c94757165f4bb87a331dd585b build.noindex/release/github-release-v0.1.5-corrected.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.5.md
scripts/ci/check-release-notes-template.sh build.noindex/release/github-release-v0.1.5-corrected.md
scripts/validate-github-body.sh build.noindex/release/release-notes-0.1.5.md build.noindex/release/github-release-v0.1.5-corrected.md build.noindex/release/pr-analysis-0.1.5.md docs/updates/v0.1.5.html
git diff --check
```

## Public 반영 결과

공개 반영 승인 후 다음을 완료했다.

- GitHub Release `v0.1.5` body 정정.
- GitHub Release `v0.1.5` body의 PR/Issue section을 제목/설명 포함 링크 형식으로 재정정.
- `docs/updates/v0.1.5.html` public Pages 배포.
- public URL 재조회로 `직접 반영된 PR과 Issue`, `#324`, `#326`, `#329`, `#334`, `#349`, `#110`의 제목/설명 포함 표기와 Pages의 사용자-facing 정정 문구 확인.

완료 시각: 01:36.
