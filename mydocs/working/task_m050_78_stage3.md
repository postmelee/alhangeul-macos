# Task #78 Stage 3 완료 보고서

## 단계 목적

public DMG 생성, Developer ID signing identity 확인, `notarytool` profile 확인, 공증/staple/Gatekeeper 검증 절차를 실제 운영 값 기준으로 갱신한다.

## 산출물

- `mydocs/manual/release_distribution_guide.md`: public DMG 서명/공증 절차 갱신
- `mydocs/working/task_m050_78_stage3.md`: Stage 3 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

- public release credential 확인 명령을 추가했다.
- public DMG 생성 예시를 실제 signing identity와 keychain profile 기준으로 바꿨다.
- `ALHANGEUL_DEVELOPER_ID_DMG` 기본 동작을 설명했다.
- rehearsal DMG는 public release 검증을 대체하지 않는다고 명확히 했다.
- `codesign`, `stapler`, `spctl` 대표 확인 명령을 추가했다.
- 기존 GitHub Release, Homebrew Cask, rollback, release checklist 구조는 유지했다.

## 주요 변경

추가한 credential 확인 명령:

```bash
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile "alhangeul-notary"
```

갱신한 public release DMG 생성 예시:

```bash
ALHANGEUL_DEVELOPER_ID_APPLICATION="Developer ID Application: Taegyu Lee (XH6JHKYXV8)" \
ALHANGEUL_NOTARY_PROFILE="alhangeul-notary" \
./scripts/release.sh 0.1.0
```

대표 확인 명령:

```bash
codesign --verify --deep --strict --verbose=2 build.noindex/release/AlhangeulMac.app
xcrun stapler validate build.noindex/release/AlhangeulMac.app
xcrun stapler validate build.noindex/release/alhangeul-macos-0.1.0.dmg
spctl --assess --type execute --verbose build.noindex/release/AlhangeulMac.app
spctl --assess --type open --context context:primary-signature --verbose build.noindex/release/alhangeul-macos-0.1.0.dmg
```

## 검증 결과

구현 계획서의 Stage 3 검증 명령을 실행했다.

```bash
rg --line-number 'security find-identity|notarytool history|ALHANGEUL_DEVELOPER_ID_APPLICATION|ALHANGEUL_NOTARY_PROFILE|staple|spctl|Gatekeeper|rehearsal|Homebrew Cask' mydocs/manual/release_distribution_guide.md
```

결과:

- `security find-identity`와 `notarytool history` 확인 명령 노출 확인
- 실제 `ALHANGEUL_DEVELOPER_ID_APPLICATION`/`ALHANGEUL_NOTARY_PROFILE` 예시 확인
- `stapler`, `spctl`, Gatekeeper 검증 설명 확인
- rehearsal DMG와 Homebrew Cask/public release asset 경계 문구 확인

```bash
bash -n scripts/release.sh scripts/package-release.sh
```

결과: 통과

```bash
./scripts/release.sh --help
```

결과:

- public release environment로 `ALHANGEUL_DEVELOPER_ID_APPLICATION`, `ALHANGEUL_NOTARY_PROFILE`, `ALHANGEUL_DEVELOPER_ID_DMG`, `ALHANGEUL_BUILD_ROOT` 출력 확인
- script help의 generic placeholder 예시는 유지됨 확인

```bash
git diff --check
```

결과: 통과

## 잔여 위험

- 이번 단계는 문서와 shell syntax 검증만 수행했다. 실제 public mode release는 실행하지 않았다.
- `notarytool history` 실제 실행은 사용자 로컬에서 이미 성공 확인된 값을 문서화한 것이며, Stage 3 검증에서는 네트워크 제출/조회 없이 문서 정합성만 확인했다.
- public DMG `sha256`은 실제 signed/notarized DMG 생성 후에만 확정된다.

## 다음 단계 영향

Stage 4에서는 README의 release packaging 안내가 상세 credential 절차를 중복하지 않고 `release_distribution_guide.md`로 연결되는지 확인하고, 남아 있는 stale 표현을 보정한다.

## 승인 요청

Stage 4 진행 승인을 요청한다.
