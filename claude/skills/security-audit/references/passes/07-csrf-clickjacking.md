# Pass 07: CSRF & Clickjacking

**OWASP Mapping:** WSTG-SESS-05 (CSRF), WSTG-CLNT-09 (Clickjacking)
**Weight:** 5% of Security Score
**Automation Level:** 70% fully automated, 25% AI-assisted, 5% manual judgment

---

## Purpose

Detect cross-site request forgery vulnerabilities that allow attackers to force authenticated users to perform unintended actions, and clickjacking (UI redressing) attacks that trick users into clicking hidden elements. CSRF and clickjacking both exploit the trust a site has in the user's browser, but use fundamentally different attack vectors — forged requests vs visual deception.

---

## Tier 0: Static Analysis (Code-Level)

### 0.1 CSRF Middleware Detection

```
Grep patterns:

# Node.js / Express CSRF middleware
pattern: "csurf|csrf-csrf|csrf|lusca\.csrf|helmet\.csrf"
expected: PRESENT on all state-changing routes
flag_if_missing: HIGH — no CSRF middleware detected

# Django CSRF
pattern: "{% csrf_token %}|csrf_token|CsrfViewMiddleware|@csrf_protect"
expected: PRESENT in all forms and middleware chain
pattern: "@csrf_exempt"
severity: HIGH — CSRF protection explicitly disabled on endpoint

# Laravel CSRF
pattern: "@csrf|csrf_field|VerifyCsrfToken"
expected: PRESENT in blade templates and middleware
pattern: "\$except\s*=\s*\["
severity: MEDIUM — routes excluded from CSRF protection (review each)

# Spring Security CSRF
pattern: "csrf\(\)\.disable\(\)|CsrfConfigurer|\.csrf\(AbstractHttpConfigurer::disable\)"
severity: HIGH — CSRF protection disabled
pattern: "CsrfToken|_csrf"
expected: PRESENT in form submissions

# Ruby on Rails
pattern: "protect_from_forgery|authenticity_token|skip_forgery_protection"
severity_skip: HIGH — forgery protection skipped on endpoint

# ASP.NET
pattern: "\[ValidateAntiForgeryToken\]|@Html\.AntiForgeryToken|AntiForgery"
expected: PRESENT on all POST action methods
pattern: "\[IgnoreAntiforgeryToken\]"
severity: HIGH — anti-forgery explicitly disabled
```

### 0.2 SameSite Cookie Configuration

```
# Check cookie settings in source code
pattern: "SameSite\s*[:=]\s*['\"]?(Strict|Lax|None)['\"]?"
expected: Strict or Lax on session cookies
flag_if: "None" without Secure flag = CRITICAL
flag_if_missing: MEDIUM — SameSite not explicitly set (browser default is Lax)

# Cookie library configuration
pattern: "cookie.*sameSite|sameSite.*cookie"
context: verify session cookies specifically set SameSite
pattern: "express-session|cookie-session|next-auth"
verify: sameSite option is configured in session middleware
```

### 0.3 Frame Protection Headers

```
# X-Frame-Options configuration
pattern: "X-Frame-Options|xFrameOptions|frameguard"
expected: PRESENT with value DENY or SAMEORIGIN
flag_if_missing: HIGH — no clickjacking protection

# CSP frame-ancestors directive
pattern: "frame-ancestors"
expected: PRESENT with 'none' or 'self'
preferred_over: X-Frame-Options (CSP is more flexible and modern)

# Helmet.js frame guard
pattern: "helmet\.frameguard|frameguard"
expected: PRESENT with action 'deny'
```

### 0.4 Custom CSRF Token Implementation

```
# Check for custom CSRF token generation
pattern: "csrfToken|_csrf|X-CSRF-Token|X-XSRF-TOKEN"
context: verify tokens are cryptographically random (not predictable)
verify: tokens are bound to user session (not global)

# Check for double-submit cookie pattern
pattern: "XSRF-TOKEN|xsrf.*cookie"
context: verify HMAC-signed variant (not plain cookie value)

# Check for Sec-Fetch headers validation
pattern: "Sec-Fetch-Site|sec-fetch-site"
expected: PRESENT — modern CSRF defense layer
context: server should reject requests where Sec-Fetch-Site !== 'same-origin'
```

---

## Tier 1: Automated Scanning (7 Checks)

### Check 1: CSRF Token Presence on State-Changing Requests

**Tools:** Burp passive analysis
**WSTG:** WSTG-SESS-05

```
Workflow:
1. Browse the application through Burp Proxy via Playwright:
   - Submit all forms (login, registration, profile update, settings)
   - Perform all state-changing actions (create, update, delete)
   - Test payment/financial transactions
   - Test password change, email change

2. Burp passive analysis — for each POST/PUT/PATCH/DELETE request:
   - Check for CSRF token in request body or custom header
   - Check for Sec-Fetch-Site header
   - Check for Origin/Referer header validation
   
3. Flag state-changing requests WITHOUT any CSRF protection:
   No CSRF token in body AND
   No custom header requirement AND
   No Sec-Fetch-Site validation AND
   Cookie-based authentication (session cookie present)

4. Categorize by impact:
   CRITICAL: Financial transactions, password changes, account deletion
   HIGH: Profile updates, permission changes, data modification
   MEDIUM: Preference changes, non-critical settings
   LOW: Read-only state changes (marking as read, etc.)
```

### Check 2: CSRF Token Validation (Missing, Empty, Reused, Cross-User)

**Tools:** Burp Repeater
**WSTG:** WSTG-SESS-05

```
Workflow:
1. Capture a legitimate state-changing request with valid CSRF token

2. Test missing token:
   - Remove CSRF token parameter entirely from request
   - Send via Burp Repeater
   - Expected: 403 Forbidden or equivalent rejection
   - VULNERABLE if request succeeds without token

3. Test empty token:
   - Set CSRF token value to empty string: csrf_token=
   - Send via Burp Repeater
   - Expected: 403 Forbidden
   - VULNERABLE if request succeeds with empty token

4. Test invalid token:
   - Replace CSRF token with random string
   - Send via Burp Repeater
   - Expected: 403 Forbidden
   - VULNERABLE if request succeeds with arbitrary token

5. Test reused token:
   - Use a previously submitted (consumed) CSRF token
   - Send via Burp Repeater
   - Acceptable: Some frameworks allow reuse within session
   - Flag if token is valid across different sessions

6. Test cross-user token:
   - Log in as User A, capture CSRF token
   - Log in as User B, use User A's CSRF token
   - Send via Burp Repeater
   - Expected: 403 Forbidden
   - CRITICAL if User A's token works for User B's session

7. Test token in different parameter:
   - Move token from body to URL parameter (or vice versa)
   - Verify server validates token from expected location only
```

### Check 3: SameSite Cookie Enforcement

**Tools:** Burp Repeater
**WSTG:** WSTG-SESS-05

```
Workflow:
1. Inspect Set-Cookie headers for session cookies:
   - Extract SameSite attribute value
   - Verify Secure flag is present when SameSite=None

2. Test cross-origin behavior:
   Burp Repeater — send request without session cookie
   simulating cross-site context:
   - Remove Referer header
   - Set Origin to external domain
   - Set Sec-Fetch-Site: cross-site
   - Check if session cookie would be sent in cross-site context

3. Test SameSite=Lax behavior:
   - Top-level GET navigation should include cookie (Lax allows this)
   - Cross-site POST should NOT include cookie
   - Cross-site iframe should NOT include cookie
   - Verify GET requests do not perform state changes

4. Test SameSite=None implications:
   - If SameSite=None, verify Secure flag is present
   - Flag as HIGH if session cookie uses SameSite=None
   - Verify additional CSRF protections exist beyond SameSite

5. Check for cookie without explicit SameSite:
   - Modern browsers default to Lax
   - Flag for explicit configuration recommendation
```

### Check 4: Sec-Fetch-Site Validation

**Tools:** Burp Repeater
**WSTG:** WSTG-SESS-05

```
Workflow:
1. Send legitimate same-origin request with:
   Sec-Fetch-Site: same-origin
   Sec-Fetch-Mode: navigate
   Sec-Fetch-Dest: document
   Expected: 200 OK

2. Modify Sec-Fetch-Site header:
   Sec-Fetch-Site: cross-site
   Expected: 403 Forbidden on state-changing endpoints
   VULNERABLE if request succeeds

3. Test without Sec-Fetch-Site header:
   Remove header entirely (older browsers do not send it)
   Expected: Server should still validate via other means
   Flag if this is the ONLY CSRF defense (not all browsers send it)

4. Test Sec-Fetch-Site: none
   Represents direct navigation (address bar)
   Should be allowed for GET requests
   Should be blocked for POST/PUT/DELETE requests

5. Document server's fetch metadata handling:
   - Does server validate Sec-Fetch-Site?
   - Is it the primary or supplementary CSRF defense?
   - What is the fallback for browsers not supporting fetch metadata?
```

### Check 5: Clickjacking Protection (X-Frame-Options + CSP frame-ancestors)

**Tools:** Burp passive scan + Burp Clickbandit
**WSTG:** WSTG-CLNT-09

```
Workflow:
1. Burp passive scan — check all page responses for:
   X-Frame-Options: DENY or SAMEORIGIN
   Content-Security-Policy: frame-ancestors 'none' or 'self'
   Flag if NEITHER header is present

2. Verify header consistency:
   - Check ALL responses (not just the homepage)
   - Sensitive pages (login, payment, settings) MUST have frame protection
   - API responses do not need frame protection (not rendered in browser)

3. Burp Clickbandit — generate clickjacking PoC:
   - Create transparent iframe overlay on target page
   - Position iframe so critical buttons (Submit, Delete, Confirm) align
   - Verify if page renders inside iframe
   - If page renders: VULNERABLE to clickjacking

4. Test X-Frame-Options edge cases:
   - ALLOWFROM is deprecated (not supported by Chrome/Edge)
   - If using ALLOWFROM, recommend CSP frame-ancestors instead
   - Check for conflicting X-Frame-Options values across responses

5. Test CSP frame-ancestors:
   - Verify frame-ancestors 'none' blocks all framing
   - If 'self' is used, verify subdomain scope is appropriate
   - Check for overly permissive frame-ancestors (third-party domains)
```

### Check 6: Frame-Busting Bypass (Sandbox Attribute)

**Tools:** Burp Clickbandit
**WSTG:** WSTG-CLNT-09

```
Workflow:
1. Check for JavaScript-based frame busting:
   pattern: "top\.location|self\.location|window\.top|parent\.location"
   pattern: "if\s*\(.*top\s*!==?\s*self|window\s*!==?\s*top\)"
   Note: JS frame-busting is INSUFFICIENT as sole protection

2. Test frame-busting bypass via sandbox:
   Create iframe with sandbox attribute:
   <iframe sandbox="allow-forms" src="https://target.com/sensitive-page">
   - sandbox without allow-scripts disables JS frame-busting
   - If page renders in sandboxed iframe: frame-busting is bypassed
   - User can still click on forms within sandboxed iframe

3. Test sandbox attribute combinations:
   - sandbox="" — most restrictive, blocks all
   - sandbox="allow-forms" — allows form submission but blocks scripts
   - sandbox="allow-scripts" — allows scripts (frame-busting may work)
   - sandbox="allow-forms allow-same-origin" — dangerous combination

4. Verify defense-in-depth:
   - X-Frame-Options/CSP frame-ancestors should be the PRIMARY defense
   - JS frame-busting is a SECONDARY defense only
   - Flag if JS frame-busting is the only protection
```

### Check 7: CSRF in GraphQL

**Tools:** Burp Repeater
**WSTG:** WSTG-SESS-05, WSTG-APIT-01

```
Workflow:
1. Test GraphQL mutations via GET request:
   GET /graphql?query=mutation{updateEmail(email:"attacker@evil.com")}
   Expected: 405 Method Not Allowed for mutations via GET
   VULNERABLE if mutation executes via GET (CSRF via <img> tag)

2. Test GraphQL mutations with x-www-form-urlencoded content type:
   POST /graphql
   Content-Type: application/x-www-form-urlencoded
   Body: query=mutation{updateEmail(email:"attacker@evil.com")}
   Expected: Rejected — GraphQL should require application/json
   VULNERABLE if mutation executes (CSRF via HTML form submission)

3. Test GraphQL without CSRF token:
   POST /graphql
   Content-Type: application/json
   (Remove CSRF token if present)
   Body: {"query":"mutation{updateEmail(email:\"attacker@evil.com\")}"}
   Expected: 403 if CSRF token is required
   Note: application/json triggers CORS preflight (partial protection)

4. Test GraphQL mutations via multipart/form-data:
   POST /graphql
   Content-Type: multipart/form-data
   (File upload mutation via form)
   VULNERABLE if no CSRF token required for file upload mutations

5. Verify GraphQL CSRF defenses:
   - Custom Content-Type header requirement (application/json)
   - CSRF token validation on all mutations
   - SameSite cookie enforcement
   - Sec-Fetch-Site header validation
```

---

## Tier 2: AI Judgment (6 Contextual Questions)

### Q1: State-Changing Operation Coverage
Are ALL state-changing operations protected against CSRF? Review: account settings, financial transactions, privilege changes, data creation/modification/deletion, password/email changes, API key generation, webhook configuration. Is anything missing CSRF protection?

### Q2: Defense-in-Depth Assessment
Does the application rely on a single CSRF defense mechanism, or does it layer multiple defenses (CSRF tokens + SameSite cookies + Sec-Fetch-Site + Origin validation)? What happens if one layer fails?

### Q3: Token Generation Quality
Are CSRF tokens cryptographically random (CSPRNG)? Are they of sufficient length (minimum 128 bits)? Are they bound to the user's session? Could an attacker predict or brute-force a valid token?

### Q4: Clickjacking Impact Assessment
For pages vulnerable to clickjacking, what is the actual impact? Can an attacker trick users into performing dangerous actions (deleting accounts, transferring funds, changing permissions)? Are there confirmation dialogs that add a layer of protection?

### Q5: Framework CSRF Configuration
Is the CSRF middleware correctly configured for the framework in use? Common misconfigurations: excluding API routes from CSRF protection, not regenerating tokens after login, using predictable token generation, allowing token reuse across sessions.

### Q6: Cross-Origin Request Architecture
Does the application legitimately need to accept cross-origin requests (API used by mobile apps, third-party integrations, widget embedding)? Are these legitimate cross-origin flows properly secured with alternative mechanisms (API keys, OAuth tokens, CORS with credentials)?

---

## Severity Classification

### Critical (P1 — Score: 0/10)
- No CSRF protection on password change, email change, or account deletion
- No CSRF protection on financial transactions (transfers, purchases)
- CSRF token validated but cross-user tokens accepted (token not bound to session)
- Clickjacking on payment confirmation or permission grant pages with no frame protection

### High (P2 — Score: 2/10)
- No CSRF protection on profile updates or data modification endpoints
- CSRF token can be bypassed by removing the token entirely (no server validation)
- Empty CSRF token accepted by server
- GraphQL mutations executable via GET request or x-www-form-urlencoded POST
- No clickjacking protection (X-Frame-Options or CSP frame-ancestors) on sensitive pages

### Medium (P3 — Score: 5/10)
- CSRF token present but reusable across sessions (not regenerated on login)
- SameSite=None on session cookies without additional CSRF protections
- JavaScript-only frame busting (bypassable via sandbox attribute)
- CSRF protection missing on low-impact state changes (preferences, theme)
- Inconsistent frame protection (present on some pages, missing on others)

### Low (P4 — Score: 7/10)
- CSRF token present and validated but not rotated per-request (per-session is acceptable)
- SameSite=Lax instead of Strict (Lax allows top-level GET navigations)
- X-Frame-Options SAMEORIGIN when DENY would be more appropriate
- Missing Sec-Fetch-Site validation (supplementary defense only)
- ALLOWFROM used instead of CSP frame-ancestors

---

## False Positive Indicators

### CSRF False Positives
- **API endpoints using Bearer tokens:** APIs authenticated via Authorization header (not cookies) are NOT vulnerable to CSRF because the header cannot be set cross-origin. Only cookie-based auth is vulnerable
- **SameSite=Lax with GET-only state:** If SameSite=Lax and all state-changing operations require POST/PUT/DELETE, CSRF is effectively mitigated (Lax blocks cross-site POST)
- **CORS preflight protection:** Requests with custom Content-Type (application/json) trigger CORS preflight. If CORS does not allow the attacker's origin, the request is blocked. Note: this is NOT a complete defense (some browsers may not send preflight)
- **Non-state-changing requests:** GET requests that only read data do not need CSRF protection. Verify the GET truly has no side effects
- **Logout CSRF:** CSRF on logout is generally low impact (attacker logs out victim) — still report but at Low severity

### Clickjacking False Positives
- **Pages with no interactive elements:** Static content pages, marketing pages, and public documentation are low-risk for clickjacking
- **Login pages with MFA:** Even if frameable, MFA adds a layer that clickjacking cannot bypass
- **API endpoints:** JSON API responses are not rendered in browser — clickjacking is not applicable
- **Pages behind authentication:** If the attacker cannot predict the page content, clickjacking is harder (but not impossible with multi-step attacks)

---

## Remediation

### CSRF Protection Implementation
1. **Synchronizer Token Pattern (recommended):**
   - Generate cryptographically random token per session
   - Embed in hidden form field or custom header
   - Validate on server for every state-changing request
   - Regenerate token after login

2. **Double-Submit Cookie (alternative):**
   - Set CSRF token as cookie AND include in request body/header
   - Server compares cookie value with body/header value
   - Use HMAC-signed variant (not plain cookie value)

3. **SameSite Cookie Configuration:**
   ```
   Set-Cookie: session=abc123; Secure; HttpOnly; SameSite=Strict; Path=/
   ```
   - Use Strict for maximum protection (no cross-site cookie sending)
   - Use Lax if top-level GET navigation requires cookies (OAuth redirects)

4. **Sec-Fetch Metadata Validation:**
   ```
   if (request.method !== 'GET') {
     const site = request.headers['sec-fetch-site'];
     if (site && site !== 'same-origin' && site !== 'same-site') {
       return response.status(403).send('Cross-site request blocked');
     }
   }
   ```

5. **Origin/Referer Header Validation:**
   - Verify Origin header matches expected domain
   - Fall back to Referer if Origin is absent
   - Block requests with neither header on state-changing operations

### Clickjacking Protection Implementation
1. **CSP frame-ancestors (modern, preferred):**
   ```
   Content-Security-Policy: frame-ancestors 'none'
   ```
   Use 'self' if same-origin framing is required.

2. **X-Frame-Options (legacy browser support):**
   ```
   X-Frame-Options: DENY
   ```
   Use SAMEORIGIN if same-origin framing is required.

3. **Set both headers** for maximum compatibility:
   ```
   X-Frame-Options: DENY
   Content-Security-Policy: frame-ancestors 'none'
   ```

4. **JavaScript frame-busting (supplementary only):**
   ```javascript
   if (window.top !== window.self) {
     window.top.location = window.self.location;
   }
   ```
   Never rely on this as the sole defense.

### GraphQL CSRF Prevention
1. Reject mutations via GET — only allow POST for mutations
2. Require Content-Type: application/json (reject form-urlencoded)
3. Require custom header (X-Requested-With or CSRF token header)
4. Validate SameSite cookies and Sec-Fetch-Site headers
