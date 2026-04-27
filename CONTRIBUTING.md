# Contributing to alhangeul-macos

alhangeul-macos에 관심을 가져주셔서 감사합니다!

알한글 for macOS는 macOS 환경에서 HWP/HWPX 문서를 읽고, 미리보고, 나아가 편집할 수 있게 만드는 프로젝트입니다. macOS 코드, Swift bridge, 패키징, 문서, HWP 샘플 — 어떤 형태의 기여든 환영합니다. core 엔진 기여는 [`edwardkim/rhwp`](https://github.com/edwardkim/rhwp) 저장소에서 받습니다.

## 처음 참여하시나요?

### 1. 프로젝트 체험하기

코드를 보기 전에 먼저 사용해보세요:

- **[GitHub Releases](https://github.com/postmelee/alhangeul-macos/releases)** — 공개 release가 게시되면 DMG로 설치
- **소스 빌드** — 아래 "개발 환경 설정" 단계로 빌드 후 실행

### 2. 개발 환경 설정 (10분)

요구 사항:

- macOS 12 Monterey 이상
- Xcode 15 이상
- Rust toolchain (`rustup`)
- `cbindgen`, `xcodegen`

```bash
# 클론
git clone https://github.com/postmelee/alhangeul-macos.git
cd alhangeul-macos

# Rust target과 도구 준비
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo install cbindgen
brew install xcodegen

# Rust bridge 빌드 (Rhwp.xcframework 생성)
./scripts/build-rust-macos.sh

# Xcode project 생성
xcodegen generate

# HostApp Debug 빌드
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

# 실행
open build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app
```

자세한 빌드/실행 절차는 [`build_run_guide.md`](mydocs/manual/build_run_guide.md)를 참고하세요.

### 3. 첫 기여 찾기

- [`good first issue`](https://github.com/postmelee/alhangeul-macos/labels/good%20first%20issue) 라벨이 붙은 이슈
- 렌더링 차이 제보 (한컴 / Quick Look preview / 앱 viewer 스크린샷 비교)
- 문서 오타·개선
- HWP/HWPX 샘플 파일 제공 (개인정보 제거 후)

## 기여 방법

### 버그 리포트

HWP/HWPX 파일이 한컴 또는 rhwp core와 다르게 렌더링되거나, Finder Quick Look/Thumbnail이 동작하지 않는 경우 알려주세요:

1. [이슈 생성](https://github.com/postmelee/alhangeul-macos/issues/new)
2. 다음을 포함해 주세요:
   - macOS 버전, Xcode 버전, 알한글 빌드/release 버전
   - 한컴 또는 rhwp core 결과 스크린샷
   - 알한글에서 본 결과 스크린샷
   - 가능하면 HWP/HWPX 파일 첨부 (개인정보 제거 후)
3. Quick Look/Thumbnail 등록 문제는 `pluginkit -mAvvv | grep com.postmelee.alhangeulmac` 결과를 함께 첨부

### 코드 기여 — Fork & PR 워크플로우

외부 기여자는 **Fork 기반**으로 작업합니다. 저장소에 직접 push할 수 없으며, PR을 통해 코드를 제출합니다.

```
[본인 Fork]                              [postmelee/alhangeul-macos]

1. Fork (GitHub UI)
   postmelee/alhangeul-macos → myid/alhangeul-macos

2. Clone
   git clone https://github.com/myid/alhangeul-macos.git
   cd alhangeul-macos

3. 브랜치 생성 + 작업
   git checkout -b feature/my-task
   (코드 수정 + 검증)

4. Push (본인 Fork에)
   git push origin feature/my-task

5. PR 생성 (GitHub UI)                   ──→ devel 브랜치로 PR
                                              메인테이너 코드 리뷰
                                              승인 후 merge
```

**중요:**

- PR 대상 브랜치는 **`devel`** 입니다 (`main` 아님)
- 메인테이너의 코드 리뷰 승인 후 merge됩니다
- 메인테이너 워크플로우(`local/task{N}`, `publish/task{N}`)는 [`git_workflow_guide.md`](mydocs/manual/git_workflow_guide.md) 참고

### PR 전 체크리스트

```bash
./scripts/build-rust-macos.sh           # Rust bridge 빌드 + lock 검증
./scripts/check-no-appkit.sh            # 공통 계층 AppKit 의존성 검사
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh     # 렌더링 smoke test
```

위 명령이 모두 통과하는지 확인한 후 PR을 생성해주세요. PR 본문은 [`.github/pull_request_template.md`](.github/pull_request_template.md) 양식을 사용합니다.

### HWP/HWPX 샘플 파일 제공

다양한 문서로 테스트할수록 렌더링 품질이 올라갑니다. 개인정보가 없는 공공 문서나 테스트용 파일을 제공해주시면 큰 도움이 됩니다. 샘플은 `samples/` 아래에 두며, 라이선스/출처를 함께 알려주세요.

## 브랜치 규칙

| 브랜치 | 용도 | 보호 규칙 |
|--------|------|----------|
| `main` | 릴리즈 (안정 버전) | PR 필수 + 리뷰 승인 |
| `devel` | 개발 통합 (PR 대상) | PR 필수 |

- 외부 기여자 PR → `devel`
- 메인테이너 작업 PR → `publish/task{N}` → `devel`
- 릴리즈 시 `devel` → `main` + 태그

상세는 [`git_workflow_guide.md`](mydocs/manual/git_workflow_guide.md)를 참고하세요.

## 디버깅 가이드

렌더링 차이를 조사할 때 코드 수정 없이 사용할 수 있는 도구:

```bash
# 1. 기본 샘플 렌더링 smoke
./scripts/validate-stage3-render.sh

# 2. 특정 파일에서 rhwp core SVG와 native renderer PNG 비교
./scripts/render-debug-compare.sh output/render-debug path/to/sample.hwp

# 3. Finder Quick Look 강제 실행
qlmanage -p path/to/sample.hwp

# 4. Finder thumbnail smoke
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql path/to/sample.hwp
```

`render-debug-compare.sh`는 render tree JSON, core SVG, native PNG, summary를 출력합니다. 상세 절차는 [`render_core_native_compare.md`](mydocs/troubleshootings/render_core_native_compare.md)를 참고하세요.

## 프로젝트 구조

```
Sources/
├── HostApp/                  ← macOS viewer app
├── QLExtension/              ← Finder Quick Look preview extension
├── ThumbnailExtension/       ← Finder thumbnail extension
├── Shared/                   ← HostApp/extension 공통 helper
└── RhwpCoreBridge/           ← AppKit/UIKit 없는 Swift FFI wrapper + renderer

RustBridge/                   ← edwardkim/rhwp를 C ABI로 노출하는 staticlib crate
Frameworks/                   ← 생성 산출물 (Rhwp.xcframework, header, modulemap)
project.yml                   ← Xcode project 원본
rhwp-core.lock                ← core provenance + Rust bridge artifact hash/size
samples/                      ← render/Finder smoke fixture
scripts/                      ← build, lock verify, render smoke, package helper
mydocs/                       ← 작업 문서와 운영 매뉴얼
```

의존성 방향: `HostApp` / `QLExtension` / `ThumbnailExtension` ← `Shared` ← `RhwpCoreBridge` ← `Rhwp.xcframework` ← `RustBridge` ← `edwardkim/rhwp`

자세한 소유 경계와 bridge 정책은 [`project_architecture.md`](mydocs/tech/project_architecture.md)를 참고하세요.

## 코드 스타일

- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 넣지 않는다 (`./scripts/check-no-appkit.sh`로 강제)
- Rust FFI 경계의 포인터/길이/수명 해제 규칙을 명확히 유지 (자세히는 [`swift_macos_code_rules_guide.md`](mydocs/manual/swift_macos_code_rules_guide.md))
- `project.yml`이 Xcode project 원본. `AlhangeulMac.xcodeproj`는 직접 수정하지 않는다
- 모든 문서는 한국어로 작성

## 문서 작성 규칙

alhangeul-macos는 코드뿐 아니라 **작업 과정의 기록**도 프로젝트의 일부입니다(Hyper-Waterfall 방법론). PR에 문서를 포함하는 경우 아래 규칙을 지켜주세요.

### 폴더 구조 (`mydocs/` 하위)

| 폴더 | 용도 |
|------|------|
| `orders/` | 일일 작업지시 (`yyyymmdd.md`만 허용) |
| `plans/` | 수행 계획서, 구현 계획서 |
| `working/` | 단계별 완료 보고서 (`_stage{N}.md`) |
| `report/` | 최종 결과보고서 (`_report.md`) **— 최종 보고서는 반드시 여기** |
| `feedback/` | 피드백, 코드 리뷰 의견 |
| `tech/` | 기술 조사·분석 |
| `manual/` | 사용자/개발자 매뉴얼 |
| `troubleshootings/` | 트러블슈팅 (재발 방지용 해결 기록) |
| `pr/` | **외부 기여자 PR 검토 기록** (메인테이너가 관리, 기여자는 작성 불필요) |

### 파일명 규칙

타스크 관련 문서는 다음 형식을 따릅니다:

- 수행 계획서: `task_{milestone}_{이슈번호}.md` (예: `task_m100_42.md`)
- 구현 계획서: `task_{milestone}_{이슈번호}_impl.md`
- 단계별 보고서: `task_{milestone}_{이슈번호}_stage{N}.md` (`working/`)
- 최종 보고서: `task_{milestone}_{이슈번호}_report.md` (`report/`)

**주의 사항:**

- `task_` 접두어 고정 (`task_bug_`, `task_feat_` 등은 사용하지 않음)
- 마일스톤은 `m{숫자}` 형식 (예: `m100`, `m050`). 생략·약식 금지
- 후속 수정은 `_v2`, `_v3` 버전 접미어 사용 (`_fix`, `_hotfix` 금지)
- `orders/`에는 `yyyymmdd.md` 외의 파일을 두지 않습니다
- 최종 보고서(`_report.md`)는 반드시 `report/` 폴더 (`working/` 아님)

### 기여자가 작성해야 하는 문서 범위

기여자는 본인 작업 범위(내부 타스크 문서: `plans/`, `working/`, `report/`, `tech/`, `troubleshootings/` 등)만 작성합니다.

**`pr/` 폴더는 메인테이너가 PR을 검토한 기록을 남기는 전용 공간**이므로, 기여자는 직접 작성할 필요가 없습니다.

### 이 규칙이 애매하다면

PR 코멘트로 질문해주세요. 메인테이너가 안내드리고, 필요하면 [`document_structure_guide.md`](mydocs/manual/document_structure_guide.md)를 보완합니다.

## HWPUNIT 참고

- 1 inch = 7,200 HWPUNIT
- 1 inch = 25.4 mm
- 1 HWPUNIT ≈ 0.00353 mm

## 라이선스

기여하신 모든 코드와 문서는 본 저장소의 [MIT License](LICENSE)에 따라 배포됩니다.
