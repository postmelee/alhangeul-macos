# Task M016 #147 Stage 2 보고서

## 단계 목적

Stage 1 inventory와 upstream `rhwp` 최신 release 확인 결과를 바탕으로 `THIRD_PARTY_LICENSES.md`, README, `FONTS.md`, `font_fallback_strategy.md`의 책임 경계를 확정한다. Stage 3-4에서 실제 문서 변경을 할 때 중복 고지를 줄이고, 현재 Alhangeul v0.1 artifact에 실제 포함된 third-party 범위와 upstream rhwp 자체 release asset을 분리할 수 있게 한다.

## 산출물

| 파일 | 라인 수 | 내용 |
|------|---------|------|
| `mydocs/working/task_m016_147_stage2.md` | 212 | license/attribution 문서 구조 설계와 Stage 3-4 변경안 |

## 본문 변경 정도 / 본문 무손실 여부

Stage 2는 설계 단계라 기존 사용자 문서와 resource 문서를 변경하지 않았다. `THIRD_PARTY_LICENSES.md`, `README.md`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`, `mydocs/tech/font_fallback_strategy.md`는 읽기만 했고, 실제 고지 문구 변경은 Stage 3-4로 남겼다.

## 검증 결과

### 브랜치 상태

```text
$ git status --short --branch
## local/task147
```

### 계획서 검증 명령

```text
$ rg -n "^#|^##|rhwp|rhwp-studio|font|license|proprietary|WOFF2" THIRD_PARTY_LICENSES.md README.md Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md mydocs/tech/font_fallback_strategy.md
```

현재 문서 상태 요약:

- `THIRD_PARTY_LICENSES.md`: `rhwp` MIT license만 고지하고, bundled `rhwp-studio`, WOFF2 font, `rhwp-core.lock`, `manifest.json` 연결은 없다.
- `README.md`: `rhwp-studio`와 `rhwp-core.lock`을 설명하지만, 하단 License 섹션은 `[MIT License](LICENSE)`만 연결한다.
- `FONTS.md`: Git 미포함 proprietary font와 Git 포함 오픈 라이선스 font 목록을 소유한다.
- `font_fallback_strategy.md`: native renderer fallback 정책과 WOFF2 34개 재사용 정책을 소유한다.

### upstream 최신 release 확인

2026-05-06 Stage 2 진행 중 GitHub CLI로 upstream `edwardkim/rhwp` release를 확인했다.

```text
$ gh release view v0.7.10 -R edwardkim/rhwp --json tagName,name,publishedAt,targetCommitish,body,url
tagName: v0.7.10
publishedAt: 2026-05-05T17:56:40Z
targetCommitish: main
url: https://github.com/edwardkim/rhwp/releases/tag/v0.7.10
```

annotated tag 해석:

```text
$ gh api repos/edwardkim/rhwp/git/ref/tags/v0.7.10
object.sha: 2a6f59f1f64958ace5181f04cdf40cf77fa709b5
object.type: tag

$ gh api repos/edwardkim/rhwp/git/tags/2a6f59f1f64958ace5181f04cdf40cf77fa709b5
object.sha: 62a458aa317e962cd3d0eec6096728c172d57110
object.type: commit
```

`v0.7.10` release note에서 앱 저장소 license/provenance 설계에 영향을 줄 수 있는 항목:

- `v0.7.9` 후속 patch cycle
- 외부 기여자 7명, PR 13건 cherry-pick
- CLI 바이너리 release asset 4개와 `SHA256SUMS.txt`
- native Skia 기반 `PageLayerTree` -> PNG export, `native-skia` feature gate
- AI/VLM 연동, `export-png` CLI, 한글 font fallback chain, `--font-path` 동적 font loading

`v0.7.10` release asset 확인:

```text
rhwp-v0.7.10-linux-x86_64.tar.gz
rhwp-v0.7.10-macos-aarch64.tar.gz
rhwp-v0.7.10-macos-x86_64.tar.gz
rhwp-v0.7.10-windows-x86_64.zip
SHA256SUMS.txt
```

판단: `v0.7.10`은 최신 upstream release로 확인되었지만 현재 Alhangeul 앱 저장소의 실제 pin은 `rhwp-core.lock`과 `rhwp-studio/manifest.json` 기준 `v0.7.9` / `0fb3e6758b8ad11d2f3c3849c83b914684e83863`이다. 따라서 #147의 license/provenance 고지는 현재 artifact 기준인 `v0.7.9`로 작성하고, `v0.7.10` CLI binary asset은 현재 Alhangeul artifact에 포함되지 않는 upstream release asset으로 분리한다.

### whitespace 검증

```text
$ git diff --check
통과
```

## 문서별 책임 경계

| 문서 | 책임 | Stage 3-4 변경 방향 |
|------|------|---------------------|
| `THIRD_PARTY_LICENSES.md` | release 사용자가 확인하는 third-party attribution 중심 문서 | `rhwp`, bundled `rhwp-studio`, Rust bridge generated artifact, bundled font, proprietary font 비포함 정책을 요약하고 상세 provenance 위치 연결 |
| `README.md` | 사용자와 배포 검토자가 license/provenance 문서로 이동하는 진입점 | 하단 License 또는 Notice 인근에 `LICENSE`, `THIRD_PARTY_LICENSES.md`, `rhwp-core.lock`, `manifest.json`, `FONTS.md` 연결 추가 |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | bundled font별 license/source 세부 목록의 진실 원천 | `LatinModernMath-Regular.woff2` 누락 보강, `HappinessSansVF.woff2` 표기 정확화, proprietary font 비포함 문구를 release artifact 기준으로 정리 |
| `mydocs/tech/font_fallback_strategy.md` | Swift native renderer의 fallback 정책 설명 | 사용자용 license 고지 위치를 `THIRD_PARTY_LICENSES.md`와 `FONTS.md`로 연결하고, 정책 설명은 유지 |
| `rhwp-core.lock` | core source와 Rust bridge artifact hash/size의 기계 판독 provenance | #147에서는 변경하지 않음 |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | bundled `rhwp-studio` 정적 asset snapshot provenance | #147에서는 변경하지 않음. 현재 `v0.7.9` 기준을 고지 문서에서 참조 |

## `THIRD_PARTY_LICENSES.md` 섹션 설계

Stage 3에서 다음 구조로 보강한다.

1. `# Third Party Licenses`
2. `## Scope`
   - 이 문서가 Alhangeul v0.1 app/release artifact에 포함되는 third-party code/assets 기준임을 명시한다.
   - upstream `rhwp` 자체 release asset과 Alhangeul bundle 포함 asset을 구분한다.
3. `## rhwp core`
   - repository: `https://github.com/edwardkim/rhwp`
   - license: MIT
   - current bundled pin: `v0.7.9`, commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863`
   - provenance: `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`
4. `## Rust bridge generated artifacts`
   - `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h`는 `rhwp` core와 앱 저장소 `RustBridge` build output임을 설명한다.
   - hash/size는 `rhwp-core.lock`을 기준으로 한다.
5. `## Bundled rhwp-studio static assets`
   - `Sources/HostApp/Resources/rhwp-studio`가 `edwardkim/rhwp` `rhwp-studio/dist`에서 복사된 정적 asset임을 설명한다.
   - `manifest.json`의 release tag, commit, entrypoint hash를 상세 provenance로 연결한다.
   - current artifact 기준은 `v0.7.9`; upstream latest `v0.7.10`은 이 작업에서 pin으로 사용하지 않는다고 명시할지 Stage 3에서 문구 강도를 결정한다.
6. `## Bundled fonts`
   - `Sources/HostApp/Resources/rhwp-studio/fonts`의 WOFF2 34개를 오픈 라이선스 font resource로 설명한다.
   - font별 license/source는 `FONTS.md`가 소유한다고 연결한다.
7. `## Proprietary fonts not bundled`
   - 한컴/HY/HCR/Microsoft proprietary font 파일은 저장소와 release artifact에 포함하지 않는다고 명시한다.
   - 문서 rendering은 bundled WOFF2와 macOS system font fallback을 사용한다고 설명한다.
8. `## Legal interpretation`
   - 이 문서는 attribution/provenance 정리이며 법률 자문이 아님을 짧게 명시한다.

## README 진입점 설계

Stage 4에서 README 하단 `## License` 섹션을 다음 방향으로 보강한다.

- 기존 `[MIT License](LICENSE)`는 유지한다.
- `Third-party notices` 문구를 추가해 `THIRD_PARTY_LICENSES.md`로 연결한다.
- 긴 license 표는 README에 복제하지 않는다.
- 필요하면 한 문장으로 `rhwp-core.lock`, `Sources/HostApp/Resources/rhwp-studio/manifest.json`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`를 provenance/detail 문서로 연결한다.

README 상단 badge의 MIT 표기는 프로젝트 자체 license를 나타내는 것으로 유지한다. third-party license badge를 추가하지 않는다.

## `FONTS.md` 보강 설계

Stage 3에서 다음을 보강한다.

- 문서 첫 문단을 “Alhangeul v0.1 bundle에 실제 포함되는 WOFF2 목록과 Git 미포함 proprietary font 대체 정책” 기준으로 정리한다.
- `LatinModernMath-Regular.woff2` 항목을 특수/수식 계열에 추가한다.
- `HappinessSansVF.woff2`가 `Happiness-Sans-*.woff2` wildcard에 정확히 포함되지 않으므로 Happiness Sans 행을 파일명 목록 또는 별도 행으로 정리한다.
- proprietary font 섹션은 “로컬에 직접 배치해야 한다”처럼 배포 사용자가 오해할 수 있는 표현을 줄이고, “저장소/release artifact에 포함하지 않음”을 먼저 적는다.

`FONTS.md`는 font별 license/source의 세부 표를 소유하므로 `THIRD_PARTY_LICENSES.md`에 같은 표를 복제하지 않는다.

## `font_fallback_strategy.md` 보강 설계

Stage 3에서 다음만 최소 보강한다.

- 자산 출처와 사용 범위 섹션에 사용자용 third-party 고지 위치로 `THIRD_PARTY_LICENSES.md`를 연결한다.
- native renderer fallback 정책 자체, alias chain, PostScript name 주의점은 변경하지 않는다.

## Stage 3 변경 파일과 비변경 파일

Stage 3 변경 파일:

- `THIRD_PARTY_LICENSES.md`
- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`
- `mydocs/tech/font_fallback_strategy.md`
- `mydocs/working/task_m016_147_stage3.md`

Stage 3에서 변경하지 않을 파일:

- `README.md`: Stage 4에서 진입점 정리
- `rhwp-core.lock`: #147 범위에서는 pin 변경 없음
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`: #147 범위에서는 asset snapshot 변경 없음
- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`: core update 작업 범위이므로 변경 없음

Stage 4 변경 파일:

- `README.md`
- `mydocs/working/task_m016_147_stage4.md`
- `mydocs/report/task_m016_147_report.md`
- `mydocs/orders/20260506.md`

## 단순 attribution과 legal 해석 분리

단순 attribution으로 처리할 항목:

- `rhwp` repository, license, release tag, resolved commit
- bundled `rhwp-studio` asset source path, release tag, resolved commit, manifest hash 위치
- Rust bridge generated artifact hash/size 위치
- bundled WOFF2 font 목록과 `FONTS.md` 세부 license/source 연결
- proprietary font 비포함 정책

legal 해석 또는 별도 검토가 필요한 항목:

- “무료 배포” font의 재배포 조건을 법률적으로 확정하는 표현
- upstream `rhwp-studio` JS/CSS/WASM transitive npm dependency license를 release artifact notice에 어느 깊이까지 포함해야 하는지
- upstream `v0.7.10` CLI binary asset license와 Alhangeul artifact license를 같은 문서에 함께 다룰지 여부

이번 #147에서는 legal 해석을 하지 않고, 현재 저장소와 release artifact에 포함된 third-party 범위의 attribution/provenance 고지만 정리한다.

## 잔여 위험

- `v0.7.10`이 최신 release로 확인되었으므로, 별도 core update 작업이 진행되면 #147에서 작성하는 `v0.7.9` 고지를 다시 갱신해야 한다.
- `FONTS.md`의 “무료 배포” font는 redistribution 조건을 더 엄밀히 확인해야 할 수 있다. Stage 3에서는 기존 문서의 license 표현을 크게 확장하지 않고 현재 source/license 표의 정확성 보강에 그친다.
- bundled `rhwp-studio`의 transitive npm dependency license inventory는 현재 manifest에 포함되어 있지 않다. 이 범위를 포함하려면 별도 dependency license manifest 작업이 필요하다.

## 다음 단계 영향

Stage 3에서는 `THIRD_PARTY_LICENSES.md`, `FONTS.md`, `font_fallback_strategy.md`를 위 설계대로 보강한다. 이때 현재 artifact 기준은 `v0.7.9`로 고정하고, `v0.7.10`은 “확인된 upstream 최신 release이나 현재 bundle 기준은 아님”으로 분리한다.

## 승인 요청

Stage 2 완료를 보고한다. 승인 후 Stage 3 `third-party license와 font 고지 보강`으로 진행한다.
