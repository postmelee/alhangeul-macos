# Task M020 #341 Stage 3 완료보고서

## 실제 importer 호출·앱 빌드 검증 및 보고

## 최종 검증

- HostApp Debug/Release build PASS, 최종 export 목록 기준 재실행.
- Release 앱의 HostApp/Preview/Thumbnail/importer 4개 universal 실행 파일 검사 PASS.
- CFPlugIn 직접 검증 최종 11개 사례 PASS: HWP/HWPX 본문, 빈 HWPX, missing/invalid/DRM/empty/directory/symlink/FIFO/초과 파일의 기존 본문 제거. Debug도 동일 검사 PASS.
- `vtool -show-build`: importer 두 slice 모두 minos 12.0. `otool -L`: AppKit/Swift framework 직접 의존 없음.
- factory 전용 export 목록과 dead stripping으로 importer 실행 파일 118,231,072 → 27,847,160 bytes. 두 slice의 공개 정의 심볼은 AlhangeulImporterFactory 하나다.
- 실제 `package-release.sh 0.1.11` 개발용 zip 생성 PASS. 최종 zip SHA256 `6f1a913291bd0d17e1c42c8e1783e5813fd375e7f6fe582c0de03038e4b9bd2b`. 공개 릴리스 산출물이 아니다.
- package 앱 `codesign --verify --deep --strict` PASS, importer는 ad-hoc 로컬 서명이며 Developer ID/공증을 수행하지 않았다.
- no-AppKit와 git diff 형식 검사 PASS.

## 인계

최종 개발용 설치 후보는 build.noindex/spotlight-work/package/release/Alhangeul.app이다. 시스템 등록/본문 색인/검색/수정·삭제·보호 변경과 복원은 #342 작업에서 검증한다. macOS 12 runtime은 미실행이다. 실제 검색 화면은 해당 작업에서 수집한다.
