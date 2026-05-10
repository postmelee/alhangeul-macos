# Task M018 #188 Stage 1 완료 보고서

## 단계 목적

`v0.1.1` public release 실행 전에 선행 이슈, GitHub Release/tag 존재 여부, source version/build, Pages/appcast repository setting, 기존 설치본 smoke 순서를 확인하고, 실제 public release 전에 별도 승인이 필요한 항목을 확정한다.

확인 시각: `2026-05-10 23:33 KST`

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m018_188_stage1.md` | Stage 1 release preflight 결과와 승인 필요 항목 기록 |

이번 단계에서 source code, workflow, Pages 문서, release 기록 본문은 수정하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 신규 단계 보고서만 추가했다.
- 기존 소스와 기존 문서 본문은 변경하지 않았다.
- public release, tag 생성, GitHub Release 게시, Pages/appcast 갱신, 설치본 삭제는 실행하지 않았다.

## 확인 결과

### GitHub milestone 상태

`gh issue list --repo postmelee/alhangeul-macos --milestone v0.1.1 --state all --json number,title,state` 결과:

| Issue | 상태 | 제목 |
|-------|------|------|
| #183 | CLOSED | v0.1.0 설치본에서 창 확대 시 WebView runtime error 발생 |
| #184 | CLOSED | DMG 설치 창 안내와 첫 실행 안내 개선 |
| #185 | CLOSED | GitHub Release/Pages 업데이트 본문 템플릿과 생성 스크립트 고도화 |
| #186 | CLOSED | GitHub Actions Node.js 20 deprecation warning 대응 |
| #187 | CLOSED | Homebrew tap 배포 경로 확정과 Cask 검증 절차 정리 |
| #188 | OPEN | v0.1.1 patch release 준비와 public 배포 실행 |
| #198 | CLOSED | PR 생성 CI와 릴리즈 검증 CI 보강 |
| #199 | CLOSED | 공식 릴리즈 Finder thumbnail 생성 hang 수정 |
| #206 | CLOSED | Pages/appcast 배포 방식을 deploy-pages workflow로 전환 검토 |
| #208 | CLOSED | v0.1.1 Intel Mac 지원과 단일 universal DMG 안내 보강 |
| #209 | OPEN | v0.1.1 Homebrew tap 초기 공개 배포 |
| #212 | CLOSED | GitHub Pages 홍보 페이지 footer와 업데이트 안내 UX 보강 |
| #215 | CLOSED | 저작권자 정정과 release legal notice 포함 기준 보강 |

판단:

- #188의 선행 이슈는 닫혀 있다.
- #209는 #188에서 public DMG URL과 SHA256을 확정한 뒤 이어지는 Homebrew tap 공개 배포 이슈로 남아 있다.

### #188 comment 확인

`gh issue view 188 --comments` 결과 #215 handoff comment 1개를 확인했다. public DMG 검증 시 다음을 signed/notarized DMG 기준으로 반복해야 한다.

- `Alhangeul.app/Contents/Info.plist`의 `NSHumanReadableCopyright`가 `Copyright © 2025-2026 Taegyu Lee`인지 확인
- mounted app bundle 내부 `Contents/Resources/Legal/LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` 존재 확인
- 위 세 파일이 release candidate commit의 canonical 문서와 같은지 확인
- `THIRD_PARTY_LICENSES.md`에 `rhwp`/`rhwp-studio`, Sparkle, WOFF2 font, app icon/logo provenance가 포함됐는지 확인
- 결과를 #188 최종 보고서와 `mydocs/release/v0.1.1.md`에 기록

### GitHub Release/tag 상태

- `gh release view v0.1.1 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,url` 결과: `release not found`
- `git tag --list 'v0.1.1'` 결과: 출력 없음

판단:

- `v0.1.1` GitHub Release는 아직 없다.
- 로컬 tag `v0.1.1`도 아직 없다.
- tag 생성과 release workflow 실행은 Stage 4에서 작업지시자 명시 승인 후 진행해야 한다.

### Source version/build 상태

`plutil -extract` 결과:

| Target | CFBundleShortVersionString | CFBundleVersion |
|--------|----------------------------|-----------------|
| HostApp | `0.1.0` | `1` |
| QLExtension | `0.1.0` | `1` |
| ThumbnailExtension | `0.1.0` | `1` |

추가 확인:

- `Casks/alhangeul-macos.rb`는 `version "0.1.0"`과 `sha256 :no_check` 상태다.
- `Release Publish DMG` workflow default `version`은 아직 `0.1.0`이다.
- `Release Rehearsal DMG` workflow default `version`도 아직 `0.1.0`이다.
- `previous_release_ref` 기본값은 `v0.1.0`이며, `v0.1.1` release 기준으로 유지하는 것이 맞다.
- PR CI release helper checks는 이미 `0.1.1` test fixture를 사용한다.
- `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.1.html`은 `v0.1.1` latest DMG 후보 링크를 포함한다.
- `docs/appcast.xml`은 현재 `v0.1.0` item snapshot을 포함한다. #206 기준으로 official stable appcast 성공 판단은 tracked snapshot이 아니라 Pages artifact/deploy-pages/public URL이다.

판단:

- Stage 2에서 앱 본체와 두 extension을 `0.1.1` / `2`로 올려야 한다.
- Stage 2에서 release publish/rehearsal workflow default version을 `0.1.1`로 보정해야 한다.
- Cask version/SHA는 public DMG SHA256 확정 후 Stage 4에서 `scripts/update-cask-sha256.sh`로 갱신하는 것이 맞다.

### Pages/appcast repository setting 상태

`gh api repos/postmelee/alhangeul-macos/pages` 결과:

- `status`: `built`
- `build_type`: `legacy`
- `source.branch`: `main`
- `source.path`: `/docs`
- `html_url`: `https://postmelee.github.io/alhangeul-macos/`
- `public`: `true`
- `https_enforced`: `true`

`gh api repos/postmelee/alhangeul-macos/environments/github-pages` 결과:

- environment `github-pages` 존재
- branch policy protection rule 존재
- `deployment_branch_policy.protected_branches`: `false`
- `deployment_branch_policy.custom_branch_policies`: `true`

`gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies` 결과:

| Name | Type |
|------|------|
| `devel-webview` | branch |
| `gh-pages` | branch |
| `main` | branch |
| `publish/task135` | branch |

판단:

- #206에서 workflow는 `deploy-pages` 경로로 전환됐지만 repository Pages source는 아직 `legacy`다.
- release tag ref에서 `deploy-pages` job을 실행하려면 `github-pages` environment가 `v*` tag policy를 허용해야 하는데 현재 없다.
- Stage 4 public release workflow 실행 전, 다음 repository setting 변경이 별도 승인/실행되어야 한다.

```bash
gh api repos/postmelee/alhangeul-macos/pages --method PUT -f build_type=workflow
gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies --method POST -f name='v*' -f type=tag
```

### Release tag 대상 원칙

이번 release tag는 작업지시자가 확정한 release candidate commit에만 생성한다.

기본 원칙:

- `v0.1.1` tag는 #188 version/build/release communication 변경과 검증 기록이 포함된 commit을 대상으로 한다.
- release workflow는 tag ref `v0.1.1`에서만 official publish path를 통과한다.
- 필요한 경우 `devel-webview -> main` release PR/merge checkpoint를 Stage 4 전에 별도 승인 항목으로 둔다.
- 기존 `v0.1.0` 설치본은 Stage 5 Sparkle update 감지 확인 전까지 삭제하지 않는다.

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `git status --short --branch` | OK | `## local/task188` |
| `gh issue list --repo postmelee/alhangeul-macos --milestone v0.1.1 --state all --json number,title,state` | OK | #209/#188 open, 나머지 선행 이슈 closed |
| `gh issue view 188 --repo postmelee/alhangeul-macos --comments` | OK | #215 legal notice handoff 확인 |
| `gh release view v0.1.1 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,url` | 기대 실패 | `release not found` |
| `git tag --list 'v0.1.1'` | OK | 출력 없음 |
| `gh api repos/postmelee/alhangeul-macos/pages` | OK | `build_type=legacy`, `main` / `/docs` |
| `gh api repos/postmelee/alhangeul-macos/environments/github-pages` | OK | custom branch policies 사용 |
| `gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies` | OK | `v*` tag policy 없음 |
| `rg -n "CFBundleShortVersionString\|CFBundleVersion\|0\\.1\\.0\|0\\.1\\.1" ...` | OK | version/build 현황 확인 |
| `plutil -extract ...` | OK | 앱/extension 모두 `0.1.0` / `1` |

## 잔여 위험

- Pages source가 `legacy`라서 현 상태로는 official stable appcast를 `deploy-pages` success 기준으로 닫을 수 없다.
- `github-pages` environment가 `v*` tag ref를 허용하지 않으므로 tag ref workflow의 Pages deployment가 막힐 수 있다.
- `v0.1.1` source version/build가 아직 증가하지 않았으므로 Sparkle update comparison 기준이 아직 준비되지 않았다.
- `docs/appcast.xml` tracked snapshot은 `v0.1.0` 상태다. 실제 stable feed 검증은 Stage 4 public URL로 판단해야 한다.
- 기존 `v0.1.0` 설치본을 Stage 5 이전에 삭제하면 Sparkle 업데이트 감지 검증 자산을 잃는다.

## 다음 단계 영향

Stage 2에서는 다음을 수행한다.

- HostApp/QLExtension/ThumbnailExtension version/build를 `0.1.1` / `2`로 증가
- release publish/rehearsal workflow default version을 `0.1.1`로 보정
- README/Pages/release 기록의 후보 문구와 Homebrew 공개 전 안내 확인
- release note template dry-run 검증

Stage 4 전 별도 승인/실행이 필요한 repository setting:

- Pages source `legacy` -> `workflow`
- `github-pages` environment tag policy `v*` 추가

Stage 5 전 보존해야 하는 사용자 환경:

- 현재 로컬에 설치된 public `v0.1.0` 앱
- Sparkle update cache/state를 업데이트 감지 확인 전까지 임의 삭제하지 않음

## 승인 요청

1. Stage 1 결과 승인
2. Stage 2 `Version/build와 release communication source 정리` 진입 승인
3. Pages source `workflow` 전환과 `github-pages` `v*` tag policy 추가는 Stage 4 public release 실행 전 별도 승인/실행 항목으로 유지하는 방향 승인
4. 기존 public `v0.1.0` 설치본은 Stage 5 Sparkle 업데이트 감지 확인 전까지 삭제하지 않는 방향 승인
