# Pass 5: Micro-Interactions

## Tier 1: Automated Checks

### 5.1 Interactive Elements: Cursor and Pointer States

```javascript
(() => {
  const interactiveSelectors = 'a, button, [role="button"], [role="link"], [role="tab"], [role="menuitem"], [role="checkbox"], [role="radio"], [role="switch"], input[type="submit"], input[type="button"], input[type="reset"], select, [onclick], [tabindex]:not([tabindex="-1"]), label[for], summary, [class*="clickable"], [class*="Clickable"]';
  const elements = document.querySelectorAll(interactiveSelectors);
  const issues = [];
  const measurements = [];

  elements.forEach(el => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const cursor = style.cursor;
    const tag = el.tagName.toLowerCase();
    const role = el.getAttribute('role') || '';
    const isNativeInteractive = ['a', 'button', 'select', 'summary'].includes(tag);
    const hasPointer = cursor === 'pointer';

    const entry = {
      tag,
      role,
      text: (el.textContent || '').trim().substring(0, 40),
      cursor,
      hasPointer,
      width: Math.round(rect.width),
      height: Math.round(rect.height)
    };

    measurements.push(entry);

    if (!hasPointer && !isNativeInteractive && (role || el.getAttribute('onclick') || el.getAttribute('tabindex'))) {
      issues.push({
        type: 'missing-pointer-cursor',
        ...entry,
        message: `Interactive element (${tag}${role ? `[role="${role}"]` : ''}) uses cursor: ${cursor}. Should be cursor: pointer.`
      });
    }

    if (rect.width < 44 || rect.height < 44) {
      const area = rect.width * rect.height;
      if (area < 44 * 44 && tag !== 'a') {
        issues.push({
          type: 'small-touch-target',
          ...entry,
          message: `Interactive element is ${Math.round(rect.width)}x${Math.round(rect.height)}px. Minimum 44x44px for touch targets (WCAG 2.5.5).`
        });
      }
    }
  });

  return {
    totalInteractiveElements: measurements.length,
    missingPointer: issues.filter(i => i.type === 'missing-pointer-cursor').length,
    smallTouchTargets: issues.filter(i => i.type === 'small-touch-target').length,
    measurements: measurements.slice(0, 20),
    issues: issues.slice(0, 20)
  };
})()
```

### 5.2 Hover, Focus, and Active State Detection

```javascript
(() => {
  const interactiveElements = document.querySelectorAll('a, button, [role="button"], input, select, textarea, [tabindex]:not([tabindex="-1"])');
  const issues = [];
  const stateInfo = [];
  let hasTransitions = 0;
  let noTransitions = 0;

  const sheets = [];
  try {
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules || []) {
          const selectorText = rule.selectorText || '';
          if (selectorText.includes(':hover') || selectorText.includes(':focus') || selectorText.includes(':active') || selectorText.includes(':focus-visible')) {
            sheets.push({
              selector: selectorText,
              hasHover: selectorText.includes(':hover'),
              hasFocus: selectorText.includes(':focus'),
              hasFocusVisible: selectorText.includes(':focus-visible'),
              hasActive: selectorText.includes(':active')
            });
          }
        }
      } catch (e) { /* cross-origin */ }
    }
  } catch (e) { /* stylesheet error */ }

  const hoverSelectors = sheets.filter(s => s.hasHover).map(s => s.selector);
  const focusSelectors = sheets.filter(s => s.hasFocus || s.hasFocusVisible).map(s => s.selector);
  const activeSelectors = sheets.filter(s => s.hasActive).map(s => s.selector);

  interactiveElements.forEach(el => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const transition = style.transition || style.webkitTransition || '';
    const hasTransition = transition && transition !== 'none' && transition !== 'all 0s ease 0s';
    const transitionDuration = parseFloat(style.transitionDuration) * 1000 || 0;

    if (hasTransition) hasTransitions++;
    else noTransitions++;

    const tag = el.tagName.toLowerCase();
    const classes = (el.className || '').toString();
    const outlineStyle = style.outlineStyle;
    const outlineWidth = parseFloat(style.outlineWidth) || 0;

    const hasFocusOutline = outlineStyle !== 'none' && outlineWidth > 0;

    const entry = {
      tag,
      text: (el.textContent || '').trim().substring(0, 30),
      hasTransition,
      transitionDuration,
      hasFocusOutline,
      outlineStyle
    };

    stateInfo.push(entry);

    if (tag === 'button' || tag === 'a') {
      if (transitionDuration > 0 && (transitionDuration < 100 || transitionDuration > 600)) {
        issues.push({
          type: 'bad-transition-duration',
          ...entry,
          message: `Transition duration is ${transitionDuration}ms. Optimal range is 150-400ms for interactive feedback.`
        });
      }
    }
  });

  const focusOutlineElements = stateInfo.filter(s => s.hasFocusOutline);

  if (focusSelectors.length === 0 && focusOutlineElements.length === 0) {
    issues.push({
      type: 'no-focus-styles',
      message: 'No :focus or :focus-visible styles detected in any stylesheet. Keyboard users cannot see where they are.'
    });
  }

  if (hoverSelectors.length === 0) {
    issues.push({
      type: 'no-hover-styles',
      message: 'No :hover styles detected. Interactive elements have no visual hover feedback.'
    });
  }

  if (activeSelectors.length === 0) {
    issues.push({
      type: 'no-active-styles',
      message: 'No :active styles detected. Buttons and links have no pressed/click feedback.'
    });
  }

  return {
    hoverRulesCount: hoverSelectors.length,
    focusRulesCount: focusSelectors.length,
    activeRulesCount: activeSelectors.length,
    elementsWithTransitions: hasTransitions,
    elementsWithoutTransitions: noTransitions,
    transitionCoverage: (hasTransitions + noTransitions) > 0 ? Math.round((hasTransitions / (hasTransitions + noTransitions)) * 100) : 0,
    stateInfo: stateInfo.slice(0, 15),
    issues
  };
})()
```

### 5.3 Loading, Empty, and Error State Detection

```javascript
(() => {
  const issues = [];
  const findings = { loading: [], empty: [], error: [] };

  // Loading states
  const spinners = document.querySelectorAll('[class*="spinner"], [class*="Spinner"], [class*="loading"], [class*="Loading"], [class*="skeleton"], [class*="Skeleton"], [class*="shimmer"], [class*="Shimmer"], [role="progressbar"], [aria-busy="true"], [class*="pulse"], [class*="animate-pulse"]');
  spinners.forEach(el => {
    const rect = el.getBoundingClientRect();
    findings.loading.push({
      type: el.className.toString().match(/skeleton|shimmer/i) ? 'skeleton' : 'spinner',
      tag: el.tagName.toLowerCase(),
      classes: (el.className || '').toString().substring(0, 60),
      visible: rect.width > 0 && rect.height > 0
    });
  });

  // Empty states
  const emptyIndicators = document.querySelectorAll('[class*="empty"], [class*="Empty"], [class*="no-results"], [class*="no-data"], [class*="NoData"], [class*="placeholder"], [class*="Placeholder"], [class*="zero-state"], [class*="ZeroState"], [class*="blank-slate"], [class*="BlankSlate"]');
  emptyIndicators.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const hasIllustration = el.querySelector('svg, img, [class*="icon"], [class*="illustration"]');
    const hasExplanation = el.querySelector('p, [class*="description"], [class*="message"]');
    const hasCTA = el.querySelector('a, button, [role="button"]');
    const text = (el.textContent || '').trim();

    findings.empty.push({
      text: text.substring(0, 60),
      hasIllustration: !!hasIllustration,
      hasExplanation: !!hasExplanation,
      hasCTA: !!hasCTA,
      quality: (hasIllustration ? 1 : 0) + (hasExplanation ? 1 : 0) + (hasCTA ? 1 : 0)
    });

    if (!hasIllustration && !hasCTA) {
      issues.push({
        type: 'poor-empty-state',
        text: text.substring(0, 40),
        message: 'Empty state is missing illustration and CTA. Good empty states have: illustration + explanation + actionable CTA.'
      });
    }
  });

  // Error states
  const errorIndicators = document.querySelectorAll('[class*="error"], [class*="Error"], [role="alert"], [aria-invalid="true"], [class*="invalid"], [class*="Invalid"], [class*="danger"], [class*="Danger"]');
  errorIndicators.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const text = (el.textContent || '').trim();
    const style = window.getComputedStyle(el);
    const color = style.color;
    const hasIcon = el.querySelector('svg, [class*="icon"], [class*="Icon"]');
    const isInline = el.closest('form, [class*="form"]');
    const hasErrorCode = /error\s*(code|#)?\s*\d+|err_|errno/i.test(text);
    const isGeneric = /something went wrong|an error occurred|oops/i.test(text);

    findings.error.push({
      text: text.substring(0, 60),
      hasIcon: !!hasIcon,
      isInline: !!isInline,
      hasErrorCode,
      isGeneric,
      color
    });

    if (hasErrorCode) {
      issues.push({
        type: 'error-code-exposed',
        text: text.substring(0, 40),
        message: 'Error message exposes error codes to users. Use plain-language, actionable messages instead.'
      });
    }

    if (isGeneric) {
      issues.push({
        type: 'generic-error',
        text: text.substring(0, 40),
        message: 'Error message is too generic. Provide specific, actionable guidance for what the user should do.'
      });
    }

    if (!hasIcon) {
      issues.push({
        type: 'error-no-icon',
        text: text.substring(0, 40),
        message: 'Error message has no icon. Add a warning/error icon for visual recognition beyond color.'
      });
    }
  });

  return {
    loadingStates: findings.loading.length,
    hasSkeletonLoading: findings.loading.some(l => l.type === 'skeleton'),
    emptyStates: findings.empty.length,
    errorStates: findings.error.length,
    findings,
    issues: issues.slice(0, 20)
  };
})()
```

### 5.4 Transition Duration Audit

```javascript
(() => {
  const allElements = document.querySelectorAll('a, button, [role="button"], input, select, textarea, [class*="card"], [class*="Card"], [class*="nav"], [class*="menu"], [class*="dropdown"], [class*="modal"], [class*="tooltip"], [class*="popover"]');
  const durations = [];
  const issues = [];

  allElements.forEach(el => {
    const style = window.getComputedStyle(el);
    const transition = style.transition || '';
    if (!transition || transition === 'none' || transition === 'all 0s ease 0s') return;

    const durationMatch = transition.match(/([\d.]+)s/g);
    if (!durationMatch) return;

    durationMatch.forEach(d => {
      const ms = parseFloat(d) * 1000;
      if (ms === 0) return;

      durations.push({
        tag: el.tagName.toLowerCase(),
        text: (el.textContent || '').trim().substring(0, 30),
        transition: transition.substring(0, 80),
        durationMs: Math.round(ms)
      });

      if (ms < 100) {
        issues.push({
          type: 'too-fast',
          durationMs: Math.round(ms),
          element: el.tagName.toLowerCase(),
          message: `Transition ${Math.round(ms)}ms is too fast to be perceived. Use >=150ms for noticeable feedback.`
        });
      }

      if (ms > 500) {
        issues.push({
          type: 'too-slow',
          durationMs: Math.round(ms),
          element: el.tagName.toLowerCase(),
          message: `Transition ${Math.round(ms)}ms feels sluggish for UI interaction. Use 200-400ms for responsive feel.`
        });
      }
    });
  });

  const allDurations = durations.map(d => d.durationMs);
  const uniqueDurations = [...new Set(allDurations)].sort((a, b) => a - b);

  if (uniqueDurations.length > 5) {
    issues.push({
      type: 'too-many-durations',
      count: uniqueDurations.length,
      values: uniqueDurations,
      message: `${uniqueDurations.length} unique transition durations found. Limit to 2-3 (fast: 150ms, normal: 250ms, slow: 400ms).`
    });
  }

  return {
    totalTransitions: durations.length,
    uniqueDurations,
    durationCount: uniqueDurations.length,
    optimalRange: durations.filter(d => d.durationMs >= 150 && d.durationMs <= 400).length,
    durations: durations.slice(0, 20),
    issues: issues.slice(0, 15)
  };
})()
```

### 5.5 Disabled State and Aria-Disabled Audit

```javascript
(() => {
  const disabledElements = document.querySelectorAll('[disabled], [aria-disabled="true"], .disabled, [class*="disabled"], [class*="Disabled"]');
  const issues = [];
  const findings = [];

  disabledElements.forEach(el => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const opacity = parseFloat(style.opacity);
    const cursor = style.cursor;
    const pointerEvents = style.pointerEvents;
    const hasTitle = !!el.getAttribute('title');
    const hasAriaLabel = !!el.getAttribute('aria-label');
    const hasTooltip = !!el.getAttribute('data-tooltip') || !!el.closest('[class*="tooltip"]');

    const entry = {
      tag: el.tagName.toLowerCase(),
      text: (el.textContent || '').trim().substring(0, 40),
      opacity,
      cursor,
      pointerEvents,
      hasExplanation: hasTitle || hasAriaLabel || hasTooltip
    };

    findings.push(entry);

    if (opacity >= 0.9) {
      issues.push({
        type: 'unclear-disabled',
        ...entry,
        message: `Disabled element has opacity ${opacity}. Should be visually dimmed (opacity 0.4-0.6) to signal non-interactivity.`
      });
    }

    if (cursor !== 'not-allowed' && cursor !== 'default') {
      issues.push({
        type: 'wrong-disabled-cursor',
        ...entry,
        message: `Disabled element uses cursor: ${cursor}. Should use cursor: not-allowed or cursor: default.`
      });
    }

    if (!entry.hasExplanation) {
      issues.push({
        type: 'unexplained-disabled',
        ...entry,
        message: 'Disabled element has no explanation (title, aria-label, or tooltip) for why it is disabled.'
      });
    }
  });

  return {
    totalDisabledElements: findings.length,
    findings: findings.slice(0, 15),
    issues: issues.slice(0, 15)
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Do Interactions Feel Alive or Dead?**: Looking at buttons, links, cards, and interactive elements in the screenshot — do they look like they would respond when interacted with? Buttons with shadows, depth, or subtle gradients invite clicking. Flat, borderless elements with no visual affordance feel dead. Is there any visual cue that says "I am interactive"?

2. **Delight in Micro-Animations**: Are there any signs of delightful micro-animations (loading transitions, entrance effects, subtle bounces, smooth reveals)? Or does the page feel static and lifeless? Delight is not decoration — it is feedback that makes the interface feel responsive and human.

3. **Empathetic Error Handling**: When errors are present, do they feel empathetic? Does the message explain what went wrong in human language? Does it tell the user what to do next? Does it avoid blame ("You entered an invalid email" vs. "Please enter a valid email")? Is the tone warm rather than robotic?

4. **Rewarding Success Feedback**: When a user completes an action successfully, is there clear visual confirmation? A toast notification, checkmark animation, color change, or confetti moment? Or does success pass silently? The absence of positive feedback makes users uncertain if their action worked.

5. **Would You Smile?**: Is there any moment in the interface that would make a user smile or feel pleasantly surprised? An unexpected animation, a clever empty state illustration, a playful loading message, a satisfying button press? Micro-delight creates emotional connection.

6. **Loading State Quality**: Are loading states well-crafted? Skeleton screens that match the shape of incoming content are premium. Generic spinners are acceptable. No loading indicator at all is a failure. Does the loading state reduce perceived wait time?

7. **State Transition Completeness**: For each interactive element visible, mentally check: does it have a default state, hover state, focus state, active (pressed) state, and disabled state? A complete state machine means the user always knows what the element is doing. Missing states create confusion.

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | All interactive elements have cursor:pointer. All buttons/links have hover + focus + active states. Transition durations 150-400ms. Skeleton loading screens. Empty states with illustration + explanation + CTA. Error messages are inline, specific, with icons. Disabled states visually clear with explanations. At least one moment of delight. |
| 4 | >=90% elements have correct cursor. Hover + focus states present on most elements. Transitions mostly in optimal range. Has loading indicators (spinners acceptable). Empty states have at least text + CTA. Error messages are specific. 1-2 elements missing state coverage. |
| 3 | >=75% elements have correct cursor. Hover states present but focus states inconsistent. Some transitions outside optimal range. Basic loading indicators. Empty states are text-only. Error messages somewhat generic. Several elements missing active/disabled states. |
| 2 | <75% cursor coverage. Hover states on some elements, no focus styles. Transitions either too fast or too slow. No loading states visible. No empty state design. Error messages are generic ("Something went wrong"). Many interactive elements feel dead. |
| 1 | No cursor:pointer on custom interactive elements. No hover, focus, or active states. No transitions. No loading, empty, or error state handling. Interface feels completely static and unresponsive. No affordances on interactive elements. |

## Common Fixes

### Fix: Add pointer cursor to all interactive elements
```css
a, button, [role="button"], [role="link"], [role="tab"],
[role="menuitem"], [role="checkbox"], [role="radio"],
[role="switch"], [tabindex]:not([tabindex="-1"]),
label[for], summary, select {
  cursor: pointer;
}

[disabled], [aria-disabled="true"] {
  cursor: not-allowed;
  opacity: 0.5;
}
```

**Tailwind equivalent:**
```html
<button class="cursor-pointer">
<button class="cursor-not-allowed opacity-50" disabled>
```

### Fix: Complete button state machine
```css
.btn {
  transition: all 200ms ease;
  transform: translateY(0);
}

.btn:hover {
  filter: brightness(1.1);
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.btn:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

.btn:active {
  transform: translateY(0);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  filter: brightness(0.95);
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  pointer-events: none;
}
```

**Tailwind equivalent:**
```html
<button class="transition-all duration-200 hover:brightness-110 hover:-translate-y-px hover:shadow-lg focus-visible:outline-2 focus-visible:outline-primary focus-visible:outline-offset-2 active:translate-y-0 active:shadow-sm active:brightness-95 disabled:opacity-50 disabled:cursor-not-allowed disabled:pointer-events-none">
```

### Fix: Skeleton loading screen
```css
.skeleton {
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: skeleton-pulse 1.5s ease-in-out infinite;
  border-radius: 4px;
}

@keyframes skeleton-pulse {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.skeleton-text { height: 1em; margin-bottom: 0.5em; }
.skeleton-title { height: 1.5em; width: 60%; margin-bottom: 1em; }
.skeleton-avatar { width: 48px; height: 48px; border-radius: 50%; }
```

**Tailwind equivalent:**
```html
<div class="animate-pulse bg-gray-200 rounded h-4 mb-2"></div>
<div class="animate-pulse bg-gray-200 rounded h-6 w-3/5 mb-4"></div>
```

### Fix: Empathetic error message
```css
.error-message {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border-radius: 0.5rem;
  background: #fef2f2;
  border: 1px solid #fecaca;
  color: #991b1b;
  font-size: 0.875rem;
  line-height: 1.5;
}

.error-message svg {
  flex-shrink: 0;
  width: 1.25rem;
  height: 1.25rem;
  margin-top: 0.125rem;
}
```

### Fix: Transition duration standardization
```css
:root {
  --duration-fast: 150ms;
  --duration-normal: 250ms;
  --duration-slow: 400ms;
  --easing-default: cubic-bezier(0.4, 0, 0.2, 1);
}

a, button { transition: all var(--duration-fast) var(--easing-default); }
.card { transition: all var(--duration-normal) var(--easing-default); }
.modal, .drawer { transition: all var(--duration-slow) var(--easing-default); }
```
