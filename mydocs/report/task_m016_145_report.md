# Task #145 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#145 v0.1 release artifact 구성과 provenance 정리](https://github.com/postmelee/alhangeul-macos/issues/145) |
| 마일스톤 | M016 / v0.1 출시 전 보강 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task145` |
| 단계 수 | 5단계 |
| 결론 | v0.1 release artifact의 개발/검증용 zip, rehearsal DMG, public signed/notarized DMG 역할을 분리하고, checksum/provenance/release note 공개 기준을 문서와 release note generator에 반영했다. Stage 4에서 Release package zip과 staging app을 실제 생성해 bundle 포함 상태를 검증했다. |

## 최종 artifact 기준

| 계층 | 산출물 | 용도 | public 사용 |
|------|--------|------|-------------|
| 개발/설치본 smoke | `build.noindex/release/Alhangeul.app`, `build.noindex/release/alhangeul-macos-0.1.0.zip` | Release configuration bundle 구성 검증, #151 설치본 smoke 입력 | 아니오 |
| public release rehearsal | `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg`, `.sha256` | DMG layout/checksum/release script path rehearsal | 아니오 |
| public release | `build.noindex/release/alhangeul-macos-0.1.0.dmg`, `.sha256` | GitHub Release asset, 사용자 배포, Homebrew Cask digest 기준 | 예 |

checksum 공개 기준:

| checksum | 공개 범위 |
|----------|-----------|
| zip stdout checksum | 단계 보고서와 설치본 smoke report용 식별자. public release checksum으로 쓰지 않는다. |
| rehearsal DMG `.sha256` | rehearsal workflow artifact와 보고서용. public release checksum으로 쓰지 않는다. |
| public DMG `.sha256` | GitHub Release asset, release note, Homebrew Cask checksum 교체 입력. |

## Stage 4 산출물

```bash
./scripts/package-release.sh 0.1.0
```

| artifact | 위치 | 크기 | SHA256 |
|----------|------|------|--------|
| staging app | `build.noindex/release/Alhangeul.app` | `108M` | 별도 checksum 파일 없음 |
| 개발/검증용 zip | `build.noindex/release/alhangeul-macos-0.1.0.zip` | `57M` (`60231843` bytes) | `e21542e8b997717e1c7388d2bd557007bccf39d3d78bb3fc80a78e79e45b5f6c` |

이 zip은 public release asset이 아니다. public 사용자 배포 기준은 `scripts/release.sh` public mode 또는 `release-publish.yml`이 만드는 signed/notarized/stapled DMG다.

## Provenance 기준

| 대상 | 기준 |
|------|------|
| `rhwp` core release tag/commit | `rhwp-core.lock` |
| Rust bridge artifact hash/size | `rhwp-core.lock` |
| FFI ABI surface | `rhwp-ffi-symbols.txt` |
| bundled `rhwp-studio` asset | `Sources/HostApp/Resources/rhwp-studio/manifest.json` |
| third-party notices | `THIRD_PARTY_LICENSES.md`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` |

현재 기준:

| 항목 | 값 |
|------|----|
| `rhwp` release tag | `v0.7.10` |
| `rhwp` resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| upstream latest 확인 | `v0.7.10`, published `2026-05-05T17:56:40Z` |
| `rhwp-studio` release tag | `v0.7.10` |
| `rhwp-studio` resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| `release-publish.yml` 기본 `expected_rhwp_tag` | `v0.7.10` |

#167 이후 current `rhwp-core.lock`, bundled `rhwp-studio` manifest, release publish workflow 기본 guard는 같은 `v0.7.10` 기준으로 정합화되어 있다.

## release note generator

`scripts/ci/write-release-notes.sh`는 public DMG digest를 입력받아 release note skeleton을 생성한다. 이번 작업에서 다음 항목을 추가했다.

- bundled `rhwp-studio` release tag
- bundled `rhwp-studio` resolved commit
- `Sources/HostApp/Resources/rhwp-studio/manifest.json` 위치
- `THIRD_PARTY_LICENSES.md`
- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`

검증용 dummy/final digest 입력으로 `write-release-notes.sh`를 실행했고, core/studio/third-party notice 항목이 출력되는 것을 확인했다.

## 변경 파일 목록

| 파일 | 내용 |
|------|------|
| `mydocs/manual/release_distribution_guide.md` | artifact 3계층, checksum 공개 기준, provenance 원천, release note 필수 항목, checklist 보강 |
| `scripts/ci/write-release-notes.sh` | `rhwp-studio` manifest와 third-party notices를 release note skeleton에 추가 |
| `mydocs/plans/task_m016_145.md` | #167 이후 current `v0.7.10` 기준으로 계획서 보정 |
| `mydocs/plans/task_m016_145_impl.md` | #167 이후 current `v0.7.10` 기준과 실제 `AlhangeulPreview.appex` 산출물명으로 검증 계획 보정 |
| `mydocs/orders/20260507.md` | #145 진행/완료 상태 기록 |
| `mydocs/working/task_m016_145_stage3.md` | Stage 3 문서/스크립트 정합성 보강 보고 |
| `mydocs/working/task_m016_145_stage4.md` | Stage 4 package artifact 생성과 bundle 포함 검증 보고 |
| `mydocs/working/task_m016_145_stage5.md` | Stage 5 최종 handoff 보고 |
| `mydocs/report/task_m016_145_report.md` | 최종 보고서 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획/Stage 1-2 | `0f6edba` 이전 #145 PR | release artifact inventory, artifact 공개 항목 설계, README 로드맵 정리를 먼저 merge했다. |
| Stage 3 | `3fef88d` | release distribution guide와 release note generator를 `v0.7.10` provenance 기준으로 보강했다. |
| Stage 4 | `53d23dd` | `package-release` 산출물을 생성하고 bundle 포함 상태와 zip checksum을 검증했다. |
| Stage 5 | 이번 최종 보고 커밋 | 최종 보고서, Stage 5 보고서, 오늘할일 완료 처리를 정리한다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `bash -n scripts/package-release.sh scripts/release.sh scripts/ci/write-release-notes.sh` | OK | Stage 3 |
| `./scripts/release.sh --help` | OK | Stage 3 |
| `scripts/verify-rhwp-studio-assets.sh` | OK | Stage 3 |
| `bash scripts/ci/write-release-notes.sh ...` | OK | Stage 3/5 |
| `gh release view -R edwardkim/rhwp --json tagName,publishedAt,url` | OK | latest `v0.7.10` 확인 |
| `./scripts/package-release.sh 0.1.0` | OK | Release package staging app과 zip 생성 |
| `test -d build.noindex/release/Alhangeul.app` | OK | staging app 존재 |
| `test -f build.noindex/release/alhangeul-macos-0.1.0.zip` | OK | zip 존재 |
| `shasum -a 256 build.noindex/release/alhangeul-macos-0.1.0.zip` | OK | `e21542e8...b5f6c` |
| Preview appex 포함 확인 | OK | `AlhangeulPreview.appex` |
| Thumbnail appex 포함 확인 | OK | `AlhangeulThumbnail.appex` |
| bundled `rhwp-studio` 필수 asset 확인 | OK | index, WASM, JS, CSS, manifest, WOFF2 35개 |
| `scripts/verify-rhwp-studio-assets.sh build.noindex/release/.../rhwp-studio` | OK | bundle 내부 resource 검증 |
| `codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app` | OK | ad-hoc local signing 기준 |
| `git diff --check` | OK | whitespace error 없음 |

Stage 4 package build 중 Xcode/CoreSimulator 관련 sandbox 경고가 출력되었지만 macOS Release build와 package 생성은 성공했다. 이 경고는 packaging 실패로 분류하지 않는다.

## Public release 전 남은 조건

| 구분 | 남은 작업 |
|------|-----------|
| #150 | WKWebView viewer asset loading 실패 fallback 보강 |
| #149 | 손상/대용량 HWP/HWPX opening fallback 보강 |
| #151 | Stage 4 package 산출물을 입력으로 Quick Look/Thumbnail 설치본 smoke gate 정리 |
| #146 | Viewer와 Quick Look/Thumbnail 렌더 경로 한계 문서화 |
| public release | Developer ID signing, app/DMG notarization, staple, Gatekeeper assessment, GitHub Release upload |
| Homebrew Cask | public DMG checksum 확정 후 Cask checksum 교체 여부 결정 |
| upstream latest | release 실행 직전 `rhwp` upstream latest가 current `v0.7.10`과 여전히 일치하는지 재확인 |

## 제외한 작업

- public DMG 생성
- `scripts/release.sh --skip-notarize 0.1.0` rehearsal DMG 생성
- Developer ID signing/notarization/staple
- GitHub Release 생성 또는 asset upload
- Homebrew Cask checksum 교체
- #150/#149/#151/#146 구현 또는 문서 본작업

## 작업지시자 승인 요청

Task #145의 release artifact 구성과 provenance 정리를 완료했다. 다음 단계는 `publish/task145` 브랜치 push와 `devel-webview` 대상 PR 생성 승인이다.
