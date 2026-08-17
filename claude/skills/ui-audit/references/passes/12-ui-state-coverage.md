# Pass 12: UI State Coverage

Evaluates whether interactive components implement all expected visual states — default, hover, focus, active, disabled, loading, error, empty, and success. Missing states degrade usability by removing feedback, confusing users about what is interactive, and leaving no guidance when things go wrong or data is absent.

---

## Tier 0: Code Analysis

Perform these checks using Read, Grep, and Glob only (no browser required).

### 0-1. Hover state implementations

```
pattern: onMouseEnter|onMouseLeave|:hover|hover:|hover\s*\{
glob: "*.{tsx,jsx,vue,svelte,css,scss,less}"
```

### 0-2. Focus state implementations

```
pattern: onFocus|onBlur|:focus-visible|:focus-within|:focus(?!-)|focus:|focus-visible:|ring-
glob: "*.{tsx,jsx,vue,svelte,css,scss,less}"
```

### 0-3. Active state implementations

```
pattern: :active|active:|onMouseDown|onPointerDown
glob: "*.{tsx,jsx,vue,svelte,css,scss,less}"
```

### 0-4. Disabled state implementations

```
pattern: disabled|isDisabled|:disabled|aria-disabled|disabled:|opacity-50|cursor-not-allowed
glob: "*.{tsx,jsx,vue,svelte,css,scss,less}"
```

### 0-5. Loading state implementations

```
pattern: isLoading|loading|Spinner|Loader|skeleton|Skeleton|aria-busy|role="progressbar"|animate-spin|animate-pulse
glob: "*.{tsx,jsx,vue,svelte,css,scss,less}"
```

### 0-6. Error state implementations

```
pattern: isError|error|Error|invalid|:invalid|aria-invalid|aria-errormessage|border-red|text-red|destructive
glob: "*.{tsx,jsx,vue,svelte,css,scss,less}"
```

### 0-7. Empty state implementations

```
pattern: isEmpty|empty|no.?data|no.?results|no.?items|nothing.?(here|found|to)|EmptyState|emptyState
glob: "*.{tsx,jsx,vue,svelte}"
```

### 0-8. Success state implementations

```
pattern: isSuccess|success|Success|toast|Toast|Notification|check-circle|CheckCircle|confirmed|confirmation
glob: "*.{tsx,jsx,vue,svelte}"
```

### 0-9. State coverage per component

For each interactive component file (buttons, inputs, forms, cards with onClick, links, toggles, dropdowns), count how many of these state categories are implemented:

1. Default (always present)
2. Hover
3. Focus
4. Active
5. Disabled
6. Loading
7. Error
8. Empty (for data-displaying components)
9. Success (for action components)

Calculate:

```
coverage = implemented_states / expected_states * 100
```

Where `expected_states` depends on component type:
- **Buttons**: default, hover, focus, active, disabled, loading (6 expected)
- **Inputs**: default, hover, focus, disabled, error (5 expected)
- **Forms**: default, loading, error, success (4 expected)
- **Lists/Tables**: default, loading, empty, error (4 expected)
- **Cards with actions**: default, hover, focus (3 expected)

### 0-10. Flag components missing critical states

Any interactive element (button, link, input, select, textarea, checkbox, radio) must have at minimum:
- **Hover** — visual feedback on pointer
- **Focus** — visible indicator for keyboard navigation
- **Disabled** — clear "unavailable" presentation

Flag components missing any of these three as critical failures.

---

## Tier 1: Automated Browser Checks

### Script 1 — auditHoverStates

```javascript
(() => {
  const results = {
    totalInteractive: 0,
    withHoverChange: 0,
    withoutHoverChange: 0,
    hoverless: [],
    hoverDetails: [],
    recommendations: []
  };

  const interactiveSelectors = [
    'button', '[role="button"]', 'a[href]',
    'input:not([type="hidden"])', 'textarea', 'select',
    '[onclick]', '[tabindex="0"]',
    '[class*="card"][class*="click"], [class*="clickable"]'
  ];

  const interactiveEls = [];
  interactiveSelectors.forEach(sel => {
    try {
      document.querySelectorAll(sel).forEach(el => {
        const rect = el.getBoundingClientRect();
        if (rect.width > 0 && rect.height > 0) {
          interactiveEls.push(el);
        }
      });
    } catch (e) {}
  });

  const uniqueEls = [...new Set(interactiveEls)];
  results.totalInteractive = uniqueEls.length;

  const selectorFor = (el) => {
    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
      : '';
    const text = (el.textContent || '').trim().slice(0, 25);
    return { selector: `${tag}${id}${cls}`, text };
  };

  const propsToCheck = [
    'backgroundColor', 'color', 'borderColor', 'boxShadow',
    'transform', 'opacity', 'textDecoration', 'outline'
  ];

  const getStyleSnapshot = (el) => {
    const computed = getComputedStyle(el);
    const snapshot = {};
    propsToCheck.forEach(prop => {
      snapshot[prop] = computed[prop];
    });
    return snapshot;
  };

  uniqueEls.slice(0, 100).forEach(el => {
    const before = getStyleSnapshot(el);

    el.dispatchEvent(new MouseEvent('mouseenter', { bubbles: true }));
    el.dispatchEvent(new MouseEvent('mouseover', { bubbles: true }));
    el.matches(':hover');

    const after = getStyleSnapshot(el);

    el.dispatchEvent(new MouseEvent('mouseleave', { bubbles: true }));
    el.dispatchEvent(new MouseEvent('mouseout', { bubbles: true }));

    const changes = {};
    let hasChange = false;
    propsToCheck.forEach(prop => {
      if (before[prop] !== after[prop]) {
        changes[prop] = { from: before[prop], to: after[prop] };
        hasChange = true;
      }
    });

    if (hasChange) {
      results.withHoverChange++;
      if (results.hoverDetails.length < 15) {
        const info = selectorFor(el);
        results.hoverDetails.push({
          ...info,
          changes: Object.keys(changes)
        });
      }
    } else {
      results.withoutHoverChange++;
      if (results.hoverless.length < 20) {
        results.hoverless.push(selectorFor(el));
      }
    }
  });

  const checked = Math.min(uniqueEls.length, 100);
  if (results.withoutHoverChange > checked * 0.3 && checked > 5) {
    results.recommendations.push(
      `${results.withoutHoverChange}/${checked} interactive elements show no visual change on hover — add hover states for user feedback`
    );
  }

  return results;
})();
```

### Script 2 — auditFocusStates

```javascript
(() => {
  const results = {
    totalFocusable: 0,
    withVisibleFocus: 0,
    withoutVisibleFocus: 0,
    focusDetails: [],
    noFocusSamples: [],
    recommendations: []
  };

  const focusableEls = document.querySelectorAll(
    'button, [role="button"], a[href], input:not([type="hidden"]), textarea, select, [tabindex="0"], [tabindex="1"], [contenteditable="true"]'
  );

  const visibleEls = [...focusableEls].filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && !el.disabled;
  });

  results.totalFocusable = visibleEls.length;

  const selectorFor = (el) => {
    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
      : '';
    return `${tag}${id}${cls}`;
  };

  const FOCUS_PROPS = ['outline', 'outlineColor', 'outlineWidth', 'outlineStyle',
    'boxShadow', 'borderColor', 'backgroundColor', 'color'];

  visibleEls.slice(0, 80).forEach(el => {
    const beforeStyles = {};
    const computed = getComputedStyle(el);
    FOCUS_PROPS.forEach(prop => {
      beforeStyles[prop] = computed[prop];
    });

    el.focus({ preventScroll: true });

    const afterStyles = {};
    const focusedComputed = getComputedStyle(el);
    FOCUS_PROPS.forEach(prop => {
      afterStyles[prop] = focusedComputed[prop];
    });

    el.blur();

    const changes = {};
    let hasVisibleChange = false;
    FOCUS_PROPS.forEach(prop => {
      if (beforeStyles[prop] !== afterStyles[prop]) {
        changes[prop] = { from: beforeStyles[prop], to: afterStyles[prop] };
        hasVisibleChange = true;
      }
    });

    const hasOutline = afterStyles.outlineStyle !== 'none' &&
      afterStyles.outlineWidth !== '0px' &&
      afterStyles.outline !== 'none';
    const hasShadow = afterStyles.boxShadow !== 'none' &&
      afterStyles.boxShadow !== beforeStyles.boxShadow;
    const hasBorderChange = afterStyles.borderColor !== beforeStyles.borderColor;

    const isVisible = hasVisibleChange || hasOutline || hasShadow || hasBorderChange;

    if (isVisible) {
      results.withVisibleFocus++;
      if (results.focusDetails.length < 15) {
        results.focusDetails.push({
          selector: selectorFor(el),
          indicator: hasOutline ? 'outline' : hasShadow ? 'box-shadow' : hasBorderChange ? 'border' : 'other',
          changes: Object.keys(changes),
          text: (el.textContent || '').trim().slice(0, 25)
        });
      }
    } else {
      results.withoutVisibleFocus++;
      if (results.noFocusSamples.length < 20) {
        results.noFocusSamples.push({
          selector: selectorFor(el),
          tag: el.tagName.toLowerCase(),
          text: (el.textContent || '').trim().slice(0, 25),
          outlineStyle: afterStyles.outlineStyle,
          outlineColor: afterStyles.outlineColor
        });
      }
    }
  });

  const checked = Math.min(visibleEls.length, 80);
  if (results.withoutVisibleFocus > 0) {
    results.recommendations.push(
      `${results.withoutVisibleFocus}/${checked} focusable elements have no visible focus indicator — this fails WCAG 2.4.7 (Focus Visible). Add focus-visible styles.`
    );
  }

  return results;
})();
```

### Script 3 — auditDisabledStates

```javascript
(() => {
  const results = {
    totalDisabled: 0,
    properlyStyled: 0,
    improperlyStyled: 0,
    inTabOrder: 0,
    details: [],
    recommendations: []
  };

  const disabledEls = document.querySelectorAll(
    '[disabled], [aria-disabled="true"], .disabled, [class*="disabled"]'
  );

  const selectorFor = (el) => {
    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
      : '';
    return `${tag}${id}${cls}`;
  };

  disabledEls.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;

    results.totalDisabled++;

    const computed = getComputedStyle(el);
    const opacity = parseFloat(computed.opacity);
    const cursor = computed.cursor;
    const pointerEvents = computed.pointerEvents;
    const tabindex = el.getAttribute('tabindex');
    const hasDisabledAttr = el.hasAttribute('disabled');

    const hasReducedOpacity = opacity < 0.8;
    const hasDisabledCursor = cursor === 'not-allowed' || cursor === 'default';
    const isRemoved = pointerEvents === 'none';

    const isProperlyStyled = hasReducedOpacity || hasDisabledCursor || isRemoved;
    const isInTabOrder = !hasDisabledAttr && tabindex !== '-1' && tabindex !== null;

    if (isProperlyStyled) {
      results.properlyStyled++;
    } else {
      results.improperlyStyled++;
    }

    if (isInTabOrder) {
      results.inTabOrder++;
    }

    if (results.details.length < 20) {
      results.details.push({
        selector: selectorFor(el),
        opacity,
        cursor,
        pointerEvents,
        tabindex: tabindex || (hasDisabledAttr ? 'disabled' : 'none'),
        isProperlyStyled,
        stillFocusable: isInTabOrder,
        text: (el.textContent || '').trim().slice(0, 30)
      });
    }
  });

  if (results.improperlyStyled > 0) {
    results.recommendations.push(
      `${results.improperlyStyled} disabled elements still look interactive — add reduced opacity (0.5-0.7) and cursor: not-allowed`
    );
  }

  if (results.inTabOrder > 0) {
    results.recommendations.push(
      `${results.inTabOrder} disabled elements are still in the tab order — use the disabled attribute (not just aria-disabled) or add tabindex="-1"`
    );
  }

  return results;
})();
```

### Script 4 — auditLoadingStates

```javascript
(() => {
  const results = {
    loadingIndicatorsFound: 0,
    indicatorTypes: {},
    skeletons: [],
    spinners: [],
    progressBars: [],
    ariaLiveRegions: 0,
    ariaBusyElements: 0,
    recommendations: []
  };

  const selectorFor = (el) => {
    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
      : '';
    return `${tag}${id}${cls}`;
  };

  const skeletonEls = document.querySelectorAll(
    '[class*="skeleton"], [class*="Skeleton"], [class*="shimmer"], [class*="placeholder"], .animate-pulse'
  );
  skeletonEls.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    results.loadingIndicatorsFound++;
    results.indicatorTypes['skeleton'] = (results.indicatorTypes['skeleton'] || 0) + 1;
    if (results.skeletons.length < 10) {
      results.skeletons.push({
        selector: selectorFor(el),
        size: `${Math.round(rect.width)}x${Math.round(rect.height)}`
      });
    }
  });

  const spinnerEls = document.querySelectorAll(
    '[class*="spinner"], [class*="Spinner"], [class*="loader"], [class*="Loader"], .animate-spin, [class*="loading"]'
  );
  spinnerEls.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    results.loadingIndicatorsFound++;
    results.indicatorTypes['spinner'] = (results.indicatorTypes['spinner'] || 0) + 1;
    if (results.spinners.length < 10) {
      results.spinners.push({
        selector: selectorFor(el),
        size: `${Math.round(rect.width)}x${Math.round(rect.height)}`
      });
    }
  });

  const progressEls = document.querySelectorAll(
    '[role="progressbar"], progress, [class*="progress"], [class*="Progress"]'
  );
  progressEls.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    results.loadingIndicatorsFound++;
    results.indicatorTypes['progress'] = (results.indicatorTypes['progress'] || 0) + 1;
    if (results.progressBars.length < 10) {
      const value = el.getAttribute('aria-valuenow') || el.value || null;
      results.progressBars.push({
        selector: selectorFor(el),
        value,
        size: `${Math.round(rect.width)}x${Math.round(rect.height)}`
      });
    }
  });

  const liveRegions = document.querySelectorAll('[aria-live]');
  results.ariaLiveRegions = liveRegions.length;

  const busyEls = document.querySelectorAll('[aria-busy="true"]');
  results.ariaBusyElements = busyEls.length;

  const svgSpinners = document.querySelectorAll('svg');
  svgSpinners.forEach(svg => {
    const rect = svg.getBoundingClientRect();
    if (rect.width <= 0 || rect.width > 60) return;
    const computed = getComputedStyle(svg);
    const animation = computed.animation || computed.webkitAnimation || '';
    if (animation.includes('spin') || animation.includes('rotate')) {
      results.loadingIndicatorsFound++;
      results.indicatorTypes['animated-svg'] = (results.indicatorTypes['animated-svg'] || 0) + 1;
    }
  });

  const forms = document.querySelectorAll('form');
  const tables = document.querySelectorAll('table, [role="table"]');
  const lists = document.querySelectorAll('[role="list"], ul, ol');
  const dataAreas = forms.length + tables.length + lists.length;

  if (results.loadingIndicatorsFound === 0 && dataAreas > 0) {
    results.recommendations.push(
      `No loading indicators found on a page with ${dataAreas} data areas (forms, tables, lists) — add skeleton screens or spinners for async content`
    );
  }

  if (results.ariaLiveRegions === 0 && results.loadingIndicatorsFound > 0) {
    results.recommendations.push(
      'Loading indicators exist but no aria-live regions found — screen readers won\'t announce loading state changes. Add aria-live="polite" to loading containers.'
    );
  }

  return results;
})();
```

### Script 5 — auditEmptyStates

```javascript
(() => {
  const results = {
    dataContainers: 0,
    withEmptyState: 0,
    withoutEmptyState: 0,
    emptyContainers: [],
    emptyStateQuality: [],
    recommendations: []
  };

  const selectorFor = (el) => {
    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
      : '';
    return `${tag}${id}${cls}`;
  };

  const dataContainerSelectors = [
    'table', '[role="table"]', '[role="grid"]',
    'ul[role="list"]', 'ol[role="list"]',
    '[class*="list"], [class*="List"]',
    '[class*="grid"], [class*="Grid"]',
    '[class*="feed"], [class*="Feed"]',
    '[class*="results"], [class*="Results"]',
    '[class*="items"], [class*="Items"]',
    '[class*="dashboard"]', '[class*="Dashboard"]'
  ];

  const dataContainers = new Set();
  dataContainerSelectors.forEach(sel => {
    try {
      document.querySelectorAll(sel).forEach(el => {
        const rect = el.getBoundingClientRect();
        if (rect.width > 0 && rect.height > 0) {
          dataContainers.add(el);
        }
      });
    } catch (e) {}
  });

  results.dataContainers = dataContainers.size;

  dataContainers.forEach(container => {
    const contentChildren = [...container.children].filter(c => {
      const r = c.getBoundingClientRect();
      return r.width > 0 && r.height > 0;
    });

    const text = (container.textContent || '').toLowerCase().trim();
    const isEmpty = contentChildren.length <= 1;

    const emptyIndicators = [
      'no results', 'no data', 'no items', 'nothing found',
      'nothing here', 'no records', 'empty', 'nothing to show',
      'nothing to display', 'no entries', 'get started', 'create your first'
    ];

    const hasEmptyMessage = emptyIndicators.some(phrase => text.includes(phrase));
    const hasEmptyComponent = container.querySelector(
      '[class*="empty"], [class*="Empty"], [class*="no-data"], [class*="no-results"], [class*="placeholder"]'
    );

    if (isEmpty || hasEmptyMessage || hasEmptyComponent) {
      if (hasEmptyMessage || hasEmptyComponent) {
        results.withEmptyState++;

        const hasCta = container.querySelector('button, a[href], [role="button"]');
        const hasIllustration = container.querySelector('svg, img, [class*="illustration"], [class*="icon"]');
        const hasGuidance = text.length > 30;

        if (results.emptyStateQuality.length < 10) {
          results.emptyStateQuality.push({
            selector: selectorFor(container),
            hasCta: !!hasCta,
            hasIllustration: !!hasIllustration,
            hasGuidance,
            textPreview: text.slice(0, 80),
            quality: (hasCta ? 1 : 0) + (hasIllustration ? 1 : 0) + (hasGuidance ? 1 : 0)
          });
        }
      } else if (isEmpty) {
        results.withoutEmptyState++;
        if (results.emptyContainers.length < 10) {
          results.emptyContainers.push({
            selector: selectorFor(container),
            childCount: contentChildren.length,
            isBlank: text.length < 10
          });
        }
      }
    }
  });

  if (results.withoutEmptyState > 0) {
    results.recommendations.push(
      `${results.withoutEmptyState} data containers appear empty with no empty state message — add helpful empty state with illustration and CTA`
    );
  }

  const lowQuality = results.emptyStateQuality.filter(e => e.quality < 2);
  if (lowQuality.length > 0) {
    results.recommendations.push(
      `${lowQuality.length} empty states lack a CTA or illustration — enhance with actionable guidance ("Create your first..." button)`
    );
  }

  return results;
})();
```

### Script 6 — calculateStateCoverage

```javascript
(() => {
  const results = {
    componentTypes: {},
    overallCoverage: 0,
    totalComponents: 0,
    totalStatesExpected: 0,
    totalStatesFound: 0,
    criticalMissing: [],
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

  const checkState = (el, state) => {
    const computed = getComputedStyle(el);
    const cls = el.className && typeof el.className === 'string' ? el.className : '';
    const allAttrs = [...el.attributes].map(a => `${a.name}=${a.value}`).join(' ');

    switch (state) {
      case 'hover': {
        const hasHoverClass = cls.includes('hover:') || cls.includes('hover-');
        const hasCursor = computed.cursor === 'pointer';
        return hasHoverClass || hasCursor;
      }
      case 'focus': {
        const hasFocusClass = cls.includes('focus:') || cls.includes('focus-visible:') || cls.includes('ring-');
        const hasTabindex = el.hasAttribute('tabindex');
        return hasFocusClass || hasTabindex || ['button', 'a', 'input', 'textarea', 'select'].includes(el.tagName.toLowerCase());
      }
      case 'disabled': {
        const hasDisabledProp = el.hasAttribute('disabled') || allAttrs.includes('aria-disabled');
        const hasDisabledClass = cls.includes('disabled');
        return hasDisabledProp || hasDisabledClass;
      }
      case 'loading': {
        const parent = el.closest('[class*="loading"], [class*="spinner"], [aria-busy]');
        const hasLoadingClass = cls.includes('loading') || cls.includes('spinner');
        return !!parent || hasLoadingClass;
      }
      case 'error': {
        const hasErrorClass = cls.includes('error') || cls.includes('invalid') || cls.includes('destructive');
        const hasAriaInvalid = allAttrs.includes('aria-invalid');
        return hasErrorClass || hasAriaInvalid;
      }
      default:
        return false;
    }
  };

  const componentSpecs = [
    {
      label: 'Buttons',
      selector: 'button, [role="button"], input[type="submit"]',
      expectedStates: ['hover', 'focus', 'disabled', 'loading']
    },
    {
      label: 'Text Inputs',
      selector: 'input[type="text"], input[type="email"], input[type="password"], input[type="search"], input[type="tel"], input[type="url"], input:not([type]), textarea',
      expectedStates: ['hover', 'focus', 'disabled', 'error']
    },
    {
      label: 'Links',
      selector: 'a[href]',
      expectedStates: ['hover', 'focus']
    },
    {
      label: 'Select/Dropdown',
      selector: 'select, [role="combobox"], [role="listbox"]',
      expectedStates: ['hover', 'focus', 'disabled', 'error']
    },
    {
      label: 'Checkboxes/Radios',
      selector: 'input[type="checkbox"], input[type="radio"], [role="checkbox"], [role="radio"]',
      expectedStates: ['hover', 'focus', 'disabled']
    }
  ];

  componentSpecs.forEach(spec => {
    const els = document.querySelectorAll(spec.selector);
    const visibleEls = [...els].filter(el => {
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    });

    if (visibleEls.length === 0) return;

    const stateResults = {};
    let statesFound = 0;

    spec.expectedStates.forEach(state => {
      const implementing = visibleEls.filter(el => checkState(el, state));
      const pct = Math.round((implementing.length / visibleEls.length) * 100);
      stateResults[state] = {
        implemented: implementing.length,
        total: visibleEls.length,
        percentage: pct
      };
      if (pct > 50) statesFound++;
    });

    const coverage = Math.round((statesFound / spec.expectedStates.length) * 100);

    results.componentTypes[spec.label] = {
      count: visibleEls.length,
      expectedStates: spec.expectedStates,
      stateResults,
      coverage
    };

    results.totalComponents += visibleEls.length;
    results.totalStatesExpected += spec.expectedStates.length;
    results.totalStatesFound += statesFound;

    const missingCritical = spec.expectedStates
      .filter(s => ['hover', 'focus'].includes(s))
      .filter(s => stateResults[s].percentage < 50);

    if (missingCritical.length > 0) {
      results.criticalMissing.push({
        component: spec.label,
        missingStates: missingCritical,
        count: visibleEls.length
      });
    }
  });

  results.overallCoverage = results.totalStatesExpected > 0
    ? Math.round((results.totalStatesFound / results.totalStatesExpected) * 100)
    : 0;

  if (results.criticalMissing.length > 0) {
    results.criticalMissing.forEach(item => {
      results.recommendations.push(
        `${item.component} (${item.count} instances) missing critical states: ${item.missingStates.join(', ')} — these are required for basic usability`
      );
    });
  }

  const lowCoverage = Object.entries(results.componentTypes)
    .filter(([_, data]) => data.coverage < 50)
    .map(([name]) => name);

  if (lowCoverage.length > 0) {
    results.recommendations.push(
      `Low state coverage (<50%) on: ${lowCoverage.join(', ')} — add missing hover, focus, disabled, and error states`
    );
  }

  return results;
})();
```

---

## Tier 2: AI Evaluation

Examine the screenshots, DOM snapshots, and Tier 0/1 results, then answer each question with a rating (good / acceptable / needs-work) and brief justification.

1. **Hover feedback** — Do hover states feel responsive and give clear feedback that an element is interactive? Is the visual change noticeable but not jarring?
2. **Focus visibility** — Are focus indicators visible and accessible without being aesthetically disruptive? Do they meet WCAG 2.4.7 requirements?
3. **Disabled clarity** — Do disabled states clearly communicate "you cannot use this" while remaining readable (not too faded to read)?
4. **Loading informativeness** — Are loading states informative (skeleton screens showing content shape, progress bars showing completion) or just generic spinners?
5. **Empty state guidance** — Do empty states guide the user toward action with a CTA, illustration, and helpful text, or do they just display "nothing here"?
6. **Error specificity** — Are error states specific and helpful ("Email must include @"), or generic ("Something went wrong")?
7. **Success reward** — Is there a visible success state that rewards the user after completing an action (toast, checkmark, confirmation message)?
8. **State consistency** — Is state implementation consistent across all components of the same type (all buttons hover the same way, all inputs show errors the same way)?

---

## Scoring Criteria

| Score | Criteria |
|-------|----------|
| **5** | All interactive components implement all 9 states (default, hover, focus, active, disabled, loading, error, empty, success). Consistent implementation across component types. Accessible focus indicators. Informative loading and empty states with CTAs. |
| **4** | Core states present everywhere (hover, focus, disabled, loading, error). Minor gaps in empty/success states. Consistent implementation with 1-2 outliers. |
| **3** | Most components have hover and focus states but inconsistent loading, empty, and error coverage. Some components missing focus indicators. |
| **2** | Only basic hover states on some elements. No visible focus indicators. Disabled elements still look interactive. No loading or empty states. |
| **1** | No state implementation beyond default appearance. Interactive elements indistinguishable from static content. No feedback for any user action. |

---

## Common Fixes

### Add hover states with Tailwind

```tsx
/* Before — static button */
<button className="bg-blue-500 text-white px-4 py-2 rounded">
  Save
</button>

/* After — hover + active states */
<button className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 active:bg-blue-700 transition-colors">
  Save
</button>
```

### Add focus-visible styles

```css
/* Before — focus removed (bad!) */
button:focus { outline: none; }

/* After — visible focus ring */
button:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}
```

```tsx
/* Tailwind version */
<button className="focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 outline-none">
```

### Add disabled state styling

```tsx
/* Before — disabled but looks normal */
<button disabled>Submit</button>

/* After — clearly disabled */
<button
  disabled
  className="disabled:opacity-50 disabled:cursor-not-allowed disabled:pointer-events-none"
>
  Submit
</button>
```

### Add loading skeleton for data areas

```tsx
/* Before — blank space while loading */
{isLoading ? null : <DataTable data={data} />}

/* After — skeleton shows content shape */
{isLoading ? (
  <div className="space-y-3" aria-busy="true">
    <div className="h-4 bg-gray-200 rounded animate-pulse w-3/4" />
    <div className="h-4 bg-gray-200 rounded animate-pulse w-1/2" />
    <div className="h-4 bg-gray-200 rounded animate-pulse w-5/6" />
  </div>
) : (
  <DataTable data={data} />
)}
```

### Add empty state with CTA

```tsx
/* Before — blank area */
{items.length === 0 && <p>No items</p>}

/* After — actionable empty state */
{items.length === 0 && (
  <div className="flex flex-col items-center justify-center py-12 text-center">
    <InboxIcon className="w-12 h-12 text-gray-400 mb-4" aria-hidden="true" />
    <h3 className="text-lg font-medium text-gray-900">No items yet</h3>
    <p className="mt-1 text-sm text-gray-500">Get started by creating your first item.</p>
    <Button variant="primary" className="mt-4" onClick={onCreateNew}>
      Create Item
    </Button>
  </div>
)}
```

### Add error state to form inputs

```tsx
/* Before — no error indication */
<input type="email" value={email} onChange={setEmail} />

/* After — error state with message */
<div>
  <input
    type="email"
    value={email}
    onChange={setEmail}
    aria-invalid={!!error}
    aria-errormessage={error ? 'email-error' : undefined}
    className={cn(
      'border rounded px-3 py-2',
      error ? 'border-red-500 focus:ring-red-500' : 'border-gray-300 focus:ring-blue-500'
    )}
  />
  {error && (
    <p id="email-error" className="mt-1 text-sm text-red-600" role="alert">
      {error}
    </p>
  )}
</div>
```
