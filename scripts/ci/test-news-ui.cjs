// 공개 소식 데이터 계약을 브라우저나 네트워크 없이 검증한다.
const test = require('node:test');
const assert = require('node:assert/strict');
const { validateNews } = require('../../docs/news.js');
const now = Date.parse('2026-09-15T09:00:00Z');
function fixture(count = 1) {
  return {
    schema_version: 2,
    updated_at: new Date(now).toISOString(),
    expires_at: new Date(now + 48 * 3600000).toISOString(),
    items: Array.from({ length: count }, (_, index) => ({
      platform: 'threads', permalink: `https://www.threads.com/@postmelee/post/Synthetic${index}`,
    })),
  };
}

test('0/1/5/6/10/11개 계약과 최신순 원문 순서 보존', () => {
  for (const count of [0, 1, 5, 6, 10, 11]) {
    const input = fixture(count);
    const result = validateNews(input, now);
    assert.equal(result.state, count ? 'ready' : 'empty');
    assert.deepEqual(result.items, input.items);
  }
});

test('비활성 초기값과 정상 빈 결과 구분', () => {
  assert.equal(validateNews({ schema_version: 2, updated_at: null, expires_at: null, items: [] }, now).state, 'inactive');
  const input = fixture(); input.updated_at = null;
  assert.throws(() => validateNews(input, now));
});

test('만료 경계와 48시간 수명 제한', () => {
  const input = fixture();
  assert.equal(validateNews(input, now + 48 * 3600000 - 1).state, 'ready');
  assert.equal(validateNews(input, now + 48 * 3600000).state, 'expired');
  input.expires_at = new Date(now + 48 * 3600000 + 1).toISOString();
  assert.throws(() => validateNews(input, now));
  input.expires_at = input.updated_at;
  assert.throws(() => validateNews(input, now));
});

test('잘못된 날짜·UTC 이외 시각·미래 갱신 시각 거부', () => {
  for (const value of ['2026-02-30T00:00:00Z', '2026-09-15T09:00:00+09:00',
                        '2026-09-15', '2026-09-15T09:00:00', '2026-09-16T09:00:00Z', 123]) {
    const input = fixture(); input.updated_at = value;
    assert.throws(() => validateNews(input, now));
  }
});

test('UTC 표기 허용', () => {
  for (const suffix of ['Z', '+00:00', '+0000', '.123456Z']) {
    const input = fixture(); input.updated_at = `2026-09-15T09:00:00${suffix}`;
    assert.equal(validateNews(input, now + 1000).state, 'ready');
  }
});

test('다른 작성자·플랫폼·인증 URL·HTML 전달 금지', () => {
  for (const permalink of ['javascript:alert(1)', 'https://evil.test/@postmelee/post/One',
                           'https://www.threads.com/@someone/post/One',
                           'https://www.threads.com/@postmelee/post/One?access_token=secret',
                           'https://www.threads.com/@postmelee/post/One#fragment',
                           'https://www.threads.com:443/@postmelee/post/One',
                           'https://user@www.threads.com/@postmelee/post/One',
                           'https://www.threads.com/@postmelee/post/One\n']) {
    const input = fixture(); input.items[0].permalink = permalink;
    assert.throws(() => validateNews(input, now));
  }
  for (const [key, value] of [['platform', 'x'], ['text', '본문'], ['html', '<img onerror=alert(1)>'],
                              ['author', {}], ['media', []], ['id', '123']]) {
    const input = fixture(); input.items[0][key] = value;
    assert.throws(() => validateNews(input, now));
  }
});

test('중복 URL과 .net 별칭의 동일 글 중복 거부', () => {
  const input = fixture();
  input.items.push({ platform: 'threads', permalink: input.items[0].permalink.replace('.com', '.net') + '/' });
  assert.throws(() => validateNews(input, now));
});

test('누락 필드·알 수 없는 필드·초과 크기·다른 스키마 거부', () => {
  for (const key of Object.keys(fixture())) {
    const input = fixture(); delete input[key];
    assert.throws(() => validateNews(input, now));
  }
  for (const value of [null, [], true, '2', 1]) {
    const input = fixture(); input.schema_version = value;
    assert.throws(() => validateNews(input, now));
  }
  assert.throws(() => validateNews({ ...fixture(), access_token: 'secret' }, now));
  assert.throws(() => validateNews(fixture(10001), now));
  assert.throws(() => validateNews(null, now));
});
