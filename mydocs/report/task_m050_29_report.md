# Issue #29 최종 결과 보고서

## 목적

`rhwp-core.lock`을 v2 산출물 provenance lock으로 확장하고, Rust bridge/package 단계에서 lock 불일치를 조기에 차단하도록 개선했다.

## 최종 변경 요약

- `rhwp-core.lock` v2 형식 도입
- `Frameworks/universal/librhwp.a` sha256/size 기록
- `Frameworks/generated_rhwp.h` sha256/size 기록
- `scripts/build-rust-macos.sh`에 `--update-lock`, `--verify-lock` 추가
- `Vendor/rhwp` commit과 `rhwp-core.lock`의 `rhwp_commit` 검증 추가
- artifact metadata 누락/불일치 시 expected/actual 출력 추가
- `scripts/package-release.sh`가 package 전 lock verify를 수행하도록 변경
- package 산출물 경로를 `build.noindex/release`로 조정
- `Casks/alhangeul-macos.rb` app bundle 이름을 현재 산출물인 `AlhangeulMac.app`에 맞춤
- README와 manual 문서 갱신

## 최종 lock 상태

`rhwp-core.lock`:

- `lock_version`: `2`
- `rhwp_commit`: `1e9d78a1d40c71779d81c6ec6870cd301d912626`
- `built_at`: `2026-04-25T00:38:17Z`

Artifacts:

| path | sha256 | size |
|------|--------|------|
| `Frameworks/universal/librhwp.a` | `725b65ad445660292bb1a5f2a0f9107ff810e65a699ade78e0a3b26dd901dd50` | `102627384` |
| `Frameworks/generated_rhwp.h` | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` | `1349` |

## 검증 결과

통과:

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/package-release.sh 0.0.0-test
```

package smoke test 산출물:

- `build.noindex/release/alhangeul-macos-0.0.0-test.zip`
- sha256: `0ff5b4b3963f09106655de8bd62f7ceba07f00e1ffc2bc825b981bac03a89143`

## 참고 및 리스크

- `Rhwp.xcframework` directory 전체 hash는 이번 범위에서 제외했다. 현재는 deterministic file artifact인 static library와 generated header를 검증한다.
- `built_at`은 update 시점 기록이며 verify 비교 대상은 commit, artifact sha256, artifact size다.
- GitHub Issue #29의 GitHub milestone은 `v0.1.0`이지만, 인계 문서와 작업 문서 prefix는 `task_m050_29`로 진행되었다. 이번 작업에서는 기존 문서 흐름을 유지했다.
- 검증 중 CoreSimulatorService 관련 경고가 출력되었지만, macOS build/package 명령은 모두 성공했다.
- 최신 `devel` 병합 후 PR #41 이름 변경 기준을 재확인해 현재 운용 파일의 app/project/package/Cask 이름을 `AlhangeulMac`/`alhangeul-macos` 기준으로 보정했다.

## 완료 판단

완료 조건을 충족했다.

- Rust bridge 산출물 commit, sha256, size가 lock에 기록된다.
- lock 불일치 시 build/package 단계에서 실패할 수 있다.
- package 전 lock verify가 수행된다.
- lock update/verify 사용법이 README와 manual 문서에 반영되었다.

## 승인 요청

이 최종 결과 보고서 기준으로 PR 생성 절차를 진행할지 승인 요청한다.
