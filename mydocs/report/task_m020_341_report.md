# Task M020 #341 최종 결과보고서

## 작업 요약

앱 내부 Contents/Library/Spotlight에 Alhangeul.mdimporter를 포함했다. CFPlugIn factory와 metadata callback이 #340 UTF-8 ABI를 사용한다. universal·bundle·서명·CI·개발 패키지 검증을 importer까지 확장했다.

## 변경 파일과 영향

| 영역 | 영향 |
|---|---|
| Sources/SpotlightImporter | CFPlugIn/파일 읽기/metadata, factory export·Info·UTI schema |
| project.yml, Alhangeul.xcodeproj | XcodeGen bundle target과 app copy phase; pbxproj는 생성 결과 |
| scripts/ci 및 verify-spotlight-importer.sh | 정적 bundle 계약과 실제 callback/실패 제거 검사 |
| scripts/release.sh, package-release.sh | importer 버전·universal·내부 서명·preflight 및 package 검증 |
| .github/workflows/pr-ci.yml, 매뉴얼 | PR gate와 운영 기준 |
| mydocs/plans/working/orders | 계획·3개 Stage·완료 기록 |

## 전후 비교

앱에 없던 파일 metadata importer를 추가했다. 실패·보호·빈 문서는 이전 본문을 제거하는 metadata를 제출한다. 파일명 제목/종류만 남기며 앱 UI나 외부 자원을 열지 않는다. factory만 공개하도록 제한해 importer binary를 약 118 MB에서 28 MB로 줄였다.

## 검증 결과

| 기준 | 결과 |
|---|---|
| HostApp Debug/Release | OK |
| 4개 실행 파일 arm64/x86_64 | OK |
| bundle UTI/factory/schema/version과 음성 fixtures | OK — 3 suite |
| 실제 CFPlugIn 직접 호출 | OK — 최종 11사례, Debug/Release |
| 파일 한도/특수 파일/DRM/실패/빈 결과 제거 | OK — 직접 callback |
| 실행 파일 최소 target 및 의존성 | OK — 두 slice minos 12.0, 직접 AppKit/Swift 없음 |
| 실제 개발용 zip 및 ad-hoc 서명 무결성 | OK |
| no-AppKit/구문/YAML/diff | OK |
| 시스템 XSD regex 검사 | MISS — Apple Mail importer 대조도 같은 오류 |
| 시스템 mdimport·실제 색인/검색 | MISS — #342 설치 smoke 대상 |
| macOS 12 runtime, Developer ID/공증 | MISS — 환경 없음 / 이번 실행 범위 제외 |

## 잔여 위험과 후속 작업

직접 callback 성공은 시스템의 실제 importer 선택이나 본문 검색 성공을 보장하지 않는다. #342 작업에서 격리 설치·mdimport·mdfind·파일 변경·보호 변경·삭제·교체 및 복원을 실행한다. 시스템 XSD 도구 오류는 XML/계약 검사와 별도로 기록했으며 등록 수용 여부도 확인한다.

## 리뷰 인계

PR은 devel 대상, 계획/Stage/commit/최종 보고를 SHA 링크로 연결한다. 내부 bundle 추가 자체는 독립 UI가 없어 합성 screenshot을 만들지 않았다. 실제 검색 증거는 #342 작업에서 제공한다. PR merge·버전 상향·공개 배포는 사용자 리뷰 후 별도로 진행한다.
