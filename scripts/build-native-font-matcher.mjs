#!/usr/bin/env node
// pinned Studio의 공식 matcher와 기존 앱 catalog 정책을 그대로 번들한다.
import {readFileSync, writeFileSync} from 'node:fs';
import {resolve, dirname, relative} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const option = key => args[args.indexOf(key) + 1];
const output = 'Sources/Shared/FontLibrary/RhwpNativeFontMatcherSource.swift';
const receiptPath = 'Sources/Shared/FontLibrary/native-font-matcher-receipt.json';
const {createHash} = await import('node:crypto');
const sha = value => createHash('sha256').update(value).digest('hex');
const policyPath = 'Sources/HostApp/Services/StudioFontProviderScript.swift';
const ownFiles = ['scripts/build-native-font-matcher.mjs', policyPath];
const ownHashes = () => Object.fromEntries(ownFiles.map(path => [path, sha(readFileSync(resolve(root, path)))]));
if (args.includes('--verify')) {
  const receipt = JSON.parse(readFileSync(resolve(root, receiptPath), 'utf8'));
  const lock = readFileSync(resolve(root, 'rhwp-core.lock'), 'utf8');
  if (receipt.schema !== 1 || !lock.includes(`rhwp_commit = "${receipt.commit}"\n`)
      || JSON.stringify(receipt.adapters) !== JSON.stringify(ownHashes())
      || receipt.outputSHA256 !== sha(readFileSync(resolve(root, output)))) throw Error('Native matcher receipt drift');
  if (args.includes('--upstream-dir')) for (const [path, digest] of Object.entries(receipt.sources)) {
    if (sha(readFileSync(resolve(option('--upstream-dir'), path))) !== digest) throw Error(`Native matcher source drift: ${path}`);
  }
  console.log('OK: native matcher receipt');
} else {
  if (!args.includes('--upstream-dir') || !args.includes('--tool-dir')) throw Error('--upstream-dir and --tool-dir required');
  const upstream = resolve(option('--upstream-dir'));
  const commit = execFileSync('git', ['-C', upstream, 'rev-parse', 'HEAD'], {encoding:'utf8'}).trim();
  if (!readFileSync(resolve(root, 'rhwp-core.lock'), 'utf8').includes(`rhwp_commit = "${commit}"\n`)) throw Error('Core pin mismatch');
  const require = createRequire(resolve(option('--tool-dir'), 'package.json'));
  const esbuild = require('esbuild');
  if (esbuild.version !== '0.25.12') throw Error('Use esbuild 0.25.12');
  const policy = readFileSync(resolve(root, policyPath), 'utf8');
  const start = policy.indexOf('      function normalize(row) {');
  const end = policy.indexOf('      async function loadCatalog(', start);
  if (start < 0 || end < 0 || policy.indexOf('      function normalize(row) {', start+1) !== -1) throw Error('Catalog policy boundary drift');
  const entry = `import {setHostFontProvider,prepareHostFontCatalog,resolveRendererLocalFont} from './src/core/local-fonts.ts';
  const name = value => typeof value === 'string' && value.trim().length > 0 && value.length <= 1024;
  const text = value => typeof value === 'string' && value.length <= 1024;
  const key = value => value.replace(/\\u0000/g,'').normalize('NFC').replace(/\\s+/g,' ').trim().toLowerCase();
  ${policy.slice(start,end)}
  globalThis.resolveNativeFonts = async input => {
    globalThis.nativeFontResult = null;
    try {
      const value = JSON.parse(input);
      if (!name(value.identity) || !Array.isArray(value.faces) || value.faces.length > 25000
          || !Array.isArray(value.requests) || value.requests.length > 2048) throw Error('Invalid native catalog');
      const faces = select(value.faces);
      const provider = {getSnapshot:async()=>({revision:value.identity,faces}),
        readFace:async()=>{throw Error('Metadata-only matcher');},subscribe:()=>()=>{}};
      await setHostFontProvider(provider); await prepareHostFontCatalog();
      const selections = value.requests.map(request => {
        if (!name(request.key) || !name(request.family) || ![400,700].includes(request.weight)
            || !['normal','italic'].includes(request.slant)) throw Error('Invalid native request');
        const face = resolveRendererLocalFont(request.family,request)?.hostReference?.face;
        // 선택할 수 없는 로컬 후보를 기본 글꼴로 조용히 바꾸지 않는다.
        const known = value.faces.some(row => names(row).includes(key(request.family)));
        return face ? {key:request.key,status:'selected',id:face.id,postscriptName:face.postscriptName,
          weight:face.weight,slant:face.slant} : {key:request.key,status:known?'unavailable':'absent'};
      });
      globalThis.nativeFontResult = JSON.stringify({identity:value.identity,selections});
    } catch { globalThis.nativeFontResult = JSON.stringify({error:'invalidCatalog'}); }
    finally { await setHostFontProvider(null); }
  };`;
  const build = await esbuild.build({stdin:{contents:entry,resolveDir:resolve(upstream,'rhwp-studio'),loader:'ts'},
    bundle:true,write:false,format:'iife',platform:'neutral',target:'es2020',minify:false,metafile:true});
  const js = build.outputFiles[0].text;
  if (js.includes('\\#(') || js.includes('"""#')) throw Error('Swift raw string delimiter collision');
  const source = `// 생성 파일: scripts/build-native-font-matcher.mjs. 직접 수정 금지.\n// rhwp ${commit}, esbuild ${esbuild.version}\nenum RhwpNativeFontMatcherSource {\n    static let commit = "${commit}"\n    static let sha256 = "${sha(js)}"\n    static let script = #"""\n${js}    """#\n}\n`;
  // Swift multiline 내용 indentation을 0으로 고정한다.
  const swift = source.replace('    """#\n}', '"""#\n}');
  const sources = {};
  for (const input of Object.keys(build.metafile.inputs).filter(p=>p!=='<stdin>').sort()) {
    const absolute = resolve(input), path = relative(upstream,absolute);
    if (path.startsWith('..')) throw Error('External matcher dependency');
    const original = readFileSync(absolute);
    const committed = execFileSync('git',['-C',upstream,'show',`${commit}:${path}`]);
    if (!original.equals(committed)) throw Error(`Modified upstream source: ${path}`);
    sources[path] = sha(original);
  }
  writeFileSync(resolve(root,output),swift);
  writeFileSync(resolve(root,receiptPath),JSON.stringify({schema:1,commit,compiler:`esbuild ${esbuild.version}`,
    adapters:ownHashes(),sources,outputSHA256:sha(swift)},null,2)+'\n');
  console.log(`OK: native matcher generated from ${Object.keys(sources).length} pinned modules`);
}
