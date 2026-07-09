# Task M020 #391 구현계획서

수행계획서: `mydocs/plans/task_m020_391.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #391 `filename/external image context ABI 조사 및 bridge 설계`
- 추적 이슈: #387 Preview/Thumbnail Skia readiness 후속 개선 추적
- 관련 완료 조사: #404 upstream 렌더 PR 대표 샘플 diff 측정
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task391`
- 목표: 현재 Swift/RustBridge가 파일명과 외부 이미지 리소스를 어떤 수준까지 전달할 수 있는지 확인하고, upstream `rhwp v0.7.17` 및 최근 external image 관련 변경을 근거로 future C ABI와 Swift/macOS 책임 경계를 설계한다.

## 구현 원칙

- #391은 조사와 설계 작업이다. RustBridge ABI 구현, `Rhwp.xcframework` 재생성, renderer backend 동작 변경, Skia 기본 전환은 수행하지 않는다.
- `rhwp-core.lock`의 pinned `v0.7.17`과 upstream unreleased 변경을 구분해서 기록한다. unreleased PR/issue는 future compatibility 관찰 대상으로만 취급한다.
- renderer backend가 임의의 파일 시스템 접근 권한을 갖는 설계는 피한다. macOS shell이 허용된 파일과 byte payload를 판정하고 RustBridge는 명시적으로 전달된 context만 사용한다.
- Quick Look Preview, Finder Thumbnail, HostApp/WKWebView, future native viewer의 파일 접근 조건을 분리한다.
- external fixture가 없거나 upstream API가 아직 확정되지 않은 항목은 구현을 보류하고 follow-up issue 후보로 정리한다.
- 기존 ABI와 JSON shape를 깨지 않는 additive 설계를 우선 검토한다. breaking change가 필요하면 별도 migration 단계와 symbol versioning 필요성을 명시한다.

## 관련 맥락

| 축 | 관련 항목 | #391 확인 포인트 |
|----|-----------|------------------|
| 현재 filename 전달 | `RhwpDocument(data:filename:)`, `rhwp_open(data,len)` | Swift가 받은 filename이 RustBridge에 전달되지 않는 현재 구조와 에러 메시지 용도만 문서화한다. |
| embedded image bytes | `ImageNode.bin_data_id`, `rhwp_image_data` | render tree image node와 BinData byte 조회 계약, nil image 처리 경로를 확인한다. |
| external/large image data | upstream `edwardkim/rhwp#1913`, `#1924`, `#1917`, `#1930`, issue `#1141` | 외부 BinData Link, placeholder 보존, 대형 BinData 처리, missing image diagnostic 필요성을 조사한다. |
| macOS sandbox | Quick Look, Thumbnail, HostApp | file URL, sibling resource, package-relative path, security-scoped access 책임이 어느 layer에 있어야 하는지 분리한다. |
| future ABI | RustBridge C ABI, Swift wrapper | open context, external refs enumeration, injected bytes, diagnostics JSON 후보를 설계한다. |

## Stage 1. 현재 app ABI와 image data 계약 inventory

### 목표

현재 알한글 downstream에서 filename과 image data가 지나가는 경로를 정리하고, external image context가 들어갈 수 없는 지점을 명확히 표시한다.

### 대상

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/PageOverlayImages.swift`
- `Sources/PreviewRenderer/CGTreeRenderer.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- `RustBridge/src/lib.rs`
- `rhwp-ffi-symbols.txt`
- `rhwp-core.lock`
- `mydocs/working/task_m020_391_stage1.md`

### 작업

1. Swift wrapper에서 `filename`이 사용되는 위치와 RustBridge로 전달되지 않는 지점을 확인한다.
2. `rhwp_open`, `rhwp_image_data`, render tree `ImageNode.bin_data_id`의 current contract를 정리한다.
3. CoreGraphics renderer가 image byte nil 또는 decode 실패를 어떻게 처리하는지 확인한다.
4. Quick Look/Thumbnail entry point가 file URL, Data, filename을 어떤 순서로 전달하는지 정리한다.
5. current ABI로는 external image discovery/injection/diagnostic이 불가능한 부분을 evidence 중심으로 기록한다.

### 검증

```bash
rg -n "filename|external|BinData|bin_data_id|rhwp_open|rhwp_image_data|imageData|DocumentCore::from_bytes|pageOverlay|overlay|sandbox|security" \
  Sources RustBridge rhwp-ffi-symbols.txt rhwp-core.lock mydocs/plans/task_m020_391_impl.md
git diff --check
```

### 완료 조건

- current Swift/RustBridge call graph와 image data contract가 Stage 1 보고서에 정리되어 있다.
- filename이 현재 ABI로 전달되지 않는다는 근거가 파일/라인 중심으로 기록되어 있다.
- Stage 2에서 확인할 upstream contract 질문 목록이 도출되어 있다.

### 커밋 메시지

```text
Task #391 Stage 1: current ABI와 image data 계약 inventory
```

## Stage 2. upstream rhwp/studio external resource contract 조사

### 목표

pinned `rhwp v0.7.17`와 upstream 최근 이슈/PR에서 filename context, external image link, placeholder, large BinData가 어떤 contract로 다뤄지는지 조사한다.

### 대상

- `rhwp-core.lock`
- upstream `edwardkim/rhwp` issue/PR metadata
- 필요 시 upstream `v0.7.17` source snapshot
- `mydocs/working/task_m020_391_stage2.md`

### 작업

1. `rhwp-core.lock`의 release tag/commit 기준을 다시 확인하고 pinned core의 public path를 조사한다.
2. upstream issue `edwardkim/rhwp#1141`과 external image, filename context, BinData 관련 PR 목록을 조회한다.
3. #404에서 분류된 external/large image data 축의 PR `#1913`, `#1924`, `#1917`, `#1930`이 #391 설계에 주는 의미를 분리한다.
4. rhwp-studio 또는 upstream CLI가 filename/base path를 사용하는지, render tree 또는 SVG export에 missing image signal을 남기는지 확인한다.
5. pinned release에서 즉시 사용할 수 있는 API와 future ABI로만 고려해야 하는 API를 분리한다.

### 검증

```bash
gh issue view 1141 --repo edwardkim/rhwp --json number,title,body,state,url
gh pr list --repo edwardkim/rhwp --search "external image filename context BinData" --state all --limit 20 --json number,title,state,url
gh pr list --repo edwardkim/rhwp --search "document context external resource" --state all --limit 20 --json number,title,state,url
gh pr view 1913 --repo edwardkim/rhwp --json number,title,body,files,state,url
gh pr view 1924 --repo edwardkim/rhwp --json number,title,body,files,state,url
gh pr view 1917 --repo edwardkim/rhwp --json number,title,body,files,state,url
gh pr view 1930 --repo edwardkim/rhwp --json number,title,body,files,state,url
rg -n "external|filename|BinData|context|resource|missing|injected|placeholder|large" \
  mydocs/working/task_m020_391_stage2.md
git diff --check
```

### 완료 조건

- pinned `v0.7.17`에서 가능한 것과 upstream unreleased 변경의 기대 효과가 구분되어 있다.
- filename context가 upstream parser/render path에서 필요한지, 또는 downstream shell responsibility인지 판단 근거가 있다.
- Stage 3 ABI 후보에 반영할 external image state 목록이 정리되어 있다.

### 커밋 메시지

```text
Task #391 Stage 2: upstream external resource contract 조사
```

## Stage 3. external image C ABI 후보 설계

### 목표

기존 C ABI와 JSON shape를 가능한 유지하면서 external image discovery, bytes injection, diagnostics를 지원할 후보 API를 설계한다.

### 대상

- `rhwp-ffi-symbols.txt`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `RustBridge/src/lib.rs`
- `mydocs/working/task_m020_391_stage3.md`

### 작업

1. `rhwp_open_with_context` 또는 context setter 방식의 장단점을 비교한다.
2. 외부 리소스 목록을 JSON으로 열람하는 `rhwp_external_image_refs` 계열 후보를 설계한다.
3. Swift shell이 허용한 bytes를 주입하는 `rhwp_inject_external_image_bytes` 계열 후보를 설계한다.
4. embedded, external, missing, placeholder, injected, decode_failed 같은 diagnostic 상태 enum 또는 JSON shape를 설계한다.
5. UTF-8 path, relative path normalization, byte buffer ownership, handle lifecycle, thread-safety, additive symbol export 정책을 정리한다.
6. legacy client가 새 symbol 없이도 기존 embedded image 렌더를 유지하는 fallback 조건을 명시한다.

### 검증

```bash
rg -n "rhwp_open_with|context setter|external.*ref|inject|diagnostic|missing|embedded|placeholder|injected|decode_failed|lifetime|UTF-8|C ABI" \
  mydocs/working/task_m020_391_stage3.md
git diff --check
```

### 완료 조건

- 최소 2개 이상의 C ABI 설계안과 선택 기준이 기록되어 있다.
- Swift/RustBridge memory ownership과 error reporting 정책이 포함되어 있다.
- 실제 구현을 위한 follow-up issue로 쪼갤 수 있는 단위가 표시되어 있다.

### 커밋 메시지

```text
Task #391 Stage 3: external image ABI 후보 설계
```

## Stage 4. Swift/macOS shell 책임 경계 설계

### 목표

Quick Look, Thumbnail, HostApp에서 filename/external resource context를 수집하고 RustBridge에 넘기는 책임 경계를 설계한다.

### 대상

- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `mydocs/working/task_m020_391_stage4.md`

### 작업

1. Quick Look Preview와 Thumbnail extension이 문서 URL, file data, display filename을 얻는 방식을 비교한다.
2. HostApp/WKWebView와 future native viewer에서 파일 접근 및 external resource resolver가 달라지는 지점을 분리한다.
3. sandbox, security-scoped resource, package-relative path, sibling file lookup, network path 금지 정책을 정리한다.
4. RustBridge에 전달할 context object의 Swift API 후보를 설계한다.
5. missing external image를 Swift renderer에서 placeholder/fallback으로 그릴지, core render tree diagnostic으로 표현할지 판단 기준을 제안한다.
6. #390 Skia policy, #404 measurement 결과, #391 ABI 설계가 만나는 rollout sequence를 정리한다.

### 검증

```bash
rg -n "Quick Look|Thumbnail|HostApp|sandbox|security scope|resource resolver|filename context|file access|diagnostic|placeholder|Skia|#390|#404" \
  mydocs/working/task_m020_391_stage4.md
git diff --check
```

### 완료 조건

- surface별 파일 접근 책임과 금지 경로가 분리되어 있다.
- Swift wrapper API 후보와 RustBridge C ABI 후보의 mapping이 정리되어 있다.
- 구현 전에 필요한 upstream/core 선행 조건과 downstream-only 가능 작업이 분리되어 있다.

### 커밋 메시지

```text
Task #391 Stage 4: macOS external resource 책임 경계 설계
```

## Stage 5. 후속 이슈 초안과 최종 보고서

### 목표

조사 결과를 최종 보고서로 정리하고, 실제 downstream 적용 작업을 후속 이슈 단위로 나눈다.

### 대상

- `mydocs/report/task_m020_391_report.md`
- `mydocs/orders/20260705.md`
- 필요 시 GitHub issue draft text

### 작업

1. Stage 1-4 결과를 current state, upstream dependency, recommended ABI, Swift responsibility, rollout order로 요약한다.
2. 후속 이슈 후보를 implementation, fixture/test, upstream coordination, Quick Look/Thumbnail policy로 분리한다.
3. #387, #390, #404와 중복되거나 선행/후행 관계가 있는 항목을 표시한다.
4. 오늘할일의 #391 상태를 완료 대기 상태로 갱신한다.
5. 최종 검증 결과와 잔여 리스크를 기록한다.

### 검증

```bash
rg -n "#391|filename|external|BinData|C ABI|Swift wrapper|Quick Look|Thumbnail|후속|residual|#387|#390|#404" \
  mydocs/report/task_m020_391_report.md mydocs/orders
git diff --check
git status --short
```

### 완료 조건

- #391 최종 보고서가 있고 실제 구현 follow-up을 등록할 수 있는 수준의 초안이 있다.
- 현재 downstream에서 바로 적용 가능한 작업과 upstream/core 변경 대기 작업이 구분되어 있다.
- 작업지시자 승인 후 final report 절차 또는 PR 게시 절차로 넘길 수 있다.

### 커밋 메시지

```text
Task #391 Stage 5 + 최종 보고서: external image ABI 설계 정리
```

## 승인 요청 사항

이 구현계획서 승인 후 Stage 1 `현재 app ABI와 image data 계약 inventory`를 시작한다.
