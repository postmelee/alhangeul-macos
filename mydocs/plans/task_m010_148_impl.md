# Task #148 구현 계획서

본 문서는 [`task_m010_148.md`](task_m010_148.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/private/tmp/rhwp-mac-task148`
- **Branch**: `local/task148`
- **기준 브랜치**: `devel-webview`
- **기준 이슈**: [#148](https://github.com/postmelee/alhangeul-macos/issues/148)
- **범위**: v0.1 Developer ID signed/notarized DMG 배포 수준 결정, Homebrew Cask 배포 준비, App Store 후속 경로 분리, 배포 자동화와 안내 템플릿화 점검

## 작업지시자 입력이 필요한 지점

다음 정보는 단계 진행 중 필요 시 확인한다. Stage 1은 추가 입력 없이 진행 가능하다.

- Homebrew 배포 대상: 별도 tap 저장소(`postmelee/homebrew-*`)를 만들지, 이 저장소의 `Casks/`를 운영 초안으로 유지할지, 장기적으로 `Homebrew/homebrew-cask` 제출까지 목표로 둘지 확인한다.
- 실제 public release 실행 시점: `./scripts/release.sh <version>` public mode, GitHub Release 게시, Homebrew tap 반영은 별도 명시 승인 후에만 실행한다.
- 릴리스 버전: 문서와 스크립트 검증은 현재 `0.1.0` 기준으로 맞추되, 실제 게시 전 최종 버전을 다시 확인한다.
- App Store 배포 방향: 이번 타스크에서는 실제 제출하지 않고, 후속 이슈 후보와 준비 체크리스트까지만 정리한다.

## Stage 1 — 현재 배포 자산과 credential 준비 상태 점검

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/release_distribution_guide.md` | 현행 release 절차, GitHub Release, Homebrew Cask, checklist 구조 점검 | 필요 변경은 Stage 2 이후 |
| `scripts/release.sh` | public/rehearsal mode, signing/notarization/staple/Gatekeeper/checksum 흐름 확인 | 원칙적으로 조사 단계 |
| `scripts/package-release.sh` | 개발용 zip package와 public DMG 책임 분리 확인 | 원칙적으로 조사 단계 |
| `Casks/alhangeul-macos.rb` | version, URL, sha256, caveats, app stanza 확인 | Stage 3 수정 후보 |
| `project.yml`, `Sources/**/Info.plist` | bundle id, version, signing/runtime 관련 release 영향 확인 | 변경 필요 여부만 판단 |

### 확인 기준

- `scripts/release.sh`가 Developer ID signed/notarized DMG를 만들 수 있는 구조인지 확인한다.
- 현재 Apple Developer Program 준비 상태 문서와 실제 로컬 credential 확인 명령 결과가 모순되지 않는지 확인한다.
- `sha256 :no_check`가 public 배포 전 임시값이라는 점이 문서와 Cask 운용 기준에 명확한지 확인한다.
- Homebrew 배포에 필요한 gap을 `Cask 값`, `GitHub Release asset`, `tap 운영`, `사용자 안내`로 분류한다.
- App Store 배포가 DMG/Homebrew와 다른 signing/export/review lane임을 후속 범위로 분리한다.

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task148
rg --line-number 'Developer ID|notarytool|notarization|공증|Homebrew Cask|GitHub Release|sha256|App Store|rehearsal' \
  README.md mydocs/manual/release_distribution_guide.md scripts/release.sh Casks/alhangeul-macos.rb
./scripts/release.sh --help
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile "alhangeul-notary"
git diff --check
```

### 커밋

```
Task #148 Stage 1: 배포 자산과 credential 준비 상태 점검
```

## Stage 2 — v0.1 배포 수준과 사용자 안내 기준 확정

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/release_distribution_guide.md` | v0.1 배포 수준을 Developer ID signed + notarized DMG 기준으로 정리 | unsigned/ad-hoc은 비교와 제외 사유 중심 |
| `mydocs/manual/release_distribution_guide.md` | Gatekeeper, quarantine, extension registration, checksum 안내 기준 보강 | 사용자 안내 템플릿의 근거 |
| `README.md` | 공개 사용자용 설치 안내 링크 또는 최소 문구 보정 | secret/운영 상세 복제 금지 |

### 반영할 판단

- Apple Developer 유료 계정과 Developer ID/notarytool 준비가 있으므로 v0.1 public DMG는 notarized artifact를 목표로 둔다.
- ad-hoc/unsigned artifact는 내부 rehearsal 또는 제한 검증용으로만 설명하고, 일반 사용자 배포 기준으로 두지 않는다.
- `--skip-notarize` rehearsal DMG는 GitHub Release, Homebrew Cask, public checksum 기준으로 사용하지 않는다.
- 사용자가 처음 설치한 뒤 앱을 한 번 실행해야 Quick Look/Thumbnail extension 등록이 안정화된다는 안내를 유지한다.

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task148
rg --line-number 'unsigned|ad-hoc|Developer ID|notarized|Gatekeeper|quarantine|Quick Look|Thumbnail|rehearsal' \
  README.md mydocs/manual/release_distribution_guide.md
git diff --check
```

### 커밋

```
Task #148 Stage 2: v0.1 배포 수준과 사용자 안내 기준 확정
```

## Stage 3 — Homebrew Cask와 release 준비 자동화 보강

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Casks/alhangeul-macos.rb` | public DMG 기준 version/url/sha256/caveats/app stanza 보정 | 실제 sha256은 public DMG 생성 후 확정 |
| `mydocs/manual/release_distribution_guide.md` | Homebrew tap 운영 방식, Cask 갱신 순서, audit/style 명령 정리 | tap 대상은 작업지시자 확인 필요 |
| `scripts/release.sh` 또는 신규 보조 스크립트 | release 준비 자동화 gap 보강 검토 | 과도한 게시 자동화는 제외 |
| `README.md` | brew 설치 안내가 확정 가능한 경우 최소 안내 반영 | 확정 전에는 release guide 링크 중심 |

### 자동화 후보

- public DMG `.sha256` 파일에서 Cask `sha256` 값을 갱신하는 보조 스크립트
- plist 버전, Cask version, Git tag 입력값 정합성 검사
- public DMG와 rehearsal DMG 혼동 방지 검사
- GitHub Release 게시 전 checklist 출력

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task148
bash -n scripts/release.sh scripts/package-release.sh
./scripts/release.sh --help
rg --line-number 'sha256 :no_check|Homebrew|Cask|brew install|tap|audit|style|alhangeul-macos-.*dmg' \
  README.md mydocs/manual/release_distribution_guide.md Casks/alhangeul-macos.rb scripts
git diff --check
```

Homebrew가 로컬에 있으면 다음 중 가능한 명령을 추가로 실행한다.

```bash
brew style --cask Casks/alhangeul-macos.rb
brew audit --cask --new Casks/alhangeul-macos.rb
```

### 커밋

```
Task #148 Stage 3: Homebrew Cask와 release 준비 자동화 보강
```

## Stage 4 — 배포 안내 문서 템플릿화와 App Store 후속 경로 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/release_distribution_guide.md` | release note, 설치 안내, checksum 검증, rollback 안내 템플릿 추가 | 운영 진실 원천 |
| `mydocs/manual/release_distribution_guide.md` 또는 신규 템플릿 문서 | App Store 후속 체크리스트 정리 | 실제 제출 절차 아님 |
| `README.md` | 사용자용 설치·검증 안내가 필요한 경우 간결하게 보정 | 상세 운영 절차는 manual 링크 |

### 템플릿 범위

- GitHub Release note 템플릿
- DMG 설치 안내 템플릿
- Homebrew 설치 안내 템플릿
- checksum/Gatekeeper/Quick Look 등록 확인 템플릿
- rollback/known limitations 템플릿
- App Store 후속 준비 체크리스트: bundle id, sandbox/entitlement, archive/export, App Store Connect metadata, review 대응, privacy 문서

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task148
rg --line-number '템플릿|Release note|설치 안내|checksum|Gatekeeper|rollback|App Store|App Store Connect|privacy|entitlement' \
  README.md mydocs/manual/release_distribution_guide.md mydocs
git diff --check
```

### 커밋

```
Task #148 Stage 4: 배포 안내 템플릿과 App Store 후속 경로 정리
```

## Stage 5 — 최종 검증과 보고서 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m010_148_stage{N}.md` | 각 단계 완료 보고서 작성 | 단계별 승인 후 진행 |
| `mydocs/report/task_m010_148_report.md` | 최종 결과 보고서 작성 | 모든 단계 완료 후 |
| `mydocs/orders/20260505.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
cd /private/tmp/rhwp-mac-task148
bash -n scripts/release.sh scripts/package-release.sh
./scripts/release.sh --help
rg --line-number 'Developer ID|notarytool|notarization|공증|Homebrew Cask|GitHub Release|sha256|App Store|템플릿' \
  README.md mydocs/manual/release_distribution_guide.md scripts Casks
git diff --check
git status --short --branch
```

가능하고 별도 승인이 있으면 다음 rehearsal 검증을 수행한다.

```bash
./scripts/release.sh --skip-notarize 0.1.0
```

### 실제 실행 제외 확인

다음 작업은 이 구현계획 승인만으로 실행하지 않는다. 단계 중 작업지시자에게 별도 확인한다.

- `./scripts/release.sh <version>` public mode 실행과 notarization submission
- Git tag 생성
- GitHub Release 생성과 asset upload
- Homebrew tap push 또는 `Homebrew/homebrew-cask` PR 생성
- App Store Connect 제출
- secret 파일 생성, export, 커밋

### 커밋

```
Task #148 Stage 5 + 최종 보고서: 배포 수준 결정과 안내 정리 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다.
