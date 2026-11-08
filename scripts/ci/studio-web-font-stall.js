// WKWebView smoke 전용. v0.9.0의 CDN fetch와 이전 Studio의 URL FontFace를 지연시킨다.
(() => {
  const NativeFontFace = window.FontFace, sources = new WeakMap();
  window.__fontTrace = [];
  window.__fontStallInjected = true;
  const fetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    const url = new URL(input instanceof Request ? input.url : input, document.baseURI);
    if (url.hostname !== 'cdn.jsdelivr.net' || !/\.(?:woff2?|[ot]tf)$/i.test(url.pathname)) {
      return fetch(input, init);
    }
    const signal = init?.signal ?? (input instanceof Request ? input.signal : null);
    const row = {url: url.href, kind: 'fetch', status: 'injected-pending'};
    window.__fontTrace.push(row);
    return new Promise((_, reject) => {
      const abort = () => {
        row.status = 'aborted';
        reject(new DOMException('Font request aborted', 'AbortError'));
      };
      if (signal?.aborted) abort();
      else signal?.addEventListener('abort', abort, {once: true});
    });
  };
  window.FontFace = new Proxy(NativeFontFace, {
    construct(target, args) {
      const face = Reflect.construct(target, args);
      sources.set(face, args[1]);
      return face;
    }
  });
  const load = NativeFontFace.prototype.load;
  NativeFontFace.prototype.load = function () {
    const row = {family: this.family, start: performance.now(), status: 'pending'};
    window.__fontTrace.push(row);
    if (typeof sources.get(this) === 'string' && /url\(["']?https?:\/\//i.test(sources.get(this))) {
      row.status = 'injected-pending';
      return new Promise(() => {});
    }
    return load.call(this).then(face => {
      row.status = 'loaded'; row.end = performance.now(); return face;
    }, error => {row.status = String(error); row.end = performance.now(); throw error;});
  };
})();
