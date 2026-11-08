# 웹 폰트 목록

알한글에 내장한 rhwp v0.9.0의 글꼴은 WOFF2 38개, 기호용 TTF 1개, 수식 윤곽용 OTF 1개다. 파일별 저작권 고지·해시·라이선스 전문은 번들의 `rhwp-studio/fonts/licenses/`에 있다.
저작권 보호가 필요한 proprietary 폰트는 Git과 release artifact에 포함하지 않으며, 아래 fallback 후보로 대체한다.

## Proprietary 폰트 (Git/release artifact 미포함)

한컴/HY/HCR/Microsoft 계열 proprietary 폰트 파일은 저장소와 release artifact에 포함하지 않는다. 문서 표시 시 대응되는 bundled WOFF2 또는 시스템 폰트 fallback으로 대체한다.

### 한컴 폰트

| 파일명 | 폰트명 | 폴백 대체 |
|--------|--------|----------|
| hamchob-r.woff2 | 함초롬바탕 | Pretendard 또는 시스템 세리프 |
| hamchod-r.woff2 | 함초롬돋움 | Pretendard 또는 시스템 산세리프 |
| h2hdrm.woff2 | HY헤드라인M | Pretendard-Bold |
| hygprm.woff2 | HY고딕 | Pretendard |
| hygtre.woff2 | HY그래픽 | Pretendard |
| hymjre.woff2 | HY명조 | Pretendard 또는 시스템 세리프 |

### Microsoft 폰트

| 파일명 | 폰트명 | 폴백 대체 |
|--------|--------|----------|
| ArialW05-Regular.woff2 | Arial | 시스템 산세리프 |
| Calibri.woff2 | Calibri | Pretendard |
| CourierNewW05-Regular.woff2 | Courier New | 시스템 모노스페이스 |
| TahomaW05-Regular.woff2 | Tahoma | Pretendard |
| TimesNewRomanW05-Regular.woff2 | Times New Roman | 시스템 세리프 |
| VerdanaW05-Regular.woff2 | Verdana | Pretendard |
| MalgunGothicW35-Regular.woff2 | 맑은 고딕 | Pretendard |
| WebdingsW95-Regular.woff2 | Webdings | — |
| WingdingsW95-3.woff2 | Wingdings 3 | — |

## 오픈 라이선스/무료 배포 폰트 (Git 포함)

### Serif (명조체 계열)

| 파일명 | 폰트명 | 라이선스 | 출처 | 대체 대상 |
|--------|--------|---------|------|----------|
| NotoSerifKR-Regular.woff2 | Noto Serif KR Regular | SIL OFL 1.1 | Google Fonts | 바탕, 한컴바탕, 함초롬바탕 |
| NotoSerifKR-Bold.woff2 | Noto Serif KR Bold | SIL OFL 1.1 | Google Fonts | 바탕 Bold |
| NanumMyeongjo-Regular.woff2 | 나눔명조 Regular | SIL OFL 1.1 | Google Fonts | HY명조, 휴먼명조 |
| NanumMyeongjo-Bold.woff2 | 나눔명조 Bold | SIL OFL 1.1 | Google Fonts | HY명조 Bold |
| NanumMyeongjo-ExtraBold.woff2 | 나눔명조 ExtraBold | SIL OFL 1.1 | Google Fonts | HY명조 ExtraBold |
| GowunBatang-Regular.woff2 | 고운바탕 Regular | SIL OFL 1.1 | Google Fonts | 궁서 대체 |
| GowunBatang-Bold.woff2 | 고운바탕 Bold | SIL OFL 1.1 | Google Fonts | 궁서 Bold |
| RHWPPublicBatang-Regular.woff2 | RHWP Public Batang Regular | SIL OFL 1.1 | Google Fonts Batang 파생본 | 문서의 원본·지정 프로그램 부재 시 조건부 대체 |
| RHWPOldHangul-Regular.woff2 | RHWP Old Hangul subset | SIL OFL 1.1 | Adobe Source Han Serif | 옛한글/세리프 보조 |

### Sans-serif (고딕체 계열)

| 파일명 | 폰트명 | 라이선스 | 출처 | 대체 대상 |
|--------|--------|---------|------|----------|
| Pretendard-*.woff2 (9종) | Pretendard | SIL OFL 1.1 | GitHub | 맑은 고딕, 함초롬돋움 |
| NotoSansKR-ExtraLight.woff2 | Noto Sans KR ExtraLight | SIL OFL 1.1 | Google Fonts | 얇은 고딕체 |
| NotoSansKR-Regular.woff2 | Noto Sans KR Regular | SIL OFL 1.1 | Google Fonts | 돋움, 굴림, 한컴돋움 |
| NotoSansKR-Bold.woff2 | Noto Sans KR Bold | SIL OFL 1.1 | Google Fonts | 돋움 Bold |
| NanumGothic-Regular.woff2 | 나눔고딕 Regular | SIL OFL 1.1 | Google Fonts | 나눔고딕 (동일) |
| NanumGothic-Bold.woff2 | 나눔고딕 Bold | SIL OFL 1.1 | Google Fonts | 나눔고딕 Bold |
| NanumGothic-ExtraBold.woff2 | 나눔고딕 ExtraBold | SIL OFL 1.1 | Google Fonts | 나눔고딕 ExtraBold |
| GowunDodum-Regular.woff2 | 고운돋움 Regular | SIL OFL 1.1 | Google Fonts | HY고딕 대체 |
| SpoqaHanSans-Regular.woff2 | 스포카 한 산스 | SIL OFL 1.1 | GitHub | 보조 Sans |

### Monospace (고정폭)

| 파일명 | 폰트명 | 라이선스 | 출처 | 대체 대상 |
|--------|--------|---------|------|----------|
| D2Coding-Regular.woff2 | D2 Coding Regular | SIL OFL 1.1 | GitHub (naver) | 굴림체, 바탕체 |
| D2Coding-Bold.woff2 | D2 Coding Bold | SIL OFL 1.1 | GitHub (naver) | 굴림체 Bold |
| NanumGothicCoding-Regular.woff2 | 나눔고딕코딩 Regular | SIL OFL 1.1 | Google Fonts | 보조 Monospace |
| NanumGothicCoding-Bold.woff2 | 나눔고딕코딩 Bold | SIL OFL 1.1 | Google Fonts | 보조 Monospace Bold |

### 특수/장식체

| 파일명 | 폰트명 | 라이선스 | 출처 |
|--------|--------|---------|------|
| NotoSansSymbols2-Regular.ttf | Noto Sans Symbols 2 Regular | SIL OFL 1.1 | Google |
| NotoSansMath-Regular.woff2 | Noto Sans Math Regular | SIL OFL 1.1 | Google LLC |
| LatinModernMath-VariableOutline-subset.otf | RHWP LMM Variable Outline | GUST Font License | Latin Modern Math 파생 수식 윤곽 |
| LatinModernMath-Regular.woff2 | Latin Modern Math Regular | GUST Font License (GFL) | CTAN/GUST |
| Cafe24Ssurround-v2.0.woff2 | 카페24 써라운드 | SIL OFL 1.1 | Cafe24 |
| Cafe24Supermagic-Regular-v1.0.woff2 | 카페24 슈퍼매직 | SIL OFL 1.1 | Cafe24 |
| Happiness-Sans-Regular.woff2 | 행복고딕 Regular | SIL OFL 1.1 | 행복나눔 |
| Happiness-Sans-Bold.woff2 | 행복고딕 Bold | SIL OFL 1.1 | 행복나눔 |
| Happiness-Sans-Title.woff2 | 행복고딕 Title | SIL OFL 1.1 | 행복나눔 |
| HappinessSansVF.woff2 | 행복고딕 Variable | SIL OFL 1.1 | 행복나눔 |
