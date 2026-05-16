# Task #148 Stage 5 완료 보고서: 최종 검증과 보고서 정리

## 단계 목적

#148의 최종 검증을 수행하고, v0.1 서명·공증 배포 수준 결정 결과를 최종 보고서로 정리했다. 실제 public release, notarization submission, GitHub Release 게시, Homebrew tap 반영은 실행하지 않았다.

## 최종 결정

v0.1 public release의 기본 배포 수준은 `Developer ID signed + notarized DMG`로 둔다.

| 산출물 | public 사용 | 기준 |
|--------|-------------|------|
| 개발용 zip | 아니오 | Release configuration bundle 구성과 설치본 smoke 입력 |
| `--skip-notarize` rehearsal DMG | 아니오 | DMG layout/checksum/release script path 확인 |
| public DMG | 예 | `scripts/release.sh <version>` public mode로 생성, Developer ID signing/notarization/staple/Gatekeeper/sha256 검증 |
| Homebrew Cask | 후속 | public DMG 업로드와 sha256 고정 후 같은 DMG를 참조 |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `bash -n scripts/release.sh scripts/package-release.sh scripts/update-cask-sha256.sh` | OK | shell syntax 통과 |
| `./scripts/release.sh --help` | OK | public release env와 rehearsal option 확인 |
| `./scripts/update-cask-sha256.sh --help` | OK | Cask sha256 갱신 usage 확인 |
| public checksum dry-run | OK | `sha256` 64자 mock 입력, Cask 수정 없음 |
| rehearsal checksum negative | OK | `*-rehearsal.dmg.sha256` 입력 거부 |
| stale public-doc reference scan | OK | README/release guide/update script 대상 `AlhangeulMac`, `/private/tmp/rhwp-mac-task148` 출력 없음 |
| policy keyword scan | OK | Developer ID, notarization, rehearsal, Homebrew Cask, sha256 기준 확인 |
| `git diff --check` | OK | whitespace 오류 없음 |

public checksum dry-run:

```text
Cask: Casks/alhangeul-macos.rb
Version: 0.1.0
SHA256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Dry run: no files changed.
```

rehearsal checksum negative:

```text
ERROR: refusing to update Homebrew Cask from rehearsal checksum: alhangeul-macos-0.1.0-rehearsal.dmg.sha256
```

## 변경 파일

| 파일 | 내용 |
|------|------|
| `mydocs/report/task_m016_148_report.md` | 최종 결과보고서 작성 |
| `mydocs/orders/20260508.md` | #148 완료 처리 |
| `mydocs/working/task_m016_148_stage5.md` | Stage 5 완료 보고서 작성 |

## 제외한 작업

- `./scripts/release.sh <version>` public mode 실행
- Apple notarization submission
- Git tag 생성
- GitHub Release 생성과 asset upload
- Homebrew tap 생성, push, PR
- App Store Connect 제출
- secret 생성·저장·export

## 후속 영향

- #151 설치본 smoke gate는 public 기준과 rehearsal/dev 기준을 분리해서 검증해야 한다.
- #146 known limitations 문서는 public artifact가 notarized DMG임을 전제로 사용자 안내를 작성해야 한다.
- 실제 release 작업에서는 public DMG 생성 후 `scripts/update-cask-sha256.sh`로 Cask digest를 고정해야 한다.

## 완료 판단

#148의 수용 기준을 충족했다.

- 선택한 배포 수준과 사용자 설치 안내가 README와 release guide에 반영됐다.
- codesign/notarization/Gatekeeper 검증 명령과 해석 기준이 release guide에 정리됐다.
- 공증을 미루지 않고 v0.1 public 기본값으로 삼되, 실제 submission은 release 실행 승인 시점으로 분리했다.
- Homebrew Cask와 App Store는 public DMG 결정의 후속 경로로 분리했다.
