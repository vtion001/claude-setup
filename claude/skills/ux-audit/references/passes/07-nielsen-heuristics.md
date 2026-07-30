# Pass 7: Nielsen's 10 Usability Heuristics

## Tier 1: Automated Checks

### 7.1 System Status Indicators (Heuristic #1: Visibility of System Status)

```javascript
(() => {
  const issues = [];
  const findings = {
    loadingIndicators: [],
    progressBars: [],
    statusMessages: [],
    activeStates: []
  };

  const loaders = document.querySelectorAll('[class*="loading"], [class*="Loading"], [class*="spinner"], [class*="Spinner"], [role="progressbar"], [aria-busy="true"], [class*="skeleton"], [class*="progress"]');
  loaders.forEach(el => {
    const rect = el.getBoundingClientRect();
    findings.loadingIndicators.push({
      tag: el.tagName.toLowerCase(),
      classes: (el.className || '').toString().substring(0, 60),
      visible: rect.width > 0 && rect.height > 0,
      role: el.getAttribute('role'),
      ariaValueNow: el.getAttribute('aria-valuenow'),
      ariaValueMax: el.getAttribute('aria-valuemax')
    });
  });

  const progressBars = document.querySelectorAll('[role="progressbar"], progress, [class*="progress-bar"], [class*="ProgressBar"]');
  progressBars.forEach(bar => {
    const hasValue = bar.getAttribute('aria-valuenow') || bar.value !== undefined;
    const hasMax = bar.getAttribute('aria-valuemax') || bar.max !== undefined;
    const hasLabel = bar.getAttribute('aria-label') || bar.getAttribute('aria-labelledby');

    findings.progressBars.push({
      hasValue: !!hasValue,
      hasMax: !!hasMax,
      hasLabel: !!hasLabel
    });

    if (!hasLabel) {
      issues.push({
        type: 'progress-no-label',
        message: 'Progress bar missing aria-label. Users (especially screen reader users) cannot understand what is progressing.'
      });
    }
  });

  const navLinks = document.querySelectorAll('nav a, [role="navigation"] a, [role="tab"], [role="tablist"] button');
  navLinks.forEach(link => {
    const isCurrent = link.getAttribute('aria-current') || link.classList.contains('active') || link.classList.contains('current') || link.getAttribute('aria-selected') === 'true';
    const style = window.getComputedStyle(link);

    findings.activeStates.push({
      text: (link.textContent || '').trim().substring(0, 30),
      isCurrent: !!isCurrent,
      ariaCurrent: link.getAttribute('aria-current'),
      ariaSelected: link.getAttribute('aria-selected')
    });
  });

  const activeNavItems = findings.activeStates.filter(s => s.isCurrent);
  if (navLinks.length > 0 && activeNavItems.length === 0) {
    issues.push({
      type: 'no-active-nav',
      navItemCount: navLinks.length,
      message: 'Navigation has no active/current indicator. Users cannot see where they are in the site structure.'
    });
  }

  const forms = document.querySelectorAll('form');
  forms.forEach(form => {
    const submitBtn = form.querySelector('[type="submit"], button:not([type="button"]):not([type="reset"])');
    if (submitBtn) {
      const hasLoadingClass = /loading|submitting|pending|disabled/i.test(submitBtn.className || '');
      const hasAriaDisabled = submitBtn.getAttribute('aria-disabled');
      if (!hasLoadingClass && !hasAriaDisabled) {
        issues.push({
          type: 'no-submit-feedback',
          formAction: (form.action || '').substring(0, 40),
          message: 'Form submit button has no loading/submitting state class or aria-disabled handling. Users need feedback during submission.'
        });
      }
    }
  });

  return {
    loadingIndicators: findings.loadingIndicators.length,
    progressBars: findings.progressBars.length,
    activeNavItems: activeNavItems.length,
    totalNavItems: navLinks.length,
    findings,
    issues
  };
})()
```

### 7.2 User Control: Undo, Cancel, and Escape Support (Heuristic #3: User Control & Freedom)

```javascript
(() => {
  const issues = [];
  const findings = { modals: [], forms: [], destructiveActions: [] };

  const modals = document.querySelectorAll('[role="dialog"], [class*="modal"], [class*="Modal"], [class*="dialog"], [class*="Dialog"], [class*="popup"], [class*="Popup"], [class*="overlay"], [class*="Overlay"]');
  modals.forEach(modal => {
    const rect = modal.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const closeBtn = modal.querySelector('[class*="close"], [class*="Close"], [aria-label="Close"], [aria-label*="close"], button[class*="dismiss"]');
    const cancelBtn = modal.querySelector('button[class*="cancel"], button[class*="Cancel"], a[class*="cancel"]');
    const escapeHandler = modal.getAttribute('tabindex') !== null || modal.getAttribute('role') === 'dialog';

    findings.modals.push({
      hasCloseButton: !!closeBtn,
      hasCancelButton: !!cancelBtn,
      hasEscapeSupport: escapeHandler,
      classes: (modal.className || '').toString().substring(0, 60)
    });

    if (!closeBtn && !cancelBtn) {
      issues.push({
        type: 'modal-no-exit',
        classes: (modal.className || '').toString().substring(0, 40),
        message: 'Modal/dialog has no close or cancel button. Users are trapped. Add an X button and a Cancel option.'
      });
    }
  });

  const forms = document.querySelectorAll('form');
  forms.forEach(form => {
    const fields = form.querySelectorAll('input, select, textarea');
    if (fields.length < 2) return;

    const cancelBtn = form.querySelector('button[type="reset"], [class*="cancel"], [class*="Cancel"], a[href]');
    const hasUnsavedWarning = form.getAttribute('data-unsaved') || form.classList.contains('dirty');

    findings.forms.push({
      fieldCount: fields.length,
      hasCancelButton: !!cancelBtn,
      hasUnsavedWarning: !!hasUnsavedWarning
    });

    if (!cancelBtn && fields.length >= 3) {
      issues.push({
        type: 'form-no-cancel',
        fieldCount: fields.length,
        message: `Form with ${fields.length} fields has no cancel/back option. Long forms need an escape route.`
      });
    }
  });

  const destructiveButtons = document.querySelectorAll('button[class*="delete"], button[class*="Delete"], button[class*="remove"], button[class*="Remove"], button[class*="destroy"], [class*="danger"]');
  destructiveButtons.forEach(btn => {
    const text = (btn.textContent || '').trim();
    const hasConfirm = btn.getAttribute('data-confirm') || btn.getAttribute('aria-haspopup') || btn.closest('[class*="confirm"]');

    findings.destructiveActions.push({
      text: text.substring(0, 30),
      hasConfirmation: !!hasConfirm
    });

    if (!hasConfirm) {
      issues.push({
        type: 'destructive-no-confirm',
        text: text.substring(0, 30),
        message: `Destructive action "${text}" has no confirmation step. Destructive actions must require explicit confirmation.`
      });
    }
  });

  return {
    modals: findings.modals.length,
    forms: findings.forms.length,
    destructiveActions: findings.destructiveActions.length,
    findings,
    issues
  };
})()
```

### 7.3 Consistency and Standards (Heuristic #4)

```javascript
(() => {
  const issues = [];
  const findings = { links: [], buttons: [], inputs: [] };

  const links = document.querySelectorAll('a');
  const linkStyles = new Set();
  links.forEach(link => {
    const style = window.getComputedStyle(link);
    const rect = link.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const isNav = link.closest('nav, [role="navigation"], header, footer');
    if (isNav) return;

    const styleKey = `${style.color}|${style.textDecorationLine}|${style.fontWeight}`;
    linkStyles.add(styleKey);

    findings.links.push({
      text: (link.textContent || '').trim().substring(0, 30),
      color: style.color,
      decoration: style.textDecorationLine,
      weight: style.fontWeight
    });
  });

  if (linkStyles.size > 3) {
    issues.push({
      type: 'inconsistent-link-styles',
      uniqueStyles: linkStyles.size,
      message: `${linkStyles.size} different link styles detected (excluding nav). Links should look consistent throughout the page.`
    });
  }

  const buttons = document.querySelectorAll('button, [role="button"], input[type="submit"], input[type="button"]');
  const buttonStyles = new Map();
  buttons.forEach(btn => {
    const style = window.getComputedStyle(btn);
    const rect = btn.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const borderRadius = style.borderRadius;
    if (!buttonStyles.has(borderRadius)) buttonStyles.set(borderRadius, 0);
    buttonStyles.set(borderRadius, buttonStyles.get(borderRadius) + 1);

    findings.buttons.push({
      text: (btn.textContent || '').trim().substring(0, 30),
      borderRadius,
      fontSize: style.fontSize,
      padding: `${style.paddingTop} ${style.paddingRight}`
    });
  });

  if (buttonStyles.size > 3) {
    issues.push({
      type: 'inconsistent-button-radius',
      uniqueRadii: [...buttonStyles.entries()].map(([r, c]) => ({ radius: r, count: c })),
      message: `${buttonStyles.size} different border-radius values on buttons. Use 1-2 consistent values.`
    });
  }

  const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"]), select, textarea');
  const inputStyles = new Set();
  inputs.forEach(input => {
    const style = window.getComputedStyle(input);
    const rect = input.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const styleKey = `${style.borderRadius}|${style.borderWidth}|${style.borderColor}|${style.fontSize}|${Math.round(parseFloat(style.height))}`;
    inputStyles.add(styleKey);

    findings.inputs.push({
      type: input.type || input.tagName.toLowerCase(),
      borderRadius: style.borderRadius,
      height: Math.round(parseFloat(style.height)),
      fontSize: style.fontSize
    });
  });

  if (inputStyles.size > 2 && inputs.length > 3) {
    issues.push({
      type: 'inconsistent-input-styles',
      uniqueStyles: inputStyles.size,
      inputCount: inputs.length,
      message: `${inputStyles.size} different input styles for ${inputs.length} fields. Form inputs should be visually identical.`
    });
  }

  return {
    uniqueLinkStyles: linkStyles.size,
    uniqueButtonRadii: buttonStyles.size,
    uniqueInputStyles: inputStyles.size,
    findings: {
      links: findings.links.slice(0, 10),
      buttons: findings.buttons.slice(0, 10),
      inputs: findings.inputs.slice(0, 10)
    },
    issues
  };
})()
```

### 7.4 Error Prevention and Plain Language (Heuristics #5, #9)

```javascript
(() => {
  const issues = [];
  const findings = { labels: [], placeholders: [], errorMessages: [], confirmations: [] };

  const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]), select, textarea');
  inputs.forEach(input => {
    const id = input.id;
    const name = input.name;
    const type = input.type || 'text';
    const placeholder = input.placeholder || '';
    const label = id ? document.querySelector(`label[for="${id}"]`) : null;
    const ariaLabel = input.getAttribute('aria-label');
    const ariaLabelledBy = input.getAttribute('aria-labelledby');
    const parentLabel = input.closest('label');
    const hasVisibleLabel = !!(label || parentLabel);
    const hasAnyLabel = !!(hasVisibleLabel || ariaLabel || ariaLabelledBy);

    const entry = {
      type,
      name: name || id || type,
      hasVisibleLabel,
      hasAnyLabel,
      placeholder: placeholder.substring(0, 40),
      isPlaceholderOnly: !hasVisibleLabel && !!placeholder,
      hasAutocomplete: !!input.getAttribute('autocomplete'),
      hasPattern: !!input.getAttribute('pattern'),
      hasRequired: input.required || input.getAttribute('aria-required') === 'true',
      hasMinMax: !!input.min || !!input.max || !!input.minLength || !!input.maxLength
    };

    findings.labels.push(entry);

    if (entry.isPlaceholderOnly) {
      issues.push({
        type: 'placeholder-only-label',
        field: entry.name,
        placeholder: entry.placeholder,
        message: `Input "${entry.name}" uses placeholder as its only label. Placeholders disappear on focus. Add a visible <label>.`
      });
    }

    if (!hasAnyLabel) {
      issues.push({
        type: 'no-label',
        field: entry.name,
        message: `Input "${entry.name}" has no label, aria-label, or aria-labelledby. Screen readers cannot identify this field.`
      });
    }

    if (type === 'email' && !input.getAttribute('autocomplete')) {
      issues.push({
        type: 'missing-autocomplete',
        field: entry.name,
        message: `Email input missing autocomplete="email". Autocomplete reduces friction and errors.`
      });
    }

    if ((type === 'password') && !input.getAttribute('autocomplete')) {
      issues.push({
        type: 'missing-autocomplete',
        field: entry.name,
        message: `Password input missing autocomplete attribute. Use "current-password" or "new-password".`
      });
    }
  });

  const errorMessages = document.querySelectorAll('[class*="error"], [role="alert"], [aria-live="polite"], [aria-live="assertive"], [class*="invalid"], [class*="validation"]');
  errorMessages.forEach(el => {
    const text = (el.textContent || '').trim();
    if (text.length < 3) return;

    const hasErrorCode = /error\s*(code|#)?\s*\d+|err[_-]|errno|\b[45]\d{2}\b|exception/i.test(text);
    const isTechnical = /null|undefined|NaN|stack\s*trace|cannot read|is not a function|unexpected token/i.test(text);
    const isBlaming = /you (must|should|need to|have to|failed|didn't)/i.test(text);
    const hasRecovery = /(try|please|check|verify|make sure|enter a valid|use a different)/i.test(text);

    findings.errorMessages.push({
      text: text.substring(0, 80),
      hasErrorCode,
      isTechnical,
      isBlaming,
      hasRecovery
    });

    if (hasErrorCode || isTechnical) {
      issues.push({
        type: 'technical-error-message',
        text: text.substring(0, 60),
        message: 'Error message exposes technical details. Replace with plain-language explanation of what happened and what to do.'
      });
    }

    if (isBlaming) {
      issues.push({
        type: 'blaming-error',
        text: text.substring(0, 60),
        message: 'Error message blames the user. Rewrite to be empathetic: "Please enter a valid email" instead of "You must enter a valid email".'
      });
    }

    if (!hasRecovery && text.length > 10) {
      issues.push({
        type: 'no-recovery-guidance',
        text: text.substring(0, 60),
        message: 'Error message does not provide recovery guidance. Tell the user what to do to fix the problem.'
      });
    }
  });

  return {
    totalInputs: inputs.length,
    placeholderOnlyInputs: findings.labels.filter(l => l.isPlaceholderOnly).length,
    unlabeledInputs: findings.labels.filter(l => !l.hasAnyLabel).length,
    inputsWithAutocomplete: findings.labels.filter(l => l.hasAutocomplete).length,
    errorMessages: findings.errorMessages.length,
    technicalErrors: findings.errorMessages.filter(e => e.hasErrorCode || e.isTechnical).length,
    findings,
    issues: issues.slice(0, 25)
  };
})()
```

### 7.5 Recognition Over Recall and Help (Heuristics #6, #10)

```javascript
(() => {
  const issues = [];
  const findings = { tooltips: [], breadcrumbs: [], searchElements: [], helpLinks: [], contextualHelp: [] };

  const tooltips = document.querySelectorAll('[title], [data-tooltip], [aria-describedby], [class*="tooltip"], [class*="Tooltip"], [role="tooltip"]');
  findings.tooltips = tooltips.length;

  const breadcrumbs = document.querySelectorAll('[class*="breadcrumb"], [class*="Breadcrumb"], nav[aria-label="breadcrumb"], nav[aria-label="Breadcrumb"], ol[class*="breadcrumb"]');
  findings.breadcrumbs = breadcrumbs.length;

  if (breadcrumbs.length === 0) {
    const navDepthIndicators = document.querySelectorAll('[class*="back"], [class*="parent"], a[href="../"], [class*="crumb"]');
    if (navDepthIndicators.length === 0) {
      const links = document.querySelectorAll('nav a, [role="navigation"] a');
      if (links.length > 5) {
        issues.push({
          type: 'no-breadcrumbs',
          message: 'Complex navigation detected but no breadcrumbs found. Users cannot see where they are in the information architecture.'
        });
      }
    }
  }

  const search = document.querySelectorAll('input[type="search"], [role="search"], [class*="search"], [class*="Search"], input[placeholder*="search" i]');
  findings.searchElements = search.length;

  const helpElements = document.querySelectorAll('a[href*="help"], a[href*="faq"], a[href*="support"], a[href*="docs"], [class*="help"], [class*="Help"], [class*="faq"], [class*="FAQ"], [aria-label*="help" i]');
  findings.helpLinks = helpElements.length;

  const contextHelp = document.querySelectorAll('[class*="hint"], [class*="Hint"], [class*="helper"], [class*="Helper"], [class*="help-text"], [class*="helpText"], .form-text, [id$="-help"], [id$="-hint"], [class*="description"]');
  findings.contextualHelp = contextHelp.length;

  const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"]), select, textarea');
  let inputsWithHelp = 0;
  let inputsWithoutHelp = 0;

  inputs.forEach(input => {
    const id = input.id;
    const describedBy = input.getAttribute('aria-describedby');
    const hint = describedBy ? document.getElementById(describedBy) : null;
    const parentGroup = input.closest('[class*="group"], [class*="field"], fieldset');
    const siblingHelp = parentGroup ? parentGroup.querySelector('[class*="hint"], [class*="help"], [class*="description"], small') : null;

    if (hint || siblingHelp || input.placeholder) {
      inputsWithHelp++;
    } else {
      inputsWithoutHelp++;
    }
  });

  const icons = document.querySelectorAll('svg, [class*="icon"], [class*="Icon"], i[class]');
  let iconsWithLabels = 0;
  let iconsWithoutLabels = 0;

  icons.forEach(icon => {
    const rect = icon.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    if (rect.width > 48 || rect.height > 48) return;

    const hasLabel = icon.getAttribute('aria-label') || icon.getAttribute('title') || icon.closest('[aria-label]') || icon.closest('[title]');
    const hasAdjacentText = icon.parentElement && (icon.parentElement.textContent || '').trim().length > icon.textContent.trim().length + 1;
    const isDecorative = icon.getAttribute('aria-hidden') === 'true' || icon.getAttribute('role') === 'presentation';

    if (isDecorative || hasAdjacentText) {
      iconsWithLabels++;
    } else if (hasLabel) {
      iconsWithLabels++;
    } else {
      iconsWithoutLabels++;
    }
  });

  if (iconsWithoutLabels > 3) {
    issues.push({
      type: 'icon-only-no-label',
      count: iconsWithoutLabels,
      message: `${iconsWithoutLabels} icon-only elements detected without labels. Icons without text labels require users to recall meaning. Add text labels or tooltips.`
    });
  }

  if (findings.helpLinks === 0) {
    issues.push({
      type: 'no-help-access',
      message: 'No help, FAQ, support, or documentation links found on the page. Users stuck on a task have no recourse.'
    });
  }

  return {
    tooltipCount: findings.tooltips,
    breadcrumbCount: findings.breadcrumbs,
    searchElementCount: findings.searchElements,
    helpLinkCount: findings.helpLinks,
    contextualHelpCount: findings.contextualHelp,
    inputsWithHelp,
    inputsWithoutHelp,
    iconsWithLabels,
    iconsWithoutLabels,
    findings,
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, evaluate each of Nielsen's 10 heuristics. For each, answer the specific question and score 1-5. Then flag the **weakest 3** for the final report.

### H1: Visibility of System Status
**Question**: At any given moment on this page, does the user know what is happening? Is there clear feedback for every action (loading, saving, navigating, submitting)? Can the user tell where they are in the site, what page they are on, and what state the system is in?

### H2: Match Between System and Real World
**Question**: Does the language, terminology, and iconography match what the target user would naturally use? Or does it use developer jargon, internal product names, or unfamiliar metaphors? Are form labels written in the user's language? Do icons match real-world conventions (trash for delete, pencil for edit, magnifying glass for search)?

### H3: User Control and Freedom
**Question**: Can the user easily undo, cancel, or go back from any action? Can they close modals? Can they abandon long forms? Is there a "back" or "cancel" option for multi-step processes? Are destructive actions (delete, remove) protected by confirmation? Can the user recover from mistakes?

### H4: Consistency and Standards
**Question**: Are UI patterns consistent throughout the page? Do all buttons look the same? Do all links behave the same? Do all form fields have the same style? Does the page follow platform conventions (links are blue/underlined, errors are red, success is green)? Would a user who has used other websites know how to use this one?

### H5: Error Prevention
**Question**: Does the design prevent errors before they occur? Are form fields properly constrained (date pickers instead of free text, dropdowns instead of typo-prone inputs)? Are required fields marked? Are destructive actions gated behind confirmation? Is input validation visible before submission?

### H6: Recognition Rather Than Recall
**Question**: Can the user see all available options rather than having to remember them? Are navigation items visible? Are recently visited items shown? Are form options presented as selectable lists rather than empty fields? Does the page minimize the user's memory load?

### H7: Flexibility and Efficiency of Use
**Question**: Does the page serve both novice and expert users? Are there shortcuts for power users (keyboard shortcuts, bulk actions)? Can experienced users skip tutorials or onboarding? Is the most common task the easiest to perform?

### H8: Aesthetic and Minimalist Design
**Question**: Does every visible element serve a purpose? Is there unnecessary decoration, redundant text, or visual noise? Does the interface contain only information relevant to the user's current task? Is the signal-to-noise ratio high?

### H9: Help Users Recognize, Diagnose, and Recover from Errors
**Question**: When errors occur, are they expressed in plain language (not error codes)? Do they precisely indicate the problem? Do they constructively suggest a solution? Are error messages placed near the source of the error (inline, not just in a top banner)?

### H10: Help and Documentation
**Question**: Is help available when needed? Can the user find documentation, FAQs, or support? Is contextual help available for complex form fields? Are tooltips provided for ambiguous icons or features? Is the help searchable?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | All 10 heuristics score 4+ individually. Navigation has active state indicators and breadcrumbs. All inputs have visible labels + autocomplete. Error messages are inline, specific, and empathetic with recovery guidance. No placeholder-only inputs. Modals have close + cancel. Destructive actions have confirmation. Help/docs are accessible. Icon-only actions all have tooltips. Keyboard shortcuts documented. |
| 4 | 8-9 heuristics score 4+, 1-2 at 3. Most inputs properly labeled. Most errors have plain-language messages. Modals have close buttons. Most destructive actions protected. Some contextual help present. Minor consistency issues. |
| 3 | 6-7 heuristics score 3+. Some inputs use placeholder-only labels. Error messages exist but are sometimes generic. Some modals lack close buttons. 1-2 unprotected destructive actions. Navigation lacks active state. Limited help content. |
| 2 | 4-5 heuristics score 3+. Multiple placeholder-only inputs. Error messages expose technical codes or blame users. Modals trap users. Multiple destructive actions with no confirmation. Inconsistent element styling. No help resources. |
| 1 | Fewer than 4 heuristics score 3+. Most inputs lack labels. Error handling is absent or shows raw exceptions. No user control (no cancel, no undo, no back). Major inconsistencies across same-type elements. No wayfinding (no breadcrumbs, no active nav states). Page feels hostile to users. |

## Common Fixes

### Fix: Add visible labels to all inputs
```css
/* Replace placeholder-only pattern with visible label */
.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.form-field label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-text);
}

.form-field input::placeholder {
  color: var(--color-text-secondary);
  font-style: italic;
}
```

**Tailwind equivalent:**
```html
<div class="flex flex-col gap-1">
  <label class="text-sm font-medium text-gray-900">Email address</label>
  <input type="email" autocomplete="email" placeholder="you@example.com" class="placeholder:text-gray-400 placeholder:italic">
</div>
```

### Fix: Add active navigation indicator
```css
nav a[aria-current="page"],
nav a.active {
  font-weight: 600;
  color: var(--color-primary);
  border-bottom: 2px solid var(--color-primary);
  padding-bottom: 0.25rem;
}
```

**Tailwind equivalent:**
```html
<a href="/current" aria-current="page" class="font-semibold text-blue-600 border-b-2 border-blue-600 pb-1">
```

### Fix: Add close button to modals
```css
.modal-close {
  position: absolute;
  top: 1rem;
  right: 1rem;
  width: 2rem;
  height: 2rem;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: transparent;
  border-radius: 0.25rem;
  cursor: pointer;
  color: var(--color-text-secondary);
  transition: background-color 150ms ease;
}

.modal-close:hover {
  background-color: var(--color-bg-secondary);
  color: var(--color-text);
}

.modal-close:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}
```

**Tailwind equivalent:**
```html
<button class="absolute top-4 right-4 w-8 h-8 flex items-center justify-center bg-transparent rounded hover:bg-gray-100 text-gray-500 hover:text-gray-800 transition-colors focus-visible:outline-2 focus-visible:outline-blue-600 focus-visible:outline-offset-2" aria-label="Close dialog">
  <svg>...</svg>
</button>
```

### Fix: Destructive action confirmation pattern
```css
.confirm-dialog {
  max-width: 28rem;
  padding: 1.5rem;
  border-radius: 0.75rem;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
}

.confirm-dialog h3 {
  font-size: 1.125rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

.confirm-dialog p {
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  margin-bottom: 1.5rem;
}

.confirm-dialog .actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
}

.confirm-dialog .btn-cancel {
  padding: 0.5rem 1rem;
  background: transparent;
  border: 1px solid var(--color-border);
  border-radius: 0.375rem;
}

.confirm-dialog .btn-destructive {
  padding: 0.5rem 1rem;
  background: var(--color-error);
  color: white;
  border: none;
  border-radius: 0.375rem;
}
```

### Fix: Plain-language inline error messages
```css
/* Position error messages inline, close to the source */
.form-field.has-error input {
  border-color: var(--color-error);
  box-shadow: 0 0 0 1px var(--color-error);
}

.form-field .field-error {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  margin-top: 0.375rem;
  font-size: 0.8125rem;
  color: var(--color-error);
}

.form-field .field-error svg {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
}
```

**Tailwind equivalent:**
```html
<div class="space-y-1">
  <input class="border-red-500 ring-1 ring-red-500">
  <p class="flex items-center gap-1.5 mt-1.5 text-[13px] text-red-600">
    <svg class="w-4 h-4 shrink-0">...</svg>
    Please enter a valid email address (e.g., name@company.com)
  </p>
</div>
```

### Fix: Add breadcrumb navigation
```css
.breadcrumbs {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: var(--color-text-secondary);
  padding: 1rem 0;
}

.breadcrumbs a {
  color: var(--color-primary);
  text-decoration: none;
}

.breadcrumbs a:hover {
  text-decoration: underline;
}

.breadcrumbs span[aria-current="page"] {
  color: var(--color-text);
  font-weight: 500;
}

.breadcrumbs .separator {
  color: var(--color-border);
  user-select: none;
}
```

**Tailwind equivalent:**
```html
<nav aria-label="Breadcrumb" class="flex items-center gap-2 text-sm text-gray-500 py-4">
  <a href="/" class="text-blue-600 hover:underline">Home</a>
  <span class="text-gray-300 select-none">/</span>
  <a href="/products" class="text-blue-600 hover:underline">Products</a>
  <span class="text-gray-300 select-none">/</span>
  <span aria-current="page" class="text-gray-900 font-medium">Widget Pro</span>
</nav>
```

### Fix: Add autocomplete attributes to common fields
```html
<input type="text" name="name" autocomplete="name">
<input type="email" name="email" autocomplete="email">
<input type="tel" name="phone" autocomplete="tel">
<input type="text" name="address" autocomplete="street-address">
<input type="text" name="city" autocomplete="address-level2">
<input type="text" name="zip" autocomplete="postal-code">
<input type="text" name="cc-number" autocomplete="cc-number">
<input type="password" name="current-password" autocomplete="current-password">
<input type="password" name="new-password" autocomplete="new-password">
```
