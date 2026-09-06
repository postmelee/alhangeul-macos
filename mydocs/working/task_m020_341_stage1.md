# Task M020 #341 Stage 1 완료보고서

## CFPlugIn importer와 app bundle 통합

## 구현

`Sources/SpotlightImporter`에 CFPlugIn factory/COM 수명/metadata callback, Info.plist와 UTI schema를 추가했다. HostApp UTI 9종과 버전 값을 재사용하며 XcodeGen dependency copy phase로 Contents/Library/Spotlight에 배치한다. `Alhangeul.xcodeproj` 변경은 xcodegen 생성 결과다.

regular-file/32 MiB/읽기 전후 수정 시각·크기를 검사하고 leaf symlink와 특수 파일을 열지 않는다. #340 ABI 반환은 CFString으로 복사한 뒤 bytes를 해제한다. 빈/실패/보호 결과에는 kCFNull로 이전 본문 제거를 명시한다. 제품 로그·UI·네트워크 접근은 없다.

## 검증

- SpotlightImporter Release arm64/x86_64 build PASS. XCFramework의 실제 rhwp.h 헤더 이름을 적용했다.
- 실제 CFPlugInCreate/factory/QueryInterface/Release와 ImportData PASS. 공개 한글 샘플의 본문 및 없는 파일의 기존 본문 제거를 확인했다.
- 현재 macOS MetadataSchema.xsd와 types/allattrs 형식을 대조했다.
- 전체 HostApp 배치/서명·package 검사는 후속 단계에서 이어간다.

## 근거

XcodeGen 공식 ProjectSpec의 dependency.copy(destination/subpath) 계약을 사용했다: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#dependency
