# Pass 09: API Security

**OWASP Mapping:** OWASP API Security Top 10 (2023), WSTG-APIT-01
**Weight:** 10% of Security Score
**Automation Level:** 50% fully automated, 35% AI-assisted, 15% manual judgment

---

## Purpose

Evaluate the security posture of all API endpoints including REST, GraphQL, and WebSocket interfaces. APIs represent the fastest-growing attack surface in modern applications. This pass covers authentication enforcement, object-level and property-level authorization, rate limiting, input validation, error handling, and API inventory management. The OWASP API Security Top 10 is used as the primary reference alongside WSTG-APIT testing guidance.

---

## Tier 0: Static Analysis (Code-Level)

### 0.1 API Route Definitions

```
Grep patterns:

# Express.js routes
pattern: "app\.(get|post|put|patch|delete|all)\s*\(\s*['\"/]"
context: enumerate all API endpoints

# Next.js API routes
pattern: "export\s+(default\s+)?function\s+(GET|POST|PUT|PATCH|DELETE)"
context: App Router route handlers
pattern: "export\s+default\s+function\s+handler"
context: Pages Router API routes

# FastAPI / Flask / Django routes
pattern: "@app\.(get|post|put|patch|delete|route)\s*\("
pattern: "@router\.(get|post|put|patch|delete)\s*\("
pattern: "path\(.*views?\."
pattern: "urlpatterns\s*=\s*\["

# NestJS routes
pattern: "@(Get|Post|Put|Patch|Delete|All)\("
context: NestJS controller decorators

# GraphQL schema
pattern: "type\s+Query\s*\{|type\s+Mutation\s*\{|type\s+Subscription\s*\{"
context: enumerate all GraphQL operations
pattern: "extend\s+type\s+(Query|Mutation)"
context: extended schema definitions
```

### 0.2 Authentication Middleware on API Routes

```
# Express middleware patterns
pattern: "app\.use\(.*auth|app\.use\(.*passport|app\.use\(.*jwt"
context: verify auth middleware is applied globally or per-route
pattern: "router\.use\(.*auth|router\.use\(.*protect"
context: verify router-level auth middleware

# Per-route auth decorators
pattern: "@(UseGuards|Authorize|RequireAuth|Protected|Auth|Login_required)"
context: verify auth on individual endpoints
pattern: "@(Public|AllowAny|anonymous_allowed|SkipAuth|NoAuth)"
severity: MEDIUM — endpoint explicitly bypasses authentication

# Check for unprotected routes
Look for: routes WITHOUT auth middleware that handle sensitive data
Compare: list of all routes vs list of authenticated routes
Flag: any data-modifying route without auth middleware

# JWT verification
pattern: "jwt\.verify|jsonwebtoken\.verify|jose\.jwtVerify"
expected: PRESENT for JWT-based auth
pattern: "jwt\.decode(?!\s*.*verify)"
severity: HIGH — decoding without verification allows token forgery
```

### 0.3 Rate Limiting Configuration

```
# Rate limiting libraries
pattern: "express-rate-limit|rate-limit|ratelimit|throttle|bottleneck"
expected: PRESENT on API routes
flag_if_missing: HIGH — no rate limiting detected

# Rate limit configuration
pattern: "(windowMs|window|interval)\s*[:=]\s*(\d+)"
pattern: "(max|limit|maxRequests)\s*[:=]\s*(\d+)"
context: verify reasonable limits (not too permissive)

# Per-endpoint rate limiting
pattern: "rateLimit\(|limiter\(|throttle\("
context: verify rate limiting on sensitive endpoints (login, registration, password reset, API)

# Redis/memory store for rate limiting
pattern: "rate-limit-redis|ioredis|redis.*rate|memoryStore"
context: distributed rate limiting requires shared store (not in-memory)
```

### 0.4 Input Validation on API Endpoints

```
# Validation libraries
pattern: "zod|yup|joi|class-validator|ajv|express-validator|cerberus|marshmallow|pydantic"
expected: PRESENT for request body validation

# Schema validation patterns
pattern: "\.validate\(|\.parse\(|\.safeParse\(|\.check\("
context: verify validation is applied to request data

# SQL parameterization
pattern: "\$\{.*\}.*(?:SELECT|INSERT|UPDATE|DELETE|WHERE)"
severity: HIGH — template literal SQL (potential injection)
pattern: "\.query\(\s*`|\.execute\(\s*`"
severity: HIGH — template literal in SQL query
expected_instead: "\.query\(\s*['\"].*\$\d|\.query\(\s*['\"].*\?|parameterized|prepared"

# ORM usage (safer than raw SQL)
pattern: "prisma\.|sequelize\.|typeorm\.|mongoose\.|knex\."
context: ORMs provide parameterization by default (but check for raw queries)
pattern: "\.raw\(|\.rawQuery\(|\$queryRaw"
severity: MEDIUM — raw SQL within ORM bypasses parameterization
```

---

## Tier 1: Automated Scanning (12 Checks)

### Check 1: API Authentication (All Endpoints Require Auth)

**Tools:** Burp Intruder
**OWASP API:** API2:2023

```
Workflow:
1. Enumerate all API endpoints from:
   - Source code analysis (Tier 0)
   - Burp Sitemap (crawled endpoints)
   - OpenAPI/Swagger specification
   - GraphQL introspection

2. For each endpoint, send request without authentication:
   - Remove Authorization header
   - Remove session cookies
   - Send via Burp Intruder (Sniper mode on endpoint list)

3. Analyze responses:
   200 OK with data = CRITICAL (unauthenticated access to data)
   200 OK empty = MEDIUM (endpoint accessible but no data)
   401 Unauthorized = PASS
   403 Forbidden = PASS
   404 Not Found = INFO (endpoint hidden from unauth users)

4. Special attention to:
   - Admin endpoints (/admin/*, /api/admin/*)
   - User data endpoints (/api/users/*, /api/profile)
   - File/document endpoints (/api/files/*, /api/documents/*)
   - Configuration endpoints (/api/settings, /api/config)
   - Debug/health endpoints (/debug, /health, /metrics, /status)
```

### Check 2: BOLA / Object-Level Authorization

**Tools:** Burp Intruder
**OWASP API:** API1:2023

```
Workflow:
1. Authenticate as User A (regular user)
2. Identify endpoints that reference objects by ID:
   GET /api/users/{id}
   GET /api/orders/{id}
   GET /api/documents/{id}
   PUT /api/users/{id}/profile
   DELETE /api/comments/{id}

3. Burp Intruder — for each endpoint:
   - Replace User A's object ID with User B's object ID
   - Use sequential IDs if integer (1, 2, 3...)
   - Use known other-user UUIDs if available
   - Test across multiple object types

4. Analyze responses:
   200 OK with User B's data = CRITICAL (BOLA/IDOR confirmed)
   200 OK with User A's data = PASS (server-side filtering)
   403 Forbidden = PASS (authorization enforced)
   404 Not Found = ACCEPTABLE (may be hiding resources)

5. Test with different HTTP methods:
   GET (read) — can User A read User B's data?
   PUT (update) — can User A modify User B's data?
   DELETE — can User A delete User B's resources?

6. Check for GUID predictability:
   - Are UUIDs v1 (time-based, predictable) or v4 (random)?
   - Can object IDs be enumerated or guessed?
   - Is object ID the ONLY authorization check?
```

### Check 3: Property-Level Authorization (Mass Assignment, Excessive Data)

**Tools:** Burp Repeater
**OWASP API:** API3:2023

```
Workflow:
PART A — Excessive Data Exposure:
1. Send legitimate API requests and analyze responses
2. Check for unnecessary fields in response:
   - Password hashes in user profiles
   - Internal IDs or database keys
   - Other users' data in list endpoints
   - Admin/system fields (created_by, internal_notes)
   - Sensitive PII not needed for the UI

3. Compare API response with what the UI actually displays
   If API returns 20 fields but UI shows 5: flag excessive data

PART B — Mass Assignment:
1. Capture a legitimate PUT/PATCH request (e.g., profile update)
2. Add extra fields that should not be user-modifiable:
   - "role": "admin"
   - "isAdmin": true
   - "isVerified": true
   - "balance": 99999
   - "permissions": ["admin", "superuser"]
   - "email_verified": true
   - "subscription": "enterprise"
   
3. Send via Burp Repeater
4. Verify if extra fields were accepted:
   - GET the modified resource
   - Check if unauthorized fields were updated
   - CRITICAL if role/permission escalation succeeds
```

### Check 4: Rate Limiting (429 Response Verification)

**Tools:** Burp Intruder (controlled)
**OWASP API:** API4:2023

```
Workflow:
1. Test rate limiting on critical endpoints:
   - Login endpoint (prevent brute force)
   - Registration endpoint (prevent mass account creation)
   - Password reset (prevent email bombing)
   - API data endpoints (prevent scraping)
   - File upload (prevent resource exhaustion)

2. Burp Intruder (controlled, within safe limits):
   - Send 20 rapid requests to each endpoint
   - Monitor for 429 Too Many Requests response
   - Record the threshold at which rate limiting activates

3. Verify rate limit behavior:
   - Response includes Retry-After header
   - Rate limit resets after cooldown period
   - Rate limit is per-user (not global — one user should not block others)
   - Rate limit applies to failed attempts (not just successful ones)

4. Test rate limit bypass attempts:
   - X-Forwarded-For header manipulation
   - X-Real-IP header manipulation
   - Different API keys (if key-based limiting)
   - Case variations in URL path
   - Add trailing slash or query parameters

5. IMPORTANT: Keep request volume LOW (max 20-30 requests per test)
   Do NOT run exhaustive rate limit testing on production
```

### Check 5: GraphQL Introspection (Enabled in Production?)

**Tools:** Burp Repeater
**OWASP API:** API9:2023

```
Workflow:
1. Send introspection query:
   POST /graphql
   Content-Type: application/json
   {"query": "{__schema{types{name,fields{name,type{name}}}}}"}

2. Analyze response:
   Full schema returned = HIGH (information disclosure)
   Error/empty = PASS (introspection disabled)
   Partial schema = MEDIUM (partial introspection)

3. Test introspection variations:
   - Full introspection: {__schema{queryType{name}}}
   - Type introspection: {__type(name:"User"){fields{name}}}
   - Field suggestions: send intentional typo, check for "Did you mean...?"

4. If introspection is disabled, attempt schema inference:
   - Send queries with common type names (User, Order, Product)
   - Analyze error messages for field suggestions
   - Build partial schema from error responses

5. Check for development tools in production:
   - GraphiQL interface: /graphiql, /graphql/playground
   - Apollo Studio/Sandbox: embedded explorer
   - GraphQL Voyager: schema visualization
```

### Check 6: GraphQL Depth/Complexity (Deeply Nested Queries, Aliases)

**Tools:** Burp Repeater
**OWASP API:** API4:2023

```
Workflow:
1. Test query depth limits:
   Send increasingly deep nested query:
   {user{friends{friends{friends{friends{friends{name}}}}}}}
   
   Expected: Depth limit error (e.g., "Query depth exceeds maximum of 10")
   VULNERABLE if unlimited depth is allowed (DoS risk)

2. Test query complexity limits:
   Send query requesting many fields:
   {users{id,name,email,phone,address,orders{id,total,items{id,name,price}}}}
   
   Expected: Complexity limit error
   VULNERABLE if unlimited field selection is allowed

3. Test alias-based amplification:
   {
     a1: user(id: 1) { name }
     a2: user(id: 2) { name }
     a3: user(id: 3) { name }
     ... (repeat 100+ times)
   }
   
   Expected: Alias limit or complexity limit
   VULNERABLE if unlimited aliases are allowed (rate limit bypass)

4. Test batch query (array of queries):
   POST [
     {"query": "{ user(id: 1) { name } }"},
     {"query": "{ user(id: 2) { name } }"},
     ... (repeat many times)
   ]
   
   Expected: Batch size limit
   VULNERABLE if unlimited batch queries are allowed

5. Verify limits are enforced:
   - Query depth limit (recommended: 7-10)
   - Query complexity/cost limit
   - Alias count limit
   - Batch query count limit
   - Request size limit (bytes)
```

### Check 7: API Versioning (Deprecated/Undocumented Versions)

**Tools:** Burp Intruder
**OWASP API:** API9:2023

```
Workflow:
1. Test for deprecated API versions:
   /api/v1/users (may be deprecated but still active)
   /api/v2/users (current version)
   /v1/, /v2/, /v3/ prefix variations
   /api/1.0/, /api/2.0/ variations

2. Burp Intruder — fuzz API version prefixes:
   Payload: v1, v2, v3, v4, v0, beta, alpha, staging, dev, test, internal, legacy
   Position: /api/{version}/users

3. Check for version-specific vulnerabilities:
   - Deprecated versions may lack security patches
   - Older versions may have weaker authentication
   - Compare authorization behavior between versions

4. Check for undocumented endpoints:
   /api/debug, /api/test, /api/internal
   /api/__debug__, /api/_internal
   /swagger, /api-docs, /openapi.json, /openapi.yaml

5. Flag deprecated but accessible versions:
   HIGH: Old API version accessible with weaker auth/authz
   MEDIUM: Old API version accessible but same security controls
   LOW: Old API version returns deprecation notice but still works
```

### Check 8: Content-Type Enforcement

**Tools:** Burp Repeater
**OWASP API:** API8:2023

```
Workflow:
1. For API endpoints expecting JSON, test with wrong Content-Type:
   
   Original: Content-Type: application/json
   Test 1: Content-Type: text/plain
   Test 2: Content-Type: application/x-www-form-urlencoded
   Test 3: Content-Type: multipart/form-data
   Test 4: Content-Type: text/xml
   Test 5: Remove Content-Type header entirely

2. Analyze server behavior:
   PASS: Server rejects with 415 Unsupported Media Type
   VULNERABLE: Server processes request regardless of Content-Type
   Note: Accepting form-urlencoded on JSON endpoints enables CSRF

3. Test Content-Type header injection:
   Content-Type: application/json; charset=utf-7
   Content-Type: application/json; boundary=something
   Check for encoding-based attacks

4. For file upload endpoints:
   - Verify Content-Type matches actual file content
   - Test with mismatched MIME types
   - Verify server validates file content (not just header)
```

### Check 9: Mass Assignment (Extra Fields in POST/PUT)

**Tools:** Burp Repeater
**OWASP API:** API3:2023

```
Workflow:
1. Capture legitimate create/update requests
2. For each endpoint, add sensitive extra fields:

   User registration:
   Original: {"username": "test", "email": "test@test.com", "password": "Test1234!"}
   Attack:   {"username": "test", "email": "test@test.com", "password": "Test1234!", 
              "role": "admin", "isAdmin": true, "verified": true}

   Profile update:
   Original: {"name": "New Name"}
   Attack:   {"name": "New Name", "email": "admin@target.com", "role": "admin",
              "subscription_tier": "enterprise", "credits": 99999}

3. Send modified request via Burp Repeater
4. Verify what was actually stored:
   - GET the resource after modification
   - Compare all fields with expected values
   - Check if unauthorized fields were accepted

5. Common mass assignment targets:
   - role, isAdmin, is_admin, admin, permissions
   - verified, email_verified, is_active, is_superuser
   - balance, credits, subscription, plan, tier
   - created_at, updated_at (timestamp manipulation)
   - user_id, owner_id (ownership transfer)
   - internal_notes, admin_notes (data injection)
```

### Check 10: API Error Handling (Stack Traces in Errors)

**Tools:** Burp Intruder
**OWASP API:** API8:2023

```
Workflow:
1. Trigger errors across API endpoints:
   - Send invalid data types (string where number expected)
   - Send extremely long strings (10,000+ chars)
   - Send null/undefined values for required fields
   - Send invalid JSON syntax
   - Request non-existent resources with random IDs
   - Use invalid HTTP methods (PATCH on GET-only endpoint)
   - Send requests with invalid/expired auth tokens
   - Send SQL injection payloads (may trigger database errors)

2. Analyze error responses for information disclosure:
   CRITICAL: Full stack traces with file paths and line numbers
   HIGH: Database error messages revealing schema/table names
   HIGH: Internal IP addresses or hostnames
   MEDIUM: Framework/library version numbers
   MEDIUM: Detailed error codes mapping to internal logic
   LOW: Generic error with status code only (PASS)

3. Verify consistent error format:
   - All errors should follow same JSON structure
   - No HTML error pages from API endpoints
   - Status codes should be appropriate (400, 401, 403, 404, 500)
   - Error messages should be user-friendly (no technical details)

4. Check for debug mode indicators:
   - Verbose error output
   - Debug toolbar (Django Debug Toolbar, etc.)
   - Source code in error pages
   - Environment variable dumps
```

### Check 11: WebSocket API Security

**Tools:** Burp + Playwright
**OWASP API:** API2:2023, API8:2023

```
Workflow:
1. Identify WebSocket endpoints:
   - Check for ws:// or wss:// URLs in source code
   - Monitor Burp proxy for WebSocket upgrade requests
   - Check for Socket.IO, WS, or similar library usage

2. Test WebSocket authentication:
   - Attempt to establish connection without authentication
   - Attempt to send messages without session token
   - Check if authentication is per-connection or per-message
   - Verify session expiration is enforced on open connections

3. Test WebSocket authorization:
   - Subscribe to channels/rooms the user should not access
   - Send messages to channels the user should not write to
   - Attempt to impersonate other users via WebSocket messages

4. Test WebSocket input validation:
   - Send XSS payloads via WebSocket messages
   - Send SQL injection payloads via WebSocket messages
   - Send oversized messages (DoS)
   - Send malformed JSON/binary data

5. Check WebSocket origin:
   - Modify Origin header on upgrade request
   - Verify server validates Origin
   - Cross-Site WebSocket Hijacking risk if origin not validated
```

### Check 12: OpenAPI/Swagger Exposure

**Tools:** Burp + WebFetch
**OWASP API:** API9:2023

```
Workflow:
1. Check for exposed API documentation:
   /swagger
   /swagger-ui
   /swagger-ui.html
   /swagger.json
   /swagger.yaml
   /api-docs
   /api-docs.json
   /openapi.json
   /openapi.yaml
   /v2/api-docs
   /v3/api-docs
   /redoc
   /graphql (with introspection)
   /graphiql
   /.well-known/openapi

2. Analyze exposed documentation:
   CRITICAL: Full API spec with internal/admin endpoints documented
   HIGH: API spec accessible without authentication
   MEDIUM: API spec accessible to authenticated users only
   LOW: API spec exists but is restricted to admin users

3. Check for sensitive information in spec:
   - Internal endpoint documentation
   - Authentication mechanism details
   - Example values containing real data
   - Server URLs revealing internal infrastructure
   - Deprecated endpoints listed

4. Verify documentation matches implementation:
   - Are undocumented endpoints accessible?
   - Are documented security requirements enforced?
   - Are example payloads safe (not containing real data)?
```

---

## Tier 2: AI Judgment (8 Contextual Questions)

### Q1: API Authentication Architecture
Is the API authentication mechanism appropriate for the use case? Is token-based auth (JWT/OAuth) used correctly with proper expiration, refresh, and revocation? Are API keys used where they should not be (they are not suitable for user authentication)?

### Q2: Authorization Granularity
Is authorization enforced at the object level (not just endpoint level)? Can User A access User B's specific resources? Is the authorization model consistent across all API versions and endpoints? Are there any endpoints where authorization is missing or inconsistent?

### Q3: API Surface Area Minimization
Does the API expose only the data and operations necessary for its consumers? Are there endpoints that return excessive data? Are there unused or deprecated endpoints that should be decommissioned? Is the API documentation proportionate to the public surface area?

### Q4: Input Validation Completeness
Is input validation applied consistently across all API endpoints? Are validation rules appropriate for the data type and business context? Is validation performed on the server side (not just client-side)? Are edge cases handled (empty strings, null, negative numbers, unicode, oversized inputs)?

### Q5: Error Handling Security
Do API error responses leak sensitive information? Are error messages consistent regardless of the failure reason (preventing enumeration)? Is there a centralized error handling mechanism? Do errors fail securely (deny access on error, not grant)?

### Q6: Rate Limiting Strategy
Is the rate limiting strategy appropriate for each endpoint's sensitivity? Are critical endpoints (login, password reset) more strictly limited than read-only endpoints? Can rate limits be bypassed via header manipulation or API key rotation? Is rate limiting per-user, per-IP, or global?

### Q7: API Versioning and Deprecation
Are deprecated API versions properly decommissioned or do they remain accessible with potentially weaker security? Is there a clear deprecation timeline? Are security patches applied to all active API versions?

### Q8: Third-Party API Consumption Safety
Does the application consume external APIs safely? Are responses from third-party APIs validated before processing? Are third-party API keys stored securely? Is there fallback handling for third-party API failures?

---

## Severity Classification

### Critical (P1 — Score: 0/10)
- API endpoints accessible without any authentication returning sensitive data
- BOLA vulnerability allowing access to other users' personal/financial data
- Mass assignment allowing role/permission escalation to admin
- SQL injection via API parameters (confirmed execution)
- API keys or credentials exposed in API documentation or responses

### High (P2 — Score: 2/10)
- BOLA on non-critical resources (preferences, non-sensitive data)
- GraphQL introspection enabled in production with sensitive schema
- No rate limiting on login or password reset endpoints
- Stack traces or database errors exposed in API error responses
- GraphQL mutations executable via GET (CSRF risk)
- Deprecated API version accessible with weaker security controls
- WebSocket connections accepting arbitrary origins

### Medium (P3 — Score: 5/10)
- Excessive data exposure (API returns more fields than UI needs)
- Rate limiting present but bypassable via header manipulation
- GraphQL depth/complexity limits missing (DoS risk)
- API error responses inconsistent (different formats for different errors)
- Swagger/OpenAPI documentation publicly accessible
- API versioning with no deprecation plan
- Content-Type not enforced (accepts wrong content types)

### Low (P4 — Score: 7/10)
- GraphQL alias limit not enforced (minor DoS risk)
- API pagination missing max limit (data scraping risk)
- Rate limit thresholds too generous but present
- API documentation contains example data that looks like real data
- Health/status endpoints accessible without auth (typically acceptable)
- Missing Retry-After header on 429 responses

---

## False Positive Indicators

### Authentication False Positives
- **Public endpoints:** Some API endpoints are intentionally public (product listing, public profiles, health checks). Verify against the application's access control design
- **Service-to-service auth:** Internal APIs may use network-level security (VPC, service mesh) instead of per-request auth. Flag but note the architecture
- **Webhook endpoints:** Webhook receivers may intentionally accept unauthenticated requests with signature verification instead

### BOLA False Positives
- **Public resources:** Resources intentionally accessible to all users (public posts, shared documents) are not BOLA vulnerabilities
- **Admin endpoints:** Admin users legitimately accessing other users' data is not BOLA — verify the requesting user's role
- **UUIDs preventing enumeration:** While UUIDs make BOLA harder to exploit, they are NOT a security control. Still flag missing authorization checks

### Rate Limiting False Positives
- **Cached responses:** Responses served from CDN cache may not trigger rate limits — this is expected behavior
- **Health check endpoints:** Rate limiting on health/status endpoints may be intentionally absent
- **Internal API endpoints:** APIs only accessible from internal networks may have relaxed rate limits

---

## Remediation

### API Authentication
1. Require authentication on all non-public endpoints
2. Use OAuth 2.0 or JWT with proper configuration
3. Implement token expiration (short-lived access tokens, longer refresh tokens)
4. Use API keys only for service identification, not user authentication
5. Implement token revocation for logout and security events

### BOLA/IDOR Prevention
1. Implement object-level authorization on every endpoint
2. Verify the requesting user owns or has access to the requested resource
3. Use random UUIDs (v4) instead of sequential IDs (defense in depth)
4. Centralize authorization logic (middleware or policy engine)
5. Log and alert on authorization failures

### Rate Limiting
1. Implement per-user rate limiting (not just per-IP)
2. Use sliding window algorithm for smooth rate limiting
3. Set stricter limits on sensitive endpoints (login: 5/min, API: 100/min)
4. Return 429 with Retry-After header
5. Use distributed rate limiting store (Redis) for multi-instance deployments

### GraphQL Security
1. Disable introspection in production
2. Implement query depth limit (max 7-10 levels)
3. Implement query complexity/cost analysis
4. Limit aliases per query
5. Disable batch queries or limit batch size
6. Require POST method with application/json Content-Type for mutations

### Input Validation
1. Validate all input on the server side using a schema validation library
2. Enforce strict typing (reject unexpected types)
3. Set maximum lengths for all string fields
4. Use allowlists for enumerated values
5. Sanitize output (context-aware encoding)
