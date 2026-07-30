/**
 * Derive scene durations from the ACTUAL trimmed footage, and merge in the
 * recorded cursor timeline.
 *
 * The skill's worst gotcha was "re-derive caption/overlay windows from a
 * montage every shoot". Hardcoded seconds drift the moment page-load speed
 * changes — it bit this very sample (a 40s SSE clip against a 6.36s hardcoded
 * window). Scene clips only fix that if their lengths are MEASURED, not typed.
 *
 * v4 additions: durations come from the TRIMMED clip (post-calibration), and
 * each scene carries the real cursor path captured alongside it.
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import RAW_CONFIG from './demo.config.js';
import { resolve } from './presets.mjs';

// Resolve preset + intensity ONCE here, so the Remotion component reads literal
// token values and never has to know a preset exists.
const CONFIG = resolve(RAW_CONFIG);

const { default: ffprobeInstaller } = await import('@ffprobe-installer/ffprobe');

const dur = (f) => parseFloat(execFileSync(ffprobeInstaller.path, [
  '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f,
]).toString().trim());

const scenes = CONFIG.scenes.map((s) => {
  const clip = `footage/${s.id}.mp4`;
  const cursorFile = `footage/${s.id}.cursor.json`;

  // Never fall back to a default path — a missing artefact means the capture
  // did not produce what the render is about to claim it did.
  if (!fs.existsSync(clip)) throw new Error(`missing footage: ${clip} — run capture first`);
  if (!fs.existsSync(cursorFile)) throw new Error(`missing cursor timeline: ${cursorFile}`);

  const cursor = JSON.parse(fs.readFileSync(cursorFile, 'utf8'));
  const sec = dur(clip);

  // Coordinate sanity: every logged point must lie inside the capture viewport.
  const { width, height } = cursor.viewport;
  for (const p of cursor.samples) {
    if (p.x < 0 || p.y < 0 || p.x > width || p.y > height) {
      throw new Error(`[${s.id}] cursor sample outside viewport: ${JSON.stringify(p)}`);
    }
  }

  return {
    id: s.id,
    sec,
    caption: s.caption,
    sub: s.sub,
    viewport: cursor.viewport,
    // Store seconds for the render; the capture logs ms.
    samples: cursor.samples.map((p) => ({ t: p.t / 1000, x: p.x, y: p.y })),
    events: cursor.events.map((e) => ({
      t: e.t / 1000, tEnd: e.tEnd / 1000,
      tClick: e.tClick == null ? null : e.tClick / 1000,
      x: e.x, y: e.y, w: e.w, h: e.h, label: e.label,
    })),
  };
});

fs.writeFileSync('remotion/src/scenes.json', JSON.stringify(scenes, null, 2));
fs.writeFileSync('remotion/src/config.json', JSON.stringify(CONFIG, null, 2));

for (const s of scenes) {
  const late = s.events.filter((e) => e.tEnd > s.sec);
  console.log(`${s.id}  ${s.sec.toFixed(2)}s  ${s.samples.length} samples  ${s.events.length} targets` +
              (late.length ? `  !! ${late.length} target(s) end after the clip` : ''));
}
console.log(`total footage: ${scenes.reduce((n, s) => n + s.sec, 0).toFixed(2)}s`);
