# Task #148 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#148 v0.1 서명·공증 배포 수준 결정](https://github.com/postmelee/alhangeul-macos/issues/148) |
| 마일스톤 | M016 / v0.1 출시 전 보강 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task148` |
| 단계 수 | 5단계 |
| 결론 | v0.1 public release 기본 배포 수준은 `Developer ID signed + notarized DMG`로 확정했다. 개발용 zip과 rehearsal DMG는 public 배포 기준에서 제외하고, Homebrew Cask는 public DMG 업로드와 sha256 고정 이후 후속 배포 경로로 분리했다. |

## 배포 수준 결정

| 배포 수준 | v0.1 판단 | 사용 범위 |
|-----------|-----------|-----------|
| unsigned app/DMG | public 배포 기준 아님 | 제한적 개발 확인 |
| ad-hoc signed app/DMG | public 배포 기준 아님 | CI/로컬 bundle 구조 확인 |
| Developer ID signed, not notarized | public 배포 기준 아님 | notarization 실패 원인 분리 시 임시 확인 |
| Developer ID signed + notarized DMG | v0.1 public 기본값 | GitHub Release asset, 사용자 배포, Homebrew Cask 기준 산출물 |
| Mac App Store | v0.1 범위 밖 | 후속 배포 lane |

public 사용자가 받는 artifact는 `scripts/release.sh <version>` public mode로 생성한 `alhangeul-macos-<version>.dmg`와 `.sha256`이다. `--skip-notarize` rehearsal DMG와 개발용 zip은 GitHub Release public asset 또는 Homebrew Cask URL에 사용하지 않는다.

## 산출물 경계

| 산출물 | 용도 | public 사용 |
|--------|------|-------------|
| `build.noindex/release/Alhangeul.app` | Release configuration bundle 구성과 설치본 smoke 입력 | 아니오 |
| `alhangeul-macos-<version>.zip` | 개발/검증용 zip | 아니오 |
| `alhangeul-macos-<version>-rehearsal.dmg` | DMG layout/checksum/release script path rehearsal | 아니오 |
| `alhangeul-macos-<version>.dmg` | GitHub Release asset, 사용자 배포, Cask digest 기준 | 예 |

## 변경 파일

| 파일 | 내용 |
|------|------|
| `README.md` | Release / Install 섹션에 v0.1 notarized DMG 기준과 `Alhangeul.app` 최초 실행 안내 반영 |
| `mydocs/manual/release_distribution_guide.md` | v0.1 배포 수준 결정, 사용자 설치 안내 기준, Cask sha256 갱신과 tap 검증 기준 보강 |
| `scripts/update-cask-sha256.sh` | public DMG `.sha256`에서 Cask version/sha256을 갱신하는 guard script 추가 |
| `mydocs/orders/20260505.md` | 기존 #148 이력을 M016 섹션으로 보정 |
| `mydocs/orders/20260508.md` | #148 진행/완료 상태 기록 |
| `mydocs/plans/task_m016_148.md` | M016 기준 수행계획서 |
| `mydocs/plans/task_m016_148_impl.md` | M016 기준 구현계획서 |
| `mydocs/working/task_m016_148_stage1.md` | 배포 자산과 credential 준비 상태 점검 보고 |
| `mydocs/working/task_m016_148_stage2.md` | v0.1 배포 수준과 사용자 안내 기준 보고 |
| `mydocs/working/task_m016_148_stage3.md` | Homebrew Cask와 release 준비 자동화 보강 보고 |
| `mydocs/working/task_m016_148_stage4.md` | M016 문서명과 현재 앱명 정합화 보고 |
| `mydocs/working/task_m016_148_stage5.md` | 최종 검증 보고 |
| `mydocs/report/task_m016_148_report.md` | 최종 보고서 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획/Stage 1-3 | 기존 `local/task148` 커밋 | release pipeline, credential, 배포 수준, Cask guard를 먼저 정리했으나 M010 문서명으로 남아 있었다. |
| 최신화 | `911aee1` | `origin/devel-webview`를 merge하고 #145/#147/#150/#167 결과와 충돌을 해소했다. |
| Stage 4 | `f98aa60` | `task_m010_148*` 문서를 `task_m016_148*`로 보정하고 README/release guide의 `Alhangeul.app` 기준을 맞췄다. |
| Stage 5 | 이번 최종 보고 커밋 | 최종 검증, Stage 5 보고서, 최종 보고서, 오늘할일 완료 처리를 정리한다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `bash -n scripts/release.sh scripts/package-release.sh scripts/update-cask-sha256.sh` | OK | shell syntax 통과 |
| `./scripts/release.sh --help` | OK | public release env와 `--skip-notarize` 확인 |
| `./scripts/update-cask-sha256.sh --help` | OK | Cask sha256 갱신 usage 확인 |
| Cask public checksum dry-run | OK | mock public DMG checksum으로 Cask 수정 없이 검증 |
| Cask rehearsal checksum negative | OK | `*-rehearsal.dmg.sha256` 거부 확인 |
| stale public-doc reference scan | OK | README/release guide/update script 대상 `AlhangeulMac`, `/private/tmp/rhwp-mac-task148` 출력 없음 |
| policy keyword scan | OK | Developer ID, notarization, rehearsal, Homebrew Cask, sha256 기준 확인 |
| `git diff --check` | OK | whitespace 오류 없음 |

## 미실행 범위

- public DMG 생성
- Apple notarization submission
- Git tag 생성
- GitHub Release 생성 또는 asset upload
- Homebrew tap 생성, push, PR
- App Store Connect 제출
- signing credential export 또는 secret 저장

## 잔여 위험과 후속 작업

| 구분 | 내용 |
|------|------|
| 실제 notarization | Apple notarization server 판정은 실제 public release 실행 시점에 확정된다. |
| Cask sha256 | public DMG가 아직 없으므로 `Casks/alhangeul-macos.rb`의 `sha256 :no_check`는 유지한다. |
| Homebrew tap | tap 대상은 아직 확정하지 않았다. 실제 release 작업에서 선택해야 한다. |
| #151 | 설치본 smoke gate는 개발용 zip/rehearsal/public DMG 기준을 혼동하지 않도록 구성해야 한다. |
| #146 | known limitations 문서는 public artifact가 signed/notarized DMG라는 전제로 설치 안내와 한계를 정리해야 한다. |

## 완료 판단

#148의 수용 기준은 충족했다.

- 선택한 배포 수준과 사용자 설치 안내가 README 또는 release note 기준 문서에 반영됐다.
- codesign/notarization/Gatekeeper 검증 명령과 결과 해석 기준이 release guide에 정리됐다.
- 공증은 v0.1 public 기본값으로 삼고, 실제 submission은 release 실행 승인 시점으로 분리했다.
- Homebrew Cask와 App Store는 이번 task의 실제 배포 실행 범위에서 제외하고 후속 경로로 분리했다.

## 작업지시자 승인 요청

Task #148의 v0.1 서명·공증 배포 수준 결정을 완료했다. 다음 단계는 `publish/task148` 브랜치 push와 `devel-webview` 대상 PR 생성 승인이다.
