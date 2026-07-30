# Pass 9: Accessibility

## Tier 1: Automated Checks

### Axe-Core WCAG Violations

```javascript
(() => {
  const results = { pass: "accessibility", method: "axe-core", issues: [], stats: {} };

  // Check if axe is already loaded
  if (typeof axe === 'undefined') {
    results.stats.axeLoaded = false;
    results.issues.push({ type: 'axe-not-loaded', message: 'axe-core not available. Inject via script tag first.' });

    // Fallback: manual checks when axe is not available
    const manualChecks = [];

    // Check images without alt
    const imagesNoAlt = Array.from(document.querySelectorAll('img')).filter(img => {
      return !img.hasAttribute('alt');
    });
    if (imagesNoAlt.length > 0) {
      manualChecks.push({ rule: 'image-alt', count: imagesNoAlt.length, elements: imagesNoAlt.slice(0, 5).map(i => i.src?.substring(0, 60)) });
    }

    // Check form inputs without labels
    const inputsNoLabel = Array.from(document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]), select, textarea')).filter(input => {
      const id = input.id;
      const hasLabel = id && document.querySelector(`label[for="${id}"]`);
      const hasAriaLabel = input.getAttribute('aria-label');
      const hasAriaLabelledBy = input.getAttribute('aria-labelledby');
      const wrappedInLabel = input.closest('label');
      const hasTitle = input.getAttribute('title');
      return !hasLabel && !hasAriaLabel && !hasAriaLabelledBy && !wrappedInLabel && !hasTitle;
    });
    if (inputsNoLabel.length > 0) {
      manualChecks.push({ rule: 'label', count: inputsNoLabel.length, elements: inputsNoLabel.slice(0, 5).map(i => i.name || i.type || i.tagName) });
    }

    // Check buttons without accessible names
    const buttonsNoName = Array.from(document.querySelectorAll('button, [role="button"]')).filter(btn => {
      const text = (btn.textContent || '').trim();
      const ariaLabel = btn.getAttribute('aria-label');
      const ariaLabelledBy = btn.getAttribute('aria-labelledby');
      const title = btn.getAttribute('title');
      return !text && !ariaLabel && !ariaLabelledBy && !title;
    });
    if (buttonsNoName.length > 0) {
      manualChecks.push({ rule: 'button-name', count: buttonsNoName.length });
    }

    results.issues = manualChecks;
    return results;
  }

  // axe is available — this branch runs after injection
  results.stats.axeLoaded = true;
  return results;
})()
```

### Heading Hierarchy

```javascript
(() => {
  const results = { check: "heading-hierarchy", issues: [], stats: {} };

  const headings = Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6'));

  const headingList = headings.map(h => ({
    level: parseInt(h.tagName.charAt(1)),
    text: (h.textContent || '').trim().substring(0, 60),
    visible: getComputedStyle(h).display !== 'none' && getComputedStyle(h).visibility !== 'hidden'
  }));

  // Count h1 elements
  const h1Count = headingList.filter(h => h.level === 1).length;

  // Check for skipped levels
  const skippedLevels = [];
  for (let i = 1; i < headingList.length; i++) {
    const current = headingList[i].level;
    const previous = headingList[i - 1].level;
    if (current > previous + 1) {
      skippedLevels.push({
        from: `h${previous}`,
        to: `h${current}`,
        skipped: Array.from({ length: current - previous - 1 }, (_, j) => `h${previous + 1 + j}`).join(', '),
        nearText: headingList[i].text
      });
    }
  }

  // Check for empty headings
  const emptyHeadings = headingList.filter(h => !h.text || h.text.length === 0);

  results.stats = {
    totalHeadings: headingList.length,
    h1Count,
    hasExactlyOneH1: h1Count === 1,
    skippedLevelCount: skippedLevels.length,
    emptyHeadingCount: emptyHeadings.length,
    hierarchy: headingList.slice(0, 20)
  };

  if (h1Count === 0) results.issues.push({ type: 'missing-h1', message: 'No h1 element found on page' });
  if (h1Count > 1) results.issues.push({ type: 'multiple-h1', count: h1Count, message: `Found ${h1Count} h1 elements, expected exactly 1` });
  if (skippedLevels.length > 0) results.issues.push({ type: 'skipped-levels', skips: skippedLevels });
  if (emptyHeadings.length > 0) results.issues.push({ type: 'empty-headings', count: emptyHeadings.length });

  return results;
})()
```

### Landmarks

```javascript
(() => {
  const results = { check: "landmarks", issues: [], stats: {} };

  const landmarks = {
    main: document.querySelectorAll('main, [role="main"]').length,
    nav: document.querySelectorAll('nav, [role="navigation"]').length,
    banner: document.querySelectorAll('header, [role="banner"]').length,
    contentinfo: document.querySelectorAll('footer, [role="contentinfo"]').length,
    complementary: document.querySelectorAll('aside, [role="complementary"]').length,
    search: document.querySelectorAll('[role="search"], search').length,
    form: document.querySelectorAll('[role="form"]').length,
    region: document.querySelectorAll('[role="region"][aria-label], [role="region"][aria-labelledby], section[aria-label], section[aria-labelledby]').length
  };

  // Required landmarks
  if (landmarks.main === 0) results.issues.push({ type: 'missing-main', message: 'No <main> or [role="main"] landmark found' });
  if (landmarks.main > 1) results.issues.push({ type: 'multiple-main', count: landmarks.main, message: 'Multiple main landmarks found, expected 1' });
  if (landmarks.nav === 0) results.issues.push({ type: 'missing-nav', message: 'No <nav> or [role="navigation"] landmark found' });
  if (landmarks.banner === 0) results.issues.push({ type: 'missing-header', message: 'No <header> or [role="banner"] landmark found' });
  if (landmarks.contentinfo === 0) results.issues.push({ type: 'missing-footer', message: 'No <footer> or [role="contentinfo"] landmark found' });

  // Check that all page content is inside a landmark
  const bodyChildren = Array.from(document.body.children);
  const outsideLandmark = bodyChildren.filter(el => {
    const tag = el.tagName.toLowerCase();
    const role = el.getAttribute('role');
    const isLandmark = ['header', 'nav', 'main', 'aside', 'footer', 'section', 'search'].includes(tag) ||
      ['banner', 'navigation', 'main', 'complementary', 'contentinfo', 'search', 'form', 'region'].includes(role);
    const isScript = ['script', 'style', 'link', 'noscript', 'template'].includes(tag);
    const isHidden = getComputedStyle(el).display === 'none';
    return !isLandmark && !isScript && !isHidden && el.textContent.trim().length > 0;
  });

  results.stats = { landmarks, contentOutsideLandmarks: outsideLandmark.length };
  if (outsideLandmark.length > 0) {
    results.issues.push({
      type: 'content-outside-landmarks',
      count: outsideLandmark.length,
      elements: outsideLandmark.slice(0, 5).map(el => el.tagName.toLowerCase() + (el.className ? '.' + el.className.split(' ')[0] : ''))
    });
  }

  return results;
})()
```

### Image Alt Text

```javascript
(() => {
  const results = { check: "image-alt", issues: [], stats: {} };

  const images = Array.from(document.querySelectorAll('img'));
  const svgs = Array.from(document.querySelectorAll('svg'));
  const bgImages = Array.from(document.querySelectorAll('*')).filter(el => {
    const bg = getComputedStyle(el).backgroundImage;
    return bg && bg !== 'none' && bg.includes('url(');
  });

  const missingAlt = images.filter(img => !img.hasAttribute('alt'));
  const emptyAltOnContent = images.filter(img => {
    const alt = img.getAttribute('alt');
    const isDecorative = img.getAttribute('role') === 'presentation' || img.getAttribute('aria-hidden') === 'true';
    // Empty alt is OK only for decorative images
    return alt === '' && !isDecorative && !img.closest('a, button');
  });
  const redundantAlt = images.filter(img => {
    const alt = (img.getAttribute('alt') || '').toLowerCase();
    return alt.includes('image of') || alt.includes('photo of') || alt.includes('picture of') || alt === 'image' || alt === 'photo' || alt === 'icon';
  });

  // SVGs without accessible names
  const svgsNoTitle = svgs.filter(svg => {
    const title = svg.querySelector('title');
    const ariaLabel = svg.getAttribute('aria-label');
    const ariaHidden = svg.getAttribute('aria-hidden');
    const role = svg.getAttribute('role');
    return !title && !ariaLabel && ariaHidden !== 'true' && role !== 'presentation';
  });

  results.stats = {
    totalImages: images.length,
    missingAltCount: missingAlt.length,
    emptyAltOnContentImages: emptyAltOnContent.length,
    redundantAltCount: redundantAlt.length,
    svgCount: svgs.length,
    svgsWithoutTitleCount: svgsNoTitle.length,
    backgroundImageCount: bgImages.length
  };

  if (missingAlt.length > 0) results.issues.push({ type: 'missing-alt', count: missingAlt.length, elements: missingAlt.slice(0, 5).map(i => i.src?.substring(0, 60)) });
  if (redundantAlt.length > 0) results.issues.push({ type: 'redundant-alt', count: redundantAlt.length, elements: redundantAlt.slice(0, 5).map(i => ({ src: i.src?.substring(0, 40), alt: i.alt })) });
  if (svgsNoTitle.length > 0) results.issues.push({ type: 'svg-no-title', count: svgsNoTitle.length });

  return results;
})()
```

### Form Labels

```javascript
(() => {
  const results = { check: "form-labels", issues: [], stats: {} };

  const inputs = Array.from(document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="reset"]):not([type="image"]), select, textarea'));

  const inputDetails = inputs.map(input => {
    const id = input.id;
    const name = input.name || '';
    const type = input.type || input.tagName.toLowerCase();
    const hasExplicitLabel = id && document.querySelector(`label[for="${id}"]`) !== null;
    const hasAriaLabel = !!input.getAttribute('aria-label');
    const hasAriaLabelledBy = !!input.getAttribute('aria-labelledby');
    const wrappedInLabel = input.closest('label') !== null;
    const hasTitle = !!input.getAttribute('title');
    const hasPlaceholderOnly = !!input.getAttribute('placeholder') && !hasExplicitLabel && !hasAriaLabel && !hasAriaLabelledBy && !wrappedInLabel;
    const hasAnyLabel = hasExplicitLabel || hasAriaLabel || hasAriaLabelledBy || wrappedInLabel || hasTitle;

    return {
      name: name || id || type,
      type,
      hasLabel: hasAnyLabel,
      labelMethod: hasExplicitLabel ? 'for/id' : hasAriaLabel ? 'aria-label' : hasAriaLabelledBy ? 'aria-labelledby' : wrappedInLabel ? 'wrapped' : hasTitle ? 'title' : 'none',
      placeholderOnly: hasPlaceholderOnly
    };
  });

  const unlabeled = inputDetails.filter(i => !i.hasLabel);
  const placeholderOnly = inputDetails.filter(i => i.placeholderOnly);

  results.stats = {
    totalInputs: inputs.length,
    unlabeledCount: unlabeled.length,
    placeholderOnlyCount: placeholderOnly.length
  };

  if (unlabeled.length > 0) results.issues.push({ type: 'missing-label', count: unlabeled.length, elements: unlabeled.slice(0, 10) });
  if (placeholderOnly.length > 0) results.issues.push({ type: 'placeholder-as-label', count: placeholderOnly.length, elements: placeholderOnly.slice(0, 10), message: 'Placeholder is not a substitute for a label — it disappears on input' });

  return results;
})()
```

### Touch Targets & Spacing

```javascript
(() => {
  const results = { check: "touch-targets", issues: [], stats: {} };

  const interactives = Array.from(document.querySelectorAll('a, button, [role="button"], input, select, textarea, [tabindex="0"], label[for]'));

  const targetData = interactives.map(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return null;
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') return null;
    return { el, rect, width: rect.width, height: rect.height };
  }).filter(Boolean);

  const undersized = targetData.filter(t => t.width < 44 || t.height < 44).map(t => ({
    element: t.el.tagName.toLowerCase() + (t.el.className ? '.' + String(t.el.className).split(' ')[0] : ''),
    text: (t.el.textContent || '').trim().substring(0, 30),
    width: Math.round(t.width),
    height: Math.round(t.height)
  }));

  // Check spacing between adjacent interactive elements (minimum 8px gap)
  const tooClose = [];
  for (let i = 0; i < targetData.length && i < 200; i++) {
    for (let j = i + 1; j < targetData.length && j < 200; j++) {
      const a = targetData[i].rect;
      const b = targetData[j].rect;
      const hGap = Math.max(0, Math.max(b.left - a.right, a.left - b.right));
      const vGap = Math.max(0, Math.max(b.top - a.bottom, a.top - b.bottom));
      const gap = Math.min(hGap, vGap);
      // Only flag if they're on the same row/column (within overlap)
      const sameRow = !(a.bottom < b.top || b.bottom < a.top);
      const sameCol = !(a.right < b.left || b.right < a.left);
      if ((sameRow || sameCol) && gap < 8 && gap >= 0) {
        tooClose.push({
          elementA: (targetData[i].el.textContent || '').trim().substring(0, 20),
          elementB: (targetData[j].el.textContent || '').trim().substring(0, 20),
          gap: Math.round(gap)
        });
        if (tooClose.length >= 10) break;
      }
    }
    if (tooClose.length >= 10) break;
  }

  results.stats = {
    totalTargets: targetData.length,
    undersizedCount: undersized.length,
    tooCloseCount: tooClose.length
  };

  if (undersized.length > 0) results.issues.push({ type: 'undersized-target', count: undersized.length, elements: undersized.slice(0, 10) });
  if (tooClose.length > 0) results.issues.push({ type: 'insufficient-spacing', count: tooClose.length, pairs: tooClose.slice(0, 5) });

  return results;
})()
```

### Reduced Motion Respect

```javascript
(() => {
  const results = { check: "reduced-motion", issues: [], stats: {} };

  // Check all stylesheets for prefers-reduced-motion media queries
  let hasReducedMotionQuery = false;
  try {
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules || []) {
          if (rule.type === CSSRule.MEDIA_RULE && rule.conditionText && rule.conditionText.includes('prefers-reduced-motion')) {
            hasReducedMotionQuery = true;
            break;
          }
        }
      } catch (e) { /* cross-origin stylesheet */ }
      if (hasReducedMotionQuery) break;
    }
  } catch (e) { /* stylesheet access error */ }

  // Check for CSS animations and transitions in use
  const animated = [];
  const allEls = document.querySelectorAll('*');
  for (let i = 0; i < Math.min(allEls.length, 500); i++) {
    const style = getComputedStyle(allEls[i]);
    const hasAnimation = style.animationName && style.animationName !== 'none';
    const hasTransition = style.transitionProperty && style.transitionProperty !== 'all' && style.transitionDuration !== '0s';
    if (hasAnimation) {
      animated.push({
        element: allEls[i].tagName.toLowerCase() + (allEls[i].className ? '.' + String(allEls[i].className).split(' ')[0] : ''),
        type: 'animation',
        name: style.animationName,
        duration: style.animationDuration
      });
    }
  }

  // Check for autoplay videos
  const autoplayVideos = Array.from(document.querySelectorAll('video[autoplay]'));
  const autoplayWithoutMuted = autoplayVideos.filter(v => !v.muted);

  // Check for GIFs (which can't be paused)
  const gifs = Array.from(document.querySelectorAll('img[src*=".gif"], img[src*=".GIF"]'));

  results.stats = {
    hasReducedMotionQuery,
    animatedElementCount: animated.length,
    autoplayVideoCount: autoplayVideos.length,
    autoplayWithoutMutedCount: autoplayWithoutMuted.length,
    gifCount: gifs.length
  };

  if (!hasReducedMotionQuery && animated.length > 0) {
    results.issues.push({ type: 'no-reduced-motion-query', message: 'Animations detected but no prefers-reduced-motion media query found', animatedCount: animated.length });
  }
  if (autoplayWithoutMuted.length > 0) {
    results.issues.push({ type: 'autoplay-not-muted', count: autoplayWithoutMuted.length });
  }
  if (gifs.length > 0) {
    results.issues.push({ type: 'animated-gif', count: gifs.length, message: 'Animated GIFs cannot be paused by users' });
  }

  return results;
})()
```

## Tier 2: AI Judgment

### Cognitive Load
When reviewing the screenshot:
1. Is there **at most one primary action** visible per screen or section?
2. Is **progressive disclosure** used — are advanced options hidden behind "More" or expandable sections?
3. Can a user **understand the page purpose** within 5 seconds of looking at the screenshot?
4. Are **instructions minimal** — does the interface explain itself through layout rather than text instructions?
5. Is **information density** appropriate — not too sparse (wasted space) or too dense (overwhelming)?
6. Are **related items grouped** visually (Gestalt proximity) to reduce scanning effort?
7. Is there a **clear visual hierarchy** — can you instantly identify what to read/do first, second, third?

### Neurodiversity Considerations
When reviewing the interface:
1. Is there **no autoplaying media** (video, audio, carousel) that starts without user action?
2. Are there **no flashing or strobing elements** that flash more than 3 times per second?
3. Is **wall-of-text avoided** — are paragraphs short (3-4 sentences max), with headings breaking up sections?
4. Are **fonts legible** — not overly decorative, thin, or low-contrast for body text?
5. Is **color not the sole means** of conveying information (error states, status, required fields)?
6. Are **patterns and textures** used sparingly and not overwhelming?
7. Is the **reading level appropriate** — is language plain and jargon-free for the target audience?

### Motor Accessibility
When reviewing mobile viewports:
1. Are **hover-only interactions** absent — can all functionality be accessed via tap/click?
2. Are **drag interactions** optional — is there an alternative way to accomplish drag-based tasks?
3. Are **gesture-based controls** (swipe, pinch) supplemented with button alternatives?
4. Are **time limits** generous or adjustable — no features that require rapid tapping or precise timing?
5. Are **error recovery paths** easy — undo, back, and cancel are always accessible?

### Focus Visibility
When reviewing keyboard interaction:
1. Is there a **visible focus indicator** on all interactive elements when tabbed to?
2. Does the **focus indicator have sufficient contrast** (3:1 ratio against adjacent colors)?
3. Is the **focus order logical** — does it follow the visual reading order (left-to-right, top-to-bottom)?
4. Are there **no keyboard traps** — can users tab into and out of all components (modals, menus, widgets)?
5. Are **skip links** provided to bypass repetitive navigation?
6. Do **custom components** (dropdowns, date pickers, carousels) support full keyboard operation?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Zero axe-core violations (critical/serious). Heading hierarchy h1-h6 with no skips and exactly 1 h1. All landmarks present. 100% of images have meaningful alt text. 100% of inputs labeled. All touch targets >= 44px with >= 8px gaps. prefers-reduced-motion handled. No cognitive overload. Full keyboard support with visible focus. |
| 4 | 0 critical, 1-2 serious axe violations. Heading hierarchy mostly correct (1 skip). All required landmarks present. 1-2 images missing alt. 1-2 inputs rely on placeholder only. 1-3 undersized targets. Reduced motion partially handled. Minor cognitive load issues. Focus visible on most elements. |
| 3 | 0 critical, 3-5 serious violations. Heading hierarchy has 2-3 skips. Missing 1 required landmark. 3-5 images missing alt. 3-5 inputs unlabeled. 4-6 undersized targets. No reduced motion query but few animations. Some cognitive load issues. Focus occasionally invisible. |
| 2 | 1-2 critical violations. No heading hierarchy. Missing multiple landmarks. 6-10 images missing alt. Multiple unlabeled form fields. Many undersized targets. Autoplay media without controls. Significant cognitive overload. Focus ring removed globally. |
| 1 | 3+ critical violations. No semantic HTML (divs for everything). No landmarks. Most images missing alt. Forms unusable without sight. Tiny touch targets everywhere. Flashing content. Wall-of-text throughout. No keyboard support. Inaccessible custom widgets. |

## Common Fixes

### Missing Alt Text
```html
<!-- Tailwind: No styling fix — this is an HTML attribute fix -->
<img src="hero.jpg" alt="Team collaborating around a whiteboard in modern office" />
<!-- Decorative images: -->
<img src="divider.svg" alt="" role="presentation" />
```

### Missing Form Labels
```html
<!-- Add visible label (preferred) -->
<label for="email" class="block text-sm font-medium text-gray-700">Email address</label>
<input type="email" id="email" name="email" />

<!-- Or screen-reader only label: Tailwind sr-only -->
<label for="search" class="sr-only">Search</label>
<input type="search" id="search" placeholder="Search..." />
```

### Focus Visibility
```css
/* Tailwind: focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-blue-500 */
*:focus-visible {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
}
/* Never do this: */
/* *:focus { outline: none; } */
```

### Touch Target Size
```css
/* Tailwind: min-h-[44px] min-w-[44px] or p-3 */
.touch-target {
  min-height: 44px;
  min-width: 44px;
  padding: 10px;
}
/* Inline links in text — use padding to increase target: */
a {
  padding: 4px 0; /* Tailwind: py-1 */
}
```

### Reduced Motion
```css
/* Tailwind: motion-reduce:transition-none motion-reduce:animate-none */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### Skip Link
```html
<!-- First element in body -->
<a href="#main-content" class="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-white focus:text-black focus:ring-2">
  Skip to main content
</a>
```

### Heading Hierarchy
```html
<!-- Correct: -->
<h1>Page Title</h1>
  <h2>Section</h2>
    <h3>Subsection</h3>
  <h2>Another Section</h2>

<!-- Wrong: Skipping from h1 to h3 -->
<h1>Page Title</h1>
  <h3>Subsection</h3> <!-- Missing h2 -->
```

### Color Not Sole Indicator
```css
/* Add icon or text alongside color for errors */
.error-field {
  border-color: #ef4444; /* Tailwind: border-red-500 */
  border-width: 2px; /* Tailwind: border-2 (thicker border as secondary indicator) */
}
.error-message::before {
  content: "⚠ "; /* Icon as secondary indicator */
}
```
