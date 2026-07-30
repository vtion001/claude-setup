# Pass 2: Typography

## Tier 1: Automated Checks

### 2.1 Body Font Size and Line Height

```javascript
(() => {
  const bodyElements = document.querySelectorAll('p, li, td, dd, blockquote, .body-text, [class*="description"], [class*="content"]');
  const issues = [];
  const measurements = [];

  bodyElements.forEach(el => {
    const style = window.getComputedStyle(el);
    const fontSize = parseFloat(style.fontSize);
    const lineHeight = parseFloat(style.lineHeight);
    const lineHeightRatio = lineHeight / fontSize;
    const text = (el.textContent || '').trim();

    if (text.length < 10) return;

    measurements.push({
      tag: el.tagName.toLowerCase(),
      text: text.substring(0, 50),
      fontSize: Math.round(fontSize * 10) / 10,
      lineHeight: Math.round(lineHeight * 10) / 10,
      lineHeightRatio: Math.round(lineHeightRatio * 100) / 100
    });

    if (fontSize < 16) {
      issues.push({
        type: 'small-body-text',
        element: el.tagName.toLowerCase(),
        text: text.substring(0, 40),
        fontSize,
        message: `Body text is ${fontSize}px. Minimum 16px recommended for readability.`
      });
    }

    if (lineHeightRatio < 1.4) {
      issues.push({
        type: 'tight-line-height',
        element: el.tagName.toLowerCase(),
        text: text.substring(0, 40),
        lineHeightRatio: Math.round(lineHeightRatio * 100) / 100,
        message: `Line height ratio is ${Math.round(lineHeightRatio * 100) / 100}. Minimum 1.5x recommended for body text.`
      });
    }
  });

  const fontSizes = measurements.map(m => m.fontSize);
  const avgFontSize = fontSizes.length > 0 ? Math.round((fontSizes.reduce((a, b) => a + b, 0) / fontSizes.length) * 10) / 10 : 0;

  return {
    totalBodyElements: measurements.length,
    avgBodyFontSize: avgFontSize,
    measurements: measurements.slice(0, 20),
    issues
  };
})()
```

### 2.2 Line Length (Characters Per Line)

```javascript
(() => {
  const textBlocks = document.querySelectorAll('p, li, blockquote, .body-text, article p, main p');
  const issues = [];
  const measurements = [];

  textBlocks.forEach(el => {
    const text = (el.textContent || '').trim();
    if (text.length < 20) return;

    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    const fontSize = parseFloat(style.fontSize);
    const charWidth = fontSize * 0.55;
    const charsPerLine = Math.round(rect.width / charWidth);

    measurements.push({
      tag: el.tagName.toLowerCase(),
      text: text.substring(0, 50),
      containerWidth: Math.round(rect.width),
      estimatedCharsPerLine: charsPerLine,
      fontSize: Math.round(fontSize)
    });

    if (charsPerLine > 75) {
      issues.push({
        type: 'line-too-long',
        charsPerLine,
        containerWidth: Math.round(rect.width),
        message: `Line length ~${charsPerLine} chars. Maximum 75 chars recommended. Container is ${Math.round(rect.width)}px wide.`
      });
    }

    if (charsPerLine < 45 && rect.width > 200) {
      issues.push({
        type: 'line-too-short',
        charsPerLine,
        containerWidth: Math.round(rect.width),
        message: `Line length ~${charsPerLine} chars. Minimum 45 chars recommended for comfortable reading.`
      });
    }
  });

  return {
    totalTextBlocks: measurements.length,
    measurements: measurements.slice(0, 15),
    issues
  };
})()
```

### 2.3 Type Scale Ratio Analysis

```javascript
(() => {
  const allText = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, li, a, button, span, label, input, textarea');
  const sizeSet = new Set();
  const sizeUsage = {};

  allText.forEach(el => {
    const style = window.getComputedStyle(el);
    const fontSize = Math.round(parseFloat(style.fontSize) * 10) / 10;
    if (fontSize === 0) return;
    sizeSet.add(fontSize);
    if (!sizeUsage[fontSize]) sizeUsage[fontSize] = 0;
    sizeUsage[fontSize]++;
  });

  const sizes = [...sizeSet].sort((a, b) => b - a);
  const ratios = [];

  for (let i = 0; i < sizes.length - 1; i++) {
    const ratio = Math.round((sizes[i] / sizes[i + 1]) * 1000) / 1000;
    ratios.push({
      larger: sizes[i],
      smaller: sizes[i + 1],
      ratio
    });
  }

  const knownScales = [
    { name: 'Minor Second', ratio: 1.067 },
    { name: 'Major Second', ratio: 1.125 },
    { name: 'Minor Third', ratio: 1.2 },
    { name: 'Major Third', ratio: 1.25 },
    { name: 'Perfect Fourth', ratio: 1.333 },
    { name: 'Augmented Fourth', ratio: 1.414 },
    { name: 'Perfect Fifth', ratio: 1.5 },
    { name: 'Golden Ratio', ratio: 1.618 }
  ];

  const avgRatio = ratios.length > 0 ? ratios.reduce((sum, r) => sum + r.ratio, 0) / ratios.length : 0;
  const closestScale = knownScales.reduce((closest, scale) => {
    const diff = Math.abs(avgRatio - scale.ratio);
    return diff < Math.abs(avgRatio - closest.ratio) ? scale : closest;
  }, knownScales[0]);

  const ratioVariance = ratios.length > 0
    ? Math.round(Math.sqrt(ratios.reduce((sum, r) => sum + Math.pow(r.ratio - avgRatio, 2), 0) / ratios.length) * 1000) / 1000
    : 0;

  const issues = [];
  if (ratioVariance > 0.3) {
    issues.push({
      type: 'inconsistent-scale',
      message: `Type scale variance is ${ratioVariance}. Ratios are not following a consistent scale. Consider using a ${closestScale.name} (${closestScale.ratio}) scale.`
    });
  }

  if (sizes.length > 8) {
    issues.push({
      type: 'too-many-sizes',
      message: `${sizes.length} unique font sizes detected. Limit to 6-8 for a clean type scale.`
    });
  }

  return {
    uniqueSizes: sizes,
    sizeCount: sizes.length,
    sizeUsage,
    ratios,
    averageRatio: Math.round(avgRatio * 1000) / 1000,
    closestKnownScale: closestScale,
    ratioVariance,
    issues
  };
})()
```

### 2.4 Font Family Count and Weight Contrast

```javascript
(() => {
  const allElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, a, button, span, li, label, input, textarea, blockquote, figcaption, nav a, footer *');
  const families = new Set();
  const weights = new Set();
  const familyUsage = {};
  const weightUsage = {};

  allElements.forEach(el => {
    const style = window.getComputedStyle(el);
    const family = style.fontFamily.split(',')[0].trim().replace(/['"]/g, '');
    const weight = parseInt(style.fontWeight) || 400;

    if (family) {
      families.add(family);
      if (!familyUsage[family]) familyUsage[family] = 0;
      familyUsage[family]++;
    }

    weights.add(weight);
    if (!weightUsage[weight]) weightUsage[weight] = 0;
    weightUsage[weight]++;
  });

  const sortedWeights = [...weights].sort((a, b) => a - b);
  const weightSteps = sortedWeights.length;
  const weightRange = sortedWeights.length > 1 ? sortedWeights[sortedWeights.length - 1] - sortedWeights[0] : 0;

  const issues = [];

  if (families.size > 3) {
    issues.push({
      type: 'too-many-fonts',
      count: families.size,
      fonts: [...families],
      message: `${families.size} font families detected. Maximum 2-3 recommended (1 heading + 1 body + optional monospace).`
    });
  }

  if (weightSteps < 2) {
    issues.push({
      type: 'insufficient-weight-contrast',
      weights: sortedWeights,
      message: 'Only 1 font weight used. Use at least 2 weight steps (e.g., 400 and 700) for hierarchy.'
    });
  }

  if (weightRange > 0 && weightRange < 200) {
    issues.push({
      type: 'weak-weight-contrast',
      weights: sortedWeights,
      message: `Font weight range is only ${weightRange}. Minimum 200 weight difference (2 steps) recommended for clear hierarchy.`
    });
  }

  return {
    fontFamilies: [...families],
    fontFamilyCount: families.size,
    familyUsage,
    fontWeights: sortedWeights,
    weightSteps,
    weightRange,
    weightUsage,
    issues
  };
})()
```

### 2.5 Font Loading / FOIT / FOUT Detection

```javascript
(() => {
  const fontLinks = document.querySelectorAll('link[href*="fonts"], link[href*="typekit"], link[href*="googleapis.com/css"]');
  const fontFaces = [];
  const issues = [];

  try {
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules || []) {
          if (rule instanceof CSSFontFaceRule) {
            const display = rule.style.fontDisplay || 'auto';
            const family = rule.style.fontFamily || 'unknown';
            fontFaces.push({
              family: family.replace(/['"]/g, ''),
              display,
              src: (rule.style.getPropertyValue('src') || '').substring(0, 100)
            });

            if (display === 'auto' || display === 'block') {
              issues.push({
                type: 'foit-risk',
                family: family.replace(/['"]/g, ''),
                display,
                message: `Font "${family}" uses font-display: ${display}. This causes FOIT (invisible text). Use "swap" or "optional".`
              });
            }
          }
        }
      } catch (e) {
        // Cross-origin stylesheet, skip
      }
    }
  } catch (e) {
    // Stylesheet access error
  }

  const preloads = document.querySelectorAll('link[rel="preload"][as="font"]');
  const hasPreload = preloads.length > 0;

  if (fontLinks.length > 0 && !hasPreload) {
    issues.push({
      type: 'no-font-preload',
      message: 'External fonts detected but no preload links found. Add <link rel="preload" as="font"> for critical fonts.'
    });
  }

  return {
    externalFontLinks: fontLinks.length,
    fontFaceRules: fontFaces,
    fontFaceCount: fontFaces.length,
    hasPreload,
    preloadCount: preloads.length,
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Typographic Personality**: Does the typography have a distinct personality that matches the brand? A fintech app should feel precise and trustworthy (geometric sans-serif), a children's site should feel playful (rounded, warm), a luxury brand should feel elegant (high-contrast serif). Score based on appropriateness, not personal preference.

2. **Hierarchy Through Type Alone**: If you removed all color and images, could you still understand the page structure from typography alone? Clear size steps, weight contrast, and spacing between heading levels should create an obvious hierarchy without any visual support.

3. **Reading Comfort in Long Passages**: For any body text longer than 3 lines: is the line height generous enough to feel open (1.5-1.8x)? Is the line length comfortable (45-75 characters)? Does the font have good x-height and open counters for screen reading? Would you read a full article set in this type?

4. **Typographic Consistency**: Are the same elements styled the same way everywhere? Do all H2s look alike? Do all body paragraphs share the same size/weight/color? Inconsistency in same-level elements signals a lack of design system.

5. **Whitespace Between Type Elements**: Is there appropriate spacing between headings and their following content? Between paragraphs? Between list items? Typography lives in the space around it. Cramped type destroys readability even when the font choice is good.

6. **Font Pairing Harmony**: If multiple fonts are used, do they complement each other? Good pairings share either similar x-height, similar proportions, or intentional contrast (serif + sans-serif). Bad pairings fight each other or are too similar to justify using two fonts.

7. **Text Color and Background Relationship**: Is the text color appropriate for readability? Pure black (#000) on pure white (#FFF) can cause eye strain. Slightly softened combinations (e.g., #1a1a1a on #fafafa) are more comfortable. Is there sufficient contrast without being harsh?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Body text >=16px with line-height >=1.5x. Line lengths 45-75 chars. Consistent type scale following a known ratio (Major Third, Perfect Fourth, etc.) with <=6 unique sizes. <=2 font families with clear purpose. >=2 weight steps with >=200 weight difference. Font-display: swap or optional on all @font-face rules. Typography has brand-appropriate personality. |
| 4 | Body text >=16px. Line-height >=1.4x. Line lengths slightly outside range (40-80 chars). <=7 unique font sizes. <=3 font families. Type scale mostly consistent with 1-2 deviations. Font loading handled but not optimally. |
| 3 | Body text >=14px but <16px on some elements. Line-height between 1.3-1.5x. Line lengths occasionally exceed 80 chars. 8-9 unique font sizes. Type scale has no discernible ratio. Only 1 font weight used. |
| 2 | Body text <14px in multiple places. Line-height <1.3x making text feel cramped. Line lengths >90 chars or <35 chars. >10 unique font sizes with no system. >3 font families. FOIT risk on primary fonts. |
| 1 | Body text <12px. No line-height control (browser defaults). Lines span full viewport width. No type scale at all — sizes appear random. Multiple competing font families with no harmony. Font loading causes visible flash. |

## Common Fixes

### Fix: Establish minimum body text size
```css
body {
  font-size: 1rem; /* 16px base */
  line-height: 1.6;
}

small, .caption, .footnote {
  font-size: 0.875rem; /* 14px minimum for secondary text */
  line-height: 1.5;
}
```

**Tailwind equivalent:**
```html
<body class="text-base leading-relaxed">
<small class="text-sm leading-normal">
```

### Fix: Constrain line length
```css
p, li, blockquote {
  max-width: 65ch;
}

.article-body {
  max-width: 70ch;
  margin-inline: auto;
}
```

**Tailwind equivalent:**
```html
<p class="max-w-prose">
<article class="max-w-[70ch] mx-auto">
```

### Fix: Implement a type scale (Major Third - 1.25)
```css
:root {
  --step--1: 0.8rem;    /* 12.8px */
  --step-0: 1rem;       /* 16px base */
  --step-1: 1.25rem;    /* 20px */
  --step-2: 1.563rem;   /* 25px */
  --step-3: 1.953rem;   /* 31.25px */
  --step-4: 2.441rem;   /* 39px */
  --step-5: 3.052rem;   /* 48.8px */
}

h1 { font-size: var(--step-5); }
h2 { font-size: var(--step-4); }
h3 { font-size: var(--step-3); }
h4 { font-size: var(--step-2); }
p  { font-size: var(--step-0); }
```

### Fix: Font loading optimization
```css
@font-face {
  font-family: 'BrandFont';
  src: url('/fonts/brand.woff2') format('woff2');
  font-display: swap;
  font-weight: 400 700;
}
```

```html
<link rel="preload" href="/fonts/brand.woff2" as="font" type="font/woff2" crossorigin>
```

### Fix: Add weight contrast
```css
h1, h2, h3 { font-weight: 700; }
h4, h5, h6 { font-weight: 600; }
p, li { font-weight: 400; }
strong, .emphasis { font-weight: 600; }
```

**Tailwind equivalent:**
```html
<h1 class="font-bold">
<p class="font-normal">
<strong class="font-semibold">
```
