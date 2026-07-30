# Pass 11: Mobile & Responsive Design

## Tier 1: Automated Checks

### Horizontal Overflow Detection

```javascript
(() => {
  const results = { check: "horizontal-overflow", issues: [], stats: {} };

  const viewportWidth = window.innerWidth;
  const docWidth = document.documentElement.scrollWidth;
  const bodyWidth = document.body.scrollWidth;
  const hasHorizontalScroll = Math.max(docWidth, bodyWidth) > viewportWidth + 1;

  // Find elements causing overflow
  const overflowingElements = [];
  if (hasHorizontalScroll) {
    const allElements = document.querySelectorAll('*');
    for (let i = 0; i < allElements.length; i++) {
      const el = allElements[i];
      const rect = el.getBoundingClientRect();
      if (rect.right > viewportWidth + 1 && rect.width > 0 && rect.height > 0) {
        const style = getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden') continue;
        overflowingElements.push({
          element: el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (el.className ? '.' + String(el.className).split(' ')[0] : ''),
          rightEdge: Math.round(rect.right),
          width: Math.round(rect.width),
          overflowBy: Math.round(rect.right - viewportWidth)
        });
        if (overflowingElements.length >= 10) break;
      }
    }
  }

  // Check for elements with fixed widths that could cause overflow at smaller viewports
  const fixedWidthElements = [];
  const els = document.querySelectorAll('*');
  for (let i = 0; i < Math.min(els.length, 500); i++) {
    const style = getComputedStyle(els[i]);
    const rect = els[i].getBoundingClientRect();
    if (rect.width === 0) continue;
    const inlineWidth = els[i].style.width;
    if (inlineWidth && inlineWidth.includes('px')) {
      const px = parseInt(inlineWidth);
      if (px > 350) {
        fixedWidthElements.push({
          element: els[i].tagName.toLowerCase() + (els[i].className ? '.' + String(els[i].className).split(' ')[0] : ''),
          fixedWidth: inlineWidth,
          actualWidth: Math.round(rect.width)
        });
      }
    }
    if (fixedWidthElements.length >= 5) break;
  }

  // Check tables for responsiveness
  const tables = Array.from(document.querySelectorAll('table'));
  const unresponsiveTables = tables.filter(t => {
    const rect = t.getBoundingClientRect();
    const parent = t.parentElement;
    const parentStyle = parent ? getComputedStyle(parent) : null;
    const hasOverflowScroll = parentStyle && (parentStyle.overflowX === 'auto' || parentStyle.overflowX === 'scroll');
    return rect.width > viewportWidth && !hasOverflowScroll;
  }).map(t => ({
    width: Math.round(t.getBoundingClientRect().width),
    columns: t.rows[0]?.cells.length || 0
  }));

  results.stats = {
    viewportWidth,
    documentWidth: Math.max(docWidth, bodyWidth),
    hasHorizontalScroll,
    overflowingElementCount: overflowingElements.length,
    fixedWidthElementCount: fixedWidthElements.length,
    unresponsiveTableCount: unresponsiveTables.length
  };

  if (hasHorizontalScroll) results.issues.push({ type: 'horizontal-scroll', overflowBy: Math.max(docWidth, bodyWidth) - viewportWidth, elements: overflowingElements });
  if (fixedWidthElements.length > 0) results.issues.push({ type: 'fixed-width', elements: fixedWidthElements });
  if (unresponsiveTables.length > 0) results.issues.push({ type: 'unresponsive-tables', tables: unresponsiveTables });

  return results;
})()
```

### Thumb Zone — Primary Actions Position

```javascript
(() => {
  const results = { check: "thumb-zone", issues: [], stats: {} };

  const viewportHeight = window.innerHeight;
  const viewportWidth = window.innerWidth;
  const isMobileViewport = viewportWidth <= 768;

  if (!isMobileViewport) {
    results.stats = { skipped: true, reason: 'Not a mobile viewport', viewportWidth };
    return results;
  }

  // Thumb zone: bottom 1/3 of screen is easiest to reach
  const thumbZoneTop = viewportHeight * (2 / 3);

  // Find primary CTAs
  const primaryCTAs = Array.from(document.querySelectorAll(
    '[data-cta="primary"], .cta-primary, .btn-primary, [class*="primary"], button[type="submit"], a[class*="cta"]'
  ));

  // Also find all buttons/links that look like primary actions
  const allActions = Array.from(document.querySelectorAll('button, [role="button"], a[class*="btn"]'));
  const prominentActions = allActions.filter(el => {
    const style = getComputedStyle(el);
    const bg = style.backgroundColor;
    const isProminent = bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent';
    return isProminent;
  });

  const actionsToCheck = primaryCTAs.length > 0 ? primaryCTAs : prominentActions.slice(0, 10);

  const actionPositions = actionsToCheck.map(el => {
    const rect = el.getBoundingClientRect();
    return {
      text: (el.textContent || '').trim().substring(0, 30),
      top: Math.round(rect.top),
      bottom: Math.round(rect.bottom),
      centerY: Math.round(rect.top + rect.height / 2),
      inThumbZone: rect.top >= thumbZoneTop,
      inViewport: rect.top >= 0 && rect.bottom <= viewportHeight,
      distanceFromThumbZone: rect.top < thumbZoneTop ? Math.round(thumbZoneTop - rect.top) : 0
    };
  });

  const outsideThumbZone = actionPositions.filter(a => !a.inThumbZone && a.inViewport);

  // Check if bottom navigation exists
  const bottomNav = document.querySelector('[class*="bottom-nav"], [class*="tab-bar"], [class*="footer-nav"], nav[class*="fixed"]');
  let hasBottomNav = false;
  if (bottomNav) {
    const rect = bottomNav.getBoundingClientRect();
    const style = getComputedStyle(bottomNav);
    hasBottomNav = (style.position === 'fixed' || style.position === 'sticky') && rect.bottom >= viewportHeight - 20;
  }

  results.stats = {
    viewportHeight,
    thumbZoneStartY: Math.round(thumbZoneTop),
    primaryActionsChecked: actionsToCheck.length,
    actionsInThumbZone: actionPositions.filter(a => a.inThumbZone).length,
    actionsOutsideThumbZone: outsideThumbZone.length,
    hasBottomNav
  };

  if (outsideThumbZone.length > 0) {
    results.issues.push({
      type: 'actions-outside-thumb-zone',
      count: outsideThumbZone.length,
      actions: outsideThumbZone.slice(0, 5)
    });
  }

  return results;
})()
```

### Touch Targets on Mobile

```javascript
(() => {
  const results = { check: "mobile-touch-targets", issues: [], stats: {} };

  const viewportWidth = window.innerWidth;
  const isMobile = viewportWidth <= 768;

  if (!isMobile) {
    results.stats = { skipped: true, reason: 'Not mobile viewport', viewportWidth };
    return results;
  }

  const interactives = Array.from(document.querySelectorAll(
    'a, button, [role="button"], input, select, textarea, [tabindex="0"], label[for]'
  ));

  const targetData = [];
  const undersized = [];

  interactives.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return;
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') return;

    const entry = {
      element: el.tagName.toLowerCase(),
      text: (el.textContent || el.value || '').trim().substring(0, 25),
      width: Math.round(rect.width),
      height: Math.round(rect.height)
    };

    targetData.push(entry);

    if (rect.width < 44 || rect.height < 44) {
      undersized.push(entry);
    }
  });

  results.stats = {
    totalTargets: targetData.length,
    undersizedCount: undersized.length,
    complianceRate: targetData.length > 0 ? Math.round((1 - undersized.length / targetData.length) * 100) : 100
  };

  if (undersized.length > 0) {
    results.issues.push({
      type: 'undersized-touch-target',
      count: undersized.length,
      elements: undersized.slice(0, 15)
    });
  }

  return results;
})()
```

### Viewport Meta Tag & Base Font Size

```javascript
(() => {
  const results = { check: "viewport-and-font", issues: [], stats: {} };

  // Check viewport meta tag
  const viewportMeta = document.querySelector('meta[name="viewport"]');
  const viewportContent = viewportMeta ? viewportMeta.getAttribute('content') : null;

  let viewportIssues = [];
  if (!viewportMeta) {
    viewportIssues.push('No viewport meta tag found');
  } else {
    if (!viewportContent.includes('width=device-width')) {
      viewportIssues.push('Missing width=device-width');
    }
    if (!viewportContent.includes('initial-scale=1') && !viewportContent.includes('initial-scale=1.0')) {
      viewportIssues.push('Missing initial-scale=1');
    }
    if (viewportContent.includes('maximum-scale=1') || viewportContent.includes('user-scalable=no') || viewportContent.includes('user-scalable=0')) {
      viewportIssues.push('Zoom is disabled — this harms accessibility');
    }
  }

  // Check body text font size (should be >= 16px on mobile to prevent iOS zoom)
  const bodyStyle = getComputedStyle(document.body);
  const bodyFontSize = parseFloat(bodyStyle.fontSize);

  // Check common text elements for font size
  const textElements = Array.from(document.querySelectorAll('p, li, td, span, label, .text, [class*="body"]'));
  const smallTextElements = textElements.filter(el => {
    const style = getComputedStyle(el);
    const size = parseFloat(style.fontSize);
    return size < 16 && el.textContent.trim().length > 20;
  }).slice(0, 10).map(el => ({
    element: el.tagName.toLowerCase() + (el.className ? '.' + String(el.className).split(' ')[0] : ''),
    fontSize: parseFloat(getComputedStyle(el).fontSize),
    preview: el.textContent.trim().substring(0, 40)
  }));

  // Check input font size (< 16px triggers iOS zoom on focus)
  const inputs = Array.from(document.querySelectorAll('input, select, textarea'));
  const smallInputs = inputs.filter(inp => {
    const size = parseFloat(getComputedStyle(inp).fontSize);
    return size < 16;
  }).map(inp => ({
    element: inp.tagName.toLowerCase(),
    type: inp.type || 'text',
    name: inp.name || inp.id || '',
    fontSize: parseFloat(getComputedStyle(inp).fontSize)
  }));

  results.stats = {
    hasViewportMeta: !!viewportMeta,
    viewportContent,
    bodyFontSize,
    smallTextCount: smallTextElements.length,
    smallInputCount: smallInputs.length
  };

  viewportIssues.forEach(msg => results.issues.push({ type: 'viewport', message: msg }));
  if (smallTextElements.length > 0) results.issues.push({ type: 'small-body-text', count: smallTextElements.length, elements: smallTextElements });
  if (smallInputs.length > 0) results.issues.push({ type: 'small-input-text', count: smallInputs.length, elements: smallInputs.slice(0, 5), message: 'Input font size < 16px triggers zoom on iOS Safari' });

  return results;
})()
```

## Tier 2: AI Judgment

### Designed vs. Squished
When viewing mobile screenshots:
1. Does the layout feel **intentionally designed for mobile**, or does it look like a desktop layout compressed?
2. Are **images appropriately sized** for the viewport — not stretched, cropped awkwardly, or too small to see?
3. Is **text readable without zooming** — proper line length (45-75 characters), adequate line height?
4. Do **cards and containers** have sufficient padding on mobile — content not jammed against screen edges?
5. Are **multi-column layouts** collapsed to single column on mobile, or are columns too narrow?
6. Do **horizontal elements** (feature comparisons, pricing tables) adapt to vertical layout?

### Content Prioritization
When comparing desktop vs mobile views:
1. Is the **most important content** shown first on mobile (not buried after secondary content)?
2. Are **hero sections** appropriately condensed — still impactful but not taking up 2+ screens?
3. Is **above-the-fold content** meaningful on mobile — can users understand the page purpose without scrolling?
4. Are **secondary elements** (sidebars, related content, ads) deprioritized or hidden on mobile?
5. Is the **CTA visible** without scrolling on mobile?

### Mobile Navigation Quality
When reviewing mobile navigation:
1. Is there a **hamburger menu or bottom nav** — not a squeezed horizontal desktop nav?
2. Does the **mobile menu** open smoothly and cover sufficient screen area?
3. Is the **back/close action** clearly visible in mobile menus?
4. Does the **search function** work well on mobile — full-width input, auto-suggestions?
5. Is **breadcrumb navigation** adapted for mobile (truncated, scrollable, or hidden)?
6. Can users **reach all pages** that are accessible on desktop?

### Thumb Comfort
When evaluating interactive elements on mobile:
1. Are **frequently used actions** positioned in the natural thumb reach zone (bottom 2/3 of screen)?
2. Are **destructive actions** (delete, cancel) positioned away from common tap areas?
3. Is there **adequate spacing** between tap targets — no risk of accidental taps?
4. Do **swipe gestures** feel natural and are they discoverable?
5. Are **modals and dialogs** positioned with action buttons in the bottom portion of the screen?

### Progressive Disclosure on Mobile
When reviewing content density:
1. Are **long forms** broken into steps on mobile instead of showing all fields at once?
2. Are **detailed content sections** collapsed by default with expand/collapse (accordion)?
3. Are **filter/sort options** in a drawer or bottom sheet rather than always visible?
4. Is **supplementary information** (tooltips, help text) behind tap-to-reveal rather than always shown?
5. Are **image galleries** adapted (thumbnails, swipe carousel) rather than showing all full-size images?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Zero horizontal overflow at all breakpoints (375/768/1024/1440). Primary actions in thumb zone. All touch targets >= 44px. Viewport meta tag correct. Body text >= 16px. Layout feels intentionally designed for each breakpoint. Content properly prioritized. Excellent mobile nav. Progressive disclosure throughout. |
| 4 | No overflow at standard breakpoints. 1-2 touch targets slightly undersized. Viewport meta correct. Text mostly >= 16px (1-2 small elements). Layout well-adapted but 1 section feels slightly compressed. Content priority mostly correct. Good mobile nav. Some progressive disclosure. |
| 3 | Minor horizontal overflow at 375px (< 20px). 3-5 undersized touch targets. Viewport meta present but zoom disabled. Several text elements < 16px. Some sections feel squished rather than redesigned. Content priority partially adapted. Basic hamburger menu. Limited progressive disclosure. |
| 2 | Horizontal overflow at 375px and 768px. Many undersized targets. Missing or misconfigured viewport meta. Input fields < 16px (iOS zoom issue). Desktop layout forced onto mobile. No content reprioritization. Navigation barely usable. No progressive disclosure — walls of content. |
| 1 | Horizontal overflow at all viewports. No viewport meta tag. Desktop-only layout with no responsive adaptation. Touch targets unusable. Text unreadable without zoom. No mobile navigation. Site essentially broken on mobile. |

## Common Fixes

### Horizontal Overflow Prevention
```css
/* Tailwind: max-w-full overflow-x-hidden on html/body */
html, body {
  max-width: 100%;
  overflow-x: hidden;
}
/* Fix common culprits */
img, video, iframe, table {
  max-width: 100%; /* Tailwind: max-w-full */
}
pre, code {
  overflow-x: auto; /* Tailwind: overflow-x-auto */
  max-width: 100%;
}
```

### Responsive Table
```css
/* Wrap tables in scrollable container */
/* Tailwind: overflow-x-auto */
.table-wrapper {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}
/* Or stack on mobile */
@media (max-width: 768px) {
  table, thead, tbody, th, td, tr {
    display: block;
  }
  th { display: none; }
  td::before {
    content: attr(data-label);
    font-weight: 600;
    display: inline-block;
    width: 120px;
  }
}
```

### Viewport Meta Tag
```html
<!-- Correct: allows zoom, sets device width -->
<meta name="viewport" content="width=device-width, initial-scale=1" />

<!-- Wrong: prevents zoom -->
<!-- <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" /> -->
```

### Mobile Font Size
```css
/* Prevent iOS zoom on input focus */
/* Tailwind: text-base (which is 16px) on all inputs */
input, select, textarea {
  font-size: 16px; /* Tailwind: text-base */
}
/* Body text minimum */
body {
  font-size: 16px; /* Tailwind: text-base */
  line-height: 1.6; /* Tailwind: leading-relaxed */
}
@media (max-width: 768px) {
  p, li, td {
    font-size: 16px;
    line-height: 1.6;
  }
}
```

### Thumb Zone CTA Positioning
```css
/* Fixed bottom CTA bar for mobile */
@media (max-width: 768px) {
  .cta-bar {
    position: fixed; /* Tailwind: fixed */
    bottom: 0; /* Tailwind: bottom-0 */
    left: 0;
    right: 0; /* Tailwind: inset-x-0 */
    padding: 12px 16px; /* Tailwind: px-4 py-3 */
    background: white; /* Tailwind: bg-white */
    border-top: 1px solid #e5e7eb; /* Tailwind: border-t */
    z-index: 40; /* Tailwind: z-40 */
    box-shadow: 0 -2px 10px rgba(0,0,0,0.05);
  }
  /* Add padding to body to prevent content hiding behind fixed CTA */
  body {
    padding-bottom: 80px;
  }
}
```

### Single Column on Mobile
```css
/* Tailwind: grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 */
.feature-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}
@media (min-width: 768px) {
  .feature-grid { grid-template-columns: repeat(2, 1fr); }
}
@media (min-width: 1024px) {
  .feature-grid { grid-template-columns: repeat(3, 1fr); }
}
```
