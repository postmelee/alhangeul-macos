# Task M020 #563 Stage 1 완료보고서

- 단계: 글꼴 위치·형식·접근 조건 조사
- 일자: 2026-09-17
- 승인 근거: 같은 대화에서 작업지시자의 “진행해줘”로 구현계획 및 Stage 1 진입 승인
- 마일스톤: M020 / 글꼴 마이그레이션 / v0.2 계열
- 브랜치: `local/task563`
- 산출물: [글꼴 마이그레이션 조사·설계](../tech/font_migration_design.md)
- 상태: Stage 1 조사 완료, Stage 2 승인 대기

## 1. 결과

Mac에서 읽을 수 있는 한컴 앱 내부 글꼴을 실제 확인했다. 설치된 제품은 한컴 편집기가 아닌 **한컴오피스 한글 뷰어 12.31.8 (6446)**이며, `Contents/Resources/Hnc/Shared/TTF/Install`의 문서용 TTF 9개를 식별했다. 공식 편집기 안내의 `TTF/Hwp`와 다르므로 제품·버전별 탐색이 필요하다.

한컴 앱 전체를 검색하면 문서용 9개 외에 UI 아이콘 TTF 1개가 추가된다. 무차별적인 파일 확장자 수집과 사용자에게 제시할 문서 글꼴 후보를 구분해야 한다.

CoreText 이름 목록의 관찰 결과가 프로세스 제한에 따라 달랐다. 일반 호스트 권한에서는 설치된 Pretendard·Spoqa Neo가 목록에 보였으나 제한된 조사 프로세스에서는 보이지 않았다. 한컴 뷰어 내부 HCRBatang은 양쪽 목록에서 없었지만 파일 descriptor는 양쪽에서 생성됐다. **목록에서 없다는 것과 파일이 없다는 것은 다르다.** 실제 알한글의 sandbox 동작은 별도 검증 대상이다.

## 2. 조사·검증 결과

| 검증 | 결과 | 한계 |
|------|------|------|
| 환경·버전 | macOS 26.5.2 (25F84), 알한글 0.2.2 (20), 뷰어 12.31.8 (6446) | 최소 macOS 12와 한컴 편집기 실측 아님 |
| 글꼴 위치·크기·hash | 한컴 문서용 9개, 아이콘용 1개 구분; 문서용 메타데이터·hash 기록 | 앱 코드에서 자동 탐색한 결과 아님 |
| 파일 읽기·CoreText descriptor | 한컴 9개, 공개 static TTF/OTF 표본 성공 | 등록·화면·PDF 사용은 미실행 |
| 이름 매칭 입력 | HCR Batang/함초롬바탕, 한컴돋움/Haansoft Dotum 별칭 확인 | 레거시 name encoding 처리는 후속 설계 |
| TTC·가변 구분 | TTC face 18개; 가변 SF-Pro는 sfnt face 1개·descriptor 36개 | descriptor index와 collection face index 혼동 금지 |
| 접근 조건 | 현재 3개 target의 sandbox·선택 파일 entitlement, 공유 group 미설정 확인 | CLI 읽기 성공은 제품의 접근 성공이 아님 |
| 공식 자료 | Apple 접근·지원 형식, 한컴 Mac/Windows 경로, Microsoft OpenType 및 공개 글꼴 LICENSE 확인 | 한컴 글꼴별 영구 복사·제거 후 사용 조건 미확정 |
| 실험 자산 | OFL static TTF/OTF regular/bold 확보, hash 기록 | 시스템 설치본과 격리할 파생 이름 필요; TTC 생성·가변 자산 확보 후속 |
| 입력 보존 | 조사한 원본 font hash 재확인 | 앱 삭제·폰트 등록·제거·렌더 실험 없음 |

현재 PDF provider의 1,310,720-byte WOFF2 제한과 실제 30 MB 이상 TTF 사이의 차이도 확인했다. 이 사실은 Stage 2 공급 경계 설계에 넘기며 이번 단계에서 제한을 변경하지 않았다.

## 3. 실행 방법과 재현 근거

실행한 읽기 전용 조사:

- `sw_vers`
- Python `plistlib`로 한컴 뷰어와 알한글의 Info.plist 버전·bundle ID 확인.
- 후보 앱 내부와 사용자/공용 글꼴 디렉터리의 파일 목록·확장자 개수 확인.
- Python 표준 라이브러리로 sfnt/TTC 헤더, name·OS/2·fvar 테이블, 파일 크기와 SHA-256 확인.
- `/tmp/task563-stage1/inventory.swift`에서 `CTFontManagerCreateFontDescriptorsFromURL`와 `CTFontManagerCopyAvailablePostScriptNames` 조회. 일반 호스트 권한의 동일 조회를 대조 실행.
- `command -v swift`, `command -v pdffonts`, `command -v pdftotext`, Python의 `fontTools` 모듈 존재 확인.
- 공식 문서의 URL·대상 버전·확인일과 근거를 설계 문서에 기록.

CoreText 확인의 핵심은 다음과 같다. font 등록 API를 호출하지 않는다. 재조회 시 각 프로세스의 권한 범위를 반드시 함께 기록한다.

```swift
import Foundation
import CoreText
let available = Set(CTFontManagerCopyAvailablePostScriptNames() as! [String])
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
        as? [CTFontDescriptor] ?? []
    for descriptor in descriptors {
        let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute)
            as? String ?? ""
        print(url.lastPathComponent, name, available.contains(name))
    }
}
```

raw 조사 결과와 모듈 캐시는 `/tmp/task563-stage1/`에만 있다. 저장소에는 글꼴 bytes·사용자 절대 경로·binary 산출물을 추가하지 않고 결과 표·hash·재현 방법만 기록한다.

## 4. 미확인 항목과 인계

- 한컴 편집기 및 Windows 설치본의 실제 경로·버전·권한은 미검증이다. 공식 안내와 실측을 분리했다.
- 한컴 글꼴 전체의 영구 복사·제거 후 사용 권한을 확정하지 못했다. 공개 OFL 글꼴로 기술 실험을 진행할 수 있으므로 조사·설계를 중단할 사유는 아니며, 실제 한컴 지원의 수용 조건으로 남긴다.
- 앱 sandbox의 사용자 선택·지속 접근과 확장 공유는 Stage 2 설계 및 #565 / #568 실제 앱 검증에 인계한다.
- static TTF·OTF의 독립 공급은 Stage 3에서 검증한다. TTC는 OFL 표본으로 생성, variable는 공식 release 파일을 고정해 준비하는 계획을 정했다.
- fontTools 미설치는 준비 항목이다. 추후 전용 환경에 도구를 준비하거나 동등한 방법을 사용한다.

## 5. 범위·문서 검증

- 제품 코드, entitlement, project.yml, core pin, 번들·설치 글꼴 변경 없음.
- 계획서 승인 상태와 오늘할일을 갱신했다.
- `git diff --check` 및 참조 표기 검증을 수행한다.
- 본 단계에서는 앱 빌드·PDF 렌더·Quick Look smoke를 실행하지 않았다. 조사 결과와 후속 조건 정리를 완료했으며 기능 지원 완료를 주장하지 않는다.

## 6. 다음 단계 승인 요청

Stage 2에서 독립 보관·중복/이름 매칭·화면/PDF/확장 공급 계약을 설계한다. 단계별 승인 규칙에 따라 본 보고서 승인 전에는 Stage 2에 진입하지 않는다.
