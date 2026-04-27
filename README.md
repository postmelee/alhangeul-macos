<p align="center">
  <img src="assets/logo-256@2x.png" alt="rhwp logo" width="128" />
</p>
<h1 align="center">Alhangeul</h1>

<p align="center">
  <strong>알한글 for macOS</strong><br/>
  <em>Mac-native HWP/HWPX file utility</em>
</p>

<p align="center">
  <a href="https://github.com/postmelee/alhangeul-macos"><img src="https://img.shields.io/badge/platform-macOS%2012%2B-blue" alt="macOS 12+" /></a>
  <a href="https://www.swift.org/"><img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9" /></a>
  <a href="https://www.rust-lang.org/"><img src="https://img.shields.io/badge/Rust-native%20bridge-orange" alt="Rust native bridge" /></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT" /></a>
</p>

---

### Mac에서 한글 파일은 더 이상 이방인이 아닙니다.
스페이스바로 미리보고, Finder에서 썸네일로 찾고, PDF/HWPX/Markdown으로 변환하세요.

![home_banner](assets/home_banner.png)

**알한글**은 Mac에서 HWP/HWPX 파일을 Finder, Quick Look, Spotlight, PDF 변환까지 자연스럽게 다루는 오픈소스 문서 유틸리티입니다. 파일을 업로드하지 않고 로컬에서 **열고**, **검색**하고, **변환**하세요.

Rust 기반 [`rhwp`](https://github.com/edwardkim/rhwp) 코어를 macOS 앱, Quick Look preview, Finder thumbnail, Swift bridge로 연결합니다. 닫힌 HWP/HWPX 문서를 더 많은 환경에서 다룰 수 있게 한다는 rhwp의 방향을 **Mac 네이티브** 경험으로 확장합니다.

## 이정표

```
v0.1(Mac에서 열린다) → v0.2(Mac답게 본다) → v0.3(찾고 추출한다) → v0.4(변환하고 자동화한다) → v0.5(믿고 설치한다) → v1.0(작게 고친다) → v2.0(AI가 다룬다)
```

| 버전 | 단계 | 사용자에게 보이는 변화 | 주요 범위 |
|------|------|------------------------|-----------|
| `v0.1` | Mac에서 열린다 | Finder와 Quick Look에서 HWP/HWPX가 보이고, 앱에서 문서를 열 수 있습니다. | Quick Look preview, Finder thumbnail, 읽기 전용 viewer, native rendering |
| `v0.2` | Mac답게 본다 | 한글 프로그램 없이도 문서를 찾고, 복사하고, PDF로 보낼 수 있습니다. | pinch zoom, 문서 내 검색, 텍스트 선택/복사, 페이지 썸네일, PDF export |
| `v0.3` | 찾고 추출한다 | 파일명뿐 아니라 본문, 표, 이미지, 문서 정보를 Mac에서 꺼낼 수 있습니다. | 본문 추출, 표/이미지 추출, Markdown/JSON export, Spotlight 본문 검색 |
| `v0.4` | 변환하고 자동화한다 | 여러 HWP/HWPX 문서를 Finder, CLI, Shortcuts 흐름에서 변환할 수 있습니다. | PDF/Text/Markdown/HWPX 변환, batch 변환, Quick Action, CLI, Shortcuts |
| `v0.5` | 믿고 설치한다 | 일반 사용자가 설치해도 되는 안정적인 Mac 앱으로 배포합니다. | signed/notarized 배포, 업데이트, crash-safe opening, 접근성, 호환성 리포트 |
| `v1.0` | 작게 고친다 | 문서 손상을 피하면서 자주 필요한 작은 수정부터 지원합니다. | 기본 텍스트/문단/표 편집, undo/redo, autosave, 복사본 저장 |
| `v2.0` | AI가 다룬다 | 에이전트가 문서를 열고, 수정하고, 렌더링 결과로 검증하는 루프를 제공합니다. | 구조화 patch API, page anchor, 문서 diff, render verification, agent tooling |

세부 구현 제약과 날짜가 필요한 판단은 [제품 로드맵 메모](mydocs/tech/product_roadmap_notes.md)에 분리해 둡니다.

## 로드맵

체크된 항목은 현재 저장소 기준으로 구현된 기능입니다. 체크되지 않은 항목은 제품 방향입니다.

### v0.1 — "Mac에서 열린다" Preview Release

> Finder에서 HWP/HWPX 파일이 낯선 회색 아이콘이 아니라 "내용이 보이는 문서"가 되게 만듭니다.

- [x] `RustBridge` staticlib와 `Rhwp.xcframework` 구성
- [x] C ABI symbol snapshot과 `rhwp-core.lock` 기반 provenance/artifact 검증
- [x] `.hwp`, `.hwpx` Quick Look preview
- [x] 첫 페이지 기반 Finder thumbnail
- [x] HWP/HWPX UTI 등록
- [x] HostApp에서 HWP/HWPX 열기
- [x] 다중 페이지 스크롤
- [x] toolbar/menu 기반 확대, 축소, 실제 크기
- [x] 문서명, 현재 페이지, 전체 페이지 수, zoom 상태 표시
- [x] 50 MB 초과 preview fallback
- [x] Quick Look/Thumbnail extension 상태 진단
- [x] CoreGraphics/CoreText 기반 native page renderer
- [x] 렌더링 smoke test와 render debug compare 도구

### v0.2 — "Mac답게 본다" Native Viewer

> "한글이 없어도 Mac에서 HWP를 보고, 찾고, 복사하고, PDF로 보낼 수 있습니다."

- [ ] 네이티브 trackpad pinch zoom
- [ ] 확대 중심점 유지와 scroll offset 보정
- [ ] 문서 내 검색
- [ ] 검색 결과 이동과 현재 페이지 동기화
- [ ] 텍스트 선택/복사
- [ ] 표 텍스트 복사
- [ ] 페이지 썸네일 sidebar
- [ ] 페이지 번호 이동
- [ ] PDF로 내보내기
- [ ] 인쇄

### v0.3 — "찾고 추출한다" Find & Extract

> 파일명뿐 아니라 HWP 문서 안의 단어, 표, 이미지, 문서 정보를 Mac에서 바로 찾고 꺼낼 수 있게 만듭니다.

- [ ] 문서 정보 보기: 페이지 수, 포맷, 버전, 사용 글꼴
- [ ] 본문 텍스트 추출
- [ ] 페이지별 텍스트 추출
- [ ] 읽기 순서와 page anchor를 포함한 blocks JSON
- [ ] 표를 CSV/Markdown으로 추출
- [ ] 문서 안 이미지 추출
- [ ] Markdown export
- [ ] JSON export
- [ ] Spotlight 본문/메타데이터 인덱싱

### v0.4 — "변환하고 자동화한다" Convert & Automate

> 다운로드 폴더의 HWP 공문을 한 번에 PDF/HWPX/Markdown으로 정리할 수 있게 만듭니다.

- [ ] HWP/HWPX -> PDF 변환
- [ ] HWP/HWPX -> Plain Text 변환
- [ ] HWP/HWPX -> Markdown 변환
- [ ] HWP -> HWPX 변환
- [ ] PNG/JPEG page export
- [ ] 폴더 일괄 변환
- [ ] Finder 우클릭 Quick Action
- [ ] CLI 제공
- [ ] Shortcuts 자동화

### v0.5 — "믿고 설치한다" Consumer Stable

> 오픈소스 실험 앱이 아니라, 일반 사용자가 설치해도 되는 신뢰 가능한 Mac 앱으로 만듭니다.

- [ ] signed/notarized DMG
- [ ] GitHub Releases
- [ ] Homebrew Cask
- [ ] 자동 업데이트 또는 업데이트 확인
- [ ] crash-safe file opening
- [ ] corrupt file fallback
- [ ] 큰 문서 page cache와 progressive rendering
- [ ] 렌더링 visual diff와 fixture corpus 확장
- [ ] 문서 호환성/렌더링 한계 리포트
- [ ] VoiceOver, 키보드 탐색, 고대비
- [ ] 로컬 처리 우선 privacy 정책

### v1.0 — "작게 고친다" Safe Editing

> 전체 워드프로세서를 바로 대체하기보다, 자주 필요한 작은 수정부터 안전하게 지원합니다.

- [ ] 텍스트 삽입/삭제
- [ ] 굵게, 밑줄, 글꼴 크기 등 기본 글자 서식
- [ ] 문단 정렬/간격
- [ ] 표 셀 텍스트 수정
- [ ] 양식 필드 채우기
- [ ] undo/redo
- [ ] autosave/dirty state
- [ ] 복사본 저장과 손상 방지 정책
- [ ] HWPX 우선 저장
- [ ] HWP 저장은 round-trip test와 호환성 경고 이후 보수적으로 개방

### v2.0 — "AI가 다룬다" Agent-ready Docs

> 에이전트가 HWP/HWPX 문서를 열고, 수정하고, 렌더링 결과로 검증하는 루프를 제공합니다.

- [ ] 구조화된 문서 patch API
- [ ] 표/문단/필드 단위 편집 API
- [ ] Markdown/JSON/RAG chunk export
- [ ] page anchor와 bbox 기반 문서 참조
- [ ] render verification loop
- [ ] 변경 전후 diff
- [ ] screenshot/render output 기반 재검증
- [ ] Codex/Claude 연동 plugin 또는 tool packaging

## Features

### Finder Integration (Finder 통합)

- `.hwp`, `.hwpx` Quick Look preview
- 첫 페이지 기반 Finder thumbnail
- `.hwp`, `.hwpx` 및 Hancom 계열 UTI 등록
- 50 MB 초과 파일 preview fallback
- 앱 정보 창에서 Quick Look/Thumbnail extension 번들 포함과 시스템 등록 상태 확인

### Native Viewer (네이티브 뷰어)

- macOS SwiftUI 기반 HostApp
- HWP/HWPX 파일 열기
- Finder 또는 다른 앱에서 파일 열기 요청 수신
- 다중 페이지 스크롤
- toolbar/menu/slider 기반 확대, 축소, 실제 크기
- 문서명, 현재 페이지, 전체 페이지 수, zoom 상태 표시

### Rendering (렌더링)

- Rust core render tree JSON 디코딩
- CoreGraphics 기반 page rendering
- CoreText 기반 text run rendering
- 이미지 bin data 조회 및 렌더링
- 페이지 배경, 사각형, 선, 타원, path, 그룹 노드 일부 렌더링
- table cell clipping
- 밑줄, 취소선, 음영 등 일부 text decoration

### Core Bridge (코어 브리지)

- `edwardkim/rhwp`를 git dependency로 사용하는 `RustBridge` crate
- C ABI 기반 `rhwp_*` FFI entrypoint
- `cbindgen` header/modulemap 생성
- universal static library 생성
- `Rhwp.xcframework`를 HostApp, Quick Look, Thumbnail target에서 공유
- FFI symbol set을 `rhwp-ffi-symbols.txt`로 고정

### Development Workflow (개발 워크플로우)

- XcodeGen 기반 project 생성
- Rust bridge와 Swift renderer 분리
- `check-no-appkit.sh`로 shared Swift bridge의 AppKit/UIKit 의존성 검사
- `validate-stage3-render.sh`로 렌더링 smoke test
- GitHub Issue 기반 task branch와 한국어 작업 문서

자세한 구조와 bridge 정책은 [아키텍처 문서](mydocs/tech/project_architecture.md)를 참조하세요.

## Quick Start (소스 빌드)
처음 프로젝트에 참여하는 개발자는 [Project Structure](#project-structure)를 먼저 보고, 세부 경계는 [아키텍처 문서](mydocs/tech/project_architecture.md), 상세한 빌드 및 검증 절차는 [빌드 및 실행 가이드](mydocs/manual/build_run_guide.md)를 확인하세요. 실제 빌드는 Rust bridge 산출물을 만든 뒤 Xcode project를 생성하고 HostApp을 빌드하는 순서입니다.

### Requirements

- macOS 12 Monterey 이상
- Xcode 15 이상
- Swift 5.9
- Rust toolchain
- `cbindgen`
- XcodeGen

### Initial Setup

```bash
git clone https://github.com/postmelee/alhangeul-macos.git
cd alhangeul-macos

rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo install cbindgen
brew install xcodegen
```

### Build

```bash
./scripts/build-rust-macos.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Run

```bash
open build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app
```

### Checks

```bash
./scripts/validate-stage3-render.sh
./scripts/check-no-appkit.sh
```

- Core dependency - [core dependency 운영 가이드](mydocs/manual/core_dependency_operation_guide.md)
- release packaging - [릴리스/배포 가이드](mydocs/manual/release_distribution_guide.md)
- Finder extension 등록 검증 - [빌드 및 실행 가이드](mydocs/manual/build_run_guide.md)

## Project Structure

이 저장소는 먼저 macOS 제품 타깃을 나누고, 그 아래에 공통 Swift 계층과 Rust bridge를 둡니다.

```text
Sources/
├── HostApp/                  # macOS viewer app
│   ├── Services/             # 파일 열기, extension 상태 확인
│   ├── Stores/               # 문서 viewer 상태
│   ├── Support/              # 빌드 정보
│   └── Views/                # SwiftUI/AppKit viewer UI
├── QLExtension/              # Quick Look preview extension
├── ThumbnailExtension/       # Finder thumbnail extension
├── Shared/                   # HostApp/extension 공통 macOS helper
└── RhwpCoreBridge/           # AppKit/UIKit 없는 Swift FFI wrapper + render tree renderer

RustBridge/                   # edwardkim/rhwp를 C ABI로 노출하는 Rust staticlib crate
├── Cargo.toml                # rhwp git dependency 선언
├── Cargo.lock                # Cargo가 해석한 resolved commit 고정
├── cbindgen.toml             # C header 생성 설정
└── src/lib.rs                # rhwp_* FFI entrypoints

Frameworks/                   # generated Rhwp.xcframework/header/modulemap, git ignore 대상
project.yml                   # Xcode project 원본
rhwp-core.lock                # core provenance + Rust bridge artifact hash/size
samples/                      # render smoke와 Finder smoke용 HWP/HWPX fixture
scripts/                      # build, lock verify, render smoke, package helper
mydocs/                       # hyper-waterfall 작업 문서와 운영 매뉴얼
```

`project.yml`은 `AlhangeulMac.xcodeproj`의 원본입니다. target, source 포함 범위, bundle identifier, extension embedding을 바꿀 때는 `project.yml`을 수정한 뒤 `xcodegen generate`를 실행합니다.

타깃 간 소유 경계, 공통 Swift 계층, Rust bridge, 런타임 데이터 흐름은 [아키텍처 문서](mydocs/tech/project_architecture.md)를 참조하세요.

## AI 페어 프로그래밍으로 개발합니다

> 이 섹션의 문제의식과 개발 방법론 설명은 `edwardkim/rhwp` README.md의 ["AI 페어 프로그래밍으로 개발합니다"](https://github.com/edwardkim/rhwp#ai-%ED%8E%98%EC%96%B4-%ED%94%84%EB%A1%9C%EA%B7%B8%EB%9E%98%EB%B0%8D%EC%9C%BC%EB%A1%9C-%EA%B0%9C%EB%B0%9C%ED%95%A9%EB%8B%88%EB%8B%A4) 섹션을 바탕으로 합니다. alhangeul-macos에서는 같은 절차를 Claude Code와 OpenAI Codex에 함께 적용합니다.

**이것은 바이브 코딩이 아닙니다.** AI가 주는 코드를 읽지도 않고 수락하는 것이 아닙니다. 모든 계획은 검토되고, 모든 결과물은 검증되며, 모든 결정의 뒤에는 사람이 있습니다.

바이브 코딩 — AI 출력을 읽지 않고 수락하고, AI에게 아키텍처 결정을 맡기고, 이해하지 못하는 코드를 배포하는 것 — 은 함정입니다. 겉보기에는 동작하지만, 이해하지 못했기 때문에 문제가 생겨도 진단할 수 없는 코드가 만들어집니다.

이 프로젝트는 정반대의 접근을 취합니다. 사람 **작업지시자**가 방향, 품질, 아키텍처 결정의 완전한 소유권을 유지하고, AI는 혼자서는 불가능한 속도와 규모로 구현을 수행합니다. 핵심 차이: **사람은 절대 생각을 멈추지 않습니다.**

### 바이브 코딩 vs. AI 주도 개발

| | 바이브 코딩 | 이 프로젝트 |
|--|-----------|-----------|
| **사람의 역할** | AI 출력 수락 | 지시, 검토, 결정 |
| **계획** | 없음 — "그냥 만들어" | 계획서 작성 → 승인 → 실행 |
| **품질 관문** | 동작하길 바람 | 빌드 + 렌더링 smoke test + 코드 리뷰 |
| **디버깅** | AI에게 AI 버그 수정 요청 | 사람이 진단, AI가 구현 |
| **아키텍처** | 우연히 형성 | 의도적 설계 (core, bridge, app 경계) |
| **문서** | 없음 | `mydocs/` 프로세스 기록 |
| **결과물** | 취약, 유지보수 어려움 | 검증 가능한 변경 단위 |

AI는 배율기입니다. 하지만 배율기는 기존 프로세스를 증폭시킵니다. 프로세스 없음 × AI = 빠른 혼돈. 좋은 프로세스 × AI = 비범한 결과물.

### 개발 프로세스

이 프로젝트는 [**Claude Code**](https://claude.ai/code) 와 [**OpenAI Codex**](https://openai.com/ko-KR/codex/)를 페어 프로그래밍 파트너로 사용하여 개발합니다. 전체 개발 과정은 Issue, branch, 작업 문서, PR에 투명하게 남깁니다.

```text
작업지시자 (사람)                    AI 페어 프로그래머 (Claude Code / Codex)
────────────────                    ─────────────────────────────────────
방향 설정, 우선순위 결정        →    분석, 계획, 구현
계획 검토, 승인                ←    구현 계획서 작성
도메인 피드백 제공              →    디버깅, 테스트, 반복
아키텍처 결정                  →    정밀하게 실행
품질 및 정확성 판단            ←    코드, 문서, 테스트 생성
```

`mydocs/` 디렉토리에 개발 기록이 있습니다: 일일 작업 기록, 구현 계획서, 단계별 완료 보고서, 최종 보고서, 기술 연구 문서, 트러블슈팅 기록.

> `mydocs/`는 코드에 대한 문서만이 아닙니다 — **AI로 소프트웨어를 만드는 방법**에 대한 문서입니다.

**Hyper-Waterfall 방법론** — 거시적 워터폴 + 미시적 애자일, AI가 이 둘을 동시에 가능하게 한다.

### Git 워크플로우

```text
local/task{N}  ──커밋──커밋──┐
                              ├─→ publish/task{N} push
                              ├─→ devel draft PR + merge
                              ├─→ main merge + 태그 (릴리즈 시점)
```

| 브랜치 | 용도 |
|--------|------|
| `main` | 릴리즈 |
| `devel` | 개발 통합 |
| `local/task{N}` | GitHub Issue 번호 기반 타스크 브랜치 |
| `publish/task{N}` | `devel` 대상 PR 생성을 위한 원격 게시 브랜치 |

### 타스크 관리

- **GitHub Issues**로 타스크 번호 자동 채번 — 중복 방지
- 브랜치명: `local/task{issue번호}`
- PR 생성용 원격 브랜치명: `publish/task{issue번호}`
- 오늘할일: `mydocs/orders/yyyymmdd.md`
- 커밋 메시지:
  - 기본형: `Task #{번호}: 내용`
  - 단계 커밋: `Task #{번호} Stage {N}: 내용`
- PR 대상: `postmelee/alhangeul-macos`의 `devel`

### 타스크 진행 절차

이슈 → 브랜치 → 오늘할일 → 수행계획서 → 구현계획서 → 구현 → 검증 → 단계 보고 → 최종 보고 → PR 게시 → merge 후 정리.

15단계 상세, 승인 게이트, 커밋 메시지 규칙은 [`task_workflow_guide.md`](mydocs/manual/task_workflow_guide.md)를 참고하세요.

### 디버깅 프로토콜

1. `validate-stage3-render.sh` → 기본 샘플 렌더링 확인
2. `pluginkit -m` → Quick Look/Thumbnail extension 등록 확인
3. `qlmanage -p` → Finder preview 경로 확인
4. `render-debug-compare.sh` → 특정 파일의 render tree JSON, core SVG, native PNG, pixel diff 산출
5. 필요 시 별도 `edwardkim/rhwp` clone 또는 Cargo checkout에서 core rendering data 확인

### 문서 생성 규칙

모든 문서는 **한국어**로 작성합니다.

```text
mydocs/
├── orders/           # 오늘 할일 (yyyymmdd.md)
├── plans/            # 수행 계획서, 구현 계획서
│   └── archives/     # 완료된 계획서 보관
├── working/          # 단계별 완료 보고서
├── report/           # 최종 보고서
├── feedback/         # 코드 리뷰 피드백
├── tech/             # 기술 사항 정리 문서
├── manual/           # 매뉴얼, 가이드 문서
├── troubleshootings/ # 트러블슈팅 관련 문서
└── pr/               # 외부 기여자 PR 검토 기록
```

폴더별 역할, 파일명 규칙(`task_{milestone}_{issue}.md` 등), 외부 PR 정책은 [`document_structure_guide.md`](mydocs/manual/document_structure_guide.md)를 참고하세요.

## Architecture

```mermaid
graph TB
    HWP[HWP/HWPX File] --> HostApp[HostApp Viewer]
    HWP --> Preview[Quick Look Preview]
    HWP --> Thumbnail[Finder Thumbnail]
    Preview --> Shared[Shared HwpPageImageRenderer]
    Thumbnail --> Shared
    HostApp --> Doc[RhwpDocument]
    Shared --> Doc
    Doc --> Bridge[RhwpCoreBridge]
    Bridge --> XC[Rhwp.xcframework / Rhwp C ABI]
    XC --> RustBridge[RustBridge]
    RustBridge --> Core[edwardkim/rhwp git dependency]
    Core --> Data[Render Tree JSON / Image Data]
    Data --> Bridge
    Bridge --> CG[CoreGraphics / CoreText Renderer]
```
## Contributing

기여 환영합니다. 다음 핵심 사항을 먼저 확인해 주세요:
- PR base 는 devel 입니다 (main 아님). GitHub 기본 브랜치는 main 이지만 기여 PR 은 모두 devel 로 받습니다.
- 이슈 먼저 확인: 동일 영역에 진행 중인 작업이 있는지 [열린 이슈](https://github.com/postmelee/alhangeul-macos/issues) 와 [열린 PR](https://github.com/postmelee/alhangeul-macos/pulls) 을 먼저 확인해 주세요. 중복 작업을 방지합니다.
- 이슈 close 는 메인테이너: 작업 완료 후 PR 만 제출해 주세요. 이슈는 PR 머지 시 메인테이너가 close 합니다.

상세한 기여 절차 (Fork → 브랜치 → 커밋 → PR) 는 [CONTRIBUTING.md](CONTRIBUTING.md) 를 참고하세요.
## Notice

본 제품은 한글과컴퓨터의 한글 문서 파일(`.hwp`, `.hwpx`) 공개 문서를 참고하여 개발하였습니다.

## Trademark

"한글", "한컴", "HWP", "HWPX"는 주식회사 한글과컴퓨터의 등록 상표입니다. 본 프로젝트는 한글과컴퓨터와 제휴, 후원, 승인 관계가 없는 독립적인 오픈소스 프로젝트입니다.

"Hangul", "Hancom", "HWP", and "HWPX" are registered trademarks of Hancom Inc. This project is an independent open-source project with no affiliation, sponsorship, or endorsement by Hancom Inc.

## License

[MIT License](LICENSE)
