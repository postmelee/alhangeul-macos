# Task M010 #264 Stage 1 완료 보고서

## 단계 목적

릴리즈 안내 표면의 현재 변경사항 구조를 조사하고, `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화` 구분을 어디에 어떤 상세도로 적용할지 확정한다.

이번 단계는 inventory와 정보 구조 확정만 수행했다. manual, script, Pages HTML은 수정하지 않았다.

## 조사 범위

확인한 파일:

- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/release/index.md`
- `mydocs/release/v0.1.2.md`
- `docs/updates/v0.1.2.html`
- `scripts/ci/write-release-notes.sh`
- `scripts/ci/check-release-notes-template.sh`

## 현재 구조

### GitHub Release body

`scripts/ci/write-release-notes.sh`는 다음 큰 heading을 생성한다.

- `## 사용자용 요약`
- `## 설치 방법`
- `## 지원 환경과 아키텍처`
- `## 설치 후 첫 실행과 Quick Look/Thumbnail 활성화 안내`
- `## 업데이트 확인 방법`
- `## 이번 버전의 주요 변경 사항`
- `## 다운로드 산출물과 SHA256`
- `## Homebrew Cask`
- `## Release metadata`
- `## 검증 결과`
- `## 릴리즈 delta 기반 추가 확인 항목`
- `## 알려진 제한 사항과 후속 이슈`
- `## Third Party notices`

문제는 `## 이번 버전의 주요 변경 사항`이 실제 변경사항을 담지 않고 다음 성격의 안내만 생성한다는 점이다.

- 직전 공개 릴리즈 대비 사용자-facing 변경은 release delta checklist 기준으로 정리한다.
- Issue/PR과 기여자는 release detail doc 기준으로 확인한다.
- 문서 전용 변경과 설치본 smoke가 필요한 변경은 release delta checklist에서 구분한다.

즉, GitHub Release body가 release owner의 보정이 필요하다는 사실은 알려주지만, 사용자가 설치 전에 알아야 할 실제 변경사항을 `rhwp` 변화와 앱 변화로 분리해 보여주지 않는다.

`scripts/ci/check-release-notes-template.sh`도 현재는 큰 heading 존재만 검사한다. `## 이번 버전의 주요 변경 사항` 내부에 실제 사용자-facing 구분이 있는지는 검증하지 않는다.

### Pages 릴리즈 노트

`docs/updates/v0.1.2.html`은 사용자용 짧은 안내 표면으로 기능한다. 현재 구조는 다음과 같다.

- `주요 변경`: `rhwp` core/studio 갱신, About provenance, update maintenance, UTI policy, Web viewer runtime banner, universal DMG 안내가 한 목록에 섞여 있다.
- `포함된 rhwp`: `rhwp v0.7.11` upstream release 링크와 provenance commit을 짧게 표시한다.
- `알려진 한계`
- `설치와 업데이트`

Pages는 GitHub Release body의 긴 검증과 provenance를 복제하지 않는다는 manual 기준과 잘 맞는다. 다만 `주요 변경` 목록 안에서는 `rhwp` 변화와 앱 변화가 섞여 있어, 다음 릴리즈부터는 짧은 구분 기준을 manual에 명시하는 편이 좋다.

### 내부 릴리즈 기록

`mydocs/release/v0.1.2.md`는 현재 가장 좋은 기준 사례다.

- `사용자용 요약`에서 release 전체 의미를 한 문단으로 설명한다.
- `직전 공개 릴리즈 대비 변경점` 표에서 `Core/studio`, `About window`, `Update maintenance`, `UTI policy`, `Web viewer runtime error UX`, `Release metadata`, `Release communication`으로 영역을 나눈다.
- `Release metadata`와 검증 결과는 별도 섹션에 분리한다.

이 구조는 내부 기록에는 충분하지만, GitHub Release body와 Pages에 직접 강제되지는 않는다. Stage 2에서는 `mydocs/release/index.md`의 정보 소유 기준과 갱신 순서에 새 구분을 연결한다.

## 확정한 정보 구조

### GitHub Release body

기존 큰 heading `## 이번 버전의 주요 변경 사항`은 유지한다. 그 아래에 다음 하위 heading을 필수로 둔다.

```md
### 전체 요약

### 포함된 rhwp 변화

### 알한글 앱 변화
```

적용 기준:

- `전체 요약`: 이번 릴리즈를 설치해야 하는 이유를 3~5개 bullet로 쓴다. 사용자가 가장 먼저 읽는 변화 요약이다.
- `포함된 rhwp 변화`: upstream `rhwp` core 또는 bundled `rhwp-studio` 변경 중 앱 사용자가 체감할 수 있는 문서 열기, 렌더링, HWP/HWPX 호환성, viewer/editor 동작 영향을 적는다.
- `알한글 앱 변화`: HostApp, Quick Look, Finder thumbnail, 저장/공유/PDF/인쇄, 설치, 업데이트, About, DMG, Homebrew, Pages/Sparkle 등 앱 저장소가 소유한 변화를 적는다.

`rhwp`가 바뀌지 않은 릴리즈에서도 `### 포함된 rhwp 변화` heading은 유지한다. 이 경우 다음처럼 짧게 작성할 수 있게 한다.

```md
- 이번 릴리즈에서 bundled `rhwp` core와 `rhwp-studio` 버전 변경은 없습니다.
```

`rhwp` 반영 중심 릴리즈에서는 `include_rhwp_in_title=true` 사용 여부를 기존 정책대로 판단하되, title 병기 여부와 무관하게 `### 포함된 rhwp 변화`에 upstream release 링크와 앱 영향 요약을 남긴다.

### Pages 릴리즈 노트

Pages는 사용자용 짧은 안내 표면이다. 따라서 GitHub Release body의 heading을 그대로 모두 복제하지 않는다.

적용 기준:

- hero 문단 또는 첫 section에서 `전체 요약`에 해당하는 한 문단 요약을 제공한다.
- bundled `rhwp` 변경이 있는 릴리즈는 기존 `포함된 rhwp` section을 유지하고, upstream release 링크를 짧게 둔다.
- 앱 변화는 `주요 변경` 또는 필요 시 `알한글 앱 변화` section으로 구분한다.
- commit, manifest, checksum, 상세 검증 결과는 GitHub Release body와 `mydocs/release/v<version>.md`로 연결한다.

Stage 2 manual 문구는 "필요 시 `알한글 앱 변화` section을 둔다" 수준으로 두고, 기존 public Pages 파일을 소급 수정하지 않는다.

### 내부 릴리즈 기록

`mydocs/release/v<version>.md`는 장기 기록이므로 현재의 `직전 공개 릴리즈 대비 변경점` 표를 유지하되, release owner가 `Core/studio` 계열과 앱 변화 계열을 누락 없이 대조하도록 `mydocs/release/index.md`에 갱신 순서를 보강한다.

## Stage 2 변경 범위

Stage 2에서는 다음을 수정한다.

- `mydocs/manual/release_github_pages_sparkle_guide.md`
  - GitHub Release body의 세 하위 heading 기준 추가
  - Pages 릴리즈 노트의 짧은 적용 기준 추가
- `mydocs/release/index.md`
  - 릴리즈 문서 갱신 순서에 `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화` 대조 기준 추가
- `mydocs/manual/release_distribution_guide.md` 또는 `release_policy_guide.md`
  - Stage 2에서 실제 문맥을 보며 checklist 연결이 필요한 경우에만 최소 보강

Stage 2에서는 script 변경을 하지 않는다.

## Stage 3 변경 범위

Stage 3에서는 다음을 수정한다.

- `scripts/ci/write-release-notes.sh`
  - `## 이번 버전의 주요 변경 사항` 아래에 `### 전체 요약`, `### 포함된 rhwp 변화`, `### 알한글 앱 변화` 생성
  - `### 포함된 rhwp 변화`에는 `rhwp` release tag와 upstream release URL을 포함
  - 실제 변경 내용은 release owner가 보정해야 한다는 안내를 유지하되, 사용자-facing 구분이 비어 보이지 않게 작성 지침 bullet을 둠
- `scripts/ci/check-release-notes-template.sh`
  - 위 세 하위 heading을 필수 heading으로 검사

## 부수 관찰

`release_github_pages_sparkle_guide.md`의 Homebrew 예시 명령은 `brew install --cask postmelee/tap/alhangeul-macos`이고, 현재 README/Pages/release record의 공개 명령은 `brew install --cask postmelee/tap/alhangeul`이다. 이번 Stage 1의 주된 범위는 변경사항 구분 구조이므로 직접 수정하지 않았다. Stage 2에서 같은 문서를 수정할 때 release communication 일관성 보정 범위에 포함할지 판단한다.

## 검증

실행한 명령:

```bash
rg -n "사용자용 요약|이번 버전의 주요 변경 사항|주요 변경|포함된 rhwp|Release metadata|release delta|직전 공개 릴리즈 대비 변경점|GitHub Release body|Pages" \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/manual/release_policy_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/release/index.md \
  mydocs/release/v0.1.2.md \
  docs/updates/v0.1.2.html \
  scripts/ci/write-release-notes.sh \
  scripts/ci/check-release-notes-template.sh
```

결과:

- 현재 manual은 release note 필수 큰 항목과 Pages 역할을 정의하지만, 세 하위 구분을 요구하지 않는다.
- release note generator는 실제 변경사항을 생성하지 않고 release delta checklist 참조 문구만 생성한다.
- template checker는 큰 heading만 검사한다.
- 내부 기록과 Pages v0.1.2는 새 구조의 근거로 삼을 수 있는 사례를 이미 일부 갖고 있다.

## 다음 단계 승인 요청

Stage 2에서는 위 정보 구조를 기준으로 release manual과 `mydocs/release/index.md`를 보강한다. 기존 public GitHub Release body 수정, public Pages deployment, script 변경은 Stage 2 범위에서 제외한다.
