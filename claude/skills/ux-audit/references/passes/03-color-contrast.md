# Pass 3: Color & Contrast

## Tier 1: Automated Checks

### 3.1 WCAG Contrast Ratio Checks

```javascript
(() => {
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
    return (lighter + 0.05) / (darker + 0.05);
  }

  function parseColor(color) {
    const temp = document.createElement('div');
    temp.style.color = color;
    temp.style.display = 'none';
    document.body.appendChild(temp);
    const computed = window.getComputedStyle(temp).color;
    document.body.removeChild(temp);
    const match = computed.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function getEffectiveBg(el) {
    let current = el;
    while (current && current !== document.documentElement) {
      const style = window.getComputedStyle(current);
      const bg = style.backgroundColor;
      if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
        return parseColor(bg);
      }
      current = current.parentElement;
    }
    return { r: 255, g: 255, b: 255 };
  }

  const textElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, a, span, li, label, button, td, th, blockquote, figcaption');
  const results = [];
  const failures = [];
  let passCount = 0;
  let failCount = 0;

  const checked = new Set();

  textElements.forEach(el => {
    const text = (el.textContent || '').trim();
    if (text.length < 2) return;

    const style = window.getComputedStyle(el);
    const fgColor = parseColor(style.color);
    const bgColor = getEffectiveBg(el);
    if (!fgColor || !bgColor) return;

    const key = `${fgColor.r},${fgColor.g},${fgColor.b}-${bgColor.r},${bgColor.g},${bgColor.b}`;
    if (checked.has(key)) return;
    checked.add(key);

    const fgLum = luminance(fgColor.r, fgColor.g, fgColor.b);
    const bgLum = luminance(bgColor.r, bgColor.g, bgColor.b);
    const ratio = Math.round(contrastRatio(fgLum, bgLum) * 100) / 100;

    const fontSize = parseFloat(style.fontSize);
    const fontWeight = parseInt(style.fontWeight) || 400;
    const isLargeText = fontSize >= 24 || (fontSize >= 18.66 && fontWeight >= 700);

    const requiredAA = isLargeText ? 3 : 4.5;
    const requiredAAA = isLargeText ? 4.5 : 7;
    const passesAA = ratio >= requiredAA;
    const passesAAA = ratio >= requiredAAA;

    const result = {
      text: text.substring(0, 40),
      tag: el.tagName.toLowerCase(),
      foreground: `rgb(${fgColor.r}, ${fgColor.g}, ${fgColor.b})`,
      background: `rgb(${bgColor.r}, ${bgColor.g}, ${bgColor.b})`,
      ratio,
      isLargeText,
      requiredAA,
      passesAA,
      passesAAA
    };

    results.push(result);

    if (passesAA) {
      passCount++;
    } else {
      failCount++;
      failures.push(result);
    }
  });

  return {
    totalPairsTested: results.length,
    passCount,
    failCount,
    passRate: results.length > 0 ? Math.round((passCount / results.length) * 100) : 0,
    failures: failures.slice(0, 20),
    allResults: results.slice(0, 30)
  };
})()
```

### 3.2 Unique Color Count and Palette Analysis

```javascript
(() => {
  const elements = document.querySelectorAll('*');
  const colorSet = new Set();
  const bgColorSet = new Set();
  const borderColorSet = new Set();
  const colorUsage = {};

  function normalizeColor(color) {
    if (!color || color === 'transparent' || color === 'rgba(0, 0, 0, 0)') return null;
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return `rgb(${match[1]}, ${match[2]}, ${match[3]})`;
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

  const sampled = Array.from(elements).slice(0, 500);

  sampled.forEach(el => {
    const style = window.getComputedStyle(el);

    const fg = normalizeColor(style.color);
    const bg = normalizeColor(style.backgroundColor);
    const border = normalizeColor(style.borderColor);

    if (fg) {
      colorSet.add(fg);
      colorUsage[fg] = (colorUsage[fg] || 0) + 1;
    }
    if (bg) {
      bgColorSet.add(bg);
      colorUsage[bg] = (colorUsage[bg] || 0) + 1;
    }
    if (border) {
      borderColorSet.add(border);
    }
  });

  const allColors = [...new Set([...colorSet, ...bgColorSet])];
  const colorDetails = allColors.map(c => {
    const match = c.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
    if (!match) return null;
    const r = parseInt(match[1]);
    const g = parseInt(match[2]);
    const b = parseInt(match[3]);
    const hsl = rgbToHsl(r, g, b);
    const isNeutral = hsl.s < 10;
    return { rgb: c, hsl, isNeutral, usage: colorUsage[c] || 0 };
  }).filter(Boolean);

  const chromatic = colorDetails.filter(c => !c.isNeutral);
  const neutrals = colorDetails.filter(c => c.isNeutral);

  const hueGroups = {};
  chromatic.forEach(c => {
    const hueGroup = Math.round(c.hsl.h / 30) * 30;
    if (!hueGroups[hueGroup]) hueGroups[hueGroup] = [];
    hueGroups[hueGroup].push(c);
  });

  const distinctHues = Object.keys(hueGroups).length;

  const issues = [];
  if (distinctHues > 7) {
    issues.push({
      type: 'too-many-hues',
      count: distinctHues,
      message: `${distinctHues} distinct hue groups detected. Limit to 5 primary + 2 accent colors maximum.`
    });
  }

  if (chromatic.length > 12) {
    issues.push({
      type: 'too-many-chromatic-colors',
      count: chromatic.length,
      message: `${chromatic.length} unique chromatic colors used. Consider consolidating to a tighter palette.`
    });
  }

  return {
    totalUniqueColors: allColors.length,
    chromaticColors: chromatic.length,
    neutralColors: neutrals.length,
    distinctHueGroups: distinctHues,
    hueGroups: Object.fromEntries(Object.entries(hueGroups).map(([k, v]) => [k, v.length])),
    topColors: colorDetails.sort((a, b) => b.usage - a.usage).slice(0, 15),
    issues
  };
})()
```

### 3.3 Color-Only Information Detection

```javascript
(() => {
  const issues = [];

  const links = document.querySelectorAll('a');
  links.forEach(link => {
    const style = window.getComputedStyle(link);
    const hasUnderline = style.textDecorationLine.includes('underline');
    const hasBorder = parseFloat(style.borderBottomWidth) > 0;
    const hasIcon = link.querySelector('svg, img, i, [class*="icon"]');
    const isNav = link.closest('nav, [role="navigation"], header');

    if (!hasUnderline && !hasBorder && !hasIcon && !isNav) {
      const parentStyle = link.parentElement ? window.getComputedStyle(link.parentElement) : null;
      const parentColor = parentStyle ? parentStyle.color : '';
      const linkColor = style.color;

      if (parentColor && linkColor !== parentColor) {
        issues.push({
          type: 'color-only-link',
          text: (link.textContent || '').trim().substring(0, 40),
          href: (link.href || '').substring(0, 60),
          message: 'Link distinguished only by color. Add underline, icon, or other visual indicator.'
        });
      }
    }
  });

  const formFields = document.querySelectorAll('input, select, textarea');
  formFields.forEach(field => {
    const style = window.getComputedStyle(field);
    const ariaInvalid = field.getAttribute('aria-invalid');
    const hasErrorClass = field.className.match(/error|invalid|danger/i);
    const borderColor = style.borderColor;

    if ((ariaInvalid === 'true' || hasErrorClass) && borderColor) {
      const errorMsg = field.parentElement ? field.parentElement.querySelector('.error, [class*="error"], [role="alert"]') : null;
      const errorIcon = field.parentElement ? field.parentElement.querySelector('svg, [class*="icon"]') : null;

      if (!errorMsg && !errorIcon) {
        issues.push({
          type: 'color-only-error',
          fieldName: field.name || field.id || field.type,
          message: 'Form error indicated only by color change. Add an error message, icon, or both.'
        });
      }
    }
  });

  const statusElements = document.querySelectorAll('[class*="status"], [class*="badge"], [class*="tag"], [class*="chip"], [class*="label"]');
  statusElements.forEach(el => {
    const text = (el.textContent || '').trim();
    const hasIcon = el.querySelector('svg, img, i, [class*="icon"]');
    const hasAriaLabel = el.getAttribute('aria-label');

    if (!text && !hasIcon && !hasAriaLabel) {
      issues.push({
        type: 'color-only-status',
        classes: el.className.substring(0, 60),
        message: 'Status/badge element conveys meaning only through color. Add text or icon.'
      });
    }
  });

  return {
    colorOnlyLinks: issues.filter(i => i.type === 'color-only-link').length,
    colorOnlyErrors: issues.filter(i => i.type === 'color-only-error').length,
    colorOnlyStatuses: issues.filter(i => i.type === 'color-only-status').length,
    totalIssues: issues.length,
    issues: issues.slice(0, 20)
  };
})()
```

### 3.4 Semantic Color Consistency

```javascript
(() => {
  const semanticPatterns = {
    error: { selectors: '[class*="error"], [class*="danger"], [class*="invalid"], [role="alert"]', expectedHue: [0, 15] },
    success: { selectors: '[class*="success"], [class*="valid"], [class*="complete"]', expectedHue: [100, 150] },
    warning: { selectors: '[class*="warning"], [class*="caution"], [class*="warn"]', expectedHue: [30, 55] },
    info: { selectors: '[class*="info"], [class*="notice"], [class*="tip"]', expectedHue: [195, 230] }
  };

  function getHue(colorStr) {
    const match = colorStr.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
    if (!match) return null;
    let r = parseInt(match[1]) / 255;
    let g = parseInt(match[2]) / 255;
    let b = parseInt(match[3]) / 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    if (max === min) return null;
    const d = max - min;
    let h;
    switch (max) {
      case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
      case g: h = ((b - r) / d + 2) / 6; break;
      case b: h = ((r - g) / d + 4) / 6; break;
    }
    return Math.round(h * 360);
  }

  const results = {};
  const issues = [];

  for (const [semantic, config] of Object.entries(semanticPatterns)) {
    const elements = document.querySelectorAll(config.selectors);
    const colors = new Set();

    elements.forEach(el => {
      const style = window.getComputedStyle(el);
      const fg = style.color;
      const bg = style.backgroundColor;
      if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') colors.add(bg);
      if (fg) colors.add(fg);
    });

    const hues = [...colors].map(c => ({ color: c, hue: getHue(c) })).filter(c => c.hue !== null);

    const mismatched = hues.filter(c => {
      const [minHue, maxHue] = config.expectedHue;
      return c.hue < minHue || c.hue > maxHue;
    });

    results[semantic] = {
      elementCount: elements.length,
      uniqueColors: colors.size,
      hues: hues.map(h => ({ color: h.color, hue: h.hue })),
      mismatched: mismatched.length
    };

    if (mismatched.length > 0) {
      issues.push({
        type: 'semantic-color-mismatch',
        semantic,
        expectedHueRange: config.expectedHue,
        mismatchedColors: mismatched.slice(0, 5),
        message: `${semantic} elements use non-standard colors. Expected hue range ${config.expectedHue[0]}-${config.expectedHue[1]}, found mismatches.`
      });
    }

    const uniqueHues = [...new Set(hues.map(h => Math.round(h.hue / 10) * 10))];
    if (uniqueHues.length > 2 && elements.length > 2) {
      issues.push({
        type: 'inconsistent-semantic-color',
        semantic,
        hueVariations: uniqueHues,
        message: `${semantic} elements use ${uniqueHues.length} different hues. Use a single consistent color for each semantic meaning.`
      });
    }
  }

  return {
    semanticColorMap: results,
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Palette Cohesion**: Do all colors on the page feel like they belong to the same family? Look for rogue colors that break the palette. A cohesive palette uses colors from related hue families or a deliberate complementary/triadic scheme. Random one-off colors are a red flag.

2. **Emotional Alignment**: Does the color palette match the product's emotional intent? A health app should feel calming (blues, greens, soft tones). A children's product should feel energetic (bright primaries). A luxury brand should feel refined (deep tones, muted metallics, restrained accent usage). Rate the match between palette and purpose.

3. **Intentional Accent Usage**: Is there a clear accent color used sparingly for emphasis (CTAs, active states, key highlights)? Or is the accent color overused, diluting its power? The best designs use the accent on <10% of the page area. If the accent appears everywhere, nothing is emphasized.

4. **Dark/Light Mode Parity**: If the page has both modes, do they feel equally polished? Common dark mode failures: inverted grays that feel washed out, colored elements that are too vibrant on dark backgrounds, shadows that don't translate. If only one mode exists, evaluate whether the chosen mode is appropriate for the product.

5. **Contrast Comfort**: Beyond passing WCAG ratios, does the contrast feel comfortable for extended reading? Pure black on pure white can cause halation (glowing edges). Very low-contrast designs strain the eyes. The sweet spot is high enough for clarity, soft enough for comfort.

6. **Color Proportion (60-30-10 Rule)**: Does the page follow roughly 60% dominant color (usually background), 30% secondary color (cards, sections), and 10% accent color? This classic ratio creates visual balance. Rate how close the page comes to balanced color distribution.

7. **Colorblindness Resilience**: Beyond color-only information checks: would the overall page layout, hierarchy, and information architecture still be clear to someone with deuteranopia (red-green deficiency)? Are red and green used in close proximity (e.g., error/success states side by side)?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | 100% of text passes WCAG AA contrast (4.5:1 normal, 3:1 large). <=5 distinct hue groups + 2 accent colors. No color-only information. Semantic colors are consistent (red=error, green=success everywhere). Palette feels cohesive and emotionally appropriate. Dark/light modes equally polished. |
| 4 | >=95% of text passes WCAG AA. <=6 distinct hue groups. <=2 color-only information instances. Semantic colors mostly consistent with 1 deviation. Palette is cohesive with 1 rogue color. |
| 3 | >=85% of text passes WCAG AA. 7-8 distinct hue groups. 3-5 color-only instances. Some semantic color inconsistency. Palette has 2-3 colors that feel out of place. Accent color overused. |
| 2 | >=70% of text passes WCAG AA. >8 distinct hue groups — palette feels chaotic. Multiple color-only information issues. Error/success colors inconsistent. No clear accent strategy. |
| 1 | <70% of text passes WCAG AA. Colors appear randomly chosen. Color is the only indicator for critical information (links, errors, status). Semantic colors contradictory (green for errors, red for success). Uncomfortable contrast throughout. |

## Common Fixes

### Fix: Improve contrast on light backgrounds
```css
/* Before: Low-contrast gray text */
/* .text { color: #999; } */

/* After: WCAG AA-passing gray */
.text { color: #595959; } /* 7:1 ratio on white */
.text-secondary { color: #737373; } /* 4.6:1 ratio on white - AA for normal text */
```

**Tailwind equivalent:**
```html
<p class="text-gray-700"> <!-- replaces text-gray-400 -->
<p class="text-gray-600"> <!-- for secondary text -->
```

### Fix: Add non-color indicators to links
```css
/* Ensure links have underline OR other visual cue */
a:not(nav a) {
  text-decoration: underline;
  text-underline-offset: 2px;
  text-decoration-thickness: 1px;
}

a:hover {
  text-decoration-thickness: 2px;
}
```

**Tailwind equivalent:**
```html
<a class="underline underline-offset-2 decoration-1 hover:decoration-2">
```

### Fix: Consolidate color palette
```css
:root {
  /* Primary palette */
  --color-primary: #2563eb;
  --color-primary-light: #3b82f6;
  --color-primary-dark: #1d4ed8;

  /* Semantic colors */
  --color-error: #dc2626;
  --color-success: #16a34a;
  --color-warning: #d97706;
  --color-info: #2563eb;

  /* Neutrals */
  --color-text: #1f2937;
  --color-text-secondary: #6b7280;
  --color-bg: #ffffff;
  --color-bg-secondary: #f9fafb;
  --color-border: #e5e7eb;
}
```

### Fix: Add icon + text to error states
```css
.error-message::before {
  content: '⚠';
  margin-right: 0.5rem;
  font-size: 1em;
}

.error-message {
  color: var(--color-error);
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
```

### Fix: Comfortable text contrast (anti-halation)
```css
body {
  color: #1a1a2e; /* Slightly warm dark instead of pure black */
  background-color: #fafafa; /* Slightly warm instead of pure white */
}

/* Dark mode */
@media (prefers-color-scheme: dark) {
  body {
    color: #e0e0e0; /* Not pure white */
    background-color: #121212; /* Not pure black */
  }
}
```
