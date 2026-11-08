import AppKit
import SwiftUI
import WebKit

/// 합성 계약 이벤트를 실제 WK transport로 전달한다. upstream의 rollback 보증 검증은 아니다.
@main struct StudioFatalRecoverySmoke {
    struct Failure: Error, CustomStringConvertible { let description: String }
    @MainActor static var checks = 0
    @MainActor static func check(_ value: Bool, _ name: String) throws {
        guard value else { throw Failure(description: name) }
        checks += 1; print("PASS \(name)")
    }
    @MainActor static func wait(_ name: String, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(20)
        while !predicate() {
            guard Date() < deadline else { throw Failure(description: "timeout: \(name)") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    @MainActor static func web(in view: NSView) -> WKWebView? {
        if let web = view as? WKWebView { return web }
        return view.subviews.compactMap { web(in: $0) }.first
    }
    @MainActor static func js(_ web: WKWebView, _ source: String, _ args: [String:Any] = [:]) async throws -> Any? {
        try await web.callAsyncJavaScript(source, arguments: args, in: nil, contentWorld: .page)
    }
    @MainActor static func type(_ web: WKWebView, _ text: String) async throws {
        _ = try await js(web, """
        const input = document.querySelector('textarea'); input.focus();
        if (!document.execCommand('insertText', false, text)) throw Error('insert failed');
        """, ["text": text])
    }
    @MainActor static func capture(_ window: NSWindow, to url: URL) throws {
        let view = window.contentView!
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw Failure(description: "native banner screenshot unavailable")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw Failure(description: "native banner screenshot encoding")
        }
        try png.write(to: url)
    }
    @MainActor static func answer(_ window: NSWindow, _ response: NSApplication.ModalResponse) async throws {
        try await wait("confirmation sheet") { window.attachedSheet != nil }
        window.endSheet(window.attachedSheet!, returnCode: response)
        try await wait("confirmation dismissed") { window.attachedSheet == nil }
        try await Task.sleep(nanoseconds: 150_000_000)
    }
    @MainActor static func save(_ window: NSWindow) async -> RhwpStudioDocumentSaveResult {
        await withCheckedContinuation { done in
            if !RhwpStudioNativeCommandDispatcher.saveDocument(in: window, completion: { done.resume(returning: $0) }) {
                done.resume(returning: .failed("no viewer"))
            }
        }
    }
    @MainActor static func fatal(_ coordinator: RhwpStudioWebView.Coordinator, _ web: WKWebView) {
        // OS process 종료 callback을 주입한다. upstream 오류 수정/실제 OS process kill 검증은 아니다.
        coordinator.webViewWebContentProcessDidTerminate(web)
    }
    @MainActor static func ready(_ store: DocumentViewerStore) async throws {
        try await wait("ready") { store.hasDocument && !store.isWebViewLoading && !store.isLoading }
        try await Task.sleep(nanoseconds: 350_000_000)
    }
    @MainActor static func run(format: DocumentSaveFormat, fixture: URL, output: URL) async throws {
        let store = DocumentViewerStore()
        let window = NSWindow(contentRect: .init(x: 100, y: 100, width: 960, height: 760),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "치명적 오류 복구 검증 \(format.rawValue)"
        window.contentView = NSHostingView(rootView: DocumentViewerView(store: store))
        let close = DocumentCloseConfirmationController()
        close.attach(window: window, store: store)
        window.makeKeyAndOrderFront(nil)
        defer { close.detach(restorePreviousDelegate: true); store.releaseRecoveryResources(); window.orderOut(nil) }
        store.loadDocument(from: fixture)
        try await ready(store)
        var original = web(in: window.contentView!)!
        let firstEpoch = store.editorSession!.snapshot.documentEpoch
        _ = try await js(original, "return await window.rhwpStudio.automation.execute('file:new-doc');")
        try await wait("new doc") { (store.editorSession?.snapshot.documentEpoch ?? 0) > firstEpoch }
        try await Task.sleep(nanoseconds: 700_000_000)
        try await type(original, "이전저장본 검증 alpha")
        try await wait("dirty") { store.hasUnsavedChanges }
        var coordinator = original.navigationDelegate as! RhwpStudioWebView.Coordinator
        let saved = output.appendingPathComponent("verified.\(format.rawValue)")
        coordinator.chooseSaveDestination = { _, _, _ in saved }
        try check(RhwpStudioNativeCommandDispatcher.run("file:save-as-\(format.rawValue)", in: window), "save format dispatched")
        try await wait("verified previous save") { store.previousSave != nil && !store.hasUnsavedChanges }
        try await wait("save request finished") { !coordinator.isSavingDocument }
        let candidate = store.previousSave!
        let savedBytes = try Data(contentsOf: saved)
        try check(candidate.data == savedBytes && candidate.format == format, "previous save uses actual synchronized and reopened bytes")
        var shareCalls = 0
        coordinator.presentShare = { data, filename in
            shareCalls += 1
            try check(DocumentSaveFormat.hwp.matchesPayloadSignature(data) && filename.hasSuffix(".hwp"), "healthy share uses correlated export")
        }
        _ = RhwpStudioNativeCommandDispatcher.run("file:share", in: window)
        try await wait("healthy share") { shareCalls == 1 }
        try await Task.sleep(nanoseconds: 200_000_000)
        try await type(original, " 미저장추가")
        try await wait("unsaved after save") { store.hasUnsavedChanges }
        let beforeFatal = store.editorSession!.snapshot
        fatal(coordinator, original)
        try check(store.suspendedSnapshot == beforeFatal, "fatal retains last session identity and dirty metadata")
        var suspendedSaveCalls = 0
        let handled = RhwpStudioNativeCommandDispatcher.saveDocument(in: window) { _ in suspendedSaveCalls += 1 }
        try check(!handled || suspendedSaveCalls == 1, "suspended save cannot remain pending")
        try await wait("fatal removes live editor") { store.webViewFailure != nil && web(in: window.contentView!) == nil }
        try check(!store.canRunWebViewCommands && store.hasUnsavedChanges, "fatal keeps last dirty and disables commands")
        try check(store.previousSave?.id == candidate.id, "fatal keeps prior verified bytes")
        try check(original.isHidden, "old WebView hidden synchronously")
        for command in ["file:save", "file:save-as", "file:share", "file:export-html", "file:export-pdf", "file:print"] {
            _ = RhwpStudioNativeCommandDispatcher.run(command, in: window)
        }
        try await Task.sleep(nanoseconds: 350_000_000)
        try check(try Data(contentsOf: saved) == savedBytes, "blocked commands preserve saved source")
        let alive = try? await js(original, "return !!window.rhwpStudio;") as? Bool
        try check(alive != true, "removed WebView no longer hosts automation editor")
        let otherStore = DocumentViewerStore()
        let other = NSWindow(contentRect: .init(x: 200, y: 200, width: 700, height: 600),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        other.contentView = NSHostingView(rootView: DocumentViewerView(store: otherStore))
        other.makeKeyAndOrderFront(nil)
        otherStore.loadDocument(from: fixture)
        try await ready(otherStore)
        let otherWeb = web(in: other.contentView!)!
        let otherCoordinator = otherWeb.navigationDelegate as! RhwpStudioWebView.Coordinator
        var wrongDestinations = 0
        otherCoordinator.chooseSaveDestination = { _, _, _ in wrongDestinations += 1; return nil }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await wait("suspended window is key") { NSApp.keyWindow === window }
        _ = RhwpStudioNativeCommandDispatcher.run("file:save-as")
        try await Task.sleep(nanoseconds: 200_000_000)
        try check(wrongDestinations == 0 && otherStore.canRunWebViewCommands,
            "suspended active window never redirects commands to healthy window")
        other.orderOut(nil); other.contentView = nil; otherStore.releaseRecoveryResources()
        store.chooseRecoveryDestination = { _, _, _ in nil }
        try check(!(await store.exportPreviousSave()), "recovery panel cancellation")
        try check(store.webViewFailure != nil && store.previousSave?.id == candidate.id, "cancel preserves suspension and candidate")
        store.chooseRecoveryDestination = { _, _, _ in saved }
        try check(!(await store.exportPreviousSave()), "recovery refuses saved source")
        let bad = output.appendingPathComponent("missing/recovery.\(format.rawValue)")
        store.chooseRecoveryDestination = { _, _, _ in bad }
        try check(!(await store.exportPreviousSave()), "recovery write failure retains state")
        try check(store.previousSave?.id == candidate.id && store.hasUnsavedChanges, "failure never cleans dirty or drops candidate")
        let recovered = output.appendingPathComponent("recovered.\(format.rawValue)")
        store.chooseRecoveryDestination = { _, _, _ in recovered }
        try check(await store.exportPreviousSave(), "separate recovery export succeeds")
        try check(try Data(contentsOf: recovered) == savedBytes, "recovery bytes exactly match previous saved point")
        let parser = try RhwpDocument(data: Data(contentsOf: recovered), filename: recovered.lastPathComponent)
        try check(parser.pageCount > 0, "recovery file reopens with native parser")
        try check(store.sourceDocument?.url == saved && store.hasUnsavedChanges && store.webViewFailure != nil,
            "recovery export never rebinds source or cleans dirty or restarts")
        if format == .hwpx { try capture(window, to: output.appendingPathComponent("fatal-previous-save.png")) }
        // 닫기/종료는 live session 조회 없이 중단 전 dirty와 복구본을 사용한다.
        window.performClose(nil)
        try await answer(window, .alertFirstButtonReturn)
        try check(window.isVisible && store.hasUnsavedChanges, "suspended close cancel keeps window")
        var terminationReply: Bool?, terminationCalls = 0
        let termination = DocumentTerminationCoordinator(reply: { _, result in terminationReply = result; terminationCalls += 1 })
        try check(termination.applicationShouldTerminate(NSApp) == .terminateLater, "suspended app termination waits")
        try await answer(window, .alertFirstButtonReturn)
        try await wait("termination cancel") { terminationReply != nil }
        try check(terminationReply == false && terminationCalls == 1, "termination cancel replies once and preserves dirty")
        let token = store.webViewReloadToken
        store.confirmRecoveryTransition = { _, _ in false }
        store.retryWebViewLoad()
        try await Task.sleep(nanoseconds: 150_000_000)
        try check(store.webViewReloadToken == token && store.previousSave?.id == candidate.id, "retry cancellation preserves failed session")
        store.confirmRecoveryTransition = { _, _ in true }
        store.retryWebViewLoad()
        try await wait("retry new WebView") { web(in: window.contentView!) != nil && store.webViewReloadToken > token }
        var retry = web(in: window.contentView!)!
        var retryCoordinator = retry.navigationDelegate as! RhwpStudioWebView.Coordinator
        retryCoordinator.webView(retry, didFail: nil, withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost))
        try await wait("retry failure") { store.webViewFailure != nil && web(in: window.contentView!) == nil }
        try check(store.previousSave?.id == candidate.id && store.suspendedSnapshot == beforeFatal, "failed retry keeps previous save and session metadata")
        store.retryWebViewLoad()
        try await ready(store)
        try check(store.previousSave?.id == candidate.id && store.previousSave?.loadID != store.webViewLoadID,
            "successful same-source retry keeps original save time and generation")
        try check(store.webViewFailure == nil && !store.hasUnsavedChanges && store.suspendedSnapshot == nil,
            "successful ready resumes editing from saved bytes")
        for outputFormat in ["html", "pdf"] {
            let live = web(in: window.contentView!)!
            let controller = live.navigationDelegate as! RhwpStudioWebView.Coordinator
            var destination: CheckedContinuation<URL?, Never>?
            var publishedCount = 0
            controller.onHTMLExported = { _ in publishedCount += 1 }
            controller.onPDFExported = { _ in publishedCount += 1 }
            if outputFormat == "html" {
                controller.chooseHTMLDestination = { _, _, _ in await withCheckedContinuation { destination = $0 } }
            } else {
                controller.choosePDFDestination = { _, _ in await withCheckedContinuation { destination = $0 } }
            }
            _ = RhwpStudioNativeCommandDispatcher.run("file:export-\(outputFormat)", in: window)
            try await wait("\(outputFormat) destination paused") { destination != nil }
            fatal(controller, live)
            let forbidden = output.appendingPathComponent("must-not-export-\(format.rawValue).\(outputFormat)")
            destination?.resume(returning: forbidden)
            try await Task.sleep(nanoseconds: 300_000_000)
            try check(!FileManager.default.fileExists(atPath: forbidden.path) && publishedCount == 0,
                "fatal prevents late \(outputFormat) publication")
            store.retryWebViewLoad(); try await ready(store)
        }
        // 인쇄/공유 준비 중 fatal은 외부 picker/print operation을 시작하지 않는다.
        let outputWeb = web(in: window.contentView!)!
        let outputCoordinator = outputWeb.navigationDelegate as! RhwpStudioWebView.Coordinator
        var printResults = 0, externalOutputs = 0
        outputCoordinator.runPrintOperation = { _, _ in externalOutputs += 1; return true }
        outputCoordinator.presentShare = { _, _ in externalOutputs += 1 }
        outputCoordinator.onPrintCompleted = { _ in printResults += 1 }
        _ = RhwpStudioNativeCommandDispatcher.run("file:print", in: window)
        _ = RhwpStudioNativeCommandDispatcher.run("file:share", in: window)
        fatal(outputCoordinator, outputWeb)
        try await wait("cancelled print callback") { printResults == 1 }
        try check(externalOutputs == 0 && printResults == 1, "fatal cancels print/share preflight without external publication")
        store.retryWebViewLoad(); try await ready(store)
        // 게시 전 fatal: 패널 선택 continuation이 뒤늦게 돌아와도 파일을 만들지 않는다.
        original = web(in: window.contentView!)!
        coordinator = original.navigationDelegate as! RhwpStudioWebView.Coordinator
        var choose: CheckedContinuation<URL?, Never>?
        coordinator.chooseSaveDestination = { _, _, _ in await withCheckedContinuation { choose = $0 } }
        let beforeDestination = output.appendingPathComponent("must-not-publish.\(format.rawValue)")
        let epoch = store.editorSession!.snapshot.documentEpoch
        _ = try await js(original, "return await window.rhwpStudio.automation.execute('file:new-doc');")
        try await wait("another new doc") { (store.editorSession?.snapshot.documentEpoch ?? 0) > epoch }
        try await Task.sleep(nanoseconds: 700_000_000)
        try await type(original, "게시경합")
        try await wait("new dirty") { store.hasUnsavedChanges }
        var completions = 0
        _ = RhwpStudioNativeCommandDispatcher.saveDocument(in: window, completion: { _ in completions += 1 })
        try await wait("save panel paused") { choose != nil }
        fatal(coordinator, original)
        try check(completions == 1, "pending save cancelled exactly once immediately at fatal")
        choose?.resume(returning: beforeDestination)
        try await Task.sleep(nanoseconds: 350_000_000)
        try check(completions == 1 && !FileManager.default.fileExists(atPath: beforeDestination.path),
            "late destination cannot publish or finish twice")
        try check(store.previousSave == nil, "new never-saved document has no recovery bytes")
        if format == .hwpx { try capture(window, to: output.appendingPathComponent("fatal-no-copy.png")) }
        // 게시 후 fatal: 실제 atomic write는 남고 늦은 notifySaved가 dirty/cache를 갱신하지 않는다.
        store.retryWebViewLoad()
        try await ready(store)
        retry = web(in: window.contentView!)!
        retryCoordinator = retry.navigationDelegate as! RhwpStudioWebView.Coordinator
        _ = try await js(retry, "return await window.rhwpStudio.automation.execute('file:new-doc');")
        try await Task.sleep(nanoseconds: 900_000_000)
        try await type(retry, "게시후저장")
        try await wait("after publish dirty") { store.hasUnsavedChanges }
        let publicationFormat = DocumentSaveFormat(rawValue: store.editorSession!.snapshot.format) ?? .hwp
        let published = output.appendingPathComponent("published-before-fatal-\(format.rawValue).\(publicationFormat.rawValue)")
        retryCoordinator.chooseSaveDestination = { _, _, _ in published }
        retryCoordinator.writeSaveData = { data, url, overwrite in
            try DocumentSavePanel.write(data: data, to: url, allowOverwrite: overwrite)
            Task { @MainActor in fatal(retryCoordinator, retry) }
        }
        let publishedResult = await save(window)
        if case .saved(let url) = publishedResult { try check(url == published, "already published write reported saved") }
        else { throw Failure(description: "published write incorrectly reported cancelled: \(publishedResult)") }
        try await wait("post-publish fatal") { store.webViewFailure != nil }
        try check(FileManager.default.fileExists(atPath: published.path), "published write retained after fatal")
        try check(store.hasUnsavedChanges && store.previousSave == nil && store.sourceDocument == nil,
            "late notifySaved cannot clean dirty, admit candidate, or bind source")
        try check(try Data(contentsOf: saved) == savedBytes,
            "recovery never overwrites original source")
        window.performClose(nil)
        try await answer(window, .alertSecondButtonReturn)
        try await wait("explicit discard closes") { !window.isVisible }
        try check(store.previousSave == nil, "explicit close removes recovery resources")
        print("PASS fatal recovery \(format.rawValue) complete")
    }
    @MainActor static func verifyProtectedAndExpired(fixture: URL, output: URL) async throws {
        for protected in [true, false] {
            var uptime = 0.0
            let pool = DocumentRecoveryCopies(ttl: 10, now: { uptime })
            let store = DocumentViewerStore(recoveryCopies: pool, classifyDocumentProtection: { _ in
                protected ? .passwordProtected : .plain
            })
            let window = NSWindow(contentRect: .init(x: 100, y: 100, width: 800, height: 700),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: DocumentViewerView(store: store))
            window.makeKeyAndOrderFront(nil)
            store.loadDocument(from: fixture); try await ready(store)
            let live = web(in: window.contentView!)!
            let controller = live.navigationDelegate as! RhwpStudioWebView.Coordinator
            controller.confirmSaveTransformation = { _, _, _ in true }
            let destination = output.appendingPathComponent(protected ? "protected-plain-copy.hwp" : "expire-source.hwp")
            controller.chooseSaveDestination = { _, _, _ in destination }
            _ = RhwpStudioNativeCommandDispatcher.run("file:save-as-hwp", in: window)
            try await wait("special source saved") { store.sourceDocument?.url == destination }
            if protected {
                try check(store.previousSave == nil, "protected origin never admits automatic plain recovery bytes")
                // 결과가 평문이어도 같은 editor epoch의 원래 보호 정책을 유지한다.
                try await wait("plain-copy request finished") { !controller.isSavingDocument }
                let repeated = await save(window)
                if case .saved = repeated {} else { throw Failure(description: "protected copy repeat save failed") }
                try check(store.previousSave == nil, "repeat save after plain copy retains original protection restriction")
            } else {
                try check(store.previousSave != nil, "plain source verified candidate admitted")
                var selection: CheckedContinuation<URL?, Never>?
                store.chooseRecoveryDestination = { _, _, _ in await withCheckedContinuation { selection = $0 } }
                fatal(controller, live)
                let export = Task { await store.exportPreviousSave() }
                try await wait("recovery lease panel") { selection != nil }
                uptime = 10
                try check(store.previousSave == nil, "expired candidate cannot start new recovery export")
                let file = output.appendingPathComponent("leased-expired-copy.hwp")
                selection?.resume(returning: file)
                try check(await export.value, "existing recovery lease survives expiry until completion")
                try check(try Data(contentsOf: file) == Data(contentsOf: destination), "leased copy bytes preserved through expiry")
                try check(!(await store.exportPreviousSave()), "expired candidate stays unavailable after lease closes")
                store.releaseRecoveryResources(); window.orderOut(nil); window.contentView = nil
                continue
            }
            fatal(controller, live)
            try check(!(await store.exportPreviousSave()) && store.webViewFailure != nil,
                "protected no-copy branch never restarts on unavailable export")
            store.releaseRecoveryResources(); window.orderOut(nil); window.contentView = nil
        }
    }

    @MainActor static func main() {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        Task { @MainActor in
            do {
                let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
                let output = URL(fileURLWithPath: CommandLine.arguments[2])
                let before = try Data(contentsOf: fixture)
                for format: DocumentSaveFormat in [.hwp, .hwpx] { try await run(format: format, fixture: fixture, output: output) }
                try await verifyProtectedAndExpired(fixture: fixture, output: output)
                try check(try Data(contentsOf: fixture) == before, "read-only fixture unchanged")
                print("PASS \(checks) fatal recovery checks (native process failure callback injection)")
                app.stop(nil); exit(0)
            } catch { print("FAIL \(error)"); app.stop(nil); exit(1) }
        }
        app.run()
    }
}

@MainActor final class DocumentWindowPresenter {
    static let shared = DocumentWindowPresenter()
    func openDocument(_ url: URL) { fatalError("unexpected external open") }
}
