# Pass 8: Laws of UX

## Tier 1: Automated Checks

### Fitts's Law — CTA Size & Proximity

```javascript
(() => {
  const results = { law: "fitts", issues: [], stats: {} };

  // Find all interactive elements
  const interactives = Array.from(document.querySelectorAll(
    'a, button, [role="button"], input[type="submit"], input[type="button"], [onclick], [tabindex="0"]'
  ));

  const undersizedTargets = [];
  const ctaSizes = [];

  interactives.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return;
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') return;

    const width = rect.width;
    const height = rect.height;
    const area = width * height;

    ctaSizes.push({ text: (el.textContent || '').trim().substring(0, 40), width: Math.round(width), height: Math.round(height), area: Math.round(area) });

    // Touch target minimum: 44x44px (WCAG 2.5.5 AAA) / 24x24px (WCAG 2.5.8 AA)
    if (width < 44 || height < 44) {
      undersizedTargets.push({
        element: el.tagName.toLowerCase() + (el.className ? '.' + el.className.split(' ')[0] : ''),
        text: (el.textContent || '').trim().substring(0, 30),
        width: Math.round(width),
        height: Math.round(height),
        belowMinimum: true
      });
    }
  });

  // Find primary CTA (largest button or [data-cta], .cta, .btn-primary)
  const primaryCTA = document.querySelector('[data-cta="primary"], .cta-primary, .btn-primary, [class*="primary"]');
  let primaryCTAInfo = null;
  if (primaryCTA) {
    const rect = primaryCTA.getBoundingClientRect();
    primaryCTAInfo = {
      text: (primaryCTA.textContent || '').trim().substring(0, 40),
      width: Math.round(rect.width),
      height: Math.round(rect.height),
      isLargestClickable: ctaSizes.length > 0 && (rect.width * rect.height) >= Math.max(...ctaSizes.map(c => c.area)) * 0.8
    };
  }

  // Measure distance from main content area to primary CTA
  const mainContent = document.querySelector('main, [role="main"], .main-content, #content');
  let distanceToCTA = null;
  if (primaryCTA && mainContent) {
    const ctaRect = primaryCTA.getBoundingClientRect();
    const mainRect = mainContent.getBoundingClientRect();
    distanceToCTA = Math.round(Math.sqrt(
      Math.pow(ctaRect.x + ctaRect.width / 2 - (mainRect.x + mainRect.width / 2), 2) +
      Math.pow(ctaRect.y + ctaRect.height / 2 - (mainRect.y + mainRect.height / 2), 2)
    ));
  }

  results.stats = {
    totalInteractiveElements: interactives.length,
    undersizedCount: undersizedTargets.length,
    primaryCTA: primaryCTAInfo,
    distanceToCTA
  };
  results.issues = undersizedTargets.slice(0, 15);

  return results;
})()
```

### Hick's Law — Choice Overload Detection

```javascript
(() => {
  const results = { law: "hicks", issues: [], stats: {} };

  // Check navigation menus for option count
  const navs = Array.from(document.querySelectorAll('nav, [role="navigation"]'));
  const navIssues = navs.map(nav => {
    const topLevelLinks = Array.from(nav.children).filter(c => {
      const tag = c.tagName.toLowerCase();
      return tag === 'a' || tag === 'li' || tag === 'button' || (c.querySelector && c.querySelector('a'));
    });
    // Also check for ul > li pattern
    const listItems = Array.from(nav.querySelectorAll(':scope > ul > li, :scope > ol > li'));
    const count = Math.max(topLevelLinks.length, listItems.length);
    return {
      element: nav.getAttribute('aria-label') || nav.className || 'nav',
      optionCount: count,
      exceeds7Plus2: count > 9,
      exceeds7: count > 7
    };
  });

  // Check dropdowns and select elements
  const selects = Array.from(document.querySelectorAll('select'));
  const selectIssues = selects.map(sel => {
    const optionCount = sel.options.length;
    return {
      element: sel.name || sel.id || 'select',
      optionCount,
      exceeds7Plus2: optionCount > 9,
      needsSearch: optionCount > 15
    };
  });

  // Check navigation depth (nested dropdowns)
  const maxDepth = (() => {
    let max = 0;
    const walk = (el, depth) => {
      if (depth > max) max = depth;
      const submenus = el.querySelectorAll(':scope > ul, :scope > [role="menu"]');
      submenus.forEach(sub => walk(sub, depth + 1));
    };
    navs.forEach(nav => walk(nav, 1));
    return max;
  })();

  // Check forms for number of fields
  const forms = Array.from(document.querySelectorAll('form'));
  const formIssues = forms.map(form => {
    const fields = form.querySelectorAll('input:not([type="hidden"]), select, textarea');
    return {
      formId: form.id || form.action || 'form',
      fieldCount: fields.length,
      tooManyChoices: fields.length > 9
    };
  });

  results.stats = {
    navigationMenus: navIssues,
    selectElements: selectIssues,
    maxNavigationDepth: maxDepth,
    navDepthExceedsMax: maxDepth > 3,
    forms: formIssues
  };

  results.issues = [
    ...navIssues.filter(n => n.exceeds7Plus2).map(n => ({ type: 'nav-overload', ...n })),
    ...selectIssues.filter(s => s.exceeds7Plus2).map(s => ({ type: 'select-overload', ...s })),
    ...formIssues.filter(f => f.tooManyChoices).map(f => ({ type: 'form-overload', ...f })),
    ...(maxDepth > 3 ? [{ type: 'nav-depth', maxDepth, maxAllowed: 3 }] : [])
  ];

  return results;
})()
```

### Miller's Law — Content Chunking

```javascript
(() => {
  const results = { law: "miller", issues: [], stats: {} };

  // Check if content is chunked into groups
  const sections = document.querySelectorAll('section, article, [role="region"], .section, .card, .block');
  const sectionCount = sections.length;

  // Check for long unbroken text blocks
  const paragraphs = Array.from(document.querySelectorAll('p'));
  const longParagraphs = paragraphs.filter(p => {
    const words = (p.textContent || '').trim().split(/\s+/).length;
    return words > 80;
  }).map(p => ({
    preview: (p.textContent || '').trim().substring(0, 60) + '...',
    wordCount: (p.textContent || '').trim().split(/\s+/).length
  }));

  // Check for unformatted numbers (phone, credit card, SSN patterns)
  const bodyText = document.body.innerText || '';
  const unformattedNumbers = [];
  const longNumberPattern = /\b\d{8,}\b/g;
  let match;
  while ((match = longNumberPattern.exec(bodyText)) !== null) {
    unformattedNumbers.push({ number: match[0], index: match.index });
    if (unformattedNumbers.length >= 10) break;
  }

  // Check list item counts
  const lists = Array.from(document.querySelectorAll('ul, ol'));
  const longLists = lists.filter(l => l.children.length > 9).map(l => ({
    type: l.tagName.toLowerCase(),
    itemCount: l.children.length,
    firstItem: (l.children[0]?.textContent || '').trim().substring(0, 30),
    needsGrouping: l.children.length > 9
  }));

  // Check grid/card layouts for item counts per visible group
  const gridContainers = Array.from(document.querySelectorAll('[class*="grid"], [class*="cards"], [class*="items"], [style*="grid"]'));
  const gridIssues = gridContainers.map(g => {
    const children = Array.from(g.children).filter(c => {
      const s = getComputedStyle(c);
      return s.display !== 'none' && s.visibility !== 'hidden';
    });
    return {
      element: g.className ? g.className.split(' ')[0] : g.tagName,
      childCount: children.length,
      exceedsChunkSize: children.length > 9
    };
  }).filter(g => g.exceedsChunkSize);

  results.stats = {
    sectionCount,
    contentChunked: sectionCount >= 3 && sectionCount <= 9,
    longParagraphCount: longParagraphs.length,
    unformattedNumberCount: unformattedNumbers.length,
    longListCount: longLists.length
  };

  results.issues = [
    ...longParagraphs.slice(0, 5).map(p => ({ type: 'unchunked-text', ...p })),
    ...unformattedNumbers.slice(0, 5).map(n => ({ type: 'unformatted-number', ...n })),
    ...longLists.slice(0, 5).map(l => ({ type: 'long-list', ...l })),
    ...gridIssues.slice(0, 5).map(g => ({ type: 'grid-overload', ...g }))
  ];

  return results;
})()
```

### Doherty Threshold — Response Time

```javascript
(() => {
  const results = { law: "doherty", issues: [], stats: {} };

  const perf = performance.getEntriesByType('navigation')[0];
  const paintEntries = performance.getEntriesByType('paint');

  const fcp = paintEntries.find(e => e.name === 'first-contentful-paint');
  const lcp = (() => {
    try {
      const entries = performance.getEntriesByType('largest-contentful-paint');
      return entries.length > 0 ? entries[entries.length - 1] : null;
    } catch (e) { return null; }
  })();

  const metrics = {};
  if (perf) {
    metrics.domContentLoaded = Math.round(perf.domContentLoadedEventEnd - perf.startTime);
    metrics.loadComplete = Math.round(perf.loadEventEnd - perf.startTime);
    metrics.ttfb = Math.round(perf.responseStart - perf.startTime);
    metrics.domInteractive = Math.round(perf.domInteractive - perf.startTime);
    metrics.serverResponseTime = Math.round(perf.responseEnd - perf.requestStart);
  }

  if (fcp) metrics.firstContentfulPaint = Math.round(fcp.startTime);
  if (lcp) metrics.largestContentfulPaint = Math.round(lcp.startTime);

  // Doherty Threshold: system response < 400ms keeps users in flow
  const dohertyThreshold = 400;
  const issues = [];

  if (metrics.ttfb && metrics.ttfb > dohertyThreshold) {
    issues.push({ metric: 'TTFB', value: metrics.ttfb, threshold: dohertyThreshold, unit: 'ms' });
  }
  if (metrics.firstContentfulPaint && metrics.firstContentfulPaint > dohertyThreshold) {
    issues.push({ metric: 'FCP', value: metrics.firstContentfulPaint, threshold: dohertyThreshold, unit: 'ms' });
  }
  if (metrics.domInteractive && metrics.domInteractive > dohertyThreshold) {
    issues.push({ metric: 'DOM Interactive', value: metrics.domInteractive, threshold: dohertyThreshold, unit: 'ms' });
  }

  // Check for transitions and animations that might affect perceived speed
  const allElements = document.querySelectorAll('*');
  let transitionCount = 0;
  for (let i = 0; i < Math.min(allElements.length, 500); i++) {
    const style = getComputedStyle(allElements[i]);
    if (style.transitionDuration && style.transitionDuration !== '0s') transitionCount++;
  }

  results.stats = { ...metrics, dohertyThreshold, transitionCount };
  results.issues = issues;

  return results;
})()
```

## Tier 2: AI Judgment

### Jakob's Law — Convention Compliance
When reviewing the screenshot:
1. Is the **logo** in the top-left corner and does it link to the homepage?
2. Is the **primary navigation** horizontal across the top or in a left sidebar?
3. Is the **search bar** in the header area (top-center or top-right)?
4. Is the **shopping cart icon** (if applicable) in the top-right corner?
5. Is the **login/account link** in the top-right area?
6. Does the **footer** contain contact info, privacy policy, and sitemap links?
7. Do **links** look visually distinct from body text (underline or color)?
8. Is the **"back" or "cancel" action** on the left side of button groups?
9. Does the **form layout** follow a single-column pattern (not scattered)?
10. Do **error messages** appear near the field that caused the error?

### Peak-End Rule — Flow Endings
When reviewing multi-step flows (checkout, signup, onboarding):
1. Is the **final screen** of each flow the most visually polished (celebration, confirmation, next steps)?
2. Does the **success state** include a clear confirmation message with visual emphasis (checkmark, color, animation)?
3. Does the **thank you / confirmation page** provide clear next steps or a path forward?
4. Is the **highest friction point** (payment, personal info) followed by a rewarding moment?
5. Does the **error recovery flow** end on a positive note (not just "try again")?
6. Are **empty states** (no results, empty cart) designed to feel encouraging rather than dead-end?

### Von Restorff Effect — Isolation & Emphasis
When reviewing each visible section:
1. Is there **exactly one standout element** per section (not competing for attention)?
2. Does the **primary CTA** contrast clearly with secondary actions?
3. Are **sale prices, badges, or promotions** visually distinct from surrounding content?
4. Is the **most important information** in each card/section visually differentiated?
5. Do **multiple highlighted elements** in the same view compete and cancel each other out?

### Tesler's Law — Complexity Management
When reviewing the interface:
1. Does the system **absorb complexity** that the user shouldn't need to manage (smart defaults, auto-detection)?
2. Are **addresses auto-completed** or formatted for the user?
3. Does the system **pre-fill known information** (logged-in user's name, email, preferences)?
4. Are **date/time pickers** provided instead of requiring manual text entry in specific formats?
5. Does the system **calculate derived values** automatically (totals, taxes, shipping)?
6. Are **error messages actionable** — telling users exactly what to fix, not just what went wrong?

### Postel's Law — Robustness Principle
When reviewing forms and inputs:
1. Does the system **accept flexible input formats** (phone: 555-1234, (555) 1234, 5551234)?
2. Are **dates accepted** in multiple formats or via picker?
3. Does **search** tolerate typos, partial matches, or synonyms?
4. Is **output always strict and consistent** regardless of input variations?
5. Do **form fields strip whitespace** and handle copy-paste gracefully?

### Zeigarnik Effect — Progress & Continuity
When reviewing multi-step flows:
1. Do **multi-step processes** show a progress indicator (stepper, progress bar, breadcrumb)?
2. Is it clear **which step the user is on** and how many remain?
3. Are **incomplete profiles or tasks** surfaced with a completion percentage?
4. Does the interface **save draft state** so users can return to incomplete work?
5. Do **onboarding flows** show progress to encourage completion?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | All touch targets >= 44px. Nav has <= 7 items with max depth 3. Content chunked into 5-9 groups. Numbers formatted. Page loads under 400ms. Conventions followed perfectly. Clear progress indicators. One standout per section. System absorbs all manageable complexity. |
| 4 | 1-2 undersized targets. Nav 8-9 items but well-organized. Content mostly chunked. Minor formatting gaps. Page loads 400-800ms. 1 convention deviation. Progress shown in most flows. Occasional competing emphasis. Complexity mostly managed by system. |
| 3 | 3-5 undersized targets. Nav 10+ items or depth 4. Some unchunked content blocks. Several unformatted numbers. Page loads 800ms-1.5s. 2-3 convention deviations. Progress shown inconsistently. Multiple sections with competing emphasis. User handles some avoidable complexity. |
| 2 | 6-10 undersized targets. Nav overwhelming (15+ items or depth 5+). Large text walls. Many unformatted numbers. Page loads 1.5-3s. Multiple broken conventions. No progress indicators in multi-step flows. No clear visual hierarchy. User forced to manage significant complexity. |
| 1 | 10+ undersized targets. Navigation unusable. No content chunking. No number formatting. Page loads > 3s. Interface follows no standard conventions. No progress indicators anywhere. Random visual emphasis. System pushes all complexity to user. |

## Common Fixes

### Undersized Touch Targets
```css
/* Tailwind: min-w-[44px] min-h-[44px] or p-3 on buttons */
button, a, [role="button"] {
  min-width: 44px;
  min-height: 44px;
  padding: 12px 16px;
}
```

### Navigation Overload
```css
/* Group nav items visually with separators */
nav > ul > li:nth-child(5) {
  border-left: 1px solid var(--border-color);
  margin-left: 8px;
  padding-left: 8px;
}
/* Tailwind: Use divide-x or border-l on grouped items */
```

### Content Chunking
```css
/* Add visual separation between content groups */
section + section {
  margin-top: 3rem; /* Tailwind: mt-12 */
  padding-top: 3rem; /* Tailwind: pt-12 */
  border-top: 1px solid var(--border-color); /* Tailwind: border-t */
}
```

### Number Formatting
This is a logic fix, not CSS. Format phone numbers, credit cards, and long numbers with separators:
- Phone: `(555) 123-4567`
- Credit card: `4242 4242 4242 4242`
- Large numbers: `1,234,567`

### CTA Emphasis (Von Restorff)
```css
/* Make primary CTA stand out from secondary actions */
.btn-primary {
  font-size: 1.125rem; /* Tailwind: text-lg */
  padding: 14px 28px; /* Tailwind: px-7 py-3.5 */
  font-weight: 600; /* Tailwind: font-semibold */
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1); /* Tailwind: shadow-md */
}
.btn-secondary {
  font-size: 0.875rem; /* Tailwind: text-sm */
  background: transparent; /* Tailwind: bg-transparent */
  border: 1px solid currentColor; /* Tailwind: border */
}
```

### Progress Indicators
```css
/* Step indicator styling */
.step-indicator {
  display: flex;
  gap: 0.5rem; /* Tailwind: flex gap-2 */
}
.step-indicator .step {
  width: 2rem;
  height: 2rem;
  border-radius: 9999px; /* Tailwind: w-8 h-8 rounded-full */
  display: flex;
  align-items: center;
  justify-content: center;
}
.step-indicator .step.active {
  background-color: var(--primary); /* Tailwind: bg-primary */
  color: white;
}
.step-indicator .step.completed {
  background-color: var(--success); /* Tailwind: bg-green-500 */
}
```
