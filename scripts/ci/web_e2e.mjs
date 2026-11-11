// End-to-end check of the BUILT web app in headless Chrome (CI: .github/workflows/web_e2e.yml).
//
//   node scripts/ci/web_e2e.mjs
//
// Environment (all optional):
//   BASE_URL     where build/web is served          (default http://127.0.0.1:8787/)
//   STREAM_URL   scripts/ci/loop_stream.py base     (default http://127.0.0.1:8099)
//   OUT_DIR      results, console log, summary      (default web-e2e-out)
//   CHROME_BIN   Chrome/Chromium executable         (default: the installed "chrome" channel)
//
// Flutter web draws to a canvas, so the page is driven through its accessibility tree: the
// "Enable accessibility" placeholder is activated and every control is found by its
// accessible name (role + name), never by coordinates. Output is silenced by a page hook
// (every context's destination goes through a gain-0 node, <audio> elements are muted), and
// the same hook records the Web Audio calls the app makes.
//
// Checks marked `info` are reported, never blocking (the built-in station needs the internet).
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const BASE = (process.env.BASE_URL || 'http://127.0.0.1:8787/').replace(/\/?$/, '/');
const STREAM = (process.env.STREAM_URL || 'http://127.0.0.1:8099').replace(/\/$/, '');
const OUT = process.env.OUT_DIR || 'web-e2e-out';
const LEVELS = JSON.parse(fs.readFileSync(path.join(HERE, '..', 'sounds', 'levels.json'), 'utf8'));
const MANIFEST_BIN_JSON = 'assets/AssetManifest.bin.json';

// The ten sounds started together (the 2026-11-10 W5 set). Named, never counted: the number of
// cards changes as sounds are added.
const TEN = ['Light Rain', 'Birds', 'Wind', 'Cafe', 'River', 'Library', 'Office', 'Train', 'Keyboard', 'Clock'];

// Fail closed: a run that executed fewer blocking checks than this (a check removed, the script
// ended early) must not go green. Raise it when a blocking check is added.
const MIN_BLOCKING = 16;

fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------- results

const results = [];
let passedBlocking = 0;
async function check(id, name, fn, { blocking = true } = {}) {
  const t0 = Date.now();
  let status = 'pass';
  let detail = '';
  try {
    detail = (await fn()) || '';
  } catch (e) {
    status = blocking ? 'fail' : 'info';
    detail = String(e && e.message ? e.message : e).split('\n')[0];
  }
  if (status === 'pass' && !blocking) status = 'info';
  if (status === 'pass') passedBlocking++;
  const r = { id, name, status, blocking, ms: Date.now() - t0, detail };
  results.push(r);
  console.log(`${status.toUpperCase().padEnd(4)} ${id} ${name}${detail ? ' - ' + detail : ''}`);
  return status !== 'fail';
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, ms, what) {
  const end = Date.now() + ms;
  let last;
  while (Date.now() < end) {
    try {
      last = await fn();
      if (last) return last;
    } catch (e) {
      last = e;
    }
    await sleep(100);
  }
  throw new Error(`timed out after ${ms} ms: ${what}`);
}
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// ---------------------------------------------------------------- page hook

// Runs before any page script. Records Web Audio activity on window.__e2e and mutes the output.
function installHook() {
  const W = (window.__e2e = { contexts: [], sources: [], media: [], stopCalls: 0 });

  const NativeAC = window.AudioContext;
  window.AudioContext = class extends NativeAC {
    constructor(...a) {
      super(...a);
      W.contexts.push(this);
    }
  };

  // Mute: anything connected to a live destination goes through a gain-0 node instead.
  const origConnect = AudioNode.prototype.connect;
  const mutes = new WeakMap();
  AudioNode.prototype.connect = function (dest, ...rest) {
    if (typeof AudioDestinationNode !== 'undefined' && dest instanceof AudioDestinationNode &&
        !(dest.context instanceof OfflineAudioContext)) {
      const ctx = dest.context;
      let m = mutes.get(ctx);
      if (!m) {
        m = ctx.createGain();
        m.gain.value = 0;
        origConnect.call(m, ctx.destination);
        mutes.set(ctx, m);
      }
      origConnect.call(this, m, ...rest);
      return dest;
    }
    return origConnect.call(this, dest, ...rest);
  };

  const origStart = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function (...a) {
    const rec = {
      loop: this.loop,
      loopStart: this.loopStart,
      loopEnd: this.loopEnd,
      duration: this.buffer ? this.buffer.duration : null,
      ctxState: this.context.state,
      stopped: false,
      ended: false,
    };
    this.addEventListener('ended', () => { rec.ended = true; });
    W.sources.push(rec);
    this.__rec = rec;
    return origStart.apply(this, a);
  };
  const origStop = AudioBufferSourceNode.prototype.stop;
  AudioBufferSourceNode.prototype.stop = function (...a) {
    W.stopCalls++;
    if (this.__rec) this.__rec.stopped = true;
    return origStop.apply(this, a);
  };

  // Radio: just_audio keeps a detached <audio>; mute it before play() and remember it.
  const origPlay = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function (...a) {
    this.muted = true;
    if (!W.media.includes(this)) W.media.push(this);
    return origPlay.apply(this, a);
  };
}

// ---------------------------------------------------------------- main

const browser = await chromium.launch({
  headless: true,
  ...(process.env.CHROME_BIN ? { executablePath: process.env.CHROME_BIN } : { channel: 'chrome' }),
  args: ['--autoplay-policy=no-user-gesture-required', '--mute-audio'],
});
const context = await browser.newContext({
  locale: 'en-US', // card and button names below are the English ones
  viewport: { width: 1280, height: 2600 }, // tall: every category fits, no scrolling needed
});
await context.addInitScript(installHook);

const consoleLines = [];
const pageErrors = [];
function watch(page) {
  page.on('console', (m) => consoleLines.push({ t: Date.now(), type: m.type(), text: m.text() }));
  page.on('pageerror', (e) => pageErrors.push(String(e && e.message ? e.message : e)));
}

// ------------------------------------------------------------ W1: every bundled sound decodes
{
  const page = await context.newPage();
  watch(page);
  await page.goto(BASE + 'manifest.json');

  let paths = [];
  await check('W1.1', 'manifest lists the bundled sounds and matches levels.json', async () => {
    const b64 = await page.evaluate(async (u) => JSON.parse(await (await fetch(u)).text()), BASE + MANIFEST_BIN_JSON);
    const text = Buffer.from(b64, 'base64').toString('latin1');
    paths = [...new Set(text.match(/assets\/sounds\/[A-Za-z0-9_\-/]+\.ogg/g) || [])].sort();
    const expected = LEVELS.sounds.map((s) => 'assets/sounds/' + s.path).sort();
    if (paths.length !== expected.length) throw new Error(`manifest has ${paths.length}, levels.json ${expected.length}`);
    if (JSON.stringify(paths) !== JSON.stringify(expected)) throw new Error('manifest and levels.json differ');
    if (!paths.includes('assets/sounds/nature/walk-on-gravel.ogg')) throw new Error('walk-on-gravel missing');
    return `${paths.length} sounds`;
  });

  const byPath = new Map(LEVELS.sounds.map((s) => ['assets/sounds/' + s.path, s]));
  const items = paths.map((p) => ({ url: BASE + 'assets/' + p, path: p, ...pick(byPath.get(p) || {}) }));
  function pick(s) { return { N: s.N, channels: s.channels, bytes: s.bytes, rate: s.rate }; }

  let w1 = null;
  await check('W1.2', 'every sound is served with the bytes levels.json pins', async () => {
    if (!items.length) throw new Error('nothing to fetch');
    w1 = await page.evaluate(async (items) => {
      const out = [];
      for (const it of items) {
        const r = await fetch(it.url);
        const buf = await r.arrayBuffer();
        // Offline: no output device, nothing audible. One frame is enough, the decoded
        // buffer keeps its own length.
        let dec = null, err = null;
        try {
          dec = await new OfflineAudioContext(1, 1, 44100).decodeAudioData(buf.slice(0));
        } catch (e) { err = String(e); }
        let bad = 0;
        if (dec) {
          for (let c = 0; c < dec.numberOfChannels; c++) {
            const d = dec.getChannelData(c);
            for (let i = 0; i < d.length; i++) if (!Number.isFinite(d[i])) bad++;
          }
        }
        out.push({
          path: it.path, status: r.status, bytes: buf.byteLength, err,
          length: dec && dec.length, channels: dec && dec.numberOfChannels,
          rate: dec && dec.sampleRate, nonFinite: bad,
        });
      }
      return out;
    }, items);
    const wrong = w1.filter((r, i) => r.status !== 200 || r.bytes !== items[i].bytes);
    if (wrong.length) throw new Error(`${wrong.length} wrong: ${wrong.slice(0, 3).map((r) => `${r.path} status ${r.status} bytes ${r.bytes}`).join('; ')}`);
    return `${w1.length} files, ${w1.reduce((a, r) => a + r.bytes, 0)} bytes`;
  });
  await check('W1.3', 'every sound decodes at 44100 Hz with the exact length and channels', async () => {
    if (!w1) throw new Error('no fetch results');
    const wrong = w1.filter((r, i) => r.err || r.length !== items[i].N || r.channels !== items[i].channels || r.rate !== 44100);
    if (wrong.length) throw new Error(`${wrong.length} wrong: ${wrong.slice(0, 3).map((r, i) => `${r.path} ${r.err || `len ${r.length} ch ${r.channels} rate ${r.rate}`}`).join('; ')}`);
    return `${w1.length}/${w1.length}`;
  });
  await check('W1.4', 'no decoded sample is NaN or infinite', async () => {
    if (!w1) throw new Error('no fetch results');
    const wrong = w1.filter((r) => r.nonFinite !== 0);
    if (wrong.length) throw new Error(`${wrong.length} files: ${wrong.slice(0, 3).map((r) => r.path).join(', ')}`);
    return 'all samples finite';
  });
  await page.close();
}

// ------------------------------------------------------------ the app
const page = await context.newPage();
watch(page);
await page.goto(BASE);

// The card's label is a pointer-events:none span inside the tappable semantics node, which is
// what receives the click.
const card = (name) => page
  .locator('flt-semantics[flt-tappable]')
  .filter({ has: page.getByText(new RegExp(`(^|\\s)${esc(name)}$`)) })
  .first();
const hook = () => page.evaluate(() => {
  const W = window.__e2e;
  return {
    sources: W.sources.map((s) => ({ ...s })),
    contexts: W.contexts.map((c) => c.state),
    stopCalls: W.stopCalls,
  };
});
const media = () => page.evaluate(() => {
  const W = window.__e2e;
  const el = W.media[W.media.length - 1];
  return el ? { n: W.media.length, paused: el.paused, t: el.currentTime, err: el.error ? el.error.code : null, src: el.currentSrc || el.src } : null;
});
// The handler logs every controller's status on each change, e.g.
// "[WH] _onCtrlChanged: [Light Rain:playing, CI Dead:error] allStopped=false". That is the app's own
// state for a station (the per-controller "status:" lines miss some transitions, such as the web
// stream's stall recovery and a failed load). Consecutive repeats are collapsed.
const SNAP = '[WH] _onCtrlChanged: [';
const status = (name) => {
  const out = [];
  for (const { text } of consoleLines) {
    if (!text.startsWith(SNAP)) continue;
    for (const part of text.slice(SNAP.length, text.lastIndexOf('] allStopped')).split(', ')) {
      const i = part.lastIndexOf(':');
      if (part.slice(0, i) === name && out[out.length - 1] !== part.slice(i + 1)) out.push(part.slice(i + 1));
    }
  }
  return out;
};
const lastStatus = (name) => status(name).pop();

let booted = false;
await check('F1', 'app boots, accessibility enabled, Sounds tab shows the cards', async () => {
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 });
  // The placeholder sits off screen on purpose; activating it turns the semantics tree on.
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  await page.getByRole('tab', { name: 'Sounds' }).click({ timeout: 30000 });
  await card('Light Rain').waitFor({ timeout: 15000 });
  await card('Yumi Co. Radio').waitFor({ timeout: 15000 });
  booted = true;
  return 'semantics on, Light Rain and Yumi Co. Radio found by name';
});

let started = [];
await check('F2', 'ten sounds start: ten looping sources, loopEnd == buffer duration', async () => {
  if (!booted) throw new Error('app did not boot');
  for (let i = 0; i < TEN.length; i++) {
    await card(TEN[i]).click({ timeout: 10000 });
    await until(async () => (await hook()).sources.length >= i + 1, 15000, `${TEN[i]} started a source`);
  }
  await sleep(500);
  started = (await hook()).sources;
  if (started.length !== TEN.length) throw new Error(`${started.length} sources started, expected ${TEN.length}`);
  const bad = started.filter((s) => s.loop !== true || s.loopStart !== 0 || !(s.duration > 0) || s.loopEnd !== s.duration);
  if (bad.length) throw new Error(`${bad.length} not looping to the buffer end: ${JSON.stringify(bad[0])}`);
  return `${started.length} sources, durations ${started.map((s) => s.duration.toFixed(1)).join(' ')}`;
});
await check('F3', 'every audio context is running', async () => {
  const h = await hook();
  if (h.contexts.length < TEN.length) throw new Error(`${h.contexts.length} contexts, expected at least ${TEN.length}`);
  const notRunning = h.contexts.filter((s) => s !== 'running');
  if (notRunning.length) throw new Error(`states: ${h.contexts.join(',')}`);
  return `${h.contexts.length} running`;
});
await check('F4', 'no page error while the sounds start', async () => {
  if (pageErrors.length) throw new Error(pageErrors[0]);
  return 'none';
});

await check('F5', 'Stop All stops every source', async () => {
  if (!started.length) throw new Error('no sources were started');
  await page.getByRole('button', { name: 'Stop All' }).first().click({ timeout: 10000 });
  await until(async () => (await hook()).sources.every((s) => s.ended), 10000, 'every source ended');
  const h = await hook();
  const notStopped = h.sources.filter((s) => !s.stopped || !s.ended);
  if (notStopped.length) throw new Error(`${notStopped.length} sources not stopped`);
  if (h.stopCalls !== h.sources.length) throw new Error(`${h.stopCalls} stop() calls for ${h.sources.length} sources`);
  return `${h.stopCalls} stop() calls == ${h.sources.length} started, all ended`;
});

// ------------------------------------------------------------ radio
const streamUrl = STREAM + '/stream';
const deadUrl = STREAM + '/dead';
async function addStation(name, url) {
  const step = async (what, fn) => {
    try { await fn(); } catch (e) { throw new Error(`add "${name}": ${what}: ${String(e.message).split('\n')[0]}`); }
  };
  await step('open the add page', () => page.getByRole('button', { name: 'Add radio station' }).click({ timeout: 10000 }));
  await step('URL tab', () => page.getByRole('tab', { name: /URL/ }).click({ timeout: 10000 }));
  await step('fill the stream URL', () => page.getByRole('textbox', { name: /Stream URL/ }).fill(url, { timeout: 10000 }));
  await step('fill the name', () => page.getByRole('textbox', { name: /Station name/ }).fill(name, { timeout: 10000 }));
  await step('press Add Station', () => page.getByRole('button', { name: 'Add Station' }).click({ timeout: 10000 }));
  await step('confirmation', () => page.getByText(`Added "${name}"`).first().waitFor({ timeout: 10000 }));
  await step('back to the list', () => page.getByRole('button', { name: /^Back/ }).click({ timeout: 10000 }));
  await step('card in the list', () => card(name).waitFor({ timeout: 10000 }));
}
let added = false;
await check('R0', 'two custom stations (live stream, dead URL) added through the app', async () => {
  if (!booted) throw new Error('app did not boot');
  await addStation('CI Stream', streamUrl);
  await addStation('CI Dead', deadUrl);
  added = true;
  return `${streamUrl} and ${deadUrl}`;
});

async function advancing(label, ms = 2000, min = 1.5) {
  const a = await media();
  if (!a) throw new Error(`${label}: no <audio> element`);
  await sleep(ms);
  const b = await media();
  const d = b.t - a.t;
  if (!(d >= min)) throw new Error(`${label}: currentTime moved ${d.toFixed(2)} s in ${ms} ms (need >= ${min})`);
  return d;
}
async function frozen(label) {
  const a = await media();
  await sleep(1500);
  const b = await media();
  const d = Math.abs(b.t - a.t);
  if (!(b.paused && d < 0.1)) throw new Error(`${label}: paused=${b.paused}, currentTime moved ${d.toFixed(2)} s`);
  return d;
}

let playing = false;
await check('R1', 'custom station plays: status playing and <audio> currentTime advances', async () => {
  if (!added) throw new Error('station not added');
  await card('CI Stream').click({ timeout: 10000 });
  await until(() => lastStatus('CI Stream') === 'playing', 20000, `CI Stream status playing (last: ${lastStatus('CI Stream')})`);
  const d = await advancing('play');
  const m = await media();
  if (!m.src.endsWith('/stream')) throw new Error(`the <audio> element plays ${m.src}, not the local stream`);
  playing = true;
  return `status ${status('CI Stream').join(' > ')}; +${d.toFixed(2)} s in 2 s`;
});
await check('R2', 'pause freezes the stream', async () => {
  if (!playing) throw new Error('not playing');
  await page.getByRole('button', { name: 'Pause All' }).first().click({ timeout: 10000 });
  const d = await frozen('pause');
  return `paused, moved ${d.toFixed(2)} s in 1.5 s`;
});
await check('R3', 'resume plays again, currentTime advances', async () => {
  if (!playing) throw new Error('not playing');
  await page.getByRole('button', { name: 'Resume All' }).first().click({ timeout: 10000 });
  await until(() => lastStatus('CI Stream') === 'playing', 15000, `status playing after resume (last: ${lastStatus('CI Stream')})`);
  await until(async () => { const m = await media(); return m && !m.paused; }, 10000, '<audio> not paused');
  const d = await advancing('resume');
  return `+${d.toFixed(2)} s in 2 s, status ${lastStatus('CI Stream')}`;
});
await check('R4', 'stop pauses the element and clears the status', async () => {
  if (!playing) throw new Error('not playing');
  await page.getByRole('button', { name: 'Stop All' }).first().click({ timeout: 10000 });
  await until(() => lastStatus('CI Stream') === 'notInitialized', 10000, `status notInitialized (last: ${lastStatus('CI Stream')})`);
  const d = await frozen('stop');
  return `status ${lastStatus('CI Stream')}, element paused, moved ${d.toFixed(2)} s`;
});
await check('R5', 'a dead URL ends in error, not stuck on loading', async () => {
  if (!added) throw new Error('station not added');
  await card('CI Dead').click({ timeout: 10000 });
  await until(() => status('CI Dead').includes('error'), 20000, `CI Dead status error (seen: ${status('CI Dead').join(' > ') || 'none'})`);
  return `status ${status('CI Dead').join(' > ')}`;
});
// Leave the dead one in whatever state it is: the app is closed at the end.
await page.getByRole('button', { name: 'Stop All' }).first().click({ timeout: 5000 }).catch(() => {});

await check('R6', 'built-in Yumi Co. Radio (internet, not blocking)', async () => {
  await card('Yumi Co. Radio').click({ timeout: 10000 });
  await until(() => lastStatus('Yumi Co. Radio') === 'playing', 20000, `Yumi status playing (last: ${lastStatus('Yumi Co. Radio')})`);
  const d = await advancing('yumi');
  return `playing, +${d.toFixed(2)} s in 2 s`;
}, { blocking: false });
await page.getByRole('button', { name: 'Stop All' }).first().click({ timeout: 5000 }).catch(() => {});

await check('F6', 'no page error during the whole run', async () => {
  if (pageErrors.length) throw new Error(`${pageErrors.length}: ${pageErrors[0]}`);
  return 'none';
});

// ------------------------------------------------------------ report
await browser.close();

const failed = results.filter((r) => r.status === 'fail');
const expectedMin = results.filter((r) => r.blocking).length; // every blocking check must have run and passed
fs.writeFileSync(path.join(OUT, 'console.log'), consoleLines.map((l) => `${new Date(l.t).toISOString()} ${l.type} ${l.text}`).join('\n') + '\n');
fs.writeFileSync(path.join(OUT, 'results.json'), JSON.stringify({ passedBlocking, failed: failed.length, expectedMin, results }, null, 2));
const md = [
  '### Web e2e (built app, headless Chrome)',
  '',
  '| | check | result |',
  '|---|---|---|',
  ...results.map((r) => `| ${r.status === 'pass' ? 'pass' : r.status === 'info' ? 'info' : '**FAIL**'} | ${r.id} ${r.name} | ${r.detail.replace(/\|/g, '/')} |`),
  '',
  `${passedBlocking} of ${expectedMin} blocking checks passed, ${failed.length} failed.`,
].join('\n');
fs.writeFileSync(path.join(OUT, 'summary.md'), md + '\n');
console.log(`WEB_E2E_RESULT passed=${passedBlocking} failed=${failed.length} blocking=${expectedMin}`);
process.exit(failed.length === 0 && passedBlocking === expectedMin && passedBlocking >= MIN_BLOCKING ? 0 : 1);
