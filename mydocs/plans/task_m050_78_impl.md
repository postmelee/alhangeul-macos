# Task #78 구현 계획서

본 문서는 [`task_m050_78.md`](task_m050_78.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/tmp/rhwp-mac-task78` (분리 worktree)
- **Branch**: `local/task78` (origin/devel 기준)
- **기준 이슈**: [#78](https://github.com/postmelee/alhangeul-macos/issues/78)
- **범위**: Apple Developer Program 기반 서명, 공증, DMG 배포 절차 문서 최신화

## Stage 1 — 현행 release 문서와 script 입력값 정합성 점검

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/release_distribution_guide.md` | 현행 credential 준비 상태, public mode, rehearsal mode, 검증 항목 구조 확인 | 변경은 Stage 2 이후 |
| `scripts/release.sh` | 환경변수, preflight, signing, notarization, staple, Gatekeeper 검증 흐름 확인 | 원칙적으로 변경 없음 |
| `README.md` | release packaging 안내가 manual로 충분히 연결되는지 확인 | 필요 시 Stage 4에서 보정 |

### 확인 기준

- 문서의 명령 예시가 `scripts/release.sh`의 실제 입력값과 어긋나지 않는지 확인한다.
- `ALHANGEUL_DEVELOPER_ID_APPLICATION`, `ALHANGEUL_NOTARY_PROFILE`, `ALHANGEUL_DEVELOPER_ID_DMG`, `ALHANGEUL_BUILD_ROOT` 설명을 script usage와 대조한다.
- Apple Developer Program credential 미준비 전제로 남은 문장을 찾아 Stage 2 수정 대상으로 분류한다.
- 비밀값이 문서에 들어가지 않아야 하는 위치와 기록 가능한 운영 값을 구분한다.

### 단계 검증

```bash
cd /tmp/rhwp-mac-task78
rg --line-number 'Apple Developer|Developer ID|notarytool|notarization|ALHANGEUL|공증|서명|credential|public mode|rehearsal' README.md mydocs/manual/release_distribution_guide.md scripts/release.sh
./scripts/release.sh --help
git diff --check
```

### 커밋

```
Task #78 Stage 1: release 문서와 script 입력값 정합성 점검
```

## Stage 2 — Apple Developer Program 준비 상태와 secret 관리 원칙 갱신

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/release_distribution_guide.md` | 현재 상태와 확정된 운영 값을 Apple Developer Program 가입 완료 기준으로 갱신 | Team ID, identity, profile name만 기록 |
| `mydocs/manual/release_distribution_guide.md` | 작업지시자가 직접 관리해야 하는 secret과 문서에 기록 가능한 값을 분리 | password, app-specific password, `.p8`, `.p12` 금지 |

### 반영할 비밀이 아닌 운영 값

- Team ID: `XH6JHKYXV8`
- Developer ID Application identity: `Developer ID Application: Taegyu Lee (XH6JHKYXV8)`
- notarytool keychain profile: `alhangeul-notary`

### 반영하지 않을 값

- Apple ID password
- app-specific password
- App Store Connect API private key (`.p8`)
- exported signing identity (`.p12`)와 password
- Keychain 내부 credential payload

### 단계 검증

```bash
cd /tmp/rhwp-mac-task78
rg --line-number 'XH6JHKYXV8|Developer ID Application: Taegyu Lee|alhangeul-notary|app-specific password|\\.p8|\\.p12|비밀|secret' mydocs/manual/release_distribution_guide.md
git diff --check
```

### 커밋

```
Task #78 Stage 2: Apple Developer 배포 credential 상태 문서화
```

## Stage 3 — public DMG 서명, 공증, 검증 절차 갱신

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/release_distribution_guide.md` | public DMG 생성 명령 예시를 실제 identity/profile 기준으로 갱신 | secret은 keychain profile 참조 |
| `mydocs/manual/release_distribution_guide.md` | Developer ID signing identity 확인, notarytool profile 확인, app/DMG 공증, staple, `spctl` 검증 순서 보강 | `scripts/release.sh` 수행 흐름과 일치 |
| `mydocs/manual/release_distribution_guide.md` | rehearsal DMG와 public DMG의 사용 금지/허용 경계를 재정리 | Cask/GitHub Release asset 혼동 방지 |

### 문서화할 명령 범위

- `security find-identity -v -p codesigning`
- `xcrun notarytool history --keychain-profile "alhangeul-notary"`
- `ALHANGEUL_DEVELOPER_ID_APPLICATION="Developer ID Application: Taegyu Lee (XH6JHKYXV8)" ALHANGEUL_NOTARY_PROFILE="alhangeul-notary" ./scripts/release.sh <version>`
- `codesign`, `xcrun stapler`, `spctl`, `shasum`은 script가 수행하는 검증 항목으로 설명

### 단계 검증

```bash
cd /tmp/rhwp-mac-task78
rg --line-number 'security find-identity|notarytool history|ALHANGEUL_DEVELOPER_ID_APPLICATION|ALHANGEUL_NOTARY_PROFILE|staple|spctl|Gatekeeper|rehearsal|Homebrew Cask' mydocs/manual/release_distribution_guide.md
bash -n scripts/release.sh scripts/package-release.sh
./scripts/release.sh --help
git diff --check
```

### 커밋

```
Task #78 Stage 3: public DMG 서명과 공증 절차 갱신
```

## Stage 4 — README 안내 보정과 문서 검증

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `README.md` | release packaging 섹션이 상세 배포 절차를 manual로 연결하는지 확인하고 필요 시 보정 | 상세 credential 절차는 README에 복제하지 않음 |
| `mydocs/manual/release_distribution_guide.md` | Stage 1~3 변경 후 중복, 모순, stale wording 최종 점검 | manual을 진실 원천으로 유지 |

### 단계 검증

```bash
cd /tmp/rhwp-mac-task78
rg --line-number 'release packaging|릴리스/배포|signed|notarized|공증|Developer ID|notarytool' README.md mydocs/manual/release_distribution_guide.md
rg --line-number 'credential 없이|credential이 없|Apple Developer Program credential이 없' mydocs/manual/release_distribution_guide.md
git diff --check
```

두 번째 `rg`는 남아도 되는 rehearsal 설명과 stale 표현을 구분하기 위한 확인용이다. Apple Developer Program 가입 전제를 계속 주장하는 문장이 있으면 Stage 4 안에서 보정한다.

### 커밋

```
Task #78 Stage 4: README 배포 안내와 문서 정합성 보정
```

## Stage 5 — 최종 검증과 보고서 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m050_78_stage{N}.md` | 각 단계 완료 보고서 작성 | 단계별 승인 후 진행 |
| `mydocs/report/task_m050_78_report.md` | 최종 결과 보고서 작성 | 모든 단계 완료 후 |
| `mydocs/orders/20260429.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
cd /tmp/rhwp-mac-task78
bash -n scripts/release.sh scripts/package-release.sh
./scripts/release.sh --help
rg --line-number 'Apple Developer|Developer ID|notarytool|notarization|ALHANGEUL|공증|서명|credential' README.md mydocs/manual/release_distribution_guide.md scripts/release.sh
git diff --check
git status --short --branch
```

### 실제 실행 제외 확인

이번 task에서는 다음을 실행하지 않는다.

- `./scripts/release.sh <version>` public mode 실행
- 공증 submit/wait
- GitHub Release 생성
- Homebrew Cask 배포 PR 생성
- 인증서 또는 secret 파일 생성/커밋

### 커밋

```
Task #78 Stage 5 + 최종 보고서: 배포 절차 문서 최신화 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다.
