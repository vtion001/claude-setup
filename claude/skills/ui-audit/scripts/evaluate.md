# Reusable browser_evaluate Script Library

Shared IIFE scripts used across multiple `/ui-audit` passes. Each script is self-contained,
returns JSON, and can be passed directly to Playwright's `page.evaluate()` or the
`browser_evaluate` MCP tool.

Reference these scripts from SKILL.md pass definitions instead of duplicating evaluation logic.

---

## 1. getComputedStylesForAll

Extracts computed styles for all visible elements on the page. Used by passes 01 (tokens),
02 (CSS architecture), 07 (color), and 08 (typography).

```javascript
/**
 * @returns {Array<{selector: string, tagName: string, styles: Object}>}
 * styles includes: color, backgroundColor, fontSize, fontFamily, fontWeight,
 * padding, margin, border, borderRadius, lineHeight, gap
 */
(() => {
  const STYLE_PROPS = [
    'color', 'backgroundColor', 'fontSize', 'fontFamily', 'fontWeight',
    'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft',
    'marginTop', 'marginRight', 'marginBottom', 'marginLeft',
    'borderTopWidth', 'borderRightWidth', 'borderBottomWidth', 'borderLeftWidth',
    'borderTopColor', 'borderRightColor', 'borderBottomColor', 'borderLeftColor',
    'borderTopLeftRadius', 'borderTopRightRadius', 'borderBottomLeftRadius', 'borderBottomRightRadius',
    'lineHeight', 'gap', 'rowGap', 'columnGap'
  ];

  const results = [];
  const elements = document.querySelectorAll('body *');

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    if (getComputedStyle(el).display === 'none') continue;
    if (getComputedStyle(el).visibility === 'hidden') continue;

    const computed = getComputedStyle(el);
    const styles = {};
    for (const prop of STYLE_PROPS) {
      styles[prop] = computed[prop];
    }

    let selector = el.tagName.toLowerCase();
    if (el.id) selector += '#' + el.id;
    if (el.className && typeof el.className === 'string') {
      const classes = el.className.trim().split(/\s+/).slice(0, 3).join('.');
      if (classes) selector += '.' + classes;
    }

    results.push({ selector, tagName: el.tagName, styles });
  }

  return results;
})()
```

---

## 2. measureElementSizes

Gets bounding rectangles for all visible elements. Used by passes 05 (Gestalt),
06 (visual balance), and 10 (grid/layout).

```javascript
/**
 * @returns {Array<{selector: string, tagName: string, rect: {x: number, y: number, width: number, height: number}}>}
 */
(() => {
  const results = [];
  const elements = document.querySelectorAll('body *');

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    if (getComputedStyle(el).display === 'none') continue;

    let selector = el.tagName.toLowerCase();
    if (el.id) selector += '#' + el.id;
    if (el.className && typeof el.className === 'string') {
      const classes = el.className.trim().split(/\s+/).slice(0, 3).join('.');
      if (classes) selector += '.' + classes;
    }

    results.push({
      selector,
      tagName: el.tagName,
      rect: {
        x: Math.round(rect.x * 100) / 100,
        y: Math.round(rect.y * 100) / 100,
        width: Math.round(rect.width * 100) / 100,
        height: Math.round(rect.height * 100) / 100
      }
    });
  }

  return results;
})()
```

---

## 3. getColorPalette

Extracts all unique colors from the page across multiple properties. Used by passes
07 (color system) and 01 (design tokens).

```javascript
/**
 * @returns {{colors: Array<{value: string, count: number, elements: string[]}>, uniqueCount: number, uniqueHues: number}}
 */
(() => {
  const COLOR_PROPS = ['color', 'backgroundColor', 'borderTopColor', 'borderRightColor',
    'borderBottomColor', 'borderLeftColor', 'outlineColor'];
  const colorMap = new Map();
  const elements = document.querySelectorAll('body *');

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    const computed = getComputedStyle(el);
    if (computed.display === 'none') continue;

    let selector = el.tagName.toLowerCase();
    if (el.id) selector += '#' + el.id;

    for (const prop of COLOR_PROPS) {
      const val = computed[prop];
      if (!val || val === 'rgba(0, 0, 0, 0)' || val === 'transparent') continue;

      if (!colorMap.has(val)) {
        colorMap.set(val, { value: val, count: 0, elements: [] });
      }
      const entry = colorMap.get(val);
      entry.count++;
      if (entry.elements.length < 5) entry.elements.push(selector);
    }
  }

  const svgs = document.querySelectorAll('svg, svg *');
  for (const el of svgs) {
    const computed = getComputedStyle(el);
    for (const prop of ['fill', 'stroke']) {
      const val = computed[prop];
      if (!val || val === 'none' || val === 'rgba(0, 0, 0, 0)' || val === 'transparent') continue;
      if (!colorMap.has(val)) {
        colorMap.set(val, { value: val, count: 0, elements: [] });
      }
      const entry = colorMap.get(val);
      entry.count++;
      if (entry.elements.length < 5) entry.elements.push('svg');
    }
  }

  const colors = Array.from(colorMap.values()).sort((a, b) => b.count - a.count);

  const hueSet = new Set();
  for (const c of colors) {
    const match = c.value.match(/^rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
    if (match) {
      const [, r, g, b] = match.map(Number);
      const max = Math.max(r, g, b), min = Math.min(r, g, b);
      if (max - min > 10) {
        let h = 0;
        const d = max - min;
        if (max === r) h = ((g - b) / d) % 6;
        else if (max === g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h = Math.round(h * 60);
        if (h < 0) h += 360;
        hueSet.add(Math.round(h / 30) * 30);
      }
    }
  }

  return { colors, uniqueCount: colors.length, uniqueHues: hueSet.size };
})()
```

---

## 4. getTypographyMap

Extracts all unique typography combinations. Used by passes 08 (type system) and
01 (design tokens).

```javascript
/**
 * @returns {Array<{fontSize: string, fontFamily: string, fontWeight: string, lineHeight: string, letterSpacing: string, count: number, elements: string[]}>}
 * Sorted by frequency (most common first)
 */
(() => {
  const typoMap = new Map();
  const elements = document.querySelectorAll('body *');

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    const computed = getComputedStyle(el);
    if (computed.display === 'none') continue;

    const hasText = el.childNodes.length > 0 &&
      Array.from(el.childNodes).some(n => n.nodeType === 3 && n.textContent.trim());
    if (!hasText) continue;

    const key = [
      computed.fontSize,
      computed.fontFamily.split(',')[0].trim().replace(/['"]/g, ''),
      computed.fontWeight,
      computed.lineHeight,
      computed.letterSpacing
    ].join('|');

    if (!typoMap.has(key)) {
      typoMap.set(key, {
        fontSize: computed.fontSize,
        fontFamily: computed.fontFamily.split(',')[0].trim().replace(/['"]/g, ''),
        fontWeight: computed.fontWeight,
        lineHeight: computed.lineHeight,
        letterSpacing: computed.letterSpacing,
        count: 0,
        elements: []
      });
    }

    const entry = typoMap.get(key);
    entry.count++;
    if (entry.elements.length < 5) {
      let selector = el.tagName.toLowerCase();
      if (el.id) selector += '#' + el.id;
      if (el.className && typeof el.className === 'string') {
        const cls = el.className.trim().split(/\s+/).slice(0, 2).join('.');
        if (cls) selector += '.' + cls;
      }
      entry.elements.push(selector);
    }
  }

  return Array.from(typoMap.values()).sort((a, b) => b.count - a.count);
})()
```

---

## 5. getSpacingMap

Extracts all spacing values (padding, margin, gap). Used by passes 01 (tokens),
10 (grid/layout), and 06 (visual balance).

```javascript
/**
 * @returns {{values: Array<{value: string, count: number, property: string}>, gridAlignment: number}}
 * gridAlignment: percentage of values that align to a 4px or 8px grid
 */
(() => {
  const SPACING_PROPS = [
    'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft',
    'marginTop', 'marginRight', 'marginBottom', 'marginLeft',
    'gap', 'rowGap', 'columnGap'
  ];

  const spacingMap = new Map();
  let totalValues = 0;
  let gridAligned = 0;
  const elements = document.querySelectorAll('body *');

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    const computed = getComputedStyle(el);
    if (computed.display === 'none') continue;

    for (const prop of SPACING_PROPS) {
      const val = computed[prop];
      if (!val || val === '0px' || val === 'auto' || val === 'normal') continue;

      const key = val + '|' + prop.replace(/Top|Right|Bottom|Left/, '');
      if (!spacingMap.has(key)) {
        spacingMap.set(key, {
          value: val,
          count: 0,
          property: prop.replace(/Top|Right|Bottom|Left/, '')
        });
      }
      spacingMap.get(key).count++;

      totalValues++;
      const px = parseFloat(val);
      if (!isNaN(px) && (px % 4 === 0 || px % 8 === 0)) {
        gridAligned++;
      }
    }
  }

  const values = Array.from(spacingMap.values()).sort((a, b) => b.count - a.count);
  const gridAlignment = totalValues > 0 ? Math.round((gridAligned / totalValues) * 100) : 0;

  return { values, gridAlignment };
})()
```

---

## 6. getLayoutStructure

Maps all flex and grid containers with their properties. Used by passes 10 (grid/layout)
and 09 (atomic design).

```javascript
/**
 * @returns {Array<{selector: string, display: string, direction: string, wrap: string, gap: string, alignItems: string, justifyContent: string, childCount: number, gridTemplateColumns: string, gridTemplateRows: string}>}
 */
(() => {
  const results = [];
  const elements = document.querySelectorAll('body *');

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    const computed = getComputedStyle(el);
    const display = computed.display;

    if (!display.includes('flex') && !display.includes('grid')) continue;

    let selector = el.tagName.toLowerCase();
    if (el.id) selector += '#' + el.id;
    if (el.className && typeof el.className === 'string') {
      const classes = el.className.trim().split(/\s+/).slice(0, 3).join('.');
      if (classes) selector += '.' + classes;
    }

    const entry = {
      selector,
      display,
      direction: computed.flexDirection || 'n/a',
      wrap: computed.flexWrap || 'n/a',
      gap: computed.gap,
      alignItems: computed.alignItems,
      justifyContent: computed.justifyContent,
      childCount: el.children.length,
      gridTemplateColumns: 'n/a',
      gridTemplateRows: 'n/a'
    };

    if (display.includes('grid')) {
      entry.gridTemplateColumns = computed.gridTemplateColumns;
      entry.gridTemplateRows = computed.gridTemplateRows;
    }

    results.push(entry);
  }

  return results;
})()
```

---

## 7. getInteractiveElements

Finds all interactive elements and their state information. Used by passes 03 (component
quality) and 12 (UI state coverage).

```javascript
/**
 * @returns {Array<{selector: string, tagName: string, type: string, role: string, disabled: boolean, ariaDisabled: boolean, cursor: string, hasFocusStyle: boolean, hasAriaLabel: boolean, tabIndex: number, text: string}>}
 */
(() => {
  const INTERACTIVE_SELECTORS = [
    'button', 'a[href]', 'input', 'select', 'textarea',
    '[role="button"]', '[role="link"]', '[role="checkbox"]', '[role="radio"]',
    '[role="tab"]', '[role="menuitem"]', '[role="switch"]',
    '[tabindex]:not([tabindex="-1"])'
  ].join(', ');

  const results = [];
  const elements = document.querySelectorAll(INTERACTIVE_SELECTORS);

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    const computed = getComputedStyle(el);
    if (computed.display === 'none') continue;

    let selector = el.tagName.toLowerCase();
    if (el.id) selector += '#' + el.id;
    if (el.className && typeof el.className === 'string') {
      const classes = el.className.trim().split(/\s+/).slice(0, 3).join('.');
      if (classes) selector += '.' + classes;
    }

    let hasFocusStyle = false;
    try {
      const beforeOutline = computed.outlineStyle;
      const beforeBoxShadow = computed.boxShadow;
      el.focus();
      const afterComputed = getComputedStyle(el);
      hasFocusStyle = afterComputed.outlineStyle !== 'none' ||
        afterComputed.boxShadow !== beforeBoxShadow ||
        afterComputed.outlineStyle !== beforeOutline;
      el.blur();
    } catch (e) {
      hasFocusStyle = false;
    }

    results.push({
      selector,
      tagName: el.tagName,
      type: el.type || 'n/a',
      role: el.getAttribute('role') || 'implicit',
      disabled: el.disabled || false,
      ariaDisabled: el.getAttribute('aria-disabled') === 'true',
      cursor: computed.cursor,
      hasFocusStyle,
      hasAriaLabel: !!(el.getAttribute('aria-label') || el.getAttribute('aria-labelledby')),
      tabIndex: el.tabIndex,
      text: (el.textContent || '').trim().substring(0, 50)
    });
  }

  return results;
})()
```

---

## 8. getCSSCustomProperties

Extracts all CSS custom properties (design tokens) from stylesheets and computed styles.
Used by passes 01 (design tokens) and 07 (color system).

```javascript
/**
 * @returns {{defined: Array<{name: string, value: string, source: string}>, used: Array<{name: string, count: number}>, totalDefined: number, totalUsed: number}}
 */
(() => {
  const defined = [];
  const usedMap = new Map();

  for (const sheet of document.styleSheets) {
    try {
      const rules = sheet.cssRules || sheet.rules;
      if (!rules) continue;

      for (const rule of rules) {
        if (rule.style) {
          for (let i = 0; i < rule.style.length; i++) {
            const prop = rule.style[i];
            if (prop.startsWith('--')) {
              defined.push({
                name: prop,
                value: rule.style.getPropertyValue(prop).trim(),
                source: rule.selectorText || ':root'
              });
            }

            const val = rule.style.getPropertyValue(prop);
            if (val && val.includes('var(--')) {
              const matches = val.match(/var\(--[^,)]+/g);
              if (matches) {
                for (const m of matches) {
                  const varName = m.replace('var(', '').trim();
                  usedMap.set(varName, (usedMap.get(varName) || 0) + 1);
                }
              }
            }
          }
        }

        if (rule.cssRules) {
          for (const innerRule of rule.cssRules) {
            if (innerRule.style) {
              for (let i = 0; i < innerRule.style.length; i++) {
                const prop = innerRule.style[i];
                if (prop.startsWith('--')) {
                  defined.push({
                    name: prop,
                    value: innerRule.style.getPropertyValue(prop).trim(),
                    source: innerRule.selectorText || '@media'
                  });
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // Cross-origin stylesheet, skip
    }
  }

  const rootStyles = getComputedStyle(document.documentElement);
  for (let i = 0; i < rootStyles.length; i++) {
    const prop = rootStyles[i];
    if (prop.startsWith('--')) {
      const exists = defined.find(d => d.name === prop && d.source === ':root');
      if (!exists) {
        defined.push({
          name: prop,
          value: rootStyles.getPropertyValue(prop).trim(),
          source: ':root (computed)'
        });
      }
    }
  }

  const used = Array.from(usedMap.entries())
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count);

  return {
    defined,
    used,
    totalDefined: defined.length,
    totalUsed: used.length
  };
})()
```

---

## 9. getAccessibilityTree

Builds a simplified accessibility tree. Used by passes 03 (component quality) and
11 (icon system).

```javascript
/**
 * @returns {{headings: Array, landmarks: Array, images: Array, forms: Array, focusOrder: Array}}
 */
(() => {
  const headings = [];
  document.querySelectorAll('h1, h2, h3, h4, h5, h6, [role="heading"]').forEach(el => {
    if (getComputedStyle(el).display === 'none') return;
    headings.push({
      level: el.tagName.match(/H(\d)/) ? parseInt(el.tagName[1]) : parseInt(el.getAttribute('aria-level') || '2'),
      text: (el.textContent || '').trim().substring(0, 100),
      selector: el.tagName.toLowerCase() + (el.id ? '#' + el.id : '')
    });
  });

  const landmarks = [];
  const LANDMARK_SELECTORS = 'header, footer, main, nav, aside, section[aria-label], section[aria-labelledby], [role="banner"], [role="navigation"], [role="main"], [role="complementary"], [role="contentinfo"], [role="search"], [role="form"], [role="region"][aria-label]';
  document.querySelectorAll(LANDMARK_SELECTORS).forEach(el => {
    if (getComputedStyle(el).display === 'none') return;
    landmarks.push({
      role: el.getAttribute('role') || el.tagName.toLowerCase(),
      label: el.getAttribute('aria-label') || el.getAttribute('aria-labelledby') || 'unlabeled',
      tagName: el.tagName.toLowerCase()
    });
  });

  const images = [];
  document.querySelectorAll('img, [role="img"], svg[aria-label]').forEach(el => {
    if (getComputedStyle(el).display === 'none') return;
    images.push({
      src: el.src ? el.src.substring(0, 100) : 'svg',
      alt: el.getAttribute('alt'),
      hasAlt: el.hasAttribute('alt'),
      ariaLabel: el.getAttribute('aria-label') || null,
      ariaHidden: el.getAttribute('aria-hidden') === 'true',
      role: el.getAttribute('role') || 'img',
      decorative: el.getAttribute('alt') === '' || el.getAttribute('aria-hidden') === 'true'
    });
  });

  const forms = [];
  document.querySelectorAll('input, select, textarea').forEach(el => {
    if (getComputedStyle(el).display === 'none') return;
    const id = el.id;
    const label = id ? document.querySelector(`label[for="${id}"]`) : null;
    const ariaLabel = el.getAttribute('aria-label');
    const ariaLabelledby = el.getAttribute('aria-labelledby');
    const placeholder = el.getAttribute('placeholder');

    forms.push({
      type: el.type || el.tagName.toLowerCase(),
      id: id || null,
      hasLabel: !!label,
      labelText: label ? label.textContent.trim().substring(0, 50) : null,
      ariaLabel: ariaLabel || null,
      ariaLabelledby: ariaLabelledby || null,
      placeholder: placeholder || null,
      hasAccessibleName: !!(label || ariaLabel || ariaLabelledby),
      required: el.required || el.getAttribute('aria-required') === 'true'
    });
  });

  const focusOrder = [];
  const focusable = document.querySelectorAll(
    'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
  );
  focusable.forEach((el, index) => {
    if (getComputedStyle(el).display === 'none') return;
    const rect = el.getBoundingClientRect();
    focusOrder.push({
      index,
      tagName: el.tagName.toLowerCase(),
      text: (el.textContent || el.getAttribute('aria-label') || '').trim().substring(0, 30),
      tabIndex: el.tabIndex,
      y: Math.round(rect.y),
      x: Math.round(rect.x)
    });
  });

  return { headings, landmarks, images, forms, focusOrder };
})()
```

---

## 10. getBreakpointInfo

Returns current viewport information and detected breakpoint range. Used by all visual
passes and cross-viewport comparison.

```javascript
/**
 * @returns {{width: number, height: number, devicePixelRatio: number, orientation: string, breakpoint: string, scrollHeight: number, scrollWidth: number}}
 */
(() => {
  const width = window.innerWidth;
  const height = window.innerHeight;

  let breakpoint = 'unknown';
  if (width < 480) breakpoint = 'mobile-sm';
  else if (width < 640) breakpoint = 'mobile';
  else if (width < 768) breakpoint = 'mobile-lg';
  else if (width < 1024) breakpoint = 'tablet';
  else if (width < 1280) breakpoint = 'desktop';
  else if (width < 1536) breakpoint = 'desktop-lg';
  else breakpoint = 'wide';

  return {
    width,
    height,
    devicePixelRatio: window.devicePixelRatio || 1,
    orientation: width > height ? 'landscape' : 'portrait',
    breakpoint,
    scrollHeight: document.documentElement.scrollHeight,
    scrollWidth: document.documentElement.scrollWidth,
    hasHorizontalOverflow: document.documentElement.scrollWidth > width
  };
})()
```

---

## 11. getAnimations

Finds all elements with CSS transitions or animations. Used by pass 04 (visual regression)
and pass 03 (component quality).

```javascript
/**
 * @returns {Array<{selector: string, type: string, property: string, duration: string, timingFunction: string, delay: string, animationName: string, iterationCount: string}>}
 */
(() => {
  const results = [];
  const elements = document.querySelectorAll('body *');

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    const computed = getComputedStyle(el);
    if (computed.display === 'none') continue;

    let selector = el.tagName.toLowerCase();
    if (el.id) selector += '#' + el.id;
    if (el.className && typeof el.className === 'string') {
      const classes = el.className.trim().split(/\s+/).slice(0, 3).join('.');
      if (classes) selector += '.' + classes;
    }

    const transitionProp = computed.transitionProperty;
    const transitionDur = computed.transitionDuration;
    if (transitionProp && transitionProp !== 'none' && transitionDur && transitionDur !== '0s') {
      const props = transitionProp.split(',').map(p => p.trim());
      const durations = transitionDur.split(',').map(d => d.trim());
      const timings = (computed.transitionTimingFunction || '').split(',').map(t => t.trim());
      const delays = (computed.transitionDelay || '').split(',').map(d => d.trim());

      for (let i = 0; i < props.length; i++) {
        results.push({
          selector,
          type: 'transition',
          property: props[i],
          duration: durations[i % durations.length] || '0s',
          timingFunction: timings[i % timings.length] || 'ease',
          delay: delays[i % delays.length] || '0s',
          animationName: 'n/a',
          iterationCount: 'n/a'
        });
      }
    }

    const animName = computed.animationName;
    const animDur = computed.animationDuration;
    if (animName && animName !== 'none' && animDur && animDur !== '0s') {
      const names = animName.split(',').map(n => n.trim());
      const durations = animDur.split(',').map(d => d.trim());
      const timings = (computed.animationTimingFunction || '').split(',').map(t => t.trim());
      const delays = (computed.animationDelay || '').split(',').map(d => d.trim());
      const iterations = (computed.animationIterationCount || '').split(',').map(c => c.trim());

      for (let i = 0; i < names.length; i++) {
        results.push({
          selector,
          type: 'animation',
          property: 'animation',
          duration: durations[i % durations.length] || '0s',
          timingFunction: timings[i % timings.length] || 'ease',
          delay: delays[i % delays.length] || '0s',
          animationName: names[i],
          iterationCount: iterations[i % iterations.length] || '1'
        });
      }
    }
  }

  return results;
})()
```

---

## 12. getSVGInfo

Analyzes all SVG elements for icon system consistency. Used by pass 11 (icon system)
and pass 03 (component quality).

```javascript
/**
 * @returns {{svgs: Array<{selector: string, viewBox: string, width: string, height: string, fill: string, stroke: string, strokeWidth: string, ariaLabel: string, ariaHidden: boolean, role: string, childCount: number, source: string}>, patterns: {sizes: Object, fills: string[], strokes: string[], libraries: string[]}}}
 */
(() => {
  const svgs = [];
  const sizeMap = {};
  const fillSet = new Set();
  const strokeSet = new Set();
  const libraryHints = new Set();

  const elements = document.querySelectorAll('svg');

  for (const el of elements) {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;
    const computed = getComputedStyle(el);
    if (computed.display === 'none') continue;

    let selector = 'svg';
    if (el.id) selector += '#' + el.id;
    if (el.className && el.className.baseVal) {
      const classes = el.className.baseVal.trim().split(/\s+/).slice(0, 3).join('.');
      if (classes) selector += '.' + classes;
    }

    const viewBox = el.getAttribute('viewBox') || 'none';
    const width = el.getAttribute('width') || computed.width || 'auto';
    const height = el.getAttribute('height') || computed.height || 'auto';
    const fill = computed.fill || 'none';
    const stroke = computed.stroke || 'none';
    const strokeWidth = computed.strokeWidth || '0';

    let source = 'custom';
    const classList = el.className.baseVal || '';
    const parentClasses = el.parentElement ? (el.parentElement.className || '') : '';
    const allClasses = classList + ' ' + parentClasses;
    if (allClasses.includes('lucide')) source = 'lucide';
    else if (allClasses.includes('heroicon')) source = 'heroicons';
    else if (allClasses.includes('feather')) source = 'feather';
    else if (allClasses.includes('fa-') || allClasses.includes('font-awesome')) source = 'font-awesome';
    else if (allClasses.includes('material')) source = 'material-icons';
    else if (allClasses.includes('tabler')) source = 'tabler';
    else if (allClasses.includes('phosphor')) source = 'phosphor';
    else if (el.querySelector('use')) source = 'sprite';

    libraryHints.add(source);

    const sizeKey = Math.round(rect.width) + 'x' + Math.round(rect.height);
    sizeMap[sizeKey] = (sizeMap[sizeKey] || 0) + 1;

    if (fill !== 'none' && fill !== 'rgba(0, 0, 0, 0)') fillSet.add(fill);
    if (stroke !== 'none' && stroke !== 'rgba(0, 0, 0, 0)') strokeSet.add(stroke);

    svgs.push({
      selector,
      viewBox,
      width,
      height,
      fill,
      stroke,
      strokeWidth,
      ariaLabel: el.getAttribute('aria-label') || '',
      ariaHidden: el.getAttribute('aria-hidden') === 'true',
      role: el.getAttribute('role') || 'none',
      childCount: el.children.length,
      source,
      renderedSize: sizeKey
    });
  }

  return {
    svgs,
    totalCount: svgs.length,
    patterns: {
      sizes: sizeMap,
      fills: Array.from(fillSet),
      strokes: Array.from(strokeSet),
      libraries: Array.from(libraryHints),
      multipleLibraries: libraryHints.size > 1
    }
  };
})()
```

---

## Usage Notes

### Calling from SKILL.md Pass Definitions

Reference scripts by name in pass instructions:

```
Run evaluate script: getComputedStylesForAll
Store result as: tier1_styles
```

### Combining Scripts

For passes that need data from multiple scripts, call them sequentially and merge results
in the analysis phase. Do not combine scripts into a single evaluate call -- keep them
modular for reuse.

### Performance Considerations

- `getComputedStylesForAll` is the heaviest script. On pages with 1000+ elements, it may
  take 2-3 seconds. Use it once and cache the result for the session.
- `getInteractiveElements` triggers focus/blur on each element. This is safe but may cause
  brief visual flicker in headed mode.
- All scripts filter out `display: none` and zero-size elements to avoid noise.
- Selectors are truncated to 3 classes maximum to keep output size manageable.

### Return Size Limits

If a page has thousands of elements, these scripts may return large JSON payloads. The
skill should truncate results to the top 500 elements when the full dataset is not needed
for scoring.
