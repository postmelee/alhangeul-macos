// #594: upstream 공개 웹폰트 로더의 무제한 대기를 제한하는 후보 빌드 변환.
// 네트워크를 끄지 않는다. 실패 face는 CSS 공급에서도 제외해 fonts.ready 재대기를 막는다.
export const fontLoadDeadlineSource = `
const failedFontFiles = new Set<string>();
async function loadFontWithDeadline(face: FontFace): Promise<FontFace> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      face.load(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('WEB_FONT_LOAD_TIMEOUT')), 5000);
      }),
    ]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}
`;
function once(source, before, after) {
  if (source.split(before).length !== 2) throw Error('Web font loader source drift: ' + before);
  return source.replace(before, after);
}
export function adaptFontLoader(source) {
  source = once(source, 'const loadedFiles = new Set<string>();',
    'const loadedFiles = new Set<string>();\n' + fontLoadDeadlineSource);
  source = once(source, '.filter(entry => !(disableExternal && isExternalFontFile(entry.file)))',
    '.filter(entry => !failedFontFiles.has(entry.file) && !(disableExternal && isExternalFontFile(entry.file)))');
  source = once(source, 'targetSet.has(normalizeFontFamily(entry.name)) && !isDetectedOSFont(entry.name)',
    '!failedFontFiles.has(entry.file) && targetSet.has(normalizeFontFamily(entry.name)) && !isDetectedOSFont(entry.name)');
  source = once(source, 'const result = await face.load();', 'const result = await loadFontWithDeadline(face);');
  source = once(source, '        failed++;',
    '        failed++;\n        failedFontFiles.add(f.file);\n        for (let index = registeredFontFaces.length - 1; index >= 0; index--) {\n          const entry = registeredFontFaces[index];\n          if (entry.file !== f.file) continue;\n          registeredFontFaceKeys.delete(fontFaceKey(entry));\n          registeredFontFaces.splice(index, 1);\n        }\n        registerFontFaces([], options);');
  return source;
}
export function fontLoadDeadlinePlugin() {
  let visited = false;
  return {
    name: 'alhangeul-web-font-deadline', enforce: 'pre',
    transform(source, id) {
      if (!id.endsWith('/src/core/font-loader.ts')) return;
      visited = true;
      return {code: adaptFontLoader(source), map: null};
    },
    generateBundle() {
      if (!visited) throw Error('Web font deadline adapter was not included');
    },
  };
}

// 정식 pin 갱신 전의 #594 후보 빌드. 기본 build-rhwp-studio와 설치 자산은 변경하지 않는다.
if (process.argv[1] && new URL(import.meta.url).pathname === process.argv[1]) {
  const {readFileSync, writeFileSync, realpathSync, existsSync} = await import('node:fs');
  const {resolve} = await import('node:path');
  const {createRequire} = await import('node:module');
  const {pathToFileURL} = await import('node:url');
  const {createHash} = await import('node:crypto');
  const args = process.argv.slice(2);
  const arg = name => {const i = args.indexOf(name); return i >= 0 ? args[i + 1] : null;};
  const upstream = arg('--upstream-dir'), out = arg('--out-dir');
  if (!upstream || !out || !existsSync('/Volumes/T7') || !realpathSync(resolve(out, '..')).startsWith('/Volumes/T7/')) {
    throw Error('Usage: node scripts/studio-font-load-adapter.mjs --upstream-dir DIR --out-dir T7_EXISTING_PARENT/DIR');
  }
  const studio = resolve(upstream, 'rhwp-studio');
  const require = createRequire(resolve(studio, 'package.json'));
  const {build} = await import(pathToFileURL(require.resolve('vite')));
  const original = readFileSync(resolve(studio, 'src/core/font-loader.ts'), 'utf8');
  const sha = text => createHash('sha256').update(text).digest('hex');
  await build({root: studio, configFile: resolve(studio, 'vite.config.ts'), base: './',
    plugins: [fontLoadDeadlinePlugin()], build: {outDir: resolve(out)}});
  writeFileSync(resolve(out, 'alhangeul-font-load-deadline.json'), JSON.stringify({
    schema: 1, timeoutMs: 5000, originalSHA256: sha(original), adaptedSHA256: sha(adaptFontLoader(original)),
  }, null, 2) + '\n');
}
