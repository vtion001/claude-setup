/**
 * v4 capture — DOM-anchored cursor.
 *
 * WHAT CHANGED AND WHY
 * --------------------
 * v1-v3 drew a cursor from a hand-typed map of viewport percentages. Nothing
 * tied those numbers to a rendered element, so the cursor pointed at whatever
 * happened to occupy that fraction of the frame, and the interface never
 * reacted underneath it — the footage was captured before the coordinates
 * existed. It read as a sticker on a video.
 *
 * Here Playwright moves the REAL mouse to each element's real box
 * (`boundingBox()`), and the movement is logged as it happens. The drawn cursor
 * at render time and the UI's own hover state both derive from the same
 * movement, so they cannot drift apart.
 *
 * Scene-clip model: each scene records its OWN video, so caption timings bind
 * to a scene rather than to a wall-clock offset that shifts with page-load
 * speed. That removes the skill's worst gotcha ("re-derive caption windows from
 * a montage every shoot").
 */
import { chromium } from 'playwright';
import { spawnSync, execFileSync } from 'node:child_process';
import fs from 'node:fs';
import CONFIG from './demo.config.js';

// The Playwright image has no ffmpeg on PATH, and Playwright's own bundled
// build is VP8-only. Use the static installer build for anything H.264.
const { default: ffmpegInstaller } = await import('@ffmpeg-installer/ffmpeg');
const FFMPEG = ffmpegInstaller.path;

const BASE = process.env.BASE_URL;
const EMAIL = process.env.DEMO_EMAIL;
const PASS = process.env.DEMO_PASS;

const VIEWPORT = CONFIG.capture.viewport;
const CAL = CONFIG.capture.calibration;
const FRAME_PX = 8;                       // calibration probe resolution
const MARKER_HOLD_MS = 160;               // long enough to guarantee >=2 encoded frames at 25fps

const easeInOut = (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);

/* ------------------------------------------------------------------ */
/* calibration                                                         */
/* ------------------------------------------------------------------ */

/**
 * `recordVideo` gives no frame-accurate mapping from wall-clock time to video
 * frames, and the encoder does not necessarily start at page creation.
 * Unmeasured, a 200ms error puts the drawn cursor BEHIND the highlight it is
 * supposed to be causing.
 *
 * So: flash a full-viewport magenta field at t0 and find it in the footage.
 * The marker is deliberately obnoxious — it must be trivially separable from
 * real UI by a histogram test.
 */
const showMarker = async (page) => {
  const t0 = Date.now();
  await page.evaluate((color) => {
    const el = document.createElement('div');
    el.id = '__demo_calibration__';
    el.style.cssText = `position:fixed;inset:0;background:${color};z-index:2147483647;pointer-events:none`;
    document.documentElement.appendChild(el);
  }, CAL.color);
  await page.waitForTimeout(MARKER_HOLD_MS);
  await page.evaluate(() => document.getElementById('__demo_calibration__')?.remove());
  return t0;
};

/**
 * Decode the first seconds at 8x8 and find the magenta frames. `showinfo`
 * gives pts_time per frame on stderr in the same order the raw frames arrive on
 * stdout, so frame index maps to a real timestamp — no fps assumption.
 */
const findMarker = (clip) => {
  const bytes = FRAME_PX * FRAME_PX * 3;
  // spawnSync, not execFileSync: we need stdout (the pixels) AND stderr (the
  // showinfo timestamps) from ONE decode, so the two are guaranteed to describe
  // the same frames.
  const res = spawnSync(FFMPEG, [
    '-v', 'info', '-i', clip, '-t', String(CAL.searchSec),
    '-vf', `scale=${FRAME_PX}:${FRAME_PX},showinfo`,
    '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-',
  ], { maxBuffer: 1 << 28 });
  if (res.error) throw res.error;

  const raw = res.stdout;
  const times = [...res.stderr.toString().matchAll(/pts_time:([0-9.]+)/g)].map((m) => parseFloat(m[1]));
  const frames = Math.floor(raw.length / bytes);

  const isMagenta = (i) => {
    let r = 0, g = 0, b = 0;
    for (let p = 0; p < bytes; p += 3) { r += raw[i * bytes + p]; g += raw[i * bytes + p + 1]; b += raw[i * bytes + p + 2]; }
    const n = bytes / 3;
    return r / n > 170 && b / n > 170 && g / n < 90;
  };

  let first = -1, last = -1;
  for (let i = 0; i < Math.min(frames, times.length); i++) {
    if (isMagenta(i)) { if (first < 0) first = i; last = i; }
    else if (first >= 0) break;                       // only the leading run counts
  }
  // A silently unaligned cursor is worse than a failed build.
  if (first < 0) throw new Error(`calibration marker not found in first ${CAL.searchSec}s of ${clip}`);

  const frameDur = times.length > 1 ? times[1] - times[0] : 0.04;
  return { markerSec: times[first], trimSec: times[last] + frameDur, frames: last - first + 1 };
};

/* ------------------------------------------------------------------ */
/* capture                                                             */
/* ------------------------------------------------------------------ */

const run = async () => {
  fs.mkdirSync('/work/footage', { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: 1,
    recordVideo: { dir: '/work/footage/_tmp', size: VIEWPORT },
  });

  const login = await ctx.newPage();
  await login.goto(`${BASE}/login`, { waitUntil: 'networkidle' });
  await login.fill('input[name="email"]', EMAIL);
  await login.fill('input[name="password"]', PASS);
  await login.click('button[type="submit"]');
  await login.waitForTimeout(2500);

  // Fail loudly. Swallowing this once produced a "successful" render in which
  // every scene was the login screen under a caption describing a feature.
  // Root cause that time: the app sets a `secure` session cookie; localhost gets
  // a trustworthy-origin pass but host.docker.internal over plain HTTP does not,
  // so the session was dropped and every POST 419'd.
  if (/\/login\b/.test(login.url())) {
    throw new Error(
      `Login failed — still at ${login.url()}. If the app sets a Secure session ` +
      `cookie, serve it with SESSION_SECURE_COOKIE=false for the capture run.`
    );
  }
  console.log(`authenticated -> ${login.url()}`);
  await login.close();

  for (const scene of CONFIG.scenes) {
    const page = await ctx.newPage();
    const samples = [];
    const events = [];
    let t0 = 0;

    try {
      await page.goto(`${BASE}${scene.url}`, { waitUntil: scene.settle, timeout: 20000 });
      await page.waitForTimeout(1200);

      // The marker goes here — AFTER the page has painted — not at page
      // creation. Flashed on about:blank it raced the encoder's first frame and
      // was missed entirely on one scene in three. Two things follow:
      //   · the encoder is definitely running, so the flash is definitely caught
      //   · trimming at the marker also discards the page LOAD, so every scene
      //     opens on a settled page instead of mid-render
      t0 = await showMarker(page);
      const at = () => Date.now() - t0;

      // Start off-target so the first move is a real travel, not a teleport.
      let cur = { x: Math.round(VIEWPORT.width * 0.5), y: Math.round(VIEWPORT.height * 0.86) };
      await page.mouse.move(cur.x, cur.y);
      samples.push({ t: at(), ...cur });

      for (const target of scene.targets) {
        const loc = page.locator(target.sel).first();
        // Loud on failure, naming the scene and the selector — this is the
        // regression guard against a UI change silently pointing at nothing.
        await loc.waitFor({ state: 'visible', timeout: 8000 }).catch(() => {
          throw new Error(`[${scene.id}] selector never became visible: ${target.sel}`);
        });
        const box = await loc.boundingBox();
        if (!box) throw new Error(`[${scene.id}] boundingBox() null (not rendered): ${target.sel}`);

        const to = { x: Math.round(box.x + box.width / 2), y: Math.round(box.y + box.height / 2) };
        const travel = Math.hypot(to.x - cur.x, to.y - cur.y);
        const ms = Math.min(1200, Math.max(420, travel * 1.15));
        const steps = Math.max(10, Math.round(ms / 18));

        // Eased travel, driven step by step so every logged point is a real
        // mouse position at a real timestamp — not a curve invented afterwards.
        for (let i = 1; i <= steps; i++) {
          const k = easeInOut(i / steps);
          const x = Math.round(cur.x + (to.x - cur.x) * k);
          const y = Math.round(cur.y + (to.y - cur.y) * k);
          await page.mouse.move(x, y);
          samples.push({ t: at(), x, y });
          await page.waitForTimeout(Math.max(4, Math.round(ms / steps) - 6));
        }
        cur = to;

        const tArrive = at();
        // Dwell so hover and focus states are actually visible in the footage.
        await page.waitForTimeout(target.dwell);
        samples.push({ t: at(), ...cur });

        let tClick = null;
        if (target.click) {
          tClick = at();
          await page.mouse.down();
          await page.waitForTimeout(90);
          await page.mouse.up();
          await page.waitForTimeout(700);
          samples.push({ t: at(), ...cur });
        }

        events.push({
          t: tArrive, tEnd: at(), tClick,
          x: to.x, y: to.y,
          w: Math.round(box.width), h: Math.round(box.height),
          label: target.label || target.sel,
        });
      }

      await page.waitForTimeout(600);
      samples.push({ t: at(), ...cur });
    } catch (e) {
      await page.close();
      throw e;
    }

    const video = page.video();
    await page.close();
    if (!video) throw new Error(`[${scene.id}] no video recorded`);

    const rawClip = `/work/footage/${scene.id}.raw.webm`;
    await video.saveAs(rawClip);

    // ---- align, then CUT the marker out of the delivered footage ----
    // The marker sits at the FIRST frame of every scene clip, not before the
    // timeline, so left in place it flashes magenta inside the panel as each
    // scene fades in.
    const { markerSec, trimSec, frames } = findMarker(rawClip);
    const outClip = `/work/footage/${scene.id}.mp4`;
    // Output seeking (-ss after -i) is frame-exact; the clips are ~6s so the
    // cost is irrelevant, and H.264 decodes far faster in Remotion than VP8.
    execFileSync(FFMPEG, [
      '-y', '-v', 'error', '-i', rawClip, '-ss', trimSec.toFixed(3),
      '-c:v', 'libx264', '-crf', '18', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-an', outClip,
    ]);
    fs.unlinkSync(rawClip);

    // Rebase the timeline by the same amount so the render performs NO offset
    // arithmetic — alignment is baked into the artefacts.
    const shiftMs = (trimSec - markerSec) * 1000;
    const rebase = (o) => ({ ...o, t: Math.round(o.t - shiftMs), ...(o.tEnd != null ? { tEnd: Math.round(o.tEnd - shiftMs) } : {}), ...(o.tClick != null ? { tClick: Math.round(o.tClick - shiftMs) } : {}) });

    fs.writeFileSync(`/work/footage/${scene.id}.cursor.json`, JSON.stringify({
      id: scene.id,
      viewport: VIEWPORT,
      markerSec, trimSec, markerFrames: frames,
      offsetMs: 0,                                   // consumed above, by design
      samples: samples.map(rebase),
      events: events.map(rebase),
    }, null, 2));

    console.log(`saved ${outClip}  marker@${markerSec.toFixed(3)}s (${frames}f)  trim=${trimSec.toFixed(3)}s  ` +
                `${samples.length} samples / ${events.length} targets`);
  }

  await ctx.close();
  await browser.close();
};

run().catch((e) => { console.error(e); process.exit(1); });
