# Task M010 #497 Stage 1 보고서

## 단계 목적

승인된 HWP3 저장 수정안에 따라 NSSavePanel의 파일 단위 sandbox 권한과 호환되는 임시 저장 위치를 사용하고 기존 배타적 게시 계약을 유지한다.

## 산출물

`DocumentSaveContract.swift`, `DocumentSaveContractTests.swift`, 이 보고서와 오늘할일. 근거 로그는 `build.noindex/task497/host-tests.log`, `no-appkit.log`, `xcodegen.log`다.

## 변경과 보존

임의 sibling 임시 파일 생성을 FileManager의 itemReplacementDirectory로 바꿨다. 같은 volume의 임시 디렉터리에서 완성본을 만든 뒤 RENAME_EXCL로 게시하고 defer로 디렉터리를 정리한다. 일반 overwrite 허용 저장·보호 경고·문서 변환·core·Studio·entitlement는 변경하지 않았다. 기본 publisher를 주입 함수의 기본값으로 연결해 실제 배타적 rename에 대한 경쟁 생성 테스트를 추가했다.

## 검증

- HostAppTests 184개 통과. 기존 실패 후 정리 테스트를 강화하고 경쟁 destination 보존·게시 실패 정리·성공 후 정리 3개를 추가했다.
- XcodeGen 생성 후 추적 project diff 없음. AppKit 공통 경계 검사 통과.
- 첫 테스트 실행은 도구 sandbox가 Xcode/Swift 캐시 쓰기를 막아 의존성 준비에서 중단됐다. 정상 개발 권한으로 재실행한 결과 전체 성공했으며 제품 오류로 분류하지 않는다.
- `git diff --check` 통과.

## 잔여 위험

Unit test의 임시 디렉터리 접근 성공은 NSSavePanel 파일 단위 권한 성공을 대신하지 않는다. 실제 sandbox 앱과 네 가지 HWP3 변환 조합은 Stage 2에서 검증한다.

## 다음 단계

같은 승인 범위의 Stage 2에서 ad hoc 서명 Debug 앱의 sandbox·user-selected.read-write entitlement 및 비활성 endpoint를 확인하고 실제 문서 저장·재열기를 검증한다. 공증된 새 release draft 검증과 구분한다.

## 승인 범위

2026-09-06 작업지시자가 별도 이슈 등록·수정·회귀 검증 진행을 승인했다. 이 범위에서 Stage 2를 계속 수행하며 tag·main·공개 배포는 실행하지 않는다.
