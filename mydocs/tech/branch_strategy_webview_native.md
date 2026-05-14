# 제품 devel 승격과 native 전환 브랜치 전략

작성일: 2026-05-06
갱신일: 2026-05-14

## 목적

이 문서는 `alhangeul-macos` 저장소의 제품 개발 브랜치와 Swift native viewer/editor 전환 브랜치 전략을 정리한다. HostApp viewer/editor 첫 출시는 native renderer/editor 대신 `rhwp-studio`를 WKWebView로 로드하는 방식으로 진행되었고, 첫 public release 이후 제품 개발 라인을 `devel`로 승격하며 native 전환 라인은 별도 이름으로 보존한다.

이 문서는 브랜치 역할과 문서/자동화 기준의 진실 원천이다. README와 CONTRIBUTING은 외부 독자가 필요한 요약만 제공하고, 상세 판단 근거와 remote 전환 runbook은 이 문서를 기준으로 유지한다.

## 현재 결정

- `main`은 release/tag 기준 브랜치다.
- `devel`은 일반 제품 개발과 외부 기여 기본 브랜치다.
- `native-viewer-editor`는 Swift native viewer/editor와 장기 native 전환 작업 통합 브랜치다.
- `devel-webview`는 전환 기간 동안 기존 링크와 자동화 호환성을 보존하는 legacy alias다.
- `devel -> main` 반영은 release PR로 수행하고, merge 후 tag/GitHub Release를 `main` 기준으로 만든다.
- 외부 기여 PR은 `main`으로 보내지 않는다. 작업 범위에 따라 `devel` 또는 `native-viewer-editor`를 base로 고른다.
- 2026-05-14 전환 전 fork나 오래된 clone을 기준으로 새 기여를 시작하는 것은 권장하지 않는다. 새 fork/clone 또는 최신 `origin/devel`에서 새 작업 브랜치를 만든다.

## Task #244 devel 승격 전환 정책

작성일: 2026-05-14

첫 public release와 v0.1.2 patch release 이후 `devel-webview`가 실질적인 제품 개발 라인이 되었고, `devel` 이름이 일반 기여 기본 브랜치로 오해될 위험이 커졌다. 따라서 #244에서는 기존 장기 native 라인을 보존하면서 제품 개발 라인을 `devel`로 승격하는 전환을 준비한다.

### 전환 후 브랜치 역할

| 브랜치 | 전환 후 역할 | 전환 방식 |
|--------|--------------|-----------|
| `main` | release/tag 기준 브랜치. public GitHub Release와 Homebrew Cask가 참조하는 안정 기준 | 유지 |
| `devel` | 일반 제품 개발과 외부 기여 기본 브랜치. WKWebView-backed viewer/editor, Finder/Quick Look/Thumbnail, PDF/공유/저장, Mac 통합, 변환, 배포, 문서 작업을 받는다 | `devel-webview` 제품 라인과 `main`의 release 후속 기록을 통합한 commit으로 교체 |
| `native-viewer-editor` | 기존 `devel` head를 보존하는 Swift native viewer/editor 장기 개발 브랜치 | 기존 `origin/devel` head에서 새 원격 브랜치로 생성 |
| `devel-webview` | 전환 안정화 기간 동안 기존 링크와 자동화 호환성을 위한 legacy alias | 새 제품 `devel` 기준 commit으로 fast-forward한 뒤 유지하고, 삭제 여부는 별도 승인으로 판단 |
| `local/task{N}` | 하이퍼-워터폴 내부 작업 브랜치 | 유지 |
| `publish/task{N}` | 원격 PR 게시용 브랜치 | 유지 |

### 선택한 native 보존 브랜치 이름

기존 `devel`은 Swift native viewer renderer뿐 아니라 editor foundation 장기 작업까지 포함하는 라인이다. 따라서 보존 브랜치 이름은 `native-viewer-editor`로 한다.

검토한 후보:

| 후보 | 판단 |
|------|------|
| `native-viewer` | v0.5 viewer 범위는 잘 드러나지만 v0.6 native editor foundation을 담기에는 좁다. |
| `native-viewer-editor` | viewer와 editor 장기 전환 범위가 모두 드러나므로 채택한다. |
| `native-devel` | 짧지만 성격이 모호하다. |
| `experiment/native` | 장기 유지 라인보다 실험 브랜치처럼 보인다. |

### 제품 `devel` 기준 commit 원칙

새 `devel`은 `origin/devel-webview`만 단순 복사하지 않는다. `origin/main`에는 v0.1.2 public release 후속 README, release record, Pages 관련 변경이 있으므로 제품 개발 기준은 다음 조건을 만족해야 한다.

1. first parent는 기존 제품 개발 라인인 `origin/devel-webview`를 유지한다.
2. `origin/main` 전용 release 후속 변경을 병합한다.
3. 기존 `origin/devel` 전용 native renderer commit은 새 제품 `devel`에 직접 merge하지 않는다.
4. 기존 `origin/devel` head는 먼저 `origin/native-viewer-editor`로 보존한다.

권장 생성 방식:

```bash
git fetch origin
git checkout -B task244/product-devel-candidate origin/devel-webview
git merge --no-ff origin/main -m "Merge main release records into devel product line"
```

Stage 1 가상 병합에서 `origin/main + origin/devel-webview`는 충돌 없이 자동 병합 가능했다. 실제 전환 실행 직전에도 같은 확인을 반복한다.

### 원격 전환 runbook

이 runbook은 Stage 5에서 작업지시자가 원격 전환 실행을 명시 승인한 뒤에만 수행한다.

1. 원격 최신화와 사전 상태 기록

   ```bash
   git fetch origin
   git ls-remote --heads origin main devel devel-webview native-viewer-editor
   gh pr list --repo postmelee/alhangeul-macos --state open --base devel
   gh pr list --repo postmelee/alhangeul-macos --state open --base devel-webview
   ```

2. 기존 `devel`에 열린 PR이 없는지 확인한다.

   - #244 Stage 2 기준 PR #131은 구현하지 않기로 결정되어 closed 상태이고, 관련 이슈 #130도 `not planned`로 closed 상태다.
   - 새 open PR이 있으면 merge/close/retarget 결정을 먼저 받은 뒤 전환한다.

3. 기존 `devel` head를 `native-viewer-editor`로 보존한다.

   ```bash
   git push origin origin/devel:refs/heads/native-viewer-editor
   git ls-remote --heads origin native-viewer-editor
   ```

   이미 `native-viewer-editor`가 존재하면 즉시 중단하고 현재 ref와 의도한 ref를 비교한 뒤 작업지시자 확인을 받는다.

4. 제품 개발 후보 commit을 만든다.

   ```bash
   git checkout -B task244/product-devel-candidate origin/devel-webview
   git merge --no-ff origin/main -m "Merge main release records into devel product line"
   git log --oneline --graph --decorate --max-count=20
   git diff --check
   ```

5. `devel-webview` legacy alias를 제품 후보로 fast-forward한다.

   후보 commit은 `origin/devel-webview`의 descendant여야 한다. fast-forward가 아니면 중단한다.

   ```bash
   git push origin task244/product-devel-candidate:devel-webview
   ```

6. `devel`을 제품 후보로 교체한다.

   기존 `origin/devel`과 새 후보는 fast-forward 관계가 아니므로 branch protection과 maintainer 승인 상태를 먼저 확인한다. 실행이 승인되면 `--force-with-lease`로 기존 ref를 명시해 오동작을 막는다.

   ```bash
   old_devel="$(git rev-parse origin/devel)"
   git push --force-with-lease=refs/heads/devel:"$old_devel" origin task244/product-devel-candidate:devel
   ```

   branch protection 때문에 거부되면 GitHub repository setting에서 임시 허용 또는 브랜치 rename 방식으로 처리해야 하며, 로컬에서 우회하지 않는다.

7. 전환 후 검증

   ```bash
   git fetch origin
   git rev-parse origin/devel origin/devel-webview origin/native-viewer-editor origin/main
   git merge-base --is-ancestor origin/devel-webview origin/devel
   git log --oneline --decorate --max-count=5 origin/devel
   gh pr list --repo postmelee/alhangeul-macos --state open --base devel
   ```

8. GitHub repository setting 수동 확인

   - `main`: release/tag 기준 보호 유지
   - `devel`: 일반 작업 PR 대상 보호 규칙 적용
   - `native-viewer-editor`: native viewer/editor 장기 라인 보호 규칙 적용
   - `devel-webview`: legacy alias 보호 또는 삭제 일정 결정
   - default branch는 별도 승인으로 결정한다. 외부 기여 PR base 오입력을 줄이려면 `devel` 전환을 검토하되, release/tag 기준 문서와 GitHub Pages 운영 영향도 함께 확인한다.

### 전환 전 gate

원격 전환 실행 전에 다음 조건을 만족해야 한다.

- [ ] `origin/main`, `origin/devel-webview`, `origin/devel`을 최신 fetch했다.
- [ ] `origin/devel`에 열린 PR이 없다. 또는 모든 열린 PR의 처리 방향이 승인되었다.
- [ ] 기존 `origin/devel` head를 `native-viewer-editor`로 보존하는 작업이 승인되었다.
- [ ] 제품 후보 commit이 `origin/devel-webview` descendant이며 `origin/main` 전용 release 후속 변경을 포함한다.
- [ ] `devel` 비 fast-forward 교체가 필요하다는 점을 작업지시자가 명시 승인했다.
- [ ] branch protection/default branch 수동 설정 항목이 확인되었다.
- [ ] `devel-webview` legacy 유지 기간과 삭제 여부를 별도 판단하기로 했다.

### 전환 후 기여 기준

전환 후 외부 기여 PR base 기준은 다음과 같다.

| 작업 유형 | PR base |
|-----------|---------|
| WKWebView-backed viewer/editor, `rhwp-studio` 통합 | `devel` |
| Finder Quick Look / Thumbnail | `devel` |
| PDF/export/print/share/save, Spotlight/mdimporter, 변환, 배포, 문서 | `devel` |
| release automation, packaging, Cask | `devel` |
| Swift native viewer renderer, CoreGraphics/CoreText renderer | `native-viewer-editor` |
| render tree 기반 native viewer UI, native zoom/cache/page interaction | `native-viewer-editor` |
| Swift native editor foundation, caret/selection/IME/overlay | `native-viewer-editor` |

범위가 애매하면 PR 생성 전에 이슈 또는 Discussion에서 확인한다. `main`은 release/tag 기준이므로 일반 기여 PR base로 사용하지 않는다.

## 전환 전 브랜치 상태 기록

2026-05-06 Stage 1 조사 기준 remote-tracking 상태는 다음과 같다. 아래 내용은 첫 출시 전 분기 상태 기록이며, 현재 운영 기준은 위의 Task #244 전환 정책이다.

| 비교 | left 전용 | right 전용 | 의미 |
|------|-----------|------------|------|
| `origin/main...origin/devel-webview` | 6 | 232 | `main`에는 README/banner 전용 변경이 있고, `devel-webview`에는 첫 출시 작업이 크게 누적되어 있다. |
| `origin/devel...origin/devel-webview` | 22 | 69 | `devel`과 `devel-webview`는 이미 분기되었다. |

`origin/main` 전용 commit은 README/banner 계열 변경을 포함했다. 따라서 당시 `devel-webview -> main` release PR에서는 `main` 전용 README/banner 변경을 보존할지, `devel-webview`의 최신 README로 대체할지 명시적으로 확인해야 했다.

`origin/devel` 전용 commit은 Task #119 font fallback과 Task #123 native renderer/body overflow replay/clip 정책 중심이다. 이 내용은 Swift native viewer/editor 전환 브랜치 성격과 맞다.

`origin/devel-webview` 전용 commit은 Task #134 WKWebView viewer MVP, Task #142/#144/#153 HostApp viewer 문서 동작과 drag/drop, Task #154 Alhangeul identity 정리 중심이다. 이 내용은 v0.1.x 출시 우선 브랜치 성격과 맞다.

## 브랜치별 역할

| 브랜치 | 역할 | PR 기준 |
|--------|------|---------|
| `main` | release/tag 기준. public GitHub Release와 Homebrew Cask가 참조할 안정 기준 | release PR만 merge |
| `devel` | 일반 제품 개발과 외부 기여 기본 브랜치. WKWebView-backed viewer/editor, Finder/Quick Look/Thumbnail, PDF/공유/저장, Mac 통합, 변환, 배포, 문서 작업 통합 | 일반 작업 PR의 기본 base |
| `native-viewer-editor` | Swift native viewer/editor, CoreGraphics/CoreText rendering, render tree 기반 viewer UI, native page interaction과 editor foundation 장기 개발 통합 브랜치 | native viewer/editor 작업 PR base |
| `devel-webview` | 전환 기간 legacy alias. 기존 링크와 자동화 호환성을 보존 | 신규 PR 기본 base로 사용하지 않음 |
| `local/task{N}` | 하이퍼-워터폴 내부 작업 브랜치. 원격 push 금지 | `publish/task{N}`로 게시 |
| `publish/task{N}` | 원격 PR 게시용 브랜치. PR merge 후 삭제 | 작업 범위에 맞는 통합 브랜치 대상 |

## 첫 출시 전 단기 운영안 기록

이 절은 2026-05-06 첫 출시 전 판단 기록이다. Task #244 전환 이후 현재 운영 기준은 제품 `devel`과 native `native-viewer-editor` 분리다.

첫 출시 전에는 현재 이름을 유지한다.

브랜치 rename을 지금 수행하지 않는 이유는 다음과 같다.

- `devel-webview`에 이미 WKWebView viewer와 출시 준비 작업이 누적되어 있다.
- 출시 전 rename은 PR base, branch protection, review instruction, 문서 링크, 자동화 branch filter를 동시에 흔든다.
- v0.1.x의 가장 큰 위험은 브랜치 이름보다 release artifact와 설치본 smoke, fallback, license/provenance 정합성이다.
- `devel`에는 native renderer 전용 작업이 남아 있어, `devel-webview`와 무리하게 합치면 출시 기준이 흐려질 수 있다.

단기 운영 기준:

1. v0.1.x 작업은 기본적으로 `devel-webview`를 기준으로 시작한다.
2. Swift native viewer/editor 동작을 직접 바꾸는 작업만 `devel`을 기준으로 시작한다.
3. release-critical 수정은 먼저 `devel-webview`로 반영한다.
4. 같은 수정이 native renderer 장기 브랜치에도 필요하면 별도 PR 또는 cherry-pick으로 `devel`에 후속 반영한다.
5. `main`에는 release PR 외의 일반 작업 PR을 보내지 않는다.

## 출시 후 장기 선택지 기록

Task #244에서 선택지 B를 채택했다. 제품 라인은 `devel`로 승격하고, 기존 `devel`의 native 장기 라인은 `native-viewer-editor`로 보존한다.

v0.1.x 첫 출시 이후에는 다음 선택지를 다시 판단한다.

### 선택지 A: 현재 이름 유지

`devel-webview`와 `devel` 이름을 유지한다.

장점:

- 현재 문서와 브랜치 보호 설정을 크게 바꾸지 않아도 된다.
- WKWebView 기반 출시 라인과 Swift native 전환 라인이 계속 분리된다.
- v0.1.x patch release 운영이 단순하다.

단점:

- `devel-webview`가 장기 주 작업 브랜치처럼 보이지 않고 임시 전환 브랜치처럼 보일 수 있다.
- `devel`이라는 이름이 일반적인 주 개발 브랜치로 오해될 수 있다.

### 선택지 B: 출시 라인을 주 개발 브랜치로 승격

`devel-webview`를 `devel` 또는 `develop`으로 승격하고, 기존 `devel`은 `native-viewer-editor`, `native-devel`, `experiment/native` 같은 이름으로 변경한다.

장점:

- 주 개발 브랜치 이름이 일반 관례와 더 잘 맞는다.
- Swift native 전환 브랜치의 성격이 이름에서 드러난다.
- 외부 기여자가 PR base를 잘못 고를 가능성이 줄어든다.

단점:

- branch protection, default PR base 안내, 자동화 branch filter, 열린 PR base, 문서 링크를 모두 바꿔야 한다.
- v0.1.x patch release가 남아 있으면 release line과 rename 작업이 충돌할 수 있다.

판단 시점:

- 첫 public release와 긴급 patch release 가능성이 안정된 뒤
- 열린 PR 수와 branch protection 변경 부담이 낮을 때
- Swift native viewer/editor 전환 라인을 독립 이름으로 유지할 필요가 명확할 때

## `devel -> main` release PR 체크리스트

release PR 생성 전에 확인한다.

- [ ] `origin/main`과 `origin/devel`을 최신 fetch했다.
- [ ] `git rev-list --left-right --count origin/main...origin/devel` 결과를 확인했다.
- [ ] `origin/main` 전용 README/banner 변경을 보존할지 대체할지 결정했다.
- [ ] release-critical PR이 모두 `devel`에 merge되었다.
- [ ] `native-viewer-editor` 전용 Swift native viewer/editor 전환 commit을 release PR에 포함하지 않는다는 점을 확인했다.
- [ ] `rhwp-core.lock`, `RustBridge/Cargo.lock`, release artifact provenance가 release 기준과 일치한다.
- [ ] release guide의 필수 검증을 실행했다.
- [ ] release PR은 `devel` head에서 `main` base로 만든다.
- [ ] release PR merge 후 tag와 GitHub Release는 `main` 기준으로 만든다.
- [ ] release PR merge 후에도 `devel`은 patch/follow-up 기준 브랜치로 유지한다.

## 외부 기여 PR base 기준

| 작업 유형 | PR base |
|-----------|---------|
| WKWebView-backed viewer/editor, `rhwp-studio` 통합 | `devel` |
| Finder Quick Look / Thumbnail | `devel` |
| PDF/export/print/share/save, Spotlight/mdimporter, 변환, 배포, 문서 | `devel` |
| release automation, packaging, Cask | `devel` |
| Swift native viewer renderer, CoreGraphics/CoreText renderer | `native-viewer-editor` |
| render tree 기반 native viewer UI, native zoom/cache/page interaction | `native-viewer-editor` |
| Swift native editor foundation, caret/selection/IME/overlay | `native-viewer-editor` |

범위가 애매하면 PR을 만들기 전에 이슈 또는 Discussion에서 확인한다. GitHub default branch 설정과 관계없이 일반 기여 PR은 `main`으로 보내지 않는다.

## 자동화와 보호 규칙 점검 항목

GitHub 설정과 자동화는 다음 기준을 점검해야 한다.

- `main` 보호 규칙: release PR과 review approval을 요구한다.
- `devel` 보호 규칙: 일반 작업 PR과 review/검증을 요구한다.
- `native-viewer-editor` 보호 규칙: Swift native viewer/editor 전환 PR이 일반 출시 라인으로 섞이지 않게 한다.
- `devel-webview` 보호 규칙: legacy alias 유지 기간 동안 기존 자동화 호환성을 확인한다.
- CI branch filter: `main`, `devel`, `native-viewer-editor`, `devel-webview`, `publish/task*` 중 필요한 대상을 명시한다.
- release workflow: public artifact와 GitHub Release publish는 `main` tag 기준으로만 수행한다.
- release rehearsal: 필요하면 `devel`에서 artifact rehearsal은 허용하되 public publish와 구분한다.
- PR template/review instruction: 일반 작업 PR target은 `devel`, native 작업 PR target은 `native-viewer-editor`로 안내한다.
- docs: README, CONTRIBUTING, workflow manual, release guide가 같은 branch 역할을 설명해야 한다.

## 후속 이슈 후보

이 문서는 현재 정책을 정리한다. 다음 작업은 필요 시 별도 이슈로 분리한다.

- GitHub branch protection과 default branch 설정 점검
- CI/release automation branch filter 점검
- `devel-webview` legacy alias 삭제 여부와 시점 결정
- `devel`과 `native-viewer-editor` 사이의 release-critical fix 동기화 절차 정리
- `main` README/banner 변경 보존 정책을 release PR checklist에 반영

## 관련 문서

- [README.md](../../README.md)
- [CONTRIBUTING.md](../../CONTRIBUTING.md)
- [git_workflow_guide.md](../manual/git_workflow_guide.md)
- [pr_process_guide.md](../manual/pr_process_guide.md)
- [release_distribution_guide.md](../manual/release_distribution_guide.md)
- [product_roadmap_notes.md](product_roadmap_notes.md)
