# Task M015 #119 Stage 1 완료 보고서

## 단계 목적

`rhwp-studio`에 이미 포함된 Web font 자산을 Quick Look/Thumbnail native renderer에서 재사용할 수 있는지 확인하고, Stage 2의 font resource 배치 전략을 확정한다.

이번 단계는 코드 구현 없이 조사와 판단만 수행했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m015_119_stage1.md` | Stage 1 조사 결과와 Stage 2 구현 방향 |
| `mydocs/orders/20260503.md` | #119 상태를 Stage 1 완료 승인 대기로 갱신 |

## 조사 결과

### 1. 현재 번들 폰트 구성

`Sources/HostApp/Resources/rhwp-studio/fonts`에는 WOFF2 34개와 `FONTS.md`가 있다. 디렉터리 크기는 약 21 MB다.

확인 명령:

```bash
rg --files | rg 'fonts|woff2|ttf|otf|FONTS.md'
du -sh Sources/HostApp/Resources/rhwp-studio/fonts
find Sources/HostApp/Resources/rhwp-studio/fonts -name '*.woff2' -type f | wc -l
```

핵심 결과:

```text
21M Sources/HostApp/Resources/rhwp-studio/fonts
34
```

`FONTS.md`의 오픈 라이선스 목록은 이번 #119의 native fallback 정책에도 그대로 reference로 쓸 수 있다.

- Serif: Noto Serif KR, Nanum Myeongjo, Gowun Batang
- Sans-serif: Pretendard, Noto Sans KR, Nanum Gothic, Gowun Dodum, Spoqa Han Sans
- Monospace: D2Coding, Nanum Gothic Coding
- Math/특수: Latin Modern Math, Cafe24, Happiness Sans 계열

한컴/HY/Microsoft proprietary font 파일은 Git에 포함되어 있지 않고, `FONTS.md`에 fallback 대체만 기록되어 있다. 이 정책은 native renderer에서도 유지해야 한다.

### 2. CoreText WOFF2 등록 가능성

Swift one-off 검증에서 `CTFontManagerRegisterFontsForURL(..., .process, ...)`로 현재 WOFF2 34개가 모두 process-local 등록에 성공했다.

검증은 기본 Swift module cache가 홈 디렉터리에 쓰이면서 sandbox에 막혀, `/private/tmp/rhwp-task119-swift-cache`를 module cache로 지정해 재실행했다.

확인 명령:

```bash
swift -module-cache-path /private/tmp/rhwp-task119-swift-cache -e '... CTFontManagerRegisterFontsForURL ...'
```

대표 결과:

```text
OK Pretendard-Regular.woff2 Pretendard-Regular
OK D2Coding-Regular.woff2 D2Coding
OK NanumGothic-Regular.woff2 NanumGothic
OK NanumMyeongjo-Regular.woff2 NanumMyeongjo
OK GowunBatang-Regular.woff2 GowunBatang-Regular
OK GowunDodum-Regular.woff2 GowunDodum-Regular
```

전체 결과에서 실패한 WOFF2는 없었다.

주의할 점은 일부 Noto 파일의 PostScript name이 파일명과 직관적으로 일치하지 않는다는 점이다.

```text
OK NotoSansKR-Regular.woff2 NotoSansKRThin-Regular
OK NotoSansKR-Bold.woff2 NotoSansKRThin-Bold
OK NotoSerifKR-Regular.woff2 NotoSerifKRExtraLight-Regular
OK NotoSerifKR-Bold.woff2 NotoSerifKRExtraLight-Bold
```

따라서 Stage 3의 alias mapping은 파일명 기반 추측이 아니라, 등록 후 PostScript name 후보를 명시적으로 관리해야 한다.

### 3. target resource 경계

`project.yml` 기준 현재 `rhwp-studio` 폴더 resource는 HostApp에만 포함된다.

```yaml
HostApp:
  sources:
    - path: Sources/HostApp
      excludes:
        - Resources/rhwp-studio
    - path: Sources/HostApp/Resources/rhwp-studio
      type: folder

QLExtension:
  sources:
    - path: Sources/QLExtension
    - path: Sources/Shared
    - path: Sources/RhwpCoreBridge

ThumbnailExtension:
  sources:
    - path: Sources/ThumbnailExtension
    - path: Sources/Shared
    - path: Sources/RhwpCoreBridge
```

QLExtension과 ThumbnailExtension에는 font resource가 직접 포함되어 있지 않다. 하지만 두 extension은 HostApp bundle의 `Contents/PlugIns/*.appex` 아래에 embed되므로, Stage 2에서는 중복 embed를 피하고 다음 순서로 font directory를 찾는 helper를 우선 구현하는 편이 낫다.

1. `Bundle.main.resourceURL/rhwp-studio/fonts`
2. extension bundle 기준 `../../Resources/rhwp-studio/fonts`
3. resource를 찾지 못하면 기존 시스템 fallback 유지

이 경로가 실제 app bundle/extension runtime에서 실패하면, 그때 QLExtension/ThumbnailExtension에 최소 subset font resource를 직접 포함하는 보정으로 전환한다.

### 4. 현재 Swift fallback 매핑의 갭

현재 `FontFallback.swift`는 많은 HWP 기본 폰트를 Apple 기본 폰트로 보낸다.

- `함초롬바탕`, `한컴바탕`, `바탕`, `궁서`, `HY신명조` 등: `AppleMyungjo`
- `함초롬돋움`, `한컴돋움`, `돋움`, `굴림`, `맑은 고딕` 등: `AppleSDGothicNeo-Regular`
- 일부 Nanum 계열은 font name을 그대로 반환

Stage 2-3에서는 이 구조를 번들 폰트 우선 fallback으로 바꿔야 한다.

초기 mapping 방향:

| HWP 계열 | 우선 fallback |
|----------|---------------|
| `함초롬돋움`, `맑은 고딕`, `HY고딕`, `HY그래픽` | Pretendard |
| `돋움`, `굴림`, `한컴돋움` | Noto Sans KR 또는 Pretendard |
| `함초롬바탕`, `한컴바탕`, `바탕` | Noto Serif KR |
| `HY명조`, `휴먼명조` | Nanum Myeongjo |
| `궁서` | Gowun Batang |
| `굴림체`, `바탕체`, coding/monospace 계열 | D2Coding 또는 Nanum Gothic Coding |

## Stage 2 구현 방향

Stage 2는 `WOFF2 직접 재사용` 전략으로 진행한다.

구현 기준:

- 새 TTF/OTF resource를 추가하지 않는다.
- 기존 `Sources/HostApp/Resources/rhwp-studio/fonts`를 native renderer에서도 process-local로 등록한다.
- 공통 helper는 AppKit/UIKit/WebKit 없이 `Foundation`과 `CoreText`만 사용한다.
- HostApp/Quick Look/Thumbnail에서 같은 helper를 호출할 수 있도록 `Sources/RhwpCoreBridge`에 두는 방향을 우선 검토한다.
- helper는 중복 등록을 피하고, 이미 등록됨 오류는 성공과 동등하게 취급한다.
- 등록 실패 또는 resource lookup 실패 시 기존 시스템 fallback으로 내려간다.

`mydocs/tech/font_fallback_strategy.md`는 작성하는 편이 맞다. `FontFallback.swift`가 이미 이 문서를 참조하고 있고, 이번 작업은 public release에 포함될 font provenance/fallback 정책이므로 Stage 3 또는 Stage 5에서 별도 기술 문서로 남긴다. `FONTS.md`는 WebView asset 목록 문서로 유지한다.

## 검증 결과

구현계획서 Stage 1 검증 항목을 수행했다.

```bash
git status --short --branch
rg --files | rg 'fonts|woff2|ttf|otf|FONTS.md'
sed -n '1,220p' Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md
sed -n '1,140p' Sources/RhwpCoreBridge/FontFallback.swift
sed -n '1,120p' project.yml
find Sources -maxdepth 3 -type d | sort
git diff --check
```

추가로 CoreText WOFF2 등록 검증을 수행했다.

```bash
swift -module-cache-path /private/tmp/rhwp-task119-swift-cache -e '...'
```

결과:

- `git status --short --branch`: `local/task119`가 `origin/devel-webview`보다 2 commits ahead, 작업 시작 시 미커밋 변경 없음
- WOFF2 34개 확인
- `FONTS.md`, `FontFallback.swift`, `project.yml`, source directory 구조 확인
- CoreText WOFF2 process-local 등록 34/34 성공
- `git diff --check` 통과

## 잔여 위험

- 현재 검증은 one-off Swift process 기준이다. 실제 Quick Look/Thumbnail extension process에서 parent app resource를 읽는 경로는 Stage 2-4에서 별도로 확인해야 한다.
- Noto 계열 PostScript name이 파일명과 다르므로 alias mapping을 단순 파일명으로 구현하면 실패할 수 있다.
- WOFF2를 process-local로 등록해도 bold/italic trait 합성 결과가 WebView/rhwp-studio CSS font matching과 완전히 같지는 않을 수 있다.
- extension에서 parent app resource 접근이 macOS/PlugInKit 상태에 따라 제한되면 최소 subset 직접 embed로 전환해야 한다.

## 다음 단계 영향

Stage 2는 native용 TTF/OTF 추가 없이, 기존 WOFF2 resource 재사용 helper를 구현한다. 구현 후 `xcodegen generate`, HostApp build, `check-no-appkit.sh`를 실행해 target/resource 영향과 계층 규칙을 확인한다.

## 승인 요청

Stage 2. 공통 폰트 등록 구조와 resource 배치 구현 진행 승인을 요청한다.
