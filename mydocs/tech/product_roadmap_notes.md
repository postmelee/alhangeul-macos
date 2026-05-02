# 제품 정체성 및 로드맵 세부 메모

작성일: 2026-04-27

## 목적

README.md는 외부 사용자가 프로젝트를 빠르게 이해하기 위한 문서로 유지한다. 날짜가 필요한 판단, 특정 macOS API 선택, 현재 FFI 제약, release compatibility 상태처럼 시간이 지나면 해석이 달라질 수 있는 내용은 이 문서와 관련 기술 문서에 분리한다.

## 제품 방향

알한글은 단순한 `rhwp` macOS 포팅판이 아니라 Mac 사용자를 위한 HWP/HWPX 파일 시스템 통합 유틸리티를 지향한다.

제품 흐름은 다음 순서로 확장한다.

```text
읽기 -> 찾기 -> 추출 -> 변환 -> 자동화 -> 안전한 편집 -> Agent-ready 문서 환경
```

초기 목표는 완전한 워드프로세서가 아니다. 먼저 HWP/HWPX가 Mac에서 자연스럽게 보이는 파일이 되게 만들고, 검색과 복사, 변환과 자동화를 통해 실제 문서 흐름에 들어가는 것을 우선한다. MVP viewer는 `rhwp-studio`를 WKWebView로 통합해 배포 가능성을 먼저 확보하고, native viewer renderer는 후순위 마일스톤에서 다시 끌어올린다.

## 설계 원칙

- 초반부터 완전한 한컴오피스 대체재를 선언하지 않는다. 조판, 저장, 호환성, 표, 수식, 각주, 개체 배치는 단계적으로 검증한다.
- WKWebView MVP는 출시 우선순위를 위한 명시적 예외다. 다만 제품의 중심은 여전히 Finder, Quick Look, Spotlight, Shortcuts, PDF, 메뉴바, 트랙패드, 키보드 단축키 같은 Mac 통합 경험에 둔다.
- 문서 처리를 클라우드 업로드 중심으로 만들지 않는다. 기본값은 로컬 처리이며, 외부 전송은 사용자가 명시적으로 선택해야 한다.
- HWP 저장 기능은 손상 방지 정책, round-trip test, 호환성 경고, 복사본 저장 흐름이 준비된 뒤 보수적으로 연다.

## 로드맵 구현 메모

### WKWebView MVP

2026-05-03 기준 MVP 출시 우선순위는 HostApp viewer를 `edwardkim/rhwp`의 `devel-webview` 브랜치 `rhwp-studio` 기반 WKWebView로 전환하는 것이다.

- v0.1은 Quick Look/Thumbnail과 WKWebView viewer를 묶어 먼저 배포 가능한 앱을 만든다.
- Spotlight, PDF export/print, 텍스트 추출, 변환, Quick Action, CLI처럼 WKWebView 기반에서도 진행 가능한 기능은 native viewer 고도화보다 앞쪽 마일스톤에 둔다.
- CoreGraphics/CoreText 기반 native viewer renderer, native pinch zoom, page cache, native page thumbnail sidebar는 후순위 native viewer 마일스톤으로 내린다.
- viewer가 Web/WASM 경로를 사용하더라도 Finder/Quick Look/Thumbnail, 파일 열기, 배포, sandbox, privacy 정책은 이 저장소가 소유한다.

### Spotlight

2026-04-27 기준 검토에서는 macOS custom file의 본문/메타데이터 검색을 Core Spotlight 색인만으로 설계하지 않는다. HWP/HWPX 같은 custom file을 Spotlight에 노출하려면 Spotlight importer plugin(`.mdimporter`) 경로를 함께 검토하고, `mdimport` 기반 검증 흐름을 설계해야 한다.

### Shortcuts와 App Intents

2026-04-27 기준 `project.yml`의 deployment target은 macOS 12다. App Intents 기반 Shortcuts 자동화는 macOS 13 이상에서 사용할 수 있으므로, 해당 기능을 구현할 때는 availability gate를 두거나 최소 지원 OS를 상향해야 한다.

### macOS C ABI

2026-04-27 기준 macOS C ABI는 렌더링과 thumbnail 경로 중심이다. WKWebView MVP viewer는 Web/WASM 경로를 사용할 수 있으므로, 이 ABI는 우선 Quick Look/Thumbnail과 후순위 native viewer renderer 경로의 계약으로 본다.

- `rhwp_open`
- `rhwp_close`
- `rhwp_page_count`
- `rhwp_page_size`
- `rhwp_render_page_tree`
- `rhwp_render_page_svg`
- `rhwp_image_data`
- `rhwp_extract_thumbnail`
- `rhwp_free_string`
- `rhwp_free_bytes`

검색, 복사, Markdown/JSON/RAG export에 필요한 읽기 순서, 표 구조, 문단 의미, page anchor API는 별도 core API와 C ABI 계약이 필요하다.

### Core release compatibility

2026-04-27 기준 Stable core 전환 상태와 release tag compatibility 판단은 [core_release_compatibility.md](core_release_compatibility.md)를 진실 원천으로 둔다. README.md에는 특정 upstream release의 현재 상태를 직접 적지 않는다.
