# Threads 소식 Stage 1 fixture

이 폴더는 인증 없이 데이터 계약과 API client의 경계를 검증한다. 실데이터 수집 증거가 아니다.

- `public-news.json`: 스키마 2의 synthetic 원문 참조 JSON. 본문·미디어·작성자 객체는 금지한다. 테스트 링크를 제품 페이지에 게시하지 않는다.
- `oembed-response.json`: 실측한 `/t/{shortcode}` 정규화와 `embed.js` 구조를 참고해 만든 synthetic 응답. 실게시물 HTML이 아니며 검증용으로만 사용한다.
- `probe-responses.json`: 공식 조회 문서의 필드 구조를 참고해 직접 만든 synthetic 응답. 본인 계정의 실응답을 익명화한 자료가 아니다. cursor도 테스트 문자열이다.
- [공식 조회 문서](https://developers.facebook.com/docs/threads/retrieve-and-discover-posts/retrieve-posts): `topic_tag`는 태그가 있는 글에만, `reposted_post`는 재게시물에만 반환된다. `/me/threads`의 답글은 별도 endpoint로 조회한다.

실제 계정의 263개 조회·대상 6개·인증 없는 oEmbed 6개 확인 결과는 기술 조사 기록에 있다. 이 fixture 자체는 그 실측 증거가 아니다. 로컬 표시 검증용 링크 JSON은 `build.noindex/task555/stage1/`에만 있으며 원본 응답이나 토큰·인증 URL은 커밋하지 않는다.
