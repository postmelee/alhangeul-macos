# Task M015 #119 구현 계획서

수행계획서: `mydocs/plans/task_m015_119.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #119 오픈 라이선스 한글 폰트 번들 및 폰트 대체 정책 도입
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 기준 브랜치: `devel-webview`
- 작업 브랜치: `local/task119`
- 작업 위치: `/private/tmp/rhwp-mac-task119`
- 주 대상: Quick Look/Thumbnail이 공유하는 Swift native render 경로
- 참고 자산: `Sources/HostApp/Resources/rhwp-studio/fonts`
- 목표: `rhwp-studio`의 폰트/alias 정책을 reference로 삼아 Swift native renderer의 HWP 폰트 fallback을 번들 오픈 라이선스 폰트 중심으로 개선한다.

## 구현 원칙

- HostApp viewer는 별도 작업에서 WKWebView 기반으로 진행 중이므로, 이번 구현의 주 사용자 영향은 Quick Look preview와 Finder thumbnail로 한정한다.
- `rhwp-studio`의 DOM/CSS/WebFont 구조를 Swift로 복제하지 않는다. 폰트 목록, alias 정책, 라이선스 판단만 reference로 삼는다.
- 기존 `rhwp-studio` WOFF2 자산을 먼저 재사용 가능성 관점에서 검증한다.
- CoreText가 WOFF2를 직접 등록하지 못하면 중복을 최소화한 native용 TTF/OTF resource 경로로 전환한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 직접 의존을 추가하지 않는다.
- 폰트 등록 실패, resource 누락, PostScript name 불일치는 crash가 아니라 기존 시스템 fallback으로 이어져야 한다.
- proprietary font 파일은 포함하지 않고, proprietary HWP font name은 오픈 라이선스 fallback family로만 매핑한다.
- 산출 PNG/SVG/JSON은 저장소에 커밋하지 않고, 단계 보고서에 경로와 핵심값만 기록한다.

## Stage 1. 폰트 자산과 native 등록 가능성 조사

### 목표

- `rhwp-studio` 번들 폰트 목록과 라이선스 문서를 기준으로 native renderer에서 재사용할 수 있는 후보를 확정한다.
- CoreText가 WOFF2 파일을 process-local font로 등록할 수 있는지 실제로 검증한다.
- HostApp resource와 app extension resource 경계에서 Quick Look/Thumbnail이 접근 가능한 배치 전략을 정한다.

### 작업

- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`와 실제 WOFF2 파일 목록을 비교한다.
- `project.yml`의 HostApp/QLExtension/ThumbnailExtension resource 포함 구조를 확인한다.
- 작은 검증 스니펫 또는 Swift one-off 실행으로 `CTFontManagerRegisterFontsForURL`의 WOFF2 등록 성공 여부와 등록된 PostScript name을 확인한다.
- `FontFallback.swift`의 현재 alias 매핑과 `rhwp-studio` fallback 문서의 차이를 정리한다.
- `mydocs/tech/font_fallback_strategy.md`를 신규 산출물로 만들지, `FONTS.md`와 보고서만으로 충분한지 판단한다.
- Stage 2에서 쓸 resource 전략을 `WOFF2 직접 재사용`, `TTF/OTF 별도 추가`, `최소 subset 추가` 중 하나로 확정한다.

### 예상 변경 파일

- `mydocs/working/task_m015_119_stage1.md`

### 검증

```bash
git status --short --branch
rg --files | rg 'fonts|woff2|ttf|otf|FONTS.md'
sed -n '1,220p' Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md
sed -n '1,140p' Sources/RhwpCoreBridge/FontFallback.swift
sed -n '1,120p' project.yml
find Sources -maxdepth 3 -type d | sort
git diff --check
```

### 완료 기준

- WOFF2 직접 재사용 가능 여부가 근거와 함께 기록된다.
- Quick Look/Thumbnail extension에서 사용할 font resource 배치 전략이 확정된다.
- Stage 2 구현 범위와 폰트 subset 후보가 정리된다.

### 커밋 메시지

```text
Task #119 Stage 1: 폰트 자산과 native 등록 가능성 조사
```

## Stage 2. 공통 폰트 등록 구조와 resource 배치 구현

### 목표

- HostApp, Quick Look, Thumbnail이 같은 font registration 정책을 쓰도록 공통 helper를 추가한다.
- Stage 1에서 확정한 resource 전략에 맞게 font 파일을 app/extension bundle에 포함한다.

### 작업

- process-local font registration helper를 설계한다.
- helper 위치를 `Sources/RhwpCoreBridge` 또는 `Sources/Shared` 중 하나로 확정하고, AppKit/UIKit/WebKit 의존이 없도록 구현한다.
- WOFF2 직접 재사용이 가능하면 `rhwp-studio/fonts` 또는 공유 resource lookup 경로를 extension에서도 안전하게 찾도록 보강한다.
- WOFF2 직접 재사용이 불가하면 native용 TTF/OTF subset resource를 추가하고 `project.yml`에 HostApp/QLExtension/ThumbnailExtension resource 포함을 반영한다.
- 동일 process에서 중복 등록을 피하기 위한 idempotent guard를 둔다.
- 등록 실패 시 diagnostic은 남기되 rendering은 기존 fallback으로 계속 진행되게 한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/FontFallback.swift`
- 필요 시 `Sources/RhwpCoreBridge/FontResourceRegistry.swift`
- 필요 시 `Sources/Shared/*Font*.swift`
- 필요 시 native font resource 디렉터리
- 필요 시 `project.yml`
- `mydocs/working/task_m015_119_stage2.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge Sources/Shared project.yml
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- 공통 font registration helper가 추가된다.
- app과 extension target에서 font resource가 compile/link 단계에 포함된다.
- AppKit/UIKit 직접 의존 금지 검증이 통과한다.

### 커밋 메시지

```text
Task #119 Stage 2: 공통 폰트 등록과 resource 배치 구현
```

## Stage 3. HWP font alias 매핑과 CoreText 선택 정책 보강

### 목표

- HWP 문서에서 자주 등장하는 proprietary font family를 번들 오픈 라이선스 폰트 또는 시스템 fallback으로 일관되게 매핑한다.
- #120 텍스트 advance 보정과 충돌하지 않도록 `CGTreeRenderer`의 font 선택 경로를 안정화한다.

### 작업

- HWP font family normalization helper를 추가한다.
- `함초롬돋움`, `함초롬바탕`, `한컴돋움`, `한컴바탕`, `돋움`, `바탕`, `굴림`, `궁서`, `HY*`, `Malgun Gothic`, `Nanum*`, `D2Coding` 계열 alias를 정리한다.
- regular/bold/italic 요청 시 PostScript name 직접 선택과 CoreText synthetic trait 적용 순서를 결정한다.
- 등록된 번들 폰트가 없을 때 시스템 폰트로 내려가는 fallback chain을 명시한다.
- `resolveAppleFont`와 `mapHWPFontToApple`의 이름/책임이 실제 정책과 맞지 않으면 최소 범위에서 정리한다.
- Equation 또는 marker 렌더링의 기존 font 선택이 의도치 않게 바뀌지 않는지 확인한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/FontFallback.swift`
- 필요 시 `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `mydocs/tech/font_fallback_strategy.md`
- `mydocs/working/task_m015_119_stage3.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/FontFallback.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task119-stage3-hongbo samples/20250130-hongbo.hwp
test -s /private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-summary.txt
sed -n '1,180p' /private/tmp/rhwp-task119-stage3-hongbo/20250130-hongbo-page1-summary.txt
git diff --check
```

### 완료 기준

- 주요 HWP font family가 문서화된 번들/system fallback chain으로 해석된다.
- `20250130-hongbo.hwp` 기준 native render 산출물이 생성된다.
- 기존 equation/marker font 경로 회귀 여부가 보고서에 기록된다.

### 커밋 메시지

```text
Task #119 Stage 3: HWP font alias 매핑 보강
```

## Stage 4. Quick Look/Thumbnail 중심 렌더 검증과 회귀 확인

### 목표

- 변경된 font fallback이 Quick Look/Thumbnail 공통 bitmap 경로에서 실제로 적용되는지 확인한다.
- M015 대표 샘플과 font-sensitive 샘플에서 #120 이후 텍스트 위치 보정이 회귀하지 않는지 확인한다.

### 작업

- `samples/20250130-hongbo.hwp`, `samples/basic/BookReview.hwp`, `samples/복학원서.hwp` render smoke를 수행한다.
- `render-debug-compare.sh`로 font-sensitive 샘플의 summary와 native PNG를 생성한다.
- 가능하면 release/debug app bundle 기준으로 Quick Look preview와 Thumbnail smoke를 실행한다.
- extension resource lookup 실패, missing glyph, font registration 실패 로그가 있는지 확인한다.
- Stage 1 기준과 변경 후 결과의 차이를 보고서에 정리한다.

### 예상 변경 파일

- 필요 시 `Sources/RhwpCoreBridge/FontFallback.swift`
- 필요 시 `Sources/Shared/*Font*.swift`
- `mydocs/working/task_m015_119_stage4.md`

### 검증

```bash
git status --short --branch
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task119-stage4-smoke samples/basic/BookReview.hwp samples/복학원서.hwp samples/20250130-hongbo.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task119-stage4-hongbo samples/20250130-hongbo.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task119-stage4-book samples/basic/BookReview.hwp
./scripts/check-no-appkit.sh
git diff --check
```

환경이 허용될 때 추가 실행:

```bash
qlmanage -r
qlmanage -r cache
qlmanage -t -x -s 512 -o /tmp/alhangeul-task119-thumbnail samples/20250130-hongbo.hwp
```

### 완료 기준

- 대표 샘플 render smoke가 통과한다.
- font-sensitive 샘플의 native PNG와 summary가 보고서에 기록된다.
- Quick Look/Thumbnail extension resource 적용 여부가 확인되거나, 환경성 한계가 분리 기록된다.

### 커밋 메시지

```text
Task #119 Stage 4: Quick Look 폰트 렌더 검증
```

## Stage 5. 라이선스 문서화와 최종 정리

### 목표

- public release 전에 font resource provenance와 fallback 정책을 문서화한다.
- 최종 보고서와 오늘할일을 정리하고 PR 전 상태를 만든다.

### 작업

- 추가된 font resource가 있으면 출처, 라이선스, 파일 목록, 대체 대상 HWP font family를 문서화한다.
- WOFF2를 그대로 재사용한 경우에도 WebView 자산과 native renderer 사용 범위를 명확히 기록한다.
- `FontFallback.swift`가 참조하는 `mydocs/tech/font_fallback_strategy.md`가 필요하면 신규 작성한다.
- 최종 build/smoke 명령을 실행한다.
- `mydocs/orders/20260503.md`의 #119 행을 완료 상태로 갱신한다.
- 최종 보고서에 변경 파일, 검증 결과, 잔여 리스크, 후속 #109 연결점을 정리한다.

### 예상 변경 파일

- 필요 시 `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`
- 필요 시 `mydocs/tech/font_fallback_strategy.md`
- `mydocs/working/task_m015_119_stage5.md`
- `mydocs/report/task_m015_119_report.md`
- `mydocs/orders/20260503.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task119-final-smoke samples/basic/BookReview.hwp samples/복학원서.hwp samples/20250130-hongbo.hwp
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- font fallback 정책과 font resource provenance가 문서화된다.
- 최종 smoke/build 결과가 보고서에 기록된다.
- 오늘할일이 완료 상태로 갱신된다.
- PR 게시 전 미커밋 변경이 없다.

### 커밋 메시지

```text
Task #119 Stage 5 + 최종 보고서: 폰트 fallback 정책 정리
```
