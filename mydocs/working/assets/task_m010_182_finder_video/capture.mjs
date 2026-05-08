import { spawn } from "node:child_process";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const width = 1440;
const height = 810;
const captureScale = 2;
const fps = 30;
const frameCount = 104;
const durationSeconds = frameCount / fps;
const outputDir = process.argv[2] || "/private/tmp/task182-finder-frames";
const htmlPath = path.join(__dirname, "index.html");
const chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const debugPort = Number(process.env.TASK182_CDP_PORT) || 42182;
const profileDir = `/private/tmp/task182-chrome-${debugPort}`;

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const waitForProcessExit = (process, timeoutMs = 1500) => new Promise((resolve) => {
  let settled = false;
  const finish = () => {
    if (settled) return;
    settled = true;
    resolve();
  };

  process.once("exit", finish);
  setTimeout(finish, timeoutMs);
});

const fetchJsonWithRetry = async (url, attempts = 80) => {
  let lastError;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await fetch(url);
      if (response.ok) return response.json();
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }

    await delay(100);
  }

  throw lastError;
};

const connect = (webSocketUrl) => new Promise((resolve, reject) => {
  const socket = new WebSocket(webSocketUrl);
  const pending = new Map();
  const eventWaiters = [];
  let nextId = 1;

  socket.addEventListener("open", () => {
    const send = (method, params = {}, sessionId = undefined) => {
      const id = nextId;
      nextId += 1;
      const payload = { id, method, params };
      if (sessionId) payload.sessionId = sessionId;

      return new Promise((methodResolve, methodReject) => {
        pending.set(id, { resolve: methodResolve, reject: methodReject });
        socket.send(JSON.stringify(payload));
      });
    };

    const waitForEvent = (method, sessionId = undefined) => new Promise((eventResolve) => {
      eventWaiters.push({ method, sessionId, resolve: eventResolve });
    });

    resolve({ socket, send, waitForEvent });
  });

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);

    if (message.id && pending.has(message.id)) {
      const { resolve: methodResolve, reject: methodReject } = pending.get(message.id);
      pending.delete(message.id);

      if (message.error) {
        methodReject(new Error(message.error.message));
      } else {
        methodResolve(message.result || {});
      }

      return;
    }

    for (let index = 0; index < eventWaiters.length; index += 1) {
      const waiter = eventWaiters[index];
      if (waiter.method !== message.method) continue;
      if (waiter.sessionId && waiter.sessionId !== message.sessionId) continue;

      eventWaiters.splice(index, 1);
      waiter.resolve(message.params || {});
      break;
    }
  });

  socket.addEventListener("error", reject);
});

await rm(outputDir, { recursive: true, force: true });
await mkdir(outputDir, { recursive: true });

const chrome = spawn(chromePath, [
  "--headless=new",
  "--disable-gpu",
  "--hide-scrollbars",
  "--no-first-run",
  "--no-default-browser-check",
  `--force-device-scale-factor=${captureScale}`,
  `--window-size=${width},${height}`,
  `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=${profileDir}`,
  "about:blank",
], {
  stdio: "ignore",
});

try {
  const version = await fetchJsonWithRetry(`http://127.0.0.1:${debugPort}/json/version`);
  const { socket, send, waitForEvent } = await connect(version.webSocketDebuggerUrl);
  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
  const cdp = (method, params = {}) => send(method, params, sessionId);

  await cdp("Page.enable");
  await cdp("Runtime.enable");
  await cdp("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: captureScale,
    mobile: false,
    screenWidth: width,
    screenHeight: height,
  });

  const loadEvent = waitForEvent("Page.loadEventFired", sessionId);
  await cdp("Page.navigate", { url: `file://${htmlPath}` });
  await loadEvent;
  await cdp("Runtime.evaluate", { expression: "document.fonts.ready", awaitPromise: true });

  for (let frame = 0; frame < frameCount; frame += 1) {
    const progress = frame / (frameCount - 1);
    await cdp("Runtime.evaluate", {
      expression: `window.setProgress(${progress});`,
      awaitPromise: false,
    });
    const screenshot = await cdp("Page.captureScreenshot", {
      format: "png",
      fromSurface: true,
      captureBeyondViewport: false,
    });
    const frameName = `frame_${String(frame + 1).padStart(4, "0")}.png`;
    await writeFile(path.join(outputDir, frameName), Buffer.from(screenshot.data, "base64"));
  }

  socket.close();
} finally {
  chrome.kill("SIGTERM");
  await waitForProcessExit(chrome);
  await rm(profileDir, { recursive: true, force: true }).catch(() => {});
}

console.log(`Captured ${frameCount} frames to ${outputDir}`);
