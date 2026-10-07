// 앱 소유 목록 연결. upstream 파일·renderer·편집 명령은 수정하지 않는다.
export const receiptName = 'alhangeul-font-menu-adapter.json';
export const buildCommand = 'node scripts/build-rhwp-studio.mjs --upstream-dir <checkout>';
export const sourcePaths = ['src/core/local-fonts.ts', 'src/ui/toolbar.ts'];

function replaceOnce(source, before, after, label) {
  if (source.split(before).length !== 2) throw Error(`Studio font menu adapter drift: ${label}`);
  return source.replace(before, after);
}

export function adaptSource(source, path) {
  if (path === sourcePaths[0]) {
    return replaceOnce(source,
      'export function getLocalFonts(options: GetLocalFontsOptions = {}): string[] {\n',
      `export function getLocalFonts(options: GetLocalFontsOptions = {}): string[] {
  // 알한글: 메뉴는 공급 가능한 family를 표시하고 style 선택은 기존 renderer에 맡긴다.
  if (hasHostFontProvider()) {
    return normalizeFamilies(currentHostRecords().map(record => record.family));
  }
`, path);
  }
  if (path === sourcePaths[1]) {
    source = replaceOnce(source,
      "import { getLocalFonts } from '@/core/local-fonts';",
      "import { getLocalFonts, onHostFontsChanged, prepareHostFontCatalog, getHostFontState } from '@/core/local-fonts';", path);
    return replaceOnce(source,
      "    eventBus.on('local-fonts-changed', () => {\n      this.refreshFontDropdown();\n    });",
      `    eventBus.on('local-fonts-changed', () => {
      this.refreshFontDropdown();
    });
    onHostFontsChanged(() => {
      // 이전 snapshot의 선택 항목은 즉시 폐기한다. 문서 선택값은 유지한다.
      this.closeFontMenu();
      const generation = getHostFontState().generation;
      void prepareHostFontCatalog().then(() => {
        if (getHostFontState().generation === generation && this.fontMenu) {
          this.renderFontMenu(this.fontMenu);
        }
      });
    });`, path);
  }
  throw Error(`Unexpected Studio adapter source: ${path}`);
}

export function fontMenuPlugin(sources, receipt) {
  const visited = new Set();
  return {
    name: 'alhangeul-host-font-menu', enforce: 'pre',
    transform(source, id) {
      const input = sources.find(row => row.absolute === id);
      if (!input) return;
      if (source !== input.original) throw Error(`Studio font menu source changed during build: ${input.path}`);
      visited.add(input.path);
      return {code: input.adapted, map: null};
    },
    generateBundle() {
      if (sourcePaths.some(path => !visited.has(path))) throw Error('Studio font menu adapter was not included');
      this.emitFile({type: 'asset', fileName: receiptName, source: JSON.stringify(receipt, null, 2) + '\n'});
    },
  };
}
