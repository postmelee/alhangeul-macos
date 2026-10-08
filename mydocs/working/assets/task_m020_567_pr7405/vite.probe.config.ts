import original from './vite.config';
export default {...original, plugins: [], base: './', build: {outDir:'../probe-dist', rollupOptions:{input:'probe.html'}}};
