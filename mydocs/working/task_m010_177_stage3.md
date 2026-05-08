# Task M010 #177 Stage 3 보고서

## 목표

GitHub Pages 정적 사이트에 업데이트 안내 경로와 Sparkle appcast 고정 URL을 추가하고, 소개 페이지의 다운로드 버튼을 GitHub Release 페이지가 아닌 최신 공식 DMG 직접 다운로드 URL로 연결한다.

이번 단계는 사용자 안내와 정적 feed 위치 확정까지만 다룬다. Sparkle appcast의 실제 signed release item 생성과 release workflow 연동은 Stage 4 범위다.

## 변경 사항

### 직접 DMG 다운로드 버튼

`docs/index.html`의 상단 다운로드 버튼을 최신 release asset 직접 다운로드 URL로 변경했다.

```text
https://github.com/postmelee/alhangeul-macos/releases/latest/download/alhangeul-macos-0.1.0.dmg
```

이 URL은 GitHub Release의 latest release에 `alhangeul-macos-0.1.0.dmg` asset이 올라간 뒤 유효해진다. 첫 공식 release publish 전에는 404가 날 수 있으므로 FAQ에는 GitHub Releases fallback link를 함께 남겼다.

### 업데이트 안내 페이지

`docs/updates/index.html`을 추가했다.

- 앱 메뉴 `알한글 > 업데이트 확인...` 안내
- 수동 확인과 자동 확인 정책 설명
- Sparkle appcast 고정 URL 표시
- v0.1.0 릴리즈 노트 연결

`docs/updates/v0.1.0.html`도 추가했다.

- v0.1.0 첫 공식 릴리즈의 주요 기능
- Quick Look/Finder native 렌더 경로와 앱 WKWebView 경로 차이
- HWPX 저장 한계
- 설치와 업데이트 확인 경로

### appcast skeleton

`docs/appcast.xml`을 추가했다.

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>알한글 업데이트</title>
    <link>https://postmelee.github.io/alhangeul-macos/updates/</link>
    <description>알한글 macOS 앱 업데이트 feed</description>
    <language>ko</language>
  </channel>
</rss>
```

현재는 release item을 넣지 않은 skeleton이다. Stage 4에서 release version, DMG URL, length, Sparkle EdDSA signature, release notes URL을 포함하는 item 생성 경로를 만든다.

### 스타일

`docs/styles.css`에 업데이트 안내 페이지용 레이아웃, action button, appcast code panel, release note list 스타일을 추가했다. 기존 소개 페이지 톤을 유지하되, 업데이트 안내는 단순한 문서형 페이지로 구성했다.

## 검증

```bash
xmllint --noout docs/appcast.xml
```

결과: XML 문법 오류 없음.

```bash
rg -n "releases/(latest/download|download/v)|appcast|updates|alhangeul-macos-0.1.0.dmg" \
  docs/index.html docs/appcast.xml docs/updates docs/styles.css
```

결과:

- `docs/index.html` 다운로드 버튼이 `releases/latest/download/alhangeul-macos-0.1.0.dmg`를 가리킴
- FAQ와 footer에서 `updates/` 경로 확인
- 업데이트 안내 페이지에서 `https://postmelee.github.io/alhangeul-macos/appcast.xml` 표시 확인

```bash
python3 -m http.server 8000 --directory docs
curl -I http://localhost:8000/
curl -I http://localhost:8000/appcast.xml
curl -I http://localhost:8000/updates/
curl -I http://localhost:8000/updates/v0.1.0.html
```

결과:

- `/`: `HTTP/1.0 200 OK`
- `/appcast.xml`: `HTTP/1.0 200 OK`, `Content-type: application/xml`
- `/updates/`: `HTTP/1.0 200 OK`
- `/updates/v0.1.0.html`: `HTTP/1.0 200 OK`

```bash
git diff --check
```

결과: 문제 없음.

## 리스크와 후속 처리

- `latest/download/alhangeul-macos-0.1.0.dmg`는 #166에서 첫 공식 release를 non-draft official release로 publish하고 해당 asset을 업로드해야 정상 동작한다.
- `docs/appcast.xml`은 아직 Sparkle이 설치 가능한 업데이트로 판단할 release item을 포함하지 않는다. Stage 4에서 signed appcast item 생성과 release workflow 연동을 완료해야 한다.
- Stage 5에서 사용자가 요청하면 로컬 test appcast 또는 실제 release 후보를 기준으로 앱 안의 업데이트 안내 화면 smoke를 확인한다.

## 다음 단계 승인 요청

Stage 4 `appcast 생성 script와 release workflow 연동` 진행 승인을 요청한다.
