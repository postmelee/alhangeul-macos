import Foundation

/// Host bridge closure에서 공개 same-page 계약을 소비한다.
enum RhwpStudioCommandRecoveryScript {
    static let source = """
    let recoverySession = null;
    let recoveryTimer = null;
    let recoveryPending = false;
    const recoveryReports = new Map();
    const ownedErrors = new WeakSet();
    let recoveryQueue = Promise.resolve();
    function recoveryAPI() {
      if (!window.__alhangeulEditorLoad?.commandRecovery) return null;
      const api = window.rhwpCommandErrors;
      return api?.capability === 'command-error-v1' && typeof api.getState === 'function'
        && typeof api.isHandledError === 'function' && typeof api.inspect === 'function' ? api : null;
    }
    function assertRecoveryReady() {
      const state = recoveryAPI()?.getState();
      if (state && (state.status !== 'ready' ||
          (recoveryPending && state.documentSessionId === recoverySession))) {
        throw new Error('편집 상태를 확인 중입니다. 잠시 후 다시 시도해 주세요.');
      }
    }
    window.__alhangeulAssertRecoveryReady = assertRecoveryReady;
    for (const type of ['keydown','beforeinput','paste','cut','drop','compositionstart']) {
      window.addEventListener(type, event => {
        try { assertRecoveryReady(); }
        catch { event.preventDefault(); event.stopImmediatePropagation(); }
      }, true);
    }
    function recoveryFatal(session, code) {
      if (recoveryAPI()?.getState()?.documentSessionId !== session) return;
      postNative({type:'runtime-error', message:'편집 상태를 확인할 수 없습니다.', reason:code});
    }
    function recoveryEnvelope(session, status, payload) {
      const next = recoveryQueue.then(() => sendRecoveryEnvelope(session, status, payload));
      recoveryQueue = next.catch(() => {});
      return next;
    }
    async function sendRecoveryEnvelope(session, status, payload) {
      const api = recoveryAPI();
      if (!api || api.getState()?.documentSessionId !== session) return;
      // getState와 native epoch를 await 양쪽에서 묶는다. payload ID를 분해하지 않는다.
      const native = await readNativeSession(false, true);
      if (api.getState()?.documentSessionId !== session) return;
      const envelope = {loadToken:sessionLoad.token, loadID:sessionLoad.loadID,
        documentEpoch:native.documentEpoch, documentSessionId:session};
      postNative({type:'command-recovery-state', ...envelope, status});
      if (payload) postNative({type:'upstream-command-failure', ...envelope, payload});
    }
    async function acceptRecoveryReport(payload) {
      const api = recoveryAPI(), state = api?.getState();
      if (!api || !state) return;
      const session = state.documentSessionId;
      const verdict = api.inspect(payload, session, new Set());
      if (verdict === 'stale') return;
      if (verdict !== 'accept') { recoveryFatal(session, 'INVALID_COMMAND_REPORT'); return; }
      const serialized = JSON.stringify(payload);
      if (recoverySession !== session) {
        recoverySession = session; recoveryReports.clear(); recoveryPending = false;
        clearTimeout(recoveryTimer);
      }
      if (recoveryReports.has(payload.eventId)) {
        if (recoveryReports.get(payload.eventId) !== serialized) recoveryFatal(session, 'CONFLICTING_COMMAND_REPORT');
        else if (api.getState()?.status === 'ready') { recoveryPending = false; clearTimeout(recoveryTimer); }
        return;
      }
      if (recoveryReports.size >= 256) { recoveryFatal(session, 'COMMAND_EVENT_LIMIT'); return; }
      recoveryReports.set(payload.eventId, serialized);
      try {
        // blocked 보고도 payload를 먼저 native 판정에 보낸다.
        await recoveryEnvelope(session, 'ready', payload);
        if (api.getState()?.documentSessionId === session) {
          recoveryPending = false; clearTimeout(recoveryTimer);
        }
      } catch { recoveryFatal(session, 'COMMAND_REPORT_BINDING_FAILED'); }
    }
    window.__alhangeulHandleCommandError = error => {
      const api = recoveryAPI(), state = api?.getState();
      if (!state || !api.isHandledError(error)) return false;
      if (ownedErrors.has(error)) return true;
      ownedErrors.add(error);
      const session = state.documentSessionId;
      if (recoverySession !== session) { recoverySession = session; recoveryReports.clear(); }
      if (state.status !== 'recovering') {
        if (!recoveryPending) {
          recoveryPending = true;
          recoveryTimer = setTimeout(() => recoveryFatal(session, 'COMMAND_REPORT_TIMEOUT'), 12000);
        }
        Promise.resolve(error.report).then(acceptRecoveryReport,
          () => recoveryFatal(session, 'COMMAND_REPORT_REJECTED'));
        return true;
      }
      recoveryPending = true;
      clearTimeout(recoveryTimer);
      recoveryTimer = setTimeout(() => recoveryFatal(session, 'COMMAND_REPORT_TIMEOUT'), 12000);
      recoveryEnvelope(session, 'recovering').catch(() => recoveryFatal(session, 'COMMAND_STATE_BINDING_FAILED'));
      // 실제 소유한 typed error의 report도 구독해 이벤트 누락을 감지한다.
      Promise.resolve(error.report).then(acceptRecoveryReport,
        () => recoveryFatal(session, 'COMMAND_REPORT_REJECTED'));
      return true;
    };
    window.addEventListener('rhwp-command-error', event => { void acceptRecoveryReport(event.detail); });
    const recoveryPoll = setInterval(() => {
      const state = recoveryAPI()?.getState();
      if (!state) return;
      const session = state.documentSessionId;
      if (recoverySession !== session) {
        recoverySession = session; recoveryPending = false; recoveryReports.clear();
        clearTimeout(recoveryTimer);
      }
      if (['recovering','blocked'].includes(state.status) && !recoveryPending) {
        recoveryPending = true;
        recoveryTimer = setTimeout(() => recoveryFatal(session, 'COMMAND_REPORT_TIMEOUT'), 12000);
        recoveryEnvelope(session, 'recovering').catch(() => recoveryFatal(session, 'COMMAND_STATE_BINDING_FAILED'));
      }
    }, 100);
    window.addEventListener('pagehide', () => {
      clearTimeout(recoveryTimer); clearInterval(recoveryPoll);
    }, {once:true});
    """
}
