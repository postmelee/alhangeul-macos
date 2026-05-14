# Task M010 #243 Stage 5 완료보고서

## 단계 목적

창 닫기와 앱 종료 저장 확인 기능을 통합 검증하고, 최종 보고서와 오늘할일 완료 상태를 정리한다.

## 산출물

- `mydocs/working/task_m010_243_stage5.md`
  - Stage 5 통합 검증 결과 기록.
- `mydocs/report/task_m010_243_report.md`
  - Task #243 최종 보고서 작성.
- `mydocs/orders/20260514.md`
  - #243 상태를 `완료`로 갱신.

## 검증 환경

- worktree: `/Users/melee/Documents/projects/rhwp-mac`
- branch: `local/task243`
- Debug app: `build.noindex/DerivedDataTask243/Build/Products/Debug/Alhangeul.app`
- UI smoke sample: `KTX.hwp`
- UI 조작 도구: Computer Use

## 자동 검증 결과

```bash
./scripts/check-no-appkit.sh
```

- 결과: 성공. `OK: shared Swift code has no AppKit/UIKit dependencies`

```bash
xcodegen generate
```

- 결과: 성공. `Alhangeul.xcodeproj`가 `project.yml` 기준으로 재생성됨.

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- sandbox 실행 결과: 새 DerivedData 경로의 Sparkle SwiftPM fetch가 `github.com` DNS 제한으로 실패.
- 승인 경로 재실행 결과: `** BUILD SUCCEEDED ** [12.179 sec]`
- 참고: Xcode CoreSimulator version 경고가 출력되었지만 macOS HostApp build는 성공했다.

```bash
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataTask243/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

- 결과: 둘 다 성공. source asset과 Debug app bundle asset 검증 통과.

```bash
rg -n "Task M010 #243|#243|저장되지 않은|저장하지 않음|applicationShouldTerminate|windowShouldClose|hasUnsavedChanges|document-edited" \
  Sources/HostApp mydocs/orders/20260514.md mydocs/plans/task_m010_243.md mydocs/plans/task_m010_243_impl.md mydocs/working mydocs/report
```

- 결과: dirty state, WebView edited bridge, 창 닫기 guard, app termination hook, 단계 문서 연결 지점 확인.

```bash
git diff --check
git status --short --branch
```

- 문서 작성 전 기준 결과: whitespace error 없음, worktree clean.

## UI smoke 결과

Computer Use로 Debug app을 실행해 다음을 확인했다.

1. `KTX.hwp` 문서를 열고 본문에 실제 입력 이벤트를 발생시켜 dirty 상태를 만들었다.
2. `Command+Q` 실행 시 `변경사항을 저장할까요?` sheet가 표시되고 `저장`, `저장하지 않음`, `취소` 버튼이 노출됨을 확인했다.
3. 앱 종료 sheet에서 `취소`를 선택하면 sheet가 사라지고 문서 창이 유지됨을 확인했다.
4. 다시 `Command+Q`를 실행한 뒤 `저장하지 않음`을 선택하면 앱이 종료됨을 확인했다.
5. 문서를 다시 열고 dirty 상태를 만든 뒤 창 닫기 버튼을 누르면 동일한 저장 확인 sheet가 표시됨을 확인했다.
6. 창 닫기 sheet에서 `취소`를 선택하면 문서 창이 유지됨을 확인했다.
7. 다시 창 닫기 버튼을 누른 뒤 `저장하지 않음`을 선택하면 문서 창이 닫힘을 확인했다.
8. smoke 중 생성된 Debug app 프로세스는 `build.noindex/DerivedDataTask243` 경로의 프로세스만 확인 후 종료했다.

## 직접 확인하지 않은 항목

- `저장` 버튼으로 원본 `KTX.hwp`를 덮어쓰는 경로는 실행하지 않았다. smoke 문서가 최근 문서로 로드된 실제 샘플 파일이어서, 저장 성공을 누르면 source sample에 변경이 기록될 수 있기 때문이다.
- 저장 completion API와 저장 실패/취소 분기는 Stage 3/4 build와 코드 경로 검증으로 확인했고, 실제 저장 성공 후 닫기/종료는 후속 별도 temp 문서 smoke로 보강할 수 있다.
- dirty 문서 2개 이상의 순차 종료 확인은 이번 UI smoke에서 수행하지 않았다. `DocumentTerminationCoordinator`의 순차 처리 경로는 build와 코드 경로 검색으로 확인했다.

## 완료 판단

- dirty state bridge, 창 닫기 저장 확인, 앱 종료 저장 확인이 모두 컴파일되고 Debug app에서 핵심 sheet 흐름이 동작한다.
- `취소`는 창 닫기와 앱 종료를 중단한다.
- `저장하지 않음`은 창 닫기와 앱 종료를 계속 진행한다.
- source sample 파일에는 저장 변경을 남기지 않았고, smoke 후 worktree는 clean 상태를 유지했다.

## 잔여 위험

- `저장` 선택 후 실제 저장 성공까지 이어지는 UI smoke는 별도 temp 문서로 보강 필요하다.
- 여러 dirty 문서의 순차 sheet 표시 순서는 실제 multi-window foreground smoke로 보강하면 더 확실하다.
- dirty signal은 입력 이벤트 중심의 보수적 감지다. 모든 `rhwp-studio` 편집 command를 완전하게 의미 분석하지는 않는다.

## 다음 단계 영향

Task #243 구현과 통합 검증은 완료되었다. 작업지시자 승인 후 최종 커밋을 기준으로 게시 브랜치/PR 절차를 진행할 수 있다.
