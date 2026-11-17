// edwardkim/rhwp#9164 수정 릴리스 동기화 시 이 변환과 빌드 증명을 함께 제거한다.
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
