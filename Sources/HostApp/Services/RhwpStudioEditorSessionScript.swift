import Foundation

enum RhwpStudioEditorSessionScript {
    /// 공개 확장 명령의 CommandServices로 생성 성공을 관찰한다. 초기화 전에 설치해야
    /// 자동 빈 문서도 식별하며, 이미 열린 문서를 소급해서 새 문서로 간주하지 않는다.
    static let provenanceSource = """
    (() => {
      let readOrigin = () => ({generation: null, createdByEditor: false});
      window.__alhangeulDocumentOrigin = () => readOrigin();
      function install(automation) {
        if (!automation?.registerCommand || !automation?.execute) return;
        const id = "ext:alhangeul-observe-document-creation";
        try {
          automation.registerCommand({id, label: "문서 생성 상태 연결", canExecute: () => true,
            execute(services) {
              const wasm = services.wasm;
              if (typeof wasm?.createNewDocument !== "function") return;
              const original = wasm.createNewDocument;
              let createdGeneration = null;
              function create(...args) {
                const before = wasm.documentGeneration;
                const result = original.apply(this, args);
                // 실패한 생성이나 다른 receiver는 기존 문서의 출처를 바꾸지 않는다.
                if (this === wasm && Number.isSafeInteger(wasm.documentGeneration) &&
                    wasm.documentGeneration > before) createdGeneration = wasm.documentGeneration;
                return result;
              }
              wasm.createNewDocument = create;
              readOrigin = () => ({generation: wasm.documentGeneration,
                createdByEditor: wasm.createNewDocument === create && createdGeneration !== null &&
                  wasm.documentGeneration === createdGeneration});
            }
          });
          automation.execute(id);
        } catch {
          // API가 달라지거나 연결에 실패하면 보호 상태 미확정 정책으로 남는다.
        } finally {
          automation.unregisterCommand?.(id);
        }
      }
      function observeStudio(studio) {
        if (!studio || typeof studio !== "object") return;
        if (studio.automation) { install(studio.automation); return; }
        Object.defineProperty(studio, "automation", {configurable: true,
          set(value) {
            Object.defineProperty(studio, "automation", {value, writable: true, configurable: true, enumerable: true});
            install(value);
          }
        });
      }
      if (window.rhwpStudio) observeStudio(window.rhwpStudio);
      else Object.defineProperty(window, "rhwpStudio", {configurable: true,
        set(value) {
          Object.defineProperty(window, "rhwpStudio", {value, writable: true, configurable: true, enumerable: true});
          observeStudio(value);
        }
      });
    })();
    """

    /// Host bridge의 requestRhwp/postNative와 같은 closure 안에서 실행한다.
    static let source = """
    const sessionLoad = window.__alhangeulEditorLoad;
    let sessionSnapshot = null;
    let sessionSequence = 0;
    let sessionCheckTimer = null;
    let sessionCheckRunning = false;
    let sessionCheckAgain = false;
    let sessionReadVersion = 0;

    function readDocumentOrigin() {
      return window.__alhangeulDocumentOrigin?.() ?? {generation: null, createdByEditor: false};
    }

    function scheduleEditorSessionCheck() {
      if (!sessionLoad) return;
      if (sessionCheckRunning) {
        sessionCheckAgain = true;
        return;
      }
      if (sessionCheckTimer !== null) return;
      // capture 이벤트의 실제 편집 handler가 끝난 뒤 읽는다. 연속 이벤트는 합친다.
      sessionCheckTimer = setTimeout(() => {
        sessionCheckTimer = null;
        refreshEditorSession();
      }, 40);
    }

    async function refreshEditorSession() {
      if (sessionCheckRunning || !sessionLoad || window.__alhangeulSaveLock) return;
      const readVersion = sessionReadVersion;
      sessionCheckRunning = true;
      try {
        const automation = window.rhwpStudio?.automation;
        if (!automation?.getContext().hasDocument) return;
        const origin = readDocumentOrigin();
        // 전체 문서 export/SHA를 만드는 getDocumentState는 첫 등록·세대 교체에만 쓴다.
        const identity = await requestRhwp("getSelectionContext");
        let state;
        if (!sessionSnapshot || identity.documentEpoch !== sessionSnapshot.documentEpoch) {
          state = await requestRhwp("getDocumentState");
        } else {
          const pageCount = await requestRhwp("pageCount");
          const context = automation.getContext();
          state = {
            documentEpoch: identity.documentEpoch, changeSeq: identity.changeSeq,
            dirty: context.isDirty, pageCount, format: context.sourceFormat
          };
        }
        // await 사이 교체/편집이 일어났다면 여러 문서의 metadata를 합치지 않는다.
        const fence = await requestRhwp("getSelectionContext");
        if (state.documentEpoch !== fence.documentEpoch || state.changeSeq !== fence.changeSeq ||
            origin.generation !== readDocumentOrigin().generation) {
          sessionCheckAgain = true;
          return;
        }
        if (!Number.isSafeInteger(state.documentEpoch) || state.documentEpoch < 1 ||
            !Number.isSafeInteger(state.changeSeq) || state.changeSeq < 0 ||
            !Number.isSafeInteger(state.pageCount) || state.pageCount < 1 ||
            typeof state.dirty !== "boolean") return;
        if (readVersion !== sessionReadVersion || window.__alhangeulSaveLock) return;
        const next = {
          // 고정 bundle의 렌더 준비 표시다. source/protection 식별에는 사용하지 않는다.
          ready: !document.documentElement.classList.contains("rhwp-busy"),
          documentEpoch: state.documentEpoch, changeSeq: state.changeSeq,
          dirty: state.dirty, pageCount: state.pageCount, format: state.format,
          createdByEditor: window.__alhangeulDocumentOrigin?.().createdByEditor === true
        };
        if (JSON.stringify(next) === JSON.stringify(sessionSnapshot)) return;
        sessionSnapshot = next;
        postNative({
          type: "editor-session", token: sessionLoad.token,
          loadID: sessionLoad.loadID, sequence: ++sessionSequence, ...next
        });
      } catch {
        // 초기화·문서 교체 중이면 다음 조회에서 재확인한다. 실제 로드 실패는 기존 bridge가 보고한다.
      } finally {
        sessionCheckRunning = false;
        if (sessionCheckAgain) {
          sessionCheckAgain = false;
          scheduleEditorSessionCheck();
        }
      }
    }

    // 지연 초기화, 구독 전 생성, DOM을 바꾸지 않는 automation/plugin 작업도 확인한다.
    scheduleEditorSessionCheck();
    const sessionPoll = setInterval(scheduleEditorSessionCheck, 1000);
    window.addEventListener("pagehide", () => clearInterval(sessionPoll), { once: true });
    """
}
