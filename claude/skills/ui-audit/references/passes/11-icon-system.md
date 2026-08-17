# Pass 11: Icon System

Evaluates the consistency, accessibility, and visual coherence of the icon system. A well-implemented icon system uses a single source library, follows a consistent size scale, aligns properly with adjacent text, and includes appropriate accessibility attributes for both decorative and meaningful icons.

---

## Tier 0: Code Analysis

Perform these checks using Read, Grep, and Glob only (no browser required).

### 0-1. Identify icon sources

Check for icon library packages in package.json or equivalent:

```
pattern: "lucide-react|@heroicons/react|react-icons|@fortawesome|@phosphor-icons|@tabler/icons|ionicons|@mdi|feather-icons|@radix-ui/react-icons|@ant-design/icons"
glob: "package.json"
```

Check for icon font imports:

```
pattern: font-awesome|material-icons|ionicons|icomoon
glob: "*.{css,scss,less,html}"
```

Check for custom SVG icon files:

```
pattern: "*.svg"
paths: "src/icons/**", "src/assets/icons/**", "public/icons/**", "src/components/icons/**"
```

### 0-2. Check for mixed icon sources

If more than one icon library or source type is detected (e.g., lucide-react AND @heroicons/react, or SVG files AND icon fonts), flag as inconsistency. Count imports per source:

```
pattern: import\s+.*\s+from\s+['"]lucide-react
glob: "*.{tsx,jsx,vue,svelte}"
```

```
pattern: import\s+.*\s+from\s+['"]@heroicons
glob: "*.{tsx,jsx,vue,svelte}"
```

Repeat for each detected library. Compare counts — the dominant library should account for >90% of all icon imports.

### 0-3. SVG consistency checks

For SVG icon files, check for consistent attributes:

```
pattern: viewBox="
glob: "*.svg"
```

Extract viewBox values and check if they are uniform (e.g., all `0 0 24 24` or all `0 0 20 20`). Mixed viewBox values indicate icons sourced from different sets.

```
pattern: stroke-width="|strokeWidth[=:]
glob: "*.{svg,tsx,jsx,vue,svelte}"
```

Check stroke-width consistency — icons from the same set typically share a stroke-width (1, 1.5, or 2).

### 0-4. Icon wrapper component check

Look for a shared Icon component that standardizes size, color, and accessibility:

```
pattern: (Icon|IconWrapper|SvgIcon|BaseIcon)\s*[=:({]
glob: "*.{tsx,jsx,vue,svelte}"
```

Check if icon components accept standardized props:

```
pattern: size\s*[=:?]|width\s*[=:?]|height\s*[=:?]|color\s*[=:?]|className\s*[=:?]
glob: "**/Icon*.{tsx,jsx,vue,svelte}"
```

### 0-5. Icon accessibility patterns

Check for proper accessibility attributes on icons:

```
pattern: aria-hidden\s*=\s*["']true["']
glob: "*.{tsx,jsx,vue,svelte,html}"
```

```
pattern: aria-label\s*=\s*["']
glob: "*.{tsx,jsx,vue,svelte,html}"
```

```
pattern: role\s*=\s*["']img["']
glob: "*.{tsx,jsx,vue,svelte,html}"
```

### 0-6. Icon-only buttons without accessible names

Find buttons that contain only icons (no visible text):

```
pattern: <(button|Button)[^>]*>\s*<(svg|Icon|.*Icon)
glob: "*.{tsx,jsx,vue,svelte,html}"
```

For each match, verify the button has `aria-label`, `aria-labelledby`, or a `sr-only`/`visually-hidden` text child. Flag buttons missing all three.

### 0-7. Icon size prop usage

```
pattern: (size|width|height)\s*=\s*[{"]?\d+
glob: "*.{tsx,jsx,vue,svelte}"
```

Extract all icon size values and check if they follow a scale (16, 20, 24, 32, 48) or are arbitrary.

---

## Tier 1: Automated Browser Checks

### Script 1 — measureIconSizes

```javascript
(() => {
  const results = {
    totalIcons: 0,
    sizeDistribution: {},
    dominantSize: null,
    deviations: [],
    followsScale: false,
    sizeScale: [12, 14, 16, 18, 20, 24, 28, 32, 40, 48, 64],
    recommendations: []
  };

  const iconEls = [];

  document.querySelectorAll('svg').forEach(svg => {
    const rect = svg.getBoundingClientRect();
    if (rect.width > 0 && rect.width < 200 && rect.height > 0 && rect.height < 200) {
      iconEls.push({ el: svg, rect, type: 'svg' });
    }
  });

  document.querySelectorAll('i[class], span[class*="icon"], [class*="icon-"], [data-icon]').forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width > 0 && rect.width < 200 && rect.height > 0 && rect.height < 200) {
      const text = el.textContent ? el.textContent.trim() : '';
      if (text.length <= 2 || el.classList.toString().includes('icon')) {
        iconEls.push({ el, rect, type: 'icon-class' });
      }
    }
  });

  results.totalIcons = iconEls.length;
  const sizeMap = new Map();
  const onScale = results.sizeScale;

  iconEls.forEach(({ el, rect, type }) => {
    const w = Math.round(rect.width);
    const h = Math.round(rect.height);
    const size = `${w}x${h}`;

    sizeMap.set(size, (sizeMap.get(size) || 0) + 1);
  });

  const sorted = [...sizeMap.entries()]
    .map(([size, count]) => ({ size, count }))
    .sort((a, b) => b.count - a.count);

  sorted.forEach(entry => {
    results.sizeDistribution[entry.size] = entry.count;
  });

  results.dominantSize = sorted.length > 0 ? sorted[0].size : null;

  const dominantCount = sorted.length > 0 ? sorted[0].count : 0;
  const nonDominant = iconEls.length - dominantCount;

  if (sorted.length > 0) {
    sorted.slice(1).forEach(entry => {
      if (entry.count >= 2) {
        const [w] = entry.size.split('x').map(Number);
        const isOnScale = onScale.some(s => Math.abs(w - s) <= 1);
        if (!isOnScale && results.deviations.length < 10) {
          results.deviations.push({
            size: entry.size,
            count: entry.count,
            onScale: false
          });
        }
      }
    });
  }

  const allSizes = sorted.map(s => parseInt(s.size.split('x')[0]));
  results.followsScale = allSizes.every(s =>
    onScale.some(scale => Math.abs(s - scale) <= 2)
  );

  if (!results.followsScale && sorted.length > 3) {
    results.recommendations.push(
      `Icons use ${sorted.length} different sizes — standardize to a scale (16, 20, 24, 32, 48)`
    );
  }

  if (nonDominant > iconEls.length * 0.4 && sorted.length > 2) {
    results.recommendations.push(
      `Only ${Math.round((dominantCount / iconEls.length) * 100)}% of icons use the dominant size (${results.dominantSize}) — improve size consistency`
    );
  }

  return results;
})();
```

### Script 2 — checkIconAlignment

```javascript
(() => {
  const results = {
    totalIconTextPairs: 0,
    aligned: 0,
    misaligned: 0,
    misalignedSamples: [],
    gapDistribution: {},
    recommendations: []
  };

  const isIconEl = (el) => {
    if (el.tagName === 'SVG' || el.tagName === 'svg') return true;
    if (el.tagName === 'I' && el.classList.length > 0) return true;
    if (el.tagName === 'IMG' && el.getAttribute('src')?.includes('icon')) return true;
    const cls = el.className && typeof el.className === 'string' ? el.className : '';
    return cls.includes('icon') || el.hasAttribute('data-icon');
  };

  const isTextEl = (el) => {
    if (!el.childNodes) return false;
    for (const node of el.childNodes) {
      if (node.nodeType === 3 && node.textContent.trim().length > 0) return true;
    }
    return false;
  };

  const TOLERANCE = 2;

  const flexContainers = document.querySelectorAll('body *');

  flexContainers.forEach(container => {
    const computed = getComputedStyle(container);
    if (!['flex', 'inline-flex'].includes(computed.display)) return;

    const children = [...container.children];
    if (children.length < 2) return;

    for (let i = 0; i < children.length - 1; i++) {
      const a = children[i];
      const b = children[i + 1];

      let iconEl = null;
      let textEl = null;

      if (isIconEl(a) && (isTextEl(b) || b.textContent.trim().length > 0)) {
        iconEl = a;
        textEl = b;
      } else if (isIconEl(b) && (isTextEl(a) || a.textContent.trim().length > 0)) {
        iconEl = b;
        textEl = a;
      }

      if (!iconEl || !textEl) continue;

      results.totalIconTextPairs++;

      const iconRect = iconEl.getBoundingClientRect();
      const textRect = textEl.getBoundingClientRect();

      const iconCenter = iconRect.top + iconRect.height / 2;
      const textCenter = textRect.top + textRect.height / 2;
      const offset = Math.abs(iconCenter - textCenter);

      const gapBetween = Math.abs(
        iconRect.left < textRect.left
          ? textRect.left - iconRect.right
          : iconRect.left - textRect.right
      );
      const gapRounded = `${Math.round(gapBetween)}px`;
      results.gapDistribution[gapRounded] = (results.gapDistribution[gapRounded] || 0) + 1;

      if (offset <= TOLERANCE) {
        results.aligned++;
      } else {
        results.misaligned++;
        if (results.misalignedSamples.length < 15) {
          const tag = container.tagName.toLowerCase();
          const cls = container.className && typeof container.className === 'string'
            ? `.${container.className.split(/\s+/).filter(Boolean).slice(0, 2).join('.')}`
            : '';
          results.misalignedSamples.push({
            container: `${tag}${cls}`,
            iconSize: `${Math.round(iconRect.width)}x${Math.round(iconRect.height)}`,
            textHeight: Math.round(textRect.height),
            verticalOffset: Math.round(offset),
            gap: gapRounded,
            textPreview: textEl.textContent.trim().slice(0, 30)
          });
        }
      }
    }
  });

  if (results.misaligned > results.totalIconTextPairs * 0.2 && results.totalIconTextPairs > 3) {
    results.recommendations.push(
      `${results.misaligned}/${results.totalIconTextPairs} icon-text pairs are vertically misaligned (>2px offset) — use align-items: center on containers or adjust icon vertical-align`
    );
  }

  const gapValues = Object.keys(results.gapDistribution);
  if (gapValues.length > 3) {
    results.recommendations.push(
      `${gapValues.length} different icon-text gap values detected — standardize to 1-2 gap sizes`
    );
  }

  return results;
})();
```

### Script 3 — detectMixedIconSets

```javascript
(() => {
  const results = {
    totalSvgIcons: 0,
    strokeWidths: {},
    fillPatterns: {},
    viewBoxes: {},
    pathComplexity: { simple: 0, medium: 0, complex: 0 },
    isMixed: false,
    dominantStyle: null,
    recommendations: []
  };

  const svgs = document.querySelectorAll('svg');
  const iconSvgs = [];

  svgs.forEach(svg => {
    const rect = svg.getBoundingClientRect();
    if (rect.width > 4 && rect.width < 100 && rect.height > 4 && rect.height < 100) {
      iconSvgs.push(svg);
    }
  });

  results.totalSvgIcons = iconSvgs.length;

  iconSvgs.forEach(svg => {
    const viewBox = svg.getAttribute('viewBox') || 'none';
    results.viewBoxes[viewBox] = (results.viewBoxes[viewBox] || 0) + 1;

    const paths = svg.querySelectorAll('path, line, circle, rect, polyline, polygon');
    let hasStroke = false;
    let hasFill = false;
    let strokeWidth = null;

    paths.forEach(path => {
      const computed = getComputedStyle(path);
      const stroke = computed.stroke;
      const fill = computed.fill;
      const sw = computed.strokeWidth;

      if (stroke && stroke !== 'none' && stroke !== 'rgba(0, 0, 0, 0)') {
        hasStroke = true;
        if (sw) strokeWidth = sw;
      }
      if (fill && fill !== 'none' && fill !== 'rgba(0, 0, 0, 0)') {
        hasFill = true;
      }
    });

    if (strokeWidth) {
      results.strokeWidths[strokeWidth] = (results.strokeWidths[strokeWidth] || 0) + 1;
    }

    const fillPattern = hasFill && hasStroke ? 'mixed' :
      hasFill ? 'filled' :
      hasStroke ? 'stroked' : 'empty';
    results.fillPatterns[fillPattern] = (results.fillPatterns[fillPattern] || 0) + 1;

    const totalPathLength = [...paths]
      .reduce((sum, p) => {
        const d = p.getAttribute('d') || '';
        return sum + d.length;
      }, 0);

    if (totalPathLength < 50) results.pathComplexity.simple++;
    else if (totalPathLength < 200) results.pathComplexity.medium++;
    else results.pathComplexity.complex++;
  });

  const strokeWidthCount = Object.keys(results.strokeWidths).length;
  const fillPatternCount = Object.keys(results.fillPatterns).filter(k => k !== 'empty').length;
  const viewBoxCount = Object.keys(results.viewBoxes).filter(k => k !== 'none').length;

  results.isMixed = strokeWidthCount > 2 || fillPatternCount > 1 || viewBoxCount > 2;

  const fillEntries = Object.entries(results.fillPatterns).sort((a, b) => b[1] - a[1]);
  results.dominantStyle = fillEntries.length > 0 ? fillEntries[0][0] : null;

  if (strokeWidthCount > 2) {
    results.recommendations.push(
      `${strokeWidthCount} different stroke-width values detected across icons (${Object.keys(results.strokeWidths).join(', ')}) — icons likely from different sets. Standardize to one stroke-width.`
    );
  }

  if (fillPatternCount > 1) {
    results.recommendations.push(
      `Mixed fill patterns: ${Object.entries(results.fillPatterns).map(([k, v]) => `${k}(${v})`).join(', ')} — choose one style (stroked or filled) and be consistent`
    );
  }

  if (viewBoxCount > 2) {
    results.recommendations.push(
      `${viewBoxCount} different viewBox values — icons sourced from multiple libraries. Standardize to one viewBox (typically "0 0 24 24")`
    );
  }

  return results;
})();
```

### Script 4 — checkIconAccessibility

```javascript
(() => {
  const results = {
    totalIcons: 0,
    decorativeIcons: { total: 0, properlyHidden: 0, missingAriaHidden: 0 },
    meaningfulIcons: { total: 0, hasLabel: 0, missingLabel: 0 },
    iconOnlyButtons: { total: 0, accessible: 0, inaccessible: 0 },
    samples: { missingAriaHidden: [], missingLabel: [], inaccessibleButtons: [] },
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

  const hasVisibleText = (el) => {
    for (const child of el.childNodes) {
      if (child.nodeType === 3 && child.textContent.trim().length > 0) return true;
      if (child.nodeType === 1) {
        const computed = getComputedStyle(child);
        if (computed.display !== 'none' && computed.visibility !== 'hidden') {
          const cls = child.className && typeof child.className === 'string' ? child.className : '';
          if (cls.includes('sr-only') || cls.includes('visually-hidden') ||
              cls.includes('screen-reader')) continue;
          if (child.textContent && child.textContent.trim().length > 0 &&
              child.tagName !== 'SVG' && child.tagName !== 'svg' &&
              !child.tagName.toLowerCase().startsWith('i')) {
            return true;
          }
        }
      }
    }
    return false;
  };

  const hasSrOnlyText = (el) => {
    const srEls = el.querySelectorAll('.sr-only, .visually-hidden, .screen-reader-text, [class*="sr-only"]');
    return srEls.length > 0 && [...srEls].some(s => s.textContent.trim().length > 0);
  };

  const svgs = document.querySelectorAll('svg');
  svgs.forEach(svg => {
    const rect = svg.getBoundingClientRect();
    if (rect.width <= 0 || rect.width > 100 || rect.height <= 0 || rect.height > 100) return;

    results.totalIcons++;
    const ariaHidden = svg.getAttribute('aria-hidden');
    const ariaLabel = svg.getAttribute('aria-label');
    const ariaLabelledby = svg.getAttribute('aria-labelledby');
    const role = svg.getAttribute('role');
    const title = svg.querySelector('title');

    const isDecorative = ariaHidden === 'true' || (!ariaLabel && !ariaLabelledby && !title && role !== 'img');
    const hasAccessibleName = ariaLabel || ariaLabelledby || (title && title.textContent.trim());

    if (isDecorative) {
      results.decorativeIcons.total++;
      if (ariaHidden === 'true') {
        results.decorativeIcons.properlyHidden++;
      } else {
        results.decorativeIcons.missingAriaHidden++;
        if (results.samples.missingAriaHidden.length < 10) {
          const parent = svg.parentElement;
          results.samples.missingAriaHidden.push({
            selector: selectorFor(svg),
            parentSelector: parent ? selectorFor(parent) : 'none',
            size: `${Math.round(rect.width)}x${Math.round(rect.height)}`
          });
        }
      }
    } else {
      results.meaningfulIcons.total++;
      if (hasAccessibleName) {
        results.meaningfulIcons.hasLabel++;
      } else {
        results.meaningfulIcons.missingLabel++;
        if (results.samples.missingLabel.length < 10) {
          results.samples.missingLabel.push({
            selector: selectorFor(svg),
            size: `${Math.round(rect.width)}x${Math.round(rect.height)}`
          });
        }
      }
    }
  });

  const buttons = document.querySelectorAll('button, [role="button"], a[href]');
  buttons.forEach(btn => {
    const svgChild = btn.querySelector('svg');
    if (!svgChild) return;
    if (hasVisibleText(btn)) return;

    results.iconOnlyButtons.total++;

    const ariaLabel = btn.getAttribute('aria-label');
    const ariaLabelledby = btn.getAttribute('aria-labelledby');
    const title = btn.getAttribute('title');
    const hasSrText = hasSrOnlyText(btn);

    if (ariaLabel || ariaLabelledby || title || hasSrText) {
      results.iconOnlyButtons.accessible++;
    } else {
      results.iconOnlyButtons.inaccessible++;
      if (results.samples.inaccessibleButtons.length < 10) {
        results.samples.inaccessibleButtons.push({
          selector: selectorFor(btn),
          tag: btn.tagName.toLowerCase(),
          classes: btn.className && typeof btn.className === 'string'
            ? btn.className.split(/\s+/).slice(0, 4).join(' ')
            : ''
        });
      }
    }
  });

  if (results.decorativeIcons.missingAriaHidden > 0) {
    results.recommendations.push(
      `${results.decorativeIcons.missingAriaHidden} decorative icons missing aria-hidden="true" — screen readers will attempt to announce them`
    );
  }

  if (results.meaningfulIcons.missingLabel > 0) {
    results.recommendations.push(
      `${results.meaningfulIcons.missingLabel} meaningful icons missing accessible labels (aria-label or <title>) — screen readers cannot convey their meaning`
    );
  }

  if (results.iconOnlyButtons.inaccessible > 0) {
    results.recommendations.push(
      `${results.iconOnlyButtons.inaccessible} icon-only buttons have no accessible name — add aria-label to each`
    );
  }

  return results;
})();
```

### Script 5 — measureIconTextProportion

```javascript
(() => {
  const results = {
    totalPairs: 0,
    wellProportioned: 0,
    tooLarge: 0,
    tooSmall: 0,
    ratioDistribution: {},
    samples: [],
    recommendations: []
  };

  const isIconEl = (el) => {
    if (el.tagName === 'SVG' || el.tagName === 'svg') {
      const rect = el.getBoundingClientRect();
      return rect.width > 4 && rect.width < 100;
    }
    if (el.tagName === 'I' && el.classList.length > 0) return true;
    const cls = el.className && typeof el.className === 'string' ? el.className : '';
    return cls.includes('icon');
  };

  const getTextFontSize = (el) => {
    const computed = getComputedStyle(el);
    return parseFloat(computed.fontSize);
  };

  const allEls = document.querySelectorAll('body *');

  allEls.forEach(container => {
    const children = [...container.children];
    if (children.length < 2) return;

    for (let i = 0; i < children.length; i++) {
      const child = children[i];
      if (!isIconEl(child)) continue;

      const iconRect = child.getBoundingClientRect();
      if (iconRect.width <= 0) continue;
      const iconSize = Math.max(iconRect.width, iconRect.height);

      let textEl = null;
      for (let j = 0; j < children.length; j++) {
        if (j === i) continue;
        const sibling = children[j];
        if (sibling.textContent && sibling.textContent.trim().length > 1 &&
            !isIconEl(sibling)) {
          textEl = sibling;
          break;
        }
      }

      if (!textEl) {
        const parentText = container.textContent ? container.textContent.trim() : '';
        if (parentText.length > 1) {
          textEl = container;
        }
      }

      if (!textEl) continue;

      const fontSize = getTextFontSize(textEl);
      if (fontSize <= 0) continue;

      results.totalPairs++;

      const ratio = Math.round((iconSize / fontSize) * 100) / 100;
      const ratioKey = ratio.toFixed(1);
      results.ratioDistribution[ratioKey] = (results.ratioDistribution[ratioKey] || 0) + 1;

      if (ratio >= 0.75 && ratio <= 1.5) {
        results.wellProportioned++;
      } else if (ratio > 1.5) {
        results.tooLarge++;
      } else {
        results.tooSmall++;
      }

      if (results.samples.length < 20) {
        const tag = container.tagName.toLowerCase();
        const cls = container.className && typeof container.className === 'string'
          ? `.${container.className.split(/\s+/).filter(Boolean).slice(0, 2).join('.')}`
          : '';
        results.samples.push({
          container: `${tag}${cls}`,
          iconSize: Math.round(iconSize),
          textFontSize: Math.round(fontSize),
          ratio,
          assessment: ratio >= 0.75 && ratio <= 1.5 ? 'good' :
            ratio > 1.5 ? 'too-large' : 'too-small',
          textPreview: textEl.textContent.trim().slice(0, 30)
        });
      }
    }
  });

  if (results.tooLarge > results.totalPairs * 0.2 && results.totalPairs > 3) {
    results.recommendations.push(
      `${results.tooLarge} icons are >1.5x the adjacent text size — reduce icon size or increase text size for better proportion`
    );
  }

  if (results.tooSmall > results.totalPairs * 0.2 && results.totalPairs > 3) {
    results.recommendations.push(
      `${results.tooSmall} icons are <0.75x the adjacent text size — icons may be hard to see. Increase icon size`
    );
  }

  return results;
})();
```

---

## Tier 2: AI Evaluation

Examine the screenshots, DOM snapshots, and Tier 0/1 results, then answer each question with a rating (good / acceptable / needs-work) and brief justification.

1. **Visual family** — Do all icons look like they belong to the same family? Is the style consistent (outline vs filled, rounded vs sharp corners, consistent stroke weight)?
2. **Metaphor clarity** — Are icon metaphors clear and universally understood? Would a user immediately recognize what each icon represents?
3. **Redundancy vs value** — Are icons redundant with adjacent text labels (adding visual noise without information), or do they genuinely add meaning and improve scannability?
4. **Size consistency** — Is the icon size scale consistent and proportional to adjacent text across the entire page?
5. **Rendering quality** — Are there any icons that look pixelated, blurry, crisp-but-misaligned, or visually lower quality than others?
6. **Stroke weight consistency** — Is the stroke width uniform across all line-style icons, or do some appear thicker/thinner than others?
7. **Missing icon opportunities** — Are there places where icons would significantly improve scannability or comprehension but are absent?

---

## Scoring Criteria

| Score | Criteria |
|-------|----------|
| **5** | Single icon set with consistent style. All sizes follow a defined scale. Proper accessibility (aria-hidden on decorative, aria-label on meaningful, all icon-only buttons labeled). Icons vertically centered with text. Consistent stroke-width. |
| **4** | Mostly consistent icon set with minor alignment issues. Accessibility mostly covered with a few gaps. Sizes are consistent with 1-2 outliers. |
| **3** | Some mixed icon sources but visually similar enough. Inconsistent sizes in places. Accessibility coverage is partial (>50% of icons properly attributed). |
| **2** | Multiple icon sets with visibly different styles. No consistent size system. Most icons lack accessibility attributes. Poor vertical alignment with text. |
| **1** | No icon consistency — mixed fonts, SVGs, and image sprites. Random sizes. Zero accessibility. Misaligned throughout. |

---

## Common Fixes

### Standardize icon size to a scale

```tsx
/* Before — arbitrary sizes */
<SearchIcon width={18} height={18} />
<UserIcon width={22} height={22} />
<MenuIcon width={26} height={26} />

/* After — size scale via shared component */
<Icon name="search" size="sm" />   {/* 16px */}
<Icon name="user" size="md" />     {/* 24px */}
<Icon name="menu" size="md" />     {/* 24px */}
```

### Add aria-hidden to decorative icons

```tsx
/* Before */
<button>
  <SaveIcon />
  Save Document
</button>

/* After — icon is decorative because text provides the label */
<button>
  <SaveIcon aria-hidden="true" />
  Save Document
</button>
```

### Add aria-label to icon-only buttons

```tsx
/* Before — no accessible name */
<button><TrashIcon /></button>

/* After */
<button aria-label="Delete item"><TrashIcon aria-hidden="true" /></button>
```

### Fix vertical alignment of icons with text

```css
/* Before — icons sit above or below text baseline */
.nav-item svg { /* no alignment */ }

/* After */
.nav-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.nav-item svg {
  flex-shrink: 0;
}
```

### Normalize stroke-width across icons

```css
/* Apply consistent stroke-width to all icon SVGs */
.icon svg,
svg.icon {
  stroke-width: 1.5;
}
```

### Wrap icons in a shared Icon component

```tsx
/* Before — direct library usage scattered everywhere */
import { Search } from 'lucide-react';
<Search size={24} className="text-gray-500" />

/* After — centralized Icon component */
import { Icon } from '@/components/ui/Icon';
<Icon name="search" size="md" color="muted" />

/* Icon.tsx */
const sizes = { sm: 16, md: 24, lg: 32 };
const colors = { default: 'currentColor', muted: 'var(--color-muted)' };

function Icon({ name, size = 'md', color = 'default', className, ...props }) {
  const IconComponent = iconMap[name];
  return (
    <IconComponent
      width={sizes[size]}
      height={sizes[size]}
      color={colors[color]}
      aria-hidden="true"
      className={className}
      {...props}
    />
  );
}
```
