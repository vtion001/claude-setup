import React from 'react';
import {
  AbsoluteFill, Sequence, OffthreadVideo, staticFile,
  useCurrentFrame, useVideoConfig, interpolate, Easing, random,
} from 'remotion';

import scenes from './scenes.json';
import config from './config.json';

export const SCENES = scenes;
export const CONFIG = config;

/**
 * v4.
 *
 * The cursor is no longer invented. v1-v3 carried a hand-typed map of viewport
 * percentages — nothing tied those numbers to a rendered element, so the cursor
 * pointed at whatever occupied that fraction of the frame and the UI never
 * reacted underneath it. Here every position is a real mouse sample logged
 * during capture, at a real timestamp, and every focus ring is sized from the
 * element's real `boundingBox()`.
 *
 * The look is no longer hardcoded either: tokens arrive resolved from
 * demo.config.js via a preset, so choosing an aesthetic is data, not a code edit.
 */

const B = config.brand;
const M = config.motion;

/* ---------------- colour ---------------- */

const hexToRgb = (h) => {
  const n = parseInt(h.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};

const rgbToHsl = ([r, g, b]) => {
  r /= 255; g /= 255; b /= 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  const l = (mx + mn) / 2;
  if (!d) return [0, 0, l];
  const s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
  const h = mx === r ? ((g - b) / d + (g < b ? 6 : 0))
          : mx === g ? (b - r) / d + 2
          : (r - g) / d + 4;
  return [h * 60, s, l];
};

const hslToCss = ([h, s, l], alpha = 1) =>
  `hsla(${((h % 360) + 360) % 360}, ${Math.round(s * 100)}%, ${Math.round(l * 100)}%, ${alpha})`;

/**
 * Hue drift: the key light rotates a fixed number of degrees per scene, so
 * sections read as chapters rather than repetitions. Sampling a reference
 * product film showed its tint shifting cool→warm between sections; v1-v3 held
 * one accent for their entire runtime.
 */
const accentFor = (i, alpha = 1) => {
  const hsl = rgbToHsl(hexToRgb(B.accent));
  return hslToCss([hsl[0] + i * (B.hueDrift || 0), hsl[1], hsl[2]], alpha);
};

/**
 * Contrast rhythm: alternating stage brightness scene to scene. The reference
 * film's frame luminance swung roughly 40x across its opening; these builds
 * were uniformly lit throughout, which is what made them monotonous rather than
 * merely dark.
 */
const rhythmFor = (i) =>
  M.rhythm === 'alternating' ? M.rhythmRange[i % 2] : 1;

const easeStd = Easing.bezier(0.4, 0, 0.2, 1);
const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
const easeEmph = Easing.bezier(0.34, 1.7, 0.64, 1);

/* ---------------- atmosphere ---------------- */

const Ambience = ({ frame, index = 0 }) => {
  const pulse = Math.sin(frame / 44) * 0.5 + 0.5;
  const drift = interpolate(pulse, [0, 1], [-3, 3]);
  const lift = rhythmFor(index);
  const a = interpolate(pulse, [0, 1], [0.5, 0.72]) * lift;
  return (
    <AbsoluteFill style={{ background: `linear-gradient(155deg, ${B.surfaceAlt} 0%, ${B.surface} 62%)` }}>
      <div style={{
        position: 'absolute', inset: '-25%',
        background:
          `radial-gradient(50% 44% at ${52 + drift}% 6%, ${accentFor(index, Math.min(a * 0.55, 0.8))} 0%, transparent 60%),` +
          `radial-gradient(44% 40% at ${14 - drift}% 96%, ${accentFor(index + 2, 0.3 * lift)} 0%, transparent 62%)`,
        filter: 'blur(30px)',
      }} />
    </AbsoluteFill>
  );
};

const Sparkles = ({ frame, seed, index = 0, count = 12 }) => {
  if (!M.particles) return null;
  return (
    <AbsoluteFill style={{ pointerEvents: 'none' }}>
      {new Array(count).fill(0).map((_, i) => {
        const px = random(`${seed}x${i}`) * 100;
        const py = random(`${seed}y${i}`) * 100;
        const phase = random(`${seed}p${i}`) * 60;
        const life = (frame + phase) % 70;
        const s = interpolate(life, [0, 14, 40, 70], [0, 1, 0.85, 0], { extrapolateRight: 'clamp' });
        const size = 7 + random(`${seed}s${i}`) * 11;
        const c = accentFor(index);
        return (
          <div key={i} style={{
            position: 'absolute', left: `${px}%`, top: `${py}%`,
            width: size, height: size, opacity: s * 0.9,
            transform: `translate(-50%,-50%) rotate(${life * 2}deg) scale(${s})`,
            background: `conic-gradient(from 0deg, transparent 0deg, ${c} 12deg, transparent 24deg, transparent 90deg, ${c} 102deg, transparent 114deg, transparent 180deg, ${c} 192deg, transparent 204deg, transparent 270deg, ${c} 282deg, transparent 294deg)`,
            filter: `blur(0.4px) drop-shadow(0 0 6px ${c})`,
          }} />
        );
      })}
    </AbsoluteFill>
  );
};

/* ---------------- cursor, replayed from real samples ---------------- */

/** Linear interpolation between the two real samples bracketing `t`. */
const posAt = (samples, t) => {
  if (!samples.length) return null;
  if (t <= samples[0].t) return samples[0];
  const last = samples[samples.length - 1];
  if (t >= last.t) return last;
  let lo = 0, hi = samples.length - 1;
  while (hi - lo > 1) {
    const mid = (lo + hi) >> 1;
    if (samples[mid].t <= t) lo = mid; else hi = mid;
  }
  const a = samples[lo], b = samples[hi];
  const k = b.t === a.t ? 0 : (t - a.t) / (b.t - a.t);
  return { x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k };
};

const Cursor = ({ scene, t, index }) => {
  const now = posAt(scene.samples, t);
  if (!now) return null;
  const prev = posAt(scene.samples, Math.max(0, t - 1 / 30));

  const { width: vw, height: vh } = scene.viewport;
  // Velocity from CONSECUTIVE REAL SAMPLES — not from an easing curve invented
  // between invented points. Motion blur is the strongest "filmed" cue, and it
  // is only honest if the speed is measured.
  const vel = Math.hypot(now.x - prev.x, now.y - prev.y);
  const blur = M.blur ? Math.min(vel * 0.09, 6) : 0;

  const click = scene.events.find((e) => e.tClick != null && t >= e.tClick && t < e.tClick + 0.5);
  const ripple = click ? (t - click.tClick) / 0.5 : -1;
  const c = accentFor(index);

  return (
    <div style={{ position: 'absolute', left: `${(now.x / vw) * 100}%`, top: `${(now.y / vh) * 100}%`, transform: 'translate(-50%,-50%)' }}>
      {ripple >= 0 && (
        <>
          <div style={{
            position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-50%)',
            width: 30 + ripple * 130, height: 30 + ripple * 130, borderRadius: '50%',
            border: `2px solid ${c}`, opacity: 1 - ripple,
          }} />
          <div style={{
            position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-50%)',
            width: 96, height: 96, borderRadius: '50%',
            background: `radial-gradient(circle, ${accentFor(index, 0.28)} 0%, transparent 70%)`, opacity: 1 - ripple,
          }} />
        </>
      )}
      {/* Soft contact shadow so the cursor sits ON the interface, not above it. */}
      <div style={{
        position: 'absolute', left: 6, top: 10, width: 54, height: 54, borderRadius: '50%',
        background: `radial-gradient(circle, ${accentFor(index, 0.22)} 0%, transparent 68%)`,
      }} />
      <svg width="46" height="52" viewBox="0 0 46 52" style={{ filter: `blur(${blur}px) drop-shadow(0 6px 14px rgba(0,0,0,0.75))` }}>
        <path d="M9 4 L9 34 L16 28 L21 41 L27 38 L22 26 L32 26 Z"
              fill="#FFFFFF" stroke="#12121A" strokeWidth="2.2" strokeLinejoin="round" />
      </svg>
    </div>
  );
};

/**
 * The ring is sized from the element's RECORDED box. v3 drew a fixed 132x46
 * pill, which fitted nothing in particular — a wide table row and a small tab
 * button got the same rectangle.
 */
const FocusRing = ({ scene, t, index }) => {
  const { width: vw, height: vh } = scene.viewport;
  const LEAD = 0.3, FADE = 0.25;
  return (
    <>
      {scene.events.map((e, i) => {
        const a = interpolate(
          t, [e.t - LEAD, e.t - LEAD + 0.18, e.tEnd, e.tEnd + FADE], [0, 1, 1, 0],
          { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' },
        );
        if (a <= 0.01) return null;
        const breathe = 1 + Math.sin(t * 7) * 0.012;
        const pad = 8;
        return (
          <div key={i} style={{
            position: 'absolute',
            left: `${(e.x / vw) * 100}%`, top: `${(e.y / vh) * 100}%`,
            width: `${((e.w + pad * 2) / vw) * 100}%`, height: `${((e.h + pad * 2) / vh) * 100}%`,
            transform: `translate(-50%,-50%) scale(${breathe})`,
            borderRadius: 12,
            border: `2px solid ${accentFor(index)}`,
            background: accentFor(index, 0.1),
            boxShadow: `0 0 26px ${accentFor(index, 0.5)}, inset 0 0 18px ${accentFor(index, 0.14)}`,
            opacity: a * 0.95,
          }} />
        );
      })}
    </>
  );
};

/** The label of whatever the cursor is currently on — states the point. */
const TargetLabel = ({ scene, t, index }) => {
  const { width: vw, height: vh } = scene.viewport;
  return (
    <>
      {scene.events.map((e, i) => {
        const a = interpolate(t, [e.t, e.t + 0.2, e.tEnd, e.tEnd + 0.2], [0, 1, 1, 0],
          { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
        if (a <= 0.01) return null;
        const above = e.y / vh > 0.55;
        return (
          <div key={i} style={{
            position: 'absolute',
            left: `${(e.x / vw) * 100}%`,
            top: `${((e.y + (above ? -e.h / 2 - 34 : e.h / 2 + 12)) / vh) * 100}%`,
            transform: 'translateX(-50%)', opacity: a,
            padding: '7px 16px', borderRadius: 999, whiteSpace: 'nowrap',
            background: 'rgba(6,6,11,0.94)', border: `1px solid ${accentFor(index, 0.7)}`,
            color: '#FFFFFF', fontSize: 21, fontWeight: 700, fontFamily: B.font,
            boxShadow: `0 10px 30px rgba(0,0,0,0.75)`,
          }}>{e.label}</div>
        );
      })}
    </>
  );
};

/* ---------------- the staged screen ---------------- */

const INNER_W = 1500;

const Stage = ({ scene, frame, dur, index }) => {
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const p = frame / dur;
  // ENTRY MUST FINISH BEFORE THE FIRST TARGET. The capture starts moving the
  // mouse within ~0.5s of the clip, so a 1s entry meant the most important
  // moment of the scene — the first hover — played out under heavy motion blur
  // at a 26-degree tilt. Verified in a montage; it is why this is 16 and not 30.
  const ENTRY = 16;
  const inT = interpolate(frame, [0, ENTRY], [0, 1], { extrapolateRight: 'clamp', easing: easeOut });
  const outT = interpolate(frame, [dur - 20, dur], [0, 1], { extrapolateLeft: 'clamp', easing: easeStd });

  const tilt = M.tilt ?? 11;
  const rotY = interpolate(inT, [0, 1], [tilt * 1.5, tilt]) - outT * 9;
  const rotX = interpolate(inT, [0, 1], [tilt * 0.8, tilt * 0.45]);
  const z = interpolate(inT, [0, 1], [-420, 0]) - outT * 300;
  const scale = interpolate(inT, [0, 1], [0.95, 1.06]) + p * (M.push ?? 0.03);
  const op = interpolate(frame, [0, 10], [0, 1], { extrapolateRight: 'clamp' }) * (1 - outT);

  const speed = Math.abs(interpolate(frame, [0, ENTRY], [1, 0], { extrapolateRight: 'clamp' })) + outT;
  const mblur = M.blur ? Math.min(speed * 5, 6) : 0;

  // The inner surface matches the CAPTURE ASPECT EXACTLY. Without this the
  // video is letterboxed or cropped by objectFit and every cursor coordinate
  // lands slightly wrong — which would quietly reintroduce the bug this whole
  // version exists to remove.
  const innerH = INNER_W * (scene.viewport.height / scene.viewport.width);
  const lift = rhythmFor(index);

  return (
    <AbsoluteFill style={{ perspective: 1500, alignItems: 'center', justifyContent: 'center' }}>
      <div style={{
        transformStyle: 'preserve-3d',
        transform: `translate3d(0,0,${z}px) rotateY(${-rotY}deg) rotateX(${rotX}deg) scale(${scale})`,
        opacity: op, filter: `blur(${mblur}px)`,
      }}>
        <div style={{
          position: 'relative', width: INNER_W + 24, height: innerH + 24, borderRadius: B.radius,
          background: B.panel, padding: 12, boxSizing: 'border-box',
          boxShadow: `0 80px 160px -40px rgba(0,0,0,0.95), 0 0 0 1px rgba(255,255,255,0.08)`,
        }}>
          <div style={{
            position: 'absolute', top: -2, left: 30, right: 30, height: 3, borderRadius: 3,
            background: `linear-gradient(90deg, transparent, ${accentFor(index)}, ${accentFor(index + 3)}, transparent)`,
            opacity: 0.6 + 0.35 * lift, filter: 'blur(1px)',
          }} />
          <div style={{ position: 'relative', width: INNER_W, height: innerH, borderRadius: B.radius - 8, overflow: 'hidden' }}>
            <OffthreadVideo src={staticFile(`footage/${scene.id}.mp4`)}
                            style={{ width: '100%', height: '100%', objectFit: 'fill', display: 'block' }} />

            <FocusRing scene={scene} t={t} index={index} />
            <Cursor scene={scene} t={t} index={index} />
            <TargetLabel scene={scene} t={t} index={index} />
            <Sparkles frame={frame} seed={scene.id} index={index} count={10} />

            {M.dof && (
              <AbsoluteFill style={{
                backdropFilter: 'blur(5px)',
                WebkitMaskImage: 'linear-gradient(100deg, #000 0%, rgba(0,0,0,0.55) 20%, transparent 42%)',
                maskImage: 'linear-gradient(100deg, #000 0%, rgba(0,0,0,0.55) 20%, transparent 42%)',
                pointerEvents: 'none',
              }} />
            )}
          </div>
        </div>
      </div>
      <AbsoluteFill style={{
        background: `radial-gradient(115% 85% at 50% 48%, transparent ${28 + 10 * lift}%, rgba(0,0,0,${0.9 - 0.18 * lift}) 100%)`,
        pointerEvents: 'none',
      }} />
    </AbsoluteFill>
  );
};

const SceneType = ({ text, sub, frame, dur, index }) => {
  const y = interpolate(frame, [14, 44], [30, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: easeEmph });
  const blur = interpolate(frame, [14, 34], [10, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const op = interpolate(frame, [14, 32], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const out = interpolate(frame, [dur - 16, dur - 2], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const bar = interpolate(frame, [18, 46], [0, 72], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: easeOut });
  return (
    <AbsoluteFill style={{ justifyContent: 'flex-end', alignItems: 'center', paddingBottom: 46, fontFamily: B.font }}>
      <div style={{ transform: `translateY(${y}px)`, opacity: op * out, filter: `blur(${blur}px)`, textAlign: 'center' }}>
        <div style={{ width: bar, height: 3, background: accentFor(index), borderRadius: 2, margin: '0 auto 14px', boxShadow: `0 0 16px ${accentFor(index)}` }} />
        <div style={{ fontSize: 42, fontWeight: 700, color: B.text, textShadow: '0 6px 30px rgba(0,0,0,0.9)' }}>{text}</div>
        <div style={{ fontSize: 21, fontWeight: 500, color: B.muted, marginTop: 8 }}>{sub}</div>
      </div>
    </AbsoluteFill>
  );
};

const Scene = ({ scene, dur, index }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill>
      <Ambience frame={frame} index={index} />
      <Stage scene={scene} frame={frame} dur={dur} index={index} />
      <SceneType text={scene.caption} sub={scene.sub} frame={frame} dur={dur} index={index} />
    </AbsoluteFill>
  );
};

/* ---------------- kinetic title ---------------- */

const KineticWords = ({ words, dur }) => {
  const frame = useCurrentFrame();
  return (
    <div style={{ display: 'flex', gap: 22, justifyContent: 'center', flexWrap: 'wrap' }}>
      {words.map((w, i) => {
        const start = 4 + i * 7;
        const x = interpolate(frame, [start, start + 22], [90, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: easeEmph });
        const op = interpolate(frame, [start, start + 14], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
        const blur = M.blur ? interpolate(frame, [start, start + 20], [16, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }) : 0;
        const out = interpolate(frame, [dur - 16, dur], [1, 0], { extrapolateLeft: 'clamp' });
        return (
          <span key={i} style={{
            display: 'inline-block', transform: `translateX(${x}px)`, opacity: op * out,
            filter: `blur(${blur}px)`,
            fontSize: 108, fontWeight: 800, color: B.text, letterSpacing: -2,
            textShadow: `0 12px 70px ${accentFor(0, 0.4)}`,
          }}>{w}</span>
        );
      })}
    </div>
  );
};

const Title = ({ kicker, words, sub, dur, index = 0 }) => {
  const frame = useCurrentFrame();
  const kick = interpolate(frame, [0, 18], [0, 1], { extrapolateRight: 'clamp' });
  const subOp = interpolate(frame, [26, 46], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const out = interpolate(frame, [dur - 14, dur], [1, 0], { extrapolateLeft: 'clamp' });
  return (
    <AbsoluteFill style={{ fontFamily: B.font, alignItems: 'center', justifyContent: 'center', opacity: out }}>
      <Ambience frame={frame} index={index} />
      <Sparkles frame={frame} seed={kicker} index={index} count={18} />
      <div style={{ textAlign: 'center', zIndex: 2 }}>
        <div style={{ fontSize: 16, fontWeight: 700, letterSpacing: 6, textTransform: 'uppercase', color: accentFor(index), marginBottom: 24, opacity: kick }}>{kicker}</div>
        <KineticWords words={words} dur={dur} />
        <div style={{ fontSize: 25, fontWeight: 500, color: B.muted, marginTop: 26, opacity: subOp }}>{sub}</div>
      </div>
      {/* Watermark defaults to cards-only: no reference-grade product film
          brands its own screen recording continuously. */}
      {config.watermark?.mode !== 'none' && (
        <div style={{
          position: 'absolute', bottom: 40, fontSize: 14, letterSpacing: 3,
          textTransform: 'uppercase', color: B.muted, opacity: 0.6 * kick,
        }}>{config.watermark.text}</div>
      )}
      <AbsoluteFill style={{ background: 'radial-gradient(115% 85% at 50% 50%, transparent 40%, rgba(0,0,0,0.78) 100%)', pointerEvents: 'none' }} />
    </AbsoluteFill>
  );
};

/* ---------------- timeline ---------------- */

export const layout = (fps) => {
  const intro = Math.round(3.2 * fps);
  const outro = Math.round(3.0 * fps);
  const OVERLAP = Math.round(0.45 * fps);
  let cursor = intro - OVERLAP;
  const items = SCENES.map((s, i) => {
    const d = Math.round(s.sec * fps);
    const from = cursor;
    cursor += d - OVERLAP;
    return { s, d, from, i };
  });
  return { intro, outro, items, total: cursor + outro };
};

export const Demo = () => {
  const { fps } = useVideoConfig();
  const { intro, outro, items, total } = layout(fps);
  return (
    <AbsoluteFill style={{ background: B.surface }}>
      <Sequence durationInFrames={intro}>
        <Title {...config.intro} dur={intro} index={0} />
      </Sequence>
      {items.map(({ s, d, from, i }) => (
        <Sequence key={s.id} from={from} durationInFrames={d}>
          <Scene scene={s} dur={d} index={i} />
        </Sequence>
      ))}
      <Sequence from={total - outro} durationInFrames={outro}>
        <Title {...config.outro} dur={outro} index={items.length} />
      </Sequence>
    </AbsoluteFill>
  );
};
