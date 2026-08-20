# Pass 3: Component Quality

Evaluates the structural integrity, API consistency, reusability, and interactive behavior of UI components. Well-built components have typed props, consistent APIs, clean separation of concerns, full keyboard support, and predictable styling across instances.

---

## Tier 0: Code Analysis

Perform these checks using Read, Grep, and Glob only (no browser required).

### 0-1. Component file inventory
List all component files by framework.

```
glob: "*.{tsx,jsx}"             # React
glob: "*.vue"                    # Vue SFC
glob: "*.svelte"                 # Svelte
glob: "*.component.{ts,js}"     # Angular
```

Count total component files and categorize by directory (components/, pages/, layouts/, features/, etc.).

### 0-2. TypeScript interface/type coverage
Check whether components have typed prop interfaces.

```
pattern: interface\s+\w+Props|type\s+\w+Props\s*=
glob: "*.{tsx,ts}"
```

Count components WITH prop types vs components WITHOUT. Report the ratio as **type coverage**.

For untyped components, check for PropTypes usage:
```
pattern: \.propTypes\s*=|PropTypes\.\w+
glob: "*.{jsx,js}"
```

### 0-3. Prop API consistency audit
Check for inconsistent boolean prop naming patterns.

```
# Positive boolean patterns
pattern: is[A-Z]\w+|has[A-Z]\w+|can[A-Z]\w+|should[A-Z]\w+|with[A-Z]\w+
glob: "*.{tsx,jsx,vue,svelte}"

# Negative/bare boolean patterns
pattern: disabled|active|open|visible|loading|selected|checked|expanded|collapsed|readonly|required
glob: "*.{tsx,jsx,vue,svelte}"
```

Flag if BOTH `isDisabled` and `disabled` patterns exist (inconsistent naming). Same for `isActive`/`active`, `isOpen`/`open`, etc.

### 0-4. Default values on optional props
Check for destructured props with default values.

```
pattern: \{\s*[\w]+\s*=\s*[\w"'`\[\{]
glob: "*.{tsx,jsx}"
```

Compare against total optional props. Props without defaults that are accessed without null checks are potential runtime errors.

### 0-5. Component complexity check
Find large components (>200 lines).

```bash
# Count lines per component file
wc -l *.tsx *.jsx *.vue *.svelte
```

Components >200 lines: complexity warning.
Components >400 lines: should be split.
Components >600 lines: critical, almost certainly a god component.

### 0-6. Separation of concerns
Check if components mix data fetching with presentation.

```
# Data fetching in components
pattern: fetch\(|axios\.|useSWR|useQuery|getServerSideProps|getStaticProps|\$fetch|useFetch
glob: "*.{tsx,jsx,vue,svelte}"
```

Components that contain BOTH data fetching and significant JSX/template markup are violating separation of concerns.

### 0-7. className/style prop extensibility
Check if components accept className or style props for external customization.

```
pattern: className\??\s*:\s*string|class\??\s*:\s*string|style\??\s*:
glob: "*.{tsx,ts}"
```

Components that don't accept `className` or equivalent are harder to customize and compose.

### 0-8. Naming convention consistency
Check file naming patterns.

```
# PascalCase (React convention)
glob: "**/[A-Z]*.{tsx,jsx}"

# kebab-case
glob: "**/[a-z]*-[a-z]*.{tsx,jsx}"

# Suffixed patterns
glob: "*.component.{tsx,jsx,ts,js}"
glob: "*.Container.{tsx,jsx}"
glob: "*.view.{tsx,jsx}"
```

Flag if multiple naming conventions coexist. Consistent naming reduces cognitive overhead.

---

## Tier 1: Automated Browser Checks

### 3.1 auditInteractiveElements

```javascript
(() => {
  const result = {
    scriptId: 'auditInteractiveElements',
    timestamp: new Date().toISOString(),
    buttons: { total: 0, issues: [] },
    links: { total: 0, issues: [] },
    inputs: { total: 0, issues: [] },
    selects: { total: 0, issues: [] },
    touchTargetViolations: [],
    focusStyleMissing: [],
    cursorIssues: [],
    transitionMissing: [],
    totalIssues: 0
  };

  const MAX_ISSUES = 25;
  const MIN_TOUCH_TARGET = 44;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    const text = el.textContent?.trim().substring(0, 30) || '';
    const base = classes ? `${tag}.${classes}` : tag;
    return text ? `${base} ("${text}")` : base;
  };

  const checkTouchTarget = (el) => {
    const rect = el.getBoundingClientRect();
    if (rect.width < MIN_TOUCH_TARGET || rect.height < MIN_TOUCH_TARGET) {
      return {
        width: Math.round(rect.width),
        height: Math.round(rect.height),
        minRequired: MIN_TOUCH_TARGET,
        shortfall: {
          width: Math.max(0, MIN_TOUCH_TARGET - Math.round(rect.width)),
          height: Math.max(0, MIN_TOUCH_TARGET - Math.round(rect.height))
        }
      };
    }
    return null;
  };

  const checkFocusStyle = (el) => {
    const normal = getComputedStyle(el);
    const normalOutline = normal.outline;
    const normalBoxShadow = normal.boxShadow;
    const normalBorderColor = normal.borderColor;

    el.focus();
    const focused = getComputedStyle(el);
    const focusedOutline = focused.outline;
    const focusedBoxShadow = focused.boxShadow;
    const focusedBorderColor = focused.borderColor;
    el.blur();

    const outlineChanged = normalOutline !== focusedOutline;
    const shadowChanged = normalBoxShadow !== focusedBoxShadow;
    const borderChanged = normalBorderColor !== focusedBorderColor;

    const hasNoOutline = focusedOutline === 'none' || focusedOutline.includes('0px');
    const hasNoShadow = focusedBoxShadow === 'none';

    return !(outlineChanged || shadowChanged || borderChanged) && hasNoOutline;
  };

  const checkCursor = (el) => {
    const style = getComputedStyle(el);
    const tag = el.tagName.toLowerCase();
    const isClickable = tag === 'button' || tag === 'a' ||
      el.getAttribute('role') === 'button' ||
      el.getAttribute('tabindex') !== null ||
      el.onclick !== null;

    if (isClickable && style.cursor !== 'pointer' && tag !== 'input' && tag !== 'select' && tag !== 'textarea') {
      return { current: style.cursor, expected: 'pointer' };
    }
    return null;
  };

  const checkTransition = (el) => {
    const style = getComputedStyle(el);
    const hasTransition = style.transition && style.transition !== 'all 0s ease 0s' && style.transition !== 'none';
    return !hasTransition;
  };

  const auditElement = (el, category) => {
    const selector = getSelector(el);
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return;

    category.total++;
    const issues = [];

    const touchIssue = checkTouchTarget(el);
    if (touchIssue && result.touchTargetViolations.length < MAX_ISSUES) {
      result.touchTargetViolations.push({ element: selector, ...touchIssue });
      issues.push('touch-target');
    }

    try {
      const focusMissing = checkFocusStyle(el);
      if (focusMissing && result.focusStyleMissing.length < MAX_ISSUES) {
        result.focusStyleMissing.push({ element: selector });
        issues.push('focus-style');
      }
    } catch (e) {}

    const cursorIssue = checkCursor(el);
    if (cursorIssue && result.cursorIssues.length < MAX_ISSUES) {
      result.cursorIssues.push({ element: selector, ...cursorIssue });
      issues.push('cursor');
    }

    if (checkTransition(el) && result.transitionMissing.length < MAX_ISSUES) {
      result.transitionMissing.push({ element: selector });
      issues.push('transition');
    }

    if (issues.length > 0 && category.issues.length < MAX_ISSUES) {
      category.issues.push({ element: selector, issues });
    }

    result.totalIssues += issues.length;
  };

  document.querySelectorAll('button, [role="button"], input[type="button"], input[type="submit"]').forEach(el => auditElement(el, result.buttons));
  document.querySelectorAll('a[href]').forEach(el => auditElement(el, result.links));
  document.querySelectorAll('input:not([type="button"]):not([type="submit"]):not([type="hidden"]), textarea').forEach(el => auditElement(el, result.inputs));
  document.querySelectorAll('select').forEach(el => auditElement(el, result.selects));

  result.summary = {
    totalInteractiveElements: result.buttons.total + result.links.total + result.inputs.total + result.selects.total,
    buttons: result.buttons.total,
    links: result.links.total,
    inputs: result.inputs.total,
    selects: result.selects.total,
    touchTargetViolations: result.touchTargetViolations.length,
    focusStyleMissing: result.focusStyleMissing.length,
    cursorIssues: result.cursorIssues.length,
    transitionMissing: result.transitionMissing.length,
    totalIssues: result.totalIssues
  };

  return result;
})()
```

### 3.2 checkComponentConsistency

```javascript
(() => {
  const result = {
    scriptId: 'checkComponentConsistency',
    timestamp: new Date().toISOString(),
    componentTypes: [],
    inconsistencies: [],
    totalComponentsAudited: 0,
    consistencyScore: 0
  };

  const MAX_INSTANCES = 20;

  const componentGroups = [
    {
      name: 'buttons',
      selector: 'button, [role="button"], .btn, [class*="button"], [class*="Button"], input[type="button"], input[type="submit"]',
      props: ['font-size', 'font-weight', 'font-family', 'border-radius', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left', 'line-height', 'letter-spacing', 'text-transform', 'cursor']
    },
    {
      name: 'cards',
      selector: '[class*="card"], [class*="Card"], .card, article.card',
      props: ['border-radius', 'box-shadow', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left', 'border-width', 'border-style', 'background-color']
    },
    {
      name: 'inputs',
      selector: 'input[type="text"], input[type="email"], input[type="password"], input[type="search"], input[type="tel"], input[type="url"], input[type="number"], textarea',
      props: ['font-size', 'font-family', 'border-radius', 'border-width', 'border-color', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left', 'height', 'line-height', 'background-color']
    },
    {
      name: 'badges',
      selector: '[class*="badge"], [class*="Badge"], [class*="tag"], [class*="Tag"], [class*="chip"], [class*="Chip"]',
      props: ['font-size', 'font-weight', 'border-radius', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left', 'line-height', 'text-transform']
    },
    {
      name: 'headings',
      selector: 'h1, h2, h3, h4, h5, h6',
      props: ['font-family', 'font-weight', 'line-height', 'letter-spacing', 'color']
    }
  ];

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  let totalConsistent = 0;
  let totalChecked = 0;

  for (const group of componentGroups) {
    const elements = Array.from(document.querySelectorAll(group.selector))
      .filter(el => {
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      })
      .slice(0, MAX_INSTANCES);

    if (elements.length < 2) continue;

    const instances = elements.map(el => {
      const styles = getComputedStyle(el);
      const values = {};
      for (const prop of group.props) {
        values[prop] = styles.getPropertyValue(prop).trim();
      }
      return { selector: getSelector(el), values };
    });

    const propDeviations = {};
    for (const prop of group.props) {
      const uniqueValues = new Map();
      for (const inst of instances) {
        const val = inst.values[prop];
        if (!uniqueValues.has(val)) uniqueValues.set(val, []);
        uniqueValues.get(val).push(inst.selector);
      }

      const deviation = uniqueValues.size;
      totalChecked++;
      if (deviation === 1) totalConsistent++;

      if (deviation > 1) {
        propDeviations[prop] = {
          uniqueValues: deviation,
          values: Array.from(uniqueValues.entries()).map(([value, selectors]) => ({
            value,
            count: selectors.length,
            elements: selectors.slice(0, 3)
          }))
        };
      }
    }

    const deviationCount = Object.keys(propDeviations).length;
    result.totalComponentsAudited += elements.length;

    const typeResult = {
      name: group.name,
      instanceCount: elements.length,
      consistentProps: group.props.length - deviationCount,
      deviatingProps: deviationCount,
      totalProps: group.props.length,
      consistencyRate: Math.round(((group.props.length - deviationCount) / group.props.length) * 100) + '%'
    };

    result.componentTypes.push(typeResult);

    if (deviationCount > 0) {
      result.inconsistencies.push({
        componentType: group.name,
        deviations: propDeviations
      });
    }
  }

  result.consistencyScore = totalChecked > 0
    ? Math.round((totalConsistent / totalChecked) * 100)
    : 0;

  result.summary = {
    componentTypesAudited: result.componentTypes.length,
    totalInstancesAudited: result.totalComponentsAudited,
    overallConsistencyScore: result.consistencyScore + '%',
    typesWithInconsistencies: result.inconsistencies.length,
    componentBreakdown: result.componentTypes.map(t => `${t.name}: ${t.instanceCount} instances, ${t.consistencyRate} consistent`)
  };

  return result;
})()
```

### 3.3 measureComponentReuse

```javascript
(() => {
  const result = {
    scriptId: 'measureComponentReuse',
    timestamp: new Date().toISOString(),
    componentPatterns: [],
    oneOffComponents: [],
    highReuseComponents: [],
    reuseScore: 0,
    totalUniquePatterns: 0,
    totalInstances: 0
  };

  const patternMap = new Map();

  const allElements = document.querySelectorAll('body *');
  for (const el of allElements) {
    const classes = Array.from(el.classList);
    if (classes.length === 0) continue;

    for (const cls of classes) {
      if (cls.length < 3) continue;
      if (/^(flex|grid|block|inline|hidden|p-|m-|w-|h-|text-|bg-|border-|rounded-|shadow-|opacity-|z-|gap-|space-|overflow-|cursor-|transition-|duration-|sr-|not-|absolute|relative|fixed|sticky)/.test(cls)) continue;

      if (!patternMap.has(cls)) patternMap.set(cls, 0);
      patternMap.set(cls, patternMap.get(cls) + 1);
    }

    const testId = el.getAttribute('data-testid') || el.getAttribute('data-cy') || el.getAttribute('data-test');
    if (testId) {
      const key = `[data-testid="${testId}"]`;
      if (!patternMap.has(key)) patternMap.set(key, 0);
      patternMap.set(key, patternMap.get(key) + 1);
    }

    const role = el.getAttribute('role');
    if (role && !['presentation', 'none', 'generic'].includes(role)) {
      const key = `[role="${role}"]`;
      if (!patternMap.has(key)) patternMap.set(key, 0);
      patternMap.set(key, patternMap.get(key) + 1);
    }
  }

  const sorted = Array.from(patternMap.entries())
    .filter(([_, count]) => count >= 1)
    .sort((a, b) => b[1] - a[1]);

  result.totalUniquePatterns = sorted.length;
  result.totalInstances = sorted.reduce((sum, [_, count]) => sum + count, 0);

  for (const [pattern, count] of sorted.slice(0, 50)) {
    const entry = { pattern, instances: count };
    result.componentPatterns.push(entry);

    if (count === 1) {
      result.oneOffComponents.push(entry);
    } else if (count >= 5) {
      result.highReuseComponents.push(entry);
    }
  }

  result.oneOffComponents = result.oneOffComponents.slice(0, 20);
  result.highReuseComponents = result.highReuseComponents.slice(0, 20);

  const reusedCount = sorted.filter(([_, count]) => count > 1).length;
  result.reuseScore = result.totalUniquePatterns > 0
    ? Math.round((reusedCount / result.totalUniquePatterns) * 100)
    : 0;

  result.summary = {
    totalUniquePatterns: result.totalUniquePatterns,
    patternsUsedOnce: result.oneOffComponents.length,
    patternsUsed5Plus: result.highReuseComponents.length,
    reuseScore: result.reuseScore + '%',
    topReusedPatterns: result.highReuseComponents.slice(0, 10).map(c => `${c.pattern} (${c.instances}x)`)
  };

  return result;
})()
```

### 3.4 checkKeyboardNavigation

```javascript
(() => {
  const result = {
    scriptId: 'checkKeyboardNavigation',
    timestamp: new Date().toISOString(),
    focusableElements: [],
    tabOrderIssues: [],
    unreachableElements: [],
    focusTrapRisks: [],
    totalFocusable: 0,
    totalUnreachable: 0,
    tabIndexMisuse: []
  };

  const MAX_SAMPLES = 30;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    const text = (el.textContent || el.getAttribute('aria-label') || '').trim().substring(0, 25);
    const base = classes ? `${tag}.${classes}` : tag;
    return text ? `${base} ("${text}")` : base;
  };

  const naturallyFocusable = 'a[href], button, input:not([type="hidden"]), select, textarea, [contenteditable="true"]';
  const allNatural = document.querySelectorAll(naturallyFocusable);
  const allTabIndexed = document.querySelectorAll('[tabindex]');

  const allFocusable = new Set();
  allNatural.forEach(el => allFocusable.add(el));
  allTabIndexed.forEach(el => {
    const idx = parseInt(el.getAttribute('tabindex'));
    if (idx >= 0) allFocusable.add(el);
  });

  const interactiveButNotFocusable = document.querySelectorAll(
    '[onclick], [role="button"], [role="link"], [role="tab"], [role="menuitem"], [role="checkbox"], [role="radio"], [role="switch"], [role="slider"], [role="combobox"]'
  );

  for (const el of interactiveButNotFocusable) {
    if (!allFocusable.has(el)) {
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        const style = getComputedStyle(el);
        if (style.display !== 'none' && style.visibility !== 'hidden') {
          result.unreachableElements.push({
            element: getSelector(el),
            role: el.getAttribute('role') || 'none',
            hasOnclick: !!el.onclick || el.hasAttribute('onclick'),
            tabindex: el.getAttribute('tabindex'),
            suggestion: 'Add tabindex="0" or use a native interactive element'
          });
        }
      }
    }
  }
  result.totalUnreachable = result.unreachableElements.length;
  result.unreachableElements = result.unreachableElements.slice(0, MAX_SAMPLES);

  for (const el of allTabIndexed) {
    const idx = parseInt(el.getAttribute('tabindex'));
    if (idx > 0 && result.tabIndexMisuse.length < MAX_SAMPLES) {
      result.tabIndexMisuse.push({
        element: getSelector(el),
        tabindex: idx,
        issue: 'Positive tabindex disrupts natural tab order. Use tabindex="0" instead.'
      });
    }
  }

  const focusableArray = Array.from(allFocusable).filter(el => {
    const rect = el.getBoundingClientRect();
    const style = getComputedStyle(el);
    return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
  });

  result.totalFocusable = focusableArray.length;

  let prevRect = null;
  let prevEl = null;
  for (let i = 0; i < Math.min(focusableArray.length, 100); i++) {
    const el = focusableArray[i];
    const rect = el.getBoundingClientRect();

    if (prevRect && prevEl) {
      const goesBackward = rect.top < prevRect.top - 50;
      const jumpsRight = rect.left > prevRect.left + 500 && rect.top === prevRect.top;

      if (goesBackward && result.tabOrderIssues.length < MAX_SAMPLES) {
        result.tabOrderIssues.push({
          from: getSelector(prevEl),
          to: getSelector(el),
          issue: 'Tab order jumps backward on page',
          fromPosition: { top: Math.round(prevRect.top), left: Math.round(prevRect.left) },
          toPosition: { top: Math.round(rect.top), left: Math.round(rect.left) }
        });
      }
    }

    result.focusableElements.push({
      index: i,
      element: getSelector(el),
      tag: el.tagName.toLowerCase(),
      tabindex: el.getAttribute('tabindex'),
      position: { top: Math.round(rect.top), left: Math.round(rect.left) }
    });

    prevRect = rect;
    prevEl = el;
  }

  result.focusableElements = result.focusableElements.slice(0, 30);

  const modals = document.querySelectorAll('[role="dialog"], [aria-modal="true"], .modal, [class*="modal"], [class*="Modal"]');
  for (const modal of modals) {
    const style = getComputedStyle(modal);
    if (style.display === 'none' || style.visibility === 'hidden') continue;

    const focusableInModal = modal.querySelectorAll(naturallyFocusable + ', [tabindex="0"]');
    if (focusableInModal.length > 0 && result.focusTrapRisks.length < 5) {
      const hasAriaModal = modal.getAttribute('aria-modal') === 'true';
      result.focusTrapRisks.push({
        element: getSelector(modal),
        focusableChildren: focusableInModal.length,
        hasAriaModal,
        issue: hasAriaModal ? 'Modal detected with aria-modal - verify focus trap is implemented' : 'Visible modal without aria-modal="true" - focus may escape'
      });
    }
  }

  result.summary = {
    totalFocusableElements: result.totalFocusable,
    unreachableInteractive: result.totalUnreachable,
    tabOrderIssues: result.tabOrderIssues.length,
    positiveTabindexMisuse: result.tabIndexMisuse.length,
    focusTrapRisks: result.focusTrapRisks.length,
    overallHealth: result.totalUnreachable === 0 && result.tabIndexMisuse.length === 0 && result.tabOrderIssues.length === 0
      ? 'GOOD' : result.totalUnreachable > 5 ? 'POOR' : 'NEEDS_ATTENTION'
  };

  return result;
})()
```

### 3.5 auditComponentAPISurface

```javascript
(() => {
  const result = {
    scriptId: 'auditComponentAPISurface',
    timestamp: new Date().toISOString(),
    dataAttributes: [],
    ariaAttributes: [],
    customAttributePatterns: [],
    eventHandlerPatterns: [],
    extensibilityScore: 0
  };

  const MAX_SAMPLES = 20;
  const dataAttrMap = new Map();
  const ariaAttrMap = new Map();
  const customAttrMap = new Map();

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 2).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const allElements = document.querySelectorAll('body *');

  for (const el of allElements) {
    for (const attr of el.attributes) {
      if (attr.name.startsWith('data-')) {
        const key = attr.name;
        if (!dataAttrMap.has(key)) dataAttrMap.set(key, { count: 0, sampleValues: [], sampleElements: [] });
        const entry = dataAttrMap.get(key);
        entry.count++;
        if (entry.sampleValues.length < 3 && attr.value) entry.sampleValues.push(attr.value.substring(0, 50));
        if (entry.sampleElements.length < 3) entry.sampleElements.push(getSelector(el));
      }

      if (attr.name.startsWith('aria-') || attr.name === 'role') {
        const key = attr.name;
        if (!ariaAttrMap.has(key)) ariaAttrMap.set(key, { count: 0, sampleValues: [] });
        const entry = ariaAttrMap.get(key);
        entry.count++;
        if (entry.sampleValues.length < 3 && attr.value) entry.sampleValues.push(attr.value.substring(0, 50));
      }
    }
  }

  dataAttrMap.forEach((data, key) => {
    result.dataAttributes.push({
      attribute: key,
      occurrences: data.count,
      sampleValues: data.sampleValues,
      sampleElements: data.sampleElements
    });
  });
  result.dataAttributes.sort((a, b) => b.occurrences - a.occurrences);
  result.dataAttributes = result.dataAttributes.slice(0, MAX_SAMPLES);

  ariaAttrMap.forEach((data, key) => {
    result.ariaAttributes.push({
      attribute: key,
      occurrences: data.count,
      sampleValues: data.sampleValues
    });
  });
  result.ariaAttributes.sort((a, b) => b.occurrences - a.occurrences);
  result.ariaAttributes = result.ariaAttributes.slice(0, MAX_SAMPLES);

  const classNameAccepting = document.querySelectorAll('[class]:not(html):not(head):not(body)').length;
  const totalVisible = document.querySelectorAll('body *').length;
  const classNameRate = totalVisible > 0 ? Math.round((classNameAccepting / totalVisible) * 100) : 0;

  const hasTestIds = result.dataAttributes.some(a => ['data-testid', 'data-test', 'data-cy'].includes(a.attribute));
  const hasRoles = result.ariaAttributes.some(a => a.attribute === 'role');
  const hasAriaLabels = result.ariaAttributes.some(a => a.attribute === 'aria-label' || a.attribute === 'aria-labelledby');

  let score = 0;
  if (classNameRate > 80) score += 2;
  else if (classNameRate > 50) score += 1;
  if (hasTestIds) score += 1;
  if (hasRoles) score += 1;
  if (hasAriaLabels) score += 1;
  result.extensibilityScore = score;

  result.summary = {
    uniqueDataAttributes: dataAttrMap.size,
    uniqueAriaAttributes: ariaAttrMap.size,
    elementsWithClasses: classNameAccepting,
    totalVisibleElements: totalVisible,
    classNameCoverage: classNameRate + '%',
    hasTestIds,
    hasAriaRoles: hasRoles,
    hasAriaLabels,
    extensibilityScore: result.extensibilityScore + '/5'
  };

  return result;
})()
```

---

## Tier 2: AI Evaluation

After collecting Tier 0 and Tier 1 data, examine screenshots and DOM snapshots to answer these questions:

1. **Do components follow a consistent API pattern?** Are boolean props named consistently (isOpen vs open)? Do similar components accept similar props? Or is every component a unique snowflake?

2. **Is there a clear separation between container and presentational components?** Can you identify components that only fetch/manage data vs components that only render UI? Or are data fetching, state management, and rendering all tangled together?

3. **Are components appropriately sized?** Are there god components doing too much, or micro-components that are unnecessarily fragmented? Does each component have a clear, single responsibility?

4. **Do similar components share a consistent visual language?** Do all buttons look like buttons? Do all cards have the same border-radius, shadow, and padding? Or do instances of the same component type vary in appearance?

5. **Are component boundaries logical from a UX perspective?** Do the component breaks align with how users think about the interface? Or are components split in ways that make the UX feel disjointed?

6. **Would it be easy to create a variant of an existing component?** If you needed a "compact" version of a card or a "danger" variant of a button, is the component structured to support that without duplicating code?

---

## Scoring Criteria

| Score | Types | API Consistency | Keyboard/Focus | Separation | Visual Consistency |
|-------|-------|----------------|----------------|------------|-------------------|
| **5** | Full TypeScript interfaces on all components | Uniform prop naming, default values | All interactive elements focusable, no tab order issues | Clean container/presentational split | All instances of same type match visually |
| **4** | 80%+ typed, minor gaps | Mostly consistent with 1-2 deviations | Minor focus style gaps, no unreachable elements | Mostly separated, rare mixing | Consistent with minor deviations |
| **3** | 50-79% typed | Some naming inconsistencies | Several missing focus styles, a few unreachable | Mixed — some components do both | Noticeable inconsistencies |
| **2** | <50% typed, some PropTypes | Inconsistent across components | Many missing focus styles, unreachable elements | Most components mix concerns | Significant visual variation |
| **1** | No type definitions | No discernible pattern | Keyboard navigation broken, elements unreachable | No separation at all | Every instance looks different |

---

## Common Fixes

### Add missing TypeScript interfaces
```tsx
/* Before */
function Card({ title, description, onClick }) {
  return <div onClick={onClick}>...</div>;
}

/* After */
interface CardProps {
  title: string;
  description: string;
  onClick?: () => void;
  className?: string;
}

function Card({ title, description, onClick, className }: CardProps) {
  return <div className={className} onClick={onClick}>...</div>;
}
```

### Standardize prop naming conventions
```tsx
/* Before: inconsistent boolean naming */
<Modal isOpen={true} />
<Dropdown open={true} />
<Sidebar visible={true} />

/* After: pick one pattern and stick with it */
<Modal isOpen={true} />
<Dropdown isOpen={true} />
<Sidebar isOpen={true} />
```

### Add focus styles to interactive elements
```css
/* Before: focus removed */
button:focus { outline: none; }

/* After: visible focus-visible style */
button:focus-visible {
  outline: 2px solid var(--color-focus-ring);
  outline-offset: 2px;
}
```

### Add cursor:pointer to clickable elements
```css
/* Before: no cursor change on custom buttons */
[role="button"] { /* no cursor */ }

/* After */
[role="button"] { cursor: pointer; }
button, a, [role="button"], [role="link"] { cursor: pointer; }
```

### Add touch target sizing
```css
/* Before: tiny icon button */
.icon-button { width: 24px; height: 24px; }

/* After: meets 44x44px minimum */
.icon-button {
  width: 24px;
  height: 24px;
  min-width: 44px;
  min-height: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
```

### Add className prop for extensibility
```tsx
/* Before: closed component */
function Badge({ label }: { label: string }) {
  return <span className="badge">{label}</span>;
}

/* After: extensible with className merging */
function Badge({ label, className }: { label: string; className?: string }) {
  return <span className={cn('badge', className)}>{label}</span>;
}
```
