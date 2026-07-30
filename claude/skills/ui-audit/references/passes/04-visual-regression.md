# Pass 4: Visual Regression

Detects rendering anomalies, layout breakage, overflow issues, misalignment, clipped text, overlapping elements, and sub-pixel artifacts that indicate visual bugs. This is a browser-only pass focused entirely on what the user actually sees.

---

## Tier 0: Code Analysis

N/A -- This pass is browser-only. Visual regression issues are detected by inspecting the rendered DOM, not source code. Skip directly to Tier 1.

---

## Tier 1: Automated Browser Checks

### 4.1 detectOverflow

```javascript
(() => {
  const result = {
    scriptId: 'detectOverflow',
    timestamp: new Date().toISOString(),
    horizontalOverflows: [],
    verticalOverflows: [],
    bodyOverflow: { hasHorizontalScroll: false, hasVerticalScroll: false, scrollWidth: 0, clientWidth: 0 },
    totalOverflows: 0
  };

  const MAX_SAMPLES = 40;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const getPath = (el) => {
    const parts = [];
    let current = el;
    while (current && current !== document.body && parts.length < 4) {
      parts.unshift(getSelector(current));
      current = current.parentElement;
    }
    return parts.join(' > ');
  };

  const isScrollContainer = (el) => {
    const style = getComputedStyle(el);
    return (
      style.overflow === 'auto' || style.overflow === 'scroll' ||
      style.overflowX === 'auto' || style.overflowX === 'scroll' ||
      style.overflowY === 'auto' || style.overflowY === 'scroll'
    );
  };

  result.bodyOverflow = {
    hasHorizontalScroll: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    hasVerticalScroll: document.documentElement.scrollHeight > document.documentElement.clientHeight,
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
    scrollHeight: document.documentElement.scrollHeight,
    clientHeight: document.documentElement.clientHeight,
    overflowAmount: {
      horizontal: Math.max(0, document.documentElement.scrollWidth - document.documentElement.clientWidth),
      vertical: Math.max(0, document.documentElement.scrollHeight - document.documentElement.clientHeight)
    }
  };

  const allElements = document.querySelectorAll('body *');

  for (const el of allElements) {
    if (isScrollContainer(el)) continue;

    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;

    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;

    const hasHOverflow = el.scrollWidth > el.clientWidth + 1;
    const hasVOverflow = el.scrollHeight > el.clientHeight + 1;

    if (style.overflow === 'visible' || style.overflowX === 'visible') {
      if (hasHOverflow && el.scrollWidth - el.clientWidth > 5) {
        if (result.horizontalOverflows.length < MAX_SAMPLES) {
          result.horizontalOverflows.push({
            element: getSelector(el),
            path: getPath(el),
            scrollWidth: el.scrollWidth,
            clientWidth: el.clientWidth,
            overflowAmount: el.scrollWidth - el.clientWidth,
            overflow: style.overflow,
            position: { top: Math.round(rect.top), left: Math.round(rect.left) },
            size: { width: Math.round(rect.width), height: Math.round(rect.height) }
          });
        }
      }
    }

    if (style.overflow === 'visible' || style.overflowY === 'visible') {
      if (hasVOverflow && el.scrollHeight - el.clientHeight > 5) {
        if (result.verticalOverflows.length < MAX_SAMPLES) {
          result.verticalOverflows.push({
            element: getSelector(el),
            path: getPath(el),
            scrollHeight: el.scrollHeight,
            clientHeight: el.clientHeight,
            overflowAmount: el.scrollHeight - el.clientHeight,
            overflow: style.overflow,
            position: { top: Math.round(rect.top), left: Math.round(rect.left) },
            size: { width: Math.round(rect.width), height: Math.round(rect.height) }
          });
        }
      }
    }
  }

  const childOverflowingParent = [];
  for (const el of allElements) {
    const parent = el.parentElement;
    if (!parent || parent === document.body || parent === document.documentElement) continue;

    const parentStyle = getComputedStyle(parent);
    if (isScrollContainer(parent)) continue;
    if (parentStyle.overflow !== 'visible' && parentStyle.overflow !== '') continue;

    const childRect = el.getBoundingClientRect();
    const parentRect = parent.getBoundingClientRect();

    if (childRect.width === 0 || childRect.height === 0) continue;
    if (parentRect.width === 0 || parentRect.height === 0) continue;

    const overflowRight = childRect.right - parentRect.right;
    const overflowBottom = childRect.bottom - parentRect.bottom;
    const overflowLeft = parentRect.left - childRect.left;
    const overflowTop = parentRect.top - childRect.top;

    const threshold = 10;
    if (overflowRight > threshold || overflowBottom > threshold || overflowLeft > threshold || overflowTop > threshold) {
      if (childOverflowingParent.length < 20) {
        childOverflowingParent.push({
          child: getSelector(el),
          parent: getSelector(parent),
          overflow: {
            right: Math.round(Math.max(0, overflowRight)),
            bottom: Math.round(Math.max(0, overflowBottom)),
            left: Math.round(Math.max(0, overflowLeft)),
            top: Math.round(Math.max(0, overflowTop))
          }
        });
      }
    }
  }

  result.childOverflowingParent = childOverflowingParent;
  result.totalOverflows = result.horizontalOverflows.length + result.verticalOverflows.length + childOverflowingParent.length;

  result.summary = {
    bodyHasHorizontalScroll: result.bodyOverflow.hasHorizontalScroll,
    bodyHorizontalOverflow: result.bodyOverflow.overflowAmount.horizontal + 'px',
    horizontalOverflows: result.horizontalOverflows.length,
    verticalOverflows: result.verticalOverflows.length,
    childrenOverflowingParent: childOverflowingParent.length,
    totalOverflowIssues: result.totalOverflows,
    severity: result.bodyOverflow.hasHorizontalScroll ? 'CRITICAL'
      : result.totalOverflows > 10 ? 'HIGH'
      : result.totalOverflows > 3 ? 'MEDIUM'
      : result.totalOverflows > 0 ? 'LOW'
      : 'NONE'
  };

  return result;
})()
```

### 4.2 detectMisalignment

```javascript
(() => {
  const result = {
    scriptId: 'detectMisalignment',
    timestamp: new Date().toISOString(),
    flexMisalignments: [],
    gridMisalignments: [],
    textBaselineMisalignments: [],
    marginCollapseIssues: [],
    totalMisalignments: 0
  };

  const MAX_SAMPLES = 30;
  const TOLERANCE = 2;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const checkFlexGridContainers = (containerType) => {
    const containers = [];
    const allElements = document.querySelectorAll('body *');

    for (const el of allElements) {
      const style = getComputedStyle(el);
      if (style.display === containerType || style.display === `inline-${containerType}`) {
        containers.push(el);
      }
    }

    for (const container of containers.slice(0, 50)) {
      const children = Array.from(container.children).filter(child => {
        const s = getComputedStyle(child);
        const r = child.getBoundingClientRect();
        return s.display !== 'none' && s.visibility !== 'hidden' && s.position !== 'absolute' && s.position !== 'fixed' && r.width > 0 && r.height > 0;
      });

      if (children.length < 2) continue;

      const containerStyle = getComputedStyle(container);
      const isRow = containerType === 'flex'
        ? (!containerStyle.flexDirection || containerStyle.flexDirection === 'row' || containerStyle.flexDirection === 'row-reverse')
        : true;

      if (isRow) {
        const tops = children.map(c => Math.round(c.getBoundingClientRect().top));
        const bottoms = children.map(c => Math.round(c.getBoundingClientRect().bottom));

        const sameRow = children.filter(c => {
          const rect = c.getBoundingClientRect();
          return Math.abs(rect.top - children[0].getBoundingClientRect().top) < 50;
        });

        if (sameRow.length >= 2) {
          const rowTops = sameRow.map(c => Math.round(c.getBoundingClientRect().top));
          const topSpread = Math.max(...rowTops) - Math.min(...rowTops);

          if (topSpread > TOLERANCE) {
            const issues = containerType === 'flex' ? result.flexMisalignments : result.gridMisalignments;
            if (issues.length < MAX_SAMPLES) {
              issues.push({
                container: getSelector(container),
                childCount: children.length,
                topSpread: topSpread + 'px',
                alignment: containerStyle.alignItems || 'stretch',
                children: sameRow.slice(0, 4).map(c => ({
                  element: getSelector(c),
                  top: Math.round(c.getBoundingClientRect().top),
                  height: Math.round(c.getBoundingClientRect().height)
                }))
              });
            }
          }
        }
      } else {
        const lefts = children.map(c => Math.round(c.getBoundingClientRect().left));
        const leftSpread = Math.max(...lefts) - Math.min(...lefts);

        if (leftSpread > TOLERANCE && children.length >= 2) {
          const issues = containerType === 'flex' ? result.flexMisalignments : result.gridMisalignments;
          if (issues.length < MAX_SAMPLES) {
            issues.push({
              container: getSelector(container),
              childCount: children.length,
              leftSpread: leftSpread + 'px',
              alignment: containerStyle.alignItems || 'stretch',
              children: children.slice(0, 4).map(c => ({
                element: getSelector(c),
                left: Math.round(c.getBoundingClientRect().left)
              }))
            });
          }
        }
      }
    }
  };

  checkFlexGridContainers('flex');
  checkFlexGridContainers('grid');

  const inlineContainers = document.querySelectorAll('p, li, span, label, div, a');
  for (const container of Array.from(inlineContainers).slice(0, 100)) {
    const children = Array.from(container.children).filter(c => {
      const s = getComputedStyle(c);
      return s.display === 'inline' || s.display === 'inline-block' || s.display === 'inline-flex';
    });

    if (children.length < 2) continue;

    const baselines = children.map(c => {
      const rect = c.getBoundingClientRect();
      const style = getComputedStyle(c);
      const fontSize = parseFloat(style.fontSize);
      return Math.round(rect.bottom - fontSize * 0.2);
    });

    const baselineSpread = Math.max(...baselines) - Math.min(...baselines);
    if (baselineSpread > 3 && result.textBaselineMisalignments.length < MAX_SAMPLES) {
      result.textBaselineMisalignments.push({
        container: getSelector(container),
        baselineSpread: baselineSpread + 'px',
        children: children.slice(0, 3).map(c => ({
          element: getSelector(c),
          verticalAlign: getComputedStyle(c).verticalAlign,
          fontSize: getComputedStyle(c).fontSize,
          lineHeight: getComputedStyle(c).lineHeight
        }))
      });
    }
  }

  result.totalMisalignments = result.flexMisalignments.length + result.gridMisalignments.length + result.textBaselineMisalignments.length;

  result.summary = {
    flexMisalignments: result.flexMisalignments.length,
    gridMisalignments: result.gridMisalignments.length,
    textBaselineMisalignments: result.textBaselineMisalignments.length,
    totalMisalignments: result.totalMisalignments,
    severity: result.totalMisalignments > 15 ? 'HIGH'
      : result.totalMisalignments > 5 ? 'MEDIUM'
      : result.totalMisalignments > 0 ? 'LOW'
      : 'NONE'
  };

  return result;
})()
```

### 4.3 detectClippedText

```javascript
(() => {
  const result = {
    scriptId: 'detectClippedText',
    timestamp: new Date().toISOString(),
    ellipsisElements: [],
    overflowHiddenClipping: [],
    singleLineClipping: [],
    multiLineClipping: [],
    totalClipped: 0
  };

  const MAX_SAMPLES = 35;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    const text = el.textContent?.trim().substring(0, 30) || '';
    const base = classes ? `${tag}.${classes}` : tag;
    return text ? `${base} ("${text}...")` : base;
  };

  const textElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, p, span, a, li, td, th, label, button, [class*="title"], [class*="Title"], [class*="heading"], [class*="Heading"], [class*="description"], [class*="Description"], [class*="text"], [class*="label"], [class*="name"]');

  for (const el of textElements) {
    const style = getComputedStyle(el);
    const rect = el.getBoundingClientRect();

    if (style.display === 'none' || style.visibility === 'hidden') continue;
    if (rect.width === 0 || rect.height === 0) continue;
    if (!el.textContent?.trim()) continue;

    if (style.textOverflow === 'ellipsis') {
      const isActuallyClipped = el.scrollWidth > el.clientWidth + 1;
      if (result.ellipsisElements.length < MAX_SAMPLES) {
        result.ellipsisElements.push({
          element: getSelector(el),
          isCurrentlyClipped: isActuallyClipped,
          scrollWidth: el.scrollWidth,
          clientWidth: el.clientWidth,
          fullText: isActuallyClipped ? el.textContent.trim().substring(0, 100) : null,
          whiteSpace: style.whiteSpace,
          overflow: style.overflow
        });
      }
    }

    const webkitLineClamp = style.getPropertyValue('-webkit-line-clamp');
    if (webkitLineClamp && webkitLineClamp !== 'none') {
      const isClipped = el.scrollHeight > el.clientHeight + 1;
      if (result.multiLineClipping.length < MAX_SAMPLES) {
        result.multiLineClipping.push({
          element: getSelector(el),
          lineClamp: parseInt(webkitLineClamp),
          isCurrentlyClipped: isClipped,
          scrollHeight: el.scrollHeight,
          clientHeight: el.clientHeight,
          fullText: isClipped ? el.textContent.trim().substring(0, 150) : null
        });
      }
    }

    if (style.overflow === 'hidden' || style.overflowY === 'hidden') {
      if (style.textOverflow !== 'ellipsis' && (!webkitLineClamp || webkitLineClamp === 'none')) {
        const vClipped = el.scrollHeight > el.clientHeight + 2;
        const hClipped = el.scrollWidth > el.clientWidth + 2;

        if ((vClipped || hClipped) && result.overflowHiddenClipping.length < MAX_SAMPLES) {
          result.overflowHiddenClipping.push({
            element: getSelector(el),
            verticallyClipped: vClipped,
            horizontallyClipped: hClipped,
            scrollHeight: el.scrollHeight,
            clientHeight: el.clientHeight,
            scrollWidth: el.scrollWidth,
            clientWidth: el.clientWidth,
            hiddenAmount: {
              vertical: Math.max(0, el.scrollHeight - el.clientHeight),
              horizontal: Math.max(0, el.scrollWidth - el.clientWidth)
            },
            fullText: el.textContent.trim().substring(0, 150),
            severity: (vClipped && el.scrollHeight - el.clientHeight > 50) ? 'HIGH' : 'LOW'
          });
        }
      }
    }

    if (style.whiteSpace === 'nowrap' && style.textOverflow !== 'ellipsis' && style.overflow !== 'hidden') {
      if (el.scrollWidth > el.clientWidth + 5 && result.singleLineClipping.length < MAX_SAMPLES) {
        result.singleLineClipping.push({
          element: getSelector(el),
          scrollWidth: el.scrollWidth,
          clientWidth: el.clientWidth,
          overflowAmount: el.scrollWidth - el.clientWidth,
          issue: 'white-space:nowrap without text-overflow:ellipsis or overflow:hidden'
        });
      }
    }
  }

  result.totalClipped = result.ellipsisElements.filter(e => e.isCurrentlyClipped).length
    + result.overflowHiddenClipping.length
    + result.multiLineClipping.filter(e => e.isCurrentlyClipped).length
    + result.singleLineClipping.length;

  result.summary = {
    ellipsisElements: result.ellipsisElements.length,
    activelyClippedByEllipsis: result.ellipsisElements.filter(e => e.isCurrentlyClipped).length,
    overflowHiddenClipping: result.overflowHiddenClipping.length,
    multiLineClampElements: result.multiLineClipping.length,
    activelyClampClipped: result.multiLineClipping.filter(e => e.isCurrentlyClipped).length,
    unhandledNoWrap: result.singleLineClipping.length,
    totalActivelyClipped: result.totalClipped,
    severity: result.overflowHiddenClipping.filter(e => e.severity === 'HIGH').length > 0 ? 'HIGH'
      : result.totalClipped > 10 ? 'MEDIUM'
      : result.totalClipped > 0 ? 'LOW'
      : 'NONE'
  };

  return result;
})()
```

### 4.4 detectOverlappingElements

```javascript
(() => {
  const result = {
    scriptId: 'detectOverlappingElements',
    timestamp: new Date().toISOString(),
    overlaps: [],
    zIndexConflicts: [],
    stickyOverlaps: [],
    totalOverlaps: 0
  };

  const MAX_SAMPLES = 30;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const rectsOverlap = (a, b) => {
    return !(a.right <= b.left || a.left >= b.right || a.bottom <= b.top || a.top >= b.bottom);
  };

  const overlapArea = (a, b) => {
    const x = Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left));
    const y = Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
    return x * y;
  };

  const isParentChild = (a, b) => {
    return a.contains(b) || b.contains(a);
  };

  const positionedElements = [];
  const allElements = document.querySelectorAll('body *');

  for (const el of allElements) {
    const style = getComputedStyle(el);
    const rect = el.getBoundingClientRect();

    if (style.display === 'none' || style.visibility === 'hidden') continue;
    if (rect.width === 0 || rect.height === 0) continue;

    const isPositioned = style.position === 'absolute' || style.position === 'fixed' || style.position === 'sticky';
    const hasZIndex = style.zIndex !== 'auto' && parseInt(style.zIndex) > 0;
    const isNegativeMargin = parseFloat(style.marginTop) < -5 || parseFloat(style.marginLeft) < -5;
    const isTransformed = style.transform !== 'none';

    if (isPositioned || hasZIndex || isNegativeMargin || isTransformed) {
      positionedElements.push({
        el,
        rect,
        style,
        zIndex: parseInt(style.zIndex) || 0,
        position: style.position
      });
    }
  }

  for (let i = 0; i < positionedElements.length; i++) {
    for (let j = i + 1; j < positionedElements.length; j++) {
      const a = positionedElements[i];
      const b = positionedElements[j];

      if (isParentChild(a.el, b.el)) continue;

      if (rectsOverlap(a.rect, b.rect)) {
        const area = overlapArea(a.rect, b.rect);
        const smallerArea = Math.min(a.rect.width * a.rect.height, b.rect.width * b.rect.height);
        const overlapPercent = smallerArea > 0 ? Math.round((area / smallerArea) * 100) : 0;

        if (overlapPercent > 20 && result.overlaps.length < MAX_SAMPLES) {
          result.overlaps.push({
            elementA: getSelector(a.el),
            elementB: getSelector(b.el),
            overlapPercent: overlapPercent + '%',
            overlapArea: Math.round(area) + 'px2',
            zIndexA: a.zIndex,
            zIndexB: b.zIndex,
            positionA: a.position,
            positionB: b.position,
            rectA: { top: Math.round(a.rect.top), left: Math.round(a.rect.left), width: Math.round(a.rect.width), height: Math.round(a.rect.height) },
            rectB: { top: Math.round(b.rect.top), left: Math.round(b.rect.left), width: Math.round(b.rect.width), height: Math.round(b.rect.height) }
          });
        }

        if (a.zIndex === b.zIndex && a.zIndex > 0 && result.zIndexConflicts.length < MAX_SAMPLES) {
          result.zIndexConflicts.push({
            elementA: getSelector(a.el),
            elementB: getSelector(b.el),
            sharedZIndex: a.zIndex,
            issue: 'Same z-index on overlapping positioned elements creates unpredictable stacking'
          });
        }
      }
    }
  }

  const stickyElements = positionedElements.filter(p => p.position === 'sticky' || p.position === 'fixed');
  for (const sticky of stickyElements) {
    const stickyRect = sticky.rect;
    const contentElements = document.querySelectorAll('main *, article *, section *, [role="main"] *');

    for (const content of Array.from(contentElements).slice(0, 100)) {
      if (isParentChild(sticky.el, content)) continue;
      const contentRect = content.getBoundingClientRect();
      if (contentRect.width === 0 || contentRect.height === 0) continue;

      if (rectsOverlap(stickyRect, contentRect)) {
        const area = overlapArea(stickyRect, contentRect);
        if (area > 500 && result.stickyOverlaps.length < 10) {
          result.stickyOverlaps.push({
            stickyElement: getSelector(sticky.el),
            coveredContent: getSelector(content),
            position: sticky.position,
            zIndex: sticky.zIndex,
            overlapArea: Math.round(area) + 'px2',
            issue: 'Sticky/fixed element covers content below it'
          });
          break;
        }
      }
    }
  }

  result.totalOverlaps = result.overlaps.length + result.stickyOverlaps.length;

  result.summary = {
    positionedElementsFound: positionedElements.length,
    overlappingSiblings: result.overlaps.length,
    zIndexConflicts: result.zIndexConflicts.length,
    stickyContentOverlaps: result.stickyOverlaps.length,
    totalOverlapIssues: result.totalOverlaps,
    severity: result.stickyOverlaps.length > 0 ? 'HIGH'
      : result.overlaps.length > 5 ? 'MEDIUM'
      : result.overlaps.length > 0 ? 'LOW'
      : 'NONE'
  };

  return result;
})()
```

### 4.5 detectSubPixelIssues

```javascript
(() => {
  const result = {
    scriptId: 'detectSubPixelIssues',
    timestamp: new Date().toISOString(),
    fractionalPositions: [],
    fractionalSizes: [],
    nonIntegerImages: [],
    oddDimensionElements: [],
    transformOriginIssues: [],
    totalIssues: 0
  };

  const MAX_SAMPLES = 30;
  const SIGNIFICANT_FRACTION = 0.01;

  const getSelector = (el) => {
    if (el.id) return `#${el.id}`;
    const classes = Array.from(el.classList).slice(0, 3).join('.');
    const tag = el.tagName.toLowerCase();
    return classes ? `${tag}.${classes}` : tag;
  };

  const hasFraction = (value) => {
    const frac = Math.abs(value - Math.round(value));
    return frac > SIGNIFICANT_FRACTION && frac < (1 - SIGNIFICANT_FRACTION);
  };

  const allElements = document.querySelectorAll('body *');

  for (const el of Array.from(allElements).slice(0, 500)) {
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;

    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) continue;

    if ((hasFraction(rect.left) || hasFraction(rect.top)) && result.fractionalPositions.length < MAX_SAMPLES) {
      const isTransformed = style.transform !== 'none';
      const isPercentBased = style.left?.includes('%') || style.top?.includes('%');

      if (!isTransformed && !isPercentBased) {
        result.fractionalPositions.push({
          element: getSelector(el),
          left: Math.round(rect.left * 100) / 100,
          top: Math.round(rect.top * 100) / 100,
          position: style.position,
          issue: 'Sub-pixel position may cause blurry rendering on non-retina displays'
        });
      }
    }

    if ((hasFraction(rect.width) || hasFraction(rect.height)) && result.fractionalSizes.length < MAX_SAMPLES) {
      const hasBorder = parseFloat(style.borderWidth) > 0;
      if (hasBorder) {
        result.fractionalSizes.push({
          element: getSelector(el),
          width: Math.round(rect.width * 100) / 100,
          height: Math.round(rect.height * 100) / 100,
          borderWidth: style.borderWidth,
          issue: 'Fractional size with borders may render inconsistently'
        });
      }
    }
  }

  const images = document.querySelectorAll('img, picture img, svg, [class*="icon"], [class*="Icon"]');
  for (const img of images) {
    const rect = img.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) continue;

    if ((hasFraction(rect.width) || hasFraction(rect.height)) && result.nonIntegerImages.length < MAX_SAMPLES) {
      result.nonIntegerImages.push({
        element: getSelector(img),
        renderedWidth: Math.round(rect.width * 100) / 100,
        renderedHeight: Math.round(rect.height * 100) / 100,
        naturalWidth: img.naturalWidth || null,
        naturalHeight: img.naturalHeight || null,
        issue: 'Non-integer image dimensions cause blurry rendering'
      });
    }
  }

  const borderedElements = document.querySelectorAll('hr, [class*="divider"], [class*="Divider"], [class*="separator"], [class*="border"]');
  for (const el of borderedElements) {
    const rect = el.getBoundingClientRect();
    const style = getComputedStyle(el);
    if (rect.width === 0 && rect.height === 0) continue;

    const borderWidths = [
      parseFloat(style.borderTopWidth),
      parseFloat(style.borderRightWidth),
      parseFloat(style.borderBottomWidth),
      parseFloat(style.borderLeftWidth)
    ].filter(w => w > 0);

    for (const bw of borderWidths) {
      if (hasFraction(bw) && result.oddDimensionElements.length < MAX_SAMPLES) {
        result.oddDimensionElements.push({
          element: getSelector(el),
          borderWidth: bw,
          issue: 'Fractional border-width renders inconsistently across browsers'
        });
        break;
      }
    }
  }

  const transformedElements = document.querySelectorAll('[style*="transform"]');
  for (const el of transformedElements) {
    const style = getComputedStyle(el);
    if (style.transform === 'none') continue;

    const origin = style.transformOrigin;
    const parts = origin.split(' ').map(parseFloat);
    const hasSubPixelOrigin = parts.some(p => hasFraction(p));

    if (hasSubPixelOrigin && result.transformOriginIssues.length < MAX_SAMPLES) {
      result.transformOriginIssues.push({
        element: getSelector(el),
        transformOrigin: origin,
        transform: style.transform.substring(0, 60),
        issue: 'Sub-pixel transform-origin may cause blurry transforms'
      });
    }
  }

  result.totalIssues = result.fractionalPositions.length + result.fractionalSizes.length
    + result.nonIntegerImages.length + result.oddDimensionElements.length + result.transformOriginIssues.length;

  result.summary = {
    fractionalPositions: result.fractionalPositions.length,
    fractionalSizes: result.fractionalSizes.length,
    nonIntegerImages: result.nonIntegerImages.length,
    fractionalBorders: result.oddDimensionElements.length,
    subPixelTransforms: result.transformOriginIssues.length,
    totalSubPixelIssues: result.totalIssues,
    severity: result.nonIntegerImages.length > 5 ? 'MEDIUM'
      : result.totalIssues > 10 ? 'LOW'
      : 'NONE',
    note: 'Sub-pixel issues are most visible on 1x (non-retina) displays'
  };

  return result;
})()
```

---

## Tier 2: AI Evaluation

After collecting Tier 1 data, examine screenshots and DOM snapshots to answer these questions:

1. **Are there any visible rendering anomalies in the screenshot?** Look for: text bleeding outside containers, elements stacked on top of each other unexpectedly, partial borders, misaligned icons next to text, backgrounds not covering their full container, or phantom scrollbars.

2. **Do elements that should be aligned actually appear aligned?** Check: are navigation items level? Are form labels aligned with their inputs? Are grid card heights consistent? Are list items flush left? Use the grid overlay mentally to check pixel-level alignment.

3. **Is text being clipped anywhere it shouldn't be?** Look for: truncated headings that should show in full, descriptions cut off mid-sentence without ellipsis, text disappearing behind fixed/sticky elements, or text hidden by overflow:hidden containers.

4. **Are there layout shifts visible between breakpoints that look accidental vs intentional?** Accidental: content suddenly wrapping, elements jumping to unexpected positions, orphaned items on new lines, spacing collapsing to zero. Intentional: responsive reflow from multi-column to single-column, navigation collapsing to hamburger.

5. **Do responsive transitions look designed or just "squished"?** At smaller viewports, does the layout gracefully adapt (reflow, reorganize, re-prioritize), or does it just compress everything horizontally until it breaks?

6. **Are there any elements that appear to be fighting for space?** Look for: overlapping content without clear z-index hierarchy, elements pushed off-screen by siblings, content jammed against viewport edges with no margin, or fixed/sticky elements covering scrollable content without adequate padding.

---

## Scoring Criteria

| Score | Overflow | Alignment | Clipping | Overlaps | Sub-pixel |
|-------|----------|-----------|----------|----------|-----------|
| **5** | Zero overflow issues at any breakpoint, no unwanted scrollbars | Pixel-perfect alignment everywhere | No unintentional text clipping | No overlapping elements | No visible sub-pixel artifacts |
| **4** | 1-2 minor overflow at edge breakpoints only | Alignment solid, 1-2 hairline deviations | Minor ellipsis usage, no lost content | Rare overlap, properly z-indexed | Minor sub-pixel, not user-visible |
| **3** | Several overflows but not on primary content | Some alignment gaps on secondary content | Several clipped areas but not on critical text | A few overlaps needing attention | Some blurry images/borders |
| **2** | Obvious overflow on main content areas | Multiple visible misalignments | Important text being clipped or hidden | Overlapping elements causing confusion | Visible rendering artifacts |
| **1** | Page has horizontal scrollbar, major layout breakage | Widespread misalignment, no visual structure | Critical content hidden or inaccessible | Major overlapping making content unreadable | Severe rendering issues |

---

## Common Fixes

### Fix content overflow
```css
/* Before: content escapes container */
.card-body { /* no overflow control */ }

/* After: contain overflow appropriately */
.card-body {
  overflow: hidden;       /* clip content */
  /* OR */
  overflow-wrap: break-word;  /* allow text to wrap */
  word-break: break-word;
  /* OR */
  min-width: 0;          /* allow flex children to shrink */
}
```

### Fix body horizontal scroll
```css
/* Before: something is wider than the viewport */
/* After: contain all children */
html, body {
  overflow-x: hidden;  /* last resort */
}
/* Better: find the offending element */
.offending-element {
  max-width: 100%;
  box-sizing: border-box;
}
```

### Fix flex alignment
```css
/* Before: misaligned items */
.row { display: flex; }

/* After: explicit alignment */
.row {
  display: flex;
  align-items: center;     /* vertical alignment */
  /* OR */
  align-items: baseline;   /* for text alignment */
}
```

### Fix clipped text
```css
/* Before: text cut off without indicator */
.title {
  overflow: hidden;
  height: 24px;
}

/* After: proper truncation with indicator */
.title {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  /* OR for multi-line: */
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
```

### Fix z-index stacking
```css
/* Before: competing z-index values */
.header { position: sticky; z-index: 100; }
.modal { position: fixed; z-index: 50; }

/* After: systematic z-index scale */
:root {
  --z-dropdown: 100;
  --z-sticky: 200;
  --z-modal-backdrop: 300;
  --z-modal: 400;
  --z-toast: 500;
  --z-tooltip: 600;
}
.header { position: sticky; z-index: var(--z-sticky); }
.modal { position: fixed; z-index: var(--z-modal); }
```

### Fix sticky element covering content
```css
/* Before: sticky header covers content */
.header { position: sticky; top: 0; height: 64px; }

/* After: add scroll-padding so anchored/scrolled content clears the header */
html {
  scroll-padding-top: 64px;
}
/* Or add padding to main content */
main {
  padding-top: 64px;
}
```

### Fix sub-pixel image rendering
```css
/* Before: fractional image dimensions */
img { width: 33.33%; }

/* After: integer pixel dimensions */
img {
  width: 100%;
  max-width: 33.33%;
  image-rendering: -webkit-optimize-contrast; /* crisp edges */
}
/* Or use explicit integer sizing */
img { width: 200px; height: 150px; object-fit: cover; }
```
