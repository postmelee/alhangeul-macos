# Task M010 #166 Stage 3 보고서

## 단계 목적

`v0.1.0` official release workflow를 실행할 수 있도록 release source를 확정하고, `main` 반영과 `v0.1.0` tag push까지 완료했다. 이 단계는 Git ref 정렬만 수행했으며, GitHub Release workflow 실행, signed/notarized DMG 생성, appcast 갱신, Homebrew Cask 갱신은 수행하지 않았다.

## 산출물

### 문서 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m010_166_stage3.md` | Stage 3 release ref 확정 결과 기록 |
| `mydocs/orders/20260509.md` | #166 비고를 Stage 3 완료 후 Stage 4 승인 대기로 갱신 |

### 외부 Git 상태

| 항목 | 결과 |
|------|------|
| release source | `local/task166` Stage 2 완료 commit `d41cdd9f1471d143dbb5cbbbc612fd0a92d50f6b` |
| `origin/main` push 전 | `359ce0f4f95a4e249fa2b85cb6dccd92b663794f` |
| `origin/main` push 후 | `1693a96f6fd9c54c4d621f2f94aa856c16281e1a` |
| merge commit | `1693a96f6fd9c54c4d621f2f94aa856c16281e1a` |
| merge parents | `359ce0f4f95a4e249fa2b85cb6dccd92b663794f d41cdd9f1471d143dbb5cbbbc612fd0a92d50f6b` |
| tag | `v0.1.0` |
| tag object | `ff3b6f9221b56965392d3de34c317564a1def777` |
| tag target commit | `1693a96f6fd9c54c4d621f2f94aa856c16281e1a` |

## 본문 변경 정도 / 본문 무손실 여부

`local/task166`에서 앱 소스는 변경하지 않았다. Stage 3의 local branch 변경은 단계 보고서와 오늘할일 갱신뿐이다.

외부 상태로는 `main`에 merge commit을 만들었다. `origin/main`은 release source의 ancestor가 아니어서 fast-forward가 불가능했고, 작업지시자 승인을 받은 뒤 merge commit 방식으로 진행했다. 충돌 파일은 `README.md` 1개였고, release 후보인 `local/task166` 쪽 README를 유지했다. 확인 명령 `git diff local/task166 -- README.md`는 출력이 없었다.

merge commit의 release source 대비 추가 차이는 `git diff --check` 통과를 위한 기존 Stage 151 문서 EOF 공백 제거 2줄뿐이다.

```text
mydocs/report/task_m016_151_report.md  | 1 -
mydocs/working/task_m016_151_stage4.md | 1 -
```

## 검증 결과

### release source와 main 관계 확인

Stage 3 시작 시점:

```text
## local/task166...origin/devel-webview [ahead 4]
HEAD=d41cdd9f1471d143dbb5cbbbc612fd0a92d50f6b
origin/devel-webview=6a74f071d03916daa0ca362247dd4625fac5967f
origin/main=359ce0f4f95a4e249fa2b85cb6dccd92b663794f
```

`origin/devel-webview`는 `local/task166`의 ancestor였지만, `origin/main`은 ancestor가 아니었다. `git merge-tree --write-tree origin/main HEAD` 결과 README 충돌 1개가 확인됐다.

```text
Auto-merging README.md
CONFLICT (content): Merge conflict in README.md
```

충돌 해소 방식은 작업지시자 승인 후 `local/task166` 쪽 README를 유지하는 것으로 확정했다.

### main merge

실행:

```text
git checkout main
git pull --ff-only origin main
git merge --no-ff local/task166 -m "Merge local/task166 for v0.1.0 release"
git checkout --theirs README.md
git add README.md
git commit --no-edit
```

결과:

```text
[main 1693a96] Merge local/task166 for v0.1.0 release
```

검증:

```text
1693a96f6fd9c54c4d621f2f94aa856c16281e1a
359ce0f4f95a4e249fa2b85cb6dccd92b663794f d41cdd9f1471d143dbb5cbbbc612fd0a92d50f6b
Merge local/task166 for v0.1.0 release
```

`git diff --cached --check`는 최종 merge commit 전 통과했다.

### tag 생성과 push

실행:

```text
git tag -a v0.1.0 -m "Alhangeul v0.1.0"
git push origin main
git push origin v0.1.0
```

push 결과:

```text
To https://github.com/postmelee/alhangeul-macos.git
   359ce0f..1693a96  main -> main

To https://github.com/postmelee/alhangeul-macos.git
 * [new tag]         v0.1.0 -> v0.1.0
```

원격 ref 확인:

```text
1693a96f6fd9c54c4d621f2f94aa856c16281e1a refs/heads/main
ff3b6f9221b56965392d3de34c317564a1def777 refs/tags/v0.1.0
1693a96f6fd9c54c4d621f2f94aa856c16281e1a refs/tags/v0.1.0^{}
```

tag 확인:

```text
tag v0.1.0
TaggerDate: Sat May 9 02:45:48 2026 +0900

Alhangeul v0.1.0

commit 1693a96f6fd9c54c4d621f2f94aa856c16281e1a (tag: v0.1.0, origin/main, origin/HEAD)
Merge: 359ce0f d41cdd9
```

### workflow 노출 확인

`main` 반영 후 default branch 기준 workflow 목록:

```text
Release Publish DMG      active  273409453
Release Rehearsal DMG    active  273409455
rhwp Upstream Release Check active 273409456
Copilot code review      active  268604381
pages-build-deployment   active  273132573
```

Stage 1에서 확인했던 "release workflow가 default branch에 없어 `gh workflow list`에 보이지 않는 문제"는 Stage 3에서 해소됐다.

### Stage 4 readiness 재확인

GitHub environments:

```text
github-pages
```

`release` environment는 아직 없다.

```text
failed to get secrets: HTTP 404: Not Found (.../environments/release/secrets?per_page=100)
failed to get variables: HTTP 404: Not Found (.../environments/release/variables?per_page=100)
```

`v0.1.0` GitHub Release는 아직 생성되지 않았다.

```text
release not found
```

이는 expected state다. Stage 4에서 workflow를 실행해야 GitHub Release와 public DMG asset이 생성된다.

## 잔여 위험

- Stage 4 official release는 여전히 `release` environment와 signing/notarization/Sparkle secrets/variables 부재로 blocked다.
- `v0.1.0` tag는 원격에 존재하지만 GitHub Release asset은 아직 없다.
- public DMG SHA256, appcast enclosure, Sparkle signature, notarization 결과, latest release 상태는 Stage 4 workflow 실행 후에만 확인할 수 있다.
- `main` push로 default branch에는 release workflow가 노출됐지만, workflow 실행은 아직 수행하지 않았다.

## 다음 단계 영향

Stage 4 `official GitHub Release publish`는 ref 조건만 놓고 보면 진행 가능하다. 실행 전에는 최소한 다음 환경 구성이 필요하다.

- `release` environment 생성 또는 workflow environment 운용 방식 확정
- variables: `ALHANGEUL_DEVELOPER_ID_APPLICATION`, `ALHANGEUL_DEVELOPER_ID_DMG`, `ALHANGEUL_NOTARY_PROFILE`, `APPLE_TEAM_ID`, `ALHANGEUL_PAGES_BRANCH`
- secrets: `DEVELOPER_ID_APPLICATION_P12_BASE64`, `DEVELOPER_ID_APPLICATION_P12_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_APP_SPECIFIC_PASSWORD`, `RELEASE_KEYCHAIN_PASSWORD`, `SPARKLE_ED_PRIVATE_KEY`

Stage 4 실행 시 workflow ref는 `v0.1.0`, 입력은 `version=0.1.0`, `expected_rhwp_tag=v0.7.10`, `draft=false`, `prerelease=false`를 사용한다.

## 승인 요청

Stage 3 `release ref 확정과 main/tag 준비`를 완료했다. GitHub release environment와 required secrets/variables가 준비된 뒤 Stage 4 `official GitHub Release publish`를 진행할지 승인 요청한다.
