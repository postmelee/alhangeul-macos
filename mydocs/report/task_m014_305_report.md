# Task M014 #305 최종 보고서 - CoreGraphics 복학원서 PUA 표시 최소 보정

## 작업 요약

- 이슈: [#305 CoreGraphics preview에서 복학원서.hwp PUA 표시 최소 보정](https://github.com/postmelee/alhangeul-macos/issues/305)
- 마일스톤: M014 `v0.1.4 Native Preview/Viewer Parity`
- 브랜치: `local/task305`
- 기준 브랜치: `devel`
- 단계 수: 계획/구현 포함 4단계

`samples/복학원서.hwp`를 Quick Look preview와 Finder thumbnail로 볼 때 CoreGraphics 경로에서 PUA 문자가 깨져 보이는 문제를 최소 범위로 보정했다.

최종 결과는 다음과 같다.

- `CGTreeRenderer`의 CoreText 문자열 생성 직전에 display text helper를 추가했다.
- `U+F012B`는 `(인)`으로 표시한다.
- `U+F081C`는 화면에 그리지 않는다.
- source/display text 길이가 달라지는 경우 `charPositions`를 nil로 처리한다.
- Quick Look/Thumbnail 기본 `.coreGraphicsOnly` 정책과 Skia opt-in 진단 경로는 변경하지 않았다.
- QLExtension/ThumbnailExtension Debug build와 대표 샘플 render smoke가 통과했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | 확인된 PUA 두 codepoint를 CoreGraphics display text로 보정하고, display text 기준으로 CoreText line/layout을 생성 |
| `mydocs/orders/20260531.md` | #305 진행/완료 상태 기록 |
| `mydocs/plans/task_m014_305.md` | 수행계획서 |
| `mydocs/plans/task_m014_305_impl.md` | 구현계획서 |
| `mydocs/working/task_m014_305_stage1.md` | `복학원서.hwp` render tree PUA inventory와 renderer 소비 지점 확인 |
| `mydocs/working/task_m014_305_stage2.md` | CoreGraphics PUA 보정 구현과 보정 전/후 렌더 확인 |
| `mydocs/working/task_m014_305_stage3.md` | extension build, 정책 유지, 대표 샘플 smoke 결과 |
| `mydocs/report/task_m014_305_report.md` | 최종 보고서 |

## 변경 전·후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| `U+F012B` 서명란 표시 | fallback glyph/tofu | `(인)` |
| `U+F081C` filler 표시 | 하단 안내문 앞 깨진 사각형 2개 | 표시 안 함 |
| Quick Look 단일 PNG backend | `.coreGraphicsOnly` | 변경 없음 |
| Quick Look 다중 PDF backend | `.coreGraphicsOnly` | 변경 없음 |
| Finder Thumbnail backend | `renderFirstPage` 기본 `.coreGraphicsOnly` | 변경 없음 |
| Skia opt-in 경로 | helper/diagnostic 유지 | 변경 없음 |

render tree에서 확인한 대상 run:

| id | codepoints | bbox | 판단 |
|---:|---|---|---|
| 119 | `U+F012B` (`983339`) | `x=367.6333, y=585.4874, w=27.0, h=14.6667` | 서명란 `(인)` 의도 |
| 235 | `U+F081C`, `U+F081C` (`985116`, `985116`) | `x=56.6933, y=793.6533, w=0.0, h=283.9467` | TAC filler, 숨김 의도 |

## 단계별 결과

| 단계 | 결과 |
|------|------|
| 계획 | #305 수행계획서와 오늘할일 등록 |
| Stage 1 | `복학원서.hwp` render tree에서 `U+F012B`, `U+F081C` run을 확인하고 `CGTreeRenderer`가 `run.text`를 그대로 소비하는 지점 확인 |
| Stage 2 | `CGTreeRenderer`에 display text helper 추가, 일반/centered text run 모두 보정 문자열 사용 |
| Stage 3 | `복학원서.hwp`, `hwp-multi-001.hwp`, `exam_eng.hwp` render smoke와 QLExtension/ThumbnailExtension Debug build 통과 |
| Stage 4 | 최종 보고서와 release handoff 정리 |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `./scripts/check-no-appkit.sh` | OK | `Sources/RhwpCoreBridge` AppKit/UIKit 의존 없음 |
| `swiftc -parse-as-library -typecheck ... CGTreeRenderer.swift` | OK | Swift source typecheck 통과 |
| `./scripts/render-debug-compare.sh build.noindex/task305-stage2 samples/복학원서.hwp` | OK | 보정 후 native PNG에서 `(인)` 표시와 filler 숨김 확인 |
| `./scripts/render-debug-compare.sh build.noindex/task305-stage3 samples/복학원서.hwp samples/hwp-multi-001.hwp samples/exam_eng.hwp` | OK | 대표 샘플 3개 page 1 render smoke 통과 |
| `rg -n "policy: \\.coreGraphicsOnly|skiaOptIn|renderFirstPage|HwpThumbnailRenderCache" ...` | OK | Quick Look/Thumbnail 기본 정책 유지 확인 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension ... build` | OK | sandbox 밖 재실행 기준 `** BUILD SUCCEEDED ** [13.605 sec]` |
| `xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension ... build` | OK | `** BUILD SUCCEEDED ** [1.676 sec]` |
| `git diff --check` | OK | 공백 오류 없음 |

참고: 첫 sandbox 내부 `xcodebuild`는 Sparkle package resolve 중 `github.com` DNS 접근 제한으로 실패했다. 동일 명령을 sandbox 밖에서 재실행해 통과했다.

`render-debug-compare.sh`의 `LAYOUT_OVERFLOW` 2건은 Stage 1 baseline과 동일한 기존 `복학원서.hwp` layout warning이다.

## Release Handoff

#305가 `devel`에 merge되면 v0.1.4 release artifact는 다시 생성해야 한다. 이미 만들어 둔 draft v0.1.4 signed/notarized DMG는 #305 수정이 들어가기 전 산출물이므로, #301은 다음 순서로 이어가는 것이 맞다.

1. #305 PR merge
2. #301 release 브랜치/계획에서 #305 반영 사실 기록
3. `devel -> main` release PR 또는 main tag 기준을 #305 merge 이후 commit으로 재정렬
4. `v0.1.4` tag와 draft signed/notarized DMG 재생성
5. public signed/notarized DMG 설치 smoke에서 `samples/복학원서.hwp` Quick Look/Thumbnail PUA 보정 확인
6. smoke 통과 후 공식 publish 진행

## 잔여 위험과 후속 작업

| 항목 | 상태 |
|------|------|
| CoreGraphics 임시 보정 유지보수 | 확인된 두 codepoint만 처리하도록 제한했다. 장기적으로는 PageLayerTree `displayText` 소비로 전환하는 것이 맞다. |
| PageLayerTree/Skia 기본 전환 | 이번 범위 아님. #258/#259 계열 M20 흐름에서 cache signature와 visual/performance gate를 포함해 처리한다. |
| Quick Look UI cache | 설치본 smoke 전 `qlmanage -r`, `qlmanage -r cache`, Finder/QuickLookUIService 재시작이 필요할 수 있다. |
| signed/notarized DMG | 이번 범위 아님. #301에서 새 artifact로 다시 검증해야 한다. |

## PR 공유용 요약

- CoreGraphics text renderer에서 `복학원서.hwp`의 `U+F012B`를 `(인)`으로 표시하고 `U+F081C` filler를 숨기도록 최소 보정했다.
- 보정 문자열과 원문 길이가 달라지면 원문 기준 `charPositions`를 재사용하지 않게 했다.
- Quick Look/Thumbnail 기본 `.coreGraphicsOnly` 정책과 Skia opt-in 경로는 변경하지 않았다.
- `복학원서.hwp`/대표 샘플 render smoke, QLExtension/ThumbnailExtension Debug build가 통과했다.

## 작업지시자 승인 요청

#305 구현과 최종 보고서 작성은 완료됐다. 다음 단계는 `publish/task305` 원격 브랜치 push와 `devel` 대상 Open PR 생성이다.

