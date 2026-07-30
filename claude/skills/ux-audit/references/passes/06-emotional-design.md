# Pass 6: Emotional Design

## Tier 1: Automated Checks

### 6.1 Custom Illustration and Visual Identity Detection

```javascript
(() => {
  const images = document.querySelectorAll('img');
  const svgs = document.querySelectorAll('svg');
  const findings = { illustrations: [], stockPhotos: [], icons: [], decorative: [] };
  const issues = [];

  images.forEach(img => {
    const src = (img.src || '').toLowerCase();
    const alt = (img.alt || '').toLowerCase();
    const rect = img.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const isLarge = rect.width > 200 || rect.height > 200;
    const isStock = /unsplash|pexels|shutterstock|istockphoto|gettyimages|stock|placeholder|lorem|picsum|placehold/i.test(src);
    const isAvatar = /avatar|profile|user/i.test(src) || /avatar|profile|user/i.test(img.className || '');
    const isDecorative = !img.alt || img.alt === '' || img.getAttribute('role') === 'presentation';

    const entry = {
      src: src.substring(0, 80),
      alt: alt.substring(0, 40),
      width: Math.round(rect.width),
      height: Math.round(rect.height),
      isStock,
      isDecorative
    };

    if (isStock && isLarge) {
      findings.stockPhotos.push(entry);
    } else if (isLarge && !isAvatar) {
      findings.illustrations.push(entry);
    } else if (!isLarge) {
      findings.icons.push(entry);
    }

    if (isDecorative && isLarge) {
      findings.decorative.push(entry);
    }
  });

  const inlineSvgs = [];
  svgs.forEach(svg => {
    const rect = svg.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const pathCount = svg.querySelectorAll('path, circle, rect, polygon, line, ellipse').length;
    const isIllustration = pathCount > 10 || (rect.width > 100 && rect.height > 100);
    const isIcon = pathCount <= 10 && rect.width <= 48;

    if (isIllustration) {
      inlineSvgs.push({
        type: 'illustration',
        pathCount,
        width: Math.round(rect.width),
        height: Math.round(rect.height),
        ariaLabel: svg.getAttribute('aria-label') || ''
      });
    }
  });

  if (findings.stockPhotos.length > 0 && findings.illustrations.length === 0 && inlineSvgs.length === 0) {
    issues.push({
      type: 'stock-only',
      count: findings.stockPhotos.length,
      message: 'Page uses only stock photography with no custom illustrations. Custom illustrations create stronger brand identity and emotional connection.'
    });
  }

  if (findings.illustrations.length === 0 && inlineSvgs.length === 0 && findings.stockPhotos.length === 0) {
    issues.push({
      type: 'no-visuals',
      message: 'No illustrations or meaningful images detected. Visual elements create emotional engagement and break up text content.'
    });
  }

  return {
    totalImages: images.length,
    stockPhotos: findings.stockPhotos.length,
    customIllustrations: findings.illustrations.length,
    inlineSvgIllustrations: inlineSvgs.length,
    decorativeImages: findings.decorative.length,
    svgDetails: inlineSvgs.slice(0, 10),
    stockPhotoSources: findings.stockPhotos.map(s => s.src).slice(0, 10),
    issues
  };
})()
```

### 6.2 Copy Personality and Tone Detection

```javascript
(() => {
  const textElements = document.querySelectorAll('h1, h2, h3, p, button, a, [class*="hero"] *, [class*="cta"] *, [class*="tagline"], [class*="subtitle"], [class*="description"]');
  const issues = [];
  const analysis = {
    totalTextBlocks: 0,
    boilerplate: [],
    personality: [],
    microcopy: []
  };

  const boilerplatePatterns = [
    /lorem ipsum/i,
    /welcome to our website/i,
    /we are a leading/i,
    /best in class/i,
    /world-class/i,
    /cutting.?edge/i,
    /leverage\s+(our|the)/i,
    /synergy|synergize/i,
    /innovative solutions/i,
    /seamless(ly)?\s+integrat/i,
    /empowering?\s+(your|the|our)/i,
    /revolutioniz(e|ing)/i,
    /next.?gen(eration)?/i,
    /paradigm/i,
    /holistic approach/i,
    /end-to-end solution/i,
    /one-stop shop/i,
    /thought leader/i,
    /move the needle/i,
    /circle back/i
  ];

  const personalityIndicators = [
    { pattern: /\b(hey|hi|hello|howdy|yo)\b/i, trait: 'casual-greeting' },
    { pattern: /\b(awesome|amazing|cool|sweet|neat|love)\b/i, trait: 'enthusiastic' },
    { pattern: /\b(hmm|well|actually|btw|fyi)\b/i, trait: 'conversational' },
    { pattern: /!{2,}|\?!|👋|🎉|✨|🚀/i, trait: 'expressive-punctuation' },
    { pattern: /\b(we|our|us)\b.*\b(believe|think|care|love)\b/i, trait: 'human-voice' },
    { pattern: /\b(you|your|you'll|you're)\b/i, trait: 'user-centered' },
    { pattern: /\b(simple|easy|fast|quick|free)\b/i, trait: 'benefit-focused' }
  ];

  textElements.forEach(el => {
    const text = (el.textContent || '').trim();
    if (text.length < 5 || text.length > 500) return;
    analysis.totalTextBlocks++;

    boilerplatePatterns.forEach(pattern => {
      if (pattern.test(text)) {
        analysis.boilerplate.push({
          text: text.substring(0, 60),
          pattern: pattern.source,
          tag: el.tagName.toLowerCase()
        });
      }
    });

    personalityIndicators.forEach(({ pattern, trait }) => {
      if (pattern.test(text)) {
        analysis.personality.push({
          text: text.substring(0, 60),
          trait,
          tag: el.tagName.toLowerCase()
        });
      }
    });
  });

  const buttonTexts = document.querySelectorAll('button, [role="button"], input[type="submit"], a[class*="btn"], a[class*="button"]');
  buttonTexts.forEach(btn => {
    const text = (btn.textContent || btn.value || '').trim();
    if (!text) return;

    const isGeneric = /^(submit|click here|button|ok|go|send|next|continue|learn more)$/i.test(text);
    const isDescriptive = text.split(/\s+/).length >= 2 && !isGeneric;

    analysis.microcopy.push({
      text,
      isGeneric,
      isDescriptive
    });

    if (isGeneric) {
      issues.push({
        type: 'generic-button-text',
        text,
        message: `Button text "${text}" is generic. Use action-specific copy like "Start free trial" or "Download the guide".`
      });
    }
  });

  const boilerplateRatio = analysis.totalTextBlocks > 0 ? analysis.boilerplate.length / analysis.totalTextBlocks : 0;
  const personalityScore = analysis.personality.length;
  const genericButtonRatio = analysis.microcopy.length > 0 ? analysis.microcopy.filter(m => m.isGeneric).length / analysis.microcopy.length : 0;

  if (boilerplateRatio > 0.2) {
    issues.push({
      type: 'excessive-boilerplate',
      ratio: Math.round(boilerplateRatio * 100),
      examples: analysis.boilerplate.slice(0, 5),
      message: `${Math.round(boilerplateRatio * 100)}% of text uses corporate boilerplate/jargon. Replace with authentic, specific copy.`
    });
  }

  if (personalityScore === 0 && analysis.totalTextBlocks > 5) {
    issues.push({
      type: 'no-personality',
      message: 'No personality markers detected in copy. The text reads like generic template content. Add voice, humor, or warmth.'
    });
  }

  return {
    totalTextBlocks: analysis.totalTextBlocks,
    boilerplateInstances: analysis.boilerplate.length,
    boilerplateRatio: Math.round(boilerplateRatio * 100),
    personalityTraits: [...new Set(analysis.personality.map(p => p.trait))],
    personalityInstances: personalityScore,
    genericButtons: analysis.microcopy.filter(m => m.isGeneric).length,
    totalButtons: analysis.microcopy.length,
    boilerplateExamples: analysis.boilerplate.slice(0, 10),
    personalityExamples: analysis.personality.slice(0, 10),
    issues
  };
})()
```

### 6.3 Animation on Key Moments Detection

```javascript
(() => {
  const findings = { cssAnimations: [], cssTransitions: [], jsAnimations: [] };
  const issues = [];

  try {
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules || []) {
          if (rule instanceof CSSKeyframesRule) {
            findings.cssAnimations.push({
              name: rule.name,
              keyframeCount: rule.cssRules ? rule.cssRules.length : 0
            });
          }
        }
      } catch (e) { /* cross-origin */ }
    }
  } catch (e) { /* stylesheet error */ }

  const animatedElements = document.querySelectorAll('[class*="animate"], [class*="Animate"], [class*="transition"], [class*="Transition"], [class*="fade"], [class*="Fade"], [class*="slide"], [class*="Slide"], [class*="bounce"], [class*="Bounce"], [class*="zoom"], [class*="Zoom"]');

  animatedElements.forEach(el => {
    const style = window.getComputedStyle(el);
    const animation = style.animationName || '';
    const transition = style.transition || '';

    if (animation && animation !== 'none') {
      findings.jsAnimations.push({
        tag: el.tagName.toLowerCase(),
        classes: (el.className || '').toString().substring(0, 60),
        animationName: animation,
        duration: style.animationDuration
      });
    }
  });

  const heroSection = document.querySelector('[class*="hero"], [class*="Hero"], header > *:first-child, main > *:first-child');
  if (heroSection) {
    const heroStyle = window.getComputedStyle(heroSection);
    const hasAnimation = heroStyle.animationName !== 'none' || heroStyle.transition !== 'all 0s ease 0s';
    if (!hasAnimation) {
      const childrenAnimated = heroSection.querySelectorAll('[class*="animate"], [class*="fade"], [class*="slide"]');
      if (childrenAnimated.length === 0) {
        issues.push({
          type: 'static-hero',
          message: 'Hero section has no entrance animation. A subtle fade-in or slide-up on the hero creates a polished first impression.'
        });
      }
    }
  }

  const totalAnimations = findings.cssAnimations.length + findings.jsAnimations.length;

  if (totalAnimations === 0) {
    issues.push({
      type: 'no-animations',
      message: 'No CSS animations or animated elements detected. Strategic animations on key moments (page load, CTA hover, success states) add life to the interface.'
    });
  }

  const prefersReducedMotion = document.querySelectorAll('[class*="motion-reduce"], [class*="reduced-motion"]');

  return {
    cssKeyframeAnimations: findings.cssAnimations.length,
    animatedElements: findings.jsAnimations.length,
    totalAnimations,
    cssAnimationNames: findings.cssAnimations.map(a => a.name),
    animatedElementDetails: findings.jsAnimations.slice(0, 15),
    respectsReducedMotion: prefersReducedMotion.length > 0,
    issues
  };
})()
```

### 6.4 Brand-Specific Visual Element Detection

```javascript
(() => {
  const findings = { brandElements: [], customProperties: [], themeTokens: [] };
  const issues = [];

  const favicon = document.querySelector('link[rel="icon"], link[rel="shortcut icon"]');
  const ogImage = document.querySelector('meta[property="og:image"]');
  const themeColor = document.querySelector('meta[name="theme-color"]');
  const manifest = document.querySelector('link[rel="manifest"]');
  const appleTouchIcon = document.querySelector('link[rel="apple-touch-icon"]');

  findings.brandElements.push(
    { element: 'favicon', exists: !!favicon, value: favicon ? favicon.href : null },
    { element: 'og:image', exists: !!ogImage, value: ogImage ? ogImage.content : null },
    { element: 'theme-color', exists: !!themeColor, value: themeColor ? themeColor.content : null },
    { element: 'manifest', exists: !!manifest, value: manifest ? manifest.href : null },
    { element: 'apple-touch-icon', exists: !!appleTouchIcon, value: appleTouchIcon ? appleTouchIcon.href : null }
  );

  try {
    const rootStyles = window.getComputedStyle(document.documentElement);
    const allProperties = [];
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules || []) {
          if (rule.selectorText === ':root' || rule.selectorText === 'html') {
            const cssText = rule.cssText || '';
            const customProps = cssText.match(/--[\w-]+/g) || [];
            allProperties.push(...customProps);
          }
        }
      } catch (e) { /* cross-origin */ }
    }

    const brandProps = allProperties.filter(p => /brand|primary|accent|theme|logo/i.test(p));
    findings.customProperties = [...new Set(allProperties)].slice(0, 30);
    findings.themeTokens = brandProps;
  } catch (e) { /* stylesheet error */ }

  const logo = document.querySelector('[class*="logo"], [class*="Logo"], [id*="logo"], [id*="Logo"], header img:first-of-type, nav img:first-of-type');
  const brandName = document.querySelector('meta[property="og:site_name"], title');

  if (!logo) {
    issues.push({
      type: 'no-logo',
      message: 'No logo element detected in the page. Brand identity starts with a visible, prominent logo.'
    });
  }

  if (!themeColor) {
    issues.push({
      type: 'no-theme-color',
      message: 'No <meta name="theme-color"> found. This sets the browser chrome color on mobile, reinforcing brand.'
    });
  }

  if (findings.themeTokens.length === 0 && findings.customProperties.length > 0) {
    issues.push({
      type: 'no-brand-tokens',
      message: 'CSS custom properties exist but none are named with brand/primary/accent. Use semantic token names for maintainability.'
    });
  }

  const missingBrandElements = findings.brandElements.filter(b => !b.exists);
  if (missingBrandElements.length >= 3) {
    issues.push({
      type: 'incomplete-brand-identity',
      missing: missingBrandElements.map(b => b.element),
      message: `Missing ${missingBrandElements.length} brand identity elements: ${missingBrandElements.map(b => b.element).join(', ')}.`
    });
  }

  return {
    brandElements: findings.brandElements,
    customPropertyCount: findings.customProperties.length,
    brandTokenCount: findings.themeTokens.length,
    themeTokens: findings.themeTokens,
    hasLogo: !!logo,
    brandName: brandName ? (brandName.content || brandName.textContent || '').substring(0, 40) : null,
    issues
  };
})()
```

## Tier 2: AI Judgment

When reviewing the screenshot and DOM snapshot, answer each question with a score from 1-5 and a brief justification:

1. **Visceral Reaction (50ms Gut Check)**: What is your instant gut reaction to the screenshot before reading any content? Rate on a scale: Does it feel professional? Cheap? Warm? Cold? Trustworthy? Sketchy? Modern? Dated? The visceral layer is processed before conscious thought. A strong visceral reaction means the visual design communicates immediately.

2. **Behavioral Efficiency (Primary Task Flow)**: Can the user complete the primary task on this page in 3 clicks or fewer? Count the steps from landing to completing the most important action. Every extra click is friction. Every unclear label is a decision tax. Rate based on how efficiently the design guides the user to their goal.

3. **Reflective Memorability**: If a user visited this page once, would they remember it a week later? Would they describe it to a friend? Is there a distinctive visual element, clever interaction, or unique design choice that sticks? Generic-looking pages score 1. Pages with a clear visual identity and memorable moments score 5.

4. **Human vs. Template Feel**: Does this page feel like it was crafted by humans who care, or assembled from a template? Signs of human craft: intentional asymmetry, custom illustrations, thoughtful microcopy, personality in error messages. Signs of template: generic stock photos, "Lorem ipsum" energy, perfectly uniform cards with no character.

5. **Emotional Tone Consistency**: Is the emotional tone consistent across all elements? A playful hero section followed by a sterile corporate footer creates emotional whiplash. The illustration style, copy tone, color warmth, and spacing density should all tell the same emotional story.

6. **Trust Signal Presence**: Does the page build trust? Look for: real team photos (not stock), customer testimonials with names/photos, security badges, privacy messaging, transparent pricing, recognizable brand partnerships, professional domain, SSL indicator awareness. Each trust signal adds credibility.

7. **Cultural Sensitivity and Inclusivity**: Does the imagery and copy feel inclusive? Are people of diverse backgrounds represented in photos/illustrations? Is the language gender-neutral? Are cultural assumptions embedded in metaphors or idioms? Inclusive design creates broader emotional resonance.

8. **Joy Budget Allocation**: Has the design spent its "joy budget" wisely? Joy elements (animations, illustrations, playful copy) should concentrate on: first visit impression, successful completion moments, waiting/loading moments, and error recovery. Joy in the wrong place (checkout flow, form validation) feels frivolous.

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Custom illustrations (not stock). Copy has distinct personality matching brand tone. Key moments have meaningful animations. Brand identity complete (favicon, og:image, theme-color, manifest). Visceral reaction is strongly positive. Primary task achievable in <=2 clicks. Page is memorable and feels human-crafted. Emotional tone is consistent throughout. |
| 4 | Mix of custom and stock imagery. Copy has some personality. At least 2-3 animated moments. Most brand identity elements present. Visceral reaction is positive. Primary task in <=3 clicks. Page has 1-2 distinctive elements. Tone is mostly consistent. |
| 3 | Mostly stock imagery but well-curated. Copy is functional but personality-free. 1 animation (or only page transitions). Some brand identity elements missing. Visceral reaction is neutral. Primary task in 4 clicks. Page looks professional but generic. Tone has minor inconsistencies. |
| 2 | Obvious stock photos (watermarks, generic business people). Copy uses corporate jargon and boilerplate. No animations. Missing multiple brand identity elements. Visceral reaction is slightly negative. Primary task unclear. Page looks templated. Tone inconsistent between sections. |
| 1 | No imagery or broken images. Copy is placeholder or boilerplate. Zero animations or engagement. No brand identity elements. Visceral reaction is strongly negative (cheap, untrustworthy, broken). Primary task is buried or impossible. Page is forgettable. No emotional design consideration at all. |

## Common Fixes

### Fix: Add entrance animation to hero section
```css
.hero-content {
  animation: hero-entrance 0.8s cubic-bezier(0.16, 1, 0.3, 1) both;
}

@keyframes hero-entrance {
  from {
    opacity: 0;
    transform: translateY(24px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@media (prefers-reduced-motion: reduce) {
  .hero-content {
    animation: none;
  }
}
```

**Tailwind equivalent:**
```html
<div class="animate-[hero-entrance_0.8s_cubic-bezier(0.16,1,0.3,1)_both] motion-reduce:animate-none">
```

### Fix: Replace generic button copy
```css
/* This is a copy/content fix, not CSS — but for --fix mode: */
/* Replace: "Submit" → "Start your free trial" */
/* Replace: "Click here" → "View the full report" */
/* Replace: "Learn more" → "See how it works" */
/* Replace: "Send" → "Send my message" */
/* Principle: verb + specific object = actionable microcopy */
```

### Fix: Add brand identity meta tags
```html
<meta name="theme-color" content="#2563eb">
<meta property="og:image" content="/images/og-image.png">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/manifest.json">
```

### Fix: Success state animation
```css
.success-checkmark {
  animation: check-appear 0.4s cubic-bezier(0.65, 0, 0.35, 1) 0.2s both;
}

@keyframes check-appear {
  from {
    transform: scale(0) rotate(-45deg);
    opacity: 0;
  }
  50% {
    transform: scale(1.2) rotate(0);
  }
  to {
    transform: scale(1) rotate(0);
    opacity: 1;
  }
}

.success-message {
  animation: fade-up 0.5s ease 0.4s both;
}

@keyframes fade-up {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
```

### Fix: Add scroll-triggered reveal animations
```css
.reveal {
  opacity: 0;
  transform: translateY(20px);
  transition: opacity 0.6s ease, transform 0.6s ease;
}

.reveal.visible {
  opacity: 1;
  transform: translateY(0);
}

@media (prefers-reduced-motion: reduce) {
  .reveal {
    opacity: 1;
    transform: none;
    transition: none;
  }
}
```

```javascript
/* Observer for scroll reveals (add to page JS, not audit script) */
/*
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
    }
  });
}, { threshold: 0.1 });

document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
*/
```
