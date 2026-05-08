# Task M016 #145 Stage 5 보고서

## 단계 목적

Stage 1-4 결과를 최종 보고서로 묶고, release artifact 구성/checksum/provenance 공개 기준과 public release 전 남은 gate를 명확히 한다.

## 현재 release 기준 확인

2026-05-07 기준 upstream `edwardkim/rhwp` latest release를 다시 확인했다.

```bash
gh release view -R edwardkim/rhwp --json tagName,publishedAt,url
```

결과:

```json
{"publishedAt":"2026-05-05T17:56:40Z","tagName":"v0.7.10","url":"https://github.com/edwardkim/rhwp/releases/tag/v0.7.10"}
```

따라서 #167 이후 current `rhwp-core.lock`, bundled `rhwp-studio` manifest, release publish workflow 기본 `expected_rhwp_tag`는 현재 모두 `v0.7.10` 기준으로 일치한다.

## 최종 보고서 작성

최종 보고서는 `mydocs/report/task_m016_145_report.md`에 작성했다. 포함 내용:

- artifact 3계층: 개발/설치본 smoke zip, rehearsal DMG, public signed/notarized DMG
- Stage 4 생성 산출물과 checksum
- `rhwp-core.lock`, `rhwp-studio` manifest, FFI symbol snapshot, third-party notices 기준
- release note generator 변경 결과
- 실행한 검증과 실행하지 않은 public release 항목
- #150/#149/#151/#146 후속 gate

## 후속 gate 상태

2026-05-07 확인 기준:

| Issue | 상태 | release 전 의미 |
|------|------|----------------|
| #150 WKWebView viewer asset loading 실패 fallback 보강 | OPEN | WebView asset loading 실패 시 사용자/운영 fallback 기준 보강 필요 |
| #149 손상·대용량 HWP/HWPX 파일 opening fallback 보강 | OPEN | 열기 실패/대용량 입력의 사용자 fallback 기준 보강 필요 |
| #151 Quick Look/Thumbnail 설치본 smoke gate 정리 | OPEN | Stage 4 package 산출물을 입력으로 설치본 smoke gate 판정 필요 |
| #146 Viewer와 Quick Look/Thumbnail 렌더 경로 한계 문서화 | OPEN | release note/README/known limitations에 연결할 한계 문서화 필요 |

## 최종 검증

```bash
shasum -a 256 build.noindex/release/alhangeul-macos-0.1.0.zip
test -d build.noindex/release/Alhangeul.app
test -f build.noindex/release/alhangeul-macos-0.1.0.zip
test -f build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm
test -d build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
test -d build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
scripts/verify-rhwp-studio-assets.sh build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio
codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app
bash scripts/ci/write-release-notes.sh 0.1.0 e21542e8b997717e1c7388d2bd557007bccf39d3d78bb3fc80a78e79e45b5f6c build.noindex/release/test-final-release-notes-0.1.0.md
rg -n "alhangeul-macos-0.1.0|SHA256|rhwp-core.lock|rhwp-studio|manifest.json|rehearsal|public DMG|#150|#149|#151|#146|v0.7.10" \
  mydocs/working/task_m016_145_stage5.md mydocs/report/task_m016_145_report.md mydocs/orders/20260507.md mydocs/manual/release_distribution_guide.md
git diff --check
```

결과:

```text
e21542e8b997717e1c7388d2bd557007bccf39d3d78bb3fc80a78e79e45b5f6c  build.noindex/release/alhangeul-macos-0.1.0.zip
OK: rhwp-studio assets verified at build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio
build.noindex/release/Alhangeul.app: valid on disk
build.noindex/release/Alhangeul.app: satisfies its Designated Requirement
```

`git diff --check`는 통과했다.

## 판정

Stage 5 기준은 충족했다. #145는 release artifact 구성과 provenance 공개 기준 정리를 완료했다.

다음 단계는 `publish/task145` 브랜치 push와 `devel-webview` 대상 PR 생성이다. PR merge 후 #145 이슈 close와 브랜치/worktree 정리는 merge 확인 후 별도 cleanup 절차로 수행한다.
