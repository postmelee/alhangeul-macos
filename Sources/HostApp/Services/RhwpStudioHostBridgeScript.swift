import Foundation

enum RhwpStudioHostBridgeScript {
    static let messageHandlerName = "alhangeulHost"

    static let source = """
    (() => {
      if (window.__alhangeulHostBridgeInstalled) {
        return;
      }
      window.__alhangeulHostBridgeInstalled = true;

      const nativeCommands = new Set(["file:open", "file:save", "file:save-as", "file:print", "file:share", "file:export-pdf"]);

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

      function encodeBytesToBase64(bytes) {
        const chunkSize = 0x8000;
        const chunks = [];
        for (let offset = 0; offset < bytes.length; offset += chunkSize) {
          chunks.push(String.fromCharCode(...bytes.slice(offset, offset + chunkSize)));
        }
        return btoa(chunks.join(""));
      }

      async function requestHwpExportPayload() {
        try {
          const payload = await requestRhwp("exportHwpBase64");
          if (payload && typeof payload.base64 === "string") {
            return payload;
          }
        } catch {
          // Older rhwp-studio bundles do not expose exportHwpBase64.
        }

        const bytes = await requestRhwp("exportHwp");
        return {
          base64: encodeBytesToBase64(bytes),
          byteCount: bytes.length
        };
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

      function enableNativeCommandItems() {
        document.querySelectorAll(".md-item[data-cmd]").forEach((item) => {
          const command = item.dataset.cmd;
          if (nativeCommands.has(command)) {
            item.classList.remove("disabled");
            item.removeAttribute("aria-disabled");
          }
        });
      }

      function ensureSaveAsMenuItem() {
        const saveItem = document.querySelector('.md-item[data-cmd="file:save"]');
        if (!saveItem || document.querySelector('.md-item[data-cmd="file:save-as"]')) {
          return;
        }

        const item = document.createElement("div");
        item.className = "md-item";
        item.dataset.cmd = "file:save-as";
        item.innerHTML = '<span class="md-icon"></span><span class="md-label">다른 이름으로 저장...</span><span class="md-shortcut">Command+Shift+S</span>';
        saveItem.after(item);
      }

      function macShortcutLabel(value) {
        return value
          .replace(/\\bCtrl\\+/g, "Command+")
          .replace(/\\bAlt\\+/g, "Option+");
      }

      function rewriteShortcutLabelsForMac() {
        document.querySelectorAll(".md-shortcut, .tb-split-shortcut").forEach((label) => {
          const nextText = macShortcutLabel(label.textContent || "");
          if (label.textContent !== nextText) {
            label.textContent = nextText;
          }
        });

        document.querySelectorAll('[title*="Ctrl+"], [title*="Alt+"]').forEach((element) => {
          const title = element.getAttribute("title");
          if (!title) {
            return;
          }
          const nextTitle = macShortcutLabel(title);
          if (title !== nextTitle) {
            element.setAttribute("title", nextTitle);
          }
        });
      }

      function refreshHostOverrides() {
        ensureSaveAsMenuItem();
        enableNativeCommandItems();
        rewriteShortcutLabelsForMac();
      }

      let pendingHostOverridesRefresh = false;

      function scheduleHostOverridesRefresh() {
        if (pendingHostOverridesRefresh) {
          return;
        }

        pendingHostOverridesRefresh = true;
        requestAnimationFrame(() => {
          pendingHostOverridesRefresh = false;
          refreshHostOverrides();
        });
      }

      function nativeCommandForShortcut(event) {
        if (event.repeat || event.isComposing || event.altKey) {
          return null;
        }

        const hasCommandModifier = event.metaKey || event.ctrlKey;
        if (!hasCommandModifier) {
          return null;
        }

        const key = event.key.toLowerCase();
        const code = event.code;
        if (code === "KeyO" || key === "o" || key === "ㅐ") {
          if (event.shiftKey) {
            return null;
          }
          return "file:open";
        }
        if (code === "KeyS" || key === "s" || key === "ㄴ") {
          if (event.shiftKey) {
            return "file:save-as";
          }
          return "file:save";
        }
        if (code === "KeyP" || key === "p" || key === "ㅔ") {
          if (event.shiftKey) {
            return null;
          }
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

      async function exportHwpDocument(messageType, errorPrefix) {
        try {
          await settleEditorState();
          const payload = await requestHwpExportPayload();
          postNative({
            type: messageType,
            fileName: currentFileName(),
            base64: payload.base64,
            byteCount: payload.byteCount
          });
        } catch (error) {
          postNative({
            type: "error",
            message: `${errorPrefix}: ${error?.message || String(error)}`
          });
        }
      }

      async function exportPDFDocument() {
        try {
          await settleEditorState();
          const payload = await requestHwpExportPayload();
          postNative({
            type: "export-pdf-document",
            fileName: currentFileName(),
            base64: payload.base64,
            byteCount: payload.byteCount
          });
        } catch (error) {
          postNative({
            type: "error",
            message: `PDF 데이터를 만들 수 없습니다: ${error?.message || String(error)}`
          });
        }
      }

      async function printDocument() {
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

      async function handleNativeCommand(command) {
        if (command === "file:open" || command === "file:save" || command === "file:save-as" || command === "file:export-pdf") {
          postNative({
            type: "command",
            command,
            fileName: currentFileName()
          });
          return;
        }

        if (command === "file:share") {
          exportHwpDocument("share-document", "공유 데이터를 만들 수 없습니다");
          return;
        }

        if (command === "file:print") {
          printDocument();
          return;
        }
      }

      window.__alhangeulHostBridgeExportHwpDocument = (messageType) => {
        if (messageType !== "save-document" && messageType !== "share-document") {
          return false;
        }

        exportHwpDocument(messageType, "문서를 내보낼 수 없습니다");
        return true;
      };

      window.__alhangeulHostBridgeExportPDFDocument = () => {
        exportPDFDocument();
        return true;
      };

      window.__alhangeulHostBridgeRunNativeCommand = (command) => {
        if (!nativeCommands.has(command)) {
          return false;
        }

        closeMenus();
        handleNativeCommand(command);
        return true;
      };

      refreshHostOverrides();

      const nativeCommandObserver = new MutationObserver(() => {
        refreshHostOverrides();
      });
      nativeCommandObserver.observe(document.documentElement, {
        childList: true,
        subtree: true
      });

      function handleNativeCommandElementEvent(event) {
        const target = event.target;
        if (!(target instanceof Element)) {
          return;
        }

        const item = target.closest(".md-item[data-cmd]");
        if (!item) {
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
      }

      document.addEventListener("mousedown", scheduleHostOverridesRefresh, true);
      document.addEventListener("mousedown", handleNativeCommandElementEvent, true);
      document.addEventListener("click", handleNativeCommandElementEvent, true);

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
