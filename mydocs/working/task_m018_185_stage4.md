# Task M018 #185 Stage 4 완료 보고서

## 단계 목적

릴리즈별 장기 기록 문서 구조를 만들고, 직전 공개 릴리즈 대비 변경 delta를 release candidate 검증 입력으로 넘기는 기준을 마련했다. 동시에 `release_distribution_guide.md`에서 버전별 기록, 환경 식별자, troubleshooting 후보로 분리할 정보를 분류했다.

## 산출물

- `mydocs/release/index.md`: 52 lines
  - 릴리즈 기록 폴더의 역할, 릴리즈 목록, 정보 소유 기준, 갱신 순서 작성
- `mydocs/release/v0.1.0.md`: 93 lines
  - 실제 공개된 `v0.1.0` GitHub Release 상태, asset, SHA256, 배포 결정, 제공 기능, known limitations, provenance 기록
- `mydocs/release/v0.1.1.md`: 95 lines
  - `v0.1.1` release candidate 기록 초안, `v0.1.0` 대비 변경점, 연결 Issue/PR, #188 public smoke handoff 작성
- `mydocs/tech/release_environment.md`: 68 lines
  - Team ID, signing identity 표시명, notary profile name, GitHub Actions 변수/secret 이름 등 비밀이 아닌 운영 환경 식별자 분리
- `mydocs/manual/document_structure_guide.md`: 107 lines
  - `release/` 폴더 역할, `v<version>.md` 파일명 기준, release environment 문서, troubleshooting 분리 기준 추가
- `scripts/ci/write-release-delta-checklist.sh`: 190 lines
  - `previous-release-ref`, `candidate-ref`, `output-file`을 받아 변경 파일 path 기반 영향 영역 초안을 생성
  - 한 파일이 여러 영향 영역에 걸칠 수 있으므로 중복 표시를 허용
  - release owner 수동 보정 필요성을 output에 명시
- `build.noindex/release/delta-checklist-0.1.1.md`
  - 검증용 생성 산출물이며 git 추적 대상은 아님

## 본문 변경 정도 / 본문 무손실 여부

- 이번 단계에서는 `release_distribution_guide.md` 본문을 아직 직접 일반화하지 않았다. Stage 4의 목적은 분리 대상 문서와 기준을 먼저 만들고, Stage 5에서 매뉴얼 본문을 이 기준으로 통합하는 것이다.
- `v0.1.0`의 실제 공개 asset과 SHA256은 GitHub Release API에서 확인해 `mydocs/release/v0.1.0.md`에 기록했다.
- Team ID, signing identity 표시명, notary profile name은 `mydocs/tech/release_environment.md`로 분리했다. password, app-specific password, `.p8`, `.p12`, Sparkle EdDSA private key, GitHub token은 기록 금지 항목으로 명시했다.
- `troubleshootings/` 새 문서는 만들지 않았다. 현재 분리 대상은 release policy, release decision record, 환경 스냅샷 성격이 강하다. Gatekeeper/quarantine, appcast push 실패 같은 주제는 실제 실패 증상, 재현 조건, 원인, 예방 절차가 모였을 때 별도 troubleshooting 문서로 분리하는 기준만 남겼다.

## `release_distribution_guide.md` 분리 판단

Stage 5에서 본문 일반화 시 다음처럼 처리한다.

| 현재 매뉴얼 정보 | 판단 | 이동/유지 위치 |
|------------------|------|----------------|
| `v0.1.0 시점에 이미 결정` 표현 | 버전별 history 표현은 release 기록으로 분리, 현재도 유효한 naming policy만 매뉴얼에 유지 | `mydocs/release/v0.1.0.md` + 매뉴얼 일반화 |
| `v0.1.x public release는 devel-webview...` | 현재 release line 정책으로 매뉴얼에 유지 가능하되 특정 cycle history는 release 기록에 보조 기록 | 매뉴얼 유지 + `mydocs/release/v0.1.1.md` |
| Apple Developer Program 준비 날짜와 credential 확인 기록 | 환경 스냅샷 | `mydocs/tech/release_environment.md` |
| Team ID, signing identity, notary profile | 비밀은 아니지만 환경 의존 식별자 | `mydocs/tech/release_environment.md`; 매뉴얼은 env var/profile 참조 중심으로 일반화 |
| `v0.1 배포 수준 결정` 표 | 정책은 일반화해 매뉴얼 유지, `v0.1` 판단은 release decision record로 분리 | 매뉴얼 + `mydocs/release/v0.1.0.md` |
| `v0.1 artifact 구성 기준` | 산출물 계층 정책은 일반 release 기준으로 유지, 제목과 예시는 `<version>` 기반으로 일반화 | 매뉴얼 Stage 5 |
| `v0.1 렌더링 경로와 알려진 한계 공개 기준` | release note에 포함할 기준은 유지하되 `v0.1.x/current release line` 표현으로 정리 | 매뉴얼 Stage 5 + release 문서 |
| `0.1.0` 고정 명령 예시 | 버전 중립 예시로 일반화 | 매뉴얼 Stage 5 |
| Gatekeeper/quarantine 확인 항목 | 일반 설치 문제 triage checklist로 매뉴얼 유지 | troubleshooting 분리 보류 |
| Rollback에서 `mydocs/troubleshootings/` 기록 지시 | 실제 incident 발생 시 적용할 절차이므로 매뉴얼 유지 | 매뉴얼 유지 |

## Delta helper 한계

- path 기반 자동 분류라 의미 분석을 하지 않는다.
- `Sources/HostApp/Services/*`처럼 넓은 path는 viewer와 저장/공유 계열에 모두 걸릴 수 있다.
- `assets/`, `rust-toolchain.toml`처럼 release 영향이 있을 수 있지만 자동 분류가 어려운 파일은 `수동 분류 필요`로 남긴다.
- 문서 변경은 문서 전용 변경으로 분류하지만, release communication 문서가 실제 배포 smoke 항목을 바꾸는 경우 release owner가 별도 보정해야 한다.
- helper output은 release 승인 장치가 아니라 checklist 초안이다.

## 검증 결과

구현계획서 Stage 4 검증 명령을 수행했다.

```bash
git status --short --branch
```

결과:

```text
## local/task185
 M mydocs/manual/document_structure_guide.md
?? mydocs/release/
?? mydocs/tech/release_environment.md
?? mydocs/working/task_m018_185_stage4.md
?? scripts/ci/write-release-delta-checklist.sh
```

```bash
git log --oneline v0.1.0..HEAD
```

결과 요약:

- #183 PR #191 merge와 창 확대 runtime error 수정 commit 확인
- #199 PR #200 merge와 Finder thumbnail hang 수정 commit 확인
- #184 PR #201 merge와 DMG 설치 안내 개선 commit 확인
- #185 Stage 1~3.2 release communication 기준, template, Pages/README 변경 commit 확인

```bash
git diff --name-only v0.1.0..HEAD
```

결과 요약:

- HostApp viewer: `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- Quick Look/thumbnail/rendering: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`, `Sources/Shared/*`, `Sources/ThumbnailExtension/*`
- Release workflow/DMG: `.github/workflows/release-publish.yml`, `scripts/release.sh`, `scripts/create-dmg-background.swift`, `scripts/ci/import-developer-id-certificate.sh`
- Release communication: `docs/updates/index.html`, `docs/updates/v0.1.1.html`, `scripts/ci/write-release-notes.sh`, `scripts/ci/check-release-notes-template.sh`
- 문서: README, `mydocs/` 작업 문서와 보고서

```bash
rg -n "release/|릴리즈|v0\\.1\\.0|v0\\.1\\.1|검증|provenance|GitHub Release|Pages|appcast|release_environment|troubleshootings" mydocs/release mydocs/tech mydocs/manual/document_structure_guide.md
```

결과 요약:

- `document_structure_guide.md`에 `release/`, release environment, troubleshooting 분리 기준이 반영됨
- `mydocs/release/index.md`에 GitHub Release, Pages, appcast, README, release 기록, troubleshooting의 정보 소유 경계가 반영됨
- `mydocs/release/v0.1.0.md`에 실제 `v0.1.0` GitHub Release, Pages, SHA256, provenance, 후속 patch 입력이 기록됨
- `mydocs/release/v0.1.1.md`에 `v0.1.1` 후보 변경점, 연결 Issue/PR, #188 smoke, provenance, release communication checklist가 기록됨
- `mydocs/tech/release_environment.md`에 release environment 식별자와 기록 금지 항목이 반영됨

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

delta helper 검증:

```bash
bash -n scripts/ci/write-release-delta-checklist.sh
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
rg -n "HostApp|Quick Look|Thumbnail|Sparkle|DMG|Homebrew|문서" build.noindex/release/delta-checklist-0.1.1.md
```

결과 요약:

- shell syntax 통과
- `build.noindex/release/delta-checklist-0.1.1.md` 생성 성공
- HostApp viewer, Quick Look preview, Finder thumbnail, Sparkle/appcast/Pages, DMG/signing/notarization, Homebrew Cask, 문서 전용 변경 section 확인
- `Homebrew Cask`는 현재 범위에서 변경 없음으로 표시
- `assets/alhanguel_readme.png`, `rust-toolchain.toml`은 `수동 분류 필요`로 표시

## 잔여 위험

- `v0.1.1` 문서는 public release 전 후보 초안이다. 실제 DMG SHA256, appcast EdDSA signature, Homebrew Cask SHA256, GitHub Release body는 #188에서 확정해야 한다.
- `release_distribution_guide.md`에는 아직 `v0.1`, `0.1.0`, 환경 식별자, 고정 예시가 남아 있다. Stage 5에서 이번 단계의 분리 기준을 적용해 매뉴얼을 일반화해야 한다.
- delta helper는 path 기반 초안 생성기다. release owner 보정 없이 release 승인 기준으로 쓰면 안 된다.
- `mydocs/release/v0.1.0.md`의 public asset 정보는 GitHub Release API 기준이다. asset이 나중에 교체되면 GitHub Release와 이 문서를 함께 갱신해야 한다.

## 다음 단계 영향

Stage 5에서는 `release_distribution_guide.md`를 이번 단계 기준에 맞춰 정리한다. 구체적으로는 고정 `0.1.0` 명령 예시를 `<version>`으로 일반화하고, 환경 식별자는 `release_environment.md`로 링크하며, release detail 문서와 delta checklist를 GitHub Release/Pages/appcast 확인 절차에 통합한다.

Stage 5 최종 보고서에는 #188에서 실제로 반복할 public URL, public DMG SHA256, appcast, Cask, smoke handoff를 묶어 넘긴다.

## 승인 요청

Stage 4 산출물 승인을 요청한다.

승인 후 Stage 5 `매뉴얼 통합, 최종 dry-run, #188 handoff 정리`로 진행한다.
