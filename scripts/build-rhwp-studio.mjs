#!/usr/bin/env node
// 공개 host provider를 기존 메뉴에 연결하는 재현 가능한 Studio 빌드/증명 검증.
import {readFileSync, writeFileSync, cpSync, mkdirSync, mkdtempSync, symlinkSync, rmSync, existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {dirname, resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {adaptSource, fontMenuPlugin, receiptName, buildCommand, sourcePaths} from './studio-font-menu-adapter.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const adapterFiles = ['scripts/build-rhwp-studio.mjs', 'scripts/studio-font-menu-adapter.mjs'];
const sha = input => createHash('sha256').update(input).digest('hex');
const args = process.argv.slice(2);
const value = key => { const i = args.indexOf(key); return i < 0 ? null : args[i + 1]; };
if (args.includes('--help')) {
  console.log('Usage: node scripts/build-rhwp-studio.mjs --upstream-dir DIR\n       node scripts/build-rhwp-studio.mjs --verify-receipt RESOURCE_DIR [--upstream-dir DIR]');
  process.exit(0);
}
const upstream = value('--upstream-dir');
const resource = value('--verify-receipt');
const git = (...args) => execFileSync('git', ['-C', upstream, ...args], {encoding: 'utf8'}).trim();
function fingerprints() {
  return Object.fromEntries(adapterFiles.map(path => [path, sha(readFileSync(resolve(root, path)))]));
}
function loadSources() {
  return sourcePaths.map(path => {
    const absolute = resolve(upstream, 'rhwp-studio', path);
    const original = readFileSync(absolute, 'utf8');
    const committed = execFileSync('git', ['-C', upstream, 'show', `HEAD:rhwp-studio/${path}`], {encoding: 'utf8'});
    if (original !== committed) throw Error(`Modified upstream Studio source: ${path}`);
    return {path, absolute, original, adapted: adaptSource(original, path)};
  });
}
try {
  if (resource) {
    const receipt = JSON.parse(readFileSync(resolve(resource, receiptName), 'utf8'));
    if (receipt.schema !== 1 || receipt.studio_build_command !== buildCommand ||
        !/^[a-f0-9]{40}$/.test(receipt.source_resolved_commit)) throw Error('Invalid Studio font menu adapter receipt');
    const manifestPath = resolve(resource, 'manifest.json');
    if (existsSync(manifestPath) && JSON.parse(readFileSync(manifestPath, 'utf8')).source_resolved_commit !== receipt.source_resolved_commit) {
      throw Error('Studio font menu adapter manifest commit mismatch');
    }
    if (JSON.stringify(receipt.adapter_files) !== JSON.stringify(fingerprints())) throw Error('Studio font menu adapter fingerprint mismatch');
    if (receipt.sources?.length !== sourcePaths.length || receipt.sources.some((row, i) => row.path !== sourcePaths[i] ||
        !/^[a-f0-9]{64}$/.test(row.original_sha256) || !/^[a-f0-9]{64}$/.test(row.adapted_sha256))) throw Error('Invalid Studio font menu source fingerprints');
    if (upstream) {
      if (receipt.source_resolved_commit !== git('rev-parse', 'HEAD')) throw Error('Studio font menu adapter commit mismatch');
      const sources = loadSources();
      if (sources.some((row, i) => receipt.sources[i].original_sha256 !== sha(row.original) ||
          receipt.sources[i].adapted_sha256 !== sha(row.adapted))) throw Error('Studio font menu adapter source mismatch');
    }
    console.log('OK: Studio font menu adapter receipt verified');
  } else {
    if (!upstream) throw Error('--upstream-dir is required');
    const sources = loadSources();
    const studio = resolve(upstream, 'rhwp-studio');
    const require = createRequire(resolve(studio, 'package.json'));
    // 변환된 소스도 pinned compiler로 검사한다. upstream checkout은 변경하지 않는다.
    mkdirSync(resolve(root, 'build.noindex'), {recursive: true});
    const checkDir = mkdtempSync(resolve(root, 'build.noindex/studio-typecheck-'));
    try {
      cpSync(resolve(studio, 'src'), resolve(checkDir, 'src'), {recursive: true});
      cpSync(resolve(studio, 'types'), resolve(checkDir, 'types'), {recursive: true});
      symlinkSync(resolve(studio, 'node_modules'), resolve(checkDir, 'node_modules'), 'dir');
      for (const row of sources) writeFileSync(resolve(checkDir, row.path), row.adapted);
      const config = JSON.parse(readFileSync(resolve(studio, 'tsconfig.json'), 'utf8'));
      config.compilerOptions.paths['@wasm/*'] = [resolve(upstream, 'pkg/*')];
      writeFileSync(resolve(checkDir, 'tsconfig.json'), JSON.stringify(config));
      execFileSync(process.execPath, [resolve(studio, 'node_modules/typescript/lib/tsc.js'), '--project', resolve(checkDir, 'tsconfig.json')],
        {cwd: studio, stdio: 'inherit'});
    } finally { rmSync(checkDir, {recursive: true, force: true}); }
    const receipt = {schema: 1, studio_build_command: buildCommand, source_resolved_commit: git('rev-parse', 'HEAD'),
      adapter_files: fingerprints(), sources: sources.map(row => ({path: row.path,
        original_sha256: sha(row.original), adapted_sha256: sha(row.adapted)}))};
    const {build} = await import(pathToFileURL(require.resolve('vite')));
    await build({root: studio, configFile: resolve(studio, 'vite.config.ts'), base: './',
      plugins: [fontMenuPlugin(sources, receipt)]});
    console.log('OK: Studio built with host font menu adapter; upstream source files unchanged');
  }
} catch (error) { console.error(String(error)); process.exitCode = 1; }
