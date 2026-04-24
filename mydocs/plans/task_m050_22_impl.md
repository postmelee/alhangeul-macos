# Issue #22 구현 계획서

## 구현 목표

배포 준비에 필요한 최소 범위로 `rhwp` 코어 소싱/FFI 결합 구조를 정리한다.

- macOS 네이티브 브리지가 `wasm_api` 래퍼 대신 네이티브 코어 query 레이어에 직접 의존하게 한다.
- Thumbnail 경로에 embedded preview fast path를 도입할 수 있는 FFI 표면을 정리한다.
- Swift 계층과 문서에서 제품별 API 책임을 더 명확히 보이게 한다.

## 단계 계획

### 1단계. `RustBridge` 네이티브 의존 정리

- `RustBridge/src/lib.rs`에서 `rhwp::wasm_api::HwpDocument` 의존을 제거한다.
- `DocumentCore` 또는 동등한 네이티브 query 표면으로 `open`, `page_count`, `page_size`, `render_page_tree`, `image_data`를 다시 연결한다.
- 기존 FFI 심볼 집합이 유지되는지 우선 확인하고, 불가피한 변경만 최소화한다.

### 2단계. Thumbnail fast path FFI 추가

- `parser::extract_thumbnail_only`를 감싸는 네이티브 FFI 함수를 설계한다.
- 반환 메모리 수명, 포맷 문자열, fallback 규칙을 명확히 한다.
- 기존 첫 페이지 직접 렌더 경로와 충돌하지 않도록 Thumbnail 전용 표면으로 분리한다.

### 3단계. Swift 호출 경로 반영

- `RhwpDocument` 또는 Shared helper에서 새/기존 FFI 역할을 정리한다.
- `ThumbnailExtension`은 embedded preview 우선, 실패 시 현재 첫 페이지 렌더 fallback으로 구성한다.
- Viewer와 Quick Look은 render tree 기반 기본 경로를 유지한다.

### 4단계. 작은 Finder 아이콘 크기 지원

- `Sources/ThumbnailExtension/Info.plist`의 `QLThumbnailMinimumDimension` 정책을 재조정한다.
- 렌더러가 충분히 빠르면 Apple 문서 권고에 따라 해당 키를 제거해 표준 리스트/작은 아이콘 요청까지 썸네일 provider가 호출되도록 한다.
- `qlmanage`의 소형 요청 크기(`16`, `32`, `64`)와 Finder 아이콘 보기에서 회귀 여부를 확인한다.

### 5단계. Thumbnail 성능 경로 최적화

- `HwpThumbnailProvider`에서 불필요한 `MainActor` 고정을 제거하고, thumbnail 계산을 UI 격리와 분리한다.
- `HwpPageImageRenderer`, `RhwpDocument`, `CGTreeRenderer`의 actor 격리를 재검토해 thumbnail 경로가 메인 액터를 점유하지 않도록 정리한다.
- 같은 파일에 대한 연속 요청에서 재사용할 수 있도록 `fileURL + 수정시각 + 요청 크기 bucket` 기준 캐시 또는 in-flight dedupe를 도입한다.
- render fallback은 가능한 한 요청 크기 중심으로 비용을 제한하고, embedded preview decode도 중복 계산을 줄인다.

### 6단계. 문서와 provenance 정리

- `mydocs/tech/project_architecture.md`에 새 결합 구조와 제품별 API 책임을 반영한다.
- 필요 시 `mydocs/manual/release_distribution_guide.md` 또는 관련 문서에 코어 provenance/산출물 검증 포인트를 추가한다.
- 즉시안과 후속안(submodule 유지, git rev pin 전환, upstream 분리)을 구분해 기록한다.
- Finder grouped icon view 버벅임이 `.hwp`가 없는 폴더에서도 재현된 사실을 문서화하고, 앱 문제와 Finder 문제를 분리한다.
- `Feedback Assistant` 제출 경로, 권장 첨부물, 복붙 가능한 본문을 `mydocs/troubleshootings/` 문서로 정리한다.

### 7단계. 검증 및 보고 준비

- Rust bridge 재생성, Swift 빌드, 렌더 smoke test를 수행한다.
- 단계별 완료 보고서와 최종 보고서에 넣을 검증 결과를 정리한다.

## 단계별 검증

- 1단계 후:
  - `./scripts/build-rust-macos.sh`
  - 필요 시 `git diff --check -- RustBridge/src/lib.rs rhwp-ffi-symbols.txt`

- 2단계 후:
  - `./scripts/build-rust-macos.sh`
  - 필요 시 `git diff --check -- RustBridge/src/lib.rs rhwp-ffi-symbols.txt Sources/RhwpCoreBridge/RhwpDocument.swift`

- 3단계 후:
  - `./scripts/check-no-appkit.sh`
  - `xcodegen generate`
  - `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`

- 4단계 후:
  - `xcodegen generate`
  - `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
  - `qlmanage -t -x -s 16 -o /tmp <sample-or-user-file.hwp>`
  - `qlmanage -t -x -s 32 -o /tmp <sample-or-user-file.hwp>`
  - `qlmanage -t -x -s 64 -o /tmp <sample-or-user-file.hwp>`

- 5단계 후:
  - `xcodegen generate`
  - `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
  - `qlmanage -t -x -s 16 -o /tmp <sample-or-user-file.hwp>`
  - `qlmanage -t -x -s 32 -o /tmp <sample-or-user-file.hwp>`
  - `qlmanage -t -x -s 64 -o /tmp <sample-or-user-file.hwp>`
  - `/usr/bin/time -lp qlmanage -t -x -s 16 -o /tmp <sample-or-user-file.hwp>`

- 6단계 후:
  - `git diff --check -- mydocs/tech/project_architecture.md mydocs/manual/release_distribution_guide.md mydocs/troubleshootings/finder_icon_view_recent_opened_scroll_feedback_assistant.md`

- 7단계 후:
  - `./scripts/validate-stage3-render.sh`
  - `git diff --check`

## 보류 기준

다음 조건 중 하나가 발생하면 즉시 다음 단계로 넘어가지 않고 보고 후 승인 대기한다.

1. `DocumentCore` 직접 의존으로 전환하는 과정에서 upstream `rhwp` 변경이 선행되어야 하는 경우
2. Thumbnail fast path 도입이 기존 품질 기준과 충돌하는 경우
3. FFI 심볼 변경이 Viewer/Quick Look/Thumbnail 전체에 광범위한 수정 영향을 주는 경우
4. 작은 아이콘 영역에서 Finder가 운영체제 정책상 일반 아이콘을 유지하는 범위가 남아 있는 경우
5. thumbnail 경로의 actor 격리 제거가 HostApp/Preview 경로와 충돌하는 경우

## 승인 요청 사항

- 이 구현 계획서 보정본 기준으로 7단계 진행 승인 요청
