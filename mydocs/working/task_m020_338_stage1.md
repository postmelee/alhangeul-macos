# Task M020 #338 Stage 1 완료보고서

## 현재 SDK·UTI·API 및 검증 환경 조사

- 2026-09-07 갱신한 #337–#343 본문을 GitHub에 게시하고 원격 본문 일치를 재조회했다.
- 기준 devel 1a5eefb, core v0.8.6/f1f9c6a, macOS 26.5.2 / Xcode 26.6, 최소 OS 12.0을 확인했다.
- 앱 Info.plist의 HWP/HWPX UTI 9종을 확인했다. 현재 `mdimport -L` 목록에 알한글/HWP importer는 없다.
- SDK MDImporter.h에 CFPlugIn `MDImporterInterfaceStruct`, factory type/interface UUID 및 GetMetadata callback 계약이 존재한다. CoreFoundation/CFPlugInCOM/CoreServices header probe를 arm64·x86_64 macOS 12 target으로 `clang -fsyntax-only` 검증했다.
- `/usr/bin/mdimport -h`에서 -t 시험과 -i 색인, -d2 본문 제외/-d3 본문 포함을 확인했다. `/usr/bin/mdutil -s /`는 Indexing enabled, mds는 running이다. Data 볼륨 alias 조회의 unknown 상태를 시스템 전체 비활성으로 오판하지 않는다.
- 문서 전체 Unicode·페이지 텍스트·parser IR·Semantic IR의 정책 차이를 소스로 대조했다. 선택과 품질·비용 측정은 #339 입력이다.
- 현재 Xcode의 CSImportExtension 템플릿 존재를 macOS 파일 검색 동작의 증거로 삼지 않는다. Apple 현재 API 설명은 macOS에 CFPlugIn importer를 안내한다.
- 근거 파일: build.noindex/spotlight-issue-assessment/{issue337-published.json,mdimport-help.txt,importers-before-unsandboxed.txt}, build.noindex/spotlight-work/sdk-probe.c. macOS 12 runtime은 미실행이다.
