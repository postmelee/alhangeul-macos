import Foundation

enum RhwpStudioHTMLExportScript {
    static let source = """
    async function captureHTMLDownload(format, execute, id) {
      const originalClick = HTMLAnchorElement.prototype.click;
      let captured = null;
      HTMLAnchorElement.prototype.click = function() {
        if (captured || !this.href.startsWith("blob:") ||
            !this.download.toLowerCase().endsWith(`.${format}`)) {
          throw new Error("예상하지 않은 내보내기 다운로드입니다.");
        }
        // upstream URL은 1초 뒤 폐기된다. Blob을 보존하여 native 요청 전용 URL을 만든다.
        captured = {fileName:this.download, blob:fetch(this.href).then(response => response.blob())};
      };
      try {
        const result = await execute(`file:export-${format}`);
        if (result?.ok !== true || !captured) throw new Error("내보낼 파일을 만들 수 없습니다.");
        const blob = await captured.blob;
        const lock = requireSaveLock(id);
        lock.downloadURL = URL.createObjectURL(blob);
        lock.downloadFileName = captured.fileName;
        return {downloadURL:lock.downloadURL, downloadFileName:captured.fileName, mimeType:blob.type};
      } finally {
        HTMLAnchorElement.prototype.click = originalClick;
      }
    }

    window.__alhangeulHostBridgeStartHTMLDownload = id => {
      const lock = requireSaveLock(id);
      if (!lock.downloadURL || lock.downloadStarted) throw new Error("유효한 다운로드가 없습니다.");
      lock.downloadStarted = true;
      const anchor = document.createElement("a");
      anchor.href = lock.downloadURL;
      anchor.download = lock.downloadFileName;
      lock.downloadAnchor = anchor;
      try { anchor.click(); } finally { lock.downloadAnchor = null; }
      return true;
    };
    """
}
