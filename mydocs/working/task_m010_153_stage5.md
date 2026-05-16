# Task #153 Stage 5 보고서

## 단계 목적

Task #153의 구현, 단계 보고서, 검증 결과를 최종 보고서와 PR 작성 직전 상태로 정리한다. 이번 단계는 소스 동작을 변경하지 않고 문서와 진행 상태만 정리한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m010_153_stage5.md` | 최종 보고 및 PR 준비 상태 정리 |
| `mydocs/orders/20260506.md` | Task #153 상태를 Stage 5 보고 승인 대기로 갱신 |

## 현재 커밋 범위

`devel-webview..local/task153` 기준 커밋은 다음과 같다.

| 커밋 | 내용 |
|------|------|
| `0b29dc1` | Task #153 Stage 4: Finder drag toolbar smoke 검증 |
| `8adc536` | Task #153 Stage 3: native drag URL store 연결 |
| `cb68b49` | Task #153 Stage 2: native file URL drop callback 추가 |
| `c19ea96` | Task #153 Stage 1: native drag URL 경로 조사 |
| `f3c14ad` | Task #153: 구현 계획서 작성 |
| `a608908` | Task #153: 수행 계획서 작성과 오늘할일 갱신 |

## 구현 요약

| 파일 | 변경 요약 |
|------|----------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `WKWebView` subclass에서 Finder file URL drag pasteboard를 읽고, 지원 확장자 HWP/HWPX URL을 native callback으로 전달한다. native URL drop 직후 같은 파일명의 JS `dropped-document` fallback이 source-less 문서로 덮어쓰지 않도록 짧은 중복 억제 상태를 둔다. |
| `Sources/HostApp/Views/DocumentViewerView.swift` | `RhwpStudioWebView`의 native drop callback을 `DocumentViewerStore.loadDocument(from:)` 경로로 연결한다. 이 경로를 통해 `sourceDocument`, 최근 문서, `Finder에서 보기` 정책을 기존 native open과 동일하게 사용한다. |

## 검증 결과 요약

| 항목 | 결과 |
|------|------|
| `git diff --check` | 통과 |
| `scripts/check-no-appkit.sh` | 통과, shared Swift code에 AppKit/UIKit 의존 없음 |
| HostApp Debug build | 통과, `** BUILD SUCCEEDED **` |
| Finder drag/drop HWP | 통과, toolbar `공유`, `Finder에서 보기`, `PDF로 내보내기` 모두 enabled |
| Finder에서 보기 실행 | 통과, Finder selection이 `/private/tmp/rhwp-task153-drag/task153_unique.hwp`를 가리킴 |
| native open HWP | 통과, toolbar 세 항목 모두 enabled |
| native open HWPX | 통과, toolbar 세 항목 모두 enabled |

## 미실행 항목과 잔여 위험

| 항목 | 상태 | 비고 |
|------|------|------|
| source-less JS/File drop fallback UI smoke | 미실행 | Finder drag/drop은 native URL 경로로 선점되므로 별도 source-less UI 재현을 하지 못했다. 기존 fallback 코드는 유지했다. |
| HWPX Finder drag/drop UI smoke | 미실행 | HWPX는 native open 경로만 확인했다. native pasteboard 필터는 HWP/HWPX를 동일하게 허용한다. |
| duplicate guard 정책 | 잔여 위험 | 현재는 normalized filename과 짧은 시간 창으로 같은 사용자 drop의 JS fallback 덮어쓰기를 억제한다. 동일 파일명을 연속 drop하는 특수 케이스는 후속 관찰 대상이다. |
| Finder drag smoke 재현성 | 잔여 위험 | 창이 겹쳐 실제 drop target이 앱 window가 아니면 문서 로드가 발생하지 않는다. 검증 시에는 Finder와 앱 창을 분리 배치해 성공을 확인했다. |

## PR 준비 상태

| 항목 | 값 |
|------|----|
| 작업 브랜치 | `local/task153` |
| PR 게시 브랜치 | `publish/task153` 예정 |
| 대상 통합 브랜치 | `devel-webview` |
| 최종 보고서 | `mydocs/report/task_m010_153_report.md` 예정 |
| GitHub Issue | `#153` |

## 검증 명령

실행 명령:

```bash
git diff --check
git log --oneline devel-webview..local/task153
```

결과:

- `git diff --check`는 출력 없이 성공했다.
- `git log --oneline devel-webview..local/task153`에서 Stage 1부터 Stage 4까지의 커밋과 계획서 커밋이 확인되었다.

## 다음 단계 영향

다음 승인이 내려지면 최종 보고서 `mydocs/report/task_m010_153_report.md`를 작성하고, 오늘할일을 완료 상태로 갱신한 뒤 최종 커밋, `publish/task153` push, `devel-webview` 대상 PR 생성을 진행한다.

## 승인 요청

Stage 5 문서 정리와 PR 준비 상태 점검을 완료했다. 이 보고서 기준으로 최종 보고서 작성 및 PR 게시 단계에 진입할지 승인 요청한다.
