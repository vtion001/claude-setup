# Pass 01: Reconnaissance & Attack Surface Mapping

**Weight:** 3% of Security Score
**OWASP Mapping:** WSTG-INFO-01 through WSTG-INFO-10
**Focus:** Map the complete attack surface before testing begins. Identify technologies, endpoints, entry points, and exposed information that inform all subsequent passes.
**Automation Level:** 75% fully automated, 20% AI-assisted, 5% manual judgment

---

## Tier 0: Static Analysis

Grep/Read patterns to check in source code before any browser or Burp interaction.

### 0.1 API Endpoint Discovery in Source Code

Scan for all HTTP client calls and route definitions to build an endpoint map.

**Grep patterns:**

```
# Express/Node route definitions
pattern: (app|router)\.(get|post|put|patch|delete|all|use)\s*\(
glob: "*.{js,ts,mjs}"

# Next.js API routes (file-based)
pattern: export\s+(default\s+)?(async\s+)?function\s+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)
glob: "**/app/**/route.{js,ts}"

# Next.js pages router API
glob: "**/pages/api/**/*.{js,ts}"

# FastAPI/Flask/Django route definitions
pattern: @(app|router|api_view)\.(get|post|put|patch|delete|route)\s*\(
glob: "*.py"

# Laravel route definitions
pattern: Route::(get|post|put|patch|delete|any|resource|apiResource)\s*\(
glob: "*.php"

# Fetch/Axios client-side calls
pattern: (fetch|axios)\s*\(|\.get\s*\(|\.post\s*\(|\.put\s*\(|\.delete\s*\(
glob: "*.{js,ts,jsx,tsx}"

# GraphQL endpoint definitions
pattern: (typeDefs|schema|gql`|graphql|Query|Mutation|Subscription)
glob: "*.{js,ts,graphql,gql}"

# WebSocket endpoints
pattern: (WebSocket|ws://|wss://|socket\.io|io\()
glob: "*.{js,ts,jsx,tsx}"
```

**What to look for:**
- Total count of unique endpoints
- Unprotected routes (missing auth middleware)
- Internal/debug endpoints that may be exposed
- API versioning patterns (v1, v2, etc.)

### 0.2 Exposed Secrets in Source Code

Search for hardcoded credentials, API keys, tokens, and secrets.

**Grep patterns:**

```
# API keys and tokens
pattern: (api[_-]?key|apikey|api[_-]?secret|api[_-]?token)\s*[:=]\s*['"][A-Za-z0-9+/=_-]{16,}
glob: "*.{js,ts,jsx,tsx,py,php,rb,java,go,env,yml,yaml,json}"

# AWS credentials
pattern: (AKIA[0-9A-Z]{16}|aws[_-]?(secret|access)[_-]?key)
glob: "*"

# Private keys
pattern: -----BEGIN\s+(RSA|EC|DSA|OPENSSH)?\s*PRIVATE\s+KEY-----
glob: "*"

# JWT secrets
pattern: (jwt[_-]?secret|JWT_SECRET|token[_-]?secret)\s*[:=]\s*['"]
glob: "*.{js,ts,py,php,env,yml,yaml}"

# Database connection strings
pattern: (mongodb(\+srv)?://|postgres(ql)?://|mysql://|redis://|amqp://)
glob: "*.{js,ts,py,php,env,yml,yaml,json}"

# Generic password patterns
pattern: (password|passwd|pwd|secret)\s*[:=]\s*['"][^'"]{8,}['"]
glob: "*.{js,ts,py,php,env,yml,yaml,json}"

# Stripe keys
pattern: (sk_live_|pk_live_|rk_live_)[A-Za-z0-9]{20,}
glob: "*"

# SendGrid, Twilio, Firebase keys
pattern: (SG\.[A-Za-z0-9_-]{22,}|AC[a-f0-9]{32}|AIza[A-Za-z0-9_-]{35})
glob: "*"
```

**What to look for:**
- Any match is a potential Critical finding
- Check if the file is in .gitignore
- Verify if the secret is a placeholder/example vs real value
- Check git history for previously committed secrets

### 0.3 Configuration File Discovery

Identify configuration files that reveal architecture and security settings.

**Glob patterns:**

```
# Environment files
**/.*env*
**/.env.local
**/.env.production
**/.env.development

# Package manifests (version fingerprinting)
**/package.json
**/composer.json
**/requirements.txt
**/Pipfile
**/Gemfile
**/go.mod
**/pom.xml
**/build.gradle

# CI/CD configurations
**/.github/workflows/*.yml
**/.gitlab-ci.yml
**/Jenkinsfile
**/Dockerfile
**/docker-compose*.yml

# Web server configs
**/nginx.conf
**/apache.conf
**/.htaccess
**/next.config.*
**/nuxt.config.*
**/vite.config.*
**/vercel.json
**/netlify.toml

# Security-relevant configs
**/cors.*
**/helmet.*
**/csp.*
**/auth.*
**/middleware.*
```

**What to look for:**
- Debug mode enabled in production configs
- Permissive CORS origins
- Missing security middleware
- Exposed Docker/CI secrets

### 0.4 Framework and Version Detection

Read package manifests to identify frameworks and versions for CVE lookup.

**Read targets:**
- `package.json` — check `dependencies` and `devDependencies` for framework names and versions
- `composer.json` — PHP framework detection
- `requirements.txt` / `Pipfile` — Python framework detection
- `go.mod` — Go framework detection
- `Gemfile` — Ruby framework detection

**Critical version checks:**
- Node.js/Express version (< 4.x has known vulns)
- React version (< 18 missing auto-escaping improvements)
- Next.js version (specific CVEs per version)
- Django version (security patches per minor version)
- Laravel version (known deserialization issues)
- Any dependency with known CVSS >= 7.0

---

## Tier 1: Automated Scanning

Burp MCP + Playwright browser automation checks. Each check describes the specific workflow.

### 1.1 Technology Fingerprinting

**Purpose:** Identify server technologies, frameworks, CDNs, WAFs, and load balancers from HTTP response data.

**Burp Workflow:**
1. Configure Burp proxy to intercept traffic
2. Navigate to the target using Playwright `browser_navigate`
3. Analyze responses with Burp passive scan
4. Examine response headers for technology indicators:
   - `Server` header (Apache, Nginx, IIS, Cloudflare)
   - `X-Powered-By` header (Express, PHP, ASP.NET)
   - `X-Generator` header (WordPress, Drupal)
   - `Via` header (proxy/CDN detection)
   - `X-Cache` header (CDN caching layer)

**Playwright Commands:**
```
browser_navigate → target URL
browser_evaluate → document.querySelector('meta[name="generator"]')?.content
browser_evaluate → Array.from(document.querySelectorAll('script[src]')).map(s => s.src)
browser_evaluate → Array.from(document.querySelectorAll('link[href]')).map(l => l.href)
```

**What to record:** Full technology stack list with versions where available.

### 1.2 Robots.txt and Sitemap Discovery

**Purpose:** Discover paths the application explicitly hides or exposes via robots.txt and sitemap.xml.

**Burp Workflow:**
1. Use WebFetch to retrieve `{target}/robots.txt`
2. Use WebFetch to retrieve `{target}/sitemap.xml`
3. Parse all `Disallow` entries from robots.txt — these are high-priority recon targets
4. Parse all `<loc>` entries from sitemap.xml — these reveal URL structure
5. Check for `sitemap.xml.gz`, `sitemap_index.xml`, `sitemaps/` directory

**WebFetch Targets:**
```
{target}/robots.txt
{target}/sitemap.xml
{target}/sitemap.xml.gz
{target}/sitemap_index.xml
{target}/.well-known/security.txt
{target}/humans.txt
```

**What to record:** All discovered paths, especially `Disallow` entries that hint at admin panels, API docs, or internal tools.

### 1.3 Hidden Endpoint Discovery

**Purpose:** Discover undocumented endpoints including admin panels, API documentation, debug tools, and backup files.

**Burp Intruder Workflow:**
1. Configure Burp Intruder with target base URL
2. Set payload position: `{target}/[PAYLOAD]`
3. Use Sniper attack type with common path wordlist
4. Set rate limit per target type (localhost: 20/sec, staging: 10/sec, production: 2/sec)
5. Analyze responses — flag any non-404 responses

**Wordlist (critical paths to test):**
```
admin
administrator
wp-admin
login
dashboard
api
api/docs
api/v1
api/v2
swagger
swagger-ui
swagger.json
openapi.json
graphql
graphiql
playground
debug
_debug
__debug__
.env
.env.local
.env.production
.git/config
.git/HEAD
.svn/entries
.DS_Store
wp-config.php.bak
config.php.bak
server-status
server-info
phpinfo.php
info.php
test
test.php
backup
db
database
phpmyadmin
adminer
console
shell
actuator
actuator/health
actuator/env
health
healthcheck
metrics
trace
dump
heapdump
```

**Response analysis:**
- 200 OK — endpoint exists, investigate content
- 301/302 — redirect target reveals information
- 401/403 — endpoint exists but requires auth (still valuable recon)
- 500 — error may reveal stack trace

### 1.4 JavaScript Source Analysis for API Endpoints and Secrets

**Purpose:** Extract API endpoints, secrets, and internal URLs from client-side JavaScript bundles.

**Playwright Workflow:**
1. Navigate to target with `browser_navigate`
2. Collect all loaded JavaScript sources
3. Evaluate inline scripts and bundled code for patterns

**Playwright Commands:**
```
browser_evaluate → {
  const scripts = performance.getEntriesByType('resource')
    .filter(r => r.initiatorType === 'script')
    .map(r => r.name);
  return scripts;
}

browser_evaluate → {
  // Search for API endpoints in page context
  const text = document.documentElement.innerHTML;
  const apiPatterns = text.match(/(\/api\/[a-zA-Z0-9/_-]+)/g);
  const urlPatterns = text.match(/https?:\/\/[a-zA-Z0-9._-]+[a-zA-Z0-9./_-]*/g);
  return { apiEndpoints: [...new Set(apiPatterns || [])], urls: [...new Set(urlPatterns || [])] };
}

browser_evaluate → {
  // Check for exposed environment variables
  const windowKeys = Object.keys(window).filter(k =>
    k.includes('ENV') || k.includes('CONFIG') || k.includes('API') ||
    k.includes('SECRET') || k.includes('KEY') || k.includes('TOKEN')
  );
  const envData = {};
  windowKeys.forEach(k => { envData[k] = typeof window[k] === 'object' ? JSON.stringify(window[k]).substring(0, 200) : String(window[k]).substring(0, 200); });
  return envData;
}
```

**Burp passive analysis:** Review all JavaScript responses in Burp proxy history for:
- Hardcoded API keys or tokens
- Internal hostnames or IP addresses
- Debug flags or feature toggles
- Source map references (`//# sourceMappingURL=`)

### 1.5 API Documentation Detection

**Purpose:** Discover exposed API documentation (OpenAPI/Swagger, GraphQL introspection, Postman collections).

**Burp Scanner Workflow:**
1. Run Burp passive scan on all discovered endpoints
2. Look for OpenAPI/Swagger indicators in responses
3. Test GraphQL introspection query

**WebFetch Targets:**
```
{target}/swagger.json
{target}/swagger.yaml
{target}/openapi.json
{target}/openapi.yaml
{target}/api-docs
{target}/api-docs.json
{target}/v1/api-docs
{target}/v2/api-docs
{target}/v3/api-docs
{target}/docs
{target}/redoc
```

**GraphQL Introspection Test (Burp Repeater):**
```
POST {target}/graphql
Content-Type: application/json

{"query": "{ __schema { types { name fields { name } } } }"}
```

**What to record:** Any exposed API documentation is a Medium finding minimum. Full schema exposure in production is High.

### 1.6 Application Architecture Mapping

**Purpose:** Detect CDN, WAF, load balancer, reverse proxy, and microservice architecture patterns.

**Burp Passive Analysis:**
1. Examine response headers across multiple pages
2. Look for CDN indicators:
   - `cf-ray` (Cloudflare)
   - `x-amz-cf-id` (CloudFront)
   - `x-fastly-request-id` (Fastly)
   - `x-vercel-id` (Vercel)
3. Look for WAF indicators:
   - `x-sucuri-id`, `x-cdn` headers
   - 403 responses with WAF-specific error pages
4. Look for load balancer indicators:
   - Varying `Server` headers across requests
   - Sticky session cookies
   - `X-Forwarded-For`, `X-Real-IP` handling

**Playwright Commands:**
```
browser_evaluate → {
  const perf = performance.getEntriesByType('resource');
  const origins = [...new Set(perf.map(r => new URL(r.name).origin))];
  return { resourceOrigins: origins, totalResources: perf.length };
}
```

### 1.7 Entry Point Enumeration

**Purpose:** Catalog all input vectors — forms, URL parameters, headers, cookies, file uploads, WebSocket connections.

**Burp Target Workflow:**
1. Crawl the application using Burp Scanner (crawl-only mode)
2. Review Burp Target site map for all discovered entry points
3. Catalog each parameter and its context (URL, body, header, cookie)

**Playwright Commands:**
```
browser_evaluate → {
  const forms = Array.from(document.querySelectorAll('form')).map(f => ({
    action: f.action,
    method: f.method,
    inputs: Array.from(f.querySelectorAll('input, textarea, select')).map(i => ({
      name: i.name, type: i.type, id: i.id, required: i.required
    }))
  }));
  const links = Array.from(document.querySelectorAll('a[href]')).map(a => a.href);
  const urlParams = new URLSearchParams(window.location.search);
  const params = Object.fromEntries(urlParams.entries());
  return { forms, linkCount: links.length, urlParams: params };
}
```

**What to record:** Complete entry point inventory with parameter names, types, and contexts.

### 1.8 HTML Comment and Metadata Review

**Purpose:** Find developer comments, debug information, and metadata left in production HTML.

**Playwright Commands:**
```
browser_evaluate → {
  const walker = document.createTreeWalker(document, NodeFilter.SHOW_COMMENT);
  const comments = [];
  while (walker.nextNode()) {
    const text = walker.currentNode.textContent.trim();
    if (text.length > 0) comments.push(text.substring(0, 500));
  }
  return { commentCount: comments.length, comments: comments.slice(0, 50) };
}

browser_evaluate → {
  const metas = Array.from(document.querySelectorAll('meta')).map(m => ({
    name: m.getAttribute('name') || m.getAttribute('property') || m.getAttribute('http-equiv'),
    content: m.getAttribute('content')
  }));
  return metas.filter(m => m.name);
}
```

**Grep patterns for source code:**
```
# TODO/FIXME/HACK/BUG comments
pattern: (TODO|FIXME|HACK|BUG|XXX|TEMP|TEMPORARY)
glob: "*.{js,ts,jsx,tsx,py,php,rb,html}"

# Commented-out code with credentials
pattern: //.*password|//.*secret|//.*key|#.*password|#.*secret
glob: "*.{js,ts,py,php,rb}"
```

### 1.9 Version Detection for CVE Lookup

**Purpose:** Identify specific framework and library versions to cross-reference against known CVE databases.

**Burp Fingerprinting Workflow:**
1. Analyze HTTP headers for version strings
2. Check common version-revealing endpoints:
   - `{target}/wp-includes/version.php` (WordPress)
   - `{target}/CHANGELOG.md`
   - `{target}/package.json` (if exposed)
3. Cross-reference detected versions against NVD/CVE databases

**Playwright Commands:**
```
browser_evaluate → {
  const versions = {};
  if (window.jQuery) versions.jQuery = jQuery.fn.jquery;
  if (window.React) versions.React = window.React.version;
  if (window.Vue) versions.Vue = window.Vue.version;
  if (window.angular) versions.Angular = window.angular.version?.full;
  if (window.ng) versions.Angular = 'detected (version in bundle)';
  if (window.Ember) versions.Ember = window.Ember.VERSION;
  if (window.Backbone) versions.Backbone = window.Backbone.VERSION;
  if (window._) versions.Lodash = window._.VERSION;
  if (window.moment) versions.Moment = window.moment.version;
  return versions;
}
```

### 1.10 Subdomain and Virtual Host Discovery

**Purpose:** Discover additional subdomains and virtual hosts that expand the attack surface.

**Burp Intruder Workflow:**
1. Configure Burp Intruder to test Host header variations
2. Set payload position in the `Host` header: `[PAYLOAD].{target-domain}`
3. Use Sniper attack type with common subdomain wordlist
4. Compare response sizes — different responses indicate valid virtual hosts

**Subdomain wordlist (priority targets):**
```
api
staging
stage
dev
development
test
qa
uat
beta
alpha
admin
portal
dashboard
app
internal
intranet
mail
webmail
vpn
cdn
static
assets
media
docs
wiki
git
gitlab
jenkins
ci
cd
monitor
grafana
kibana
elastic
```

**Rate limiting:** Max 5 requests/second for this check. Stop after 100 attempts if no results.

---

## Tier 2: AI Judgment

Contextual questions for Claude to assess based on Tier 0 and Tier 1 results.

### Question 1: Attack Surface Proportionality
Is the exposed attack surface proportional to the application's stated purpose? A simple blog with 200 API endpoints suggests excessive exposure.

### Question 2: Information Leakage Assessment
Do the discovered comments, metadata, and configuration files reveal enough information for an attacker to plan targeted attacks? Rate the information leakage from None to Critical.

### Question 3: Technology Stack Risk Profile
Based on detected frameworks and versions, what is the overall risk profile? Are there known unpatched CVEs? Is the stack well-maintained or abandoned?

### Question 4: Hidden Endpoint Risk
Do any discovered hidden endpoints (admin panels, debug tools, API docs) pose immediate risk if accessed by an attacker? Evaluate each for exploitability.

### Question 5: Secret Exposure Severity
For any secrets found in source code, assess: Are they real credentials or placeholders? Are they for production or development? What is the blast radius if compromised?

### Question 6: Architecture Security Posture
Does the application architecture (CDN, WAF, load balancer configuration) provide adequate defense-in-depth? Are there single points of failure?

### Question 7: Entry Point Coverage
Are all identified entry points adequately represented in subsequent security testing? Flag any entry points that require special attention (file uploads, WebSockets, GraphQL).

### Question 8: Reconnaissance Completeness
Based on all findings, is the reconnaissance phase complete enough to proceed to targeted testing? Are there areas that need deeper investigation?

---

## Severity Classification

### Critical
- Production API keys, database credentials, or private keys exposed in source code or client-side JavaScript
- Exposed admin panel with no authentication
- .git directory accessible revealing full source code
- Database connection strings exposed publicly

### High
- Internal API documentation (Swagger/OpenAPI) exposed in production
- GraphQL introspection enabled in production with sensitive schema
- Source maps exposed revealing full source code
- Debug endpoints accessible in production

### Medium
- Technology version disclosure enabling CVE lookup
- HTML comments revealing internal architecture or developer notes
- robots.txt disclosing sensitive paths
- Unnecessary HTTP headers revealing server technology

### Low
- Generic technology fingerprinting (framework name without version)
- Standard sitemap.xml exposure
- Minor metadata in HTML (generator tags)
- Development tool artifacts (e.g., README files)

---

## False Positive Indicators

1. **Placeholder secrets** — Values like `your-api-key-here`, `changeme`, `xxx`, `TODO` are not real secrets
2. **Test/example files** — Secrets in test fixtures, example configs, or documentation are usually not real
3. **Client-side public keys** — Stripe publishable keys (`pk_`), Firebase config, Mapbox tokens are designed to be public
4. **Build-time constants** — Some "secrets" in JS bundles are public configuration (API base URLs, feature flags)
5. **CDN version headers** — Version strings from CDN providers are informational, not app-specific
6. **Standard robots.txt** — Generic Disallow entries (e.g., `/wp-admin/` on WordPress) are expected
7. **Development-only endpoints** — Endpoints that only exist in development builds (check if they respond in production)
8. **Rate-limited enumeration results** — 429 responses during subdomain discovery are expected behavior, not findings

---

## Remediation

### Exposed Secrets
- Immediately rotate all compromised credentials
- Remove secrets from source code; use environment variables
- Add secret patterns to `.gitignore` and pre-commit hooks
- Scan git history with tools like `trufflehog` or `gitleaks`
- Implement secret management (AWS Secrets Manager, HashiCorp Vault, Doppler)

### Information Disclosure
- Remove `Server`, `X-Powered-By`, `X-Generator` headers
- Strip HTML comments from production builds
- Disable source maps in production (`devtool: false` in webpack)
- Remove debug endpoints and API documentation from production
- Implement custom error pages that don't reveal stack traces

### Hidden Endpoints
- Remove or restrict access to admin panels, debug tools, and API docs
- Implement IP allowlisting for administrative endpoints
- Use non-guessable paths for internal tools (not `/admin` or `/debug`)
- Ensure all endpoints require authentication

### Technology Fingerprinting
- Customize or remove default server headers
- Use generic error pages that don't reveal framework details
- Keep all frameworks and libraries updated to latest stable versions
- Subscribe to security advisories for all stack components

### Architecture Hardening
- Deploy WAF in front of all public-facing endpoints
- Use CDN with DDoS protection
- Implement proper network segmentation
- Ensure internal services are not accessible from the public internet
- Disable GraphQL introspection in production
- Remove unused API versions and endpoints
