# Pass 1: Visual Hierarchy

## Tier 1: Automated Checks

### 1.1 Dominant Element Detection

```javascript
(() => {
  const elements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, a, button, img, video, [role="heading"]');
  const viewport = { w: window.innerWidth, h: window.innerHeight };
  const results = [];

  elements.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    const style = window.getComputedStyle(el);
    const area = rect.width * rect.height;
    const viewportArea = viewport.w * viewport.h;
    const areaRatio = area / viewportArea;
    const fontSize = parseFloat(style.fontSize) || 0;
    const fontWeight = parseInt(style.fontWeight) || 400;
    const isAboveFold = rect.top < viewport.h;

    results.push({
      tag: el.tagName.toLowerCase(),
      text: (el.textContent || '').trim().substring(0, 80),
      area: Math.round(area),
      areaRatio: Math.round(areaRatio * 10000) / 100,
      fontSize,
      fontWeight,
      isAboveFold,
      x: Math.round(rect.left),
      y: Math.round(rect.top),
      width: Math.round(rect.width),
      height: Math.round(rect.height)
    });
  });

  results.sort((a, b) => b.areaRatio - a.areaRatio);

  const aboveFold = results.filter(r => r.isAboveFold);
  const dominantElement = aboveFold[0] || null;
  const topElements = aboveFold.slice(0, 10);

  return {
    totalElementsAnalyzed: results.length,
    aboveFoldCount: aboveFold.length,
    dominantElement,
    topElementsByArea: topElements,
    viewport
  };
})()
```

### 1.2 Flat Hierarchy Detection (All Elements Same Size/Weight)

```javascript
(() => {
  const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6, [role="heading"]');
  const sizeMap = {};
  const weightMap = {};
  const issues = [];

  headings.forEach(el => {
    const style = window.getComputedStyle(el);
    const fontSize = Math.round(parseFloat(style.fontSize));
    const fontWeight = parseInt(style.fontWeight) || 400;
    const tag = el.tagName.toLowerCase();

    if (!sizeMap[tag]) sizeMap[tag] = [];
    sizeMap[tag].push(fontSize);

    if (!weightMap[tag]) weightMap[tag] = [];
    weightMap[tag].push(fontWeight);
  });

  const allSizes = Object.values(sizeMap).flat();
  const uniqueSizes = [...new Set(allSizes)];
  const allWeights = Object.values(weightMap).flat();
  const uniqueWeights = [...new Set(allWeights)];

  const isFlatHierarchy = uniqueSizes.length <= 1 && headings.length > 1;
  const hasWeightContrast = uniqueWeights.length >= 2;
  const sizeRange = allSizes.length > 0 ? Math.max(...allSizes) - Math.min(...allSizes) : 0;

  if (isFlatHierarchy) {
    issues.push({
      type: 'flat-hierarchy',
      message: `All ${headings.length} headings use the same font size (${uniqueSizes[0]}px). No visual hierarchy exists.`
    });
  }

  if (sizeRange > 0 && sizeRange < 4) {
    issues.push({
      type: 'weak-hierarchy',
      message: `Heading size range is only ${sizeRange}px. Minimum 8px difference recommended between levels.`
    });
  }

  if (!hasWeightContrast && headings.length > 1) {
    issues.push({
      type: 'no-weight-contrast',
      message: 'All headings use the same font weight. Use at least 2 weight steps for hierarchy.'
    });
  }

  const tagSizeConsistency = {};
  for (const [tag, sizes] of Object.entries(sizeMap)) {
    const unique = [...new Set(sizes)];
    if (unique.length > 1) {
      tagSizeConsistency[tag] = {
        consistent: false,
        sizes: unique,
        message: `${tag} elements have inconsistent sizes: ${unique.join(', ')}px`
      };
      issues.push({ type: 'inconsistent-tag-size', message: tagSizeConsistency[tag].message });
    } else {
      tagSizeConsistency[tag] = { consistent: true, size: unique[0] };
    }
  }

  return {
    headingCount: headings.length,
    uniqueFontSizes: uniqueSizes.sort((a, b) => b - a),
    uniqueFontWeights: uniqueWeights.sort((a, b) => b - a),
    sizeRange,
    isFlatHierarchy,
    hasWeightContrast,
    tagSizeConsistency,
    issues
  };
})()
```

### 1.3 F-Pattern / Z-Pattern Alignment Check

```javascript
(() => {
  const viewport = { w: window.innerWidth, h: window.innerHeight };
  const importantEls = document.querySelectorAll('h1, h2, h3, nav, [role="navigation"], button[type="submit"], .cta, [class*="cta"], [class*="hero"], a[class*="btn"], a[class*="button"]');
  const positions = [];

  importantEls.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    if (rect.top > viewport.h * 2) return;

    const relX = rect.left / viewport.w;
    const relY = rect.top / viewport.h;
    const centerX = (rect.left + rect.width / 2) / viewport.w;
    const centerY = (rect.top + rect.height / 2) / viewport.h;

    positions.push({
      tag: el.tagName.toLowerCase(),
      text: (el.textContent || '').trim().substring(0, 60),
      relativeX: Math.round(relX * 100) / 100,
      relativeY: Math.round(relY * 100) / 100,
      centerX: Math.round(centerX * 100) / 100,
      centerY: Math.round(centerY * 100) / 100,
      quadrant: `${centerY < 0.5 ? 'top' : 'bottom'}-${centerX < 0.5 ? 'left' : 'right'}`
    });
  });

  const topLeftElements = positions.filter(p => p.quadrant === 'top-left');
  const topRightElements = positions.filter(p => p.quadrant === 'top-right');
  const bottomLeftElements = positions.filter(p => p.quadrant === 'bottom-left');
  const bottomRightElements = positions.filter(p => p.quadrant === 'bottom-right');

  const fPatternScore = (() => {
    let score = 0;
    if (topLeftElements.length > 0) score += 30;
    if (positions.some(p => p.relativeY < 0.3 && p.relativeX > 0.5)) score += 20;
    if (positions.some(p => p.relativeY > 0.3 && p.relativeY < 0.7 && p.relativeX < 0.3)) score += 25;
    if (positions.some(p => p.relativeY > 0.5 && p.relativeX < 0.5)) score += 25;
    return score;
  })();

  const zPatternScore = (() => {
    let score = 0;
    if (topLeftElements.length > 0) score += 25;
    if (topRightElements.length > 0) score += 25;
    if (bottomLeftElements.length > 0) score += 25;
    if (bottomRightElements.length > 0) score += 25;
    return score;
  })();

  return {
    elementCount: positions.length,
    positions,
    quadrantDistribution: {
      topLeft: topLeftElements.length,
      topRight: topRightElements.length,
      bottomLeft: bottomLeftElements.length,
      bottomRight: bottomRightElements.length
    },
    fPatternScore,
    zPatternScore,
    suggestedPattern: fPatternScore >= zPatternScore ? 'F-pattern' : 'Z-pattern',
    issues: positions.length === 0 ? [{ type: 'no-landmarks', message: 'No important elements detected above the fold.' }] : []
  };
})()
```

### 1.4 Above-the-Fold Content Density

```javascript
(() => {
  const viewport = { w: window.innerWidth, h: window.innerHeight };
  const allVisible = document.querySelectorAll('h1, h2, h3, p, img, video, button, a, input, select, textarea, [role="button"]');
  const aboveFold = [];
  let totalContentArea = 0;

  allVisible.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    if (rect.bottom < 0 || rect.top > viewport.h) return;

    const visibleTop = Math.max(rect.top, 0);
    const visibleBottom = Math.min(rect.bottom, viewport.h);
    const visibleHeight = visibleBottom - visibleTop;
    const visibleArea = rect.width * visibleHeight;
    totalContentArea += visibleArea;

    aboveFold.push({
      tag: el.tagName.toLowerCase(),
      text: (el.textContent || '').trim().substring(0, 40),
      area: Math.round(visibleArea)
    });
  });

  const viewportArea = viewport.w * viewport.h;
  const densityRatio = totalContentArea / viewportArea;
  const hasCTA = aboveFold.some(el => el.tag === 'button' || el.tag === 'a');
  const hasHeading = aboveFold.some(el => ['h1', 'h2', 'h3'].includes(el.tag));
  const hasImage = aboveFold.some(el => el.tag === 'img' || el.tag === 'video');

  const issues = [];
  if (densityRatio > 1.5) {
    issues.push({ type: 'overcrowded', message: `Above-fold density is ${Math.round(densityRatio * 100)}%. Content overlaps or is too dense.` });
  }
  if (densityRatio < 0.15) {
    issues.push({ type: 'too-sparse', message: `Above-fold density is only ${Math.round(densityRatio * 100)}%. The fold feels empty.` });
  }
  if (!hasCTA) {
    issues.push({ type: 'no-cta', message: 'No call-to-action button or link found above the fold.' });
  }
  if (!hasHeading) {
    issues.push({ type: 'no-heading', message: 'No heading (h1-h3) found above the fold.' });
  }

  return {
    aboveFoldElements: aboveFold.length,
    densityPercent: Math.round(densityRatio * 100),
    hasCTA,
    hasHeading,
    hasImage,
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **First Fixation Point**: Where does your eye go first in the screenshot? Is it the most important element on the page (hero headline, primary CTA, key value proposition)? If your eye goes to a decorative element, logo, or secondary content first, that is a hierarchy failure.

2. **Reading Flow Clarity**: Can you trace a natural reading path from the most important element through supporting content to the call-to-action? Or does the eye bounce randomly? A clear flow means each element logically leads to the next in importance.

3. **Single Memorable Element**: Is there ONE unforgettable element that dominates the page? Great hierarchy means one thing is clearly the star. If everything competes for attention equally, nothing wins.

4. **3-Second Test**: If a first-time visitor saw this page for exactly 3 seconds, would they know (a) what this product/site does, (b) who it is for, and (c) what to do next? Score based on how many of these three are answered.

5. **Size-to-Importance Ratio**: Are the most important elements the largest? Are secondary elements visually subordinate? Check that heading sizes descend logically (h1 > h2 > h3) and that CTAs are larger/bolder than surrounding text.

6. **Visual Weight Distribution**: Is there a clear focal point, or is visual weight evenly distributed creating a flat, boring layout? Look for intentional contrast through size, color, whitespace, or position.

7. **Squint Test**: If you squint at the screenshot until it blurs, can you still identify the primary content block, navigation, and CTA? The macro structure should be readable even when details are lost.

8. **Entry Point Hierarchy for Key User Tasks**: For the primary user task on this page, is the entry point (the first thing to click/read) visually prominent? Or is it buried among equal-weight elements?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Clear dominant element above fold. Eye tracks a deliberate path (F or Z). Heading sizes descend logically with >=8px steps. CTA is visually dominant. 3-second test passes all 3 checks. Zero flat-hierarchy issues detected. |
| 4 | Dominant element exists but competes with 1 other element. Reading flow is mostly clear with 1 ambiguous transition. Heading hierarchy has <=1 inconsistency. 3-second test passes 2 of 3 checks. |
| 3 | Multiple elements compete for dominance. Reading flow requires effort to trace. Heading size differences are <6px between levels. CTA exists but does not stand out. 3-second test passes 1 of 3 checks. |
| 2 | Flat hierarchy detected — most elements are similar size/weight. No clear reading flow. CTA is not visually distinguishable from other links. Headings are inconsistently sized across same levels. |
| 1 | All elements are the same visual weight. No focal point exists. Page feels like a wall of text or a random arrangement. CTA is missing or invisible. 3-second test fails completely. |

## Common Fixes

### Fix: Establish dominant heading
```css
/* Before: All headings same size */
/* After: Clear type scale */
h1 { font-size: 3rem; font-weight: 800; line-height: 1.1; }
h2 { font-size: 2rem; font-weight: 700; line-height: 1.2; }
h3 { font-size: 1.5rem; font-weight: 600; line-height: 1.3; }
```

**Tailwind equivalent:**
```html
<h1 class="text-5xl font-extrabold leading-tight">
<h2 class="text-3xl font-bold leading-snug">
<h3 class="text-2xl font-semibold leading-normal">
```

### Fix: Make CTA visually dominant
```css
.cta-primary {
  font-size: 1.125rem;
  font-weight: 700;
  padding: 0.875rem 2rem;
  border-radius: 0.5rem;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.15);
}
```

**Tailwind equivalent:**
```html
<button class="text-lg font-bold py-3.5 px-8 rounded-lg shadow-lg">
```

### Fix: Create visual weight contrast
```css
/* Add whitespace around hero to make it stand out */
.hero-section {
  padding: 5rem 2rem;
  margin-bottom: 3rem;
}

/* Reduce visual weight of secondary content */
.secondary-content {
  font-size: 0.875rem;
  color: #6b7280;
  font-weight: 400;
}
```

**Tailwind equivalent:**
```html
<section class="py-20 px-8 mb-12">
<div class="text-sm text-gray-500 font-normal">
```

### Fix: Improve F-pattern alignment
```css
/* Align key content to left for F-pattern scanning */
.content-section {
  text-align: left;
  max-width: 65ch;
}

/* Place CTA in natural F-pattern termination point */
.cta-container {
  margin-top: 2rem;
  display: flex;
  justify-content: flex-start;
}
```
