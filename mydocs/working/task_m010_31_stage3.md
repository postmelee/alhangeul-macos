# Task #31 Stage 3 완료 보고서

## 단계 목적

`mydocs/tech/project_architecture.md`를 제품 타깃 중심으로 재정렬한다. README에서 정리한 제품 타깃 -> 공통 Swift 계층 -> Rust bridge -> generated artifact 흐름과 같은 순서로 architecture 문서를 맞춘다.

## 변경 파일

- `mydocs/tech/project_architecture.md`
- `mydocs/plans/task_m010_31.md`
- `mydocs/working/task_m010_31_stage1.md`
- `mydocs/working/task_m010_31_stage3.md`
- `mydocs/orders/20260426.md`

## 변경 내용

Architecture 상위 구조:

- 기존 짧은 bullet list를 `Sources/`, `RustBridge/`, `Frameworks/`, `project.yml`, `rhwp-core.lock`, `scripts/`, `mydocs/` 순서의 구조 블록으로 바꿨다.
- `Sources/` 아래에 `HostApp`, `QLExtension`, `ThumbnailExtension`, `Shared`, `RhwpCoreBridge`가 한 번만 나타나도록 정리했다.

제품 타깃:

- `HostApp`을 사용자가 직접 여는 macOS viewer app으로 설명하고, 파일 열기, 보안 범위 접근, page cache, zoom, AppKit drawing, extension embed 관계를 명시했다.
- `QLExtension`을 Quick Look preview extension으로 설명하고, 첫 페이지 render tree 기반 PNG preview와 50 MB 초과 텍스트 fallback을 분리했다.
- `ThumbnailExtension`을 Finder thumbnail extension으로 설명하고, 요청 크기 bucket, render cache, aspect-fit drawing, fallback tile을 분리했다.

공통 Swift 계층:

- `Shared`는 HostApp/extension 공통 macOS helper이며, 현재 핵심 소유 코드가 `HwpPageImageRenderer`임을 명시했다.
- `RhwpCoreBridge`는 문서 핸들 수명, render tree 모델, FFI 호출, CoreGraphics/CoreText renderer를 소유한다고 정리했다.
- `RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 넣지 않는다는 규칙을 제품 타깃/Shared 경계와 함께 설명했다.

Rust bridge와 generated artifact:

- core 경계와 `RustBridge` 경계를 제품 타깃 뒤로 이동했다.
- Demo/Preview commit pin과 Stable release tag + resolved commit 기준을 별도 절로 나눴다.
- `Frameworks/Rhwp.xcframework`, generated header, modulemap, universal staticlib이 생성 산출물이며 `rhwp-core.lock` 정합성과 함께 검증해야 한다고 정리했다.

Runtime flow:

- 기존 Quick Look/Thumbnail 통합 흐름을 `Quick Look preview 경로`와 `Thumbnail 경로`로 분리했다.
- thumbnail 경로에 `HwpThumbnailRenderRequest`, `HwpThumbnailRenderCache`, aspect-fit drawing, extension badge 단계를 반영했다.

직접 비교 명칭 보정:

- 사용자 피드백에 따라 현재 Task #31 계획서와 Stage 1 작업 보고서에서도 비교 대상 프로젝트명을 직접 쓰는 표현을 제거했다.
- Stage 5 이름도 “직접 비교 명칭 제거 여부, Demo/Preview vs Stable 표현, 검색 gate 검증”으로 보정했다.

## 본문 변경 정도 / 본문 무손실 여부

Architecture 문서의 기존 FFI 심볼 목록, FFI 안전성 규칙, project 원본 규칙, localized display name 규칙, Finder/Quick Look 검증 기준은 유지했다. 순서와 설명 밀도만 제품 타깃 중심으로 조정했다.

source, `project.yml`, build script, lock 파일, generated framework 산출물은 변경하지 않았다.

## 검증 결과

diff whitespace:

```text
$ git diff --check
결과: 통과
```

직접 비교 명칭 제거:

```text
$ rg --line-number '<실제 비교 대상 프로젝트명>' README.md mydocs/tech/project_architecture.md mydocs/plans/task_m010_31.md mydocs/working/task_m010_31_stage1.md mydocs/working/task_m010_31_stage2.md
결과: 출력 없음
```

공개 구조 문서의 비교 표현:

```text
$ rg --line-number '<제외 비교 표현>' README.md mydocs/tech/project_architecture.md
결과: 출력 없음
```

제품 타깃/공통 계층 구조 표현:

```text
$ rg --line-number 'HostApp|QLExtension|ThumbnailExtension|Shared|RhwpCoreBridge|RustBridge|Frameworks|project.yml|rhwp-core.lock' mydocs/tech/project_architecture.md
결과: architecture 문서의 상위 구조, 제품 타깃, 공통 Swift 계층, Rust bridge, generated artifact 절에서 주요 경계가 확인됨.
```

Demo/Preview와 Stable 표현:

```text
$ rg --line-number 'Demo/Preview|Stable|release tag|resolved commit|rev|branch/floating' mydocs/tech/project_architecture.md
결과: Demo/Preview commit pin과 Stable release tag + resolved commit 기준이 확인됨.
```

## 잔여 위험

- `mydocs/working`과 과거 task plan/report에는 과거 작업 기록이 남아 있다. 이번 단계에서는 현재 Task #31 문서와 공개 구조 문서만 보정했다.
- build/run guide는 아직 Stage 4 대상이다. 신규 진입자의 실제 실행 순서는 Stage 4에서 architecture/README와 맞춰 보강해야 한다.

## 다음 단계

Stage 4에서는 `mydocs/manual/build_run_guide.md`를 신규 진입자 실행 순서 중심으로 보강하고, 필요하면 `Sources/README.md`와 `RustBridge/README.md` 추가 여부를 판단한다.

## 승인 요청

Stage 3 architecture 재정렬을 완료했다. 이 보고서 기준으로 Stage 4 `build/run guide와 필요 시 Sources/RustBridge README 보강`을 진행할지 승인 요청한다.
