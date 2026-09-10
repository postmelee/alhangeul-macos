import Foundation

/// 저장 snapshot부터 완료 통지까지 하나의 요청으로 묶는다.
enum RhwpStudioSaveBridgeScript {
    static let guardSource = """
    (() => {
      window.__alhangeulSaveLock = null;
      for (const type of ["keydown", "beforeinput", "input", "mousedown", "click", "paste", "cut", "drop", "compositionstart"]) {
        window.addEventListener(type, event => {
          if (!window.__alhangeulSaveLock) return;
          if (type === "click" && event.target === window.__alhangeulSaveLock.downloadAnchor) return;
          event.preventDefault();
          event.stopImmediatePropagation();
        }, true);
      }
      window.addEventListener("message", event => {
        const data = event.data;
        if (!window.__alhangeulSaveLock || data?.type !== "rhwp-request") return;
        if (!["loadFile", "automation.execute", "applyTextCommand", "revertTextCommand", "plugin.invoke"].includes(data.method)) return;
        event.stopImmediatePropagation();
        window.postMessage({type: "rhwp-response", id: data.id, error: "문서 저장 중입니다."}, "*");
      }, true);
    })();
    """

    static let source = """
    let executeForExport = null;
    function emitNativeSession(state) {
      const next = {
        ready: !document.documentElement.classList.contains("rhwp-busy"),
        documentEpoch: state.documentEpoch, changeSeq: state.changeSeq,
        dirty: state.dirty, pageCount: state.pageCount, format: state.format,
        createdByEditor: window.__alhangeulDocumentOrigin?.().createdByEditor === true
      };
      sessionSnapshot = next;
      const message = {type: "editor-session", token: sessionLoad.token,
        loadID: sessionLoad.loadID, sequence: ++sessionSequence, ...next};
      postNative(message);
      return message;
    }

    async function readNativeSession(settle = true) {
      const readVersion = ++sessionReadVersion;
      if (settle) await settleEditorState();
      const origin = readDocumentOrigin();
      const state = await requestRhwp("getDocumentState");
      const fence = await requestRhwp("getSelectionContext");
      if (readVersion !== sessionReadVersion ||
          origin.generation !== readDocumentOrigin().generation ||
          state.documentEpoch !== fence.documentEpoch || state.changeSeq !== fence.changeSeq) {
        throw new Error("문서가 변경되었습니다. 다시 시도해 주세요.");
      }
      const snapshot = emitNativeSession(state);
      if (!snapshot.ready || snapshot.pageCount < 1) throw new Error("문서를 준비 중입니다.");
      return snapshot;
    }

    function requireSaveLock(id) {
      const lock = window.__alhangeulSaveLock;
      if (!lock || lock.id !== id) throw new Error("저장 요청이 만료되거나 변경되었습니다.");
      return lock;
    }

    function releaseSaveLock(id) {
      const lock = window.__alhangeulSaveLock;
      if (!lock || lock.id !== id) return;
      clearTimeout(lock.timer);
      if (lock.downloadURL) URL.revokeObjectURL(lock.downloadURL);
      window.__alhangeulSaveLock = null;
      scheduleEditorSessionCheck();
    }

    async function validateSaveLock(id) {
      const lock = requireSaveLock(id);
      const state = await requestRhwp("getDocumentState");
      requireSaveLock(id);
      if (state.documentEpoch !== lock.state.documentEpoch ||
          state.changeSeq !== lock.state.changeSeq ||
          state.documentSha256 !== lock.state.documentSha256 ||
          document.documentElement.classList.contains("rhwp-busy")) {
        throw new Error("저장 중 문서가 변경되었습니다. 다시 저장해 주세요.");
      }
      return state;
    }

    window.__alhangeulHostBridgeReadSession = () => readNativeSession();
    window.__alhangeulHostBridgeSave = {
      async begin(id, token, epoch, format) {
        if (window.__alhangeulSaveLock) throw new Error("이미 저장이 진행 중입니다.");
        if (sessionLoad.token !== token) throw new Error("다른 viewer의 저장 요청입니다.");
        await settleEditorState();
        if (window.__alhangeulSaveLock) throw new Error("이미 저장이 진행 중입니다.");
        const lock = {id, state: null, timer: null};
        window.__alhangeulSaveLock = lock;
        ++sessionReadVersion;
        lock.timer = setTimeout(() => releaseSaveLock(id), 60000);
        // 공개 automation 명령도 저장이 끝난 뒤 실행하도록 거부한다.
        const automation = window.rhwpStudio.automation;
        if (!automation.__alhangeulSaveGuard) {
          const execute = automation.execute;
          executeForExport = (...args) => execute.apply(automation, args);
          automation.execute = function(...args) {
            if (window.__alhangeulSaveLock) return Promise.resolve({ok:false, error:"문서 저장 중입니다."});
            return execute.apply(this, args);
          };
          automation.__alhangeulSaveGuard = true;
        }
        try {
          const state = await requestRhwp("getDocumentState");
          requireSaveLock(id);
          if (state.documentEpoch !== epoch || state.pageCount < 1 ||
              document.documentElement.classList.contains("rhwp-busy")) {
            throw new Error("저장할 문서가 변경되었거나 준비 중입니다.");
          }
          lock.state = state;
          const payload = format === "pdf" ? await documentPages()
            : (format === "doc" || format === "html") ? await captureHTMLDownload(format, executeForExport, id)
            : await requestSaveExportPayload(format);
          await validateSaveLock(id);
          return {requestID:id, token, snapshot:emitNativeSession(state), format,
            fileName:fileNameForSaveFormat(format), ...payload};
        } catch (error) {
          releaseSaveLock(id);
          throw error;
        }
      },
      validate: validateSaveLock,
      async finish(id, fileName, timeText) {
        await validateSaveLock(id);
        // 고정 bundle의 공개 API는 호출 즉시 clean을 반영하고 draft 정리 완료를 기다린다.
        const result = await window.rhwpStudio.notifySaved(fileName);
        if (result?.ok !== true) throw new Error("편집기의 저장 완료 통지가 실패했습니다.");
        rememberCurrentFileName(fileName);
        showTemporaryStatusMessage(`저장 완료 ${timeText}`, fileName);
        return await readNativeSession(false);
      },
      release: releaseSaveLock
    };
    """
}
