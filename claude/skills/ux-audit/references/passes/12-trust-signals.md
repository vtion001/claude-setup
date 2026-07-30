# Pass 12: Trust Signals

## Tier 1: Automated Checks

### Social Proof in First Viewport

```javascript
(() => {
  const results = { check: "social-proof", issues: [], stats: {} };

  const viewportHeight = window.innerHeight;
  const viewportWidth = window.innerWidth;

  // Social proof patterns to search for
  const socialProofSelectors = [
    '[class*="testimonial"]', '[class*="review"]', '[class*="rating"]',
    '[class*="social-proof"]', '[class*="trust"]', '[class*="customer"]',
    '[class*="client"]', '[class*="partner"]', '[class*="logo-bar"]',
    '[class*="logo-strip"]', '[class*="as-seen"]', '[class*="featured"]',
    '[class*="badge"]', '[class*="award"]', '[class*="certification"]',
    '[data-testid*="testimonial"]', '[data-testid*="review"]'
  ];

  const socialProofElements = [];
  socialProofSelectors.forEach(sel => {
    const els = document.querySelectorAll(sel);
    els.forEach(el => {
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        socialProofElements.push({
          selector: sel,
          element: el.tagName.toLowerCase() + (el.className ? '.' + String(el.className).split(' ')[0] : ''),
          inFirstViewport: rect.top < viewportHeight,
          top: Math.round(rect.top)
        });
      }
    });
  });

  // Check for star ratings (unicode stars, SVG stars, star images)
  const allText = document.body.innerText;
  const hasStarRatings = /[★☆⭐]/.test(allText) || document.querySelectorAll('[class*="star"], [class*="rating"] svg, [aria-label*="star"], [aria-label*="rating"]').length > 0;

  // Check for user count / social proof numbers
  const socialProofNumbers = [];
  const numberPatterns = [
    /(\d[\d,]*\+?)\s*(users|customers|companies|businesses|teams|downloads|installs|reviews|ratings)/gi,
    /trusted\s*by\s*(\d[\d,]*\+?)/gi,
    /join\s*(\d[\d,]*\+?)/gi,
    /over\s*(\d[\d,]*\+?)\s*(users|customers|companies)/gi
  ];
  numberPatterns.forEach(pattern => {
    let match;
    while ((match = pattern.exec(allText)) !== null) {
      socialProofNumbers.push(match[0].substring(0, 60));
      if (socialProofNumbers.length >= 5) break;
    }
  });

  // Check for logo bars (images in a row, typically partner/client logos)
  const imgContainers = Array.from(document.querySelectorAll('div, section, ul'));
  let logoBarFound = false;
  for (const container of imgContainers) {
    const imgs = container.querySelectorAll(':scope > img, :scope > li > img, :scope > a > img, :scope > div > img');
    if (imgs.length >= 3) {
      const firstRect = imgs[0].getBoundingClientRect();
      const lastRect = imgs[imgs.length - 1].getBoundingClientRect();
      const sameRow = Math.abs(firstRect.top - lastRect.top) < 50;
      const smallImages = Array.from(imgs).every(img => img.getBoundingClientRect().height < 80);
      if (sameRow && smallImages) {
        logoBarFound = true;
        break;
      }
    }
    if (logoBarFound) break;
  }

  const inFirstViewport = socialProofElements.filter(s => s.inFirstViewport);

  results.stats = {
    totalSocialProofElements: socialProofElements.length,
    inFirstViewport: inFirstViewport.length,
    hasStarRatings,
    socialProofNumbers: socialProofNumbers.slice(0, 5),
    hasLogoBar: logoBarFound
  };

  if (inFirstViewport.length === 0 && socialProofElements.length === 0) {
    results.issues.push({ type: 'no-social-proof', message: 'No social proof elements detected on the page' });
  } else if (inFirstViewport.length === 0) {
    results.issues.push({ type: 'social-proof-below-fold', message: 'Social proof exists but is below the first viewport', closestPosition: socialProofElements[0]?.top });
  }

  return results;
})()
```

### Security Badges Near Payment

```javascript
(() => {
  const results = { check: "security-badges", issues: [], stats: {} };

  // Detect payment/checkout context
  const allText = (document.body.innerText || '').toLowerCase();
  const isPaymentPage = /checkout|payment|billing|credit\s*card|debit\s*card|pay\s*now|place\s*order|complete\s*purchase/i.test(allText);
  const hasPaymentForm = document.querySelector('input[type="password"], input[name*="card"], input[name*="cc"], input[autocomplete*="cc-"], [class*="payment"], [class*="checkout"], [class*="billing"]') !== null;

  if (!isPaymentPage && !hasPaymentForm) {
    results.stats = { isPaymentPage: false, skipped: true };
    return results;
  }

  // Look for security badges and trust indicators
  const securitySelectors = [
    '[class*="secure"]', '[class*="security"]', '[class*="trust"]',
    '[class*="badge"]', '[class*="ssl"]', '[class*="lock"]',
    '[class*="verified"]', '[class*="encrypted"]', '[class*="safe"]',
    '[class*="guarantee"]', '[class*="protection"]',
    'img[alt*="secure"]', 'img[alt*="ssl"]', 'img[alt*="trust"]',
    'img[alt*="verified"]', 'img[alt*="norton"]', 'img[alt*="mcafee"]',
    'img[alt*="stripe"]', 'img[alt*="paypal"]',
    'img[src*="badge"]', 'img[src*="trust"]', 'img[src*="secure"]',
    'img[src*="ssl"]'
  ];

  const securityElements = [];
  securitySelectors.forEach(sel => {
    document.querySelectorAll(sel).forEach(el => {
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        securityElements.push({
          element: el.tagName.toLowerCase(),
          class: (el.className || '').toString().substring(0, 40),
          alt: el.alt || '',
          top: Math.round(rect.top)
        });
      }
    });
  });

  // Check for lock icon / shield icon (SVG or icon font)
  const lockIcons = document.querySelectorAll('[class*="lock"], [class*="shield"], svg[class*="lock"], svg[class*="shield"]');

  // Check for "Secure checkout" or similar text
  const secureTextPatterns = [
    /secure\s*(checkout|payment|transaction)/i,
    /ssl\s*encrypted/i,
    /256.?bit\s*(encryption|ssl)/i,
    /data\s*(is\s*)?(encrypted|protected|secure)/i,
    /100%\s*secure/i,
    /money.?back\s*guarantee/i
  ];
  const hasSecureText = secureTextPatterns.some(p => p.test(allText));

  // Check proximity of security badges to payment form
  const paymentForm = document.querySelector('[class*="payment"], [class*="checkout"], [class*="billing"], form');
  let badgeNearForm = false;
  if (paymentForm && securityElements.length > 0) {
    const formRect = paymentForm.getBoundingClientRect();
    badgeNearForm = securityElements.some(badge => Math.abs(badge.top - formRect.bottom) < 200 || Math.abs(badge.top - formRect.top) < 200);
  }

  results.stats = {
    isPaymentPage: true,
    securityBadgeCount: securityElements.length,
    hasLockIcon: lockIcons.length > 0,
    hasSecureText,
    badgeNearPaymentForm: badgeNearForm
  };

  if (securityElements.length === 0 && !hasSecureText) {
    results.issues.push({ type: 'no-security-indicators', message: 'Payment page has no visible security badges, lock icons, or secure checkout text' });
  }
  if (securityElements.length > 0 && !badgeNearForm) {
    results.issues.push({ type: 'badges-far-from-form', message: 'Security badges exist but are not near the payment form' });
  }

  return results;
})()
```

### CTA Button Labels

```javascript
(() => {
  const results = { check: "cta-labels", issues: [], stats: {} };

  const ctaElements = Array.from(document.querySelectorAll(
    'button, [role="button"], input[type="submit"], input[type="button"], a[class*="btn"], a[class*="cta"], a[class*="button"]'
  ));

  // Weak/generic CTA labels
  const weakLabels = ['submit', 'click here', 'go', 'send', 'ok', 'yes', 'continue', 'next', 'more', 'learn more', 'read more', 'info', 'details'];

  // Strong action-verb labels
  const strongPatterns = [
    /^(get|start|try|create|build|download|install|join|sign\s*up|register|subscribe|book|schedule|reserve|order|buy|add\s*to|save|explore|discover|request|claim|unlock|upgrade)/i
  ];

  const buttonAnalysis = ctaElements.map(el => {
    const text = (el.textContent || el.value || '').trim();
    if (!text || text.length > 50) return null;

    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') return null;

    const lower = text.toLowerCase();
    const isWeak = weakLabels.includes(lower);
    const isStrong = strongPatterns.some(p => p.test(text));

    return {
      text,
      isWeak,
      isStrong,
      element: el.tagName.toLowerCase()
    };
  }).filter(Boolean);

  const weakButtons = buttonAnalysis.filter(b => b.isWeak);
  const strongButtons = buttonAnalysis.filter(b => b.isStrong);
  const neutralButtons = buttonAnalysis.filter(b => !b.isWeak && !b.isStrong);

  results.stats = {
    totalCTAs: buttonAnalysis.length,
    strongLabelCount: strongButtons.length,
    weakLabelCount: weakButtons.length,
    neutralLabelCount: neutralButtons.length,
    strongLabels: strongButtons.slice(0, 5).map(b => b.text),
    weakLabels: weakButtons.slice(0, 5).map(b => b.text)
  };

  if (weakButtons.length > 0) {
    results.issues.push({
      type: 'weak-cta-labels',
      count: weakButtons.length,
      labels: weakButtons.slice(0, 10).map(b => b.text),
      recommendation: 'Replace generic labels with action verbs (e.g., "Submit" → "Create Account", "Click Here" → "Download Guide")'
    });
  }

  return results;
})()
```

### Form Field Count & Privacy Link

```javascript
(() => {
  const results = { check: "form-trust", issues: [], stats: {} };

  const forms = Array.from(document.querySelectorAll('form'));

  const formAnalysis = forms.map(form => {
    const visibleFields = Array.from(form.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="reset"]), select, textarea')).filter(f => {
      const style = getComputedStyle(f);
      return style.display !== 'none' && style.visibility !== 'hidden';
    });

    const fieldNames = visibleFields.map(f => f.name || f.type || f.placeholder || 'unknown');
    const fieldCount = visibleFields.length;

    // Check for privacy link near form
    const formRect = form.getBoundingClientRect();
    const allLinks = Array.from(document.querySelectorAll('a'));
    const privacyLink = allLinks.find(a => {
      const text = (a.textContent || '').toLowerCase();
      const href = (a.href || '').toLowerCase();
      const isPrivacyLink = text.includes('privacy') || href.includes('privacy');
      if (!isPrivacyLink) return false;
      const linkRect = a.getBoundingClientRect();
      const distance = Math.abs(linkRect.top - formRect.bottom);
      return distance < 200;
    });

    // Check for sensitive fields
    const sensitiveFields = visibleFields.filter(f => {
      const name = (f.name || f.type || f.placeholder || f.id || '').toLowerCase();
      return /phone|ssn|social|dob|birth|address|income|salary|employer/i.test(name);
    });

    return {
      formId: form.id || form.action?.substring(0, 40) || 'form',
      fieldCount,
      fields: fieldNames.slice(0, 10),
      tooManyFields: fieldCount > 7,
      hasPrivacyLinkNearby: !!privacyLink,
      sensitiveFieldCount: sensitiveFields.length,
      sensitiveFields: sensitiveFields.map(f => f.name || f.type).slice(0, 5)
    };
  });

  // Check for global privacy policy link
  const globalPrivacyLink = Array.from(document.querySelectorAll('a')).find(a => {
    const text = (a.textContent || '').toLowerCase();
    const href = (a.href || '').toLowerCase();
    return text.includes('privacy policy') || href.includes('privacy');
  });

  results.stats = {
    totalForms: forms.length,
    formsExceeding7Fields: formAnalysis.filter(f => f.tooManyFields).length,
    formsWithPrivacyLink: formAnalysis.filter(f => f.hasPrivacyLinkNearby).length,
    hasGlobalPrivacyLink: !!globalPrivacyLink
  };

  formAnalysis.forEach(form => {
    if (form.tooManyFields) {
      results.issues.push({ type: 'too-many-fields', form: form.formId, fieldCount: form.fieldCount, recommendation: `Reduce to <=7 fields or split into steps. Current: ${form.fieldCount}` });
    }
    if (!form.hasPrivacyLinkNearby && form.sensitiveFieldCount > 0) {
      results.issues.push({ type: 'no-privacy-near-form', form: form.formId, sensitiveFields: form.sensitiveFields, message: 'Form collects sensitive data but has no privacy link nearby' });
    }
  });

  if (!globalPrivacyLink) {
    results.issues.push({ type: 'no-global-privacy-link', message: 'No privacy policy link found on the page' });
  }

  return results;
})()
```

## Tier 2: AI Judgment

### Trustworthiness at First Glance
When viewing the screenshot for the first time (simulate a 5-second first impression):
1. Does the site look **professionally designed** — consistent spacing, aligned elements, quality typography?
2. Is there **visual clutter** or does the page feel clean and confident?
3. Are there **stock photo red flags** — obviously fake smiles, watermarks, low-resolution images?
4. Does the **color scheme** feel appropriate for the industry (healthcare = calming blues/greens, finance = navy/gold, tech = clean modern)?
5. Is the **branding consistent** — logo quality, color consistency, typography matches the brand promise?
6. Does it look **current** — or does the design feel dated (Web 2.0 glossy buttons, early 2010s flat design)?
7. Would a first-time visitor **feel comfortable** entering personal information here?

### Credential & Partnership Visibility
When reviewing trust-building content:
1. Are **credentials** visible (certifications, awards, years in business, team photos)?
2. Are **partner/integration logos** displayed (payment processors, industry associations, tech partners)?
3. Are **case studies or success metrics** quantified (not just vague claims)?
4. Is there an **"About" page** link visible — can users learn who is behind the product?
5. Are **real names and photos** used for testimonials (not anonymous or stock)?
6. Is **contact information** easily findable (address, phone, email — not just a contact form)?

### CTA Tone Assessment
When evaluating call-to-action language:
1. Does the CTA feel **inviting** ("Start your free trial") or **aggressive** ("BUY NOW!!!")?
2. Is there **urgency without manipulation** — does "Limited time" have a real deadline, or is it fake scarcity?
3. Do CTAs use **first-person positive framing** ("Start my free trial" vs. impersonal "Submit")?
4. Is the **value proposition clear** in or near the CTA — does the user know what they get?
5. Are there **too many competing CTAs** creating decision paralysis instead of trust?

### Form Invasiveness
When evaluating data collection:
1. Does the form **ask only for what's needed** at this stage (email for newsletter, not full address)?
2. Are **optional fields** clearly marked — or does every field feel required?
3. Is there a **clear reason** communicated for each piece of data collected?
4. Is **social login** offered as a low-friction alternative to full registration?
5. Does the form **feel proportional** to the value offered (free ebook shouldn't require 10 fields)?

### Credit Card Comfort
When reviewing payment flows:
1. Would you **feel safe entering a credit card** on this page?
2. Are **recognized payment processors** shown (Stripe, PayPal, Apple Pay logos)?
3. Is there a **money-back guarantee** or refund policy visible?
4. Is the **pricing transparent** — no surprises after entering card info?
5. Is there a **padlock icon** or "Secure" indicator near payment fields?
6. Does the page **communicate** what will happen after payment (instant access, email confirmation, shipping timeline)?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Social proof in first viewport (testimonials, ratings, user counts, or logo bar). Security badges adjacent to payment forms. All CTAs use action-verb labels. Forms have <= 7 fields with privacy link nearby. Professional design, real testimonials with names/photos, transparent pricing, recognized payment processor logos. |
| 4 | Social proof present but slightly below fold. Security indicators present on payment pages. Most CTAs use action verbs (1-2 generic). Forms reasonable length. Professional design. 1 minor trust gap (e.g., anonymous testimonials, no partner logos). |
| 3 | Social proof exists but buried. Payment page has some security indicators but not near form. Mix of action-verb and generic CTA labels. 1-2 forms exceed 7 fields. Design adequate but not confidence-inspiring. Missing 2-3 trust signals. |
| 2 | No social proof in first viewport. Payment page lacks security badges. Most CTAs are generic ("Submit", "Click here"). Forms ask for excessive data. Design looks dated or unprofessional. No visible credentials. Missing contact info. Anonymous testimonials or none. |
| 1 | Zero social proof anywhere. No security indicators on payment pages. All CTAs generic or misleading. Forms invasive (10+ fields) with no privacy info. Design looks untrustworthy. No credentials, no testimonials, no contact info. Payment flow feels unsafe. |

## Common Fixes

### Social Proof in Hero
```html
<!-- Add a trust bar below the hero -->
<div class="flex items-center justify-center gap-8 py-4 border-t border-b border-gray-100">
  <!-- Tailwind: flex items-center justify-center gap-8 py-4 border-y border-gray-100 -->
  <div class="text-sm text-gray-600">
    <span class="font-semibold text-gray-900">4.9/5</span> from 2,400+ reviews
  </div>
  <div class="flex gap-4 items-center opacity-60">
    <img src="/logos/partner1.svg" alt="Partner 1" class="h-6" />
    <img src="/logos/partner2.svg" alt="Partner 2" class="h-6" />
    <img src="/logos/partner3.svg" alt="Partner 3" class="h-6" />
  </div>
</div>
```

### Security Badge Near Payment
```html
<!-- Place directly below or beside payment form -->
<div class="flex items-center gap-4 mt-4 p-3 bg-gray-50 rounded-md border border-gray-200">
  <!-- Tailwind: flex items-center gap-4 mt-4 p-3 bg-gray-50 rounded-md border -->
  <svg class="w-5 h-5 text-green-600 shrink-0" fill="currentColor" viewBox="0 0 20 20">
    <!-- lock icon SVG path -->
  </svg>
  <p class="text-sm text-gray-600">
    Your payment is secured with 256-bit SSL encryption. We never store your card details.
  </p>
</div>
```

### Action-Verb CTA Labels
```html
<!-- Wrong -->
<button>Submit</button>
<a href="/signup">Click here</a>

<!-- Correct -->
<button>Create my account</button>
<a href="/signup" class="btn btn-primary">Start free trial</a>
<button>Download the guide</button>
<button>Schedule a demo</button>
<button>Get instant access</button>
```

### Privacy Link Near Form
```html
<form>
  <!-- form fields -->
  <button type="submit" class="btn btn-primary">Subscribe</button>
  <p class="text-xs text-gray-500 mt-2">
    We respect your privacy. Read our
    <a href="/privacy" class="underline hover:text-gray-700">Privacy Policy</a>.
    Unsubscribe anytime.
  </p>
</form>
```

### Reduce Form Fields
```html
<!-- Before: 9 fields -->
<!-- After: 3 essential fields + progressive profiling later -->
<form>
  <label for="name" class="block text-sm font-medium">Full name</label>
  <input type="text" id="name" name="name" required class="w-full border rounded-md px-3 py-2 mt-1" />

  <label for="email" class="block text-sm font-medium mt-4">Email</label>
  <input type="email" id="email" name="email" required class="w-full border rounded-md px-3 py-2 mt-1" />

  <label for="company" class="block text-sm font-medium mt-4">Company (optional)</label>
  <input type="text" id="company" name="company" class="w-full border rounded-md px-3 py-2 mt-1" />

  <button type="submit" class="w-full mt-6 py-3 bg-blue-600 text-white rounded-md font-medium">
    Get started free
  </button>
</form>
```
