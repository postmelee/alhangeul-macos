# Task M040 #79 Stage 1 완료보고서

## 단계 목적

기존 릴리스 매뉴얼, workflow, release record, 최신 공개 release 기준을 수집해 `public_release_runbook.md` 작성 기준을 확정했다. 이 단계는 runbook 본문을 작성하기 전, 어떤 정보는 실행 문서에 직접 넣고 어떤 정보는 기존 하위 매뉴얼로 연결할지 구분하는 사전 분석 단계다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m040_79_stage1.md` | Stage 1 기준 수집 결과와 다음 단계 설계 기준 기록 |

이번 단계에서는 실제 runbook 본문이나 기존 매뉴얼을 수정하지 않았다. Stage 2에서 `mydocs/manual/public_release_runbook.md`를 신규 작성한다.

## 수집 결과

### 외부 release 기준

| 항목 | 확인 결과 |
|------|-----------|
| 최신 공개 앱 release | `v0.1.3` |
| GitHub Release title | `Alhangeul v0.1.3 (rhwp v0.7.12)` |
| 공개 상태 | non-draft, non-prerelease |
| publishedAt | `2026-05-18T09:11:34Z` |
| GitHub Release URL | `https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.3` |
| 최신 upstream `rhwp` release | `v0.7.13` |
| upstream publishedAt | `2026-05-26T13:57:15Z` |
| upstream release URL | `https://github.com/edwardkim/rhwp/releases/tag/v0.7.13` |

`gh release view`는 최초 일반 sandbox 실행에서는 네트워크 제한으로 실패했고, 승인된 escalated 실행에서 위 메타데이터를 확인했다. 동일 내용은 GitHub web release page에서도 확인했다.

### 로컬 release candidate 관련 기준

| 항목 | 현재 값 |
|------|---------|
| `rhwp-core.lock` | `rhwp_release_tag = "v0.7.13"`, commit `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| bundled `rhwp-studio` manifest | `source_release_tag = "v0.7.13"`, commit `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| HostApp plist | `CFBundleShortVersionString=0.1.3`, `CFBundleVersion=9` |
| Quick Look extension plist | `CFBundleShortVersionString=0.1.3`, `CFBundleVersion=9` |
| Thumbnail extension plist | `CFBundleShortVersionString=0.1.3`, `CFBundleVersion=9` |
| `Release Publish DMG` workflow default | `version=0.1.3`, `previous_release_ref=v0.1.2`, `expected_rhwp_tag=v0.7.12` |
| `Release Rehearsal DMG` workflow default | `version=0.1.3`, `previous_release_ref=v0.1.2`, `expected_rhwp_tag=v0.7.12` |
| repository Cask source | `version "0.1.2"`, SHA256 `37a27321...` |

이 조합은 runbook의 핵심 preflight 요구사항을 보여준다. 현재 lock/manifest는 upstream 최신 `rhwp v0.7.13`을 가리키지만 앱/extension plist와 workflow default는 `v0.1.3` release 기준에 머물러 있다. 따라서 runbook은 workflow 기본값을 신뢰하지 말고 매번 release owner가 입력값을 확정하도록 해야 한다.

## 기존 문서 역할 분류

| 문서 | runbook에서의 역할 |
|------|-------------------|
| `release_distribution_guide.md` | 릴리스/배포 매뉴얼 묶음의 진입점. Stage 3에서 새 runbook 링크를 추가한다. |
| `release_policy_guide.md` | 배포 브랜치, 산출물 계층, 사용자 안내, provenance 공개 기준의 진실 원천으로 링크한다. |
| `ci_workflow_guide.md` | `Release Rehearsal DMG`, `Release Publish DMG`, Pages workflow의 trigger/input/권한 설명으로 링크한다. |
| `release_packaging_dmg_guide.md` | release script, rehearsal/public DMG, Finder smoke 세부 절차로 링크한다. |
| `release_signing_notarization_guide.md` | Developer ID, notarytool, signing preflight, Gatekeeper 검증 기준으로 링크한다. |
| `release_github_pages_sparkle_guide.md` | GitHub Release body, Pages, Sparkle appcast, delta checklist 기준으로 링크한다. |
| `release_homebrew_cask_guide.md` | public DMG SHA256 확정 후 Cask 갱신과 tap 검증 기준으로 링크한다. |
| `mydocs/release/v<version>.md` | 릴리즈별 실제 결정, SHA256, workflow run, 수동 smoke 결과 기록 위치로 안내한다. |

## runbook에 직접 넣을 기준

- public release 실행, GitHub Release 게시, Sparkle appcast 갱신, Homebrew Cask 반영은 작업지시자의 명시 승인 후에만 수행한다.
- 매 릴리즈 시작 시 `version`, `build`, `candidate commit`, `previous_release_ref`, `expected_rhwp_tag`, `require_latest_rhwp`, `include_rhwp_in_title`, `draft`, `prerelease`를 확정한다.
- workflow default는 stale할 수 있으므로 입력값을 그대로 쓰지 않고 현재 release context와 대조한다.
- `rhwp-core.lock`, bundled `rhwp-studio` manifest, app/extension plist, README/Pages/release record, Cask source가 같은 release identity를 가리키는지 확인한다.
- `draft=false`, `prerelease=false` 공식 release에서만 stable Sparkle appcast와 Pages deployment를 성공 조건으로 본다.
- Homebrew Cask는 public DMG asset과 SHA256이 확정된 뒤 별도 승인 gate로 처리한다.
- 실행하지 않은 Finder Quick Look/Thumbnail, Sparkle update, Intel Mac 실기기 smoke는 성공으로 기록하지 않는다.
- secret 값은 문서, commit, shell history에 남기지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

기존 매뉴얼과 코드 본문은 변경하지 않았다. 신규 Stage 1 완료보고서만 추가했다.

## 검증 결과

### `gh release view`

승인된 escalated 실행으로 최신 release 메타데이터를 확인했다.

```text
postmelee/alhangeul-macos: tagName=v0.1.3, isDraft=false, isPrerelease=false, publishedAt=2026-05-18T09:11:34Z
edwardkim/rhwp: tagName=v0.7.13, isDraft=false, isPrerelease=false, publishedAt=2026-05-26T13:57:15Z
```

### Stage 1 계획 검증 명령

```bash
rg -n "Release Publish DMG|Release Rehearsal DMG|previous_release_ref|expected_rhwp_tag|SPARKLE_ED_PRIVATE_KEY|Homebrew|Rollback" mydocs/manual .github/workflows
```

결과: 통과. 기존 매뉴얼과 workflow에서 release workflow input, Sparkle secret 이름, Homebrew gate, rollback 기준을 확인했다.

```bash
git diff --check
```

결과: 통과. whitespace 오류 없음.

## 잔여 위험

- 최신 공개 release와 upstream latest release는 시간이 지나면 바뀐다. Stage 2 runbook에는 특정 값보다 재확인 절차를 중심으로 적어야 한다.
- GitHub web page는 일부 동적 영역 로딩 오류를 표시할 수 있으므로, runbook에는 가능하면 `gh release view`와 release page 확인을 함께 쓰도록 안내한다.
- Homebrew tap의 실제 최신 상태는 repository local Cask source와 다를 수 있다. Stage 2에서는 local source와 tap 검증을 분리해 쓴다.

## 다음 단계 영향

Stage 2에서는 위 수집 결과를 바탕으로 `mydocs/manual/public_release_runbook.md`를 신규 작성한다. 핵심은 "배포일 실행 순서"와 "stale 기본값/최신성 불일치 감지"이며, 세부 정책은 기존 하위 매뉴얼 링크로 연결한다.

## 승인 요청

Stage 1 완료 결과를 검토한 뒤 Stage 2 `public_release_runbook.md` 신규 작성 진행 승인을 요청한다.
