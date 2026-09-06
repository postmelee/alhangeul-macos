# Task M020 #341 구현계획서

## Stage 1: CFPlugIn importer와 app bundle 통합

Objective-C CFPlugIn factory와 MDImporter interface를 구현한다. 파일 descriptor의 regular-file/size 검사와 bounded read 후 #340 ABI로 본문을 추출한다. 성공/빈/부분은 표준 metadata를, 보호/실패는 기존 본문 제거값을 반환한다. factory/UTI/schema/identifier를 검증하고 XcodeGen bundle을 HostApp Contents/Library/Spotlight에 포함한다.

## Stage 2: 서명·universal·CI/package 검증 경로 통합

실행 파일과 bundle 계약 검사에 importer를 필수로 추가한다. 공개 release signer/preflight에 importer의 내부 우선 서명/식별자/서명 검증을 넣되 공개 서명·공증은 실행하지 않는다. CI 및 package가 같은 검사를 호출하도록 연결하고 누락/오류 fixture로 음성 경로를 확인한다.

## Stage 3: 실제 importer 호출·앱 빌드 검증 및 보고

HostApp Debug/Release universal build와 실제 CFPlugIn factory/QueryInterface/import callback을 실행한다. 공개/합성 입력의 본문, 실패 후 기존 본문 제거, 빈/한도/파일 read 실패를 확인한다. 설치본 실제 mdimport/색인/search lifecycle은 #342 작업에 맡긴다. 코드·검증·영향·제한을 보고하고 템플릿 PR을 생성한다.

## 수용 기준

앱 내부 importer의 위치/실행 파일/식별자/UTI/factory와 두 architecture가 일치한다. 본문·경로를 제품 로그에 남기지 않는다. AppKit/UI/네트워크/외부 파일/비밀번호 저장소에 의존하지 않는다. build.noindex 산출물을 자동 등록하지 않고 현재 설치본을 유지한다. macOS 12 runtime과 공개 서명/공증은 미실행으로 보고한다.
