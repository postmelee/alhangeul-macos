# Task M015 #119 Stage 5 완료 보고서

## 단계 목적

Public release 전에 font resource provenance와 fallback 정책을 최종 문서화하고, 최종 smoke/build 결과와 PR 본문용 Before/After placeholder를 준비한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/tech/font_fallback_strategy.md` | native renderer font resource 출처, 사용 범위, extension resource reuse 정책 보강 |
| `mydocs/working/task_m015_119_stage5.md` | Stage 5 최종 정리/검증 결과 |
| `mydocs/report/task_m015_119_report.md` | #119 최종 보고서와 PR 본문 placeholder |
| `mydocs/orders/20260503.md` | #119 완료 상태 기록 |

## 문서 정리

`font_fallback_strategy.md`에 다음을 명시했다.

- 기준 자산 목록과 라이선스 설명의 원천은 `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`
- #119는 새 font 파일을 추가하지 않고 기존 WebView viewer용 WOFF2 34개를 native renderer에서 재사용
- Serif/Sans-serif/Monospace/Math-special 계열별 bundled font와 native fallback 사용처
- HostApp bundle에만 `rhwp-studio/fonts`를 포함하고, QLExtension/ThumbnailExtension은 parent app resource를 lookup하는 정책

## PR 본문 placeholder

사용자가 직접 GitHub PR 본문에 이미지를 첨부할 수 있도록 최종 보고서에 `## 스크린샷` 섹션용 placeholder를 넣었다.

현재 생성된 로컬 preview 이미지:

```text
/private/tmp/rhwp-task119-preview-compare/BookReview-before.png
/private/tmp/rhwp-task119-preview-compare/BookReview-after.png
/private/tmp/rhwp-task119-preview-compare/20250130-hongbo-before.png
/private/tmp/rhwp-task119-preview-compare/20250130-hongbo-after.png
/private/tmp/rhwp-task119-preview-compare/BookReview-before-after.png
/private/tmp/rhwp-task119-preview-compare/20250130-hongbo-before-after.png
```

이미지는 저장소에 커밋하지 않았다.

## 검증 결과

### AppKit/UIKit 경계

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### 기본 render smoke

```bash
./scripts/validate-stage3-render.sh
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452089 png=/private/tmp/rhwp-mac-task119/output/stage3-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67667 png=/private/tmp/rhwp-mac-task119/output/stage3-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=182000 png=/private/tmp/rhwp-mac-task119/output/stage3-render/exam_kor-page1.png
```

`exam_kor.hwp`에서 기존 layout overflow diagnostic이 출력됐지만 smoke 실패로 이어지지 않았다.

### 대표 샘플 render smoke

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task119-final-smoke \
  samples/basic/BookReview.hwp \
  samples/복학원서.hwp \
  samples/20250130-hongbo.hwp
```

결과:

```text
OK BookReview.hwp: page=1 size=794x1123 textRuns=66 hangulRuns=28 hangulScalars=209 nonWhitePixels=386919 png=/private/tmp/rhwp-task119-final-smoke/BookReview-page1.png
OK 복학원서.hwp: page=1 size=794x1123 textRuns=102 hangulRuns=25 hangulScalars=143 nonWhitePixels=261878 png=/private/tmp/rhwp-task119-final-smoke/복학원서-page1.png
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=91412 png=/private/tmp/rhwp-task119-final-smoke/20250130-hongbo-page1.png
```

`BookReview.hwp`에서 기존 layout overflow diagnostic이 출력됐지만 smoke 실패로 이어지지 않았다.

### Xcode project / Debug build

```bash
xcodegen generate
```

결과:

```text
Created project at /tmp/rhwp-mac-task119/AlhangeulMac.xcodeproj
```

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [6.009 sec]
```

sandbox 내부 `xcodebuild`는 generated `Frameworks/Rhwp.xcframework` 접근을 실패로 판정했으나, 동일 명령을 승인된 sandbox 외부 실행으로 검증해 성공했다.

### diff check

```bash
git diff --check
```

결과: 성공

## 잔여 위험

- GUI preview 창을 여는 `qlmanage -p`는 Stage 4 자동화 정책상 실행하지 않았다.
- before/after PNG는 `/private/tmp/rhwp-task119-preview-compare`에 생성된 로컬 산출물이며 저장소에는 커밋하지 않았다.
- #119는 font fallback 품질 보강이다. 도형 shadow, line arrow, dash, text shadow/rotation/vertical text 같은 스타일 parity는 후속 #109에서 다룬다.

## 다음 단계 영향

#109는 Swift native renderer 도형·텍스트 스타일 1차 parity 보강이다. #119에서 font registration과 fallback 체인을 안정화했으므로, #109에서는 같은 샘플에서 font 누락을 별도 변수로 두지 않고 도형/텍스트 스타일 누락을 좁혀볼 수 있다.
