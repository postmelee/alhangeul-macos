# Task #610 최종 보고

## 변경

Preview 및 Thumbnail의 `QLSupportedContentTypes`에 확인된 `com.infraware.polarisofficeservice.hwp`를 각각 추가했다. 나머지 기존 9개 UTI는 유지했다. HostApp 문서 연결, Spotlight, 렌더러, 버전은 변경하지 않았다. 근거가 없는 Polaris HWPX 식별자는 추가하지 않았다.

정적 계약 검사와 회귀 6개(기존/신규 UTI 누락 20 subcase 포함)를 추가하여 PR CI에 연결했다.

## 검증

- 두 source plist lint: PASS
- 계약 검사 및 unittest 6개: PASS
- 수정 전 HEAD의 plist 음성 대조: Polaris HWP 누락으로 실패 확인
- workflow YAML parse 및 git diff --check: PASS
- shared Swift AppKit/UIKit 경계 검사: PASS
- 동일 devel 기준 기존 Rhwp.xcframework를 사용한 QLExtension 및 ThumbnailExtension unsigned Debug build: PASS
- 두 build.noindex/Products/Debug 확장 번들 Info.plist 계약 검사: PASS

## 한계

이 검증은 UTI 누락 수정과 컴파일/번들 반영 확인이다. Polaris 설치 환경의 LaunchServices UTI 선택 및 Finder 실제 표시를 재현하지 않았다. 개발 확장을 수동 시스템 등록하거나 기존 설치 앱을 변경하지 않았다. 릴리즈, 공증, 배포는 하지 않았다. 따라서 사용자에게 이미 배포되어 해결됐다고 안내하면 안 된다.
