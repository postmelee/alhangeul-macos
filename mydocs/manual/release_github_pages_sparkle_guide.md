# GitHub Release, Pages, Sparkle 가이드

## 목적

이 문서는 GitHub Release 본문, Pages 업데이트 문서, Sparkle stable appcast, 포함 PR 분석, release delta checklist 기준을 정리한다. public DMG 생성과 signing/notarization은 각각 [`release_packaging_dmg_guide.md`](release_packaging_dmg_guide.md), [`release_signing_notarization_guide.md`](release_signing_notarization_guide.md)를 따른다.

## 권한 원칙

- GitHub Release 게시, release asset upload, Sparkle appcast 갱신, Pages deployment는 작업지시자의 명시 승인 후 수행한다.
- draft 또는 prerelease가 아닌 official release에서만 stable appcast와 Pages deployment를 실행한다.
- `draft=true`, `prerelease=false` release workflow 실행은 signed/notarized DMG를 public publish 전에 smoke하기 위한 pre-public 검증 단계다. 이 단계에서 stable appcast와 Pages deployment가 skip되는 것은 정상 동작이다.
- `main`에 merge된 `docs/**` 변경의 docs-only Pages 자동 배포는 승인된 merge 결과를 반영하는 운영 경로이며, Sparkle appcast를 새로 생성하지 않고 기존 public appcast를 보존한다.
- GitHub token과 Sparkle EdDSA private key는 저장소에 기록하지 않는다.

## GitHub Release 생성 전 확인

- release branch 또는 tag 기준 commit이 정확한가
- 릴리즈 상세 기록 `mydocs/release/v<version>.md`가 현재 release candidate 기준으로 갱신되었는가
- 직전 public release 이후 merge된 PR의 title/body, linked Issue, 최종 보고서를 읽고 `포함 PR 분석` 표가 작성되었는가
- 직전 public release 대비 delta checklist가 생성되고 release owner가 PR 분석표의 누락 확인용 보조 자료로 보정했는가
- GitHub Release body의 `이번 버전의 주요 변경 사항`에 `변경 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`가 실제 사용자-facing 내용으로 보정되었는가
- `변경 요약`과 `알한글 앱 변화`가 `포함 PR 분석` 표에서 사용자-facing으로 판정된 항목만 기준으로 작성되었는가
- GitHub Release body에 릴리즈 요약에 반영된 PR, 해결된 Issue, 참고/연관 Issue를 구분하는 section이 있는가
- GitHub Release body에 `mydocs/release/v<version>.md` 같은 실제 조회 가능한 상세 문서가 GitHub blob URL로 링크되어 있는가
- 마지막 release candidate 변경, bugfix PR, draft signed/notarized DMG smoke 이후 official stable publish 전에 GitHub Release body와 Pages 업데이트 문서를 다시 검토했는가
- `변경 요약`과 `알한글 앱 변화`가 특정 검증 샘플명, issue 번호, 내부 구현 용어가 아니라 사용자가 보는 증상과 개선 결과 중심으로 쓰였는가
- GitHub Release title이 기본형 `Alhangeul v<version>`을 쓰는가, 또는 upstream `rhwp` 반영 중심 release라서 `(rhwp vX.Y.Z)` 병기 조건을 충족하는가
- `rhwp-core.lock`의 core repository와 commit이 release note에 기록되었는가
- `rhwp-studio` manifest의 release tag와 commit이 release note에 기록되었는가
- third-party notices 위치가 release note에 기록되었는가
- `validate-stage3-render.sh` 결과가 release report에 기록되었는가
- DMG 파일 SHA256이 기록되었는가
- 렌더링 경로, 알려진 한계, 수동 확인 항목이 기록되었는가

## GitHub Release title

기본 title은 앱 버전만 사용한다.

```text
Alhangeul v<version>
```

Upstream `rhwp` core 또는 bundled `rhwp-studio` 반영이 release의 중심 사용자-facing 변화일 때만 다음 형식을 허용한다.

```text
Alhangeul v<version> (rhwp v<rhwp-version>)
```

이 예외를 쓰는 경우 release body의 `Release metadata`와 `포함된 rhwp 변화`에 bundled `rhwp` 변경 영향과 검증 결과를 함께 기록한다. 앱 자체 bugfix, packaging, Pages/appcast, Homebrew, 문서 변경 중심 release는 기본 title을 유지한다.

## Delta checklist

delta checklist 초안 생성:

```bash
scripts/ci/write-release-delta-checklist.sh <previous-release-tag> <candidate-ref> build.noindex/release/delta-checklist-<version>.md
```

GitHub Actions workflow에서 생성되는 경우:

- `Release Rehearsal DMG`
  - input: `previous_release_ref`
  - candidate ref: workflow checkout commit인 `$GITHUB_SHA`
  - artifact: `alhangeul-macos-<version>-rehearsal-delta-checklist`
- `Release Publish DMG`
  - input: `previous_release_ref`
  - candidate ref: `v<version>`
  - artifact: `alhangeul-macos-<version>-release-delta-checklist`

두 workflow 모두 `GITHUB_STEP_SUMMARY`에 previous ref, candidate ref, checklist path를 남긴다. workflow artifact 또는 로컬 helper 출력 중 하나를 release owner가 검토하고 보정한다.

이 helper는 변경 파일 path 기반 초안만 만든다. release owner는 누락, 과잉, smoke 필요 여부를 보정해야 하며, 사용자-facing release note 판단의 1차 입력으로 쓰지 않는다. 공개 요약의 1차 입력은 `포함 PR 분석` 표다.

영향 영역 후보:

- HostApp viewer
- Quick Look preview
- Finder thumbnail
- 저장/다른 이름 저장
- PDF/인쇄/공유
- Sparkle/appcast/Pages
- DMG/signing/notarization
- Homebrew Cask
- `rhwp` core/viewer asset provenance
- 문서 전용 변경

## 포함 PR 분석

릴리즈 노트는 코드 전체 diff보다 직전 공개 릴리즈 이후 merge된 PR, 연결 Issue, 작업 최종 보고서를 먼저 읽고 작성한다. 기준 범위는 release owner가 확정한 `previous_release_ref..candidate_ref`다.

분석 순서:

1. `previous_release_ref..candidate_ref` 범위의 merge PR 목록을 만든다.
2. 각 PR의 title, body, closing keyword, 참고/연관 Issue 표기, 변경 파일 요약을 확인한다.
3. 내부 타스크 PR이면 `mydocs/report/task_*_<issue>_report.md` 후보를 찾아 최종 보고서를 읽는다.
4. 각 PR을 `사용자-facing`, `개발자-facing`, `운영/배포`, `문서-only`, `upstream sync` 중 하나로 분류한다.
5. 사용자-facing 여부와 공개 요약 반영 여부를 release owner가 확정한다.
6. path 기반 delta checklist로 누락된 영향 영역이나 smoke 항목이 없는지 보조 확인한다.

`mydocs/release/v<version>.md`에는 다음 표준 표를 남긴다.

| PR | 제목 | 분류 | 사용자-facing | 공개 요약 반영 | 해결된 Issue | 참고/연관 Issue | 근거 문서 | 비고 |
|----|------|------|---------------|----------------|---------------|-------------|-----------|------|
| `#<PR>` | PR title | 사용자-facing / 개발자-facing / 운영/배포 / 문서-only / upstream sync | 예/아니오/확인 필요 | 예/아니오 | `#<issue>` 또는 없음 | `#<issue>` 또는 없음 | PR body, 최종 보고서, release record | 판단 근거 |

분류 기준:

- 사용자-facing: HostApp, Quick Look preview, Finder thumbnail, 저장/공유/PDF/인쇄, 설치, 업데이트처럼 사용자가 직접 체감하는 앱 동작이나 표시 결과가 달라지는 변경.
- 개발자-facing: 내부 개발자, 리뷰어, CI 작성자, 기여자 경험을 바꾸지만 일반 사용자 안내의 주요 요약이 아닌 변경.
- 운영/배포: release workflow, signing/notarization, Pages/Sparkle, Homebrew, version/build, release record처럼 배포 운영과 검증 경로를 바꾸는 변경.
- 문서-only: source 동작이나 배포 산출물을 바꾸지 않는 문서 정리.
- upstream sync: `rhwp` core 또는 bundled `rhwp-studio` provenance를 upstream release/commit 기준으로 동기화하는 변경. upstream sync는 사용자-facing 효과와 provenance 변경이 섞일 수 있으므로 upstream release note와 앱 경로 영향 검토 뒤 사용자-facing 여부를 별도로 판정한다.

Issue 구분 기준:

- `해결된 Issue`는 PR title/body/report/branch에서 확인되는 대상 타스크 Issue, PR body의 closing keyword(`Closes`, `Fixes`, `Resolves` 등), 또는 release record에서 완료 확정된 항목을 쓴다.
- `Related`, `Refs`, `관련 이슈`, `선행/연관`, 단순 링크는 `참고/연관 Issue`로 분리한다.
- PR body가 특정 Issue를 언급하더라도 완료 확정 근거가 없으면 해결된 Issue로 쓰지 않는다.
- 이전 public release에서 이미 해결된 Issue는 이번 릴리즈의 public `참고/연관 Issue`에 다시 나열하지 않고 `포함 PR 분석` 표의 PR별 참고 근거로만 남긴다.
- GitHub Release body와 PR body에 `#<number>` 뒤 한글 조사가 바로 붙지 않게 한다. 공개 body는 등록 전 `scripts/validate-github-body.sh <body-file>`를 통과해야 한다.
- GitHub Release body의 PR/Issue 목록은 GitHub 자동 제목 치환에 의존하지 않는다. `[#<number>: 제목](URL) - 한 줄 설명`처럼 번호, 제목, 필요한 설명을 본문에 직접 남긴다.

## Release note 본문

Release note에 포함할 내용:

- 주요 변경 사항: `변경 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`
- 다운로드 및 설치: `다운로드`, `지원 환경`, `설치 후 첫 실행`, `업데이트 확인`, `Homebrew` 하위 구분으로 DMG, SHA256, 지원 macOS, universal DMG, 첫 실행, Quick Look/Thumbnail 활성화, 업데이트 확인, Homebrew 공개 상태를 정리한다.
- 알려진 제한 사항: viewer/editor 실행 경로, Quick Look/Thumbnail/PDF/인쇄 경로 차이, smoke 의미, 후속 native renderer 범위
- 이번 릴리즈 관련 PR과 Issue: 릴리즈 요약에 반영한 PR, 해결된 Issue, 참고/연관 Issue 구분
- 상세 기록: release detail doc, release index, Pages 릴리즈 노트, GitHub Release URL, `Release metadata`, Third Party notices, bundled font notice

### 주요 변경 사항 작성 기준

`## 이번 버전의 주요 변경 사항`은 release owner가 직전 public release 대비 실제 사용자-facing 변화를 보정해 작성한다. generated template이나 delta checklist 초안을 그대로 두지 않는다. GitHub Release body에서는 이 section을 첫 top-level section으로 둔다. `변경 요약`과 `알한글 앱 변화`는 `포함 PR 분석` 표에서 사용자-facing으로 판정된 항목만 기준으로 작성한다.

작성 원칙:

- 공개 릴리즈 노트의 top-level 요약은 "영향을 받는 문서/기능 영역", "사용자가 보던 증상", "이번 버전에서 달라진 결과" 순서로 일반화해 쓴다.
- 검증 fixture, 샘플 파일명, issue 번호, PR 번호, stage 번호는 public Pages와 GitHub Release의 주요 변경 요약에 쓰지 않는다. 해당 정보는 내부 release record, 검증 결과, changelog provenance에 둔다.
- `PUA`, `sentinel`, `render tree`, `CoreGraphics`처럼 일반 사용자가 바로 이해하기 어려운 구현 용어는 먼저 "특수 문자/기호 표시", "텍스트 배경/음영", "Quick Look 미리보기" 같은 사용자 용어로 설명하고, 필요할 때만 괄호나 metadata에서 기술 용어를 보충한다.
- workflow default, README 정렬, manifest/checksum/provenance 같은 운영 변경은 사용자에게 직접 영향을 주는 설치, 업데이트, 보안 검증, 배포 경로 변화가 있을 때만 주요 변경에 넣는다. 그렇지 않으면 `Release metadata`, 내부 release record, 최종 보고서로 분리한다.
- 개발자-facing, 운영/배포, 문서-only PR은 사용자-facing 결과가 따로 확인되지 않는 한 `변경 요약`이나 `알한글 앱 변화`의 근거로 쓰지 않는다. 필요한 경우 GitHub Release의 `이번 릴리즈 관련 PR과 Issue`, `기술 세부`, `검증 세부`, 내부 release record에 둔다.
- 설치, 지원 OS, Quick Look 활성화, 업데이트 확인, 상세 문서 링크는 `다운로드 및 설치` 또는 `상세 기록`으로 합치고, `이번 버전의 주요 변경 사항`보다 앞에 두지 않는다.
- `릴리즈 delta 기반 추가 확인 항목`처럼 release owner용 내부 절차는 public GitHub Release body에 쓰지 않는다. delta checklist는 내부 release record와 workflow artifact에서만 누락 확인용으로 사용한다.
- `검증 결과`는 실제 실행 결과가 아닌 가이드라인 문구로 쓰지 않는다. public body에는 검증 세부를 길게 복제하지 않고, 필요한 경우 `상세 기록`의 release detail doc 링크로 연결한다.
- draft signed/notarized DMG smoke 이후 bugfix PR, tag 재지정, release candidate 변경이 있으면 official stable publish 전에 주요 변경 사항을 최종 candidate 기준으로 다시 작성한다.

공개 표면별 역할:

- Pages 업데이트 문서는 사용자용 안내 표면이다. 주요 변경, hero, 설치 안내에는 샘플 파일명, issue 번호, PR 번호, `PUA`, `sentinel`, `CoreGraphics` 같은 구현/검증 용어를 쓰지 않고 증상과 개선 결과로 일반화한다.
- GitHub Release는 사용자와 개발자가 모두 보는 public 표면이다. 첫 top-level section은 `## 이번 버전의 주요 변경 사항`이어야 하며, 설치와 provenance보다 이번 버전에서 달라진 결과를 먼저 보여준다. 샘플 파일명, 구현 용어, 관련 PR/Issue, 검증 fixture는 `이번 릴리즈 관련 PR과 Issue` 또는 내부 release record로 분리한다.
- GitHub Release에는 `## 상세 기록` section을 두고 `mydocs/release/v<version>.md`, 필요 시 `mydocs/release/index.md`, Pages 릴리즈 노트처럼 실제 조회 가능한 문서를 링크한다. 저장소 문서는 plain code path만 쓰지 않고 `https://github.com/postmelee/alhangeul-macos/blob/main/...` 형식의 GitHub blob URL로 연결한다.
- 내부 `mydocs/release/v<version>.md`는 release decision record다. 샘플 파일명, 재현 조건, 구현 용어, 검증 명령, workflow run, 포함 PR 분석, PR/Issue, SHA256, provenance를 가장 자세히 남긴다.
- GitHub Release의 기술 세부 section이 필요하면 주요 변경과 다운로드/설치보다 뒤에 둔다. 기술 세부가 없더라도 release body는 유효하지만, 앱 자체 렌더링 bugfix처럼 재현 샘플과 구현 경계가 중요한 release는 내부 release record 링크를 우선한다.

### Post-publish 문구 정정

public publish 이후 GitHub Release, Pages 업데이트 문서, release record, 최종 보고서의 표현을 다시 다듬어야 하면 같은 release closeout 묶음으로 처리한다.

- 사용자-facing 문구 보정, section heading 변경, 기술 세부/검증 세부 추가, 이전 버전 안내 banner 정규화는 같은 종료 정리 단계에서 한 번에 검토한다.
- 같은 릴리즈의 문구 정정만으로 `devel` PR과 `main` PR을 반복 생성하지 않는다. publish 후 public Pages 또는 release record 반영이 필요한 정정은 `main` 대상 종료 정리 PR 하나로 묶는다.
- GitHub Release 본문을 `gh release edit` 등으로 직접 고친 경우, 같은 종료 정리 PR에 `mydocs/release/v<version>.md`와 최종 보고서를 함께 갱신해 public 상태와 저장소 기록이 어긋나지 않게 한다.
- 종료 정리 PR에는 실제 생성된 PR 목록과 과도하게 쪼개진 작업이 있었다면 그 원인과 다음 릴리즈 적용 규칙을 기록한다.

필수 하위 구분:

- `### 변경 요약`: 이번 릴리즈에서 달라진 점을 3~5개 bullet로 쓴다. `rhwp` 반영과 앱 자체 변경을 합쳐 사용자가 체감할 결과 중심으로 요약한다.
- `### 포함된 rhwp 변화`: upstream `rhwp` core 또는 bundled `rhwp-studio` 변경 중 문서 열기, 렌더링, HWP/HWPX 호환성, viewer/editor 동작에 실제로 영향을 주는 내용을 적는다. upstream release note 전체를 복제하지 않는다.
- `### 알한글 앱 변화`: HostApp, Quick Look, Finder thumbnail, 저장/공유/PDF/인쇄, 설치, 업데이트처럼 앱 저장소가 소유하고 사용자가 체감하는 변화를 적는다. 앱 자체 신규 기능이나 동작 변화가 크지 않으면 "이번 릴리즈의 앱 자체 신규 기능은 크지 않으며, 핵심 변화는 bundled `rhwp` 문서 처리 개선을 앱/Quick Look/Finder 썸네일 경로에 반영한 것"처럼 1~2개 bullet로 짧게 쓴다. source metadata, workflow default, README/Pages 정렬, 단순 version bump, checksum 정렬은 사용자-facing 앱 변화로 쓰지 않는다.

GitHub Release body에는 사용자 요약보다 뒤에 `## 이번 릴리즈 관련 PR과 Issue` section을 둔다. 이 section은 최소 다음 하위 항목을 포함한다. `#<number>`만 단독으로 나열하거나 inline code로 감싸지 않고, GitHub PR/Issue 제목 또는 release owner가 확정한 한 줄 설명을 함께 쓴다.

- `### 릴리즈 요약에 반영된 PR`: release body의 사용자-facing/기술 세부/검증 세부에 실제로 반영한 PR을 `[#<number>: PR 제목](PR URL) - 반영 내용` 형식으로 나열한다.
- `### 해결된 Issue`: 대상 타스크 Issue, closing keyword, release record에서 완료 확정된 Issue만 `[#<number>: Issue 제목](Issue URL) - 완료 근거` 형식으로 나열한다.
- `### 참고/연관 Issue`: `Refs`, `Related`, 선행/연관, 단순 참고 Issue 중 이번 릴리즈 설명에 필요한 항목만 `[#<number>: Issue 제목](Issue URL) - 관련 근거` 형식으로 분리해 나열한다. 이전 public release에서 이미 해결된 Issue나 운영 기록용 Issue는 public body 대신 내부 release record의 `포함 PR 분석` 표에 남긴다.

`rhwp` 버전이 직전 public release와 같으면 `포함된 rhwp 변화` heading은 유지하고 "이번 릴리즈에서 bundled `rhwp` core와 `rhwp-studio` 버전 변경은 없습니다."처럼 짧게 쓴다. upstream `rhwp` 반영이 release의 중심 사용자-facing 변화라면 title 병기 여부와 별개로 upstream release 링크, bundled tag/commit, 앱에서 확인한 영향을 함께 기록한다.

검증, commit, manifest, SHA256 같은 긴 provenance는 `Release metadata`, `검증 결과`, 내부 `mydocs/release/v<version>.md`에 둔다. 주요 변경 사항은 사용자가 이해할 변화 중심으로 유지한다.

Homebrew Cask 안내 기준:

- Issue #209 tap context 검증이 끝나기 전에는 Homebrew 설치 명령을 public 안내에 확정 문구로 쓰지 않는다.
- 검증 전 공식 설치 경로는 GitHub Release DMG와 Pages 다운로드 버튼이다.
- Cask URL은 Sparkle enclosure와 마찬가지로 tag 고정 public universal DMG URL을 사용하고, Intel Mac/Apple Silicon Mac용 URL을 나누지 않는다.
- Issue #209 완료 후 공개할 명령은 `brew install --cask postmelee/tap/alhangeul`을 기준으로 하며, README, GitHub Release 본문, Pages 문구가 같은 명령을 써야 한다.

본문 후보 생성:

```bash
scripts/ci/write-release-notes.sh <version> <public-dmg-sha256> build.noindex/release/release-notes-<version>.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-<version>.md
scripts/validate-github-body.sh build.noindex/release/release-notes-<version>.md
```

`Release metadata`는 `rhwp-core.lock`과 `Sources/HostApp/Resources/rhwp-studio/manifest.json`에서 읽은 값을 기준으로 생성한다. 수동 release note를 작성할 때도 같은 항목명을 사용해 내부 release record와 대조할 수 있게 한다.

## Pages 업데이트 문서

Pages는 사용자용 릴리즈 안내 표면이다. GitHub Release body의 긴 provenance, delta checklist, PR별 검증 기록을 그대로 복제하지 않는다. Pages의 `변경 요약`은 `포함 PR 분석` 표에서 사용자-facing으로 판정된 항목만 기준으로 작성한다.

확인 기준:

- `docs/updates/v<version>.html`이 현재 사이트의 header, hero, action button, content section, footer 구조를 유지하는가
- `docs/updates/index.html`의 최신 항목과 latest DMG link가 최신 public release 파일명을 가리키는가
- Pages 다운로드 버튼이 아키텍처 선택 UI 없이 단일 universal DMG latest URL을 직접 가리키는가
- hero와 `변경 요약`이 내부 구현이나 upstream 버전명보다 이번 버전을 설치했을 때 사용자가 체감할 문서 열기, 미리보기, 설치, 업데이트 변화를 먼저 설명하는가
- 사용자가 필요한 설치 방법, 첫 실행 안내, 업데이트 확인, 알려진 한계를 간결하게 확인할 수 있는가
- Intel Mac과 Apple Silicon Mac이 같은 DMG를 사용한다는 안내가 최신 다운로드 주변 또는 FAQ/릴리즈 노트에 있는가
- 최신 버전이 아닌 `docs/updates/v<version>.html`에는 최신 릴리즈 안내 banner가 있고, 최신 버전 페이지에는 해당 banner가 없는가
- bundled `rhwp`를 안내해야 하는 release라면 `rhwp v<version>`과 upstream release 링크를 짧게 표시하고, commit/manifest/checksum 표는 GitHub Release body와 내부 release record로 연결하는가
- 앱 자체 변화는 `주요 변경` 또는 필요 시 `알한글 앱 변화` section에서 짧게 구분하고, `rhwp` provenance와 한 목록에 과도하게 섞지 않는가
- 특정 샘플 문서명이나 검증 fixture명 대신 "일부 HWP 양식 문서", "특수 문자/기호 표시", "텍스트 배경/음영"처럼 사용자가 이해할 수 있는 증상 단위로 일반화했는가
- `알한글 앱 변화` section이 workflow, README, release record 정렬 같은 운영 항목보다 HostApp, Quick Look preview, Finder thumbnail, 설치/업데이트 경로의 사용자-visible 변화를 우선하는가
- 실제 public DMG SHA256이 아직 확정되지 않은 문서는 release candidate 또는 #188 handoff 상태를 명확히 표시하는가

Pages 다운로드 버튼은 사용자를 위한 latest DMG URL을 사용한다.

```text
https://github.com/postmelee/alhangeul-macos/releases/latest/download/alhangeul-macos-<version>.dmg
```

이전 버전 안내 banner는 수동으로 버전마다 고치지 않는다. `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates`가 `docs/updates/v*.html` 중 가장 높은 semantic version을 최신 릴리즈 노트로 보고, 이전 버전 페이지의 banner를 삽입/갱신하며 최신 버전 페이지의 banner를 제거한다. PR CI는 `--check` 모드로 source가 정규화되어 있는지 확인하고, `prepare-pages-artifact.sh`는 Pages artifact를 만들 때 같은 helper를 한 번 더 실행한다.

### Pages 배포 모델

Pages/appcast 배포는 GitHub Actions Pages deployment 기준이다. repository Pages source는 `build_type=workflow`이어야 하며, `Release Publish DMG` workflow의 official stable release path가 generated `appcast.xml`을 포함한 Pages artifact를 업로드한 뒤 `deploy-pages` job으로 배포한다.

필수 repository 설정:

- Pages source: `workflow`
- environment: `github-pages`
- `github-pages` deployment branch/tag policy: docs-only 배포용 `main` branch와 release tag ref `v<version>`을 허용하는 tag rule `v*`

workflow 기준:

- `scripts/ci/prepare-pages-artifact.sh`가 release tag에 포함된 `docs/` 정적 파일과 generated `appcast.xml`을 Pages artifact directory로 조립한다.
- `actions/upload-pages-artifact@v5`가 Pages artifact를 업로드한다.
- `actions/deploy-pages@v5`가 `github-pages` environment로 배포하고 `page_url` output을 남긴다.
- `deploy-pages` job은 `pages: write`, `id-token: write` 권한을 가진다.
- release workflow와 docs-only workflow는 `pages-deploy` concurrency group을 공유하고 `cancel-in-progress: false`로 Pages deployment를 취소 없이 직렬화한다.
- generated appcast는 Pages source branch에 commit하지 않는다. 장기 기록은 workflow artifact/deployment 기록과 `mydocs/release/v<version>.md`에 남긴다.

### Docs-only Pages 배포

`Docs-only Pages Deploy` workflow는 release와 무관한 `docs/**` 변경을 public Pages에 반영한다. 이 workflow는 `push` to `main` with `docs/**`와 `workflow_dispatch`에서 실행되며, 내부에서 `GITHUB_REF=refs/heads/main`을 확인한다.

역할 분리:

- `Release Publish DMG`: official stable release에서 signed/notarized DMG, GitHub Release asset, generated stable appcast, Pages artifact를 함께 게시한다.
- `Docs-only Pages Deploy`: 이미 public Pages에 배포된 latest appcast를 보존하면서 `docs/` 정적 파일 변경만 배포한다.

appcast 보존 기준:

- docs-only workflow는 Sparkle appcast를 새로 생성하지 않는다.
- public `https://postmelee.github.io/alhangeul-macos/appcast.xml`을 다운로드해 `test -s`와 `xmllint --noout` 검증을 통과한 파일만 Pages artifact root의 `appcast.xml`로 사용한다.
- repository의 `docs/appcast.xml`은 stale copy일 수 있으므로 docs-only 배포 source로 사용하지 않는다.
- public appcast 다운로드 또는 XML 검증이 실패하면 Pages deployment를 중단한다.
- stale `docs/appcast.xml` fallback은 허용하지 않는다.

## Sparkle appcast

알한글 앱은 stable feed 하나만 사용한다.

```text
https://postmelee.github.io/alhangeul-macos/appcast.xml
```

### 앱 업데이트 확인 동작

HostApp은 Sparkle updater를 시작한 뒤, `automaticallyChecksForUpdates`가 켜진 경우에만 `checkForUpdatesInBackground()`를 1회 요청한다. 이 경로는 앱 실행 시 새 release 안내를 더 빨리 받을 수 있게 하기 위한 백그라운드 확인이며, 최신 상태 안내 모달을 강제로 띄우는 수동 확인 경로가 아니다.

앱 메뉴의 `알한글 > 업데이트 확인...`은 사용자가 직접 요청한 확인으로 유지한다. 이 메뉴는 `checkForUpdates(nil)` 경로를 사용하므로, 최신 상태 안내나 이미 진행 중인 업데이트 UI가 사용자에게 표시될 수 있다.

`SUEnableAutomaticChecks`는 자동 확인 기본값을 켜지만, 사용자가 자동 확인을 끈 상태에서는 앱 실행 시 백그라운드 확인을 강제하지 않는다. `SUAutomaticallyUpdate`는 `false`로 유지하며, 새 버전이 발견되어도 설치 여부는 Sparkle 표준 UI에서 사용자가 선택한다.

앱에 포함된 `SUPublicEDKey`는 Sparkle update archive 검증용 public key다. private key는 저장소에 기록하지 않고, release workflow에서는 GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY`로만 전달한다.

Sparkle private key를 GitHub Actions secret에 등록해야 할 때는 release 관리자 로컬 Keychain에서 다음 방식으로 export한다.

```bash
build.noindex/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  -x /path/to/sparkle_ed_private_key.txt
```

export한 파일 내용 전체를 `SPARKLE_ED_PRIVATE_KEY` secret 값으로 등록한 뒤, 파일은 안전하게 삭제한다. 이 값은 Keychain의 “Private key for signing Sparkle updates” 항목 password와 동일한 민감 정보로 취급한다.

`Release Publish DMG` workflow의 appcast 동작 기준:

- `draft=false`이고 `prerelease=false`인 공식 release에서만 stable appcast를 갱신한다.
- `draft=true`, `prerelease=false` 실행은 pre-public signed/notarized DMG smoke 단계다. 이 단계에서는 stable appcast를 갱신하지 않고 step summary에 skip 사유만 남긴다.
- prerelease 실행도 stable appcast와 Pages deployment를 갱신하지 않는다.
- official stable release에서는 workflow가 signed/notarized DMG를 GitHub Release asset으로 업로드한 뒤 `sign_update --ed-key-file - -p`로 DMG EdDSA signature를 만든다.
- official stable release에서는 `scripts/ci/write-sparkle-appcast.sh`가 tag 고정 DMG URL과 release notes URL로 `appcast.xml`을 생성한다.
- official stable release에서는 workflow가 generated `appcast.xml`을 Pages artifact root의 `appcast.xml`로 포함한다.
- official stable release의 `deploy-pages` job이 성공해야 stable appcast 배포 성공으로 본다. branch push fallback을 기본 경로로 사용하지 않는다.

appcast enclosure URL은 latest URL이 아니라 tag 고정 URL을 사용한다.

```text
https://github.com/postmelee/alhangeul-macos/releases/download/v<version>/alhangeul-macos-<version>.dmg
```

이 URL은 단일 universal DMG를 가리킨다. Sparkle appcast는 아키텍처별 enclosure를 나누지 않고, `scripts/release.sh`/workflow가 검증한 `arm64 + x86_64` app/extension bundle을 포함한 public DMG만 stable item으로 사용한다.

Sparkle appcast의 version/build와 enclosure filename은 앱 버전만 사용한다. Bundled `rhwp` 버전은 appcast item version에 넣지 않고, release notes URL이 가리키는 GitHub Pages/GitHub Release metadata에서 확인하게 한다.

따라서 공식 release 완료 후에는 다음을 확인한다.

- `https://github.com/postmelee/alhangeul-macos/releases/latest`가 방금 게시한 non-draft, non-prerelease release를 가리키는가
- `Release Publish DMG` workflow의 `deploy-pages` job이 성공했고 `page_url`이 `https://postmelee.github.io/alhangeul-macos/`를 가리키는가
- Pages 다운로드 버튼의 asset filename이 최신 public DMG 파일명과 일치하는가
- `https://postmelee.github.io/alhangeul-macos/appcast.xml`이 새 release item과 Sparkle EdDSA signature를 포함하는가
