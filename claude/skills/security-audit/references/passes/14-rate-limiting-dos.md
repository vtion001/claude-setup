# Pass 14: Rate Limiting & DoS Resilience

**Weight:** 2% of Security Score
**OWASP Mapping:** API4:2023 (Unrestricted Resource Consumption), API6:2023 (Unrestricted Access to Sensitive Business Flows)
**Automation Level:** 70% fully automated, 20% AI-assisted, 10% manual judgment
**Difficulty:** Medium -- testing must be carefully rate-limited to avoid actual disruption

---

## IMPORTANT: NON-DESTRUCTIVE TESTING ONLY

This pass uses strictly NON-DESTRUCTIVE testing methods. The goal is to verify that defensive mechanisms EXIST, not to overwhelm or disrupt the target.

**Hard Rules:**
- Maximum 10-20 requests per individual test
- Never exceed 5 requests per second to any single endpoint
- Stop immediately if 429 or 503 responses are received
- Never test actual denial-of-service conditions
- Never test against production without explicit authorization
- All tests verify the PRESENCE of defenses, not the ABSENCE of availability
- If a rate limiter triggers, that is a PASS (defense works)

---

## Overview

Rate limiting and DoS resilience protect applications from abuse through resource exhaustion. Without proper rate limiting, attackers can brute-force credentials, scrape data at scale, abuse expensive operations, and degrade service for legitimate users. This pass verifies that defensive mechanisms are in place and correctly configured, without actually testing their breaking point.

**Key Principle:** We test that the shield exists and responds correctly, not whether it can withstand a sustained barrage.

---

## Tier 0: Static Analysis (Code Review)

### 0.1 Rate Limiting Middleware

Search for rate limiting implementation in the codebase.

**Grep patterns:**

```
# Express rate limiting
Pattern: (express-rate-limit|rate-limit|rateLimit|rateLimiter|express-slow-down|express-brute)
Files: **/*.{js,ts}
Context: Check configuration (window, max, keyGenerator)

# Django throttling
Pattern: (throttle_classes|DEFAULT_THROTTLE_RATES|UserRateThrottle|AnonRateThrottle|ScopedRateThrottle)
Files: **/*.py
Context: Check rate values and scope assignments

# Laravel rate limiting
Pattern: (RateLimiter|throttle:|ThrottleRequests|RateLimited)
Files: **/*.php
Context: Check middleware application and limits

# API Gateway rate limiting
Pattern: (rateLimit|quota|throttl|burstLimit|requestsPerSecond)
Files: **/*.{yml,yaml,json,tf,hcl}
Context: Infrastructure-level rate limiting configuration

# Redis-based rate limiting
Pattern: (ioredis|redis|bull|limiter|sliding-window|token-bucket|leaky-bucket)
Files: **/*.{js,ts,py,rb}
Context: Distributed rate limiting implementation

# Nginx rate limiting
Pattern: (limit_req|limit_conn|limit_rate)
Files: nginx.conf, **/nginx/*.conf, **/*.nginx
Context: Web server level rate limiting

# General rate limit patterns
Pattern: (maxRequests|windowMs|rateLimit|requestLimit|apiLimit|callLimit)
Files: **/*.{js,ts,py,rb,php,go,java}
Context: Application-level rate limit configuration
```

### 0.2 ReDoS (Regular Expression DoS) Patterns

Search for regex patterns vulnerable to catastrophic backtracking.

**Grep patterns:**

```
# Nested quantifiers (primary ReDoS indicator)
Pattern: \(\.\*\)\+|\(\.\+\)\+|\(\.\*\)\*|\(\[.*?\]\+\)\+|\(\[.*?\]\*\)\+
Files: **/*.{js,ts,py,rb,php,java,go}
Context: Nested quantifiers like (a+)+ cause exponential backtracking

# Overlapping alternation with quantifiers
Pattern: \(.*?\|.*?\)\+|\(.*?\|.*?\)\*
Files: **/*.{js,ts,py,rb,php}
Context: Alternation where branches overlap causes backtracking

# Common vulnerable patterns
Pattern: (RegExp|re\.compile|Pattern\.compile|preg_match|Regex\.new)\s*\(
Files: **/*.{js,ts,py,rb,php,java}
Context: Review each regex for exponential backtracking potential

# Email validation regex (frequently vulnerable)
Pattern: [\w\.\-\+]+@[\w\.\-]+\.\w+
Files: **/*.{js,ts,py,rb,php}
Context: Complex email regex is a common ReDoS vector

# URL validation regex (frequently vulnerable)
Pattern: https?://[^\s/]+
Files: **/*.{js,ts,py,rb,php}
Context: Complex URL regex with backtracking potential
```

### 0.3 Resource-Intensive Operations Without Limits

Search for operations that consume significant resources without restrictions.

**Grep patterns:**

```
# Unbounded database queries
Pattern: (findAll|find\(\s*\{?\s*\}?\s*\)|SELECT\s+\*\s+FROM|\.all\(\s*\))(?!.*limit|.*take|.*top|.*LIMIT)
Files: **/*.{js,ts,py,rb,php,sql}
Context: Queries without LIMIT can return entire tables

# Large file operations without size limits
Pattern: (readFile|readFileSync|open\(|fopen|file_get_contents)
Files: **/*.{js,ts,py,rb,php}
Context: File operations without size validation

# Recursive operations on user input
Pattern: (JSON\.parse|xml\.parse|yaml\.load|deserialize|unmarshal)
Files: **/*.{js,ts,py,rb,php,go,java}
Context: Deeply nested input can exhaust stack/memory

# Image/PDF processing without limits
Pattern: (sharp|jimp|Pillow|ImageMagick|convert|gm\(|puppeteer.*pdf|wkhtmltopdf)
Files: **/*.{js,ts,py,rb,php}
Context: Media processing is CPU-intensive; needs input size limits

# Unbounded pagination
Pattern: (page|offset|skip|limit)\s*[:=]\s*(req\.|request\.|params\.|query\.)
Files: **/*.{js,ts,py,rb,php}
Context: Client-controlled pagination without max limit
```

---

## Tier 1: Automated Scanning (Burp MCP + Playwright)

### Check 14.1: Login Rate Limiting

**Tools:** Burp Intruder (rate-limited)
**OWASP:** API4:2023, WSTG-ATHN-03

```
WORKFLOW:
1. Identify the login endpoint
2. Send 10 failed login attempts with incorrect password
3. Check for rate limiting response (429, CAPTCHA, account lockout)

BURP INTRUDER CONFIGURATION:
- Target: Login endpoint (POST /api/auth/login, POST /login)
- Payload: 10 incorrect passwords for a valid username
- Rate: 1 request per second (maximum)
- Attack type: Sniper

EXPECTED DEFENSIVE RESPONSES:
- 429 Too Many Requests with Retry-After header
- CAPTCHA challenge after N failures
- Account lockout message after N failures
- Progressive delay (increasing response time)
- IP-based blocking

INDICATORS OF VULNERABILITY:
- All 10 requests return 401 (unauthorized) with no rate limiting
- Response time remains constant across all attempts
- No Retry-After, X-RateLimit-Remaining, or similar headers
- No CAPTCHA or lockout mechanism triggered
- Account enumeration possible through timing differences
```

### Check 14.2: API Rate Limiting

**Tools:** Burp Intruder (rate-limited)
**OWASP:** API4:2023

```
WORKFLOW:
1. Identify API endpoints (authenticated and unauthenticated)
2. Send 15-20 rapid requests to the same endpoint
3. Check for rate limit headers and 429 responses

BURP INTRUDER CONFIGURATION:
- Target: Most commonly used API endpoint
- Payload: Same valid request repeated 20 times
- Rate: 2 requests per second
- Attack type: Sniper (no payload variation, just repetition)

CHECK RESPONSE HEADERS:
- X-RateLimit-Limit: Maximum requests allowed
- X-RateLimit-Remaining: Requests remaining in window
- X-RateLimit-Reset: When the window resets
- Retry-After: Seconds to wait before retrying
- X-RateLimit-Policy: Rate limit policy identifier

VERIFY:
a) Rate limit headers present on normal responses
b) 429 response returned when limit exceeded
c) Retry-After header provides reasonable wait time
d) Rate limit applies per-user (not just per-IP)
e) Different endpoints may have different limits

INDICATORS OF VULNERABILITY:
- No rate limit headers on any response
- All 20 requests return 200 OK
- Rate limiting headers present but not enforced (counter never decrements)
- Very high limits (>1000 per minute) on sensitive endpoints
```

### Check 14.3: Rate Limit Bypass via Header Manipulation

**Tools:** Burp Repeater
**OWASP:** API4:2023

```
WORKFLOW:
1. First trigger the rate limiter (send requests until 429)
2. Then attempt bypass techniques

BYPASS ATTEMPTS (test each individually):
a) X-Forwarded-For: 127.0.0.1
b) X-Forwarded-For: <random_ip>
c) X-Real-IP: <random_ip>
d) X-Originating-IP: <random_ip>
e) X-Remote-IP: <random_ip>
f) X-Client-IP: <random_ip>
g) X-Remote-Addr: <random_ip>
h) True-Client-IP: <random_ip>
i) CF-Connecting-IP: <random_ip>
j) Fastly-Client-IP: <random_ip>

FOR EACH BYPASS:
- Add the header to the rate-limited request
- Send via Burp Repeater
- Check if 429 changes to 200 (bypass successful)

INDICATORS OF VULNERABILITY:
- Adding X-Forwarded-For changes rate limit behavior
- Different IP in forwarding header resets the rate counter
- Rate limiting relies solely on client-supplied IP header
```

### Check 14.4: GraphQL Batching Limits

**Tools:** Burp Repeater
**OWASP:** API4:2023

```
WORKFLOW:
1. Identify GraphQL endpoint
2. Test alias-based batching
3. Test array-based query batching

ALIAS BATCHING TEST:
{
  q1: user(id: "1") { email }
  q2: user(id: "2") { email }
  q3: user(id: "3") { email }
  q4: user(id: "4") { email }
  q5: user(id: "5") { email }
  q6: user(id: "6") { email }
  q7: user(id: "7") { email }
  q8: user(id: "8") { email }
  q9: user(id: "9") { email }
  q10: user(id: "10") { email }
}

ARRAY BATCHING TEST:
[
  {"query": "{ user(id: \"1\") { email } }"},
  {"query": "{ user(id: \"2\") { email } }"},
  {"query": "{ user(id: \"3\") { email } }"},
  {"query": "{ user(id: \"4\") { email } }"},
  {"query": "{ user(id: \"5\") { email } }"}
]

DEPTH TEST:
{
  user(id: "1") {
    posts {
      comments {
        author {
          posts {
            comments {
              author { id }
            }
          }
        }
      }
    }
  }
}

INDICATORS OF VULNERABILITY:
- All aliased queries execute in a single request
- Array batching not limited to N queries
- Deeply nested queries execute without depth limit
- No query complexity scoring or cost analysis
- No per-query rate limiting (batch counts as 1 request)
```

### Check 14.5: WebSocket Message Rate

**Tools:** Playwright
**OWASP:** API4:2023

```
PLAYWRIGHT SCRIPT:
// Connect to WebSocket and measure rate limiting
(() => {
  return new Promise((resolve) => {
    const wsUrl = document.querySelector('[data-ws-url]')?.dataset.wsUrl
      || window.__WS_URL
      || null;

    if (!wsUrl) {
      resolve({ status: 'no_websocket_detected' });
      return;
    }

    const ws = new WebSocket(wsUrl);
    const results = { sent: 0, received: 0, errors: 0, closed: false };

    ws.onopen = () => {
      // Send 10 rapid messages
      for (let i = 0; i < 10; i++) {
        try {
          ws.send(JSON.stringify({ type: 'ping', id: i }));
          results.sent++;
        } catch (e) {
          results.errors++;
        }
      }
      setTimeout(() => {
        ws.close();
        resolve(results);
      }, 3000);
    };

    ws.onmessage = () => { results.received++; };
    ws.onerror = () => { results.errors++; };
    ws.onclose = () => { results.closed = true; };

    setTimeout(() => resolve({ ...results, timeout: true }), 5000);
  });
})()

INDICATORS OF VULNERABILITY:
- All 10 messages processed without throttling
- No connection close or error on rapid messaging
- No rate limit headers in WebSocket handshake response
```

### Check 14.6: File Upload Size Limits

**Tools:** Burp Repeater
**OWASP:** API4:2023

```
WORKFLOW:
1. Identify file upload endpoints
2. Test with files exceeding reasonable size limits
3. Verify server rejects oversized uploads promptly

TESTS (using Burp Repeater):
a) Send file slightly over stated limit (if 10MB limit, send 11MB)
b) Send very large Content-Length header (1GB) with small body
c) Send chunked transfer encoding with no end boundary
d) Send multipart form with many small files (100 files)

EXPECTED DEFENSIVE RESPONSES:
- 413 Payload Too Large
- Rejection before full upload completes (early termination)
- Clear error message with maximum size stated
- Request body size limit at web server level

INDICATORS OF VULNERABILITY:
- Server accepts files of any size
- Server reads entire upload before rejecting (memory exhaustion risk)
- No Content-Length validation before processing
- 500 error instead of 413 (unhandled, not by design)
```

### Check 14.7: Request Size Limits

**Tools:** Burp Repeater
**OWASP:** API4:2023

```
WORKFLOW:
1. Send requests with oversized components
2. Verify server enforces limits on headers and body

TESTS:
a) Oversized header: Send Cookie header with 100KB value
b) Many headers: Send 100 custom headers
c) Oversized body: Send 50MB JSON body
d) Oversized URL: Send URL with 16KB query string
e) Oversized JSON key: Send JSON with 10KB key name

EXPECTED DEFENSIVE RESPONSES:
- 431 Request Header Fields Too Large (for header issues)
- 413 Payload Too Large (for body issues)
- 414 URI Too Long (for URL issues)
- Early connection termination for extreme sizes

INDICATORS OF VULNERABILITY:
- Server processes oversized requests without rejection
- OOM errors triggered by large inputs
- No configured limits at web server or framework level
```

### Check 14.8: ReDoS Pattern Identification

**Tools:** Code analysis (Grep)
**OWASP:** API4:2023

```
WORKFLOW:
1. Extract all regular expressions from the codebase (Tier 0 patterns)
2. Analyze each for catastrophic backtracking potential
3. Test suspicious patterns with crafted input

KNOWN VULNERABLE PATTERNS:
- /^(a+)+$/           -> Input: "aaaaaaaaaaaaaaaa!"
- /^([a-z]+)+$/       -> Input: "aaaaaaaaaaaaaaa!"  
- /^(a|a)+$/          -> Input: "aaaaaaaaaaaaaaaa!"
- /^(a*)*$/           -> Input: "aaaaaaaaaaaaaaaa!"
- /(\w+)*@/           -> Input: "aaaaaaaaaaaaaaaa!"
- /(.*a){x}/          -> Input: "aaaaaaaaaaaaaaaa!"
- /^[\s\S]*(x|y|z)/   -> Input: 100KB string without x, y, or z

ANALYSIS APPROACH:
- Flag patterns with nested quantifiers: (a+)+, (a*)+, (a+)*
- Flag patterns with overlapping alternation: (a|ab)+
- Flag patterns with backreferences and quantifiers: (a+)\1+
- Recommend safe alternatives (atomic groups, possessive quantifiers, RE2)

INDICATORS OF VULNERABILITY:
- Regex patterns with nested quantifiers on user-controlled input
- Email/URL validation using complex custom regex (instead of libraries)
- No regex timeout configured (Node.js: no built-in protection)
- User-supplied regex patterns (search, filter features)
```

### Check 14.9: Resource Exhaustion (Expensive Operations)

**Tools:** Burp Repeater
**OWASP:** API4:2023, API6:2023

```
WORKFLOW:
1. Identify operations that are computationally expensive
2. Send requests that maximize resource consumption
3. Verify limits are enforced

SPECIFIC TESTS (max 5 requests per test):
a) Export endpoint: Request export of maximum data range
b) Search endpoint: Search with wildcard/regex that matches everything
c) Report generation: Request report spanning maximum date range
d) PDF generation: Request PDF with maximum content
e) Image processing: Request largest supported dimensions

BURP REPEATER:
- Send each request and measure response time
- Compare response time with normal request (baseline)
- If expensive request takes >10x baseline, check for limits

INDICATORS OF VULNERABILITY:
- No limit on export record count
- Search accepts regex from users without complexity limits
- Report generation has no timeout
- No queue/background processing for expensive operations
- Single expensive request blocks other requests (no isolation)
```

### Check 14.10: Pagination Limits

**Tools:** Burp Repeater
**OWASP:** API4:2023

```
WORKFLOW:
1. Identify list/collection endpoints
2. Test pagination parameter manipulation
3. Verify maximum page size is enforced

TESTS:
a) Set page_size/limit/per_page to very large value: ?limit=999999
b) Set page_size to 0: ?limit=0
c) Set page_size to negative: ?limit=-1
d) Omit pagination parameter entirely
e) Set offset to very large value: ?offset=999999999

EXPECTED BEHAVIOR:
- Server enforces maximum page size (e.g., max 100 per page)
- Server uses default page size when parameter is missing
- Server rejects negative/zero/invalid values
- Server returns empty array (not error) for high offset

INDICATORS OF VULNERABILITY:
- Server returns all records when no limit specified
- Server accepts limit=999999 and returns all records
- Negative limit causes error instead of being rejected gracefully
- No maximum page size enforced (client controls result set size)
```

---

## Tier 2: AI Judgment Questions

### Question 1: Defense Depth
Are rate limits applied at multiple layers (CDN/WAF, web server, application, database)? Would bypassing one layer still leave other defenses active?

### Question 2: Rate Limit Granularity
Are rate limits applied per-user, per-IP, or per-API-key? Are different endpoints given different rate limits based on their cost and sensitivity? Are authenticated and unauthenticated endpoints rate-limited differently?

### Question 3: Graceful Degradation
When rate limits are exceeded, does the application degrade gracefully? Are rate-limited responses informative (429 with Retry-After) rather than cryptic errors? Does the application continue serving other users normally?

### Question 4: Resource Isolation
Are expensive operations isolated from the main request-serving path? Are there separate worker pools, queues, or circuit breakers for resource-intensive tasks? Could a single expensive request block other users?

### Question 5: Monitoring and Alerting
Are rate limit violations logged and monitored? Would the team be alerted to a sustained brute-force attack or data scraping campaign? Are there automated responses to detected abuse?

### Question 6: Client-Side Considerations
Does the application implement client-side throttling (debouncing, request queuing)? While not a security control, client-side rate limiting reduces unnecessary load and improves UX during rate-limited responses.

---

## Severity Classification

### Critical (P1) -- Score: 0/10
- No rate limiting on authentication endpoints (enables brute-force attacks)
- No rate limiting on API endpoints handling sensitive data (enables mass data scraping)
- ReDoS vulnerability on user-facing input validation (single request causes minutes-long hang)

### High (P2) -- Score: 2/10
- Rate limiting easily bypassed via header manipulation (X-Forwarded-For)
- GraphQL batching allows unlimited queries per request
- No pagination limits allowing full database extraction
- No file upload size limits (memory exhaustion possible)

### Medium (P3) -- Score: 5/10
- Rate limiting present but with very high thresholds (>1000/min on sensitive endpoints)
- Rate limiting on login but not on password reset or registration
- WebSocket connections without message rate limiting
- Resource-intensive operations without timeout or queuing

### Low (P4) -- Score: 7/10
- Rate limit headers present but inconsistent across endpoints
- Rate limiting present but missing Retry-After header
- Minor pagination limit issues (default page size too large but capped)
- ReDoS patterns in code but not on user-controlled input paths

---

## False Positive Indicators

1. **Infrastructure Rate Limiting:** Rate limiting may be applied at the CDN/WAF level (Cloudflare, AWS WAF, API Gateway) and not visible in application code. Check infrastructure configuration before flagging missing application-level limits.
2. **Internal APIs:** APIs called only by trusted internal services may intentionally have no rate limiting. Verify the API is actually exposed to untrusted clients.
3. **Authenticated Endpoints with Quotas:** Some applications use billing-based quotas instead of traditional rate limiting. Usage tracking via subscription tiers is a valid alternative.
4. **Load Balancer Behavior:** 429 responses may not appear in testing if the load balancer distributes requests across multiple application instances, each with independent rate counters.
5. **Test Environment Differences:** Rate limiting may be disabled in staging/development environments for testing convenience. Verify against production configuration.
6. **CDN Caching:** GET requests that are cached at the CDN level may appear to bypass rate limiting because they never reach the application server.

---

## Remediation

### Rate Limiting Implementation

```javascript
// Express.js example with express-rate-limit
const rateLimit = require('express-rate-limit');

// General API rate limit
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // 100 requests per window
  standardHeaders: true,     // Return rate limit headers
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip, // Per-user if authenticated
  handler: (req, res) => {
    res.status(429).json({
      error: 'Too many requests',
      retryAfter: Math.ceil(req.rateLimit.resetTime / 1000)
    });
  }
});

// Strict login rate limit
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,                    // 5 attempts per 15 minutes
  skipSuccessfulRequests: true
});

app.use('/api/', apiLimiter);
app.use('/api/auth/login', loginLimiter);
```

### ReDoS Prevention
- Use RE2-based regex engines (no backtracking): `re2` npm package, Google RE2
- Set regex timeouts where supported
- Avoid nested quantifiers: `(a+)+` -> `a+`
- Use atomic groups or possessive quantifiers where available
- Prefer purpose-built validators over custom regex (email: `validator.js`, URL: `URL()` constructor)
- Limit input length before applying regex

### GraphQL Protection
- Implement query depth limiting (max depth 7-10)
- Implement query complexity/cost analysis
- Limit batch size (max 5-10 queries per request)
- Disable aliases above a threshold
- Set per-query timeout
- Use persisted queries (allowlisted queries only)

### Pagination Enforcement
- Always enforce server-side maximum page size (e.g., max 100)
- Use cursor-based pagination instead of offset for large datasets
- Return total count only when explicitly requested
- Set sensible defaults (page_size=20 if not specified)

### Resource Protection
- Set timeouts on all database queries
- Use job queues for expensive operations (PDF generation, exports, reports)
- Implement circuit breakers for external service calls
- Set maximum request body size at web server level
- Configure connection pool limits
- Monitor and alert on request duration anomalies
