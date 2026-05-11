# Task M019 #205 Stage 2 완료 보고서

## 단계 목적

앱 버전과 bundled `rhwp` provenance 표기 정책을 release 정책 문서와 사용자-facing 문서에 반영했다.

이번 단계는 문서/Pages HTML 보강만 수행했고, release note generator와 publish workflow 변경은 Stage 3으로 남겼다. Public release 실행, GitHub Release 게시, Pages deployment, Sparkle appcast 갱신은 수행하지 않았다.

## 변경 요약

### Release policy

`mydocs/manual/release_policy_guide.md`에 `릴리즈 식별자와 bundled rhwp 표기 정책` 섹션을 추가했다.

정리한 기준:

- 공식 앱 release identity는 `Alhangeul v<app-version>` 하나로 유지한다.
- Git tag, bundle version, DMG filename, Sparkle appcast version/build, Homebrew Cask version은 앱 버전만 사용한다.
- GitHub Release title 기본형은 `Alhangeul v<app-version>`이다.
- Upstream `rhwp` 반영이 release의 중심 사용자-facing 변화일 때만 `Alhangeul v<app-version> (rhwp v<rhwp-version>)` 병기를 허용한다.
- 앱 자체 bugfix, packaging, CI, 문서, Sparkle/Homebrew 중심 release나 bundled `rhwp`가 직전 release와 같은 경우에는 title에 `rhwp` 버전을 병기하지 않는다.
- GitHub Release body와 내부 release record의 표준 `Release metadata` 항목을 추가했다.
- README와 Pages에는 짧은 `rhwp v<version>` provenance와 upstream release 링크만 표시하고, 긴 commit/manifest/checksum 기록은 GitHub Release body와 `mydocs/release/v<version>.md`로 분리한다.
- 자동 upstream sync PR/release handoff에 필요한 최소 provenance 항목과 release title 판단 항목을 정리했다.

### GitHub Release, Pages, Sparkle guide

`mydocs/manual/release_github_pages_sparkle_guide.md`에 release 표면별 적용 기준을 보강했다.

추가한 기준:

- GitHub Release 생성 전 title이 기본형인지, 또는 `(rhwp vX.Y.Z)` 병기 조건을 충족하는지 확인한다.
- GitHub Release title 기본형과 예외형을 문서화했다.
- Release note 본문 포함 항목을 `Release metadata` 중심으로 정리했다.
- `Release metadata`는 `rhwp-core.lock`과 `Sources/HostApp/Resources/rhwp-studio/manifest.json`에서 읽은 값을 기준으로 생성한다.
- Pages는 bundled `rhwp`를 안내해야 하는 release에서 `rhwp v<version>`과 upstream release 링크만 짧게 표시한다.
- Sparkle appcast의 version/build와 enclosure filename은 앱 버전만 사용하고, bundled `rhwp` 버전은 release notes URL이 가리키는 metadata에서 확인하게 한다.

### README

`README.md`의 최신 공개 릴리즈 요약에 현재 최신 공개 release인 `v0.1.0`의 bundled `rhwp` provenance를 한 줄로 추가했다.

추가 문구:

- 포함된 `rhwp`: `v0.7.10`
- 링크: `https://github.com/edwardkim/rhwp/releases/tag/v0.7.10`
- 기준: `rhwp-core.lock`, bundled `rhwp-studio` manifest

README의 역할도 보정했다. 최신 공개 릴리즈는 1개만 요약하고, bundled `rhwp` provenance는 한 줄 요약만 표시한다고 명시했다. `v0.1.1`은 아직 patch release 후보로 유지해 release 상태를 새로 확정한 것처럼 쓰지 않았다.

### Pages `v0.1.1`

`docs/updates/v0.1.1.html`에 요청받은 bundled `rhwp` 안내를 추가했다.

추가 내용:

- hero action에 알한글 `v0.1.1` GitHub Release 링크 추가
- `포함된 rhwp` section 추가
- `rhwp v0.7.10` upstream release 링크 추가
- bundled `rhwp-studio`도 같은 `v0.7.10` 기준임을 짧게 안내
- 세부 provenance는 알한글 GitHub Release와 릴리즈 기록에서 확인하도록 연결

GitHub Release body 수준의 긴 metadata 표는 Pages에 넣지 않았다. Pages는 사용자용 안내 표면이라는 기준을 유지했다.

### Pages `v0.1.0` 보정

Stage 2 완료 후 점검에서 `v0.1.1`만 보강하면 특정 페이지에만 정책을 적용한 것처럼 보일 수 있음을 확인했다. `docs/updates/v0.1.0.html`에도 같은 사용자용 short provenance 기준을 적용했다.

추가 내용:

- hero action에 알한글 `v0.1.0` GitHub Release 링크 추가
- `포함된 rhwp` section 추가
- `rhwp v0.7.10` upstream release 링크 추가
- bundled `rhwp-studio`도 같은 `v0.7.10` 기준임을 짧게 안내
- 세부 provenance는 알한글 GitHub Release와 릴리즈 기록에서 확인하도록 연결

### Release record `v0.1.1`

`mydocs/release/v0.1.1.md`의 `Provenance` 섹션을 표준 `Release metadata` 형식으로 보정했다.

추가/정리한 항목:

- App version: `v0.1.1`
- rhwp core release tag/commit
- bundled rhwp-studio release tag/commit
- core lock
- studio manifest
- Third Party notices

### Release record `v0.1.0` 보정

`mydocs/release/v0.1.0.md`도 `Release metadata` 형식으로 맞췄다. `v0.1.0`은 이미 공개 완료된 release이므로 배포 결정이나 검증 결과는 바꾸지 않고, 기존 provenance 값을 표준 항목명으로만 정리했다.

추가/정리한 항목:

- App version: `v0.1.0`
- rhwp core release tag/commit
- bundled rhwp-studio release tag/commit
- core lock
- studio manifest

## 변경 파일

- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `README.md`
- `docs/updates/v0.1.0.html`
- `docs/updates/v0.1.1.html`
- `mydocs/release/v0.1.0.md`
- `mydocs/release/v0.1.1.md`
- `mydocs/working/task_m019_205_stage2.md`

## 변경하지 않은 항목

- `rhwp-core.lock`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- Rust bridge artifact
- bundled `rhwp-studio` asset
- `Alhangeul.xcodeproj`
- release note generator
- release publish workflow
- public GitHub Pages 배포 결과
- GitHub Release 게시 상태
- Sparkle appcast

## 검증 결과

실행한 명령:

```bash
rg -n "앱 release identity|릴리즈 식별자|Release metadata|rhwp v0.7.10|edwardkim/rhwp/releases/tag/v0.7.10|Alhangeul v0.1.0|Alhangeul v0.1.1|bundled rhwp|rhwp-studio|release handoff|upstream sync|자동 upstream sync" \
  README.md docs/updates/v0.1.0.html docs/updates/v0.1.1.html mydocs/release/v0.1.0.md mydocs/release/v0.1.1.md mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md
git diff --check -- README.md docs/updates/v0.1.0.html docs/updates/v0.1.1.html mydocs/release/v0.1.0.md mydocs/release/v0.1.1.md mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md
```

결과:

- `docs/updates/v0.1.1.html`에서 `rhwp v0.7.10`과 `https://github.com/edwardkim/rhwp/releases/tag/v0.7.10` 링크 확인.
- `docs/updates/v0.1.1.html`에서 알한글 `v0.1.1` GitHub Release 링크 확인.
- `docs/updates/v0.1.0.html`에서 `rhwp v0.7.10`과 `https://github.com/edwardkim/rhwp/releases/tag/v0.7.10` 링크 확인.
- `docs/updates/v0.1.0.html`에서 알한글 `v0.1.0` GitHub Release 링크 확인.
- `README.md`에서 최신 공개 릴리즈 `v0.1.0`의 bundled `rhwp v0.7.10` 한 줄 요약 확인.
- `release_policy_guide.md`에서 release identity, title 기본형/예외형, 표준 metadata, upstream sync handoff 기준 확인.
- `release_github_pages_sparkle_guide.md`에서 GitHub Release title, Pages short provenance, Sparkle appcast 앱 버전 경계 확인.
- `mydocs/release/v0.1.0.md`에서 `Release metadata` 표 확인.
- `mydocs/release/v0.1.1.md`에서 `Release metadata` 표 확인.
- `git diff --check`: 통과.

## 다음 단계 제안

Stage 3에서는 `scripts/ci/write-release-notes.sh`가 Stage 2의 표준 `Release metadata` 표를 생성하도록 바꾸고, `scripts/ci/check-release-notes-template.sh`와 `.github/workflows/release-publish.yml`의 release title 생성 경로를 정책과 맞춘다.
