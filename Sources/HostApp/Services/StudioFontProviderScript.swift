import Foundation

/// 공개 Studio API용 factory. 같은 page realm의 bootstrap이 native transport를 연결한다.
enum StudioFontProviderScript {
    static var bootstrapSource: String {
        """
        (() => {
          if (window.__alhangeulFontConnection) return;
          const create = \(source);
          const adapter = create({
            postMessage: body => window.webkit.messageHandlers.alhangeulFonts.postMessage(body),
            getLoadToken: () => window.__alhangeulEditorLoad?.token,
            getFontsAPI: () => window.rhwpStudio?.fonts,
            events: window
          });
          let stopped = false, status = 'waiting', error = null, timer = null;
          let pending = null;
          const deadline = Date.now() + 15000;
          async function connect() {
            if (stopped || pending) return;
            if (!window.rhwpStudio?.fonts) {
              if (Date.now() < deadline) timer = setTimeout(connect, 50);
              else status = 'unsupported';
              return;
            }
            pending = adapter.connect();
            try {
              const result = await pending;
              if (!stopped) { status = result.supported ? 'connected' : 'unsupported'; error = null; }
            } catch {
              if (!stopped) { status = 'failed'; error = 'fontProviderUnavailable'; }
            } finally { pending = null; }
          }
          const connection = Object.freeze({
            getState: () => ({status, error, ...(window.rhwpStudio?.fonts?.getState?.() || {})}),
            getOutputContext: requests => adapter.getOutputContext(requests),
            refresh() {
              if (stopped) return;
              adapter.refresh();
              if (status === 'failed') void connect();
            },
            async dispose() {
              if (stopped) return;
              stopped = true; status = 'disposed';
              if (timer !== null) clearTimeout(timer);
              window.removeEventListener('alhangeul-fonts-changed', reconnect);
              await adapter.dispose();
            }
          });
          function reconnect() { if (status === 'failed') void connect(); }
          window.__alhangeulFontConnection = connection;
          window.addEventListener('alhangeul-fonts-changed', reconnect);
          window.addEventListener('pagehide', () => { void connection.dispose(); }, {once: true});
          void connect();
        })();
        """
    }

    static let source = #"""
    ((environment) => {
      const {postMessage, getLoadToken, getFontsAPI, events} = environment;
      const delay = environment.delay || (ms => new Promise(resolve => setTimeout(resolve, ms)));
      const abortError = () => new DOMException('Font request cancelled', 'AbortError');
      const failure = code => Object.assign(new Error(code), {code});
      const codeOf = error => error?.code || error?.message || String(error);
      const name = value => typeof value === 'string' && value.trim().length > 0 && value.length <= 1024;
      const key = value => value.replace(/\u0000/g, '').normalize('NFC').replace(/\s+/g, ' ').trim().toLowerCase();
      const text = value => typeof value === 'string' && value.length <= 1024;
      let epoch = 0, disposed = false, catalogPromise = null, catalog = null;
      let lifetime = new AbortController(), active = 0, connectedAPI = null, connection = null;
      let recoveryUsed = false, recoveryTimer = null;
      const queue = [], listeners = new Set();

      function check(signal, expected = epoch) {
        if (disposed || signal?.aborted || expected !== epoch) throw abortError();
      }
      function abortable(promise, signal) {
        if (!signal) return promise;
        if (signal.aborted) { promise.catch(() => {}); return Promise.reject(abortError()); }
        return new Promise((resolve, reject) => {
          const abort = () => { signal.removeEventListener('abort', abort); reject(abortError()); };
          signal.addEventListener('abort', abort, {once: true});
          promise.then(value => { signal.removeEventListener('abort', abort); resolve(value); },
            error => { signal.removeEventListener('abort', abort); reject(error); });
        });
      }
      function notify() {
        for (const listener of [...listeners]) {
          try { listener(); } catch { /* 한 소비자 오류가 나머지 무효화를 막지 않는다. */ }
        }
      }
      function invalidate(resetRecovery) {
        epoch++;
        lifetime.abort(); lifetime = new AbortController();
        catalog = null; catalogPromise = null;
        if (resetRecovery) recoveryUsed = false;
        if (recoveryTimer !== null) { clearTimeout(recoveryTimer); recoveryTimer = null; }
        pump();
      }
      function refresh() {
        if (disposed) return;
        invalidate(true);
        // 먼저 이전 목록을 폐기한 후 upstream이 새 snapshot을 요청하게 한다.
        notify();
      }
      function recover(expected, error) {
        if (disposed || expected !== epoch || recoveryUsed) return;
        if (!['busy', 'staleSession', 'staleGeneration'].includes(codeOf(error))) return;
        recoveryUsed = true;
        // upstream의 같은 세대 실패 cache를 한 번만 갱신한다. 무한 재렌더는 금지한다.
        recoveryTimer = setTimeout(() => {
          recoveryTimer = null;
          if (!disposed && expected === epoch) { invalidate(false); notify(); }
        }, 1000);
      }
      async function rpc(op, credentials, fields = {}) {
        return postMessage({version: 1, op, loadToken: credentials.loadToken,
          ...(credentials.session ? {session: credentials.session, revision: credentials.revision} : {}), ...fields});
      }
      async function retry(operation, signal, expected) {
        const waits = [100, 250, 500];
        for (let attempt = 0; ; attempt++) {
          check(signal, expected);
          try { const result = await operation(); check(signal, expected); return result; }
          catch (error) {
            check(signal, expected);
            if (codeOf(error) !== 'busy' || attempt === waits.length) throw error;
            await abortable(delay(waits[attempt]), signal);
          }
        }
      }

      function normalize(row) {
        if (!row || !['installed', 'managed'].includes(row.source) || !name(row.id) ||
            !name(row.family) || !name(row.fullName) || !text(row.postScriptName) || !text(row.style) ||
            !Array.isArray(row.aliases) || row.aliases.length > 32 ||
            !Number.isInteger(row.traits) || row.traits < 0 || row.traits > 0xffffffff) return null;
        const aliases = [...new Set(row.aliases.filter(name))];
        let weight = row.weight;
        let slant;
        if (row.source === 'managed') {
          if (!Number.isInteger(weight) || weight < 1 || weight > 1000) return null;
          slant = row.traits & 512 ? 'oblique' : row.traits & 1 ? 'italic' : 'normal';
        } else {
          // CoreText symbolic traits에는 정확한 weight가 없다. 알려진 static style만 사용한다.
          if (!name(row.style)) return null;
          const style = row.style.toLowerCase().replace(/[\s_-]/g, '');
          const base = style.replace(/italic|oblique/g, '') || 'regular';
          const weights = {thin: 100, extralight: 200, ultralight: 200, light: 300,
            regular: 400, normal: 400, roman: 400, medium: 500, semibold: 600,
            demibold: 600, bold: 700, extrabold: 800, ultrabold: 800, black: 900, heavy: 900};
          weight = Object.prototype.hasOwnProperty.call(weights, base) ? weights[base] : null;
          if (!weight || (base === 'regular' && (row.traits & 2))) return null;
          slant = style.includes('oblique') ? 'oblique' : (row.traits & 1) || style.includes('italic') ? 'italic' : 'normal';
        }
        return {id: row.id, family: row.family, fullName: row.fullName,
          postscriptName: row.postScriptName, style: row.style, aliases, weight, slant};
      }
      function names(row) {
        return [row.family, row.fullName, row.postScriptName, ...(Array.isArray(row.aliases) ? row.aliases : [])]
          .filter(name).map(key).filter(Boolean);
      }
      function select(rows) {
        const blocked = new Set(), managed = [], installed = [], idCounts = new Map();
        for (const row of rows) {
          idCounts.set(row.id, (idCounts.get(row.id) || 0) + 1);
          const face = normalize(row);
          if (row.source === 'managed') {
            // 충돌/미지원/잘못된 metadata를 동명 설치 파일로 숨기지 않는다.
            if (row.limitation || !face) names(row).forEach(n => blocked.add(n));
            else managed.push({row, face});
          } else if (face && !row.limitation) installed.push({row, face});
        }
        const usable = ({row, face}) => idCounts.get(face.id) === 1 && !names(row).some(n => blocked.has(n));
        const selected = managed.filter(usable);
        const exact = new Set(), styled = new Set();
        for (const {row, face} of selected) {
          [row.postScriptName, row.fullName].filter(name).forEach(n => exact.add(key(n)));
          names(row).forEach(n => styled.add(JSON.stringify([n, face.weight, face.slant])));
        }
        const candidates = installed.filter(usable).filter(({row, face}) =>
          ![row.postScriptName, row.fullName].filter(name).some(n => exact.has(key(n))) &&
          !names(row).some(n => styled.has(JSON.stringify([n, face.weight, face.slant]))));
        // 동명 설치 파일은 임의 첫 파일을 선택하지 않는다. upstream matcher의 모호함 처리에 맡긴다.
        return [...selected, ...candidates].map(({face}) => Object.freeze({...face, aliases: Object.freeze(face.aliases)}));
      }
      async function loadCatalog(expected, signal) {
        const loadToken = getLoadToken();
        if (!name(loadToken)) throw failure('staleSession');
        for (let attempt = 0; ; attempt++) {
          try {
            const hello = await retry(() => rpc('handshake', {loadToken}), signal, expected);
            if (hello.version !== 1 || !name(hello.session) || !name(hello.revision)) throw failure('invalidResponse');
            const credentials = {loadToken, session: hello.session, revision: hello.revision};
            let offset = 0, total = null, identity = null;
            const rows = [];
            do {
              const page = await retry(() => rpc('catalog', credentials, {offset}), signal, expected);
              if (page.revision !== hello.revision || !Array.isArray(page.faces) || page.faces.length > 128 ||
                  !Number.isInteger(page.total) || page.total < 0 || page.total > 24096 ||
                  (total !== null && total !== page.total) || page.nextOffset !== offset + page.faces.length ||
                  page.nextOffset > page.total || (page.nextOffset === offset && offset < page.total)) throw failure('invalidResponse');
              total = page.total; offset = page.nextOffset;
              if (page.identity !== undefined) {
                if (!name(page.identity) || (identity !== null && identity !== page.identity)) throw failure('invalidResponse');
                identity = page.identity;
              }
              if (page.faces.some(row => !row || typeof row !== 'object')) throw failure('invalidResponse');
              rows.push(...page.faces);
            } while (offset < total);
            check(signal, expected);
            if (loadToken !== getLoadToken()) throw failure('staleSession');
            const faces = Object.freeze(select(rows));
            const snapshot = Object.freeze({revision: `${expected}:${hello.revision}`, faces});
            const ids = new Map(faces.map(face => [face.id, face]));
            const unavailableNames = new Set();
            for (const row of rows) {
              if (row.limitation !== 'disabled' && !ids.has(row.id)) names(row).forEach(n => unavailableNames.add(n));
            }
            catalog = {credentials, snapshot, identity, unavailableNames, ids};
            return snapshot;
          } catch (error) {
            check(signal, expected);
            if (!['staleSession', 'staleGeneration'].includes(codeOf(error)) || attempt >= 2 || loadToken !== getLoadToken()) throw error;
            await abortable(delay(100), signal);
          }
        }
      }
      function getSnapshot(signal) {
        try { check(signal); } catch (error) { return Promise.reject(error); }
        if (!catalogPromise) {
          const expected = epoch;
          catalogPromise = loadCatalog(expected, lifetime.signal).catch(error => {
            if (expected === epoch) catalogPromise = null;
            recover(expected, error);
            throw error;
          });
        }
        return abortable(catalogPromise, signal);
      }
      function pump() {
        // native slot 2개에 맞춘다. 대기열은 별도로 64개까지 제한한다.
        for (let i = queue.length - 1; i >= 0; i--) {
          const item = queue[i];
          if (disposed || item.signal.aborted || item.expected !== epoch) {
            queue.splice(i, 1); item.reject(abortError());
          }
        }
        while (active < 2 && queue.length) {
          const item = queue.shift(); active++;
          Promise.resolve().then(item.run).then(item.resolve, item.reject).finally(() => { active--; pump(); });
        }
      }
      async function transfer(id, state, signal, expected) {
        const credentials = state.credentials;
        let opened = null, opening = false;
        const cancel = () => {
          if (opened || opening) rpc('cancel', credentials, {id: opened?.id || id}).catch(() => {});
        };
        signal.addEventListener('abort', cancel, {once: true});
        try {
          opened = await retry(async () => {
            opening = true;
            try {
              const result = await rpc('openFace', credentials, {id});
              // 취소를 무시하고 뒤늦게 발급된 transfer도 반드시 회수한다.
              opened = result;
              return result;
            } finally { opening = false; }
          }, signal, expected);
          if (!name(opened.id) || opened.revision !== credentials.revision ||
              !Number.isInteger(opened.byteCount) || opened.byteCount < 1 || opened.byteCount > 64 * 1024 * 1024 ||
              !Number.isInteger(opened.faceIndex) || opened.faceIndex < 0 || opened.faceIndex > 65535 ||
              !/^[a-f0-9]{64}$/i.test(opened.sha256)) throw failure('invalidResponse');
          const face = state.ids.get(id);
          if ((face.postscriptName && opened.postScriptName !== face.postscriptName) || opened.weight !== face.weight) {
            throw failure('faceMismatch');
          }
          const bytes = new Uint8Array(opened.byteCount);
          for (let offset = 0; offset < bytes.length;) {
            const length = Math.min(256 * 1024, bytes.length - offset);
            const chunk = await retry(() => rpc('readChunk', credentials, {id: opened.id, offset, length}), signal, expected);
            if (chunk.id !== opened.id || chunk.revision !== credentials.revision || chunk.offset !== offset ||
                typeof chunk.data !== 'string' || chunk.data.length > 4 * Math.ceil(length / 3)) throw failure('invalidResponse');
            const decoded = atob(chunk.data);
            if (decoded.length !== length) throw failure('invalidResponse');
            for (let i = 0; i < length; i++) bytes[offset + i] = decoded.charCodeAt(i);
            offset += length;
          }
          check(signal, expected);
          if (getLoadToken() !== credentials.loadToken) throw failure('staleSession');
          return {bytes: bytes.buffer, faceIndex: opened.faceIndex};
        } finally {
          signal.removeEventListener('abort', cancel);
          if (name(opened?.id)) await rpc('closeFace', credentials, {id: opened.id}).catch(() => {});
        }
      }
      function readFace(id, revision, signal) {
        try {
          check(signal);
          if (!catalog || revision !== catalog.snapshot.revision || !catalog.ids.has(id)) throw failure('staleGeneration');
          if (queue.length >= 64) { const error = failure('busy'); recover(epoch, error); throw error; }
        } catch (error) { return Promise.reject(error); }
        const state = catalog, expected = epoch, controller = new AbortController();
        const parent = lifetime.signal;
        const cancel = () => { controller.abort(); pump(); };
        parent.addEventListener('abort', cancel, {once: true});
        signal?.addEventListener('abort', cancel, {once: true});
        const work = new Promise((resolve, reject) => {
          queue.push({resolve, reject, signal: controller.signal, expected,
            run: () => { check(controller.signal, expected); return transfer(id, state, controller.signal, expected); }});
          pump();
        }).catch(error => { recover(expected, error); throw error; }).finally(() => {
          parent.removeEventListener('abort', cancel);
          signal?.removeEventListener('abort', cancel);
        });
        return abortable(work, controller.signal);
      }
      const provider = Object.freeze({getSnapshot, readFace,
        subscribe(listener) { check(); listeners.add(listener); return () => listeners.delete(listener); }});
      function getOutputContext(requests) {
        if (!catalog || !name(catalog.identity) || !Array.isArray(requests) || requests.length > 2048) return null;
        if (requests.some(request => !request || !name(request.family) || !name(request.key))) return null;
        const unavailable = requests.filter(request => catalog.unavailableNames.has(key(request.family)))
          .map(request => request.key);
        return {identity: catalog.identity, revision: catalog.snapshot.revision, unavailable};
      }
      events?.addEventListener('alhangeul-fonts-changed', refresh);
      async function connect() {
        check();
        if (connection) return connection;
        const api = getFontsAPI();
        if (typeof api?.setProvider !== 'function' || typeof api?.getState !== 'function') return {supported: false};
        connectedAPI = api;
        connection = Promise.resolve().then(() => { check(); return api.setProvider(provider); }).then(() => {
          check(); return {supported: true, state: api.getState()};
        }).catch(error => { connection = null; throw error; });
        return connection;
      }
      async function dispose() {
        if (disposed) return;
        disposed = true; invalidate(false); listeners.clear();
        events?.removeEventListener('alhangeul-fonts-changed', refresh);
        if (connectedAPI) await connectedAPI.setProvider(null);
        connectedAPI = null;
      }
      // 문서 epoch/loadToken 교체 때 native begin 이후 refresh를 호출하는 책임은 소유 coordinator에 있다.
      return Object.freeze({provider, connect, refresh, dispose, getOutputContext});
    })
    """#
}
