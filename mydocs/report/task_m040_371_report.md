# Task M040 #371 최종 결과보고서

## 작업 요약

| 항목 | 값 |
|------|----|
| GitHub Issue | [#371](https://github.com/postmelee/alhangeul-macos/issues/371) |
| 마일스톤 | M040 (`v0.4`) |
| 작업 브랜치 | `local/task371` |
| 기준 브랜치 | `devel` |
| 단계 수 | 3단계 |
| 목적 | HWP 3.0 문서가 HostApp 열기 사전 검증과 bundled Studio URL byte guard에서 미지원 파일로 차단되는 문제 수정 |

제보 샘플 `/Users/melee/Documents/projects/forks/rhwp/samples/hwp3-sample16.hwp`는 `HWP Document File V3.00` header를 가진 HWP 3.0 문서이며, 현재 `devel`에 동기화된 `rhwp v0.7.17` core는 이 파일을 page 64개 문서로 parse/render할 수 있다. 이번 작업은 core가 처리할 수 있는 HWP 3.0 문서를 HostApp의 Swift validator와 bundled `rhwp-studio` URL byte guard가 사전에 차단하지 않도록 두 guard를 보강했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/Shared/HwpDocumentInputValidator.swift` | `HWP Document File V3.` ASCII prefix를 `hwp3MagicPrefix`로 추가하고, 지원 문서 signature 판정에 포함했다. 기존 HWP5 CFB magic, HWPX ZIP magic, 빈 문서/미지원 문서 오류 문구는 유지했다. |
| `Sources/HostApp/Resources/rhwp-studio/assets/index-B-NDEaFR.js` | bundled Studio minified asset의 URL byte kind guard에서 HWP5 CFB 또는 HWP 3.0 prefix이면 `hwp`로 분류하도록 보강했다. HWPX/HTML/unknown 판정 순서는 유지했다. |
| `mydocs/plans/task_m040_371.md` | 수행계획서. 원인, 범위, 제외 항목, 검증 계획을 기록했다. |
| `mydocs/plans/task_m040_371_impl.md` | 구현계획서. Stage 1~3의 변경 파일, 검증 명령, 완료 기준을 기록했다. |
| `mydocs/working/task_m040_371_stage1.md` | Swift validator 변경과 HostApp build 검증 결과를 기록했다. |
| `mydocs/working/task_m040_371_stage2.md` | bundled Studio URL byte guard 변경과 asset syntax/build 검증 결과를 기록했다. |
| `mydocs/orders/20260624.md` | #371 작업을 등록하고 완료 처리했다. |
| `mydocs/report/task_m040_371_report.md` | 최종 결과보고서. |

## 변경 전·후 정량 비교

| 항목 | 결과 |
|------|------|
| Swift 코드 변경 | `HwpDocumentInputValidator.swift` 4 insertions, 1 deletion |
| Studio asset 변경 | `index-B-NDEaFR.js` minified 1줄 치환, 1 insertion/1 deletion |
| 계획/보고 문서 | 수행계획 91 lines, 구현계획 153 lines, Stage 1 보고 78 lines, Stage 2 보고 78 lines |
| 전체 task diff | 최종 보고서 작성 전 기준 7 files changed, 412 insertions, 2 deletions |
| HWP 3.0 샘플 렌더 smoke | page 1 render tree/SVG/native PNG 생성, `PageCount: 64`, `PageSizePt: 793.7x1122.5` |

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | Swift `HwpDocumentInputValidator`가 `HWP Document File V3.` prefix를 지원 문서 signature로 허용하도록 수정 |
| Stage 2 | bundled `rhwp-studio` URL byte guard가 HWP 3.0 prefix를 `hwp`로 분류하도록 수정 |
| Stage 3 | HostApp build, bundled resource, HWP 3.0 sample render smoke를 통합 검증하고 최종 결과보고서와 오늘할일 완료 처리를 반영 |

## 검증 결과

| 검증 항목 | 결과 | 비고 |
|-----------|------|------|
| `git status --short --branch` | OK | Stage 3 시작 시 `local/task371...origin/devel [ahead 4]`, 미커밋 변경 없음 |
| `git diff --check` | OK | whitespace 오류 없음 |
| `node --check Sources/HostApp/Resources/rhwp-studio/assets/index-B-NDEaFR.js` | OK | bundled Studio asset syntax check 통과 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | OK | `** BUILD SUCCEEDED ** [8.800 sec]` |
| `test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/index.html` | OK | built app에 Studio resource 포함 |
| wasm asset count test | OK | `rhwp_bg-CljGnRKH.wasm` 1개 확인 |
| built app Studio guard 확인 | OK | built app resource의 `index-B-NDEaFR.js`에 HWP 3.0 prefix byte array 포함 |
| `./scripts/render-debug-compare.sh /private/tmp/alhangeul-hwp3-sample16-task371-conflict --page 1 /Users/melee/Documents/projects/forks/rhwp/samples/hwp3-sample16.hwp` | OK | `devel` 충돌 해결 후 render tree, core SVG, native PNG, diff PNG 생성 |

## 실행하지 않은 항목

이번 task에서는 다음 항목을 실행하지 않았다.

- Debug 앱 foreground 세션에서 사용자가 보는 실제 WebView 로드 화면 수동 확인
- 기존 HWP5/HWPX 샘플의 앱 UI 수동 열기 확인
- PDF 또는 텍스트 파일을 앱 UI에서 열었을 때의 오류 화면 수동 확인
- #372 범위인 실패 후 WebView 보존/재시도 모달 UX 변경
- upstream `rhwp-studio` source 재빌드 또는 동기화

## 잔여 위험과 후속 작업

- `Sources/HostApp/Resources/rhwp-studio/assets/index-B-NDEaFR.js`는 minified bundled asset이다. 향후 `rhwp-studio`를 upstream dist로 다시 동기화하면 이번 URL byte guard 보강이 사라질 수 있으므로, Studio sync 작업에서 HWP 3.0 guard를 다시 확인해야 한다.
- 이번 변경은 `HWP Document File V3.` prefix만 허용한다. HWP 2.x 또는 signature가 다른 legacy 변형은 계속 지원 대상으로 보지 않는다.
- core가 제보 샘플을 렌더링할 수 있음은 확인했지만, 모든 HWP 3.x 문서의 렌더링 품질을 보장하지는 않는다.
- 실패 후 창 전체가 비활성화되는 UX는 이번 task 범위가 아니며 #372에서 별도 처리한다.

## 커밋 목록

```text
bd25852 Task #371: 수행계획서 작성과 오늘할일 갱신
759f6af Task #371: 구현 계획서 작성
f39ce67 Task #371 Stage 1: HWP 3.0 Swift 입력 검증 허용
56e1c4c Task #371 Stage 2: Studio URL guard에서 HWP 3.0 허용
3a514a8 Task #371 Stage 3 + 최종 보고서: HWP 3.0 HostApp 열기 검증 보강 완료
```

`devel` 충돌 해결 커밋은 본 보고서의 asset/core 버전 갱신과 함께 생성한다.

## 작업지시자 승인 요청

PR #373 충돌 해결 후 `publish/task371` 원격 브랜치에 push하고 `devel` 대상 PR 상태를 재확인한다.
