# Task M018 #206 Stage 4 완료 보고서

## 단계 목적

Stage 3에서 전환한 Pages artifact + `deploy-pages` 배포 모델을 release/CI 매뉴얼과 `v0.1.1` release record 초안에 반영했다. #188 public release 실행 전에 확인해야 할 Pages source, environment tag policy, deployment URL, public appcast 검증 기준을 문서화했다.

## 산출물

| 파일 | 라인 수 | 요약 |
|------|---------|------|
| `mydocs/manual/release_github_pages_sparkle_guide.md` | 175 | Pages 배포 모델을 `build_type=workflow`, `github-pages`, `v*` tag policy, `upload-pages-artifact@v5`, `deploy-pages@v5` 기준으로 갱신 |
| `mydocs/manual/ci_workflow_guide.md` | 217 | `Release Publish DMG` 권한/job 경계, Pages artifact helper 재현 명령, Pages deployment summary 기준 갱신 |
| `mydocs/manual/release_distribution_guide.md` | 131 | release asset 목록과 최종 체크리스트를 Pages deployment URL/public appcast 검증 기준으로 갱신 |
| `mydocs/release/v0.1.1.md` | 111 | #206 변경점, 연결 이슈, #188 Pages/appcast handoff 체크리스트 추가 |

## 본문 변경 정도 / 본문 무손실 여부

기존 release 문서의 signing/notarization, DMG, universal DMG, Homebrew Cask, GitHub Release 본문 기준은 유지했다. 변경은 Pages/appcast 배포 경로와 #188 검증 기준에 한정했다. 사용자-facing `docs/` HTML 본문은 수정하지 않았다.

## 주요 변경 내용

- `release_github_pages_sparkle_guide.md`
  - branch publishing 설명을 GitHub Actions Pages deployment 기준으로 교체했다.
  - repository precondition으로 Pages source `workflow`, `github-pages` environment, `v*` tag policy를 명시했다.
  - generated appcast는 source branch commit이 아니라 Pages artifact에 포함된다고 정리했다.
  - official release 후 `deploy-pages` job `page_url`과 public appcast URL을 확인하도록 추가했다.
- `ci_workflow_guide.md`
  - `Release Publish DMG`의 release job과 Pages job 권한을 분리해 문서화했다.
  - PR CI release checks 재현 명령에 `prepare-pages-artifact.sh` dry-run을 추가했다.
  - workflow summary 산출물에 Pages artifact와 GitHub Pages deployment 섹션을 추가했다.
- `release_distribution_guide.md`
  - `prepare-pages-artifact.sh`를 release 자산 목록에 추가했다.
  - 최종 release checklist에서 Pages source `workflow`, `github-pages` `v*`, `deploy-pages` `page_url`, public appcast URL 검증을 추가했다.
- `v0.1.1.md`
  - #206을 v0.1.1 release record와 연결했다.
  - #188 반복 기준에 Pages deployment precondition과 public appcast 확인 항목을 추가했다.

## 검증 결과

```bash
rg -n "deploy-pages|upload-pages-artifact|github-pages|build_type|workflow|Pages deployment|appcast|#188|#206|v\\*" mydocs/manual mydocs/release/v0.1.1.md
```

결과 요약:

- `release_github_pages_sparkle_guide.md`에 `build_type=workflow`, `github-pages`, `v*`, `upload-pages-artifact@v5`, `deploy-pages@v5`, `page_url` 기준 존재
- `ci_workflow_guide.md`에 release job/Pages job 권한 경계, Pages artifact helper 재현 명령, Pages deployment summary 기준 존재
- `release_distribution_guide.md`에 Pages deployment URL, public appcast URL, `v*` tag policy checklist 존재
- `v0.1.1.md`에 #206 변경점과 #188 Pages/appcast handoff 존재

```bash
rg -n "ALHANGEUL_PAGES_BRANCH|Pages branch|Publish Sparkle appcast to Pages branch|docs/appcast.xml이 Pages branch" mydocs/manual mydocs/release/v0.1.1.md
```

결과 요약:

- 기존 workflow env/step 이름 또는 `docs/appcast.xml` Pages branch 갱신 확인 문구는 남아 있지 않다.
- `v0.1.1.md`의 "Pages branch push가 아니라" 문구는 이전 방식과 새 방식의 차이를 설명하는 비교 문장이다.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

```bash
wc -l mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/ci_workflow_guide.md mydocs/manual/release_distribution_guide.md mydocs/release/v0.1.1.md
```

결과:

```text
     175 mydocs/manual/release_github_pages_sparkle_guide.md
     217 mydocs/manual/ci_workflow_guide.md
     131 mydocs/manual/release_distribution_guide.md
     111 mydocs/release/v0.1.1.md
     634 total
```

## 잔여 위험

- repository Pages source 전환과 `github-pages` environment `v*` tag policy 추가는 아직 실행하지 않았다.
- 실제 `deploy-pages` job 성공, `page_url`, public `appcast.xml` 반영은 GitHub Actions official release run에서만 최종 확인 가능하다.
- #188 전까지 repository setting 변경을 언제 실행할지 작업지시자 승인이 필요하다.

## 다음 단계 영향

Stage 5에서는 전체 workflow/helper/documentation 검증을 반복하고 최종 보고서와 PR 준비를 진행한다. Stage 5 final report에는 repository setting 변경 실행 여부와 미실행 시 #188 전 승인/실행 항목을 분리해 남겨야 한다.

## 승인 요청

Stage 4 산출물 승인을 요청한다.

승인 후 Stage 5 `통합 검증, 최종 보고, PR 준비`로 진행한다.
