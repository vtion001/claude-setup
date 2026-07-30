# Pass 5: Gestalt Principles

Evaluates whether the UI leverages the six core Gestalt principles (proximity, similarity, continuity, closure, figure-ground, common region) to communicate relationships, reduce cognitive load, and create instantly legible groupings.

## Tier 0: Code Analysis

Before launching the browser, analyze the source code for structural grouping patterns:

1. **Container grouping** — Search component templates (JSX/TSX/HTML/Vue) for grouping patterns. Are related items wrapped in shared containers (`div`, `section`, `fieldset`, `article`, `ul`, `ol`, `dl`)? Look for semantic grouping elements vs flat DOM structures.
2. **Visual grouping CSS** — Check for CSS that creates visual regions: `border`, `border-radius`, `background-color`, `box-shadow`, `padding` applied to container elements. These create "common region" cues.
3. **List and grid patterns** — Detect whether related items use consistent list/grid containers (`ul > li`, CSS Grid, Flexbox with `gap`). Flat sibling `<div>` elements without a wrapper signal weak grouping.
4. **Form organization** — Check form markup for `<fieldset>` + `<legend>`, or wrapper `<div>`/`<section>` elements that group related fields. Forms with all inputs as flat siblings lack proximity structure.
5. **Spacing tokens** — Check if spacing between groups (inter-group) uses larger tokens than spacing within groups (intra-group). Look at gap/margin/padding values in CSS custom properties or Tailwind classes.
6. **Consistent component patterns** — Check whether all cards, list items, buttons, or nav items use the same internal structure and CSS classes (similarity principle at the code level).

## Tier 1: Automated Browser Checks

### 5.1 Measure Proximity Ratios

```javascript
(() => {
  const groups = [
    { name: 'formFields', selector: 'form, [class*="form"], fieldset' },
    { name: 'navItems', selector: 'nav, [role="navigation"], [class*="nav"]' },
    { name: 'cardLists', selector: '[class*="grid"], [class*="list"], [class*="cards"], ul, ol' },
    { name: 'buttonGroups', selector: '[class*="actions"], [class*="buttons"], [class*="toolbar"], [role="toolbar"]' }
  ];

  const results = [];

  groups.forEach(({ name, selector }) => {
    const containers = document.querySelectorAll(selector);
    containers.forEach(container => {
      const children = Array.from(container.children).filter(el => {
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      });
      if (children.length < 2) return;

      const intraGaps = [];
      for (let i = 0; i < children.length - 1; i++) {
        const r1 = children[i].getBoundingClientRect();
        const r2 = children[i + 1].getBoundingClientRect();
        const isHorizontal = Math.abs(r1.top - r2.top) < r1.height * 0.5;
        const gap = isHorizontal
          ? Math.max(0, r2.left - r1.right)
          : Math.max(0, r2.top - r1.bottom);
        intraGaps.push(Math.round(gap));
      }

      const containerRect = container.getBoundingClientRect();
      const nextSibling = container.nextElementSibling;
      const prevSibling = container.previousElementSibling;
      const interGaps = [];

      if (nextSibling) {
        const nextRect = nextSibling.getBoundingClientRect();
        const gap = Math.max(0, nextRect.top - containerRect.bottom);
        if (gap < 500) interGaps.push(Math.round(gap));
      }
      if (prevSibling) {
        const prevRect = prevSibling.getBoundingClientRect();
        const gap = Math.max(0, containerRect.top - prevRect.bottom);
        if (gap < 500) interGaps.push(Math.round(gap));
      }

      const avgIntra = intraGaps.length > 0
        ? Math.round(intraGaps.reduce((a, b) => a + b, 0) / intraGaps.length)
        : 0;
      const avgInter = interGaps.length > 0
        ? Math.round(interGaps.reduce((a, b) => a + b, 0) / interGaps.length)
        : 0;
      const proximityRatio = avgIntra > 0 ? Math.round((avgInter / avgIntra) * 100) / 100 : null;

      results.push({
        group: name,
        element: container.tagName.toLowerCase(),
        classes: (container.className || '').toString().substring(0, 60),
        childCount: children.length,
        intraGroupGaps: intraGaps,
        avgIntraGap: avgIntra,
        avgInterGap: avgInter,
        proximityRatio,
        passes: proximityRatio === null || proximityRatio >= 2
      });
    });
  });

  const passing = results.filter(r => r.passes).length;
  const failing = results.filter(r => !r.passes).length;
  const issues = results
    .filter(r => !r.passes)
    .map(r => ({
      type: 'weak-proximity',
      group: r.group,
      ratio: r.proximityRatio,
      message: `${r.group} container (${r.element}.${r.classes.split(' ')[0]}) has proximity ratio ${r.proximityRatio}x. Inter-group gap (${r.avgInterGap}px) should be >=2x intra-group gap (${r.avgIntraGap}px).`
    }));

  return {
    groupsAnalyzed: results.length,
    passing,
    failing,
    proximityScore: results.length > 0 ? Math.round((passing / results.length) * 100) : 100,
    details: results.slice(0, 15),
    issues: issues.slice(0, 10)
  };
})()
```

### 5.2 Check Similarity Across Same-Type Elements

```javascript
(() => {
  const typeSelectors = {
    buttons: 'button, [role="button"], a[class*="btn"], a[class*="button"], input[type="submit"]',
    cards: '[class*="card"], [class*="Card"], [class*="tile"], [class*="Tile"]',
    listItems: 'ul > li, ol > li',
    headings: 'h1, h2, h3, h4, h5, h6',
    navLinks: 'nav a, [role="navigation"] a',
    inputs: 'input[type="text"], input[type="email"], input[type="password"], input[type="search"], textarea, select'
  };

  const results = {};
  const issues = [];

  for (const [typeName, selector] of Object.entries(typeSelectors)) {
    const elements = Array.from(document.querySelectorAll(selector)).filter(el => {
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    }).slice(0, 30);

    if (elements.length < 2) continue;

    const styles = elements.map(el => {
      const s = window.getComputedStyle(el);
      return {
        fontSize: Math.round(parseFloat(s.fontSize) || 0),
        fontWeight: parseInt(s.fontWeight) || 400,
        color: s.color,
        backgroundColor: s.backgroundColor,
        borderRadius: s.borderRadius,
        paddingTop: Math.round(parseFloat(s.paddingTop) || 0),
        paddingLeft: Math.round(parseFloat(s.paddingLeft) || 0),
        paddingBottom: Math.round(parseFloat(s.paddingBottom) || 0),
        paddingRight: Math.round(parseFloat(s.paddingRight) || 0),
        height: Math.round(el.getBoundingClientRect().height)
      };
    });

    const props = ['fontSize', 'fontWeight', 'color', 'backgroundColor', 'borderRadius', 'paddingTop', 'paddingLeft'];
    const deviations = {};

    for (const prop of props) {
      const values = styles.map(s => s[prop]);
      const unique = [...new Set(values)];
      const mode = values.sort((a, b) =>
        values.filter(v => v === a).length - values.filter(v => v === b).length
      ).pop();
      const deviating = values.filter(v => v !== mode).length;
      const deviationPct = Math.round((deviating / values.length) * 100);

      deviations[prop] = {
        uniqueValues: unique.length,
        mode,
        deviationPercent: deviationPct,
        consistent: deviationPct <= 10
      };
    }

    const inconsistentProps = Object.entries(deviations)
      .filter(([_, d]) => !d.consistent)
      .map(([prop, d]) => prop);

    const consistencyScore = Math.round(
      (Object.values(deviations).filter(d => d.consistent).length / props.length) * 100
    );

    results[typeName] = {
      count: elements.length,
      consistencyScore,
      deviations,
      inconsistentProperties: inconsistentProps
    };

    if (inconsistentProps.length > 0) {
      issues.push({
        type: 'similarity-violation',
        elementType: typeName,
        inconsistentProps: inconsistentProps,
        consistencyScore,
        message: `${typeName} elements have inconsistent ${inconsistentProps.join(', ')}. ${consistencyScore}% overall consistency.`
      });
    }
  }

  const overallScore = Object.values(results).length > 0
    ? Math.round(Object.values(results).reduce((sum, r) => sum + r.consistencyScore, 0) / Object.values(results).length)
    : 100;

  return {
    typesAnalyzed: Object.keys(results).length,
    overallSimilarityScore: overallScore,
    results,
    issues: issues.slice(0, 10)
  };
})()
```

### 5.3 Check Continuity (Alignment Lines)

```javascript
(() => {
  const sections = document.querySelectorAll('section, main, article, [class*="container"], [class*="wrapper"], [class*="content"]');
  const viewport = { w: window.innerWidth, h: window.innerHeight };
  const allPositions = [];
  const alignmentLines = { left: {}, right: {}, centerX: {}, top: {} };

  const elements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, img, button, a, input, [class*="card"], [class*="Card"], ul, ol, table, form');
  const sampled = Array.from(elements).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && rect.top < viewport.h * 3;
  }).slice(0, 150);

  sampled.forEach(el => {
    const rect = el.getBoundingClientRect();
    const left = Math.round(rect.left);
    const right = Math.round(rect.right);
    const centerX = Math.round(rect.left + rect.width / 2);
    const top = Math.round(rect.top);

    allPositions.push({ tag: el.tagName.toLowerCase(), left, right, centerX, top });

    const snap = v => Math.round(v / 2) * 2;
    alignmentLines.left[snap(left)] = (alignmentLines.left[snap(left)] || 0) + 1;
    alignmentLines.right[snap(right)] = (alignmentLines.right[snap(right)] || 0) + 1;
    alignmentLines.centerX[snap(centerX)] = (alignmentLines.centerX[snap(centerX)] || 0) + 1;
    alignmentLines.top[snap(top)] = (alignmentLines.top[snap(top)] || 0) + 1;
  });

  const findDominantLines = (lineMap, minCount) => {
    return Object.entries(lineMap)
      .map(([pos, count]) => ({ position: parseInt(pos), count }))
      .filter(l => l.count >= minCount)
      .sort((a, b) => b.count - a.count);
  };

  const dominantLeft = findDominantLines(alignmentLines.left, 3);
  const dominantRight = findDominantLines(alignmentLines.right, 3);
  const dominantCenter = findDominantLines(alignmentLines.centerX, 3);

  const totalElements = sampled.length;
  const alignedToAnyLine = sampled.filter(el => {
    const rect = el.getBoundingClientRect();
    const left = Math.round(rect.left);
    const centerX = Math.round(rect.left + rect.width / 2);
    const snap = v => Math.round(v / 2) * 2;
    return dominantLeft.some(l => Math.abs(l.position - snap(left)) <= 2) ||
           dominantCenter.some(l => Math.abs(l.position - snap(centerX)) <= 2) ||
           dominantRight.some(l => Math.abs(l.position - snap(Math.round(rect.right))) <= 2);
  }).length;

  const alignmentScore = totalElements > 0 ? Math.round((alignedToAnyLine / totalElements) * 100) : 100;

  const issues = [];
  if (dominantLeft.length === 0 && dominantCenter.length === 0) {
    issues.push({
      type: 'no-alignment-lines',
      message: 'No dominant alignment lines detected. Elements appear randomly positioned.'
    });
  }
  if (alignmentScore < 50) {
    issues.push({
      type: 'weak-alignment',
      alignmentScore,
      message: `Only ${alignmentScore}% of elements align to dominant grid lines. Elements feel scattered.`
    });
  }

  return {
    totalElementsChecked: totalElements,
    alignedElements: alignedToAnyLine,
    alignmentScore,
    dominantAlignmentLines: {
      left: dominantLeft.slice(0, 5),
      right: dominantRight.slice(0, 5),
      center: dominantCenter.slice(0, 5)
    },
    gridColumnsDetected: dominantLeft.length,
    issues
  };
})()
```

### 5.4 Check Closure (Container Boundaries)

```javascript
(() => {
  const containers = document.querySelectorAll(
    '[class*="card"], [class*="Card"], [class*="panel"], [class*="Panel"], ' +
    '[class*="modal"], [class*="Modal"], [class*="dialog"], [class*="Dialog"], ' +
    '[class*="tile"], [class*="Tile"], [class*="box"], [class*="Box"], ' +
    '[class*="widget"], [class*="Widget"], article, aside, ' +
    '[class*="dropdown"], [class*="Dropdown"], [class*="popover"], [class*="Popover"], ' +
    '[class*="tooltip"], [class*="Tooltip"], section'
  );

  const results = [];
  const issues = [];
  let withClosure = 0;
  let withoutClosure = 0;

  const sampled = Array.from(containers).filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && rect.width < window.innerWidth * 0.95;
  }).slice(0, 80);

  sampled.forEach(el => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();

    const hasBorder = style.borderStyle !== 'none' && parseFloat(style.borderWidth) > 0;
    const hasBackground = style.backgroundColor !== 'rgba(0, 0, 0, 0)' && style.backgroundColor !== 'transparent';
    const hasShadow = style.boxShadow !== 'none' && style.boxShadow !== '';
    const hasOutline = style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0;
    const hasBorderRadius = parseFloat(style.borderRadius) > 0;
    const hasPadding = (parseFloat(style.paddingTop) || 0) >= 8 &&
                        (parseFloat(style.paddingLeft) || 0) >= 8;

    const closureCues = [];
    if (hasBorder) closureCues.push('border');
    if (hasBackground) closureCues.push('background');
    if (hasShadow) closureCues.push('shadow');
    if (hasBorderRadius) closureCues.push('border-radius');
    if (hasPadding) closureCues.push('padding');

    const hasClosure = closureCues.length >= 2;

    if (hasClosure) {
      withClosure++;
    } else {
      withoutClosure++;
    }

    const entry = {
      tag: el.tagName.toLowerCase(),
      classes: (el.className || '').toString().substring(0, 60),
      width: Math.round(rect.width),
      height: Math.round(rect.height),
      closureCues,
      hasClosure
    };

    results.push(entry);

    if (!hasClosure && el.children.length > 1) {
      issues.push({
        type: 'missing-closure',
        ...entry,
        message: `Container ${entry.tag}.${entry.classes.split(' ')[0]} has ${closureCues.length} closure cue(s) [${closureCues.join(', ') || 'none'}]. Needs >=2 cues (border, background, shadow, padding) for clear boundaries.`
      });
    }
  });

  const closureScore = sampled.length > 0
    ? Math.round((withClosure / sampled.length) * 100)
    : 100;

  return {
    containersAnalyzed: sampled.length,
    withClosure,
    withoutClosure,
    closureScore,
    details: results.slice(0, 15),
    issues: issues.slice(0, 10)
  };
})()
```

### 5.5 Check Figure-Ground Separation

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

  function getEffectiveBg(el) {
    let current = el;
    while (current && current !== document.documentElement) {
      const style = window.getComputedStyle(current);
      const bg = style.backgroundColor;
      if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
        return parseRGB(bg);
      }
      current = current.parentElement;
    }
    return { r: 255, g: 255, b: 255 };
  }

  const overlays = document.querySelectorAll(
    '[class*="modal"], [class*="Modal"], [class*="dialog"], [class*="Dialog"], ' +
    '[class*="dropdown"], [class*="Dropdown"], [class*="popover"], [class*="Popover"], ' +
    '[class*="overlay"], [class*="Overlay"], [class*="tooltip"], [class*="Tooltip"], ' +
    '[role="dialog"], [role="alertdialog"], [role="menu"], [role="listbox"]'
  );

  const mainContent = document.querySelector('main, [role="main"], [class*="content"], #content, #app, #root');
  const sidebar = document.querySelector('aside, [class*="sidebar"], [class*="Sidebar"], [role="complementary"]');
  const header = document.querySelector('header, [role="banner"]');
  const footer = document.querySelector('footer, [role="contentinfo"]');

  const layers = [];
  const issues = [];

  const pageBg = getEffectiveBg(document.body);
  const pageBgLum = luminance(pageBg.r, pageBg.g, pageBg.b);

  const regions = [
    { name: 'main-content', el: mainContent },
    { name: 'sidebar', el: sidebar },
    { name: 'header', el: header },
    { name: 'footer', el: footer }
  ];

  regions.forEach(({ name, el }) => {
    if (!el) return;
    const bg = getEffectiveBg(el);
    const bgLum = luminance(bg.r, bg.g, bg.b);
    const contrast = contrastRatio(pageBgLum, bgLum);
    const style = window.getComputedStyle(el);
    const zIndex = parseInt(style.zIndex) || 0;

    layers.push({
      region: name,
      backgroundColor: `rgb(${bg.r}, ${bg.g}, ${bg.b})`,
      contrastWithPageBg: contrast,
      zIndex,
      hasShadow: style.boxShadow !== 'none',
      hasBorder: style.borderStyle !== 'none' && parseFloat(style.borderWidth) > 0,
      separation: contrast > 1.1 || style.boxShadow !== 'none' || (style.borderStyle !== 'none' && parseFloat(style.borderWidth) > 0) ? 'clear' : 'weak'
    });
  });

  const overlayResults = [];
  overlays.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const style = window.getComputedStyle(el);
    const bg = getEffectiveBg(el);
    const bgLum = luminance(bg.r, bg.g, bg.b);
    const contrast = contrastRatio(pageBgLum, bgLum);
    const zIndex = parseInt(style.zIndex) || 0;

    overlayResults.push({
      tag: el.tagName.toLowerCase(),
      classes: (el.className || '').toString().substring(0, 50),
      zIndex,
      contrastWithPageBg: contrast,
      hasShadow: style.boxShadow !== 'none',
      elevation: zIndex > 10 ? 'high' : zIndex > 0 ? 'medium' : 'flat'
    });

    if (zIndex <= 0 && !style.boxShadow && contrast < 1.3) {
      issues.push({
        type: 'weak-figure-ground',
        element: el.tagName.toLowerCase(),
        message: `Overlay element lacks elevation (z-index: ${zIndex}, no shadow, contrast: ${contrast}). Should float above content with shadow or z-index.`
      });
    }
  });

  const weakRegions = layers.filter(l => l.separation === 'weak');
  if (weakRegions.length > 0) {
    weakRegions.forEach(r => {
      issues.push({
        type: 'weak-region-separation',
        region: r.region,
        contrast: r.contrastWithPageBg,
        message: `${r.region} has weak figure-ground separation (contrast: ${r.contrastWithPageBg}x, no shadow or border).`
      });
    });
  }

  return {
    pageBg: `rgb(${pageBg.r}, ${pageBg.g}, ${pageBg.b})`,
    regionLayers: layers,
    overlayElements: overlayResults,
    figureGroundScore: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 15),
    issues: issues.slice(0, 10)
  };
})()
```

### 5.6 Check Common Region Grouping

```javascript
(() => {
  const relatedGroups = [
    {
      name: 'formFieldGroups',
      parentSelector: 'form, [class*="form"], fieldset',
      childSelector: 'label, input, select, textarea, [class*="field"], [class*="Field"]'
    },
    {
      name: 'navigationGroups',
      parentSelector: 'nav, [role="navigation"]',
      childSelector: 'a, button'
    },
    {
      name: 'cardContentGroups',
      parentSelector: '[class*="card"], [class*="Card"]',
      childSelector: 'h2, h3, h4, p, img, a, button, span'
    },
    {
      name: 'actionGroups',
      parentSelector: '[class*="actions"], [class*="toolbar"], [class*="button-group"], [role="toolbar"]',
      childSelector: 'button, a'
    },
    {
      name: 'listGroups',
      parentSelector: 'ul, ol, [class*="list"], [class*="List"]',
      childSelector: 'li, [class*="item"], [class*="Item"]'
    }
  ];

  const results = [];
  const issues = [];

  relatedGroups.forEach(({ name, parentSelector, childSelector }) => {
    const parents = document.querySelectorAll(parentSelector);
    parents.forEach(parent => {
      const children = parent.querySelectorAll(childSelector);
      if (children.length < 2) return;

      const parentStyle = window.getComputedStyle(parent);
      const parentRect = parent.getBoundingClientRect();
      if (parentRect.width === 0 || parentRect.height === 0) return;

      const hasBackground = parentStyle.backgroundColor !== 'rgba(0, 0, 0, 0)' &&
                            parentStyle.backgroundColor !== 'transparent';
      const hasBorder = parentStyle.borderStyle !== 'none' && parseFloat(parentStyle.borderWidth) > 0;
      const hasShadow = parentStyle.boxShadow !== 'none' && parentStyle.boxShadow !== '';
      const hasPadding = (parseFloat(parentStyle.paddingTop) || 0) >= 8;
      const hasBorderRadius = parseFloat(parentStyle.borderRadius) > 0;

      const regionCues = [];
      if (hasBackground) regionCues.push('background');
      if (hasBorder) regionCues.push('border');
      if (hasShadow) regionCues.push('shadow');
      if (hasPadding) regionCues.push('padding');
      if (hasBorderRadius) regionCues.push('border-radius');

      const hasCommonRegion = regionCues.length >= 1;

      const entry = {
        group: name,
        tag: parent.tagName.toLowerCase(),
        classes: (parent.className || '').toString().substring(0, 50),
        childCount: children.length,
        regionCues,
        hasCommonRegion
      };

      results.push(entry);

      if (!hasCommonRegion) {
        issues.push({
          type: 'missing-common-region',
          ...entry,
          message: `${name}: ${entry.tag}.${entry.classes.split(' ')[0]} groups ${children.length} related items but has no visual container (no background, border, shadow, or padding).`
        });
      }
    });
  });

  const withRegion = results.filter(r => r.hasCommonRegion).length;
  const withoutRegion = results.filter(r => !r.hasCommonRegion).length;
  const commonRegionScore = results.length > 0
    ? Math.round((withRegion / results.length) * 100)
    : 100;

  return {
    groupsAnalyzed: results.length,
    withCommonRegion: withRegion,
    withoutCommonRegion: withoutRegion,
    commonRegionScore,
    details: results.slice(0, 15),
    issues: issues.slice(0, 10)
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Proximity Communicates Relationships**: Does proximity accurately communicate relationships? Are related items (form label + input, card title + description, nav items) clearly closer to each other than to unrelated elements? Or are there cases where unrelated items feel grouped by proximity?

2. **Similarity Signals Same-Type Elements**: Do similar elements look similar? Can you identify element types (buttons, cards, nav links, form fields) by visual appearance alone without reading labels? Or do same-type elements vary in size, color, padding, or shape?

3. **Alignment Creates Continuity**: Are there clear alignment lines creating visual continuity across the page? Do headings, text blocks, images, and cards align to a visible grid? Or do elements feel randomly placed with no alignment structure?

4. **Closure Defines Boundaries**: Do containers and cards provide clear figure-ground separation? Can you immediately identify discrete UI components (cards, panels, dialogs, form groups) as bounded units? Or do some containers blend into the background?

5. **Groupings Feel Correct**: Are there any groupings that feel wrong — items that look related but are not, or related items that look separate? Does the visual grouping match the logical/semantic grouping of content?

6. **Cognitive Load Reduction**: Does the overall layout leverage Gestalt principles to reduce cognitive load? Can you understand the page structure at a glance, or do you need to study it carefully to understand which elements belong together?

7. **Common Region Clarity**: Are there areas where adding a subtle background color, border, or padding would dramatically improve grouping clarity? Are there groups of related items that currently float without any visual container?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | All 6 Gestalt principles clearly applied. Groups are instantly legible. Proximity ratio >=2x between groups vs within groups. Same-type elements have >=90% style consistency. Clear alignment grid with >=70% of elements aligned. All containers have >=2 closure cues. Strong figure-ground separation. All related items share common region. |
| 4 | 5 of 6 principles applied well. Minor grouping ambiguity in 1-2 areas. Proximity ratio >=1.5x. Same-type consistency >=80%. Most elements aligned. Most containers have closure. Minor figure-ground issues. |
| 3 | 3-4 principles present but inconsistent. Some groups clear, others ambiguous. Proximity ratio mixed. Similarity breaks in 2+ element types. Alignment visible but not rigorous. Some containers lack closure. |
| 2 | Weak grouping throughout. Proximity does not match relationships — related items are far apart or unrelated items are close. Same-type elements vary significantly. No clear alignment grid. Containers blend into background. |
| 1 | No intentional grouping. Elements appear randomly placed. No proximity structure, no similarity, no alignment, no closure. Page requires effort to understand what belongs together. |

## Common Fixes

### Fix: Improve proximity between related items
```css
/* Reduce gap between label and input (proximity) */
.form-group label {
  margin-bottom: 0.25rem; /* 4px — tight coupling */
}

/* Increase gap between form groups (inter-group spacing) */
.form-group + .form-group {
  margin-top: 1.5rem; /* 24px — clear separation */
}
```

**Tailwind equivalent:**
```html
<label class="mb-1">
<div class="space-y-6"> <!-- 24px between form groups -->
```

### Fix: Enforce similarity across same-type elements
```css
/* All buttons should use the same base styles */
.btn {
  font-size: 0.875rem;
  font-weight: 600;
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  line-height: 1.25rem;
}

/* All cards should share internal padding and radius */
.card {
  padding: 1.5rem;
  border-radius: 0.5rem;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
}
```

**Tailwind equivalent:**
```html
<button class="text-sm font-semibold py-2 px-4 rounded-md">
<div class="p-6 rounded-lg border border-gray-200 bg-white">
```

### Fix: Add alignment grid
```css
/* Establish consistent content alignment */
.container {
  max-width: 80rem;
  margin: 0 auto;
  padding: 0 1.5rem;
}

/* Use CSS Grid for consistent column alignment */
.content-grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: 1.5rem;
}
```

### Fix: Add closure cues to containers
```css
/* Add clear boundaries to cards and panels */
.card {
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 0.5rem;
  padding: 1.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

/* Add subtle background for grouped regions */
.field-group {
  background-color: var(--color-surface-subtle);
  padding: 1rem 1.25rem;
  border-radius: 0.375rem;
}
```

**Tailwind equivalent:**
```html
<div class="bg-white border border-gray-200 rounded-lg p-6 shadow-sm">
<fieldset class="bg-gray-50 p-4 rounded-md">
```

### Fix: Improve figure-ground for overlays
```css
/* Modals and dropdowns need elevation */
.modal {
  z-index: 50;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
  background: var(--color-surface);
  border-radius: 0.75rem;
}

.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 40;
}

.dropdown-menu {
  z-index: 30;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.12);
  border: 1px solid var(--color-border);
}
```

**Tailwind equivalent:**
```html
<div class="z-50 shadow-2xl bg-white rounded-xl"> <!-- modal -->
<div class="fixed inset-0 bg-black/50 z-40">     <!-- backdrop -->
<div class="z-30 shadow-xl border border-gray-200"> <!-- dropdown -->
```

### Fix: Add common region to related items
```css
/* Wrap related form fields in a visual group */
fieldset {
  border: 1px solid var(--color-border-subtle);
  border-radius: 0.5rem;
  padding: 1.25rem;
  background: var(--color-surface-subtle);
}

fieldset legend {
  font-weight: 600;
  font-size: 0.875rem;
  padding: 0 0.5rem;
  color: var(--color-text-secondary);
}
```

**Tailwind equivalent:**
```html
<fieldset class="border border-gray-200 rounded-lg p-5 bg-gray-50/50">
  <legend class="font-semibold text-sm px-2 text-gray-600">
```
