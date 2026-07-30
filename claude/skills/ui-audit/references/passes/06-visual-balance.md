# Pass 6: Visual Balance & Composition

Evaluates whether the page layout achieves visual balance through intentional weight distribution, harmonious proportions, purposeful whitespace, and a clear visual flow that guides the user's eye from focal point through supporting content.

## Tier 0: Code Analysis

Before launching the browser, analyze the source code for layout and composition patterns:

1. **Layout structure** — Detect layout approach from templates: CSS Grid vs Flexbox vs floats. Check for nested container patterns and how content is distributed across the viewport.
2. **Width constraints** — Check for explicit `max-width` on containers (content should not span full viewport width on large screens). Look for `max-width: 80rem`, `max-width: 1200px`, or similar constraints in CSS/Tailwind classes.
3. **Aspect ratio usage** — Check for `aspect-ratio` property, padding-trick ratios (`padding-bottom: 56.25%`), or fixed width/height ratios on media elements.
4. **Section structure consistency** — Compare section markup across pages/templates. Do all sections follow a consistent pattern (heading + description + content + CTA)? Or is each section structurally unique?
5. **Grid system** — Detect if a formal grid system is in use (12-column grid, CSS Grid template areas, Tailwind's grid classes). Check for consistent column counts and breakpoint behavior.
6. **Whitespace tokens** — Check if large spacing values (section padding, hero margins) use design tokens or consistent values, or if they appear arbitrary.

## Tier 1: Automated Browser Checks

### 6.1 Measure Visual Weight Distribution

```javascript
(() => {
  const viewport = { w: window.innerWidth, h: window.innerHeight };
  const elements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, img, video, svg, button, a, input, select, textarea, [class*="card"], [class*="Card"], [class*="hero"], [class*="Hero"], table, iframe, canvas');

  function parseRGB(color) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function lum(r, g, b) {
    const [rs, gs, bs] = [r, g, b].map(c => {
      c = c / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
  }

  const pageBgEl = document.body;
  const pageBgColor = parseRGB(window.getComputedStyle(pageBgEl).backgroundColor) || { r: 255, g: 255, b: 255 };
  const pageBgLum = lum(pageBgColor.r, pageBgColor.g, pageBgColor.b);

  const quadrants = {
    topLeft: { weight: 0, elements: 0 },
    topRight: { weight: 0, elements: 0 },
    bottomLeft: { weight: 0, elements: 0 },
    bottomRight: { weight: 0, elements: 0 }
  };

  const midX = viewport.w / 2;
  const midY = viewport.h / 2;
  let totalWeight = 0;

  const sampled = Array.from(elements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && rect.top < viewport.h * 1.5;
  }).slice(0, 200);

  sampled.forEach(el => {
    const rect = el.getBoundingClientRect();
    const style = window.getComputedStyle(el);
    const area = rect.width * rect.height;

    const fgColor = parseRGB(style.color);
    const bgColor = parseRGB(style.backgroundColor);

    let contrastFactor = 1;
    if (fgColor) {
      const fgLum = lum(fgColor.r, fgColor.g, fgColor.b);
      contrastFactor = Math.abs(fgLum - pageBgLum) + 0.5;
    }
    if (bgColor && bgColor.r + bgColor.g + bgColor.b < 700) {
      const bgLum = lum(bgColor.r, bgColor.g, bgColor.b);
      contrastFactor = Math.max(contrastFactor, Math.abs(bgLum - pageBgLum) + 0.5);
    }

    const fontWeight = parseInt(style.fontWeight) || 400;
    const weightFactor = fontWeight >= 700 ? 1.3 : fontWeight >= 500 ? 1.1 : 1;

    const fontSize = parseFloat(style.fontSize) || 16;
    const sizeFactor = fontSize > 24 ? 1.4 : fontSize > 18 ? 1.2 : 1;

    const visualWeight = area * contrastFactor * weightFactor * sizeFactor;

    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;

    const qKey = `${centerY < midY ? 'top' : 'bottom'}${centerX < midX ? 'Left' : 'Right'}`;
    quadrants[qKey].weight += visualWeight;
    quadrants[qKey].elements++;
    totalWeight += visualWeight;
  });

  const distribution = {};
  for (const [q, data] of Object.entries(quadrants)) {
    distribution[q] = {
      weightPercent: totalWeight > 0 ? Math.round((data.weight / totalWeight) * 100) : 0,
      elements: data.elements
    };
  }

  const maxQuadrant = Math.max(...Object.values(distribution).map(d => d.weightPercent));
  const minQuadrant = Math.min(...Object.values(distribution).map(d => d.weightPercent));
  const imbalance = maxQuadrant - minQuadrant;

  const topWeight = distribution.topLeft.weightPercent + distribution.topRight.weightPercent;
  const bottomWeight = distribution.bottomLeft.weightPercent + distribution.bottomRight.weightPercent;
  const leftWeight = distribution.topLeft.weightPercent + distribution.bottomLeft.weightPercent;
  const rightWeight = distribution.topRight.weightPercent + distribution.bottomRight.weightPercent;

  const issues = [];
  if (maxQuadrant > 40) {
    const heaviest = Object.entries(distribution).sort((a, b) => b[1].weightPercent - a[1].weightPercent)[0];
    issues.push({
      type: 'heavy-quadrant',
      quadrant: heaviest[0],
      weight: heaviest[1].weightPercent,
      message: `${heaviest[0]} quadrant holds ${heaviest[1].weightPercent}% of visual weight. No quadrant should exceed 40% for balanced composition.`
    });
  }
  if (Math.abs(leftWeight - rightWeight) > 30) {
    issues.push({
      type: 'horizontal-imbalance',
      leftWeight,
      rightWeight,
      message: `Horizontal imbalance: left ${leftWeight}% vs right ${rightWeight}%. Difference of ${Math.abs(leftWeight - rightWeight)}%.`
    });
  }
  if (Math.abs(topWeight - bottomWeight) > 40) {
    issues.push({
      type: 'vertical-imbalance',
      topWeight,
      bottomWeight,
      message: `Vertical imbalance: top ${topWeight}% vs bottom ${bottomWeight}%. Top-heavy or bottom-heavy layout.`
    });
  }

  return {
    viewport,
    elementsAnalyzed: sampled.length,
    quadrantDistribution: distribution,
    horizontalBalance: { left: leftWeight, right: rightWeight, diff: Math.abs(leftWeight - rightWeight) },
    verticalBalance: { top: topWeight, bottom: bottomWeight, diff: Math.abs(topWeight - bottomWeight) },
    maxQuadrantWeight: maxQuadrant,
    imbalanceScore: imbalance,
    balanceScore: Math.max(0, 100 - imbalance * 2),
    issues
  };
})()
```

### 6.2 Measure Whitespace Ratio

```javascript
(() => {
  const viewport = { w: window.innerWidth, h: window.innerHeight };
  const scrollHeight = Math.min(document.documentElement.scrollHeight, viewport.h * 5);
  const totalPageArea = viewport.w * scrollHeight;

  const sections = document.querySelectorAll('section, article, header, footer, main, aside, nav, [class*="hero"], [class*="Hero"]');
  const macroWhitespace = { total: 0, gaps: [] };

  const sortedSections = Array.from(sections)
    .map(el => ({ el, rect: el.getBoundingClientRect() }))
    .filter(s => s.rect.height > 0)
    .sort((a, b) => a.rect.top - b.rect.top);

  for (let i = 0; i < sortedSections.length - 1; i++) {
    const gap = sortedSections[i + 1].rect.top - sortedSections[i].rect.bottom;
    if (gap > 0 && gap < 500) {
      macroWhitespace.gaps.push({
        between: `${sortedSections[i].el.tagName.toLowerCase()} -> ${sortedSections[i + 1].el.tagName.toLowerCase()}`,
        gap: Math.round(gap)
      });
      macroWhitespace.total += gap * viewport.w;
    }
  }

  const contentElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, img, video, button, a, input, table, ul, ol, [class*="card"], [class*="Card"]');
  let contentArea = 0;

  const sampled = Array.from(contentElements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && rect.top < scrollHeight;
  }).slice(0, 300);

  sampled.forEach(el => {
    const rect = el.getBoundingClientRect();
    contentArea += rect.width * rect.height;
  });

  const viewportArea = viewport.w * viewport.h;
  const aboveFoldContent = sampled.filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.top < viewport.h;
  }).reduce((sum, el) => {
    const rect = el.getBoundingClientRect();
    const visibleHeight = Math.min(rect.bottom, viewport.h) - Math.max(rect.top, 0);
    return sum + rect.width * Math.max(0, visibleHeight);
  }, 0);

  const aboveFoldWhitespaceRatio = Math.round(((viewportArea - aboveFoldContent) / viewportArea) * 100);

  const macroGaps = macroWhitespace.gaps.map(g => g.gap);
  const uniqueMacroGaps = [...new Set(macroGaps)].sort((a, b) => a - b);
  const macroConsistent = uniqueMacroGaps.length <= 3;

  const issues = [];
  if (aboveFoldWhitespaceRatio < 25) {
    issues.push({
      type: 'cramped-above-fold',
      ratio: aboveFoldWhitespaceRatio,
      message: `Above-fold whitespace is only ${aboveFoldWhitespaceRatio}%. Target 30-50% for breathing room.`
    });
  }
  if (aboveFoldWhitespaceRatio > 65) {
    issues.push({
      type: 'excessive-whitespace',
      ratio: aboveFoldWhitespaceRatio,
      message: `Above-fold whitespace is ${aboveFoldWhitespaceRatio}%. Content feels sparse — consider adding visual elements.`
    });
  }
  if (!macroConsistent && macroWhitespace.gaps.length > 2) {
    issues.push({
      type: 'inconsistent-section-spacing',
      uniqueGaps: uniqueMacroGaps,
      message: `${uniqueMacroGaps.length} different section gap sizes detected (${uniqueMacroGaps.join(', ')}px). Use 1-3 consistent values.`
    });
  }

  return {
    viewport,
    aboveFoldWhitespacePercent: aboveFoldWhitespaceRatio,
    macroWhitespace: {
      sectionGaps: macroWhitespace.gaps.slice(0, 10),
      uniqueGapValues: uniqueMacroGaps,
      isConsistent: macroConsistent
    },
    contentElementsCounted: sampled.length,
    whitespaceBand: aboveFoldWhitespaceRatio >= 30 && aboveFoldWhitespaceRatio <= 50 ? 'ideal' :
                    aboveFoldWhitespaceRatio < 30 ? 'cramped' : 'sparse',
    issues
  };
})()
```

### 6.3 Check Layout Symmetry

```javascript
(() => {
  const viewport = { w: window.innerWidth, h: window.innerHeight };
  const sections = document.querySelectorAll('section, [class*="section"], [class*="Section"], header, footer, main > div, [class*="hero"], [class*="Hero"], [class*="banner"], [class*="Banner"]');

  const results = [];
  const issues = [];
  const centerX = viewport.w / 2;

  const sampled = Array.from(sections).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > viewport.w * 0.5 && rect.height > 40;
  }).slice(0, 20);

  sampled.forEach(section => {
    const children = Array.from(section.children).filter(el => {
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    });

    if (children.length < 1) return;

    let leftWeight = 0;
    let rightWeight = 0;

    children.forEach(child => {
      const rect = child.getBoundingClientRect();
      const childCenter = rect.left + rect.width / 2;
      const area = rect.width * rect.height;

      if (childCenter < centerX) {
        leftWeight += area;
      } else {
        rightWeight += area;
      }
    });

    const totalWeight = leftWeight + rightWeight;
    const asymmetry = totalWeight > 0
      ? Math.round(Math.abs(leftWeight - rightWeight) / totalWeight * 100)
      : 0;

    const style = window.getComputedStyle(section);
    const isFlexOrGrid = style.display === 'flex' || style.display === 'grid';
    const isCentered = style.justifyContent === 'center' || style.textAlign === 'center' ||
                       (style.marginLeft === 'auto' && style.marginRight === 'auto');

    const sectionRect = section.getBoundingClientRect();
    const contentCenterX = sectionRect.left + sectionRect.width / 2;
    const centerOffset = Math.abs(contentCenterX - centerX);

    const entry = {
      tag: section.tagName.toLowerCase(),
      classes: (section.className || '').toString().substring(0, 50),
      childCount: children.length,
      leftWeightPercent: totalWeight > 0 ? Math.round((leftWeight / totalWeight) * 100) : 50,
      rightWeightPercent: totalWeight > 0 ? Math.round((rightWeight / totalWeight) * 100) : 50,
      asymmetryPercent: asymmetry,
      isCentered,
      isFlexOrGrid,
      centerOffsetPx: Math.round(centerOffset)
    };

    results.push(entry);

    if (asymmetry > 30 && !isCentered && children.length > 1) {
      issues.push({
        type: 'unbalanced-section',
        ...entry,
        message: `Section ${entry.tag}.${entry.classes.split(' ')[0]} is ${asymmetry}% asymmetric (left: ${entry.leftWeightPercent}%, right: ${entry.rightWeightPercent}%). Check intentionality.`
      });
    }
  });

  const avgAsymmetry = results.length > 0
    ? Math.round(results.reduce((sum, r) => sum + r.asymmetryPercent, 0) / results.length)
    : 0;

  return {
    sectionsAnalyzed: results.length,
    averageAsymmetry: avgAsymmetry,
    symmetryScore: Math.max(0, 100 - avgAsymmetry),
    sections: results.slice(0, 12),
    issues: issues.slice(0, 8)
  };
})()
```

### 6.4 Measure Proportional Harmony (Golden Ratio)

```javascript
(() => {
  const PHI = 1.618;
  const PHI_TOLERANCE = 0.15;
  const viewport = { w: window.innerWidth, h: window.innerHeight };

  function ratioDistance(actual, target) {
    return Math.abs(actual - target) / target;
  }

  function isNearGolden(ratio) {
    const r = ratio > 1 ? ratio : 1 / ratio;
    return ratioDistance(r, PHI) <= PHI_TOLERANCE;
  }

  const measurements = [];
  const issues = [];

  const heroSection = document.querySelector('[class*="hero"], [class*="Hero"], [class*="banner"], [class*="Banner"], header');
  if (heroSection) {
    const rect = heroSection.getBoundingClientRect();
    const ratio = rect.width / rect.height;
    measurements.push({
      element: 'hero-section',
      width: Math.round(rect.width),
      height: Math.round(rect.height),
      ratio: Math.round(ratio * 1000) / 1000,
      goldenDistance: Math.round(ratioDistance(ratio > 1 ? ratio : 1 / ratio, PHI) * 100),
      isNearGolden: isNearGolden(ratio)
    });
  }

  const images = document.querySelectorAll('img, video, [class*="image"], [class*="Image"]');
  Array.from(images).slice(0, 15).forEach(img => {
    const rect = img.getBoundingClientRect();
    if (rect.width < 50 || rect.height < 50) return;
    const ratio = rect.width / rect.height;
    measurements.push({
      element: 'image',
      src: (img.src || '').substring(0, 60),
      width: Math.round(rect.width),
      height: Math.round(rect.height),
      ratio: Math.round(ratio * 1000) / 1000,
      goldenDistance: Math.round(ratioDistance(ratio > 1 ? ratio : 1 / ratio, PHI) * 100),
      isNearGolden: isNearGolden(ratio)
    });
  });

  const twoColLayouts = document.querySelectorAll('[class*="grid"], [class*="Grid"], [class*="flex"], [class*="row"], [class*="Row"]');
  Array.from(twoColLayouts).slice(0, 10).forEach(container => {
    const children = Array.from(container.children).filter(el => {
      const rect = el.getBoundingClientRect();
      return rect.width > 50 && rect.height > 50;
    });
    if (children.length !== 2) return;

    const r1 = children[0].getBoundingClientRect();
    const r2 = children[1].getBoundingClientRect();

    const isHorizontal = Math.abs(r1.top - r2.top) < 20;
    if (!isHorizontal) return;

    const widthRatio = Math.max(r1.width, r2.width) / Math.min(r1.width, r2.width);
    measurements.push({
      element: 'two-column-split',
      classes: (container.className || '').toString().substring(0, 50),
      col1Width: Math.round(r1.width),
      col2Width: Math.round(r2.width),
      ratio: Math.round(widthRatio * 1000) / 1000,
      goldenDistance: Math.round(ratioDistance(widthRatio, PHI) * 100),
      isNearGolden: isNearGolden(widthRatio)
    });
  });

  const aboveFoldRatio = viewport.w / viewport.h;
  measurements.push({
    element: 'viewport',
    width: viewport.w,
    height: viewport.h,
    ratio: Math.round(aboveFoldRatio * 1000) / 1000,
    goldenDistance: Math.round(ratioDistance(aboveFoldRatio > 1 ? aboveFoldRatio : 1 / aboveFoldRatio, PHI) * 100),
    isNearGolden: isNearGolden(aboveFoldRatio)
  });

  const goldenCount = measurements.filter(m => m.isNearGolden).length;
  const harmonyScore = measurements.length > 0
    ? Math.round((goldenCount / measurements.length) * 100)
    : 0;

  const commonRatios = { '1:1': 1, '4:3': 1.333, '3:2': 1.5, 'golden': PHI, '16:9': 1.778, '2:1': 2 };
  const ratioDistribution = {};
  measurements.forEach(m => {
    const r = m.ratio > 1 ? m.ratio : 1 / m.ratio;
    let closest = 'other';
    let minDist = Infinity;
    for (const [name, target] of Object.entries(commonRatios)) {
      const dist = Math.abs(r - target);
      if (dist < minDist && dist < 0.3) {
        minDist = dist;
        closest = name;
      }
    }
    ratioDistribution[closest] = (ratioDistribution[closest] || 0) + 1;
  });

  return {
    measurementCount: measurements.length,
    goldenRatioMatches: goldenCount,
    harmonyScore,
    ratioDistribution,
    measurements: measurements.slice(0, 15),
    issues
  };
})()
```

### 6.5 Check Visual Flow (Eye Tracking Path)

```javascript
(() => {
  const viewport = { w: window.innerWidth, h: window.innerHeight };

  function parseRGB(color) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return null;
    return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
  }

  function saturation(r, g, b) {
    const max = Math.max(r, g, b) / 255;
    const min = Math.min(r, g, b) / 255;
    if (max === 0) return 0;
    return (max - min) / max;
  }

  const allElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, img, video, button, [role="button"], a[class*="btn"], a[class*="button"], a[class*="cta"], [class*="hero"], [class*="Hero"], [class*="cta"], [class*="CTA"], svg');

  const dominantElements = [];

  Array.from(allElements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 20 && rect.height > 20 && rect.top < viewport.h * 2;
  }).slice(0, 50).forEach(el => {
    const rect = el.getBoundingClientRect();
    const style = window.getComputedStyle(el);
    const area = rect.width * rect.height;
    const fontSize = parseFloat(style.fontSize) || 16;
    const fontWeight = parseInt(style.fontWeight) || 400;

    const bgColor = parseRGB(style.backgroundColor);
    const fgColor = parseRGB(style.color);

    let colorSat = 0;
    if (bgColor) colorSat = Math.max(colorSat, saturation(bgColor.r, bgColor.g, bgColor.b));
    if (fgColor) colorSat = Math.max(colorSat, saturation(fgColor.r, fgColor.g, fgColor.b));

    const dominanceScore = (area / (viewport.w * viewport.h)) * 100 +
                           (fontSize / 16) * 10 +
                           (fontWeight >= 700 ? 15 : 0) +
                           colorSat * 20;

    dominantElements.push({
      tag: el.tagName.toLowerCase(),
      text: (el.textContent || '').trim().substring(0, 50),
      x: Math.round(rect.left + rect.width / 2),
      y: Math.round(rect.top + rect.height / 2),
      area: Math.round(area),
      fontSize,
      fontWeight,
      saturation: Math.round(colorSat * 100),
      dominanceScore: Math.round(dominanceScore * 100) / 100
    });
  });

  dominantElements.sort((a, b) => b.dominanceScore - a.dominanceScore);
  const topElements = dominantElements.slice(0, 8);

  let patternType = 'unknown';
  if (topElements.length >= 3) {
    const first = topElements[0];
    const second = topElements[1];
    const third = topElements[2];

    const startsTopLeft = first.x < viewport.w * 0.6 && first.y < viewport.h * 0.5;
    const secondRight = second.x > viewport.w * 0.5;
    const thirdLeft = third.x < viewport.w * 0.5;

    if (startsTopLeft && secondRight && thirdLeft) {
      patternType = 'Z-pattern';
    } else if (startsTopLeft && !secondRight) {
      patternType = 'F-pattern';
    } else if (first.x > viewport.w * 0.3 && first.x < viewport.w * 0.7) {
      patternType = 'center-focal';
    } else {
      patternType = 'scattered';
    }
  }

  const hasClearFocalPoint = topElements.length > 1 &&
    topElements[0].dominanceScore > topElements[1].dominanceScore * 1.3;

  const flowPath = topElements.map((el, i) => ({
    step: i + 1,
    element: `${el.tag}: "${el.text.substring(0, 30)}"`,
    position: { x: el.x, y: el.y },
    dominanceScore: el.dominanceScore
  }));

  const issues = [];
  if (!hasClearFocalPoint && topElements.length > 1) {
    issues.push({
      type: 'no-focal-point',
      message: `No clear focal point. Top 2 elements have similar dominance (${topElements[0].dominanceScore} vs ${topElements[1].dominanceScore}). Make one element clearly dominant.`
    });
  }
  if (patternType === 'scattered') {
    issues.push({
      type: 'scattered-flow',
      message: 'Visual flow path is scattered. Dominant elements do not form a recognizable reading pattern (F, Z, or center-focal).'
    });
  }

  return {
    dominantElementsFound: dominantElements.length,
    topElements: topElements.slice(0, 6),
    detectedPattern: patternType,
    hasClearFocalPoint,
    flowPath: flowPath.slice(0, 6),
    flowScore: hasClearFocalPoint ? (patternType !== 'scattered' ? 100 : 60) : (patternType !== 'scattered' ? 50 : 20),
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Visual Balance**: Does the page feel visually balanced, or is it noticeably heavier on one side? For symmetric layouts (hero sections, centered content), is symmetry maintained? For asymmetric layouts (sidebar + content), does the heavier side feel intentional?

2. **Intentional Whitespace**: Is whitespace used purposefully to create breathing room and emphasis, or is it just leftover space? Does whitespace feel designed (consistent margins, generous hero padding) or accidental (random gaps, uneven margins)?

3. **Eye Flow Path**: Does the layout guide the eye from the most important element to the next in a logical progression? Can you trace a clear path from focal point through supporting content to call-to-action? Or does your eye bounce randomly?

4. **Orphaned Elements**: Are there any elements that feel visually "orphaned" — floating alone without clear connection to surrounding content? Elements that seem detached from the composition undermine balance.

5. **Clear Focal Point**: Does the composition have one unmistakable focal point? Is it the most important element on the page (hero headline, primary CTA, key image)? Or do multiple elements compete equally for attention?

6. **Appropriate Visual Density**: Is the visual density appropriate for the page type? Dashboards should feel dense and information-rich. Landing pages should feel airy and focused. Does the density match the page's purpose?

7. **Proportional Harmony**: Do proportions feel harmonious — do element sizes, spacing ratios, and column widths feel like they belong to a coherent system? Or do sizes and proportions feel arbitrary?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Clear focal point with dominant element. Balanced composition — no quadrant exceeds 40% visual weight. Intentional whitespace at 30-50% above fold. Harmonious proportions (elements near golden ratio or consistent system). Strong visual flow (F-pattern, Z-pattern, or center-focal). No orphaned elements. |
| 4 | Good balance with minor whitespace inconsistencies. Focal point exists but slightly competes with one other element. Whitespace mostly intentional. Proportions feel considered. Visual flow is clear with one ambiguous step. |
| 3 | Functional but flat composition. No standout focal point — multiple elements share similar visual weight. Whitespace is adequate but not intentional. Some section spacing inconsistent. Proportions workable but arbitrary. |
| 2 | Unbalanced layout — one side or quadrant noticeably heavier. Whitespace either cramped (<25%) or excessive (>65%). No discernible visual flow. Orphaned elements present. Proportions feel random. |
| 1 | No compositional intention. Layout feels like content was placed without design consideration. No focal point, no flow, no whitespace strategy. Elements scattered or uniformly dense with no hierarchy. |

## Common Fixes

### Fix: Constrain content width for balance
```css
.container {
  max-width: 80rem; /* 1280px */
  margin: 0 auto;
  padding: 0 1.5rem;
}

.content-narrow {
  max-width: 65ch; /* Ideal reading width */
  margin: 0 auto;
}
```

**Tailwind equivalent:**
```html
<div class="max-w-7xl mx-auto px-6">
<div class="max-w-prose mx-auto">
```

### Fix: Create intentional whitespace hierarchy
```css
/* Hero sections get maximum breathing room */
.hero {
  padding: 6rem 2rem;
}

/* Regular sections get moderate spacing */
section {
  padding: 4rem 2rem;
}

/* Compact sections (features, testimonials) */
.section-compact {
  padding: 3rem 2rem;
}
```

**Tailwind equivalent:**
```html
<section class="py-24 px-8">   <!-- hero -->
<section class="py-16 px-8">   <!-- standard -->
<section class="py-12 px-8">   <!-- compact -->
```

### Fix: Establish focal point emphasis
```css
/* Make hero headline visually dominant */
.hero-headline {
  font-size: clamp(2.5rem, 5vw, 4.5rem);
  font-weight: 800;
  line-height: 1.1;
  max-width: 20ch;
}

/* Reduce visual weight of secondary elements */
.supporting-text {
  font-size: 1.125rem;
  color: var(--color-text-secondary);
  font-weight: 400;
  max-width: 50ch;
}
```

**Tailwind equivalent:**
```html
<h1 class="text-5xl lg:text-7xl font-extrabold leading-tight max-w-[20ch]">
<p class="text-lg text-gray-600 font-normal max-w-prose">
```

### Fix: Balance two-column layouts with golden ratio
```css
/* Content + sidebar: golden ratio split */
.layout-golden {
  display: grid;
  grid-template-columns: 1fr 0.618fr; /* ~62% / ~38% */
  gap: 2rem;
}

/* Equal emphasis: 50/50 */
.layout-equal {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
}
```

**Tailwind equivalent:**
```html
<div class="grid grid-cols-[1fr_0.618fr] gap-8">
<div class="grid grid-cols-2 gap-8">
```

### Fix: Guide visual flow with element ordering
```css
/* Place focal point at natural starting position */
.hero-content {
  display: flex;
  flex-direction: column;
  align-items: flex-start; /* Left-aligned for F-pattern */
  gap: 1.5rem;
}

/* CTA follows supporting text naturally */
.hero-cta {
  margin-top: 2rem;
}
```
