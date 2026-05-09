# Task M018 #199 최종 결과 보고서

## 작업 요약

- 이슈: [#199](https://github.com/postmelee/alhangeul-macos/issues/199) 공식 릴리즈 Finder thumbnail 생성 hang 수정
- 마일스톤: M018 / `v0.1.1`
- 통합 대상: `devel-webview`
- 작업 브랜치: `local/task199`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task199`

공식 `v0.1.0` 설치본에서 HWP/HWPX thumbnail 생성이 60초 이상 응답하지 않는 문제를 재현했고, 원인을 Thumbnail extension의 CoreGraphics 렌더 경로에서 회색조 색 변환과 concurrent bitmap rendering이 겹치는 hang으로 분리했다. 수정은 thumbnail worker 직렬화와 RGB direct color setter 적용으로 완료했다.

## 재현 결과

정리 후 설치본은 `/Applications/Alhangeul.app` 하나였고, PluginKit도 공식 Thumbnail extension을 활성 상태로 보고했다.

공식 설치본 기준 `qlmanage -t`는 PNG를 만들지 못했고, unified log에 `Generation ... took more than 60 seconds to reply`가 기록됐다.

멈춘 stack의 핵심 경로:

```text
HwpThumbnailRenderCache.renderedPage
-> HwpPageImageRenderer.renderPage
-> CGContextFillRect
-> CGColorTransformConvertColorComponents
-> CGCMSConverterCreateCachedCGvImageConverter
-> __psynch_mutexwait
```

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | thumbnail worker queue를 serial queue로 변경 |
| `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | QL drawing/fallback 색 설정을 RGB direct setter로 변경 |
| `Sources/Shared/HwpPageImageRenderer.swift` | bitmap page background fill을 RGB direct setter로 변경 |
| `Sources/Shared/HwpPreviewPDFRenderer.swift` | PDF page background fill을 RGB direct setter로 변경 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | page/open shape white fill을 RGB direct setter로 변경 |
| `mydocs/plans/task_m018_199.md` | 수행계획서 |
| `mydocs/plans/task_m018_199_impl.md` | 구현계획서 |
| `mydocs/working/task_m018_199_stage1.md` | 공식 설치본 재현/진단 |
| `mydocs/working/task_m018_199_stage2.md` | 최소 수정 구현 보고 |
| `mydocs/working/task_m018_199_stage3.md` | Debug/Release smoke 검증 |
| `mydocs/report/task_m018_199_report.md` | 최종 결과 보고 |
| `mydocs/orders/20260509.md` | #199 진행 상태 갱신 |

`project.yml`, `Alhangeul.xcodeproj`, `rhwp-core.lock`, `Frameworks/Rhwp.xcframework`는 수정하지 않았다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `rg -n "CGColor\\(gray:" Sources` | 출력 없음 |
| Debug `CODE_SIGNING_ALLOWED=NO` build | 성공 |
| Release `CODE_SIGNING_ALLOWED=NO` build | 성공 |
| Debug 임시 등록본 HWP thumbnail | PNG 생성, `177 x 256` |
| Debug 임시 등록본 HWPX thumbnail | PNG 생성, `182 x 256` |
| Release 임시 등록본 HWP thumbnail | PNG 생성, `177 x 256` |
| Release 임시 등록본 HWPX thumbnail | PNG 생성, `182 x 256` |
| Release forced UTI HWP thumbnail | PNG 생성, `177 x 256` |
| `git diff --check` | 통과 |

실행한 주요 검증 명령:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/DerivedDataRelease CODE_SIGNING_ALLOWED=NO build
qlmanage -t -x -s 256 -o /private/tmp/alhangeul-qlrelease-smoke2/hwp samples/exam_science.hwp
qlmanage -t -x -s 256 -o /private/tmp/alhangeul-qlrelease-smoke2/hwpx samples/hwpx/hwpx-01.hwpx
git diff --check
```

## 현재 설치 상태

임시 테스트 설치본 `/Users/melee/Applications/Alhangeul.app`은 제거했다. 현재 시스템 등록은 공식 설치본만 가리킨다.

```text
/Applications/Alhangeul.app
Path = /Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
Parent Bundle = /Applications/Alhangeul.app
```

단, 공식 `/Applications/Alhangeul.app` `v0.1.0`에는 이번 수정이 포함되어 있지 않다. 현재 Finder에서 thumbnail이 계속 보이지 않는 것은 캐시/중복 설치 문제가 아니라 `v0.1.0` 설치본의 제품 결함으로 보는 것이 맞다. 실제 사용자 환경에서 해결하려면 #199가 merge된 뒤 #188 `v0.1.1` signed/notarized 패치 설치본으로 교체해야 한다.

## #188 release handoff

[#188](https://github.com/postmelee/alhangeul-macos/issues/188) `v0.1.1 patch release 준비와 public 배포 실행`에서 다음 smoke를 signed/notarized DMG 설치본으로 반복한다.

1. `/Applications/Alhangeul.app`이 `v0.1.1` 이상인지 확인한다.
2. `pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension` 경로가 `/Applications/Alhangeul.app`인지 확인한다.
3. `qlmanage -r && qlmanage -r cache`를 실행한다.
4. `qlmanage -t -x -s 256 -o <tmp>/hwp samples/exam_science.hwp`가 PNG를 생성하는지 확인한다.
5. `qlmanage -t -x -s 256 -o <tmp>/hwpx samples/hwpx/hwpx-01.hwpx`가 PNG를 생성하는지 확인한다.
6. Finder icon view에서 같은 샘플의 thumbnail이 표시되는지 확인한다.
7. unified log에 `took more than 60 seconds to reply`가 재발하지 않는지 확인한다.

## 잔여 위험

- 임시 smoke는 ad-hoc signed 로컬 빌드로 수행했다. 최종 사용자 경로는 #188에서 Developer ID signing/notarization된 DMG로 다시 검증해야 한다.
- Thumbnail extension sandbox에서 parent app의 bundled font resource read deny 로그가 관찰된다. 이번 thumbnail PNG 생성에는 치명적이지 않았지만, font fallback 품질 이슈가 남을 수 있어 별도 타스크로 분리하는 것이 적절하다.

## PR 게시 전 상태

`local/task199`에는 구현, 단계 보고서, 최종 보고서가 커밋 대상이다. 승인 후 `publish/task199` 브랜치를 게시하고 `devel-webview` 대상으로 PR을 생성한다.
