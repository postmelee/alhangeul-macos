# WKWebView 첫 출시와 native renderer 브랜치 전략

작성일: 2026-05-06

## 목적

이 문서는 `alhangeul-macos` 저장소의 첫 public release 전후 브랜치 전략을 정리한다. HostApp viewer 첫 출시는 native renderer 대신 `rhwp-studio`를 WKWebView로 로드하는 방식으로 결정되었으므로, 출시 우선 작업과 native renderer 실험 작업을 서로 다른 통합 브랜치로 운영한다.

이 문서는 브랜치 역할과 문서/자동화 기준의 진실 원천이다. README와 CONTRIBUTING은 외부 독자가 필요한 요약만 제공하고, 상세 판단 근거와 후속 rename 후보는 이 문서를 기준으로 유지한다.

## 현재 결정

- `main`은 release/tag 기준 브랜치다.
- `devel-webview`는 v0.1.x 첫 public release 준비 기준 브랜치다.
- `devel`은 native viewer renderer와 장기 native viewer 실험/통합 브랜치다.
- 첫 출시 전에는 브랜치 rename을 하지 않는다.
- `devel-webview -> main` 반영은 release PR로 수행하고, merge 후 tag/GitHub Release를 `main` 기준으로 만든다.
- 외부 기여 PR은 `main`으로 보내지 않는다. 작업 범위에 따라 `devel-webview` 또는 `devel`을 base로 고른다.

## 현재 브랜치 상태

2026-05-06 Stage 1 조사 기준 remote-tracking 상태는 다음과 같다.

| 비교 | left 전용 | right 전용 | 의미 |
|------|-----------|------------|------|
| `origin/main...origin/devel-webview` | 6 | 232 | `main`에는 README/banner 전용 변경이 있고, `devel-webview`에는 첫 출시 작업이 크게 누적되어 있다. |
| `origin/devel...origin/devel-webview` | 22 | 69 | `devel`과 `devel-webview`는 이미 분기되었다. |

`origin/main` 전용 commit은 README/banner 계열 변경을 포함한다. 따라서 `devel-webview -> main` release PR에서는 `main` 전용 README/banner 변경을 보존할지, `devel-webview`의 최신 README로 대체할지 명시적으로 확인해야 한다.

`origin/devel` 전용 commit은 Task #119 font fallback과 Task #123 native renderer/body overflow replay/clip 정책 중심이다. 이 내용은 native renderer 실험/장기 개발 브랜치 성격과 맞다.

`origin/devel-webview` 전용 commit은 Task #134 WKWebView viewer MVP, Task #142/#144/#153 HostApp viewer 문서 동작과 drag/drop, Task #154 Alhangeul identity 정리 중심이다. 이 내용은 v0.1.x 출시 우선 브랜치 성격과 맞다.

## 브랜치별 역할

| 브랜치 | 역할 | PR 기준 |
|--------|------|---------|
| `main` | release/tag 기준. public GitHub Release와 Homebrew Cask가 참조할 안정 기준 | release PR만 merge |
| `devel-webview` | v0.1.x WKWebView MVP, Finder/Quick Look/Thumbnail, Spotlight, 변환, 배포, 문서 작업의 기본 통합 브랜치 | 일반 작업 PR의 기본 base |
| `devel` | native viewer renderer, CoreGraphics/CoreText rendering, render tree 기반 viewer UI, native page interaction 실험/장기 개발 통합 브랜치 | native renderer 작업 PR base |
| `local/task{N}` | 하이퍼-워터폴 내부 작업 브랜치. 원격 push 금지 | `publish/task{N}`로 게시 |
| `publish/task{N}` | 원격 PR 게시용 브랜치. PR merge 후 삭제 | 작업 범위에 맞는 통합 브랜치 대상 |

## 첫 출시 전 단기 운영안

첫 출시 전에는 현재 이름을 유지한다.

브랜치 rename을 지금 수행하지 않는 이유는 다음과 같다.

- `devel-webview`에 이미 WKWebView viewer와 출시 준비 작업이 누적되어 있다.
- 출시 전 rename은 PR base, branch protection, review instruction, 문서 링크, 자동화 branch filter를 동시에 흔든다.
- v0.1.x의 가장 큰 위험은 브랜치 이름보다 release artifact와 설치본 smoke, fallback, license/provenance 정합성이다.
- `devel`에는 native renderer 전용 작업이 남아 있어, `devel-webview`와 무리하게 합치면 출시 기준이 흐려질 수 있다.

단기 운영 기준:

1. v0.1.x 작업은 기본적으로 `devel-webview`를 기준으로 시작한다.
2. native renderer 동작을 직접 바꾸는 작업만 `devel`을 기준으로 시작한다.
3. release-critical 수정은 먼저 `devel-webview`로 반영한다.
4. 같은 수정이 native renderer 장기 브랜치에도 필요하면 별도 PR 또는 cherry-pick으로 `devel`에 후속 반영한다.
5. `main`에는 release PR 외의 일반 작업 PR을 보내지 않는다.

## 출시 후 장기 선택지

v0.1.x 첫 출시 이후에는 다음 선택지를 다시 판단한다.

### 선택지 A: 현재 이름 유지

`devel-webview`와 `devel` 이름을 유지한다.

장점:

- 현재 문서와 브랜치 보호 설정을 크게 바꾸지 않아도 된다.
- WKWebView 기반 출시 라인과 native renderer 실험 라인이 계속 분리된다.
- v0.1.x patch release 운영이 단순하다.

단점:

- `devel-webview`가 장기 주 작업 브랜치처럼 보이지 않고 임시 전환 브랜치처럼 보일 수 있다.
- `devel`이라는 이름이 일반적인 주 개발 브랜치로 오해될 수 있다.

### 선택지 B: 출시 라인을 주 개발 브랜치로 승격

`devel-webview`를 `devel` 또는 `develop`으로 승격하고, 기존 `devel`은 `native-renderer`, `native-devel`, `experiment/native-renderer` 같은 이름으로 변경한다.

장점:

- 주 개발 브랜치 이름이 일반 관례와 더 잘 맞는다.
- native renderer 실험 브랜치의 성격이 이름에서 드러난다.
- 외부 기여자가 PR base를 잘못 고를 가능성이 줄어든다.

단점:

- branch protection, default PR base 안내, 자동화 branch filter, 열린 PR base, 문서 링크를 모두 바꿔야 한다.
- v0.1.x patch release가 남아 있으면 release line과 rename 작업이 충돌할 수 있다.

판단 시점:

- 첫 public release와 긴급 patch release 가능성이 안정된 뒤
- 열린 PR 수와 branch protection 변경 부담이 낮을 때
- native renderer 실험 라인을 독립 이름으로 유지할 필요가 명확할 때

## `devel-webview -> main` 승격 체크리스트

release PR 생성 전에 확인한다.

- [ ] `origin/main`과 `origin/devel-webview`를 최신 fetch했다.
- [ ] `git rev-list --left-right --count origin/main...origin/devel-webview` 결과를 확인했다.
- [ ] `origin/main` 전용 README/banner 변경을 보존할지 대체할지 결정했다.
- [ ] release-critical PR이 모두 `devel-webview`에 merge되었다.
- [ ] `devel` 전용 native renderer 실험 commit을 release PR에 포함하지 않는다는 점을 확인했다.
- [ ] `rhwp-core.lock`, `RustBridge/Cargo.lock`, release artifact provenance가 release 기준과 일치한다.
- [ ] release guide의 필수 검증을 실행했다.
- [ ] release PR은 `devel-webview` head에서 `main` base로 만든다.
- [ ] release PR merge 후 tag와 GitHub Release는 `main` 기준으로 만든다.
- [ ] release PR merge 후에도 `devel-webview`는 v0.1.x patch/follow-up 기준 브랜치로 유지한다.

## 외부 기여 PR base 기준

| 작업 유형 | PR base |
|-----------|---------|
| WKWebView MVP viewer, `rhwp-studio` 통합 | `devel-webview` |
| Finder Quick Look / Thumbnail | `devel-webview` |
| Spotlight, PDF/export/print, 변환, 배포, 문서 | `devel-webview` |
| release automation, packaging, Cask | `devel-webview` |
| native viewer renderer, CoreGraphics/CoreText renderer | `devel` |
| render tree 기반 native viewer UI, native zoom/cache/page interaction | `devel` |

범위가 애매하면 PR을 만들기 전에 이슈 또는 Discussion에서 확인한다. GitHub 기본 브랜치가 `main`이어도 기여 PR은 `main`으로 보내지 않는다.

## 자동화와 보호 규칙 점검 항목

첫 출시 전 문서 정합화와 별개로, GitHub 설정과 자동화는 다음 기준을 점검해야 한다.

- `main` 보호 규칙: release PR과 review approval을 요구한다.
- `devel-webview` 보호 규칙: 작업 PR과 review/검증을 요구한다.
- `devel` 보호 규칙: native renderer 실험 PR이 일반 출시 라인으로 섞이지 않게 한다.
- CI branch filter: `main`, `devel-webview`, `devel`, `publish/task*` 중 필요한 대상을 명시한다.
- release workflow: public artifact와 GitHub Release publish는 `main` tag 기준으로만 수행한다.
- release rehearsal: 필요하면 `devel-webview`에서 artifact rehearsal은 허용하되 public publish와 구분한다.
- PR template/review instruction: 기본 PR target을 `devel`로 단정하지 않는다.
- docs: README, CONTRIBUTING, workflow manual, release guide가 같은 branch 역할을 설명해야 한다.

## 후속 이슈 후보

이 문서는 현재 정책을 정리한다. 다음 작업은 필요 시 별도 이슈로 분리한다.

- 첫 public release 후 브랜치 rename 여부 결정
- GitHub branch protection과 default branch 설정 점검
- CI/release automation branch filter 점검
- `devel-webview`와 `devel` 사이의 release-critical fix 동기화 절차 정리
- `main` README/banner 변경 보존 정책을 release PR checklist에 반영

## 관련 문서

- [README.md](../../README.md)
- [CONTRIBUTING.md](../../CONTRIBUTING.md)
- [git_workflow_guide.md](../manual/git_workflow_guide.md)
- [pr_process_guide.md](../manual/pr_process_guide.md)
- [release_distribution_guide.md](../manual/release_distribution_guide.md)
- [product_roadmap_notes.md](product_roadmap_notes.md)
