# Task M013 #263 Stage 3 보고서

## 단계 목적

Stage 3의 목적은 Stage 2에서 추가한 `native_macos_skia_editor_strategy.md`를 기준으로 사용자-facing README, 제품 로드맵, 아키텍처, Skia Quick Look/Thumbnail backend 문서를 정렬하는 것이다.

이번 단계는 문서 갱신만 수행했고, 코드, RustBridge ABI, workflow branch filter, 원격 브랜치는 변경하지 않았다.

## 변경 파일

| 파일 | 변경 요약 |
|------|-----------|
| `README.md` | 장기 방향을 native macOS viewer/editor shell, Rust/rhwp Skia renderer, Swift overlay 구조로 조정했다. 이정표, 렌더링 경로, 브랜치 요약, Mermaid 아키텍처, PR base 요약을 갱신했다. |
| `mydocs/tech/product_roadmap_notes.md` | 제품 흐름과 v0.5/v0.6 구현 메모를 native shell/Skia renderer/Swift overlay 기준으로 조정하고 전략 문서 링크를 추가했다. |
| `mydocs/tech/project_architecture.md` | RhwpCoreBridge 현재 경로와 장기 HostApp native 경로를 분리하고, `v0.7.11` lock 기준과 장기 책임 경계를 반영했다. |
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | Quick Look/Thumbnail Skia backend 문서가 HostApp viewer/editor 전환과 별도 범위임을 명시하고 전략 문서로 연결했다. |
| `mydocs/working/task_m013_263_stage3.md` | Stage 3 보고서 |
| `mydocs/orders/20260518.md` | #263 상태를 Stage 3 완료, Stage 4 승인 대기로 갱신 |

## 핵심 반영 내용

### README

- “Swift native viewer/editor” 표현을 “native macOS viewer/editor shell” 중심으로 바꿨다.
- 장기 HostApp 경로는 Swift가 renderer 전체를 재구현하는 것이 아니라 Rust/rhwp Skia renderer와 Swift 편집 UI/오버레이를 결합하는 방향이라고 설명했다.
- `native-viewer-editor` 브랜치를 HostApp native shell과 Swift overlay 실험 라인으로 설명했다.
- Mermaid diagram에 Rust/rhwp Skia renderer와 장기 HostApp path를 추가했다.

### 제품 로드맵

- 제품 흐름을 `WebView 첫 배포 -> Mac 통합 확장 -> 변환/자동화 -> native macOS viewer/editor shell -> 안전한 native 편집 -> Agent-ready 문서 환경`으로 조정했다.
- v0.5는 HostApp native viewer shell, page/tile viewport, native search/copy 중심으로 정리했다.
- v0.6은 caret/selection/IME/ruler/object overlay와 command routing 중심으로 정리했다.
- 저장 가능한 mutation은 hit-test, selection, dirty state, round-trip gate 이후 보수적으로 여는 것으로 유지했다.

### 아키텍처

- 현재 HostApp PDF export, Quick Look, Thumbnail이 공유하는 CoreGraphics/CoreText render tree bitmap 경로를 유지했다.
- 장기 HostApp native 경로는 Swift shell + Rust/rhwp Skia renderer + Swift overlay로 별도 섹션을 추가했다.
- core pin 설명을 현재 `rhwp-core.lock` 기준인 `v0.7.11` / `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`로 정리했다.

### Skia Quick Look/Thumbnail backend

- 이 문서가 HostApp viewer/editor 전환 문서가 아니라는 점을 다시 명시했다.
- HostApp native macOS shell 구현은 비범위에 추가했다.
- 장기 editor shell 책임 경계는 새 전략 문서가 소유하도록 연결했다.

## 보류한 변경

다음 문서는 Stage 4에서 브랜치/기여자 기준으로 갱신한다.

- `mydocs/tech/branch_strategy_webview_native.md`
- `mydocs/manual/git_workflow_guide.md`
- `mydocs/manual/pr_process_guide.md`
- `CONTRIBUTING.md`
- `.github/pull_request_template.md`
- `.github/copilot-instructions.md`
- release/CI 관련 문서의 native line 표현

## 검증 계획

Stage 3 작성 후 다음 검증을 수행한다.

```bash
git diff --check
rg -n "Swift native viewer|Swift native editor|Swift native viewer/editor|v0\\.7\\.10" \
  README.md mydocs/tech/product_roadmap_notes.md mydocs/tech/project_architecture.md mydocs/tech/skia_quicklook_thumbnail_backend.md
rg -n "native_macos_skia_editor_strategy|Rust/rhwp Skia|native macOS viewer/editor shell|CoreGraphics/CoreText" \
  README.md mydocs/tech/product_roadmap_notes.md mydocs/tech/project_architecture.md mydocs/tech/skia_quicklook_thumbnail_backend.md
```

코드와 workflow를 변경하지 않았으므로 Xcode build, render smoke, YAML 검증은 이번 단계에서 제외한다.

## 리스크

- README 일부 PR base 설명은 갱신했지만, 상세 기여자 문서와 PR template은 아직 Stage 4 전이라 표현이 완전히 일치하지 않는다.
- CoreGraphics/CoreText renderer는 현행 경로이므로 제거 대상으로 읽히지 않도록 계속 조심해야 한다.
- `v0.5+` milestone의 사용자-facing 표현이 넓어졌지만, 실제 HostApp Skia renderer 구현은 아직 별도 이슈가 필요하다.

## 승인 요청

Stage 3 문서 갱신을 완료했다. 이 보고서 기준으로 Stage 4 브랜치 전략/기여자/PR 안내 문서 갱신을 진행하려면 작업지시자 승인이 필요하다.
