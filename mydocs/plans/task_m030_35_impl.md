# Task M030 #35 구현 계획서

## 작업 개요

- 이슈: #35 Quick Look/Thumbnail 공통 group drawing 저해상도 렌더링 수정
- 마일스톤: `v0.3.0`
- 브랜치: `local/task35`
- 수행계획서: `mydocs/plans/task_m030_35.md`
- 목표: `group-drawing-02.hwp`의 Quick Look preview와 Finder thumbnail 공통 저해상도 렌더링 원인을 확인하고, 앱 저장소 소유 렌더링 경로에서 수정 가능한 문제를 보정한다.

## 구현 원칙

- `project.yml`을 Xcode project 원본으로 유지하고 `AlhangeulMac.xcodeproj`를 직접 수정하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다.
- `Vendor/rhwp`에는 임시 수정 커밋을 남기지 않는다.
- core 변경이 필요하다고 판단되면 앱 저장소 구현을 중단하고 core 이슈 또는 별도 작업으로 분리한다.
- Quick Look preview와 Thumbnail extension이 공유하는 첫 페이지 렌더링 경로를 우선 확인한다.

## 단계 계획

### Stage 1. 재현과 렌더링 경로 확인

- `group-drawing-02.hwp` 샘플 위치를 확인한다.
- embedded preview 품질 게이트가 해당 샘플에서 full render fallback으로 전환되는지 확인한다.
- `HwpPageImageRenderer`가 Quick Look preview와 Thumbnail에서 동일한 렌더링 결과를 만드는 경로를 추적한다.
- 결과물: `mydocs/working/task_m030_35_stage1.md`

### Stage 2. thumbnail 변경 이력과 embedded preview 정책 정리

- GitHub PR #23, #36과 `hwpql` 참고 구현을 확인한다.
- embedded preview fast path가 어떤 경로에 도입됐는지 확인한다.
- Finder PDF와 같은 동작을 목표로 Quick Look preview와 큰 Finder thumbnail은 직접 렌더링하고, 작은 Finder thumbnail에서만 embedded preview를 허용하는 정책을 확정한다.
- 결과물: `mydocs/working/task_m030_35_stage2.md`

### Stage 3. embedded preview 정책 구현

- `HwpPageImageRenderer`의 기본 경로는 embedded preview를 사용하지 않는 full render로 고정한다.
- `ThumbnailExtension`은 요청 픽셀 크기가 작은 경우에만 embedded preview fast path를 명시적으로 허용한다.
- 큰 Finder icon view와 Quick Look preview는 PDF처럼 요청 크기에 맞춰 직접 렌더한다.
- 결과물: `mydocs/working/task_m030_35_stage3.md`

### Stage 4. render tree와 Swift renderer 추가 분석

- `group-drawing-02.hwp`의 full render 결과가 여전히 낮은 품질이면 render tree에서 group/image/shape/text node 구조와 좌표, 크기, transform 정보를 확인한다.
- `RenderTree.swift` 디코딩 모델과 `CGTreeRenderer`의 group, image, shape 처리 누락 여부를 확인한다.
- core render tree 생성 문제인지 Swift renderer 해석 문제인지 1차 판정한다.
- 결과물: `mydocs/working/task_m030_35_stage4.md`

### Stage 5. 검증과 회귀 확인

- `./scripts/check-no-appkit.sh`를 실행한다.
- `./scripts/validate-stage3-render.sh`를 실행한다.
- 필요 시 `xcodegen generate`와 HostApp Debug build를 실행한다.
- Finder 통합 품질 확인이 필요하면 Release package smoke test 절차로 Quick Look preview와 thumbnail을 확인한다.
- 결과물: `mydocs/working/task_m030_35_stage5.md`

## 검증 기준

- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존이 없어야 한다.
- 기본 렌더링 smoke test가 통과해야 한다.
- `group-drawing-02.hwp`가 Quick Look preview와 큰 Finder thumbnail에서 embedded preview 대신 full render 경로로 처리되어야 한다.
- 작은 Finder thumbnail에서는 embedded preview fast path를 유지할 수 있다.
- 큰 Finder icon view와 Quick Look preview는 PDF처럼 요청 크기에 맞춰 직접 생성되어야 한다.
- core 변경이 필요하다고 판정된 경우에는 앱 저장소에 임시 core 수정을 남기지 않고 보고서에 분리 근거를 남긴다.

## 승인 요청

이 구현 계획서 승인 후 Stage 1 재현과 렌더링 경로 확인을 시작한다.
