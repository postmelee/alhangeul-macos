# Issue #9 단계 1 완료 보고서

## 수행 내용

- 원격 `devel` 최신 상태와 기존 PR merge 상태를 확인했다.
- Issue #9를 생성하고 `origin/devel` 기준으로 `local/task9` 브랜치를 생성했다.
- 다음 파일을 기준으로 현재 프로젝트 상태를 확인했다.
  - `README.md`
  - `AGENTS.md`
  - `docs/ARCHITECTURE.md` (현재는 `mydocs/tech/project_architecture.md`로 이전)
  - `docs/RHWP_CORE_BRIDGE_PLAN.md` (현재는 중복 문서로 삭제되고 운영 기준은 `mydocs/tech/project_architecture.md`, `mydocs/manual/` 문서로 정리)
  - `Sources/HostApp`
  - `Sources/QLExtension`
  - `Sources/ThumbnailExtension`
  - `Sources/RhwpCoreBridge`
  - `RustBridge/src/lib.rs`
  - `scripts/`
  - `Casks/rhwp-mac.rb`

## 확인한 구현 상태

- HostApp viewer는 HWP/HWPX 열기, 다중 페이지 스크롤, 확대/축소를 제공한다.
- Quick Look preview와 Thumbnail extension은 첫 페이지 bitmap 렌더링 경로를 공유한다.
- Swift renderer는 render tree JSON을 CoreGraphics/CoreText로 렌더링한다.
- RustBridge는 `rhwp` core를 C ABI와 `Rhwp.xcframework`로 노출한다.
- 릴리스 패키징 스크립트와 Homebrew Cask 초안은 있으나, 첫 공개 릴리스 전 배포 metadata 정리가 필요하다.

## 결과

README를 현재 macOS 앱 저장소 기준으로 재작성할 근거를 확보했다.
