# Pass 10: Grid & Layout System

Evaluates whether the page uses a consistent, systematic approach to layout — grid definitions, container widths, breakpoint behavior, gap consistency, and responsive patterns. A healthy layout system eliminates magic numbers, prevents overflow bugs, and ensures the UI adapts gracefully across viewports.

---

## Tier 0: Code Analysis

Perform these checks using Read, Grep, and Glob only (no browser required).

### 0-1. CSS Grid template definitions

```
pattern: grid-template-(columns|rows)\s*:
glob: "*.{css,scss,less,tsx,jsx,vue,svelte}"
```

Also check for Tailwind grid utilities:

```
pattern: grid-cols-\d+|grid-rows-\d+
glob: "*.{tsx,jsx,vue,svelte,html}"
```

### 0-2. Breakpoint definitions

Search for media query breakpoints:

```
pattern: @media\s*\(\s*(min|max)-width\s*:\s*\d+
glob: "*.{css,scss,less}"
```

Check Tailwind screens config:

```
pattern: screens\s*:\s*\{
glob: "tailwind.config.{js,ts,mjs,cjs}"
```

Check for container queries:

```
pattern: @container|container-type\s*:
glob: "*.{css,scss,less}"
```

### 0-3. Container max-width values

```
pattern: max-width\s*:\s*\d+
glob: "*.{css,scss,less,tsx,jsx,vue,svelte}"
```

Also check for Tailwind container config and `container` class usage.

### 0-4. Grid vs Flexbox usage patterns

Count occurrences of each:

```
pattern: display\s*:\s*grid|grid-template
glob: "*.{css,scss,less}"
```

```
pattern: display\s*:\s*flex|flex-direction|flex-wrap
glob: "*.{css,scss,less}"
```

For Tailwind projects:

```
pattern: \bflex\b|\bflex-col\b|\bflex-row\b|\bflex-wrap\b
glob: "*.{tsx,jsx,vue,svelte,html}"
```

```
pattern: \bgrid\b|\bgrid-cols-
glob: "*.{tsx,jsx,vue,svelte,html}"
```

### 0-5. Layout magic numbers

Search for hardcoded pixel widths that are not standard breakpoints or common sizes:

```
pattern: width\s*:\s*\d{3,}px|min-width\s*:\s*\d{3,}px|max-width\s*:\s*\d{3,}px
glob: "*.{css,scss,less,tsx,jsx,vue,svelte}"
```

Exclude values that match standard breakpoints (320, 375, 640, 768, 1024, 1280, 1440, 1536, 1920). Remaining matches are magic numbers.

### 0-6. Responsive pattern detection

Check for responsive Tailwind prefixes:

```
pattern: (sm|md|lg|xl|2xl):
glob: "*.{tsx,jsx,vue,svelte,html}"
```

Or media query patterns in CSS:

```
pattern: @media\s*\(
glob: "*.{css,scss,less}"
```

Count responsive declarations per file. Files with layout responsibilities but zero responsive patterns are red flags.

### 0-7. Gap/spacing in layout contexts

```
pattern: gap\s*:\s*|row-gap\s*:\s*|column-gap\s*:\s*
glob: "*.{css,scss,less}"
```

```
pattern: gap-\d+|gap-x-\d+|gap-y-\d+|space-x-\d+|space-y-\d+
glob: "*.{tsx,jsx,vue,svelte,html}"
```

Compare gap values across layout files — are they consistent or arbitrary?

---

## Tier 1: Automated Browser Checks

### Script 1 — measureGridAlignment

```javascript
(() => {
  const results = {
    viewportWidth: window.innerWidth,
    viewportHeight: window.innerHeight,
    totalGridContainers: 0,
    totalFlexContainers: 0,
    columnAlignmentScore: 0,
    gridDetails: [],
    alignmentSamples: []
  };

  const COLUMN_COUNT = 12;
  const TOLERANCE = 4;
  const colWidth = window.innerWidth / COLUMN_COUNT;
  const columnEdges = [];
  for (let i = 0; i <= COLUMN_COUNT; i++) {
    columnEdges.push(Math.round(i * colWidth));
  }

  const snapsToGrid = (x) => {
    return columnEdges.some(edge => Math.abs(x - edge) <= TOLERANCE);
  };

  const allEls = document.querySelectorAll('body *');
  let alignedCount = 0;
  let totalChecked = 0;

  allEls.forEach(el => {
    const computed = getComputedStyle(el);
    const display = computed.display;

    if (display === 'grid' || display === 'inline-grid') {
      results.totalGridContainers++;
      if (results.gridDetails.length < 15) {
        const tag = el.tagName.toLowerCase();
        const id = el.id ? `#${el.id}` : '';
        const cls = el.className && typeof el.className === 'string'
          ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
          : '';
        results.gridDetails.push({
          selector: `${tag}${id}${cls}`,
          columns: computed.gridTemplateColumns,
          rows: computed.gridTemplateRows,
          gap: computed.gap,
          childCount: el.children.length
        });
      }
    }

    if (display === 'flex' || display === 'inline-flex') {
      results.totalFlexContainers++;
    }
  });

  const contentEls = document.querySelectorAll(
    'body > *, body > * > *, main *, [role="main"] *, .container *, .wrapper *'
  );

  const seen = new Set();
  contentEls.forEach(el => {
    if (seen.has(el)) return;
    seen.add(el);
    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    if (rect.width >= window.innerWidth * 0.95) return;
    if (rect.width < 50) return;

    totalChecked++;
    const leftSnaps = snapsToGrid(rect.left);
    const rightSnaps = snapsToGrid(rect.right);

    if (leftSnaps || rightSnaps) {
      alignedCount++;
    }

    if (results.alignmentSamples.length < 20) {
      const tag = el.tagName.toLowerCase();
      const cls = el.className && typeof el.className === 'string'
        ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 2).join('.')}`
        : '';
      results.alignmentSamples.push({
        selector: `${tag}${cls}`,
        left: Math.round(rect.left),
        right: Math.round(rect.right),
        width: Math.round(rect.width),
        leftAligned: leftSnaps,
        rightAligned: rightSnaps
      });
    }
  });

  results.columnAlignmentScore = totalChecked > 0
    ? Math.round((alignedCount / totalChecked) * 100)
    : 0;

  return results;
})();
```

### Script 2 — checkContainerConsistency

```javascript
(() => {
  const results = {
    totalContainers: 0,
    uniqueMaxWidths: [],
    uniquePaddings: [],
    containerDetails: [],
    isConsistent: false,
    recommendations: []
  };

  const containerSelectors = [
    '.container', '.wrapper', '.content', '.page',
    '[class*="container"]', '[class*="wrapper"]', '[class*="content-wrapper"]',
    '[class*="max-w-"]', '[class*="mx-auto"]',
    'main', '[role="main"]'
  ];

  const containerEls = new Set();
  containerSelectors.forEach(sel => {
    try {
      document.querySelectorAll(sel).forEach(el => containerEls.add(el));
    } catch (e) {}
  });

  const allEls = document.querySelectorAll('body *');
  allEls.forEach(el => {
    const computed = getComputedStyle(el);
    const maxW = computed.maxWidth;
    const marginL = computed.marginLeft;
    const marginR = computed.marginRight;
    if (maxW !== 'none' && marginL === marginR && marginL !== '0px' &&
        el.children.length >= 2) {
      containerEls.add(el);
    }
  });

  results.totalContainers = containerEls.size;

  const maxWidthMap = new Map();
  const paddingMap = new Map();

  containerEls.forEach(el => {
    const computed = getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    const maxW = computed.maxWidth;
    const pLeft = computed.paddingLeft;
    const pRight = computed.paddingRight;

    maxWidthMap.set(maxW, (maxWidthMap.get(maxW) || 0) + 1);

    const paddingKey = `${pLeft}|${pRight}`;
    paddingMap.set(paddingKey, (paddingMap.get(paddingKey) || 0) + 1);

    if (results.containerDetails.length < 20) {
      const tag = el.tagName.toLowerCase();
      const id = el.id ? `#${el.id}` : '';
      const cls = el.className && typeof el.className === 'string'
        ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
        : '';
      results.containerDetails.push({
        selector: `${tag}${id}${cls}`,
        maxWidth: maxW,
        width: `${Math.round(rect.width)}px`,
        paddingLeft: pLeft,
        paddingRight: pRight,
        childCount: el.children.length
      });
    }
  });

  results.uniqueMaxWidths = [...maxWidthMap.entries()]
    .map(([val, count]) => ({ value: val, count }))
    .sort((a, b) => b.count - a.count);

  results.uniquePaddings = [...paddingMap.entries()]
    .map(([val, count]) => ({ value: val, count }))
    .sort((a, b) => b.count - a.count);

  const uniqueNonNone = results.uniqueMaxWidths.filter(w => w.value !== 'none');
  results.isConsistent = uniqueNonNone.length <= 2;

  if (uniqueNonNone.length > 2) {
    results.recommendations.push(
      `${uniqueNonNone.length} different max-width values found across containers — standardize to 1-2 values`
    );
  }

  const uniquePads = results.uniquePaddings.filter(p => p.value !== '0px|0px');
  if (uniquePads.length > 3) {
    results.recommendations.push(
      `${uniquePads.length} different padding patterns on containers — use consistent container padding`
    );
  }

  if (results.totalContainers === 0) {
    results.recommendations.push(
      'No container/wrapper elements detected — content may extend to viewport edges without consistent margins'
    );
  }

  return results;
})();
```

### Script 3 — checkBreakpointBehavior

```javascript
(() => {
  const results = {
    viewportWidth: window.innerWidth,
    viewportHeight: window.innerHeight,
    isMobile: window.innerWidth < 768,
    hasHorizontalScroll: false,
    overflowingElements: [],
    edgeTouchingElements: [],
    unstackedColumns: [],
    recommendations: []
  };

  results.hasHorizontalScroll = document.documentElement.scrollWidth > window.innerWidth;

  const allEls = document.querySelectorAll('body *');

  allEls.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;

    const tag = el.tagName.toLowerCase();
    if (['script', 'style', 'noscript', 'br', 'hr'].includes(tag)) return;

    const selectorFor = () => {
      const id = el.id ? `#${el.id}` : '';
      const cls = el.className && typeof el.className === 'string'
        ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 2).join('.')}`
        : '';
      return `${tag}${id}${cls}`;
    };

    if (rect.right > window.innerWidth + 2 && results.overflowingElements.length < 15) {
      results.overflowingElements.push({
        selector: selectorFor(),
        right: Math.round(rect.right),
        width: Math.round(rect.width),
        overflowBy: Math.round(rect.right - window.innerWidth)
      });
    }

    if (rect.left < 1 && rect.right > window.innerWidth - 1 &&
        rect.width >= window.innerWidth - 2) {
      const computed = getComputedStyle(el);
      const pLeft = parseFloat(computed.paddingLeft);
      const pRight = parseFloat(computed.paddingRight);
      if (pLeft < 8 && pRight < 8 && el.textContent && el.textContent.trim().length > 20) {
        if (results.edgeTouchingElements.length < 10) {
          results.edgeTouchingElements.push({
            selector: selectorFor(),
            paddingLeft: computed.paddingLeft,
            paddingRight: computed.paddingRight,
            textPreview: el.textContent.trim().slice(0, 50)
          });
        }
      }
    }

    if (results.isMobile) {
      const computed = getComputedStyle(el);
      const display = computed.display;
      if ((display === 'flex' || display === 'grid') &&
          el.children.length >= 2) {
        const children = [...el.children];
        const childRects = children
          .map(c => c.getBoundingClientRect())
          .filter(r => r.width > 0 && r.height > 0);

        if (childRects.length >= 2) {
          const allSameRow = childRects.every(r =>
            Math.abs(r.top - childRects[0].top) < 10
          );

          if (allSameRow) {
            const totalChildWidth = childRects.reduce((s, r) => s + r.width, 0);
            if (totalChildWidth > window.innerWidth * 0.9) {
              if (results.unstackedColumns.length < 10) {
                results.unstackedColumns.push({
                  selector: selectorFor(),
                  display,
                  childCount: childRects.length,
                  totalChildWidth: Math.round(totalChildWidth),
                  viewportWidth: window.innerWidth
                });
              }
            }
          }
        }
      }
    }
  });

  if (results.hasHorizontalScroll) {
    results.recommendations.push(
      `Page has horizontal scroll (document width: ${document.documentElement.scrollWidth}px, viewport: ${window.innerWidth}px) — find and fix overflowing elements`
    );
  }

  if (results.overflowingElements.length > 0) {
    results.recommendations.push(
      `${results.overflowingElements.length} elements extend beyond the viewport — add overflow-x: hidden or fix widths`
    );
  }

  if (results.edgeTouchingElements.length > 0) {
    results.recommendations.push(
      `${results.edgeTouchingElements.length} text elements touch viewport edges with no padding — add container padding`
    );
  }

  if (results.unstackedColumns.length > 0) {
    results.recommendations.push(
      `${results.unstackedColumns.length} multi-column layouts haven't stacked on mobile (${window.innerWidth}px viewport) — add responsive breakpoints`
    );
  }

  return results;
})();
```

### Script 4 — measureGapConsistency

```javascript
(() => {
  const results = {
    totalLayoutContainers: 0,
    gapValues: {},
    uniqueGapCount: 0,
    dominantGap: null,
    isConsistent: false,
    details: [],
    recommendations: []
  };

  const allEls = document.querySelectorAll('body *');
  const gapMap = new Map();

  allEls.forEach(el => {
    const computed = getComputedStyle(el);
    const display = computed.display;

    if (!['flex', 'inline-flex', 'grid', 'inline-grid'].includes(display)) return;
    if (el.children.length < 2) return;

    results.totalLayoutContainers++;

    const gap = computed.gap;
    const rowGap = computed.rowGap;
    const colGap = computed.columnGap;

    const gapKey = gap !== 'normal' ? gap : `${rowGap}|${colGap}`;
    gapMap.set(gapKey, (gapMap.get(gapKey) || 0) + 1);

    if (results.details.length < 25) {
      const tag = el.tagName.toLowerCase();
      const id = el.id ? `#${el.id}` : '';
      const cls = el.className && typeof el.className === 'string'
        ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
        : '';
      results.details.push({
        selector: `${tag}${id}${cls}`,
        display,
        gap: gap !== 'normal' ? gap : null,
        rowGap: rowGap !== 'normal' ? rowGap : null,
        columnGap: colGap !== 'normal' ? colGap : null,
        childCount: el.children.length
      });
    }
  });

  const sorted = [...gapMap.entries()]
    .map(([val, count]) => ({ value: val, count }))
    .sort((a, b) => b.count - a.count);

  sorted.forEach(entry => {
    results.gapValues[entry.value] = entry.count;
  });

  results.uniqueGapCount = sorted.length;
  results.dominantGap = sorted.length > 0 ? sorted[0].value : null;

  const nonZeroGaps = sorted.filter(g =>
    g.value !== 'normal|normal' && g.value !== '0px' && g.value !== '0px|0px'
  );
  results.isConsistent = nonZeroGaps.length <= 4;

  if (nonZeroGaps.length > 6) {
    results.recommendations.push(
      `${nonZeroGaps.length} different gap values used across layout containers — standardize to a spacing scale (e.g., 4px, 8px, 16px, 24px, 32px)`
    );
  }

  const noGapContainers = results.details.filter(d =>
    !d.gap && !d.rowGap && !d.columnGap
  );
  if (noGapContainers.length > 3) {
    results.recommendations.push(
      `${noGapContainers.length} flex/grid containers have no gap defined — children may rely on margin for spacing (less maintainable)`
    );
  }

  return results;
})();
```

### Script 5 — detectLayoutAntipatterns

```javascript
(() => {
  const results = {
    totalIssues: 0,
    deepNesting: [],
    positionConflicts: [],
    hardcodedInFlex: [],
    unnecessaryMarginAuto: [],
    recommendations: []
  };

  const selectorFor = (el) => {
    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 2).join('.')}`
      : '';
    return `${tag}${id}${cls}`;
  };

  const allEls = document.querySelectorAll('body *');

  allEls.forEach(el => {
    const computed = getComputedStyle(el);
    const display = computed.display;
    const position = computed.position;

    if (['flex', 'inline-flex', 'grid', 'inline-grid'].includes(display)) {
      let depth = 0;
      let parent = el.parentElement;
      while (parent && parent !== document.body) {
        const parentDisplay = getComputedStyle(parent).display;
        if (['flex', 'inline-flex', 'grid', 'inline-grid'].includes(parentDisplay)) {
          depth++;
        }
        parent = parent.parentElement;
      }

      if (depth >= 3 && results.deepNesting.length < 10) {
        results.deepNesting.push({
          selector: selectorFor(el),
          layoutDepth: depth,
          display
        });
        results.totalIssues++;
      }
    }

    if (position === 'absolute' || position === 'fixed') {
      const parent = el.parentElement;
      if (parent) {
        const parentDisplay = getComputedStyle(parent).display;
        if (['flex', 'inline-flex', 'grid', 'inline-grid'].includes(parentDisplay)) {
          if (results.positionConflicts.length < 10) {
            results.positionConflicts.push({
              selector: selectorFor(el),
              position,
              parentDisplay,
              parentSelector: selectorFor(parent)
            });
            results.totalIssues++;
          }
        }
      }
    }

    const parent = el.parentElement;
    if (parent) {
      const parentDisplay = getComputedStyle(parent).display;
      if (['flex', 'inline-flex'].includes(parentDisplay)) {
        const width = computed.width;
        const minWidth = computed.minWidth;
        if (width !== 'auto' && !width.includes('%') && !width.includes('calc') &&
            width !== '0px' && parseInt(width) > 100) {
          if (results.hardcodedInFlex.length < 10) {
            results.hardcodedInFlex.push({
              selector: selectorFor(el),
              width,
              minWidth,
              parentSelector: selectorFor(parent)
            });
            results.totalIssues++;
          }
        }

        const marginLeft = computed.marginLeft;
        const marginRight = computed.marginRight;
        if (marginLeft === marginRight && marginLeft !== '0px') {
          const parentJustify = getComputedStyle(parent).justifyContent;
          if (parentJustify === 'center' || parentJustify === 'space-between' ||
              parentJustify === 'space-around') {
            if (results.unnecessaryMarginAuto.length < 10) {
              results.unnecessaryMarginAuto.push({
                selector: selectorFor(el),
                margin: `0 ${marginLeft}`,
                parentJustify,
                parentSelector: selectorFor(parent)
              });
              results.totalIssues++;
            }
          }
        }
      }
    }
  });

  if (results.deepNesting.length > 0) {
    results.recommendations.push(
      `${results.deepNesting.length} elements have 3+ levels of nested flex/grid — simplify layout hierarchy`
    );
  }
  if (results.positionConflicts.length > 0) {
    results.recommendations.push(
      `${results.positionConflicts.length} absolutely-positioned elements inside flex/grid containers — this removes them from layout flow and may cause overlap`
    );
  }
  if (results.hardcodedInFlex.length > 0) {
    results.recommendations.push(
      `${results.hardcodedInFlex.length} flex children have hardcoded pixel widths — use flex-basis, flex-grow, or percentage widths instead`
    );
  }

  return results;
})();
```

### Script 6 — checkResponsiveGrid

```javascript
(() => {
  const results = {
    viewportWidth: window.innerWidth,
    isMobileViewport: window.innerWidth <= 768,
    isTabletViewport: window.innerWidth > 768 && window.innerWidth <= 1024,
    horizontalScroll: document.documentElement.scrollWidth > window.innerWidth,
    scrollOverflow: document.documentElement.scrollWidth - window.innerWidth,
    multiColumnLayouts: [],
    properlyStacked: 0,
    notStacked: 0,
    gridColumnsReduced: [],
    recommendations: []
  };

  const layoutContainers = document.querySelectorAll('body *');

  layoutContainers.forEach(el => {
    const computed = getComputedStyle(el);
    const display = computed.display;
    if (!['flex', 'inline-flex', 'grid', 'inline-grid'].includes(display)) return;
    if (el.children.length < 2) return;

    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;

    const children = [...el.children].filter(c => {
      const r = c.getBoundingClientRect();
      return r.width > 0 && r.height > 0;
    });

    if (children.length < 2) return;

    const childRects = children.map(c => c.getBoundingClientRect());
    const firstTop = childRects[0].top;
    const allSameRow = childRects.every(r => Math.abs(r.top - firstTop) < 5);
    const isStacked = childRects.every((r, i) => {
      if (i === 0) return true;
      return r.top >= childRects[i - 1].bottom - 5;
    });

    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
      : '';
    const selector = `${tag}${id}${cls}`;

    if (display.includes('grid')) {
      const cols = computed.gridTemplateColumns;
      const colCount = cols ? cols.split(/\s+/).filter(v => v !== '').length : 0;
      if (results.gridColumnsReduced.length < 15) {
        results.gridColumnsReduced.push({
          selector,
          columns: cols,
          columnCount: colCount,
          viewport: window.innerWidth
        });
      }
    }

    if (results.isMobileViewport && children.length >= 2) {
      const totalChildWidth = childRects.reduce((s, r) => s + r.width, 0);

      if (allSameRow && totalChildWidth > window.innerWidth * 0.85) {
        results.notStacked++;
        if (results.multiColumnLayouts.length < 10) {
          results.multiColumnLayouts.push({
            selector,
            display,
            childCount: children.length,
            behavior: 'not-stacked',
            totalChildWidth: Math.round(totalChildWidth),
            containerWidth: Math.round(rect.width)
          });
        }
      } else if (isStacked) {
        results.properlyStacked++;
      }
    }
  });

  if (results.isMobileViewport) {
    if (results.notStacked > 0) {
      results.recommendations.push(
        `${results.notStacked} multi-column layouts are not stacking on mobile (${window.innerWidth}px) — add flex-wrap or responsive grid columns`
      );
    }
    if (results.horizontalScroll) {
      results.recommendations.push(
        `Horizontal scroll detected on mobile: ${results.scrollOverflow}px overflow — check for fixed-width elements`
      );
    }
  }

  if (results.gridColumnsReduced.length > 0) {
    const manyColumns = results.gridColumnsReduced.filter(g =>
      g.columnCount >= 3 && results.isMobileViewport
    );
    if (manyColumns.length > 0) {
      results.recommendations.push(
        `${manyColumns.length} grid containers still have 3+ columns on mobile — reduce columns at small breakpoints`
      );
    }
  }

  return results;
})();
```

---

## Tier 2: AI Evaluation

Examine the screenshots, DOM snapshots, and Tier 0/1 results, then answer each question with a rating (good / acceptable / needs-work) and brief justification.

1. **Grid system feel** — Does the layout feel like it is built on a grid system, or are elements placed arbitrarily with inconsistent spacing?
2. **Container consistency** — Are containers consistently sized and padded across all sections of the page?
3. **Breakpoint transitions** — Do breakpoint transitions feel smooth and designed, or abrupt and broken?
4. **Grid appropriateness** — Is the grid system appropriate for the content type (12-column for complex dashboards, simpler for content-heavy pages)?
5. **Mobile breakdowns** — Are there layout patterns that work on desktop but clearly break on mobile (overlapping elements, tiny text, unreachable buttons)?
6. **Grid vs Flexbox choices** — Does the use of CSS Grid vs Flexbox feel intentional and appropriate for each context (Grid for 2D layouts, Flexbox for 1D)?
7. **Container queries opportunity** — Are there self-contained components that would benefit from container queries instead of media queries for responsive behavior?

---

## Scoring Criteria

| Score | Criteria |
|-------|----------|
| **5** | Consistent grid system with defined columns. Clean breakpoint transitions at all viewports. No horizontal scroll issues. Containers uniformly sized and padded. Gap values follow a spacing scale. No layout magic numbers. |
| **4** | Good grid system with minor alignment issues. Breakpoints mostly smooth. One or two containers with inconsistent max-width. Gap values mostly consistent. |
| **3** | Partial grid system — some areas use grid/flex properly but others have hardcoded layouts. Some breakpoint issues. Mixed gap values. A few magic numbers. |
| **2** | Inconsistent layouts with frequent hardcoded widths. Breakpoints missing or broken at common viewports. Containers have varying max-widths. Many layout antipatterns. |
| **1** | No grid system. Elements positioned with absolute coordinates or arbitrary widths. No responsive breakpoints. Horizontal scroll on mobile. No consistent container pattern. |

---

## Common Fixes

### Add consistent container max-width

```css
/* Before — inconsistent containers */
.hero { max-width: 1200px; margin: 0 auto; }
.content { max-width: 1100px; margin: 0 auto; }
.footer { max-width: 1280px; margin: 0 auto; }

/* After — single container token */
:root { --container-max: 1280px; --container-padding: 1.5rem; }
.container {
  max-width: var(--container-max);
  margin: 0 auto;
  padding-inline: var(--container-padding);
}
```

### Replace hardcoded widths with grid columns

```css
/* Before */
.sidebar { width: 347px; }
.main { width: calc(100% - 347px); }

/* After */
.layout {
  display: grid;
  grid-template-columns: 280px 1fr;
  gap: var(--spacing-lg);
}
@media (max-width: 768px) {
  .layout { grid-template-columns: 1fr; }
}
```

### Add responsive breakpoints for stacking

```css
/* Before — flex row at all sizes */
.features { display: flex; gap: 24px; }

/* After — stacks on mobile */
.features {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-md);
}
.features > * {
  flex: 1 1 300px;
}
```

### Standardize gap values to a spacing scale

```css
/* Before — arbitrary gaps */
.grid-a { gap: 12px; }
.grid-b { gap: 18px; }
.grid-c { gap: 22px; }
.grid-d { gap: 15px; }

/* After — token-based gaps */
.grid-a { gap: var(--spacing-sm); }   /* 8px */
.grid-b { gap: var(--spacing-md); }   /* 16px */
.grid-c { gap: var(--spacing-lg); }   /* 24px */
.grid-d { gap: var(--spacing-md); }   /* 16px */
```

### Fix horizontal overflow on mobile

```css
/* Add to global styles */
html { overflow-x: hidden; }
img, video, iframe { max-width: 100%; height: auto; }
table { display: block; overflow-x: auto; }
pre { overflow-x: auto; white-space: pre-wrap; word-wrap: break-word; }
```

### Replace deeply nested flex/grid with simpler structure

```html
<!-- Before — 4 levels of flex nesting -->
<div class="flex">
  <div class="flex">
    <div class="flex">
      <div class="flex">content</div>
    </div>
  </div>
</div>

<!-- After — flat grid -->
<div class="grid grid-cols-3 gap-4">
  <div>content</div>
  <div>content</div>
  <div>content</div>
</div>
```
