import AppKit
import WebKit
import PDFKit

let root = URL(fileURLWithPath: "/Users/melee/Documents/projects/rhwp-mac")
let output = root.appendingPathComponent("build.noindex/task567/pr7405-validation")
actor Fixture {
    var mode = "normal"
    var generation = 0
    var releases = 0
    var reads = 0
    let regular: StudioFontBytes
    let bold: StudioFontBytes
    let ttc: [StudioFontBytes]
    let standalone: [String: StudioFontBytes]
    init() throws {
        func inspect(_ url: URL) throws -> [StudioFontBytes] {
            let data = try Data(contentsOf:url)
            return try FontFileInspector().inspect(data, filename:url.lastPathComponent).faces.map { .init(data:data,face:$0) }
        }
        let fonts = root.appendingPathComponent("build.noindex/task567/fonts/gowun-batang")
        regular = try inspect(fonts.appendingPathComponent("GowunBatang-Regular.ttf"))[0]
        bold = try inspect(fonts.appendingPathComponent("GowunBatang-Bold.ttf"))[0]
        let synthetic = output.appendingPathComponent("upstream/tests/fixtures/fonts")
        ttc = try inspect(synthetic.appendingPathComponent("RHWPHostFixture.ttc"))
        var refs:[String:StudioFontBytes]=[:]
        for style in ["Regular","Italic","Oblique"] {refs[style]=try inspect(synthetic.appendingPathComponent("RHWPHostFixture-\(style).ttf"))[0]}
        standalone=refs
    }
    func set(_ value:String) {mode=value;generation += 1}
    func reference(_ style:String) -> String { standalone[style]!.data.base64EncodedString() }
    func current(_ value:Int)->Bool { generation==value }
    func released(){releases += 1}
    func stats()->[String:Int] { ["reads":reads,"releases":releases] }
    func snapshot()->StudioFontSupplySnapshot {
        let gen=generation, selectedMode=mode
        var resources:[String:StudioFontBytes]=[:]
        var faces:[StudioFontFace]=[]
        func append(_ id:String,_ bytes:StudioFontBytes,_ family:String,_ style:String,_ weight:Int,_ ps:String?=nil){
            resources[id]=bytes
            faces.append(.init(id:id,source:"managed",postScriptName:ps ?? "\(family)-\(style)",family:family,fullName:family+" "+style,style:style,aliases:[],weight:weight,traits:0,limitation:nil))
        }
        if selectedMode.hasPrefix("ttc") || selectedMode.hasPrefix("standalone") {
            if selectedMode=="ttc" {for (i,style) in ["Regular","Italic","Oblique"].enumerated(){append("ttc\(i)",ttc[i],"Collection Face",style,400)}}
            else {
                let style=selectedMode.hasSuffix("italic") ? "Italic":"Oblique"
                let index=style=="Italic" ? 1:2
                append("selected",selectedMode.hasPrefix("ttc") ? ttc[index]:standalone[style]!,"Collection Face",style,400,"Collection-Selected")
            }
        } else {
            append("regular",selectedMode=="replace" ? bold:regular,"Host Face","Regular",400)
            append("bold",bold,"Host Face","Bold",700)
        }
        let immutable=resources
        return .init(identity:"fixture-\(gen)",faces:faces,omitted:0,failure:nil,
            read:{id in try await self.read(id, resources:immutable,mode:selectedMode)},
            current:{await self.current(gen)},release:{await self.released()})
    }
    func read(_ id:String,resources:[String:StudioFontBytes],mode:String) async throws -> StudioFontBytes {
        reads += 1
        if mode=="slow" { await withCheckedContinuation { (c:CheckedContinuation<Void,Never>) in DispatchQueue.global().asyncAfter(deadline:.now()+0.8){c.resume()} } }
        if mode=="error" { throw StudioFontError.unavailable }
        guard let value=resources[id] else {throw StudioFontError.invalidRequest}
        print("NATIVE READ \(id) \(value.data.count) \(value.face.id.sfntIndex) \(value.face.id.objectHash)")
        return value
    }
}
@MainActor final class Control:NSObject,WKScriptMessageHandlerWithReply {
    let fixture:Fixture;let fonts:StudioFontMessageHandler;let budget:StudioFontTransferBudget
    weak var web:WKWebView?
    init(_ fixture:Fixture,_ fonts:StudioFontMessageHandler,_ budget:StudioFontTransferBudget){self.fixture=fixture;self.fonts=fonts;self.budget=budget}
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage,replyHandler:@escaping(Any?,String?)->Void){
        Task { @MainActor in
            let args=message.body as! [String:Any]
            if let mode=args["mode"] as? String {
                await fixture.set(mode);fonts.begin(loadToken:"probe",observeChanges:false)
                _ = try? await web?.evaluateJavaScript("window.dispatchEvent(new Event('alhangeul-fonts-changed'))")
                replyHandler(true,nil)
            } else if let style=args["reference"] as? String {replyHandler(await fixture.reference(style),nil)}
            else if args["budget"] as? Bool == true {
                var slots:[UUID]=[]
                for _ in 0..<2 {if let s=try? await budget.acquire(){slots.append(s)}}
                for s in slots {await budget.release(s)}
                var stats=await fixture.stats();stats["free"]=slots.count;replyHandler(stats,nil)
            }else{replyHandler(nil,"unknown")}
        }
    }
}
@main struct Probe {
 @MainActor static func main() {
    setbuf(stdout,nil)
    let app=NSApplication.shared;app.setActivationPolicy(.regular)
    Task { @MainActor in
      do { try await run();print("PROBE COMPLETE");exit(0) } catch {print("PROBE FAIL \(error)");exit(1)}
    }
    app.run()
 }
 @MainActor static func run() async throws {
    let fixture=try Fixture();let budget=StudioFontTransferBudget()
    let handler=StudioFontMessageHandler(session:StudioFontSession(supply:.init(snapshot:{await fixture.snapshot()}),budget:budget))
    let control=Control(fixture,handler,budget)
    let config=WKWebViewConfiguration();config.websiteDataStore = .nonPersistent()
    config.setURLSchemeHandler(RhwpStudioResourceSchemeHandler(),forURLScheme:"alhangeul-studio")
    config.userContentController.addScriptMessageHandler(handler,contentWorld:.page,name:StudioFontMessageHandler.name)
    config.userContentController.addScriptMessageHandler(control,contentWorld:.page,name:"probeControl")
    let web=WKWebView(frame:NSRect(x:0,y:0,width:1050,height:850),configuration:config);handler.webView=web;control.web=web
    let window=NSWindow(contentRect:web.frame,styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false);window.title="PR #7405 WebKit 글꼴 검증";window.contentView=web;window.makeKeyAndOrderFront(nil)
    defer{handler.reset();config.userContentController.removeScriptMessageHandler(forName:StudioFontMessageHandler.name,contentWorld:.page);config.userContentController.removeScriptMessageHandler(forName:"probeControl",contentWorld:.page);window.orderOut(nil)}
    handler.begin(loadToken:"probe",observeChanges:false)
    web.load(URLRequest(url:URL(string:"alhangeul-studio://app/index.html")!))
    var ready=false
    for _ in 0..<300 {if (try? await web.evaluateJavaScript("window.probeReady === true")) as? Bool == true {ready=true;break};try await Task.sleep(nanoseconds:100_000_000)}
    guard ready else { throw NSError(domain:"probe",code:1,userInfo:[NSLocalizedDescriptionKey:"page readiness timeout"]) }
    let result=try await web.callAsyncJavaScript("return await window.runProbe();",arguments:[:],in:nil,contentWorld:.page)
    let data=try JSONSerialization.data(withJSONObject:result!,options:[.prettyPrinted,.sortedKeys]);try data.write(to:output.appendingPathComponent("result.json"));print(String(data:data,encoding:.utf8)!)
    let images=try await web.evaluateJavaScript("window.probeImages") as! [[String:String]]
    for (index,image) in images.enumerated(){if let raw=image["image"]?.split(separator:",").last,let data=Data(base64Encoded:String(raw)){try data.write(to:output.appendingPathComponent("canvas-\(index).png"))}}
    try JSONSerialization.data(withJSONObject:images.map{$0["title"] ?? ""},options:.prettyPrinted).write(to:output.appendingPathComponent("canvas-titles.json"))
    let snapshot=try await withCheckedThrowingContinuation { (c:CheckedContinuation<NSImage,Error>) in web.takeSnapshot(with:nil){image,error in if let error {c.resume(throwing:error)}else{c.resume(returning:image!)}} }
    if let tiff=snapshot.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]){try png.write(to:output.appendingPathComponent("webkit-proof.png"))}
    let svg=try await web.evaluateJavaScript("window.probeSvg") as! String
    try svg.write(to:output.appendingPathComponent("portable.svg"),atomically:true,encoding:.utf8)
    var outputWeb:WKWebView?
    let pdfRenderer=RhwpStudioPagePDFRenderer(webViewFactory:{config in let result=WKWebView(frame:NSRect(x:0,y:0,width:794,height:1123),configuration:config);outputWeb=result;return result})
    let payload=try RhwpStudioPagePayload(fileName:"probe.hwp",pageCount:1,pages:[svg])
    let pdf:PDFDocument=try await withCheckedThrowingContinuation { c in pdfRenderer.render(payload:payload){c.resume(with:$0)} }
    pdf.write(to:output.appendingPathComponent("current-output.pdf"))
    let outputFonts=try await outputWeb!.callAsyncJavaScript("return [...document.querySelectorAll('svg text')].map(n=>({text:n.textContent,family:getComputedStyle(n).fontFamily,weight:getComputedStyle(n).fontWeight}));",arguments:[:],in:nil,contentWorld:.defaultClient)
    try JSONSerialization.data(withJSONObject:outputFonts!,options:.prettyPrinted).write(to:output.appendingPathComponent("output-fonts.json"))
    if let page=pdf.page(at:0){let img=page.thumbnail(of:NSSize(width:794,height:1123),for:.mediaBox);if let tiff=img.tiffRepresentation,let png=NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]){try png.write(to:output.appendingPathComponent("current-output.png"))}}
    // Output-only feasibility probe: immutable fixture bytes, no Studio API in this realm.
    let fontsDir=root.appendingPathComponent("build.noindex/task567/fonts/gowun-batang")
    let outputRegular=try Data(contentsOf:fontsDir.appendingPathComponent("GowunBatang-Regular.ttf"))
    let outputBold=try Data(contentsOf:fontsDir.appendingPathComponent("GowunBatang-Bold.ttf"))
    let prepared=try await outputWeb!.callAsyncJavaScript("""
      for (const [encoded,weight] of [[regular,'400'],[bold,'700']]) {
        const bytes=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
        const font=new FontFace('Host Face',bytes,{weight,style:'normal'});
        await font.load();document.fonts.add(font);
      }
      await document.fonts.load('400 24px "Host Face"','한글');
      await document.fonts.load('700 24px "Host Face"','가나다');
      await document.fonts.ready;
      for(const n of document.querySelectorAll('svg text')) {
        if(getComputedStyle(n).fontFamily.includes('Host Face')) n.style.setProperty('font-family','"Host Face"','important');
      }
      return [...document.fonts].filter(f=>f.family==='Host Face').map(f=>({family:f.family,weight:f.weight,status:f.status}));
      """,arguments:["regular":outputRegular.base64EncodedString(),"bold":outputBold.base64EncodedString()],in:nil,contentWorld:.defaultClient)
    try JSONSerialization.data(withJSONObject:prepared!,options:.prettyPrinted).write(to:output.appendingPathComponent("output-injected-fonts.json"))
    let pdfConfig=WKPDFConfiguration();pdfConfig.rect=outputWeb!.bounds
    let injected:Data=try await withCheckedThrowingContinuation{c in outputWeb!.createPDF(configuration:pdfConfig){c.resume(with:$0)}}
    try injected.write(to:output.appendingPathComponent("output-injected.pdf"))
    if let page=PDFDocument(data:injected)?.page(at:0){let img=page.thumbnail(of:NSSize(width:794,height:1123),for:.mediaBox);if let tiff=img.tiffRepresentation,let png=NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]){try png.write(to:output.appendingPathComponent("output-injected.png"))}}
    // Reset/reload must revoke the old native session.
    let old=try await web.callAsyncJavaScript("return await window.webkit.messageHandlers.alhangeulFonts.postMessage({op:'handshake',version:1,loadToken:'probe'});",arguments:[:],in:nil,contentWorld:.page) as! [String:Any]
    handler.begin(loadToken:"reload",observeChanges:false)
    let rejected=try await web.callAsyncJavaScript("try { await window.webkit.messageHandlers.alhangeulFonts.postMessage({...old,op:'catalog',loadToken:'probe'}); return false; } catch {return true}",arguments:["old":old],in:nil,contentWorld:.page)
    try JSONSerialization.data(withJSONObject:["oldLoadTokenRejected":rejected as? Bool ?? false,"fixtureStats":await fixture.stats()],options:.prettyPrinted).write(to:output.appendingPathComponent("lifecycle.json"))
 }
}
@MainActor final class DocumentWindowPresenter {
 static let shared=DocumentWindowPresenter()
 func openDocument(_ url:URL){fatalError("unexpected external document open")}
}
