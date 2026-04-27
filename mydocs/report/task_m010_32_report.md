# Issue #32 최종 결과 보고서

## 작업 요약

- GitHub Issue: #32
- 마일스톤: M010
- 작업 브랜치: `local/task32`
- 작업명: 서명·공증·DMG 포함 release pipeline 자동화
- 단계 수: 5개 단계 + 최종 보고

macOS 공개 배포용 release pipeline을 개발용 package 흐름과 분리했다. 기존 `scripts/package-release.sh`는 개발/검증용 zip package 역할로 유지하고, 신규 `scripts/release.sh`가 public DMG release pipeline을 담당하도록 정리했다. 현재 v0.1.0은 Demo/Preview release 목표이므로 Apple Developer Program credential 없이 가능한 rehearsal 검증과 credential fail-fast 검증까지 완료했다.

## 최종 변경 요약

- `scripts/release.sh`를 추가해 public release DMG 생성 경로를 마련했다.
- public mode에서 Developer ID signing identity, notarytool keychain profile, clean worktree를 preflight로 확인한다.
- app notarization, app staple, DMG signing, DMG notarization, DMG staple, Gatekeeper 검증 경로를 script에 포함했다.
- `--skip-notarize` rehearsal mode를 추가해 credential 없이 DMG layout과 checksum 생성까지 확인할 수 있게 했다.
- rehearsal 산출물은 `*-rehearsal.dmg`로 분리해 public release와 Homebrew Cask에 잘못 연결되지 않도록 했다.
- `scripts/package-release.sh`의 `rm -rf` 경로에 `${BUILD_DIR:?}` guard를 추가했다.
- release distribution guide와 README에 개발용 package, public DMG, rehearsal DMG의 역할 차이를 문서화했다.
- Homebrew Cask URL을 public DMG 산출물명 기준으로 보정했다.

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | 기존 package script, Cask, release guide, signing 설정 조사 |
| Stage 2 | release script CLI, public/rehearsal mode, credential preflight, 실패 정책 설계 |
| Stage 3 | 신규 `scripts/release.sh` 구현과 credential 없는 rehearsal 검증 |
| Stage 4 | release guide, README, Cask URL/sha256 운영 정책 보정 |
| Stage 5 | shell 정적 검증, Cask syntax, credential fail-fast, rehearsal DMG/checksum 검증 |

## 변경 파일과 영향 범위

배포 script:

- `scripts/release.sh`
- `scripts/package-release.sh`

사용자-facing/운영 문서:

- `README.md`
- `mydocs/manual/release_distribution_guide.md`
- `Casks/alhangeul-macos.rb`

하이퍼-워터폴 작업 문서:

- `mydocs/plans/task_m010_32.md`
- `mydocs/working/task_m010_32_stage1.md`
- `mydocs/working/task_m010_32_stage2.md`
- `mydocs/working/task_m010_32_stage3.md`
- `mydocs/working/task_m010_32_stage4.md`
- `mydocs/working/task_m010_32_stage5.md`
- `mydocs/report/task_m010_32_report.md`
- `mydocs/orders/20260426.md`

Swift source, Rust source, `project.yml`, bundle identifier, FFI ABI는 변경하지 않았다.

## 변경 전·후 정량 비교

`devel..local/task32` 누적 변경 기준:

```text
12 files changed, 1785 insertions(+), 22 deletions(-)
```

변경 유형:

- release script 1개 추가
- 기존 package script 안전 guard 보정
- Cask 1개 보정
- 사용자-facing/운영 문서 2개 보정
- 수행계획서 1개 작성
- 단계 보고서 5개 작성
- 최종 보고서 1개 작성
- 오늘할일 1개 갱신

## 검증 결과

Shell syntax:

```bash
bash -n scripts/release.sh scripts/package-release.sh scripts/build-rust-macos.sh scripts/check-no-appkit.sh
```

결과: 통과

Shellcheck:

```bash
shellcheck scripts/release.sh scripts/package-release.sh scripts/build-rust-macos.sh scripts/check-no-appkit.sh
```

결과: 통과

Cask syntax:

```bash
ruby -c Casks/alhangeul-macos.rb
```

결과: `Syntax OK`

Public mode credential fail-fast:

```bash
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.0
```

결과: build 전에 `ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release`로 실패

Rehearsal DMG:

```bash
./scripts/release.sh --skip-notarize 0.1.0
```

결과: sandbox 밖 실행에서 성공

Rehearsal checksum:

```bash
shasum -a 256 -c alhangeul-macos-0.1.0-rehearsal.dmg.sha256
```

결과: `alhangeul-macos-0.1.0-rehearsal.dmg: OK`

Bundle 구조:

```text
build.noindex/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
build.noindex/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
```

결과: 두 extension 포함 확인

Version:

```text
HostApp: 0.1.0
QLExtension: 0.1.0
ThumbnailExtension: 0.1.0
```

결과: 세 bundle version 일치

Whitespace:

```bash
git diff --check
```

결과: 통과

직접 언급 금지 용어 확인:

```bash
rg --line-number "<직접 언급 금지 용어>" README.md mydocs/manual/release_distribution_guide.md Casks/alhangeul-macos.rb scripts/release.sh scripts/package-release.sh mydocs/plans/task_m010_32.md mydocs/working/task_m010_32_stage*.md mydocs/report/task_m010_32_report.md
```

결과: 출력 없음

## 수용 기준 충족 여부

| 기준 | 결과 |
|------|------|
| 개발용 package script와 public release script 책임 분리 | OK |
| Rust bridge lock verify를 release 흐름에 포함 | OK |
| Release build와 DMG 생성 경로 제공 | OK |
| Developer ID signing/notarization/staple/Gatekeeper 경로 제공 | OK |
| credential 없는 환경에서 fail-fast/rehearsal 검증 가능 | OK |
| public 산출물과 rehearsal 산출물 파일명 분리 | OK |
| release guide, README, Cask 정책 보정 | OK |
| GitHub Release 생성 자동화 제외 | OK |
| Homebrew tap PR 자동화 제외 | OK |

## 잔여 위험과 후속 작업

- Apple Developer Program credential이 없어 public mode의 실제 Developer ID signing, app/DMG notarization, staple, Gatekeeper 검증은 실행하지 못했다.
- Cask의 `sha256 :no_check`는 public signed/notarized DMG가 생성된 뒤 실제 digest로 교체해야 한다.
- GitHub Release 생성 자동화, Homebrew tap PR 자동화, release note template 자동 생성, Finder smoke test report 자동 첨부는 후속 issue로 분리하는 편이 적합하다.
- 실제 credential 환경에서 embedded app extension signing이 안정적으로 처리되는지 별도 확인이 필요하다.

## 완료 판단

Issue #32의 목표인 signed release pipeline 준비, 개발용 package와 public release 흐름 분리, DMG 산출물 정책 정리, credential 없는 검증 경로 제공, release guide와 Cask 정책 보정을 완료했다.

## 승인 요청

이 최종 결과 보고서 기준으로 draft PR 리뷰와 merge 승인을 요청한다.
