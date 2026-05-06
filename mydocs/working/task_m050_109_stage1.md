# Task M050 #109 Stage 1 보고서

## 단계 목적

rhwp-studio/core renderer가 이미 지원하는 도형·텍스트 style 항목을 Swift native renderer의 현재 처리와 대조했다. 이번 단계는 구현 없이 기준 조사만 수행했고, `devel` 작업이 `devel-webview` 배포 경로에 미치는 영향을 분리했다.

## 산출물

| 파일 | 내용 |
| --- | --- |
| `mydocs/working/task_m050_109_stage1.md` | style 항목별 reference, Swift 처리 상태, 다음 단계 구현/보류 판단을 기록했다. |

소스 변경은 없다.

## 기준 확인

- 현재 core 고정 기준은 `rhwp-core.lock`과 `RustBridge/Cargo.toml` 모두 `edwardkim/rhwp` `v0.7.9`, commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863`이다.
- reference 구현은 cargo checkout의 `src/renderer/web_canvas.rs`, `src/renderer/svg.rs`, `src/renderer/render_tree.rs`, `src/renderer/layout/text_measurement.rs`를 기준으로 확인했다.
- `devel` HostApp viewer는 `DocumentPageView` + `CGTreeRenderer` 기반 native viewer이다.
- `devel-webview` HostApp viewer는 `RhwpStudioWebView` 기반이고 `Sources/HostApp/Resources/rhwp-studio`에 full web bundle을 포함한다.
- 두 브랜치의 공용 native renderer 차이는 `origin/devel-webview...origin/devel` 기준 `CGTreeRenderer.swift`, `FontFallback.swift`, `FontResourceRegistry.swift`로 제한된다.

## Style 현황

| 항목 | render tree 필드 | rhwp-studio/core 기준 | Swift 현재 상태 | 다음 단계 판단 |
| --- | --- | --- | --- | --- |
| dash | `ShapeStyle.strokeDash`, `LineStyle.dash` | `Solid`, `Dash`, `Dot`, `DashDot`, `DashDotDot`을 canvas line dash로 매핑 | 동일 이름 dash는 `applyDash`에서 이미 처리 | Stage 2에서 alias 필요 여부만 확인 |
| line arrow | `LineStyle.startArrow`, `endArrow`, `startArrowSize`, `endArrowSize` | line 양끝에 `Arrow`, `ConcaveArrow`, diamond/circle/square 계열을 그림 | 필드는 디코딩되지만 line/path stroke에서 미사용 | Stage 2 구현 대상 |
| path `ArcTo` | `PathCommand.arcTo` | SVG는 `A` command, WebCanvas는 cubic bezier 변환 사용 | 디코딩은 되지만 `buildCGPath`에서 endpoint 직선 fallback | Stage 2 구현 대상, 변환 위험 시 조건부 fallback |
| pattern fill | `ShapeStyle.pattern` | 6x6 tile pattern으로 type 0-5 가로/세로/대각/역대각/십자/격자 처리 | 배경색만 채우는 fallback | Stage 3 구현 대상 |
| shape shadow | `ShapeStyle.shadow` | shadow color/offset/alpha/blur를 canvas shadow로 적용 | 필드는 디코딩되지만 미사용 | Stage 3 구현 대상 |
| line shadow | `LineStyle.shadow` | line stroke 전에 canvas shadow 적용 후 reset | 필드는 디코딩되지만 미사용 | Stage 3 또는 Stage 2에서 적용 순서 판단 |
| text shadow | `TextStyle.shadowType`, `shadowColor`, `shadowOffsetX/Y` | shadow pass를 먼저 그리고 본문 pass를 그림 | 필드는 디코딩되지만 `drawTextLine`에서 미사용 | Stage 4 구현 대상 |
| superscript/subscript | `TextStyle.superscript`, `subscript` | font size 0.7배, y offset 보정 | 필드는 디코딩되지만 font/baseline에 미반영 | Stage 4 구현 대상 |
| emphasis dot | `TextStyle.emphasisDot` | 글자별 강조점을 baseline 위에 별도 text로 그림 | 필드는 디코딩되지만 미사용 | Stage 4 구현 대상 |
| tab leader | `TextStyle.tabLeaders` | `extract_tab_leaders`로 leader range 생성, fill type 1-11 draw | 필드는 디코딩되고 tab layout은 있으나 leader draw 없음 | Stage 4 구현 대상 |
| text rotation | `TextRunNode.rotation` | bbox 중심 회전 후 중앙 정렬 text draw | 필드는 디코딩되지만 `CGTreeRenderer` text path에서 미사용 | Stage 5에서 구현 가능성 판단 |
| vertical text | `TextRunNode.isVertical` | core layout/render path에서 vertical run을 별도 취급 | 필드는 디코딩되지만 Swift draw path에서 미사용 | Stage 5에서 범위 제한 필요 |

## 영향 범위

이번 #109는 `devel`의 native viewer renderer parity 작업이다. `devel-webview` 배포 앱의 HostApp 문서 화면은 WKWebView/rhwp-studio bundle을 사용하므로 이 작업을 `devel`에만 진행하는 한 직접 영향은 없다.

다만 Quick Look preview와 Thumbnail extension은 `HwpPageImageRenderer`를 통해 `CGTreeRenderer`를 사용한다. 따라서 #109 변경을 나중에 `devel-webview`로 cherry-pick 또는 backport하면 HostApp WKWebView 화면은 그대로여도 Finder Quick Look/Thumbnail native bitmap 출력은 바뀔 수 있다. 백포트는 별도 승인과 Quick Look/Thumbnail smoke 검증이 필요하다.

## 검증 결과

| 명령 | 결과 |
| --- | --- |
| `git status --short --branch` | Stage 1 보고서 작성 전 `local/task109` 확인 |
| `rg -n "shadow|arrow|dash|pattern|ArcTo|rotation|is_vertical|superscript|subscript|emphasis|tab_leader|WebCanvasRenderer|render_overflow|draw" ...` | 생성된 web bundle 노이즈를 피하기 위해 `Sources`, `scripts`, lock/Cargo 파일로 범위를 좁혀 실행. 관련 필드와 Swift 미사용 지점을 확인 |
| `rg -n "struct TextStyle|struct ShapeStyle|struct LineStyle|enum PathCommand|renderTextRun|applyShapeStyleFill|applyDash|arcTo" Sources/RhwpCoreBridge` | `RenderTree.swift`의 style 필드와 `CGTreeRenderer.swift`의 현재 helper 위치 확인 |
| `git diff --name-status origin/devel-webview...origin/devel -- Sources/RhwpCoreBridge Sources/Shared Sources/QLExtension Sources/ThumbnailExtension Sources/HostApp/Views/DocumentViewerView.swift` | `CGTreeRenderer.swift`, `FontFallback.swift`, `FontResourceRegistry.swift`만 차이 확인 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage1-bokhak samples/복학원서.hwp` | 성공. render tree JSON 189,498 bytes, core SVG 380,803 bytes, native PNG 794x1123, non-white pixels 261,995. qlmanage rasterize 문제로 diff PNG는 생성되지 않음 |
| `git diff --check` | 보고서 작성 전 통과 |

작업 중 메인 worktree가 한 차례 `devel-webview`로 돌아간 것을 확인했지만, 해당 상태에서는 소스/문서 변경을 하지 않았다. Stage 1 산출물 작성 전 `local/task109`로 다시 전환했다.

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 조사 보고서 신규 작성만 포함한다. 기존 소스와 문서 본문은 변경하지 않았으므로 본문 손실은 없다.

## 잔여 위험

- 현재 샘플 `복학원서.hwp`는 모든 issue 범위 style을 포괄하지 않는다. Stage 2-5에서 각 항목별 샘플 부족 시 구현은 제한하고 fallback으로 남겨야 한다.
- text rotation/vertical text는 CoreText 좌표계, baseline, decoration, cluster drawing과 충돌할 수 있어 Stage 5에서 별도 판단이 필요하다.
- line arrow와 arcTo는 path geometry 변경이라 기존 shape 위치가 미세하게 달라질 수 있다.
- qlmanage rasterize 실패로 core SVG/native PNG diff image는 Stage 1에서 생성되지 않았다. 이후 구현 단계에서는 native smoke와 시각 산출물을 함께 확인한다.

## 다음 단계 영향

Stage 2는 도형 stroke/path 쪽으로 좁힌다. 우선 dash alias 확인, line arrow helper, `ArcTo` cubic bezier 변환 또는 안전 fallback을 `CGTreeRenderer.swift` 안에 제한적으로 추가한다. `devel-webview` 백포트는 이번 단계와 다음 단계 범위에 포함하지 않는다.

## 승인 요청

Stage 1 기준 조사를 완료했다. 다음 단계로 `Stage 2. 도형 stroke/path style 보강`을 진행하려면 작업지시자 승인이 필요하다.
