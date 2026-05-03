# 폰트 fallback 정책

## 목적

Quick Look preview와 Finder thumbnail의 Swift native renderer가 HWP 문서의 proprietary font name을 직접 번들하지 않고, `rhwp-studio`에 포함된 오픈 라이선스 WOFF2와 macOS 시스템 폰트로 안정적으로 대체한다.

이 문서는 `Sources/RhwpCoreBridge/FontFallback.swift`의 정책 설명이다. WebView viewer는 `rhwp-studio`의 CSS/WebFont 로딩을 그대로 사용하며, 이 문서는 native renderer 전용 정책을 기록한다.

## 기본 원칙

- 한컴, HY, Microsoft proprietary font 파일은 Git에 포함하지 않는다.
- `Sources/HostApp/Resources/rhwp-studio/fonts`의 WOFF2를 CoreText process-local font로 등록해 재사용한다.
- Swift renderer는 DOM/CSS font matching을 복제하지 않고, HWP font family를 native 후보 체인으로 정규화한다.
- 등록 실패, resource 누락, 후보 font 미설치 상태는 crash가 아니라 다음 후보 또는 시스템 fallback으로 처리한다.
- 후보 이름은 가능하면 CoreText PostScript name을 사용한다.

## 자산 출처와 사용 범위

기준 자산 목록과 라이선스 설명은 `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`가 소유한다. `devel-webview`에서는 이미 WebView viewer bundle에 포함된 WOFF2 34개를 native renderer에서도 재사용한다. WebView bundle이 없는 `devel` 대상 PR에서는 전체 `rhwp-studio` 앱 자산을 가져오지 않고, 동일 라이선스 원천의 `rhwp-studio/fonts` 디렉터리만 HostApp resource로 포함한다.

| 계열 | 주요 bundled font | native renderer 사용처 |
|------|-------------------|-------------------------|
| Serif | Noto Serif KR, Nanum Myeongjo, Gowun Batang | 바탕/명조/궁서 계열 fallback |
| Sans-serif | Pretendard, Noto Sans KR, Nanum Gothic, Gowun Dodum, Spoqa Han Sans | 돋움/고딕/맑은 고딕/HY고딕 계열 fallback |
| Monospace | D2Coding, Nanum Gothic Coding | 돋움체/굴림체/바탕체/Courier 계열 fallback |
| Math/special | Latin Modern Math, Cafe24, Happiness Sans | 수식 보조 및 장식 계열 fallback |

HostApp bundle에는 `rhwp-studio/fonts`가 포함되지만, QLExtension/ThumbnailExtension bundle에는 font resource를 중복 포함하지 않는다. extension process는 parent app의 `Contents/Resources/rhwp-studio/fonts`를 찾아 process-local로 등록한다.

## WOFF2 PostScript name 주의점

일부 파일명과 CoreText PostScript name이 다르다. Swift native mapping은 파일명을 직접 쓰지 않는다.

| 파일 | CoreText PostScript name |
|------|--------------------------|
| `NotoSansKR-Regular.woff2` | `NotoSansKRThin-Regular` |
| `NotoSansKR-Bold.woff2` | `NotoSansKRThin-Bold` |
| `NotoSerifKR-Regular.woff2` | `NotoSerifKRExtraLight-Regular` |
| `NotoSerifKR-Bold.woff2` | `NotoSerifKRExtraLight-Bold` |

## 주요 alias 체인

| HWP 계열 | native 후보 체인 |
|----------|------------------|
| `함초롬바탕`, `한컴바탕`, `바탕`, `Batang` | Noto Serif KR -> Nanum Myeongjo -> Gowun Batang -> AppleMyungjo -> Times New Roman |
| `HY명조`, `HY신명조`, `HY견명조`, `휴먼명조`, `나눔명조` | Nanum Myeongjo -> Noto Serif KR -> AppleMyungjo -> Times New Roman |
| `궁서`, `궁서체`, `Gungsuh` | Gowun Batang -> Nanum Myeongjo -> Noto Serif KR -> AppleMyungjo |
| `함초롬돋움`, `맑은 고딕`, `Calibri`, `Tahoma`, `Verdana` | Pretendard -> Apple SD Gothic Neo -> Helvetica Neue |
| `한컴돋움`, `돋움`, `굴림`, `Dotum`, `Gulim` | Noto Sans KR -> Pretendard -> Nanum Gothic -> Apple SD Gothic Neo -> Helvetica Neue |
| `HY고딕`, `HY그래픽`, `HY헤드라인M`, `HY중고딕`, `HY견고딕` | Pretendard -> Gowun Dodum -> Noto Sans KR -> Apple SD Gothic Neo |
| `돋움체`, `굴림체`, `바탕체`, `Courier New`, `Consolas` | D2Coding -> Nanum Gothic Coding -> Courier New -> Apple SD Gothic Neo |
| `NanumGothic` | Nanum Gothic -> Noto Sans KR -> Pretendard -> Apple SD Gothic Neo |
| `D2Coding` | D2Coding -> Nanum Gothic Coding -> Courier New -> Apple SD Gothic Neo |
| `HY바다L`, `한컴 소망 B`, `한컴 쿨재즈 B` | Cafe24/Happiness Sans 장식체 -> Pretendard -> Apple SD Gothic Neo |

알 수 없는 font family는 먼저 원래 이름을 CoreText에서 찾고, 실패하면 Apple SD Gothic Neo, Pretendard, Helvetica Neue 순서로 내려간다.

## bold / italic 처리

후보 font에 명시 bold PostScript name이 있으면 bold 요청 시 해당 face를 먼저 선택한다. italic face가 없는 번들 한글 폰트는 CoreText synthetic trait 적용을 시도하고, 실패하면 regular 또는 bold face를 유지한다.

문자 폭과 줄 배치는 #120의 text advance 보정 경로가 담당한다. 이 정책은 glyph 선택과 기본 metric의 fallback 범위를 좁히는 역할만 한다.
