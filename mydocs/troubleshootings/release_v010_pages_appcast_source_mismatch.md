# v0.1.0 release Pages appcast source mismatch

## 작성 목적

2026년 5월 9일 `v0.1.0` 첫 public release 과정에서 `Release Publish DMG` workflow는 성공했지만, 공개 `appcast.xml` URL이 처음에는 최신 feed를 제공하지 않았다.

이 문서는 같은 문제가 다음 release에서 반복되지 않도록 증상, 원인, 확인 명령, 복구 절차, 재발 방지 기준을 기록한다.

## 발생 상황

관련 작업:

- GitHub Issue: [#166](https://github.com/postmelee/alhangeul-macos/issues/166)
- Release: [v0.1.0](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.0)
- Release workflow run: `25574049810`
- Pages deployment run: `25574667555`

`Release Publish DMG` workflow는 다음 항목까지 성공했다.

- signed/notarized DMG 생성
- GitHub Release asset 게시
- Sparkle EdDSA signature 생성
- `docs/appcast.xml` 생성
- GitHub Actions bot commit으로 `main`에 appcast 반영

그러나 공개 URL `https://postmelee.github.io/alhangeul-macos/appcast.xml`은 처음에 stale feed를 반환했다.

## 증상

workflow 결과만 보면 appcast 생성이 성공한 것처럼 보인다.

```text
b672f40 Task #177: Update Sparkle appcast for v0.1.0
 docs/appcast.xml | 10 ++++++++++
```

하지만 public Pages URL을 직접 확인하면 release item이 없거나 이전 feed가 내려올 수 있다.

```bash
curl -I -L https://postmelee.github.io/alhangeul-macos/appcast.xml
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml
```

이 상태에서는 설치된 앱의 Sparkle updater가 최신 public appcast를 읽지 못한다.

## 원인

repository variable `ALHANGEUL_PAGES_BRANCH`는 `main`으로 설정했지만, GitHub Pages source는 여전히 `devel-webview` `/docs`를 보고 있었다.

즉:

- workflow는 `main`의 `docs/appcast.xml`을 갱신했다.
- GitHub Pages는 `devel-webview`의 `/docs`를 배포하고 있었다.
- 그래서 workflow가 성공해도 public appcast URL은 최신 `main` feed를 제공하지 않았다.

## 확인 명령

Pages source 확인:

```bash
gh api repos/postmelee/alhangeul-macos/pages \
  --jq '{build_type,source,html_url}'
```

기대값:

```json
{
  "build_type": "legacy",
  "source": {
    "branch": "main",
    "path": "/docs"
  },
  "html_url": "https://postmelee.github.io/alhangeul-macos/"
}
```

workflow가 appcast를 어느 branch에 커밋했는지 확인:

```bash
git log --oneline --decorate -5 -- docs/appcast.xml
```

public appcast 확인:

```bash
curl -fsSL -o /tmp/alhangeul-appcast.xml \
  https://postmelee.github.io/alhangeul-macos/appcast.xml

xmllint --noout /tmp/alhangeul-appcast.xml

rg -n "sparkle:version|sparkle:shortVersionString|sparkle:edSignature|alhangeul-macos-.*\\.dmg" \
  /tmp/alhangeul-appcast.xml
```

`v0.1.0` 기준 기대 항목:

```text
sparkle:version>1</sparkle:version>
sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
sparkle:edSignature="..."
https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg
```

Pages deployment 확인:

```bash
gh run list --repo postmelee/alhangeul-macos \
  --limit 10 \
  --json databaseId,workflowName,status,conclusion,headBranch,headSha,url

gh run watch <pages-run-id> --repo postmelee/alhangeul-macos --exit-status
```

## 복구 절차

GitHub Pages source를 `main` `/docs`로 전환한다.

```bash
gh api -X PUT repos/postmelee/alhangeul-macos/pages \
  -F 'source[branch]=main' \
  -F 'source[path]=/docs'
```

필요하면 Pages build를 수동 요청한다.

```bash
gh api -X POST repos/postmelee/alhangeul-macos/pages/builds
```

이후 `pages-build-deployment` run이 success인지 확인한다.

```bash
gh run list --repo postmelee/alhangeul-macos \
  --limit 5 \
  --json databaseId,workflowName,status,conclusion,headBranch,headSha,url
```

마지막으로 public URL을 직접 내려받아 확인한다.

```bash
curl -fsSL -o /tmp/alhangeul-appcast.xml \
  https://postmelee.github.io/alhangeul-macos/appcast.xml
xmllint --noout /tmp/alhangeul-appcast.xml
```

## 재발 방지

다음 release부터는 아래 항목을 release gate로 둔다.

1. `ALHANGEUL_PAGES_BRANCH` repository variable이 GitHub Pages source branch와 같은지 확인한다.
2. 현재 운영 기준은 `main` `/docs`다.
3. workflow의 `docs/appcast.xml` 생성 성공만으로 appcast 배포 성공을 판단하지 않는다.
4. 반드시 public URL `https://postmelee.github.io/alhangeul-macos/appcast.xml`을 직접 내려받아 검증한다.
5. `pages-build-deployment` run이 새 `main` commit 기준으로 success인지 확인한다.

## 관련 문서

- [`release_distribution_guide.md`](../manual/release_distribution_guide.md)
- [`task_m010_166_report.md`](../report/task_m010_166_report.md)
- [`task_m010_166_stage5.md`](../working/task_m010_166_stage5.md)
