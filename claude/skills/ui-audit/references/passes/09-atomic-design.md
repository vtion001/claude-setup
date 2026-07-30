# Pass 9: Atomic Design Compliance

Evaluates whether the component architecture follows atomic design principles — a clear hierarchy from atoms (buttons, inputs) through molecules (search bars, form fields) to organisms (headers, cards), templates (layouts), and pages (routes). A well-structured atomic system maximizes reuse, reduces duplication, and makes the codebase navigable for new developers.

---

## Tier 0: Code Analysis

Perform these checks using Read, Grep, and Glob only (no browser required).

### 0-1. Map component hierarchy from source files

Classify every component into its atomic design tier:

| Tier | Examples | Heuristic |
|------|----------|-----------|
| **Atoms** | buttons, inputs, labels, icons, badges, avatars, dividers, tooltips | Single HTML element or minimal wrapper, no child components imported |
| **Molecules** | search bars (input + button), form fields (label + input + error), nav items (icon + text), media objects (image + text) | Composes 2-3 atoms, no layout responsibility |
| **Organisms** | headers, footers, cards, forms, navigation bars, sidebars, modals, tables | Composes multiple molecules/atoms, represents a distinct UI section |
| **Templates** | page layouts, dashboard layouts, auth layouts | Defines slot/content areas, uses `children`/`<slot>`, no business logic |
| **Pages** | actual route components | Connected to routing, fetches data, composes organisms into templates |

Glob for component files:

```
pattern: "*.{tsx,jsx,vue,svelte}"
paths: "src/components/**", "src/ui/**", "src/lib/**", "app/**", "components/**"
```

For each file, check imports to determine tier:
- Files that import zero local components = likely atoms
- Files that import 1-3 atoms = likely molecules
- Files that import molecules or many atoms = likely organisms
- Files that use `children`/`<slot>` and define layout = likely templates

### 0-2. Calculate component reuse rate

```
pattern: import\s+.*\s+from\s+['"]\.\./
glob: "*.{tsx,jsx,vue,svelte}"
```

Count how many times each component is imported across the codebase. Calculate:

```
reuse_rate = components_used_more_than_once / total_exported_components * 100
```

Flag components imported only once (candidates for inlining or generalization).

### 0-3. Detect one-off components that duplicate existing ones

Search for component files with similar names or overlapping responsibilities:

```
pattern: (Button|Btn|Input|Card|Modal|Header|Footer|Nav|Badge|Avatar|Tag|Chip)
glob: "*.{tsx,jsx,vue,svelte}"
```

Flag cases where multiple files match the same base pattern (e.g., `PrimaryButton.tsx`, `SubmitButton.tsx`, `ActionButton.tsx` alongside `Button.tsx`).

### 0-4. Check composition patterns

For each organism-level component, verify it imports and composes molecules/atoms rather than reinventing base elements:

```
pattern: <(button|input|select|textarea|a|img)\s
glob: "*.{tsx,jsx,vue,svelte}"
```

Exclude atom-level files. Organisms and molecules that use raw HTML elements instead of the project's atom components indicate broken composition.

### 0-5. Count shared vs page-specific components

```
shared: components in src/components/**, src/ui/**, src/lib/ui/**
page_specific: components co-located with routes (app/**/components/**, pages/**/*)
```

Calculate:

```
shared_ratio = shared_components / (shared_components + page_specific_components) * 100
```

A healthy project has 60-80% shared components. Below 40% suggests excessive co-location without reuse.

### 0-6. Check for barrel exports (index files)

```
pattern: export\s+\{.*\}\s+from|export\s+\*\s+from|export\s+\{\s*default
glob: "**/index.{ts,tsx,js,jsx}"
```

Component directories without barrel exports make imports verbose and signal a disorganized component library.

### 0-7. Check component file size

Read each component file and flag:
- Files over 300 lines: likely needs decomposition
- Files over 500 lines: definitely needs decomposition
- Files with more than 3 `useState`/`useEffect` hooks: likely too complex for a single component

---

## Tier 1: Automated Browser Checks

### Script 1 — measureComponentReuse

```javascript
(() => {
  const results = {
    totalElements: 0,
    uniquePatterns: 0,
    reuseRatio: 0,
    patterns: [],
    singleUsePatterns: [],
    highReusePatterns: []
  };

  const fingerprint = (el) => {
    const tag = el.tagName.toLowerCase();
    const classes = [...el.classList].sort().join('.');
    const attrs = [...el.attributes]
      .filter(a => ['role', 'type', 'data-testid', 'data-component', 'aria-label'].includes(a.name))
      .map(a => `${a.name}=${a.value}`)
      .sort()
      .join(',');
    const childTags = [...el.children].map(c => c.tagName.toLowerCase()).join('+');
    return `${tag}|${classes}|${attrs}|${childTags}`;
  };

  const patternMap = new Map();
  const allEls = document.querySelectorAll('body *');
  results.totalElements = allEls.length;

  allEls.forEach(el => {
    if (['SCRIPT', 'STYLE', 'NOSCRIPT', 'BR', 'HR', 'WBR'].includes(el.tagName)) return;
    const fp = fingerprint(el);
    if (!fp || fp === '||') return;
    if (!patternMap.has(fp)) {
      patternMap.set(fp, { count: 0, sample: null });
    }
    const entry = patternMap.get(fp);
    entry.count++;
    if (!entry.sample) {
      const tag = el.tagName.toLowerCase();
      const id = el.id ? `#${el.id}` : '';
      const cls = el.className && typeof el.className === 'string'
        ? `.${el.className.split(/\s+/).slice(0, 3).join('.')}`
        : '';
      const text = (el.textContent || '').trim().slice(0, 40);
      entry.sample = { selector: `${tag}${id}${cls}`, text };
    }
  });

  results.uniquePatterns = patternMap.size;

  const sorted = [...patternMap.entries()]
    .map(([fp, data]) => ({ fingerprint: fp.slice(0, 100), ...data }))
    .sort((a, b) => b.count - a.count);

  results.singleUsePatterns = sorted
    .filter(p => p.count === 1)
    .slice(0, 20)
    .map(p => ({ fingerprint: p.fingerprint, sample: p.sample }));

  results.highReusePatterns = sorted
    .filter(p => p.count >= 3)
    .slice(0, 20)
    .map(p => ({ fingerprint: p.fingerprint, count: p.count, sample: p.sample }));

  const reusedPatterns = sorted.filter(p => p.count > 1).length;
  results.reuseRatio = patternMap.size > 0
    ? Math.round((reusedPatterns / patternMap.size) * 100)
    : 0;

  results.patterns = sorted.slice(0, 30).map(p => ({
    fingerprint: p.fingerprint,
    count: p.count,
    sample: p.sample
  }));

  return results;
})();
```

### Script 2 — detectDuplicatePatterns

```javascript
(() => {
  const results = {
    totalCandidates: 0,
    duplicateGroups: [],
    recommendations: []
  };

  const structuralFingerprint = (el) => {
    const walk = (node, depth) => {
      if (depth > 6) return '';
      const tag = node.tagName ? node.tagName.toLowerCase() : '';
      if (!tag || ['script', 'style', 'noscript'].includes(tag)) return '';
      const childSigs = [...node.children].map(c => walk(c, depth + 1)).filter(Boolean);
      return `${tag}(${childSigs.join(',')})`;
    };
    return walk(el, 0);
  };

  const selectorFor = (el) => {
    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 3).join('.')}`
      : '';
    return `${tag}${id}${cls}`;
  };

  const candidates = document.querySelectorAll(
    'body div, body section, body article, body aside, body nav, body main, body form, body ul, body ol'
  );

  const structureMap = new Map();

  candidates.forEach(el => {
    if (el.children.length < 2 || el.children.length > 30) return;
    const fp = structuralFingerprint(el);
    if (fp.length < 10) return;

    if (!structureMap.has(fp)) {
      structureMap.set(fp, []);
    }
    structureMap.get(fp).push(el);
  });

  const duplicateGroups = [...structureMap.entries()]
    .filter(([_, els]) => els.length >= 2)
    .sort((a, b) => b[1].length - a[1].length)
    .slice(0, 15);

  results.totalCandidates = candidates.length;

  duplicateGroups.forEach(([fp, els]) => {
    const samples = els.slice(0, 4).map(el => {
      const classes = el.className && typeof el.className === 'string'
        ? el.className.split(/\s+/).filter(Boolean)
        : [];
      return {
        selector: selectorFor(el),
        classNames: classes.slice(0, 5),
        childCount: el.children.length,
        textPreview: (el.textContent || '').trim().slice(0, 60)
      };
    });

    const classSets = samples.map(s => new Set(s.classNames));
    const allSameClasses = classSets.length > 1 &&
      classSets.every(s => {
        const first = classSets[0];
        return s.size === first.size && [...s].every(c => first.has(c));
      });

    results.duplicateGroups.push({
      structureFingerprint: fp.slice(0, 120),
      instanceCount: els.length,
      sameClasses: allSameClasses,
      isComponent: allSameClasses,
      needsComponentization: !allSameClasses && els.length >= 3,
      samples
    });
  });

  results.duplicateGroups
    .filter(g => g.needsComponentization)
    .forEach(g => {
      results.recommendations.push(
        `${g.instanceCount} elements share identical DOM structure (${g.structureFingerprint.slice(0, 60)}) but have different classes — extract into a reusable component`
      );
    });

  if (results.duplicateGroups.filter(g => g.isComponent).length > 0) {
    const totalReused = results.duplicateGroups
      .filter(g => g.isComponent)
      .reduce((sum, g) => sum + g.instanceCount, 0);
    results.recommendations.push(
      `${totalReused} elements appear to be reused components (same structure + classes) — good composition`
    );
  }

  return results;
})();
```

### Script 3 — checkCompositionDepth

```javascript
(() => {
  const results = {
    maxDepth: 0,
    avgDepth: 0,
    depthDistribution: {},
    tooDeep: [],
    tooFlat: [],
    componentLikeElements: 0
  };

  const isComponentLike = (el) => {
    if (!el.tagName) return false;
    const tag = el.tagName.toLowerCase();
    if (['div', 'section', 'article', 'aside', 'nav', 'main', 'header', 'footer', 'form'].includes(tag)) {
      const hasMultipleChildren = el.children.length >= 2;
      const hasClasses = el.classList && el.classList.length > 0;
      const hasRole = el.hasAttribute('role');
      const hasDataAttr = [...el.attributes].some(a => a.name.startsWith('data-'));
      return hasMultipleChildren && (hasClasses || hasRole || hasDataAttr);
    }
    return false;
  };

  const measureDepth = (el) => {
    let depth = 0;
    let current = el;
    while (current.parentElement && current.parentElement !== document.body) {
      if (isComponentLike(current.parentElement)) {
        depth++;
      }
      current = current.parentElement;
    }
    return depth;
  };

  const componentEls = [];
  const allEls = document.querySelectorAll('body *');
  allEls.forEach(el => {
    if (isComponentLike(el)) {
      componentEls.push(el);
    }
  });

  results.componentLikeElements = componentEls.length;

  const selectorFor = (el) => {
    const tag = el.tagName.toLowerCase();
    const id = el.id ? `#${el.id}` : '';
    const cls = el.className && typeof el.className === 'string'
      ? `.${el.className.split(/\s+/).filter(Boolean).slice(0, 2).join('.')}`
      : '';
    return `${tag}${id}${cls}`;
  };

  let totalDepth = 0;
  const depths = [];

  componentEls.forEach(el => {
    const depth = measureDepth(el);
    depths.push(depth);
    totalDepth += depth;

    const bucket = String(depth);
    results.depthDistribution[bucket] = (results.depthDistribution[bucket] || 0) + 1;

    if (depth > 5 && results.tooDeep.length < 10) {
      results.tooDeep.push({
        selector: selectorFor(el),
        depth,
        childCount: el.children.length,
        textPreview: (el.textContent || '').trim().slice(0, 50)
      });
    }

    const directChildren = el.children.length;
    if (directChildren > 20 && depth < 2 && results.tooFlat.length < 10) {
      results.tooFlat.push({
        selector: selectorFor(el),
        directChildren,
        depth,
        childTags: [...el.children].slice(0, 10).map(c => c.tagName.toLowerCase())
      });
    }
  });

  results.maxDepth = depths.length > 0 ? Math.max(...depths) : 0;
  results.avgDepth = depths.length > 0
    ? Math.round((totalDepth / depths.length) * 10) / 10
    : 0;

  return results;
})();
```

### Script 4 — measureComponentCoverage

```javascript
(() => {
  const results = {
    patterns: {},
    overallConsistency: 0,
    totalPatterns: 0,
    consistentPatterns: 0,
    recommendations: []
  };

  const analyzePattern = (selector, label) => {
    const els = document.querySelectorAll(selector);
    if (els.length === 0) return null;

    const implementations = new Map();

    els.forEach(el => {
      const tag = el.tagName.toLowerCase();
      const classes = el.className && typeof el.className === 'string'
        ? [...el.classList].sort().join(' ')
        : '';
      const key = `${tag}|${classes}`;

      if (!implementations.has(key)) {
        implementations.set(key, { count: 0, sample: null });
      }
      const entry = implementations.get(key);
      entry.count++;
      if (!entry.sample) {
        const id = el.id ? `#${el.id}` : '';
        const cls = classes ? `.${classes.split(' ').slice(0, 3).join('.')}` : '';
        entry.sample = `${tag}${id}${cls}`;
      }
    });

    const sorted = [...implementations.entries()]
      .sort((a, b) => b[1].count - a[1].count);

    const dominantCount = sorted[0] ? sorted[0][1].count : 0;
    const totalCount = els.length;
    const consistency = totalCount > 0
      ? Math.round((dominantCount / totalCount) * 100)
      : 0;

    return {
      label,
      totalInstances: totalCount,
      uniqueImplementations: implementations.size,
      consistency,
      isConsistent: implementations.size <= 2 && consistency >= 70,
      implementations: sorted.slice(0, 5).map(([key, data]) => ({
        signature: key.slice(0, 80),
        count: data.count,
        sample: data.sample
      }))
    };
  };

  const patternChecks = [
    { selector: 'button, [role="button"], input[type="submit"], input[type="button"]', label: 'Buttons' },
    { selector: 'input:not([type="hidden"]):not([type="submit"]):not([type="button"]), textarea, select', label: 'Form Inputs' },
    { selector: '[class*="card"], [class*="Card"], article', label: 'Cards' },
    { selector: 'ul, ol, [role="list"]', label: 'Lists' },
    { selector: '[class*="badge"], [class*="Badge"], [class*="tag"], [class*="Tag"], [class*="chip"], [class*="Chip"]', label: 'Badges/Tags' },
    { selector: '[class*="avatar"], [class*="Avatar"], img[class*="profile"], img[class*="user"]', label: 'Avatars' },
    { selector: '[class*="modal"], [class*="Modal"], [class*="dialog"], [role="dialog"]', label: 'Modals/Dialogs' },
    { selector: 'table, [role="table"], [class*="table"], [class*="Table"]', label: 'Tables' },
    { selector: 'nav, [role="navigation"]', label: 'Navigation' },
    { selector: '[class*="tooltip"], [class*="Tooltip"], [role="tooltip"]', label: 'Tooltips' }
  ];

  let consistentCount = 0;
  let totalChecked = 0;

  patternChecks.forEach(({ selector, label }) => {
    const analysis = analyzePattern(selector, label);
    if (analysis && analysis.totalInstances > 0) {
      results.patterns[label] = analysis;
      totalChecked++;
      if (analysis.isConsistent) consistentCount++;

      if (!analysis.isConsistent && analysis.totalInstances >= 3) {
        results.recommendations.push(
          `${label}: ${analysis.uniqueImplementations} different implementations found across ${analysis.totalInstances} instances — standardize into a single reusable component`
        );
      }
    }
  });

  results.totalPatterns = totalChecked;
  results.consistentPatterns = consistentCount;
  results.overallConsistency = totalChecked > 0
    ? Math.round((consistentCount / totalChecked) * 100)
    : 0;

  return results;
})();
```

---

## Tier 2: AI Evaluation

Examine the screenshots, DOM snapshots, and Tier 0/1 results, then answer each question with a rating (good / acceptable / needs-work) and brief justification.

1. **Clear hierarchy** — Is there a clear hierarchy from atoms to pages? Can you visually identify atoms, molecules, and organisms in the rendered UI?
2. **Genuine composition** — Are molecules genuinely composed from atoms, or do they reinvent base elements (e.g., a search bar that builds its own input instead of importing the shared Input atom)?
3. **Extraction opportunities** — Are there obvious opportunities to extract reusable components from repeated visual patterns on the page?
4. **Intentional structure** — Does the component structure feel intentional and designed, or organic and accidental (grown over time without a plan)?
5. **Decomposition needs** — Are there components that are too large and should be decomposed into smaller atomic pieces?
6. **Directory organization** — Is there a consistent component directory structure (e.g., `atoms/`, `molecules/`, `organisms/` or `ui/`, `features/`, `layouts/`)?
7. **Discoverability** — Would a new developer know where to find or create a component based on the file organization and naming alone?
8. **Consistency across pages** — Do different pages/views use the same components, or do they each have their own slightly different implementations of the same UI patterns?

---

## Scoring Criteria

| Score | Criteria |
|-------|----------|
| **5** | Clear atomic hierarchy with >80% reuse rate. Consistent composition where organisms use molecules and molecules use atoms. Well-organized directory structure. Barrel exports. All common patterns componentized. |
| **4** | Good hierarchy with minor reuse gaps. Most organisms compose molecules properly. Some one-off components that could be generalized. Directory structure is mostly consistent. |
| **3** | Some reusable components exist but composition is inconsistent. Mix of composed components and components that reinvent base elements. Moderate reuse rate (40-60%). |
| **2** | Mostly ad-hoc components with low reuse. No clear atomic hierarchy. Components frequently use raw HTML elements instead of shared atoms. Many duplicated patterns. |
| **1** | No component system. Everything is built inline or as monolithic page components. Zero reuse. Each page reinvents all UI elements from scratch. |

---

## Common Fixes

### Extract repeated patterns into shared atom components

```tsx
/* Before — raw button in every organism */
<button className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">
  Save
</button>

/* After — shared Button atom */
import { Button } from '@/components/ui/Button';
<Button variant="primary">Save</Button>
```

### Compose molecules from atoms instead of raw HTML

```tsx
/* Before — molecule reinvents the input */
function SearchBar() {
  return (
    <div className="flex gap-2">
      <input className="border rounded px-3 py-2" placeholder="Search..." />
      <button className="bg-blue-500 text-white px-4 py-2 rounded">Go</button>
    </div>
  );
}

/* After — molecule composes atoms */
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';

function SearchBar() {
  return (
    <div className="flex gap-2">
      <Input placeholder="Search..." />
      <Button variant="primary">Go</Button>
    </div>
  );
}
```

### Restructure directories with atomic design tiers

```
src/components/
  ui/               # Atoms — Button, Input, Badge, Avatar, Icon, Divider
  patterns/          # Molecules — SearchBar, FormField, NavItem, MediaObject
  blocks/            # Organisms — Header, Footer, Card, Sidebar, Modal, DataTable
  layouts/           # Templates — DashboardLayout, AuthLayout, PageLayout
```

### Add barrel exports for clean imports

```typescript
// src/components/ui/index.ts
export { Button } from './Button';
export { Input } from './Input';
export { Badge } from './Badge';
export { Avatar } from './Avatar';
export { Icon } from './Icon';
export { Tooltip } from './Tooltip';
```

### Split oversized components

```tsx
/* Before — 400-line Card component */
function ProductCard({ product }) {
  // ... 400 lines of mixed concerns
}

/* After — decomposed into molecules */
function ProductCard({ product }) {
  return (
    <Card>
      <ProductImage src={product.image} alt={product.name} />
      <ProductDetails name={product.name} description={product.description} />
      <ProductPricing price={product.price} discount={product.discount} />
      <ProductActions productId={product.id} />
    </Card>
  );
}
```

### Consolidate duplicate component variants

```tsx
/* Before — multiple button files */
// PrimaryButton.tsx, SubmitButton.tsx, ActionButton.tsx, CancelButton.tsx

/* After — single Button with variants */
// Button.tsx
type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'ghost';

function Button({ variant = 'primary', children, ...props }: ButtonProps) {
  const styles = variantStyles[variant];
  return <button className={styles} {...props}>{children}</button>;
}
```
