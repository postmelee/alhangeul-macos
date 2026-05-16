# Task M018 #185 Stage 1 완료 보고서

## 단계 목적

현재 release communication 표면을 조사하고, GitHub Release 본문, Pages 업데이트 페이지, README, `mydocs/release/`가 각각 어떤 정보를 소유할지 확정했다.

이번 단계는 구현 전 기준 확정 단계이므로 release note script, Pages HTML, README, 매뉴얼 본문은 수정하지 않았다. 후속 Stage 2~4에서 적용할 변경 원칙과 정보 경계만 이 보고서에 기록한다.

## 산출물

- `mydocs/working/task_m018_185_stage1.md`: Stage 1 조사 결과와 정보 소유 경계 기록

조사 대상 파일과 규모:

- `scripts/ci/write-release-notes.sh`: 95 lines
- `docs/updates/index.html`: 106 lines
- `docs/updates/v0.1.0.html`: 98 lines
- `docs/appcast.xml`: 9 lines
- `README.md`: 521 lines
- `mydocs/manual/release_distribution_guide.md`: 631 lines
- `mydocs/plans/task_m018_185_impl.md`: 293 lines

선행 이슈 반영 상태:

- #183 `v0.1.0 설치본에서 창 확대 시 WebView runtime error 발생`: GitHub issue CLOSED, `devel-webview`에 PR #191 merge 확인
- #199 `공식 릴리즈 Finder thumbnail 생성 hang 수정`: GitHub issue CLOSED, `devel-webview`에 PR #200 merge 확인
- #184 `DMG 설치 창 안내와 첫 실행 안내 개선`: GitHub issue CLOSED, `devel-webview`에 PR #201 merge 확인

## 조사 결과

### `scripts/ci/write-release-notes.sh`

현재 script는 `<version> <dmg-sha256> <output-file>`만 입력받고, public DMG용 GitHub Release note skeleton을 생성한다. 입력 검증은 semantic version과 64자 SHA256을 확인하고, `rhwp-core.lock`, `rhwp-studio` manifest, third-party notice 파일 존재를 확인한다.

현재 출력은 다음 항목 중심이다.

- 설치
- 산출물
- 포함된 `rhwp` core
- 포함된 viewer asset provenance
- Third Party notices
- 렌더링 경로와 알려진 제한 사항
- 검증

누락 또는 보강이 필요한 항목:

- 사용자용 요약
- 설치 후 첫 실행과 Quick Look/Thumbnail 활성화 안내
- Sparkle 업데이트 확인 방법
- 이번 버전의 주요 변경 사항
- release delta 기반 추가 확인 항목
- 후속 이슈
- 실제 smoke 결과와 #188 handoff 구분
- 필수 섹션 누락 검증

### Pages 업데이트 페이지

`docs/updates/index.html`은 업데이트 안내와 Sparkle appcast URL, 릴리즈 목록을 제공한다. 최신 DMG 다운로드 버튼은 현재 `releases/latest/download/alhangeul-macos-0.1.0.dmg`를 가리킨다.

`docs/updates/v0.1.0.html`은 현재 사용자가 마음에 든다고 확인한 양식이다. 구조는 다음과 같다.

- 동일한 site header와 brand link
- hero 영역의 릴리즈 제목, 요약, primary/secondary action
- `updates-content` 안의 `updates-section` 반복
- 주요 기능, 알려진 한계, 설치와 업데이트
- 기존 footer

확정 기준:

- Stage 3에서 `docs/updates/v0.1.1.html`은 이 양식과 CSS/class 구조를 유지한다.
- 사이트 스타일, layout, hero/footer 디자인 개편은 하지 않는다.
- Pages 페이지는 GitHub Release 본문을 길게 복제하지 않고 사용자-facing 요약과 설치/업데이트 안내 중심으로 둔다.
- 운영 상세, delta checklist, PR별 검증은 `mydocs/release/v0.1.1.md`와 GitHub Release 본문으로 넘긴다.

### Sparkle appcast

현재 `docs/appcast.xml`은 channel skeleton만 있고 item은 없다. `scripts/ci/write-sparkle-appcast.sh`는 version, build, tag-fixed DMG URL, byte length, EdDSA signature, release notes URL, pubDate를 받아 stable appcast item을 생성한다.

확정 기준:

- appcast의 DMG URL은 tag 고정 URL을 사용한다.
- Pages 다운로드 버튼은 사용자 편의를 위해 latest URL을 사용할 수 있지만, release 완료 후 asset filename이 최신 public DMG와 일치하는지 확인한다.
- appcast 게시와 EdDSA signature 생성은 #188 범위로 넘긴다.

### README

README는 제품 소개, 이정표, 전체 로드맵, 기능 설명, 렌더링 경로, 알려진 한계, Release/Install, 개발 워크플로우까지 포함하고 있어 release가 누적될수록 최신 릴리즈 요약과 장기 로드맵이 섞일 위험이 있다.

확정 기준:

- README는 프로젝트 소개, 현재 작업 축, 최신 공개 릴리즈 1개 요약만 유지한다.
- 과거 릴리즈 상세는 README에 누적하지 않고 `mydocs/release/`와 GitHub Release 링크로 넘긴다.
- 기존 기능/렌더링 경로/known limitations 중 public release note와 중복되는 항목은 README에서 과도하게 늘리지 않는다.

### 배포 매뉴얼

`release_distribution_guide.md`에는 public DMG, rehearsal DMG, GitHub Release, Sparkle appcast, Homebrew Cask, 릴리스 체크리스트 기준이 이미 존재한다. 다만 GitHub Release, Pages 업데이트 페이지, README 최신 릴리즈 블록, `mydocs/release/` 장기 기록을 하나의 release communication 기준으로 묶는 규칙은 아직 약하다.

확정 기준:

- Stage 5에서 GitHub Release 본문 작성, Pages 업데이트, appcast 확인, README 최신 릴리즈 요약, `mydocs/release/v<version>.md` 작성 항목을 릴리스 체크리스트에 통합한다.
- public release 실행, GitHub Release 게시, appcast 게시, Homebrew tap 반영은 계속 작업지시자 명시 승인 범위로 둔다.

### 참고 release 구조

참고 자료인 `edwardkim/rhwp` `v0.7.10` release는 제목에서 핵심 변화를 요약하고, 한 문단 cycle 요약 뒤 신규 기능, 외부 PR/기여자, 후속 이슈, 잔여 PR, changelog 링크로 구성되어 있다.

알한글에 적용할 때는 그대로 복제하지 않고 다음만 차용한다.

- 릴리즈 제목과 첫 문단에서 cycle의 의미를 빠르게 요약한다.
- 주요 변경, 기여자/PR, 후속 이슈를 별도 섹션으로 둔다.
- 상세 changelog 또는 장기 기록 문서 링크를 둔다.

알한글에서 우선 배치할 내용은 다음이다.

- DMG 설치 방법
- 설치 후 첫 실행과 Quick Look/Thumbnail 활성화
- Sparkle 업데이트 확인 방법
- DMG/SHA256
- signing/notarization/Gatekeeper 검증 요약
- `rhwp` core와 bundled viewer asset provenance
- 렌더링 경로와 알려진 한계

참고 URL: https://github.com/edwardkim/rhwp/releases/tag/v0.7.10

## 정보 소유 경계

| 표면 | 역할 | 포함할 정보 | 제외 또는 링크로 넘길 정보 |
|------|------|-------------|----------------------------|
| GitHub Release 본문 | public release의 공식 상세 안내 | 사용자 요약, 설치/첫 실행, 업데이트 확인, 주요 변경, DMG/SHA256, provenance, 검증 결과, delta 추가 확인 항목, known limitations, third-party notices | Pages용 긴 HTML 서술, 내부 단계별 보고서 전문 |
| Pages `docs/updates/index.html` | 사용자가 확인하는 업데이트 landing | 최신 DMG 다운로드, Sparkle appcast URL, 릴리즈 목록 | 긴 provenance, PR별 검증, 내부 체크리스트 |
| Pages `docs/updates/v<version>.html` | 사용자-facing 버전별 릴리즈 페이지 | 현재 디자인을 유지한 요약, 주요 변경, 알려진 한계, 설치와 업데이트 | GitHub Release 본문 전체 복제, delta checklist 전문 |
| `docs/appcast.xml` | Sparkle stable feed | version/build, tag-fixed DMG URL, release notes URL, EdDSA signature, minimum system version | 사용자용 긴 본문 |
| README | 프로젝트 첫 화면 | 제품 소개, 현재 작업 축, 최신 공개 릴리즈 1개 요약, 상세 링크 | 과거 릴리즈 상세 누적, 운영 체크리스트 |
| `mydocs/release/index.md` | 내부 장기 릴리즈 목록 | 릴리즈별 문서 목록, 최신 릴리즈, GitHub Release/Pages 링크 | 단계별 작업 보고서 전문 |
| `mydocs/release/v<version>.md` | release communication 장기 기록 | 변경점, Issue/PR, 기여자, 검증 결과, known limitations, provenance, GitHub Release/Pages/appcast 링크, #188 handoff | 사용자에게 바로 보여줄 짧은 landing copy |
| `release_distribution_guide.md` | 운영 절차 | release communication 작성/검증 체크리스트와 게시 순서 | 버전별 상세 기록 |

## 본문 변경 정도 / 본문 무손실 여부

- 이번 단계에서 기존 release note script, Pages HTML, README, 매뉴얼 본문은 수정하지 않았다.
- 새로 추가한 문서는 Stage 1 보고서뿐이다.
- 기존 사용자-facing Pages 디자인은 손대지 않았고, Stage 3에서도 현 양식 유지가 수용 기준이다.
- 조사 결과는 후속 단계에서 적용할 기준으로만 기록했다.

## 검증 결과

구현계획서 Stage 1 검증 명령을 수행했다.

```bash
git status --short --branch
```

결과:

```text
## local/task185
?? mydocs/working/task_m018_185_stage1.md
```

```bash
bash -n scripts/ci/write-release-notes.sh
```

결과: 출력 없음, exit code 0.

```bash
rg -n "Release|release|업데이트|appcast|SHA256|provenance|Quick Look|Thumbnail" README.md docs/updates docs/appcast.xml mydocs/manual/release_distribution_guide.md scripts/ci/write-release-notes.sh
```

결과 요약:

- README의 milestone/roadmap/features/release install 구간에 Quick Look, Thumbnail, release, provenance, checksum 설명이 분산되어 있다.
- `scripts/ci/write-release-notes.sh`는 SHA256, core/viewer provenance, Third Party notices, 렌더링 경로와 한계를 생성한다.
- `release_distribution_guide.md`는 GitHub Release, Sparkle appcast, Pages latest URL, Homebrew Cask, 릴리스 체크리스트 기준을 포함한다.
- `docs/updates/index.html`과 `docs/updates/v0.1.0.html`은 latest DMG URL, 업데이트 확인, Sparkle appcast, 주요 기능, 알려진 한계, 설치 안내를 포함한다.
- `docs/appcast.xml`은 현재 channel skeleton만 포함한다.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

추가 확인:

```bash
git tag --list 'v0.1.0'
git diff --name-only v0.1.0..HEAD
git log --oneline v0.1.0..HEAD --max-count=80
```

결과 요약:

- `v0.1.0` tag 존재 확인
- `v0.1.0..HEAD` 범위에는 #183, #199, #184, #185 관련 commit과 release workflow, HostApp WebView bridge, thumbnail provider/cache, DMG layout, release manual, task 문서 변경이 포함된다.
- Stage 4에서 이 범위를 delta checklist의 기본 입력으로 사용할 수 있다.

## 잔여 위험

- Pages의 최신 DMG 링크는 latest URL과 versioned filename을 함께 쓰므로 release 게시 순서에 따라 stale 상태가 생길 수 있다. Stage 3과 Stage 5에서 체크리스트로 보강해야 한다.
- `v0.1.1` public DMG SHA256과 appcast EdDSA signature는 #188에서 확정되므로 이번 작업의 후보 문서에는 placeholder가 남을 수 있다.
- release delta는 파일 경로만으로 영향 영역을 완벽히 판단할 수 없다. Stage 4 helper를 만들더라도 release owner 보정이 필요하다.
- README를 줄일 때 기존 roadmap의 유용한 장기 방향까지 잃지 않도록, 제품 방향과 릴리즈 상세를 분리해야 한다.
- `edwardkim/rhwp` release 구조는 CLI/core 프로젝트 기준이므로 알한글에는 설치/첫 실행/공증/provenance를 우선하는 방식으로만 차용해야 한다.

## 다음 단계 영향

Stage 2에서는 GitHub Release 본문 template을 먼저 보강한다. 이번 단계에서 확정한 정보 경계에 따라 GitHub Release 본문에는 상세 운영 정보를 넣고, Pages용 간결한 문구나 README 요약 문구까지 과도하게 섞지 않는다.

Stage 3에서는 `docs/updates/v0.1.0.html`의 현재 디자인을 유지하는 조건으로 `v0.1.1` Pages 후보를 만든다. 디자인 개편은 하지 않고 버전, 링크, 사용자-facing 문구만 갱신한다.

Stage 4에서는 `mydocs/release/`를 장기 기록 위치로 만들고, `v0.1.0..HEAD` 범위를 기준으로 release delta checklist 초안을 생성하거나 수동 작성 기준을 문서화한다.

Stage 5에서는 배포 매뉴얼의 checklist가 GitHub Release, Pages, README, release detail 문서, appcast 검증을 함께 요구하도록 정리한다.

## 승인 요청

Stage 1 산출물과 정보 소유 경계 승인을 요청한다.

승인 후 Stage 2 `GitHub Release 본문 template과 필수 섹션 검증 구현`으로 진행한다.
