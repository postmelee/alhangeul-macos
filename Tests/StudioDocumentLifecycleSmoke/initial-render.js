// 배포물과 분리된 smoke 번들에서만 실행한다.
{
  const mode = MODE_LITERAL;
  window.initialRenderLoads = (window.initialRenderLoads || 0) + 1;
  const view = this;
  const wasm = this.wasm;
  if (mode !== 'control' && !window.initialRenderInjection && !wasm.fileName.includes('swap-B')) {
    const original = wasm.prepareCanvasMetrics;
    wasm.prepareCanvasMetrics = async function (...args) {
      this.prepareCanvasMetrics = original;
      const result = original.apply(this, args);
      window.initialRenderInjection = 0;
      const before = view.rendererSelectionEpoch;
      queueMicrotask(() => {
        const count = mode === 'burst' ? 8 : 1;
        for (let i = 0; i < count; ++i) {
          window.initialRenderInjection++;
          document.fonts.dispatchEvent(new Event('loadingdone'));
          document.title = JSON.stringify([before, view.rendererSelectionEpoch, view.pages.length, wasm.pageCount]);
        }
      });
      if (mode === 'swap') await new Promise(resolve => setTimeout(resolve, 1500));
      return result;
    };
  }
}
