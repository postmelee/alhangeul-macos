import Foundation

/// 앱이 소유하는 글꼴 선택 UI. 공개 automation 명령과 기존 편집 명령 수명을 사용한다.
enum StudioFontPickerScript {
    static let source = #"""
    (({adapter, getAutomation, document}) => {
      const openID = 'ext:alhangeul-local-font-picker';
      const applyID = 'ext:alhangeul-apply-local-font';
      let automation = null, dialog = null, disposed = false;
      const editable = ctx => ctx.hasDocument && ctx.isEditable &&
        (!ctx.isFormMode || ctx.canEditFormField) && !ctx.inCellSelectionMode &&
        !ctx.inTableObjectSelection && !ctx.inPictureObjectSelection;
      function close() {
        if (!dialog) return;
        const old = dialog; dialog = null;
        old.overlay.remove();
        if (old.services.wasm.documentGeneration === old.generation &&
            old.services.getInputHandler() === old.input) old.input.focus();
      }
      function element(tag, text, parent) {
        const node = document.createElement(tag);
        if (text) node.textContent = text;
        parent?.appendChild(node);
        return node;
      }
      async function open(services) {
        close();
        const input = services.getInputHandler(), selection = input?.getSelection();
        if (!selection) return;
        const saved = JSON.parse(JSON.stringify(selection));
        const generation = services.wasm.documentGeneration;
        const overlay = element('div'); overlay.className = 'alhangeul-local-font-overlay';
        const style = element('style', '', overlay);
        style.textContent = `
          .alhangeul-local-font-overlay {position:fixed;inset:0;z-index:10000;background:#0006;display:grid;place-items:center}
          .alhangeul-local-font-dialog {width:min(420px,90vw);padding:24px;border-radius:12px;background:Canvas;color:CanvasText;box-shadow:0 12px 40px #0004;font:14px system-ui}
          .alhangeul-local-font-dialog h2 {font-size:18px;margin:0 0 8px}
          .alhangeul-local-font-dialog p {margin:0 0 16px;color:CanvasText;opacity:.8;line-height:1.5}
          .alhangeul-local-font-dialog input,.alhangeul-local-font-dialog select {box-sizing:border-box;width:100%;font:inherit;margin-bottom:12px;padding:8px}
          .alhangeul-local-font-dialog select {height:min(260px,35vh)}
          .alhangeul-local-font-actions {display:flex;justify-content:flex-end;gap:8px}
          .alhangeul-local-font-actions button {font:inherit;padding:6px 16px}
        `;
        const panel = element('section', '', overlay); panel.className = 'alhangeul-local-font-dialog';
        panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-modal', 'true');
        panel.setAttribute('aria-labelledby', 'alhangeul-local-font-title');
        const title = element('h2', '로컬 글꼴 선택', panel); title.id = 'alhangeul-local-font-title';
        element('p', '선택한 글자에 사용할 글꼴을 고르세요.', panel);
        const search = element('input', '', panel); search.type = 'search';
        search.placeholder = '글꼴 이름 검색'; search.setAttribute('aria-label', '글꼴 이름 검색');
        const list = element('select', '', panel); list.size = 10; list.setAttribute('aria-label', '사용 가능한 로컬 글꼴');
        const message = element('p', '글꼴 목록을 준비하고 있습니다.', panel);
        message.setAttribute('role', 'status');
        const actions = element('div', '', panel); actions.className = 'alhangeul-local-font-actions';
        const cancel = element('button', '취소', actions);
        const apply = element('button', '적용', actions); apply.disabled = true;
        dialog = {overlay, services, input, saved, generation, revision: null, families: [], list, apply, message};
        const current = dialog;
        function populate() {
          list.replaceChildren();
          const filter = search.value.trim().normalize('NFC').toLocaleLowerCase('ko');
          for (const family of current.families.filter(n => n.normalize('NFC').toLocaleLowerCase('ko').includes(filter))) {
            const option = element('option', family, list); option.value = family;
          }
          list.selectedIndex = -1; apply.disabled = true;
          message.textContent = current.families.length ? `${list.options.length}개 글꼴` :
            '사용 가능한 글꼴이 없습니다. 알한글 글꼴 설정에서 사용 설정과 접근 권한을 확인하세요.';
        }
        search.addEventListener('input', populate);
        list.addEventListener('change', () => { apply.disabled = !list.value; });
        cancel.addEventListener('click', close);
        apply.addEventListener('click', () => { void choose(current); });
        overlay.addEventListener('click', event => { if (event.target === overlay) close(); });
        overlay.addEventListener('keydown', event => {
          if (event.key === 'Escape') { event.preventDefault(); close(); }
          else if (event.key === 'Tab') {
            const controls = [search, list, cancel, apply].filter(n => !n.disabled);
            const index = controls.indexOf(document.activeElement);
            if ((event.shiftKey && index <= 0) || (!event.shiftKey && index === controls.length - 1)) {
              event.preventDefault(); controls[event.shiftKey ? controls.length - 1 : 0].focus();
            }
          }
        });
        document.body.appendChild(overlay); search.focus();
        try {
          const snapshot = await adapter.provider.getSnapshot(new AbortController().signal);
          if (disposed || dialog !== current || services.wasm.documentGeneration !== generation) return;
          current.revision = snapshot.revision;
          current.families = [...new Set(snapshot.faces.map(f => f.family))].sort((a, b) => a.localeCompare(b, 'ko'));
          populate();
        } catch { if (dialog === current) message.textContent = '글꼴 목록을 불러오지 못했습니다. 글꼴 설정을 확인한 뒤 다시 열어주세요.'; }
      }
      async function choose(current) {
        const family = current.list.value;
        if (dialog !== current || !current.families.includes(family)) return;
        current.apply.disabled = true;
        try {
          const snapshot = await adapter.provider.getSnapshot(new AbortController().signal);
          if (dialog !== current) return;
          if (snapshot.revision !== current.revision) { close(); return; }
          const result = automation.execute(applyID, {family});
          if ((!result.ok || dialog === current) && dialog === current) {
            current.message.textContent = '현재 선택 영역에는 글꼴을 적용할 수 없습니다.';
            current.apply.disabled = false;
          }
        } catch { if (dialog === current) current.message.textContent = '글꼴이 변경되었습니다. 창을 다시 열어주세요.'; }
      }
      function install() {
        if (disposed) return false;
        if (automation) return true;
        const api = getAutomation();
        if (!api?.registerCommand || !api?.addMenuItem || !api?.execute) return false;
        automation = api;
        api.registerCommand({id: openID, label: '로컬 글꼴 선택…', opensDialog: true,
          canExecute: ctx => editable(ctx) && ctx.hasSelection,
          execute: services => { void open(services); }});
        api.registerCommand({id: applyID, label: '로컬 글꼴 적용', canExecute: editable,
          execute(services, params) {
            const current = dialog, family = params?.family;
            if (!current || !current.families.includes(family) || services.wasm !== current.services.wasm ||
                services.wasm.documentGeneration !== current.generation || services.getInputHandler() !== current.input) return;
            const fontId = services.wasm.findOrCreateFontId(family);
            if (fontId < 0) return;
            current.input.applyCharPropsToRange(current.saved.start, current.saved.end, {fontId});
            close();
          }});
        api.addMenuItem({menuId: 'format', commandId: openID, position: 'bottom'});
        return true;
      }
      const off = adapter.provider.subscribe(close);
      return Object.freeze({install, dispose() {
        if (disposed) return;
        disposed = true; close(); off();
        automation?.unregisterCommand(openID); automation?.unregisterCommand(applyID);
        automation = null;
      }});
    })
    """#
}
