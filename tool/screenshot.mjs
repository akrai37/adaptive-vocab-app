// Drives headless Chrome to screenshot the web build, for checking screens.
//
// Usage: node tool/screenshot.mjs <url> <out.png> <waitMs> [step ...]
//   step: "x,y" click · "type:text" type · "wait:ms" pause
//   EACH=1 also saves <out>-N.png after every step.
import { spawn } from 'node:child_process';
import { writeFileSync, rmSync } from 'node:fs';

const [url, out, waitMs = '9000', ...steps] = process.argv.slice(2);
const profile = out + '.profile';
rmSync(profile, { recursive: true, force: true });
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new', '--remote-debugging-port=9333', '--window-size=1280,800',
  `--user-data-dir=${profile}`, 'about:blank']);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let targets;
for (let i = 0; i < 40 && !targets; i++) {
  await sleep(500);
  try { targets = await (await fetch('http://127.0.0.1:9333/json')).json(); } catch {}
}
const ws = new WebSocket(targets.find((t) => t.type === 'page').webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = {};
const send = (method, params = {}) => new Promise((r) => {
  pending[++id] = r;
  ws.send(JSON.stringify({ id, method, params }));
});
ws.onmessage = (m) => {
  const d = JSON.parse(m.data);
  if (d.id && pending[d.id]) pending[d.id](d.result);
  if (d.method === 'Runtime.exceptionThrown') {
    console.log('exception:', JSON.stringify(d.params.exceptionDetails).slice(0, 400));
  }
};
const snap = async (file) => {
  const s = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(file, Buffer.from(s.data, 'base64'));
};

await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride',
  { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url });
await sleep(+waitMs);

let n = 0;
for (const step of steps) {
  if (step.startsWith('type:')) {
    for (const ch of step.slice(5)) await send('Input.dispatchKeyEvent', { type: 'char', text: ch });
    await sleep(500);
  } else if (step.startsWith('wait:')) {
    await sleep(+step.slice(5));
  } else {
    const [x, y] = step.split(',').map(Number);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
    }
    await sleep(1500);
  }
  if (process.env.EACH) await snap(out.replace(/\.png$/, `-${++n}.png`));
}
await snap(out);
chrome.kill();
await sleep(500);
try { rmSync(profile, { recursive: true, force: true }); } catch {} // Chrome may still hold files
process.exit(0);
