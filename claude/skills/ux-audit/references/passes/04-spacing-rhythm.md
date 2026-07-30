# Pass 4: Spacing & Rhythm

## Tier 1: Automated Checks

### 4.1 8px Grid Adherence

```javascript
(() => {
  const elements = document.querySelectorAll('section, article, div, header, footer, main, aside, nav, form, ul, ol, table, [class*="card"], [class*="container"], [class*="wrapper"], [class*="grid"], [class*="row"], [class*="col"]');
  const gridBase = 8;
  const violations = [];
  const compliant = [];
  let totalChecked = 0;

  const sampled = Array.from(elements).slice(0, 200);

  sampled.forEach(el => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const spacings = {
      marginTop: parseFloat(style.marginTop) || 0,
      marginBottom: parseFloat(style.marginBottom) || 0,
      marginLeft: parseFloat(style.marginLeft) || 0,
      marginRight: parseFloat(style.marginRight) || 0,
      paddingTop: parseFloat(style.paddingTop) || 0,
      paddingBottom: parseFloat(style.paddingBottom) || 0,
      paddingLeft: parseFloat(style.paddingLeft) || 0,
      paddingRight: parseFloat(style.paddingRight) || 0,
      gap: parseFloat(style.gap) || 0
    };

    const elViolations = [];
    for (const [prop, value] of Object.entries(spacings)) {
      if (value === 0) continue;
      totalChecked++;
      const remainder = value % gridBase;
      if (remainder !== 0 && value > 2) {
        elViolations.push({
          property: prop,
          value: Math.round(value * 10) / 10,
          nearest: Math.round(value / gridBase) * gridBase,
          off: Math.round(remainder * 10) / 10
        });
      } else {
        compliant.push({ property: prop, value: Math.round(value) });
      }
    }

    if (elViolations.length > 0) {
      violations.push({
        tag: el.tagName.toLowerCase(),
        classes: (el.className || '').toString().substring(0, 60),
        violations: elViolations
      });
    }
  });

  const complianceRate = totalChecked > 0 ? Math.round(((totalChecked - violations.reduce((sum, v) => sum + v.violations.length, 0)) / totalChecked) * 100) : 100;

  return {
    gridBase,
    totalSpacingsChecked: totalChecked,
    complianceRate,
    violationCount: violations.reduce((sum, v) => sum + v.violations.length, 0),
    violations: violations.slice(0, 20),
    issues: complianceRate < 70 ? [{
      type: 'poor-grid-adherence',
      message: `Only ${complianceRate}% of spacings follow the ${gridBase}px grid. Standardize margins/paddings to multiples of ${gridBase}px.`
    }] : []
  };
})()
```

### 4.2 Spacing Consistency Across Similar Elements

```javascript
(() => {
  const groupSelectors = {
    cards: '[class*="card"], [class*="Card"]',
    listItems: 'li',
    sections: 'section, [class*="section"]',
    buttons: 'button, [role="button"], a[class*="btn"], a[class*="button"]',
    formFields: 'input, select, textarea',
    headings: 'h1, h2, h3, h4, h5, h6',
    paragraphs: 'p'
  };

  const results = {};
  const issues = [];

  for (const [group, selector] of Object.entries(groupSelectors)) {
    const elements = document.querySelectorAll(selector);
    if (elements.length < 2) continue;

    const spacings = [];
    const sampled = Array.from(elements).slice(0, 30);

    sampled.forEach(el => {
      const style = window.getComputedStyle(el);
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;

      spacings.push({
        marginTop: Math.round(parseFloat(style.marginTop) || 0),
        marginBottom: Math.round(parseFloat(style.marginBottom) || 0),
        paddingTop: Math.round(parseFloat(style.paddingTop) || 0),
        paddingBottom: Math.round(parseFloat(style.paddingBottom) || 0),
        paddingLeft: Math.round(parseFloat(style.paddingLeft) || 0),
        paddingRight: Math.round(parseFloat(style.paddingRight) || 0)
      });
    });

    if (spacings.length < 2) continue;

    const consistency = {};
    for (const prop of ['marginTop', 'marginBottom', 'paddingTop', 'paddingBottom', 'paddingLeft', 'paddingRight']) {
      const values = spacings.map(s => s[prop]);
      const unique = [...new Set(values)];
      const isConsistent = unique.length === 1;
      const variance = unique.length > 1
        ? Math.round(Math.sqrt(values.reduce((sum, v) => sum + Math.pow(v - values[0], 2), 0) / values.length))
        : 0;
      consistency[prop] = { unique, isConsistent, variance };
    }

    const inconsistentProps = Object.entries(consistency).filter(([_, v]) => !v.isConsistent && v.unique.some(u => u > 0));

    if (inconsistentProps.length > 0) {
      issues.push({
        type: 'inconsistent-spacing',
        group,
        elementCount: sampled.length,
        inconsistentProperties: inconsistentProps.map(([prop, data]) => ({
          property: prop,
          values: data.unique,
          variance: data.variance
        })),
        message: `${group} elements have inconsistent spacing across ${inconsistentProps.length} properties.`
      });
    }

    results[group] = {
      count: sampled.length,
      consistency
    };
  }

  return {
    groupsAnalyzed: Object.keys(results).length,
    results,
    issues
  };
})()
```

### 4.3 Proximity Principle Check (Related Items Grouped)

```javascript
(() => {
  const issues = [];

  const formGroups = document.querySelectorAll('form, [class*="form"]');
  formGroups.forEach(form => {
    const labels = form.querySelectorAll('label');
    labels.forEach(label => {
      const forId = label.getAttribute('for');
      let input = null;

      if (forId) {
        input = document.getElementById(forId);
      } else {
        input = label.querySelector('input, select, textarea');
      }

      if (!input) return;

      const labelRect = label.getBoundingClientRect();
      const inputRect = input.getBoundingClientRect();
      const gap = Math.abs(inputRect.top - labelRect.bottom);

      if (gap > 16 && inputRect.top > labelRect.bottom) {
        issues.push({
          type: 'label-input-gap',
          label: (label.textContent || '').trim().substring(0, 30),
          gap: Math.round(gap),
          message: `Label "${(label.textContent || '').trim().substring(0, 20)}" is ${Math.round(gap)}px from its input. Max 8px recommended.`
        });
      }
    });
  });

  const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
  headings.forEach(heading => {
    const next = heading.nextElementSibling;
    if (!next) return;
    const headingRect = heading.getBoundingClientRect();
    const nextRect = next.getBoundingClientRect();
    const gapAfter = nextRect.top - headingRect.bottom;

    const prev = heading.previousElementSibling;
    if (prev) {
      const prevRect = prev.getBoundingClientRect();
      const gapBefore = headingRect.top - prevRect.bottom;

      if (gapBefore > 0 && gapAfter > 0 && gapAfter >= gapBefore) {
        issues.push({
          type: 'heading-proximity',
          heading: (heading.textContent || '').trim().substring(0, 40),
          tag: heading.tagName.toLowerCase(),
          gapBefore: Math.round(gapBefore),
          gapAfter: Math.round(gapAfter),
          message: `Heading "${(heading.textContent || '').trim().substring(0, 20)}" has ${Math.round(gapAfter)}px below and ${Math.round(gapBefore)}px above. Headings should be closer to their content (below) than the preceding content (above).`
        });
      }
    }
  });

  const navItems = document.querySelectorAll('nav a, nav button, [role="navigation"] a');
  if (navItems.length >= 2) {
    const gaps = [];
    for (let i = 0; i < navItems.length - 1; i++) {
      const r1 = navItems[i].getBoundingClientRect();
      const r2 = navItems[i + 1].getBoundingClientRect();
      const isHorizontal = Math.abs(r1.top - r2.top) < 10;
      const gap = isHorizontal ? r2.left - r1.right : r2.top - r1.bottom;
      gaps.push(Math.round(gap));
    }
    const uniqueGaps = [...new Set(gaps)];
    if (uniqueGaps.length > 2) {
      issues.push({
        type: 'uneven-nav-spacing',
        gaps: uniqueGaps,
        message: `Navigation items have ${uniqueGaps.length} different gap sizes (${uniqueGaps.join(', ')}px). Use uniform spacing.`
      });
    }
  }

  return {
    labelInputIssues: issues.filter(i => i.type === 'label-input-gap').length,
    headingProximityIssues: issues.filter(i => i.type === 'heading-proximity').length,
    navSpacingIssues: issues.filter(i => i.type === 'uneven-nav-spacing').length,
    totalIssues: issues.length,
    issues: issues.slice(0, 20)
  };
})()
```

### 4.4 Component Padding and External Margin Minimums

```javascript
(() => {
  const components = document.querySelectorAll('[class*="card"], [class*="Card"], [class*="panel"], [class*="Panel"], [class*="modal"], [class*="Modal"], [class*="dialog"], [class*="Dialog"], [class*="tile"], [class*="Tile"], [class*="widget"], [class*="Widget"], [class*="box"], [class*="Box"], button, [role="button"]');
  const issues = [];
  const measurements = [];

  const sampled = Array.from(components).slice(0, 100);

  sampled.forEach(el => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const padding = {
      top: Math.round(parseFloat(style.paddingTop) || 0),
      right: Math.round(parseFloat(style.paddingRight) || 0),
      bottom: Math.round(parseFloat(style.paddingBottom) || 0),
      left: Math.round(parseFloat(style.paddingLeft) || 0)
    };

    const margin = {
      top: Math.round(parseFloat(style.marginTop) || 0),
      right: Math.round(parseFloat(style.marginRight) || 0),
      bottom: Math.round(parseFloat(style.marginBottom) || 0),
      left: Math.round(parseFloat(style.marginLeft) || 0)
    };

    const minPadding = Math.min(padding.top, padding.right, padding.bottom, padding.left);
    const maxMargin = Math.max(margin.top, margin.bottom);
    const isButton = el.tagName === 'BUTTON' || el.getAttribute('role') === 'button';

    const entry = {
      tag: el.tagName.toLowerCase(),
      classes: (el.className || '').toString().substring(0, 50),
      padding,
      margin,
      minPadding,
      isButton
    };

    measurements.push(entry);

    if (minPadding < 8 && minPadding > 0 && !isButton) {
      issues.push({
        type: 'cramped-padding',
        ...entry,
        message: `Component has ${minPadding}px minimum padding. Minimum 8px recommended for touch-friendly, readable components.`
      });
    }

    if (isButton && (padding.top < 6 || padding.left < 12)) {
      issues.push({
        type: 'cramped-button',
        ...entry,
        message: `Button has ${padding.top}px vertical and ${padding.left}px horizontal padding. Minimum 8px/16px recommended.`
      });
    }

    if (maxMargin > 0 && maxMargin < 16 && !isButton) {
      issues.push({
        type: 'tight-external-margin',
        ...entry,
        message: `Component has ${maxMargin}px external margin. Minimum 16px recommended for visual breathing room between components.`
      });
    }
  });

  return {
    totalComponents: sampled.length,
    crampedPadding: issues.filter(i => i.type === 'cramped-padding').length,
    crampedButtons: issues.filter(i => i.type === 'cramped-button').length,
    tightMargins: issues.filter(i => i.type === 'tight-external-margin').length,
    measurements: measurements.slice(0, 15),
    issues: issues.slice(0, 20)
  };
})()
```

### 4.5 Vertical Rhythm Consistency

```javascript
(() => {
  const contentElements = document.querySelectorAll('main *, article *, [class*="content"] *, section *');
  const verticalGaps = [];
  const issues = [];

  const blockElements = Array.from(contentElements).filter(el => {
    const style = window.getComputedStyle(el);
    const display = style.display;
    return (display === 'block' || display === 'flex' || display === 'grid' || display === 'list-item') &&
           el.getBoundingClientRect().height > 0;
  }).slice(0, 100);

  for (let i = 0; i < blockElements.length - 1; i++) {
    const r1 = blockElements[i].getBoundingClientRect();
    const r2 = blockElements[i + 1].getBoundingClientRect();

    if (blockElements[i + 1].contains(blockElements[i]) || blockElements[i].contains(blockElements[i + 1])) continue;

    const gap = r2.top - r1.bottom;
    if (gap >= 0 && gap < 200) {
      verticalGaps.push({
        between: `${blockElements[i].tagName.toLowerCase()} → ${blockElements[i + 1].tagName.toLowerCase()}`,
        gap: Math.round(gap)
      });
    }
  }

  const gapValues = verticalGaps.map(g => g.gap).filter(g => g > 0);
  const uniqueGaps = [...new Set(gapValues)].sort((a, b) => a - b);

  const gridAlignedGaps = gapValues.filter(g => g % 4 === 0);
  const rhythmScore = gapValues.length > 0 ? Math.round((gridAlignedGaps.length / gapValues.length) * 100) : 100;

  if (uniqueGaps.length > 8) {
    issues.push({
      type: 'chaotic-vertical-rhythm',
      uniqueGapCount: uniqueGaps.length,
      gaps: uniqueGaps,
      message: `${uniqueGaps.length} unique vertical gap sizes detected. Limit to 3-5 distinct spacing values for consistent rhythm.`
    });
  }

  if (rhythmScore < 60) {
    issues.push({
      type: 'poor-grid-rhythm',
      rhythmScore,
      message: `Only ${rhythmScore}% of vertical gaps align to a 4px grid. Use a consistent spacing scale.`
    });
  }

  return {
    totalGapsMeasured: verticalGaps.length,
    uniqueGapValues: uniqueGaps,
    uniqueGapCount: uniqueGaps.length,
    rhythmScore,
    sampleGaps: verticalGaps.slice(0, 20),
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Does the Page Breathe?**: Is there generous whitespace around the primary content area, or does content run edge-to-edge without relief? The eye needs empty space to rest. A page that breathes has at least 30-40% whitespace. A cramped page makes users feel claustrophobic.

2. **Generous Whitespace Around Primary Element**: Is the hero section, primary card, or main CTA surrounded by significantly more whitespace than other elements? The most important element should have the most breathing room. This creates visual emphasis through space, not just size.

3. **Intentional Rhythm**: When scrolling, does the page have a predictable, pleasant vertical rhythm? Like music, good layout has beats — content blocks appear at regular intervals with consistent spacing. Random spacing creates visual noise.

4. **Density Storytelling**: Does spacing density change intentionally to signal different content zones? Dense spacing for navigation/toolbars signals utility. Generous spacing in hero sections signals importance. Cards with consistent internal padding signal repeating content. Varying density should feel deliberate, not accidental.

5. **Section Separation**: Are different content sections clearly separated? Through whitespace, dividers, background color changes, or a combination? Can you tell where one section ends and another begins without reading the content?

6. **Internal Consistency Within Components**: Do all cards have the same internal padding? Do all list items have the same gap? Do all buttons have the same padding? Within a component type, spacing should be identical. Inconsistency within same-type components signals broken CSS or missing design tokens.

7. **Margin Collapse Awareness**: Are there any sections where elements appear unexpectedly close together (margin collapse) or where spacing between items feels uneven due to margins stacking differently than intended?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | >=90% of spacings follow 8px grid. <=4 unique vertical gap sizes creating clear rhythm. All same-type components have identical spacing. Component padding >=8px. External margins >=16px. Labels within 8px of their inputs. Headings closer to following content than preceding. Page whitespace ratio 30-50%. |
| 4 | >=80% of spacings follow 8px grid. <=6 unique gap sizes. Same-type components have <=1 spacing deviation. Component padding >=6px. Most headings follow proximity principle. Good whitespace ratio. |
| 3 | >=65% of spacings follow 8px grid. 7-8 unique gap sizes — rhythm is inconsistent. Some same-type components differ in spacing. A few cramped components (<8px padding). Headings sometimes closer to preceding content. |
| 2 | <65% grid adherence. >8 unique gap sizes — no discernible rhythm. Multiple component types with inconsistent internal spacing. Several elements with <4px padding. Label-to-input gaps >16px. Page feels either cramped or has random spacing. |
| 1 | No grid adherence. Spacings appear random. No consistency across same-type components. Components have 0-2px padding. No breathing room between sections. Page is either wall-to-wall content or has enormous unexplained gaps. |

## Common Fixes

### Fix: Establish spacing scale (8px base)
```css
:root {
  --space-1: 0.25rem;   /* 4px - hairline */
  --space-2: 0.5rem;    /* 8px - tight */
  --space-3: 0.75rem;   /* 12px - compact */
  --space-4: 1rem;      /* 16px - default */
  --space-5: 1.5rem;    /* 24px - comfortable */
  --space-6: 2rem;      /* 32px - spacious */
  --space-8: 3rem;      /* 48px - section gap */
  --space-10: 4rem;     /* 64px - page section */
  --space-12: 5rem;     /* 80px - hero padding */
  --space-16: 8rem;     /* 128px - major break */
}
```

**Tailwind equivalent:** Use the default spacing scale (p-1 through p-16, m-1 through m-16) which already follows an 8px-aligned system at standard breakpoints.

### Fix: Consistent component padding
```css
.card {
  padding: var(--space-5); /* 24px */
}

.card-compact {
  padding: var(--space-4); /* 16px */
}

button {
  padding: var(--space-2) var(--space-4); /* 8px 16px */
}
```

**Tailwind equivalent:**
```html
<div class="p-6">       <!-- 24px card padding -->
<div class="p-4">       <!-- 16px compact card -->
<button class="py-2 px-4"> <!-- 8px/16px button -->
```

### Fix: Heading proximity (closer to content below)
```css
h2, h3, h4 {
  margin-top: 2.5rem;   /* 40px - space above */
  margin-bottom: 0.75rem; /* 12px - close to content below */
}
```

**Tailwind equivalent:**
```html
<h2 class="mt-10 mb-3">
<h3 class="mt-8 mb-2">
```

### Fix: Section separation
```css
section + section {
  margin-top: var(--space-10); /* 64px between sections */
}

/* Or with dividers */
section + section {
  border-top: 1px solid var(--color-border);
  padding-top: var(--space-8);
  margin-top: var(--space-8);
}
```

**Tailwind equivalent:**
```html
<section class="mt-16">
<section class="border-t border-gray-200 pt-12 mt-12">
```

### Fix: Label-to-input proximity
```css
.form-group label {
  display: block;
  margin-bottom: 0.25rem; /* 4px gap to input */
  font-weight: 500;
}

.form-group + .form-group {
  margin-top: 1.5rem; /* 24px between field groups */
}
```

**Tailwind equivalent:**
```html
<label class="block mb-1 font-medium">
<div class="space-y-6"> <!-- 24px between form groups -->
```
