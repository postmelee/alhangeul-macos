# Task #90 Stage 4 완료 보고서 - 검증과 후속 조치 자료 정리

## 단계 목적

Stage 1-3에서 확인한 `복학원서.hwp` page 1 layout overflow 조사 결과를 최종 보고서로 통합하고, 앱 저장소에서 즉시 수정하지 않을 항목과 후속 추적 이슈를 명확히 분리한다.

## 산출물

| 산출물 | 경로 | 비고 |
|--------|------|------|
| 최종 보고서 | `mydocs/report/task_m010_90_report.md` | #90 전체 결론, 검증, 후속 작업 정리 |
| 오늘할일 갱신 | `mydocs/orders/20260429.md` | #90 완료 상태와 완료 시각 기록 |
| Stage 4 보고서 | `mydocs/working/task_m010_90_stage4.md` | 본 문서 |
| 후속 GitHub Issue | `https://github.com/postmelee/alhangeul-macos/issues/94` | PR #81 전후 core pin A/B 비교 분리 |

제품 source code 변경은 없다. Stage 4는 Investigation PR 성격의 조사 결과 보존과 후속 작업 분리가 목적이다.

## 정리 결과

### 1. #90 결론

`복학원서.hwp` page 1의 하단 table/text overflow는 앱 Quick Look/View/Thumbnail 표시 계층의 clip 누락 문제가 아니라 `rhwp` core layout/render tree/SVG 산출 문제로 결론낸다.

근거:

- render tree JSON에서 body clip bottom `1084.7pt` 아래에 table/text run이 배치된다.
- core SVG도 같은 좌표 구조를 포함한다.
- Swift `CGTreeRenderer`는 `Body.clip_rect`와 `TableCell.clip`을 적용한다.
- native PNG는 body clip 아래 non-white pixel이 없다.
- page-level clip을 Quick Look shared renderer에 임시 적용해도 baseline PNG와 byte 단위로 동일했다.

### 2. upstream 추적

별도 upstream 신규 이슈를 만들기보다, 이미 열린 `edwardkim/rhwp` #421을 같은 계열 문제로 추적한다.

- upstream: `https://github.com/edwardkim/rhwp/issues/421`
- 제목: `복학원서.hwp BehindText 그림 후속 본문 문단 배치가 한컴과 다름`
- 메인테이너가 워터마크 효과 이미지 속성 구현과 맞물린 일련 작업으로 처리하겠다고 답변한 상태다.

### 3. 후속 #94 분리

사용자 관찰상 과거에는 하단이 조금 잘리는 정도였으나 현재는 오른쪽으로 크게 이동해 잘려 보인다는 차이가 있다. 이 변화는 PR #81의 core pin 변경과 시점이 맞지만, old core bridge 재빌드 기반 pre/post 비교는 #90 범위를 넘는다.

따라서 다음 후속 이슈를 생성했다.

- `#94 PR #81 전후 rhwp core pin 복학원서.hwp 렌더 회귀 A/B 비교`
- URL: `https://github.com/postmelee/alhangeul-macos/issues/94`
- 목적: core pin `1e9d78a1d40c71779d81c6ec6870cd301d912626`와 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`를 같은 조건에서 렌더링해 증상 악화 도입 구간을 확정한다.

### 4. #84/#85 clip 판단

HostApp Viewer의 page bounds clip은 view containment 관점의 무해한 안전장치로 유지할 수 있다. 다만 #90의 문제처럼 layout 좌표 자체가 core에서 잘못 산출된 경우에는 clip이 정상 배치를 만들지 않는다.

Quick Look shared renderer에 page-level clip을 추가하는 실험은 `복학원서.hwp` 산출물을 바꾸지 않았다. 따라서 #90 범위에서는 Quick Look clip 코드를 추가하지 않는다.

## 검증 결과

Stage 4 계획서의 검증 명령을 실행했다.

```bash
git status --short --branch
git diff --check
./scripts/validate-stage3-render.sh /tmp/rhwp-task90-stage4-render-smoke
```

결과 요약:

```text
## local/task90
git diff --check 통과
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=449097
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53220
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=108 hangulRuns=71 hangulScalars=1203 nonWhitePixels=159757
```

## 잔여 위험

- PR #81 전후 core pin 변경이 증상 악화의 직접 원인인지는 #94에서 old bridge 재빌드 후 확정해야 한다.
- upstream #421이 해결되기 전까지 `복학원서.hwp`의 본문 배치 차이는 앱 저장소에서 근본 수정할 수 없다.
- core SVG는 clip 정보를 포함하므로 단순 화면 캡처만으로는 layout 좌표 문제를 설명하기 어렵다. upstream 공유 시 render tree/SVG 좌표 근거를 함께 제시해야 한다.

## 다음 단계 영향

#90은 조사 완료로 최종 보고서와 함께 PR을 게시할 수 있다. 본 증상 자체의 core 수정은 upstream #421, 회귀 도입 구간 확정은 #94에서 추적한다.

## 승인 요청

Stage 4 완료와 최종 보고서 검토를 요청한다. 승인 후 `publish/task90` 원격 브랜치 push와 devel 대상 draft PR 생성을 진행한다.
