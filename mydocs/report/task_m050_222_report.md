# Task M050 #222 최종 결과 보고서

## 작업 요약

- GitHub Issue: [#222](https://github.com/postmelee/alhangeul-macos/issues/222)
- 마일스톤: M050 / v0.5
- 작업명: rhwp v0.7.11 기준 Swift native renderer parity gap 정리와 따라잡기
- 작업 브랜치: `local/task222`
- 기준 브랜치: `devel` `341ad56`
- 단계 수: 5단계(최종 보고 포함)

`samples/복학원서.hwp`의 Quick Look preview와 thumbnail 공통 native renderer에서 `BehindText` 이미지가 문서 본문 위에 그려지거나 일부 이미지가 보이지 않는 문제를 수정했다.

중앙 워터마크는 render tree의 page-level `Image`가 `text_wrap: "BehindText"`인데도 body 뒤에 그려지는 z-order 문제였다. 좌상단 로고는 render tree에는 존재하지만 `bin_data_id=1`이 PCX라서 `CGImageSource`가 직접 decode하지 못해 native renderer에서 누락되던 문제였다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/RenderTree.swift` | `ImageNode.textWrap` 디코딩 추가 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | page-level/nested `BehindText` draw order 보정, PCX fallback decode 추가 |
| `mydocs/orders/20260516.md` | #222 작업 상태 관리 |
| `mydocs/plans/task_m050_222.md` | 수행계획서 |
| `mydocs/plans/task_m050_222_impl.md` | 구현계획서 |
| `mydocs/working/task_m050_222_stage1.md` | Stage 1 보고서 |
| `mydocs/working/task_m050_222_stage2.md` | Stage 2 보고서 |
| `mydocs/working/task_m050_222_stage3.md` | Stage 3 보고서 |
| `mydocs/working/task_m050_222_stage4.md` | Stage 4 보고서 |
| `mydocs/report/task_m050_222_report.md` | 최종 결과 보고서 |

## 단계별 결과

### Stage 1. `text_wrap`와 draw order 책임 범위 확정

- `복학원서.hwp` 중앙 워터마크가 page top-level `Image(id 84)`이고 `text_wrap: "BehindText"`임을 확인했다.
- 좌상단 로고도 `Body > Column` 내부 `Image(id 7)`이며 `text_wrap: "BehindText"`임을 확인했다.
- Swift `ImageNode`에 `text_wrap` 디코딩이 없고, `CGTreeRenderer`가 raw child order를 따라 그리는 구조가 원인임을 분리했다.

### Stage 2. `BehindText` 이미지 렌더 패스 구현

- `ImageNode.textWrap` 필드를 추가했다.
- page render pass를 `PageBackground -> page-level BehindText image -> foreground children` 순서로 분리했다.
- foreground pass에서 이미 그린 page-level `BehindText` 이미지는 중복 렌더하지 않도록 제외했다.

### Stage 3. `복학원서.hwp` visual/debug smoke 검증

- `render-debug-compare`로 `복학원서.hwp` native PNG를 생성했다.
- 중앙 워터마크가 page-level `BehindText` pass로 body/table/text보다 먼저 그려지는 것을 확인했다.
- 흑백/GrayScale/effect 차이는 사용자가 제외한 upstream parity 문제로 유지했다.
- `hwp-img-001.hwp` smoke로 non-`BehindText` 이미지 순서가 기존 경로에 남는 것을 확인했다.

### Stage 4. nested `BehindText` 로고와 PCX fallback 보정

- 좌상단 로고가 render tree에서 누락된 것이 아니라 PCX bin data decode 실패로 빠지는 문제임을 확인했다.
- `CGImageSource` decode를 우선 사용하고, 실패 시 PCX fallback decoder를 사용하도록 보정했다.
- 손상 PCX가 extension 프로세스를 크래시시키지 않도록 row length, 지원 layout, decoded/pixel buffer 상한 검증을 추가했다.
- `Column` 내부 nested `BehindText` 이미지는 같은 column foreground보다 먼저 그리도록 순서를 보정했다.
- `복학원서.hwp` native PNG에서 좌상단 로고가 보이는 것을 확인했다.

### Stage 5. 최종 정리와 보고

- 최종 결과 보고서를 작성했다.
- `mydocs/orders/20260516.md`의 #222 상태를 완료로 갱신했다.
- PR 게시 전 승인 요청 상태로 정리했다.

## 변경 전·후 정량 비교

- Stage 4까지 누적 diff: 9 files changed, 908 insertions, 6 deletions
- 최종 단계 추가 산출물: 최종 결과 보고서 105 lines, 오늘할일 완료 처리
- source 변경: 2 files
- 계획/보고 문서: 수행계획서 1개, 구현계획서 1개, 단계 보고서 4개, 최종 보고서 1개
- 검증 산출물:
  - `/private/tmp/rhwp-bokhak-watermark-task222-stage4-final`
  - `/private/tmp/rhwp-task222-image-smoke-stage4`

## 검증 결과

| 검증 | 결과 |
|------|------|
| `git diff --check` | 통과 |
| `./scripts/check-no-appkit.sh` | 통과 |
| Swift renderer typecheck | 통과 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-bokhak-watermark-task222-stage4-final --page 1 samples/복학원서.hwp` | 통과 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task222-image-smoke-stage4 --page 1 samples/hwp-img-001.hwp` | 통과 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | 통과 |

Xcode build는 sandbox 내 SwiftPM/clang cache 권한 문제로 최초 실패했고, 동일 명령을 권한 상승으로 재실행해 성공했다. 빌드 중 CoreSimulator out-of-date 경고는 macOS target 빌드 결과에는 영향을 주지 않았다.

## 수용 기준

- `text_wrap: "BehindText"`가 Swift render tree 모델에 보존됨: OK
- 중앙 page-level 워터마크가 본문/table/text pass보다 먼저 그려짐: OK
- 좌상단 nested `BehindText` 로고가 preview/thumbnail 공통 renderer에서 보임: OK
- PCX fallback은 ImageIO 실패 시에만 적용되어 기존 JPEG/PNG 경로를 유지함: OK
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 없음: OK

## 잔여 위험과 후속 작업

- 중앙 워터마크는 아직 앱 native renderer에서 검게 보인다. 이는 `GrayScale`, `brightness`, `contrast` effect parity가 rhwp-studio 최신과 맞지 않는 문제이며, 이번 task 범위에서 제외했다.
- PCX fallback은 이번 샘플에서 확인된 PCX 구조를 처리하도록 구현했다. 더 다양한 PCX 변형 문서는 후속 샘플 기반 검증이 필요하다.
- 하단 안내 문구 주변의 기존 layout overflow 진단은 계속 출력된다. 이번 작업의 z-order/image decode 수정과는 별개다.
- core/rhwp upstream 갱신 후 image effect parity가 들어오면 동일 샘플로 색상 차이를 다시 확인해야 한다.

## PR 준비 상태

- 수행 계획서: 작성 완료
- 구현 계획서: 작성 완료
- Stage 1-4 보고서: 작성 완료
- 최종 보고서: 작성 완료
- 오늘할일: 완료 처리
- source 검증과 HostApp build: 완료

PR 생성은 작업지시자 최종 승인 후 `publish/task222` 원격 브랜치로 push하고 통합 대상 브랜치 기준 draft PR로 진행한다.
