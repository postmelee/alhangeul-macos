import * as local from './src/core/local-fonts';
import { HostCanvasFontSession, withHostCanvasFonts } from './src/core/host-canvas-fonts';
import { CanvasKitLayerRenderer } from './src/view/canvaskit-renderer';
import { collectHostFontRequests } from './src/core/host-font-requests';
import { WasmBridge } from './src/core/wasm-bridge';
import { normalizeFontFaceData } from './src/core/sfnt-face';
import { setRawCanvasFont } from './src/core/canvas-font-raw';
import { CanvasSupplementalMetricProvider } from './src/core/supplemental-text-metrics';
const win = window as any;
win.rhwpStudio = {fonts:{setProvider:local.setHostFontProvider,getState:local.getHostFontState}};
const fonts=win.rhwpStudio.fonts;
const records:any[]=[];
const pause=(ms:number)=>new Promise(r=>setTimeout(r,ms));
const count=()=>[...document.fonts].filter(f=>f.family.includes('__rhwp_host_face_')).length;
const check=(name:string,pass:boolean,details:any={})=>{records.push({name,pass,...details}); if(!pass) console.error('CHECK FAIL',name,details);};
let credentials:any=null, calls:any[]=[];
async function message(op:string,args:any={},auth:any=credentials) {
 const result=await win.webkit.messageHandlers.alhangeulFonts.postMessage({version:1,loadToken:'probe',op,...(op==='handshake'?{}:{session:auth?.session,revision:auth?.revision}),...args});
 return result;
}
const aborted=(s:AbortSignal)=>{if(s.aborted)throw new DOMException('Aborted','AbortError');};
const provider={
 async getSnapshot(signal:AbortSignal){
   const auth=await message('handshake');aborted(signal);const faces:any[]=[];let offset=0;
   while(true){const row=await message('catalog',{offset},auth);aborted(signal);faces.push(...row.faces);if(row.nextOffset>=row.total)break;offset=row.nextOffset;}
   credentials=auth;
   return {revision:auth.revision,faces:faces.filter(f=>!f.limitation).map(f=>({id:f.id,family:f.family,fullName:f.fullName,postscriptName:f.postScriptName,style:f.style,aliases:f.aliases,weight:f.weight,slant:/oblique/i.test(f.style)?'oblique':/italic/i.test(f.style)?'italic':'normal'}))};
 },
 async readFace(id:string,revision:string,signal:AbortSignal){
   const auth=credentials;if(!auth||auth.revision!==revision)throw Error('revision mismatch');aborted(signal);
   let transfer:string|null=null;
   const cancel=()=>{void message('cancel',{id:transfer??id},auth).catch(()=>{});};signal.addEventListener('abort',cancel,{once:true});
   try{const open=await message('openFace',{id},auth);transfer=open.id;aborted(signal);const data=new Uint8Array(open.byteCount);
    for(let offset=0;offset<data.length;){aborted(signal);const row=await message('readChunk',{id:transfer,offset,length:Math.min(262144,data.length-offset)},auth);aborted(signal);if(row.revision!==revision||row.offset!==offset)throw Error('stale chunk');const bytes=Uint8Array.from(atob(row.data),c=>c.charCodeAt(0));data.set(bytes,offset);offset+=bytes.length;}
    calls.push({id,revision,hash:open.sha256,faceIndex:open.faceIndex,bytes:data.length});return {bytes:data.buffer,faceIndex:open.faceIndex};
   }finally{signal.removeEventListener('abort',cancel);if(transfer)await message('closeFace',{id:transfer},auth).catch(()=>{});}
 },
 subscribe(notify:()=>void){window.addEventListener('alhangeul-fonts-changed',notify);return()=>window.removeEventListener('alhangeul-fonts-changed',notify);}
};
const change=async(mode:string)=>{await win.webkit.messageHandlers.probeControl.postMessage({mode});await local.prepareHostFontCatalog();};
const selected=(family='Host Face',weight=400,slant:any='normal')=>local.resolveRendererLocalFont(family,{weight,slant});
function canvas(w=400,h=130){const c=document.createElement('canvas');c.width=w;c.height=h;return c;}
function picture(title:string,c:HTMLCanvasElement){const h=document.createElement('h3');h.textContent=title;document.querySelector('#proof')!.append(h,c);}
function draw(session:HostCanvasFontSession,font:string,text='가나다 ABC 😀'){const c=canvas();const ctx=c.getContext('2d')!;ctx.fillStyle='white';ctx.fillRect(0,0,c.width,c.height);withHostCanvasFonts(session,()=>{ctx.font=font;ctx.fillStyle='black';ctx.fillText(text,8,80);});return {c,image:c.toDataURL(),width:ctx.measureText('😀').width,font:ctx.font};}
win.runProbe=async()=>{
 const wasm=new WasmBridge();await wasm.initialize();
 const before=calls.length;await fonts.setProvider(provider);check('metadata only',calls.length===before,fonts.getState());
 const session=new HostCanvasFontSession();await session.prepare([selected()!]);const regular=draw(session,'40px "Host Face"');picture('Native IPC → Canvas2D · Gowun Batang Regular',regular.c);check('native static face applied',session.diagnostics().loaded===1&&regular.font.includes('__rhwp_host_face_'),{diag:session.diagnostics()});
 await session.prepare([selected('Host Face',700)!]);const bold=draw(session,'bold 40px "Host Face"');picture('Native IPC → Canvas2D · Gowun Batang Bold',bold.c);check('bold chosen',calls.some(c=>c.id==='bold')&&regular.image!==bold.image,{calls:calls.slice()});
 const oldRevision=credentials.revision;await change('replace');await session.prepare([selected()!]);const replacement=draw(session,'40px "Host Face"');check('same name replacement',oldRevision!==credentials.revision&&replacement.image!==regular.image,{fontCount:count()});
 await change('error');await session.prepare([selected()!]);check('read failure cleared old FontFace',session.diagnostics().failed===1&&count()===0,session.diagnostics());
 await change('normal');await session.prepare([selected()!]);check('error recovery new revision',draw(session,'40px "Host Face"').image===regular.image,session.diagnostics());
 const ref=selected()!;await change('replace');check('old reference rejected',await local.loadRendererLocalFont(ref)===null);
 await change('ttc');
 for(const [style,index,units] of [['Regular',0,900],['Italic',1,1080],['Oblique',2,1200]] as const){
  const r=selected('Collection Face',400,style==='Regular'?'normal':style.toLowerCase())!;await session.prepare([r]);const css=`${index?style.toLowerCase()+' ':''}48px "Collection Face"`;const drawn=draw(session,css,'A가😀');
  const data=await provider.readFace(r.hostReference!.face.id,credentials.revision,new AbortController().signal);
  const control=await win.webkit.messageHandlers.probeControl.postMessage({reference:style});const bytes=Uint8Array.from(atob(control),c=>c.charCodeAt(0)).buffer;
  const expectedFont=new FontFace('standalone-'+style,bytes);await expectedFont.load();document.fonts.add(expectedFont);const c=canvas();const ctx=c.getContext('2d')!;ctx.fillStyle='white';ctx.fillRect(0,0,c.width,c.height);setRawCanvasFont(ctx,`48px "standalone-${style}"`);ctx.fillStyle='black';ctx.fillText('A가😀',8,80);
  const metric=new CanvasSupplementalMetricProvider();metric.reset({document:1,fonts:index+1});const m=await metric.prepare({document:1,fonts:index+1},[{key:'emoji',cluster:'😀',font:css}],()=>document.fonts.ready,()=>session.measurementContext(canvas().getContext('2d')!));
  check('TTC '+style+' paint/measurement',drawn.image===c.toDataURL()&&Math.abs(drawn.width-48*units/1000)<0.01&&m.metrics[0].measuredAdvancePx===drawn.width,{index:data.faceIndex,width:drawn.width,measured:m.metrics[0].measuredAdvancePx,expected:48*units/1000,referenceWidth:ctx.measureText('😀').width,pixelsEqual:drawn.image===c.toDataURL(),descriptor:drawn.font});picture('TTC '+style,drawn.c);document.fonts.delete(expectedFont);
 }
 await fonts.setProvider(null);check('detach releases FontFace',count()===0);session.reset();
 // Late native I/O deliberately ignores cancellation; the native session must discard it.
 await change('slow');await fonts.setProvider(provider);const slow=session.prepare([selected()!]);await pause(100);await fonts.setProvider(null);await slow;check('detach rejects late native response',count()===0&&session.diagnostics().loaded===0);await pause(50);
 await change('normal');await fonts.setProvider(provider);
 wasm.createNewDocument();const text='한글 가나다 ABC 0123';wasm.insertText(0,0,0,text);wasm.applyCharFormat(0,0,0,text.length,JSON.stringify({fontId:wasm.findOrCreateFontId('Host Face'),fontSize:2400}));wasm.applyCharFormat(0,0,3,6,JSON.stringify({bold:true}));
 await wasm.prepareCanvasMetrics('canvas2d');const docCanvas=canvas(794,1123);const paints:any[]=[];const orig=CanvasRenderingContext2D.prototype.fillText;CanvasRenderingContext2D.prototype.fillText=function(t,x,y,...rest){paints.push({t,font:this.font});return orig.call(this,t,x,y,...rest);};try{wasm.renderPageToCanvas(0,docCanvas,1);}finally{CanvasRenderingContext2D.prototype.fillText=orig;}
 picture('Actual WASM document → WebKit Canvas2D',docCanvas);check('actual document host faces',wasm.getHostCanvasFontDiagnostics().loaded===2&&paints.some(p=>p.font.includes('__rhwp_host_face_')),{diag:wasm.getHostCanvasFontDiagnostics(),paints:paints.slice(0,20)});
 const svg=wasm.renderPageSvg(0);win.probeSvg=svg;check('portable SVG retains names',svg.includes('Host Face')&&!svg.includes('__rhwp_host_face_'));
 const saved=wasm.exportHwp();const generation=wasm.documentGeneration;await change('replace');wasm.invalidateCanvasMetricFonts();await wasm.prepareCanvasMetrics('canvas2d');check('font change preserves document',wasm.documentGeneration===generation&&Array.from(saved).join()===Array.from(wasm.exportHwp()).join());
 wasm.createNewDocument();check('document switch releases FontFaces',wasm.getHostCanvasFontDiagnostics().loaded===0&&count()===0);
 // Pending document preparation must not repopulate a newly created document.
 await change('slow');await fonts.setProvider(provider);wasm.insertText(0,0,0,'한글');wasm.applyCharFormat(0,0,0,2,JSON.stringify({fontId:wasm.findOrCreateFontId('Host Face'),fontSize:2400}));const pendingDoc=wasm.prepareCanvasMetrics('canvas2d');await pause(100);wasm.createNewDocument();await pendingDoc;check('pending native document switch',wasm.getHostCanvasFontDiagnostics().loaded===0&&count()===0);
 await change('normal');const ignoring={...provider,async readFace(id,rev,signal){const data=await provider.readFace(id,rev,new AbortController().signal);await pause(300);return data;}};await fonts.setProvider(ignoring);const pendingIgnored=session.prepare([selected()!]);await pause(100);await fonts.setProvider(null);await pendingIgnored;check('upstream discards abort-ignoring provider result',count()===0&&session.diagnostics().loaded===0);await fonts.setProvider(provider);
 // Selected TTC italic/oblique outlines compared with independently supplied standalone files on each requested backend.
 await change('ttc');
 for(const backend of ['webgl','webgpu','software'] as const){
  try{const contexts:any[]=[];const originalGet=HTMLCanvasElement.prototype.getContext;
   HTMLCanvasElement.prototype.getContext=function(type,...args){const ctx=originalGet.call(this,type,...args);if(ctx&&String(type).includes('webgl')){const ext=ctx.getExtension('WEBGL_debug_renderer_info');contexts.push({type,renderer:ctx.getParameter(ext?ext.UNMASKED_RENDERER_WEBGL:ctx.RENDERER),version:ctx.getParameter(ctx.VERSION),lost:ctx.isContextLost()});}return ctx;};
   const r=await CanvasKitLayerRenderer.create('default',backend);const off=local.onHostFontsChanged(()=>r.resetDocumentResources());
   for(const [style,index] of [['Italic',1],['Oblique',2]] as const){
    const tree:any={pageWidth:400,pageHeight:130,root:{kind:'leaf',bounds:{x:0,y:0,width:400,height:130},ops:[{type:'textRun',text:'A가',bbox:{x:10,y:10,width:300,height:90},baseline:70,positions:[0,70,140],positionsComplete:true,style:{fontFamily:'Collection Face',fontSize:64,italic:true,color:'#111111'}}]}};
    await change(style==='Italic'?'ttc-italic':'ttc-oblique');await r.prepareHostFonts(collectHostFontRequests(tree));const c=canvas();r.renderPage(tree,c,1);const image=c.toDataURL();const diag=r.diagnostics();picture('CanvasKit requested '+backend+' · '+style,c);
    await change(style==='Italic'?'standalone-italic':'standalone-oblique');tree.root.ops[0].style.italic=false;tree.root.ops[0].style.fontFamily='Collection-Selected';await r.prepareHostFonts(collectHostFontRequests(tree));const refCanvas=canvas();r.renderPage(tree,refCanvas,1);
    check('CanvasKit '+backend+' '+style+' TTC parity',diag.localTypefaceCount===1&&image===refCanvas.toDataURL()&&diag.lastRenderCompleted,{requested:backend,diagnostics:diag,pixelsEqual:image===refCanvas.toDataURL(),contexts:contexts.slice()});
   }
   off();r.dispose();HTMLCanvasElement.prototype.getContext=originalGet;check('CanvasKit '+backend+' dispose',r.diagnostics().localTypefaceCount===0);
  }catch(e){records.push({name:'CanvasKit '+backend,pass:false,error:String(e)});}
 }
 await fonts.setProvider(null);wasm.releaseCanvasFontResources();check('final cleanup',count()===0);
 const budget=await win.webkit.messageHandlers.probeControl.postMessage({budget:true});check('native slots reusable',budget.free===2,budget);
 win.probeImages=[...document.querySelectorAll('#proof canvas')].map(c=>({title:c.previousElementSibling?.textContent,image:c.toDataURL()}));win.probeResult={records,calls,userAgent:navigator.userAgent,webgpu:!!navigator.gpu,finalFontCount:count()};return win.probeResult;
};
win.probeReady=true;
