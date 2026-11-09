// Stage 3 원본 문서 관측 재실행. 문서·글꼴을 수정하거나 host provider를 연결하지 않는다.
import {readFileSync, writeFileSync, copyFileSync, mkdirSync} from 'node:fs';
import {resolve, relative, isAbsolute, sep} from 'node:path';
import {pathToFileURL, fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

const [repoArg, upstreamArg, outputArg] = process.argv.slice(2);
if (!repoArg || !upstreamArg || !outputArg) throw Error('저장소, upstream checkout, 새 출력 경로가 필요합니다');
const root=resolve(repoArg), upstream=resolve(upstreamArg), out=resolve(outputArg);
const child=relative(resolve(root,'build.noindex'),out);
if (!child || child==='..' || child.startsWith('..'+sep) || isAbsolute(child)) throw Error('build.noindex 하위 경로가 필요합니다');
mkdirSync(out); // 상위 경로가 존재해야 하며 기존 결과는 덮어쓰지 않는다.
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const bundle=resolve(root,'Sources/HostApp/Resources/rhwp-studio');
copyFileSync(resolve(bundle,'rhwp.js'),resolve(out,'probe-rhwp.mjs'));
const {initSync,HwpDocument}=await import(pathToFileURL(resolve(out,'probe-rhwp.mjs')));
const wasm=readFileSync(resolve(bundle,'rhwp_bg.wasm'));
initSync({module:wasm});
const result={scope:'bundled-wasm-page0-without-host-provider',
  sourceCommit:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),
  dirty:!!execFileSync('git',['status','--porcelain'],{cwd:root,encoding:'utf8'}).trim(),
  studioCommit:JSON.parse(readFileSync(resolve(bundle,'manifest.json'),'utf8')).source_resolved_commit,
  scriptSHA256:hash(readFileSync(fileURLToPath(import.meta.url))),
  wasmSHA256:hash(wasm),jsSHA256:hash(readFileSync(resolve(bundle,'rhwp.js'))),results:[]};
for(const [format,name] of [['hwp','samples/hwp3-sample10.hwp'],
  ['hwpx','mydocs/pr/assets/issue7774/sql-sample10-regressions-20261015/hwp3-sample10-hwpx.hwpx']]) {
  const data=readFileSync(resolve(upstream,name));
  const row={format,inputSHA256:hash(data),providerConnected:false};
  let doc;
  try {
    doc=new HwpDocument(data);
    row.pageCount=doc.pageCount();
    const svg=doc.renderPageSvg(0);
    writeFileSync(resolve(out,format+'-page0.svg'),svg);
    Object.assign(row,{svgSHA256:hash(svg),svgBytes:Buffer.byteLength(svg),
      fontFamilies:[...new Set([...svg.matchAll(/font-family="([^"]+)"/g)].map(m=>m[1]))].sort(),
      parseAndSVG:'PASS',actualFontSelection:'NOT_RUN',visualComparison:'NOT_RUN'});
  } catch {
    Object.assign(row,{parseAndSVG:'FAIL',error:'documentProbeFailed'});
    process.exitCode=1;
  } finally {doc?.free();}
  result.results.push(row);
}
writeFileSync(resolve(out,'result.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
