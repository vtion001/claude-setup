# Pass 13: Performance Perception

## Tier 1: Automated Checks

### Core Web Vitals — LCP & CLS

```javascript
(() => {
  const results = { check: "core-web-vitals", issues: [], stats: {} };

  // LCP from Performance API
  let lcp = null;
  try {
    const lcpEntries = performance.getEntriesByType('largest-contentful-paint');
    if (lcpEntries.length > 0) {
      const lastEntry = lcpEntries[lcpEntries.length - 1];
      lcp = {
        value: Math.round(lastEntry.startTime),
        element: lastEntry.element ? lastEntry.element.tagName.toLowerCase() + (lastEntry.element.id ? '#' + lastEntry.element.id : '') : 'unknown',
        size: lastEntry.size,
        url: lastEntry.url || null,
        rating: lastEntry.startTime <= 2500 ? 'good' : lastEntry.startTime <= 4000 ? 'needs-improvement' : 'poor'
      };
    }
  } catch (e) { lcp = { error: 'LCP API not available' }; }

  // CLS from Layout Shift entries
  let cls = { value: 0, shifts: [] };
  try {
    const layoutShiftEntries = performance.getEntriesByType('layout-shift');
    let totalCLS = 0;
    layoutShiftEntries.forEach(entry => {
      if (!entry.hadRecentInput) {
        totalCLS += entry.value;
        if (entry.value > 0.01) {
          cls.shifts.push({
            value: Math.round(entry.value * 1000) / 1000,
            startTime: Math.round(entry.startTime),
            sources: entry.sources ? entry.sources.slice(0, 2).map(s => s.node ? s.node.tagName?.toLowerCase() : 'unknown') : []
          });
        }
      }
    });
    cls.value = Math.round(totalCLS * 1000) / 1000;
    cls.rating = cls.value <= 0.1 ? 'good' : cls.value <= 0.25 ? 'needs-improvement' : 'poor';
  } catch (e) { cls = { error: 'Layout Shift API not available' }; }

  // FCP
  let fcp = null;
  const paintEntries = performance.getEntriesByType('paint');
  const fcpEntry = paintEntries.find(e => e.name === 'first-contentful-paint');
  if (fcpEntry) {
    fcp = {
      value: Math.round(fcpEntry.startTime),
      rating: fcpEntry.startTime <= 1800 ? 'good' : fcpEntry.startTime <= 3000 ? 'needs-improvement' : 'poor'
    };
  }

  // TTFB
  const navEntry = performance.getEntriesByType('navigation')[0];
  let ttfb = null;
  if (navEntry) {
    const ttfbValue = Math.round(navEntry.responseStart - navEntry.startTime);
    ttfb = {
      value: ttfbValue,
      rating: ttfbValue <= 800 ? 'good' : ttfbValue <= 1800 ? 'needs-improvement' : 'poor'
    };
  }

  results.stats = { lcp, cls, fcp, ttfb };

  if (lcp && lcp.value && lcp.value > 2500) {
    results.issues.push({ type: 'slow-lcp', value: lcp.value, threshold: 2500, element: lcp.element, rating: lcp.rating });
  }
  if (cls && cls.value > 0.1) {
    results.issues.push({ type: 'high-cls', value: cls.value, threshold: 0.1, shifts: cls.shifts.slice(0, 3), rating: cls.rating });
  }
  if (fcp && fcp.value > 1800) {
    results.issues.push({ type: 'slow-fcp', value: fcp.value, threshold: 1800, rating: fcp.rating });
  }
  if (ttfb && ttfb.value > 800) {
    results.issues.push({ type: 'slow-ttfb', value: ttfb.value, threshold: 800, rating: ttfb.rating });
  }

  return results;
})()
```

### Skeleton vs Spinner Detection

```javascript
(() => {
  const results = { check: "loading-patterns", issues: [], stats: {} };

  // Detect skeleton screens
  const skeletonSelectors = [
    '[class*="skeleton"]', '[class*="shimmer"]', '[class*="placeholder"]',
    '[class*="loading"]', '[class*="pulse"]', '[class*="animate-pulse"]',
    '[data-loading]', '[data-skeleton]', '[aria-busy="true"]'
  ];

  const skeletons = [];
  skeletonSelectors.forEach(sel => {
    document.querySelectorAll(sel).forEach(el => {
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        skeletons.push({
          selector: sel,
          element: el.tagName.toLowerCase() + (el.className ? '.' + String(el.className).split(' ')[0] : ''),
          visible: getComputedStyle(el).display !== 'none'
        });
      }
    });
  });

  // Detect spinners
  const spinnerSelectors = [
    '[class*="spinner"]', '[class*="spin"]', '[class*="loader"]',
    '[class*="loading-indicator"]', '[class*="progress"]',
    '[role="progressbar"]', '[role="status"]',
    '.fa-spinner', '.fa-spin', '[class*="circular-progress"]'
  ];

  const spinners = [];
  spinnerSelectors.forEach(sel => {
    document.querySelectorAll(sel).forEach(el => {
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        const style = getComputedStyle(el);
        spinners.push({
          selector: sel,
          element: el.tagName.toLowerCase() + (el.className ? '.' + String(el.className).split(' ')[0] : ''),
          visible: style.display !== 'none' && style.visibility !== 'hidden',
          hasAnimation: style.animationName !== 'none' || style.animationName !== ''
        });
      }
    });
  });

  // Check for CSS animations that look like loading patterns
  const pulseAnimations = [];
  const allEls = document.querySelectorAll('*');
  for (let i = 0; i < Math.min(allEls.length, 500); i++) {
    const style = getComputedStyle(allEls[i]);
    if (style.animationName && (style.animationName.includes('pulse') || style.animationName.includes('shimmer') || style.animationName.includes('skeleton'))) {
      pulseAnimations.push({
        element: allEls[i].tagName.toLowerCase() + (allEls[i].className ? '.' + String(allEls[i].className).split(' ')[0] : ''),
        animation: style.animationName
      });
    }
    if (pulseAnimations.length >= 5) break;
  }

  const usesSkeletons = skeletons.length > 0 || pulseAnimations.length > 0;
  const usesSpinners = spinners.length > 0;

  results.stats = {
    skeletonCount: skeletons.length,
    spinnerCount: spinners.length,
    pulseAnimationCount: pulseAnimations.length,
    loadingStrategy: usesSkeletons ? 'skeleton' : usesSpinners ? 'spinner' : 'none-detected',
    recommendation: !usesSkeletons && !usesSpinners ? 'Consider adding skeleton screens for loading states' : usesSkeletons ? 'Good: using skeleton screens' : 'Consider upgrading spinners to skeleton screens for better perceived performance'
  };

  if (!usesSkeletons && !usesSpinners) {
    results.issues.push({ type: 'no-loading-indicators', message: 'No skeleton screens or loading indicators detected. Users may not know content is loading.' });
  }

  return results;
})()
```

### Lazy Loading & Oversized Images

```javascript
(() => {
  const results = { check: "image-optimization", issues: [], stats: {} };

  const viewportHeight = window.innerHeight;
  const images = Array.from(document.querySelectorAll('img'));

  // Check lazy loading for below-fold images
  const belowFoldImages = [];
  const aboveFoldImages = [];

  images.forEach(img => {
    const rect = img.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return;

    const isBelowFold = rect.top > viewportHeight;
    const isLazy = img.loading === 'lazy' || img.getAttribute('data-src') || img.getAttribute('data-lazy') || img.classList.contains('lazyload') || img.classList.contains('lazy');

    const entry = {
      src: (img.currentSrc || img.src || '').substring(0, 80),
      belowFold: isBelowFold,
      hasLazyLoading: isLazy,
      top: Math.round(rect.top)
    };

    if (isBelowFold) {
      belowFoldImages.push(entry);
    } else {
      aboveFoldImages.push(entry);
    }
  });

  const belowFoldNotLazy = belowFoldImages.filter(i => !i.hasLazyLoading);

  // Check for oversized images (natural dimensions > 2x display dimensions)
  const oversizedImages = images.map(img => {
    const rect = img.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return null;
    if (!img.naturalWidth || !img.naturalHeight) return null;

    const widthRatio = img.naturalWidth / rect.width;
    const heightRatio = img.naturalHeight / rect.height;
    const isOversized = widthRatio > 2 || heightRatio > 2;

    if (!isOversized) return null;

    return {
      src: (img.currentSrc || img.src || '').substring(0, 80),
      naturalWidth: img.naturalWidth,
      naturalHeight: img.naturalHeight,
      displayWidth: Math.round(rect.width),
      displayHeight: Math.round(rect.height),
      widthRatio: Math.round(widthRatio * 10) / 10,
      heightRatio: Math.round(heightRatio * 10) / 10,
      wastedPixels: (img.naturalWidth * img.naturalHeight) - (Math.round(rect.width) * Math.round(rect.height) * 4)
    };
  }).filter(Boolean);

  // Check for modern image formats
  const imageFormats = {};
  images.forEach(img => {
    const src = img.currentSrc || img.src || '';
    const ext = src.split('?')[0].split('.').pop()?.toLowerCase() || 'unknown';
    imageFormats[ext] = (imageFormats[ext] || 0) + 1;
  });

  // Check for <picture> with srcset (responsive images)
  const pictureElements = document.querySelectorAll('picture');
  const srcsetImages = document.querySelectorAll('img[srcset], img[sizes]');

  results.stats = {
    totalImages: images.length,
    aboveFoldCount: aboveFoldImages.length,
    belowFoldCount: belowFoldImages.length,
    belowFoldWithoutLazy: belowFoldNotLazy.length,
    oversizedCount: oversizedImages.length,
    imageFormats,
    pictureElements: pictureElements.length,
    responsiveImages: srcsetImages.length
  };

  if (belowFoldNotLazy.length > 0) {
    results.issues.push({
      type: 'missing-lazy-loading',
      count: belowFoldNotLazy.length,
      images: belowFoldNotLazy.slice(0, 5),
      fix: 'Add loading="lazy" to below-fold images'
    });
  }
  if (oversizedImages.length > 0) {
    results.issues.push({
      type: 'oversized-images',
      count: oversizedImages.length,
      images: oversizedImages.slice(0, 5),
      fix: 'Serve images at 2x display size maximum. Use srcset for responsive sizing.'
    });
  }

  return results;
})()
```

### Layout Shift During Load

```javascript
(() => {
  const results = { check: "layout-shift-sources", issues: [], stats: {} };

  // Images without dimensions (cause layout shift when loaded)
  const images = Array.from(document.querySelectorAll('img'));
  const imagesWithoutDimensions = images.filter(img => {
    const rect = img.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return false;
    const hasWidth = img.hasAttribute('width') || img.style.width || img.hasAttribute('data-width');
    const hasHeight = img.hasAttribute('height') || img.style.height || img.hasAttribute('data-height');
    const hasAspectRatio = getComputedStyle(img).aspectRatio !== 'auto';
    return !hasWidth || !hasHeight;
  }).map(img => ({
    src: (img.currentSrc || img.src || '').substring(0, 60),
    hasWidth: img.hasAttribute('width') || !!img.style.width,
    hasHeight: img.hasAttribute('height') || !!img.style.height,
    displayWidth: Math.round(img.getBoundingClientRect().width),
    displayHeight: Math.round(img.getBoundingClientRect().height)
  }));

  // Videos and iframes without dimensions
  const embeds = Array.from(document.querySelectorAll('video, iframe'));
  const embedsWithoutDimensions = embeds.filter(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return false;
    return !el.hasAttribute('width') || !el.hasAttribute('height');
  }).map(el => ({
    element: el.tagName.toLowerCase(),
    src: (el.src || '').substring(0, 60),
    hasWidth: el.hasAttribute('width'),
    hasHeight: el.hasAttribute('height')
  }));

  // Check for dynamic content that might shift (ads, late-loading components)
  const dynamicContainers = Array.from(document.querySelectorAll('[class*="ad"], [class*="banner"], [id*="ad-"], [data-ad], ins.adsbygoogle'));
  const adsWithoutReservedSpace = dynamicContainers.filter(el => {
    const style = getComputedStyle(el);
    return !style.minHeight || style.minHeight === '0px' || style.minHeight === 'auto';
  });

  // Check for web fonts that might cause FOUT/FOIT
  const fontLinks = document.querySelectorAll('link[href*="font"], link[href*="typekit"]');
  const fontFaceRules = [];
  try {
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules || []) {
          if (rule.type === CSSRule.FONT_FACE_RULE) {
            fontFaceRules.push(rule.style.fontFamily);
          }
        }
      } catch (e) { /* cross-origin */ }
    }
  } catch (e) { /* stylesheet access */ }

  const hasFontDisplay = (() => {
    try {
      for (const sheet of document.styleSheets) {
        try {
          for (const rule of sheet.cssRules || []) {
            if (rule.type === CSSRule.FONT_FACE_RULE) {
              const fontDisplay = rule.style.getPropertyValue('font-display');
              if (fontDisplay && fontDisplay !== 'auto') return true;
            }
          }
        } catch (e) { /* cross-origin */ }
      }
    } catch (e) { /* stylesheet access */ }
    return false;
  })();

  results.stats = {
    imagesWithoutDimensions: imagesWithoutDimensions.length,
    embedsWithoutDimensions: embedsWithoutDimensions.length,
    adsWithoutReservedSpace: adsWithoutReservedSpace.length,
    fontLinksCount: fontLinks.length,
    customFontCount: fontFaceRules.length,
    hasFontDisplay
  };

  if (imagesWithoutDimensions.length > 0) {
    results.issues.push({ type: 'images-no-dimensions', count: imagesWithoutDimensions.length, images: imagesWithoutDimensions.slice(0, 5), fix: 'Add width and height attributes to all <img> elements' });
  }
  if (embedsWithoutDimensions.length > 0) {
    results.issues.push({ type: 'embeds-no-dimensions', count: embedsWithoutDimensions.length, embeds: embedsWithoutDimensions.slice(0, 3) });
  }
  if (adsWithoutReservedSpace.length > 0) {
    results.issues.push({ type: 'ads-no-reserved-space', count: adsWithoutReservedSpace.length, fix: 'Add min-height to ad containers to reserve space' });
  }
  if (fontFaceRules.length > 0 && !hasFontDisplay) {
    results.issues.push({ type: 'no-font-display', message: 'Custom fonts detected without font-display property. This can cause FOUT/FOIT layout shifts.' });
  }

  return results;
})()
```

## Tier 2: AI Judgment

### Perceived Speed
When reviewing the page (both screenshot and load behavior):
1. Does the page **feel fast** — even if metrics are borderline, does the experience feel instant?
2. Is the **above-fold content** rendered quickly while below-fold loads progressively?
3. Are **critical resources** (hero image, main text, primary CTA) visible immediately?
4. Does the page feel **lighter than competitors** in the same category?
5. Are **animations smooth** (60fps feel) or do they stutter and feel janky?

### Progressive Painting
When reviewing load sequence:
1. Does the page **paint progressively** (content appears piece by piece) or does it flash all at once after a blank period?
2. Is there a **visible progression** — skeleton -> blurred placeholder -> full content?
3. Do **images load with blur-up or fade-in** instead of popping in abruptly?
4. Does the **layout remain stable** as content loads — no jumping or reflowing?
5. Is the **initial paint meaningful** — does the first frame show real content or just a blank shell?

### Action Feedback Immediacy
When reviewing interactive elements:
1. Do **buttons respond instantly** to clicks with visual feedback (pressed state, color change, ripple)?
2. Do **form submissions** show immediate feedback (loading spinner in button, disabled state)?
3. Does **navigation feel instant** — is there a page transition or loading bar?
4. Do **add-to-cart and similar actions** provide immediate visual confirmation (toast, animation, counter update)?
5. Are **loading states** shown within 100ms of user action (not after a visible delay)?
6. Is there **optimistic UI** — does the interface update before the server confirms (then roll back on error)?

### Loading Awareness
When reviewing loading states:
1. Does the user **always know what's happening** — is loading state clear and visible?
2. Are **progress bars** used for operations with known duration (file upload, multi-step processing)?
3. Are **spinners** used only for short, indeterminate operations (< 3 seconds)?
4. Is there a **timeout message** if loading takes too long ("This is taking longer than expected...")?
5. Are **empty states during loading** handled gracefully (not just blank space)?
6. Do **error states** from failed loads provide clear recovery paths (retry, go back)?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | LCP < 2.5s, CLS < 0.1. Skeleton screens for all async content. All below-fold images lazy-loaded. No oversized images (all <=2x display). No layout shift sources (images have dimensions, fonts have font-display). Page feels instant. Progressive paint with blur-up. Immediate action feedback everywhere. Clear loading awareness at all times. |
| 4 | LCP 2.5-3s, CLS < 0.15. Loading indicators present (skeleton or spinner). Most below-fold images lazy-loaded (1-2 missed). 1-2 oversized images. Minor layout shift sources. Page feels fast. Mostly progressive paint. Action feedback on primary interactions. Good loading awareness. |
| 3 | LCP 3-4s, CLS 0.15-0.25. Spinners but no skeletons. Some lazy loading. 3-5 oversized images. Several images without dimensions. Page feels adequate but not fast. Some progressive paint. Action feedback inconsistent. Loading states present but not comprehensive. |
| 2 | LCP 4-6s, CLS 0.25-0.5. Minimal loading indicators. No lazy loading. Many oversized images. Significant layout shifts. Page feels slow. No progressive paint (flash of blank then content). Delayed action feedback. Users unsure if actions worked. |
| 1 | LCP > 6s, CLS > 0.5. No loading indicators. No lazy loading. All images oversized. Massive layout shifts. Page feels broken. Long blank screen before content. No action feedback. No loading awareness — users don't know if page is working. |

## Common Fixes

### Lazy Loading
```html
<!-- Add loading="lazy" to below-fold images -->
<img src="photo.jpg" alt="Description" loading="lazy" width="800" height="600" />

<!-- Above-fold hero: use eager (default) + fetchpriority -->
<img src="hero.jpg" alt="Hero image" fetchpriority="high" width="1200" height="600" />
```

### Image Dimensions (Prevent CLS)
```html
<!-- Always include width and height -->
<img src="photo.jpg" alt="Description" width="800" height="600" />

<!-- Or use aspect-ratio in CSS -->
<!-- Tailwind: aspect-video or aspect-[4/3] -->
```
```css
img {
  aspect-ratio: attr(width) / attr(height);
  width: 100%;
  height: auto;
}
```

### Skeleton Screen
```css
/* Tailwind: animate-pulse bg-gray-200 rounded */
.skeleton {
  background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s ease-in-out infinite;
  border-radius: 4px;
}
@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
/* Skeleton shapes */
.skeleton-text { height: 1em; margin-bottom: 0.5em; border-radius: 4px; }
.skeleton-title { height: 1.5em; width: 60%; margin-bottom: 1em; }
.skeleton-avatar { width: 48px; height: 48px; border-radius: 50%; }
.skeleton-image { width: 100%; aspect-ratio: 16/9; }
```

### Font Display
```css
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom.woff2') format('woff2');
  font-display: swap; /* Show fallback immediately, swap when loaded */
}
/* Or use optional for non-critical fonts */
@font-face {
  font-family: 'DecorativeFont';
  src: url('/fonts/decorative.woff2') format('woff2');
  font-display: optional; /* Only use if already cached */
}
```

### Responsive Images
```html
<picture>
  <source srcset="photo-400.webp 400w, photo-800.webp 800w, photo-1200.webp 1200w"
          sizes="(max-width: 768px) 100vw, (max-width: 1024px) 50vw, 33vw"
          type="image/webp" />
  <img src="photo-800.jpg" alt="Description" width="800" height="600" loading="lazy" />
</picture>
```

### Button Loading State
```css
/* Tailwind: disabled:opacity-60 disabled:cursor-not-allowed */
button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
button .spinner {
  display: none;
}
button.loading .spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}
button.loading .label {
  visibility: hidden;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
```

### Reserve Space for Ads/Dynamic Content
```css
/* Tailwind: min-h-[250px] or aspect-[728/90] */
.ad-container {
  min-height: 250px; /* Standard ad height */
  background: #f9fafb; /* Subtle placeholder bg */
  display: flex;
  align-items: center;
  justify-content: center;
}
.ad-container::before {
  content: 'Advertisement';
  color: #9ca3af;
  font-size: 0.75rem;
}
```
