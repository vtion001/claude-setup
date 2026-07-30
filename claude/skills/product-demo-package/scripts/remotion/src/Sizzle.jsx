import React from 'react';
import {
  AbsoluteFill, Sequence, OffthreadVideo, staticFile,
  useCurrentFrame, useVideoConfig, interpolate, Easing,
} from 'remotion';

import scenes from './scenes.json';
import config from './config.json';

/**
 * Short cut from the SAME footage, for `output.genre` including 'sizzle'.
 *
 * The explainer earns its length by holding on each screen. A sizzle earns
 * attention by cutting on the payoff — so each beat starts just BEFORE a
 * recorded target moment (`events[].t`), not at the top of the clip where the
 * cursor is still travelling. That is only possible because the capture logged
 * when each moment actually happened.
 */

const B = config.brand;
const BEAT_SEC = 2.3;
const LEAD_SEC = 0.55;   // how much run-up to the moment we keep

const easeOut = Easing.bezier(0.16, 1, 0.3, 1);

const hexToRgb = (h) => { const n = parseInt(h.replace('#', ''), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
const rgbToHsl = ([r, g, b]) => {
  r /= 255; g /= 255; b /= 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  const l = (mx + mn) / 2;
  if (!d) return [0, 0, l];
  const s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
  const h = mx === r ? ((g - b) / d + (g < b ? 6 : 0)) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [h * 60, s, l];
};
const accentFor = (i, a = 1) => {
  const [h, s, l] = rgbToHsl(hexToRgb(B.accent));
  return `hsla(${(((h + i * (B.hueDrift || 0)) % 360) + 360) % 360}, ${Math.round(s * 100)}%, ${Math.round(l * 100)}%, ${a})`;
};

/** The most interesting second of a clip: the first recorded target moment. */
const beatStart = (scene) => {
  const e = scene.events[0];
  const raw = e ? e.t - LEAD_SEC : 0;
  // Never run past the end of the clip.
  return Math.max(0, Math.min(raw, Math.max(0, scene.sec - BEAT_SEC)));
};

const Beat = ({ scene, index, dur }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const punch = interpolate(frame, [0, 10], [1.13, 1.0], { extrapolateRight: 'clamp', easing: easeOut });
  const slide = interpolate(frame, [0, dur], [0, -22]);
  const flash = interpolate(frame, [0, 5], [0.85, 0], { extrapolateRight: 'clamp' });
  const wordIn = interpolate(frame, [4, 18], [70, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: easeOut });
  const wordOp = interpolate(frame, [4, 16, dur - 8, dur], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  return (
    <AbsoluteFill style={{ background: B.surface, overflow: 'hidden' }}>
      <AbsoluteFill style={{ transform: `scale(${punch}) translateX(${slide}px)` }}>
        <OffthreadVideo
          src={staticFile(`footage/${scene.id}.mp4`)}
          trimBefore={Math.round(beatStart(scene) * fps)}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        />
      </AbsoluteFill>

      {/* Hard cut reads as a cut, not a dissolve — one frame of light. */}
      <AbsoluteFill style={{ background: accentFor(index, flash), pointerEvents: 'none' }} />

      <AbsoluteFill style={{
        background: `linear-gradient(180deg, transparent 45%, rgba(0,0,0,0.85) 100%)`, pointerEvents: 'none',
      }} />

      <AbsoluteFill style={{ justifyContent: 'flex-end', padding: '0 90px 76px', fontFamily: B.font }}>
        <div style={{ transform: `translateY(${wordIn}px)`, opacity: wordOp }}>
          <div style={{ width: 64, height: 4, background: accentFor(index), borderRadius: 2, marginBottom: 18 }} />
          <div style={{ fontSize: 68, fontWeight: 800, color: '#FFF', letterSpacing: -1.5, lineHeight: 1.05 }}>{scene.caption}</div>
          <div style={{ fontSize: 26, fontWeight: 500, color: 'rgba(255,255,255,0.72)', marginTop: 12 }}>{scene.sub}</div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const EndCard = ({ dur }) => {
  const frame = useCurrentFrame();
  const op = interpolate(frame, [0, 12], [0, 1], { extrapolateRight: 'clamp' });
  const out = interpolate(frame, [dur - 10, dur], [1, 0], { extrapolateLeft: 'clamp' });
  const scale = interpolate(frame, [0, 24], [1.1, 1], { extrapolateRight: 'clamp', easing: easeOut });
  return (
    <AbsoluteFill style={{
      background: `radial-gradient(70% 60% at 50% 45%, ${B.surfaceAlt} 0%, ${B.surface} 70%)`,
      alignItems: 'center', justifyContent: 'center', fontFamily: B.font, opacity: op * out,
    }}>
      <div style={{ textAlign: 'center', transform: `scale(${scale})` }}>
        <div style={{ fontSize: 92, fontWeight: 800, color: B.text, letterSpacing: -2 }}>{config.outro.words.join(' ')}</div>
        <div style={{ fontSize: 22, color: B.muted, marginTop: 18, letterSpacing: 3, textTransform: 'uppercase' }}>{config.watermark.text}</div>
      </div>
    </AbsoluteFill>
  );
};

export const sizzleLayout = (fps) => {
  const beat = Math.round(BEAT_SEC * fps);
  const end = Math.round(2.2 * fps);
  return { beat, end, total: scenes.length * beat + end };
};

export const Sizzle = () => {
  const { fps } = useVideoConfig();
  const { beat, end, total } = sizzleLayout(fps);
  return (
    <AbsoluteFill style={{ background: B.surface }}>
      {scenes.map((s, i) => (
        <Sequence key={s.id} from={i * beat} durationInFrames={beat}>
          <Beat scene={s} index={i} dur={beat} />
        </Sequence>
      ))}
      <Sequence from={total - end} durationInFrames={end}>
        <EndCard dur={end} />
      </Sequence>
    </AbsoluteFill>
  );
};
