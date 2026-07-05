# Task M020 #404 구현계획서

수행계획서: `mydocs/plans/task_m020_404.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #404 `upstream 렌더 PR 대표 샘플 diff 측정`
- 추적 이슈: #387 Preview/Thumbnail Skia readiness 후속 개선 추적
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task404`
- 목표: upstream `edwardkim/rhwp` 최근 렌더 PR의 대표 샘플을 기준으로 core SVG, render tree JSON, Swift native PNG, Skia PNG 가능 여부를 비교하고 downstream 보정 후보를 증거 기반으로 분류한다.

## 구현 원칙

- #404는 측정과 판단 기록 작업이다. 제품 renderer, bridge ABI, Skia default 정책은 변경하지 않는다.
- upstream `devel` 변경 자체를 알한글 release default로 pin하지 않는다. unreleased commit 기준 샘플은 "관찰 대상"으로만 취급한다.
- 저장소에 없는 upstream 샘플은 바로 `samples/`에 편입하지 않는다. 장기 fixture 편입 필요성은 최종 보고서 또는 후속 이슈 후보로 분리한다.
- visual diff 숫자 하나로 결론을 내리지 않는다. hard fail은 구조 누락, blank/fallback, page size/aspect ratio, missing image data, glyph/clip, transform, RawSvg fallback 여부를 우선 본다.
- Quick Look과 Finder Thumbnail은 같은 renderer contract를 일부 공유하지만 rollout 판단은 surface별로 분리한다.
- GitHub 조회, upstream sample 확보, live repo 확인이 필요한 단계는 네트워크 의존 작업으로 분리해 기록한다.

## 측정 후보 축

| 축 | 관련 upstream PR | downstream 확인 포인트 |
|----|------------------|------------------------|
| RawSvg/차트 | `edwardkim/rhwp#1890`, `edwardkim/rhwp#1453` 계열 | 일반 SVG vector 또는 chart SVG가 Swift `RawSvg` fallback으로 떨어지는지 확인 |
| Group/shape/transform | `edwardkim/rhwp#1905` | group-level matrix/schema 적응이 필요한지, 자식 bbox/transform이 평탄화되어 내려오는지 확인 |
| external/large image data | `edwardkim/rhwp#1913`, `#1924`, `#1917`, `#1930` | `ImageNode.bin_data_id`와 `rhwp_image_data` 계약, external context ABI 필요성 확인 |
| text/equation/font/clip/endnote | `edwardkim/rhwp#1881`, `#1911`, `#1875`, `#1926`, `#1919`, `#1912`, `#1895` | CoreText clip, equation SVG parser, font fallback, footnote/endnote ordering 차이 확인 |
| page geometry baseline | `edwardkim/rhwp#1936`, `#1935`, `#1928`, `#1927`, `#1894`, `#1887`, `#1886`, `#1878`, `#1873`, `#1867` | core update만으로 자동 반영될 좌표/page count 계열 기준 확인 |

## Stage 1. upstream PR와 샘플 후보 inventory

### 목표

측정 후보 축별로 upstream PR, 변경 파일, 샘플/fixture 경로, 알한글 측 입력 가능성을 하나의 표로 정리한다.

### 대상

- `mydocs/working/task_m020_404_stage1.md`
- `mydocs/plans/task_m020_404_impl.md`
- upstream PR metadata
- 알한글 `samples/`와 기존 M020 report/tech 문서

### 작업

1. 관련 upstream PR의 title/body/files를 조회해 렌더 영향과 샘플 파일 경로를 추출한다.
2. PR별 sample path가 upstream repo에 존재하는지, binary fixture인지, PDF oracle 포함 여부를 분류한다.
3. 알한글 저장소에 이미 같은 샘플 또는 동등한 샘플이 있는지 확인한다.
4. 샘플 후보를 `즉시 측정 가능`, `upstream checkout 필요`, `fixture 편입 후보`, `권위 PDF만 참고`, `측정 제외`로 분류한다.
5. Stage 2에서 사용할 1차 sample set과 Stage 3 이후 보류 sample set을 제안한다.

### 검증

```bash
gh pr view 1890 --repo edwardkim/rhwp --json number,title,body,files,url
gh pr view 1905 --repo edwardkim/rhwp --json number,title,body,files,url
gh pr view 1913 --repo edwardkim/rhwp --json number,title,body,files,url
gh pr view 1924 --repo edwardkim/rhwp --json number,title,body,files,url
gh pr view 1881 --repo edwardkim/rhwp --json number,title,body,files,url
gh pr view 1875 --repo edwardkim/rhwp --json number,title,body,files,url
rg -n "issue1892|issue1891|issue1835|chart|endnote|equation|KTX|복학원서|hwp-multi|hwpx-01" \
  samples mydocs/report mydocs/tech
git diff --check
```

### 완료 조건

- 후보 축별 upstream PR와 샘플 후보가 Stage 1 보고서에 정리되어 있다.
- 즉시 측정 가능한 샘플과 upstream checkout 또는 fixture 편입이 필요한 샘플이 분리되어 있다.
- Stage 2에서 실행할 최소 측정 sample set 후보가 제안되어 있다.

### 커밋 메시지

```text
Task #404 Stage 1: upstream 렌더 샘플 후보 inventory
```

## Stage 2. 측정 명령과 산출물 형식 확정

### 목표

Stage 1 sample set을 실제 알한글 비교 도구에 연결할 명령, output directory, summary table 형식을 확정한다.

### 대상

- `scripts/render-debug-compare.sh`
- `scripts/smoke-quicklook-skia-policy.sh`
- `scripts/smoke-thumbnail-skia-policy.sh`
- `scripts/preview-visual-diff-harness.sh`
- `mydocs/working/task_m020_404_stage2.md`

### 작업

1. `render-debug-compare.sh`의 필수 산출물과 optional `qlmanage` raster diff 실패 조건을 정리한다.
2. Quick Look/Thumbnail Skia policy smoke가 Stage 1 sample set에 적용 가능한지 확인한다.
3. `preview-visual-diff-harness.sh`가 rhwp-studio reference를 요구하는 샘플과 그렇지 않은 샘플을 분리한다.
4. output directory와 filename convention을 고정한다.
5. 후보 축별 측정표 template을 Stage 2 보고서에 작성한다.

### 검증

```bash
./scripts/render-debug-compare.sh --help
./scripts/smoke-quicklook-skia-policy.sh --help
./scripts/smoke-thumbnail-skia-policy.sh --help
./scripts/preview-visual-diff-harness.sh --help
test -f Frameworks/universal/librhwp.a
test -f Frameworks/modulemap/module.modulemap
git diff --check
```

### 완료 조건

- `build.noindex/task404-*` 산출물 위치가 확정되어 있다.
- 각 후보 축의 필수 산출물과 선택 산출물이 구분되어 있다.
- Stage 3 실행 명령이 그대로 복사해 실행 가능한 형태로 정리되어 있다.

### 커밋 메시지

```text
Task #404 Stage 2: 렌더 diff 측정 명령 확정
```

## Stage 3. 대표 샘플 diff 실행

### 목표

대표 샘플군의 core SVG, render tree JSON, Swift native PNG, 가능한 경우 Skia PNG 또는 visual diff 결과를 생성하고 hard fail을 분류한다.

### 대상

- `build.noindex/task404-render-debug/`
- `build.noindex/task404-quicklook-policy/`
- `build.noindex/task404-thumbnail-policy/`
- 필요 시 `build.noindex/task404-visual-cg/`
- 필요 시 `build.noindex/task404-visual-skia/`
- `mydocs/working/task_m020_404_stage3.md`

### 작업

1. Stage 2에서 확정한 대표 샘플에 대해 `render-debug-compare.sh`를 실행한다.
2. Quick Look/Thumbnail policy smoke가 가능한 샘플에 대해 CoreGraphics와 Skia opt-in 결과를 측정한다.
3. rhwp-studio reference가 의미 있는 샘플은 visual diff harness를 추가 실행한다.
4. summary에서 page size, render tree bytes, core SVG bytes, native non-white pixels, text/glyph 통계, diff ratio, backend/fallback을 추출한다.
5. hard fail을 후보 축별로 분류한다.

### 검증

```bash
./scripts/validate-stage3-render.sh
./scripts/render-debug-compare.sh build.noindex/task404-render-debug path/to/sample.hwp
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task404-quicklook-policy path/to/sample.hwp
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task404-thumbnail-policy path/to/sample.hwp
rg -n "NativeNonWhitePixels|CoreSVGBytes|RenderTreeJSONBytes|Diff:|DiffReason|backend|fallback|failed=0|OK" \
  build.noindex/task404-render-debug build.noindex/task404-quicklook-policy \
  build.noindex/task404-thumbnail-policy mydocs/working/task_m020_404_stage3.md
git diff --check
```

### 완료 조건

- 대표 샘플별 필수 산출물 생성 여부가 보고서에 기록되어 있다.
- hard fail과 환경/optional raster 실패가 분리되어 있다.
- Skia/CoreGraphics 차이가 후속 판단 가능한 수준으로 요약되어 있다.

### 커밋 메시지

```text
Task #404 Stage 3: 대표 샘플 렌더 diff 측정
```

## Stage 4. downstream 보정 후보와 후속 이슈 분리안

### 목표

Stage 3 측정 결과를 바탕으로 어떤 축이 자동 반영인지, Skia 전환 후보인지, Swift CoreGraphics 보강 대상인지 분류한다.

### 대상

- `mydocs/working/task_m020_404_stage4.md`
- 필요 시 `mydocs/tech/skia_quicklook_thumbnail_backend.md`

### 작업

1. 후보 축별 측정 결과를 `자동 반영`, `Skia 전환 후보`, `Swift CoreGraphics 보강 필요`, `upstream 대기/별도 조사`로 분류한다.
2. 후속 이슈 후보를 생성 단위로 나눈다.
3. #387, #390, #391 등 기존 M020 이슈와 중복 여부를 확인한다.
4. 장기 fixture 편입이 필요한 sample을 별도 test-assets 후보로 분리한다.
5. 필요한 경우 기술 문서에 #404 결과 요약 링크를 추가할지 판단한다.

### 검증

```bash
gh issue list --repo postmelee/alhangeul-macos --state open \
  --search "RawSvg chart transform external image equation clip Skia" \
  --limit 30 --json number,title,state,milestone,labels,url
rg -n "자동 반영|Skia 전환 후보|Swift CoreGraphics 보강 필요|upstream 대기|후속 이슈|#387|#390|#391" \
  mydocs/working/task_m020_404_stage4.md
git diff --check
```

### 완료 조건

- 각 후보 축의 분류와 근거가 Stage 4 보고서에 있다.
- 새 이슈가 필요한 항목과 기존 이슈에 연결할 항목이 분리되어 있다.
- fixture 편입 후보와 임시 산출물 보관 정책이 정리되어 있다.

### 커밋 메시지

```text
Task #404 Stage 4: downstream 보정 후보 분류
```

## Stage 5. 최종 보고서와 PR 준비

### 목표

측정 결과, 후속 권고, residual risk를 최종 보고서에 정리하고 PR 게시 준비를 한다.

### 대상

- `mydocs/report/task_m020_404_report.md`
- `mydocs/orders/20260705.md` 또는 실제 완료일 orders 파일
- 필요 시 `mydocs/report/assets/task_m020_404/`

### 작업

1. Stage 1-4 결과를 요약한 최종 보고서를 작성한다.
2. 후속 이슈 생성이 필요한 경우 제목/본문 초안을 보고서에 남기고 작업지시자 승인 대상으로 분리한다.
3. 오늘할일 상태를 완료로 갱신한다.
4. 최종 검증 명령을 실행한다.
5. publish branch와 PR 생성 준비 상태를 확인한다.

### 검증

```bash
git diff --check
rg -n "#404|RawSvg|Group|external|text/equation|page geometry|후속|residual" \
  mydocs/report/task_m020_404_report.md mydocs/orders
git status --short
```

### 완료 조건

- 최종 보고서가 #404 목표와 산출물을 모두 닫는다.
- 후속 구현 이슈 후보가 근거와 함께 정리되어 있다.
- 작업트리가 PR 게시 가능한 상태다.

### 커밋 메시지

```text
Task #404 Stage 5 + 최종 보고서: upstream 렌더 diff 측정 정리
```
