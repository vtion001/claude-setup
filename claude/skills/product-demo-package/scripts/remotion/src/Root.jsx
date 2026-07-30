import React from 'react';
import { Composition } from 'remotion';
import { Demo, layout, CONFIG } from './Demo';
import { Sizzle, sizzleLayout } from './Sizzle';

const { width, height, fps } = CONFIG.output;

// Lengths derived from the ffmpeg-read footage durations, per the skill's rule:
// durations are MEASURED, never typed.
const explainer = layout(fps);
const sizzle = sizzleLayout(fps);

const genre = CONFIG.output.genre;
const wants = (g) => genre === 'both' || genre === g;

export const RemotionRoot = () => (
  <>
    {wants('explainer') && (
      <Composition id="Demo" component={Demo} durationInFrames={explainer.total}
                   fps={fps} width={width} height={height} />
    )}
    {wants('sizzle') && (
      <Composition id="Sizzle" component={Sizzle} durationInFrames={sizzle.total}
                   fps={fps} width={width} height={height} />
    )}
  </>
);
