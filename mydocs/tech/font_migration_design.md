# 글꼴 마이그레이션 조사·설계

## 2026-09-20 현재 적용 기준

Mac 기본 목표는 **활성 설치 글꼴 자동 사용**으로 변경됐다. [#565 수정 계획](../plans/task_m020_565_impl.md)을 현재 기준으로 삼는다. 메타데이터·설정·필요한 권한을 지속하고 필요한 bytes만 읽으며 기존 rhwp 매칭/fallback을 재사용한다. 원본 삭제·비활성·권한 상실 시 계속 사용을 보장하지 않는다. 한컴 앱 내부에만 있는 글꼴 자동 추출은 기본 범위에서 제외한다.

아래 독립 복사·import·manifest·snapshot 계약과 기존 조사 결과는 **별도 Windows ZIP/외부 파일 가져오기 및 관리 자산**에 유효하다. 이를 Mac 설치 참조의 필수 경로로 적용하지 않는다. 설치 참조의 지속 권한·활성 상태·generation/캐시 무효화 계약은 #565 실험 뒤 확정한다. OS 설치나 fsType은 외부 사용 허가의 증명이 아니다.

기존 #563/#564 및 #565 Stage 1–2 결과는 보존한다. Studio 제품 연결은 #567, PDF·인쇄·native·확장은 #568, 전체 수용·웹 안내는 #569 범위다. 최소 연결 probe는 이 소비자들의 완료를 대신하지 않는다.


- 관련: [상위 #562](https://github.com/postmelee/alhangeul-macos/issues/562), [조사·설계 #563](https://github.com/postmelee/alhangeul-macos/issues/563)
- 마일스톤: M020 / 글꼴 마이그레이션 / v0.2 계열
- 확인일: 2026-09-17
- 현재 범위: Stage 1–4 조사·설계·독립 실험·후속 인계 완료. 최종 보고·PR 게시를 승인받았으며 제품 통합은 후속 이슈 범위다.

## 1. 조사 결론

1. 같은 Mac에서도 **OS 설치 글꼴**과 **한컴 앱 내부 글꼴**은 별개다. CoreText 목록만으로 한컴 앱 내부 글꼴을 모두 찾을 수 없다.
2. 설치된 한컴 **뷰어**에서 문서용 TTF 9개를 확인했다. 편집기 공식 안내의 `TTF/Hwp`와 달리 이 뷰어는 `TTF/Install`에 보관한다. 제품·버전별 후보 경로와 수동 선택 대안이 필요하다.
3. 조사 도구의 실행 제한에 따라 설치 글꼴 목록이 달라졌다. CLI 읽기 성공은 실제 알한글 sandbox·WebContent의 접근 성공을 의미하지 않는다.
4. TTF·OTF regular/bold와 가변 TTF의 wght 400/700은 독립 WebView에서 원본 부재 후 재실행·화면·PDF 공급을 확인했다. TTC는 메타데이터 두 face 조회에 성공했지만 raw bytes만 공급하면 bold 요청에도 첫 regular face가 표시됐다. 제품 앱·다른 OS의 호환성을 대신하는 결과는 아니다. 상세는 16절을 따른다.
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

## 9. Stage 2 결정 — 독립 저장과 소유 경계

2026-09-17 Stage 1 승인 후 작성한 **구현 전 설계 계약**이다. 아래 API·저장 형식·제한값은 제안이며 실제 적용 성공은 Stage 3 및 후속 제품 구현에서 검증한다.

### 저장 방식

- 원본을 계속 참조하는 방식 대신 **사용자가 선택한 지원 파일을 앱 관리 영역으로 복사**한다. 원본 위치·bookmark는 출처 표시와 명시적인 재가져오기 보조에만 사용한다. 렌더링은 원본 경로나 한컴 앱의 존재에 의존하지 않는다.
- HostApp·Quick Look·Thumbnail이 사용할 영구 저장소는 App Group container의 `Library/Application Support/FontLibrary/v1/`을 우선안으로 한다. group identifier는 실제 개발팀·서명 설정 확인 후 #564 / #568 이슈에서 확정하고 placeholder 식별자를 제품에 넣지 않는다.
- App Group entitlement가 없는 상태에서 호스트 전용 저장소를 공유 저장소라고 취급하거나 확장이 다른 container를 직접 탐색하게 하지 않는다. group 접근 불가 시 가져오기 커밋을 실패시키고 기존 글꼴 목록을 유지한다.
- 폰트를 OS 글꼴 디렉터리에 설치하거나 한컴 bundle을 수정하지 않는다. 시스템 설치와 별개로 앱만의 수명을 가진다.
- 영구 라이브러리는 cache 디렉터리에 두지 않는다. 삭제/재설치로 앱 관리 데이터까지 제거하면 복사본도 사라질 수 있다는 사용자 안내는 별도 필요하다. 여기서 보장할 목표는 **한컴 앱의 제거와 무관한 수명**이다.

```text
FontLibrary/v1/
  library.lock                  # 프로세스 간 manifest/lease 변경 조정
  current.json                  # schemaVersion, generation, 활성 face·충돌 선택
  objects/<sha256>.font          # 검증한 원본 bytes, 불변 객체
  licenses/<notice-id>.txt       # 확보된 라이선스·출처 고지
  staging/<transaction-id>/      # 미완료 작업; 렌더러 접근 불가
  leases/<session-id>.json       # 사용 중 snapshot의 객체 보존 정보
```

`objects`의 파일 확장자는 사용자 원본 확장자와 독립적이며 실제 signature로 형식을 판정한다. 구현에서는 ASCII 이름의 관리 파일만 만들고 원본 파일명은 표시용 metadata로 보존한다.

### 쓰기·복구·삭제

1. HostApp 내 단일 writer가 파일을 읽기 전용으로 열고 같은 handle에서 bytes를 복사하며 hash·길이·구조를 검증한다. scan 때의 경로/크기만 믿지 않는다. 파일이 변경됐거나 끝까지 읽지 못하면 해당 항목을 실패시킨다.
2. staging에서 메타데이터와 객체를 준비한다. 디스크 부족·취소·개별 파일 실패는 기존 manifest를 변경하지 않는다. 정상 항목만 반영하는 부분 성공은 결과 목록으로 명확히 알린다.
3. 프로세스 간 lock을 잡고 최신 generation을 다시 읽어 중복/충돌을 재판정한다. 객체를 먼저 같은 volume의 최종 경로에 게시하고 마지막에 새 manifest를 atomic replace한다. crash 내구성이 필요한 파일/디렉터리 동기화와 손상 복구를 #564 이슈에서 검증한다.
4. 재실행 시 manifest가 참조하는 객체의 존재·형식을 확인하고, 손상 객체는 사용할 수 없음으로 표시한다. 남은 staging과 manifest에 없는 객체는 활성 lease를 확인한 뒤 정리한다. 알 수 없는 schema는 덮어쓰지 않고 명시적으로 실패시킨다.
5. 사용자 삭제는 먼저 active 목록에서 제거하고 generation을 증가시킨다. 이미 렌더링 중인 snapshot은 끝까지 기존 bytes를 사용한다. 새 문서·새 출력은 새 목록을 사용한다.
6. 물리 삭제는 어떤 활성 lease도 참조하지 않는 객체에만 수행한다. 시간 경과만으로 활성 여부를 판단하지 않는다. #564 Stage 3에서는 PID/시작 식별자 조회 대신 세션별 lease 파일의 kernel flock 소유 여부를 사용한다. 잠금·권한 확인 실패와 손상 lease는 보존한다. 실제 종료·해제 후 회수와 보수적 보존 검증은 [Stage 3 보고](../working/task_m020_564_stage3.md)에 기록했다.
7. 프로세스 간 lock에서 manifest 선택과 lease 생성을 함께 수행해 삭제 경쟁을 막는다. renderer는 해당 lease의 font set만 사용하고 성공·실패·취소 시 해제한다. WebContent가 종료해도 HostApp이 소유한 렌더 세션이 lease를 정리한다.

## 10. 메타데이터·중복·결과 계약

### 최소 모델

| 모델 | 필수 정보·의미 |
|------|---------------|
| FontObject | sha256, byteCount, signatureFormat, collectionFaceCount, validationVersion; 원본 경로 없음 |
| FontFace | objectHash + sfntFaceIndex, 이름 레코드, PostScript 이름, weight/width/slant, coverage 요약, version 문자열, axes/instances, fsType 원값 |
| NameRecord | nameID, platformID, encodingID, languageID/tag, decodedValue; 원래 구분을 보존 |
| SourceReceipt | Mac 앱 / OS 설치 / Windows 묶음 / 수동 폴더, 표시 파일명, 확인 버전, importedAt, 선택적 로컬 bookmark; 문서·WebView로 내보내지 않음 |
| UsageEvidence | localCopy와 embedding 조건을 분리한 상태·출처·확인 시점. 사용자가 확인했다는 사실과 공급자 라이선스 증거를 구분 |
| ActiveSelection | 충돌 그룹별 선택 face, 활성 여부, 선택 이유; 후보들을 일괄 덮어쓰지 않음 |
| FontSnapshot | schemaVersion, generation, resolutionPolicyVersion, 선택 face/axes/공급 상태 및 객체 집합 digest, leaseID |

예: object A의 TTC face 0과 face 1은 서로 다른 FontFace다. 가변 TTF의 여러 named instance는 같은 sfnt face와 다른 axes 조합이며, CoreText descriptor 나열 순서를 face index로 쓰지 않는다. 변환이 필요한 경우 원본 hash와 별도의 파생 hash·변환 버전·라이선스 조건을 보존한다.

| 상황 | 처리 |
|------|------|
| 동일 bytes 재가져오기 | hash로 중복 제거; 이미 있음. 새 출처 영수증은 추가 가능 |
| 같은 family의 Regular와 Bold | 별도 face로 보존; 같은 이름의 중복으로 삭제하지 않음 |
| 같은 PS/full name이나 같은 family+style, 다른 hash | 버전 충돌 후보. 기존 선택 유지, 사용자에게 교체/기존 유지 선택 제공 |
| 새 버전 문자열이 더 큼 | 자동 교체 근거로 쓰지 않음. version 문자열은 표시·비교 참고 |
| 지원 파일이나 특정 face 공급 불가 | 보관 상태와 렌더 경로별 적용 상태를 구분해 안내 |
| 손상·signature 불일치·읽기 실패 | 해당 파일 제외, 이유와 재시도 방법 표시 |
| 사용 조건 미확인 | 상태를 보존하고 확인 경로 안내; 파일 발견 사실을 사용 허용 판정으로 바꾸지 않음 |

파일 단위 결과는 `추가됨 / 이미 있음 / 선택 필요 / 지원하지 않음 / 읽기 실패 / 취소됨`으로 구분한다. ‘가져오기 완료’와 ‘이 문서에서 적용됨’은 별도의 상태다. 충돌 상태에서는 임의의 다른 버전을 자동 선택하지 않는다.

## 11. 이름 해석·선택 우선순위

name ID 1/2, 4, 6, 16/17 및 언어·인코딩을 보존한다. OpenType은 기본 family와 typographic family를 구분하므로 family 문자열 하나만으로 스타일을 그룹화하지 않는다. [OpenType name 규격](https://learn.microsoft.com/en-us/typography/opentype/spec/name)

1. 요청 입력은 원본 문서의 font name, weight/style, 언어와 필요한 문자다. 저장할 문서 이름을 앱 내부 공급 alias로 바꾸지 않는다.
2. 비교 키에는 Unicode NFC, 앞뒤 공백 제거, 연속 공백 정리, locale 독립 대소문자 정규화를 사용한다. 공백·하이픈을 모두 삭제하거나 부분 문자열로 동일 글꼴을 판단하지 않는다.
3. 사용자가 확정한 충돌 선택을 적용한 뒤 **정확한 PostScript 이름 → 정확한 full name → family/typographic family와 요청 스타일 → 검증된 명시 alias** 순서로 후보를 찾는다. 같은 순위에 후보가 둘 이상이면 충돌로 처리한다.
4. 바탕 계열 fallback 같은 유사 글꼴 매핑은 원본 이름의 정확한 일치가 아니다. 가져온 정확한 face를 찾은 뒤에만 기존 fallback을 사용한다.
5. 명시적인 face 이름과 요청 bold가 충돌할 때는 실제 bold face를 별도로 해석하고, 없으면 합성 또는 fallback 사실을 기록한다. synthetic bold를 원본 bold face 적용 성공으로 표시하지 않는다.
6. 필요한 글리프가 없으면 해당 문자 run만 fallback한다. 폰트 일부만 지원할 때 전체 문서가 완전히 같은 글꼴로 재현됐다고 표시하지 않는다.
7. 삭제·사용 불가·충돌 미선택이면 기존 renderer의 fallback을 적용하고 원인을 표시한다. `FontResolution`은 selected face, axes, alias kind, synthetic traits, fallback reason, snapshot digest를 포함한다.

WebView에 쓰는 CSS family는 `AHFont_<opaque-face-id>` 같은 앱 생성 alias로 두어 내장 `@font-face`와의 동명이인 충돌을 피한다. 이는 CSS 식별자이며 사용자 font binary를 변경하는 것이 아니다. 문서의 font name → 내부 alias 변환은 렌더링에서만 사용하고 HWP/HWPX 저장·복사 경로에 역류하지 않도록 #567 이슈에서 검증한다.

## 12. 공급 인터페이스와 출력 일관성

### 인터페이스 제안

- `FontLibrary.importCandidates(...) → ImportResult`: native HostApp 소유. 문서/페이지 JS가 임의 파일 경로로 호출할 수 없다.
- `FontLibrary.acquireSnapshot(requests, consumer) → FontSnapshot`: 한 번의 렌더 작업에서 사용할 선택과 immutable objects를 고정한다.
- `FontResourceProvider.read(resourceID, snapshot) → bytes + verifiedFormat`: snapshot allowlist 밖의 객체·변조 파일은 거부한다.
- `FontResolver.resolve(request, snapshot) → FontResolution`: 선택 근거와 fallback을 반환한다.
- `releaseSnapshot(leaseID)`: renderer lifecycle에 연결한다.

이 이름은 설계용 제안이며 아직 공개 ABI나 Studio API가 아니다.

| 소비자 | 공급·선택 제안 | 현재 변경 필요 지점·담당 |
|--------|----------------|--------------------------|
| Studio CSS/SVG/Canvas2D | 문서 font 요구를 해석해 내부 CSS alias와 `@font-face` 공급; load 완료 후 측정·렌더 캐시 갱신 | 현재 `queryLocalFonts`/존재 probe와 native 공급 목록을 합치는 정식 adapter, #567 |
| Studio CanvasKit | 같은 snapshot의 SFNT bytes와 face/axes를 엔진에 전달 | 현재 bytes 경로가 Local Font Access API에 의존. CSS 공급만으로 완료되지 않음; #567 및 필요 upstream 변경 |
| PDF·인쇄 | export 시작 시 현재 문서의 font snapshot 고정; 내부 alias·정확한 bytes를 전용 공급자로 전달 | Noto 강제 보정 전에 가져온 일치 face 적용. 임베딩 조건·Unicode·CSP 확인; #568 |
| CoreGraphics Quick Look/Thumbnail | 공유 객체에서 exact face를 process-local로 생성하고 기존 fallback 앞에서 해석 | URL/descriptor 또는 bytes 기반 생성 후 실제 선택 face 검증; 동일 PS 등록 충돌에 유의; #568 |
| Skia Quick Look/Thumbnail | 같은 snapshot의 검증된 관리 경로/bytes를 명시적으로 전달 | RustBridge `PngExportOptions.font_paths`가 현재 빈 목록. FFI 및 pinned core 선택 계약 조사·보강; #568 |

`Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`의 문서 경로·mtime·크기와 renderSignature 외에 font snapshot digest / 해석 정책 버전을 반영한다. 앱 자체의 기존 캐시는 이를 통해 무효화할 수 있지만 Finder가 보관한 외부 캐시의 갱신까지 보장하는 것은 별도 실설치 검증 사항이다.

PDF 작업 중 font 변경이 발생하면 진행 중 출력은 기존 snapshot으로 끝내고 다음 출력에 새 generation을 적용한다. 화면이 변경된 경우 출력 준비 때 문서 revision과 font snapshot을 함께 잡아 오래된 SVG와 새 글꼴이 혼합되지 않게 한다. export 종료·취소·WebContent 종료 시 lease를 해제한다.

### WebView 리소스 경계

`alhangeul-font://session/<token>/<resource-id>` 같은 전용 custom scheme을 제안한다. Native가 생성한 opaque ID와 세션 allowlist로만 해석하고 문서 유래 경로·URL을 파일 경로에 연결하지 않는다. 기존 리소스 handler를 넓혀 임의 디렉터리를 노출하지 않는다. custom scheme 처리는 현재 앱도 사용하는 WKURLSchemeHandler 경계를 따른다. [Apple API](https://developer.apple.com/documentation/webkit/wkurlschemehandler)

- 기본 native snapshot provider와 main/PDF WebView의 handler 인스턴스는 분리한다. PDF의 content JavaScript 비활성화와 navigation 차단을 유지한다.
- 필요한 `font-src`만 좁혀 허용하고 HTTP/HTTPS·file URL은 글꼴 공급에 사용하지 않는다. URL credential/query/fragment·중첩 경로·인코딩 우회는 거부한다.
- JS bridge에 원본 경로·bookmark·전체 설치 글꼴을 넘기지 않는다. 현재 문서에 필요한 목록과 리소스 식별자만 제공한다.
- MIME은 검증한 TTF/OTF/collection 형식에 맞춘다. TTC·가변은 WebKit/CanvasKit에서 해당 face·axes 선택을 입증하기 전까지 공급 지원으로 표시하지 않는다.
- 임베딩이 허용되지 않는 글꼴은 PDF에 몰래 포함하지 않는다. 출력에서 대체될 글꼴을 표시하고 취소/대체 출력 선택을 제공하는 정책을 #568 이슈에서 구현한다. `fsType`을 변경하지 않는다.
- 기대한 글꼴의 load 실패를 조용한 성공으로 처리하지 않는다. 미분류 fallback과 로드 실패를 구분하고, 현재 PDF 오류·timeout lifecycle을 보존한다.

## 13. 입력·자원 제한과 실패 정책

다음 값은 Stage 1에서 본 약 31 MB TTF를 수용하는 **초기 검증용 후보**다. 실제 성능·메모리 검증 전 확정된 제품 한도로 안내하지 않는다.

| 대상 | 후보 한도·처리 |
|------|----------------|
| 개별 원본 파일 | 64 MiB; 0 byte·불완전 읽기·허용 형식 아님 거부 |
| 가져오기 묶음 | 파일 4,096개 / 실제 해제·복사 합계 1 GiB; 취소 가능한 진행 표시 |
| ZIP 탐색 | 디렉터리 깊이 32, 절대 경로·상위 이탈·symlink·정규화 충돌 거부; 중첩 ZIP 재귀 해제 안 함 |
| ZIP 자원 계산 | metadata만 신뢰하지 않고 실제 출력 bytes 누계로 중단; 실패 staging 정리 |
| renderer | 필요한 글꼴만 선택, 읽기/파싱 동시성 제한; library 전체를 bytes 배열로 로드하지 않음 |
| 디스크·내구성 | 여유 공간 확인과 게시 단계 오류 처리; manifest 성공 전 ‘추가됨’ 표시 금지 |

한도를 넘는 정상 대형 글꼴도 ‘손상’이 아닌 ‘현재 크기 제한’으로 안내한다. 처리 순서가 결과를 바꾸지 않도록 충돌 선택과 부분 성공을 transaction 결과에 기록한다.

## 14. Stage 3 구체 실험·판정표

아래는 Stage 2에서 승인 요청한 실험표다. Stage 3의 실제 수행 범위·결과·미검증 항목은 16절과 단계 보고서에 기록했다.

| 실험 | 입력·실행 | 관측·합격 기준 |
|------|-----------|----------------|
| 준비 | OFL Spoqa Neo TTF / Pretendard OTF Regular·Bold를 전용 임시 영역에 복사. fontTools는 전용 환경에 준비 | 원본 hash·LICENSE 보존, name 1/2/4/6/16/17을 실제 파생 이름으로 조정, CFF 내부 이름도 일관되게 처리 |
| 설치본 오인 방지 | 파생 family는 `Task563ProbeSans`·`Task563ProbeSerif` 등 RFN 없는 고유 이름. 같은 이름이 시스템 목록에 없음을 host 권한에서 확인 | 파일 이름만 변경하지 않음. 원본 font 파일은 수정하지 않음 |
| A: 정상 공급 | 관리 객체에서 custom scheme으로 표본 공급. 한글/영문과 regular/bold | requested resource hash·선택 face·화면 raster/측정·PDF font resource·추출 텍스트 기록 |
| B: 원본 부재 | 프로세스 종료 → 실험 원본 위치 분리 → 새 프로세스가 관리 객체만 읽음 | A와 같은 resource hash·face·텍스트, 허용 오차 내 raster/측정. 원본 경로 접근 0 |
| C: 관리 객체도 없음 | 별도 새 프로세스, 미설치 파생 이름 요청, 리소스는 명시적으로 실패 | A/B와 같은 성공으로 판정하지 않음. load 실패·fallback 검출; 사용자 시스템 폰트는 변경하지 않음 |
| D: 굵기·이름 | regular/bold와 한글 별칭 요청을 같은 snapshot에 연결 | 실제 공급 face·weight가 요청과 일치. CSS alias가 사용자 문서 이름과 혼동되지 않음 |
| E: TTC | OFL TTF 두 face를 고유 이름으로 생성한 TTC로 묶어 header count와 face별 이름 확인 | header face index 기준으로 선택. 실패하면 읽기 지원과 공급 미지원 구분 |
| F: 가변 | 공식 Pretendard release의 variable 자산·LICENSE·hash 확보 후 고유 파생 이름 사용 | 하나의 sfnt face와 axes/named instance를 분리하고 두 weight를 실제 비교. 미확보 시 미검증으로 유지 |
| G: 충돌·손상 | 동일 bytes 2개, 같은 이름 다른 hash, 잘린 실험 복사본 | duplicate / conflict / invalid의 서로 다른 판정; 잘못된 버전을 자동 선택하지 않음 |

스크립트 출력은 `build.noindex/task563-font-migration/`에 두고 `summary.json`, font manifest, 요청 로그, 화면 PNG, PDF·추출 텍스트로 구분한다. `.app`이 필요하면 같은 `build.noindex/` 아래에 두며 제품 target·Quick Look 등록을 변경하지 않는다.

실험은 resource bytes와 렌더 결과의 연결을 입증하는 범위다. 실제 HWP/HWPX 편집·저장, signed sandbox 앱·공유 container·확장, 실인쇄와 한컴 제거 시나리오 전체 수용은 #567 ~ #569 이슈에서 검증한다.

## 15. Stage 2 수용 검토와 잔여 조건

- 설계 검토 완료: 원본 부재, 동명 버전 충돌, 부분 실패, 게시 도중 종료, 출력 중 삭제, 프로세스별 등록, Studio CSS/CanvasKit 차이, PDF Noto 보정, Skia 빈 font_paths, 외부 캐시를 각각 계약에 연결했다.
- Stage 2 종료 시 미실행 항목: App Group 설정, importer/renderer 구현, 파일 복사, 시스템 등록, PDF 생성, 성능 측정. 이후 독립 복사·PDF 실험 결과는 16절을 따른다.
- Stage 3 핵심 검증: 독립 bytes 공급과 새 프로세스의 화면·PDF 선택. 여기서 실패하면 원인을 반영해 설계를 수정하고 성공으로 넘기지 않는다.
- 제품 구현 전 조건: group ID·서명·macOS 12 접근, TTC/가변 공급 지원, CoreText 동명 등록 충돌, Skia의 명시 글꼴 우선순위, 메모리 한도, 한컴 글꼴별 사용 조건.

## 16. Stage 3 실측 — 독립 화면·PDF 공급

재현 코드: [shell 진입점](../../scripts/probe-font-migration.sh), [fixture·판정 runner](../../scripts/font_migration_probe.py), [Swift WebView probe](../../scripts/font_migration_probe.swift). 실행 명령·시행착오·증거 경로는 [Stage 3 보고서](../working/task_m020_563_stage3.md)에 있다.

### 확인한 범위

- macOS 26.5.2에서 로그인된 host 권한으로 독립 실행 파일을 실행했다. Swift는 macOS 12 target으로 경고 없이 컴파일했지만 macOS 12 runtime·sandbox 배포 검증은 아니다.
- OFL Spoqa Neo TTF / Pretendard OTF regular·bold를 고유한 `Task563<실행 ID>TTF/OTF` 내부 이름으로 파생했다. name table과 CFF 내부 이름을 함께 변경하고 고지를 보존했다. 사용자 원본은 수정하지 않았다.
- 가변 글꼴은 [공식 v1.3.9 TTF](https://github.com/orioncactus/pretendard/blob/v1.3.9/packages/pretendard/dist/public/variable/PretendardVariable.ttf) 및 [같은 태그의 OFL](https://github.com/orioncactus/pretendard/blob/v1.3.9/LICENSE)을 확보했다. resolved commit `5c41199ea0024a9e0b2cb31735265056e5472d76`, 원본 SHA-256 `3090ccde0442bb347aa7685d9ba8b17436a60682df6e8f92a9a670de14056e22`. 내부 family·PS·fvar instance 이름을 고유하게 변경했다.
- 각 프로세스의 CoreText 설치 목록에 파생 PS가 없음을 먼저 검사했다. process/global 글꼴 등록을 하지 않고 manifest의 관리 파일만 읽어 hash와 descriptor를 확인한 뒤 custom scheme의 ID allowlist로 공급했다.
- A 정상 공급 → 종료 → 실험용 원본 디렉터리 제거 → B 새 프로세스 → 관리 경로를 비운 C 새 프로세스를 비교했다. 사용자 한컴 앱과 원본 폰트는 보존했다. B의 native 코드는 원본 경로를 탐색하지 않으며, OS 전체 파일 접근을 tracing한 결과로 주장하지 않는다.
- 별도 D 실행에서는 관리 파일을 잘라 hash 불일치를 주입했다. WebView/PDF 생성 전 거부됐으며 원래 관리 bytes로 복구했다.

| 항목 | 실측·판정 |
|------|-----------|
| static TTF·OTF 일반/굵게 | 공급 hash·선택 PS 확인, 화면 PNG/글리프·측정 및 PDF 리소스 확인. A/B 동일, C와 구별 — 독립 실험 통과 |
| 가변 TTF | sfnt face 1개, wght 범위 45–930, named instance 9개. 400/700 렌더·PDF PS 및 재실행 통과. 다른 축·임의 가변 폰트는 미검증 |
| TTC | 합성 collection header 2 faces 및 CoreText 이름 2개 확인. raw TTC를 서로 다른 CSS ID로 공급해도 bold 요청은 regular로 표시 — 개별 face 선택 미입증 |
| PDF 텍스트 | 한글·영문 표본 8행 정확 추출, 실제 파생 PS의 임베딩 및 비 MacRoman subset ToUnicode 확인 |
| 원본 부재 | A/B 화면 snapshot, 행별 Canvas raster·폭, PDF raster가 정확히 같음. PDF 파일 자체는 생성 메타데이터 때문에 byte 일치를 요구하지 않음 |
| 관리 파일 부재 | C에서 8개 font load 모두 rejected, 공급 성공 0개, PDF의 파생 PS 없음. 시스템 fallback의 글리프·폭은 A/B와 다름 |
| 중복·충돌·잘린 파일 | 같은 hash와 같은 PS/다른 hash fixture 구별, fontTools 잘린 파일 거부, native 공급 hash 불일치 거부. 정식 importer/UI 검증은 아님 |
| 한글·영문 이름 해석 | 별도 CSS ID에 명시적으로 연결한 실험. 실제 한글 별칭 resolver·HWP/HWPX 저장 이름 유지·동명 시스템 등록 충돌은 미검증 |
| HFT | 실제 자산·decoder 실험 없음. 초기 미지원 방침 유지 |

### 설계에 반영할 조건

1. TTF·OTF 관리 복사와 bytes 공급은 기술적으로 가능한 것으로 확인했다. 한컴 제거 안내는 실제 한컴 자산의 조건 및 signed 제품 통합 수용을 완료한 뒤에 한다.
2. TTC는 목록에서 두 face를 찾았다는 이유로 가져오기 완료/적용 성공 처리하지 않는다. face-aware 공급 또는 허용되는 경우 개별 SFNT로 파생하는 방안을 #564 · #567 · #568 이슈에서 검증한다. 이번에는 원래 개별 TTF의 regular/bold 렌더가 비교 기준이며, 제품 TTC 분리기를 구현한 것은 아니다.
3. 가변 폰트는 file/face와 axes/named instance를 계속 구분한다. 같은 bytes여도 weight에 따라 raster·PDF PS가 달라졌으므로 snapshot/cache key에 선택 axes를 포함한다.
4. PDF는 전체 subset에 ToUnicode가 있어야 한다는 단순 검사 대신 임베딩·subset encoding·한글 매핑과 전체 추출을 함께 검사한다. 이번 WebKit은 TTF의 MacRoman subset에는 ToUnicode를 만들지 않고 비 MacRoman subset에는 만들었다. 사용자 문서 전반의 검색·복사 회귀는 별도 수용 대상이다.
5. signed App Group 공유, 제품 Studio CSS/CanvasKit, 전용 PDF의 Noto 우선순위, CoreGraphics/Skia·Quick Look/Thumbnail, Windows ZIP, 실인쇄·최소 OS는 아직 연결·검증하지 않았다. 기존 12절의 소유 경계가 유지된다.


## 17. Stage 4 확정 범위 및 제품 구현 인계

이 표의 **확인됨**은 기재한 환경·실험 범위만 뜻한다. 현재 배포 제품의 기능 지원 표가 아니다. M020/v0.2 계열이 배포 목표이며 patch·일정은 별도로 정한다.

| 대상 | 현재 판정 | 출시 지원으로 안내하기 위한 조건 | 소유 이슈 |
|------|-----------|--------------------------------|-----------|
| static TTF·OTF | 독립 공급 확인됨 / 제품 지원 조건부 | signed 관리 저장소·실제 이름 해석·화면/출력/확장 수용 | #564 · #567 · #568 · #569 |
| TTC | 목록 확인됨 / face 공급 조건부 | raw bytes에서 bold가 regular로 표시된 실패를 해결하고 face별 실제 선택 검증 | #564 · #567 · #568 |
| 가변 TTF | 공개 1종의 wght 400/700 확인됨 / 나머지 미검증 | file/face/축 구분, 선택 axes별 글리프·출력·캐시와 지원 범위 기록 | #564 · #567 · #568 |
| HFT | 초기 미지원 | 초기 범위에서 제외하고 미지원 이유 표시. 실제 decoder 실험 없음 | #564 · #566 · #569 |
| Mac 한컴 뷰어 | 버전 12.31.8 문서용 TTF 9개 위치 확인됨 / 제품 탐색 미검증 | signed sandbox 자동 탐색·위치 선택·다중 설치·취소/거부 및 사용 조건 확인 | #565 · #569 |
| Mac 한컴 편집기 | 공식 후보 위치 확인 / 실제 설치본 미검증 | 편집기 버전별 실제 설치 위치·권한·문서 적용 수용 | #565 · #569 |
| Mac OS 설치 글꼴 | 경로/metadata 확인됨 / 앱 가져오기 미검증 | 접근 가능한 사용자/공용 Fonts와 출처 미확정 글꼴 구분 | #565 · #564 |
| Windows 폴더·ZIP | 공식 경로 조사 / 실제 입력 미검증 | Windows 버전별 생성 입력, 한글 경로·ZIP 제한·원본 입력 부재 재실행 | #566 · #569 |
| Studio 한글/영문 이름 매칭 | 미검증 | 명시 CSS ID 실험과 별개로 HWP/HWPX 이름·스타일·편집·저장·재열기 검증 | #567 |
| PDF·인쇄·확장 | 독립 WebView PDF 일부 확인됨 / 제품 통합 미검증 | 전용 PDF/Noto 정책, 실인쇄, CoreGraphics/Skia, App Group 및 Finder 캐시 수용 | #568 |
| 한컴 제거 후 독립 사용 | 공개 파생 자산의 원본 부재 확인됨 / 실제 한컴 수용 미검증 | 글꼴별 사용 조건·signed 제품에서 관리 복사와 전체 표시/출력 경로를 검증 | #564 · #565 · #568 · #569 |

### 구현 순서와 경계

1. **#563 최종 검토·통합 후 #564 공통 기반부터 시작한다.** App Group identifier/entitlement와 저장 수명, 불변 객체·원자적 manifest, 중복/충돌·삭제·복구, snapshot/lease 및 좁은 리소스 공급 계약을 우선 구현한다. 다른 입력·renderer가 의존하는 계약이므로 첫 착수 대상으로 고정한다.
2. #564 계약을 바탕으로 #565 Mac 탐색, #566 Windows 폴더·ZIP, #567 이름·화면을 구현한다. Mac 사용자 시나리오를 우선 확인하되 Windows 완료 조건을 제거하지 않는다. 각 이슈는 자체 브랜치·계획·승인을 따른다.
3. #568 출력·확장은 공통 계약에서 준비할 수 있지만 최종 완료는 #565 · #566 · #567 입력·화면 결과를 수용한 뒤 판정한다. font_paths가 비어 있는 Skia와 App Group 서명은 이 경로의 명시적 잔여 작업이다.
4. #569 통합 검증에서 OS/제품/형식/renderer별 실제 결과를 묶고 웹페이지 안내를 확정한다. 문서 초안 작성과 공개 배포는 별개이며 배포는 별도 지시가 필요하다.

지원 제한은 저장·목록 조회·실제 선택을 분리해 표시한다. TTC/가변의 조건이 충족되지 않은 항목은 추가됨만 표시해 적용 성공처럼 보이게 하지 않는다. HFT 해석, Windows helper, 상용 글꼴 번들 재배포와 모든 한글 문서의 배치 완전 동일성은 이 마일스톤 범위가 아니다.

### 사용자 안내 확정 조건

- Mac 안내 순서: 가져오기 진입 → 자동 탐색 → 필요 시 위치/권한 선택 → 글꼴/충돌/결과 확인 → 대표 문서 화면·PDF 확인 → 재실행 확인. 권한 선택이 필요한 환경에도 항상 버튼 한 번으로 끝난다고 약속하지 않는다.
- Windows 안내 순서: 검증된 한글 버전의 글꼴 위치 확인 → 원본을 복사 → 폴더 ZIP 생성 → Mac으로 전송 → 가져오기 → 결과·문서 확인. 모든 버전에 같은 폴더를 안내하지 않는다.
- **한컴 삭제 후 사용 가능**이라는 문구는 실제 한컴 자산의 사용 조건, 독립 관리 복사, 원본 부재 후 새 프로세스, 화면/PDF/인쇄/Quick Look/썸네일 수용이 완료된 제품·버전에 한정한다. 글꼴 가져오기 중 한컴 앱을 자동으로 삭제하지 않는다.
- 실제 메뉴명·화면 예시는 후속 구현 결과로 채운다. 현재는 조사·기술 검증 완료와 제품 개발 예정/진행 상태를 구분하고 출시되지 않은 기능을 현재 사용 가능하다고 안내하지 않는다.

### GitHub 인계

Stage 3 결과 보고 후 Stage 4 진행 승인에 따라 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562), 조사 [#563](https://github.com/postmelee/alhangeul-macos/issues/563), 후속 #564 ~ #569 본문에 범위·의존 관계·수용 기준을 반영했다. 기존 체크리스트/제외 범위는 보존하고 원본 참조 허용·무조건 TTC 지원 등 조사 결과와 맞지 않는 표현을 보정했다. #563 최종 승인 항목과 미구현 제품 항목은 완료 처리하지 않았다.

[마일스톤 22](https://github.com/postmelee/alhangeul-macos/milestone/22)의 설명은 M020/v0.2 계열 및 조건부 TTC/가변 범위로 정렬했다. 명칭·기한·연결 관계와 이슈 OPEN 상태는 유지한다. 최종 결과와 검증 기록은 [Stage 4 보고서](../working/task_m020_563_stage4.md) 및 [최종 보고서](../report/task_m020_563_report.md)를 따른다.
