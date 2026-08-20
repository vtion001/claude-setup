# Pass 02: Security Headers & Configuration

**Weight:** 8% of Security Score
**OWASP Mapping:** A02:2025 (Security Misconfiguration), WSTG-CONF-01 through WSTG-CONF-11
**Focus:** Server configuration, security headers, TLS settings, CORS policy, cookie flags, and deployment hardening. These are often the easiest wins with the broadest impact.
**Automation Level:** 95% fully automated, 5% AI-assisted

---

## Tier 0: Static Analysis

Grep/Read patterns to verify security headers and configuration are implemented in source code.

### 0.1 Security Header Middleware Detection

Verify that security headers are configured at the application or server level.

**Grep patterns:**

```
# Helmet.js (Express/Node)
pattern: (require\s*\(\s*['"]helmet['"]\)|import\s+helmet|app\.use\s*\(\s*helmet)
glob: "*.{js,ts,mjs}"

# Next.js security headers in config
pattern: (headers|securityHeaders|Content-Security-Policy|X-Frame-Options|Strict-Transport-Security)
glob: "**/next.config.{js,ts,mjs}"

# Vercel/Netlify header config
pattern: (headers|X-Frame-Options|Content-Security-Policy)
glob: "**/vercel.json"
pattern: (headers|X-Frame-Options|Content-Security-Policy)
glob: "**/netlify.toml"

# Laravel middleware
pattern: (VerifyCsrfToken|TrustProxies|PreventRequestsDuringMaintenance|SecurityHeaders)
glob: "**/*.php"

# Django security middleware
pattern: (SecurityMiddleware|SECURE_BROWSER_XSS_FILTER|SECURE_CONTENT_TYPE_NOSNIFF|SECURE_HSTS)
glob: "**/settings.py"

# ASP.NET security headers
pattern: (UseHsts|UseHttpsRedirection|AddAntiforgery|Content-Security-Policy)
glob: "*.{cs,cshtml}"

# Nginx security headers
pattern: (add_header\s+(X-Frame-Options|Content-Security-Policy|Strict-Transport-Security|X-Content-Type-Options))
glob: "**/nginx*.conf"

# Apache security headers
pattern: (Header\s+(set|always\s+set)\s+(X-Frame-Options|Content-Security-Policy|Strict-Transport-Security))
glob: "**/.htaccess"
```

**What to look for:**
- Whether ANY security header middleware exists
- If headers are applied globally or only to specific routes
- If CSP is defined or only a placeholder

### 0.2 CORS Configuration

Check for CORS settings and identify overly permissive configurations.

**Grep patterns:**

```
# Express CORS
pattern: (cors\s*\(|Access-Control-Allow-Origin|credentials:\s*true|origin:\s*['"]?\*)
glob: "*.{js,ts,mjs}"

# Next.js CORS
pattern: (Access-Control-Allow-Origin|allowedOrigins|cors)
glob: "**/next.config.{js,ts,mjs}"
glob: "**/middleware.{js,ts}"

# Django CORS
pattern: (CORS_ALLOW_ALL_ORIGINS|CORS_ALLOWED_ORIGINS|CORS_ALLOW_CREDENTIALS)
glob: "**/settings.py"

# Laravel CORS
pattern: (allowed_origins|supports_credentials|allowed_methods)
glob: "**/cors.php"

# Generic wildcard origin
pattern: Access-Control-Allow-Origin.*\*
glob: "*"
```

**Critical findings:**
- `origin: '*'` with `credentials: true` — this is a broken configuration (browsers block it, but the intent is dangerous)
- Dynamic origin reflection without validation
- `CORS_ALLOW_ALL_ORIGINS = True` in production

### 0.3 Debug Mode and Verbose Error Settings

Check that debug mode is disabled in production configurations.

**Grep patterns:**

```
# Node/Express debug
pattern: (DEBUG\s*[:=]|NODE_ENV\s*[:=]\s*['"]development['"]|app\.set\s*\(\s*['"]env['"].*development)
glob: "*.{js,ts,env,yml,yaml}"

# Django debug
pattern: DEBUG\s*=\s*True
glob: "**/settings.py"

# Laravel debug
pattern: APP_DEBUG\s*=\s*true
glob: "**/.env*"

# Flask debug
pattern: (debug\s*=\s*True|FLASK_DEBUG\s*=\s*1)
glob: "*.{py,env}"

# Next.js error overlay
pattern: (reactStrictMode|devIndicators)
glob: "**/next.config.{js,ts,mjs}"

# Generic debug flags
pattern: (debug_mode|DEBUG_MODE|verbose_errors|SHOW_ERRORS)\s*[:=]\s*(true|1|['"]true['"]|yes)
glob: "*.{js,ts,py,php,env,yml,yaml,json}"
```

### 0.4 .env File Security

Verify .env files are properly gitignored and not exposed.

**Glob patterns:**
```
**/.env
**/.env.local
**/.env.production
**/.env.staging
**/.env.development
```

**Grep in .gitignore:**
```
pattern: \.env
glob: "**/.gitignore"
```

**What to look for:**
- .env files not listed in .gitignore
- .env files committed to git history
- Sensitive values in .env.example (should use placeholders)

---

## Tier 1: Automated Scanning

### 1.1 Complete Security Headers Audit

**Purpose:** Verify all 14 OWASP-recommended security headers are present and correctly configured.

**Burp Passive Scan Workflow:**
1. Navigate to multiple pages using Playwright
2. Capture all HTTP responses in Burp proxy
3. Analyze response headers against the complete checklist

**Header Checklist (14 headers):**

| Header | Required Value | Severity if Missing |
|--------|---------------|-------------------|
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains; preload` | High |
| `Content-Security-Policy` | Strict policy (see 1.2) | High |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` | Medium |
| `X-Content-Type-Options` | `nosniff` | Medium |
| `Referrer-Policy` | `no-referrer` or `strict-origin-when-cross-origin` | Medium |
| `Permissions-Policy` | Restrictive (disable unused APIs) | Medium |
| `Cross-Origin-Opener-Policy` | `same-origin` | Medium |
| `Cross-Origin-Embedder-Policy` | `require-corp` | Low |
| `Cross-Origin-Resource-Policy` | `same-origin` | Low |
| `Cache-Control` | `no-store, max-age=0` (sensitive pages) | Medium |
| `X-DNS-Prefetch-Control` | `off` | Low |
| `X-Permitted-Cross-Domain-Policies` | `none` | Low |
| `Clear-Site-Data` | Present on logout responses | Low |
| `Expect-CT` | `max-age=86400, enforce` (if still supported) | Info |

**Playwright Commands:**
```
browser_navigate → target URL
browser_evaluate → {
  return new Promise(resolve => {
    fetch(window.location.href, { method: 'HEAD' })
      .then(r => {
        const headers = {};
        r.headers.forEach((v, k) => { headers[k] = v; });
        resolve(headers);
      });
  });
}
```

### 1.2 CSP Deep Analysis

**Purpose:** Analyze Content-Security-Policy for dangerous directives that weaken protection.

**Burp Workflow + Playwright:**
1. Extract CSP header from Burp proxy responses
2. Parse each directive and evaluate against security benchmarks

**Playwright Commands:**
```
browser_evaluate → {
  const meta = document.querySelector('meta[http-equiv="Content-Security-Policy"]');
  const cspMeta = meta ? meta.getAttribute('content') : null;
  return { cspMeta };
}
```

**CSP Analysis Checklist:**

| Directive Issue | Severity | Description |
|----------------|----------|-------------|
| `unsafe-inline` in `script-src` | High | Allows inline scripts, defeats XSS protection |
| `unsafe-eval` in `script-src` | High | Allows eval(), enables code injection |
| `*` wildcard in any `*-src` | High | Allows loading from any origin |
| `data:` in `script-src` | High | Allows data: URI scripts |
| Missing `default-src` | Medium | No fallback for undefined directives |
| Missing `object-src 'none'` | Medium | Allows Flash/Java plugins |
| Missing `base-uri 'self'` | Medium | Allows base tag hijacking |
| Missing `form-action` | Medium | Allows form submission to any origin |
| Missing `frame-ancestors` | Medium | No clickjacking protection via CSP |
| `https:` as sole restriction | Medium | Too broad, allows any HTTPS origin |
| Missing `upgrade-insecure-requests` | Low | Mixed content not auto-upgraded |
| Missing `report-uri` or `report-to` | Info | No CSP violation reporting |

**Bypass validation (Burp Repeater):**
- If CSP allows specific domains, check for JSONP endpoints on those domains
- If CSP allows `strict-dynamic`, verify nonce implementation
- Check if CSP is report-only (not enforcing)

### 1.3 CORS Configuration Testing

**Purpose:** Verify CORS policy does not allow unauthorized cross-origin access.

**Burp Repeater Workflow:**
1. Send request with `Origin: https://evil.com` header
2. Send request with `Origin: null` header
3. Send request with `Origin: https://subdomain.{target}` header
4. Send request with `Origin: https://{target}.evil.com` header
5. Analyze `Access-Control-Allow-Origin` and `Access-Control-Allow-Credentials` in responses

**Test Matrix:**

| Test | Origin Sent | Expected Response | Finding if Fails |
|------|------------|-------------------|-----------------|
| Arbitrary origin | `https://evil.com` | No ACAO header or not reflected | High — origin reflection |
| Null origin | `null` | No ACAO header | High — null origin accepted |
| Subdomain | `https://sub.{target}` | ACAO matches only if subdomain is trusted | Medium |
| Prefix attack | `https://{target}.evil.com` | No ACAO header | High — weak prefix matching |
| Credentials | Any reflected origin | ACAC should NOT be `true` with wildcard | Critical — credential theft |

### 1.4 HTTP Methods Testing

**Purpose:** Verify only necessary HTTP methods are enabled on each endpoint.

**Burp Intruder Workflow:**
1. For each discovered endpoint, send OPTIONS request
2. Parse `Allow` header to see which methods are permitted
3. Test dangerous methods: PUT, DELETE, TRACE, CONNECT

**Specific method tests (Burp Repeater):**

```
# TRACE method (XST attack vector)
TRACE {target} HTTP/1.1
Host: {target-host}

# PUT method (unauthorized file upload)
PUT {target}/test.txt HTTP/1.1
Host: {target-host}
Content-Type: text/plain

test content

# DELETE method
DELETE {target}/api/resource/1 HTTP/1.1
Host: {target-host}
```

**Severity:** TRACE enabled = Medium. PUT/DELETE without auth = High.

### 1.5 TLS Version and Cipher Suite Analysis

**Purpose:** Verify only secure TLS versions and cipher suites are supported.

**Burp Workflow:**
1. Use Burp's TLS configuration analysis
2. Check for deprecated protocol support

**Checks:**

| Check | Expected | Severity if Fails |
|-------|----------|------------------|
| TLS 1.0 disabled | Not supported | High |
| TLS 1.1 disabled | Not supported | High |
| TLS 1.2 supported | Supported with strong ciphers | Required |
| TLS 1.3 supported | Supported | Recommended |
| RC4 ciphers disabled | Not offered | High |
| DES/3DES disabled | Not offered | High |
| NULL ciphers disabled | Not offered | Critical |
| Forward secrecy | ECDHE/DHE ciphers preferred | Medium |
| Certificate validity | Not expired, correct hostname | Critical |
| Certificate chain | Complete chain to trusted CA | High |

### 1.6 Cookie Security Flags

**Purpose:** Verify all cookies have appropriate security attributes.

**Burp Passive Scan Workflow:**
1. Intercept all Set-Cookie headers during browsing
2. Analyze each cookie for required flags

**Cookie Attribute Checklist:**

| Attribute | Required For | Severity if Missing |
|-----------|-------------|-------------------|
| `Secure` | All cookies on HTTPS sites | High |
| `HttpOnly` | Session cookies, auth tokens | High |
| `SameSite=Strict` or `Lax` | All cookies | Medium |
| `Path=/` (appropriate scope) | All cookies | Low |
| `Domain` (not overly broad) | All cookies | Medium |
| `__Host-` prefix | Session cookies (strongest) | Info |
| `__Secure-` prefix | Auth cookies on HTTPS | Info |
| `Max-Age` or `Expires` | Persistent cookies | Low |

**Playwright Commands:**
```
browser_evaluate → {
  return document.cookie.split(';').map(c => {
    const [name, value] = c.trim().split('=');
    return { name: name.trim(), valueLength: (value || '').length };
  });
}
```

### 1.7 Directory Listing Detection

**Purpose:** Verify directory browsing is disabled on the web server.

**Burp + Playwright Workflow:**
1. Navigate to known directories without a trailing filename
2. Check for directory listing indicators

**Test paths (Burp Intruder):**
```
{target}/images/
{target}/assets/
{target}/uploads/
{target}/static/
{target}/css/
{target}/js/
{target}/files/
{target}/backup/
{target}/logs/
```

**Detection indicators:**
- HTML title containing "Index of" or "Directory listing"
- Apache/Nginx default directory listing template
- File/folder listings with modification dates and sizes
- Sortable column headers (Name, Size, Date)

### 1.8 Default Credentials on Admin Paths

**Purpose:** Test common admin paths for default username/password combinations.

**Burp Intruder Workflow:**
1. For each discovered admin path (from Pass 01), attempt login with default credentials
2. Use Pitchfork attack type with correlated username:password pairs
3. Limit to max 10 attempts per endpoint to avoid lockout

**Default credential pairs:**
```
admin:admin
admin:password
admin:123456
administrator:administrator
root:root
root:toor
user:user
test:test
demo:demo
guest:guest
```

**Rate limiting:** Max 1 request every 3 seconds. Stop immediately if lockout is detected.

### 1.9 Information Disclosure Headers

**Purpose:** Verify technology-revealing headers are removed from production responses.

**Burp Passive Scan Workflow:**
1. Check all responses for headers that should be removed
2. Flag any headers that reveal specific technology or version information

**Headers to flag:**

| Header | Risk | Action |
|--------|------|--------|
| `Server: Apache/2.4.51` | Medium | Remove or genericize |
| `X-Powered-By: Express` | Medium | Remove (`app.disable('x-powered-by')`) |
| `X-Powered-By: PHP/8.1` | Medium | Remove (`expose_php = Off`) |
| `X-AspNet-Version: 4.0` | Medium | Remove |
| `X-Generator: WordPress 6.4` | Medium | Remove |
| `X-Drupal-Cache` | Low | Remove |
| `X-SourceMap` | Medium | Remove in production |
| `X-Debug-Token` | High | Remove in production |
| `X-Runtime` | Low | Remove (timing oracle) |

### 1.10 Cloud Storage Exposure

**Purpose:** Check for misconfigured cloud storage buckets/containers that allow public access.

**WebFetch Workflow:**
1. Identify cloud storage URLs from source code (Tier 0) and JavaScript analysis
2. Test each discovered bucket/container for public access

**Test patterns:**
```
# AWS S3
https://{bucket}.s3.amazonaws.com/
https://{bucket}.s3.{region}.amazonaws.com/
https://s3.amazonaws.com/{bucket}/

# Azure Blob
https://{account}.blob.core.windows.net/{container}/

# GCP Storage
https://storage.googleapis.com/{bucket}/
https://{bucket}.storage.googleapis.com/
```

**What to check:**
- Can the bucket be listed without authentication?
- Can objects be read without authentication?
- Are write permissions open?

### 1.11 HSTS Preload Readiness

**Purpose:** Verify HSTS header meets preload list requirements.

**Burp Passive Analysis:**
1. Extract `Strict-Transport-Security` header
2. Validate against preload requirements

**Preload requirements:**
- `max-age` >= 31536000 (1 year, recommended 63072000 / 2 years)
- `includeSubDomains` directive present
- `preload` directive present
- Served over HTTPS
- Redirects from HTTP to HTTPS (same host, then to HTTPS of same host before redirect elsewhere)
- All subdomains must support HTTPS

### 1.12 Headers-to-Remove Verification

**Purpose:** Comprehensive check that all headers revealing unnecessary information are stripped.

**Burp Passive Analysis:**
1. Collect all response headers across all pages
2. Create a unique header list
3. Flag any non-standard headers that could leak information

**Headers that should be present:**
- All 14 security headers from check 1.1

**Headers that should NOT be present:**
- `Server` (with version)
- `X-Powered-By`
- `X-AspNet-Version`
- `X-Generator`
- `X-SourceMap`
- `X-Debug-Token`
- `X-Request-Id` (in production, unless needed for support)
- Any custom debug headers

---

## Tier 2: AI Judgment

### Question 1: CSP Effectiveness
Given the application's functionality (SPA, SSR, embedded content, third-party widgets), is the CSP policy appropriately restrictive without breaking functionality? Would a stricter policy be feasible?

### Question 2: CORS Necessity
Does the application legitimately need CORS? If so, are the allowed origins limited to known trusted domains? Could the CORS policy be more restrictive?

### Question 3: Cookie Architecture
Are cookies being used appropriately? Should any data currently in cookies be moved to server-side sessions? Are there cookies that should not exist?

### Question 4: Header Completeness
Considering the full response header set, are there any missing headers that would significantly improve the security posture for this specific application type?

### Question 5: Configuration Drift Risk
Are security configurations defined in code (infrastructure-as-code) or manually configured on servers? Is there risk of configuration drift between environments?

### Question 6: Debug Surface
Even with debug mode disabled, are there residual debug endpoints, verbose error messages, or development tools accessible in the production deployment?

### Question 7: TLS Configuration Context
Is the TLS configuration appropriate for the application's compliance requirements (PCI-DSS, HIPAA, SOC 2)? Are there any cipher suites that should be disabled for compliance?

### Question 8: Cloud Configuration
Are cloud service configurations (S3 buckets, CDN settings, serverless function permissions) following least-privilege principles? Are there any overly permissive IAM or bucket policies?

---

## Severity Classification

### Critical
- `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true`
- NULL TLS cipher suites enabled
- Expired or invalid TLS certificate
- Cloud storage bucket with public write access
- Debug mode enabled in production with stack traces visible

### High
- Missing CSP header entirely
- CSP with `unsafe-inline` and `unsafe-eval` in `script-src`
- Missing HSTS header on HTTPS site
- TLS 1.0 or 1.1 still supported
- Session cookies missing `Secure` or `HttpOnly` flags
- CORS reflecting arbitrary origins
- Directory listing enabled exposing sensitive files

### Medium
- Missing `X-Frame-Options` or CSP `frame-ancestors` (clickjacking risk)
- Missing `X-Content-Type-Options: nosniff`
- Missing `Referrer-Policy`
- Missing `Permissions-Policy`
- CORS with overly broad allowed origins
- Cookies missing `SameSite` attribute
- Server/X-Powered-By headers revealing technology and version
- Weak TLS cipher suites (no forward secrecy)

### Low
- Missing `Cross-Origin-Embedder-Policy`
- Missing `Cross-Origin-Resource-Policy`
- Missing `X-DNS-Prefetch-Control`
- Server header present without version (just "nginx" or "Apache")
- Cache-Control not set to `no-store` on non-sensitive pages
- Missing HSTS `preload` directive (has HSTS but not preload-ready)

---

## False Positive Indicators

1. **CDN-injected headers** — Some headers come from CDN/WAF layers, not the application. The CDN may strip application headers or add its own. Verify by testing directly against origin if possible.
2. **CSP report-only** — `Content-Security-Policy-Report-Only` is not enforcement. Note it as "CSP exists but is not enforced" rather than "CSP missing."
3. **API vs page responses** — API endpoints may legitimately have different headers than HTML pages. Evaluate headers in context.
4. **CORS on public APIs** — Some APIs are intentionally public and need `Access-Control-Allow-Origin: *`. This is acceptable IF no credentials are used.
5. **Development environment** — Security headers may intentionally differ in development. Only flag for production configs.
6. **Static asset caching** — `Cache-Control` on static assets (images, CSS, JS) should allow caching. Only flag `no-store` missing on sensitive/dynamic pages.
7. **HSTS on localhost** — HSTS should not be tested against localhost. Only evaluate on HTTPS domains.
8. **Load balancer headers** — `X-Request-Id`, `X-Correlation-Id` are operational headers, not security risks unless they leak internal IPs.

---

## Remediation

### Security Headers Implementation

**Express/Node.js (Helmet.js):**
```javascript
const helmet = require('helmet');
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'"],
      imgSrc: ["'self'", "data:"],
      objectSrc: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
      frameAncestors: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  strictTransportSecurity: { maxAge: 63072000, includeSubDomains: true, preload: true },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  crossOriginEmbedderPolicy: { policy: 'require-corp' },
  crossOriginResourcePolicy: { policy: 'same-origin' },
  dnsPrefetchControl: { allow: false },
  permittedCrossDomainPolicies: { permittedPolicies: 'none' },
}));
app.disable('x-powered-by');
```

**Next.js (next.config.js):**
```javascript
const securityHeaders = [
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  { key: 'Content-Security-Policy', value: "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests" },
];
```

### CORS Hardening
- Replace wildcard origins with explicit domain allowlist
- Remove `credentials: true` unless specifically needed for authenticated cross-origin requests
- Validate origin against allowlist on every request, not just on OPTIONS preflight
- Set appropriate `Access-Control-Max-Age` to reduce preflight requests

### Cookie Hardening
- Add `Secure` flag to all cookies on HTTPS sites
- Add `HttpOnly` to all cookies that don't need JavaScript access
- Set `SameSite=Strict` for session cookies, `SameSite=Lax` as minimum for all others
- Use `__Host-` prefix for session cookies
- Set appropriate `Path` to limit cookie scope
- Set explicit `Domain` to prevent subdomain access where not needed

### TLS Hardening
- Disable TLS 1.0 and TLS 1.1
- Disable RC4, DES, 3DES, NULL, and export cipher suites
- Prefer ECDHE cipher suites for forward secrecy
- Enable TLS 1.3 where supported
- Implement OCSP stapling
- Renew certificates before expiry (automate with Let's Encrypt/certbot)
