# 글꼴 마이그레이션 조사·설계

- 관련: [상위 #562](https://github.com/postmelee/alhangeul-macos/issues/562), [조사·설계 #563](https://github.com/postmelee/alhangeul-macos/issues/563)
- 마일스톤: M020 / 글꼴 마이그레이션 / v0.2 계열
- 확인일: 2026-09-17
- 현재 범위: Stage 1 조사 결과. 독립 저장 계약과 화면·PDF 실험은 Stage 2·3에서 진행한다.

## 1. 조사 결론

1. 같은 Mac에서도 **OS 설치 글꼴**과 **한컴 앱 내부 글꼴**은 별개다. CoreText 목록만으로 한컴 앱 내부 글꼴을 모두 찾을 수 없다.
2. 설치된 한컴 **뷰어**에서 문서용 TTF 9개를 확인했다. 편집기 공식 안내의 `TTF/Hwp`와 달리 이 뷰어는 `TTF/Install`에 보관한다. 제품·버전별 후보 경로와 수동 선택 대안이 필요하다.
3. 조사 도구의 실행 제한에 따라 설치 글꼴 목록이 달라졌다. CLI 읽기 성공은 실제 알한글 sandbox·WebContent의 접근 성공을 의미하지 않는다.
4. 로컬 TTF·OTF·TTC 및 가변 TTF의 메타데이터 조회는 가능했다. 실제 앱 적용·PDF·다른 Mac/Windows 버전의 호환성은 아직 검증하지 않았다.
5. 한컴 제거 후 독립 사용에는 가져온 파일의 수명뿐 아니라 사용·복사 조건 확인이 필요하다. `fsType`은 임베딩 정보이며 영구 복사·재배포 권한의 충분한 근거가 아니다.

## 2. 확인 환경과 측정 경계

| 항목 | 확인 결과 |
|------|-----------|
| OS | macOS 26.5.2, build 25F84 |
| 설치된 알한글 | 0.2.2 (20), bundle ID `com.postmelee.alhangeul` |
| 조사한 한컴 제품 | Hancom Office HWP Viewer 12.31.8 (6446), `com.haansoft.HancomOfficeViewer.Mac` |
| 한컴 편집기 | `/Applications`와 사용자 Applications의 일반 설치 후보에서 발견하지 못함. 다른 위치까지 부재를 단정하지 않음 |
| core 기준 | `rhwp v0.8.6`, `f1f9c6ae58344ee9368996d3543f76b9345cf227` |
| 제품 최소 대상 | `project.yml` 기준 macOS 12.0. 이번 조사는 macOS 12 실행 검증이 아님 |
| Windows | 이번 단계에서 실설치 환경 조사 없음. 공식 경로 안내만 확인 |
| 도구 | Swift/CoreText, Python 표준 라이브러리, `pdffonts`, `pdftotext` 사용 가능. 현재 기본 Python에 fontTools 없음 |

Info.plist, 디렉터리, font bytes를 읽어 메타데이터만 조사했다. font 등록 API, 앱 실행·삭제, 시스템 글꼴 수정, Quick Look 등록, PDF 렌더 실험은 수행하지 않았다.

## 3. 출처별 위치·지원 표

경로는 공식 설치 예시 또는 사용자 이름을 제거한 상대 경로다. 다른 앱 컨테이너를 무단으로 탐색하는 기능을 전제로 하지 않는다.

| 출처 | 경로 후보 | 근거·상태 | 다음 확인 |
|------|-----------|-----------|-----------|
| Mac 한컴 뷰어 12.31.8 | 앱 내부 `Contents/Resources/Hnc/Shared/TTF/Install` | 실측: TTF 9개, 전부 파일 읽기·descriptor 생성 가능 | 실제 알한글 sandbox의 탐색·사용자 선택 접근 |
| Mac 한글 편집기 | 앱 내부 `Contents/Resources/Hnc/Shared/Fonts`, `Contents/Resources/Hnc/Shared/TTF/Hwp` | [한컴 공식 안내](https://www.hancom.com/support/faqCenter/faq/detail/2821). 편집기 실측 아님 | 편집기 제품·버전별 실제 파일과 권한 |
| Mac 사용자 설치 글꼴 | `~/Library/Fonts` | 실측: TTF 103, OTF 30, `.gz` 18개 파일. 파일 개수이며 설치 활성화/face 수와 다름 | CoreText와 승인된 경로 탐색의 조합 |
| Mac 공용 설치 글꼴 | `/Library/Fonts` | 실측: TTF 9, OTF 81개 파일 | 동일 이름·버전 충돌과 실제 앱 접근 |
| Mac 시스템 글꼴 | `/System/Library/Fonts` | 선택한 TTC만 읽기 확인. 사용자 이전 대상과 구분 | 시스템 기본 fallback으로 유지, 제품 복사 대상으로 일괄 취급하지 않음 |
| Windows 시스템 설치 | `%WINDIR%\Fonts` | [한컴 안내](https://www.hancom.com/support/faqCenter/faq/detail/2680)에 `C:\Windows\Fonts` 사례. 실측 없음 | 설치 위치에서 원본을 복사해 ZIP 만드는 실제 절차 |
| Windows 사용자 설치 | `%LOCALAPPDATA%\Microsoft\Windows\Fonts` | 추가 조사 후보. 이번에는 경로의 공식 계약·실설치 미검증 | 사용자 단위 설치본 확인 후 사용자 안내에 반영 |
| Windows 한글 2014 | 설치 루트 `Hnc\HOffice9\Shared\TTF\Hwp`, `Shared\Fonts` | 위 한컴 안내의 버전별 사례 | TTF와 HFT를 구분해 수집 |
| Windows NEO 이후 | 설치 루트 `Hnc\OfficeX\HOffice{버전}\Shared\TTF\Hwp`, `Shared\Fonts` | 위 한컴 안내의 버전별 사례. 공식 페이지 오타를 정규 경로의 보장으로 해석하지 않음 | 설치본의 실제 Program Files/Program Files (x86) 위치 |
| Windows 한글 2022 HFT | `C:\Program Files (x86)\Hnc\Office 2022\HOffice120\Shared\Fonts` | [한컴 2022 도움말](https://help.hancom.com/hoffice120/ko-KR/Hwp/file/options/options%28font%29.htm) | HFT는 초기 미지원, 발견·안내만 고려 |

한컴 뷰어 앱 전체에는 TTF가 10개 있으나, 1개는 GCDWebUploader의 `glyphicons-halflings-regular.ttf`다. 프레임워크 내부 UI 아이콘 파일을 사용자가 원한 문서 글꼴로 자동 선택하지 않아야 한다. 서브디렉터리 구분은 제품 탐색 설계에 인계한다.

Microsoft는 Windows 10/11에서 사용자용 설치와 모든 사용자용 설치를 구분하고, 글꼴 설치와 개별 앱 지원이 다를 수 있다고 설명한다. [Microsoft 글꼴 관리](https://support.microsoft.com/en-us/windows/experience/personalization/manage-fonts-in-windows)

## 4. 메타데이터와 목록 조회 관찰

`CTFontManagerCreateFontDescriptorsFromURL`로 등록하지 않고 font descriptor를 읽었다. [Apple API 문서](https://developer.apple.com/documentation/coretext/ctfontmanagercreatefontdescriptorsfromurl(_:))

한컴 뷰어 문서용 9개는 모두 static TrueType이며 파일당 sfnt face 1개다. 전체 파일의 hash와 크기를 읽었고, 아래 표에서 본 단계의 식별 근거를 보존한다.

| 파일 | PS 이름 | 버전 | 크기(bytes) | fsType | SHA-256 |
|------|---------|------|-------------|--------|---------|
| HANBatang.ttf | HCRBatang | Version 2.100; Build 20170117 | 28413328 | 8 | `c5d544769d832477d48b7318222b9c3c2eced25455f7ba9acb23060dcecac104` |
| HANBatangB.ttf | HCRBatang-Bold | Version 2.100; Build 20170117 | 30692160 | 8 | `0d355f9766ffd1c7ec7648260611ddea9e12ea3c610423e552d52b921fc0f29f` |
| HANBatangExt.ttf | HCRBatangExt | Version 1.500; Build 20140709 | 1721716 | 8 | `f88d957a26dd5a6360424e37b6d25b4192a83d922b7ac1fa9fb92d34e579afe4` |
| HANDotum.ttf | HCRDotum | Version 2.100; Build 20170117 | 22252900 | 8 | `1d0437906d52e96af36943008f144ad74d6e994493df3a4210a9761e077ea898` |
| HANDotumB.ttf | HCRDotum-Bold | Version 2.100; Build 20170117 | 31085224 | 8 | `5b0b9fa5f3ba2f7b2e3576c6c2e2f2a7a92f68c98f8270e10791ceb363ce1e51` |
| HANDotumExt.ttf | HCRDotumExt | Version 1.500; Build 20140709 | 1717916 | 8 | `a2828746031f9e725b667ab1e5c96b553b6b42d24d55669a4472605692f8807c` |
| HDotum.TTF | Haansoft-Dotum | Version 1.30 | 22877444 | 0 | `b05e5e2f646961c7bdcb9904a7b6d84d288d9c44c3955d60b254cc8ad2305a76` |
| HYHWPEQ.TTF | HyhwpEQ | Version 1.13 | 155612 | 0 | `a3a3cd992a89ac38e7707b58143ebdb1da9511d3c462f019cda7f92c30467807` |
| HancomEQN.ttf | HancomEQN | Version 1.0 | 244816 | 0 | `c249c422e4acbafe2757c0f4a5d714414f84305c728776d889224f6116186e35` |


`HANBatang.ttf`의 Unicode name 레코드에는 `HCR Batang`과 `함초롬바탕`이 함께 있다. `HDotum.TTF`는 `한컴돋움`과 `Haansoft Dotum`이 있으며 PostScript 이름은 `Haansoft-Dotum`이다. CoreText의 한 가지 표시 이름만 저장하면 문서의 다른 이름과 연결할 정보가 누락될 수 있다. 레거시 name encoding은 플랫폼/encoding에 맞춰 처리해야 하며 단일 인코딩으로 읽은 깨진 문자열은 별칭으로 등록하지 않는다.

### 조사 프로세스 제한의 영향

| 표본 | 제한된 조사 프로세스의 available PS 목록 | 일반 호스트 권한으로 재조회 | 파일 descriptor 생성 |
|------|-------------------------------------------------|---------------------------|----------------------|
| HCRBatang | 없음 | 없음 | 양쪽 성공 |
| Pretendard-Regular | 없음 | 있음 | 양쪽 성공 |
| SpoqaHanSansNeo-Regular | 없음 | 있음 | 양쪽 성공 |
| AppleSDGothicNeo-Regular | 있음 | 있음 | 양쪽 성공 |

동일한 읽기 전용 코드를 사용했다. 이 결과는 **해당 프로세스에서 보이는 목록**이며 전체 OS의 설치 유무나 실제 알한글의 목록을 의미하지 않는다. `globallyAvailable`이라는 임시 결과 필드 역시 `CTFontManagerCopyAvailablePostScriptNames()` 포함 여부만 뜻한다. 본문에서는 전역 설치 여부로 해석하지 않는다.

### 형식별 현재 판정

| 형식 | 실측 또는 공식 근거 | Stage 1 판정 |
|------|--------------------|--------------|
| static TTF | 한컴 9개, Spoqa Neo Regular/Bold descriptor 생성 및 signature 확인 | 읽기·식별 확인, 렌더 공급 미검증 |
| static OTF/CFF | Pretendard Regular/Bold `OTTO` signature와 descriptor 확인 | 읽기·식별 확인, 렌더 공급 미검증 |
| TTC | AppleSDGothicNeo.ttc 헤더의 face 18개와 descriptor 18개 확인 | collection 구분 가능, 개별 face 공급 미검증 |
| variable TTF | SF-Pro.ttf의 sfnt face는 1개, `fvar` 존재, CoreText descriptor는 36개 | descriptor 순번을 TTC face index로 취급하면 안 됨. 축·instance 연결은 후속 |
| HFT | 한컴 전용 형식이라는 공식 안내. 로컬 표본 없음 | 초기 지원 제외; TTF와 같은 이름이라고 동일 글꼴로 보장하지 않음 |
| `.pcf.gz` 등 | 사용자 폴더에서 지원 후보 외 파일 존재 | 확장자 검색만으로 전부 가져오지 않음 |

Apple은 macOS가 TTF·가변 TTF·TTC·OTF·OTC를 지원한다고 안내한다. 이는 알한글의 모든 출력 경로에서 지원됨을 의미하지 않는다. [Apple 서체 지원 형식](https://support.apple.com/en-ca/guide/font-book/fntbk1000/mac)

## 5. 샌드박스·지속 접근·공유 조건

[Apple 파일 접근 문서](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)에 따르면 사용자 선택 폴더는 하위 항목 접근을 확장할 수 있으나 다른 권한으로 실패할 수 있다. 재실행 후 외부 원본 접근을 유지하려면 security-scoped bookmark의 복원·scope 수명 관리가 필요하다. 자기 컨테이너 보관과 외부 원본 지속 참조를 구분해야 한다.

| 현재 코드 | 확인 사항 | 설계에 넘길 조건 |
|-----------|-----------|------------------|
| HostApp.entitlements | sandbox, user-selected read-write 사용 | 가져오기에는 읽기 최소 범위 사용; 실제 폴더 선택 검증 필요 |
| QLExtension/ThumbnailExtension.entitlements | sandbox, user-selected read-only 사용 | 호스트가 읽는 관리 글꼴을 확장도 읽을 수 있다는 보장 없음 |
| 3개 target entitlement | `application-groups` 및 `files.bookmarks.app-scope` 명시 없음 | 저장소 공유·지속 접근 필요에 따라 entitlement 계약 검토 |
| RecentDocumentStore.swift | security-scoped bookmark 생성·복원 코드 존재 | 구현 존재와 현재 서명 환경에서의 지속 접근 성공은 별도 확인 |
| FontResourceRegistry.swift | 번들 WOFF2를 `.process`로 등록 | WebContent/다른 프로세스에 등록이 자동 전파된다고 가정하지 않음 |

App Group은 앱과 확장이 데이터를 공유하는 공식 수단이다. 현재 활성화되지 않았으므로 identifier·서명·지원 OS 조건까지 설계해야 한다. [Apple App Group 설정](https://developer.apple.com/documentation/xcode/configuring-app-groups)

현재 PDF 폰트 공급자는 번들 WOFF2 allowlist와 파일당 1,310,720-byte 한도를 가진다. 조사한 한컴 TTF 중에는 30 MB를 넘는 파일도 있다. 기존 공급자에 경로만 추가하는 것으로 가져오기를 지원할 수 없으며, 형식·용량·리소스 경계를 Stage 2에서 별도 검토한다.

## 6. 사용·복사·임베딩 조건

- 한컴의 [제공 글꼴 공지](https://www.hancom.com/news/notice/detail/11458)는 2022-04-25 기준 글꼴별 사용 범위 자료를 별도 첨부한다고 설명한다. 이번 웹 조회에서는 첨부 원문의 개별 조건을 확보하지 못했다. 최신 뷰어 12.31.8의 글꼴 전체에 이 과거 공지를 포괄 적용하지 않는다.
- 현재 한컴 글꼴의 영구 복사·한컴 제거 후 사용·제품 재배포 허용 여부는 **미확정**이다. 본 단계에서는 파일을 읽어 식별만 했고 상용 글꼴을 복사·재배포하지 않았다.
- OpenType `OS/2.fsType`은 임베딩 동작의 입력이다. `0`과 `8`의 의미가 다르고, subset 제한 등 추가 bit도 고려해야 한다. 이 값만으로 별도 EULA가 부여하는 영구 보관 권한을 단정하지 않는다. [Microsoft OpenType 규격](https://learn.microsoft.com/en-us/typography/opentype/spec/os2#fstype)
- Pretendard와 Spoqa Han Sans Neo의 공식 라이선스는 SIL OFL 1.1이다. 복사본에는 고지를 보존하고, 격리 실험용으로 내부 이름·형식을 바꾸면 Reserved Font Name 조건을 지킨다. [Pretendard LICENSE](https://github.com/orioncactus/pretendard/blob/main/LICENSE), [Spoqa LICENSE](https://github.com/spoqa/spoqa-han-sans/blob/main/LICENSE)

이는 조사 결과와 제품 설계 입력이다. 사용자에게 한컴의 모든 글꼴을 제한 없이 가져올 수 있다고 안내할 근거는 아직 없다.

## 7. Stage 3 자산 준비 계획

| 목적 | 확보 상태·자산 | 준비 및 제한 |
|------|----------------|--------------|
| 한글 TTF regular/bold | 로컬 Spoqa Han Sans Neo 1.100 두 파일 읽기 확인 | OFL 고지와 출처 보존. 시스템에 설치되어 있으므로 허용된 별도 내부 이름의 실험 파생본을 만들고 새 이름이 시스템에 없는지 확인 |
| 한글 OTF regular/bold | 로컬 Pretendard 1.309 두 파일 읽기 확인 | 위와 동일. `Pretendard` 등 RFN을 실험 파생본의 사용자 표시 이름에 사용하지 않음 |
| TTC 공급 실험 | 시스템 TTC는 메타데이터만 확인 | OFL TTF 두 face로 별도 collection을 생성하는 방법을 Stage 2에서 확정. fontTools 등 도구 준비 필요. 상용/시스템 TTC 복사로 대체하지 않음 |
| 가변 글꼴 | SF-Pro는 메타데이터만 확인 | [Pretendard 공식 배포](https://github.com/orioncactus/pretendard/releases)의 variable 파일을 추후 특정 release·hash·LICENSE로 고정해 확보. 아직 binary 미확보 |
| 한컴 실제 호환성 | 뷰어 9개 파일의 위치·메타데이터 확보 | 사용 조건 확인 후에만 실험 대상 선정. 편집기 실설치와 동일하다고 간주하지 않음 |
| 손상·중복·미지원 입력 | 합성 가능 | 실험 복사본에서만 생성하고 원본 보존 |

| 로컬 검증 자산 | SHA-256 |
|----------------|---------|
| Pretendard-Regular.otf | `3ffbacde6ab8411f1d2db54bb9b1f0b3ee2a738932033722cf0388c06aed1c93` |
| Pretendard-Bold.otf | `2e91915fab54df71cc9598ebf608b2bdb54c6fe3c066ac61dff0bc44fca71cc7` |
| SpoqaHanSansNeo-Regular.ttf | `9c53606e813ee2a94e7bd912d52fc8779ae4117977150b202004ba1c6a088818` |
| SpoqaHanSansNeo-Bold.ttf | `00e4785f08877428325e44c0691b46243ed8285490a698d4f4514288e67fdd16` |


화면·PDF 실험의 필수 시작 자산은 확보된 OFL static TTF/OTF로 충족한다. TTC·가변·실제 편집기·Windows 설치본은 조건부 검증으로 분리한다. Stage 3에서 최종 이름 변경 전후 hash와 face 메타데이터를 다시 기록해야 한다.

## 8. 다음 단계에 남는 질문

- 문서용 후보 디렉터리를 어떻게 찾고, 사용자가 선택한 임의 폴더의 글꼴은 어떻게 구분할 것인가?
- OS 글꼴 목록과 파일 탐색 결과를 합칠 때 출처·동일 이름·여러 버전을 어떻게 보존할 것인가?
- 앱 관리 복사본과 확장 공유 저장소의 수명·권한·등록 실패를 어떻게 연결할 것인가?
- 실제 sandbox 앱과 WebContent에서 가져온 bytes를 읽고 선택하는지 어떻게 입증할 것인가?
- 한컴의 글꼴별 사용 조건과 편집기 버전별 실측을 출시 전 어떤 자료로 보완할 것인가?

이 문서의 Stage 1 완료는 조사·후속 조건 정리를 뜻하며 마이그레이션 구현 또는 제거 후 사용 검증 완료를 뜻하지 않는다.
