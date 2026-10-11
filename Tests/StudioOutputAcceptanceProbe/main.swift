import AppKit
import PDFKit
import SwiftUI
import WebKit
import ScreenCaptureKit
import CryptoKit

@main
private struct OutputAcceptanceMain {
    @MainActor static func main() {
        let app = NSApplication.shared, delegate = OutputAcceptanceProbe()
        app.setActivationPolicy(.regular); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

// 실제 Coordinator·provider·저장·seal 경로다. 목적지와 spool callback만 시험 입력이다.
@MainActor
private final class OutputAcceptanceProbe: NSObject, NSApplicationDelegate {
    struct Failure: Error { let message: String }
    private var window: NSWindow!, web: WKWebView!, coordinator: RhwpStudioWebView.Coordinator!
    private var session: RhwpStudioEditorSession?
    private var output: URL!, errors: [String] = [], checks: [String] = [], reads: [[String:Any]] = []
    private var reports: [[String:Any]] = [], exported: URL?, printResult: String?
    private let body = "한글 가나다 ABC 0123 고운바탕 글꼴 확인 입력"
    private var source = "managed"
    private var cancelNextOutput = false, cancellationObserved = false
    private var removeNextOutput = false, removalObserved = false
    private func argument(_ key: String, default value: String) -> String {
        CommandLine.arguments.first(where: { $0.hasPrefix("--\(key)=") }).map { String($0.dropFirst(key.count + 3)) } ?? value
    }
    private func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message:message) }
        checks.append(message); print("PASS: \(message)")
    }
    private func js(_ code: String) async throws -> Any? {
        try await web.callAsyncJavaScript(code,arguments:[:],in:nil,contentWorld:.page)
    }
    private func wait(_ message: String, timeout: TimeInterval = 45, _ condition: () async throws -> Bool) async throws {
        let end = ProcessInfo.processInfo.systemUptime + timeout
        while !(try await condition()) {
            if ProcessInfo.processInfo.systemUptime > end { throw Failure(message:"timeout \(message): \(errors)") }
            try await Task.sleep(nanoseconds:100_000_000)
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { do { try await run(); finish(nil) } catch { finish(String(describing:error)) } }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    private func run() async throws {
        source = argument("source",default:"managed")
        let root = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("StudioOutputAcceptanceProbe")
        output = root.appendingPathComponent("runs/" + argument("run",default:UUID().uuidString))
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let installed = try InstalledFontCatalogService(persistence:.file(at:output.appendingPathComponent("installed")),observeChanges:false)
        _ = try await installed.prepare()
        let state = try await installed.setEnabled(source == "installed")
        let library = FontLibraryService(store:.init(rootURL:output.appendingPathComponent("managed")))
        _ = try await library.prepare()
        if source == "managed" {
            let candidates = ["Regular","Bold"].map { FontImportCandidate(sourceURL:
                Bundle.main.resourceURL!.appendingPathComponent("test-fonts/GowunBatang-\($0).ttf")) }
            let imported = await library.importFonts(.init(candidates:candidates,accessURLs:[]))
            try check(imported.allSatisfy { $0.status == .added },"승인된 고운바탕 두 face를 private 관리 보관함에 복사")
        }
        if source == "installed" {
            try check(["NanumSquareR","NanumSquareB"].allSatisfy { ps in
                state.records.contains { $0.postScriptName == ps && $0.failure == nil }
            },"실제 Mac NanumSquare Regular/Bold metadata 확인")
        }
        let handler = StudioFontMessageHandler(installed:.init(factory:{installed}),library:{library},
            onOutputFaceRead:{ [weak self] id,bytes in
                self?.reads.append(["idSource":id.split(separator:":").first.map(String.init) ?? "",
                    "ps":bytes.face.postScriptName,"weight":Int(bytes.face.weightClass),"bytes":bytes.data.count,
                    "sha256":SHA256.hash(data:bytes.data).map { String(format:"%02x",$0) }.joined()])
                guard let self else { return }
                if self.cancelNextOutput {
                    self.cancelNextOutput = false; self.cancellationObserved = true
                    self.coordinator.cancelOutputPreparation()
                }
                if self.removeNextOutput {
                    self.removeNextOutput = false
                    do {
                        let manifest = try await library.list()
                        _ = try await library.remove(objectHash:bytes.face.id.objectHash,expectedGeneration:manifest.generation)
                        self.removalObserved = true
                    } catch { self.errors.append("fixture removal: \(error)") }
                }
            })
        coordinator = .init(fontMessageHandler:handler)
        coordinator.onEditorSessionChange = { self.session = $0 }
        coordinator.onError = { if let error = $0 { self.errors.append(error); print("ERROR: \(error)") } }
        coordinator.choosePDFDestination = { _,_ in self.output.appendingPathComponent("current.pdf") }
        coordinator.onPDFExported = { self.exported = $0 }
        coordinator.confirmOutputFontFallback = { failures,_ in
            self.errors.append("unexpected fallback: \(failures)"); return false
        }
        coordinator.runPrintOperation = { pdf,_ in
            do {
                try self.check(self.source == "baseline" || self.reads.count >= 2,"인쇄 seal이 실제 face 읽기 후 실행")
                let data = try XCTData(pdf)
                try data.write(to:self.output.appendingPathComponent("print.pdf"))
                return false // 물리 프린터로 전송하지 않는다.
            } catch { self.errors.append(String(describing:error)); return nil }
        }
        coordinator.onPrintCompleted = {
            switch $0 {
            case .completed: self.printResult = "completed"
            case .cancelledBeforePanel: self.printResult = "cancelledBeforePanel"
            case .cancelledOrFailed: self.printResult = "cancelledOrFailed"
            case .failed(let error): self.printResult = "failed: \(error)"
            }
        }
        web = coordinator.makeWebView()
        window = NSWindow(contentRect:NSRect(x:150,y:100,width:1100,height:820),
            styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title = "알한글 — PDF·인쇄 글꼴 · Stage 3 격리 검증"
        window.isReleasedWhenClosed = false; window.contentView = web
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        for (index,ext) in ["hwp","hwpx"].enumerated() {
            let name = source == "installed" ? "nanum-document" : "gowun-document"
            let input = Bundle.main.resourceURL!.appendingPathComponent("\(name).\(ext)")
            session = nil
            coordinator.update(document:.init(data:try Data(contentsOf:input),filename:"\(name).\(ext)",revision:index+1,sourceProtection:.plain),
                sourceDocument:nil,reloadToken:0,loadID:index+1,in:web)
            try await wait("editor ready") { self.session?.snapshot.ready == true }
            _ = try await js("""
            const a=window.rhwpStudio.automation;
            a.registerCommand({id:'ext:output-probe',label:'probe',execute(s){window.__probeWasm=s.wasm;window.__probeState=s.documentState;window.__probeInput=s.getInputHandler();}});
            a.execute('ext:output-probe');a.unregisterCommand('ext:output-probe');
            window.__probeInput.moveCursorTo({sectionIndex:0,paragraphIndex:0,charOffset:26});
            window.__probeInput.focus();const input=document.querySelector('[aria-label="문서 편집 입력"]');
            input.value=' 입력';input.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:' 입력'}));
            """)
            try await wait("actual input") { try await self.js("return window.__probeWasm.getTextRange(0,0,0,window.__probeWasm.getParagraphLength(0,0)).endsWith(' 입력');") as? Bool == true }
            let before = try await documentState()
            let readStart = reads.count
            exported = nil
            _ = try await js("return window.__alhangeulHostBridgeRunNativeCommand('file:export-pdf');")
            try await wait("native PDF export") { self.exported != nil || !self.errors.isEmpty }
            guard let url = exported, errors.isEmpty else { throw Failure(message:"export: \(errors)") }
            let saved = output.appendingPathComponent("\(ext).pdf")
            try FileManager.default.copyItem(at:url,to:saved)
            let pdf = try unwrapPDF(saved)
            let text = pdf.string ?? "", selected = pdf.page(at:0)?.selection(for:pdf.page(at:0)!.bounds(for:.mediaBox))?.string ?? ""
            try JSONSerialization.data(withJSONObject:["text":text,"selection":selected],options:[.prettyPrinted,.sortedKeys])
                .write(to:output.appendingPathComponent("\(ext)-text.json"))
            try check(pdf.pageCount == 1 && isExactWrappedText(text),"\(ext): 줄 경계의 공백을 제외한 현재 편집 본문·한글·ASCII의 PDFKit 추출")
            try check(isExactWrappedText(selected) && pdf.findString("가나다",withOptions:[]).count == 1,
                "\(ext): PDFKit 검색·영역 선택의 한글 text layer")
            let rows = CGPDFFontResourceInspector.records(in:pdf)
            if source != "baseline" {
                let expected = source == "installed" ? ["NanumSquareR","NanumSquareB"] : ["GowunBatang-Regular","GowunBatang-Bold"]
                try check(expected.allSatisfy { ps in rows.contains { $0.baseFont.hasSuffix("+"+ps) && $0.hasToUnicode && $0.fontProgramBytes > 0 } },
                    "\(ext): 정확한 Regular/Bold PS와 한글 ToUnicode")
                try check(reads.count - readStart == 2,"\(ext): PDF job은 필요한 두 face만 각 1회 읽음")
            } else { try check(reads.count == 0,"\(ext): 공급 없는 Noto 기준선은 로컬 bytes 읽기 0") }
            try check(try await documentState() == before,"\(ext): PDF 내보내기는 원래 문서 bytes·dirty·changeSeq 유지")
            printResult = nil
            _ = try await js("return window.__alhangeulHostBridgeRunNativeCommand('file:print');")
            try await wait("print completion") { self.printResult != nil || !self.errors.isEmpty }
            try check(printResult == "cancelledOrFailed" && errors.isEmpty,"\(ext): 인쇄 callback 취소를 성공과 구분")
            let printPDF = try unwrapPDF(output.appendingPathComponent("print.pdf"))
            try check(isExactWrappedText(printPDF.string ?? ""),"\(ext): seal된 실제 인쇄 PDF text layer")
            try check(try await documentState() == before,"\(ext): 인쇄 준비·취소 후 원래 문서 상태 유지")
            try FileManager.default.copyItem(at:output.appendingPathComponent("print.pdf"),to:output.appendingPathComponent("\(ext)-print.pdf"))
            if source != "baseline" {
                let existing = try Data(contentsOf:url)
                exported = nil; cancelNextOutput = true; cancellationObserved = false
                _ = try await js("return window.__alhangeulHostBridgeRunNativeCommand('file:export-pdf');")
                try await wait("cancelled job cleanup") {
                    guard self.cancellationObserved else { return false }
                    return try await self.js("return window.__alhangeulSaveLock === null;") as? Bool == true
                }
                try check(exported == nil && errors.isEmpty && (try Data(contentsOf:url)) == existing,
                    "\(ext): 실제 bytes 반환 직후 취소는 기존 목적지를 보존·늦은 결과 폐기")
                if source == "managed" {
                    removeNextOutput = true; removalObserved = false
                    _ = try await js("return window.__alhangeulHostBridgeRunNativeCommand('file:export-pdf');")
                    try await wait("removed font abort") {
                        guard self.removalObserved, !self.errors.isEmpty else { return false }
                        return try await self.js("return window.__alhangeulSaveLock === null;") as? Bool == true
                    }
                    try check(exported == nil && errors.count == 1 && errors[0].contains("출력 준비 중 문서나 글꼴이 변경")
                        && (try Data(contentsOf:url)) == existing,"\(ext): 실제 관리 자산 제거는 stale 중단·대체 확인 우회 없음")
                    errors.removeAll()
                    let regular = FontImportCandidate(sourceURL:Bundle.main.resourceURL!.appendingPathComponent("test-fonts/GowunBatang-Regular.ttf"))
                    let restored = await library.importFonts(.init(candidates:[regular],accessURLs:[]))
                    try check(restored.first?.status == .added,"\(ext): 제거한 private 복사본 복원")
                }
                _ = try await js("return window.__alhangeulHostBridgeRunNativeCommand('file:export-pdf');")
                try await wait("reexport after cancellation/change") { self.exported != nil || !self.errors.isEmpty }
                try check(exported != nil && errors.isEmpty,"\(ext): 취소·설정 변경 이후 새 snapshot으로 재출력")
                try check(try await documentState() == before,"\(ext): 취소·관리 변경·재출력에서 원래 문서 상태 유지")
            }
            reports.append(["format":ext,"text":text,"selection":selected,"fonts":rows.map { ["ps":$0.baseFont,"subtype":$0.subtype,"toUnicode":$0.hasToUnicode,"fontProgramBytes":$0.fontProgramBytes,"descendantSubtype":$0.descendantSubtype] },
                "bounds":[pdf.page(at:0)!.bounds(for:.mediaBox).width,pdf.page(at:0)!.bounds(for:.mediaBox).height],"reads":Array(reads[readStart...])])
        }
        try await capture()
        if CommandLine.arguments.contains("--panel") {
            coordinator.runPrintOperation = nil
            printResult = nil
            _ = try await js("return window.__alhangeulHostBridgeRunNativeCommand('file:print');")
            try await wait("actual panel cancellation", timeout: 180) { self.printResult != nil }
            try check(printResult == "cancelledOrFailed","실제 인쇄 패널 취소·spool 전송 없음")
        }
    }
    private func documentState() async throws -> String {
        guard let state = try await js("return JSON.stringify(await window.__alhangeulHostBridgeSave ? await new Promise((resolve,reject)=>{const id='probe-state-'+Math.random();const on=e=>{if(e.data?.type==='rhwp-response'&&e.data.id===id){window.removeEventListener('message',on);e.data.error?reject(Error(e.data.error)):resolve(e.data.result);}};window.addEventListener('message',on);window.postMessage({type:'rhwp-request',id,method:'getDocumentState',params:{}},'*');}) : null);") as? String else { throw Failure(message:"document state") }
        return state
    }
    private func isExactWrappedText(_ text: String) -> Bool {
        // 한글 단어 중간의 줄바꿈과 원래 공백에서의 줄바꿈을 구분한다.
        // 줄 내부의 문자·공백은 원본과 정확히 비교하며 전체 공백 제거로 검사하지 않는다.
        var remaining = body[...]
        for line in text.components(separatedBy:.newlines).map({$0.trimmingCharacters(in:.whitespaces)}).filter({!$0.isEmpty}) {
            if remaining.first == " " { remaining.removeFirst() }
            guard remaining.hasPrefix(line) else { return false }
            remaining = remaining.dropFirst(line.count)
        }
        return remaining.isEmpty
    }
    private func unwrapPDF(_ url: URL) throws -> PDFDocument {
        guard let pdf = PDFDocument(url:url) else { throw Failure(message:"PDF decode") }; return pdf
    }
    private func capture() async throws {
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        try await Task.sleep(nanoseconds:300_000_000)
        if #available(macOS 14.4,*) {
            for _ in 0..<3 {
                do {
                    let content = try await SCShareableContent.currentProcess
                    guard let owned = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else { break }
                    let config = SCStreamConfiguration(); config.width = 2200; config.height = 1640
                    config.showsCursor = false; config.ignoreShadowsSingleWindow = true
                    let cg = try await SCScreenshotManager.captureImage(contentFilter:SCContentFilter(desktopIndependentWindow:owned),configuration:config)
                    try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])?.write(to:output.appendingPathComponent("editor.png"))
                    return
                } catch { try await Task.sleep(nanoseconds:300_000_000) }
            }
        }
        // 화면 캡처 서비스 실패는 실제 PDF 수용과 분리하며 동일 WebView 픽셀을 남긴다.
        let image: NSImage = try await withCheckedThrowingContinuation { done in
            web.takeSnapshot(with:nil) { image,error in
                if let image { done.resume(returning:image) }
                else { done.resume(throwing:error ?? Failure(message:"WebView snapshot")) }
            }
        }
        guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]) else {
            throw Failure(message:"snapshot encoding")
        }
        try png.write(to:output.appendingPathComponent("editor.png"))
    }
    private func finish(_ error: String?) {
        if let output {
            let report: [String:Any] = ["passed":error == nil,"source":source,"checks":checks,"reads":reads,"outputs":reports,
                "errors":errors,"error":error as Any? ?? NSNull()]
            try? JSONSerialization.data(withJSONObject:report,options:[.sortedKeys,.prettyPrinted]).write(to:output.appendingPathComponent("result.json"))
        }
        if let error { print("FAIL: \(error)") }
        if error == nil && CommandLine.arguments.contains("--interactive") { return }
        exit(error == nil ? 0 : 1)
    }
}

private func XCTData(_ pdf: PDFDocument) throws -> Data {
    guard let data = pdf.dataRepresentation() else { throw OutputAcceptanceProbe.Failure(message:"PDF encoding") }; return data
}

@MainActor final class DocumentWindowPresenter {
    static let shared = DocumentWindowPresenter()
    func openDocument(_ url: URL) { fatalError("external open outside probe") }
}
