# Threads 소식 UI 로컬 검증

제품 `docs/news.js`와 CSS를 프로젝트 하위 URL에서 실행하는 격리 fixture다. `docs/`나 Pages 산출물에 복사하지 않는다.

```sh
node --test scripts/ci/test-news-ui.cjs
python3 scripts/ci/prepare-news-ui-preview.py --output-root build.noindex/task555/ui-check
python3 -m http.server 8556 --bind 127.0.0.1 --directory build.noindex/task555/ui-check
```

브라우저에서 `http://127.0.0.1:8556/qa.html`의 **전체 회귀 검증**을 누른다. 21개 PASS가 기준이다. 결과에는 최초 5개·자동 추가·마지막 묶음, 중복 방지, 빈 값·비활성·만료, JSON·script 오류와 timeout·임베드 timeout 복구, 로딩 중 만료, 수동 추가·연속 클릭·포커스, 동작 줄이기, 4가지 화면 폭 검사가 포함된다.

- `bootstrap.js`는 공개 JSON fetch와 공식 script 삽입만 로컬 응답으로 대체한다. 합성 글은 `srcdoc` iframe으로 표시하며 합성 원문 URL에 외부 요청하지 않는다.
- iframe 검증에서는 부모 viewport의 clipping도 적용되므로 감지 대상을 실제로 화면에 노출한다. 700px 사전 감지 위치는 독립된 실제 페이지에서 별도 확인한다.
- **실제 소식 화면**은 네 가지 폭에서 공식 Threads iframe을 새로 로드한다. 생성할 때 `--live-data <유효한 로컬 snapshot>`을 전달해야 한다. 전달하지 않으면 비활성 seed를 사용하므로 실제 글 검증은 실패한다. 실제 데이터와 화면 캡처는 Git에 넣지 않는다.
- 합성 동작 줄이기 검사는 JavaScript 전환 생략 경로를 확인한다. CSS media query는 정적 확인과 별도의 OS 설정 검증 대상으로 구분한다.
- `noscript` 안내는 HTML에서 확인한다. 자동 fixture는 JavaScript를 사용하므로 브라우저의 JavaScript 비활성 설정 검증을 대신하지 않는다.
- 실제 원문 내부의 접근 불가 화면과 SDK 캐시/리사이즈 동작은 공식 임베드가 제어한다. iframe 생성·높이 수신을 원문의 공개 여부 확인으로 간주하지 않는다.
