# Task #267 Stage 5 보정 보고서

## 개요

`rhwp v0.7.12` 반영과 `v0.1.3` public release handoff PR 이후 Copilot review에서 확인된 유효 지적을 보정했다. 이 보정은 public tag 생성과 release workflow 실행 전에 source와 release communication을 다시 정렬하는 단계다.

## 반영 내용

| 영역 | 내용 |
|------|------|
| Host bridge | print/share/export 전 `settleEditorState()`가 발생시키는 programmatic `change` event를 dirty state로 전송하지 않도록 guard 추가 |
| Host bridge | 중첩 native command 호출에도 guard가 풀리지 않도록 settle guard를 counter 방식으로 보정 |
| Host bridge | `rhwp-studio v0.7.12`의 `edit:compare-documents`, `edit:document-history` 명령을 non-mutating command로 분류 |
| Pages release note | `v0.1.3` DMG link를 `releases/download/v0.1.3/alhangeul-macos-0.1.3.dmg`로 고정 |
| Release note | `rhwp_render_page_png` 추가와 generated header hash/size 변경 사실을 반영 |
| Pages workflow | GitHub Releases API로 release/asset 존재를 확인하고, 404 또는 asset 없음만 skip하며 API/네트워크 오류는 실패 처리하도록 release asset gate 추가 |

## PR 상태

| PR | 대상 | 상태 |
|----|------|------|
| [#268](https://github.com/postmelee/alhangeul-macos/pull/268) | `publish/task267` -> `devel` | merged |
| [#269](https://github.com/postmelee/alhangeul-macos/pull/269) | `devel` -> `main` | merged |
| [#270](https://github.com/postmelee/alhangeul-macos/pull/270) | `publish/task267` -> `devel` | Copilot follow-up 보정 반영 |

## 검증

| 항목 | 결과 | 명령 |
|------|------|------|
| Workflow YAML parse | 통과 | `ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'` |
| Workflow actionlint | 통과 | `actionlint .github/workflows/pages-docs-deploy.yml` |
| Release link scan | 통과 | docs release DMG link version 추출 결과 `0.1.0`, `0.1.1`, `0.1.2`, `0.1.3` |
| Stale v0.1.3 latest link/FFI 문구 검색 | 통과 | `rg -n "latest/download/alhangeul-macos-0\\.1\\.3|Rust FFI symbol set.*동일|generated header hash.*동일" docs mydocs/release/v0.1.3.md` 결과 없음 |
| Whitespace | 통과 | `git diff --check` |
| HostApp Debug build | 통과 | `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask267Correction CODE_SIGNING_ALLOWED=NO build` |

## 다음 단계

- 보정 commit을 다시 `publish/task267` PR로 게시해 `devel`에 반영한다.
- `devel` 보정분을 `main`에 반영한다.
- public tag 생성과 release workflow 실행은 작업지시자 승인 후 별도 진행한다.
