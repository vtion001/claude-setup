# Pass 8: Type System

Evaluates whether the UI uses a coherent typographic system with a consistent scale ratio, strong vertical rhythm, optimal line lengths, clear heading hierarchy, sensible font pairings, fluid sizing, and performant font loading.

## Tier 0: Code Analysis

Before launching the browser, analyze the source code for typographic architecture:

1. **Font definitions** — Search for `font-family` declarations, `@font-face` rules, Google Fonts `<link>` imports, or local font files (woff2, woff, ttf, otf). Identify primary (body), secondary (headings), and monospace font stacks.
2. **Type scale ratio** — Collect all `font-size` values from CSS/Tailwind. Calculate ratios between consecutive sizes. Identify closest standard ratio: minor second (1.067), major second (1.125), minor third (1.2), major third (1.25), perfect fourth (1.333), augmented fourth (1.414), perfect fifth (1.5), golden ratio (1.618).
3. **Font-display property** — Check `@font-face` blocks for `font-display` value. Should be `swap` or `optional`. Flag `block` (causes FOIT) or missing `font-display`.
4. **Fluid typography** — Check for `clamp()` usage in font-size declarations: `font-size: clamp(min, preferred, max)`. Also check for responsive `font-size` changes via media queries.
5. **Font file formats** — Check font files served: `woff2` preferred, `woff` acceptable, `ttf`/`otf` only as fallbacks. Check for `<link rel="preload" as="font">` tags.
6. **Font-weight combinations** — Count unique `font-family` + `font-weight` combinations loaded. Should be <=6 total to avoid performance issues. Flag if loading 4+ weights of a single family.
7. **Minimum font sizes** — Search for `font-size` values below `14px` (or `0.875rem`). Only captions, labels, and footnotes should use small sizes. Body text below `14px` is a readability issue.

## Tier 1: Automated Browser Checks

### 8.1 Detect Type Scale

```javascript
(() => {
  const textElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, a, li, label, button, td, th, blockquote, figcaption, [class*="text"], [class*="title"], [class*="heading"], [class*="body"], [class*="caption"]');

  const fontSizes = new Map();

  Array.from(textElements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && (el.textContent || '').trim().length > 0;
  }).slice(0, 300).forEach(el => {
    const style = window.getComputedStyle(el);
    const size = Math.round(parseFloat(style.fontSize) * 10) / 10;
    if (!fontSizes.has(size)) {
      fontSizes.set(size, { size, count: 0, tags: new Set(), samples: [] });
    }
    const entry = fontSizes.get(size);
    entry.count++;
    entry.tags.add(el.tagName.toLowerCase());
    if (entry.samples.length < 2) {
      entry.samples.push((el.textContent || '').trim().substring(0, 40));
    }
  });

  const sizes = [...fontSizes.values()]
    .map(v => ({ ...v, tags: [...v.tags] }))
    .sort((a, b) => a.size - b.size);

  const sizeValues = sizes.map(s => s.size).filter(s => s >= 10);

  const ratios = [];
  for (let i = 0; i < sizeValues.length - 1; i++) {
    const ratio = Math.round((sizeValues[i + 1] / sizeValues[i]) * 1000) / 1000;
    if (ratio > 1.01 && ratio < 3) {
      ratios.push({
        from: sizeValues[i],
        to: sizeValues[i + 1],
        ratio
      });
    }
  }

  const knownScales = {
    'minor-second': 1.067,
    'major-second': 1.125,
    'minor-third': 1.2,
    'major-third': 1.25,
    'perfect-fourth': 1.333,
    'augmented-fourth': 1.414,
    'perfect-fifth': 1.5,
    'golden-ratio': 1.618
  };

  const ratioValues = ratios.map(r => r.ratio);
  const avgRatio = ratioValues.length > 0
    ? Math.round((ratioValues.reduce((a, b) => a + b, 0) / ratioValues.length) * 1000) / 1000
    : 0;

  let closestScale = 'custom';
  let closestDistance = Infinity;
  for (const [name, target] of Object.entries(knownScales)) {
    const dist = Math.abs(avgRatio - target);
    if (dist < closestDistance) {
      closestDistance = dist;
      closestScale = name;
    }
  }

  const scaleAdherence = ratioValues.length > 0
    ? Math.round((ratioValues.filter(r => Math.abs(r - knownScales[closestScale]) / knownScales[closestScale] < 0.15).length / ratioValues.length) * 100)
    : 0;

  const issues = [];
  if (sizes.length > 12) {
    issues.push({
      type: 'too-many-sizes',
      count: sizes.length,
      message: `${sizes.length} unique font sizes detected. A disciplined type scale should have 6-10 sizes.`
    });
  }
  if (scaleAdherence < 40 && ratios.length > 2) {
    issues.push({
      type: 'inconsistent-scale',
      adherence: scaleAdherence,
      message: `Only ${scaleAdherence}% of size steps follow the ${closestScale} ratio. Scale feels arbitrary.`
    });
  }

  const smallSizes = sizes.filter(s => s.size < 14);
  if (smallSizes.length > 0) {
    const bodySmall = smallSizes.filter(s => s.tags.includes('p') || s.tags.includes('li') || s.tags.includes('span'));
    if (bodySmall.length > 0) {
      issues.push({
        type: 'small-body-text',
        sizes: bodySmall.map(s => s.size),
        message: `Body text at ${bodySmall.map(s => s.size + 'px').join(', ')} is below 14px minimum for readability.`
      });
    }
  }

  return {
    uniqueSizeCount: sizes.length,
    sizes,
    ratios: ratios.slice(0, 15),
    averageRatio: avgRatio,
    closestNamedScale: closestScale,
    closestScaleValue: knownScales[closestScale],
    scaleAdherence,
    issues
  };
})()
```

### 8.2 Measure Vertical Rhythm

```javascript
(() => {
  const bodyStyle = window.getComputedStyle(document.body);
  const bodyFontSize = parseFloat(bodyStyle.fontSize) || 16;
  const bodyLineHeight = parseFloat(bodyStyle.lineHeight);
  const baseUnit = bodyLineHeight > 0 && bodyLineHeight < 100 ? bodyLineHeight : bodyFontSize * 1.5;

  const textElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, li, blockquote, figcaption, label, td, th');
  const rhythmChecks = [];
  let adherentLineHeights = 0;
  let totalLineHeights = 0;
  let adherentSpacings = 0;
  let totalSpacings = 0;

  const sampled = Array.from(textElements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }).slice(0, 100);

  sampled.forEach(el => {
    const style = window.getComputedStyle(el);
    const lineHeight = parseFloat(style.lineHeight);
    const marginTop = parseFloat(style.marginTop) || 0;
    const marginBottom = parseFloat(style.marginBottom) || 0;
    const paddingTop = parseFloat(style.paddingTop) || 0;
    const paddingBottom = parseFloat(style.paddingBottom) || 0;

    if (lineHeight > 0 && lineHeight < 200) {
      totalLineHeights++;
      const remainder = lineHeight % baseUnit;
      const isMultiple = remainder < 2 || (baseUnit - remainder) < 2;
      if (isMultiple) adherentLineHeights++;
    }

    [marginTop, marginBottom, paddingTop, paddingBottom].forEach(spacing => {
      if (spacing > 2) {
        totalSpacings++;
        const remainder = spacing % baseUnit;
        const isMultiple = remainder < 2 || (baseUnit - remainder) < 2;
        if (isMultiple) adherentSpacings++;
      }
    });

    rhythmChecks.push({
      tag: el.tagName.toLowerCase(),
      text: (el.textContent || '').trim().substring(0, 30),
      fontSize: Math.round(parseFloat(style.fontSize)),
      lineHeight: Math.round(lineHeight * 10) / 10,
      lineHeightRatio: Math.round((lineHeight / parseFloat(style.fontSize)) * 100) / 100,
      marginTop: Math.round(marginTop),
      marginBottom: Math.round(marginBottom),
      isLineHeightAligned: lineHeight > 0 ? ((lineHeight % baseUnit < 2) || ((baseUnit - lineHeight % baseUnit) < 2)) : false
    });
  });

  const lineHeightAdherence = totalLineHeights > 0
    ? Math.round((adherentLineHeights / totalLineHeights) * 100)
    : 0;
  const spacingAdherence = totalSpacings > 0
    ? Math.round((adherentSpacings / totalSpacings) * 100)
    : 0;
  const overallRhythm = Math.round((lineHeightAdherence + spacingAdherence) / 2);

  const lineHeightRatios = rhythmChecks.map(r => r.lineHeightRatio).filter(r => r > 0);
  const uniqueLineHeightRatios = [...new Set(lineHeightRatios.map(r => Math.round(r * 100) / 100))];

  const issues = [];
  if (overallRhythm < 40) {
    issues.push({
      type: 'weak-vertical-rhythm',
      score: overallRhythm,
      baseUnit: Math.round(baseUnit),
      message: `Vertical rhythm score is ${overallRhythm}%. Line-heights and spacings are not multiples of the base unit (${Math.round(baseUnit)}px).`
    });
  }

  const badLineHeights = rhythmChecks.filter(r => r.lineHeightRatio < 1.2 || r.lineHeightRatio > 2.0);
  if (badLineHeights.length > 0) {
    issues.push({
      type: 'extreme-line-heights',
      count: badLineHeights.length,
      examples: badLineHeights.slice(0, 3).map(r => `${r.tag}: ${r.lineHeightRatio}`),
      message: `${badLineHeights.length} elements have line-height ratios outside 1.2-2.0 range.`
    });
  }

  return {
    baseUnit: Math.round(baseUnit * 10) / 10,
    bodyFontSize,
    lineHeightAdherence,
    spacingAdherence,
    overallRhythmScore: overallRhythm,
    uniqueLineHeightRatios,
    elementsChecked: rhythmChecks.length,
    details: rhythmChecks.slice(0, 15),
    issues
  };
})()
```

### 8.3 Check Line Length

```javascript
(() => {
  const textContainers = document.querySelectorAll('p, li, blockquote, td, [class*="text"], [class*="body"], [class*="content"], [class*="description"], [class*="paragraph"]');
  const results = [];
  const issues = [];

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');

  const sampled = Array.from(textContainers).filter(el => {
    const rect = el.getBoundingClientRect();
    const text = (el.textContent || '').trim();
    return rect.width > 0 && rect.height > 0 && text.length > 20;
  }).slice(0, 50);

  sampled.forEach(el => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    const fontSize = parseFloat(style.fontSize) || 16;
    const fontFamily = style.fontFamily || 'sans-serif';

    ctx.font = `${style.fontWeight} ${fontSize}px ${fontFamily}`;

    const alphabetWidth = ctx.measureText('abcdefghijklmnopqrstuvwxyz').width;
    const avgCharWidth = alphabetWidth / 26;
    const charsPerLine = Math.round(rect.width / avgCharWidth);

    const isBodyText = ['p', 'li', 'blockquote'].includes(el.tagName.toLowerCase()) ||
                       (el.className || '').toString().includes('body') ||
                       (el.className || '').toString().includes('content');

    const entry = {
      tag: el.tagName.toLowerCase(),
      classes: (el.className || '').toString().substring(0, 40),
      containerWidth: Math.round(rect.width),
      fontSize: Math.round(fontSize),
      estimatedCharsPerLine: charsPerLine,
      isBodyText,
      inRange: charsPerLine >= 45 && charsPerLine <= 75,
      tooWide: charsPerLine > 75,
      tooNarrow: charsPerLine < 45
    };

    results.push(entry);

    if (isBodyText && charsPerLine > 85) {
      issues.push({
        type: 'line-too-long',
        ...entry,
        message: `${entry.tag} has ~${charsPerLine} characters per line. Max 75ch recommended for comfortable reading. Container is ${Math.round(rect.width)}px wide.`
      });
    }
    if (isBodyText && charsPerLine < 30 && rect.width > 200) {
      issues.push({
        type: 'line-too-short',
        ...entry,
        message: `${entry.tag} has ~${charsPerLine} characters per line. Min 45ch recommended. Text may feel choppy.`
      });
    }
  });

  const bodyTextResults = results.filter(r => r.isBodyText);
  const inRangeCount = bodyTextResults.filter(r => r.inRange).length;
  const lineLengthScore = bodyTextResults.length > 0
    ? Math.round((inRangeCount / bodyTextResults.length) * 100)
    : 100;

  return {
    totalContainersChecked: results.length,
    bodyTextContainers: bodyTextResults.length,
    inOptimalRange: inRangeCount,
    tooWide: bodyTextResults.filter(r => r.tooWide).length,
    tooNarrow: bodyTextResults.filter(r => r.tooNarrow).length,
    lineLengthScore,
    details: results.slice(0, 15),
    issues: issues.slice(0, 8)
  };
})()
```

### 8.4 Measure Typography Contrast Between Heading Levels

```javascript
(() => {
  const headingLevels = {};

  for (let level = 1; level <= 6; level++) {
    const headings = document.querySelectorAll(`h${level}, [role="heading"][aria-level="${level}"]`);
    const visibleHeadings = Array.from(headings).filter(el => {
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    });

    if (visibleHeadings.length === 0) continue;

    const styles = visibleHeadings.map(el => {
      const style = window.getComputedStyle(el);
      return {
        fontSize: Math.round(parseFloat(style.fontSize)),
        fontWeight: parseInt(style.fontWeight) || 400,
        lineHeight: Math.round(parseFloat(style.lineHeight)),
        letterSpacing: parseFloat(style.letterSpacing) || 0,
        textTransform: style.textTransform,
        color: style.color,
        fontFamily: style.fontFamily.split(',')[0].trim().replace(/"/g, '')
      };
    });

    const mode = styles[0];
    headingLevels[`h${level}`] = {
      count: visibleHeadings.length,
      fontSize: mode.fontSize,
      fontWeight: mode.fontWeight,
      lineHeight: mode.lineHeight,
      letterSpacing: Math.round(mode.letterSpacing * 10) / 10,
      textTransform: mode.textTransform,
      color: mode.color,
      fontFamily: mode.fontFamily,
      sample: (visibleHeadings[0].textContent || '').trim().substring(0, 50),
      allSizesConsistent: styles.every(s => s.fontSize === mode.fontSize)
    };
  }

  const levels = Object.keys(headingLevels).sort();
  const contrastIssues = [];
  const levelPairs = [];

  for (let i = 0; i < levels.length - 1; i++) {
    const upper = headingLevels[levels[i]];
    const lower = headingLevels[levels[i + 1]];
    const sizeRatio = Math.round((upper.fontSize / lower.fontSize) * 100) / 100;
    const weightDiff = upper.fontWeight - lower.fontWeight;
    const sizeDiff = upper.fontSize - lower.fontSize;

    const pair = {
      from: levels[i],
      to: levels[i + 1],
      sizeRatio,
      sizeDiff,
      weightDiff,
      upperSize: upper.fontSize,
      lowerSize: lower.fontSize,
      hasAdequateContrast: sizeRatio >= 1.15 || weightDiff >= 200
    };

    levelPairs.push(pair);

    if (sizeRatio < 1.15 && weightDiff < 100) {
      contrastIssues.push({
        type: 'weak-heading-contrast',
        ...pair,
        message: `${levels[i]} (${upper.fontSize}px) and ${levels[i + 1]} (${lower.fontSize}px) are too similar (ratio: ${sizeRatio}x, weight diff: ${weightDiff}). Need ratio >=1.15 or weight diff >=200.`
      });
    }

    if (upper.fontSize <= lower.fontSize) {
      contrastIssues.push({
        type: 'inverted-heading-hierarchy',
        ...pair,
        message: `${levels[i]} (${upper.fontSize}px) is same size or smaller than ${levels[i + 1]} (${lower.fontSize}px). Heading sizes must descend.`
      });
    }
  }

  const hasStrongHierarchy = levelPairs.length > 0 && levelPairs.every(p => p.hasAdequateContrast);

  const inconsistentLevels = Object.entries(headingLevels)
    .filter(([_, data]) => !data.allSizesConsistent)
    .map(([level, data]) => level);

  if (inconsistentLevels.length > 0) {
    contrastIssues.push({
      type: 'inconsistent-same-level',
      levels: inconsistentLevels,
      message: `Heading levels ${inconsistentLevels.join(', ')} have inconsistent sizes within the same level.`
    });
  }

  return {
    headingLevelsFound: levels.length,
    headingLevels,
    levelPairs,
    hasStrongHierarchy,
    hierarchyScore: levelPairs.length > 0
      ? Math.round((levelPairs.filter(p => p.hasAdequateContrast).length / levelPairs.length) * 100)
      : 100,
    issues: contrastIssues
  };
})()
```

### 8.5 Check Font Loading Strategy

```javascript
(() => {
  const fontFaceRules = [];
  const issues = [];

  Array.from(document.styleSheets).forEach(sheet => {
    try {
      Array.from(sheet.cssRules || []).forEach(rule => {
        if (rule instanceof CSSFontFaceRule) {
          const src = rule.style.getPropertyValue('src') || '';
          const family = rule.style.getPropertyValue('font-family') || '';
          const display = rule.style.getPropertyValue('font-display') || 'auto';
          const weight = rule.style.getPropertyValue('font-weight') || 'normal';
          const style = rule.style.getPropertyValue('font-style') || 'normal';

          const hasWoff2 = src.includes('woff2');
          const hasWoff = src.includes('woff');
          const hasTtf = src.includes('.ttf');
          const hasOtf = src.includes('.otf');

          fontFaceRules.push({
            family: family.replace(/"/g, ''),
            weight,
            style,
            display,
            formats: {
              woff2: hasWoff2,
              woff: hasWoff,
              ttf: hasTtf,
              otf: hasOtf
            },
            isOptimal: display === 'swap' || display === 'optional'
          });
        }
      });
    } catch (e) { /* cross-origin stylesheet */ }
  });

  const preloadFonts = document.querySelectorAll('link[rel="preload"][as="font"]');
  const googleFonts = document.querySelectorAll('link[href*="fonts.googleapis.com"], link[href*="fonts.gstatic.com"]');

  const computedFonts = new Set();
  const textElements = document.querySelectorAll('h1, h2, h3, p, a, button, span, li, label');
  Array.from(textElements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }).slice(0, 100).forEach(el => {
    const style = window.getComputedStyle(el);
    const family = style.fontFamily.split(',')[0].trim().replace(/"/g, '');
    const weight = style.fontWeight;
    computedFonts.add(`${family}:${weight}`);
  });

  const uniqueFontCombinations = [...computedFonts];

  if (fontFaceRules.some(r => r.display === 'block')) {
    issues.push({
      type: 'font-display-block',
      message: 'font-display: block causes Flash of Invisible Text (FOIT). Use "swap" or "optional" instead.'
    });
  }

  const missingDisplay = fontFaceRules.filter(r => r.display === 'auto' || r.display === '');
  if (missingDisplay.length > 0) {
    issues.push({
      type: 'missing-font-display',
      count: missingDisplay.length,
      fonts: missingDisplay.map(r => r.family),
      message: `${missingDisplay.length} @font-face rules missing font-display property. Add font-display: swap.`
    });
  }

  const noWoff2 = fontFaceRules.filter(r => !r.formats.woff2 && (r.formats.ttf || r.formats.otf));
  if (noWoff2.length > 0) {
    issues.push({
      type: 'missing-woff2',
      count: noWoff2.length,
      fonts: noWoff2.map(r => r.family),
      message: `${noWoff2.length} fonts served without woff2 format. woff2 reduces font file size by ~30%.`
    });
  }

  if (uniqueFontCombinations.length > 6) {
    issues.push({
      type: 'too-many-font-combinations',
      count: uniqueFontCombinations.length,
      combinations: uniqueFontCombinations,
      message: `${uniqueFontCombinations.length} unique font-family + weight combinations. Limit to 6 or fewer to reduce font loading time.`
    });
  }

  if (preloadFonts.length === 0 && fontFaceRules.length > 0) {
    issues.push({
      type: 'no-font-preload',
      message: 'No <link rel="preload" as="font"> found. Preloading critical fonts improves LCP.'
    });
  }

  const loadingScore = (() => {
    let score = 100;
    if (fontFaceRules.some(r => r.display === 'block')) score -= 20;
    if (missingDisplay.length > 0) score -= 15;
    if (noWoff2.length > 0) score -= 15;
    if (uniqueFontCombinations.length > 6) score -= 10;
    if (preloadFonts.length === 0 && fontFaceRules.length > 0) score -= 10;
    return Math.max(0, score);
  })();

  return {
    fontFaceRulesFound: fontFaceRules.length,
    fontFaceRules: fontFaceRules.slice(0, 10),
    preloadedFonts: preloadFonts.length,
    googleFontsLinks: googleFonts.length,
    uniqueFontCombinations,
    combinationCount: uniqueFontCombinations.length,
    loadingScore,
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Heading Level Distinction**: Can you distinguish heading levels purely by visual appearance without reading content? Is there clear and sufficient visual contrast between h1, h2, h3, and body text? Or do heading levels blur together?

2. **Type Scale Quality**: Does the type scale create enough contrast between levels, or do sizes feel too close? Is there a sense of intentional progression from the smallest to the largest text? Or do font sizes feel randomly chosen?

3. **Vertical Rhythm Flow**: Is vertical rhythm creating a sense of order in the text flow? Does the spacing between text elements feel rhythmic and predictable? Or is spacing between text blocks random and jarring?

4. **Font Pairing Harmony**: Do font pairings complement each other (serif + sans-serif, geometric + humanist, display + body)? Or do fonts clash, look too similar (redundant), or come from incompatible design traditions?

5. **Content Type Appropriateness**: Is the type system appropriate for the content type? Long-form content needs high readability (generous line-height, optimal line length). Headlines need impact (tight tracking, bold weight). Dashboards need data density (compact, monospace for numbers).

6. **Fluid Typography Responsiveness**: Does fluid typography adapt gracefully between mobile and desktop viewport sizes? Do headings scale proportionally without becoming too large or too small? Or are there viewport ranges where text feels awkward?

7. **Font Loading Perception**: Are there any visible font loading issues? Flash of Invisible Text (FOIT), Flash of Unstyled Text (FOUT), or layout shift when fonts load? Does the page feel stable during initial load?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Consistent scale ratio (>60% adherence to named scale). Strong vertical rhythm (>60% adherence to base unit). Clear heading hierarchy — every adjacent level pair has ratio >=1.15. Optimal line length (45-75ch) for all body text. <=6 font combinations loaded. font-display: swap on all @font-face. woff2 format used. Fonts preloaded. |
| 4 | Good scale with minor rhythm breaks. Heading hierarchy clear with <=1 weak pair. Most body text in 45-75ch range. <=8 font combinations. font-display set. Minor loading issues. |
| 3 | Recognizable scale but inconsistent rhythm (<40% adherence). Heading levels distinguishable but some pairs too similar. Some body text lines >85ch. 8-10 font combinations. Some @font-face missing font-display. |
| 2 | Ad-hoc font sizes with no clear ratio. No vertical rhythm — spacings random. Heading levels blur together. Body text lines >100ch or <30ch. >10 font combinations. font-display: block or missing. |
| 1 | No type system. Sizes feel random. No heading hierarchy. No rhythm. Excessive font loading. Visible FOIT. Line lengths uncontrolled. >12 unique font sizes with no pattern. |

## Common Fixes

### Fix: Establish consistent type scale (major third 1.25)
```css
:root {
  --text-xs: 0.75rem;     /* 12px — captions */
  --text-sm: 0.875rem;    /* 14px — small text */
  --text-base: 1rem;      /* 16px — body */
  --text-lg: 1.25rem;     /* 20px — large body */
  --text-xl: 1.563rem;    /* 25px — h4 */
  --text-2xl: 1.953rem;   /* 31px — h3 */
  --text-3xl: 2.441rem;   /* 39px — h2 */
  --text-4xl: 3.052rem;   /* 49px — h1 */
}

h1 { font-size: var(--text-4xl); }
h2 { font-size: var(--text-3xl); }
h3 { font-size: var(--text-2xl); }
h4 { font-size: var(--text-xl); }
p, li { font-size: var(--text-base); }
```

**Tailwind equivalent:**
```html
<h1 class="text-5xl font-bold">     <!-- ~48px -->
<h2 class="text-4xl font-bold">     <!-- ~36px -->
<h3 class="text-2xl font-semibold"> <!-- ~24px -->
<h4 class="text-xl font-semibold">  <!-- ~20px -->
<p class="text-base">               <!-- 16px -->
```

### Fix: Establish vertical rhythm base unit
```css
:root {
  --rhythm: 1.5rem; /* 24px base unit — body line-height */
}

body {
  font-size: 1rem;
  line-height: var(--rhythm);
}

h1 { line-height: calc(var(--rhythm) * 2); margin-bottom: var(--rhythm); }
h2 { line-height: calc(var(--rhythm) * 1.5); margin-bottom: calc(var(--rhythm) * 0.5); }
h3 { line-height: var(--rhythm); margin-bottom: calc(var(--rhythm) * 0.5); }
p { margin-bottom: var(--rhythm); }
```

### Fix: Constrain line length
```css
/* Using ch units for character-based width */
.prose {
  max-width: 65ch;
}

/* Using rem for container-based width */
.content {
  max-width: 40rem; /* ~640px at 16px base */
  margin: 0 auto;
}
```

**Tailwind equivalent:**
```html
<div class="max-w-prose mx-auto"> <!-- max-width: 65ch -->
<div class="max-w-2xl mx-auto">  <!-- max-width: 42rem -->
```

### Fix: Add fluid typography with clamp()
```css
h1 {
  font-size: clamp(2rem, 5vw + 1rem, 3.5rem);
}

h2 {
  font-size: clamp(1.5rem, 3vw + 0.75rem, 2.5rem);
}

p {
  font-size: clamp(1rem, 0.5vw + 0.875rem, 1.125rem);
}
```

**Tailwind equivalent (v3.3+):**
```html
<h1 class="text-[clamp(2rem,5vw+1rem,3.5rem)]">
```

### Fix: Optimize font loading
```css
@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter-var.woff2') format('woff2');
  font-weight: 100 900;
  font-style: normal;
  font-display: swap;
}
```

```html
<!-- Preload critical font -->
<link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin>

<!-- Preconnect to Google Fonts if using -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
```

### Fix: Reduce font weight combinations
```css
/* Instead of loading 6 weights: */
/* @font-face for 300, 400, 500, 600, 700, 800 */

/* Use variable font with 2-3 weights: */
@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter-var.woff2') format('woff2');
  font-weight: 100 900; /* Variable font — single file, all weights */
  font-display: swap;
}

body { font-weight: 400; }
strong, .font-semibold { font-weight: 600; }
h1, h2, .font-bold { font-weight: 700; }
```
