// 로컬 브라우저 fixture 전용. 제품 파일에는 포함하지 않는다.
(() => {
  const scenario = new URL(document.currentScript.src).searchParams.get('case');
  const nativeTimeout = window.setTimeout.bind(window);
  window.setTimeout = (callback, delay, ...args) => nativeTimeout(callback, delay === 20000 ? 120 : delay === 12000 ? 100 : delay, ...args);
  if (scenario === 'no-observer') delete window.IntersectionObserver;
  if (scenario === 'reduced') {
    const nativeMatch = window.matchMedia.bind(window);
    window.matchMedia = query => query.includes('prefers-reduced-motion') ? { matches: true } : nativeMatch(query);
  }
  let fetchCount = 0, scriptCount = 0;
  const attempts = new Map();
  window.fetch = async () => {
    fetchCount++;
    document.documentElement.dataset.fixtureFetches = String(fetchCount);
    if (scenario === 'json-retry' && fetchCount === 1) throw new Error('synthetic network failure');
    const now = Date.now();
    const count = /^\d+$/.test(scenario) ? Number(scenario) : scenario === 'no-observer' ? 11 : 6;
    const data = {
      schema_version: 2,
      updated_at: new Date(now).toISOString(),
      expires_at: new Date(now + 3600000).toISOString(),
      items: Array.from({ length: count }, (_, index) => ({ platform: 'threads', permalink: `https://www.threads.com/@postmelee/post/Synthetic${index}` })),
    };
    if (scenario === 'inactive') Object.assign(data, { updated_at: null, expires_at: null, items: [] });
    if (scenario === 'expired') Object.assign(data, { updated_at: new Date(now - 7200000).toISOString(), expires_at: new Date(now - 3600000).toISOString() });
    if (scenario === 'expires-open') data.expires_at = new Date(now + 1200).toISOString();
    if (scenario === 'expires-loading') data.expires_at = new Date(now + 40).toISOString();
    if (scenario === 'invalid') data.items[0].html = '<img src=x onerror=alert(1)>';
    return new Response(JSON.stringify(data), { status: 200, headers: { 'Content-Type': 'application/json' } });
  };
  function process() {
    document.querySelectorAll('blockquote.text-post-media').forEach(blockquote => {
      blockquote.classList.remove('text-post-media');
      const url = blockquote.dataset.textPostPermalink;
      const attempt = (attempts.get(url) || 0) + 1;
      attempts.set(url, attempt);
      if (scenario === 'embed-retry' && url.endsWith('Synthetic0') && attempt === 1) return;
      nativeTimeout(() => {
        if (!blockquote.isConnected) return;
        const frame = document.createElement('iframe');
        frame.style.height = '360px';
        frame.srcdoc = '<!doctype html><html lang="ko"><body style="font:16px system-ui;background:#fff;padding:20px">합성 소식 카드 — 브라우저 회귀 검증용</body></html>';
        blockquote.replaceWith(frame);
      }, scenario === 'expires-loading' ? 200 : 20);
    });
  }
  const append = document.head.append.bind(document.head);
  document.head.append = (...nodes) => {
    for (const node of nodes) {
      if (node.tagName === 'SCRIPT' && node.src === 'https://www.threads.com/embed.js') {
        scriptCount++;
        document.documentElement.dataset.fixtureScripts = String(scriptCount);
        node.type = 'application/x-local-fixture';
        append(node);
        nativeTimeout(() => {
          if (scenario === 'script-timeout' && scriptCount === 1) return;
          if (scenario === 'script-retry' && scriptCount === 1) node.dispatchEvent(new Event('error'));
          else {
            window.instgrm = { Embeds: { process } };
            node.dispatchEvent(new Event('load'));
          }
        }, 10);
      } else append(node);
    }
  };
})();
