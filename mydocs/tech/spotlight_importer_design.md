# Spotlight 문서 본문 검색 설계

## 목적과 소유 경계

사용자가 파일명에 없는 문서 단어로 HWP/HWPX 파일을 찾게 한다. macOS의 파일 색인용 CFPlugIn `.mdimporter`가 파일 bytes를 읽고 RustBridge 본문 추출 API를 호출하여 `kMDItemTextContent`를 전달한다. HostApp의 WKWebView, Core Spotlight 앱 색인, 페이지 bitmap/Quick Look 응답은 이 데이터 경로에 포함하지 않는다.

Apple의 [CSImportExtension 안내](https://developer.apple.com/documentation/corespotlight/csimportextension)는 macOS custom file에 Spotlight importer plugin을 사용하도록 명시한다. [MDImporter](https://developer.apple.com/documentation/coreservices/file_metadata/mdimporter)의 callback은 앱이 실행되어 있거나 window server/UI가 준비됐다는 가정을 하지 않는다. 현재 SDK 헤더를 기준으로 구현하며 보관 문서의 오래된 CLI 예는 현재 도움말과 대조한다.

| 계층 | 책임 |
|---|---|
| upstream rhwp | 형식 판별·문서 parser와 공통 모델 |
| RustBridge | 형식/보호 정책·공통 모델 순회·UTF-8/한도/상태·메모리 해제 |
| SpotlightImporter | 파일 읽기, CFPlugIn 수명, metadata dictionary 구성 |
| HostApp bundle / release scripts | importer embedding·식별자·서명·universal 검사 |
| smoke helper | 실제 선택된 importer, 추출 시험, 색인/검색, 복원 결과 |

## bundle 및 인터페이스

- 타깃: `SpotlightImporter`, 제품: `Alhangeul.mdimporter`.
- bundle ID: `com.postmelee.alhangeul.SpotlightImporter`.
- 위치: `Alhangeul.app/Contents/Library/Spotlight/Alhangeul.mdimporter`.
- XcodeGen `project.yml`에서 macOS bundle을 생성하고 HostApp copy phase가 제품을 지정 위치에 넣는다. generated xcodeproj는 편집하지 않는다.
- Objective-C와 CoreFoundation/CFPlugInCOM/CoreServices를 사용해 `MDImporterInterfaceStruct`의 QueryInterface/AddRef/Release/ImporterImportData를 제공한다. factory UUID는 이 bundle만 소유하고 Info.plist와 코드가 같은 값을 사용한다.
- 최소 OS 12.0, arm64/x86_64. SDK compile은 최소 OS 실제 실행을 대신하지 않는다.
- CFPlugIn은 `.appex`가 아니므로 PlugInKit의 Preview/Thumbnail active provider 판정을 importer 판정으로 대체하지 않는다.
- Swift/AppKit UI 계층을 링크하지 않는다. Rust 정적 링크가 요구하는 SDK 라이브러리는 명시하고 최종 binary의 의존성과 크기를 검사한다. Skia 포함 staticlib가 실제 importer 전체 크기를 의미한다고 단정하지 않는다.

## UTI와 metadata

앱의 기존 document type 9종을 지원 목록의 입력으로 사용한다. importer schema와 Info.plist 목록이 앱 선언에 맞는지 검사한다. 확장자가 같더라도 다른 앱의 exported type이 선택될 수 있으므로 실제 파일 content type과 importer 경로를 증거로 남긴다.

- `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx`
- `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`
- `com.hancom.hwp`, `com.hancom.hwpx`
- `com.haansoft.hancomofficeviewer.mac.hwp`, `com.haansoft.hancomofficeviewer.mac.hwpx`
- `org.libreoffice.hwp-document`

MVP는 본문과 파일명에서 얻는 표시 제목, 문서 kind를 제공한다. 문서 내부 author/title/date의 품질과 개인정보 정책이 검증되지 않았다면 추정하여 제공하지 않는다. metadata key는 Apple 표준 key를 사용하고 사용자 정의 검색 schema를 불필요하게 늘리지 않는다.

원문 파일은 읽기 전용이다. 네트워크, 외부 이미지 경로 로드, 앱 비밀번호 저장소, 접근 권한 dialog, 변환 파일 생성은 사용하지 않는다. 추출된 본문은 macOS Spotlight 색인으로 전달되며 별도 앱 cache/로그에는 저장하지 않는다. 합성 시험 fixture의 본문 출력만 검증 증거로 보존한다.

## 추출 정책 입력

구체적인 지원/순서/문자/한도/ABI 계약은 [본문 추출 계약](spotlight_text_extraction_contract.md)에서 확정한다. 해당 문서는 후속 #339 산출물이다.

- HWP3/HWP5/HWPX 평문을 비교 대상으로 한다. 지원은 실제 parser와 fixture로 검증한 뒤 확정한다.
- 비밀번호·DRM·배포용 문서는 비대화형 동작과 정보 노출을 고려해 기본 제외 후보로 둔다.
- 표·글상자·중첩·각주·머리말·양식·메모·숨은 글의 포함 여부와 순회를 명시한다. 화면 표시 결과와 모델 전체를 같다고 가정하지 않는다.
- DocumentCore의 전체 layout을 무조건 재사용하지 않고 parse-only 후보를 우선 비교한다.
- 입력 bytes, 출력 UTF-8 bytes, 순회 node 수·깊이를 제한하고 절단을 호출자에게 명시한다. parser 내부의 모든 CPU/메모리를 중단할 수 있다는 보장은 별도 근거가 없으면 하지 않는다.
- UTF-8 bytes의 명시 길이와 전용 해제 API를 사용하며 빈 결과와 실패를 구분한다. 오류에는 문서 본문·경로를 넣지 않는다.

## 검증 구조

| 검증 | 성공 증거 | 구분할 한계 |
|---|---|---|
| SDK/compile/link | 두 architecture와 deployment target, CFPlugIn ABI | macOS 12 runtime과 별개 |
| 직접 CFPlugIn 호출 | bundle factory·QueryInterface·실제 metadata 반환 | 시스템 등록·색인과 별개 |
| `mdimport -L` | 설치한 importer의 경로 | 그 파일에 선택됐다는 증거가 아님 |
| `mdimport -t -d3` / `-o` | 사용 importer·본문과 기본 속성 | `-t`는 index를 갱신하지 않음 |
| `mdimport -i` 후 `mdfind` | 본문 전용 고유 단어가 정확한 파일 경로를 반환 | 비동기 대기·제외 위치·경쟁 importer 영향 |
| 수정·삭제·교체 | 새 단어 등장, 옛 단어와 삭제 파일 사라짐 | timeout을 자동 성공 처리하지 않음 |
| 업데이트/등록 복원 | 교체 bundle 선택과 재색인, 기존 설치 복원 | 실제 Sparkle 공개 업데이트와 구분 |

`mdimport -d2` 단독 호출을 사용하지 않는다. 현재 `-d`는 `-t`가 필요하고 `-d2`는 본문을 숨긴다. `mdls`에 `kMDItemTextContent`가 보이는지 여부만으로 본문 색인 성공을 판정하지 않는다.

## 설치와 정리

1. 실제 설치본과 importer 목록, root volume indexing, test document hash와 작업 앱 여부를 기록한다.
2. 개발 앱과 중간 산출물은 `build.noindex` 아래에 둔다. 실제 설치 시험은 명시한 격리 설치 위치를 사용하고 기존 설치를 덮어쓰기 전에 복원 방법을 확보한다.
3. 본문 검색 fixture는 `.noindex`/`/tmp` 밖의 검색 가능한 격리 위치에 두고 합성 데이터만 사용한다. filename에는 검색 단어를 넣지 않는다.
4. importer test와 실제 index 검색을 구분한다. 최초 설치, 첫 실행, 앱 미실행, 교체 후 재색인을 관찰한다.
5. 등록한 시험 앱은 unregister하고 시험 문서·설치본만 정리한다. 기존 앱/등록을 복원하고 Preview/Thumbnail 등록 위생도 확인한다. 전체 index 초기화·system daemon kill을 정상 경로로 사용하지 않는다.
6. 스크린샷은 합성 fixture 검색 전·후 실제 화면을 사용한다. 사용자 문서나 무관한 검색 결과는 공개하지 않는다.

## 배포와 완료 판단

신규 importer의 universal 확인과 bundle identifier/실행 파일 누락 검사를 PR CI와 package에 연결한다. release signer는 importer를 HostApp보다 먼저 서명하고 새 내부 bundle을 검증해야 한다. 기존 Sparkle/Preview/Thumbnail 서명을 유지한다.

각 하위 PR의 완료와 v0.2.0 공개는 별개다. 현재 OS의 개발 설치본 시험·SDK target 검증을 공증 배포본/macOS 12/Sparkle 실제 업데이트 성공으로 확대하지 않는다. 공개 릴리스 전 해당 검증 또는 명시적인 지원/출시 판단을 기록한다. 이 설계는 버전 값을 올리거나 배포를 실행하지 않는다.
