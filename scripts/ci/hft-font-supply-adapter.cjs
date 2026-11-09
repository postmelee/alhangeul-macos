// 제품 adapter를 실제 Swift session JSON-lines 서버에 연결하는 진단 harness.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {spawn} = require('node:child_process');
const readline = require('node:readline');

const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function summarize(cases) {
  const counts = {PASS: 0, FAIL: 0, EXPECTED_LIMITATION: 0, NOT_RUN: 0};
  for (const c of cases) for (const check of c.checks) {
    if (!Object.hasOwn(counts, check.status)) throw Error('invalidStatus');
    counts[check.status]++;
  }
  return {...counts, complete: counts.FAIL === 0 && counts.NOT_RUN === 0,
    supplyComplete: cases.every(c => c.checks.filter(x => !['selection','layout','render'].includes(x.stage))
      .every(x => x.status === 'PASS' || x.status === 'EXPECTED_LIMITATION'))};
}
function validateResult(result) {
  if (result.schemaVersion !== 1 || !Array.isArray(result.cases) || !result.cases.length) throw Error('invalidReport');
  for (const c of result.cases) {
    if (!Array.isArray(c.checks) || !c.checks.length) throw Error('missingChecks');
    for (const check of c.checks) {
      if (!check.reason || !check.stage || !check.evidenceKind) throw Error('missingEvidence');
      if (!['catalog','candidate','bytes','invalidation','selection','layout','render'].includes(check.stage)) throw Error('invalidStage');
      if (!['synthetic','installed-cli'].includes(check.evidenceKind)) throw Error('invalidEvidence');
    }
  }
  const inspect = value => {
    if (!value || typeof value !== 'object') return;
    for (const [key, item] of Object.entries(value)) {
      if (['sourceURL','bookmark','data','bytes','path'].includes(key)) throw Error('privateField');
      inspect(item);
    }
  };
  inspect(result);
  if (JSON.stringify(result.summary) !== JSON.stringify(summarize(result.cases))) throw Error('invalidSummary');
}

async function run({root, executable, state, mode, family}) {
  const child = spawn(executable, [path.join(root,'Tests/FontLibraryTests/Fixtures'), state], {stdio:['pipe','pipe','pipe']});
  const exited = new Promise(resolve => {
    child.once('exit', (code,signal) => resolve([code,signal]));
    child.once('error', () => resolve([null,'spawnError']));
  });
  // stdout의 전송 bytes는 메모리에서만 소비하고 stderr 원문/사용자 경로를 보고서에 저장하지 않는다.
  child.stderr.resume();
  let seq = 0;
  const pending = new Map();
  const failAll = () => { for (const p of pending.values()) { clearTimeout(p.timer); p.reject(Error('transportExited')); } pending.clear(); };
  child.on('error', failAll); child.on('exit', failAll);
  child.stdin.on('error', failAll);
  const lines = readline.createInterface({input:child.stdout});
  lines.on('line', line => {
    try {
      const response = JSON.parse(line), p = pending.get(response.id);
      if (!p) return;
      pending.delete(response.id); clearTimeout(p.timer);
      if (response.error) p.reject(Object.assign(Error(response.error),{code:response.error}));
      else p.resolve(response.result);
    } catch { failAll(); child.kill(); }
  });
  function send(payload) {
    return new Promise((resolve,reject) => {
      if (child.exitCode !== null || child.killed) return reject(Error('transportExited'));
      const id = ++seq;
      const timer = setTimeout(() => { pending.delete(id); reject(Error('transportTimeout')); child.kill(); },20000);
      pending.set(id,{resolve,reject,timer});
      child.stdin.write(JSON.stringify({id,...payload})+'\n', error => {
        if (error) { const p=pending.get(id); if(p){clearTimeout(p.timer);pending.delete(id);p.reject(Error('transportWrite'));} }
      });
    });
  }
  const swift = fs.readFileSync(path.join(root,'Sources/HostApp/Services/StudioFontProviderScript.swift'),'utf8');
  const source = swift.match(/static let source = #"""\n([\s\S]*?)\n    """#/);
  if (!source) { child.kill(); throw Error('adapterSourceMissing'); }
  const factory = vm.runInThisContext(source[1]);
  const cases=[];
  try {
    const scenarios = mode === 'installed' ? ['installed'] : ['ttf','otf','both','none','book','empty','permission','corrupt','conflict','managed'];
    for (const scenario of scenarios) {
      const input = await send({command:'configure',scenario,family});
      const evidenceKind=input.evidenceKind, checks=[], reads=[], opened=new Map();
      const check = (stage, ok, reason, status) => checks.push({stage,status:status || (ok?'PASS':'FAIL'),reason,evidenceKind});
      const events = new EventTarget();
      const adapter=factory({events, getLoadToken:()=> 'probe-load', getFontsAPI:()=>api,
        postMessage: async body => {
          const response = await send({command:'rpc',body});
          if(body.op==='openFace') opened.set(body.id,response);
          return response;
        }});
      const api={setProvider:async provider=> { if(provider) await provider.getSnapshot(new AbortController().signal); },getState:()=>({})};
      let faces=[];
      try {
        await adapter.connect();
        const snapshot=await adapter.provider.getSnapshot(new AbortController().signal);
        faces=snapshot.faces;
        const expectedCounts={ttf:1,otf:1,both:2,none:0,book:0,empty:0,permission:1,corrupt:1,conflict:0,managed:1};
        check('catalog', mode==='installed' || input.rawFaces.length === (scenario==='both'||scenario==='conflict'||scenario==='managed'?2:scenario==='none'?0:1),'rawCatalogCount');
        if(mode==='installed') {
          check('candidate',faces.length>0,faces.length?'targetCandidates':'targetUnavailable',faces.length?'PASS':'NOT_RUN');
        } else check('candidate',faces.length===expectedCounts[scenario],`candidateCount:${scenario}`);
        if(scenario==='conflict') check('candidate',input.rawFaces.every(f=>f.limitation==='conflict'),'duplicatePostScriptConflict');
        if(scenario==='managed') {
          check('candidate',faces[0]?.id.startsWith('managed:'),'managedPrecedence');
          check('candidate',faces[0]?.aliases.includes('알한글 검증 글꼴'),'managedKoreanAlias');
        }
        if(scenario==='ttf') {
          check('candidate',!faces[0]?.aliases.includes('알한글 검증 글꼴'),'syntheticEnglishMetadataHasNoKoreanAlias');
        }
        for(const face of faces) {
          try {
            const value=await adapter.provider.readFace(face.id,snapshot.revision,new AbortController().signal);
            const bytes=Buffer.from(value.bytes), sha256=hash(bytes), signature=bytes.subarray(0,4).toString('hex');
            const native=opened.get(face.id), expected=input.expected.find(f=>f.postScriptName===face.postscriptName);
            reads.push({id:face.id,postScriptName:face.postscriptName,sha256,byteCount:bytes.length,signature,faceIndex:value.faceIndex});
            check('bytes',sha256===native?.sha256 && bytes.length===native?.byteCount,'transportMatchesNativeHash');
            check('bytes',['00010000','4f54544f'].includes(signature),'staticSfntSignature');
            if(expected) check('bytes',sha256===expected.sha256 && signature===expected.signature,'matchesFixture');
            if(['permission','corrupt'].includes(scenario)) check('bytes',false,'unexpectedReadSuccess');
          } catch(error) {
            const code=error.code || error.message;
            reads.push({id:face.id,error:code});
            check('bytes',(scenario==='permission'&&code==='permissionDenied') || (scenario==='corrupt'&&code==='corrupt'),`readFailure:${code}`);
          }
        }
        let notifications=0;
        const unsubscribe=adapter.provider.subscribe(()=>notifications++);
        await send({command:'refresh'});
        events.dispatchEvent(new Event('alhangeul-fonts-changed'));
        const next=await adapter.provider.getSnapshot(new AbortController().signal);
        check('invalidation',notifications>0,'providerSubscriberNotified');
        unsubscribe();
        check('invalidation',next.revision!==snapshot.revision,'refreshRevisionChanged');
        if(faces.length) {
          try { await adapter.provider.readFace(faces[0].id,snapshot.revision,new AbortController().signal);check('invalidation',false,'staleReadAccepted'); }
          catch(error){check('invalidation',error.code==='staleGeneration','staleReadRejected');}
        }
      } finally { await adapter.dispose(); }
      for(const stage of ['selection','layout','render']) check(stage,false,'requiresOfficialReleaseAndDocumentConsumer','NOT_RUN');
      cases.push({scenario,request:{family:mode==='installed'?family:'Alhangeul Fixture',weight:400,slant:'normal'},
        evidenceKind,observations:{rawFaces:input.rawFaces,candidates:faces,reads},checks});
    }
    const result={schemaVersion:1,mode,cases,summary:summarize(cases)};
    validateResult(result);
    return result;
  } finally {
    child.stdin.end();
    const timer=setTimeout(()=>child.kill(),3000);
    const [code, signal] = await exited; clearTimeout(timer); lines.close();
    if (code !== 0 || signal) throw Error('transportExited');
  }
}
module.exports={run,summarize,validateResult};
if(require.main===module) {
  const [root,executable,state,mode,family='']=process.argv.slice(2);
  run({root,executable,state,mode,family}).then(result=>{
    process.stdout.write(JSON.stringify(result,null,2)+'\n');
    process.exitCode=result.summary.FAIL?1:result.summary.supplyComplete?0:2;
  }).catch(()=>{process.stdout.write(JSON.stringify({schemaVersion:1,error:'probeExecutionFailed'})+'\n');process.exitCode=1;});
}
