# 제품 정체성 및 로드맵 세부 메모

작성일: 2026-04-27

## 목적

README.md는 외부 사용자가 프로젝트를 빠르게 이해하기 위한 문서로 유지한다. 날짜가 필요한 판단, 특정 macOS API 선택, 현재 FFI 제약, release compatibility 상태처럼 시간이 지나면 해석이 달라질 수 있는 내용은 이 문서와 관련 기술 문서에 분리한다.

## README 반영 기준

- README.md의 이정표는 큰 제품 방향만 보여준다.
- README.md의 체크리스트는 현재 공개 릴리즈 라인에서 이미 구현된 기능만 표시한다.
- 미래 마일스톤의 후보 기능과 구현 순서는 이 문서에서 관리하되, 확정된 지원 약속으로 취급하지 않는다.
- 실제 착수 범위와 완료 여부는 GitHub Issue, milestone, PR, 릴리즈별 기록 문서를 진실 원천으로 둔다.

## 제품 방향

알한글은 단순한 `rhwp` macOS 포팅판이 아니라 Mac 사용자를 위한 HWP/HWPX 파일 시스템 통합 유틸리티를 지향한다.

제품 흐름은 다음 순서로 확장한다.

```text
WebView 첫 배포 -> Mac 통합 확장 -> 변환/자동화 -> Swift native viewer -> Swift native editor 기반 -> 안전한 native 편집 -> Agent-ready 문서 환경
```

초기 목표는 완전한 한컴오피스 대체재가 아니다. 먼저 HWP/HWPX가 Mac에서 자연스럽게 보이는 파일이 되게 만들고, `rhwp-studio`를 WKWebView로 품어 열기, 찾기, 복사, 저장, 공유, PDF 내보내기까지 가능한 첫 공개 배포를 만든다. 이후 앱 화면 밖의 Mac 통합과 변환/자동화를 확장하고, 장기 기본 경로는 Swift native viewer와 Swift native editor로 전환한다.

## 설계 원칙

- 초반부터 완전한 한컴오피스 대체재를 선언하지 않는다. 조판, 저장, 호환성, 표, 수식, 각주, 개체 배치는 단계적으로 검증한다.
- WKWebView-backed viewer/editor는 출시 우선순위를 위한 기준선이다. native parity가 충분해질 때까지 fallback과 비교 기준으로 유지하되, 제품의 중심은 Finder, Quick Look, Spotlight, Shortcuts, PDF, 메뉴바, 트랙패드, 키보드 단축키 같은 Mac 통합 경험과 Swift native 전환에 둔다.
- 문서 처리를 클라우드 업로드 중심으로 만들지 않는다. 기본값은 로컬 처리이며, 외부 전송은 사용자가 명시적으로 선택해야 한다.
- v0.1의 HWP 저장은 bundled `rhwp-studio` export 경로를 사용한다. Swift native editor의 저장은 손상 방지 정책, round-trip test, 호환성 경고, 복사본 저장 흐름이 준비된 뒤 v1.0에서 보수적으로 연다.

## 로드맵 구현 메모

### WKWebView MVP

2026-05-06 기준 첫 공개 배포 우선순위는 HostApp viewer/editor를 bundled `rhwp-studio` 기반 WKWebView로 제공하고, Finder/Quick Look/Thumbnail, PDF export, 공유, 저장, fallback, release artifact를 v0.1 범위로 닫는 것이다.

- v0.1은 Quick Look/Thumbnail과 WKWebView-backed viewer/editor를 묶어 먼저 배포 가능한 앱을 만든다.
- WebView 내부 찾기, 복사, 기본 편집 UI는 v0.1 사용자 기능으로 취급한다.
- PDF export/print/share/save는 v0.1 HostApp bridge 기능으로 취급한다.
- 문서 정보/본문 추출, Spotlight/mdimporter, Finder/서비스/공유 extension 재사용 API는 v0.2 Mac 통합 확장으로 분리한다.
- Text/Markdown/blocks JSON/HWPX 변환, batch 변환, Quick Action, CLI, Shortcuts는 v0.3 변환/자동화로 둔다.
- CoreGraphics/CoreText 기반 native viewer renderer, native pinch zoom, page cache, native page thumbnail sidebar, native search/copy는 v0.5 Swift native viewer 마일스톤으로 둔다.
- caret/selection/IME, ruler/margin/table/object overlay, native editor command routing은 v0.6 Swift native editor foundation으로 둔다.
- viewer가 Web/WASM 경로를 사용하더라도 Finder/Quick Look/Thumbnail, 파일 열기, 저장 panel, PDF export, 공유, 배포, sandbox, privacy 정책은 이 저장소가 소유한다.

### Spotlight

2026-04-27 기준 검토에서는 macOS custom file의 본문/메타데이터 검색을 Core Spotlight 색인만으로 설계하지 않는다. HWP/HWPX 같은 custom file을 Spotlight에 노출하려면 Spotlight importer plugin(`.mdimporter`) 경로를 함께 검토하고, `mdimport` 기반 검증 흐름을 설계해야 한다.

### Shortcuts와 App Intents

2026-04-27 기준 `project.yml`의 deployment target은 macOS 12다. App Intents 기반 Shortcuts 자동화는 macOS 13 이상에서 사용할 수 있으므로, 해당 기능을 구현할 때는 availability gate를 두거나 최소 지원 OS를 상향해야 한다.

### macOS C ABI

2026-05-06 기준 macOS C ABI는 렌더링과 thumbnail 경로 중심이다. WKWebView-backed viewer/editor는 Web/WASM 경로를 사용할 수 있으므로, 이 ABI는 우선 Quick Look/Thumbnail과 Swift native viewer/editor 전환 경로의 계약으로 본다.

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

앱 화면 밖의 텍스트 추출, Spotlight, Markdown/JSON/RAG export에 필요한 읽기 순서, 표 구조, 문단 의미, page anchor API는 별도 core API와 C ABI 계약이 필요하다. WebView 내부 찾기/복사와 Swift native search/copy는 제품 표면은 비슷하지만 소유 경계가 다르므로 로드맵에서 분리한다.

### Core release compatibility

2026-04-27 기준 Stable core 전환 상태와 release tag compatibility 판단은 [core_release_compatibility.md](core_release_compatibility.md)를 진실 원천으로 둔다. README.md에는 특정 upstream release의 현재 상태를 직접 적지 않는다.
