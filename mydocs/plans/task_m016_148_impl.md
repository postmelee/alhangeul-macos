# Task #148 구현 계획서

본 문서는 [`task_m016_148.md`](task_m016_148.md) 수행계획서를 단계별 실행 단위로 정리한다. 기존 `local/task148` 브랜치에는 Stage 1-3 커밋이 남아 있었고, 2026-05-08에 최신 `devel-webview`를 merge한 뒤 M016 문서명과 현재 release 기준에 맞게 보정한다.

## 작업 환경

- **Worktree**: `/Users/melee/Documents/projects/rhwp-mac`
- **Branch**: `local/task148`
- **기준 브랜치**: `devel-webview`
- **기준 이슈**: [#148](https://github.com/postmelee/alhangeul-macos/issues/148)
- **마일스톤**: M016 / v0.1 출시 전 보강
- **범위**: v0.1 Developer ID signed/notarized DMG 배포 수준 결정, public/rehearsal/dev artifact 경계 정리, Cask checksum 준비 guard, README/release guide 정합화

## 작업지시자 입력이 필요한 지점

Stage 4는 기존 산출물의 M016 보정이므로 추가 제품 판단 없이 진행한다. 다음 항목은 Stage 5 또는 실제 release 작업에서 별도 확인한다.

- 실제 public release 실행 여부: `./scripts/release.sh <version>` public mode와 notarization submission
- GitHub Release 게시와 asset upload 시점
- Homebrew tap 대상: 이 저장소 `Casks/` 초안 유지, 별도 tap, 또는 장기 `Homebrew/homebrew-cask` 제출 중 선택
- 릴리스 버전: 문서와 검증은 현재 `0.1.0` 기준이나 실제 게시 전 최종 확인 필요
- App Store 배포 여부: 이번 타스크에서는 실제 제출 준비를 하지 않고 후속 lane으로 남김

## Stage 1 — 현재 배포 자산과 credential 준비 상태 점검

### 상태

완료. 기존 `local/task148`의 `Task #148 Stage 1: 배포 자산과 credential 준비 상태 점검` 커밋을 M016 문서명으로 이관한다.

### 확인 기준

- `scripts/release.sh`가 Developer ID signed/notarized DMG를 만들 수 있는 구조인지 확인
- Apple Developer Program 준비 상태 문서와 로컬 credential 확인 명령 결과 대조
- `sha256 :no_check`가 public 배포 전 placeholder임을 확인
- Homebrew 배포 gap을 Cask 값, GitHub Release asset, tap 운영, 사용자 안내로 분류

### 검증 명령

```bash
rg --line-number 'Developer ID|notarytool|notarization|공증|Homebrew Cask|GitHub Release|sha256|App Store|rehearsal' \
  README.md mydocs/manual/release_distribution_guide.md scripts/release.sh Casks/alhangeul-macos.rb
./scripts/release.sh --help
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile "alhangeul-notary"
git diff --check
```

## Stage 2 — v0.1 배포 수준과 사용자 안내 기준 확정

### 상태

완료. 기존 `Task #148 Stage 2: v0.1 배포 수준과 사용자 안내 기준 확정` 커밋을 유지하되, Stage 4에서 현재 `Alhangeul.app` 산출물명으로 보정한다.

### 반영할 판단

- Apple Developer 유료 계정과 Developer ID/notarytool 준비가 있으므로 v0.1 public DMG는 notarized artifact를 목표로 둔다.
- ad-hoc/unsigned artifact는 내부 rehearsal 또는 제한 검증용으로만 설명하고 일반 사용자 배포 기준으로 두지 않는다.
- `--skip-notarize` rehearsal DMG는 GitHub Release, Homebrew Cask, public checksum 기준으로 사용하지 않는다.
- 사용자가 설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail extension 등록이 안정화된다는 안내를 유지한다.

### 검증 명령

```bash
rg --line-number 'unsigned|ad-hoc|Developer ID|notarized|Gatekeeper|quarantine|Quick Look|Thumbnail|rehearsal' \
  README.md mydocs/manual/release_distribution_guide.md
git diff --check
```

## Stage 3 — Homebrew Cask와 release 준비 자동화 보강

### 상태

완료. 기존 `Task #148 Stage 3: Homebrew Cask와 release 준비 자동화 보강` 커밋을 유지한다. 단, 현재 #148 이슈 범위에 맞춰 Homebrew 배포 실행이 아니라 public DMG checksum을 Cask에 안전하게 반영하기 위한 준비 guard로 해석한다.

### 산출물

- `scripts/update-cask-sha256.sh`
- `mydocs/manual/release_distribution_guide.md`의 Cask sha256 갱신과 tap 검증 기준

### 검증 명령

```bash
bash -n scripts/release.sh scripts/package-release.sh scripts/update-cask-sha256.sh
./scripts/release.sh --help
./scripts/update-cask-sha256.sh --help
rg --line-number 'sha256 :no_check|Homebrew|Cask|brew install|tap|audit|style|alhangeul-macos-.*dmg' \
  README.md mydocs/manual/release_distribution_guide.md Casks/alhangeul-macos.rb scripts
git diff --check
```

Homebrew tap 검증은 tap 대상이 확정된 뒤 cask token 기준으로 수행한다.

## Stage 4 — M016 기준 정합화와 후속 범위 분리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/plans/task_m016_148.md` | 수행계획서를 M016 기준으로 재작성 | 기존 `task_m010_148.md` 이관 |
| `mydocs/plans/task_m016_148_impl.md` | 구현계획서를 현재 브랜치와 단계 상태에 맞게 재작성 | 기존 worktree 경로 제거 |
| `mydocs/working/task_m016_148_stage{1,2,3}.md` | 기존 단계 보고서의 파일명, 산출물명, 잔여 위험 보정 | 역사 보존, 현재 기준 명시 |
| `README.md` | 설치 안내의 `AlhangeulMac.app` 참조를 `Alhangeul.app`으로 수정 | 현재 bundle filesystem name |
| `mydocs/manual/release_distribution_guide.md` | 사용자 설치 안내의 `AlhangeulMac.app` 참조를 `Alhangeul.app`으로 수정 | #145 기준과 정합화 |
| `mydocs/orders/20260508.md` | 오늘 #148 진행 상태 추가 | todo 형식 적용 |
| `mydocs/working/task_m016_148_stage4.md` | Stage 4 완료 보고서 작성 | 다음 승인 요청 |

### 검증 명령

```bash
rg --line-number 'AlhangeulMac|/private/tmp/rhwp-mac-task148' \
  README.md mydocs/manual/release_distribution_guide.md scripts/update-cask-sha256.sh
rg --line-number 'Developer ID|notarized|rehearsal|Homebrew Cask|sha256|Gatekeeper' \
  README.md mydocs/manual/release_distribution_guide.md Casks scripts
git diff --check
```

### 커밋

```text
Task #148 Stage 4: M016 기준 배포 수준 문서 정합화
```

## Stage 5 — 최종 검증과 보고서 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/report/task_m016_148_report.md` | 최종 결과 보고서 작성 | v0.1 배포 수준 결정, 제외 범위, 후속 영향 |
| `mydocs/orders/20260508.md` | #148 상태 완료 처리 | 완료 시간 기록 |
| `mydocs/working/task_m016_148_stage5.md` | 최종 검증 보고 작성 | 필요 시 |

### 최종 검증

```bash
bash -n scripts/release.sh scripts/package-release.sh scripts/update-cask-sha256.sh
./scripts/release.sh --help
./scripts/update-cask-sha256.sh --help
rg --line-number 'Developer ID|notarytool|notarization|공증|Homebrew Cask|GitHub Release|sha256' \
  README.md mydocs/manual/release_distribution_guide.md scripts Casks
rg --line-number 'AlhangeulMac|/private/tmp/rhwp-mac-task148' \
  README.md mydocs/manual/release_distribution_guide.md scripts/update-cask-sha256.sh
git diff --check
git status --short --branch
```

가능하면 mock checksum으로 Cask update guard를 검증한다. 실제 public notarization, GitHub Release 게시, Homebrew tap 반영은 이 단계에서도 실행하지 않는다.

### 커밋

```text
Task #148 Stage 5 + 최종 보고서: 배포 수준 결정 완료
```

## 승인 요청 사항

Stage 4 완료 보고 후 Stage 5 최종 정리 진행 승인을 요청한다.
