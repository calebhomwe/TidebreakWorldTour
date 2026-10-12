#!/usr/bin/env node
// Play harness for TIDEBREAK World Tour (Godot 4.7 web export).
//
// It plays the World Tour screen the way a player would: select the next unlocked stop on the TourMap,
// press START EVENT, pick a result in the EVENT TEST HARNESS dialog, repeat until SEASON PROGRESS reads
// 100%, then RESET DEMO SAVE and play another season. It runs for several episodes (one episode = one
// season), optionally under a stress mode, and writes a JSON report plus screenshots. It exits 1 when:
// a page error fires, a numeric field is NaN/undefined/out of bounds, the phase machine makes an illegal
// transition, the game is stuck (no state change for GAME.stuckAfterMs), no progression signal moved in
// an episode, restart does not return to play, or heap grows past the limit in long mode.
//
// The project has no JavaScriptBridge hook, so state is read from canvas pixels of the exported build:
//   completed   - teal fill fraction of the SEASON PROGRESS bar (right panel), quantised to 0..7 stops
//   dialog      - the WORLD TOUR title (left panel) is dimmed by the result overlay's 76% black dimmer
//   sponsorFrac - gold fill fraction of the SPONSOR PROGRESSION bar (footer)
// Positions are in the project's 1600x900 design space and mapped through the canvas_items/keep stretch
// (scale = min(W/1600, H/900), centred), so the same probes work at phone size and across resizes.
//
//   node tools/harness/play.mjs [--episodes 3] [--secs 60] [--mode default|mobile|storm|resize|blur|storage-blocked|long]
//                               [--root build/web] [--url http://127.0.0.1:8000/index.html] [--out harness-out]
//                               [--seed 7] [--fault dead-mouse|no-boot]
//
// --root is the exported Web build (mkdir -p build/web && godot --headless --path . --export-release Web build/web/index.html).
// --fault <name> injects a known break from GAME.faults to prove this harness can fail. That run MUST exit 1.
// Playwright: `npm i --no-save --no-package-lock playwright@1.56.1 && npx playwright install --with-deps chromium`,
// or the preinstalled copy at /opt/node-tools/node_modules on the build box (resolved automatically below).

import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const requireLocal = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = requireLocal('playwright')); }
catch { ({ chromium } = createRequire('/opt/node-tools/node_modules/')('playwright')); }

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..', '..');

const args = process.argv.slice(2);
const flag = (n, d) => { const i = args.indexOf(n); if (i < 0) return d; const v = args[i + 1]; args.splice(i, 2); return v; };
const EPISODES = +flag('--episodes', '3');
const MODE = flag('--mode', 'default');
let SECS = +flag('--secs', MODE === 'long' ? '180' : '120');   // a season is ~14 ticks and a tick costs 1-5 s on SwiftShader
const URL_ = flag('--url', null);
const ROOT = path.resolve(flag('--root', path.join(REPO, 'build', 'web')));
const OUT = path.resolve(flag('--out', 'harness-out'));
let seed = +flag('--seed', '7');
const FAULT = flag('--fault', null);
const DEBUG = args.includes('--debug');   // keep every tick's state in the report and echo it to stderr
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------------------------------------
// GAME: everything game-specific lives here. Documented in docs/GAME_WIKI.md.
// ---------------------------------------------------------------------------------------------
const DESIGN = { w: 1600, h: 900 };                     // project.godot display/window/size
// TourMap: map panel content rect minus MAP_PADDING (70,58) at 1600x900, measured from the booted build.
const MAP_RECT = { x: 437, y: 186, w: 706, h: 356 };
// TourStop.map_position for the seven stops in tour order (world_tour_screen.gd _create_tour_stops).
const STOPS = [
  { id: 'pipeline', pos: [0.08, 0.34] }, { id: 'trestles', pos: [0.20, 0.19] }, { id: 'snapper', pos: [0.43, 0.64] },
  { id: 'jbay', pos: [0.55, 0.27] }, { id: 'teahupoo', pos: [0.69, 0.54] }, { id: 'cloud9', pos: [0.82, 0.36] },
  { id: 'finals', pos: [0.93, 0.62] },
];
// Map stop Button sits at map_point + (-82, 24) with size 164x58 (tour_map.gd _layout_stop_buttons).
const stopButton = (i) => [MAP_RECT.x + STOPS[i].pos[0] * MAP_RECT.w, MAP_RECT.y + STOPS[i].pos[1] * MAP_RECT.h + 53];
const BTN = {
  startEvent: [1405, 699],          // right panel START EVENT / REPLAY EVENT
  resetSave: [185, 768],            // left panel RESET DEMO SAVE
  bronze: [596, 496], silver: [732, 496], gold: [868, 496], wipeout: [1004, 496], cancel: [800, 563], // result dialog
};
const REGIONS = {
  title: { x: 60, y: 185, w: 230, h: 40 },         // "WORLD TOUR" label, white: dimmed when the result overlay is up
  progress: { x: 1272, y: 199, w: 266, h: 6 },     // SEASON PROGRESS ProgressBar, teal fill
  sponsor: { x: 362, y: 862, w: 760, h: 6 },       // SPONSOR PROGRESSION ProgressBar, gold fill
};

const GAME = {
  name: 'TIDEBREAK World Tour',
  root: ROOT,
  entry: 'index.html',
  viewport: { width: 1600, height: 900 },

  // Runs in NODE: one screenshot per tick, decoded inside the page, sampled at the regions above.
  readState: async (page) => {
    const s = await sampleRegions(page, REGIONS);
    if (!s) return { phase: 'unreadable' };
    const titleMax = s.title.max;
    if (titleMax < 30) return { phase: 'unreadable', titleMax };            // nothing drawn: engine not running
    const dialog = titleMax < 140 ? 1 : 0;                                   // dimmer is Color(0,0,0,0.76)
    const completed = Math.round(s.progress.teal * STOPS.length);
    const sponsorFrac = Math.round(s.sponsor.gold * 100) / 100;
    const phase = dialog ? 'playing' : completed >= STOPS.length ? 'over' : completed === 0 ? 'menu' : 'playing';
    return { phase, dialog, completed, sponsorFrac };
  },

  // menu = fresh season, no dialog; playing = result dialog open or 1..6 stops done; over = 7/7 done.
  transitions: { menu: ['playing'], playing: ['paused', 'over', 'menu'], paused: ['playing', 'menu'], over: ['menu', 'playing'] },

  // Must leave the game in phase 'playing' (dialog open).
  start: async (page) => {
    await waitForBoot(page);
    await act({ click: stopButton(0) }); await act({ wait: 400 });
    await act({ click: BTN.startEvent }); await act({ wait: 600 });
  },
  // From the 100% screen: RESET DEMO SAVE (back to 0%, pipeline selected) then open the dialog again.
  restart: async (page) => {
    await act({ click: BTN.resetSave }); await act({ wait: 800 });
    await act({ click: stopButton(0) }); await act({ wait: 400 });
    await act({ click: BTN.startEvent }); await act({ wait: 600 });
  },

  // Player heuristic for THIS game. The dialog offers four fixed outcomes and nothing in the game informs the
  // choice, so a player takes GOLD (strictly dominant: most XP/points, unlocks the next stop) and occasionally
  // tries the other buttons; WIPEOUT and CANCEL/ESC are exercised so the fail and cancel paths are covered.
  // Outside the dialog: select the next stop on the TourMap (the game does not advance the selection itself
  // after a result), then press START EVENT.
  policy: (state, tick, rnd, mem) => {
    if (state.dialog) {
      if (!mem.firstPickDone) { mem.firstPickDone = true; return [{ click: BTN.gold }, { wait: 350 }]; }
      const r = rnd();
      if (r < 0.60) return [{ click: BTN.gold }, { wait: 350 }];
      if (r < 0.75) return [{ click: BTN.silver }, { wait: 350 }];
      if (r < 0.88) return [{ click: BTN.bronze }, { wait: 350 }];
      if (r < 0.95) return [{ click: BTN.wipeout }, { wait: 350 }];
      return [{ key: 'Escape' }, { wait: 300 }];
    }
    const next = Math.min(state.completed, STOPS.length - 1);
    return [{ click: stopButton(next) }, { wait: 250 }, { click: BTN.startEvent }, { wait: 400 }];
  },
  touchPolicy: null,                 // clicks become taps automatically in --mode mobile
  touchMap: {},

  progression: ['completed'],        // stops completed this season: must rise within an episode
  bounded: { completed: [0, 7], sponsorFrac: [0, 1], dialog: [0, 1] },
  tickMs: 120,                       // the screenshot read itself costs 1-5 s on SwiftShader, so ticks are already slow
  stuckAfterMs: 15000,
  heapLimitMB: 60,

  // Faults rewrite a served file of the exported build so the break is real.
  faults: {
    // index.js registers the canvas "mousedown" listener; renaming the event means no click ever reaches Godot.
    'dead-mouse': async (page) => {
      await page.route('**/index.js', async (route) => {
        const body = (await (await route.fetch()).text()).replace('"mousedown"', '"mousedown-dead"');
        await route.fulfill({ body, contentType: 'text/javascript', headers: coiHeaders('text/javascript') });
      });
    },
    // index.html calls engine.startGame(...); misspelling it leaves the splash on screen forever.
    'no-boot': async (page) => {
      await page.route('**/index.html', async (route) => {
        const body = (await (await route.fetch()).text()).replace('engine.startGame(', 'engine.startGameBroken(');
        await route.fulfill({ body, contentType: 'text/html', headers: coiHeaders('text/html') });
      });
    },
  },
};
// ---------------------------------------------------------------------------------------------

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.svg': 'image/svg+xml', '.webp': 'image/webp', '.wasm': 'application/wasm', '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.wav': 'audio/wav', '.glb': 'model/gltf-binary', '.woff2': 'font/woff2', '.woff': 'font/woff', '.ttf': 'font/ttf', '.pck': 'application/octet-stream', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json' };
const coiHeaders = (type) => ({ 'Content-Type': type, 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
let server, base;
if (URL_) base = URL_;
else {
  if (!fs.existsSync(path.join(GAME.root, GAME.entry))) { console.error(`no web export at ${GAME.root}; run: mkdir -p build/web && godot --headless --path . --export-release Web build/web/index.html`); process.exit(2); }
  server = http.createServer((req, res) => {
    let f = path.join(GAME.root, decodeURIComponent(req.url.split('?')[0]));
    if (!f.startsWith(GAME.root)) { res.writeHead(403); return res.end(); }
    if (fs.existsSync(f) && fs.statSync(f).isDirectory()) f = path.join(f, 'index.html');
    if (!fs.existsSync(f)) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, coiHeaders(MIME[path.extname(f).toLowerCase()] || 'application/octet-stream'));
    fs.createReadStream(f).pipe(res);
  });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}/${GAME.entry}`;
}

let commit = 'unknown';
try { commit = execSync('git rev-parse --short HEAD', { cwd: REPO, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch {}

const report = { game: GAME.name, mode: MODE, fault: FAULT, commit, url: base, root: GAME.root, bootMs: null, episodes: [], pageErrors: [], consoleErrors: [], failedRequests: [], fps: [], heap: [], verdict: { pass: true, reasons: [] } };
const fail = (why) => { report.verdict.pass = false; if (!report.verdict.reasons.includes(why)) report.verdict.reasons.push(why); };

const mobile = MODE === 'mobile';
const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required', '--enable-precise-memory-info'] });
const ctx = await browser.newContext(mobile
  ? { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }
  : { viewport: GAME.viewport });
const page = await ctx.newPage();
page.on('pageerror', e => { report.pageErrors.push(String(e.message || e).slice(0, 300)); fail('page error'); });
page.on('console', m => { if (m.type() === 'error') report.consoleErrors.push(m.text().slice(0, 300)); });
page.on('requestfailed', r => report.failedRequests.push(r.url().replace(base, '') + ' ' + (r.failure()?.errorText || '')));
page.on('response', r => { if (r.status() >= 400) report.failedRequests.push(r.url() + ' HTTP ' + r.status()); });

if (MODE === 'storage-blocked') {
  // Godot keeps user:// (the tidebreak_world_tour.json save) in IndexedDB via IDBFS, so block that too.
  await page.addInitScript(() => {
    const boom = () => { throw new DOMException('The operation is insecure.', 'SecurityError'); };
    try { Object.defineProperty(window, 'localStorage', { get: boom }); Object.defineProperty(window, 'sessionStorage', { get: boom }); } catch {}
    try { Object.defineProperty(window, 'indexedDB', { get: () => undefined, configurable: true }); } catch {}
  });
}
if (FAULT) {
  if (!GAME.faults[FAULT]) { console.error('unknown fault', FAULT); process.exit(2); }
  await GAME.faults[FAULT](page);
}

// Design-space -> CSS pixel mapping for the current viewport (canvas_items stretch, aspect keep, centred).
function toCss([x, y]) {
  const vp = page.viewportSize();
  const s = Math.min(vp.width / DESIGN.w, vp.height / DESIGN.h);
  return [(vp.width - DESIGN.w * s) / 2 + x * s, (vp.height - DESIGN.h * s) / 2 + y * s];
}
let cdp = null;
// Minimal PNG decoder (8-bit RGB/RGBA, all five filter types) so pixels are read in Node, not on the
// game's main thread, which is busy running the engine.
function decodePng(buf) {
  let p = 8, w = 0, h = 0, colorType = 6; const idat = [];
  while (p < buf.length) {
    const len = buf.readUInt32BE(p), type = buf.toString('ascii', p + 4, p + 8), data = buf.subarray(p + 8, p + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); colorType = data[9]; }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    p += 12 + len;
  }
  const bpp = colorType === 6 ? 4 : colorType === 2 ? 3 : colorType === 4 ? 2 : 1;
  const raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * bpp, out = Buffer.alloc(w * h * bpp);
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < h; y++) {
    const ft = raw[y * (stride + 1)], row = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)), cur = out.subarray(y * stride, (y + 1) * stride);
    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? cur[i - bpp] : 0, b = prev[i], c = i >= bpp ? prev[i - bpp] : 0; let v = row[i];
      if (ft === 1) v += a; else if (ft === 2) v += b; else if (ft === 3) v += (a + b) >> 1;
      else if (ft === 4) { const pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); }
      cur[i] = v & 255;
    }
    prev = cur;
  }
  return { w, h, bpp, data: out };
}
async function screenshotPng(pg) {
  try {
    if (!cdp) cdp = await pg.context().newCDPSession(pg);
    const r = await cdp.send('Page.captureScreenshot', { format: 'png', fromSurface: true, optimizeForSpeed: true });
    return Buffer.from(r.data, 'base64');
  } catch { try { return await pg.screenshot({ type: 'png', timeout: 15000 }); } catch { return null; } }
}
async function sampleRegions(pg, regions) {
  const vp = pg.viewportSize();
  const s = Math.min(vp.width / DESIGN.w, vp.height / DESIGN.h);
  const ox = (vp.width - DESIGN.w * s) / 2, oy = (vp.height - DESIGN.h * s) / 2;
  const png = await screenshotPng(pg);
  if (!png) return null;
  const img = decodePng(png);
  // Device pixels per CSS pixel, taken from the capture itself (2 under mobile emulation, 1 on desktop).
  const dpr = img.w / vp.width;
  const out = {};
  for (const [name, r] of Object.entries(regions)) {
    const x0 = Math.round((ox + r.x * s) * dpr), y0 = Math.round((oy + r.y * s) * dpr);
    const w = Math.max(1, Math.round(r.w * s * dpr)), h = Math.max(1, Math.round(r.h * s * dpr));
    let max = 0, tealBest = 0, goldBest = 0;
    for (let row = 0; row < h; row++) {
      let teal = 0, gold = 0;
      for (let col = 0; col < w; col++) {
        const x = x0 + col, y = y0 + row;
        if (x < 0 || y < 0 || x >= img.w || y >= img.h) continue;
        const i = (y * img.w + x) * img.bpp, R = img.data[i], G = img.data[i + 1], B = img.data[i + 2];
        max = Math.max(max, R, G, B);
        // Ratio tests survive the result overlay's 76% dimmer: teal (15,214,227) dims to (4,51,54),
        // gold (245,176,38) to (59,42,9); the empty bar (20,33,38) never matches either.
        if (G > 40 && G > 3 * R && B > 3 * R) teal++;             // COLOR_TEAL (0.06,0.84,0.89)
        if (R > 40 && R > G * 1.15 && G > B * 2.5) gold++;       // COLOR_GOLD (0.96,0.69,0.15)
      }
      tealBest = Math.max(tealBest, teal / w); goldBest = Math.max(goldBest, gold / w);
    }
    out[name] = { max, teal: tealBest, gold: goldBest };
  }
  return out;
}
async function waitForBoot(pg) {
  const t0 = Date.now();
  // index.html removes #status once the engine is running; then wait for the UI to be drawn.
  await pg.waitForFunction(() => !document.getElementById('status'), null, { timeout: 120000 });
  for (let i = 0; i < 240; i++) {
    const s = await sampleRegions(pg, { title: REGIONS.title });
    if (s && s.title.max > 140) break;
    await pg.waitForTimeout(500);
  }
  report.bootMs = report.bootMs ?? (Date.now() - t0);
}

const readState = () => GAME.readState(page).catch(e => ({ phase: 'unreadable', error: String(e).slice(0, 120) }));
const fps = () => page.evaluate(ms => new Promise(res => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < ms) requestAnimationFrame(f); else res(Math.round(n * 1000 / ms)); }; requestAnimationFrame(f); setTimeout(() => res(0), ms + 2000); }), 1000).catch(() => null);
const heapMB = () => page.evaluate(() => performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : null).catch(() => null);

async function act(a) {
  try {
    if (a.wait) await page.waitForTimeout(a.wait);
    else if (a.key) { await page.keyboard.down(a.key); await page.waitForTimeout(a.hold || 80); await page.keyboard.up(a.key); }
    else if (a.click) { const [x, y] = toCss(a.click); if (mobile) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y); }
    else if (a.tap) await page.touchscreen.tap(a.tap[0], a.tap[1]);
    else if (a.drag) { await page.mouse.move(a.drag[0], a.drag[1]); await page.mouse.down(); await page.mouse.move(a.drag[2], a.drag[3], { steps: 8 }); await page.waitForTimeout(a.drag[4] || 100); await page.mouse.up(); }
    else if (a.wheel != null) await page.mouse.wheel(0, a.wheel);
  } catch {}
}
const randomAction = () => {
  const r = rnd();
  const vp = page.viewportSize();
  if (mobile || r < 0.3) return { tap: [20 + rnd() * (vp.width - 40), 20 + rnd() * (vp.height - 40)] };
  if (r < 0.6) return { key: ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Space', 'Enter', 'Escape', 'KeyP', 'KeyM', 'Tab'][Math.floor(rnd() * 10)], hold: 30 + rnd() * 100 };
  if (r < 0.85) return { click: [rnd() * DESIGN.w, rnd() * DESIGN.h] };
  return { wheel: (rnd() - 0.5) * 400 };
};

function checkState(prev, cur, ep) {
  for (const [k, v] of Object.entries(cur)) {
    if (typeof v === 'number' && !Number.isFinite(v)) { ep.invariantFailures.push(`${k} is ${v}`); fail('non-finite value'); }
    if (v === undefined) { ep.invariantFailures.push(`${k} is undefined`); fail('undefined value'); }
    const b = GAME.bounded[k];
    if (b && typeof v === 'number' && (v < b[0] || v > b[1])) { ep.invariantFailures.push(`${k}=${v} outside [${b}]`); fail('out of bounds'); }
  }
  if (!['menu', 'playing', 'paused', 'over'].includes(cur.phase)) { ep.invariantFailures.push(`unknown phase ${cur.phase}`); fail('unknown phase'); }
  if (prev && prev.phase !== cur.phase && GAME.transitions[prev.phase] && !GAME.transitions[prev.phase].includes(cur.phase)) {
    ep.invariantFailures.push(`illegal transition ${prev.phase} -> ${cur.phase}`); fail('illegal transition');
  }
}

try {
  await page.goto(base, { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(500);
  const heap0 = await heapMB(); report.heap.push({ t: 0, mb: heap0 });

  for (let e = 0; e < EPISODES; e++) {
    const ep = { index: e, startedAt: Date.now(), ticks: 0, invariantFailures: [], progression: {}, stuck: false, endPhase: null, restartOk: null, restartVia: null, states: [] };
    const mem = {};
    report.episodes.push(ep);
    try {
      if (e === 0) { await GAME.start(page); }
      else {
        // Restart into this episode. From the game's own end screen use GAME.restart; if the previous episode
        // ran out of time while still playing (no end screen), reload and start again instead.
        const before = await readState();
        if (before.phase === 'over') { await GAME.restart(page); ep.restartVia = 'restart'; }
        else { await page.reload({ waitUntil: 'load', timeout: 60000 }); await page.waitForTimeout(500); await GAME.start(page); ep.restartVia = 'reload+start'; }
        await page.waitForTimeout(500);
        let s = await readState();
        if (s.phase === 'menu') { await act({ click: BTN.startEvent }); await page.waitForTimeout(600); s = await readState(); }
        ep.restartOk = s.phase === 'playing';
        if (!ep.restartOk) { ep.invariantFailures.push(`restart did not reach playing (phase=${s.phase}, via ${ep.restartVia})`); fail('restart did not work'); }
      }
    } catch (err) { ep.invariantFailures.push('start/restart failed: ' + String(err.message).slice(0, 120)); fail(e === 0 ? 'could not start' : 'restart did not work'); }
    await page.waitForTimeout(300);
    let prev = null, lastChange = Date.now(), lastKey = '';
    const t0 = Date.now();
    let tick = 0, nextFps = 10000, nextStress = 5000;
    while (Date.now() - t0 < SECS * 1000) {
      const cur = await readState();
      checkState(prev, cur, ep);
      const key = JSON.stringify(cur);
      if (key !== lastKey) { lastKey = key; lastChange = Date.now(); }
      if ((cur.phase === 'playing' || cur.phase === 'menu') && Date.now() - lastChange > GAME.stuckAfterMs) { ep.stuck = true; fail('stuck while playing'); break; }
      for (const s of GAME.progression) if (typeof cur[s] === 'number') { const p = ep.progression[s] || (ep.progression[s] = { first: cur[s], max: cur[s], last: cur[s] }); p.max = Math.max(p.max, cur[s]); p.last = cur[s]; }
      if (DEBUG) { ep.states.push({ t: Date.now() - t0, ...cur }); console.error(`t=${Date.now() - t0} ${JSON.stringify(cur)}`); }
      else if (tick % 10 === 0) ep.states.push({ t: Date.now() - t0, ...cur });
      if (cur.phase === 'over') break;
      if (e === 0 && tick === 15 && cur.phase !== 'playing') { ep.invariantFailures.push(`not playing after start (phase=${cur.phase})`); fail('start did not reach playing'); }

      let actions = (cur.phase === 'playing' || cur.phase === 'menu') ? (GAME.policy(cur, tick, rnd, mem) || []) : [{ key: 'Enter' }, { click: [DESIGN.w / 2, DESIGN.h / 2] }];
      if (mobile && GAME.touchPolicy) actions = GAME.touchPolicy(cur, tick, rnd, mem) || [];
      if (MODE === 'storm') actions = actions.concat([randomAction(), randomAction()]);
      for (const a of actions) await act(a);

      const now = Date.now() - t0;
      if (now > nextStress) {
        nextStress += 5000;
        if (MODE === 'resize') { const small = (nextStress / 5000) % 2 === 0; await page.setViewportSize(small ? { width: 390, height: 844 } : GAME.viewport).catch(() => {}); await page.waitForTimeout(400); }
        if (MODE === 'blur') await page.evaluate(() => { window.dispatchEvent(new Event('blur')); document.dispatchEvent(new Event('visibilitychange')); setTimeout(() => { window.dispatchEvent(new Event('focus')); document.dispatchEvent(new Event('visibilitychange')); }, 400); }).catch(() => {});
      }
      if (now > nextFps) { nextFps += 10000; report.fps.push({ t: now, fps: await fps(), episode: e }); if (MODE === 'long') report.heap.push({ t: now, mb: await heapMB() }); }
      prev = cur; tick++; ep.ticks = tick;
      await page.waitForTimeout(GAME.tickMs);
    }
    const final = await readState();
    ep.endPhase = final.phase; ep.final = final; ep.durationMs = Date.now() - t0;
    if (!DEBUG) delete ep.states; // keep the report small; --debug keeps every tick
    const moved = GAME.progression.some(s => ep.progression[s] && ep.progression[s].max > ep.progression[s].first);
    if (!moved) { ep.invariantFailures.push('no progression signal moved: ' + GAME.progression.join(',')); fail('no progression'); }
    await page.screenshot({ path: path.join(OUT, `${MODE}-ep${e}-end.png`) }).catch(() => {});
  }
  if (MODE === 'long') {
    const mbs = report.heap.map(h => h.mb).filter(x => x != null);
    if (mbs.length > 2 && mbs[mbs.length - 1] - Math.min(...mbs.slice(0, 2)) > GAME.heapLimitMB) fail(`heap grew more than ${GAME.heapLimitMB} MB`);
  }
} catch (err) {
  report.pageErrors.push('HARNESS: ' + String(err.message || err).slice(0, 300)); fail('harness exception');
}

await browser.close(); server?.close();
report.finishedAt = new Date().toISOString();
const outFile = path.join(OUT, `report-${MODE}${FAULT ? '-fault-' + FAULT : ''}.json`);
fs.writeFileSync(outFile, JSON.stringify(report, null, 2));
const summary = report.episodes.map(e => `ep${e.index}: ${e.endPhase} ${Math.round((e.durationMs || 0) / 1000)}s ` + Object.entries(e.progression).map(([k, v]) => `${k} ${v.first}->${v.max}`).join(' ') + (e.restartVia ? ` restart=${e.restartVia}` : '') + (e.invariantFailures.length ? ' FAIL ' + e.invariantFailures.join('; ') : '')).join('\n');
console.log(`${GAME.name} [${MODE}${FAULT ? ' fault=' + FAULT : ''}] ${report.verdict.pass ? 'PASS' : 'FAIL'} ${report.verdict.reasons.join(', ')}\nboot ${report.bootMs} ms, fps ${report.fps.map(f => f.fps).join('/') || 'n/a'}, errors ${report.pageErrors.length}\n${summary}\nreport: ${outFile}`);
process.exit(report.verdict.pass ? 0 : 1);
