# Issue #144 Stage 5 보고서

## 단계 목적

Stage 1-4의 조사, 구현, smoke 검증 결과를 최종 보고 직전 상태로 정리한다. 오늘할일 문서의 현재 상태를 갱신하고, 작업지시자가 후속 이슈로 분리하기로 한 `Finder drag/drop 원본 URL 확보` 항목을 현재 작업 범위 밖의 잔여 항목으로 기록한다.

## 산출물

- `mydocs/orders/20260505.md`
  - #144 상태와 비고를 현재 진행 단계에 맞게 갱신
  - `Finder drag/drop 원본 URL 확보`를 백로그 항목으로 기록
- `mydocs/working/task_m010_144_stage5.md`
  - Stage 5 문서 정리 보고서

## 본문 변경 정도 / 본문 무손실 여부

- 앱 소스 변경 없음
- 리소스 변경 없음
- 문서 2개만 변경
- 기존 단계 보고서, 수행계획서, 구현계획서는 수정하지 않음

## 정리 결과

### 현재 완료된 단계

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행 계획 | `b39e697` | #144 수행계획서와 오늘할일 등록 |
| 구현 계획 | `2ad96c6` | 구현 단계와 검증 기준 정리 |
| Stage 1 | `3c73e61` | drag/drop 로드 경로와 toolbar validation 기준 조사 |
| Stage 2 | `255bdef` | injected bridge와 Swift coordinator 사이 `dropped-document` message 추가 |
| Stage 3 | `4d6b651` | dropped document를 source-less store 상태로 연결하고 AppKit toolbar validation refresh 추가 |
| Stage 4 | `5dd3d43` | Debug app smoke로 toolbar 활성 상태 확인 |

### 수용 기준 반영 상태

| 수용 기준 | 상태 | 근거 |
|-----------|------|------|
| `git diff --check` 통과 | OK | Stage 2-4 및 Stage 5 문서 작성 전 검증 통과 |
| Debug HostApp build 성공 | OK | Stage 4 `xcodebuild ... HostApp ... build` 성공 |
| drag/drop HWP 로드 후 문서 표시 | OK | `exam_social.hwp — 4페이지` 표시 확인 |
| drag/drop HWP 로드 후 `공유` enabled | OK | Stage 4 접근성 트리에서 enabled 확인 |
| drag/drop HWP 로드 후 `PDF로 내보내기` enabled | OK | Stage 4 접근성 트리에서 enabled 확인 |
| source-less drag/drop에서 `Finder에서 보기` disabled | OK | Stage 4 접근성 트리에서 disabled 확인 |
| native open 경로 toolbar 회귀 없음 | OK | `exam_science.hwp` native open에서 세 toolbar item 모두 enabled 확인 |
| HWPX 저장 제한 정책 유지 | 부분 확인 | HWPX source code 경로는 변경하지 않았지만 별도 HWPX drag/drop smoke는 미실행 |

### 후속 이슈 분리

작업지시자 확인에 따라 `Finder drag/drop 원본 URL 확보`는 현재 #144의 완료 조건에서 제외하고 후속 이슈로 분리한다.

현재 #144의 정책:

- Web `File` 기반 drag/drop은 파일명과 bytes만 신뢰한다.
- source-less dropped document는 `공유`와 `PDF로 내보내기`를 활성화한다.
- 원본 URL이 없는 상태이므로 `Finder에서 보기`는 disabled로 유지한다.
- source URL을 확보한 native open 경로에서는 `Finder에서 보기`를 enabled로 유지한다.

후속 이슈 후보 구현 방향:

- `WKWebView` wrapper 또는 상위 `NSView`에서 `NSDraggingDestination`을 구현한다.
- Finder drop pasteboard에서 file URL을 확보한다.
- 지원 확장자이면 `DocumentViewerStore.loadDocument(from:)`로 native open 경로를 사용한다.
- URL 확보 실패 또는 bytes-only drop은 현재 source-less bridge 경로로 fallback한다.

## 검증 결과

Stage 5에서 실행한 명령:

```bash
git status --short --branch -uall
```

초기 결과:

```text
## local/task144
```

Stage 5 문서 변경 후 실행할 검증:

```bash
git diff --check
```

## 잔여 위험

- HWPX drag/drop toolbar smoke는 아직 별도 실행하지 않았다. 최종 보고 전 통합 검증에서 `Sources/HostApp/Resources/sample.hwpx` 또는 `samples/hwpx/*.hwpx` 중 하나로 toolbar 상태만 추가 확인할 수 있다.
- `Finder에서 보기`를 drag/drop에서도 enabled로 만드는 요구는 후속 이슈로 분리했다. 현재 PR에는 source-less drop 정책만 포함해야 한다.
- share picker와 PDF export panel의 실제 완료까지는 Stage 4에서 클릭 검증하지 않았다. 이번 작업의 직접 목표는 toolbar enabled state 회귀 수정이다.

## 다음 단계 영향

최종 보고 단계에서 다음 파일과 결과를 요약한다.

- 변경 파일: HostApp source 4개, 단계 보고서 5개, 오늘할일 문서
- 검증: Debug build, drag/drop smoke, native open smoke, whitespace check
- 후속 작업: Finder drag/drop 원본 URL 확보

## 승인 요청

Stage 5 문서 정리를 완료했다. 최종 보고서 작성, 오늘할일 완료 처리, `publish/task144` PR 게시 단계로 진입하려면 작업지시자 승인이 필요하다.
