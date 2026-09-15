(() => {
  'use strict';
  const MAX_BYTES = 4 * 1024 * 1024;
  const MAX_ITEMS = 10000;
  const EMBED_SCRIPT = 'https://www.threads.com/embed.js';
  const PROFILE = 'https://www.threads.com/@postmelee';

  function requireValue(condition) {
    if (!condition) throw new Error('Invalid news data');
  }

  function exactKeys(value, keys) {
    requireValue(value && typeof value === 'object' && !Array.isArray(value));
    requireValue(Object.keys(value).length === keys.length && keys.every(key => Object.prototype.hasOwnProperty.call(value, key)));
  }

  function utcTime(value) {
    requireValue(typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]00:?00)$/.test(value));
    const time = Date.parse(value);
    requireValue(Number.isFinite(time) && new Date(time).toISOString().slice(0, 19) === value.slice(0, 19));
    return time;
  }

  function validateNews(data, now = Date.now()) {
    const curated = data?.schema_version === 3;
    exactKeys(data, curated ? ['schema_version', 'mode', 'items'] : ['schema_version', 'updated_at', 'expires_at', 'items']);
    requireValue((curated ? data.mode === 'manual' : data.schema_version === 2)
      && Array.isArray(data.items) && data.items.length <= MAX_ITEMS);
    let expiresAt = null;
    if (curated) {
      // 수동 목록은 자동 수집 snapshot의 시각·48시간 만료와 별개다.
    } else if (data.updated_at === null) {
      requireValue(data.expires_at === null && data.items.length === 0);
    } else {
      const updatedAt = utcTime(data.updated_at);
      expiresAt = utcTime(data.expires_at);
      requireValue(expiresAt > updatedAt && expiresAt - updatedAt <= 48 * 3600000 && updatedAt <= now + 300000);
    }
    const seen = new Set();
    const items = data.items.map(item => {
      exactKeys(item, ['platform', 'permalink']);
      requireValue(item.platform === 'threads' && typeof item.permalink === 'string');
      const match = /^https:\/\/(?:www\.)?threads\.(?:com|net)\/@?postmelee\/post\/([A-Za-z0-9_-]{1,100})\/?$/.exec(item.permalink);
      requireValue(match && !seen.has(match[1]));
      seen.add(match[1]);
      return { platform: 'threads', permalink: item.permalink };
    });
    const state = curated ? (items.length ? 'ready' : 'empty')
      : expiresAt === null ? 'inactive' : expiresAt <= now ? 'expired' : items.length ? 'ready' : 'empty';
    return { state, expiresAt, items };
  }

  if (typeof module !== 'undefined' && module.exports) module.exports = { validateNews };
  if (typeof document === 'undefined') return;
  const scriptBase = new URL('.', document.currentScript.src);
  let sdkPromise;
  let embedSequence = 0;

  function ensureSDK() {
    if (typeof window.instgrm?.Embeds?.process === 'function') return Promise.resolve();
    if (!sdkPromise) {
      const script = document.createElement('script');
      script.src = EMBED_SCRIPT;
      script.async = true;
      sdkPromise = new Promise((resolve, reject) => {
        const timeout = setTimeout(() => finish(false), 12000);
        let settled = false;
        function finish(success) {
          if (settled) return;
          settled = true;
          clearTimeout(timeout);
          script.onload = script.onerror = null;
          if (success && typeof window.instgrm?.Embeds?.process === 'function') resolve();
          else { script.remove(); reject(new Error('Embed script unavailable')); }
        }
        script.onload = () => finish(true);
        script.onerror = () => finish(false);
        document.head.append(script);
      }).catch(error => { sdkPromise = null; throw error; });
    }
    return sdkPromise;
  }

  async function fetchData(source, signal) {
    requireValue(['./data/news.json', '../data/news.json'].includes(source));
    const url = new URL(source, location.href);
    requireValue(url.origin === location.origin && url.href === new URL('data/news.json', scriptBase).href);
    const controller = new AbortController();
    const abort = () => controller.abort();
    signal.addEventListener('abort', abort, { once: true });
    const timeout = setTimeout(abort, 10000);
    try {
      const response = await fetch(url.href, { credentials: 'omit', redirect: 'error', cache: 'no-store', signal: controller.signal });
      requireValue(response.ok);
      const reader = response.body.getReader();
      const decoder = new TextDecoder('utf-8', { fatal: true });
      let bytes = 0, text = '';
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          bytes += value.byteLength;
          requireValue(bytes <= MAX_BYTES);
          text += decoder.decode(value, { stream: true });
        }
        return validateNews(JSON.parse(text + decoder.decode()));
      } finally { await reader.cancel().catch(() => {}); }
    } finally {
      clearTimeout(timeout);
      signal.removeEventListener('abort', abort);
    }
  }

  function makeSkeleton() {
    const element = (tag, className) => {
      const node = document.createElement(tag);
      node.className = className;
      return node;
    };
    const skeleton = element('div', 'news-skeleton');
    skeleton.setAttribute('aria-hidden', 'true');
    const header = element('div', 'news-skeleton-header');
    const profile = element('div', 'news-skeleton-profile');
    profile.append(element('span', 'news-skeleton-fill news-skeleton-name'), element('span', 'news-skeleton-fill news-skeleton-tag'));
    header.append(element('span', 'news-skeleton-fill news-skeleton-avatar'), profile, element('span', 'news-skeleton-fill news-skeleton-button'));
    skeleton.append(header);
    for (let i = 0; i < 2; i++) {
      const paragraph = element('div', 'news-skeleton-paragraph');
      for (const width of ['100%', '92%', i === 0 ? '68%' : '80%']) {
        const line = element('span', 'news-skeleton-fill news-skeleton-line');
        line.style.width = width;
        paragraph.append(line);
      }
      skeleton.append(paragraph);
    }
    skeleton.append(element('div', 'news-skeleton-fill news-skeleton-media'));
    const footer = element('div', 'news-skeleton-footer');
    footer.append(element('span', 'news-skeleton-fill news-skeleton-date'), element('span', 'news-skeleton-fill news-skeleton-counts'));
    skeleton.append(footer);
    return skeleton;
  }

  function makePost(item) {
    const article = document.createElement('article');
    article.className = 'news-post is-loading';
    article.tabIndex = -1;
    article.setAttribute('aria-label', '알한글 소식');
    article.dataset.permalink = item.permalink;
    const blockquote = document.createElement('blockquote');
    // 공식 SDK가 이 ID로 로딩 자리 표시자를 제거한다.
    blockquote.id = `news-embed-source-${++embedSequence}`;
    blockquote.className = 'text-post-media';
    blockquote.dataset.textPostVersion = '0';
    blockquote.dataset.textPostPermalink = item.permalink;
    const label = document.createElement('span');
    label.className = 'news-loading-label';
    label.textContent = '소식을 불러오는 중입니다';
    blockquote.append(label);
    article.append(makeSkeleton(), blockquote);
    return article;
  }

  function revealPost(article, frame) {
    const skeleton = article.querySelector('.news-skeleton');
    const previousHeight = article.getBoundingClientRect().height;
    const nextHeight = frame.getBoundingClientRect().height;
    article.classList.remove('is-loading');
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches || typeof article.animate !== 'function') {
      skeleton?.remove();
      return Promise.resolve();
    }
    article.classList.add('is-revealing');
    article.style.height = `${nextHeight}px`;
    const timing = { duration: 320, easing: 'cubic-bezier(.2,.7,.2,1)' };
    const animations = [
      article.animate([{ height: `${previousHeight}px` }, { height: `${nextHeight}px` }], timing),
      frame.animate([{ opacity: 0, transform: 'translateY(6px)' }, { opacity: 1, transform: 'translateY(0)' }], timing),
    ];
    if (skeleton) animations.push(skeleton.animate(
      [{ opacity: 1, transform: 'scale(1)' }, { opacity: 0, transform: 'scale(.995)' }],
      { duration: 220, easing: 'ease-out', fill: 'forwards' },
    ));
    return Promise.allSettled(animations.map(animation => animation.finished)).then(() => {
      animations.forEach(animation => animation.cancel());
      skeleton?.remove();
      article.classList.remove('is-revealing');
      article.style.removeProperty('height');
    });
  }

  function initNews(root) {
    const posts = root.querySelector('[data-news-posts]');
    const message = root.querySelector('[data-news-message]');
    const sentinel = root.querySelector('[data-news-sentinel]');
    const status = root.querySelector('[data-news-status]');
    const button = root.querySelector('[data-news-more]');
    const end = root.querySelector('[data-news-end]');
    const isFeed = root.dataset.newsMode === 'feed';
    const pageSize = isFeed ? 5 : 1;
    let items = [], offset = 0, busy = false, epoch = 0, expiresAt = null, expiryTimer;
    let lifetime = new AbortController();
    const observer = isFeed && 'IntersectionObserver' in window ? new IntersectionObserver(entries => {
      if (entries.some(entry => entry.isIntersecting)) loadNext();
    }, { rootMargin: '0px 0px 700px 0px' }) : null;

    function setLoading(loading) {
      status.classList.toggle('is-loading', loading);
      status.querySelector('.news-loading-label').textContent = loading ? '소식을 불러오는 중입니다' : '';
      if (!isFeed) sentinel.hidden = !loading;
    }

    function showMessage(text, retry = false) {
      const paragraph = document.createElement('p');
      paragraph.textContent = text;
      const actions = document.createElement('div');
      actions.className = 'news-message-actions';
      if (retry) {
        const retryButton = document.createElement('button');
        retryButton.type = 'button';
        retryButton.className = 'news-more';
        retryButton.textContent = '다시 시도';
        retryButton.addEventListener('click', () => loadData(true));
        actions.append(retryButton);
      }
      const link = document.createElement('a');
      link.href = PROFILE;
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
      link.textContent = 'Threads에서 소식 확인하기';
      actions.append(link);
      message.replaceChildren(paragraph, actions);
      message.hidden = false;
      message.tabIndex = -1;
      message.setAttribute('role', 'status');
    }

    function updateControls() {
      if (!isFeed) return;
      const remaining = offset < items.length;
      const failed = !!posts.querySelector('.is-failed');
      button.hidden = !remaining;
      button.setAttribute('aria-disabled', 'false');
      end.hidden = remaining || failed || !items.length;
      if (remaining && !failed) observer?.observe(sentinel);
    }

    function expire() {
      if (expiresAt === null || Date.now() < expiresAt) return false;
      epoch++;
      lifetime.abort();
      observer?.disconnect();
      clearTimeout(expiryTimer);
      posts.replaceChildren();
      busy = false;
      setLoading(false);
      if (button) button.hidden = true;
      if (end) end.hidden = true;
      showMessage('소식 갱신이 지연되고 있습니다.');
      return true;
    }

    function cardTask(article, signal) {
      let finish;
      const promise = new Promise(resolve => {
        let settled = false;
        const mutation = new MutationObserver(check);
        const timeout = setTimeout(() => finish('failed'), 20000);
        const abort = () => finish('aborted');
        finish = state => {
          if (settled) return;
          settled = true;
          clearTimeout(timeout);
          mutation.disconnect();
          signal.removeEventListener('abort', abort);
          if (state === 'loaded') {
            revealPost(article, article.querySelector('iframe')).then(() => resolve(state));
          } else {
            if (state === 'failed') showCardError(article);
            resolve(state);
          }
        };
        function check() {
          const frame = article.querySelector('iframe');
          if (frame) frame.title = '알한글 Threads 소식';
          if (frame && !article.querySelector('blockquote') && frame.getBoundingClientRect().height > 0) finish('loaded');
        }
        mutation.observe(article, { childList: true, subtree: true, attributes: true, attributeFilter: ['style'] });
        signal.addEventListener('abort', abort, { once: true });
        check();
      });
      return { promise, fail: () => finish('failed') };
    }

    function showCardError(article) {
      article.classList.remove('is-loading');
      article.classList.add('is-failed');
      const content = document.createElement('div');
      content.className = 'news-message';
      const text = document.createElement('p');
      text.textContent = '이 소식을 표시하지 못했습니다.';
      const actions = document.createElement('div');
      actions.className = 'news-message-actions';
      const retry = document.createElement('button');
      retry.type = 'button'; retry.className = 'news-more'; retry.textContent = '소식 다시 불러오기';
      const link = document.createElement('a');
      link.href = article.dataset.permalink; link.target = '_blank'; link.rel = 'noopener noreferrer'; link.textContent = '원문 확인하기';
      retry.addEventListener('click', async () => {
        if (expire()) return;
        const current = epoch;
        const replacement = makePost({ permalink: article.dataset.permalink });
        article.replaceWith(replacement);
        await renderCards([replacement], lifetime.signal);
        if (current !== epoch) return;
        replacement.focus({ preventScroll: true });
        updateControls();
      });
      actions.append(retry, link); content.append(text, actions); article.replaceChildren(content);
    }

    async function renderCards(batch, signal) {
      const tasks = batch.map(article => cardTask(article, signal));
      try {
        await ensureSDK();
        if (!signal.aborted) window.instgrm.Embeds.process();
      } catch { tasks.forEach(task => task.fail()); }
      return Promise.all(tasks.map(task => task.promise));
    }

    async function loadNext(manual = false) {
      if (busy || expire() || offset >= items.length) return;
      busy = true;
      const current = epoch;
      observer?.disconnect();
      if (button) {
        button.hidden = !manual;
        button.setAttribute('aria-disabled', 'true');
      }
      setLoading(true);
      const batch = items.slice(offset, offset + pageSize).map(makePost);
      offset += batch.length;
      posts.append(...batch);
      await renderCards(batch, lifetime.signal);
      if (current !== epoch || expire()) return;
      busy = false;
      setLoading(false);
      if (manual && document.activeElement === button) batch[0].focus({ preventScroll: true });
      updateControls();
    }

    async function loadData(manual = false) {
      const current = ++epoch;
      lifetime.abort();
      lifetime = new AbortController();
      observer?.disconnect();
      clearTimeout(expiryTimer);
      expiresAt = null; items = []; offset = 0; busy = true;
      message.hidden = true; posts.replaceChildren();
      if (button) button.hidden = true;
      if (end) end.hidden = true;
      setLoading(true);
      try {
        const data = await fetchData(root.dataset.newsSource, lifetime.signal);
        if (current !== epoch) return;
        expiresAt = data.expiresAt;
        if (expire()) return;
        if (data.state === 'inactive' || data.state === 'empty') {
          showMessage(data.state === 'inactive' ? '새로운 소식을 준비하고 있습니다.' : '아직 등록된 소식이 없습니다.');
          return;
        }
        items = isFeed ? data.items : data.items.slice(0, 1);
        if (expiresAt !== null) expiryTimer = setTimeout(expire, Math.max(0, expiresAt - Date.now()));
        busy = false;
        await loadNext();
        if (manual && current === epoch) posts.querySelector('article')?.focus({ preventScroll: true });
      } catch {
        if (current === epoch) showMessage('소식을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.', true);
      } finally {
        if (current === epoch) { busy = false; setLoading(false); }
        if (manual && current === epoch && !message.hidden) message.focus({ preventScroll: true });
      }
    }

    button?.addEventListener('click', () => loadNext(true));
    document.addEventListener('visibilitychange', () => { if (!document.hidden) expire(); });
    window.addEventListener('pageshow', expire);
    loadData();
  }

  document.querySelectorAll('[data-news]').forEach(initNews);
})();
