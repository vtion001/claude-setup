/**
 * Look presets. The point of this file is that the aesthetic is DATA.
 *
 * Across three sample builds the look was assumed rather than chosen — light,
 * then dark, then cinematic — and was wrong twice, because it lived hardcoded
 * inside the Remotion component. A preset is a complete token set; the intake
 * picks one, `demo.config.js` records it, and both the video and the PDFs read
 * from the same place.
 *
 * The `clean-light` and `cinematic-dark` values are measured from live product
 * pages (apple.com/iphone, samsung.com/galaxy, 2026-07-31), not invented.
 */

export const PRESETS = {
  /**
   * Samsung ships a LIGHT page whose media sits on NEAR-BLACK rounded panels.
   * Measured: 53 media containers, border-radius 20px, bg rgb(28,28,28), zero
   * box-shadows. The dark bezel is REQUIRED, not decorative — a light app UI on
   * a white canvas has no separation other than corner radius, and the footage
   * stops reading as an object.
   */
  'clean-light': {
    brand: {
      surface: '#FFFFFF', surfaceAlt: '#F3F3F5',
      panel: '#1C1C1C', radius: 20,
      text: '#101010', muted: '#6B6B70',
      accent: '#2F6BFF', accentAlt: '#0B5FFF',
      hueDrift: 0,
      font: '"Inter", "Segoe UI", Helvetica, Arial, sans-serif',
    },
    motion: { intensity: 'standard', blur: true, particles: false, dof: false, rhythm: 'flat', rhythmRange: [1, 1] },
  },

  'cinematic-dark': {
    brand: {
      surface: '#06060B', surfaceAlt: '#150F26',
      panel: '#141419', radius: 20,
      text: '#F7F7FA', muted: '#9E9EAF',
      accent: '#A78BFA', accentAlt: '#2F6BFF',
      hueDrift: 14,
      font: '"Segoe UI", Inter, Helvetica, Arial, sans-serif',
    },
    motion: { intensity: 'cinematic', blur: true, particles: true, dof: true, rhythm: 'alternating', rhythmRange: [0.8, 1.35] },
  },

  /**
   * Inherits the running app's palette by reading getComputedStyle on
   * :root/body — including the app's flaws. Offered for speed, not art
   * direction. Resolved at intake time and written into demo.config.js as
   * literal values, so a build never depends on the app being up.
   */
  'brand-derived': {
    brand: {
      surface: null, surfaceAlt: null, panel: '#141419', radius: 20,
      text: null, muted: null, accent: null, accentAlt: null, hueDrift: 0,
      font: null,
    },
    motion: { intensity: 'standard', blur: true, particles: false, dof: true, rhythm: 'flat', rhythmRange: [1, 1] },
  },
};

/**
 * Motion intensity is INDEPENDENT of preset — a light stage can carry cinematic
 * motion. Choosing an intensity overrides the preset's motion defaults.
 */
export const INTENSITY = {
  subtle:    { blur: false, particles: false, dof: false, rhythm: 'flat',        rhythmRange: [1, 1],      push: 0.01, tilt: 4 },
  standard:  { blur: true,  particles: false, dof: true,  rhythm: 'flat',        rhythmRange: [1, 1],      push: 0.02, tilt: 8 },
  cinematic: { blur: true,  particles: true,  dof: true,  rhythm: 'alternating', rhythmRange: [0.8, 1.35], push: 0.03, tilt: 11 },
};

export const resolve = (config) => {
  const preset = PRESETS[config.preset];
  if (!preset) throw new Error(`unknown preset "${config.preset}" — one of ${Object.keys(PRESETS).join(', ')}`);

  const motion = { ...preset.motion, ...(config.motion || {}) };
  const intensity = INTENSITY[motion.intensity];
  if (!intensity) throw new Error(`unknown motion.intensity "${motion.intensity}"`);

  return {
    ...config,
    brand: { ...preset.brand, ...(config.brand || {}) },
    // Explicit per-key overrides in demo.config.js still win over the intensity
    // defaults; the intensity only fills in what was not stated.
    motion: { ...intensity, ...motion },
  };
};
