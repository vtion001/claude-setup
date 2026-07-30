# Pass 1: Design Token Audit

Evaluates whether the project uses a systematic design token layer for colors, typography, spacing, and other visual primitives. A healthy token system reduces one-off values, enables theming, and keeps the UI consistent as it scales.

---

## Tier 0: Code Analysis

Perform these checks using Read, Grep, and Glob only (no browser required).

### 0-1. Hardcoded hex colors
Grep all source files for raw hex color values that are not inside a token definition file.

```
pattern: #[0-9a-fA-F]{3,8}\b
glob: "*.{css,scss,less,tsx,jsx,vue,svelte,html}"
```

Exclude files whose path contains `token`, `theme`, `variable`, `palette`, or `tailwind.config`. Count remaining matches as **hardcoded color violations**.

### 0-2. Hardcoded px in inline styles
Grep for inline `style` attributes or style objects containing raw pixel values.

```
pattern: style\s*=\s*[{"].*?\d+px
glob: "*.{tsx,jsx,vue,svelte,html}"
```

### 0-3. Hardcoded font-family strings
Grep for font-family declarations outside token/theme files.

```
pattern: font-family\s*:\s*['"]?[A-Z]
glob: "*.{css,scss,less,tsx,jsx,vue,svelte}"
```

Exclude files containing `token`, `theme`, `variable`, or `tailwind.config` in the path.

### 0-4. CSS custom property definitions
Count all `--*` custom property definitions across the codebase.

```
pattern: --[\w-]+\s*:
glob: "*.{css,scss,less}"
```

Separately count definitions in `:root` / `[data-theme]` blocks (global tokens) vs component-scoped definitions.

### 0-5. Tailwind config detection
Glob for `tailwind.config.{js,ts,mjs,cjs}`. If found, read the `theme.extend` section and catalog:
- Custom colors added
- Custom spacing scale entries
- Custom font families
- Custom breakpoints

### 0-6. SCSS/Less variable detection
Grep for preprocessor variable definitions.

```
pattern: \$[\w-]+\s*:          // SCSS
pattern: @[\w-]+\s*:           // Less
glob: "*.{scss,less}"
```

### 0-7. Token adoption rate calculation
Compute: `(uses of var(--*) + uses of theme tokens) / (total color/spacing/font declarations) * 100`

Grep counts needed:
- `var\(--` across all CSS/component files = token usage count
- `#[0-9a-fA-F]{3,8}` outside token files = hardcoded color count
- `\d+px` in style declarations outside token files = hardcoded spacing count
- Token adoption = token usage / (token usage + hardcoded) * 100

### 0-8. DTCG spec adherence
Search for JSON token files following the Design Token Community Group format.

```
glob: "*.tokens.json", "tokens.json", "tokens/*.json"
```

If found, check for `$value` and `$type` keys (DTCG spec). Flag files using non-standard formats (e.g., `value` without `$` prefix).

### 0-9. Orphaned token definitions
For every `--*` custom property defined, grep for its usage across the codebase. Tokens defined but never referenced in `var(--*)` calls are orphaned.

```
# For each token name found in 0-4:
pattern: var\(--token-name\)
```

Report orphaned tokens as waste / cleanup candidates.

---

## Tier 1: Automated Browser Checks

### 1.1 extractComputedTokens

```javascript
(() => {
  const result = {
    scriptId: 'extractComputedTokens',
    timestamp: new Date().toISOString(),
    rootTokens: [],
    bodyTokens: [],
    totalUniqueTokens: 0,
    tokensByCategory: { color: [], spacing: [], typography: [], other: [] },
    duplicateValues: []
  };

  const categorizeName = (name) => {
    const n = name.toLowerCase();
    if (/color|bg|background|border-color|text|foreground|accent|primary|secondary|destructive|muted|popover|card/.test(n)) return 'color';
    if (/space|gap|margin|padding|radius|size|width|height|inset/.test(n)) return 'spacing';
    if (/font|text|letter|line-height|tracking|leading|weight/.test(n)) return 'typography';
    return 'other';
  };

  const extractFromElement = (el, label) => {
    const styles = getComputedStyle(el);
    const tokens = [];
    for (let i = 0; i < styles.length; i++) {
      const prop = styles[i];
      if (prop.startsWith('--')) {
        const value = styles.getPropertyValue(prop).trim();
        tokens.push({ name: prop, value, source: label });
      }
    }
    return tokens;
  };

  const rootEl = document.documentElement;
  const bodyEl = document.body;

  result.rootTokens = extractFromElement(rootEl, ':root');
  result.bodyTokens = extractFromElement(bodyEl, 'body');

  const allTokens = [...result.rootTokens, ...result.bodyTokens];
  const seen = new Map();
  allTokens.forEach(t => {
    if (!seen.has(t.name)) seen.set(t.name, t);
  });
  result.totalUniqueTokens = seen.size;

  seen.forEach((token) => {
    const category = categorizeName(token.name);
    result.tokensByCategory[category].push({
      name: token.name,
      value: token.value
    });
  });

  const valueMap = new Map();
  seen.forEach((token) => {
    const v = token.value;
    if (!valueMap.has(v)) valueMap.set(v, []);
    valueMap.get(v).push(token.name);
  });
  valueMap.forEach((names, value) => {
    if (names.length > 1) {
      result.duplicateValues.push({ value, tokens: names, count: names.length });
    }
  });
  result.duplicateValues.sort((a, b) => b.count - a.count);

  result.summary = {
    totalTokens: result.totalUniqueTokens,
    colorTokens: result.tokensByCategory.color.length,
    spacingTokens: result.tokensByCategory.spacing.length,
    typographyTokens: result.tokensByCategory.typography.length,
    otherTokens: result.tokensByCategory.other.length,
    duplicateValueGroups: result.duplicateValues.length
  };

  return result;
})()
```

### 1.2 detectHardcodedStyles

```javascript
(() => {
  const result = {
    scriptId: 'detectHardcodedStyles',
    timestamp: new Date().toISOString(),
    hardcodedColors: [],
    hardcodedPx: [],
    hardcodedFonts: [],
    totalViolations: 0
  };

  const MAX_SAMPLES = 50;
  const hexPattern = /^#[0-9a-fA-F]{3,8}$/;
  const rgbPattern = /^rgb[a]?\(\s*\d/;
  const pxPattern = /\d+px/;
  const systemFonts = ['inherit', 'initial', 'unset', 'revert', 'serif', 'sans-serif', 'monospace', 'cursive', 'fantasy', 'system-ui', 'ui-serif', 'ui-sans-serif', 'ui-monospace', 'ui-rounded'];

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const allElements = document.querySelectorAll('*');

  for (const el of allElements) {
    const inlineStyle = el.getAttribute('style');
    if (!inlineStyle) continue;

    const selector = getSelector(el);

    const colorMatches = inlineStyle.match(/#[0-9a-fA-F]{3,8}\b/g);
    if (colorMatches && result.hardcodedColors.length < MAX_SAMPLES) {
      colorMatches.forEach(color => {
        result.hardcodedColors.push({
          selector,
          value: color,
          context: inlineStyle.substring(0, 120)
        });
      });
    }

    const rgbMatches = inlineStyle.match(/rgb[a]?\([^)]+\)/g);
    if (rgbMatches && result.hardcodedColors.length < MAX_SAMPLES) {
      rgbMatches.forEach(color => {
        result.hardcodedColors.push({
          selector,
          value: color,
          context: inlineStyle.substring(0, 120)
        });
      });
    }

    const pxMatches = inlineStyle.match(/:\s*\d+px/g);
    if (pxMatches && result.hardcodedPx.length < MAX_SAMPLES) {
      pxMatches.forEach(px => {
        result.hardcodedPx.push({
          selector,
          value: px.trim(),
          context: inlineStyle.substring(0, 120)
        });
      });
    }

    if (inlineStyle.includes('font-family') && result.hardcodedFonts.length < MAX_SAMPLES) {
      const fontMatch = inlineStyle.match(/font-family\s*:\s*([^;]+)/);
      if (fontMatch) {
        const fontValue = fontMatch[1].trim();
        const isSystem = systemFonts.some(f => fontValue.toLowerCase() === f);
        if (!isSystem) {
          result.hardcodedFonts.push({
            selector,
            value: fontValue,
            context: inlineStyle.substring(0, 120)
          });
        }
      }
    }
  }

  result.totalViolations = result.hardcodedColors.length + result.hardcodedPx.length + result.hardcodedFonts.length;

  result.summary = {
    elementsWithInlineStyles: document.querySelectorAll('[style]').length,
    hardcodedColorCount: result.hardcodedColors.length,
    hardcodedPxCount: result.hardcodedPx.length,
    hardcodedFontCount: result.hardcodedFonts.length,
    totalViolations: result.totalViolations
  };

  return result;
})()
```

### 1.3 measureTokenCoverage

```javascript
(() => {
  const result = {
    scriptId: 'measureTokenCoverage',
    timestamp: new Date().toISOString(),
    colorAnalysis: { tokenized: 0, hardcoded: 0, total: 0, rate: 0 },
    fontAnalysis: { tokenized: 0, hardcoded: 0, total: 0, rate: 0 },
    spacingAnalysis: { tokenized: 0, hardcoded: 0, total: 0, rate: 0 },
    overallAdoptionRate: 0,
    sampleHardcodedElements: []
  };

  const MAX_ELEMENTS = 500;
  const MAX_SAMPLES = 30;

  const isTokenValue = (value) => {
    return value && value.includes('var(');
  };

  const getPropertySource = (el, prop) => {
    const sheets = document.styleSheets;
    try {
      for (const sheet of sheets) {
        try {
          const rules = sheet.cssRules || sheet.rules;
          if (!rules) continue;
          for (const rule of rules) {
            if (rule.style && el.matches(rule.selectorText)) {
              const raw = rule.style.getPropertyValue(prop);
              if (raw && raw.trim()) return raw.trim();
            }
          }
        } catch (e) { continue; }
      }
    } catch (e) {}
    return null;
  };

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 2).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const visibleElements = Array.from(document.querySelectorAll('body *')).filter(el => {
    const rect = el.getBoundingClientRect();
    const style = getComputedStyle(el);
    return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
  }).slice(0, MAX_ELEMENTS);

  const colorProps = ['color', 'background-color', 'border-color', 'border-top-color', 'border-right-color', 'border-bottom-color', 'border-left-color'];
  const spacingProps = ['margin-top', 'margin-right', 'margin-bottom', 'margin-left', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left', 'gap', 'row-gap', 'column-gap'];
  const fontProps = ['font-family', 'font-size'];

  const defaultColors = ['rgba(0, 0, 0, 0)', 'rgb(0, 0, 0)', 'transparent'];

  for (const el of visibleElements) {
    for (const prop of colorProps) {
      const computed = getComputedStyle(el).getPropertyValue(prop).trim();
      if (!computed || defaultColors.includes(computed)) continue;

      const source = getPropertySource(el, prop);
      if (source && source.includes('var(--')) {
        result.colorAnalysis.tokenized++;
      } else if (computed !== 'rgba(0, 0, 0, 0)') {
        result.colorAnalysis.hardcoded++;
        if (result.sampleHardcodedElements.length < MAX_SAMPLES) {
          result.sampleHardcodedElements.push({
            selector: getSelector(el),
            property: prop,
            value: computed,
            type: 'color'
          });
        }
      }
    }

    for (const prop of spacingProps) {
      const computed = getComputedStyle(el).getPropertyValue(prop).trim();
      if (!computed || computed === '0px' || computed === 'auto' || computed === 'normal') continue;

      const source = getPropertySource(el, prop);
      if (source && source.includes('var(--')) {
        result.spacingAnalysis.tokenized++;
      } else {
        result.spacingAnalysis.hardcoded++;
      }
    }

    for (const prop of fontProps) {
      const computed = getComputedStyle(el).getPropertyValue(prop).trim();
      if (!computed) continue;

      const source = getPropertySource(el, prop);
      if (source && source.includes('var(--')) {
        result.fontAnalysis.tokenized++;
      } else {
        result.fontAnalysis.hardcoded++;
      }
    }
  }

  const calcRate = (analysis) => {
    analysis.total = analysis.tokenized + analysis.hardcoded;
    analysis.rate = analysis.total > 0 ? Math.round((analysis.tokenized / analysis.total) * 100) : 0;
  };

  calcRate(result.colorAnalysis);
  calcRate(result.fontAnalysis);
  calcRate(result.spacingAnalysis);

  const totalTokenized = result.colorAnalysis.tokenized + result.fontAnalysis.tokenized + result.spacingAnalysis.tokenized;
  const totalAll = result.colorAnalysis.total + result.fontAnalysis.total + result.spacingAnalysis.total;
  result.overallAdoptionRate = totalAll > 0 ? Math.round((totalTokenized / totalAll) * 100) : 0;

  result.summary = {
    elementsAnalyzed: visibleElements.length,
    overallAdoptionRate: result.overallAdoptionRate + '%',
    colorAdoptionRate: result.colorAnalysis.rate + '%',
    fontAdoptionRate: result.fontAnalysis.rate + '%',
    spacingAdoptionRate: result.spacingAnalysis.rate + '%',
    hardcodedSamples: result.sampleHardcodedElements.length
  };

  return result;
})()
```

### 1.4 checkSemanticTokenNaming

```javascript
(() => {
  const result = {
    scriptId: 'checkSemanticTokenNaming',
    timestamp: new Date().toISOString(),
    totalTokens: 0,
    semanticTokens: [],
    primitiveTokens: [],
    poorlyNamed: [],
    namingPatterns: {},
    hierarchyDetected: false,
    semanticScore: 0
  };

  const semanticPatterns = [
    /^--(?:color|bg|text|border|shadow|font|spacing|radius|size)-(?:primary|secondary|accent|muted|destructive|success|warning|info|foreground|background|surface|on-)/,
    /^--(?:color|bg|text|border)-(?:heading|body|caption|link|hover|active|focus|disabled|placeholder|inverse)/,
    /^--(?:spacing|gap|margin|padding)-(?:xs|sm|md|lg|xl|2xl|3xl|none|tight|loose)/,
    /^--(?:font|text)-(?:display|heading|body|caption|label|mono|code)/,
    /^--(?:radius|rounded)-(?:none|sm|md|lg|xl|full|pill)/,
    /^--(?:shadow|elevation)-(?:none|sm|md|lg|xl)/
  ];

  const primitivePatterns = [
    /^--(?:gray|red|blue|green|yellow|orange|purple|pink|slate|zinc|stone|neutral|amber|emerald|teal|cyan|sky|indigo|violet|fuchsia|rose)-\d{2,3}$/,
    /^--(?:white|black)$/,
    /^--(?:hsl|rgb|hex)-/
  ];

  const poorNamingPatterns = [
    { pattern: /^--[a-z]$/, reason: 'Single character name' },
    { pattern: /^--(?:var|val|tmp|temp|x|y|z)\d*$/, reason: 'Non-descriptive name' },
    { pattern: /^--#/, reason: 'Contains hash literal' },
    { pattern: /^\d/, reason: 'Starts with number' },
    { pattern: /^--(?:color|bg|text)-[0-9a-f]{3,8}$/i, reason: 'Named after hex value' },
    { pattern: /^--.*(?:left|right|top|bottom)-\d+$/, reason: 'Position-based naming instead of semantic' }
  ];

  const styles = getComputedStyle(document.documentElement);
  const allTokens = [];
  for (let i = 0; i < styles.length; i++) {
    const prop = styles[i];
    if (prop.startsWith('--')) {
      allTokens.push({
        name: prop,
        value: styles.getPropertyValue(prop).trim()
      });
    }
  }

  const bodyStyles = getComputedStyle(document.body);
  for (let i = 0; i < bodyStyles.length; i++) {
    const prop = bodyStyles[i];
    if (prop.startsWith('--') && !allTokens.find(t => t.name === prop)) {
      allTokens.push({
        name: prop,
        value: bodyStyles.getPropertyValue(prop).trim()
      });
    }
  }

  result.totalTokens = allTokens.length;

  for (const token of allTokens) {
    const isSemantic = semanticPatterns.some(p => p.test(token.name));
    const isPrimitive = primitivePatterns.some(p => p.test(token.name));
    const poorMatch = poorNamingPatterns.find(p => p.pattern.test(token.name));

    if (poorMatch) {
      result.poorlyNamed.push({
        name: token.name,
        value: token.value,
        reason: poorMatch.reason
      });
    } else if (isSemantic) {
      result.semanticTokens.push({ name: token.name, value: token.value });
    } else if (isPrimitive) {
      result.primitiveTokens.push({ name: token.name, value: token.value });
    }

    const prefix = token.name.split('-').slice(0, 3).join('-');
    if (!result.namingPatterns[prefix]) result.namingPatterns[prefix] = 0;
    result.namingPatterns[prefix]++;
  }

  const hasPrimitive = result.primitiveTokens.length > 0;
  const hasSemantic = result.semanticTokens.length > 0;
  const hasSemanticReferencingPrimitive = result.semanticTokens.some(t =>
    allTokens.some(p => result.primitiveTokens.find(pr => t.value.includes(pr.name)))
  );
  result.hierarchyDetected = hasPrimitive && hasSemantic;

  if (result.totalTokens > 0) {
    const semanticCount = result.semanticTokens.length;
    const poorCount = result.poorlyNamed.length;
    const goodCount = semanticCount + result.primitiveTokens.length;
    result.semanticScore = Math.round((goodCount / result.totalTokens) * 100);
  }

  const sortedPatterns = Object.entries(result.namingPatterns)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 15);

  result.summary = {
    totalTokens: result.totalTokens,
    semanticTokens: result.semanticTokens.length,
    primitiveTokens: result.primitiveTokens.length,
    poorlyNamed: result.poorlyNamed.length,
    hierarchyDetected: result.hierarchyDetected,
    semanticScore: result.semanticScore + '%',
    topPatterns: sortedPatterns
  };

  return result;
})()
```

### 1.5 detectTokenlessComponents

```javascript
(() => {
  const result = {
    scriptId: 'detectTokenlessComponents',
    timestamp: new Date().toISOString(),
    components: [],
    worstOffenders: [],
    totalAnalyzed: 0,
    totalTokenless: 0
  };

  const componentSelectors = [
    '[class*="card"]', '[class*="Card"]',
    '[class*="button"]', '[class*="Button"]', '[class*="btn"]',
    '[class*="badge"]', '[class*="Badge"]',
    '[class*="alert"]', '[class*="Alert"]',
    '[class*="modal"]', '[class*="Modal"]', '[class*="dialog"]',
    '[class*="nav"]', '[class*="Nav"]',
    '[class*="header"]', '[class*="Header"]',
    '[class*="footer"]', '[class*="Footer"]',
    '[class*="sidebar"]', '[class*="Sidebar"]',
    '[class*="input"]', '[class*="Input"]',
    '[class*="dropdown"]', '[class*="Dropdown"]',
    '[class*="tooltip"]', '[class*="Tooltip"]',
    '[class*="tab"]', '[class*="Tab"]',
    '[role="dialog"]', '[role="alert"]', '[role="navigation"]',
    '[role="tablist"]', '[role="toolbar"]',
    'button', 'input', 'select', 'textarea'
  ];

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const checkTokenUsage = (el) => {
    const props = ['color', 'background-color', 'border-color', 'font-size', 'font-family',
      'padding', 'margin', 'gap', 'border-radius', 'box-shadow'];
    let tokenCount = 0;
    let hardcodedCount = 0;
    const hardcodedProps = [];

    for (const prop of props) {
      const computed = getComputedStyle(el).getPropertyValue(prop).trim();
      if (!computed || computed === 'none' || computed === '0px' || computed === 'normal' ||
          computed === 'rgba(0, 0, 0, 0)' || computed === 'auto') continue;

      let usesToken = false;
      try {
        const sheets = document.styleSheets;
        for (const sheet of sheets) {
          try {
            const rules = sheet.cssRules;
            if (!rules) continue;
            for (const rule of rules) {
              if (rule.style && rule.selectorText) {
                try {
                  if (el.matches(rule.selectorText)) {
                    const raw = rule.style.getPropertyValue(prop);
                    if (raw && raw.includes('var(--')) {
                      usesToken = true;
                      break;
                    }
                  }
                } catch (e) {}
              }
            }
          } catch (e) { continue; }
          if (usesToken) break;
        }
      } catch (e) {}

      if (usesToken) {
        tokenCount++;
      } else {
        hardcodedCount++;
        hardcodedProps.push({ property: prop, value: computed });
      }
    }

    return { tokenCount, hardcodedCount, hardcodedProps };
  };

  const seen = new Set();
  for (const selector of componentSelectors) {
    const elements = document.querySelectorAll(selector);
    for (const el of Array.from(elements).slice(0, 10)) {
      const key = getSelector(el);
      if (seen.has(key)) continue;
      seen.add(key);

      const analysis = checkTokenUsage(el);
      const total = analysis.tokenCount + analysis.hardcodedCount;
      if (total === 0) continue;

      result.totalAnalyzed++;
      const tokenRate = Math.round((analysis.tokenCount / total) * 100);

      const entry = {
        selector: key,
        tokenRate: tokenRate + '%',
        tokenized: analysis.tokenCount,
        hardcoded: analysis.hardcodedCount,
        hardcodedProps: analysis.hardcodedProps.slice(0, 5)
      };

      result.components.push(entry);
      if (tokenRate < 50) {
        result.totalTokenless++;
        result.worstOffenders.push(entry);
      }
    }
  }

  result.worstOffenders.sort((a, b) => parseInt(a.tokenRate) - parseInt(b.tokenRate));
  result.worstOffenders = result.worstOffenders.slice(0, 15);

  result.summary = {
    componentsAnalyzed: result.totalAnalyzed,
    componentsUnder50Percent: result.totalTokenless,
    averageTokenRate: result.components.length > 0
      ? Math.round(result.components.reduce((sum, c) => sum + parseInt(c.tokenRate), 0) / result.components.length) + '%'
      : 'N/A'
  };

  return result;
})()
```

---

## Tier 2: AI Evaluation

After collecting Tier 0 and Tier 1 data, examine screenshots and DOM snapshots to answer these questions:

1. **Are token names self-documenting?** Could a new developer understand the system by reading `--color-primary-foreground` vs `--blue-500`? Do names communicate purpose or just describe the raw value?

2. **Is there a clear token hierarchy?** Can you identify primitive tokens (raw values like `--blue-500: #3b82f6`), semantic tokens (purpose-based like `--color-primary: var(--blue-500)`), and component tokens (scoped like `--button-bg: var(--color-primary)`)? Is the hierarchy used consistently?

3. **Do semantic tokens map to their actual visual purpose?** Does `--color-destructive` actually appear on delete/error elements? Does `--spacing-lg` create visually large gaps? Or are token names misleading?

4. **Are there tokens that should exist but don't?** Look for repeated hardcoded values that could be extracted. Are there obvious gaps like no token for disabled states, no token for focus rings, no token for elevation/shadows?

5. **Is the token system over-engineered or under-defined for this project's scale?** A 3-page landing site with 200 tokens is over-engineered. A 50-page app with 5 tokens is under-defined. Does the complexity match the project?

6. **Would changing a single token value propagate correctly?** If you changed `--color-primary` from blue to green, would the entire UI update consistently, or are there hardcoded overrides that would break the chain?

---

## Scoring Criteria

| Score | Token Adoption Rate | Naming | Hierarchy | Notes |
|-------|-------------------|--------|-----------|-------|
| **5** | 95%+ using tokens | Semantic naming throughout | Clear primitive > semantic > component hierarchy | Changing one token cascades cleanly; no orphaned tokens |
| **4** | 80-94% using tokens | Mostly semantic naming | At least primitive + semantic tiers | Minor hardcoded values in edge cases only |
| **3** | 50-79% using tokens | Mix of semantic and primitive names | Tokens defined but flat (no hierarchy) | Some hardcoded overrides exist alongside tokens |
| **2** | 20-49% using tokens | Mostly primitive or unclear names | Token definitions exist but underused | Significant hardcoded values throughout |
| **1** | < 20% or no tokens | No naming convention | No token system | Hardcoded hex, px, and font values everywhere |

---

## Common Fixes

### Replace hardcoded hex colors with token references
```css
/* Before */
.card { background: #f8fafc; color: #1e293b; }

/* After */
.card { background: var(--color-surface); color: var(--color-foreground); }
```

### Replace hardcoded px with spacing tokens
```css
/* Before */
.section { padding: 24px 16px; gap: 12px; }

/* After */
.section { padding: var(--spacing-lg) var(--spacing-md); gap: var(--spacing-sm); }
```

### Replace hardcoded font-family with typography tokens
```css
/* Before */
.heading { font-family: 'Inter', sans-serif; font-size: 24px; }

/* After */
.heading { font-family: var(--font-heading); font-size: var(--text-2xl); }
```

### Add missing token definitions for Tailwind projects
```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: 'hsl(var(--color-primary))',
        secondary: 'hsl(var(--color-secondary))',
        destructive: 'hsl(var(--color-destructive))',
      },
      spacing: {
        'page': 'var(--spacing-page)',
        'section': 'var(--spacing-section)',
      }
    }
  }
}
```

### Remove orphaned tokens
```css
/* Before: --color-deprecated is defined but never referenced */
:root {
  --color-primary: #3b82f6;
  --color-deprecated: #ff0000; /* REMOVE */
}

/* After */
:root {
  --color-primary: #3b82f6;
}
```

### Extract repeated hardcoded values into new tokens
```css
/* Before: same value used in 5+ places */
.card { border-radius: 8px; }
.button { border-radius: 8px; }
.input { border-radius: 8px; }

/* After: extract to token */
:root { --radius-md: 8px; }
.card { border-radius: var(--radius-md); }
.button { border-radius: var(--radius-md); }
.input { border-radius: var(--radius-md); }
```
