# Task M018 #199 구현계획서

수행계획서: `mydocs/plans/task_m018_199.md`

## 작업 개요

- 이슈: #199 공식 릴리즈 Finder thumbnail 생성 hang 수정
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task199`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task199`
- 기준 브랜치: `devel-webview`
- 목표: 공식 설치본과 새 빌드에서 HWP/HWPX thumbnail 생성이 timeout 없이 완료된다.

## 구현 원칙

- #184 DMG 안내 변경과 분리한다.
- 먼저 `qlmanage -t`로 headless thumbnail smoke를 통과시키고, Finder icon view는 후속 수동 확인으로 둔다.
- Thumbnail extension의 렌더 동시성은 보수적으로 제한한다. Finder thumbnail 요청은 빠른 완료와 안정성이 우선이다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- `project.yml`이 Xcode project 원본이다. Xcode project 직접 수정은 하지 않는다.

## Stage 1. 공식 설치본 hang 재현과 원인 경로 분리

### 목표

공식 설치본에서 thumbnail 요청이 extension 실행까지 도달하지만 렌더 완료 전에 hang 되는지 확인한다.

### 작업

- 설치본/PluginKit 상태를 확인한다.
- HWP/HWPX 샘플로 `qlmanage -t`를 실행한다.
- 멈춘 `AlhangeulThumbnail` 프로세스를 `sample`로 수집한다.
- source의 `HwpThumbnailRenderCache`, `HwpThumbnailProvider`, `HwpPageImageRenderer`를 대조한다.

### 완료 기준

- 설치/등록 문제가 아니라 공식 extension 렌더 경로 hang임이 확인된다.
- Stage 2 수정 방향이 정해진다.

## Stage 2. Thumbnail 렌더 안정화 최소 수정

### 목표

CoreGraphics bitmap rendering 경로가 Finder의 동시 요청에서 멈추지 않도록 보수적으로 직렬화하고, bitmap/PDF/QL drawing의 회색조 색 변환 경로를 RGB 직접 설정으로 바꾼다.

### 작업

- `HwpThumbnailRenderCache`의 worker queue를 serial queue로 변경한다.
- `CGColor(gray:alpha:)`로 생성한 흰색/회색 채우기 색을 `CGContext.setFillColor(red:green:blue:alpha:)` 또는 `setStrokeColor(red:green:blue:alpha:)`로 변경한다.
- Preview PDF와 shared page image renderer도 같은 색 설정 경로를 사용하도록 맞춘다.

### 완료 기준

- 코드 변경이 Thumbnail extension 경로에 한정된다.
- Debug build가 가능하다.

## Stage 3. 빌드와 qlmanage smoke 검증

### 목표

수정된 빌드에서 HWP/HWPX thumbnail PNG 생성이 완료되는지 확인한다.

### 작업

- Debug build를 수행한다.
- build 산출물 app을 등록해 `qlmanage -t` HWP/HWPX smoke를 수행한다.
- 필요하면 Release unsigned build도 확인한다.
- unified log에서 `took more than 60 seconds to reply`가 다시 발생하지 않는지 확인한다.

### 완료 기준

- HWP/HWPX 샘플 PNG가 생성된다.
- hang 프로세스가 남지 않는다.

## Stage 4. Finder 확인과 handoff 정리

### 목표

Finder icon view 관찰과 문서/보고를 정리해 #188 release smoke로 넘긴다.

### 작업

- Finder thumbnail 표시를 확인한다.
- `release_distribution_guide.md` 또는 관련 smoke 문서 보강 필요 여부를 판단한다.
- Stage 보고서와 최종 보고서에 공식 설치본 결함, 수정 내용, 검증 결과를 남긴다.

### 완료 기준

- 최종 보고서가 작성된다.
- #188에서 반복할 signed/notarized 설치본 smoke 항목이 명확하다.
