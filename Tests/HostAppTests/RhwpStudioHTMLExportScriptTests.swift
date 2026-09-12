import JavaScriptCore
import XCTest

@MainActor
final class RhwpStudioHTMLExportScriptTests: XCTestCase {
    func testCaptureDefersNavigationAndRequiresMatchingRequest() async throws {
        let context = try XCTUnwrap(JSContext())
        let done = expectation(description:"HTML capture")
        let callback: @convention(block) () -> Void = { done.fulfill() }
        context.setObject(callback, forKeyedSubscript:"testDone" as NSString)
        context.evaluateScript("""
        var clicks=0;
        function HTMLAnchorElement(){this.href='';this.download=''}
        HTMLAnchorElement.prototype.click=function(){clicks++};
        const originalClick=HTMLAnchorElement.prototype.click;
        var window={__alhangeulSaveLock:{id:'export-1'}};
        var document={createElement:()=>new HTMLAnchorElement()};
        var URL={createObjectURL:()=> 'blob:native-copy'};
        async function fetch(url){return {blob:async()=>({type:'text/html'})}}
        function requireSaveLock(id){
          if(window.__alhangeulSaveLock?.id!==id)throw new Error('stale');
          return window.__alhangeulSaveLock;
        }
        \(RhwpStudioHTMLExportScript.source)
        (async()=>{
          const result=await captureHTMLDownload('html',async()=>{
            const a=new HTMLAnchorElement();a.href='blob:upstream';a.download='문서.html';a.click();return {ok:true};
          },'export-1');
          captureSafe=clicks===0 && result.downloadURL==='blob:native-copy' && HTMLAnchorElement.prototype.click===originalClick;
          staleRejected=false;
          try{window.__alhangeulHostBridgeStartHTMLDownload('old')}catch{staleRejected=true}
          window.__alhangeulHostBridgeStartHTMLDownload('export-1');
          singleClick=clicks===1;
          try{window.__alhangeulHostBridgeStartHTMLDownload('export-1')}catch{}
          singleClick=singleClick && clicks===1;
        })().then(testDone,e=>{testError=String(e);testDone()});
        """)
        await fulfillment(of:[done],timeout:3)
        XCTAssertTrue(context.evaluateScript("typeof testError==='undefined' && captureSafe && staleRejected && singleClick")?.toBool() == true)
    }
}
