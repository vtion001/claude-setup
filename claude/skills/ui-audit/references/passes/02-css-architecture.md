# Pass 2: CSS Architecture

Evaluates the structural quality, organization, and maintainability of the project's CSS. Healthy CSS architecture uses a single consistent methodology, keeps specificity low and flat, avoids `!important` escalation, and makes it obvious where to add or modify styles.

---

## Tier 0: Code Analysis

Perform these checks using Read, Grep, and Glob only (no browser required).

### 0-1. CSS file inventory
Glob for all CSS-related files and count total lines.

```
glob: "*.{css,scss,less,sass,pcss,postcss}"
```

Also detect CSS-in-JS by searching for:
```
pattern: styled\(|styled\.|css`|css\(|createStyles|makeStyles|sx=\{
glob: "*.{ts,tsx,js,jsx}"
```

Count total CSS files, total lines of CSS, and CSS-in-JS files separately.

### 0-2. Specificity distribution analysis
Count selectors by specificity category across all stylesheets.

**Element selectors (0-0-1):**
```
pattern: ^[a-z]+[\s,{]
glob: "*.{css,scss,less}"
```

**Class selectors (0-1-0):**
```
pattern: \.[a-zA-Z_][\w-]*
glob: "*.{css,scss,less}"
```

**ID selectors (1-0-0):**
```
pattern: #[a-zA-Z_][\w-]*\s*\{
glob: "*.{css,scss,less}"
```

**Attribute selectors:**
```
pattern: \[[\w-]+
glob: "*.{css,scss,less}"
```

### 0-3. !important declarations
Count all `!important` usages.

```
pattern: !important
glob: "*.{css,scss,less,tsx,jsx,vue,svelte}"
```

Categorize by file to identify the worst offenders. Any file with >5 `!important` is a red flag.

### 0-4. CSS methodology detection
Detect which methodology the project uses.

**BEM (Block__Element--Modifier):**
```
pattern: [\w-]+__[\w-]+(?:--[\w-]+)?
glob: "*.{css,scss,less,tsx,jsx,vue,svelte,html}"
```

**CSS Modules:**
```
pattern: \.module\.(css|scss|less)
glob: "*.{ts,tsx,js,jsx,vue}"
```

**Utility-first (Tailwind):**
```
pattern: className=["'`{].*(?:flex|grid|p-|m-|text-|bg-|border-|rounded-|w-|h-)
glob: "*.{tsx,jsx,vue,svelte,html}"
```

**CSS-in-JS (styled-components, Emotion):**
```
pattern: styled\.|styled\(|css`|css\(
glob: "*.{ts,tsx,js,jsx}"
```

Count matches per methodology. If more than one has significant usage, flag as **mixed methodology**.

### 0-5. Duplicate selectors/properties
Search for identical selectors defined in multiple files.

```
pattern: \.([\w-]+)\s*\{
glob: "*.{css,scss,less}"
```

Collect all class selectors and flag any that appear in multiple files with the same properties. Also flag identical property blocks (same set of property:value pairs in different selectors).

### 0-6. Selector nesting depth
Measure maximum nesting depth in preprocessor files.

```
pattern: ^\s{4,}\S|^\t{2,}\S
glob: "*.{scss,less,sass}"
```

Count nesting levels. Selectors nested >3 levels deep are a complexity warning. >5 levels is a severe issue.

### 0-7. Unused CSS detection
Collect all class names defined in stylesheets, then search for their usage in templates/components.

```
# Step 1: Extract defined classes
pattern: \.([a-zA-Z_][\w-]*)\s*[,{]
glob: "*.{css,scss,less}"

# Step 2: Search for usage of each class in templates
pattern: className|class=|:class=
glob: "*.{tsx,jsx,vue,svelte,html}"
```

Classes defined but never referenced in any template file are candidates for removal.

### 0-8. Mixed methodology detection
If more than one methodology from 0-4 has >10% of total CSS declarations, flag as mixed. Report percentages.

---

## Tier 1: Automated Browser Checks

### 2.1 analyzeSpecificityConflicts

```javascript
(() => {
  const result = {
    scriptId: 'analyzeSpecificityConflicts',
    timestamp: new Date().toISOString(),
    totalRules: 0,
    specificityDistribution: {
      elementOnly: 0,
      singleClass: 0,
      multiClass: 0,
      withId: 0,
      withImportant: 0,
      inline: 0
    },
    highSpecificitySelectors: [],
    conflictingElements: [],
    maxSpecificity: { selector: '', score: [0, 0, 0] }
  };

  const MAX_SAMPLES = 30;

  const calcSpecificity = (selector) => {
    const ids = (selector.match(/#[\w-]+/g) || []).length;
    const classes = (selector.match(/\.[\w-]+/g) || []).length
      + (selector.match(/\[[\w-]+/g) || []).length
      + (selector.match(/:[\w-]+(?!\()/g) || []).filter(p =>
        !['::before', '::after', '::placeholder', '::first-line', '::first-letter'].some(pe => p.startsWith(pe))
      ).length;
    const elements = (selector.match(/(?:^|[\s>+~])[\w]+/g) || []).length
      + (selector.match(/::[\w-]+/g) || []).length;
    return [ids, classes, elements];
  };

  const compareSpec = (a, b) => {
    if (a[0] !== b[0]) return a[0] - b[0];
    if (a[1] !== b[1]) return a[1] - b[1];
    return a[2] - b[2];
  };

  try {
    const sheets = document.styleSheets;
    for (const sheet of sheets) {
      try {
        const rules = sheet.cssRules || sheet.rules;
        if (!rules) continue;

        for (const rule of rules) {
          if (!rule.selectorText) continue;
          result.totalRules++;

          const selectors = rule.selectorText.split(',').map(s => s.trim());
          for (const sel of selectors) {
            const spec = calcSpecificity(sel);

            if (spec[0] > 0) {
              result.specificityDistribution.withId++;
              if (result.highSpecificitySelectors.length < MAX_SAMPLES) {
                result.highSpecificitySelectors.push({
                  selector: sel,
                  specificity: spec.join('-'),
                  source: sheet.href || 'inline'
                });
              }
            } else if (spec[1] > 1) {
              result.specificityDistribution.multiClass++;
            } else if (spec[1] === 1) {
              result.specificityDistribution.singleClass++;
            } else {
              result.specificityDistribution.elementOnly++;
            }

            for (let i = 0; i < rule.style.length; i++) {
              const prop = rule.style[i];
              const val = rule.style.getPropertyValue(prop);
              if (val.includes('!important')) {
                result.specificityDistribution.withImportant++;
                break;
              }
            }

            if (compareSpec(spec, result.maxSpecificity.score) > 0) {
              result.maxSpecificity = { selector: sel, score: spec };
            }
          }
        }
      } catch (e) { continue; }
    }
  } catch (e) {}

  result.specificityDistribution.inline = document.querySelectorAll('[style]').length;

  const testElements = document.querySelectorAll('body *');
  const checked = new Set();
  for (const el of Array.from(testElements).slice(0, 200)) {
    const tag = el.tagName.toLowerCase();
    const classes = Array.from(el.classList).slice(0, 2).join('.');
    const key = classes ? `${tag}.${classes}` : tag;
    if (checked.has(key)) continue;
    checked.add(key);

    const matchingRules = [];
    try {
      const sheets = document.styleSheets;
      for (const sheet of sheets) {
        try {
          const rules = sheet.cssRules;
          if (!rules) continue;
          for (const rule of rules) {
            if (rule.selectorText) {
              try {
                if (el.matches(rule.selectorText)) {
                  matchingRules.push({
                    selector: rule.selectorText,
                    specificity: calcSpecificity(rule.selectorText),
                    propCount: rule.style.length
                  });
                }
              } catch (e) {}
            }
          }
        } catch (e) { continue; }
      }
    } catch (e) {}

    if (matchingRules.length > 5 && result.conflictingElements.length < MAX_SAMPLES) {
      result.conflictingElements.push({
        element: key,
        matchingRuleCount: matchingRules.length,
        highestSpecificity: matchingRules.reduce((max, r) =>
          compareSpec(r.specificity, max) > 0 ? r.specificity : max, [0, 0, 0]
        ).join('-'),
        topSelectors: matchingRules
          .sort((a, b) => compareSpec(b.specificity, a.specificity))
          .slice(0, 3)
          .map(r => r.selector)
      });
    }
  }

  result.conflictingElements.sort((a, b) => b.matchingRuleCount - a.matchingRuleCount);

  result.summary = {
    totalCSSRules: result.totalRules,
    idSelectors: result.specificityDistribution.withId,
    importantCount: result.specificityDistribution.withImportant,
    inlineStyles: result.specificityDistribution.inline,
    maxSpecificity: result.maxSpecificity.score.join('-') + ' (' + result.maxSpecificity.selector + ')',
    elementsWithConflicts: result.conflictingElements.length,
    highSpecificitySelectors: result.highSpecificitySelectors.length
  };

  return result;
})()
```

### 2.2 countOverriddenStyles

```javascript
(() => {
  const result = {
    scriptId: 'countOverriddenStyles',
    timestamp: new Date().toISOString(),
    overriddenProperties: [],
    totalOverrides: 0,
    importantOverrides: 0,
    worstElements: []
  };

  const MAX_ELEMENTS = 300;
  const MAX_SAMPLES = 40;
  const TRACKED_PROPS = [
    'color', 'background-color', 'font-size', 'font-weight', 'font-family',
    'margin', 'padding', 'border', 'display', 'position',
    'width', 'height', 'line-height', 'text-align', 'text-decoration'
  ];

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 2).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const elements = Array.from(document.querySelectorAll('body *')).slice(0, MAX_ELEMENTS);

  for (const el of elements) {
    let overrideCount = 0;
    const overrides = [];

    for (const prop of TRACKED_PROPS) {
      const matchingDeclarations = [];
      try {
        const sheets = document.styleSheets;
        for (const sheet of sheets) {
          try {
            const rules = sheet.cssRules;
            if (!rules) continue;
            for (const rule of rules) {
              if (rule.selectorText && rule.style) {
                try {
                  if (el.matches(rule.selectorText)) {
                    const val = rule.style.getPropertyValue(prop);
                    if (val && val.trim()) {
                      const priority = rule.style.getPropertyPriority(prop);
                      matchingDeclarations.push({
                        selector: rule.selectorText.substring(0, 80),
                        value: val.trim(),
                        important: priority === 'important'
                      });
                    }
                  }
                } catch (e) {}
              }
            }
          } catch (e) { continue; }
        }
      } catch (e) {}

      if (matchingDeclarations.length > 1) {
        overrideCount += matchingDeclarations.length - 1;
        const hasImportant = matchingDeclarations.some(d => d.important);
        if (hasImportant) result.importantOverrides++;

        if (overrides.length < 5) {
          overrides.push({
            property: prop,
            declarationCount: matchingDeclarations.length,
            winner: matchingDeclarations[matchingDeclarations.length - 1].value,
            hasImportant: hasImportant
          });
        }
      }
    }

    if (overrideCount > 3 && result.worstElements.length < MAX_SAMPLES) {
      result.worstElements.push({
        element: getSelector(el),
        totalOverrides: overrideCount,
        overriddenProps: overrides
      });
    }

    result.totalOverrides += overrideCount;
  }

  result.worstElements.sort((a, b) => b.totalOverrides - a.totalOverrides);
  result.worstElements = result.worstElements.slice(0, 20);

  result.summary = {
    elementsAnalyzed: elements.length,
    totalOverrides: result.totalOverrides,
    importantOverrides: result.importantOverrides,
    averageOverridesPerElement: elements.length > 0
      ? Math.round((result.totalOverrides / elements.length) * 100) / 100
      : 0,
    elementsWithHighOverrides: result.worstElements.length
  };

  return result;
})()
```

### 2.3 measureCSSComplexity

```javascript
(() => {
  const result = {
    scriptId: 'measureCSSComplexity',
    timestamp: new Date().toISOString(),
    totalUniqueRules: 0,
    totalDeclarations: 0,
    rulesPerElement: { avg: 0, max: 0, maxElement: '' },
    declarationsPerElement: { avg: 0, max: 0, maxElement: '' },
    mediaQueries: [],
    layerCount: 0,
    keyframeCount: 0,
    fontFaceCount: 0,
    fileBreakdown: []
  };

  const MAX_ELEMENTS = 400;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 2).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const uniqueSelectors = new Set();
  const mediaQueryMap = new Map();

  try {
    const sheets = document.styleSheets;
    for (const sheet of sheets) {
      const sheetInfo = { source: sheet.href || 'inline', rules: 0, declarations: 0 };
      try {
        const processRules = (rules) => {
          for (const rule of rules) {
            if (rule.type === CSSRule.STYLE_RULE) {
              uniqueSelectors.add(rule.selectorText);
              sheetInfo.rules++;
              sheetInfo.declarations += rule.style.length;
              result.totalDeclarations += rule.style.length;
            } else if (rule.type === CSSRule.MEDIA_RULE) {
              const key = rule.conditionText || rule.media.mediaText;
              if (!mediaQueryMap.has(key)) mediaQueryMap.set(key, 0);
              mediaQueryMap.set(key, mediaQueryMap.get(key) + 1);
              if (rule.cssRules) processRules(rule.cssRules);
            } else if (rule.type === CSSRule.KEYFRAMES_RULE) {
              result.keyframeCount++;
            } else if (rule.type === CSSRule.FONT_FACE_RULE) {
              result.fontFaceCount++;
            } else if (rule.type === 7) {
              result.layerCount++;
              if (rule.cssRules) processRules(rule.cssRules);
            } else if (rule.cssRules) {
              processRules(rule.cssRules);
            }
          }
        };

        const rules = sheet.cssRules || sheet.rules;
        if (rules) processRules(rules);
      } catch (e) { continue; }

      if (sheetInfo.rules > 0) {
        result.fileBreakdown.push(sheetInfo);
      }
    }
  } catch (e) {}

  result.totalUniqueRules = uniqueSelectors.size;

  mediaQueryMap.forEach((count, query) => {
    result.mediaQueries.push({ query, ruleBlocks: count });
  });
  result.mediaQueries.sort((a, b) => b.ruleBlocks - a.ruleBlocks);

  const elements = Array.from(document.querySelectorAll('body *')).slice(0, MAX_ELEMENTS);
  let totalRulesMatched = 0;
  let totalDeclsMatched = 0;
  let maxRules = 0;
  let maxDecls = 0;
  let maxRulesEl = '';
  let maxDeclsEl = '';

  for (const el of elements) {
    let rulesCount = 0;
    let declsCount = 0;

    try {
      const sheets = document.styleSheets;
      for (const sheet of sheets) {
        try {
          const rules = sheet.cssRules;
          if (!rules) continue;
          for (const rule of rules) {
            if (rule.selectorText) {
              try {
                if (el.matches(rule.selectorText)) {
                  rulesCount++;
                  declsCount += rule.style.length;
                }
              } catch (e) {}
            }
          }
        } catch (e) { continue; }
      }
    } catch (e) {}

    totalRulesMatched += rulesCount;
    totalDeclsMatched += declsCount;

    if (rulesCount > maxRules) {
      maxRules = rulesCount;
      maxRulesEl = getSelector(el);
    }
    if (declsCount > maxDecls) {
      maxDecls = declsCount;
      maxDeclsEl = getSelector(el);
    }
  }

  const elCount = elements.length || 1;
  result.rulesPerElement = {
    avg: Math.round((totalRulesMatched / elCount) * 100) / 100,
    max: maxRules,
    maxElement: maxRulesEl
  };
  result.declarationsPerElement = {
    avg: Math.round((totalDeclsMatched / elCount) * 100) / 100,
    max: maxDecls,
    maxElement: maxDeclsEl
  };

  result.fileBreakdown.sort((a, b) => b.declarations - a.declarations);

  result.summary = {
    totalUniqueRules: result.totalUniqueRules,
    totalDeclarations: result.totalDeclarations,
    avgRulesPerElement: result.rulesPerElement.avg,
    maxRulesOnElement: result.rulesPerElement.max + ' (' + result.rulesPerElement.maxElement + ')',
    mediaQueryCount: result.mediaQueries.length,
    keyframeAnimations: result.keyframeCount,
    fontFaces: result.fontFaceCount,
    cssLayers: result.layerCount,
    stylesheetCount: result.fileBreakdown.length
  };

  return result;
})()
```

### 2.4 detectUnusedClasses

```javascript
(() => {
  const result = {
    scriptId: 'detectUnusedClasses',
    timestamp: new Date().toISOString(),
    totalDefinedClasses: 0,
    totalUsedInDOM: 0,
    unusedClasses: [],
    usageRate: 0,
    largestUnusedRules: []
  };

  const MAX_UNUSED = 50;

  const definedClasses = new Map();

  try {
    const sheets = document.styleSheets;
    for (const sheet of sheets) {
      try {
        const rules = sheet.cssRules || sheet.rules;
        if (!rules) continue;
        const source = sheet.href || 'inline';

        const processRules = (ruleList) => {
          for (const rule of ruleList) {
            if (rule.type === CSSRule.STYLE_RULE && rule.selectorText) {
              const classMatches = rule.selectorText.match(/\.[\w-]+/g);
              if (classMatches) {
                for (const cls of classMatches) {
                  const className = cls.substring(1);
                  if (!definedClasses.has(className)) {
                    definedClasses.set(className, {
                      selector: rule.selectorText,
                      source,
                      propertyCount: rule.style.length
                    });
                  }
                }
              }
            } else if (rule.cssRules) {
              processRules(rule.cssRules);
            }
          }
        };

        processRules(rules);
      } catch (e) { continue; }
    }
  } catch (e) {}

  result.totalDefinedClasses = definedClasses.size;

  const domClasses = new Set();
  const allElements = document.querySelectorAll('*');
  for (const el of allElements) {
    for (const cls of el.classList) {
      domClasses.add(cls);
    }
  }

  let usedCount = 0;
  definedClasses.forEach((info, className) => {
    if (domClasses.has(className)) {
      usedCount++;
    } else {
      if (result.unusedClasses.length < MAX_UNUSED) {
        result.unusedClasses.push({
          className,
          selector: info.selector.substring(0, 100),
          source: info.source,
          propertyCount: info.propertyCount
        });
      }
    }
  });

  result.totalUsedInDOM = usedCount;
  result.usageRate = result.totalDefinedClasses > 0
    ? Math.round((usedCount / result.totalDefinedClasses) * 100)
    : 0;

  result.unusedClasses.sort((a, b) => b.propertyCount - a.propertyCount);

  result.largestUnusedRules = result.unusedClasses
    .filter(c => c.propertyCount > 3)
    .slice(0, 15);

  result.summary = {
    totalClassesDefined: result.totalDefinedClasses,
    totalClassesInDOM: domClasses.size,
    definedAndUsed: result.totalUsedInDOM,
    definedButUnused: result.totalDefinedClasses - result.totalUsedInDOM,
    usageRate: result.usageRate + '%',
    largestUnusedRuleCount: result.largestUnusedRules.length,
    note: 'Classes may be dynamically added or used in other pages not currently loaded'
  };

  return result;
})()
```

### 2.5 detectMethodologyMixing

```javascript
(() => {
  const result = {
    scriptId: 'detectMethodologyMixing',
    timestamp: new Date().toISOString(),
    methodologies: {
      utility: { count: 0, samples: [] },
      bem: { count: 0, samples: [] },
      cssModules: { count: 0, samples: [] },
      cssInJs: { count: 0, samples: [] },
      traditional: { count: 0, samples: [] }
    },
    mixedElements: [],
    dominantMethodology: '',
    isMixed: false,
    mixingScore: 0
  };

  const MAX_SAMPLES = 10;

  const utilityPattern = /^(flex|grid|block|inline|hidden|relative|absolute|fixed|sticky|p[xytblr]?-|m[xytblr]?-|w-|h-|min-|max-|text-|font-|bg-|border-|rounded-|shadow-|opacity-|z-|gap-|space-|overflow-|cursor-|transition-|duration-|ease-|transform|translate|rotate|scale|animate-|ring-|outline-|sr-only|not-sr-only|container|prose)/;
  const bemPattern = /^[\w-]+__[\w-]+(--[\w-]+)?$/;
  const modulePattern = /^[\w]+_[\w]+__[\w]{5,}$/;
  const styledPattern = /^(css|sc|emotion)-[\w-]+$/;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const allElements = document.querySelectorAll('body *');

  for (const el of allElements) {
    const classes = Array.from(el.classList);
    if (classes.length === 0) continue;

    const detected = new Set();

    for (const cls of classes) {
      if (utilityPattern.test(cls)) {
        detected.add('utility');
        if (result.methodologies.utility.samples.length < MAX_SAMPLES) {
          result.methodologies.utility.samples.push(cls);
        }
        result.methodologies.utility.count++;
      } else if (bemPattern.test(cls)) {
        detected.add('bem');
        if (result.methodologies.bem.samples.length < MAX_SAMPLES) {
          result.methodologies.bem.samples.push(cls);
        }
        result.methodologies.bem.count++;
      } else if (modulePattern.test(cls)) {
        detected.add('cssModules');
        if (result.methodologies.cssModules.samples.length < MAX_SAMPLES) {
          result.methodologies.cssModules.samples.push(cls);
        }
        result.methodologies.cssModules.count++;
      } else if (styledPattern.test(cls)) {
        detected.add('cssInJs');
        if (result.methodologies.cssInJs.samples.length < MAX_SAMPLES) {
          result.methodologies.cssInJs.samples.push(cls);
        }
        result.methodologies.cssInJs.count++;
      } else {
        detected.add('traditional');
        result.methodologies.traditional.count++;
      }
    }

    if (detected.size > 1 && result.mixedElements.length < 20) {
      result.mixedElements.push({
        element: getSelector(el),
        approaches: Array.from(detected),
        classes: classes.slice(0, 8)
      });
    }
  }

  const counts = Object.entries(result.methodologies)
    .map(([name, data]) => ({ name, count: data.count }))
    .filter(m => m.count > 0)
    .sort((a, b) => b.count - a.count);

  result.dominantMethodology = counts.length > 0 ? counts[0].name : 'none';

  const totalClasses = counts.reduce((sum, c) => sum + c.count, 0);
  const activeMethodologies = counts.filter(c => c.count > totalClasses * 0.1);
  result.isMixed = activeMethodologies.length > 1;

  if (result.isMixed && totalClasses > 0) {
    const dominantShare = counts[0].count / totalClasses;
    result.mixingScore = Math.round((1 - dominantShare) * 100);
  }

  result.summary = {
    dominantMethodology: result.dominantMethodology,
    isMixed: result.isMixed,
    mixingScore: result.mixingScore + '%',
    methodologyCounts: counts,
    elementsWithMixedApproaches: result.mixedElements.length,
    totalClassesAnalyzed: totalClasses
  };

  return result;
})()
```

---

## Tier 2: AI Evaluation

After collecting Tier 0 and Tier 1 data, examine screenshots and DOM snapshots to answer these questions:

1. **Is there a single, consistent CSS methodology?** Or are BEM, utility-first, CSS Modules, and/or CSS-in-JS mixed across the project? Can you identify a clear primary approach, or is it a patchwork?

2. **Could a new developer predict where to add styles for a new component?** Is there a clear convention for file placement, naming, and scope? Or would they have to guess by studying existing files?

3. **Is specificity escalation contained or spiraling?** Is specificity mostly flat (single-class selectors), or are there deep nested selectors, ID selectors, and `!important` overrides creating an escalation arms race?

4. **Are styles organized by component/feature or scattered?** Do CSS files colocate with their components, or is there a monolithic styles directory with files organized by property type (colors.css, typography.css)?

5. **Is the CSS architecture scaling well or showing strain?** Look for signs of strain: excessive overrides, growing `!important` count, duplicate declarations, inconsistent class naming in newer vs older code.

6. **Are there obvious candidates for CSS custom property extraction?** Look for repeated literal values across multiple selectors that should be extracted into shared variables or tokens.

---

## Scoring Criteria

| Score | Methodology | Specificity | !important | Organization |
|-------|------------|-------------|------------|-------------|
| **5** | Single consistent methodology everywhere | Flat specificity (mostly 0-1-0) | 0 `!important` | Clear file/component structure, no duplication |
| **4** | One primary method, minor secondary usage | Mostly flat, rare ID selectors | 1-5 `!important` | Good organization with minor inconsistencies |
| **3** | Mixed approaches but with identifiable pattern | Some specificity escalation | 6-20 `!important` | Partial organization, some scattered styles |
| **2** | Multiple methodologies with no clear primary | Frequent high-specificity selectors | 21-50 `!important` | Disorganized, significant duplication |
| **1** | No consistent approach, completely ad hoc | Specificity wars, deep nesting | 50+ `!important` | Monolithic files, no clear structure |

---

## Common Fixes

### Eliminate !important by increasing selector specificity
```css
/* Before: using !important to win */
.button { color: red !important; }

/* After: use a more specific selector or restructure */
.form .button { color: red; }
/* Or use :where() to reduce competing specificity */
:where(.button) { color: var(--button-color); }
```

### Consolidate duplicate selectors across files
```css
/* Before: same class defined in header.css and layout.css */
/* header.css */
.container { max-width: 1200px; margin: 0 auto; padding: 0 1rem; }
/* layout.css */
.container { max-width: 1200px; margin: 0 auto; padding: 0 16px; }

/* After: single definition in layout.css */
.container { max-width: 1200px; margin: 0 auto; padding: 0 var(--spacing-md); }
```

### Flatten deep nesting
```scss
/* Before: 4+ levels deep */
.page {
  .header {
    .nav {
      .list {
        .item {
          .link { color: blue; }
        }
      }
    }
  }
}

/* After: flat BEM or single-class selectors */
.nav__link { color: blue; }
```

### Standardize methodology
```tsx
/* Before: mixed inline + Tailwind + CSS modules */
<div className={styles.card} style={{ padding: '16px' }}>
  <h2 className="text-xl font-bold">{title}</h2>
</div>

/* After: consistent Tailwind */
<div className="rounded-lg border bg-card p-4">
  <h2 className="text-xl font-bold">{title}</h2>
</div>
```

### Remove unused CSS classes
```css
/* Before: dead code from removed components */
.old-banner { ... }
.deprecated-modal { ... }
.legacy-tooltip { ... }

/* After: removed, reducing bundle size */
```

### Extract repeated values to CSS custom properties
```css
/* Before: same border-radius in 12 selectors */
.card { border-radius: 12px; }
.modal { border-radius: 12px; }
.dropdown { border-radius: 12px; }

/* After: single token */
:root { --radius-lg: 12px; }
.card { border-radius: var(--radius-lg); }
.modal { border-radius: var(--radius-lg); }
.dropdown { border-radius: var(--radius-lg); }
```
