# Task #167 Stage 5 보고서

## 단계 목적

Stage 1-4 결과를 최종 보고서로 묶고, #145/#151/#146/#166이 이어받을 `rhwp v0.7.10` release 기준을 명확히 한다. 또한 최신 `origin/devel-webview`에 merge된 #145 변경을 task167 worktree에 반영해 PR diff가 기존 통합 브랜치 변경을 삭제하지 않도록 정리한다.

## 최신 통합 브랜치 반영

Stage 4 완료 후 `origin/devel-webview`에는 #145가 merge되어 있었다.

```text
0f6edba Merge pull request #168 from postmelee/publish/task145
55883da Task #145: README 로드맵과 마일스톤 기준 재구성
3312e28 Task #145 Stage 2: artifact 공개 항목 설계
c9a1d14 Task #145 Stage 1: release artifact inventory 정리
846b462 Task #145: 구현 계획서 작성
ac6b6dc Task #145: 수행 계획서 작성과 오늘할일 갱신
```

`local/task167`에 `origin/devel-webview`를 병합했다. 충돌은 `mydocs/orders/20260506.md` 한 파일에서만 발생했고, #145와 #167 오늘할일 항목을 모두 보존하는 형태로 해결했다.

병합 커밋:

```text
a88466e Merge remote-tracking branch 'origin/devel-webview' into local/task167
```

## 최종 보고서 작성

최종 보고서는 `mydocs/report/task_m016_167_report.md`에 작성했다. 포함한 핵심 내용은 다음이다.

- `rhwp` release tag와 resolved commit
- `rhwp-core.lock` artifact hash/size
- FFI symbol snapshot 변화 여부
- bundled `rhwp-studio` manifest와 entrypoint hash
- bundled WOFF2 35개와 추가 old Hangul fallback font
- Stage 1-4 검증 결과
- 작업지시자 직접 Debug app 동작 확인 결과
- #145/#151/#146/#166 handoff 기준

## Handoff 기준

| 후속 이슈 | 넘길 기준 |
|----------|----------|
| #145 | release artifact/provenance 문서와 공개 산출물 설계는 `rhwp-core.lock` `v0.7.10`, `rhwp-studio/manifest.json` `v0.7.10`, WOFF2 35개 기준으로 이어받는다. |
| #151 | 설치본 Quick Look/Thumbnail smoke는 이번 작업의 Debug/Release build 결과를 전제로 하되, 실제 package/install/PlugInKit/qlmanage 판정은 #151에서 수행한다. |
| #146 | known limitations 문서화 시 viewer 경로는 WKWebView `rhwp-studio v0.7.10`, native renderer smoke는 Stage 4 결과를 기준으로 설명한다. |
| #166 | core bump, Rust bridge artifact 재생성, bundled `rhwp-studio` asset sync를 반복하지 않는다. 이 작업 결과를 확인하고 실제 release package/signing/notarization/publish 절차만 진행한다. |

## 검증

```bash
scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
git diff --check
rg -n "v0\.7\.9|0fb3e6758b8ad11d2f3c3849c83b914684e83863|DtQ01XFR" \
  README.md THIRD_PARTY_LICENSES.md rhwp-core.lock RustBridge/Cargo.toml RustBridge/Cargo.lock \
  Sources/HostApp/Resources/rhwp-studio/manifest.json mydocs/tech mydocs/manual scripts .github
```

결과:

```text
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task167/Sources/HostApp/Resources/rhwp-studio
OK: shared Swift code has no AppKit/UIKit dependencies
```

`git diff --check`는 오류가 없었다. stale `v0.7.9`, 이전 resolved commit, 이전 WASM 파일명 검색 결과도 없었다.

## 판정

Stage 5 기준은 충족했다. #167은 `rhwp v0.7.10` core/studio release 기준 정합화와 M16 release 전 기본 재검증을 완료했다.
