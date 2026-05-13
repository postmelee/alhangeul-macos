# Task M019 #218 Stage 1 완료 보고서

## 단계 목적

`#188` `v0.1.1` public release 실행 중 발생한 workflow/signing/notarization/staticlib 실패 사례를 inventory로 정리하고, Stage 2 troubleshooting 문서의 구조와 제외 범위를 확정한다.

확인 시각: `2026-05-11 KST`

## 확인한 자료

| 자료 | 확인 내용 |
|------|-----------|
| `mydocs/working/task_m018_188_stage4.md` | `v0.1.1` public release workflow 실패 run, 실패 지점, 원인, 보정 내역 |
| `mydocs/report/task_m018_188_report.md` | 최종 public release build `4`, release workflow success, 잔여 위험 |
| `mydocs/manual/release_distribution_guide.md` | release 작업 진입점, troubleshooting 분리 기준, 전체 release flow |
| `mydocs/manual/release_signing_notarization_guide.md` | secret 기록 금지 원칙, signing/notarization 실패 시 분리 기준 |
| `.github/workflows/release-publish.yml` | `GH_TOKEN`, `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY`, `cbindgen`, certificate import, Sparkle appcast 관련 현재 workflow 경로 |
| `.github/workflows/release-rehearsal.yml`, `.github/workflows/pr-ci.yml` | `cbindgen` 설치와 staticlib hash skip 예외가 release/rehearsal/PR CI에 반영된 상태 |
| `scripts/ci/import-developer-id-certificate.sh` | Developer ID `.p12` import helper가 `security` 출력을 stderr로 보내고 keychain path만 stdout에 남기는 현재 구조 |
| `scripts/build-rust-macos.sh` | `cbindgen` 요구, `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY` 처리, FFI symbol/header 검증 유지 |
| `scripts/release.sh` | Sparkle nested component signing, app extension entitlement signing, notary status/log 출력 경로 |

## 문서화 대상 실패 사례

Stage 2 troubleshooting 문서는 아래 7개 사례를 같은 구조로 정리한다.

| 순서 | run | 실패 지점 | 문서화할 핵심 |
|------|-----|-----------|---------------|
| 1 | `25632437884` | upstream latest rhwp release 확인 | workflow에서 `GH_TOKEN`이 빠지면 `gh` 인증 기반 조회가 실패한다. release workflow에는 `GH_TOKEN: ${{ github.token }}`이 필요하다. |
| 2 | `25632495693` | Developer ID certificate import | helper stdout에 `security` 출력이 섞이면 `$GITHUB_OUTPUT` format 오류가 난다. GitHub Actions output으로 사용할 값만 stdout에 남기고 나머지는 stderr로 보내야 한다. |
| 3 | `25632545387` | rhwp lock verify | GitHub macOS runner에 `cbindgen`이 없으면 Rust bridge header generation/lock verify가 실패한다. release/rehearsal/PR CI에서 필요 시 `brew install cbindgen`을 수행한다. |
| 4 | `25632598126` | rhwp staticlib hash verify | CI runner/toolchain 차이로 `Frameworks/universal/librhwp.a` byte-for-byte hash/size가 lock과 달라질 수 있다. 당시에는 staticlib byte hash만 제한적으로 skip하고 source lock, Cargo lock, generated header, FFI symbol 검증은 유지했다. |
| 5 | `25632780594` | app notarization | notary status `Invalid` 뒤 상세 log 없이 stapling으로 진행하면 원인 진단이 어렵다. notary JSON status를 파싱하고 submission log를 출력해야 한다. |
| 6 | `25633064531` | app notarization | Sparkle nested XPC/Updater/Autoupdate가 ad-hoc signature 또는 timestamp 없는 상태이면 notarization에서 거부될 수 있다. nested component를 Developer ID/timestamp로 재서명해야 한다. |
| 7 | `25633267598` | app notarization | Quick Look/Thumbnail extension에 debug entitlement인 `get-task-allow`가 남거나 timestamp가 없으면 notarization에서 거부될 수 있다. 배포용 entitlements로 app extension을 재서명해야 한다. |

## Stage 2 문서 구조

신규 문서 파일명은 `mydocs/troubleshootings/release_v0_1_1_workflow_failures.md`로 둔다.

문서 구조:

1. 대상 release와 참조 자료
   - 이슈: `#188`, `#218`
   - 참조: `mydocs/working/task_m018_188_stage4.md`, `mydocs/report/task_m018_188_report.md`
   - 최종 public release 결과: `v0.1.1` build `4`, workflow `25645869039`
2. 전체 실패 흐름 요약 표
   - run, 실패 지점, 대표 증상, 적용된 보정
3. 사례별 진단 항목
   - 증상
   - 재현 조건
   - 원인
   - 수정
   - 예방책
4. 다음 release 전 checklist
   - workflow env/auth
   - certificate import output
   - `cbindgen` availability
   - staticlib hash skip 예외 사용 여부
   - notary log 출력
   - Sparkle nested signing
   - app extension release entitlement
5. 후속 이슈 연결
   - `#219`: signing/notarization preflight validator
   - `#220`: Rust staticlib hash 재현성 검증 정책
   - `#227`: Rust bridge staticlib artifact 검증 정책 재정의

## 민감 정보 제외 기준

문서에 기록하지 않는 값:

- Apple ID password
- app-specific password
- App Store Connect API private key
- exported signing identity `.p12` payload와 password
- Keychain credential payload
- Sparkle EdDSA private key
- GitHub token 값
- notarization credential 원문

문서화 가능한 값:

- workflow variable/secret 이름
- secret 값이 아닌 환경 변수 이름
- run 번호와 실패 step 이름
- public GitHub Actions run URL
- script/function 이름
- 비밀이 아닌 signing/notary 운영 식별자 위치(`release_environment.md` 참조)

## 제외 범위

다음 항목은 Stage 2 troubleshooting 문서에 주 사례로 넣지 않는다.

- `v0.1.1` build `2` 배포 후 확인된 Quick Look/Thumbnail extension render crash
  - 이유: release workflow 실패가 아니라 설치본 smoke 이후 발견된 제품 동작 문제다.
  - 관련 최종 조치는 `#188` Stage 6-9와 최종 보고서에 남아 있다.
- `v0.1.0` 또는 original `v0.1.1`에서 Sparkle 업데이트한 사용자의 Finder thumbnail cache 잔존
  - 이유: release workflow 실패가 아니라 업데이트 후 Finder cache/extension refresh UX 문제다.
  - 후속 이슈는 `#225`다.
- Homebrew tap 공개, `brew style`, `brew audit`, tap install smoke
  - 이유: `#209` 범위다.
- staticlib hash 장기 정책 확정
  - 이유: `#220`과 `#227` 범위다. 본 문서는 `#188` 당시의 제한적 예외와 검증 유지 범위만 설명한다.
- preflight validator 구현
  - 이유: `#219` 범위다.

## release manual 연결 위치

Stage 3에서 다음 위치에 짧은 링크를 추가하는 방향으로 정리한다.

- `release_distribution_guide.md`
  - 하위 매뉴얼 표 또는 `현재 release 자산` 근처에 release troubleshooting 문서 진입점을 추가한다.
  - Rollback의 “원인, 영향 범위, 재발 방지책을 `mydocs/troubleshootings/`에 기록한다” 기준과 연결한다.
- `release_signing_notarization_guide.md`
  - `실패 시 분리 기준`에 signing/notarization 실패 사례 문서 링크를 추가한다.
  - 사례 본문은 복제하지 않는다.

## 현재 코드 기준 대조

| 항목 | 현재 코드 위치 | Stage 2 문서 반영 방식 |
|------|----------------|------------------------|
| `GH_TOKEN` | `.github/workflows/release-publish.yml` env | release workflow에서 `gh` 사용 시 인증 env가 필요하다고 기록 |
| Developer ID import helper | `scripts/ci/import-developer-id-certificate.sh` | stdout은 keychain path만, `security` 출력은 stderr로 보내야 한다고 기록 |
| `cbindgen` | `scripts/build-rust-macos.sh`, workflow install step | runner에 없을 수 있으므로 workflow가 설치해야 한다고 기록 |
| staticlib skip | `scripts/build-rust-macos.sh`, workflow env | `librhwp.a` byte hash만 skip하고 header/symbol/source lock 검증은 유지한다고 기록 |
| notary log | `scripts/release.sh` `submit_for_notarization`, `print_notary_log` | invalid/not accepted 상태에서는 JSON과 notary log를 남겨야 한다고 기록 |
| Sparkle nested signing | `scripts/release.sh` `sign_sparkle_components_for_notarization` | nested XPC/Updater/Autoupdate를 Developer ID로 재서명한다고 기록 |
| app extension entitlements | `scripts/release.sh` `sign_app_extension_for_notarization` | Quick Look/Thumbnail appex를 배포용 entitlements로 재서명한다고 기록 |

## 검증 결과

```bash
rg -n "25632437884|25632495693|25632545387|25632598126|25632780594|25633064531|25633267598|GH_TOKEN|cbindgen|staticlib|Sparkle nested|get-task-allow" \
  mydocs/working/task_m018_188_stage4.md mydocs/report/task_m018_188_report.md
```

결과: Stage 4 보고서에서 7개 실패 run과 핵심 원인을 확인했다.

```bash
rg -n "troubleshooting|문제|notarization|Developer ID|Sparkle|staticlib" \
  mydocs/manual/release_distribution_guide.md mydocs/manual/release_signing_notarization_guide.md
```

결과: release distribution guide에는 troubleshooting 분리 기준과 rollback 기록 기준이 있고, signing/notarization guide에는 실패 시 분리 기준이 있다. Stage 3에서 짧은 링크를 추가할 위치가 확인됐다.

```bash
git diff --check -- mydocs/working/task_m019_218_stage1.md
```

결과: 통과.

## 변경 파일

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m019_218_stage1.md` | 실패 사례 inventory, Stage 2 문서 구조, 제외 범위, manual 연결 위치 확정 |

## 다음 단계

Stage 2에서는 `mydocs/troubleshootings/release_v0_1_1_workflow_failures.md`를 작성한다. release manual 연결은 Stage 3에서 수행한다.
