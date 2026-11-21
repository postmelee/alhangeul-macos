// 기존 v0.9.0은 #616 임시 보정을 사용하고, #9170의 첫 렌더링 계약을 충족하는 upstream은 손대지 않는다.
export const canvasPath = 'src/view/canvas-view.ts';
export const initialRenderEdits = {
  [canvasPath]: [
    ['  private rendererSelectionEpoch = 0;', `  private rendererSelectionEpoch = 0;
  private documentLoadEpoch = 0;
  private latestPageLoad?: Promise<boolean>;
  private latestRendererPreparation?: ReturnType<CanvasView['runRendererPreparation']>;`],
    ['    this.documentLoadPrepared = true;', '    this.documentLoadEpoch += 1;\n    this.documentLoadPrepared = true;'],
    ['async loadDocument(): Promise<void> {\n    if (this.disposed) return;',
     `async loadDocument(): Promise<boolean> {
    const generation = this.wasm.documentGeneration;
    let load = this.buildDocumentPages();
    this.latestPageLoad = load;
    for (;;) {
      const ready = await load;
      if (this.disposed || generation !== this.wasm.documentGeneration) return false;
      const latest = this.latestPageLoad;
      if (!latest || latest === load) return ready;
      // 같은 문서의 외부 그림 도착 등으로 페이지 구성이 다시 시작된 경우.
      load = latest;
    }
  }

  private async buildDocumentPages(): Promise<boolean> {
    if (this.disposed) return false;`],
    [`    this.documentLoadPrepared = false;
    if (this.disposed) return;
    const selected = await this.prepareRendererRevision(epoch, () => this.rendererSession.resolve(this.wasm));
    if (!selected) return;`, `    this.documentLoadPrepared = false;
    const load = this.documentLoadEpoch;
    const generation = this.wasm.documentGeneration;
    const current = () => !this.disposed && load === this.documentLoadEpoch
      && generation === this.wasm.documentGeneration;
    let preparation = this.prepareRendererRevision(epoch, () => this.rendererSession.resolve(this.wasm));
    for (;;) {
      const selected = await preparation;
      if (!current()) return false;
      const latest = this.latestRendererPreparation;
      if (preparation === latest) {
        if (!selected) return false;
        break;
      }
      if (!latest) return false;
      // 이미 시작된 최신 선택을 공유한다. 초기화가 새 렌더 선택을 발행하지 않는다.
      preparation = latest;
    }`],
    ["console.error('[CanvasView] 로드된 페이지가 없습니다');\n      return;",
     "console.error('[CanvasView] 로드된 페이지가 없습니다');\n      return false;"],
    ["    this.eventBus.emit('document-view-loaded');",
     "    if (!current()) return false;\n    this.eventBus.emit('document-view-loaded');\n    return true;"],
    ['  private async prepareRendererRevision(', `  private prepareRendererRevision(...args: Parameters<CanvasView['runRendererPreparation']>) {
    const preparation = this.runRendererPreparation(...args);
    this.latestRendererPreparation = preparation;
    return preparation;
  }

  private async runRendererPreparation(`],
  ],
  'src/main.ts': [
    ['    // 이미 승인된 snapshot을', '    const generation = wasm.documentGeneration;\n    // 이미 승인된 snapshot을'],
    ['    await canvasView?.loadDocument();',
     '    if (generation !== wasm.documentGeneration || !await canvasView?.loadDocument()) return;'],
    ...[
      "    await updateLoadProgress(90, '도구 모음 준비 중...');",
      "    await updateLoadProgress(94, '문서 검증 및 글꼴 확인 중...');",
      "    await updateLoadProgress(96, '편집 상태 초기화 중...');",
    ].map(line => [line, line + '\n    if (generation !== wasm.documentGeneration) return;']),
  ],
};

const legacyCommit = 'c9095c5f67632e6721e800ccc7fb43ea49d26682';
const upstreamCommit = '981ce66b4183b13c1a3b5907e04a8969c8c42034';
const once = (source, marker) => typeof source === 'string' && source.split(marker).length === 2;

/** 실제 입력 두 곳을 대조한다. 나중 타깃 SHA는 계약이 일치할 때만 수용한다. */
export function chooseInitialRenderMode(commit, sources) {
  const canvas = sources[canvasPath];
  const main = sources['src/main.ts'];
  const legacy = Object.entries(initialRenderEdits).every(([path, edits]) =>
    edits.every(([before]) => once(sources[path], before)));
  // #9170은 취소 확인, 선택 대기, 복구 프레임 완료, 빈 첫 화면의 실패 처리를 함께 제공한다.
  const modern = [
    'signal: AbortSignal,\n  options: { suppressDialogs?: boolean;',
    'await canvasView?.loadDocument();\n    signal.throwIfAborted();',
    'inputHandler?.activateWithCaretPosition();',
  ].every(marker => once(main, marker)) && [
    'ready: this.loadPreparedDocument()',
    'while (current() && this.rendererSelectionPending)',
    "this.updateVisiblePages('initial');\n      for (const recovery of recoveries) await recovery;",
    "throw new Error('첫 화면의 페이지를 그리지 못했습니다.');",
  ].every(marker => once(canvas, marker));
  if (legacy === modern || (commit === legacyCommit && !legacy) || (commit === upstreamCommit && !modern)) {
    throw Error(`Studio initial-render contract drift: ${commit}`);
  }
  return legacy ? 'legacy' : 'upstream';
}
