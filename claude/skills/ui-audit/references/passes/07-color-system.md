# Pass 7: Color System

Evaluates whether the UI uses a cohesive, intentional color system with proper semantic mapping, balanced distribution (60-30-10 rule), palette harmony, dark mode parity, and colorblind safety.

## Tier 0: Code Analysis

Before launching the browser, analyze the source code for color system architecture:

1. **Color token definitions** — Search for CSS custom properties (`--color-*`, `--c-*`), Tailwind config `theme.colors` / `theme.extend.colors`, SCSS variables (`$color-*`), or dedicated theme/token files. Map each token to its semantic role.
2. **Semantic role mapping** — Identify tokens for: primary, secondary, accent, destructive/danger/error, success, warning, info, neutral/gray scale, surface/background, text/foreground, border, muted. Flag missing semantic roles.
3. **Dark mode definitions** — Check for `prefers-color-scheme: dark` media queries, `.dark` class selectors, `dark:` Tailwind prefix usage, or theme toggle logic. Verify each light token has a dark counterpart.
4. **Palette generation method** — Determine if colors are hand-picked, generated from a seed (Radix, Tailwind defaults, Material), or based on a known system. Check for systematic shade scales (50-950 or 100-900).
5. **Hardcoded color values** — Search for raw hex (`#ff0000`), rgb(), or hsl() values used outside the token system. Count instances and flag files with the most violations.
6. **Unique color count** — Count total unique color values across the codebase (CSS + Tailwind classes + inline styles). Group by hue. Flag if there are >15 distinct hues.

## Tier 1: Automated Browser Checks

### 7.1 Measure 60-30-10 Color Distribution

```javascript
(() => {
  function parseRGB(color) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h, s, l = (max + min) / 2;

    if (max === min) {
      h = s = 0;
    } else {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
        case g: h = ((b - r) / d + 2) / 6; break;
        case b: h = ((r - g) / d + 4) / 6; break;
      }
    }
    return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
  }

  function colorKey(hsl) {
    if (hsl.s < 10) return `neutral-${Math.round(hsl.l / 10) * 10}`;
    const hueGroup = Math.round(hsl.h / 30) * 30;
    return `hue-${hueGroup}-s${Math.round(hsl.s / 20) * 20}`;
  }

  const elements = document.querySelectorAll('*');
  const colorAreas = {};
  let totalArea = 0;

  const sampled = Array.from(elements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && rect.top < window.innerHeight * 3;
  }).slice(0, 500);

  sampled.forEach(el => {
    const rect = el.getBoundingClientRect();
    const style = window.getComputedStyle(el);
    const area = rect.width * rect.height;

    const bgColor = parseRGB(style.backgroundColor);
    if (bgColor && style.backgroundColor !== 'rgba(0, 0, 0, 0)') {
      const hsl = rgbToHsl(bgColor.r, bgColor.g, bgColor.b);
      const key = colorKey(hsl);
      if (!colorAreas[key]) {
        colorAreas[key] = { area: 0, hsl, rgb: `rgb(${bgColor.r},${bgColor.g},${bgColor.b})`, count: 0 };
      }
      colorAreas[key].area += area;
      colorAreas[key].count++;
      totalArea += area;
    }
  });

  const sorted = Object.entries(colorAreas)
    .map(([key, data]) => ({
      colorGroup: key,
      rgb: data.rgb,
      hsl: data.hsl,
      areaPercent: totalArea > 0 ? Math.round((data.area / totalArea) * 100) : 0,
      elementCount: data.count
    }))
    .sort((a, b) => b.areaPercent - a.areaPercent);

  const dominant = sorted[0] || null;
  const secondary = sorted[1] || null;
  const accent = sorted.length > 2 ? sorted.slice(2).reduce((sum, c) => sum + c.areaPercent, 0) : 0;

  const distribution = {
    dominant: dominant ? { color: dominant.rgb, percent: dominant.areaPercent } : null,
    secondary: secondary ? { color: secondary.rgb, percent: secondary.areaPercent } : null,
    accentPercent: accent,
    follows60_30_10: dominant && secondary &&
      dominant.areaPercent >= 45 && dominant.areaPercent <= 75 &&
      secondary.areaPercent >= 15 && secondary.areaPercent <= 40 &&
      accent <= 20
  };

  const issues = [];
  if (dominant && dominant.areaPercent < 45) {
    issues.push({
      type: 'no-dominant-color',
      percent: dominant.areaPercent,
      message: `No dominant color. Largest color group covers only ${dominant.areaPercent}%. Should be ~60%.`
    });
  }
  if (accent > 25) {
    issues.push({
      type: 'excessive-accent',
      percent: accent,
      message: `Accent colors cover ${accent}% of surface area. Should be ~10% or less.`
    });
  }

  return {
    uniqueColorGroups: sorted.length,
    topColors: sorted.slice(0, 8),
    distribution,
    distributionScore: distribution.follows60_30_10 ? 100 : Math.max(0, 100 - Math.abs((dominant?.areaPercent || 0) - 60) * 2),
    issues
  };
})()
```

### 7.2 Check Palette Harmony

```javascript
(() => {
  function parseRGB(color) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h, s, l = (max + min) / 2;
    if (max === min) {
      h = s = 0;
    } else {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
        case g: h = ((b - r) / d + 2) / 6; break;
        case b: h = ((r - g) / d + 4) / 6; break;
      }
    }
    return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
  }

  const elements = document.querySelectorAll('*');
  const hueSet = new Set();
  const colorValues = new Map();

  const sampled = Array.from(elements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }).slice(0, 400);

  sampled.forEach(el => {
    const style = window.getComputedStyle(el);
    const colors = [style.color, style.backgroundColor, style.borderColor].filter(c => c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent');

    colors.forEach(c => {
      const rgb = parseRGB(c);
      if (!rgb) return;
      const hsl = rgbToHsl(rgb.r, rgb.g, rgb.b);
      if (hsl.s < 10) return;

      const hueGroup = Math.round(hsl.h / 15) * 15;
      hueSet.add(hueGroup);

      const key = `${hueGroup}`;
      if (!colorValues.has(key)) {
        colorValues.set(key, { hue: hueGroup, samples: [] });
      }
      colorValues.get(key).samples.push({ rgb: `rgb(${rgb.r},${rgb.g},${rgb.b})`, hsl });
    });
  });

  const hues = [...hueSet].sort((a, b) => a - b);

  let harmonyType = 'none';
  let harmonyScore = 0;

  if (hues.length === 0) {
    harmonyType = 'achromatic';
    harmonyScore = 80;
  } else if (hues.length === 1) {
    harmonyType = 'monochromatic';
    harmonyScore = 100;
  } else if (hues.length === 2) {
    const diff = Math.min(Math.abs(hues[1] - hues[0]), 360 - Math.abs(hues[1] - hues[0]));
    if (diff < 40) {
      harmonyType = 'analogous';
      harmonyScore = 95;
    } else if (diff >= 150 && diff <= 210) {
      harmonyType = 'complementary';
      harmonyScore = 90;
    } else {
      harmonyType = 'custom-duo';
      harmonyScore = 70;
    }
  } else if (hues.length === 3) {
    const diffs = [];
    for (let i = 0; i < hues.length; i++) {
      for (let j = i + 1; j < hues.length; j++) {
        diffs.push(Math.min(Math.abs(hues[j] - hues[i]), 360 - Math.abs(hues[j] - hues[i])));
      }
    }
    const avgDiff = diffs.reduce((a, b) => a + b, 0) / diffs.length;
    if (avgDiff > 100 && avgDiff < 140) {
      harmonyType = 'triadic';
      harmonyScore = 90;
    } else if (diffs.some(d => d < 40) && diffs.some(d => d > 140)) {
      harmonyType = 'split-complementary';
      harmonyScore = 85;
    } else if (diffs.every(d => d < 60)) {
      harmonyType = 'analogous';
      harmonyScore = 90;
    } else {
      harmonyType = 'custom-triad';
      harmonyScore = 65;
    }
  } else if (hues.length <= 5) {
    const allClose = hues.every((h, i) => i === 0 || Math.min(Math.abs(h - hues[i - 1]), 360 - Math.abs(h - hues[i - 1])) < 50);
    if (allClose) {
      harmonyType = 'analogous-extended';
      harmonyScore = 80;
    } else {
      harmonyType = 'custom-palette';
      harmonyScore = 60;
    }
  } else {
    harmonyType = 'too-many-hues';
    harmonyScore = Math.max(0, 50 - (hues.length - 5) * 8);
  }

  const issues = [];
  if (hues.length > 6) {
    issues.push({
      type: 'excessive-hues',
      count: hues.length,
      hues,
      message: `${hues.length} distinct hue groups detected. Limit to 3-5 hues for cohesive palette.`
    });
  }

  return {
    uniqueHueGroups: hues.length,
    hues,
    harmonyType,
    harmonyScore,
    colorGroups: [...colorValues.entries()].slice(0, 10).map(([key, data]) => ({
      hue: data.hue,
      sampleCount: data.samples.length,
      sample: data.samples[0].rgb
    })),
    issues
  };
})()
```

### 7.3 Check Semantic Color Consistency

```javascript
(() => {
  function parseRGB(color) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h, s, l = (max + min) / 2;
    if (max === min) { h = s = 0; }
    else {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
        case g: h = ((b - r) / d + 2) / 6; break;
        case b: h = ((r - g) / d + 4) / 6; break;
      }
    }
    return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
  }

  const semanticSelectors = {
    error: {
      selectors: '[class*="error"], [class*="Error"], [class*="danger"], [class*="Danger"], [class*="destructive"], [class*="invalid"], [aria-invalid="true"], .text-red, [class*="text-red"], [class*="bg-red"]',
      expectedHue: { min: 340, max: 20 }
    },
    success: {
      selectors: '[class*="success"], [class*="Success"], [class*="valid"], [class*="complete"], .text-green, [class*="text-green"], [class*="bg-green"]',
      expectedHue: { min: 90, max: 160 }
    },
    warning: {
      selectors: '[class*="warning"], [class*="Warning"], [class*="caution"], .text-yellow, [class*="text-yellow"], [class*="text-amber"], [class*="bg-yellow"], [class*="bg-amber"]',
      expectedHue: { min: 30, max: 55 }
    },
    info: {
      selectors: '[class*="info"], [class*="Info"], [class*="notice"], .text-blue, [class*="text-blue"], [class*="bg-blue"]',
      expectedHue: { min: 195, max: 250 }
    }
  };

  const results = {};
  const issues = [];

  for (const [semantic, config] of Object.entries(semanticSelectors)) {
    const elements = document.querySelectorAll(config.selectors);
    if (elements.length === 0) {
      results[semantic] = { found: false, count: 0 };
      continue;
    }

    const colors = new Set();
    const colorDetails = [];

    elements.forEach(el => {
      const style = window.getComputedStyle(el);
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;

      [style.color, style.backgroundColor, style.borderColor].forEach(c => {
        if (!c || c === 'rgba(0, 0, 0, 0)' || c === 'transparent') return;
        const rgb = parseRGB(c);
        if (!rgb) return;
        const hsl = rgbToHsl(rgb.r, rgb.g, rgb.b);
        if (hsl.s < 15) return;

        const colorStr = `rgb(${rgb.r},${rgb.g},${rgb.b})`;
        colors.add(colorStr);
        colorDetails.push({ color: colorStr, hsl });
      });
    });

    const uniqueColors = [...colors];
    const isConsistent = uniqueColors.length <= 2;

    let hueMatch = true;
    colorDetails.forEach(cd => {
      const h = cd.hsl.h;
      if (config.expectedHue.min > config.expectedHue.max) {
        hueMatch = hueMatch && (h >= config.expectedHue.min || h <= config.expectedHue.max);
      } else {
        hueMatch = hueMatch && (h >= config.expectedHue.min && h <= config.expectedHue.max);
      }
    });

    results[semantic] = {
      found: true,
      count: elements.length,
      uniqueColors: uniqueColors.slice(0, 5),
      isConsistent,
      hueMatchesExpectation: hueMatch
    };

    if (!isConsistent) {
      issues.push({
        type: 'semantic-inconsistency',
        semantic,
        colorCount: uniqueColors.length,
        colors: uniqueColors.slice(0, 4),
        message: `${semantic} semantic uses ${uniqueColors.length} different colors: ${uniqueColors.slice(0, 3).join(', ')}. Should use a single color.`
      });
    }
    if (!hueMatch && colorDetails.length > 0) {
      issues.push({
        type: 'semantic-hue-mismatch',
        semantic,
        message: `${semantic} elements use unexpected hue. Expected hue range ${config.expectedHue.min}-${config.expectedHue.max} degrees.`
      });
    }
  }

  const semanticScore = Object.values(results).filter(r => r.found && r.isConsistent && r.hueMatchesExpectation).length;
  const semanticTotal = Object.values(results).filter(r => r.found).length;

  return {
    semanticsFound: semanticTotal,
    semanticConsistencyScore: semanticTotal > 0 ? Math.round((semanticScore / semanticTotal) * 100) : 100,
    results,
    issues
  };
})()
```

### 7.4 Check Dark Mode Support

```javascript
(() => {
  function parseRGB(color) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function luminance(r, g, b) {
    const [rs, gs, bs] = [r, g, b].map(c => {
      c = c / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
  }

  function contrastRatio(l1, l2) {
    const lighter = Math.max(l1, l2);
    const darker = Math.min(l1, l2);
    return Math.round(((lighter + 0.05) / (darker + 0.05)) * 100) / 100;
  }

  const hasDarkClass = document.documentElement.classList.contains('dark') ||
                       document.body.classList.contains('dark');
  const currentScheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';

  const darkStylesheets = Array.from(document.styleSheets).some(sheet => {
    try {
      return Array.from(sheet.cssRules || []).some(rule =>
        rule.cssText && (rule.cssText.includes('prefers-color-scheme: dark') || rule.cssText.includes('.dark'))
      );
    } catch { return false; }
  });

  const darkToggle = document.querySelector(
    '[class*="theme"], [class*="Theme"], [class*="dark-mode"], [class*="dark-toggle"], ' +
    '[aria-label*="theme"], [aria-label*="dark"], [aria-label*="mode"], ' +
    'button[class*="sun"], button[class*="moon"]'
  );

  const hasDarkModeSupport = hasDarkClass || darkStylesheets || darkToggle !== null;

  const textElements = document.querySelectorAll('h1, h2, h3, p, span, a, li, label, button');
  const contrastResults = [];

  Array.from(textElements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }).slice(0, 50).forEach(el => {
    const style = window.getComputedStyle(el);
    const fgColor = parseRGB(style.color);
    if (!fgColor) return;

    let bgEl = el;
    let bgColor = null;
    while (bgEl && bgEl !== document.documentElement) {
      const bgStyle = window.getComputedStyle(bgEl);
      const bg = parseRGB(bgStyle.backgroundColor);
      if (bg && bgStyle.backgroundColor !== 'rgba(0, 0, 0, 0)') {
        bgColor = bg;
        break;
      }
      bgEl = bgEl.parentElement;
    }
    if (!bgColor) bgColor = { r: 255, g: 255, b: 255 };

    const fgLum = luminance(fgColor.r, fgColor.g, fgColor.b);
    const bgLum = luminance(bgColor.r, bgColor.g, bgColor.b);
    const ratio = contrastRatio(fgLum, bgLum);

    const fontSize = parseFloat(style.fontSize) || 16;
    const isLargeText = fontSize >= 24 || (fontSize >= 18.66 && parseInt(style.fontWeight) >= 700);
    const requiredAA = isLargeText ? 3 : 4.5;
    const passesAA = ratio >= requiredAA;

    contrastResults.push({
      text: (el.textContent || '').trim().substring(0, 30),
      fg: `rgb(${fgColor.r},${fgColor.g},${fgColor.b})`,
      bg: `rgb(${bgColor.r},${bgColor.g},${bgColor.b})`,
      ratio,
      passesAA,
      fontSize: Math.round(fontSize),
      isLargeText
    });
  });

  const passingContrast = contrastResults.filter(r => r.passesAA).length;
  const failingContrast = contrastResults.filter(r => !r.passesAA).length;

  const issues = [];
  if (!hasDarkModeSupport) {
    issues.push({
      type: 'no-dark-mode',
      message: 'No dark mode support detected. No prefers-color-scheme media query, no .dark class, and no theme toggle found.'
    });
  }
  contrastResults.filter(r => !r.passesAA).slice(0, 5).forEach(r => {
    issues.push({
      type: 'contrast-failure',
      text: r.text,
      ratio: r.ratio,
      required: r.isLargeText ? 3 : 4.5,
      message: `"${r.text}" has contrast ratio ${r.ratio} (need ${r.isLargeText ? 3 : 4.5}). FG: ${r.fg}, BG: ${r.bg}`
    });
  });

  return {
    currentScheme,
    hasDarkModeSupport,
    hasDarkClass,
    hasDarkStylesheets: darkStylesheets,
    hasDarkToggle: darkToggle !== null,
    contrastCheck: {
      total: contrastResults.length,
      passing: passingContrast,
      failing: failingContrast,
      passRate: contrastResults.length > 0 ? Math.round((passingContrast / contrastResults.length) * 100) : 100
    },
    sampleResults: contrastResults.filter(r => !r.passesAA).slice(0, 8),
    issues
  };
})()
```

### 7.5 Measure Unique Color Count

```javascript
(() => {
  function parseRGB(color) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h, s, l = (max + min) / 2;
    if (max === min) { h = s = 0; }
    else {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
        case g: h = ((b - r) / d + 2) / 6; break;
        case b: h = ((r - g) / d + 4) / 6; break;
      }
    }
    return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
  }

  const elements = document.querySelectorAll('*');
  const allColors = new Map();

  const sampled = Array.from(elements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }).slice(0, 500);

  sampled.forEach(el => {
    const style = window.getComputedStyle(el);
    const props = ['color', 'backgroundColor', 'borderColor', 'borderTopColor', 'borderBottomColor', 'outlineColor'];

    props.forEach(prop => {
      const value = style[prop];
      if (!value || value === 'rgba(0, 0, 0, 0)' || value === 'transparent' || value === 'currentcolor') return;

      const rgb = parseRGB(value);
      if (!rgb) return;

      const key = `${rgb.r},${rgb.g},${rgb.b}`;
      if (!allColors.has(key)) {
        allColors.set(key, {
          rgb: `rgb(${rgb.r},${rgb.g},${rgb.b})`,
          hsl: rgbToHsl(rgb.r, rgb.g, rgb.b),
          count: 0,
          properties: new Set()
        });
      }
      allColors.get(key).count++;
      allColors.get(key).properties.add(prop);
    });

    const svgEls = el.querySelectorAll ? el.querySelectorAll('path, rect, circle, polygon, line') : [];
    svgEls.forEach(svg => {
      const fill = svg.getAttribute('fill');
      const stroke = svg.getAttribute('stroke');
      [fill, stroke].forEach(val => {
        if (!val || val === 'none' || val === 'transparent' || val === 'currentColor') return;
        const temp = document.createElement('div');
        temp.style.color = val;
        temp.style.display = 'none';
        document.body.appendChild(temp);
        const computed = window.getComputedStyle(temp).color;
        document.body.removeChild(temp);
        const rgb = parseRGB(computed);
        if (!rgb) return;
        const key = `${rgb.r},${rgb.g},${rgb.b}`;
        if (!allColors.has(key)) {
          allColors.set(key, { rgb: `rgb(${rgb.r},${rgb.g},${rgb.b})`, hsl: rgbToHsl(rgb.r, rgb.g, rgb.b), count: 0, properties: new Set() });
        }
        allColors.get(key).count++;
        allColors.get(key).properties.add('svg');
      });
    });
  });

  const colorList = [...allColors.values()].map(c => ({
    rgb: c.rgb,
    hsl: c.hsl,
    count: c.count,
    properties: [...c.properties]
  })).sort((a, b) => b.count - a.count);

  const hueGroups = {};
  colorList.forEach(c => {
    const hueKey = c.hsl.s < 10 ? 'neutral' : `hue-${Math.round(c.hsl.h / 30) * 30}`;
    if (!hueGroups[hueKey]) hueGroups[hueKey] = [];
    hueGroups[hueKey].push(c);
  });

  const hueGroupCount = Object.keys(hueGroups).length;
  const issues = [];

  if (colorList.length > 30) {
    issues.push({
      type: 'too-many-unique-colors',
      count: colorList.length,
      message: `${colorList.length} unique color values found. Consider consolidating to a tighter palette.`
    });
  }
  if (hueGroupCount > 8) {
    issues.push({
      type: 'too-many-hue-groups',
      count: hueGroupCount,
      groups: Object.keys(hueGroups),
      message: `${hueGroupCount} distinct hue groups. Limit to 5-6 hue families for cohesion.`
    });
  }

  const nearDuplicates = [];
  for (let i = 0; i < colorList.length; i++) {
    for (let j = i + 1; j < Math.min(colorList.length, i + 20); j++) {
      const a = colorList[i].hsl;
      const b = colorList[j].hsl;
      const hueDiff = Math.min(Math.abs(a.h - b.h), 360 - Math.abs(a.h - b.h));
      if (hueDiff < 5 && Math.abs(a.s - b.s) < 8 && Math.abs(a.l - b.l) < 8 &&
          colorList[i].rgb !== colorList[j].rgb) {
        nearDuplicates.push({
          color1: colorList[i].rgb,
          color2: colorList[j].rgb,
          hueDiff,
          satDiff: Math.abs(a.s - b.s),
          lightDiff: Math.abs(a.l - b.l)
        });
      }
    }
  }

  if (nearDuplicates.length > 3) {
    issues.push({
      type: 'near-duplicate-colors',
      count: nearDuplicates.length,
      examples: nearDuplicates.slice(0, 3),
      message: `${nearDuplicates.length} near-duplicate color pairs found. Consolidate similar colors to single tokens.`
    });
  }

  return {
    totalUniqueColors: colorList.length,
    hueGroupCount,
    hueGroups: Object.entries(hueGroups).map(([key, colors]) => ({
      hue: key,
      colorCount: colors.length,
      samples: colors.slice(0, 3).map(c => c.rgb)
    })),
    topColors: colorList.slice(0, 15),
    nearDuplicates: nearDuplicates.slice(0, 5),
    colorCountScore: colorList.length <= 20 ? 100 : Math.max(0, 100 - (colorList.length - 20) * 3),
    issues
  };
})()
```

### 7.6 Check Colorblind Safety

```javascript
(() => {
  function parseRGB(color) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function simulateProtanopia(r, g, b) {
    return {
      r: Math.round(0.567 * r + 0.433 * g + 0.000 * b),
      g: Math.round(0.558 * r + 0.442 * g + 0.000 * b),
      b: Math.round(0.000 * r + 0.242 * g + 0.758 * b)
    };
  }

  function simulateDeuteranopia(r, g, b) {
    return {
      r: Math.round(0.625 * r + 0.375 * g + 0.000 * b),
      g: Math.round(0.700 * r + 0.300 * g + 0.000 * b),
      b: Math.round(0.000 * r + 0.300 * g + 0.700 * b)
    };
  }

  function colorDistance(c1, c2) {
    return Math.sqrt(
      Math.pow(c1.r - c2.r, 2) +
      Math.pow(c1.g - c2.g, 2) +
      Math.pow(c1.b - c2.b, 2)
    );
  }

  const semanticPairs = [
    {
      name: 'success-vs-danger',
      selector1: '[class*="success"], [class*="Success"], [class*="bg-green"]',
      selector2: '[class*="error"], [class*="Error"], [class*="danger"], [class*="Danger"], [class*="bg-red"]'
    },
    {
      name: 'primary-vs-secondary',
      selector1: '[class*="primary"], [class*="Primary"], button.primary',
      selector2: '[class*="secondary"], [class*="Secondary"], button.secondary'
    },
    {
      name: 'active-vs-inactive',
      selector1: '[class*="active"], [aria-selected="true"], [aria-current]',
      selector2: '[class*="inactive"], [class*="disabled"], [aria-selected="false"]'
    },
    {
      name: 'link-vs-text',
      selector1: 'a',
      selector2: 'p, span'
    }
  ];

  const results = [];
  const issues = [];

  semanticPairs.forEach(({ name, selector1, selector2 }) => {
    const el1 = document.querySelector(selector1);
    const el2 = document.querySelector(selector2);
    if (!el1 || !el2) return;

    const style1 = window.getComputedStyle(el1);
    const style2 = window.getComputedStyle(el2);

    const getRelevantColor = (style) => {
      const bg = parseRGB(style.backgroundColor);
      if (bg && style.backgroundColor !== 'rgba(0, 0, 0, 0)' && style.backgroundColor !== 'transparent') return bg;
      return parseRGB(style.color);
    };

    const color1 = getRelevantColor(style1);
    const color2 = getRelevantColor(style2);
    if (!color1 || !color2) return;

    const normalDist = Math.round(colorDistance(color1, color2));

    const prot1 = simulateProtanopia(color1.r, color1.g, color1.b);
    const prot2 = simulateProtanopia(color2.r, color2.g, color2.b);
    const protDist = Math.round(colorDistance(prot1, prot2));

    const deut1 = simulateDeuteranopia(color1.r, color1.g, color1.b);
    const deut2 = simulateDeuteranopia(color2.r, color2.g, color2.b);
    const deutDist = Math.round(colorDistance(deut1, deut2));

    const protSafe = protDist > 40;
    const deutSafe = deutDist > 40;

    const entry = {
      pair: name,
      color1: `rgb(${color1.r},${color1.g},${color1.b})`,
      color2: `rgb(${color2.r},${color2.g},${color2.b})`,
      normalDistance: normalDist,
      protanopiaDistance: protDist,
      deuteranopiaDistance: deutDist,
      protanopiaSafe: protSafe,
      deuteranopiaSafe: deutSafe,
      safe: protSafe && deutSafe
    };

    results.push(entry);

    if (!entry.safe) {
      issues.push({
        type: 'colorblind-conflict',
        pair: name,
        protDist,
        deutDist,
        message: `${name} pair becomes hard to distinguish under ${!protSafe ? 'protanopia' : ''}${!protSafe && !deutSafe ? ' and ' : ''}${!deutSafe ? 'deuteranopia' : ''} (distance: prot=${protDist}, deut=${deutDist}, need >40).`
      });
    }
  });

  const safeCount = results.filter(r => r.safe).length;
  const colorblindScore = results.length > 0
    ? Math.round((safeCount / results.length) * 100)
    : 100;

  return {
    pairsChecked: results.length,
    safePairs: safeCount,
    unsafePairs: results.length - safeCount,
    colorblindScore,
    results,
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Palette Cohesion**: Does the color palette feel cohesive and intentional? Do all colors feel like they belong to the same design system? Or are there colors that feel out of place, borrowed from a different design, or randomly chosen?

2. **60-30-10 Hierarchy**: Is the 60-30-10 ratio creating a clear visual hierarchy? Is there one dominant surface color (~60%), one secondary color (~30%), and accent colors used sparingly (~10%)? Or do too many colors compete for attention?

3. **Accent Purpose**: Are accent colors used sparingly and purposefully to draw attention to interactive elements, CTAs, and important state changes? Or are accent colors overused, diluting their impact?

4. **Dark Mode Quality**: If dark mode is present, does it feel like a first-class citizen? Are colors adapted (not just inverted)? Do images and illustrations work in both modes? Is contrast maintained? Or does dark mode feel like an afterthought?

5. **Brand and Emotional Alignment**: Is the palette emotionally aligned with the brand and purpose of the application? Does the color mood match the content (professional, playful, trustworthy, energetic)?

6. **Colorblind Accessibility**: Would a colorblind user miss any critical information conveyed solely through color? Are there secondary visual cues (icons, text labels, patterns) that supplement color coding?

7. **Color Noise**: Are there too many colors competing for attention? Does the palette feel controlled and minimal, or noisy and overwhelming? Can you count the distinct hue families on one hand?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Cohesive palette with <=5 hue families. Clear 60-30-10 distribution. Semantic colors consistent across all states (error=red, success=green, warning=amber). Dark mode with adapted colors (not inverted). All semantic pairs colorblind-safe. <=20 unique color values. |
| 4 | Good palette with minor semantic inconsistencies (1-2 states use wrong color). 60-30-10 roughly followed. Dark mode present with <=2 contrast issues. Most pairs colorblind-safe. <=30 unique colors. |
| 3 | Workable palette but too many hue families (6-8) or weak semantic mapping. Distribution unclear. Dark mode missing or has significant contrast issues. Near-duplicate colors detected. Some colorblind conflicts. |
| 2 | Inconsistent color usage across the page. No clear dominant/secondary/accent structure. >8 hue groups competing. Dark mode absent or broken. Semantic colors conflict (red used for both success and error). Multiple colorblind-unsafe pairs. |
| 1 | No color system. Hardcoded values everywhere. Colors feel random. No semantic consistency. No dark mode. >40 unique color values. Critical colorblind issues. |

## Common Fixes

### Fix: Establish color token system
```css
:root {
  /* Semantic tokens */
  --color-primary: hsl(220, 90%, 56%);
  --color-primary-hover: hsl(220, 90%, 48%);
  --color-secondary: hsl(250, 60%, 58%);
  --color-accent: hsl(35, 95%, 55%);

  /* Status tokens */
  --color-success: hsl(142, 71%, 45%);
  --color-warning: hsl(38, 92%, 50%);
  --color-error: hsl(0, 84%, 60%);
  --color-info: hsl(210, 80%, 55%);

  /* Neutral scale */
  --color-gray-50: hsl(220, 14%, 97%);
  --color-gray-100: hsl(220, 13%, 91%);
  --color-gray-200: hsl(220, 13%, 83%);
  --color-gray-300: hsl(220, 11%, 72%);
  --color-gray-400: hsl(220, 9%, 56%);
  --color-gray-500: hsl(220, 8%, 42%);
  --color-gray-600: hsl(220, 10%, 34%);
  --color-gray-700: hsl(220, 13%, 26%);
  --color-gray-800: hsl(220, 18%, 18%);
  --color-gray-900: hsl(220, 20%, 10%);

  /* Surface tokens */
  --color-bg: var(--color-gray-50);
  --color-surface: white;
  --color-text: var(--color-gray-900);
  --color-text-secondary: var(--color-gray-500);
  --color-border: var(--color-gray-200);
}
```

### Fix: Add dark mode tokens
```css
.dark, [data-theme="dark"] {
  --color-bg: var(--color-gray-900);
  --color-surface: var(--color-gray-800);
  --color-text: var(--color-gray-50);
  --color-text-secondary: var(--color-gray-400);
  --color-border: var(--color-gray-700);

  --color-primary: hsl(220, 90%, 65%);
  --color-error: hsl(0, 84%, 70%);
  --color-success: hsl(142, 71%, 55%);
  --color-warning: hsl(38, 92%, 60%);
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    /* Same dark values as above */
  }
}
```

### Fix: Replace hardcoded colors with tokens
```css
/* Before: hardcoded */
.error-message { color: #e53e3e; }
.success-badge { background: #38a169; }

/* After: tokenized */
.error-message { color: var(--color-error); }
.success-badge { background: var(--color-success); }
```

**Tailwind equivalent:**
```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: 'hsl(var(--color-primary) / <alpha-value>)',
        error: 'hsl(var(--color-error) / <alpha-value>)',
        success: 'hsl(var(--color-success) / <alpha-value>)',
      }
    }
  }
}
```

### Fix: Consolidate near-duplicate colors
```css
/* Before: 3 slightly different grays */
.text-muted { color: #718096; }
.text-light { color: #6c757d; }
.text-subtle { color: #6e7681; }

/* After: single token */
.text-muted,
.text-light,
.text-subtle { color: var(--color-text-secondary); }
```

### Fix: Add colorblind-safe secondary cues
```css
/* Don't rely on color alone for status */
.status-success::before { content: "\2713"; margin-right: 0.5rem; } /* checkmark */
.status-error::before { content: "\2717"; margin-right: 0.5rem; }   /* cross */
.status-warning::before { content: "\26A0"; margin-right: 0.5rem; } /* warning sign */
```

**Tailwind + icon approach:**
```html
<span class="text-green-600 flex items-center gap-1">
  <svg><!-- checkmark icon --></svg> Success
</span>
<span class="text-red-600 flex items-center gap-1">
  <svg><!-- x icon --></svg> Error
</span>
```
