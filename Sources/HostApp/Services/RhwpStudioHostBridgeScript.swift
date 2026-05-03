import Foundation

enum RhwpStudioHostBridgeScript {
    static let messageHandlerName = "alhangeulHost"

    static let source = """
    (() => {
      if (window.__alhangeulHostBridgeInstalled) {
        return;
      }
      window.__alhangeulHostBridgeInstalled = true;

      const nativeCommands = new Set(["file:open", "file:save", "file:print", "file:share", "file:export-pdf"]);

      function postNative(message) {
        window.webkit?.messageHandlers?.alhangeulHost?.postMessage(message);
      }

      function currentFileName() {
        return document.getElementById("sb-message")?.textContent?.split(" — ")[0] || "document.hwp";
      }

      function requestRhwp(method, params = {}, timeoutMs = 15000) {
        return new Promise((resolve, reject) => {
          const id = `alhangeul-host-${method}-${Date.now()}-${Math.random()}`;
          const timeout = setTimeout(() => {
            cleanup();
            reject(new Error(`${method} timed out.`));
          }, timeoutMs);

          function cleanup() {
            clearTimeout(timeout);
            window.removeEventListener("message", handleResponse);
          }

          function handleResponse(event) {
            const data = event.data;
            if (!data || data.type !== "rhwp-response" || data.id !== id) {
              return;
            }

            cleanup();
            if (data.error) {
              reject(new Error(data.error));
              return;
            }

            resolve(data.result);
          }

          window.addEventListener("message", handleResponse);
          window.postMessage({
            type: "rhwp-request",
            id,
            method,
            params
          }, "*");
        });
      }

      function waitForAnimationFrame() {
        return new Promise((resolve) => {
          requestAnimationFrame(() => resolve());
        });
      }

      async function settleEditorState() {
        const activeElement = document.activeElement;
        if (activeElement instanceof HTMLElement && activeElement !== document.body) {
          activeElement.dispatchEvent(new Event("change", { bubbles: true }));
          activeElement.blur();
        }

        await waitForAnimationFrame();
        await waitForAnimationFrame();
      }

      function closeMenus() {
        document.querySelectorAll("#menu-bar .menu-item.open").forEach((menu) => {
          menu.classList.remove("open");
        });
      }

      function nativeCommandForShortcut(event) {
        if (event.repeat || event.isComposing || event.altKey || event.shiftKey) {
          return null;
        }

        const hasCommandModifier = event.metaKey || event.ctrlKey;
        if (!hasCommandModifier) {
          return null;
        }

        const key = event.key.toLowerCase();
        const code = event.code;
        if (code === "KeyO" || key === "o" || key === "ㅐ") {
          return "file:open";
        }
        if (code === "KeyS" || key === "s" || key === "ㄴ") {
          return "file:save";
        }
        if (code === "KeyP" || key === "p" || key === "ㅔ") {
          return "file:print";
        }

        return null;
      }

      async function documentPages() {
        await settleEditorState();
        const pageCount = await requestRhwp("pageCount");
        const pages = [];
        for (let page = 0; page < pageCount; page += 1) {
          pages.push(await requestRhwp("getPageSvg", { page }, 30000));
        }
        return { pageCount, pages };
      }

      async function handleNativeCommand(command) {
        if (command === "file:open") {
          postNative({
            type: "command",
            command
          });
          return;
        }

        if (command === "file:save") {
          try {
            await settleEditorState();
            const bytes = await requestRhwp("exportHwp");
            postNative({
              type: "save-document",
              fileName: currentFileName(),
              bytes
            });
          } catch (error) {
            postNative({
              type: "error",
              message: `문서를 내보낼 수 없습니다: ${error?.message || String(error)}`
            });
          }
          return;
        }

        if (command === "file:share") {
          try {
            await settleEditorState();
            const bytes = await requestRhwp("exportHwp");
            postNative({
              type: "share-document",
              fileName: currentFileName(),
              bytes
            });
          } catch (error) {
            postNative({
              type: "error",
              message: `공유 데이터를 만들 수 없습니다: ${error?.message || String(error)}`
            });
          }
          return;
        }

        if (command === "file:print") {
          try {
            const { pageCount, pages } = await documentPages();
            postNative({
              type: "print-document",
              fileName: currentFileName(),
              pageCount,
              pages
            });
          } catch (error) {
            postNative({
              type: "error",
              message: `인쇄 데이터를 만들 수 없습니다: ${error?.message || String(error)}`
            });
          }
        }

        if (command === "file:export-pdf") {
          try {
            const { pageCount, pages } = await documentPages();
            postNative({
              type: "export-pdf-document",
              fileName: currentFileName(),
              pageCount,
              pages
            });
          } catch (error) {
            postNative({
              type: "error",
              message: `PDF 데이터를 만들 수 없습니다: ${error?.message || String(error)}`
            });
          }
        }
      }

      window.__alhangeulHostBridgeRunNativeCommand = (command) => {
        if (!nativeCommands.has(command)) {
          return false;
        }

        closeMenus();
        handleNativeCommand(command);
        return true;
      };

      document.addEventListener("click", (event) => {
        const target = event.target;
        if (!(target instanceof Element)) {
          return;
        }

        const item = target.closest(".md-item[data-cmd]");
        if (!item || item.classList.contains("disabled")) {
          return;
        }

        const command = item.dataset.cmd;
        if (!nativeCommands.has(command)) {
          return;
        }

        event.preventDefault();
        event.stopPropagation();
        event.stopImmediatePropagation();
        window.__alhangeulHostBridgeRunNativeCommand(command);
      }, true);

      document.addEventListener("keydown", (event) => {
        const command = nativeCommandForShortcut(event);
        if (!command) {
          return;
        }

        event.preventDefault();
        event.stopPropagation();
        event.stopImmediatePropagation();
        window.__alhangeulHostBridgeRunNativeCommand(command);
      }, true);
    })();
    """
}
