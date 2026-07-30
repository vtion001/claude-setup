# Browser Evaluate Script Library

Reusable `browser_evaluate` scripts for the UX audit skill. Each script is a complete, copy-pasteable IIFE that returns JSON.

---

## 1. measureElementSizes

Returns all visible elements with their bounding rects, sorted by area (largest first).

```javascript
(() => {
  const elements = Array.from(document.querySelectorAll('*'));
  const results = [];
  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) continue;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') continue;
    results.push({
      tag: el.tagName.toLowerCase(),
      id: el.id || null,
      classes: el.className && typeof el.className === 'string' ? el.className.slice(0, 100) : null,
      x: Math.round(rect.x),
      y: Math.round(rect.y),
      width: Math.round(rect.width),
      height: Math.round(rect.height),
      area: Math.round(rect.width * rect.height)
    });
  }
  results.sort((a, b) => b.area - a.area);
  return JSON.stringify({ count: results.length, elements: results.slice(0, 200) });
})()
```

**Returns:** `{ count: number, elements: [{ tag, id, classes, x, y, width, height, area }] }` — top 200 by area.

---

## 2. checkContrastRatios

Calculates contrast ratio for all text elements against their background. Flags WCAG AA/AAA failures.

```javascript
(() => {
  function luminance(r, g, b) {
    const [rs, gs, bs] = [r, g, b].map(c => {
      c = c / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
  }
  function parseColor(str) {
    const el = document.createElement('div');
    el.style.color = str;
    document.body.appendChild(el);
    const computed = window.getComputedStyle(el).color;
    document.body.removeChild(el);
    const match = computed.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }
  function contrastRatio(c1, c2) {
    const l1 = luminance(c1.r, c1.g, c1.b);
    const l2 = luminance(c2.r, c2.g, c2.b);
    const lighter = Math.max(l1, l2);
    const darker = Math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }
  function getEffectiveBg(el) {
    let current = el;
    while (current) {
      const bg = window.getComputedStyle(current).backgroundColor;
      const parsed = parseColor(bg);
      if (parsed && !(parsed.r === 0 && parsed.g === 0 && parsed.b === 0 && bg.includes('0)'))) {
        return parsed;
      }
      current = current.parentElement;
    }
    return { r: 255, g: 255, b: 255 };
  }
  const textEls = document.querySelectorAll('p, span, a, h1, h2, h3, h4, h5, h6, li, td, th, label, button, input, textarea, select, summary, figcaption, blockquote, cite, code, pre, dt, dd');
  const results = [];
  const failures = [];
  for (const el of textEls) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) continue;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;
    const text = el.textContent?.trim().slice(0, 50);
    if (!text) continue;
    const fgColor = parseColor(style.color);
    const bgColor = getEffectiveBg(el);
    if (!fgColor || !bgColor) continue;
    const ratio = contrastRatio(fgColor, bgColor);
    const fontSize = parseFloat(style.fontSize);
    const fontWeight = parseInt(style.fontWeight) || 400;
    const isLargeText = fontSize >= 24 || (fontSize >= 18.66 && fontWeight >= 700);
    const aaRequired = isLargeText ? 3 : 4.5;
    const aaaRequired = isLargeText ? 4.5 : 7;
    const passAA = ratio >= aaRequired;
    const passAAA = ratio >= aaaRequired;
    const entry = {
      text: text,
      tag: el.tagName.toLowerCase(),
      fontSize: Math.round(fontSize * 10) / 10,
      fontWeight: fontWeight,
      ratio: Math.round(ratio * 100) / 100,
      fg: `rgb(${fgColor.r},${fgColor.g},${fgColor.b})`,
      bg: `rgb(${bgColor.r},${bgColor.g},${bgColor.b})`,
      isLargeText: isLargeText,
      passAA: passAA,
      passAAA: passAAA
    };
    results.push(entry);
    if (!passAA) failures.push(entry);
  }
  return JSON.stringify({
    total: results.length,
    failures: failures.length,
    failureRate: results.length > 0 ? Math.round((failures.length / results.length) * 100) : 0,
    failedElements: failures.slice(0, 50),
    sample: results.slice(0, 20)
  });
})()
```

**Returns:** `{ total, failures, failureRate, failedElements: [{ text, tag, fontSize, ratio, fg, bg, passAA, passAAA }], sample }`.

---

## 3. measureSpacing

Collects all margins, paddings, and gaps. Checks adherence to an 8px grid.

```javascript
(() => {
  const elements = document.querySelectorAll('*');
  const spacingValues = { margins: {}, paddings: {}, gaps: {} };
  let totalValues = 0;
  let on8pxGrid = 0;
  const violations = [];
  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) continue;
    const style = window.getComputedStyle(el);
    if (style.display === 'none') continue;
    const props = {
      margins: ['marginTop', 'marginRight', 'marginBottom', 'marginLeft'],
      paddings: ['paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft'],
      gaps: ['gap', 'rowGap', 'columnGap']
    };
    for (const [category, propList] of Object.entries(props)) {
      for (const prop of propList) {
        const val = parseFloat(style[prop]);
        if (isNaN(val) || val === 0) continue;
        const rounded = Math.round(val);
        spacingValues[category][rounded] = (spacingValues[category][rounded] || 0) + 1;
        totalValues++;
        if (rounded % 8 === 0 || rounded % 4 === 0) {
          on8pxGrid++;
        } else {
          violations.push({
            tag: el.tagName.toLowerCase(),
            id: el.id || null,
            classes: (typeof el.className === 'string' ? el.className : '').slice(0, 60),
            property: prop,
            value: rounded
          });
        }
      }
    }
  }
  const sortByFreq = (obj) => Object.entries(obj)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .map(([val, count]) => ({ value: parseInt(val), count, onGrid: parseInt(val) % 4 === 0 }));
  return JSON.stringify({
    totalValues: totalValues,
    gridAdherence: totalValues > 0 ? Math.round((on8pxGrid / totalValues) * 100) : 100,
    uniqueMargins: Object.keys(spacingValues.margins).length,
    uniquePaddings: Object.keys(spacingValues.paddings).length,
    uniqueGaps: Object.keys(spacingValues.gaps).length,
    topMargins: sortByFreq(spacingValues.margins),
    topPaddings: sortByFreq(spacingValues.paddings),
    topGaps: sortByFreq(spacingValues.gaps),
    violations: violations.slice(0, 30)
  });
})()
```

**Returns:** `{ totalValues, gridAdherence (%), uniqueMargins, uniquePaddings, uniqueGaps, topMargins, topPaddings, topGaps, violations }`.

---

## 4. checkInteractiveElements

Finds all clickable/interactive elements. Checks for cursor:pointer, minimum 44px touch target, and accessible names.

```javascript
(() => {
  const interactive = document.querySelectorAll('a, button, input, select, textarea, [role="button"], [role="link"], [role="tab"], [role="menuitem"], [role="checkbox"], [role="radio"], [role="switch"], [tabindex]:not([tabindex="-1"]), [onclick], summary, details');
  const results = [];
  const issues = [];
  for (const el of interactive) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) continue;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;
    const accessibleName = el.getAttribute('aria-label')
      || el.getAttribute('aria-labelledby')
      || el.getAttribute('title')
      || el.textContent?.trim().slice(0, 60)
      || el.getAttribute('alt')
      || el.getAttribute('placeholder')
      || '';
    const hasCursorPointer = style.cursor === 'pointer';
    const minDimension = Math.min(rect.width, rect.height);
    const meetsTouchTarget = minDimension >= 44;
    const hasAccessibleName = accessibleName.length > 0;
    const elementIssues = [];
    if (!hasCursorPointer && el.tagName.toLowerCase() !== 'input' && el.tagName.toLowerCase() !== 'textarea' && el.tagName.toLowerCase() !== 'select') {
      elementIssues.push('missing-cursor-pointer');
    }
    if (!meetsTouchTarget) {
      elementIssues.push('touch-target-too-small');
    }
    if (!hasAccessibleName) {
      elementIssues.push('missing-accessible-name');
    }
    const entry = {
      tag: el.tagName.toLowerCase(),
      type: el.getAttribute('type') || null,
      role: el.getAttribute('role') || null,
      text: accessibleName.slice(0, 60),
      width: Math.round(rect.width),
      height: Math.round(rect.height),
      minDimension: Math.round(minDimension),
      hasCursorPointer: hasCursorPointer,
      meetsTouchTarget: meetsTouchTarget,
      hasAccessibleName: hasAccessibleName,
      issues: elementIssues
    };
    results.push(entry);
    if (elementIssues.length > 0) issues.push(entry);
  }
  return JSON.stringify({
    total: results.length,
    withIssues: issues.length,
    missingCursor: issues.filter(i => i.issues.includes('missing-cursor-pointer')).length,
    smallTouchTargets: issues.filter(i => i.issues.includes('touch-target-too-small')).length,
    missingNames: issues.filter(i => i.issues.includes('missing-accessible-name')).length,
    issues: issues.slice(0, 50),
    sample: results.slice(0, 20)
  });
})()
```

**Returns:** `{ total, withIssues, missingCursor, smallTouchTargets, missingNames, issues: [{ tag, text, width, height, issues[] }], sample }`.

---

## 5. checkHeadingHierarchy

Validates h1-h6 order, counts h1s, and checks for skipped levels.

```javascript
(() => {
  const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
  const hierarchy = [];
  const issues = [];
  let prevLevel = 0;
  let h1Count = 0;
  for (const h of headings) {
    const level = parseInt(h.tagName[1]);
    const rect = h.getBoundingClientRect();
    const style = window.getComputedStyle(h);
    const isVisible = rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
    const entry = {
      level: level,
      text: h.textContent?.trim().slice(0, 80) || '[empty]',
      fontSize: parseFloat(style.fontSize),
      fontWeight: parseInt(style.fontWeight) || 400,
      isVisible: isVisible,
      tag: h.tagName.toLowerCase()
    };
    hierarchy.push(entry);
    if (level === 1) h1Count++;
    if (prevLevel > 0 && level > prevLevel + 1) {
      issues.push({
        type: 'skipped-level',
        from: `h${prevLevel}`,
        to: `h${level}`,
        text: entry.text,
        expected: `h${prevLevel + 1}`
      });
    }
    if (prevLevel === 0 && level !== 1) {
      issues.push({
        type: 'no-h1-first',
        firstHeading: `h${level}`,
        text: entry.text
      });
    }
    prevLevel = level;
  }
  if (h1Count === 0) {
    issues.push({ type: 'missing-h1' });
  } else if (h1Count > 1) {
    issues.push({ type: 'multiple-h1', count: h1Count });
  }
  const fontSizesByLevel = {};
  for (const h of hierarchy) {
    if (!fontSizesByLevel[h.level]) fontSizesByLevel[h.level] = [];
    fontSizesByLevel[h.level].push(h.fontSize);
  }
  const sizeIssues = [];
  const levels = Object.keys(fontSizesByLevel).map(Number).sort();
  for (let i = 0; i < levels.length - 1; i++) {
    const higherAvg = fontSizesByLevel[levels[i]].reduce((a, b) => a + b, 0) / fontSizesByLevel[levels[i]].length;
    const lowerAvg = fontSizesByLevel[levels[i + 1]].reduce((a, b) => a + b, 0) / fontSizesByLevel[levels[i + 1]].length;
    if (lowerAvg >= higherAvg) {
      sizeIssues.push({
        type: 'size-inversion',
        higher: `h${levels[i]} (${Math.round(higherAvg)}px)`,
        lower: `h${levels[i + 1]} (${Math.round(lowerAvg)}px)`
      });
    }
  }
  return JSON.stringify({
    totalHeadings: hierarchy.length,
    h1Count: h1Count,
    hierarchy: hierarchy,
    structureIssues: issues,
    sizeIssues: sizeIssues,
    isValid: issues.length === 0 && sizeIssues.length === 0
  });
})()
```

**Returns:** `{ totalHeadings, h1Count, hierarchy: [{ level, text, fontSize, fontWeight }], structureIssues, sizeIssues, isValid }`.

---

## 6. checkImageOptimization

Finds images missing alt text, oversized images, and below-fold images without lazy loading.

```javascript
(() => {
  const images = document.querySelectorAll('img, picture source, [role="img"], svg[aria-label]');
  const viewportHeight = window.innerHeight;
  const results = [];
  const issues = [];
  for (const img of images) {
    if (img.tagName.toLowerCase() !== 'img') continue;
    const rect = img.getBoundingClientRect();
    const style = window.getComputedStyle(img);
    if (style.display === 'none') continue;
    const alt = img.getAttribute('alt');
    const hasAlt = alt !== null;
    const altIsEmpty = alt === '';
    const loading = img.getAttribute('loading');
    const isBelowFold = rect.top > viewportHeight;
    const hasLazyLoading = loading === 'lazy';
    const naturalWidth = img.naturalWidth || 0;
    const naturalHeight = img.naturalHeight || 0;
    const displayWidth = Math.round(rect.width);
    const displayHeight = Math.round(rect.height);
    const isOversized = naturalWidth > 0 && displayWidth > 0 && naturalWidth > displayWidth * 2;
    const wastedPixels = isOversized ? (naturalWidth * naturalHeight) - (displayWidth * displayHeight * 4) : 0;
    const src = (img.getAttribute('src') || '').slice(0, 120);
    const srcset = img.getAttribute('srcset') ? true : false;
    const elementIssues = [];
    if (!hasAlt) elementIssues.push('missing-alt');
    if (isOversized) elementIssues.push('oversized');
    if (isBelowFold && !hasLazyLoading) elementIssues.push('missing-lazy-loading');
    if (!srcset && naturalWidth > 640) elementIssues.push('missing-srcset');
    const entry = {
      src: src,
      alt: hasAlt ? (alt || '[empty-decorative]') : '[MISSING]',
      hasAlt: hasAlt,
      displaySize: `${displayWidth}x${displayHeight}`,
      naturalSize: `${naturalWidth}x${naturalHeight}`,
      isOversized: isOversized,
      isBelowFold: isBelowFold,
      hasLazyLoading: hasLazyLoading,
      hasSrcset: srcset,
      issues: elementIssues
    };
    results.push(entry);
    if (elementIssues.length > 0) issues.push(entry);
  }
  return JSON.stringify({
    totalImages: results.length,
    withIssues: issues.length,
    missingAlt: issues.filter(i => i.issues.includes('missing-alt')).length,
    oversized: issues.filter(i => i.issues.includes('oversized')).length,
    missingLazy: issues.filter(i => i.issues.includes('missing-lazy-loading')).length,
    missingSrcset: issues.filter(i => i.issues.includes('missing-srcset')).length,
    issues: issues.slice(0, 30),
    all: results.slice(0, 50)
  });
})()
```

**Returns:** `{ totalImages, withIssues, missingAlt, oversized, missingLazy, missingSrcset, issues, all }`.

---

## 7. measureTypography

Collects all font sizes, line heights, font families, and line lengths in use.

```javascript
(() => {
  const textElements = document.querySelectorAll('p, span, a, h1, h2, h3, h4, h5, h6, li, td, th, label, button, blockquote, figcaption, dt, dd, code, pre, cite, small, strong, em');
  const fontSizes = {};
  const lineHeights = {};
  const fontFamilies = {};
  const lineLengths = [];
  let totalSampled = 0;
  for (const el of textElements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) continue;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;
    const text = el.textContent?.trim();
    if (!text) continue;
    totalSampled++;
    const fontSize = Math.round(parseFloat(style.fontSize) * 10) / 10;
    fontSizes[fontSize] = (fontSizes[fontSize] || 0) + 1;
    const lineHeight = style.lineHeight;
    const lhValue = lineHeight === 'normal' ? 'normal' : (Math.round(parseFloat(lineHeight) * 10) / 10).toString();
    lineHeights[lhValue] = (lineHeights[lhValue] || 0) + 1;
    const fontFamily = style.fontFamily.split(',')[0].trim().replace(/['"]/g, '');
    fontFamilies[fontFamily] = (fontFamilies[fontFamily] || 0) + 1;
    if (el.tagName.match(/^(P|LI|BLOCKQUOTE|DD|FIGCAPTION)$/i) && rect.width > 0) {
      const charsPerLine = Math.round(rect.width / (fontSize * 0.5));
      lineLengths.push({
        tag: el.tagName.toLowerCase(),
        charsPerLine: charsPerLine,
        width: Math.round(rect.width),
        fontSize: fontSize,
        optimal: charsPerLine >= 45 && charsPerLine <= 75
      });
    }
  }
  const sortObj = (obj) => Object.entries(obj)
    .sort((a, b) => b[1] - a[1])
    .map(([value, count]) => ({ value, count }));
  const lineLengthStats = lineLengths.length > 0 ? {
    min: Math.min(...lineLengths.map(l => l.charsPerLine)),
    max: Math.max(...lineLengths.map(l => l.charsPerLine)),
    optimal: lineLengths.filter(l => l.optimal).length,
    total: lineLengths.length,
    optimalRate: Math.round((lineLengths.filter(l => l.optimal).length / lineLengths.length) * 100)
  } : null;
  return JSON.stringify({
    totalSampled: totalSampled,
    uniqueFontSizes: Object.keys(fontSizes).length,
    uniqueLineHeights: Object.keys(lineHeights).length,
    uniqueFontFamilies: Object.keys(fontFamilies).length,
    fontSizes: sortObj(fontSizes),
    lineHeights: sortObj(lineHeights),
    fontFamilies: sortObj(fontFamilies),
    lineLengths: lineLengthStats,
    lineLengthSamples: lineLengths.slice(0, 20)
  });
})()
```

**Returns:** `{ totalSampled, uniqueFontSizes, uniqueLineHeights, uniqueFontFamilies, fontSizes, lineHeights, fontFamilies, lineLengths (stats), lineLengthSamples }`.

---

## 8. checkFontLoading

Verifies all fonts loaded successfully and detects FOIT/FOUT risk.

```javascript
(() => {
  const fonts = [];
  const fontFaces = document.fonts;
  const allFonts = new Set();
  const loadedFonts = new Set();
  const failedFonts = new Set();
  for (const font of fontFaces) {
    const key = `${font.family} ${font.weight} ${font.style}`;
    allFonts.add(key);
    fonts.push({
      family: font.family.replace(/['"]/g, ''),
      weight: font.weight,
      style: font.style,
      status: font.status,
      display: font.display || 'unknown'
    });
    if (font.status === 'loaded') loadedFonts.add(key);
    else if (font.status === 'error') failedFonts.add(key);
  }
  const usedFamilies = new Set();
  const textEls = document.querySelectorAll('p, span, a, h1, h2, h3, h4, h5, h6, li, button, label, input');
  for (const el of textEls) {
    const style = window.getComputedStyle(el);
    const family = style.fontFamily.split(',')[0].trim().replace(/['"]/g, '');
    usedFamilies.add(family);
  }
  const fontDisplayValues = {};
  for (const sheet of document.styleSheets) {
    try {
      for (const rule of sheet.cssRules || []) {
        if (rule instanceof CSSFontFaceRule) {
          const family = rule.style.fontFamily?.replace(/['"]/g, '') || 'unknown';
          const display = rule.style.fontDisplay || 'auto';
          fontDisplayValues[family] = display;
        }
      }
    } catch (e) {}
  }
  const foitRisk = [];
  const foutRisk = [];
  for (const [family, display] of Object.entries(fontDisplayValues)) {
    if (display === 'block' || display === 'auto') foitRisk.push(family);
    if (display === 'swap' || display === 'fallback') foutRisk.push(family);
  }
  return JSON.stringify({
    totalFonts: allFonts.size,
    loaded: loadedFonts.size,
    failed: failedFonts.size,
    loading: allFonts.size - loadedFonts.size - failedFonts.size,
    allLoaded: failedFonts.size === 0 && allFonts.size === loadedFonts.size,
    fonts: fonts.slice(0, 30),
    usedFamilies: Array.from(usedFamilies),
    fontDisplayValues: fontDisplayValues,
    foitRisk: foitRisk,
    foutRisk: foutRisk
  });
})()
```

**Returns:** `{ totalFonts, loaded, failed, loading, allLoaded, fonts, usedFamilies, fontDisplayValues, foitRisk, foutRisk }`.

---

## 9. measurePerformance

Captures LCP and CLS values using the Performance Observer API and PerformanceNavigationTiming.

```javascript
(() => {
  const result = {
    lcp: null,
    cls: null,
    fcp: null,
    domContentLoaded: null,
    loadComplete: null,
    domNodes: document.querySelectorAll('*').length,
    resources: { total: 0, images: 0, scripts: 0, stylesheets: 0, fonts: 0 },
    transferSize: { total: 0, images: 0, scripts: 0, stylesheets: 0, fonts: 0 }
  };
  const navEntries = performance.getEntriesByType('navigation');
  if (navEntries.length > 0) {
    const nav = navEntries[0];
    result.domContentLoaded = Math.round(nav.domContentLoadedEventEnd);
    result.loadComplete = Math.round(nav.loadEventEnd);
  }
  const paintEntries = performance.getEntriesByType('paint');
  for (const entry of paintEntries) {
    if (entry.name === 'first-contentful-paint') {
      result.fcp = Math.round(entry.startTime);
    }
  }
  const lcpEntries = performance.getEntriesByType('largest-contentful-paint');
  if (lcpEntries.length > 0) {
    const lastLcp = lcpEntries[lcpEntries.length - 1];
    result.lcp = {
      time: Math.round(lastLcp.startTime),
      element: lastLcp.element ? lastLcp.element.tagName.toLowerCase() : null,
      size: lastLcp.size,
      url: (lastLcp.url || '').slice(0, 100)
    };
  }
  const layoutShiftEntries = performance.getEntriesByType('layout-shift');
  let clsValue = 0;
  for (const entry of layoutShiftEntries) {
    if (!entry.hadRecentInput) {
      clsValue += entry.value;
    }
  }
  result.cls = Math.round(clsValue * 10000) / 10000;
  const resources = performance.getEntriesByType('resource');
  for (const r of resources) {
    result.resources.total++;
    const size = r.transferSize || 0;
    result.transferSize.total += size;
    if (r.initiatorType === 'img' || r.name.match(/\.(png|jpg|jpeg|gif|webp|avif|svg|ico)/i)) {
      result.resources.images++;
      result.transferSize.images += size;
    } else if (r.initiatorType === 'script') {
      result.resources.scripts++;
      result.transferSize.scripts += size;
    } else if (r.initiatorType === 'css' || r.initiatorType === 'link') {
      result.resources.stylesheets++;
      result.transferSize.stylesheets += size;
    } else if (r.name.match(/\.(woff2?|ttf|otf|eot)/i)) {
      result.resources.fonts++;
      result.transferSize.fonts += size;
    }
  }
  const formatBytes = (b) => b > 1048576 ? `${(b / 1048576).toFixed(1)}MB` : `${(b / 1024).toFixed(1)}KB`;
  result.transferSizeFormatted = {
    total: formatBytes(result.transferSize.total),
    images: formatBytes(result.transferSize.images),
    scripts: formatBytes(result.transferSize.scripts),
    stylesheets: formatBytes(result.transferSize.stylesheets),
    fonts: formatBytes(result.transferSize.fonts)
  };
  return JSON.stringify(result);
})()
```

**Returns:** `{ lcp: { time, element, size, url }, cls, fcp, domContentLoaded, loadComplete, domNodes, resources, transferSize, transferSizeFormatted }`.

---

## 10. checkLayoutOverflow

Finds elements causing horizontal overflow at the current viewport width.

```javascript
(() => {
  const viewportWidth = document.documentElement.clientWidth;
  const viewportHeight = document.documentElement.clientHeight;
  const bodyWidth = document.body.scrollWidth;
  const hasHorizontalScroll = bodyWidth > viewportWidth;
  const overflowElements = [];
  const elements = document.querySelectorAll('*');
  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0) continue;
    const style = window.getComputedStyle(el);
    if (style.display === 'none') continue;
    const overflowRight = rect.right > viewportWidth;
    const overflowLeft = rect.left < 0;
    const contentOverflow = el.scrollWidth > el.clientWidth && style.overflowX !== 'scroll' && style.overflowX !== 'auto' && style.overflowX !== 'hidden';
    if (overflowRight || overflowLeft || contentOverflow) {
      overflowElements.push({
        tag: el.tagName.toLowerCase(),
        id: el.id || null,
        classes: (typeof el.className === 'string' ? el.className : '').slice(0, 80),
        left: Math.round(rect.left),
        right: Math.round(rect.right),
        width: Math.round(rect.width),
        overflowRight: overflowRight,
        overflowLeft: overflowLeft,
        contentOverflow: contentOverflow,
        overflowAmount: overflowRight ? Math.round(rect.right - viewportWidth) : (overflowLeft ? Math.round(Math.abs(rect.left)) : Math.round(el.scrollWidth - el.clientWidth))
      });
    }
  }
  overflowElements.sort((a, b) => b.overflowAmount - a.overflowAmount);
  return JSON.stringify({
    viewportWidth: viewportWidth,
    bodyScrollWidth: bodyWidth,
    hasHorizontalScroll: hasHorizontalScroll,
    overflowAmount: hasHorizontalScroll ? bodyWidth - viewportWidth : 0,
    overflowElements: overflowElements.slice(0, 30),
    totalOverflowing: overflowElements.length
  });
})()
```

**Returns:** `{ viewportWidth, bodyScrollWidth, hasHorizontalScroll, overflowAmount, overflowElements: [{ tag, classes, width, overflowAmount }], totalOverflowing }`.

---

## 11. checkSemanticHTML

Verifies landmarks (main, nav, header, footer), semantic structure, and ARIA roles.

```javascript
(() => {
  const landmarks = {
    main: document.querySelectorAll('main, [role="main"]').length,
    nav: document.querySelectorAll('nav, [role="navigation"]').length,
    header: document.querySelectorAll('header, [role="banner"]').length,
    footer: document.querySelectorAll('footer, [role="contentinfo"]').length,
    aside: document.querySelectorAll('aside, [role="complementary"]').length,
    search: document.querySelectorAll('[role="search"], search').length,
    form: document.querySelectorAll('form, [role="form"]').length
  };
  const issues = [];
  if (landmarks.main === 0) issues.push({ type: 'missing-landmark', landmark: 'main', severity: 'high' });
  if (landmarks.main > 1) issues.push({ type: 'multiple-landmark', landmark: 'main', count: landmarks.main, severity: 'medium' });
  if (landmarks.nav === 0) issues.push({ type: 'missing-landmark', landmark: 'nav', severity: 'medium' });
  if (landmarks.header === 0) issues.push({ type: 'missing-landmark', landmark: 'header', severity: 'low' });
  if (landmarks.footer === 0) issues.push({ type: 'missing-landmark', landmark: 'footer', severity: 'low' });
  const semanticTags = {};
  const tagNames = ['article', 'section', 'aside', 'figure', 'figcaption', 'details', 'summary', 'dialog', 'time', 'mark', 'address', 'abbr', 'cite', 'code', 'pre', 'blockquote', 'dl', 'dt', 'dd', 'table', 'thead', 'tbody', 'tfoot', 'caption'];
  for (const tag of tagNames) {
    const count = document.querySelectorAll(tag).length;
    if (count > 0) semanticTags[tag] = count;
  }
  const divCount = document.querySelectorAll('div').length;
  const spanCount = document.querySelectorAll('span').length;
  const totalElements = document.querySelectorAll('*').length;
  const semanticElementCount = Object.values(semanticTags).reduce((a, b) => a + b, 0) + landmarks.main + landmarks.nav + landmarks.header + landmarks.footer + landmarks.aside;
  const genericRatio = totalElements > 0 ? Math.round(((divCount + spanCount) / totalElements) * 100) : 0;
  if (genericRatio > 70) {
    issues.push({ type: 'div-soup', ratio: genericRatio, severity: 'medium' });
  }
  const sections = document.querySelectorAll('section');
  let unlabeledSections = 0;
  for (const s of sections) {
    if (!s.getAttribute('aria-label') && !s.getAttribute('aria-labelledby')) {
      const heading = s.querySelector('h1, h2, h3, h4, h5, h6');
      if (!heading) unlabeledSections++;
    }
  }
  if (unlabeledSections > 0) {
    issues.push({ type: 'unlabeled-sections', count: unlabeledSections, severity: 'medium' });
  }
  const skipLink = document.querySelector('a[href="#main"], a[href="#content"], a[href="#main-content"], .skip-link, .skip-nav, [class*="skip"]');
  if (!skipLink) {
    issues.push({ type: 'missing-skip-link', severity: 'medium' });
  }
  const htmlLang = document.documentElement.getAttribute('lang');
  if (!htmlLang) {
    issues.push({ type: 'missing-lang', severity: 'high' });
  }
  return JSON.stringify({
    landmarks: landmarks,
    semanticTags: semanticTags,
    divCount: divCount,
    spanCount: spanCount,
    totalElements: totalElements,
    genericRatio: genericRatio,
    semanticScore: Math.round((semanticElementCount / Math.max(1, totalElements)) * 100),
    hasSkipLink: !!skipLink,
    htmlLang: htmlLang || null,
    unlabeledSections: unlabeledSections,
    issues: issues,
    isValid: issues.length === 0
  });
})()
```

**Returns:** `{ landmarks, semanticTags, divCount, spanCount, genericRatio, semanticScore, hasSkipLink, htmlLang, issues, isValid }`.

---

## 12. checkFormAccessibility

Verifies all inputs have associated labels, proper types, and required ARIA attributes.

```javascript
(() => {
  const inputs = document.querySelectorAll('input, select, textarea');
  const results = [];
  const issues = [];
  for (const input of inputs) {
    const rect = input.getBoundingClientRect();
    const style = window.getComputedStyle(input);
    if (style.display === 'none' && input.type !== 'hidden') continue;
    if (input.type === 'hidden') continue;
    const id = input.id;
    const name = input.getAttribute('name') || null;
    const type = input.getAttribute('type') || input.tagName.toLowerCase();
    const ariaLabel = input.getAttribute('aria-label');
    const ariaLabelledBy = input.getAttribute('aria-labelledby');
    const ariaDescribedBy = input.getAttribute('aria-describedby');
    const placeholder = input.getAttribute('placeholder');
    const title = input.getAttribute('title');
    const required = input.hasAttribute('required') || input.getAttribute('aria-required') === 'true';
    const ariaInvalid = input.getAttribute('aria-invalid');
    const autocomplete = input.getAttribute('autocomplete');
    let hasLabel = false;
    let labelText = '';
    if (id) {
      const label = document.querySelector(`label[for="${id}"]`);
      if (label) {
        hasLabel = true;
        labelText = label.textContent?.trim().slice(0, 60) || '';
      }
    }
    if (!hasLabel) {
      const parentLabel = input.closest('label');
      if (parentLabel) {
        hasLabel = true;
        labelText = parentLabel.textContent?.trim().slice(0, 60) || '';
      }
    }
    if (!hasLabel && ariaLabel) {
      hasLabel = true;
      labelText = ariaLabel;
    }
    if (!hasLabel && ariaLabelledBy) {
      const refEl = document.getElementById(ariaLabelledBy);
      if (refEl) {
        hasLabel = true;
        labelText = refEl.textContent?.trim().slice(0, 60) || '';
      }
    }
    const elementIssues = [];
    if (!hasLabel) elementIssues.push('missing-label');
    if (placeholder && !hasLabel) elementIssues.push('placeholder-only-label');
    if (type === 'text' && !autocomplete && name) elementIssues.push('missing-autocomplete');
    if (type === 'password' && !autocomplete) elementIssues.push('missing-autocomplete');
    if (type === 'email' && !autocomplete) elementIssues.push('missing-autocomplete');
    if (required && !ariaInvalid && !input.getAttribute('aria-errormessage')) {
      elementIssues.push('missing-error-handling');
    }
    const entry = {
      tag: input.tagName.toLowerCase(),
      type: type,
      id: id || null,
      name: name,
      hasLabel: hasLabel,
      labelText: labelText,
      placeholder: placeholder || null,
      required: required,
      autocomplete: autocomplete || null,
      hasAriaDescribedBy: !!ariaDescribedBy,
      issues: elementIssues
    };
    results.push(entry);
    if (elementIssues.length > 0) issues.push(entry);
  }
  const forms = document.querySelectorAll('form');
  const formInfo = [];
  for (const form of forms) {
    formInfo.push({
      id: form.id || null,
      action: (form.getAttribute('action') || '').slice(0, 60),
      method: form.getAttribute('method') || 'get',
      hasAriaLabel: !!form.getAttribute('aria-label'),
      inputCount: form.querySelectorAll('input, select, textarea').length,
      hasSubmitButton: !!form.querySelector('button[type="submit"], input[type="submit"]')
    });
  }
  return JSON.stringify({
    totalInputs: results.length,
    withIssues: issues.length,
    missingLabels: issues.filter(i => i.issues.includes('missing-label')).length,
    placeholderOnly: issues.filter(i => i.issues.includes('placeholder-only-label')).length,
    missingAutocomplete: issues.filter(i => i.issues.includes('missing-autocomplete')).length,
    missingErrorHandling: issues.filter(i => i.issues.includes('missing-error-handling')).length,
    forms: formInfo,
    issues: issues.slice(0, 30),
    all: results.slice(0, 50)
  });
})()
```

**Returns:** `{ totalInputs, withIssues, missingLabels, placeholderOnly, missingAutocomplete, missingErrorHandling, forms, issues, all }`.

---

## 13. detectDarkPatterns

Checks for pre-checked opt-ins, asymmetric button styling, hidden elements that might be deceptive, and confirm-shaming.

```javascript
(() => {
  const findings = [];
  const checkboxes = document.querySelectorAll('input[type="checkbox"]');
  for (const cb of checkboxes) {
    if (cb.checked && cb.defaultChecked) {
      const label = cb.closest('label')?.textContent?.trim()
        || document.querySelector(`label[for="${cb.id}"]`)?.textContent?.trim()
        || '';
      const lowerLabel = label.toLowerCase();
      const isOptIn = lowerLabel.includes('newsletter') || lowerLabel.includes('marketing')
        || lowerLabel.includes('subscribe') || lowerLabel.includes('email')
        || lowerLabel.includes('notification') || lowerLabel.includes('agree')
        || lowerLabel.includes('opt') || lowerLabel.includes('consent')
        || lowerLabel.includes('receive') || lowerLabel.includes('send me');
      if (isOptIn) {
        findings.push({
          type: 'pre-checked-opt-in',
          severity: 'high',
          element: 'checkbox',
          label: label.slice(0, 100),
          id: cb.id || null
        });
      }
    }
  }
  const buttons = document.querySelectorAll('button, [role="button"], a.btn, a.button, input[type="button"], input[type="submit"]');
  const buttonPairs = [];
  const allButtons = Array.from(buttons).filter(b => {
    const rect = b.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  });
  for (let i = 0; i < allButtons.length - 1; i++) {
    for (let j = i + 1; j < allButtons.length; j++) {
      const a = allButtons[i];
      const b = allButtons[j];
      const aRect = a.getBoundingClientRect();
      const bRect = b.getBoundingClientRect();
      const distance = Math.abs(aRect.top - bRect.top) + Math.abs(aRect.left - bRect.left);
      if (distance > 200) continue;
      const aStyle = window.getComputedStyle(a);
      const bStyle = window.getComputedStyle(b);
      const aArea = aRect.width * aRect.height;
      const bArea = bRect.width * bRect.height;
      const sizeRatio = Math.max(aArea, bArea) / Math.min(aArea, bArea);
      const aText = a.textContent?.trim().toLowerCase() || '';
      const bText = b.textContent?.trim().toLowerCase() || '';
      const negativeWords = ['cancel', 'decline', 'no thanks', 'skip', 'not now', 'later', 'close', 'dismiss', 'no,', 'opt out'];
      const positiveWords = ['accept', 'agree', 'yes', 'continue', 'ok', 'subscribe', 'sign up', 'get', 'start', 'buy', 'confirm'];
      const aIsNeg = negativeWords.some(w => aText.includes(w));
      const bIsNeg = negativeWords.some(w => bText.includes(w));
      const aIsPos = positiveWords.some(w => aText.includes(w));
      const bIsPos = positiveWords.some(w => bText.includes(w));
      if ((aIsNeg && bIsPos) || (aIsPos && bIsNeg)) {
        if (sizeRatio > 1.5) {
          findings.push({
            type: 'asymmetric-buttons',
            severity: 'medium',
            positive: aIsPos ? aText.slice(0, 40) : bText.slice(0, 40),
            negative: aIsNeg ? aText.slice(0, 40) : bText.slice(0, 40),
            sizeRatio: Math.round(sizeRatio * 10) / 10,
            positiveArea: aIsPos ? Math.round(aArea) : Math.round(bArea),
            negativeArea: aIsNeg ? Math.round(aArea) : Math.round(bArea)
          });
        }
      }
    }
  }
  const allElements = document.querySelectorAll('*');
  for (const el of allElements) {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) {
      if (parseFloat(style.opacity) < 0.3 && parseFloat(style.opacity) > 0) {
        const text = el.textContent?.trim().toLowerCase() || '';
        if (text.includes('unsubscribe') || text.includes('opt out') || text.includes('cancel')
          || text.includes('decline') || text.includes('privacy') || text.includes('terms')) {
          findings.push({
            type: 'hidden-important-element',
            severity: 'high',
            text: el.textContent?.trim().slice(0, 80),
            opacity: parseFloat(style.opacity),
            tag: el.tagName.toLowerCase()
          });
        }
      }
      if (parseFloat(style.fontSize) < 10) {
        const text = el.textContent?.trim().toLowerCase() || '';
        if (text.includes('unsubscribe') || text.includes('opt out') || text.includes('cancel')
          || text.includes('recurring') || text.includes('auto-renew') || text.includes('billed')) {
          findings.push({
            type: 'tiny-important-text',
            severity: 'medium',
            text: el.textContent?.trim().slice(0, 80),
            fontSize: parseFloat(style.fontSize),
            tag: el.tagName.toLowerCase()
          });
        }
      }
    }
  }
  for (const btn of allButtons) {
    const text = btn.textContent?.trim().toLowerCase() || '';
    const shamingPhrases = ['no, i don\'t want', 'no, i prefer', 'i don\'t like', 'i\'ll pass on', 'no thanks, i\'d rather', 'i don\'t need', 'no, i hate'];
    for (const phrase of shamingPhrases) {
      if (text.includes(phrase)) {
        findings.push({
          type: 'confirm-shaming',
          severity: 'high',
          text: btn.textContent?.trim().slice(0, 100),
          tag: btn.tagName.toLowerCase()
        });
        break;
      }
    }
  }
  const urgencyElements = document.querySelectorAll('[class*="countdown"], [class*="timer"], [class*="hurry"], [class*="limited"], [class*="urgent"], [class*="scarcity"]');
  for (const el of urgencyElements) {
    findings.push({
      type: 'false-urgency',
      severity: 'low',
      text: el.textContent?.trim().slice(0, 80),
      classes: (typeof el.className === 'string' ? el.className : '').slice(0, 60),
      tag: el.tagName.toLowerCase()
    });
  }
  return JSON.stringify({
    totalFindings: findings.length,
    bySeverity: {
      high: findings.filter(f => f.severity === 'high').length,
      medium: findings.filter(f => f.severity === 'medium').length,
      low: findings.filter(f => f.severity === 'low').length
    },
    byType: {
      preCheckedOptIns: findings.filter(f => f.type === 'pre-checked-opt-in').length,
      asymmetricButtons: findings.filter(f => f.type === 'asymmetric-buttons').length,
      hiddenElements: findings.filter(f => f.type === 'hidden-important-element').length,
      tinyText: findings.filter(f => f.type === 'tiny-important-text').length,
      confirmShaming: findings.filter(f => f.type === 'confirm-shaming').length,
      falseUrgency: findings.filter(f => f.type === 'false-urgency').length
    },
    findings: findings.slice(0, 50)
  });
})()
```

**Returns:** `{ totalFindings, bySeverity: { high, medium, low }, byType: { preCheckedOptIns, asymmetricButtons, hiddenElements, tinyText, confirmShaming, falseUrgency }, findings }`.
