# Pass 10: Dark Patterns

## Tier 1: Automated Checks

### Pre-checked Checkboxes on Opt-in Forms

```javascript
(() => {
  const results = { check: "prechecked-optins", issues: [], stats: {} };

  const checkboxes = Array.from(document.querySelectorAll('input[type="checkbox"]'));

  const prechecked = checkboxes.filter(cb => {
    if (!cb.checked) return false;

    // Look for opt-in context: newsletter, marketing, terms, notifications, sharing
    const label = document.querySelector(`label[for="${cb.id}"]`);
    const wrappedLabel = cb.closest('label');
    const labelText = ((label?.textContent || '') + (wrappedLabel?.textContent || '')).toLowerCase();
    const nearbyText = (cb.parentElement?.textContent || '').toLowerCase();
    const combined = labelText + ' ' + nearbyText;

    const optInKeywords = [
      'newsletter', 'subscribe', 'marketing', 'email', 'notification',
      'updates', 'offers', 'promotions', 'third.?party', 'partner',
      'share', 'consent', 'agree', 'opt.?in', 'receive', 'send me',
      'keep me', 'sign me up', 'stay informed', 'communications'
    ];

    return optInKeywords.some(kw => new RegExp(kw, 'i').test(combined));
  });

  const precheckedDetails = prechecked.map(cb => {
    const label = document.querySelector(`label[for="${cb.id}"]`);
    const wrappedLabel = cb.closest('label');
    return {
      id: cb.id || cb.name || 'unnamed',
      checked: true,
      labelText: ((label?.textContent || wrappedLabel?.textContent || '')).trim().substring(0, 80),
      pattern: 'pre-checked opt-in'
    };
  });

  results.stats = {
    totalCheckboxes: checkboxes.length,
    precheckedOptInCount: prechecked.length
  };

  if (prechecked.length > 0) {
    results.issues = precheckedDetails;
  }

  return results;
})()
```

### Confirmshaming Text Detection

```javascript
(() => {
  const results = { check: "confirmshaming", issues: [], stats: {} };

  // Find dismiss/decline/close buttons and links in modals, popups, banners
  const dismissElements = Array.from(document.querySelectorAll(
    'a, button, [role="button"], span, p, div'
  ));

  const confirmShamingPatterns = [
    /no,?\s*(thanks|i\s*don'?t|i\s*prefer|i\s*hate|i\s*like\s*paying)/i,
    /i\s*don'?t\s*(want|need|like|care)/i,
    /i\s*prefer\s*(not|to\s*miss|paying\s*full)/i,
    /i('?m|\s*am)\s*(not\s*interested|happy\s*(paying|being|with\s*less))/i,
    /i\s*hate\s*(saving|good\s*deals|money|discounts)/i,
    /i('?ll|will)\s*(pass|miss\s*out|pay\s*(full|more))/i,
    /no\s*i\s*(like|enjoy|prefer)\s*(paying|spending|being)/i,
    /i\s*want\s*to\s*(miss|lose|pay\s*more|be\s*left)/i,
    /continue\s*without\s*(saving|discount|protection)/i,
    /decline\s*(this\s*)?offer/i,
    /maybe\s*later,?\s*i/i,
    /i\s*(already\s*know|understand)\s*(everything|enough)/i
  ];

  const shamingInstances = [];

  dismissElements.forEach(el => {
    const text = (el.textContent || '').trim();
    if (text.length < 5 || text.length > 150) return;

    for (const pattern of confirmShamingPatterns) {
      if (pattern.test(text)) {
        shamingInstances.push({
          text: text.substring(0, 100),
          element: el.tagName.toLowerCase(),
          pattern: pattern.source.substring(0, 40),
          inModal: !!el.closest('[role="dialog"], .modal, .popup, .overlay, [class*="modal"], [class*="popup"]')
        });
        break;
      }
    }
  });

  results.stats = { confirmShamingCount: shamingInstances.length };
  results.issues = shamingInstances.slice(0, 10);

  return results;
})()
```

### Asymmetric Button Styling

```javascript
(() => {
  const results = { check: "asymmetric-buttons", issues: [], stats: {} };

  // Find button pairs in dialogs, cookie banners, subscription prompts
  const containers = Array.from(document.querySelectorAll(
    '[role="dialog"], [role="alertdialog"], .modal, .popup, .overlay, .banner, .cookie, [class*="consent"], [class*="cookie"], [class*="modal"], [class*="popup"], [class*="newsletter"], [class*="subscribe"], form'
  ));

  const asymmetricPairs = [];

  containers.forEach(container => {
    const buttons = Array.from(container.querySelectorAll('button, [role="button"], a.btn, a[class*="button"], input[type="submit"]'));
    if (buttons.length < 2) return;

    // Compare accept vs decline button styling
    const buttonData = buttons.map(btn => {
      const style = getComputedStyle(btn);
      const rect = btn.getBoundingClientRect();
      const text = (btn.textContent || btn.value || '').trim().toLowerCase();

      const isAccept = /accept|agree|yes|ok|continue|subscribe|sign.?up|get|start|buy|allow|enable|confirm/i.test(text);
      const isDecline = /decline|reject|no|cancel|close|dismiss|skip|not now|maybe later|unsubscribe/i.test(text);

      return {
        text: (btn.textContent || btn.value || '').trim().substring(0, 40),
        isAccept,
        isDecline,
        fontSize: parseFloat(style.fontSize),
        width: rect.width,
        height: rect.height,
        area: rect.width * rect.height,
        bgColor: style.backgroundColor,
        color: style.color,
        opacity: parseFloat(style.opacity),
        isLink: btn.tagName.toLowerCase() === 'a' && !btn.className.includes('btn'),
        isHidden: style.display === 'none' || style.visibility === 'hidden' || parseFloat(style.opacity) < 0.5
      };
    });

    const acceptBtns = buttonData.filter(b => b.isAccept);
    const declineBtns = buttonData.filter(b => b.isDecline);

    acceptBtns.forEach(accept => {
      declineBtns.forEach(decline => {
        const sizeRatio = accept.area / Math.max(decline.area, 1);
        const fontRatio = accept.fontSize / Math.max(decline.fontSize, 1);

        const issues = [];
        if (sizeRatio > 2) issues.push(`accept is ${sizeRatio.toFixed(1)}x larger`);
        if (fontRatio > 1.3) issues.push(`accept font ${fontRatio.toFixed(1)}x bigger`);
        if (decline.opacity < 0.6) issues.push(`decline opacity ${decline.opacity}`);
        if (decline.isLink) issues.push('decline styled as plain link, not button');
        if (decline.isHidden) issues.push('decline is hidden or near-invisible');
        if (decline.fontSize < 12) issues.push(`decline font only ${decline.fontSize}px`);

        if (issues.length > 0) {
          asymmetricPairs.push({
            acceptText: accept.text,
            declineText: decline.text,
            sizeRatio: Math.round(sizeRatio * 10) / 10,
            fontRatio: Math.round(fontRatio * 10) / 10,
            issues
          });
        }
      });
    });
  });

  results.stats = { asymmetricPairCount: asymmetricPairs.length };
  results.issues = asymmetricPairs.slice(0, 10);

  return results;
})()
```

### Unsubscribe / Delete Account Path

```javascript
(() => {
  const results = { check: "escape-paths", issues: [], stats: {} };

  const allText = document.body.innerText.toLowerCase();
  const allLinks = Array.from(document.querySelectorAll('a'));
  const allButtons = Array.from(document.querySelectorAll('button, [role="button"]'));

  // Check for unsubscribe link
  const unsubscribeLink = allLinks.find(a => {
    const text = (a.textContent || '').toLowerCase();
    const href = (a.href || '').toLowerCase();
    return text.includes('unsubscribe') || href.includes('unsubscribe');
  });

  // Check for delete account
  const deleteAccountEl = [...allLinks, ...allButtons].find(el => {
    const text = (el.textContent || '').toLowerCase();
    return text.includes('delete account') || text.includes('close account') || text.includes('deactivate account') || text.includes('remove account');
  });

  // Check for cancel subscription
  const cancelSubEl = [...allLinks, ...allButtons].find(el => {
    const text = (el.textContent || '').toLowerCase();
    return text.includes('cancel subscription') || text.includes('cancel plan') || text.includes('cancel membership') || text.includes('downgrade');
  });

  // Check footer for required links
  const footer = document.querySelector('footer, [role="contentinfo"]');
  const footerLinks = footer ? Array.from(footer.querySelectorAll('a')).map(a => (a.textContent || '').trim().toLowerCase()) : [];

  const hasPrivacyPolicy = footerLinks.some(t => t.includes('privacy')) || allLinks.some(a => (a.textContent || '').toLowerCase().includes('privacy policy'));
  const hasTerms = footerLinks.some(t => t.includes('terms')) || allLinks.some(a => (a.textContent || '').toLowerCase().includes('terms'));

  results.stats = {
    hasUnsubscribeLink: !!unsubscribeLink,
    hasDeleteAccount: !!deleteAccountEl,
    hasCancelSubscription: !!cancelSubEl,
    hasPrivacyPolicy,
    hasTerms,
    isSubscriptionPage: /subscri|plan|pricing|membership|billing/i.test(allText),
    isSettingsPage: /settings|account|profile|preferences/i.test(allText)
  };

  // Only flag missing paths when relevant
  if (results.stats.isSubscriptionPage || results.stats.isSettingsPage) {
    if (!deleteAccountEl) results.issues.push({ type: 'no-delete-account', message: 'Account/settings page has no visible delete/deactivate account option' });
    if (!cancelSubEl && results.stats.isSubscriptionPage) results.issues.push({ type: 'no-cancel-subscription', message: 'Subscription page has no visible cancel option' });
  }

  if (!hasPrivacyPolicy) results.issues.push({ type: 'no-privacy-policy', message: 'No privacy policy link found' });

  return results;
})()
```

## Tier 2: AI Judgment

### Double Negatives in Consent
When reviewing consent forms, cookie banners, and preference screens:
1. Are there **double negatives** in checkbox labels (e.g., "Uncheck to not receive..." or "Don't disable notifications")?
2. Does the user need to **read twice** to understand what checking or unchecking a box means?
3. Is the **default state clearly communicated** — do users know what happens if they do nothing?
4. Are **opt-out instructions** written as simply as opt-in instructions?

### Hidden Costs
When reviewing pricing, checkout, and cart pages:
1. Are there **surprise fees** that appear only at the final checkout step (shipping, handling, service, convenience fees)?
2. Is the **total price** visible early in the purchase flow, not just at the end?
3. Are **taxes and fees** clearly labeled and explained?
4. Are **"free" offers** truly free, or do they require payment info that leads to charges?
5. Is **subscription pricing** clear about renewal rates, especially after trial periods?

### Cancel vs Signup Flow Parity
When comparing signup and cancellation paths:
1. Can users **cancel through the same channel** they signed up (if signup is online, cancel should be online too)?
2. Is the **cancellation flow the same number of steps** as signup (or fewer)?
3. Is there a **clear "Cancel" button** vs. being forced to call, email, or chat?
4. Are there **excessive retention screens** (more than 1 "are you sure?" before canceling)?
5. Does the cancel flow include **dark pattern retention tactics** (guilt trips, buried cancel links, countdown timers)?

### Default Option Bias
When reviewing forms, pricing pages, and selection interfaces:
1. Is the **most expensive option** pre-selected in pricing tiers?
2. Are **auto-renewal or recurring billing** options pre-selected?
3. Is the **annual plan** pre-selected over monthly when it benefits the company more?
4. Are **add-ons or upsells** pre-selected in checkout?
5. Do **default selections** genuinely serve the user's most common need, or the company's revenue?

### Trick Wording
When reviewing CTAs, buttons, and marketing copy:
1. Do **CTA buttons** clearly describe what will happen when clicked?
2. Is **"Free Trial"** actually free, or does it require a credit card?
3. Does **"Continue"** mean "proceed to next step" or "agree to purchase"?
4. Are **terms of service** linked to at the point of commitment, not buried?
5. Does **"Share with friends"** actually access contacts, or post on social media?
6. Is **"Recommended"** or **"Most Popular"** actually based on data or just upsell framing?

### Forced Continuity
When reviewing subscription and trial flows:
1. Does the **free trial auto-convert** to a paid subscription without explicit consent?
2. Is the user **clearly warned** before the trial ends and billing begins?
3. Is the **billing date** prominently shown during trial signup?
4. Can users **set a reminder** or receive notification before being charged?
5. Is the **auto-renewal disclosure** prominent, not buried in fine print?

### Roach Motel Patterns
When reviewing account management:
1. Is it **easier to sign up than to leave** — can you find the cancellation path within 2 clicks?
2. Are **data export options** available (GDPR right to data portability)?
3. Can users **turn off notifications** as easily as they were turned on?
4. Is **downgrading** as straightforward as upgrading?
5. Can users **remove payment methods** without contacting support?

## Scoring Criteria

| Score | Criteria |
|-------|---------|
| 5 | Zero dark patterns detected. All checkboxes default unchecked for opt-ins. Dismiss and accept buttons equally prominent. Clear cancel/delete paths. No confirmshaming. No trick wording. Signup and cancel paths have equal friction. All pricing transparent upfront. |
| 4 | No intentional dark patterns. 1 minor issue (e.g., slightly smaller decline button, 1 pre-checked non-critical checkbox). Cancel path exists but takes 1 extra click. All costs shown before final step. |
| 3 | 1-2 notable dark patterns. Pre-checked marketing checkbox. Asymmetric button styling in cookie banner. Cancel path exists but buried in settings. 1 instance of confusing wording. Trial terms not prominently displayed. |
| 2 | 3-4 dark patterns present. Multiple pre-checked opt-ins. Confirmshaming text on dismiss buttons. Decline option styled as plain text. Cancel requires multiple screens of retention flows. Hidden fees appear late. |
| 1 | 5+ dark patterns. Systematic use of confirmshaming, trick wording, and hidden costs. Cancel path requires phone call or is unfindable. Forced continuity with no warning. Pre-checked add-ons in checkout. Double negatives in consent. Roach motel across multiple features. |

## Common Fixes

### Pre-checked Checkboxes
```html
<!-- Wrong: pre-checked opt-in -->
<input type="checkbox" id="newsletter" checked />

<!-- Correct: unchecked by default -->
<input type="checkbox" id="newsletter" />
<label for="newsletter">Yes, send me marketing emails</label>
```

### Symmetric Button Styling
```css
/* Both accept and decline should be visually equal buttons */
/* Tailwind: Both get same sizing, decline uses outline variant */
.consent-accept,
.consent-decline {
  padding: 10px 20px; /* Tailwind: px-5 py-2.5 */
  font-size: 1rem; /* Tailwind: text-base */
  border-radius: 6px; /* Tailwind: rounded-md */
  font-weight: 500; /* Tailwind: font-medium */
  min-height: 44px; /* Tailwind: min-h-[44px] */
  cursor: pointer;
}
.consent-accept {
  background: var(--primary); /* Tailwind: bg-primary */
  color: white; /* Tailwind: text-white */
}
.consent-decline {
  background: transparent; /* Tailwind: bg-transparent */
  border: 1px solid var(--border); /* Tailwind: border */
  color: var(--text); /* Tailwind: text-foreground */
}
```

### Clear Dismiss Language
```html
<!-- Wrong: confirmshaming -->
<button>No thanks, I prefer paying full price</button>

<!-- Correct: neutral language -->
<button>No thanks</button>
<!-- or -->
<button>Dismiss</button>
<!-- or -->
<button>Close</button>
```

### Transparent Pricing
```html
<!-- Show total cost breakdown early -->
<div class="price-summary">
  <div class="flex justify-between">
    <span>Subtotal</span><span>$49.99</span>
  </div>
  <div class="flex justify-between text-sm text-gray-600">
    <span>Shipping</span><span>$5.99</span>
  </div>
  <div class="flex justify-between text-sm text-gray-600">
    <span>Tax</span><span>$4.50</span>
  </div>
  <div class="flex justify-between font-bold border-t pt-2 mt-2">
    <span>Total</span><span>$60.48</span>
  </div>
</div>
```

### Clear Cancel Path
```html
<!-- In account settings, provide obvious cancel link -->
<div class="mt-8 border-t pt-6">
  <h3 class="text-lg font-medium text-red-600">Cancel Subscription</h3>
  <p class="text-sm text-gray-600 mt-1">You can cancel anytime. Your access continues until the end of the billing period.</p>
  <button class="mt-3 px-4 py-2 border border-red-300 text-red-600 rounded-md hover:bg-red-50">
    Cancel my subscription
  </button>
</div>
```
